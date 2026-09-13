with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Remap_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.UInt8_Vec3.Vector;

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

   NaN_Bits_32 : constant Interfaces.Unsigned_32 := 16#7FC0_0000#;
   Inf_Bits_32 : constant Interfaces.Unsigned_32 := 16#7F80_0000#;

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

   function Identity_Map
     (Rows : Natural; Columns : Natural) return OpenCV.Core.Mat
   is
      Map_X : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Columns, (OpenCV.Core.Float32, 1));
   begin
      for Row in 0 .. Rows - 1 loop
         for Column in 0 .. Columns - 1 loop
            OpenCV.Core.Float32_Access.Set
              (Map_X, Row, Column, OpenCV.Core.Float32_Value (Column));
         end loop;
      end loop;
      return Map_X;
   end Identity_Map;

   function Identity_Map_Y
     (Rows : Natural; Columns : Natural) return OpenCV.Core.Mat
   is
      Map_Y : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Columns, (OpenCV.Core.Float32, 1));
   begin
      for Row in 0 .. Rows - 1 loop
         for Column in 0 .. Columns - 1 loop
            OpenCV.Core.Float32_Access.Set
              (Map_Y, Row, Column, OpenCV.Core.Float32_Value (Row));
         end loop;
      end loop;
      return Map_Y;
   end Identity_Map_Y;

   procedure Identity_Nearest_Rebinds_Destination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Map_X       : constant OpenCV.Core.Mat := Identity_Map (3, 4);
      Map_Y       : constant OpenCV.Core.Mat := Identity_Map_Y (3, 4);
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Remap
        (Source,
         Map_X,
         Map_Y,
         Destination,
         OpenCV.Image_Processing.Nearest_Neighbor);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 4
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "identity Remap must rebind Destination to 3x4 UInt8 C1");

      for Row in 0 .. Source.Rows - 1 loop
         for Column in 0 .. Source.Columns - 1 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Destination, Row, Column)
               = OpenCV.Core.UInt8_Access.Get (Source, Row, Column),
               "identity Remap must preserve unique UInt8 pixels");
         end loop;
      end loop;
   end Identity_Nearest_Rebinds_Destination;

   procedure Nearest_Horizontal_Flip (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Map_X       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));
      Map_Y       : constant OpenCV.Core.Mat := Identity_Map_Y (2, 3);
      Destination : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Source);
      for Row in 0 .. 1 loop
         OpenCV.Core.Float32_Access.Set (Map_X, Row, 0, 2.0);
         OpenCV.Core.Float32_Access.Set (Map_X, Row, 1, 1.0);
         OpenCV.Core.Float32_Access.Set (Map_X, Row, 2, 0.0);
      end loop;

      OpenCV.Image_Processing.Remap
        (Source,
         Map_X,
         Map_Y,
         Destination,
         OpenCV.Image_Processing.Nearest_Neighbor);

      for Row in 0 .. 1 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Destination, Row, 0)
            = OpenCV.Core.UInt8_Access.Get (Source, Row, 2)
            and then OpenCV.Core.UInt8_Access.Get (Destination, Row, 1)
                     = OpenCV.Core.UInt8_Access.Get (Source, Row, 1)
            and then OpenCV.Core.UInt8_Access.Get (Destination, Row, 2)
                     = OpenCV.Core.UInt8_Access.Get (Source, Row, 0),
            "horizontal flip Remap must reverse Source columns");
      end loop;
   end Nearest_Horizontal_Flip;

   procedure Linear_Interpolates_Fractional_Coordinates (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
      Map_X       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Map_Y       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Linear_Out  : OpenCV.Core.Mat;
      Nearest_Out : OpenCV.Core.Mat;
      Linear_Mid  : OpenCV.Core.Float32_Value;
      Nearest_Mid : OpenCV.Core.Float32_Value;
   begin
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 0.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 1, 10.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 2, 20.0);
      OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, 0.5);
      OpenCV.Core.Float32_Access.Set (Map_Y, 0, 0, 0.0);

      OpenCV.Image_Processing.Remap
        (Source, Map_X, Map_Y, Linear_Out, OpenCV.Image_Processing.Linear);
      OpenCV.Image_Processing.Remap
        (Source,
         Map_X,
         Map_Y,
         Nearest_Out,
         OpenCV.Image_Processing.Nearest_Neighbor);

      Linear_Mid := OpenCV.Core.Float32_Access.Get (Linear_Out, 0, 0);
      Nearest_Mid := OpenCV.Core.Float32_Access.Get (Nearest_Out, 0, 0);
      AUnit.Assertions.Assert
        (Linear_Mid > 0.0 and then Linear_Mid < 10.0,
         "half-pixel Linear Remap must interpolate between adjacent donors");
      AUnit.Assertions.Assert
        (not Nearly_Equal (Linear_Mid, Nearest_Mid, 1.0E-3),
         "Linear half-pixel Remap must differ from Nearest_Neighbor");
   end Linear_Interpolates_Fractional_Coordinates;
   procedure Accepts_Cubic_And_Lanczos (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Map_X   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Map_Y   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Cubic   : OpenCV.Core.Mat;
      Lanczos : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 17.0));
      OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, 2.0);
      OpenCV.Core.Float32_Access.Set (Map_Y, 0, 0, 2.0);

      OpenCV.Image_Processing.Remap
        (Source, Map_X, Map_Y, Cubic, OpenCV.Image_Processing.Cubic);
      OpenCV.Image_Processing.Remap
        (Source, Map_X, Map_Y, Lanczos, OpenCV.Image_Processing.Lanczos_4);

      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Cubic, 0, 0) = 17
         and then OpenCV.Core.UInt8_Access.Get (Lanczos, 0, 0) = 17,
         "Cubic and Lanczos_4 Remap must preserve a constant interior value");
   end Accepts_Cubic_And_Lanczos;

   procedure Output_Geometry_Follows_Maps (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.UInt8, 1));
      Map_X       : constant OpenCV.Core.Mat := Identity_Map (2, 3);
      Map_Y       : constant OpenCV.Core.Mat := Identity_Map_Y (2, 3);
      Destination : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Source);
      OpenCV.Image_Processing.Remap
        (Source,
         Map_X,
         Map_Y,
         Destination,
         OpenCV.Image_Processing.Nearest_Neighbor);

      AUnit.Assertions.Assert
        (Destination.Rows = 2
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "Remap Destination geometry must follow the maps, not Source");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 1, 2)
         = OpenCV.Core.UInt8_Access.Get (Source, 1, 2),
         "identity maps smaller than Source must sample matching donors");
   end Output_Geometry_Follows_Maps;

   procedure Supports_Documented_Source_Depths (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Map_X : constant OpenCV.Core.Mat := Identity_Map (2, 2);
      Map_Y : constant OpenCV.Core.Mat := Identity_Map_Y (2, 2);

      procedure Check (Source : in out OpenCV.Core.Mat) is
         Destination : OpenCV.Core.Mat;
      begin
         OpenCV.Core.Set_To (Source, (others => 7.0));
         OpenCV.Image_Processing.Remap
           (Source,
            Map_X,
            Map_Y,
            Destination,
            OpenCV.Image_Processing.Nearest_Neighbor);
         AUnit.Assertions.Assert
           (Destination.Rows = 2
            and then Destination.Columns = 2
            and then Destination.Depth = Source.Depth
            and then Destination.Channels = Source.Channels,
            "identity Remap must preserve each supported Source type");
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
   end Supports_Documented_Source_Depths;

   procedure C3_Constant_Border_Components (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Map_X       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Map_Y       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
      Border      : OpenCV.Core.UInt8_Vec3.Vector;
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 0, (1, 2, 3));
      OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, -1.0);
      OpenCV.Core.Float32_Access.Set (Map_Y, 0, 0, 0.0);
      OpenCV.Image_Processing.Remap
        (Source,
         Map_X,
         Map_Y,
         Destination,
         OpenCV.Image_Processing.Nearest_Neighbor,
         OpenCV.Core.Constant_Border,
         (Component_0 => 10.0,
          Component_1 => 20.0,
          Component_2 => 30.0,
          Component_3 => 99.0));

      Border := OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 0);
      AUnit.Assertions.Assert
        (Border = (10, 20, 30),
         "C3 Constant_Border must transmit Scalar components 0..2");
   end C3_Constant_Border_Components;

   procedure Supports_Nonconstant_Borders (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.UInt8, 1));
      Map_X  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Map_Y  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));

      function Sample
        (Kind : OpenCV.Core.Border_Kind) return Interfaces.Unsigned_8
      is
         Destination : OpenCV.Core.Mat;
      begin
         OpenCV.Image_Processing.Remap
           (Source,
            Map_X,
            Map_Y,
            Destination,
            OpenCV.Image_Processing.Nearest_Neighbor,
            Kind,
            (Component_0 => 99.0, others => 0.0));
         return OpenCV.Core.UInt8_Access.Get (Destination, 0, 0);
      end Sample;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 10);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 20);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 30);
      OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, -1.0);
      OpenCV.Core.Float32_Access.Set (Map_Y, 0, 0, 0.0);

      AUnit.Assertions.Assert
        (Sample (OpenCV.Core.Replicate) = 10,
         "Replicate at x=-1 must sample the left edge");
      AUnit.Assertions.Assert
        (Sample (OpenCV.Core.Reflect) = 10,
         "Reflect at x=-1 must sample Source column 0");
      AUnit.Assertions.Assert
        (Sample (OpenCV.Core.Reflect_101) = 20,
         "Reflect_101 at x=-1 must sample Source column 1");
      AUnit.Assertions.Assert
        (Sample (OpenCV.Core.Wrap) = 30,
         "Wrap at x=-1 must sample Source column 2");
   end Supports_Nonconstant_Borders;

   procedure Preserves_Source_And_Maps (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Map_X       : constant OpenCV.Core.Mat := Identity_Map (2, 2);
      Map_Y       : constant OpenCV.Core.Mat := Identity_Map_Y (2, 2);
      Destination : OpenCV.Core.Mat;
      Saved_Src   : Interfaces.Unsigned_8;
      Saved_X     : OpenCV.Core.Float32_Value;
      Saved_Y     : OpenCV.Core.Float32_Value;
   begin
      Fill_Unique_UInt8 (Source);
      Saved_Src := OpenCV.Core.UInt8_Access.Get (Source, 1, 1);
      Saved_X := OpenCV.Core.Float32_Access.Get (Map_X, 1, 0);
      Saved_Y := OpenCV.Core.Float32_Access.Get (Map_Y, 0, 1);
      OpenCV.Image_Processing.Remap
        (Source,
         Map_X,
         Map_Y,
         Destination,
         OpenCV.Image_Processing.Nearest_Neighbor);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 1, 1) = Saved_Src
         and then OpenCV.Core.Float32_Access.Get (Map_X, 1, 0) = Saved_X
         and then OpenCV.Core.Float32_Access.Get (Map_Y, 0, 1) = Saved_Y,
         "Remap must leave Source and maps unchanged");
   end Preserves_Source_And_Maps;

   procedure Rejects_Invalid_Public_Source_And_Map_Metadata
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Valid_Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Valid_X        : constant OpenCV.Core.Mat := Identity_Map (2, 2);
      Valid_Y        : constant OpenCV.Core.Mat := Identity_Map_Y (2, 2);
      Destination    : OpenCV.Core.Mat;
      Empty_Mat      : OpenCV.Core.Mat;
      Three_D        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int32_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int32, 1));
      Float16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float16, 1));
      Five_Channel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 5));
      UInt8_Map      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Multi_Map      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 2));
      Wide_Y         : constant OpenCV.Core.Mat := Identity_Map_Y (2, 3);
      Three_D_Map    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.Float32, 1));

      procedure Empty_Src is
      begin
         OpenCV.Image_Processing.Remap
           (Empty_Mat, Valid_X, Valid_Y, Destination);
      end Empty_Src;

      procedure Three_D_Src is
      begin
         OpenCV.Image_Processing.Remap
           (Three_D, Valid_X, Valid_Y, Destination);
      end Three_D_Src;

      procedure Int32_Src is
      begin
         OpenCV.Image_Processing.Remap
           (Int32_Source, Valid_X, Valid_Y, Destination);
      end Int32_Src;

      procedure Float16_Src is
      begin
         OpenCV.Image_Processing.Remap
           (Float16_Source, Valid_X, Valid_Y, Destination);
      end Float16_Src;

      procedure Five_Ch is
      begin
         OpenCV.Image_Processing.Remap
           (Five_Channel, Valid_X, Valid_Y, Destination);
      end Five_Ch;

      procedure Empty_Map is
      begin
         OpenCV.Image_Processing.Remap
           (Valid_Source, Empty_Mat, Valid_Y, Destination);
      end Empty_Map;

      procedure Three_D_Map_X is
      begin
         OpenCV.Image_Processing.Remap
           (Valid_Source, Three_D_Map, Valid_Y, Destination);
      end Three_D_Map_X;

      procedure UInt8_Map_X is
      begin
         OpenCV.Image_Processing.Remap
           (Valid_Source, UInt8_Map, Valid_Y, Destination);
      end UInt8_Map_X;

      procedure Multi_Map_X is
      begin
         OpenCV.Image_Processing.Remap
           (Valid_Source, Multi_Map, Valid_Y, Destination);
      end Multi_Map_X;

      procedure Mismatched_Maps is
      begin
         OpenCV.Image_Processing.Remap
           (Valid_Source, Valid_X, Wide_Y, Destination);
      end Mismatched_Maps;
   begin
      Fill_Unique_UInt8 (Valid_Source);
      Assert_Raises_OpenCV_Error
        (Empty_Src'Access, "Remap must reject an empty Source");
      Assert_Raises_OpenCV_Error
        (Three_D_Src'Access, "Remap must reject a 3-D Source");
      Assert_Raises_OpenCV_Error (Int32_Src'Access, "Remap must reject Int32");
      Assert_Raises_OpenCV_Error
        (Float16_Src'Access, "Remap must reject Float16");
      Assert_Raises_OpenCV_Error
        (Five_Ch'Access, "Remap must reject more than 4 channels");
      Assert_Raises_OpenCV_Error
        (Empty_Map'Access, "Remap must reject an empty map");
      Assert_Raises_OpenCV_Error
        (Three_D_Map_X'Access, "Remap must reject a 3-D map");
      Assert_Raises_OpenCV_Error
        (UInt8_Map_X'Access, "Remap must reject a non-Float32 map");
      Assert_Raises_OpenCV_Error
        (Multi_Map_X'Access, "Remap must reject a multi-channel map");
      Assert_Raises_OpenCV_Error
        (Mismatched_Maps'Access, "Remap must reject mismatched map geometry");
   end Rejects_Invalid_Public_Source_And_Map_Metadata;

   procedure Rejects_Area_Nonfinite_Maps_And_Size_Limit (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Valid_Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Valid_X      : constant OpenCV.Core.Mat := Identity_Map (2, 2);
      Valid_Y      : constant OpenCV.Core.Mat := Identity_Map_Y (2, 2);
      Destination  : OpenCV.Core.Mat;
      Nan_X        : OpenCV.Core.Mat := Identity_Map (2, 2);
      Inf_Y        : OpenCV.Core.Mat := Identity_Map_Y (2, 2);
      Wide_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 32_767, (OpenCV.Core.UInt8, 1));

      procedure Area_Interp is
      begin
         OpenCV.Image_Processing.Remap
           (Valid_Source,
            Valid_X,
            Valid_Y,
            Destination,
            OpenCV.Image_Processing.Area);
      end Area_Interp;

      procedure Nan_Map is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (NaN_Bits_32);
         OpenCV.Core.Float32_Access.Set (Nan_X, 0, 0, Value);
         OpenCV.Image_Processing.Remap
           (Valid_Source, Nan_X, Valid_Y, Destination);
      end Nan_Map;

      procedure Inf_Map is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (Inf_Bits_32);
         OpenCV.Core.Float32_Access.Set (Inf_Y, 0, 1, Value);
         OpenCV.Image_Processing.Remap
           (Valid_Source, Valid_X, Inf_Y, Destination);
      end Inf_Map;

      procedure Oversize is
         Tiny_X : constant OpenCV.Core.Mat := Identity_Map (1, 1);
         Tiny_Y : constant OpenCV.Core.Mat := Identity_Map_Y (1, 1);
      begin
         OpenCV.Image_Processing.Remap
           (Wide_Source, Tiny_X, Tiny_Y, Destination);
      end Oversize;
   begin
      Fill_Unique_UInt8 (Valid_Source);
      Assert_Raises_OpenCV_Error
        (Area_Interp'Access, "Remap must reject Area interpolation");
      Assert_Raises_OpenCV_Error
        (Nan_Map'Access, "Remap must reject a NaN Map_X");
      Assert_Raises_OpenCV_Error
        (Inf_Map'Access, "Remap must reject an infinite Map_Y");
      Assert_Raises_OpenCV_Error
        (Oversize'Access, "Remap must reject a 32767 dimension");
   end Rejects_Area_Nonfinite_Maps_And_Size_Limit;

   procedure Rejects_Destination_Aliases (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Map_X  : OpenCV.Core.Mat := Identity_Map (2, 2);
      Map_Y  : OpenCV.Core.Mat := Identity_Map_Y (2, 2);
      Shared : OpenCV.Core.Mat;

      procedure Alias_Source is
      begin
         OpenCV.Image_Processing.Remap (Source, Map_X, Map_Y, Source);
      end Alias_Source;

      procedure Alias_Map_X is
      begin
         OpenCV.Image_Processing.Remap (Source, Map_X, Map_Y, Map_X);
      end Alias_Map_X;

      procedure Alias_Map_Y is
      begin
         OpenCV.Image_Processing.Remap (Source, Map_X, Map_Y, Map_Y);
      end Alias_Map_Y;

      procedure Shared_Source_Data is
      begin
         OpenCV.Image_Processing.Remap (Source, Map_X, Map_Y, Shared);
      end Shared_Source_Data;
   begin
      Fill_Unique_UInt8 (Source);
      Shared := Source;
      Assert_Raises_OpenCV_Error
        (Alias_Source'Access,
         "Remap must reject Destination aliased with Source");
      Assert_Raises_OpenCV_Error
        (Alias_Map_X'Access,
         "Remap must reject Destination aliased with Map_X");
      Assert_Raises_OpenCV_Error
        (Alias_Map_Y'Access,
         "Remap must reject Destination aliased with Map_Y");
      Assert_Raises_OpenCV_Error
        (Shared_Source_Data'Access,
         "Remap must reject Destination sharing Source storage");
   end Rejects_Destination_Aliases;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Map_X        : constant OpenCV.Core.Mat := Identity_Map (2, 2);
      Map_Y        : constant OpenCV.Core.Mat := Identity_Map_Y (2, 2);
      Empty_Mat    : OpenCV.Core.Mat;
      UInt8_Map    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Nan_Map      : OpenCV.Core.Mat := Identity_Map (2, 2);

      procedure Check
        (Source        : OpenCV.Core.Mat;
         X_Map         : OpenCV.Core.Mat;
         Y_Map         : OpenCV.Core.Mat;
         Interpolation : Interfaces.Integer_32;
         Border        : Interfaces.Integer_32;
         Diagnostic    : String)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Map_X_Input
              (Map_X_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Map_Y_Input
                 (Map_Y_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
               is
                  procedure Output
                    (Destination_Handle :
                       OpenCV.Core.Module_Interop.Output_Mat_Handle) is
                  begin
                     Status :=
                       C_API.Remap
                         (Source_Handle,
                          Map_X_Handle,
                          Map_Y_Handle,
                          Destination_Handle,
                          Interpolation,
                          Border,
                          0.0,
                          0.0,
                          0.0,
                          0.0);
                  end Output;
               begin
                  OpenCV.Core.Module_Interop.With_Output_Handle
                    (Destination, Output'Access);
               end Map_Y_Input;
            begin
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Y_Map, Map_Y_Input'Access);
            end Map_X_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (X_Map, Map_X_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Remap C ABI must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Remap C ABI input must identify " & Diagnostic);
      end Check;

      procedure Check_Aliased_Source is
         Status : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Map_X_Input
              (Map_X_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Map_Y_Input
                 (Map_Y_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
               is
                  procedure Output
                    (Destination_Handle :
                       OpenCV.Core.Module_Interop.Output_Mat_Handle) is
                  begin
                     Status :=
                       C_API.Remap
                         (Source_Handle,
                          Map_X_Handle,
                          Map_Y_Handle,
                          Destination_Handle,
                          C_API.Interpolation_Nearest_Neighbor,
                          C_API.Border_Constant,
                          0.0,
                          0.0,
                          0.0,
                          0.0);
                  end Output;
               begin
                  OpenCV.Core.Module_Interop.With_Output_Handle
                    (UInt8_Source, Output'Access);
               end Map_Y_Input;
            begin
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Map_Y, Map_Y_Input'Access);
            end Map_X_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Map_X, Map_X_Input'Access);
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

      procedure Check_Success
        (Interpolation : Interfaces.Integer_32; Border : Interfaces.Integer_32)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Map_X_Input
              (Map_X_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Map_Y_Input
                 (Map_Y_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
               is
                  procedure Output
                    (Destination_Handle :
                       OpenCV.Core.Module_Interop.Output_Mat_Handle) is
                  begin
                     Status :=
                       C_API.Remap
                         (Source_Handle,
                          Map_X_Handle,
                          Map_Y_Handle,
                          Destination_Handle,
                          Interpolation,
                          Border,
                          0.0,
                          0.0,
                          0.0,
                          0.0);
                  end Output;
               begin
                  OpenCV.Core.Module_Interop.With_Output_Handle
                    (Destination, Output'Access);
               end Map_Y_Input;
            begin
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Map_Y, Map_Y_Input'Access);
            end Map_X_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Map_X, Map_X_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success, "valid Remap C ABI call must succeed");
         AUnit.Assertions.Assert
           (Destination.Rows = 2 and then Destination.Columns = 2,
            "valid Remap C ABI call must produce map geometry");
      end Check_Success;
   begin
      Fill_Unique_UInt8 (UInt8_Source);
      declare
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (NaN_Bits_32);
         OpenCV.Core.Float32_Access.Set (Nan_Map, 0, 0, Value);
      end;
      Check (UInt8_Source, Map_X, Map_Y, -1, 0, "interpolation");
      Check
        (UInt8_Source,
         Map_X,
         Map_Y,
         C_API.Interpolation_Area,
         0,
         "interpolation");
      Check (UInt8_Source, Map_X, Map_Y, 0, 99, "border");
      Check (UInt8_Source, UInt8_Map, Map_Y, 0, 0, "CV_32FC1");
      Check (Empty_Mat, Map_X, Map_Y, 0, 0, "source");
      Check (UInt8_Source, Nan_Map, Map_Y, 0, 0, "finite");
      Check_Aliased_Source;
      Check_Success
        (C_API.Interpolation_Nearest_Neighbor, C_API.Border_Constant);
      Check_Success (C_API.Interpolation_Lanczos_4, C_API.Border_Wrap);
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Remap identity Nearest rebinds Destination",
            Identity_Nearest_Rebinds_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap Nearest performs horizontal flip",
            Nearest_Horizontal_Flip'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap Linear interpolates fractional coordinates",
            Linear_Interpolates_Fractional_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap accepts Cubic and Lanczos_4",
            Accepts_Cubic_And_Lanczos'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap output geometry follows map geometry",
            Output_Geometry_Follows_Maps'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap supports documented source depths",
            Supports_Documented_Source_Depths'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap C3 Constant_Border transmits Scalar components",
            C3_Constant_Border_Components'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap supports Replicate Reflect Reflect_101 and Wrap",
            Supports_Nonconstant_Borders'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap preserves Source and maps",
            Preserves_Source_And_Maps'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap rejects invalid public source and map metadata",
            Rejects_Invalid_Public_Source_And_Map_Metadata'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap rejects Area nonfinite maps and size limit",
            Rejects_Area_Nonfinite_Maps_And_Size_Limit'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap rejects Destination aliases",
            Rejects_Destination_Aliases'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap C ABI rejects malformed inputs and accepts valid selectors",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Remap_Tests;
