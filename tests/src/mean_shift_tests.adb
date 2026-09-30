with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Mean_Shift_Tests is

   --  This suite deliberately builds and forwards NaN/Inf Float64 values
   --  through its helpers to exercise public and C ABI rejection paths.
   pragma Suppress (Validity_Check);
   pragma Suppress (Range_Check);

   use type Interfaces.Integer_32;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Float64_Value;

   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   package Vec3 renames OpenCV.Core.UInt8_Vec3;
   package Vec3_Access renames OpenCV.Core.UInt8_Vec3_Access;
   use type C_API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Float64_Value);

   NaN_Value      : constant OpenCV.Float64_Value :=
     Bits_To_Float64 (16#7FF8_0000_0000_0000#);
   Infinity_Value : constant OpenCV.Float64_Value :=
     Bits_To_Float64 (16#7FF0_0000_0000_0000#);

   --  Raw import taking arbitrary addresses so null handles can be passed.
   function Raw_Mean_Shift
     (Source, Destination   : System.Address;
      Spatial_Radius        : Interfaces.C.double;
      Color_Radius          : Interfaces.C.double;
      Maximum_Pyramid_Level : Interfaces.Integer_32;
      Maximum_Iterations    : Interfaces.Integer_32;
      Epsilon               : Interfaces.C.double) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_pyr_mean_shift_filter";

   Left_Color  : constant Vec3.Vector := (40, 80, 160);
   Right_Color : constant Vec3.Vector := (200, 150, 30);

   Default_Termination : constant IP.Mean_Shift_Termination :=
     (Maximum_Iterations => 5, Epsilon => 1.0);

   procedure Assert_Raises
     (Attempt : not null access procedure; Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, Message);
   end Assert_Raises;

   procedure Assert_Invalid (Status : C_API.Status; Fragment, Message : String)
   is
   begin
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment)
                  /= 0,
         Message & " (diagnostic: " & C_API.Last_Error_Message & ")");
   end Assert_Invalid;

   function Max_Difference (Left, Right : OpenCV.Core.Mat) return Long_Float
   is (OpenCV.Core.Norm
         (OpenCV.Core.Abs_Diff (Left, Right), OpenCV.Core.Infinity));

   function Is_UInt8_C3
     (Image : OpenCV.Core.Mat; Rows, Columns : Natural) return Boolean
   is (Image.Rows = Rows
       and then Image.Columns = Columns
       and then Image.Depth = OpenCV.Core.UInt8
       and then Image.Channels = 3);

   function Is_Placeholder (Image : OpenCV.Core.Mat) return Boolean
   is (Image.Rows = 1
       and then Image.Columns = 2
       and then Image.Depth = OpenCV.Core.UInt16
       and then Image.Channels = 2);

   function Placeholder return OpenCV.Core.Mat
   is (OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2)));

   --  Left half near Left_Color, right half near Right_Color, each channel
   --  perturbed by a deterministic offset in -6 .. 6.
   procedure Fill_Two_Color (Image : in out OpenCV.Core.Mat) is
      Half  : constant Natural := Image.Columns / 2;
      Pixel : Vec3.Vector;
      Base  : Vec3.Vector;
   begin
      for Row in 0 .. Image.Rows - 1 loop
         for Column in 0 .. Image.Columns - 1 loop
            Base := (if Column < Half then Left_Color else Right_Color);
            for Channel in Vec3.Component_Index loop
               Pixel (Channel) :=
                 Interfaces.Unsigned_8
                   (Integer (Base (Channel))
                    + (Row * 7 + Column * 13 + Channel * 5) mod 13
                    - 6);
            end loop;
            Vec3_Access.Set (Image, Row, Column, Pixel);
         end loop;
      end loop;
   end Fill_Two_Color;

   function Two_Color_Image (Rows, Columns : Natural) return OpenCV.Core.Mat is
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Columns, (OpenCV.Core.UInt8, 3));
   begin
      Fill_Two_Color (Image);
      return Image;
   end Two_Color_Image;

   --  Largest per-channel |pixel - Nominal| over the column range.
   function Max_Deviation
     (Image                     : OpenCV.Core.Mat;
      First_Column, Last_Column : Natural;
      Nominal                   : Vec3.Vector) return Natural
   is
      Largest : Natural := 0;
      Pixel   : Vec3.Vector;
   begin
      for Row in 0 .. Image.Rows - 1 loop
         for Column in First_Column .. Last_Column loop
            Pixel := Vec3_Access.Get (Image, Row, Column);
            for Channel in Vec3.Component_Index loop
               Largest :=
                 Natural'Max
                   (Largest,
                    abs (Integer (Pixel (Channel))
                         - Integer (Nominal (Channel))));
            end loop;
         end loop;
      end loop;
      return Largest;
   end Max_Deviation;

   --  Largest per-channel (max - min) over the column range.
   function Spread
     (Image : OpenCV.Core.Mat; First_Column, Last_Column : Natural)
      return Natural
   is
      Low     : array (Vec3.Component_Index) of Natural := (others => 255);
      High    : array (Vec3.Component_Index) of Natural := (others => 0);
      Pixel   : Vec3.Vector;
      Largest : Natural := 0;
   begin
      for Row in 0 .. Image.Rows - 1 loop
         for Column in First_Column .. Last_Column loop
            Pixel := Vec3_Access.Get (Image, Row, Column);
            for Channel in Vec3.Component_Index loop
               Low (Channel) :=
                 Natural'Min (Low (Channel), Natural (Pixel (Channel)));
               High (Channel) :=
                 Natural'Max (High (Channel), Natural (Pixel (Channel)));
            end loop;
         end loop;
      end loop;
      for Channel in Vec3.Component_Index loop
         Largest := Natural'Max (Largest, High (Channel) - Low (Channel));
      end loop;
      return Largest;
   end Spread;

   --  Semantic posterization oracle for a filtered Fill_Two_Color image:
   --  away from the color boundary, each half stays near its own color and
   --  becomes more uniform than the noisy source. Pyramid propagation copies
   --  upsampled coarse results into unrefined pixels, so the excluded
   --  boundary band grows with the top level (one coarse pixel spans
   --  2 ** Level source columns).
   procedure Assert_Posterized
     (Source, Filtered : OpenCV.Core.Mat;
      Message          : String;
      Level            : Natural := 1)
   is
      Margin     : constant Positive := 4 * 2**Level;
      Half       : constant Natural := Source.Columns / 2;
      Left_Last  : constant Natural := Half - Margin;
      Right_From : constant Natural := Half + Margin;
      Last       : constant Natural := Source.Columns - 1;
   begin
      AUnit.Assertions.Assert
        (Is_UInt8_C3 (Filtered, Source.Rows, Source.Columns),
         Message & ": result must have Source geometry and UInt8 C3 type");
      AUnit.Assertions.Assert
        (Max_Deviation (Filtered, 0, Left_Last, Left_Color) <= 8,
         Message & ": left region must remain near its color");
      AUnit.Assertions.Assert
        (Max_Deviation (Filtered, Right_From, Last, Right_Color) <= 8,
         Message & ": right region must remain near its color");
      AUnit.Assertions.Assert
        (Spread (Filtered, 0, Left_Last) < Spread (Source, 0, Left_Last),
         Message & ": left color spread must decrease");
      AUnit.Assertions.Assert
        (Spread (Filtered, Right_From, Last)
         < Spread (Source, Right_From, Last),
         Message & ": right color spread must decrease");
   end Assert_Posterized;

   procedure Call_Raw
     (Source                : OpenCV.Core.Mat;
      Destination           : in out OpenCV.Core.Mat;
      Spatial_Radius        : OpenCV.Float64_Value;
      Color_Radius          : OpenCV.Float64_Value;
      Maximum_Pyramid_Level : Interfaces.Integer_32;
      Maximum_Iterations    : Interfaces.Integer_32;
      Epsilon               : OpenCV.Float64_Value;
      Status                : out C_API.Status)
   is
      Result_Status : C_API.Status := C_API.Error_Unknown;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Result_Status :=
              C_API.Pyramid_Mean_Shift_Filter
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.C.double (Spatial_Radius),
                 Interfaces.C.double (Color_Radius),
                 Maximum_Pyramid_Level,
                 Maximum_Iterations,
                 Interfaces.C.double (Epsilon));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Status := Result_Status;
   end Call_Raw;

   --  Raw request expected to fail; Destination must stay the placeholder.
   procedure Expect_Raw_Invalid
     (Source                : OpenCV.Core.Mat;
      Spatial_Radius        : OpenCV.Float64_Value;
      Color_Radius          : OpenCV.Float64_Value;
      Maximum_Pyramid_Level : Interfaces.Integer_32;
      Maximum_Iterations    : Interfaces.Integer_32;
      Epsilon               : OpenCV.Float64_Value;
      Fragment, Message     : String)
   is
      Destination : OpenCV.Core.Mat := Placeholder;
      Status      : C_API.Status;
   begin
      Call_Raw
        (Source,
         Destination,
         Spatial_Radius,
         Color_Radius,
         Maximum_Pyramid_Level,
         Maximum_Iterations,
         Epsilon,
         Status);
      Assert_Invalid (Status, Fragment, Message);
      AUnit.Assertions.Assert
        (Is_Placeholder (Destination),
         Message & ": Destination must be unchanged on failure");
   end Expect_Raw_Invalid;

   --  Public request expected to raise; Destination must be unchanged.
   procedure Expect_Public_Rejection
     (Source                : OpenCV.Core.Mat;
      Spatial_Radius        : OpenCV.Float64_Value;
      Color_Radius          : OpenCV.Float64_Value;
      Maximum_Pyramid_Level : IP.Mean_Shift_Pyramid_Level;
      Termination           : IP.Mean_Shift_Termination;
      Message               : String)
   is
      Destination : OpenCV.Core.Mat := Placeholder;
      procedure Attempt is
      begin
         IP.Pyramid_Mean_Shift_Filter
           (Source,
            Destination,
            Spatial_Radius,
            Color_Radius,
            Maximum_Pyramid_Level,
            Termination);
      end Attempt;
   begin
      Assert_Raises (Attempt'Access, Message);
      AUnit.Assertions.Assert
        (Is_Placeholder (Destination),
         Message & ": Destination must be unchanged on failure");
   end Expect_Public_Rejection;

   procedure Default_Pyramid_Posterizes_Two_Color_Image (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat := Two_Color_Image (24, 40);
      Destination : OpenCV.Core.Mat := Placeholder;
   begin
      IP.Pyramid_Mean_Shift_Filter (Source, Destination, 8.0, 30.0);
      Assert_Posterized (Source, Destination, "default level 1");
   end Default_Pyramid_Posterizes_Two_Color_Image;

   procedure Level_Zero_Posterizes_Without_Pyramid (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat := Two_Color_Image (20, 30);
      Destination : OpenCV.Core.Mat;
   begin
      IP.Pyramid_Mean_Shift_Filter
        (Source, Destination, 6.0, 30.0, Maximum_Pyramid_Level => 0);
      Assert_Posterized (Source, Destination, "level 0");
   end Level_Zero_Posterizes_Without_Pyramid;

   procedure Multilevel_Pyramid_Posterizes_Large_Image (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      --  Levels 1 .. 3 are 32 x 48, 16 x 24 and 8 x 12.
      Source      : constant OpenCV.Core.Mat := Two_Color_Image (64, 96);
      Destination : OpenCV.Core.Mat;
   begin
      IP.Pyramid_Mean_Shift_Filter
        (Source, Destination, 16.0, 30.0, Maximum_Pyramid_Level => 3);
      Assert_Posterized (Source, Destination, "level 3", Level => 3);
   end Multilevel_Pyramid_Posterizes_Large_Image;

   procedure Zero_Color_Radius_Preserves_Exact_Colors (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat := Two_Color_Image (16, 24);
      Destination : OpenCV.Core.Mat;
   begin
      --  Only identical colors enter each window, so every mean is the
      --  pixel's own color and level-0 filtering reproduces Source exactly.
      IP.Pyramid_Mean_Shift_Filter
        (Source, Destination, 5.0, 0.0, Maximum_Pyramid_Level => 0);
      AUnit.Assertions.Assert
        (Is_UInt8_C3 (Destination, 16, 24)
         and then Max_Difference (Source, Destination) = 0.0,
         "Color_Radius 0 must preserve every exact-color neighborhood");
   end Zero_Color_Radius_Preserves_Exact_Colors;

   procedure Single_Iteration_Termination_Is_Applied (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source    : constant OpenCV.Core.Mat := Two_Color_Image (20, 30);
      One_Step  : OpenCV.Core.Mat;
      Converged : OpenCV.Core.Mat;
   begin
      IP.Pyramid_Mean_Shift_Filter
        (Source,
         One_Step,
         6.0,
         30.0,
         Maximum_Pyramid_Level => 0,
         Termination           => (Maximum_Iterations => 1, Epsilon => 0.0));
      IP.Pyramid_Mean_Shift_Filter
        (Source,
         Converged,
         6.0,
         30.0,
         Maximum_Pyramid_Level => 0,
         Termination           => (Maximum_Iterations => 100, Epsilon => 0.0));
      Assert_Posterized (Source, One_Step, "one iteration");
      Assert_Posterized (Source, Converged, "100 iterations");
   end Single_Iteration_Termination_Is_Applied;

   procedure Custom_Epsilon_Is_Applied (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Two_Color_Image (20, 30);
      Loose  : OpenCV.Core.Mat;
   begin
      --  A loose tolerance stops after the first shift of every pixel, which
      --  is exactly one iteration.
      IP.Pyramid_Mean_Shift_Filter
        (Source,
         Loose,
         6.0,
         30.0,
         Maximum_Pyramid_Level => 0,
         Termination           =>
           (Maximum_Iterations => 50, Epsilon => 1.0e6));
      declare
         One_Step : OpenCV.Core.Mat;
      begin
         IP.Pyramid_Mean_Shift_Filter
           (Source,
            One_Step,
            6.0,
            30.0,
            Maximum_Pyramid_Level => 0,
            Termination           =>
              (Maximum_Iterations => 1, Epsilon => 0.0));
         AUnit.Assertions.Assert
           (Max_Difference (Loose, One_Step) = 0.0,
            "a huge Epsilon must stop after the first mean-shift step");
      end;
      Assert_Posterized (Source, Loose, "huge epsilon");
   end Custom_Epsilon_Is_Applied;

   procedure Source_Is_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat := Two_Color_Image (24, 40);
      Original    : constant OpenCV.Core.Mat := Source.Clone;
      Destination : OpenCV.Core.Mat;
   begin
      IP.Pyramid_Mean_Shift_Filter (Source, Destination, 8.0, 30.0);
      AUnit.Assertions.Assert
        (Max_Difference (Source, Original) = 0.0,
         "Pyramid_Mean_Shift_Filter must not modify Source");
   end Source_Is_Unchanged;

   procedure Region_Matches_Independent_Clone (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (40, 56, (OpenCV.Core.UInt8, 3));
      Area        : constant OpenCV.Rect :=
        (X => 8, Y => 8, Width => 40, Height => 24);
      View        : OpenCV.Core.Mat := Parent.Region (Area);
      From_View   : OpenCV.Core.Mat;
      From_Clone  : OpenCV.Core.Mat;
      Parent_Copy : OpenCV.Core.Mat;
   begin
      --  Distinctive parent color outside the Region: pure magenta.
      OpenCV.Core.Set_To (Parent, (255.0, 0.0, 255.0, 0.0));
      Fill_Two_Color (View);
      Parent_Copy := Parent.Clone;
      IP.Pyramid_Mean_Shift_Filter
        (View, From_View, 10.0, 40.0, Maximum_Pyramid_Level => 2);
      IP.Pyramid_Mean_Shift_Filter
        (View.Clone, From_Clone, 10.0, 40.0, Maximum_Pyramid_Level => 2);
      AUnit.Assertions.Assert
        (Is_UInt8_C3 (From_View, 24, 40)
         and then Max_Difference (From_View, From_Clone) = 0.0,
         "a Region must filter exactly like an independent clone");
      Assert_Posterized (View, From_View, "Region", Level => 2);
      AUnit.Assertions.Assert
        (Max_Difference (Parent, Parent_Copy) = 0.0,
         "filtering a Region must not modify its parent");
   end Region_Matches_Independent_Clone;

   procedure Region_Excludes_Parent_Pixels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (20, 20, (OpenCV.Core.UInt8, 3));
      View        : OpenCV.Core.Mat :=
        Parent.Region ((X => 6, Y => 6, Width => 8, Height => 8));
      Destination : OpenCV.Core.Mat;
   begin
      --  A uniform Region inside a white parent. A huge color radius would
      --  pull any parent pixel into every window, and the pyramid would blur
      --  it in, but the logical image contains only one color.
      OpenCV.Core.Set_To (Parent, (255.0, 255.0, 255.0, 0.0));
      OpenCV.Core.Set_To (View, (10.0, 20.0, 30.0, 0.0));
      IP.Pyramid_Mean_Shift_Filter
        (View, Destination, 20.0, 1000.0, Maximum_Pyramid_Level => 2);
      AUnit.Assertions.Assert
        (Is_UInt8_C3 (Destination, 8, 8),
         "Region result must have Region geometry");
      for Row in 0 .. 7 loop
         for Column in 0 .. 7 loop
            AUnit.Assertions.Assert
              (Vec3_Access.Get (Destination, Row, Column) = (10, 20, 30),
               "parent pixels outside a Region must never influence output");
         end loop;
      end loop;
   end Region_Excludes_Parent_Pixels;

   procedure Aliased_Destination_Matches_Distinct (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image    : OpenCV.Core.Mat := Two_Color_Image (24, 40);
      Expected : OpenCV.Core.Mat;
      Parent   : constant OpenCV.Core.Mat := Two_Color_Image (24, 40);
      Left     : constant OpenCV.Core.Mat :=
        Parent.Region ((X => 0, Y => 0, Width => 30, Height => 24));
      Right    : OpenCV.Core.Mat :=
        Parent.Region ((X => 4, Y => 0, Width => 30, Height => 24));
      Overlap  : OpenCV.Core.Mat;
   begin
      IP.Pyramid_Mean_Shift_Filter (Image, Expected, 8.0, 30.0);
      IP.Pyramid_Mean_Shift_Filter (Image, Image, 8.0, 30.0);
      AUnit.Assertions.Assert
        (Max_Difference (Image, Expected) = 0.0,
         "Source used as Destination must equal a distinct Destination");

      --  Overlapping Region views: the Source snapshot is taken before any
      --  result is bound, so the result equals filtering an early clone.
      IP.Pyramid_Mean_Shift_Filter (Left.Clone, Overlap, 8.0, 30.0);
      IP.Pyramid_Mean_Shift_Filter (Left, Right, 8.0, 30.0);
      AUnit.Assertions.Assert
        (Is_UInt8_C3 (Right, 24, 30)
         and then Max_Difference (Right, Overlap) = 0.0,
         "an overlapping Destination view must not alter the logical input");
   end Aliased_Destination_Matches_Distinct;

   procedure Rejects_Invalid_Sources (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty   : OpenCV.Core.Mat;
      UInt16  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt16, 3));
      Gray    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
      BGRA    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 4));
      Three_D : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(4, 4, 4), (OpenCV.Core.UInt8, 3));
   begin
      Expect_Public_Rejection
        (Empty, 5.0, 20.0, 0, Default_Termination, "empty Source");
      Expect_Public_Rejection
        (UInt16, 5.0, 20.0, 0, Default_Termination, "UInt16 Source");
      Expect_Public_Rejection
        (Gray, 5.0, 20.0, 0, Default_Termination, "UInt8 C1 Source");
      Expect_Public_Rejection
        (BGRA, 5.0, 20.0, 0, Default_Termination, "UInt8 C4 Source");
      Expect_Public_Rejection
        (Three_D, 5.0, 20.0, 0, Default_Termination, "N-D Source");
   end Rejects_Invalid_Sources;

   procedure Rejects_Invalid_Radii_And_Epsilon (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Two_Color_Image (8, 8);
   begin
      Expect_Public_Rejection
        (Source, 0.0, 20.0, 0, Default_Termination, "zero spatial radius");
      Expect_Public_Rejection
        (Source, -2.0, 20.0, 0, Default_Termination, "negative spatial");
      Expect_Public_Rejection
        (Source, NaN_Value, 20.0, 0, Default_Termination, "NaN spatial");
      Expect_Public_Rejection
        (Source, Infinity_Value, 20.0, 0, Default_Termination, "Inf spatial");
      Expect_Public_Rejection
        (Source, 5.0, -1.0, 0, Default_Termination, "negative color radius");
      Expect_Public_Rejection
        (Source, 5.0, NaN_Value, 0, Default_Termination, "NaN color radius");
      Expect_Public_Rejection
        (Source, 5.0, -Infinity_Value, 0, Default_Termination, "-Inf color");
      Expect_Public_Rejection
        (Source,
         5.0,
         20.0,
         0,
         (Maximum_Iterations => 5, Epsilon => -0.5),
         "negative epsilon");
      Expect_Public_Rejection
        (Source,
         5.0,
         20.0,
         0,
         (Maximum_Iterations => 5, Epsilon => NaN_Value),
         "NaN epsilon");
   end Rejects_Invalid_Radii_And_Epsilon;

   procedure Rejects_Tiny_Generated_Pyramid_Levels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Two_By_Two : constant OpenCV.Core.Mat := Two_Color_Image (2, 2);
      Narrow     : constant OpenCV.Core.Mat := Two_Color_Image (40, 3);
      Wide       : constant OpenCV.Core.Mat := Two_Color_Image (3, 40);
      Four_Wide  : constant OpenCV.Core.Mat := Two_Color_Image (4, 40);
      Accepted   : OpenCV.Core.Mat;
   begin
      --  2 x 2 -> 1 x 1 child.
      Expect_Public_Rejection
        (Two_By_Two, 2.0, 20.0, 1, Default_Termination, "1 x 1 child");
      Expect_Raw_Invalid
        (Two_By_Two, 2.0, 20.0, 1, 5, 1.0, "2 x 2", "raw 1 x 1 child");
      --  40 x 3 -> 20 x 2 -> 10 x 1: one column at level 2.
      Expect_Public_Rejection
        (Narrow, 4.0, 20.0, 2, Default_Termination, "one-column level");
      Expect_Raw_Invalid
        (Narrow, 4.0, 20.0, 2, 5, 1.0, "2 x 2", "raw one-column level");
      --  3 rows -> 2 -> 1: one row at level 2.
      Expect_Public_Rejection
        (Wide, 4.0, 20.0, 2, Default_Termination, "one-row level");
      Expect_Raw_Invalid
        (Wide, 4.0, 20.0, 2, 5, 1.0, "2 x 2", "raw one-row level");
      --  Level 0 has no restriction; top level 2 x 2 is still accepted.
      IP.Pyramid_Mean_Shift_Filter
        (Two_By_Two, Accepted, 2.0, 20.0, Maximum_Pyramid_Level => 0);
      AUnit.Assertions.Assert
        (Is_UInt8_C3 (Accepted, 2, 2), "2 x 2 at level 0 must succeed");
      IP.Pyramid_Mean_Shift_Filter
        (Narrow, Accepted, 4.0, 20.0, Maximum_Pyramid_Level => 1);
      AUnit.Assertions.Assert
        (Is_UInt8_C3 (Accepted, 40, 3), "a 20 x 2 top level must succeed");
      IP.Pyramid_Mean_Shift_Filter
        (Four_Wide, Accepted, 4.0, 20.0, Maximum_Pyramid_Level => 1);
      AUnit.Assertions.Assert
        (Is_UInt8_C3 (Accepted, 4, 40), "a 2 x 20 top level must succeed");
   end Rejects_Tiny_Generated_Pyramid_Levels;

   procedure Raw_ABI_Rejects_Malformed_Requests (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Two_Color_Image (16, 16);
      Gray   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (16, 16, (OpenCV.Core.UInt8, 1));
      Status : C_API.Status;
   begin
      Expect_Raw_Invalid
        (Source, 4.0, 20.0, -1, 5, 1.0, "0 .. 8", "maximum level -1");
      Expect_Raw_Invalid
        (Source, 4.0, 20.0, 9, 5, 1.0, "0 .. 8", "maximum level 9");
      Expect_Raw_Invalid
        (Source,
         4.0,
         20.0,
         Interfaces.Integer_32'Last,
         5,
         1.0,
         "0 .. 8",
         "maximum level INT_MAX");
      Expect_Raw_Invalid
        (Source, 4.0, 20.0, 1, 0, 1.0, "1 .. 100", "iteration count 0");
      Expect_Raw_Invalid
        (Source, 4.0, 20.0, 1, 101, 1.0, "1 .. 100", "iteration count 101");
      Expect_Raw_Invalid
        (Source, 4.0, 20.0, 1, 5, -1.0, "epsilon", "negative raw epsilon");
      Expect_Raw_Invalid
        (Source, 4.0, 20.0, 1, 5, NaN_Value, "epsilon", "NaN raw epsilon");
      Expect_Raw_Invalid
        (Source, 4.0, NaN_Value, 1, 5, 1.0, "color", "NaN raw color radius");
      --  1.0e5 ** 2 = 1.0e10 cannot be rounded into a signed int.
      Expect_Raw_Invalid
        (Source, 4.0, 1.0e5, 1, 5, 1.0, "squared color", "huge color radius");
      Expect_Raw_Invalid
        (Source,
         4.0,
         1.0e200,
         1,
         5,
         1.0,
         "squared color",
         "color radius whose square overflows Float64");
      Expect_Raw_Invalid
        (Source,
         1.0e10,
         20.0,
         1,
         5,
         1.0,
         "spatial",
         "huge spatial radius overflows x +/- sp rounding");
      Expect_Raw_Invalid
        (Source,
         Infinity_Value,
         20.0,
         0,
         5,
         1.0,
         "spatial",
         "infinite raw spatial radius");
      Expect_Raw_Invalid
        (Gray, 4.0, 20.0, 0, 5, 1.0, "CV_8UC3", "raw UInt8 C1 source");

      Status :=
        Raw_Mean_Shift
          (System.Null_Address, System.Null_Address, 4.0, 20.0, 0, 5, 1.0);
      Assert_Invalid (Status, "source", "null raw handles must be rejected");
   end Raw_ABI_Rejects_Malformed_Requests;

   procedure Wide_Window_Coordinate_Sum_Is_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  About 300 KB. A window spanning the whole row sums x coordinates
      --  0 .. 99_999, roughly 5.0e9, which overflows native signed int sx.
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 100_000, (OpenCV.Core.UInt8, 3));
   begin
      OpenCV.Core.Set_To (Source, (50.0, 60.0, 70.0, 0.0));
      Expect_Public_Rejection
        (Source,
         100_000.0,
         20.0,
         0,
         Default_Termination,
         "public whole-row window accumulator");
      Expect_Raw_Invalid
        (Source,
         100_000.0,
         20.0,
         0,
         5,
         1.0,
         "accumulator",
         "raw whole-row window accumulator");
   end Wide_Window_Coordinate_Sum_Is_Rejected;

   procedure Valid_Request_Succeeds_After_Rejections (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat := Two_Color_Image (24, 40);
      Destination : OpenCV.Core.Mat := Placeholder;
      Status      : C_API.Status;
   begin
      Expect_Raw_Invalid
        (Source, 4.0, 1.0e5, 1, 5, 1.0, "squared color", "pre-recovery");
      Expect_Public_Rejection
        (Source, 0.0, 20.0, 1, Default_Termination, "pre-recovery public");
      Call_Raw (Source, Destination, 8.0, 30.0, 1, 5, 1.0, Status);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then C_API.Last_Error_Message = "",
         "a valid raw request must succeed with a cleared diagnostic");
      Assert_Posterized (Source, Destination, "raw recovery");
      Destination := Placeholder;
      IP.Pyramid_Mean_Shift_Filter (Source, Destination, 8.0, 30.0);
      Assert_Posterized (Source, Destination, "public recovery");
   end Valid_Request_Succeeds_After_Rejections;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Mean shift default pyramid posterizes a noisy two-color image",
            Default_Pyramid_Posterizes_Two_Color_Image'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift level 0 posterizes without a pyramid",
            Level_Zero_Posterizes_Without_Pyramid'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift multilevel pyramid posterizes a large image",
            Multilevel_Pyramid_Posterizes_Large_Image'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift Color_Radius 0 preserves exact-color neighborhoods",
            Zero_Color_Radius_Preserves_Exact_Colors'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift applies custom Maximum_Iterations",
            Single_Iteration_Termination_Is_Applied'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift applies custom Epsilon",
            Custom_Epsilon_Is_Applied'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift leaves Source unchanged", Source_Is_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift Region matches an independent clone",
            Region_Matches_Independent_Clone'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift Region excludes parent pixels",
            Region_Excludes_Parent_Pixels'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift aliased and overlapping Destination use the snapshot",
            Aliased_Destination_Matches_Distinct'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift rejects invalid Sources",
            Rejects_Invalid_Sources'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift rejects invalid radii and Epsilon",
            Rejects_Invalid_Radii_And_Epsilon'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift rejects generated pyramid levels below 2 x 2",
            Rejects_Tiny_Generated_Pyramid_Levels'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift C ABI rejects malformed requests",
            Raw_ABI_Rejects_Malformed_Requests'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift rejects signed-int window coordinate overflow",
            Wide_Window_Coordinate_Sum_Is_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Mean shift valid request succeeds after rejections",
            Valid_Request_Succeeds_After_Rejections'Access));
      return Result'Access;
   end Suite;

end Mean_Shift_Tests;
