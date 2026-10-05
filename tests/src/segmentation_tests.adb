with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Int32_Access;
with OpenCV.Core.Int32_Buffer_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt8_Vec3_Mat_View;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Segmentation_Tests is

   --  Negative-path tests deliberately hold NaN in Float64 variables so they
   --  can be passed to the public API.
   pragma Suppress (Validity_Check);

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.double;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Mat_Size;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Rect;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Image_Processing.GrabCut_Label;

   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   package U8 renames OpenCV.Core.UInt8_Access;
   package I32 renames OpenCV.Core.Int32_Access;
   package F64 renames OpenCV.Core.Float64_Access;
   package RGB renames OpenCV.Core.UInt8_Vec3_Access;
   use type C_API.Status;
   use type C_API.Rect_I32;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   NaN_Bits : constant Interfaces.Unsigned_64 := 16#7FF8_0000_0000_0000#;

   function Bits_To_Float is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Long_Float);

   function NaN return Long_Float is
      pragma Suppress (Range_Check);
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float (NaN_Bits);
   end NaN;

   function Smallest_Subnormal return Long_Float
   is (Bits_To_Float (1));

   function Gray (Value : Long_Float) return OpenCV.Scalar
   is ((Component_0 => Value, others => 0.0));

   function Color (B, G, R : Long_Float) return OpenCV.Scalar
   is ((Component_0 => B,
        Component_1 => G,
        Component_2 => R,
        Component_3 => 0.0));

   function Filled
     (Rows, Columns : Natural;
      Kind          : OpenCV.Core.Mat_Type;
      Value         : OpenCV.Scalar) return OpenCV.Core.Mat
   is
      Image : OpenCV.Core.Mat := OpenCV.Core.Create (Rows, Columns, Kind);
   begin
      OpenCV.Core.Set_To (Image, Value);
      return Image;
   end Filled;

   function Gray8 (Rows, Columns : Natural) return OpenCV.Core.Mat
   is (Filled (Rows, Columns, (OpenCV.Core.UInt8, 1), Gray (0.0)));

   procedure Paint
     (Image : in out OpenCV.Core.Mat;
      Area  : OpenCV.Rect;
      Value : OpenCV.Scalar)
   is
      View : OpenCV.Core.Mat := OpenCV.Core.Region (Image, Area);
   begin
      OpenCV.Core.Set_To (View, Value);
   end Paint;

   --  Number of zero scalars in a single-channel Mat.
   function Zero_Count (Image : OpenCV.Core.Mat) return OpenCV.Core.Mat_Size
   is (OpenCV.Core.Total (Image) - OpenCV.Core.Count_Non_Zero (Image));

   --  Elementwise equality of two Mats of one type and shape, any channels.
   function Same (Left, Right : OpenCV.Core.Mat) return Boolean
   is (Left.Rows = Right.Rows
       and then Left.Columns = Right.Columns
       and then OpenCV.Core.Count_Non_Zero
                  (OpenCV.Core.Reshape (OpenCV.Core.Abs_Diff (Left, Right), 1))
                = 0);

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

   --  Number of elements of a single-channel Mat equal to Value.
   function Count_Equal
     (Image : OpenCV.Core.Mat; Value : Long_Float) return OpenCV.Core.Mat_Size
   is (OpenCV.Core.Count_Non_Zero
         (OpenCV.Core.In_Range (Image, Gray (Value), Gray (Value))));

   procedure Flood_UInt8_Exact_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat := Gray8 (10, 10);
      Filled : IP.Flood_Fill_Result;
   begin
      Paint (Image, (X => 2, Y => 3, Width => 4, Height => 3), Gray (50.0));
      IP.Flood_Fill (Image, (X => 4, Y => 4), Gray (200.0), Filled);
      AUnit.Assertions.Assert
        (Filled.Pixel_Count = 12, "the 4 x 3 region has 12 pixels");
      AUnit.Assertions.Assert
        (Filled.Bounds = (X => 2, Y => 3, Width => 4, Height => 3),
         "bounds must be the painted rectangle");
      AUnit.Assertions.Assert
        (Count_Equal (Image, 200.0) = 12 and then Zero_Count (Image) = 88,
         "exactly the region is filled and the background is unchanged");
      AUnit.Assertions.Assert
        (U8.Get (Image, 3, 2) = 200 and then U8.Get (Image, 2, 2) = 0,
         "Seed X is the column and Y the row");
   end Flood_UInt8_Exact_Region;

   procedure Flood_UInt8_Color (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat :=
        Filled (8, 8, (OpenCV.Core.UInt8, 3), Color (10.0, 20.0, 30.0));
      Filled : IP.Flood_Fill_Result;
   begin
      Paint
        (Image,
         (X => 0, Y => 0, Width => 3, Height => 8),
         Color (200.0, 0.0, 0.0));
      IP.Flood_Fill (Image, (X => 6, Y => 6), Color (1.0, 2.0, 3.0), Filled);
      AUnit.Assertions.Assert
        (Filled.Pixel_Count = 40
         and then Filled.Bounds = (X => 3, Y => 0, Width => 5, Height => 8),
         "the three-channel component right of the stripe must be filled");
      AUnit.Assertions.Assert
        (RGB.Get (Image, 0, 3) = OpenCV.Core.UInt8_Vec3.Vector'(1, 2, 3)
         and then RGB.Get (Image, 0, 2)
                  = OpenCV.Core.UInt8_Vec3.Vector'(200, 0, 0),
         "all three channels are written and the stripe is preserved");
   end Flood_UInt8_Color;

   procedure Flood_Float32 (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat :=
        Filled (6, 6, (OpenCV.Core.Float32, 1), Gray (0.5));
      Filled : IP.Flood_Fill_Result;
   begin
      Paint (Image, (X => 0, Y => 2, Width => 6, Height => 1), Gray (1.5));
      IP.Flood_Fill (Image, (X => 5, Y => 5), Gray (-2.25), Filled);
      AUnit.Assertions.Assert
        (Filled.Pixel_Count = 18
         and then Filled.Bounds = (X => 0, Y => 3, Width => 6, Height => 3),
         "the Float32 component below the stripe has 18 pixels");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Image, 4, 1) = -2.25
         and then OpenCV.Core.Float32_Access.Get (Image, 2, 1) = 1.5
         and then OpenCV.Core.Float32_Access.Get (Image, 0, 1) = 0.5,
         "Float32 pixels are filled exactly and others are preserved");
   end Flood_Float32;

   procedure Flood_Connectivity (Test : in out Fixture) is
      pragma Unreferenced (Test);

      function Diagonal return OpenCV.Core.Mat is
         Image : OpenCV.Core.Mat := Gray8 (5, 5);
      begin
         for Index in 0 .. 2 loop
            U8.Set (Image, Index, Index, 255);
         end loop;
         return Image;
      end Diagonal;

      Four   : OpenCV.Core.Mat := Diagonal;
      Eight  : OpenCV.Core.Mat := Diagonal;
      Result : IP.Flood_Fill_Result;
   begin
      IP.Flood_Fill
        (Four,
         (X => 0, Y => 0),
         Gray (9.0),
         Result,
         Connectivity => IP.Four_Connected);
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 1 and then U8.Get (Four, 1, 1) = 255,
         "four-connectivity must not cross a diagonal");
      IP.Flood_Fill
        (Eight,
         (X => 0, Y => 0),
         Gray (9.0),
         Result,
         Connectivity => IP.Eight_Connected);
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 3
         and then U8.Get (Eight, 2, 2) = 9
         and then Result.Bounds = (X => 0, Y => 0, Width => 3, Height => 3),
         "eight-connectivity must follow the diagonal chain");
   end Flood_Connectivity;

   --  A 3 x 10 horizontal ramp (value = column) filled from column 0 with an
   --  upper difference of 1: every neighbour step is within range, but only
   --  columns 0 and 1 are within range of the seed.
   procedure Flood_Range_Modes (Test : in out Fixture) is
      pragma Unreferenced (Test);

      function Ramp return OpenCV.Core.Mat is
         Image : OpenCV.Core.Mat := Gray8 (3, 10);
      begin
         for Row in 0 .. 2 loop
            for Column in 0 .. 9 loop
               U8.Set (Image, Row, Column, OpenCV.UInt8_Value (Column));
            end loop;
         end loop;
         return Image;
      end Ramp;

      Floating : OpenCV.Core.Mat := Ramp;
      Fixed    : OpenCV.Core.Mat := Ramp;
      Result   : IP.Flood_Fill_Result;
   begin
      IP.Flood_Fill
        (Floating,
         (X => 0, Y => 1),
         Gray (200.0),
         Result,
         Upper_Difference => Gray (1.0));
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 30 and then U8.Get (Floating, 1, 9) = 200,
         "a floating range follows the gradual ramp to the far end");
      IP.Flood_Fill
        (Fixed,
         (X => 0, Y => 1),
         Gray (200.0),
         Result,
         Upper_Difference => Gray (1.0),
         Range_Mode       => IP.Fixed_Range);
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 6
         and then Result.Bounds = (X => 0, Y => 0, Width => 2, Height => 3)
         and then U8.Get (Fixed, 1, 2) = 2,
         "a fixed range compares every candidate with the seed value");
   end Flood_Range_Modes;

   procedure Flood_Seed_At_Edge (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat := Gray8 (5, 7);
      Result : IP.Flood_Fill_Result;
   begin
      IP.Flood_Fill (Image, (X => 6, Y => 4), Gray (3.0), Result);
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 35
         and then Result.Bounds = (X => 0, Y => 0, Width => 7, Height => 5)
         and then Count_Equal (Image, 3.0) = 35,
         "a corner seed fills the whole uniform image");
   end Flood_Seed_At_Edge;

   procedure Flood_Region_Mutates_Parent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : constant OpenCV.Core.Mat := Gray8 (10, 10);
      Alias  : constant OpenCV.Core.Mat := Parent;
      View   : OpenCV.Core.Mat :=
        OpenCV.Core.Region (Parent, (X => 5, Y => 4, Width => 5, Height => 6));
      Result : IP.Flood_Fill_Result;
   begin
      IP.Flood_Fill (View, (X => 0, Y => 0), Gray (9.0), Result);
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 30
         and then Result.Bounds = (X => 0, Y => 0, Width => 5, Height => 6),
         "the Region is filled as its own image in view coordinates");
      AUnit.Assertions.Assert
        (U8.Get (Parent, 4, 5) = 9
         and then U8.Get (Parent, 9, 9) = 9
         and then U8.Get (Parent, 3, 5) = 0
         and then U8.Get (Parent, 4, 4) = 0,
         "the parent observes the fill only inside the Region");
      AUnit.Assertions.Assert
        (U8.Get (Alias, 4, 5) = 9 and then Count_Equal (Alias, 9.0) = 30,
         "a shallow alias observes the in-place mutation");
   end Flood_Region_Mutates_Parent;

   --  A 6 x 8 uniform image with a mask wall at image column 4 (mask column
   --  5). The mask is two rows and columns larger than the image.
   procedure Flood_Mask_Obstacle_And_Offset (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat := Gray8 (6, 8);
      Mask   : OpenCV.Core.Mat := Gray8 (8, 10);
      Result : IP.Flood_Fill_Result;
   begin
      Paint (Mask, (X => 5, Y => 1, Width => 1, Height => 6), Gray (1.0));
      IP.Flood_Fill_With_Mask
        (Image,
         Mask,
         (X => 1, Y => 2),
         Gray (77.0),
         Result,
         Mask_Fill_Value => 42);
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 24
         and then Result.Bounds = (X => 0, Y => 0, Width => 4, Height => 6),
         "the fill must stop at the mask wall");
      AUnit.Assertions.Assert
        (U8.Get (Image, 0, 3) = 77
         and then U8.Get (Image, 0, 4) = 0
         and then U8.Get (Image, 0, 7) = 0,
         "image pixels under and beyond the wall are unchanged");
      AUnit.Assertions.Assert
        (U8.Get (Mask, 3, 2) = 42
         and then U8.Get (Mask, 1, 1) = 42
         and then U8.Get (Mask, 6, 4) = 42
         and then U8.Get (Mask, 1, 6) = 0
         and then U8.Get (Mask, 1, 5) = 1,
         "image (X, Y) is recorded at mask (X + 1, Y + 1) with the fill"
         & " value, and the wall and the far side are untouched");
      AUnit.Assertions.Assert
        (Count_Equal (Mask, 42.0) = 24,
         "exactly the filled pixels carry the mask fill value");
   end Flood_Mask_Obstacle_And_Offset;

   procedure Flood_Mask_Border (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat := Gray8 (4, 5);
      Mask   : OpenCV.Core.Mat := Gray8 (6, 7);
      Result : IP.Flood_Fill_Result;
   begin
      IP.Flood_Fill_With_Mask
        (Image,
         Mask,
         (X => 0, Y => 0),
         Gray (5.0),
         Result,
         Mask_Fill_Value => 200);
      for Column in 0 .. 6 loop
         AUnit.Assertions.Assert
           (U8.Get (Mask, 0, Column) = 1 and then U8.Get (Mask, 5, Column) = 1,
            "OpenCV sets the top and bottom mask border to 1");
      end loop;
      for Row in 0 .. 5 loop
         AUnit.Assertions.Assert
           (U8.Get (Mask, Row, 0) = 1 and then U8.Get (Mask, Row, 6) = 1,
            "OpenCV sets the left and right mask border to 1");
      end loop;
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 20 and then Count_Equal (Mask, 200.0) = 20,
         "the whole interior is filled and recorded");
   end Flood_Mask_Border;

   procedure Flood_Mask_Only (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image    : OpenCV.Core.Mat := Gray8 (5, 5);
      Original : OpenCV.Core.Mat;
      Mask     : OpenCV.Core.Mat := Gray8 (7, 7);
      Result   : IP.Flood_Fill_Result;
   begin
      Paint (Image, (X => 0, Y => 0, Width => 2, Height => 5), Gray (30.0));
      Original := Image.Clone;
      --  New_Value is ignored in mask-only mode, so even NaN is accepted.
      IP.Flood_Fill_With_Mask
        (Image,
         Mask,
         (X => 4, Y => 4),
         Gray (NaN),
         Result,
         Mask_Fill_Value => 9,
         Mask_Only       => True);
      AUnit.Assertions.Assert
        (Same (Image, Original), "mask-only mode must not modify Image");
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 15
         and then Result.Bounds = (X => 2, Y => 0, Width => 3, Height => 5)
         and then Count_Equal (Mask, 9.0) = 15
         and then U8.Get (Mask, 1, 3) = 9
         and then U8.Get (Mask, 1, 2) = 0,
         "mask-only mode still updates Mask and Result");
   end Flood_Mask_Only;

   procedure Flood_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat := Gray8 (6, 6);
      Result : IP.Flood_Fill_Result;

      procedure Try
        (Target : in out OpenCV.Core.Mat;
         Seed   : OpenCV.Point := (X => 1, Y => 1);
         Value  : OpenCV.Scalar := Gray (1.0);
         Lower  : OpenCV.Scalar := (others => 0.0);
         Upper  : OpenCV.Scalar := (others => 0.0)) is
      begin
         IP.Flood_Fill (Target, Seed, Value, Result, Lower, Upper);
      end Try;

      procedure Empty is
         Target : OpenCV.Core.Mat;
      begin
         Try (Target);
      end Empty;

      procedure Three_D is
         Target : OpenCV.Core.Mat :=
           OpenCV.Core.Create
             (OpenCV.Core.Dimension_Array'(4, 4, 4), (OpenCV.Core.UInt8, 1));
      begin
         Try (Target);
      end Three_D;

      procedure Float64_Depth is
         Target : OpenCV.Core.Mat :=
           Filled (4, 4, (OpenCV.Core.Float64, 1), Gray (0.0));
      begin
         Try (Target);
      end Float64_Depth;

      procedure Two_Channels is
         Target : OpenCV.Core.Mat :=
           Filled (4, 4, (OpenCV.Core.UInt8, 2), Gray (0.0));
      begin
         Try (Target);
      end Two_Channels;

      procedure Seed_Negative is
      begin
         Try (Image, Seed => (X => -1, Y => 0));
      end Seed_Negative;

      procedure Seed_Column is
      begin
         Try (Image, Seed => (X => 6, Y => 0));
      end Seed_Column;

      procedure Seed_Row is
      begin
         Try (Image, Seed => (X => 0, Y => 6));
      end Seed_Row;

      procedure Negative_Lower is
      begin
         Try (Image, Lower => Gray (-1.0));
      end Negative_Lower;

      procedure Negative_Upper is
      begin
         Try (Image, Upper => Gray (-0.5));
      end Negative_Upper;

      procedure NaN_Value is
      begin
         Try (Image, Value => Gray (NaN));
      end NaN_Value;

      procedure NaN_Difference is
      begin
         Try (Image, Upper => Gray (NaN));
      end NaN_Difference;
   begin
      Assert_Raises (Empty'Access, "an empty image is rejected");
      Assert_Raises (Three_D'Access, "an N-dimensional image is rejected");
      Assert_Raises (Float64_Depth'Access, "a Float64 image is rejected");
      Assert_Raises (Two_Channels'Access, "a two-channel image is rejected");
      Assert_Raises (Seed_Negative'Access, "a negative seed is rejected");
      Assert_Raises
        (Seed_Column'Access, "a seed past the columns is rejected");
      Assert_Raises (Seed_Row'Access, "a seed past the rows is rejected");
      Assert_Raises (Negative_Lower'Access, "a negative lower difference");
      Assert_Raises (Negative_Upper'Access, "a negative upper difference");
      Assert_Raises (NaN_Value'Access, "a NaN fill value is rejected");
      Assert_Raises (NaN_Difference'Access, "a NaN difference is rejected");
      AUnit.Assertions.Assert
        (Zero_Count (Image) = 36, "rejected calls leave the image unchanged");

      --  Components beyond the image's channels are not used.
      IP.Flood_Fill
        (Image,
         (X => 0, Y => 0),
         (Component_0 => 4.0, Component_1 => NaN, others => 0.0),
         Result,
         Upper_Difference =>
           (Component_0 => 0.0, Component_3 => -1.0, others => 0.0));
      AUnit.Assertions.Assert
        (Result.Pixel_Count = 36, "unused scalar components are ignored");
   end Flood_Invalid_Inputs;

   procedure Flood_Mask_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat := Gray8 (6, 6);
      Result : IP.Flood_Fill_Result;

      procedure Try (Mask : in out OpenCV.Core.Mat) is
      begin
         IP.Flood_Fill_With_Mask
           (Image, Mask, (X => 1, Y => 1), Gray (1.0), Result);
      end Try;

      procedure Empty_Mask is
         Mask : OpenCV.Core.Mat;
      begin
         Try (Mask);
      end Empty_Mask;

      procedure Same_Size is
         Mask : OpenCV.Core.Mat := Gray8 (6, 6);
      begin
         Try (Mask);
      end Same_Size;

      procedure Wrong_Columns is
         Mask : OpenCV.Core.Mat := Gray8 (8, 9);
      begin
         Try (Mask);
      end Wrong_Columns;

      procedure Wrong_Depth is
         Mask : OpenCV.Core.Mat :=
           Filled (8, 8, (OpenCV.Core.Int32, 1), Gray (0.0));
      begin
         Try (Mask);
      end Wrong_Depth;

      procedure Wrong_Channels is
         Mask : OpenCV.Core.Mat :=
           Filled (8, 8, (OpenCV.Core.UInt8, 3), Gray (0.0));
      begin
         Try (Mask);
      end Wrong_Channels;

      --  Image is the interior of a larger parent and Mask is the whole
      --  parent: geometry is legal but storage is shared.
      procedure Overlapping is
         Parent : OpenCV.Core.Mat := Gray8 (8, 8);
         Inner  : OpenCV.Core.Mat :=
           OpenCV.Core.Region
             (Parent, (X => 1, Y => 1, Width => 6, Height => 6));
      begin
         IP.Flood_Fill_With_Mask
           (Inner, Parent, (X => 0, Y => 0), Gray (1.0), Result);
      end Overlapping;

      --  A mask whose leading bytes are the image's own storage.
      procedure Mask_Aliases_Image is
         Parent : constant OpenCV.Core.Mat := Gray8 (8, 8);
         Inner  : OpenCV.Core.Mat :=
           OpenCV.Core.Region
             (Parent, (X => 0, Y => 0, Width => 6, Height => 6));
         Alias  : OpenCV.Core.Mat := Parent;
      begin
         IP.Flood_Fill_With_Mask
           (Inner, Alias, (X => 0, Y => 0), Gray (1.0), Result);
      end Mask_Aliases_Image;
   begin
      Assert_Raises (Empty_Mask'Access, "an empty mask is rejected");
      Assert_Raises (Same_Size'Access, "a mask without the +2 border fails");
      Assert_Raises (Wrong_Columns'Access, "a mask with wrong columns fails");
      Assert_Raises (Wrong_Depth'Access, "an Int32 mask is rejected");
      Assert_Raises (Wrong_Channels'Access, "a three-channel mask fails");
      Assert_Raises (Overlapping'Access, "an overlapping mask is rejected");
      Assert_Raises (Mask_Aliases_Image'Access, "Image as Mask is rejected");
      AUnit.Assertions.Assert
        (Zero_Count (Image) = 36, "rejected calls leave the image unchanged");
   end Flood_Mask_Invalid_Inputs;

   Zero4 : aliased constant C_API.Scalar4 := (Values => (others => 0.0));
   One4  : aliased constant C_API.Scalar4 := (Values => (others => 1.0));

   type Null_Output is (No_Null_Output, Null_Count, Null_Bounds);

   Last_Count  : aliased Interfaces.Integer_32 := 0;
   Last_Bounds : aliased C_API.Rect_I32 := (0, 0, 0, 0);

   --  Calls the raw masked flood fill on Image and Mask with the seed at the
   --  origin. The results are left in Last_Count and Last_Bounds, which are
   --  preset to garbage so failure-path zeroing is observable.
   function Raw_Masked_Fill
     (Image           : in out OpenCV.Core.Mat;
      Mask            : in out OpenCV.Core.Mat;
      Connectivity    : Interfaces.Integer_32 := 4;
      Range_Mode      : Interfaces.Integer_32 := 0;
      Mask_Fill_Value : Interfaces.Integer_32 := 1;
      Mask_Only       : Interfaces.Unsigned_8 := 0;
      Lower           : access constant C_API.Scalar4 := Zero4'Access;
      Nulls           : Null_Output := No_Null_Output) return C_API.Status
   is
      Status : C_API.Status := C_API.Success;

      procedure On_Image
        (Image_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
         procedure On_Mask
           (Mask_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              C_API.Flood_Fill_Masked
                (Image_Handle,
                 Mask_Handle,
                 0,
                 0,
                 One4'Access,
                 Lower,
                 Zero4'Access,
                 Connectivity,
                 Range_Mode,
                 Mask_Fill_Value,
                 Mask_Only,
                 (if Nulls = Null_Count then null else Last_Count'Access),
                 (if Nulls = Null_Bounds then null else Last_Bounds'Access));
         end On_Mask;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Mask, On_Mask'Access);
      end On_Image;
   begin
      Last_Count := -7;
      Last_Bounds := (1, 2, 3, 4);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, On_Image'Access);
      if Status /= C_API.Success and then Nulls = No_Null_Output then
         AUnit.Assertions.Assert
           (Last_Count = 0 and then Last_Bounds = (0, 0, 0, 0),
            "raw failure must zero the result outputs");
      end if;
      return Status;
   end Raw_Masked_Fill;

   procedure Flood_Raw_Selectors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image    : OpenCV.Core.Mat := Gray8 (4, 4);
      Mask     : OpenCV.Core.Mat := Gray8 (6, 6);
      Negative : aliased constant C_API.Scalar4 :=
        (Values => (-1.0, 0.0, 0.0, 0.0));
      Huge     : aliased constant C_API.Scalar4 :=
        (Values => (1.0e12, 0.0, 0.0, 0.0));
      NaN4     : aliased constant C_API.Scalar4 :=
        (Values => (Interfaces.C.double (NaN), others => 0.0));
   begin
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Connectivity => 0),
         "connectivity",
         "OpenCV's implicit connectivity 0 is not an ABI selector");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Connectivity => 12),
         "connectivity",
         "an unknown connectivity would set other flag bits");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Range_Mode => 2),
         "range mode",
         "an unknown range selector is rejected");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Mask_Only => 2),
         "mask-only",
         "a non-boolean mask-only selector is rejected");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Mask_Fill_Value => 0),
         "1 .. 255",
         "mask fill value 0 is rejected");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Mask_Fill_Value => 256),
         "1 .. 255",
         "mask fill value 256 would overflow into the flag bits");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Lower => NaN4'Access),
         "finite",
         "a NaN raw difference is rejected before cvFloor");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Lower => Huge'Access),
         "native int",
         "a difference beyond int is rejected before cvFloor");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Nulls => Null_Count),
         "output is null",
         "a null count output is rejected");
      Assert_Invalid
        (Raw_Masked_Fill (Image, Mask, Nulls => Null_Bounds),
         "output is null",
         "a null bounds output is rejected");
      AUnit.Assertions.Assert
        (Zero_Count (Image) = 16 and then Zero_Count (Mask) = 36,
         "shim-rejected raw calls must not write Image or Mask");

      --  A negative difference is semantic policy that OpenCV rejects safely
      --  (4.10/5.0 may already have written the mask border by then).
      AUnit.Assertions.Assert
        (Raw_Masked_Fill (Image, Mask, Lower => Negative'Access)
         = C_API.Error_OpenCV,
         "a negative difference is left to OpenCV to reject");

      --  Recovery: a valid call after the failures succeeds.
      AUnit.Assertions.Assert
        (Raw_Masked_Fill (Image, Mask) = C_API.Success
         and then Last_Count = 16
         and then Last_Bounds = (0, 0, 4, 4)
         and then C_API.Last_Error_Message = "",
         "a valid raw fill succeeds and clears the diagnostic");
   end Flood_Raw_Selectors;

   function Raw_Flood_Fill
     (Image            : System.Address;
      Seed_X           : Interfaces.Integer_32;
      Seed_Y           : Interfaces.Integer_32;
      New_Value        : access constant C_API.Scalar4;
      Lower_Difference : access constant C_API.Scalar4;
      Upper_Difference : access constant C_API.Scalar4;
      Connectivity     : Interfaces.Integer_32;
      Range_Mode       : Interfaces.Integer_32;
      Pixel_Count      : access Interfaces.Integer_32;
      Bounds           : access C_API.Rect_I32) return C_API.Status
   with Import, Convention => C, External_Name => "opencv_imgproc_flood_fill";

   procedure Flood_Raw_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Status : C_API.Status;
      Result : IP.Flood_Fill_Result;

      procedure Unmasked (Target : in out OpenCV.Core.Mat) is
         procedure Fill (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              C_API.Flood_Fill
                (Handle,
                 0,
                 0,
                 One4'Access,
                 Zero4'Access,
                 Zero4'Access,
                 4,
                 0,
                 Last_Count'Access,
                 Last_Bounds'Access);
         end Fill;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Target, Fill'Access);
      end Unmasked;

      Three_D : OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(3, 3, 3), (OpenCV.Core.UInt8, 1));
      Image   : OpenCV.Core.Mat := Gray8 (4, 4);
      Empty   : OpenCV.Core.Mat;
      Parent  : OpenCV.Core.Mat := Gray8 (6, 6);
      Inner   : OpenCV.Core.Mat :=
        OpenCV.Core.Region (Parent, (X => 1, Y => 1, Width => 4, Height => 4));
      Limit   : OpenCV.Core.Mat := Gray8 (1, 65_535);
      Wide    : OpenCV.Core.Mat := Gray8 (1, 65_536);
      Tall    : OpenCV.Core.Mat := Gray8 (65_536, 1);

      procedure Public_Wide is
      begin
         IP.Flood_Fill (Wide, (X => 0, Y => 0), Gray (1.0), Result);
      end Public_Wide;
   begin
      Status :=
        Raw_Flood_Fill
          (System.Null_Address,
           0,
           0,
           One4'Access,
           Zero4'Access,
           Zero4'Access,
           4,
           0,
           Last_Count'Access,
           Last_Bounds'Access);
      Assert_Invalid (Status, "image", "a null image handle is rejected");
      Status :=
        Raw_Flood_Fill
          (System.Null_Address,
           0,
           0,
           One4'Access,
           Zero4'Access,
           Zero4'Access,
           4,
           0,
           null,
           Last_Bounds'Access);
      Assert_Invalid (Status, "output is null", "null outputs come first");

      Unmasked (Three_D);
      Assert_Invalid
        (Status, "two-dimensional", "an N-D raw image is rejected");

      --  FFillSegment stores coordinates as ushort in OpenCV 4.1 - 5.0.
      Unmasked (Wide);
      Assert_Invalid (Status, "65535", "65536 columns would truncate ushort");
      Unmasked (Tall);
      Assert_Invalid (Status, "65535", "65536 rows would truncate ushort");
      Assert_Raises
        (Public_Wide'Access, "the public API reports the native limit");
      Unmasked (Limit);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Last_Count = 65_535,
         "exactly 65535 columns remain within the native segment range");

      Assert_Invalid
        (Raw_Masked_Fill (Image, Empty),
         "nonempty",
         "an empty raw mask is rejected rather than version-dependently"
         & " recreated");
      Assert_Invalid
        (Raw_Masked_Fill (Inner, Parent),
         "share storage",
         "a raw mask overlapping the image is rejected");
      AUnit.Assertions.Assert
        (Zero_Count (Parent) = 36,
         "the rejected overlapping call writes nothing");
   end Flood_Raw_Geometry;

   --  A 20 x 30 colour image: dark blue on the left (columns 0 .. 14) and
   --  bright yellow on the right. Seeds 1 and 2 sit well inside each half.
   function Two_Region_Source return OpenCV.Core.Mat is
      Image : OpenCV.Core.Mat :=
        Filled (20, 30, (OpenCV.Core.UInt8, 3), Color (200.0, 20.0, 20.0));
   begin
      Paint
        (Image,
         (X => 15, Y => 0, Width => 15, Height => 20),
         Color (10.0, 230.0, 240.0));
      return Image;
   end Two_Region_Source;

   function Seeded_Markers (Rows, Columns : Natural) return OpenCV.Core.Mat is
      Markers : OpenCV.Core.Mat :=
        Filled (Rows, Columns, (OpenCV.Core.Int32, 1), Gray (0.0));
   begin
      Paint (Markers, (X => 4, Y => 8, Width => 3, Height => 3), Gray (1.0));
      Paint (Markers, (X => 23, Y => 8, Width => 3, Height => 3), Gray (2.0));
      return Markers;
   end Seeded_Markers;

   procedure Watershed_Two_Regions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : constant OpenCV.Core.Mat := Two_Region_Source;
      Original : constant OpenCV.Core.Mat := Source.Clone;
      Markers  : OpenCV.Core.Mat := Seeded_Markers (20, 30);
   begin
      IP.Watershed (Source, Markers);
      AUnit.Assertions.Assert
        (Markers.Rows = 20
         and then Markers.Columns = 30
         and then Markers.Depth = OpenCV.Core.Int32
         and then Markers.Channels = 1,
         "marker geometry and type are preserved");
      AUnit.Assertions.Assert
        (Zero_Count (Markers) = 0, "every unknown pixel must be resolved");
      AUnit.Assertions.Assert
        (Count_Equal (Markers, -1.0) > 0
         and then I32.Get (Markers, 0, 0) = -1
         and then I32.Get (Markers, 19, 29) = -1,
         "boundaries, including the outer border, are marked -1");
      AUnit.Assertions.Assert
        (I32.Get (Markers, 5, 2) = 1
         and then I32.Get (Markers, 15, 10) = 1
         and then I32.Get (Markers, 5, 27) = 2
         and then I32.Get (Markers, 15, 19) = 2,
         "both seed labels propagate through their own colour region");
      for Row in 1 .. 18 loop
         AUnit.Assertions.Assert
           (I32.Get (Markers, Row, 1) = 1
            and then I32.Get (Markers, Row, 28) = 2,
            "each half is labelled consistently along every row");
      end loop;
      AUnit.Assertions.Assert
        (Same (Source, Original), "Source must not be modified");
   end Watershed_Two_Regions;

   procedure Watershed_Region_View (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Two_Region_Source;
      Parent : constant OpenCV.Core.Mat :=
        Filled (24, 34, (OpenCV.Core.Int32, 1), Gray (7.0));
      View   : OpenCV.Core.Mat :=
        OpenCV.Core.Region
          (Parent, (X => 2, Y => 2, Width => 30, Height => 20));
      Seeds  : constant OpenCV.Core.Mat := Seeded_Markers (20, 30);
   begin
      Seeds.Copy_To (View);
      IP.Watershed (Source, View);
      AUnit.Assertions.Assert
        (I32.Get (Parent, 7, 4) = 1 and then I32.Get (Parent, 7, 30) = 2,
         "labels are written into the parent through the Region");
      AUnit.Assertions.Assert
        (I32.Get (Parent, 1, 1) = 7
         and then I32.Get (Parent, 22, 32) = 7
         and then I32.Get (Parent, 1, 20) = 7,
         "parent elements outside the Region are unchanged");
      AUnit.Assertions.Assert
        (I32.Get (Parent, 2, 2) = -1, "the Region's own border is -1");
   end Watershed_Region_View;

   procedure Watershed_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source  : constant OpenCV.Core.Mat := Two_Region_Source;
      Markers : OpenCV.Core.Mat := Seeded_Markers (20, 30);

      procedure Empty_Source is
         Empty : OpenCV.Core.Mat;
      begin
         IP.Watershed (Empty, Markers);
      end Empty_Source;

      procedure Gray_Source is
      begin
         IP.Watershed (Gray8 (20, 30), Markers);
      end Gray_Source;

      procedure Float_Source is
      begin
         IP.Watershed
           (Filled (20, 30, (OpenCV.Core.Float32, 3), Gray (0.0)), Markers);
      end Float_Source;

      procedure Empty_Markers is
         Empty : OpenCV.Core.Mat;
      begin
         IP.Watershed (Source, Empty);
      end Empty_Markers;

      procedure Byte_Markers is
         Wrong : OpenCV.Core.Mat := Gray8 (20, 30);
      begin
         IP.Watershed (Source, Wrong);
      end Byte_Markers;

      procedure Two_Channel_Markers is
         Wrong : OpenCV.Core.Mat :=
           Filled (20, 30, (OpenCV.Core.Int32, 2), Gray (0.0));
      begin
         IP.Watershed (Source, Wrong);
      end Two_Channel_Markers;

      procedure Mismatched is
         Wrong : OpenCV.Core.Mat := Seeded_Markers (20, 29);
      begin
         IP.Watershed (Source, Wrong);
      end Mismatched;

      procedure Negative_Marker is
         Wrong : OpenCV.Core.Mat := Seeded_Markers (20, 30);
      begin
         I32.Set (Wrong, 3, 3, -1);
         IP.Watershed (Source, Wrong);
      end Negative_Marker;
   begin
      Assert_Raises (Empty_Source'Access, "an empty source is rejected");
      Assert_Raises (Gray_Source'Access, "a one-channel source is rejected");
      Assert_Raises (Float_Source'Access, "a Float32 source is rejected");
      Assert_Raises (Empty_Markers'Access, "empty markers are rejected");
      Assert_Raises (Byte_Markers'Access, "UInt8 markers are rejected");
      Assert_Raises (Two_Channel_Markers'Access, "two-channel markers fail");
      Assert_Raises (Mismatched'Access, "mismatched geometry is rejected");
      Assert_Raises
        (Negative_Marker'Access, "negative input markers are rejected");
      AUnit.Assertions.Assert
        (Count_Equal (Markers, 1.0) = 9 and then Zero_Count (Markers) = 582,
         "rejected calls leave the markers unchanged");
   end Watershed_Invalid_Inputs;

   Watershed_Status : C_API.Status := C_API.Success;

   procedure Raw_Watershed_Call
     (Source : OpenCV.Core.Mat; Markers : in out OpenCV.Core.Mat)
   is
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Markers_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Watershed_Status :=
              C_API.Watershed (Source_Handle, Markers_Handle);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Markers, Output'Access);
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
   end Raw_Watershed_Call;

   --  Rows x 3 Int32 markers (12 bytes per row) viewed as a Rows x 3 UInt8
   --  C3 source with a four-pixel (12-byte) row stride: the two Mats have
   --  identical geometry and address exactly the same bytes.
   procedure With_Overlapping_Source
     (Markers : in out OpenCV.Core.Mat;
      Process : not null access procedure (Source : OpenCV.Core.Mat))
   is
      Rows : constant Positive := Markers.Rows;

      procedure On_Buffer
        (Data : aliased in out OpenCV.Core.Int32_Buffer_Access.Buffer_Array)
      is
         Overlay :
           aliased OpenCV.Core.UInt8_Vec3_Mat_View.Buffer_Array
                     (0 .. 4 * Rows - 1)
         with Import, Address => Data'Address;

         --  GNAT's Unrestricted_Access yields an access-to-unconstrained
         --  pointer to the constrained overlay (its bounds live as long as
         --  this scope), so the dereference matches the aliased formal.
         type Pixel_Access is
           access all OpenCV.Core.UInt8_Vec3_Mat_View.Buffer_Array;
         Pixels : constant Pixel_Access := Overlay'Unrestricted_Access;

         procedure On_View (View : in out OpenCV.Core.Mat) is
         begin
            Process (View);
         end On_View;
      begin
         OpenCV.Core.UInt8_Vec3_Mat_View.With_Writable_Strided_Mat_View
           (Pixels.all, Rows, 3, 4, On_View'Access);
      end On_Buffer;
   begin
      OpenCV.Core.Int32_Buffer_Access.With_Writable_Buffer
        (Markers, On_Buffer'Access);
   end With_Overlapping_Source;

   procedure Watershed_Overlap_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Markers : OpenCV.Core.Mat :=
        Filled (6, 3, (OpenCV.Core.Int32, 1), Gray (0.0));
      Raised  : Boolean := False;

      procedure Public (Source : OpenCV.Core.Mat) is
      begin
         IP.Watershed (Source, Markers);
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end Public;

      procedure Raw (Source : OpenCV.Core.Mat) is
      begin
         Raw_Watershed_Call (Source, Markers);
      end Raw;
   begin
      I32.Set (Markers, 2, 1, 1);
      With_Overlapping_Source (Markers, Public'Access);
      AUnit.Assertions.Assert
        (Raised, "the public API rejects a source aliasing the markers");
      With_Overlapping_Source (Markers, Raw'Access);
      Assert_Invalid
        (Watershed_Status,
         "share storage",
         "the raw ABI rejects the same aliasing");
      AUnit.Assertions.Assert
        (I32.Get (Markers, 2, 1) = 1 and then I32.Get (Markers, 0, 0) = 0,
         "rejected calls leave the markers unchanged");
   end Watershed_Overlap_Rejected;

   function Raw_Watershed
     (Source : System.Address; Markers : System.Address) return C_API.Status
   with Import, Convention => C, External_Name => "opencv_imgproc_watershed";

   procedure Watershed_Raw_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : constant OpenCV.Core.Mat := Two_Region_Source;
      Markers  : OpenCV.Core.Mat := Seeded_Markers (20, 30);
      Empty    : OpenCV.Core.Mat;
      Cube     : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(4, 4, 4), (OpenCV.Core.UInt8, 3));
      Cube_Ids : OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(4, 4, 4), (OpenCV.Core.Int32, 1));
      Narrow   : OpenCV.Core.Mat := Seeded_Markers (20, 29);
      Bytes    : OpenCV.Core.Mat := Gray8 (20, 30);
   begin
      Assert_Invalid
        (Raw_Watershed (System.Null_Address, System.Null_Address),
         "source",
         "a null source handle is rejected");
      Raw_Watershed_Call (Empty, Markers);
      Assert_Invalid
        (Watershed_Status, "nonempty", "an empty raw source is rejected");
      Raw_Watershed_Call (Source, Empty);
      Assert_Invalid
        (Watershed_Status, "nonempty", "empty raw markers are rejected");
      Raw_Watershed_Call (Cube, Cube_Ids);
      Assert_Invalid
        (Watershed_Status,
         "two-dimensional",
         "N-D Mats whose rows and columns compare equal are rejected");
      Raw_Watershed_Call (Source, Narrow);
      AUnit.Assertions.Assert
        (Watershed_Status = C_API.Error_OpenCV,
         "a geometry mismatch is left to OpenCV's own size assertion");
      Raw_Watershed_Call (Source, Bytes);
      AUnit.Assertions.Assert
        (Watershed_Status = C_API.Error_OpenCV,
         "a marker type mismatch is left to OpenCV's own type assertion");
      AUnit.Assertions.Assert
        (Count_Equal (Markers, 2.0) = 9 and then Zero_Count (Markers) = 582,
         "rejected raw calls leave the markers unchanged");
      Raw_Watershed_Call (Source, Markers);
      AUnit.Assertions.Assert
        (Watershed_Status = C_API.Success and then Zero_Count (Markers) = 0,
         "a valid raw call succeeds after the failures");
   end Watershed_Raw_Geometry;

   --  A 40 x 40 image: a textured dark-green background (two alternating
   --  shades, so every GMM component has spread) with a textured bright-red
   --  16 x 16 object at (12, 12). The object is far from the background in
   --  colour, and both training sets hold hundreds of pixels.
   Object_Area : constant OpenCV.Rect :=
     (X => 12, Y => 12, Width => 16, Height => 16);
   Guess_Area  : constant OpenCV.Rect :=
     (X => 8, Y => 8, Width => 24, Height => 24);

   function GrabCut_Source return OpenCV.Core.Mat is
      Image : OpenCV.Core.Mat :=
        Filled (40, 40, (OpenCV.Core.UInt8, 3), Color (30.0, 90.0, 20.0));
   begin
      for Row in 0 .. 39 loop
         for Column in 0 .. 39 loop
            if (Row + Column) mod 2 = 0 then
               RGB.Set (Image, Row, Column, (40, 110, 30));
            end if;
         end loop;
      end loop;
      Paint (Image, Object_Area, Color (20.0, 20.0, 230.0));
      for Row in 12 .. 27 loop
         for Column in 12 .. 27 loop
            if (Row + Column) mod 2 = 0 then
               RGB.Set (Image, Row, Column, (35, 30, 250));
            end if;
         end loop;
      end loop;
      return Image;
   end GrabCut_Source;

   function Is_Foreground (Label : IP.GrabCut_Label) return Boolean
   is (Label in IP.Definite_Foreground | IP.Probable_Foreground);

   --  Every stable cross-version property of a segmentation of the fixture:
   --  label domain and geometry, obvious background away from the object,
   --  and the object core as (probable) foreground.
   procedure Assert_Segmented (State : IP.GrabCut_State; Context : String) is
      Mask : constant OpenCV.Core.Mat := IP.GrabCut_Mask (State);
   begin
      AUnit.Assertions.Assert
        (Mask.Rows = 40
         and then Mask.Columns = 40
         and then Mask.Depth = OpenCV.Core.UInt8
         and then Mask.Channels = 1,
         Context & ": the mask is UInt8 C1 with the source geometry");
      AUnit.Assertions.Assert
        (OpenCV.Core.Min_Max_Loc (Mask).Maximum <= 3.0,
         Context & ": every label lies in 0 .. 3");
      for Index in 0 .. 39 loop
         AUnit.Assertions.Assert
           (not Is_Foreground (IP.GrabCut_Label_At (State, 0, Index))
            and then not Is_Foreground (IP.GrabCut_Label_At (State, 39, Index))
            and then not Is_Foreground (IP.GrabCut_Label_At (State, Index, 0))
            and then not Is_Foreground
                           (IP.GrabCut_Label_At (State, Index, 39)),
            Context & ": the image border is background");
      end loop;
      for Row in 15 .. 24 loop
         for Column in 15 .. 24 loop
            AUnit.Assertions.Assert
              (Is_Foreground (IP.GrabCut_Label_At (State, Row, Column)),
               Context & ": the object core is foreground");
         end loop;
      end loop;
   end Assert_Segmented;

   procedure GrabCut_Rectangle_Initialization (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : constant OpenCV.Core.Mat := GrabCut_Source;
      Original : constant OpenCV.Core.Mat := Source.Clone;
      State    : constant IP.GrabCut_State :=
        IP.Initialize_GrabCut (Source, Guess_Area, Iterations => 2);
   begin
      AUnit.Assertions.Assert
        (IP.Is_Initialized (State), "the state reports initialization");
      Assert_Segmented (State, "rectangle initialization");
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_At (State, 3, 3) = IP.Definite_Background
         and then IP.GrabCut_Label_At (State, 7, 20) = IP.Definite_Background
         and then IP.GrabCut_Label_At (State, 32, 20) = IP.Definite_Background,
         "pixels outside the rectangle are definite background");
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_At (State, 20, 20) = IP.Probable_Foreground,
         "the rectangle interior is only ever probable foreground");
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_At (State, 9, 9) = IP.Probable_Background,
         "background colour inside the rectangle becomes probable"
         & " background");
      AUnit.Assertions.Assert
        (Same (Source, Original), "Source must not be modified");
   end GrabCut_Rectangle_Initialization;

   --  A caller mask using all four labels: definite background outside the
   --  guess, probable background in the guess margin, probable foreground
   --  over the object, and a small definite-foreground core.
   function Four_Label_Mask return OpenCV.Core.Mat is
      Mask : OpenCV.Core.Mat := Gray8 (40, 40);
   begin
      Paint (Mask, Guess_Area, Gray (2.0));
      Paint (Mask, Object_Area, Gray (3.0));
      Paint (Mask, (X => 18, Y => 18, Width => 4, Height => 4), Gray (1.0));
      return Mask;
   end Four_Label_Mask;

   procedure GrabCut_Mask_Initialization (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source  : constant OpenCV.Core.Mat := GrabCut_Source;
      Initial : constant OpenCV.Core.Mat := Four_Label_Mask;
      Copy    : constant OpenCV.Core.Mat := Initial.Clone;
      State   : constant IP.GrabCut_State :=
        IP.Initialize_GrabCut (Source, Initial);
   begin
      Assert_Segmented (State, "mask initialization");
      AUnit.Assertions.Assert
        (Same (Initial, Copy), "the caller's initial mask is unchanged");
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_At (State, 20, 20) = IP.Definite_Foreground
         and then IP.GrabCut_Label_At (State, 2, 2) = IP.Definite_Background,
         "definite labels are preserved by segmentation");
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_At (State, 9, 9) = IP.Probable_Background
         and then IP.GrabCut_Label_At (State, 13, 13) = IP.Probable_Foreground,
         "probable labels settle according to colour");
   end GrabCut_Mask_Initialization;

   procedure GrabCut_Label_Conversions (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Four is
         Label : constant IP.GrabCut_Label := IP.To_GrabCut_Label (4);
         pragma Unreferenced (Label);
      begin
         null;
      end Four;
   begin
      for Label in IP.GrabCut_Label loop
         AUnit.Assertions.Assert
           (IP.To_GrabCut_Label (IP.GrabCut_Label_Value (Label)) = Label,
            "every label round-trips through its numeric value");
      end loop;
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_Value (IP.Definite_Background) = 0
         and then IP.GrabCut_Label_Value (IP.Definite_Foreground) = 1
         and then IP.GrabCut_Label_Value (IP.Probable_Background) = 2
         and then IP.GrabCut_Label_Value (IP.Probable_Foreground) = 3,
         "labels use OpenCV's stable numeric encoding");
      Assert_Raises (Four'Access, "values above 3 are not labels");
   end GrabCut_Label_Conversions;

   --  A deliberately loose guess: the object plus a wide background margin
   --  as probable foreground. Refinement must keep the label domain valid
   --  and settle the margin as background.
   function Loose_Guess return OpenCV.Core.Mat is
      Mask : OpenCV.Core.Mat := Gray8 (40, 40);
   begin
      Paint (Mask, (X => 4, Y => 4, Width => 32, Height => 32), Gray (3.0));
      return Mask;
   end Loose_Guess;

   procedure GrabCut_Refinement (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : constant OpenCV.Core.Mat := GrabCut_Source;
      Original : constant OpenCV.Core.Mat := Source.Clone;
      --  GrabCut_State is limited: it is created in place, never copied.
      State    : IP.GrabCut_State :=
        IP.Initialize_GrabCut (Source, Loose_Guess);
   begin
      IP.Refine_GrabCut (Source, State, Iterations => 3);
      Assert_Segmented (State, "ordinary refinement");
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_At (State, 5, 5) = IP.Probable_Background
         and then IP.GrabCut_Label_At (State, 34, 20) = IP.Probable_Background,
         "refinement moves the background margin to probable background");

      IP.Refine_GrabCut_Frozen_Model (Source, State);
      Assert_Segmented (State, "frozen-model refinement");
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_At (State, 5, 5) = IP.Probable_Background,
         "a frozen-model pass keeps the settled segmentation");
      AUnit.Assertions.Assert
        (Same (Source, Original), "refinement never modifies Source");
   end GrabCut_Refinement;

   procedure GrabCut_State_Isolation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := GrabCut_Source;
      State  : constant IP.GrabCut_State :=
        IP.Initialize_GrabCut (Source, Guess_Area);
      Copy   : OpenCV.Core.Mat := IP.GrabCut_Mask (State);
      Before : constant IP.GrabCut_Label := IP.GrabCut_Label_At (State, 3, 3);
   begin
      OpenCV.Core.Set_To (Copy, Gray (3.0));
      AUnit.Assertions.Assert
        (U8.Get (Copy, 3, 3) = 3, "the returned Mat is writable");
      AUnit.Assertions.Assert
        (IP.GrabCut_Label_At (State, 3, 3) = Before
         and then Before = IP.Definite_Background,
         "writing the returned mask must not alter the state");
      AUnit.Assertions.Assert
        (U8.Get (IP.GrabCut_Mask (State), 3, 3) = 0,
         "a later accessor call returns the unchanged private mask");
   end GrabCut_State_Isolation;

   procedure Init_GrabCut (Image : OpenCV.Core.Mat; Area : OpenCV.Rect) is
      State : constant IP.GrabCut_State := IP.Initialize_GrabCut (Image, Area);
      pragma Unreferenced (State);
   begin
      null;
   end Init_GrabCut;

   procedure Init_GrabCut (Mask : OpenCV.Core.Mat) is
      State : constant IP.GrabCut_State :=
        IP.Initialize_GrabCut (GrabCut_Source, Mask);
      pragma Unreferenced (State);
   begin
      null;
   end Init_GrabCut;

   procedure GrabCut_Invalid_Rectangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := GrabCut_Source;

      procedure Empty_Source is
         Empty : OpenCV.Core.Mat;
      begin
         Init_GrabCut (Empty, Guess_Area);
      end Empty_Source;

      procedure Gray_Source is
      begin
         Init_GrabCut (Gray8 (40, 40), Guess_Area);
      end Gray_Source;

      procedure Cube_Source is
      begin
         Init_GrabCut
           (OpenCV.Core.Create
              (OpenCV.Core.Dimension_Array'(4, 4, 4), (OpenCV.Core.UInt8, 3)),
            Guess_Area);
      end Cube_Source;

      procedure Zero_Width is
      begin
         Init_GrabCut (Source, (X => 8, Y => 8, Width => 0, Height => 10));
      end Zero_Width;

      procedure Negative_Origin is
      begin
         Init_GrabCut (Source, (X => -1, Y => 8, Width => 10, Height => 10));
      end Negative_Origin;

      procedure Partly_Outside is
      begin
         Init_GrabCut (Source, (X => 35, Y => 8, Width => 10, Height => 10));
      end Partly_Outside;

      --  Four inside pixels: fewer than OpenCV 4.1's five GMM components.
      procedure Too_Few_Inside is
      begin
         Init_GrabCut (Source, (X => 8, Y => 8, Width => 2, Height => 2));
      end Too_Few_Inside;

      --  The whole image leaves no background training pixel.
      procedure Nothing_Outside is
      begin
         Init_GrabCut (Source, (X => 0, Y => 0, Width => 40, Height => 40));
      end Nothing_Outside;

      --  Leaves exactly four outside pixels in a 2 x 40 source.
      procedure Few_Outside is
      begin
         Init_GrabCut
           (Filled (2, 40, (OpenCV.Core.UInt8, 3), Gray (9.0)),
            (X => 0, Y => 0, Width => 38, Height => 2));
      end Few_Outside;
   begin
      Assert_Raises (Empty_Source'Access, "an empty source is rejected");
      Assert_Raises (Gray_Source'Access, "a one-channel source is rejected");
      Assert_Raises (Cube_Source'Access, "an N-D source is rejected");
      Assert_Raises (Zero_Width'Access, "an empty rectangle is rejected");
      Assert_Raises (Negative_Origin'Access, "a negative origin is rejected");
      Assert_Raises
        (Partly_Outside'Access, "a partly outside rectangle fails");
      Assert_Raises (Too_Few_Inside'Access, "four inside pixels are too few");
      Assert_Raises (Nothing_Outside'Access, "no outside pixels is rejected");
      Assert_Raises (Few_Outside'Access, "four outside pixels are too few");
   end GrabCut_Invalid_Rectangle;

   procedure GrabCut_Invalid_Mask (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Wrong_Mask_Type is
      begin
         Init_GrabCut (Filled (40, 40, (OpenCV.Core.Int32, 1), Gray (0.0)));
      end Wrong_Mask_Type;

      procedure Wrong_Mask_Size is
      begin
         Init_GrabCut (Gray8 (40, 39));
      end Wrong_Mask_Size;

      procedure Invalid_Label is
         Mask : OpenCV.Core.Mat := Four_Label_Mask;
      begin
         U8.Set (Mask, 0, 0, 4);
         Init_GrabCut (Mask);
      end Invalid_Label;

      procedure No_Foreground is
      begin
         Init_GrabCut (Gray8 (40, 40));
      end No_Foreground;

      --  Four definite-foreground pixels only.
      procedure Few_Foreground is
         Mask : OpenCV.Core.Mat := Gray8 (40, 40);
      begin
         Paint (Mask, (X => 10, Y => 10, Width => 2, Height => 2), Gray (1.0));
         Init_GrabCut (Mask);
      end Few_Foreground;

      --  Every pixel is foreground except four probable-background pixels.
      procedure Few_Background is
         Mask : OpenCV.Core.Mat :=
           Filled (40, 40, (OpenCV.Core.UInt8, 1), Gray (3.0));
      begin
         Paint (Mask, (X => 0, Y => 0, Width => 2, Height => 2), Gray (2.0));
         Init_GrabCut (Mask);
      end Few_Background;

      Minimal : OpenCV.Core.Mat :=
        Filled (40, 40, (OpenCV.Core.UInt8, 1), Gray (3.0));
   begin
      Assert_Raises (Wrong_Mask_Type'Access, "an Int32 mask is rejected");
      Assert_Raises (Wrong_Mask_Size'Access, "a mismatched mask is rejected");
      Assert_Raises (Invalid_Label'Access, "label value 4 is rejected");
      Assert_Raises (No_Foreground'Access, "an all-background mask fails");
      Assert_Raises (Few_Foreground'Access, "four foreground pixels fail");
      Assert_Raises (Few_Background'Access, "four background pixels fail");

      --  Exactly five pixels of one class is the portable minimum.
      Paint (Minimal, (X => 0, Y => 0, Width => 5, Height => 1), Gray (0.0));
      declare
         State : constant IP.GrabCut_State :=
           IP.Initialize_GrabCut (GrabCut_Source, Minimal);
      begin
         AUnit.Assertions.Assert
           (IP.Is_Initialized (State)
            and then IP.GrabCut_Label_At (State, 0, 0)
                     = IP.Definite_Background,
            "five background pixels satisfy the portable minimum");
      end;
   end GrabCut_Invalid_Mask;

   procedure GrabCut_Invalid_State_Use (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : constant OpenCV.Core.Mat := GrabCut_Source;
      Blank    : IP.GrabCut_State;
      Ready    : IP.GrabCut_State :=
        IP.Initialize_GrabCut (Source, Guess_Area);
      Snapshot : constant OpenCV.Core.Mat := IP.GrabCut_Mask (Ready);

      procedure Refine_Blank is
      begin
         IP.Refine_GrabCut (Source, Blank);
      end Refine_Blank;

      procedure Freeze_Blank is
      begin
         IP.Refine_GrabCut_Frozen_Model (Source, Blank);
      end Freeze_Blank;

      procedure Mask_Blank is
         Mask : constant OpenCV.Core.Mat := IP.GrabCut_Mask (Blank);
         pragma Unreferenced (Mask);
      begin
         null;
      end Mask_Blank;

      procedure Background_Blank is
         Value : constant OpenCV.Core.Mat :=
           IP.GrabCut_Background_Model (Blank);
         pragma Unreferenced (Value);
      begin
         null;
      end Background_Blank;

      procedure Foreground_Blank is
         Value : constant OpenCV.Core.Mat :=
           IP.GrabCut_Foreground_Model (Blank);
         pragma Unreferenced (Value);
      begin
         null;
      end Foreground_Blank;

      procedure Clone_Blank is
         Value : constant IP.GrabCut_State := IP.Clone_GrabCut_State (Blank);
         pragma Unreferenced (Value);
      begin
         null;
      end Clone_Blank;

      procedure Read (State : IP.GrabCut_State; Row, Column : Natural) is
         Label : constant IP.GrabCut_Label :=
           IP.GrabCut_Label_At (State, Row, Column);
         pragma Unreferenced (Label);
      begin
         null;
      end Read;

      procedure Label_Blank is
      begin
         Read (Blank, 0, 0);
      end Label_Blank;

      procedure Row_Outside is
      begin
         Read (Ready, 40, 0);
      end Row_Outside;

      procedure Column_Outside is
      begin
         Read (Ready, 0, 40);
      end Column_Outside;

      procedure Wrong_Geometry is
      begin
         IP.Refine_GrabCut
           (Filled (40, 41, (OpenCV.Core.UInt8, 3), Gray (0.0)), Ready);
      end Wrong_Geometry;

      procedure Wrong_Type is
      begin
         IP.Refine_GrabCut_Frozen_Model (Gray8 (40, 40), Ready);
      end Wrong_Type;
   begin
      AUnit.Assertions.Assert
        (not IP.Is_Initialized (Blank), "a default state is uninitialized");
      Assert_Raises (Refine_Blank'Access, "refining a blank state fails");
      Assert_Raises (Freeze_Blank'Access, "freezing a blank state fails");
      Assert_Raises (Mask_Blank'Access, "a blank state has no mask");
      Assert_Raises (Background_Blank'Access, "blank background export fails");
      Assert_Raises (Foreground_Blank'Access, "blank foreground export fails");
      Assert_Raises (Clone_Blank'Access, "blank state cannot be cloned");
      Assert_Raises (Label_Blank'Access, "a blank state has no labels");
      Assert_Raises (Row_Outside'Access, "a row outside the mask fails");
      Assert_Raises (Column_Outside'Access, "a column outside the mask fails");
      Assert_Raises (Wrong_Geometry'Access, "a mismatched source fails");
      Assert_Raises (Wrong_Type'Access, "a one-channel source fails");
      AUnit.Assertions.Assert
        (Same (IP.GrabCut_Mask (Ready), Snapshot),
         "failed refinements leave the state unchanged");
   end GrabCut_Invalid_State_Use;

   GrabCut_Status : C_API.Status := C_API.Success;

   procedure Raw_GrabCut
     (Source     : OpenCV.Core.Mat;
      Mask       : in out OpenCV.Core.Mat;
      Background : in out OpenCV.Core.Mat;
      Foreground : in out OpenCV.Core.Mat;
      Mode       : Interfaces.Integer_32;
      Iterations : Interfaces.Integer_32 := 1;
      Area       : OpenCV.Rect := Guess_Area)
   is
      procedure S (Source_H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure M (Mask_H : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            procedure B (Back_H : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
               procedure F
                 (Fore_H : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  GrabCut_Status :=
                    C_API.GrabCut
                      (Source_H,
                       Mask_H,
                       Back_H,
                       Fore_H,
                       Interfaces.Integer_32 (Area.X),
                       Interfaces.Integer_32 (Area.Y),
                       Interfaces.Integer_32 (Area.Width),
                       Interfaces.Integer_32 (Area.Height),
                       Iterations,
                       Mode);
               end F;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Foreground, F'Access);
            end B;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Background, B'Access);
         end M;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Mask, M'Access);
      end S;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, S'Access);
   end Raw_GrabCut;

   function Model (Columns : Positive := 65) return OpenCV.Core.Mat
   is (Filled (1, Columns, (OpenCV.Core.Float64, 1), Gray (0.0)));

   procedure GrabCut_Combined (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat := GrabCut_Source;
      Source_Copy : constant OpenCV.Core.Mat := Source.Clone;
      Seeds       : OpenCV.Core.Mat := Four_Label_Mask;
      Area        : constant OpenCV.Rect := Guess_Area;
   begin
      U8.Set (Seeds, 0, 0, 1);
      U8.Set (Seeds, 0, 1, 3);
      U8.Set (Seeds, 0, 2, 2);
      declare
         Original : constant OpenCV.Core.Mat := Seeds.Clone;
         Combined : constant IP.GrabCut_State :=
           IP.Initialize_GrabCut (Source, Seeds, Area);
         Plain    : constant IP.GrabCut_State :=
           IP.Initialize_GrabCut (Source, Seeds);
      begin
         Assert_Segmented (Combined, "combined initialization");
         AUnit.Assertions.Assert
           (IP.GrabCut_Label_At (Combined, 0, 0) = IP.Definite_Background
            and then IP.GrabCut_Label_At (Combined, 0, 1)
                     = IP.Definite_Background
            and then IP.GrabCut_Label_At (Combined, 0, 2)
                     = IP.Definite_Background
            and then IP.GrabCut_Label_At (Plain, 0, 0)
                     = IP.Definite_Foreground,
            "outside foreground seeds are overwritten only in combined mode");
         AUnit.Assertions.Assert
           (IP.GrabCut_Label_At (Combined, 20, 20) = IP.Definite_Foreground,
            "inside definite foreground remains definite");
         AUnit.Assertions.Assert
           (IP.GrabCut_Label_At (Combined, 9, 9) = IP.Probable_Background
            and then Is_Foreground (IP.GrabCut_Label_At (Combined, 13, 13)),
            "probable labels inside the region remain usable");
         AUnit.Assertions.Assert
           (Same (Seeds, Original) and then Same (Source, Source_Copy),
            "combined initialization does not change caller Mats");
      end;
   end GrabCut_Combined;

   procedure GrabCut_Combined_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source_Parent  : constant OpenCV.Core.Mat :=
        Filled (48, 48, (OpenCV.Core.UInt8, 3), Gray (0.0));
      Mask_Parent    : constant OpenCV.Core.Mat := Gray8 (48, 48);
      View_Area      : constant OpenCV.Rect :=
        (X => 4, Y => 4, Width => 40, Height => 40);
      Source_View    : OpenCV.Core.Mat :=
        OpenCV.Core.Region (Source_Parent, View_Area);
      Mask_View      : OpenCV.Core.Mat :=
        OpenCV.Core.Region (Mask_Parent, View_Area);
      Fixture_Source : constant OpenCV.Core.Mat := GrabCut_Source;
      Fixture_Mask   : constant OpenCV.Core.Mat := Four_Label_Mask;
   begin
      Fixture_Source.Copy_To (Source_View);
      Fixture_Mask.Copy_To (Mask_View);
      declare
         Source_Copy : constant OpenCV.Core.Mat := Source_Parent.Clone;
         Mask_Copy   : constant OpenCV.Core.Mat := Mask_Parent.Clone;
         State       : constant IP.GrabCut_State :=
           IP.Initialize_GrabCut (Source_View, Mask_View, Guess_Area);
      begin
         Assert_Segmented (State, "combined Region initialization");
         AUnit.Assertions.Assert
           (Same (Source_Parent, Source_Copy)
            and then Same (Mask_Parent, Mask_Copy),
            "Region inputs and their parents are not mutated");
      end;
   end GrabCut_Combined_Region;

   procedure GrabCut_Combined_Invalid (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Seeds : OpenCV.Core.Mat := Four_Label_Mask;
      procedure Try (Area : OpenCV.Rect) is
         State : constant IP.GrabCut_State :=
           IP.Initialize_GrabCut (GrabCut_Source, Seeds, Area);
         pragma Unreferenced (State);
      begin
         null;
      end Try;
      procedure Outside is
      begin
         Try ((X => 35, Y => 8, Width => 10, Height => 10));
      end Outside;
      procedure No_Foreground is
      begin
         Try ((X => 0, Y => 0, Width => 5, Height => 5));
      end No_Foreground;
      procedure No_Background is
      begin
         Try ((X => 0, Y => 0, Width => 40, Height => 40));
      end No_Background;
   begin
      Assert_Raises (Outside'Access, "out-of-image rectangle");
      Assert_Raises (No_Foreground'Access, "constrained foreground sparse");
      OpenCV.Core.Set_To (Seeds, Gray (3.0));
      Assert_Raises (No_Background'Access, "constrained background sparse");
      --  Background inside the region counts, even when there is no outside.
      for Column in 0 .. 4 loop
         U8.Set (Seeds, 0, Column, 2);
      end loop;
      Try ((X => 0, Y => 0, Width => 40, Height => 40));
   end GrabCut_Combined_Invalid;

   procedure GrabCut_Interchange (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source     : constant OpenCV.Core.Mat := GrabCut_Source;
      Original   : IP.GrabCut_State :=
        IP.Initialize_GrabCut (Source, Guess_Area);
      Mask       : OpenCV.Core.Mat := IP.GrabCut_Mask (Original);
      Background : OpenCV.Core.Mat := IP.GrabCut_Background_Model (Original);
      Foreground : OpenCV.Core.Mat := IP.GrabCut_Foreground_Model (Original);
      Saved_Mask : constant OpenCV.Core.Mat := Mask.Clone;
      Saved_Back : constant OpenCV.Core.Mat := Background.Clone;
      Saved_Fore : constant OpenCV.Core.Mat := Foreground.Clone;
      Restored   : IP.GrabCut_State :=
        IP.Restore_GrabCut_State (Mask, Background, Foreground);
      Cloned     : IP.GrabCut_State := IP.Clone_GrabCut_State (Original);
   begin
      AUnit.Assertions.Assert
        (IP.Is_Initialized (Restored) and then IP.Is_Initialized (Cloned),
         "restored and cloned states are initialized");
      AUnit.Assertions.Assert
        (Background.Rows = 1
         and then Background.Columns = IP.GrabCut_Model_Column_Count
         and then Background.Depth = OpenCV.Core.Float64
         and then Background.Channels = 1
         and then Foreground.Rows = 1
         and then Foreground.Columns = IP.GrabCut_Model_Column_Count
         and then Foreground.Depth = OpenCV.Core.Float64
         and then Foreground.Channels = 1,
         "both exported models have native Float64 C1 1 x 65 format");
      U8.Set (Mask, 0, 0, 3);
      F64.Set (Background, 0, 0, 0.0);
      F64.Set (Foreground, 0, 0, 0.0);
      AUnit.Assertions.Assert
        (Same (IP.GrabCut_Mask (Restored), Saved_Mask)
         and then Same (IP.GrabCut_Background_Model (Restored), Saved_Back)
         and then Same (IP.GrabCut_Foreground_Model (Restored), Saved_Fore)
         and then Same (IP.GrabCut_Background_Model (Original), Saved_Back)
         and then Same (IP.GrabCut_Foreground_Model (Original), Saved_Fore),
         "imports and exports own independent storage");
      AUnit.Assertions.Assert
        (Same (IP.GrabCut_Background_Model (Original), Saved_Back)
         and then Same (IP.GrabCut_Foreground_Model (Original), Saved_Fore),
         "repeated exports do not return mutated caller copies");
      IP.Refine_GrabCut_Frozen_Model (Source, Restored);
      IP.Refine_GrabCut_Frozen_Model (Source, Cloned);
      AUnit.Assertions.Assert
        (Same (IP.GrabCut_Mask (Original), Saved_Mask)
         and then Same (IP.GrabCut_Background_Model (Original), Saved_Back)
         and then Same (IP.GrabCut_Foreground_Model (Original), Saved_Fore),
         "refining independent states does not change their origin");
      IP.Refine_GrabCut_Frozen_Model (Source, Original);
      AUnit.Assertions.Assert
        (Same (IP.GrabCut_Mask (Original), IP.GrabCut_Mask (Restored))
         and then Same (IP.GrabCut_Mask (Original), IP.GrabCut_Mask (Cloned)),
         "frozen refinement agrees for independent states");
      IP.Refine_GrabCut (Source, Cloned);
      AUnit.Assertions.Assert
        (Same (IP.GrabCut_Mask (Original), IP.GrabCut_Mask (Restored))
         and then Same (IP.GrabCut_Background_Model (Original), Saved_Back)
         and then Same (IP.GrabCut_Foreground_Model (Original), Saved_Fore),
         "refining a clone cannot mutate its origin");
   end GrabCut_Interchange;

   --  Native layout (4.1/4.10/5.0): weights 0..4, means 5..19,
   --  covariances 20..64; component I covariance starts at 20 + 9 * I.
   function Cancellation_Model return OpenCV.Core.Mat is
      Result : OpenCV.Core.Mat := Model;
   begin
      F64.Set (Result, 0, 0, 1.0);
      --  Positive mathematical determinant, but native +inf - +inf is NaN.
      F64.Set (Result, 0, 20, 1.0E200);
      F64.Set (Result, 0, 21, 1.0E200);
      F64.Set (Result, 0, 22, 1.0);
      F64.Set (Result, 0, 23, 1.0E200);
      F64.Set (Result, 0, 24, 1.0E200);
      F64.Set (Result, 0, 27, 1.0);
      F64.Set (Result, 0, 28, 1.0);
      return Result;
   end Cancellation_Model;

   function Inverse_Overflow_Model return OpenCV.Core.Mat is
      Result : OpenCV.Core.Mat := Model;
   begin
      F64.Set (Result, 0, 0, 1.0);
      --  Native determinant is finite: 1e200 * (1e200 * 2**(-1074)).
      --  Its (2,2) cofactor multiplies the two large entries first: +inf.
      F64.Set (Result, 0, 20, 1.0E200);
      F64.Set (Result, 0, 24, 1.0E200);
      F64.Set (Result, 0, 28, OpenCV.Float64_Value (Smallest_Subnormal));
      return Result;
   end Inverse_Overflow_Model;

   procedure GrabCut_Invalid_Import (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source     : constant OpenCV.Core.Mat := GrabCut_Source;
      Ready      : constant IP.GrabCut_State :=
        IP.Initialize_GrabCut (Source, Guess_Area);
      Mask       : OpenCV.Core.Mat := IP.GrabCut_Mask (Ready);
      Background : OpenCV.Core.Mat := IP.GrabCut_Background_Model (Ready);
      Foreground : constant OpenCV.Core.Mat :=
        IP.GrabCut_Foreground_Model (Ready);
      Valid      : constant OpenCV.Core.Mat := Background.Clone;
      procedure Restore is
         State : constant IP.GrabCut_State :=
           IP.Restore_GrabCut_State (Mask, Background, Foreground);
         pragma Unreferenced (State);
      begin
         null;
      end Restore;
      procedure Restore_Cancellation is
      begin
         Restore;
         AUnit.Assertions.Assert (False, "cancellation must be rejected");
      exception
         when Error : OpenCV.OpenCV_Error =>
            AUnit.Assertions.Assert
              (Ada.Strings.Fixed.Index
                 (Ada.Exceptions.Exception_Message (Error),
                  "nonfinite native determinant")
               /= 0,
               "restore reports nonfinite native determinant arithmetic");
      end Restore_Cancellation;
   begin
      declare
         Empty : OpenCV.Core.Mat;
      begin
         Mask := Empty;
         Assert_Raises (Restore'Access, "empty mask rejected");
      end;
      Mask := Model;
      Assert_Raises (Restore'Access, "wrong mask type rejected");
      Mask := IP.GrabCut_Mask (Ready);
      U8.Set (Mask, 0, 0, 4);
      Assert_Raises (Restore'Access, "bad label rejected");
      Mask := IP.GrabCut_Mask (Ready);
      Background := Filled (1, 65, (OpenCV.Core.Float32, 1), Gray (0.0));
      Assert_Raises (Restore'Access, "wrong model depth rejected");
      Background := Model (64);
      Assert_Raises (Restore'Access, "wrong model shape rejected");
      Background := Valid.Clone;
      F64.Set (Background, 0, 5, OpenCV.Float64_Value (NaN));
      Assert_Raises (Restore'Access, "NaN rejected");
      Background := Model;
      Assert_Raises (Restore'Access, "all-zero model rejected");
      Background := Valid.Clone;
      F64.Set (Background, 0, 0, -1.0);
      Assert_Raises (Restore'Access, "negative weight rejected");
      Background := Valid.Clone;
      for Component in 0 .. 4 loop
         if F64.Get (Background, 0, Component) > 0.0 then
            for Index in 0 .. 8 loop
               F64.Set (Background, 0, 20 + 9 * Component + Index, 0.0);
            end loop;
            exit;
         end if;
      end loop;
      Assert_Raises (Restore'Access, "singular active covariance rejected");
      declare
         Raw_Mask       : OpenCV.Core.Mat := IP.GrabCut_Mask (Ready);
         Raw_Foreground : OpenCV.Core.Mat := Foreground.Clone;
         Before         : constant OpenCV.Core.Mat := Raw_Mask.Clone;
      begin
         Raw_GrabCut
           (Source,
            Raw_Mask,
            Background,
            Raw_Foreground,
            C_API.GrabCut_Eval_Freeze_Model);
         Assert_Invalid
           (GrabCut_Status,
            "determinant",
            "raw evaluation rejects singular model");
         AUnit.Assertions.Assert
           (Same (Raw_Mask, Before),
            "failed raw evaluation leaves mask intact");
      end;
      Background := Valid.Clone;
      Restore;
      AUnit.Assertions.Assert
        (Same (Background, Valid), "validation leaves native model unchanged");
      Background := Cancellation_Model;
      Restore_Cancellation;
      Background := Valid.Clone;
      OpenCV.Core.Set_To (Mask, Gray (0.0));
      Restore;
   end GrabCut_Invalid_Import;

   function Raw_Validate_GrabCut_Model
     (Handle : System.Address) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_validate_grabcut_model";

   procedure GrabCut_Raw_Import (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Ready      : constant IP.GrabCut_State :=
        IP.Initialize_GrabCut (GrabCut_Source, Guess_Area);
      Model_Copy : OpenCV.Core.Mat := IP.GrabCut_Background_Model (Ready);
      Snapshot   : constant OpenCV.Core.Mat := Model_Copy.Clone;
      Status     : C_API.Status;
      procedure Validate (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Status := C_API.Validate_GrabCut_Model (Handle);
      end Validate;
      procedure Check is
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Model_Copy, Validate'Access);
      end Check;
   begin
      Assert_Invalid
        (Raw_Validate_GrabCut_Model (System.Null_Address),
         "handle",
         "null model handle rejected");
      Check;
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Same (Model_Copy, Snapshot),
         "valid native model accepted without mutation");
      Model_Copy := IP.GrabCut_Foreground_Model (Ready);
      Check;
      AUnit.Assertions.Assert
        (Status = C_API.Success, "native exported foreground model accepted");
      Model_Copy := Cancellation_Model;
      Check;
      Assert_Invalid
        (Status,
         "nonfinite native determinant",
         "native determinant cancellation rejected");
      Model_Copy := Inverse_Overflow_Model;
      Check;
      Assert_Invalid
        (Status,
         "nonfinite native inverse",
         "finite determinant with overflowing inverse rejected");
      Model_Copy := Model (64);
      Check;
      Assert_Invalid (Status, "1 x 65", "wrong geometry rejected");
      Model_Copy := Filled (1, 65, (OpenCV.Core.Float32, 1), Gray (0.0));
      Check;
      Assert_Invalid (Status, "Float64", "wrong type rejected");
      Model_Copy := Snapshot.Clone;
      F64.Set (Model_Copy, 0, 5, OpenCV.Float64_Value (NaN));
      Check;
      Assert_Invalid (Status, "finite", "malformed payload rejected");
   end GrabCut_Raw_Import;

   procedure GrabCut_Raw_Modes (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source     : constant OpenCV.Core.Mat := GrabCut_Source;
      Mask       : OpenCV.Core.Mat;
      Background : OpenCV.Core.Mat;
      Foreground : OpenCV.Core.Mat;
      Tiny       : constant OpenCV.Core.Mat :=
        Filled (2, 2, (OpenCV.Core.UInt8, 3), Gray (5.0));
   begin
      Raw_GrabCut (Source, Mask, Background, Foreground, Mode => 4);
      Assert_Invalid (GrabCut_Status, "mode", "mode 4 is not an ABI mode");
      Raw_GrabCut (Source, Mask, Background, Foreground, Mode => -1);
      Assert_Invalid (GrabCut_Status, "mode", "a negative mode is rejected");
      Raw_GrabCut
        (Source,
         Mask,
         Background,
         Foreground,
         C_API.GrabCut_Init_With_Rect,
         Iterations => 0);
      Assert_Invalid
        (GrabCut_Status,
         "positive",
         "zero iterations would skip segmentation");
      Raw_GrabCut
        (Source,
         Mask,
         Background,
         Foreground,
         C_API.GrabCut_Eval_Freeze_Model,
         Iterations => 2);
      Assert_Invalid
        (GrabCut_Status, "exactly one", "frozen eval is one iteration only");
      Raw_GrabCut
        (Source,
         Mask,
         Background,
         Foreground,
         C_API.GrabCut_Init_With_Rect,
         Area => (X => 0, Y => 0, Width => 40, Height => 40));
      Assert_Invalid
        (GrabCut_Status, "five", "a rectangle with no background is rejected");
      Raw_GrabCut
        (Source,
         Mask,
         Background,
         Foreground,
         C_API.GrabCut_Init_With_Rect,
         Area => (X => 38, Y => 38, Width => 10, Height => 10));
      Assert_Invalid
        (GrabCut_Status,
         "five",
         "OpenCV's edge clipping is counted: 2 x 2 inside is too few");
      Raw_GrabCut
        (Tiny,
         Mask,
         Background,
         Foreground,
         C_API.GrabCut_Init_With_Rect,
         Area => (X => 0, Y => 0, Width => 1, Height => 1));
      Assert_Invalid
        (GrabCut_Status, "five", "a four-pixel image cannot train two GMMs");
      AUnit.Assertions.Assert
        (Mask.Is_Empty
         and then Background.Is_Empty
         and then Foreground.Is_Empty,
         "rejected raw calls create no state");

      --  Mask initialization scans the mask in the shim.
      Mask := Gray8 (40, 39);
      Raw_GrabCut
        (Source, Mask, Background, Foreground, C_API.GrabCut_Init_With_Mask);
      Assert_Invalid
        (GrabCut_Status, "geometry", "a mismatched raw mask is rejected");
      Mask := Four_Label_Mask;
      U8.Set (Mask, 5, 5, 9);
      Raw_GrabCut
        (Source, Mask, Background, Foreground, C_API.GrabCut_Init_With_Mask);
      Assert_Invalid (GrabCut_Status, "0 .. 3", "label 9 is rejected");

      --  Recovery: a valid rectangle initialization then succeeds and
      --  rewrites the (rebindable) mask.
      Raw_GrabCut
        (Source, Mask, Background, Foreground, C_API.GrabCut_Init_With_Rect);
      AUnit.Assertions.Assert
        (GrabCut_Status = C_API.Success
         and then Background.Columns = C_API.GrabCut_Model_Columns
         and then Foreground.Rows = 1
         and then Background.Depth = OpenCV.Core.Float64,
         "raw rectangle initialization creates Float64 1 x 65 models");
      Raw_GrabCut (Source, Mask, Background, Foreground, C_API.GrabCut_Eval);
      AUnit.Assertions.Assert
        (GrabCut_Status = C_API.Success, "raw evaluation then succeeds");
   end GrabCut_Raw_Modes;

   procedure GrabCut_Raw_State_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source     : constant OpenCV.Core.Mat := GrabCut_Source;
      Mask       : OpenCV.Core.Mat;
      Background : OpenCV.Core.Mat;
      Foreground : OpenCV.Core.Mat;
      Short      : OpenCV.Core.Mat := Model (64);
      Wide       : OpenCV.Core.Mat := Model (65);
      Float_32   : OpenCV.Core.Mat :=
        Filled (1, 65, (OpenCV.Core.Float32, 1), Gray (0.0));
      Empty      : OpenCV.Core.Mat;
      Joint      : constant OpenCV.Core.Mat := Model (130);
      Left       : OpenCV.Core.Mat :=
        OpenCV.Core.Region (Joint, (X => 0, Y => 0, Width => 65, Height => 1));
      Crossing   : OpenCV.Core.Mat :=
        OpenCV.Core.Region
          (Joint, (X => 60, Y => 0, Width => 65, Height => 1));
      Alias      : OpenCV.Core.Mat;
      Copy       : OpenCV.Core.Mat;
   begin
      Raw_GrabCut
        (Source, Mask, Background, Foreground, C_API.GrabCut_Init_With_Rect);
      AUnit.Assertions.Assert
        (GrabCut_Status = C_API.Success, "a trained state is prepared");
      Copy := Mask.Clone;

      --  Malformed models are rejected before OpenCV would recreate them.
      Raw_GrabCut (Source, Mask, Short, Foreground, C_API.GrabCut_Eval);
      Assert_Invalid (GrabCut_Status, "1 x 65", "a 1 x 64 model is rejected");
      Raw_GrabCut (Source, Mask, Background, Float_32, C_API.GrabCut_Eval);
      Assert_Invalid (GrabCut_Status, "Float64", "a Float32 model fails");
      Raw_GrabCut
        (Source, Mask, Empty, Foreground, C_API.GrabCut_Eval_Freeze_Model);
      Assert_Invalid
        (GrabCut_Status,
         "1 x 65",
         "an empty model would be recreated with zero weights");
      AUnit.Assertions.Assert
        (Empty.Is_Empty and then Short.Columns = 64,
         "rejected models are not rebound");

      --  Aliasing between state Mats is rejected.
      Alias := Background;
      Raw_GrabCut (Source, Mask, Background, Alias, C_API.GrabCut_Eval);
      Assert_Invalid
        (GrabCut_Status,
         "share storage",
         "two headers over one model buffer are rejected");
      Background.Copy_To (Left);
      Foreground.Copy_To (Wide);
      Raw_GrabCut (Source, Mask, Left, Crossing, C_API.GrabCut_Eval);
      Assert_Invalid
        (GrabCut_Status,
         "share storage",
         "overlapping model Regions are rejected");
      Alias := Mask;
      Raw_GrabCut (Source, Mask, Background, Alias, C_API.GrabCut_Eval);
      Assert_Invalid
        (GrabCut_Status, "share storage", "a model aliasing the mask fails");
      Alias := Source;
      Raw_GrabCut (Source, Alias, Background, Foreground, C_API.GrabCut_Eval);
      Assert_Invalid
        (GrabCut_Status, "share storage", "a mask aliasing the source fails");
      AUnit.Assertions.Assert
        (Same (Mask, Copy), "rejected raw calls leave the mask unchanged");

      --  Disjoint Regions of one parent are legitimate model storage.
      Raw_GrabCut (Source, Mask, Left, Wide, C_API.GrabCut_Eval);
      AUnit.Assertions.Assert
        (GrabCut_Status = C_API.Success,
         "non-overlapping model storage is accepted");
   end GrabCut_Raw_State_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Routine : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Routine));
      end Add;
   begin
      Add
        ("Flood fill UInt8 C1 exact region", Flood_UInt8_Exact_Region'Access);
      Add ("Flood fill UInt8 C3", Flood_UInt8_Color'Access);
      Add ("Flood fill Float32", Flood_Float32'Access);
      Add
        ("Flood fill four and eight connectivity", Flood_Connectivity'Access);
      Add ("Flood fill floating and fixed range", Flood_Range_Modes'Access);
      Add ("Flood fill seed at edge", Flood_Seed_At_Edge'Access);
      Add
        ("Flood fill Region mutates parent",
         Flood_Region_Mutates_Parent'Access);
      Add
        ("Flood fill mask obstacle and offset",
         Flood_Mask_Obstacle_And_Offset'Access);
      Add ("Flood fill mask border", Flood_Mask_Border'Access);
      Add ("Flood fill mask only", Flood_Mask_Only'Access);
      Add ("Flood fill invalid inputs", Flood_Invalid_Inputs'Access);
      Add ("Flood fill mask invalid inputs", Flood_Mask_Invalid_Inputs'Access);
      Add ("Flood fill raw C ABI selectors", Flood_Raw_Selectors'Access);
      Add ("Flood fill raw C ABI geometry", Flood_Raw_Geometry'Access);
      Add ("Watershed two regions", Watershed_Two_Regions'Access);
      Add ("Watershed Region view", Watershed_Region_View'Access);
      Add ("Watershed invalid inputs", Watershed_Invalid_Inputs'Access);
      Add ("Watershed overlap rejected", Watershed_Overlap_Rejected'Access);
      Add ("Watershed raw C ABI geometry", Watershed_Raw_Geometry'Access);
      Add
        ("GrabCut rectangle initialization",
         GrabCut_Rectangle_Initialization'Access);
      Add ("GrabCut mask initialization", GrabCut_Mask_Initialization'Access);
      Add ("GrabCut combined initialization", GrabCut_Combined'Access);
      Add ("GrabCut combined Region", GrabCut_Combined_Region'Access);
      Add ("GrabCut combined invalid inputs", GrabCut_Combined_Invalid'Access);
      Add ("GrabCut state interchange", GrabCut_Interchange'Access);
      Add ("GrabCut invalid import", GrabCut_Invalid_Import'Access);
      Add ("GrabCut raw model validation", GrabCut_Raw_Import'Access);
      Add ("GrabCut label conversions", GrabCut_Label_Conversions'Access);
      Add ("GrabCut refinement", GrabCut_Refinement'Access);
      Add ("GrabCut state isolation", GrabCut_State_Isolation'Access);
      Add ("GrabCut invalid rectangle", GrabCut_Invalid_Rectangle'Access);
      Add ("GrabCut invalid mask", GrabCut_Invalid_Mask'Access);
      Add ("GrabCut invalid state use", GrabCut_Invalid_State_Use'Access);
      Add ("GrabCut raw C ABI modes", GrabCut_Raw_Modes'Access);
      Add
        ("GrabCut raw C ABI state validation",
         GrabCut_Raw_State_Validation'Access);
      return Result'Access;
   end Suite;

end Segmentation_Tests;
