with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.UInt16_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Remap_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Float32_Value;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Image_Processing.Interpolation_Method;

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
     (Left, Right : OpenCV.Float32_Value; Tolerance : OpenCV.Float32_Value)
      return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Nearly_Equal;

   function Map_Component
     (Map : OpenCV.Core.Mat; Channel, Row, Column : Natural)
      return OpenCV.Float32_Value
   is
      Component : constant OpenCV.Core.Mat :=
        OpenCV.Core.Extract_Channel (Map, Channel);
   begin
      return OpenCV.Core.Float32_Access.Get (Component, Row, Column);
   end Map_Component;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Float32_Value);

   NaN_Bits_32     : constant Interfaces.Unsigned_32 := 16#7FC0_0000#;
   Inf_Bits_32     : constant Interfaces.Unsigned_32 := 16#7F80_0000#;
   Neg_Inf_Bits_32 : constant Interfaces.Unsigned_32 := 16#FF80_0000#;

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
              (Map_X, Row, Column, OpenCV.Float32_Value (Column));
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
              (Map_Y, Row, Column, OpenCV.Float32_Value (Row));
         end loop;
      end loop;
      return Map_Y;
   end Identity_Map_Y;

   procedure Map_Representations (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package IP renames OpenCV.Image_Processing;
      X                                        : OpenCV.Core.Mat :=
        Identity_Map (2, 3);
      Y                                        : OpenCV.Core.Mat :=
        Identity_Map_Y (2, 3);
      Image                                    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Direct, Interleaved_Output, Fixed_Output : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Image);
      OpenCV.Core.Float32_Access.Set (X, 0, 0, 2.0);
      OpenCV.Core.Float32_Access.Set (Y, 0, 0, 1.0);
      declare
         XY       : constant OpenCV.Core.Mat :=
           IP.Interleave_Remap_Maps (X, Y);
         Pair     : constant IP.Float_Remap_Maps := IP.Separate_Remap_Map (XY);
         Fixed    : constant IP.Fixed_Remap_Maps :=
           IP.Convert_Remap_To_Fixed (X, Y);
         Fixed_XY : constant IP.Fixed_Remap_Maps :=
           IP.Convert_Remap_To_Fixed (XY);
         Back     : constant IP.Float_Remap_Maps :=
           IP.Convert_Remap_To_Separate_Float (Fixed);
         Back_XY  : constant OpenCV.Core.Mat :=
           IP.Convert_Remap_To_Interleaved_Float (Fixed_XY);
      begin
         AUnit.Assertions.Assert
           (Map_Component (XY, 0, 0, 0) = 2.0
            and then Map_Component (XY, 1, 0, 0) = 1.0
            and then OpenCV.Core.Float32_Access.Get (Pair.Map_X, 0, 0) = 2.0
            and then OpenCV.Core.Float32_Access.Get (Pair.Map_Y, 0, 0) = 1.0,
            "C2 channel order and round trip must preserve asymmetric X/Y");
         AUnit.Assertions.Assert
           (not IP.Is_Empty (Fixed)
            and then not IP.Is_Nearest_Only (Fixed)
            and then OpenCV.Core.Float32_Access.Get (Back.Map_X, 0, 0) = 2.0
            and then Map_Component (Back_XY, 0, 0, 0) = 2.0
            and then Map_Component (Back_XY, 1, 0, 0) = 1.0,
            "fixed interpolation maps reverse to Float32 coordinates");
         for Method in IP.Nearest_Neighbor .. IP.Linear loop
            IP.Remap (Image, X, Y, Direct, Method);
            IP.Remap (Image, XY, Interleaved_Output, Method);
            IP.Remap (Image, Fixed, Fixed_Output, Method);
            for Row in 0 .. 1 loop
               for Col in 0 .. 2 loop
                  AUnit.Assertions.Assert
                    (OpenCV.Core.UInt8_Access.Get (Direct, Row, Col)
                     = OpenCV.Core.UInt8_Access.Get
                         (Interleaved_Output, Row, Col),
                     "all map forms must sample identically");
               end loop;
            end loop;
         end loop;
         IP.Remap (Image, Fixed, Fixed_Output, IP.Cubic);
         IP.Remap (Image, Fixed, Fixed_Output, IP.Lanczos_4);
         IP.Remap (Image, Fixed, Fixed_Output, IP.Linear);
      end;
   end Map_Representations;

   procedure Nearest_Fixed_And_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package IP renames OpenCV.Image_Processing;
      X          : OpenCV.Core.Mat := Identity_Map (1, 2);
      Y          : constant OpenCV.Core.Mat := Identity_Map_Y (1, 2);
      Image      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.UInt8, 1));
      Output     : OpenCV.Core.Mat;
      Empty_Maps : IP.Fixed_Remap_Maps;
      Bad_Map    : OpenCV.Core.Mat;
   begin
      Fill_Unique_UInt8 (Image);
      OpenCV.Core.Float32_Access.Set (X, 0, 0, 1.75);
      declare
         XY      : constant OpenCV.Core.Mat := IP.Interleave_Remap_Maps (X, Y);
         Fixed   : constant IP.Fixed_Remap_Maps :=
           IP.Convert_Remap_To_Fixed (XY, Nearest_Neighbor_Only => True);
         Back    : constant IP.Float_Remap_Maps :=
           IP.Convert_Remap_To_Separate_Float (Fixed);
         Back_XY : constant OpenCV.Core.Mat :=
           IP.Convert_Remap_To_Interleaved_Float (Fixed);
      begin
         AUnit.Assertions.Assert
           (IP.Is_Nearest_Only (Fixed)
            and then OpenCV.Core.Float32_Access.Get (Back.Map_X, 0, 0) = 2.0
            and then Map_Component (Back_XY, 0, 0, 0) = 2.0,
            "nearest reverse conversion returns rounded integer coordinates");
         IP.Remap (Image, Fixed, Output, IP.Nearest_Neighbor);
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Output, 0, 0) = 3,
            "nearest fixed map samples rounded coordinate");
         for Method in IP.Linear .. IP.Lanczos_4 loop
            if Method /= IP.Area then
               declare
                  procedure Attempt is
                  begin
                     IP.Remap (Image, Fixed, Output, Method);
                  end Attempt;
               begin
                  Assert_Raises_OpenCV_Error
                    (Attempt'Access,
                     "nearest-only map must reject interpolation");
               end;
            end if;
         end loop;
      end;
      declare
         procedure Attempt_Empty is
         begin
            IP.Remap (Image, Empty_Maps, Output, IP.Nearest_Neighbor);
         end Attempt_Empty;
         procedure Attempt_Bad is
         begin
            IP.Remap (Image, Bad_Map, Output);
         end Attempt_Bad;
      begin
         Assert_Raises_OpenCV_Error (Attempt_Empty'Access, "empty fixed map");
         Assert_Raises_OpenCV_Error (Attempt_Bad'Access, "empty C2 map");
      end;
   end Nearest_Fixed_And_Validation;

   procedure Encoded_Region_And_Stride (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package IP renames OpenCV.Image_Processing;
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 32_768, (OpenCV.Core.UInt8, 1));
      Source : constant OpenCV.Core.Mat :=
        Parent.Region ((X => 8, Y => 0, Width => 2, Height => 2));
      X      : constant OpenCV.Core.Mat := Identity_Map (1, 1);
      Y      : constant OpenCV.Core.Mat := Identity_Map_Y (1, 1);
      XY     : constant OpenCV.Core.Mat := IP.Interleave_Remap_Maps (X, Y);
      Fixed  : constant IP.Fixed_Remap_Maps := IP.Convert_Remap_To_Fixed (XY);
      Output : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      procedure Try_Interleaved is
      begin
         IP.Remap (Source, XY, Output, IP.Linear);
      end Try_Interleaved;
      procedure Try_Fixed is
      begin
         IP.Remap (Source, Fixed, Output, IP.Linear);
      end Try_Fixed;
   begin
      OpenCV.Core.UInt8_Access.Set (Parent, 0, 8, 41);
      OpenCV.Core.UInt8_Access.Set (Output, 0, 0, 73);
      Assert_Raises_OpenCV_Error
        (Try_Interleaved'Access, "C2 must reuse SIMD stride safety");
      Assert_Raises_OpenCV_Error
        (Try_Fixed'Access, "fixed must reuse SIMD stride safety");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Output, 0, 0) = 73
         and then OpenCV.Core.UInt8_Access.Get (Parent, 0, 8) = 41,
         "stride rejection preserves output and Region parent");
   end Encoded_Region_And_Stride;

   procedure Encoded_Float_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package IP renames OpenCV.Image_Processing;
      Image  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      XY     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 2));
      Output : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      procedure Try_Remap is
      begin
         IP.Remap (Image, XY, Output);
      end Try_Remap;
      procedure Try_Convert is
         Fixed : constant IP.Fixed_Remap_Maps :=
           IP.Convert_Remap_To_Fixed (XY);
      begin
         AUnit.Assertions.Assert (not IP.Is_Empty (Fixed), "unreachable");
      end Try_Convert;
      procedure Check (Value : OpenCV.Float32_Value) is
         pragma Suppress (Validity_Check);
      begin
         declare
            Component : OpenCV.Core.Mat :=
              OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
         begin
            OpenCV.Core.Float32_Access.Set (Component, 0, 0, Value);
            OpenCV.Core.Insert_Channel (XY, Component, 1);
         end;
         Assert_Raises_OpenCV_Error
           (Try_Remap'Access, "unsafe C2 coordinate must reject Remap");
         Assert_Raises_OpenCV_Error
           (Try_Convert'Access, "unsafe C2 coordinate must reject conversion");
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Output, 0, 0) = 73,
            "failed C2 Remap leaves marker untouched");
      end Check;
   begin
      OpenCV.Core.UInt8_Access.Set (Output, 0, 0, 73);
      Check (1.0E30);
      declare
         pragma Suppress (Validity_Check);
         Value : OpenCV.Float32_Value;
      begin
         Value := Bits_To_Float32 (NaN_Bits_32);
         Check (Value);
         Value := Bits_To_Float32 (Inf_Bits_32);
         Check (Value);
         Value := Bits_To_Float32 (Neg_Inf_Bits_32);
         Check (Value);
      end;
   end Encoded_Float_Safety;

   procedure Encoded_Region_And_Quantization (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package IP renames OpenCV.Image_Processing;
      X_Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 4, (OpenCV.Core.Float32, 1));
      Y_Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 4, (OpenCV.Core.Float32, 1));
      X        : OpenCV.Core.Mat :=
        X_Parent.Region ((X => 1, Y => 0, Width => 2, Height => 1));
      Y        : OpenCV.Core.Mat :=
        Y_Parent.Region ((X => 1, Y => 0, Width => 2, Height => 1));
      Image    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt16, 1));
      Output   : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Float32_Access.Set (X_Parent, 0, 0, 1.0E30);
      OpenCV.Core.Float32_Access.Set (Y_Parent, 0, 0, 1.0E30);
      OpenCV.Core.Float32_Access.Set (X, 0, 0, 1.25);
      OpenCV.Core.Float32_Access.Set (Y, 0, 0, 0.75);
      OpenCV.Core.Float32_Access.Set (X, 0, 1, 2.0);
      OpenCV.Core.Float32_Access.Set (Y, 0, 1, 1.0);
      OpenCV.Core.UInt16_Access.Set (Image, 1, 2, 1234);
      declare
         XY    : constant OpenCV.Core.Mat := IP.Interleave_Remap_Maps (X, Y);
         Fixed : constant IP.Fixed_Remap_Maps :=
           IP.Convert_Remap_To_Fixed (X, Y);
         Back  : constant IP.Float_Remap_Maps :=
           IP.Convert_Remap_To_Separate_Float (Fixed);
      begin
         AUnit.Assertions.Assert
           (XY.Rows = 1
            and then XY.Columns = 2
            and then Map_Component (XY, 0, 0, 0) = 1.25
            and then Map_Component (XY, 1, 0, 0) = 0.75
            and then Nearly_Equal
                       (OpenCV.Core.Float32_Access.Get (Back.Map_X, 0, 0),
                        1.25,
                        1.0 / 32.0),
            "Region conversion uses logical geometry and quantized values");
         IP.Remap (Image, XY, Output, IP.Nearest_Neighbor);
         AUnit.Assertions.Assert
           (Output.Depth = OpenCV.Core.UInt16
            and then Output.Columns = 2
            and then OpenCV.Core.UInt16_Access.Get (Output, 0, 1) = 1234
            and then OpenCV.Core.Float32_Access.Get (X_Parent, 0, 0) = 1.0E30,
            "C2 Region Remap respects source depth and parent pixels");
      end;
   end Encoded_Region_And_Quantization;

   procedure Encoded_Raw_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      X         : constant OpenCV.Core.Mat := Identity_Map (1, 1);
      Empty_Map : OpenCV.Core.Mat;
      Wrong     : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      First     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Second    : OpenCV.Core.Mat;
      Status    : C_API.Status := C_API.Success;
      procedure First_Input
        (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Second_Input
           (Other : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output_1
              (A : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
               procedure Output_2
                 (B : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Convert_Remap_Maps (Handle, Other, A, B, 5, 0);
               end Output_2;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Second, Output_2'Access);
            end Output_1;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (First, Output_1'Access);
         end Second_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Empty_Map, Second_Input'Access);
      end First_Input;
   begin
      OpenCV.Core.UInt8_Access.Set (First, 0, 0, 77);
      OpenCV.Core.Module_Interop.With_Input_Handle (Wrong, First_Input'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then OpenCV.Core.UInt8_Access.Get (First, 0, 0) = 77,
         "raw conversion rejects incorrect interleaved type atomically");
      OpenCV.Core.Module_Interop.With_Input_Handle (X, First_Input'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then OpenCV.Core.UInt8_Access.Get (First, 0, 0) = 77,
         "raw conversion rejects C1 as interleaved atomically");
   end Encoded_Raw_ABI;

   procedure Fixed_Quantization_And_Reuse (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package IP renames OpenCV.Image_Processing;
      X                       : OpenCV.Core.Mat := Identity_Map (1, 1);
      Y                       : OpenCV.Core.Mat := Identity_Map_Y (1, 1);
      Frame_1                 : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Frame_2                 : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Expected, First, Second : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Float32_Access.Set (X, 0, 0, 1.25);
      OpenCV.Core.Float32_Access.Set (Y, 0, 0, 1.5);
      for Row in 0 .. 2 loop
         for Col in 0 .. 2 loop
            OpenCV.Core.Float32_Access.Set
              (Frame_1, Row, Col, OpenCV.Float32_Value (Row * 3 + Col));
            OpenCV.Core.Float32_Access.Set
              (Frame_2, Row, Col, OpenCV.Float32_Value (Row * 3 + Col + 10));
         end loop;
      end loop;
      declare
         Fixed    : constant IP.Fixed_Remap_Maps :=
           IP.Convert_Remap_To_Fixed (X, Y);
         Restored : constant IP.Float_Remap_Maps :=
           IP.Convert_Remap_To_Separate_Float (Fixed);
      begin
         AUnit.Assertions.Assert
           (Nearly_Equal
              (OpenCV.Core.Float32_Access.Get (Restored.Map_X, 0, 0),
               1.25,
               1.0 / 32.0)
            and then Nearly_Equal
                       (OpenCV.Core.Float32_Access.Get (Restored.Map_Y, 0, 0),
                        1.5,
                        1.0 / 32.0),
            "reverse fixed coordinates differ by at most 1/32 pixel");
         for Method in IP.Linear .. IP.Lanczos_4 loop
            if Method /= IP.Area then
               IP.Remap (Frame_1, X, Y, Expected, Method);
               IP.Remap (Frame_1, Fixed, First, Method);
               AUnit.Assertions.Assert
                 (Nearly_Equal
                    (OpenCV.Core.Float32_Access.Get (Expected, 0, 0),
                     OpenCV.Core.Float32_Access.Get (First, 0, 0),
                     0.01),
                  "table-aligned fixed interpolation matches Float32");
            end if;
         end loop;
         IP.Remap (Frame_1, Fixed, First, IP.Linear);
         IP.Remap (Frame_2, Fixed, Second, IP.Linear);
         AUnit.Assertions.Assert
           (Nearly_Equal
              (OpenCV.Core.Float32_Access.Get (Second, 0, 0)
               - OpenCV.Core.Float32_Access.Get (First, 0, 0),
               10.0,
               0.01),
            "fixed map can be reused with independent Float32 frames");
      end;
   end Fixed_Quantization_And_Reuse;

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
      Linear_Mid  : OpenCV.Float32_Value;
      Nearest_Mid : OpenCV.Float32_Value;
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
         OpenCV.Constant_Border,
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

      function Sample (Kind : OpenCV.Border_Kind) return Interfaces.Unsigned_8
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
        (Sample (OpenCV.Replicate) = 10,
         "Replicate at x=-1 must sample the left edge");
      AUnit.Assertions.Assert
        (Sample (OpenCV.Reflect) = 10,
         "Reflect at x=-1 must sample Source column 0");
      AUnit.Assertions.Assert
        (Sample (OpenCV.Reflect_101) = 20,
         "Reflect_101 at x=-1 must sample Source column 1");
      AUnit.Assertions.Assert
        (Sample (OpenCV.Wrap) = 30,
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
      Saved_X     : OpenCV.Float32_Value;
      Saved_Y     : OpenCV.Float32_Value;
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
         Value : OpenCV.Float32_Value;
      begin
         Value := Bits_To_Float32 (NaN_Bits_32);
         OpenCV.Core.Float32_Access.Set (Nan_X, 0, 0, Value);
         OpenCV.Image_Processing.Remap
           (Valid_Source, Nan_X, Valid_Y, Destination);
      end Nan_Map;

      procedure Inf_Map is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Float32_Value;
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

   procedure Float_Coordinate_Range_And_Atomicity (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Map_X       : OpenCV.Core.Mat := Identity_Map (1, 1);
      Map_Y       : OpenCV.Core.Mat := Identity_Map_Y (1, 1);
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Reject_Huge_Nearest is
      begin
         OpenCV.Image_Processing.Remap
           (Source,
            Map_X,
            Map_Y,
            Destination,
            OpenCV.Image_Processing.Nearest_Neighbor);
      end Reject_Huge_Nearest;

      procedure Reject_Huge_Linear is
      begin
         OpenCV.Image_Processing.Remap
           (Source, Map_X, Map_Y, Destination, OpenCV.Image_Processing.Linear);
      end Reject_Huge_Linear;

      function Raw_Remap
        (Interpolation : Interfaces.Integer_32) return C_API.Status
      is
         Status : C_API.Status := C_API.Error_Unknown;

         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Map_X_Input
              (X_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Map_Y_Input
                 (Y_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
               is
                  procedure Output
                    (Destination_Handle :
                       OpenCV.Core.Module_Interop.Output_Mat_Handle) is
                  begin
                     Status :=
                       C_API.Remap
                         (Source_Handle,
                          X_Handle,
                          Y_Handle,
                          Destination_Handle,
                          Interpolation,
                          C_API.Border_Constant,
                          29.0,
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
           (Source, Source_Input'Access);
         return Status;
      end Raw_Remap;

      procedure Check_Nonfinite (Bits : Interfaces.Unsigned_32) is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Float32_Value;
      begin
         Value := Bits_To_Float32 (Bits);
         OpenCV.Core.Float32_Access.Set (Map_Y, 0, 0, Value);
         Assert_Raises_OpenCV_Error
           (Reject_Huge_Nearest'Access,
            "nonfinite Y must be rejected before nearest remap");
         Assert_Raises_OpenCV_Error
           (Reject_Huge_Linear'Access,
            "nonfinite Y must be rejected before linear remap");
         AUnit.Assertions.Assert
           (Raw_Remap (C_API.Interpolation_Nearest_Neighbor)
            = C_API.Error_Invalid_Argument
            and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
            "raw nonfinite rejection must preserve destination");
      end Check_Nonfinite;
   begin
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, 1.0E30);
      Assert_Raises_OpenCV_Error
        (Reject_Huge_Nearest'Access, "nearest must reject huge finite X");
      Assert_Raises_OpenCV_Error
        (Reject_Huge_Linear'Access, "linear must reject huge finite X");
      AUnit.Assertions.Assert
        (Raw_Remap (C_API.Interpolation_Nearest_Neighbor)
         = C_API.Error_Invalid_Argument
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "raw huge finite rejection must preserve the destination");
      AUnit.Assertions.Assert
        (Raw_Remap (C_API.Interpolation_Linear) = C_API.Error_Invalid_Argument
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "raw scaled huge coordinate rejection must preserve destination");
      OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, -1.0);
      Check_Nonfinite (NaN_Bits_32);
      Check_Nonfinite (Inf_Bits_32);
      Check_Nonfinite (Neg_Inf_Bits_32);
      OpenCV.Core.Float32_Access.Set (Map_Y, 0, 0, 0.0);
      OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, 1.0E8);
      Assert_Raises_OpenCV_Error
        (Reject_Huge_Linear'Access,
         "linear must reject scaled coordinates outside int range");
      OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, -1.0);
      AUnit.Assertions.Assert
        (Raw_Remap (C_API.Interpolation_Nearest_Neighbor) = C_API.Success,
         "a valid raw Remap must succeed after rejected calls");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 29,
         "ordinary out-of-source coordinates must use the border");
   end Float_Coordinate_Range_And_Atomicity;

   procedure UInt8_Linear_SIMD_Stride_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Boundary_Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 32_768, (OpenCV.Core.UInt8, 1));
      Fallback_Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 32_769, (OpenCV.Core.UInt8, 1));
      Boundary        : constant OpenCV.Core.Mat :=
        Boundary_Parent.Region ((X => 8, Y => 0, Width => 2, Height => 2));
      Fallback        : constant OpenCV.Core.Mat :=
        Fallback_Parent.Region ((X => 8, Y => 0, Width => 2, Height => 2));
      Map_X           : constant OpenCV.Core.Mat := Identity_Map (1, 1);
      Map_Y           : constant OpenCV.Core.Mat := Identity_Map_Y (1, 1);
      Destination     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));

      procedure Reject_Boundary is
      begin
         OpenCV.Image_Processing.Remap
           (Boundary,
            Map_X,
            Map_Y,
            Destination,
            OpenCV.Image_Processing.Linear,
            OpenCV.Reflect);
      end Reject_Boundary;
   begin
      OpenCV.Core.UInt8_Access.Set (Boundary_Parent, 0, 7, 99);
      OpenCV.Core.UInt8_Access.Set (Boundary_Parent, 0, 8, 21);
      OpenCV.Core.UInt8_Access.Set (Fallback_Parent, 0, 7, 99);
      OpenCV.Core.UInt8_Access.Set (Fallback_Parent, 0, 8, 42);
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 1, 74);

      AUnit.Assertions.Assert
        (Boundary.Rows = 2
         and then Boundary.Columns = 2
         and then Fallback.Rows = 2
         and then Fallback.Columns = 2,
         "Regions must have small logical dimensions despite parent strides");
      Assert_Raises_OpenCV_Error
        (Reject_Boundary'Access,
         "UInt8 Linear Remap must reject the exact 32768-byte stride");
      AUnit.Assertions.Assert
        (Destination.Rows = 1
         and then Destination.Columns = 2
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 1) = 74,
         "SIMD stride rejection preserves Destination metadata and pixels");

      OpenCV.Image_Processing.Remap
        (Fallback,
         Map_X,
         Map_Y,
         Destination,
         OpenCV.Image_Processing.Linear,
         OpenCV.Reflect);
      AUnit.Assertions.Assert
        (Destination.Rows = 1
         and then Destination.Columns = 1
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 42,
         "32769-byte stride must use scalar fallback and sample the Region");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Boundary_Parent, 0, 7) = 99
         and then OpenCV.Core.UInt8_Access.Get (Boundary_Parent, 0, 8) = 21
         and then OpenCV.Core.UInt8_Access.Get (Fallback_Parent, 0, 7) = 99
         and then OpenCV.Core.UInt8_Access.Get (Fallback_Parent, 0, 8) = 42,
         "Remap must leave both Region parents unchanged");
   end UInt8_Linear_SIMD_Stride_Boundary;

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
         Value : OpenCV.Float32_Value;
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
           ("Remap fixed quantization interpolation and reuse",
            Fixed_Quantization_And_Reuse'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap encoded raw ABI rejects malformed map",
            Encoded_Raw_ABI'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap Region maps and fixed quantization",
            Encoded_Region_And_Quantization'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap C2 and fixed SIMD stride Region safety",
            Encoded_Region_And_Stride'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap C2 nonfinite and huge coordinates",
            Encoded_Float_Safety'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap map representations and fixed reuse",
            Map_Representations'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap nearest fixed and invalid maps",
            Nearest_Fixed_And_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap UInt8 Linear SIMD stride boundary and scalar fallback",
            UInt8_Linear_SIMD_Stride_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("Remap rejects huge Float32 coordinates atomically",
            Float_Coordinate_Range_And_Atomicity'Access));
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
