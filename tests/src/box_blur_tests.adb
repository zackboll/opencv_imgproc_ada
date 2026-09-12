with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Int16_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt16_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Box_Blur_Tests is

   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
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

   procedure UInt8_C1_3x3_Produces_Exact_Center (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 1);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 2, 2);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 3, 3);
      OpenCV.Core.UInt8_Access.Set (Source, 2, 1, 4);
      OpenCV.Core.UInt8_Access.Set (Source, 2, 2, 5);
      OpenCV.Core.UInt8_Access.Set (Source, 2, 3, 6);
      OpenCV.Core.UInt8_Access.Set (Source, 3, 1, 7);
      OpenCV.Core.UInt8_Access.Set (Source, 3, 2, 8);
      OpenCV.Core.UInt8_Access.Set (Source, 3, 3, 9);
      OpenCV.Image_Processing.Box_Blur
        (Source, Destination, (Width => 3, Height => 3));

      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "box blur must replace Destination with Source geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 2, 2) = 5,
         "3x3 box blur must replace the UInt8 center with the exact mean");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 2, 2) = 5
         and then OpenCV.Core.UInt8_Access.Get (Source, 3, 3) = 9,
         "box blur must not modify a distinct source Mat");
   end UInt8_C1_3x3_Produces_Exact_Center;

   procedure UInt16_C1_Produces_Exact_Mean (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt16, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 90.0));
      OpenCV.Core.UInt16_Access.Set (Source, 2, 2, 180);
      OpenCV.Image_Processing.Box_Blur
        (Source, Destination, (Width => 3, Height => 3));

      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.UInt16
         and then Destination.Channels = 1,
         "3x3 box blur must preserve UInt16 C1 geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt16_Access.Get (Destination, 2, 2) = 100,
         "3x3 box blur must return the exact UInt16 neighborhood mean");
   end UInt16_C1_Produces_Exact_Mean;

   procedure Int16_C1_Produces_Exact_Negative_Mean (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Int16, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => -9.0));
      OpenCV.Core.Int16_Access.Set (Source, 2, 2, -18);
      OpenCV.Image_Processing.Box_Blur
        (Source, Destination, (Width => 3, Height => 3));

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Int16
         and then Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Channels = 1,
         "3x3 box blur must preserve Int16 C1 geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 2, 2) = -10,
         "3x3 box blur must return the exact negative Int16 mean");
   end Int16_C1_Produces_Exact_Negative_Mean;

   procedure Float32_C1_Produces_Exact_Mean (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 1.0));
      OpenCV.Core.Float32_Access.Set (Source, 2, 2, 10.0);
      OpenCV.Image_Processing.Box_Blur
        (Source, Destination, (Width => 3, Height => 3));

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32
         and then Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Channels = 1,
         "3x3 box blur must preserve Float32 C1 geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 2, 2) = 2.0,
         "3x3 box blur must return the exact Float32 neighborhood mean");
   end Float32_C1_Produces_Exact_Mean;

   procedure Float64_C1_Produces_Exact_Mean (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Float64, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 2.0));
      OpenCV.Core.Float64_Access.Set (Source, 2, 2, 11.0);
      OpenCV.Image_Processing.Box_Blur
        (Source, Destination, (Width => 3, Height => 3));

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float64
         and then Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Channels = 1,
         "3x3 box blur must preserve Float64 C1 geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Destination, 2, 2) = 3.0,
         "3x3 box blur must return the exact Float64 neighborhood mean");
   end Float64_C1_Produces_Exact_Mean;

   procedure UInt8_C3_Channels_Are_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      for Row in 1 .. 3 loop
         for Column in 1 .. 3 loop
            OpenCV.Core.UInt8_Vec3_Access.Set
              (Source, Row, Column, (9, 18, 27));
         end loop;
      end loop;

      OpenCV.Image_Processing.Box_Blur
        (Source, Destination, (Width => 3, Height => 3));

      AUnit.Assertions.Assert
        (Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 2, 2)
                  = (9, 18, 27),
         "box blur must average UInt8 C3 channels independently");
   end UInt8_C3_Channels_Are_Independent;

   procedure Even_Non_Square_Kernel_On_Constant_Image (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 6, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 40.0));
      OpenCV.Image_Processing.Box_Blur
        (Source, Destination, (Width => 2, Height => 4));

      AUnit.Assertions.Assert
        (Destination.Rows = 6
         and then Destination.Columns = 6
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1
         and then OpenCV.Core.UInt8_Access.Get (Destination, 2, 2) = 40
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 40,
         "box blur must accept even non-square kernels");
   end Even_Non_Square_Kernel_On_Constant_Image;

   procedure Corner_Borders_Use_Requested_Selectors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Constant_Result  : OpenCV.Core.Mat;
      Replicate_Result : OpenCV.Core.Mat;
      Default_Result   : OpenCV.Core.Mat;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 90);
      OpenCV.Image_Processing.Box_Blur
        (Source,
         Constant_Result,
         (Width => 3, Height => 3),
         OpenCV.Core.Constant_Border);
      OpenCV.Image_Processing.Box_Blur
        (Source,
         Replicate_Result,
         (Width => 3, Height => 3),
         OpenCV.Core.Replicate);
      OpenCV.Image_Processing.Box_Blur
        (Source, Default_Result, (Width => 3, Height => 3));

      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Constant_Result, 0, 0) = 10,
         "constant-border 3x3 box blur of a 1x1 UInt8 90 pixel must be 10");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Replicate_Result, 0, 0) = 90
         and then OpenCV.Core.UInt8_Access.Get (Default_Result, 0, 0) = 90,
         "replicate and default Reflect_101 must preserve a 1x1 constant");
   end Corner_Borders_Use_Requested_Selectors;

   procedure Supports_Direct_In_Place_Operation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Image, 1, 1, 1);
      OpenCV.Core.UInt8_Access.Set (Image, 1, 2, 2);
      OpenCV.Core.UInt8_Access.Set (Image, 1, 3, 3);
      OpenCV.Core.UInt8_Access.Set (Image, 2, 1, 4);
      OpenCV.Core.UInt8_Access.Set (Image, 2, 2, 5);
      OpenCV.Core.UInt8_Access.Set (Image, 2, 3, 6);
      OpenCV.Core.UInt8_Access.Set (Image, 3, 1, 7);
      OpenCV.Core.UInt8_Access.Set (Image, 3, 2, 8);
      OpenCV.Core.UInt8_Access.Set (Image, 3, 3, 9);
      OpenCV.Image_Processing.Box_Blur
        (Image, Image, (Width => 3, Height => 3));

      AUnit.Assertions.Assert
        (Image.Rows = 5
         and then Image.Columns = 5
         and then Image.Depth = OpenCV.Core.UInt8
         and then Image.Channels = 1
         and then OpenCV.Core.UInt8_Access.Get (Image, 2, 2) = 5,
         "box blur must support direct in-place filtering");
   end Supports_Direct_In_Place_Operation;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source : OpenCV.Core.Mat;
      Three_D      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int32_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int32, 1));
      Valid_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination  : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Box_Blur
           (Empty_Source, Destination, (Width => 3, Height => 3));
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Box_Blur
           (Three_D, Destination, (Width => 3, Height => 3));
      end Non_Two_Dimensional;

      procedure Zero_Width is
      begin
         OpenCV.Image_Processing.Box_Blur
           (Valid_Source, Destination, (Width => 0, Height => 3));
      end Zero_Width;

      procedure Zero_Height is
      begin
         OpenCV.Image_Processing.Box_Blur
           (Valid_Source, Destination, (Width => 3, Height => 0));
      end Zero_Height;

      procedure Unsupported_Depth is
      begin
         OpenCV.Image_Processing.Box_Blur
           (Int32_Source, Destination, (Width => 3, Height => 3));
      end Unsupported_Depth;

      procedure Wrap_Border is
      begin
         OpenCV.Image_Processing.Box_Blur
           (Valid_Source,
            Destination,
            (Width => 3, Height => 3),
            OpenCV.Core.Wrap);
      end Wrap_Border;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "box blur must reject an empty source Mat");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "box blur must reject a three-dimensional source Mat");
      Assert_Raises_OpenCV_Error
        (Zero_Width'Access, "box blur must reject a zero kernel width");
      Assert_Raises_OpenCV_Error
        (Zero_Height'Access, "box blur must reject a zero kernel height");
      Assert_Raises_OpenCV_Error
        (Unsupported_Depth'Access, "box blur must reject Int32 source Mats");
      Assert_Raises_OpenCV_Error
        (Wrap_Border'Access, "box blur must reject Wrap border");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Int32_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int32, 1));
      Three_D      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));

      procedure Check
        (Source        : OpenCV.Core.Mat;
         Kernel_Width  : Interfaces.Integer_32;
         Kernel_Height : Interfaces.Integer_32;
         Border        : Interfaces.Integer_32;
         Diagnostic    : String)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Box_Blur
                   (Source_Handle,
                    Destination_Handle,
                    Kernel_Width,
                    Kernel_Height,
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
            "malformed box blur C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed box blur C ABI input must identify " & Diagnostic);
      end Check;
   begin
      Check (UInt8_Source, 0, 3, C_API.Border_Reflect_101, "width");
      Check (UInt8_Source, -1, 3, C_API.Border_Reflect_101, "width");
      Check (UInt8_Source, 3, 0, C_API.Border_Reflect_101, "height");
      Check (UInt8_Source, 3, -2, C_API.Border_Reflect_101, "height");
      Check (Int32_Source, 3, 3, C_API.Border_Reflect_101, "CV_64F");
      Check (UInt8_Source, 3, 3, 99, "border");
      Check (Three_D, 3, 3, C_API.Border_Reflect_101, "two-dimensional");
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Box blur UInt8 C1 3x3 produces exact center",
            UInt8_C1_3x3_Produces_Exact_Center'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur UInt16 C1 produces exact mean",
            UInt16_C1_Produces_Exact_Mean'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur Int16 C1 produces exact negative mean",
            Int16_C1_Produces_Exact_Negative_Mean'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur Float32 C1 produces exact mean",
            Float32_C1_Produces_Exact_Mean'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur Float64 C1 produces exact mean",
            Float64_C1_Produces_Exact_Mean'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur processes UInt8 C3 channels independently",
            UInt8_C3_Channels_Are_Independent'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur accepts even non-square kernels",
            Even_Non_Square_Kernel_On_Constant_Image'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur uses requested Constant and Replicate borders",
            Corner_Borders_Use_Requested_Selectors'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur supports direct in-place operation",
            Supports_Direct_In_Place_Operation'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Box blur C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Box_Blur_Tests;
