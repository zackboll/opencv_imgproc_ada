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
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt16_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Median_Blur_Tests is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
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

   procedure UInt8_C1_3x3_Replaces_Impulse_With_Median (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 255);
      OpenCV.Image_Processing.Median_Blur (Source, Destination, 3);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "median blur must replace Destination with Source geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 1, 1) = 0
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 0,
         "3x3 median must replace an isolated impulse with the neighborhood"
         & " median");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 1, 1) = 255,
         "median blur must not modify a distinct source Mat");
   end UInt8_C1_3x3_Replaces_Impulse_With_Median;

   procedure UInt16_C1_5x5_Produces_Exact_Median (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt16, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 100.0));
      OpenCV.Core.UInt16_Access.Set (Source, 2, 2, 1_000);
      OpenCV.Image_Processing.Median_Blur (Source, Destination, 5);

      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.UInt16
         and then Destination.Channels = 1,
         "5x5 median must preserve UInt16 C1 geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt16_Access.Get (Destination, 2, 2) = 100,
         "5x5 median must replace the UInt16 center with the neighborhood"
         & " median");
   end UInt16_C1_5x5_Produces_Exact_Median;

   procedure Float32_C1_3x3_Produces_Exact_Median (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
      Value       : OpenCV.Core.Float32_Value := 1.0;
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 2 loop
            OpenCV.Core.Float32_Access.Set (Source, Row, Column, Value);
            Value := Value + 1.0;
         end loop;
      end loop;

      OpenCV.Image_Processing.Median_Blur (Source, Destination, 3);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32
         and then Destination.Rows = 3
         and then Destination.Columns = 3
         and then Destination.Channels = 1,
         "3x3 median must preserve Float32 C1 geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 1, 1) = 5.0,
         "3x3 median must return the exact Float32 neighborhood median");
   end Float32_C1_3x3_Produces_Exact_Median;

   procedure UInt8_C3_Channels_Are_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
      Blue        : Interfaces.Unsigned_8 := 10;
      Green       : Interfaces.Unsigned_8 := 1;
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 2 loop
            OpenCV.Core.UInt8_Vec3_Access.Set
              (Source, Row, Column, (Blue, Green, 100));
            Blue := Blue + 10;
            Green := Green + 1;
         end loop;
      end loop;
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 1, (50, 5, 0));

      OpenCV.Image_Processing.Median_Blur (Source, Destination, 3);

      AUnit.Assertions.Assert
        (Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 1, 1)
                  = (50, 5, 100),
         "median blur must filter UInt8 C3 channels independently");
   end UInt8_C3_Channels_Are_Independent;

   procedure UInt8_Kernel_7_Produces_Exact_Center (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 1.0));
      OpenCV.Core.UInt8_Access.Set (Source, 3, 3, 255);
      OpenCV.Image_Processing.Median_Blur (Source, Destination, 7);

      AUnit.Assertions.Assert
        (Destination.Rows = 7
         and then Destination.Columns = 7
         and then Destination.Depth = OpenCV.Core.UInt8
         and then OpenCV.Core.UInt8_Access.Get (Destination, 3, 3) = 1,
         "kernel 7 must accept UInt8 and return the exact central median");
   end UInt8_Kernel_7_Produces_Exact_Center;

   procedure Replicated_Border_At_Corner (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 1);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 100);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 0, 100);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 100);
      OpenCV.Image_Processing.Median_Blur (Source, Destination, 3);

      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 100,
         "median blur must use BORDER_REPLICATE at the upper-left corner");
   end Replicated_Border_At_Corner;

   procedure Supports_Direct_In_Place_Operation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Image, 1, 1, 255);
      OpenCV.Image_Processing.Median_Blur (Image, Image, 3);

      AUnit.Assertions.Assert
        (Image.Rows = 3
         and then Image.Columns = 3
         and then Image.Depth = OpenCV.Core.UInt8
         and then Image.Channels = 1
         and then OpenCV.Core.UInt8_Access.Get (Image, 1, 1) = 0
         and then OpenCV.Core.UInt8_Access.Get (Image, 0, 0) = 0,
         "median blur must support direct in-place filtering");
   end Supports_Direct_In_Place_Operation;

   procedure Rejects_Invalid_Public_Sources (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source : OpenCV.Core.Mat;
      Three_D      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Two_Channel  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 2));
      Destination  : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Median_Blur (Empty_Source, Destination, 3);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Median_Blur (Three_D, Destination, 3);
      end Non_Two_Dimensional;

      procedure Two_Channel_Source is
      begin
         OpenCV.Image_Processing.Median_Blur (Two_Channel, Destination, 3);
      end Two_Channel_Source;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "median blur must reject an empty source Mat");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "median blur must reject a three-dimensional source Mat");
      Assert_Raises_OpenCV_Error
        (Two_Channel_Source'Access,
         "median blur must reject a 2-channel source Mat");
   end Rejects_Invalid_Public_Sources;

   procedure Rejects_Incompatible_Kernel_And_Depth (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Int16_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 1));
      Float64_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float64, 1));
      UInt16_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt16, 1));
      Float32_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.Float32, 1));
      Destination    : OpenCV.Core.Mat;

      procedure Even_Kernel is
      begin
         OpenCV.Image_Processing.Median_Blur (UInt8_Source, Destination, 4);
      end Even_Kernel;

      procedure Int16_Kernel_3 is
      begin
         OpenCV.Image_Processing.Median_Blur (Int16_Source, Destination, 3);
      end Int16_Kernel_3;

      procedure Float64_Kernel_3 is
      begin
         OpenCV.Image_Processing.Median_Blur (Float64_Source, Destination, 3);
      end Float64_Kernel_3;

      procedure UInt16_Kernel_7 is
      begin
         OpenCV.Image_Processing.Median_Blur (UInt16_Source, Destination, 7);
      end UInt16_Kernel_7;

      procedure Float32_Kernel_7 is
      begin
         OpenCV.Image_Processing.Median_Blur (Float32_Source, Destination, 7);
      end Float32_Kernel_7;
   begin
      Assert_Raises_OpenCV_Error
        (Even_Kernel'Access, "median blur must reject even kernel size 4");
      Assert_Raises_OpenCV_Error
        (Int16_Kernel_3'Access, "median blur must reject Int16 with kernel 3");
      Assert_Raises_OpenCV_Error
        (Float64_Kernel_3'Access,
         "median blur must reject Float64 with kernel 3");
      Assert_Raises_OpenCV_Error
        (UInt16_Kernel_7'Access,
         "median blur must reject UInt16 with kernel 7");
      Assert_Raises_OpenCV_Error
        (Float32_Kernel_7'Access,
         "median blur must reject Float32 with kernel 7");
   end Rejects_Incompatible_Kernel_And_Depth;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Two_Channel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 2));
      Int16_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 1));
      UInt16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt16, 1));

      procedure Check
        (Source      : OpenCV.Core.Mat;
         Kernel_Size : Interfaces.Integer_32;
         Diagnostic  : String)
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
                 C_API.Median_Blur
                   (Source_Handle, Destination_Handle, Kernel_Size);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed median blur C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed median blur C ABI input must identify " & Diagnostic);
      end Check;
   begin
      Check (UInt8_Source, 1, "greater than 1");
      Check (UInt8_Source, 0, "greater than 1");
      Check (UInt8_Source, 4, "odd");
      Check (Two_Channel, 3, "channel");
      Check (Int16_Source, 3, "CV_32F");
      Check (UInt16_Source, 7, "greater than 5");
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Median blur UInt8 C1 3x3 replaces impulse with median",
            UInt8_C1_3x3_Replaces_Impulse_With_Median'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur UInt16 C1 5x5 produces exact median",
            UInt16_C1_5x5_Produces_Exact_Median'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur Float32 C1 3x3 produces exact median",
            Float32_C1_3x3_Produces_Exact_Median'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur processes UInt8 C3 channels independently",
            UInt8_C3_Channels_Are_Independent'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur UInt8 kernel 7 produces exact center",
            UInt8_Kernel_7_Produces_Exact_Center'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur uses replicated border at a corner",
            Replicated_Border_At_Corner'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur supports direct in-place operation",
            Supports_Direct_In_Place_Operation'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur rejects invalid public sources",
            Rejects_Invalid_Public_Sources'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur rejects incompatible kernel and depth",
            Rejects_Incompatible_Kernel_And_Depth'Access));
      Result.Add_Test
        (Caller.Create
           ("Median blur C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Median_Blur_Tests;
