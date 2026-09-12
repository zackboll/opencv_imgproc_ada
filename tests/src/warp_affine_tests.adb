with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Warp_Affine_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Core.Float64_Value;

   package C_API renames OpenCV.Image_Processing.Internal.C_API;

   use type C_API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   procedure Assert_Raises_OpenCV_Error
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
   end Assert_Raises_OpenCV_Error;

   function Nearly_Equal
     (Left, Right : OpenCV.Core.Float32_Value;
      Tolerance   : OpenCV.Core.Float32_Value) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Nearly_Equal;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Core.Float32_Value);

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Core.Float64_Value);

   NaN_Bits_32            : constant Interfaces.Unsigned_32 := 16#7FC0_0000#;
   Inf_Bits_64            : constant Interfaces.Unsigned_64 :=
     16#7FF0_0000_0000_0000#;
   Max_Finite_Bits_64     : constant Interfaces.Unsigned_64 :=
     16#7FEF_FFFF_FFFF_FFFF#;
   Neg_Max_Finite_Bits_64 : constant Interfaces.Unsigned_64 :=
     16#FFEF_FFFF_FFFF_FFFF#;

   procedure Fill_Unique_UInt8 (Source : in out OpenCV.Core.Mat) is
   begin
      for Row in 0 .. Source.Rows - 1 loop
         for Column in 0 .. Source.Columns - 1 loop
            OpenCV.Core.UInt8_Access.Set
              (Source,
               Row,
               Column,
               Interfaces.Unsigned_8 (10 * Row + Column + 1));
         end loop;
      end loop;
   end Fill_Unique_UInt8;

   function Identity_Float32 return OpenCV.Core.Mat is
      Transform : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.Float32_Access.Set (Transform, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Transform, 0, 1, 0.0);
      OpenCV.Core.Float32_Access.Set (Transform, 0, 2, 0.0);
      OpenCV.Core.Float32_Access.Set (Transform, 1, 0, 0.0);
      OpenCV.Core.Float32_Access.Set (Transform, 1, 1, 1.0);
      OpenCV.Core.Float32_Access.Set (Transform, 1, 2, 0.0);
      return Transform;
   end Identity_Float32;

   function Identity_Float64 return OpenCV.Core.Mat is
      Transform : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float64, 1));
   begin
      OpenCV.Core.Float64_Access.Set (Transform, 0, 0, 1.0);
      OpenCV.Core.Float64_Access.Set (Transform, 0, 1, 0.0);
      OpenCV.Core.Float64_Access.Set (Transform, 0, 2, 0.0);
      OpenCV.Core.Float64_Access.Set (Transform, 1, 0, 0.0);
      OpenCV.Core.Float64_Access.Set (Transform, 1, 1, 1.0);
      OpenCV.Core.Float64_Access.Set (Transform, 1, 2, 0.0);
      return Transform;
   end Identity_Float64;

   function Translate_X_Float32
     (Shift : OpenCV.Core.Float32_Value) return OpenCV.Core.Mat
   is
      Transform : OpenCV.Core.Mat := Identity_Float32;
   begin
      OpenCV.Core.Float32_Access.Set (Transform, 0, 2, Shift);
      return Transform;
   end Translate_X_Float32;

   procedure Identity_Rebinds_Destination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Transform   : constant OpenCV.Core.Mat := Identity_Float32;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Warp_Affine
        (Source, Transform, Destination, (Width => 4, Height => 3));

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 4
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "identity Warp_Affine must rebind Destination to 3x4 UInt8 C1");

      for Row in 0 .. Source.Rows - 1 loop
         for Column in 0 .. Source.Columns - 1 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Destination, Row, Column)
               = OpenCV.Core.UInt8_Access.Get (Source, Row, Column),
               "identity Warp_Affine must preserve unique UInt8 pixels");
         end loop;
      end loop;
   end Identity_Rebinds_Destination;

   procedure Nearest_Integer_Translation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Transform   : constant OpenCV.Core.Mat := Translate_X_Float32 (1.0);
      Destination : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Destination,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Nearest_Neighbor,
         OpenCV.Image_Processing.Source_To_Destination,
         OpenCV.Core.Constant_Border,
         (others => 0.0));

      for Row in 0 .. 2 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Destination, Row, 0) = 0,
            "forward +1 X translation must zero-fill the left column");
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Destination, Row, 1)
            = OpenCV.Core.UInt8_Access.Get (Source, Row, 0)
            and then OpenCV.Core.UInt8_Access.Get (Destination, Row, 2)
                     = OpenCV.Core.UInt8_Access.Get (Source, Row, 1),
            "forward +1 X translation must shift Source one pixel right");
      end loop;
   end Nearest_Integer_Translation;

   procedure Nonzero_Constant_Border (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Transform   : constant OpenCV.Core.Mat := Translate_X_Float32 (1.0);
      Destination : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Destination,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Nearest_Neighbor,
         OpenCV.Image_Processing.Source_To_Destination,
         OpenCV.Core.Constant_Border,
         (Component_0 => 37.0, others => 0.0));

      for Row in 0 .. 2 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Destination, Row, 0) = 37,
            "Constant_Border must fill exposed pixels with Component_0");
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Destination, Row, 1)
            = OpenCV.Core.UInt8_Access.Get (Source, Row, 0),
            "Constant_Border must still copy in-range donor pixels");
      end loop;
   end Nonzero_Constant_Border;

   procedure Replicate_Border_Ignores_Value (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Transform   : constant OpenCV.Core.Mat := Translate_X_Float32 (1.0);
      Destination : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Destination,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Nearest_Neighbor,
         OpenCV.Image_Processing.Source_To_Destination,
         OpenCV.Core.Replicate,
         (Component_0 => 99.0, others => 0.0));

      for Row in 0 .. 2 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Destination, Row, 0)
            = OpenCV.Core.UInt8_Access.Get (Source, Row, 0),
            "Replicate must copy the left Source column, not Border_Value");
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Destination, Row, 1)
            = OpenCV.Core.UInt8_Access.Get (Source, Row, 0),
            "Replicate +1 X translation must still shift remaining pixels");
      end loop;
   end Replicate_Border_Ignores_Value;

   procedure Inverse_Mapping_Reverses_Translation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Transform : constant OpenCV.Core.Mat := Translate_X_Float32 (1.0);
      Forward   : OpenCV.Core.Mat;
      Inverse   : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Forward,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Nearest_Neighbor,
         OpenCV.Image_Processing.Source_To_Destination);
      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Inverse,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Nearest_Neighbor,
         OpenCV.Image_Processing.Destination_To_Source);

      for Row in 0 .. 2 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Forward, Row, 0) = 0
            and then OpenCV.Core.UInt8_Access.Get (Forward, Row, 1)
                     = OpenCV.Core.UInt8_Access.Get (Source, Row, 0),
            "Source_To_Destination +1 X must shift right");
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Inverse, Row, 0)
            = OpenCV.Core.UInt8_Access.Get (Source, Row, 1)
            and then OpenCV.Core.UInt8_Access.Get (Inverse, Row, 1)
                     = OpenCV.Core.UInt8_Access.Get (Source, Row, 2)
            and then OpenCV.Core.UInt8_Access.Get (Inverse, Row, 2) = 0,
            "Destination_To_Source +1 X must shift left");
      end loop;
   end Inverse_Mapping_Reverses_Translation;

   procedure Linear_Fractional_Transform (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
      Transform   : constant OpenCV.Core.Mat := Translate_X_Float32 (0.5);
      Linear_Out  : OpenCV.Core.Mat;
      Nearest_Out : OpenCV.Core.Mat;
      Linear_Mid  : OpenCV.Core.Float32_Value;
      Nearest_Mid : OpenCV.Core.Float32_Value;
   begin
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 0.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 1, 10.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 2, 20.0);

      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Linear_Out,
         (Width => 3, Height => 1),
         OpenCV.Image_Processing.Linear);
      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Nearest_Out,
         (Width => 3, Height => 1),
         OpenCV.Image_Processing.Nearest_Neighbor);

      AUnit.Assertions.Assert
        (Linear_Out.Depth = OpenCV.Core.Float32
         and then Linear_Out.Channels = 1,
         "Linear Warp_Affine must preserve Float32 C1");

      Linear_Mid := OpenCV.Core.Float32_Access.Get (Linear_Out, 0, 1);
      Nearest_Mid := OpenCV.Core.Float32_Access.Get (Nearest_Out, 0, 1);
      AUnit.Assertions.Assert
        (Linear_Mid > 0.0 and then Linear_Mid < 10.0,
         "half-pixel Linear warp must interpolate between adjacent donors");
      AUnit.Assertions.Assert
        (not Nearly_Equal (Linear_Mid, Nearest_Mid, 1.0E-3),
         "Linear half-pixel warp must differ from Nearest_Neighbor");
   end Linear_Fractional_Transform;

   procedure Float64_Transform_Works (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Transform   : constant OpenCV.Core.Mat := Identity_Float64;
      Destination : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Destination,
         (Width => 3, Height => 2),
         OpenCV.Image_Processing.Nearest_Neighbor);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1
         and then Destination.Rows = 2
         and then Destination.Columns = 3,
         "Float64 Transform must not change Destination depth");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0)
         = OpenCV.Core.UInt8_Access.Get (Source, 0, 0),
         "Float64 identity Transform must preserve Source pixels");
   end Float64_Transform_Works;

   procedure Supported_Source_Depths (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Transform : constant OpenCV.Core.Mat := Identity_Float32;

      procedure Check (Source : in out OpenCV.Core.Mat) is
         Destination : OpenCV.Core.Mat;
      begin
         OpenCV.Core.Set_To (Source, (others => 7.0));
         OpenCV.Image_Processing.Warp_Affine
           (Source,
            Transform,
            Destination,
            (Width => 2, Height => 2),
            OpenCV.Image_Processing.Nearest_Neighbor);
         AUnit.Assertions.Assert
           (Destination.Rows = 2
            and then Destination.Columns = 2
            and then Destination.Depth = Source.Depth
            and then Destination.Channels = Source.Channels,
            "identity Warp_Affine must preserve each supported Source type");
      end Check;

      U8  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      U16 : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 2));
      I16 : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int16, 1));
      F32 : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      F64 : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float64, 3));
   begin
      Check (U8);
      Check (U16);
      Check (I16);
      Check (F32);
      Check (F64);
   end Supported_Source_Depths;

   procedure C3_Constant_Border_Components (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Transform   : constant OpenCV.Core.Mat := Translate_X_Float32 (1.0);
      Destination : OpenCV.Core.Mat;
      Border      : OpenCV.Core.UInt8_Vec3.Vector;
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 0, (1, 2, 3));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 1, (4, 5, 6));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 0, (7, 8, 9));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 1, (10, 11, 12));
      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Destination,
         (Width => 2, Height => 2),
         OpenCV.Image_Processing.Nearest_Neighbor,
         OpenCV.Image_Processing.Source_To_Destination,
         OpenCV.Core.Constant_Border,
         (Component_0 => 10.0,
          Component_1 => 20.0,
          Component_2 => 30.0,
          Component_3 => 99.0));

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 3,
         "C3 Warp_Affine must remain UInt8 C3");
      Border := OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 0);
      AUnit.Assertions.Assert
        (Border = (10, 20, 30),
         "C3 Constant_Border must transmit Scalar components 0..2");
   end C3_Constant_Border_Components;

   procedure Output_Size_Rebinds_Destination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Transform   : constant OpenCV.Core.Mat := Identity_Float32;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.Float32, 2));
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Warp_Affine
        (Source, Transform, Destination, (Width => 2, Height => 5));

      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 2
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "Warp_Affine must rebind Destination to the requested Output_Size");
   end Output_Size_Rebinds_Destination;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source   : OpenCV.Core.Mat;
      Empty_Xform    : OpenCV.Core.Mat;
      Three_D        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int8_Source    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int8, 1));
      Int32_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int32, 1));
      Float16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float16, 1));
      Five_Channel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 5));
      Valid_Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Valid_Xform    : OpenCV.Core.Mat := Identity_Float32;
      Square_Xform   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Short_Xform    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Multi_Xform    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 2));
      UInt8_Xform    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Destination    : OpenCV.Core.Mat;
      Shared         : OpenCV.Core.Mat;

      procedure Empty_Src is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Empty_Source, Valid_Xform, Destination, (Width => 3, Height => 3));
      end Empty_Src;

      procedure Three_D_Src is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Three_D, Valid_Xform, Destination, (Width => 3, Height => 3));
      end Three_D_Src;

      procedure Int8_Src is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Int8_Source, Valid_Xform, Destination, (Width => 3, Height => 3));
      end Int8_Src;

      procedure Int32_Src is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Int32_Source, Valid_Xform, Destination, (Width => 3, Height => 3));
      end Int32_Src;

      procedure Float16_Src is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Float16_Source,
            Valid_Xform,
            Destination,
            (Width => 3, Height => 3));
      end Float16_Src;

      procedure Five_Ch is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Five_Channel, Valid_Xform, Destination, (Width => 3, Height => 3));
      end Five_Ch;

      procedure Empty_Transform is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Empty_Xform, Destination, (Width => 3, Height => 3));
      end Empty_Transform;

      procedure Three_D_Transform is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Three_D, Destination, (Width => 3, Height => 3));
      end Three_D_Transform;

      procedure Square_Transform is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source,
            Square_Xform,
            Destination,
            (Width => 3, Height => 3));
      end Square_Transform;

      procedure Short_Transform is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Short_Xform, Destination, (Width => 3, Height => 3));
      end Short_Transform;

      procedure Multi_Transform is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Multi_Xform, Destination, (Width => 3, Height => 3));
      end Multi_Transform;

      procedure UInt8_Transform is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, UInt8_Xform, Destination, (Width => 3, Height => 3));
      end UInt8_Transform;

      procedure Zero_Width is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Valid_Xform, Destination, (Width => 0, Height => 3));
      end Zero_Width;

      procedure Zero_Height is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Valid_Xform, Destination, (Width => 3, Height => 0));
      end Zero_Height;

      procedure Cubic_Interp is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source,
            Valid_Xform,
            Destination,
            (Width => 3, Height => 3),
            OpenCV.Image_Processing.Cubic);
      end Cubic_Interp;

      procedure Area_Interp is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source,
            Valid_Xform,
            Destination,
            (Width => 3, Height => 3),
            OpenCV.Image_Processing.Area);
      end Area_Interp;

      procedure Lanczos_Interp is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source,
            Valid_Xform,
            Destination,
            (Width => 3, Height => 3),
            OpenCV.Image_Processing.Lanczos_4);
      end Lanczos_Interp;

      procedure Reflect_Border is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source,
            Valid_Xform,
            Destination,
            (Width => 3, Height => 3),
            Border => OpenCV.Core.Reflect);
      end Reflect_Border;

      procedure Reflect_101_Border is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source,
            Valid_Xform,
            Destination,
            (Width => 3, Height => 3),
            Border => OpenCV.Core.Reflect_101);
      end Reflect_101_Border;

      procedure Wrap_Border is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source,
            Valid_Xform,
            Destination,
            (Width => 3, Height => 3),
            Border => OpenCV.Core.Wrap);
      end Wrap_Border;

      procedure Alias_Source is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source,
            Valid_Xform,
            Valid_Source,
            (Width => 3, Height => 3));
      end Alias_Source;

      procedure Alias_Transform is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Valid_Xform, Valid_Xform, (Width => 3, Height => 3));
      end Alias_Transform;

      procedure Shared_Source_Data is
      begin
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Valid_Xform, Shared, (Width => 3, Height => 3));
      end Shared_Source_Data;

      procedure Nan_Transform is
         pragma Suppress (Validity_Check);
         Nan_Xform : OpenCV.Core.Mat := Identity_Float32;
         Value     : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (NaN_Bits_32);
         OpenCV.Core.Float32_Access.Set (Nan_Xform, 0, 2, Value);
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Nan_Xform, Destination, (Width => 3, Height => 3));
      end Nan_Transform;

      procedure Inf_Transform is
         pragma Suppress (Validity_Check);
         Inf_Xform : OpenCV.Core.Mat := Identity_Float64;
         Value     : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Inf_Bits_64);
         OpenCV.Core.Float64_Access.Set (Inf_Xform, 1, 2, Value);
         OpenCV.Image_Processing.Warp_Affine
           (Valid_Source, Inf_Xform, Destination, (Width => 3, Height => 3));
      end Inf_Transform;
   begin
      Fill_Unique_UInt8 (Valid_Source);
      Shared := Valid_Source;
      Assert_Raises_OpenCV_Error
        (Empty_Src'Access, "Warp_Affine must reject an empty Source");
      Assert_Raises_OpenCV_Error
        (Three_D_Src'Access, "Warp_Affine must reject a 3-D Source");
      Assert_Raises_OpenCV_Error
        (Int8_Src'Access, "Warp_Affine must reject Int8");
      Assert_Raises_OpenCV_Error
        (Int32_Src'Access, "Warp_Affine must reject Int32");
      Assert_Raises_OpenCV_Error
        (Float16_Src'Access, "Warp_Affine must reject Float16");
      Assert_Raises_OpenCV_Error
        (Five_Ch'Access, "Warp_Affine must reject more than 4 channels");
      Assert_Raises_OpenCV_Error
        (Empty_Transform'Access, "Warp_Affine must reject an empty Transform");
      Assert_Raises_OpenCV_Error
        (Three_D_Transform'Access, "Warp_Affine must reject a 3-D Transform");
      Assert_Raises_OpenCV_Error
        (Square_Transform'Access, "Warp_Affine must reject a 3x3 Transform");
      Assert_Raises_OpenCV_Error
        (Short_Transform'Access, "Warp_Affine must reject a 2x2 Transform");
      Assert_Raises_OpenCV_Error
        (Multi_Transform'Access,
         "Warp_Affine must reject a multi-channel Transform");
      Assert_Raises_OpenCV_Error
        (UInt8_Transform'Access, "Warp_Affine must reject a UInt8 Transform");
      Assert_Raises_OpenCV_Error
        (Zero_Width'Access, "Warp_Affine must reject zero Width");
      Assert_Raises_OpenCV_Error
        (Zero_Height'Access, "Warp_Affine must reject zero Height");
      Assert_Raises_OpenCV_Error
        (Cubic_Interp'Access, "Warp_Affine must reject Cubic");
      Assert_Raises_OpenCV_Error
        (Area_Interp'Access, "Warp_Affine must reject Area");
      Assert_Raises_OpenCV_Error
        (Lanczos_Interp'Access, "Warp_Affine must reject Lanczos_4");
      Assert_Raises_OpenCV_Error
        (Reflect_Border'Access, "Warp_Affine must reject Reflect");
      Assert_Raises_OpenCV_Error
        (Reflect_101_Border'Access, "Warp_Affine must reject Reflect_101");
      Assert_Raises_OpenCV_Error
        (Wrap_Border'Access, "Warp_Affine must reject Wrap");
      Assert_Raises_OpenCV_Error
        (Alias_Source'Access,
         "Warp_Affine must reject Destination aliased with Source");
      Assert_Raises_OpenCV_Error
        (Alias_Transform'Access,
         "Warp_Affine must reject Destination aliased with Transform");
      Assert_Raises_OpenCV_Error
        (Shared_Source_Data'Access,
         "Warp_Affine must reject Destination sharing Source storage");
      Assert_Raises_OpenCV_Error
        (Nan_Transform'Access, "Warp_Affine must reject a NaN Transform");
      Assert_Raises_OpenCV_Error
        (Inf_Transform'Access,
         "Warp_Affine must reject an infinite Transform");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Transform    : OpenCV.Core.Mat := Identity_Float32;
      Empty_Mat    : OpenCV.Core.Mat;
      Three_D      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int32_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int32, 1));
      Square_Xform : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      UInt8_Xform  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Nan_Xform    : OpenCV.Core.Mat := Identity_Float32;

      procedure Check
        (Source        : OpenCV.Core.Mat;
         Matrix        : OpenCV.Core.Mat;
         Width         : Interfaces.Integer_32;
         Height        : Interfaces.Integer_32;
         Interpolation : Interfaces.Integer_32;
         Mapping       : Interfaces.Integer_32;
         Border        : Interfaces.Integer_32;
         Diagnostic    : String)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Transform_Input
              (Transform_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Warp_Affine
                      (Source_Handle,
                       Transform_Handle,
                       Destination_Handle,
                       Width,
                       Height,
                       Interpolation,
                       Mapping,
                       Border,
                       0.0,
                       0.0,
                       0.0,
                       0.0);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Transform_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Matrix, Transform_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Warp_Affine C ABI must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Warp_Affine C ABI input must identify " & Diagnostic);
      end Check;

      procedure Check_Aliased_Source is
         Status : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Transform_Input
              (Transform_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Warp_Affine
                      (Source_Handle,
                       Transform_Handle,
                       Destination_Handle,
                       3,
                       3,
                       C_API.Warp_Interpolation_Nearest,
                       C_API.Warp_Mapping_Source_To_Destination,
                       C_API.Border_Constant,
                       0.0,
                       0.0,
                       0.0,
                       0.0);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (UInt8_Source, Output'Access);
            end Transform_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Transform, Transform_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "aliased Destination/Source C ABI must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "share storage")
            /= 0,
            "aliased Destination/Source C ABI must identify shared storage");
      end Check_Aliased_Source;

      procedure Check_Aliased_Transform is
         Status : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Transform_Input
              (Transform_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Warp_Affine
                      (Source_Handle,
                       Transform_Handle,
                       Destination_Handle,
                       3,
                       3,
                       C_API.Warp_Interpolation_Nearest,
                       C_API.Warp_Mapping_Source_To_Destination,
                       C_API.Border_Constant,
                       0.0,
                       0.0,
                       0.0,
                       0.0);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Transform, Output'Access);
            end Transform_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Transform, Transform_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "aliased Destination/Transform C ABI must return"
            & " invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "share storage")
            /= 0,
            "aliased Destination/Transform C ABI must identify"
            & " shared storage");
      end Check_Aliased_Transform;

      procedure Check_Success
        (Interpolation : Interfaces.Integer_32;
         Mapping       : Interfaces.Integer_32;
         Border        : Interfaces.Integer_32)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Transform_Input
              (Transform_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Warp_Affine
                      (Source_Handle,
                       Transform_Handle,
                       Destination_Handle,
                       3,
                       3,
                       Interpolation,
                       Mapping,
                       Border,
                       0.0,
                       0.0,
                       0.0,
                       0.0);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Transform_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Transform, Transform_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "valid Warp_Affine C ABI call must succeed");
         AUnit.Assertions.Assert
           (Destination.Rows = 3 and then Destination.Columns = 3,
            "valid Warp_Affine C ABI call must produce the requested size");
      end Check_Success;
   begin
      Fill_Unique_UInt8 (UInt8_Source);
      declare
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (NaN_Bits_32);
         OpenCV.Core.Float32_Access.Set (Nan_Xform, 0, 2, Value);
      end;
      Check (UInt8_Source, Transform, 3, 3, -1, 0, 0, "interpolation");
      Check (UInt8_Source, Transform, 3, 3, 2, 0, 0, "interpolation");
      Check (UInt8_Source, Transform, 3, 3, 99, 0, 0, "interpolation");
      Check (UInt8_Source, Transform, 3, 3, 0, -1, 0, "mapping");
      Check (UInt8_Source, Transform, 3, 3, 0, 2, 0, "mapping");
      Check (UInt8_Source, Transform, 3, 3, 0, 99, 0, "mapping");
      Check (UInt8_Source, Transform, 3, 3, 0, 0, 99, "border");
      Check
        (UInt8_Source, Transform, 3, 3, 0, 0, C_API.Border_Reflect, "border");
      Check (UInt8_Source, Transform, 0, 3, 0, 0, 0, "output size");
      Check (UInt8_Source, Transform, 3, 0, 0, 0, 0, "output size");
      Check (Empty_Mat, Transform, 3, 3, 0, 0, 0, "source");
      Check (Three_D, Transform, 3, 3, 0, 0, 0, "two-dimensional");
      Check (Int32_Source, Transform, 3, 3, 0, 0, 0, "CV_8U");
      Check (UInt8_Source, Square_Xform, 3, 3, 0, 0, 0, "2x3");
      Check (UInt8_Source, UInt8_Xform, 3, 3, 0, 0, 0, "CV_32F");
      Check (UInt8_Source, Nan_Xform, 3, 3, 0, 0, 0, "finite");
      Check_Aliased_Source;
      Check_Aliased_Transform;
      Check_Success
        (C_API.Warp_Interpolation_Nearest,
         C_API.Warp_Mapping_Source_To_Destination,
         C_API.Border_Constant);
      Check_Success
        (C_API.Warp_Interpolation_Linear,
         C_API.Warp_Mapping_Destination_To_Source,
         C_API.Border_Replicate);
   end C_ABI_Rejects_Malformed_Inputs;

   procedure C_ABI_Accepts_Max_Finite_Float64_Coefficient
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Transform : OpenCV.Core.Mat := Identity_Float64;

      procedure Check (Coefficient : OpenCV.Core.Float64_Value) is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Transform_Input
              (Transform_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Warp_Affine
                      (Source_Handle,
                       Transform_Handle,
                       Destination_Handle,
                       3,
                       3,
                       C_API.Warp_Interpolation_Nearest,
                       C_API.Warp_Mapping_Source_To_Destination,
                       C_API.Border_Constant,
                       0.0,
                       0.0,
                       0.0,
                       0.0);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Transform_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Transform, Transform_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Float64_Access.Set (Transform, 0, 2, Coefficient);
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (not (Status = C_API.Error_Invalid_Argument
                 and then Ada.Strings.Fixed.Index
                            (C_API.Last_Error_Message, "finite values")
                          /= 0),
            "max-finite Float64 Transform must not be rejected as nonfinite");
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "max-finite Float64 translation must pass the binding validator");
      end Check;
   begin
      Fill_Unique_UInt8 (Source);
      declare
         pragma Suppress (Validity_Check);
         Max_Finite     : OpenCV.Core.Float64_Value;
         Neg_Max_Finite : OpenCV.Core.Float64_Value;
      begin
         Max_Finite := Bits_To_Float64 (Max_Finite_Bits_64);
         Neg_Max_Finite := Bits_To_Float64 (Neg_Max_Finite_Bits_64);
         Check (Max_Finite);
         Check (Neg_Max_Finite);
      end;
   end C_ABI_Accepts_Max_Finite_Float64_Coefficient;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine identity rebinds Destination",
            Identity_Rebinds_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine nearest integer translation",
            Nearest_Integer_Translation'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine nonzero Constant_Border",
            Nonzero_Constant_Border'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine Replicate ignores Border_Value",
            Replicate_Border_Ignores_Value'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine inverse mapping reverses translation",
            Inverse_Mapping_Reverses_Translation'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine Linear fractional transform interpolates",
            Linear_Fractional_Transform'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine Float64 Transform preserves UInt8 destination",
            Float64_Transform_Works'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine supports the documented source depths",
            Supported_Source_Depths'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine C3 Constant_Border transmits Scalar components",
            C3_Constant_Border_Components'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine Output_Size rebinds Destination",
            Output_Size_Rebinds_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Warp_Affine C ABI accepts max-finite Float64 Transform",
            C_ABI_Accepts_Max_Finite_Float64_Coefficient'Access));
      return Result'Access;
   end Suite;

end Warp_Affine_Tests;
