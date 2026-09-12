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
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Bilateral_Filter_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.double;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.Float64_Value;
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

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Core.Float64_Value);

   Infinity_Bits : constant Interfaces.Unsigned_64 := 16#7FF0_0000_0000_0000#;
   NaN_Bits      : constant Interfaces.Unsigned_64 := 16#7FF8_0000_0000_0000#;

   procedure Fill_UInt8_C1
     (Image : in out OpenCV.Core.Mat; Value : Interfaces.Unsigned_8) is
   begin
      for Row in 0 .. Integer (Image.Rows) - 1 loop
         for Column in 0 .. Integer (Image.Columns) - 1 loop
            OpenCV.Core.UInt8_Access.Set (Image, Row, Column, Value);
         end loop;
      end loop;
   end Fill_UInt8_C1;

   procedure Fill_Float32_C1
     (Image : in out OpenCV.Core.Mat; Value : OpenCV.Core.Float32_Value) is
   begin
      for Row in 0 .. Integer (Image.Rows) - 1 loop
         for Column in 0 .. Integer (Image.Columns) - 1 loop
            OpenCV.Core.Float32_Access.Set (Image, Row, Column, Value);
         end loop;
      end loop;
   end Fill_Float32_C1;

   procedure Fill_UInt8_C3
     (Image : in out OpenCV.Core.Mat; Value : OpenCV.Core.UInt8_Vec3.Vector) is
   begin
      for Row in 0 .. Integer (Image.Rows) - 1 loop
         for Column in 0 .. Integer (Image.Columns) - 1 loop
            OpenCV.Core.UInt8_Vec3_Access.Set (Image, Row, Column, Value);
         end loop;
      end loop;
   end Fill_UInt8_C3;

   procedure UInt8_C1_Constant_Is_Preserved (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
   begin
      Fill_UInt8_C1 (Source, 90);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Destination, 5, 25.0, 25.0);

      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "bilateral filter must replace Destination with Source geometry"
         & " and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 90
         and then OpenCV.Core.UInt8_Access.Get (Destination, 2, 2) = 90
         and then OpenCV.Core.UInt8_Access.Get (Destination, 4, 4) = 90,
         "bilateral filter must preserve a constant UInt8 C1 image");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 90
         and then OpenCV.Core.UInt8_Access.Get (Source, 2, 2) = 90,
         "bilateral filter must not modify a distinct source Mat");
   end UInt8_C1_Constant_Is_Preserved;

   procedure Float32_C1_Constant_Is_Preserved (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
      Center      : OpenCV.Core.Float32_Value;
   begin
      Fill_Float32_C1 (Source, 1.25);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Destination, 5, 25.0, 25.0);
      Center := OpenCV.Core.Float32_Access.Get (Destination, 2, 2);

      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "bilateral filter must preserve Float32 C1 geometry and type");
      AUnit.Assertions.Assert
        (Center = 1.25 or else abs (Center - 1.25) < 1.0e-5,
         "bilateral filter must preserve a constant Float32 C1 image");
   end Float32_C1_Constant_Is_Preserved;

   procedure UInt8_C3_Constant_Color_Is_Preserved (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
      Color       : constant OpenCV.Core.UInt8_Vec3.Vector := (10, 60, 200);
   begin
      Fill_UInt8_C3 (Source, Color);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Destination, 5, 25.0, 25.0);

      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 3,
         "bilateral filter must preserve UInt8 C3 geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 2, 2) = Color,
         "bilateral filter must preserve a constant UInt8 C3 color");
   end UInt8_C3_Constant_Color_Is_Preserved;

   procedure Small_Sigma_Color_Preserves_Edge_More (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Small_Color      : OpenCV.Core.Mat;
      Large_Color      : OpenCV.Core.Mat;
      Small_Difference : Integer;
      Large_Difference : Integer;
   begin
      Fill_UInt8_C1 (Source, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 2, 2, 255);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Small_Color, 5, 8.0, 50.0);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Large_Color, 5, 150.0, 50.0);

      Small_Difference :=
        Integer (OpenCV.Core.UInt8_Access.Get (Small_Color, 2, 2))
        - Integer (OpenCV.Core.UInt8_Access.Get (Small_Color, 2, 1));
      Large_Difference :=
        Integer (OpenCV.Core.UInt8_Access.Get (Large_Color, 2, 2))
        - Integer (OpenCV.Core.UInt8_Access.Get (Large_Color, 2, 1));

      AUnit.Assertions.Assert
        (Small_Difference > Large_Difference,
         "small Sigma_Color must preserve the intensity discontinuity more"
         & " strongly than large Sigma_Color");
   end Small_Sigma_Color_Preserves_Edge_More;

   procedure Sigma_Space_Changes_Neighborhood_Weighting (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Tight_Space : OpenCV.Core.Mat;
      Wide_Space  : OpenCV.Core.Mat;
   begin
      Fill_UInt8_C1 (Source, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 2, 2, 255);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Tight_Space, 9, 80.0, 1.0);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Wide_Space, 9, 80.0, 80.0);

      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Tight_Space, 2, 2)
         /= OpenCV.Core.UInt8_Access.Get (Wide_Space, 2, 2)
         or else OpenCV.Core.UInt8_Access.Get (Tight_Space, 0, 0)
                 /= OpenCV.Core.UInt8_Access.Get (Wide_Space, 0, 0),
         "different Sigma_Space values must change bilateral weighting");
   end Sigma_Space_Changes_Neighborhood_Weighting;

   procedure Automatic_Diameter_Filters_Nonconstant_Image
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Changed     : Boolean := False;
   begin
      Fill_UInt8_C1 (Source, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 3, 3, 255);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Destination, 80.0, 80.0);

      AUnit.Assertions.Assert
        (Destination.Rows = 7
         and then Destination.Columns = 7
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "automatic-diameter bilateral filter must preserve geometry"
         & " and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 3, 3) = 255
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 0,
         "automatic-diameter bilateral filter must not modify a distinct"
         & " source");

      for Row in 0 .. Integer (Destination.Rows) - 1 loop
         for Column in 0 .. Integer (Destination.Columns) - 1 loop
            if OpenCV.Core.UInt8_Access.Get (Destination, Row, Column)
              /= OpenCV.Core.UInt8_Access.Get (Source, Row, Column)
            then
               Changed := True;
            end if;
         end loop;
      end loop;

      AUnit.Assertions.Assert
        (Changed,
         "automatic-diameter bilateral filter must actually filter a"
         & " nonconstant image");
   end Automatic_Diameter_Filters_Nonconstant_Image;

   procedure Corner_Borders_Use_Requested_Selectors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Constant_Result  : OpenCV.Core.Mat;
      Replicate_Result : OpenCV.Core.Mat;
      Default_Result   : OpenCV.Core.Mat;
   begin
      Fill_UInt8_C1 (Source, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 255);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Constant_Result, 5, 150.0, 50.0, OpenCV.Core.Constant_Border);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Replicate_Result, 5, 150.0, 50.0, OpenCV.Core.Replicate);
      OpenCV.Image_Processing.Bilateral_Filter
        (Source, Default_Result, 5, 150.0, 50.0);

      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Constant_Result, 0, 0)
         /= OpenCV.Core.UInt8_Access.Get (Replicate_Result, 0, 0),
         "Constant_Border and Replicate must produce different bilateral"
         & " corners");
      AUnit.Assertions.Assert
        (Default_Result.Rows = 5
         and then Default_Result.Columns = 5
         and then Default_Result.Depth = OpenCV.Core.UInt8,
         "default Reflect_101 bilateral filter must succeed");
   end Corner_Borders_Use_Requested_Selectors;

   procedure Rejects_Direct_In_Place_Operation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));

      procedure Attempt is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Image, Image, 5, 25.0, 25.0);
      end Attempt;
   begin
      Fill_UInt8_C1 (Image, 40);
      Assert_Raises_OpenCV_Error
        (Attempt'Access,
         "bilateral filter must reject direct in-place operation");
   end Rejects_Direct_In_Place_Operation;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source   : OpenCV.Core.Mat;
      Three_D        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      UInt16_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt16, 1));
      Int16_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 1));
      Float64_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float64, 1));
      Two_Channel    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 2));
      Four_Channel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 4));
      Valid_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination    : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Empty_Source, Destination, 5, 25.0, 25.0);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Three_D, Destination, 5, 25.0, 25.0);
      end Non_Two_Dimensional;

      procedure UInt16 is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (UInt16_Source, Destination, 5, 25.0, 25.0);
      end UInt16;

      procedure Int16 is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Int16_Source, Destination, 5, 25.0, 25.0);
      end Int16;

      procedure Float64 is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Float64_Source, Destination, 5, 25.0, 25.0);
      end Float64;

      procedure Two_Channel_Source is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Two_Channel, Destination, 5, 25.0, 25.0);
      end Two_Channel_Source;

      procedure Four_Channel_Source is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Four_Channel, Destination, 5, 25.0, 25.0);
      end Four_Channel_Source;

      procedure Zero_Sigma_Color is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, 0.0, 25.0);
      end Zero_Sigma_Color;

      procedure Negative_Sigma_Color is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, -1.0, 25.0);
      end Negative_Sigma_Color;

      procedure Nan_Sigma_Color is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, Value, 25.0);
      end Nan_Sigma_Color;

      procedure Inf_Sigma_Color is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Infinity_Bits);
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, Value, 25.0);
      end Inf_Sigma_Color;

      procedure Zero_Sigma_Space is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, 25.0, 0.0);
      end Zero_Sigma_Space;

      procedure Negative_Sigma_Space is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, 25.0, -1.0);
      end Negative_Sigma_Space;

      procedure Nan_Sigma_Space is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, 25.0, Value);
      end Nan_Sigma_Space;

      procedure Inf_Sigma_Space is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Infinity_Bits);
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, 25.0, Value);
      end Inf_Sigma_Space;

      procedure Wrap_Border is
      begin
         OpenCV.Image_Processing.Bilateral_Filter
           (Valid_Source, Destination, 5, 25.0, 25.0, OpenCV.Core.Wrap);
      end Wrap_Border;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "bilateral filter must reject an empty source Mat");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "bilateral filter must reject a three-dimensional source Mat");
      Assert_Raises_OpenCV_Error
        (UInt16'Access, "bilateral filter must reject UInt16 source Mats");
      Assert_Raises_OpenCV_Error
        (Int16'Access, "bilateral filter must reject Int16 source Mats");
      Assert_Raises_OpenCV_Error
        (Float64'Access, "bilateral filter must reject Float64 source Mats");
      Assert_Raises_OpenCV_Error
        (Two_Channel_Source'Access,
         "bilateral filter must reject a 2-channel source Mat");
      Assert_Raises_OpenCV_Error
        (Four_Channel_Source'Access,
         "bilateral filter must reject a 4-channel source Mat");
      Assert_Raises_OpenCV_Error
        (Zero_Sigma_Color'Access,
         "bilateral filter must reject Sigma_Color 0.0");
      Assert_Raises_OpenCV_Error
        (Negative_Sigma_Color'Access,
         "bilateral filter must reject negative Sigma_Color");
      Assert_Raises_OpenCV_Error
        (Nan_Sigma_Color'Access,
         "bilateral filter must reject NaN Sigma_Color");
      Assert_Raises_OpenCV_Error
        (Inf_Sigma_Color'Access,
         "bilateral filter must reject infinite Sigma_Color");
      Assert_Raises_OpenCV_Error
        (Zero_Sigma_Space'Access,
         "bilateral filter must reject Sigma_Space 0.0");
      Assert_Raises_OpenCV_Error
        (Negative_Sigma_Space'Access,
         "bilateral filter must reject negative Sigma_Space");
      Assert_Raises_OpenCV_Error
        (Nan_Sigma_Space'Access,
         "bilateral filter must reject NaN Sigma_Space");
      Assert_Raises_OpenCV_Error
        (Inf_Sigma_Space'Access,
         "bilateral filter must reject infinite Sigma_Space");
      Assert_Raises_OpenCV_Error
        (Wrap_Border'Access, "bilateral filter must reject Wrap border");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      UInt16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt16, 1));
      Two_Channel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 2));
      Three_D       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));

      procedure Check
        (Source      : OpenCV.Core.Mat;
         Diameter    : Interfaces.Integer_32;
         Sigma_Color : Interfaces.C.double;
         Sigma_Space : Interfaces.C.double;
         Border      : Interfaces.Integer_32;
         Diagnostic  : String)
      is
         pragma Suppress (Validity_Check);
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
               pragma Suppress (Validity_Check);
            begin
               Status :=
                 C_API.Bilateral_Filter
                   (Source_Handle,
                    Destination_Handle,
                    Diameter,
                    Sigma_Color,
                    Sigma_Space,
                    Border);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed bilateral filter C ABI input must return invalid"
            & " argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed bilateral filter C ABI input must identify "
            & Diagnostic);
      end Check;

      procedure Check_Bits
        (Source     : OpenCV.Core.Mat;
         Diameter   : Interfaces.Integer_32;
         Color_Bits : Interfaces.Unsigned_64;
         Space_Bits : Interfaces.Unsigned_64;
         Border     : Interfaces.Integer_32;
         Diagnostic : String)
      is
         pragma Suppress (Validity_Check);
         Color : Interfaces.C.double;
         Space : Interfaces.C.double;
      begin
         Color := Interfaces.C.double (Bits_To_Float64 (Color_Bits));
         Space := Interfaces.C.double (Bits_To_Float64 (Space_Bits));
         Check (Source, Diameter, Color, Space, Border, Diagnostic);
      end Check_Bits;

      procedure Check_Success
        (Source      : OpenCV.Core.Mat;
         Diameter    : Interfaces.Integer_32;
         Sigma_Color : Interfaces.C.double;
         Sigma_Space : Interfaces.C.double)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Bilateral_Filter
                   (Source_Handle,
                    Destination_Handle,
                    Diameter,
                    Sigma_Color,
                    Sigma_Space,
                    C_API.Border_Reflect_101);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "bilateral filter C ABI diameter 0 must be accepted as automatic"
            & " mode");
      end Check_Success;

      procedure Check_In_Place is
         Image  : OpenCV.Core.Mat :=
           OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
         Status : C_API.Status := C_API.Success;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Bilateral_Filter
                   (Source_Handle,
                    Destination_Handle,
                    5,
                    25.0,
                    25.0,
                    C_API.Border_Reflect_101);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Image, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Image, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "identical source and destination handles must be rejected");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "in-place")
            /= 0,
            "identical source and destination handles must identify in-place");
      end Check_In_Place;
   begin
      Check
        (UInt8_Source, -1, 25.0, 25.0, C_API.Border_Reflect_101, "diameter");
      Check (UInt16_Source, 5, 25.0, 25.0, C_API.Border_Reflect_101, "CV_32F");
      Check (Two_Channel, 5, 25.0, 25.0, C_API.Border_Reflect_101, "channel");
      Check
        (Three_D, 5, 25.0, 25.0, C_API.Border_Reflect_101, "two-dimensional");
      Check
        (UInt8_Source, 5, 0.0, 25.0, C_API.Border_Reflect_101, "sigma_color");
      Check
        (UInt8_Source,
         5,
         Interfaces.C.double'(-1.0),
         25.0,
         C_API.Border_Reflect_101,
         "sigma_color");
      Check_Bits
        (UInt8_Source,
         5,
         NaN_Bits,
         16#4039_0000_0000_0000#,
         C_API.Border_Reflect_101,
         "sigma_color");
      Check
        (UInt8_Source, 5, 25.0, 0.0, C_API.Border_Reflect_101, "sigma_space");
      Check
        (UInt8_Source,
         5,
         25.0,
         Interfaces.C.double'(-1.0),
         C_API.Border_Reflect_101,
         "sigma_space");
      Check_Bits
        (UInt8_Source,
         5,
         16#4039_0000_0000_0000#,
         Infinity_Bits,
         C_API.Border_Reflect_101,
         "sigma_space");
      Check (UInt8_Source, 5, 25.0, 25.0, 99, "border");
      Check_Success (UInt8_Source, 0, 25.0, 25.0);
      Check_In_Place;
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter UInt8 C1 constant is preserved",
            UInt8_C1_Constant_Is_Preserved'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter Float32 C1 constant is preserved",
            Float32_C1_Constant_Is_Preserved'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter UInt8 C3 constant color is preserved",
            UInt8_C3_Constant_Color_Is_Preserved'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter small Sigma_Color preserves an edge more",
            Small_Sigma_Color_Preserves_Edge_More'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter Sigma_Space changes neighborhood weighting",
            Sigma_Space_Changes_Neighborhood_Weighting'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter automatic diameter filters a nonconstant image",
            Automatic_Diameter_Filters_Nonconstant_Image'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter uses requested Constant and Replicate borders",
            Corner_Borders_Use_Requested_Selectors'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter rejects direct in-place operation",
            Rejects_Direct_In_Place_Operation'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Bilateral filter C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Bilateral_Filter_Tests;
