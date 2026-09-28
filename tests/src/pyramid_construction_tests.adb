with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Pyramid_Construction_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Float32_Value;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;

   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;
   use type C_API.Pyramid_Handle;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   type Index_List is array (Positive range <>) of Interfaces.Integer_32;

   All_Borders : constant array (1 .. 4) of OpenCV.Border_Kind :=
     (OpenCV.Replicate, OpenCV.Reflect, OpenCV.Reflect_101, OpenCV.Wrap);

   --  Raw import taking an arbitrary address so a null source handle can be
   --  passed across the C ABI.
   function Raw_Build_Pyramid
     (Source      : System.Address;
      Level_Count : Interfaces.Integer_32;
      Border      : Interfaces.Integer_32;
      Result      : access C_API.Pyramid_Handle) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_build_pyramid";

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

   function Has_Size
     (Image : OpenCV.Core.Mat; Rows, Columns : Natural) return Boolean
   is (Image.Rows = Rows and then Image.Columns = Columns);

   function Random_Mat
     (Rows, Columns : Natural;
      Depth         : OpenCV.Core.Depth_Type;
      Channels      : OpenCV.Core.Channel_Count := 1;
      Seed          : Interfaces.Integer_32 := 7) return OpenCV.Core.Mat
   is
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Columns, (Depth, Channels));
   begin
      OpenCV.Core.Set_Random_Seed (Seed);
      OpenCV.Core.Fill_Uniform (Image, (others => 0.0), (others => 255.0));
      return Image;
   end Random_Mat;

   --  Expected Gaussian chain built with repeated single-level Pyramid_Down.
   function Repeated_Down
     (Source      : OpenCV.Core.Mat;
      Level_Count : Positive;
      Border      : OpenCV.Border_Kind) return OpenCV.Core.Mat_Array
   is
      Levels : OpenCV.Core.Mat_Array (0 .. Level_Count - 1);
   begin
      Levels (0) := Source.Clone;
      for Index in 1 .. Levels'Last loop
         IP.Pyramid_Down (Levels (Index - 1), Levels (Index), Border);
      end loop;
      return Levels;
   end Repeated_Down;

   procedure Assert_Same_Levels
     (Actual, Expected : OpenCV.Core.Mat_Array;
      Tolerance        : Long_Float;
      Message          : String) is
   begin
      AUnit.Assertions.Assert
        (Actual'Length = Expected'Length, Message & ": level count");
      for Offset in 0 .. Actual'Length - 1 loop
         AUnit.Assertions.Assert
           (Max_Difference
              (Actual (Actual'First + Offset),
               Expected (Expected'First + Offset))
            <= Tolerance,
            Message & ": level" & Offset'Image);
      end loop;
   end Assert_Same_Levels;

   procedure Gaussian_Single_Level_Is_Independent_Clone (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Source, (others => 50.0));
      declare
         Levels : OpenCV.Core.Mat_Array :=
           IP.Build_Gaussian_Pyramid (Source, 1);
      begin
         AUnit.Assertions.Assert
           (Levels'First = 0 and then Levels'Last = 0,
            "Level_Count 1 must return exactly level 0");
         AUnit.Assertions.Assert
           (Has_Size (Levels (0), 3, 4)
            and then Levels (0).Depth = OpenCV.Core.UInt8
            and then Levels (0).Channels = 1
            and then Max_Difference (Levels (0), Source) = 0.0,
            "level 0 must equal Source");
         OpenCV.Core.Set_To (Source, (others => 9.0));
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Levels (0), 1, 1) = 50,
            "mutating Source must not change level 0");
         OpenCV.Core.Set_To (Levels (0), (others => 200.0));
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Source, 1, 1) = 9,
            "mutating level 0 must not change Source");
      end;
   end Gaussian_Single_Level_Is_Independent_Clone;

   procedure Gaussian_Geometry_And_Maximum_Levels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      type Geometry is record
         Rows, Columns, Levels : Positive;
      end record;
      --  Rows x Columns; the 9 x 7 example is Width 9, Height 7.
      Cases : constant array (1 .. 7) of Geometry :=
        ((1, 1, 1),
         (2, 2, 2),
         (3, 3, 3),
         (8, 8, 4),
         (7, 9, 5),
         (1, 16, 5),
         (1_000, 3, 11));
   begin
      for Item of Cases loop
         declare
            Source  : constant OpenCV.Core.Mat :=
              Random_Mat (Item.Rows, Item.Columns, OpenCV.Core.Float32);
            Maximum : constant Positive :=
              IP.Maximum_Pyramid_Level_Count (Source);
            Levels  : constant OpenCV.Core.Mat_Array :=
              IP.Build_Gaussian_Pyramid (Source, Maximum);
            Rows    : Natural := Item.Rows;
            Columns : Natural := Item.Columns;
            Label   : constant String :=
              Item.Rows'Image & " x" & Item.Columns'Image;
         begin
            AUnit.Assertions.Assert
              (Maximum = Item.Levels, "maximum level count for" & Label);
            AUnit.Assertions.Assert
              (Levels'First = 0 and then Levels'Last = Maximum - 1,
               "Gaussian range must be 0 .. Level_Count - 1 for" & Label);
            for Level of Levels loop
               AUnit.Assertions.Assert
                 (Has_Size (Level, Rows, Columns),
                  "natural ceil-half geometry for" & Label);
               Rows := (Rows + 1) / 2;
               Columns := (Columns + 1) / 2;
            end loop;
            AUnit.Assertions.Assert
              (Has_Size (Levels (Levels'Last), 1, 1),
               "the maximal pyramid must end at exactly 1 x 1 for" & Label);
         end;
      end loop;

      --  Even 16x12 -> 8x6 -> 4x3; odd 9x7 -> 5x4 -> 3x2 -> 2x1 -> 1x1.
      declare
         Even : constant OpenCV.Core.Mat_Array :=
           IP.Build_Gaussian_Pyramid
             (Random_Mat (12, 16, OpenCV.Core.UInt8), 3);
         Odd  : constant OpenCV.Core.Mat_Array :=
           IP.Build_Gaussian_Pyramid (Random_Mat (7, 9, OpenCV.Core.UInt8), 5);
      begin
         AUnit.Assertions.Assert
           (Has_Size (Even (1), 6, 8) and then Has_Size (Even (2), 3, 4),
            "even 16 x 12 chain must halve exactly");
         AUnit.Assertions.Assert
           (Has_Size (Odd (1), 4, 5)
            and then Has_Size (Odd (2), 2, 3)
            and then Has_Size (Odd (3), 1, 2)
            and then Has_Size (Odd (4), 1, 1),
            "odd 9 x 7 chain must follow natural geometry");
      end;
   end Gaussian_Geometry_And_Maximum_Levels;

   procedure Gaussian_Matches_Repeated_Pyramid_Down (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat :=
        Random_Mat (10, 13, OpenCV.Core.UInt8);
   begin
      for Border of All_Borders loop
         Assert_Same_Levels
           (IP.Build_Gaussian_Pyramid (Source, 4, Border),
            Repeated_Down (Source, 4, Border),
            0.0,
            "Gaussian build must equal repeated Pyramid_Down for "
            & Border'Image);
      end loop;
      Assert_Same_Levels
        (IP.Build_Gaussian_Pyramid (Source, 5),
         Repeated_Down (Source, 5, OpenCV.Reflect_101),
         0.0,
         "the default border must be Reflect_101");
   end Gaussian_Matches_Repeated_Pyramid_Down;

   procedure Gaussian_Depths_And_Channels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Depths : constant array (1 .. 5) of OpenCV.Core.Depth_Type :=
        (OpenCV.Core.UInt8,
         OpenCV.Core.UInt16,
         OpenCV.Core.Int16,
         OpenCV.Core.Float32,
         OpenCV.Core.Float64);
   begin
      for Depth of Depths loop
         for Channels in OpenCV.Core.Channel_Count range 1 .. 4 loop
            declare
               Source : constant OpenCV.Core.Mat :=
                 Random_Mat (9, 11, Depth, Channels);
               Levels : constant OpenCV.Core.Mat_Array :=
                 IP.Build_Gaussian_Pyramid (Source, 3);
            begin
               for Level of Levels loop
                  AUnit.Assertions.Assert
                    (Level.Depth = Depth and then Level.Channels = Channels,
                     "Gaussian levels must preserve "
                     & Depth'Image
                     & " C"
                     & Channels'Image);
               end loop;
               Assert_Same_Levels
                 (Levels,
                  Repeated_Down (Source, 3, OpenCV.Reflect_101),
                  0.0,
                  "Gaussian values for " & Depth'Image & Channels'Image);
            end;
         end loop;
      end loop;
   end Gaussian_Depths_And_Channels;

   procedure Gaussian_Region_Matches_Independent_Clone (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      procedure Check
        (Element_Type : OpenCV.Core.Mat_Type; Parent_Value : Long_Float)
      is
         Parent : OpenCV.Core.Mat := OpenCV.Core.Create (24, 24, Element_Type);
         Source : OpenCV.Core.Mat :=
           Parent.Region ((X => 3, Y => 5, Width => 13, Height => 9));
         Owning : OpenCV.Core.Mat;
      begin
         OpenCV.Core.Set_To (Parent, (others => Parent_Value));
         OpenCV.Core.Set_Random_Seed (11);
         OpenCV.Core.Fill_Uniform (Source, (others => 0.0), (others => 100.0));
         Owning := Source.Clone;
         for Border of All_Borders loop
            declare
               From_Region : OpenCV.Core.Mat_Array :=
                 IP.Build_Gaussian_Pyramid (Source, 5, Border);
            begin
               Assert_Same_Levels
                 (From_Region,
                  IP.Build_Gaussian_Pyramid (Owning, 5, Border),
                  0.0,
                  "Region Gaussian must match an independent clone for "
                  & Border'Image);
               OpenCV.Core.Set_To (From_Region (0), (others => 1.0));
               AUnit.Assertions.Assert
                 (Max_Difference (Source, Owning) = 0.0,
                  "Region level 0 must not share Source storage");
            end;
         end loop;
         AUnit.Assertions.Assert
           (OpenCV.Core.Norm
              (Parent.Region ((X => 0, Y => 0, Width => 24, Height => 5)),
               OpenCV.Core.Infinity)
            = Parent_Value,
            "parent pixels outside the Region must be preserved");
      end Check;
   begin
      Check ((OpenCV.Core.UInt8, 1), 250.0);
      Check ((OpenCV.Core.Float32, 3), 5_000.0);
   end Gaussian_Region_Matches_Independent_Clone;

   procedure Gaussian_Levels_Own_Storage (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Source, (others => 100.0));
      declare
         Levels : OpenCV.Core.Mat_Array :=
           IP.Build_Gaussian_Pyramid (Source, 3);
      begin
         OpenCV.Core.Set_To (Source, (others => 1.0));
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Levels (0), 0, 0) = 100,
            "Source mutation after the build must not change level 0");
         OpenCV.Core.Set_To (Levels (0), (others => 7.0));
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 1
            and then OpenCV.Core.UInt8_Access.Get (Levels (1), 0, 0) = 100,
            "mutating level 0 must change neither Source nor level 1");
         OpenCV.Core.Set_To (Levels (1), (others => 42.0));
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Levels (2), 0, 0) = 100
            and then OpenCV.Core.UInt8_Access.Get (Levels (0), 0, 0) = 7,
            "mutating one Gaussian level must not alter another level");
      end;
   end Gaussian_Levels_Own_Storage;

   procedure Pyramid_Construction_Rejects_Invalid_Inputs
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Eight  : constant OpenCV.Core.Mat :=
        Random_Mat (8, 8, OpenCV.Core.UInt8);
      Int32  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.Int32, 1));
      Empty  : OpenCV.Core.Mat;
      Three  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Ignore : Natural := 0;

      procedure Build
        (Source : OpenCV.Core.Mat;
         Count  : Positive;
         Border : OpenCV.Border_Kind := OpenCV.Reflect_101) is
      begin
         Ignore := IP.Build_Gaussian_Pyramid (Source, Count, Border)'Length;
      end Build;

      procedure Build_Laplacian
        (Source : OpenCV.Core.Mat;
         Count  : Positive;
         Border : OpenCV.Border_Kind := OpenCV.Reflect_101) is
      begin
         Ignore := IP.Build_Laplacian_Pyramid (Source, Count, Border)'Length;
      end Build_Laplacian;

      procedure Too_Many is
      begin
         Build (Eight, 5);
      end Too_Many;

      procedure Far_Too_Many is
      begin
         Build (Eight, Positive'Last);
      end Far_Too_Many;

      procedure Constant_Border is
      begin
         Build (Eight, 2, OpenCV.Constant_Border);
      end Constant_Border;

      procedure Empty_Source is
      begin
         Build (Empty, 1);
      end Empty_Source;

      procedure Int32_Source is
      begin
         Build (Int32, 2);
      end Int32_Source;

      procedure Three_D_Source is
      begin
         Build (Three, 1);
      end Three_D_Source;

      procedure Maximum_Of_Empty is
      begin
         Ignore := IP.Maximum_Pyramid_Level_Count (Empty);
      end Maximum_Of_Empty;

      procedure Laplacian_Too_Many is
      begin
         Build_Laplacian (Eight, 5);
      end Laplacian_Too_Many;

      procedure Laplacian_Constant is
      begin
         Build_Laplacian (Eight, 2, OpenCV.Constant_Border);
      end Laplacian_Constant;

      procedure Laplacian_Int32 is
      begin
         Build_Laplacian (Int32, 2);
      end Laplacian_Int32;
   begin
      Assert_Raises
        (Too_Many'Access, "Level_Count above the distinct maximum fails");
      Assert_Raises
        (Far_Too_Many'Access, "Positive'Last Level_Count must be rejected");
      Assert_Raises (Constant_Border'Access, "Constant_Border is rejected");
      Assert_Raises (Empty_Source'Access, "an empty Source is rejected");
      Assert_Raises (Int32_Source'Access, "an Int32 Source is rejected");
      Assert_Raises (Three_D_Source'Access, "a 3-D Source is rejected");
      Assert_Raises
        (Maximum_Of_Empty'Access, "Maximum_Pyramid_Level_Count needs a Mat");
      Assert_Raises
        (Laplacian_Too_Many'Access, "Laplacian Level_Count is bounded");
      Assert_Raises
        (Laplacian_Constant'Access, "Laplacian Constant_Border is rejected");
      Assert_Raises
        (Laplacian_Int32'Access, "Laplacian Int32 Source is rejected");
   end Pyramid_Construction_Rejects_Invalid_Inputs;

   procedure Sized_Pyramid_Up_Reverses_Odd_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Nine  : constant OpenCV.Core.Mat := Random_Mat (9, 9, OpenCV.Core.UInt8);
      Seven : constant OpenCV.Core.Mat :=
        Random_Mat (7, 7, OpenCV.Core.Float32, 3);
      Down  : OpenCV.Core.Mat;
      Up    : OpenCV.Core.Mat;
      Plain : OpenCV.Core.Mat;
   begin
      IP.Pyramid_Down (Nine, Down);
      AUnit.Assertions.Assert (Has_Size (Down, 5, 5), "9 -> 5");
      IP.Pyramid_Up (Down, Up, Output_Size => (Width => 9, Height => 9));
      AUnit.Assertions.Assert
        (Has_Size (Up, 9, 9)
         and then Up.Depth = OpenCV.Core.UInt8
         and then Up.Channels = 1,
         "sized Pyramid_Up must reconstruct 9 from 5");

      IP.Pyramid_Down (Seven, Down);
      AUnit.Assertions.Assert (Has_Size (Down, 4, 4), "7 -> 4");
      IP.Pyramid_Up (Down, Up, Output_Size => (Width => 7, Height => 7));
      AUnit.Assertions.Assert
        (Has_Size (Up, 7, 7)
         and then Up.Depth = OpenCV.Core.Float32
         and then Up.Channels = 3,
         "sized Pyramid_Up must reconstruct 7 from 4 with C3");

      --  Mixed extents, and the exact-double size equals the natural call.
      IP.Pyramid_Up (Down, Up, Output_Size => (Width => 8, Height => 7));
      AUnit.Assertions.Assert (Has_Size (Up, 7, 8), "mixed 8 x 7 target");
      IP.Pyramid_Up (Down, Up, Output_Size => (Width => 8, Height => 8));
      IP.Pyramid_Up (Down, Plain);
      AUnit.Assertions.Assert
        (Max_Difference (Up, Plain) = 0.0,
         "explicit 2x size must equal the natural Pyramid_Up");
   end Sized_Pyramid_Up_Reverses_Odd_Geometry;

   procedure Sized_Pyramid_Up_Rejects_Illegal_Geometry (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat :=
        Random_Mat (4, 5, OpenCV.Core.Float32);
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Target      : OpenCV.Size;

      procedure Attempt is
      begin
         IP.Pyramid_Up (Source, Destination, Target);
      end Attempt;

      procedure Check (Width, Height : OpenCV.Size_Coordinate) is
      begin
         Target := (Width => Width, Height => Height);
         Assert_Raises
           (Attempt'Access,
            "illegal explicit size" & Width'Image & Height'Image);
         AUnit.Assertions.Assert
           (Has_Size (Destination, 2, 3)
            and then Destination.Depth = OpenCV.Core.UInt8,
            "rejected sized Pyramid_Up must leave Destination unchanged");
      end Check;
   begin
      --  Source is 5 wide x 4 high: legal widths 9/10, heights 7/8.
      Check (11, 8);
      Check (8, 8);
      Check (10, 9);
      Check (10, 6);
      Check (0, 0);
      Check (OpenCV.Size_Coordinate'Last, 8);
   end Sized_Pyramid_Up_Rejects_Illegal_Geometry;

   procedure Raw_Pyramid_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat :=
        Random_Mat (8, 8, OpenCV.Core.UInt8);
      Handle : aliased C_API.Pyramid_Handle := C_API.Null_Pyramid_Handle;
      Count  : aliased Interfaces.Integer_32 := -1;
      Status : C_API.Status := C_API.Success;
      Levels : Interfaces.Integer_32 := 1;
      Border : Interfaces.Integer_32 := C_API.Border_Reflect_101;

      procedure Build (Handle_In : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Status :=
           C_API.Build_Pyramid (Handle_In, Levels, Border, Handle'Access);
      end Build;

      procedure Expect_Build (Fragment, Message : String) is
      begin
         Handle := C_API.Null_Pyramid_Handle;
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Build'Access);
         Assert_Invalid (Status, Fragment, Message);
         AUnit.Assertions.Assert
           (Handle = C_API.Null_Pyramid_Handle,
            Message & ": the result handle must be null on failure");
         Levels := 1;
         Border := C_API.Border_Reflect_101;
      end Expect_Build;

      procedure Sized_Up (Width, Height : Interfaces.Integer_32) is
         Destination : OpenCV.Core.Mat :=
           OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Pyramid_Up_Sized (Source_Handle, Target, Width, Height);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
         Assert_Invalid
           (Status,
            "explicit size",
            "raw sized pyrUp must reject" & Width'Image & Height'Image);
         AUnit.Assertions.Assert
           (Has_Size (Destination, 1, 1)
            and then Destination.Depth = OpenCV.Core.UInt16,
            "raw sized pyrUp failure must leave destination unchanged");
      end Sized_Up;
   begin
      --  Raw invalid sized-up geometry, including the native-accepted but
      --  uninitialized-column 2s + 1 case and signed extremes.
      Sized_Up (17, 16);
      Sized_Up (16, 14);
      Sized_Up (0, 16);
      Sized_Up (-15, 16);
      Sized_Up (Interfaces.Integer_32'Last, 16);
      Sized_Up (16, Interfaces.Integer_32'First);

      --  Raw invalid Gaussian level counts.
      Levels := 0;
      Expect_Build ("level count", "a zero level count must be rejected");
      Levels := -3;
      Expect_Build ("level count", "a negative level count must be rejected");
      Levels := 5;
      Expect_Build ("level count", "8 x 8 has only four distinct levels");
      Levels := Interfaces.Integer_32'Last;
      Expect_Build ("level count", "INT_MAX levels must be rejected");
      Border := C_API.Border_Constant;
      Expect_Build ("Constant_Border", "Constant border must be rejected");
      Border := 99;
      Expect_Build ("border", "an unknown border must be rejected");

      --  Null source, null result pointer, null handles.
      Status :=
        Raw_Build_Pyramid
          (System.Null_Address, 1, C_API.Border_Reflect_101, Handle'Access);
      Assert_Invalid (Status, "source", "a null source must be rejected");
      Status :=
        Raw_Build_Pyramid
          (System.Null_Address, 1, C_API.Border_Reflect_101, null);
      Assert_Invalid
        (Status, "output pointer", "a null result pointer must be rejected");
      Assert_Invalid
        (C_API.Pyramid_Count (C_API.Null_Pyramid_Handle, Count'Access),
         "arguments",
         "counting a null pyramid must be rejected");
      declare
         Destination : OpenCV.Core.Mat;
         procedure Copy (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              C_API.Pyramid_Copy_Level (C_API.Null_Pyramid_Handle, 0, Target);
         end Copy;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Copy'Access);
         Assert_Invalid
           (Status, "result", "copying from a null pyramid must be rejected");
         AUnit.Assertions.Assert
           (Destination.Is_Empty, "a failed copy must not bind a level");
      end;
      C_API.Pyramid_Destroy (C_API.Null_Pyramid_Handle);

      --  After those failures, a raw build and copies succeed.
      Levels := 4;
      Handle := C_API.Null_Pyramid_Handle;
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Build'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Handle /= C_API.Null_Pyramid_Handle,
         "a raw build must succeed after prior failures");
      Status := C_API.Pyramid_Count (Handle, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 4,
         "the raw result must report four levels");
      Assert_Invalid
        (C_API.Pyramid_Count (Handle, null),
         "arguments",
         "a null count output must be rejected");
      declare
         Expected : constant OpenCV.Core.Mat_Array :=
           Repeated_Down (Source, 4, OpenCV.Reflect_101);
         Copies   : OpenCV.Core.Mat_Array (0 .. 3);
         Outside  : OpenCV.Core.Mat :=
           OpenCV.Core.Create (1, 1, (OpenCV.Core.Int16, 1));
         Index    : Interfaces.Integer_32 := 0;

         procedure Copy (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status := C_API.Pyramid_Copy_Level (Handle, Index, Target);
         end Copy;
      begin
         for Bad of Index_List'(4, -1, Interfaces.Integer_32'Last) loop
            Index := Bad;
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Outside, Copy'Access);
            Assert_Invalid
              (Status, "out of range", "out-of-range index" & Bad'Image);
            AUnit.Assertions.Assert
              (Outside.Depth = OpenCV.Core.Int16,
               "a failed copy must leave its destination unchanged");
         end loop;
         for Level in Copies'Range loop
            Index := Interfaces.Integer_32 (Level);
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Copies (Level), Copy'Access);
            AUnit.Assertions.Assert
              (Status = C_API.Success
               and then Max_Difference (Copies (Level), Expected (Level))
                        = 0.0,
               "raw copy must publish level" & Level'Image);
         end loop;
         C_API.Pyramid_Destroy (Handle);
         Handle := C_API.Null_Pyramid_Handle;
         --  Copies stay valid and independent after the handle is gone.
         OpenCV.Core.Set_To (Copies (0), (others => 3.0));
         AUnit.Assertions.Assert
           (Max_Difference (Source, Expected (0)) = 0.0
            and then Max_Difference (Copies (1), Expected (1)) = 0.0,
            "copied levels must outlive the native result independently");
      end;
   end Raw_Pyramid_ABI_Validation;

   procedure Assert_Reconstructs
     (Source    : OpenCV.Core.Mat;
      Levels    : Positive;
      Precision : IP.Laplacian_Precision;
      Depth     : OpenCV.Core.Depth_Type;
      Tolerance : Long_Float;
      Label     : String)
   is
      Pyramid : constant OpenCV.Core.Mat_Array :=
        IP.Build_Laplacian_Pyramid
          (Source, Levels, OpenCV.Reflect_101, Precision);
      Rebuilt : constant OpenCV.Core.Mat :=
        IP.Reconstruct_Laplacian_Pyramid (Pyramid);
      Error   : constant Long_Float :=
        Max_Difference (Rebuilt, Source.Convert_To (Depth));
   begin
      AUnit.Assertions.Assert
        (Pyramid'First = 0 and then Pyramid'Last = Levels - 1,
         Label & ": Laplacian range must be 0 .. Level_Count - 1");
      for Level of Pyramid loop
         AUnit.Assertions.Assert
           (Level.Depth = Depth and then Level.Channels = Source.Channels,
            Label & ": every level must have the working depth/channels");
      end loop;
      AUnit.Assertions.Assert
        (Rebuilt.Depth = Depth
         and then Has_Size (Rebuilt, Source.Rows, Source.Columns)
         and then Rebuilt.Channels = Source.Channels,
         Label & ": reconstruction keeps the floating working depth");
      AUnit.Assertions.Assert
        (Error <= Tolerance, Label & ": reconstruction error" & Error'Image);
   end Assert_Reconstructs;

   procedure Laplacian_Precision_Policy (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8   : constant OpenCV.Core.Mat :=
        Random_Mat (12, 10, OpenCV.Core.UInt8);
      Float64 : constant OpenCV.Core.Mat :=
        Random_Mat (12, 10, OpenCV.Core.Float64);
   begin
      Assert_Reconstructs
        (UInt8,
         3,
         IP.Automatic_Precision,
         OpenCV.Core.Float32,
         1.0e-3,
         "automatic UInt8");
      Assert_Reconstructs
        (Random_Mat (12, 10, OpenCV.Core.UInt16),
         3,
         IP.Automatic_Precision,
         OpenCV.Core.Float32,
         1.0e-3,
         "automatic UInt16");
      Assert_Reconstructs
        (Float64,
         3,
         IP.Automatic_Precision,
         OpenCV.Core.Float64,
         1.0e-9,
         "automatic Float64");
      Assert_Reconstructs
        (UInt8,
         3,
         IP.Float64_Precision,
         OpenCV.Core.Float64,
         1.0e-9,
         "explicit Float64 from UInt8");
      Assert_Reconstructs
        (Random_Mat (12, 10, OpenCV.Core.Int16),
         3,
         IP.Float64_Precision,
         OpenCV.Core.Float64,
         1.0e-9,
         "explicit Float64 from Int16");
      Assert_Reconstructs
        (Float64,
         3,
         IP.Float32_Precision,
         OpenCV.Core.Float32,
         1.0e-3,
         "explicit Float32 from Float64");
   end Laplacian_Precision_Policy;

   procedure Laplacian_Integer_Source_Keeps_Negative_Detail
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
      Minimum : OpenCV.Float32_Value := 0.0;
      Maximum : OpenCV.Float32_Value := 0.0;
   begin
      --  Vertical step edge: dark left half, bright right half.
      for Row in 0 .. 7 loop
         for Column in 0 .. 7 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, (if Column < 4 then 0 else 200));
         end loop;
      end loop;
      declare
         Pyramid : constant OpenCV.Core.Mat_Array :=
           IP.Build_Laplacian_Pyramid (Source, 2);
      begin
         for Row in 0 .. 7 loop
            for Column in 0 .. 7 loop
               declare
                  Value : constant OpenCV.Float32_Value :=
                    OpenCV.Core.Float32_Access.Get (Pyramid (0), Row, Column);
               begin
                  Minimum := OpenCV.Float32_Value'Min (Minimum, Value);
                  Maximum := OpenCV.Float32_Value'Max (Maximum, Value);
               end;
            end loop;
         end loop;
         AUnit.Assertions.Assert
           (Minimum < -1.0 and then Maximum > 1.0,
            "an edge residual must keep both negative and positive detail");
         AUnit.Assertions.Assert
           (Max_Difference
              (IP.Reconstruct_Laplacian_Pyramid (Pyramid),
               Source.Convert_To (OpenCV.Core.Float32))
            <= 1.0e-3,
            "the edge image must reconstruct without saturation");
      end;
   end Laplacian_Integer_Source_Keeps_Negative_Detail;

   procedure Laplacian_Reconstructs_Geometries (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Odd : constant OpenCV.Core.Mat :=
        Random_Mat (13, 9, OpenCV.Core.Float32);
   begin
      Assert_Reconstructs
        (Random_Mat (16, 24, OpenCV.Core.Float32),
         4,
         IP.Automatic_Precision,
         OpenCV.Core.Float32,
         1.0e-3,
         "even Float32");
      Assert_Reconstructs
        (Odd,
         IP.Maximum_Pyramid_Level_Count (Odd),
         IP.Automatic_Precision,
         OpenCV.Core.Float32,
         1.0e-3,
         "odd Float32 to 1 x 1");
      Assert_Reconstructs
        (Random_Mat (11, 7, OpenCV.Core.Float64),
         4,
         IP.Automatic_Precision,
         OpenCV.Core.Float64,
         1.0e-9,
         "odd Float64");
      Assert_Reconstructs
        (Random_Mat (9, 13, OpenCV.Core.UInt8, 3),
         3,
         IP.Automatic_Precision,
         OpenCV.Core.Float32,
         1.0e-3,
         "odd UInt8 C3");
      Assert_Reconstructs
        (Random_Mat (6, 10, OpenCV.Core.Float64, 4),
         3,
         IP.Automatic_Precision,
         OpenCV.Core.Float64,
         1.0e-9,
         "Float64 C4");
      for Border of All_Borders loop
         declare
            Source : constant OpenCV.Core.Mat :=
              Random_Mat (11, 14, OpenCV.Core.Float32);
         begin
            AUnit.Assertions.Assert
              (Max_Difference
                 (IP.Reconstruct_Laplacian_Pyramid
                    (IP.Build_Laplacian_Pyramid (Source, 3, Border)),
                  Source)
               <= 1.0e-3,
               "Laplacian round trip for " & Border'Image);
         end;
      end loop;
   end Laplacian_Reconstructs_Geometries;

   procedure Laplacian_Single_Level_And_Structure (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat := Random_Mat (5, 6, OpenCV.Core.Float32);
      Before : constant OpenCV.Core.Mat := Source.Clone;
   begin
      declare
         One : OpenCV.Core.Mat_Array := IP.Build_Laplacian_Pyramid (Source, 1);
      begin
         AUnit.Assertions.Assert
           (One'Length = 1
            and then Max_Difference
                       (One (0), Source.Convert_To (OpenCV.Core.Float32))
                     = 0.0,
            "a one-level Laplacian pyramid is the converted Source");
         AUnit.Assertions.Assert
           (Max_Difference
              (IP.Reconstruct_Laplacian_Pyramid (One),
               Source.Convert_To (OpenCV.Core.Float32))
            = 0.0,
            "a one-level pyramid reconstructs to the converted Source");
         --  Float32 Source: Convert_To to the same depth must still copy.
         OpenCV.Core.Set_To (One (0), (others => -5.0));
         AUnit.Assertions.Assert
           (Max_Difference (Source, Before) = 0.0,
            "a one-level Laplacian must not share Source storage");
      end;

      --  Decomposition is literally G(i) - Up(G(i+1)); last is G(N).
      declare
         Working  : constant OpenCV.Core.Mat :=
           Source.Convert_To (OpenCV.Core.Float32);
         Gaussian : constant OpenCV.Core.Mat_Array :=
           IP.Build_Gaussian_Pyramid (Working, 3);
         Pyramid  : OpenCV.Core.Mat_Array :=
           IP.Build_Laplacian_Pyramid (Source, 3);
         Up       : OpenCV.Core.Mat;
      begin
         IP.Pyramid_Up
           (Gaussian (1), Up, Output_Size => (Width => 6, Height => 5));
         AUnit.Assertions.Assert
           (Max_Difference
              (Pyramid (0), OpenCV.Core.Subtract (Gaussian (0), Up))
            = 0.0,
            "L(0) must equal G(0) - Pyramid_Up(G(1))");
         AUnit.Assertions.Assert
           (Max_Difference (Pyramid (2), Gaussian (2)) = 0.0,
            "the last level must be the low-frequency Gaussian base");
         OpenCV.Core.Set_To (Pyramid (1), (others => 0.0));
         OpenCV.Core.Set_To (Pyramid (2), (others => 0.0));
         AUnit.Assertions.Assert
           (Max_Difference
              (Pyramid (0), OpenCV.Core.Subtract (Gaussian (0), Up))
            = 0.0
            and then Max_Difference (Source, Before) = 0.0,
            "Laplacian levels must own independent storage");
         OpenCV.Core.Set_To (Source, (others => 0.0));
         AUnit.Assertions.Assert
           (Max_Difference
              (Pyramid (0), OpenCV.Core.Subtract (Gaussian (0), Up))
            = 0.0,
            "Source mutation after the build must not change any level");
      end;
   end Laplacian_Single_Level_And_Structure;

   procedure Laplacian_Residual_Edit_And_Arbitrary_Bounds
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source   : constant OpenCV.Core.Mat :=
        Random_Mat (9, 11, OpenCV.Core.Float32);
      Pyramid  : constant OpenCV.Core.Mat_Array :=
        IP.Build_Laplacian_Pyramid (Source, 3);
      Original : constant OpenCV.Core.Mat :=
        IP.Reconstruct_Laplacian_Pyramid (Pyramid);
      Edited   : OpenCV.Core.Mat_Array (Pyramid'Range);
      Shifted  : OpenCV.Core.Mat_Array (5 .. 7);
      Snapshot : OpenCV.Core.Mat_Array (Pyramid'Range);
   begin
      for Index in Pyramid'Range loop
         Edited (Index) := Pyramid (Index).Clone;
         Snapshot (Index) := Pyramid (Index).Clone;
         Shifted (Index + 5) := Pyramid (Index);
      end loop;

      --  Zeroing the finest residual removes its detail from the result.
      OpenCV.Core.Set_To (Edited (0), (others => 0.0));
      declare
         Smoothed : constant OpenCV.Core.Mat :=
           IP.Reconstruct_Laplacian_Pyramid (Edited);
      begin
         AUnit.Assertions.Assert
           (Max_Difference (Smoothed, Original) > 1.0,
            "an edited residual must change the reconstruction");
         AUnit.Assertions.Assert
           (Max_Difference
              (Smoothed, OpenCV.Core.Subtract (Original, Pyramid (0)))
            <= 1.0e-3,
            "removing L(0) must subtract exactly that residual");
      end;

      AUnit.Assertions.Assert
        (Max_Difference (IP.Reconstruct_Laplacian_Pyramid (Shifted), Original)
         = 0.0,
         "reconstruction must follow iteration order, not index 0");
      for Index in Pyramid'Range loop
         AUnit.Assertions.Assert
           (Max_Difference (Pyramid (Index), Snapshot (Index)) = 0.0,
            "reconstruction must not modify input level" & Index'Image);
      end loop;
   end Laplacian_Residual_Edit_And_Arbitrary_Bounds;

   procedure Laplacian_Region_Matches_Independent_Clone (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (20, 20, (OpenCV.Core.UInt8, 3));
      Source : OpenCV.Core.Mat :=
        Parent.Region ((X => 4, Y => 2, Width => 11, Height => 9));
      Owning : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (255.0, 0.0, 255.0, 0.0));
      OpenCV.Core.Set_Random_Seed (3);
      OpenCV.Core.Fill_Uniform (Source, (others => 20.0), (others => 90.0));
      Owning := Source.Clone;
      for Border of All_Borders loop
         Assert_Same_Levels
           (IP.Build_Laplacian_Pyramid (Source, 4, Border),
            IP.Build_Laplacian_Pyramid (Owning, 4, Border),
            0.0,
            "Region Laplacian must match an independent clone for "
            & Border'Image);
      end loop;
      AUnit.Assertions.Assert
        (Max_Difference
           (IP.Reconstruct_Laplacian_Pyramid
              (IP.Build_Laplacian_Pyramid (Source, 4)),
            Owning.Convert_To (OpenCV.Core.Float32))
         <= 1.0e-3,
         "a Region Laplacian must reconstruct the logical image");
   end Laplacian_Region_Matches_Independent_Clone;

   procedure Reconstruction_Rejects_Malformed_Pyramids (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Valid     : constant OpenCV.Core.Mat_Array :=
        IP.Build_Laplacian_Pyramid (Random_Mat (9, 11, OpenCV.Core.UInt8), 3);
      Candidate : OpenCV.Core.Mat_Array (Valid'Range);
      Empty_Mat : OpenCV.Core.Mat;

      procedure Attempt is
         Rebuilt : constant OpenCV.Core.Mat :=
           IP.Reconstruct_Laplacian_Pyramid (Candidate);
      begin
         AUnit.Assertions.Assert
           (Rebuilt.Is_Empty, "malformed reconstruction must not succeed");
      end Attempt;

      procedure Empty_Array is
         Nothing : OpenCV.Core.Mat_Array (1 .. 0);
         Rebuilt : constant OpenCV.Core.Mat :=
           IP.Reconstruct_Laplacian_Pyramid (Nothing);
      begin
         AUnit.Assertions.Assert
           (Rebuilt.Is_Empty, "an empty pyramid must not reconstruct");
      end Empty_Array;

      procedure Check
        (Level : Natural; Replacement : OpenCV.Core.Mat; Message : String) is
      begin
         Candidate := Valid;
         Candidate (Level) := Replacement;
         Assert_Raises (Attempt'Access, Message);
      end Check;
   begin
      Assert_Raises (Empty_Array'Access, "an empty array must be rejected");
      Check (1, Empty_Mat, "an empty level must be rejected");
      Check
        (0,
         Valid (0).Convert_To (OpenCV.Core.UInt8),
         "integer levels must be rejected");
      Check
        (2,
         Valid (2).Convert_To (OpenCV.Core.Float64),
         "mixed Float32/Float64 levels must be rejected");
      Check
        (1,
         OpenCV.Core.Create (5, 6, (OpenCV.Core.Float32, 3)),
         "a channel mismatch must be rejected");
      Check
        (1,
         OpenCV.Core.Create (4, 6, (OpenCV.Core.Float32, 1)),
         "a wrong row progression must be rejected");
      Check
        (2,
         OpenCV.Core.Create (3, 2, (OpenCV.Core.Float32, 1)),
         "a wrong column progression must be rejected");
      Check
        (0,
         OpenCV.Core.Create
           (OpenCV.Core.Dimension_Array'(1 => 9, 2 => 11, 3 => 1),
            (OpenCV.Core.Float32, 1)),
         "a three-dimensional level must be rejected");
      Candidate := Valid;
      Candidate (0) := Candidate (1);
      Assert_Raises
        (Attempt'Access, "a coarse-to-fine order must be rejected");
   end Reconstruction_Rejects_Malformed_Pyramids;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Routine : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Routine));
      end Add;
   begin
      Add
        ("Gaussian Level_Count 1 is an independent Source clone",
         Gaussian_Single_Level_Is_Independent_Clone'Access);
      Add
        ("Gaussian geometry and maximum level count",
         Gaussian_Geometry_And_Maximum_Levels'Access);
      Add
        ("Gaussian build matches repeated Pyramid_Down for every border",
         Gaussian_Matches_Repeated_Pyramid_Down'Access);
      Add
        ("Gaussian build covers supported depths and channels",
         Gaussian_Depths_And_Channels'Access);
      Add
        ("Gaussian Region matches an independent clone",
         Gaussian_Region_Matches_Independent_Clone'Access);
      Add
        ("Gaussian levels own independent storage",
         Gaussian_Levels_Own_Storage'Access);
      Add
        ("Pyramid construction rejects invalid inputs",
         Pyramid_Construction_Rejects_Invalid_Inputs'Access);
      Add
        ("Sized Pyramid_Up reverses odd Pyramid_Down geometry",
         Sized_Pyramid_Up_Reverses_Odd_Geometry'Access);
      Add
        ("Sized Pyramid_Up rejects illegal geometry atomically",
         Sized_Pyramid_Up_Rejects_Illegal_Geometry'Access);
      Add
        ("Raw pyramid C ABI validation and handle lifetime",
         Raw_Pyramid_ABI_Validation'Access);
      Add ("Laplacian precision policy", Laplacian_Precision_Policy'Access);
      Add
        ("Laplacian integer source keeps negative detail",
         Laplacian_Integer_Source_Keeps_Negative_Detail'Access);
      Add
        ("Laplacian reconstructs even, odd, and multichannel images",
         Laplacian_Reconstructs_Geometries'Access);
      Add
        ("Laplacian single level and decomposition structure",
         Laplacian_Single_Level_And_Structure'Access);
      Add
        ("Laplacian residual edits and arbitrary array bounds",
         Laplacian_Residual_Edit_And_Arbitrary_Bounds'Access);
      Add
        ("Reconstruction rejects malformed pyramids",
         Reconstruction_Rejects_Malformed_Pyramids'Access);
      Add
        ("Laplacian Region matches an independent clone",
         Laplacian_Region_Matches_Independent_Clone'Access);
      return Result'Access;
   end Suite;

end Pyramid_Construction_Tests;
