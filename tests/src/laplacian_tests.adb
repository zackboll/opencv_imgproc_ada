with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Ada.Strings.Fixed;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Int16_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Laplacian_Tests is

   use type Interfaces.Integer_16;
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

   procedure Kernel_1_Replaces_Destination_And_Preserves_Source
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.Float64, 2));
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 10);
      OpenCV.Image_Processing.Laplacian
        (Source,
         Destination,
         OpenCV.Image_Processing.Int16_Depth,
         1,
         Border => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.Int16
         and then Destination.Channels = 1,
         "Laplacian must replace Destination with the requested type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 1, 1) = -40
         and then OpenCV.Core.Int16_Access.Get (Destination, 0, 1) = 10,
         "Laplacian Kernel_1 must preserve special-aperture output");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 1, 1) = 10,
         "Laplacian must not modify a distinct source Mat");
   end Kernel_1_Replaces_Destination_And_Preserves_Source;

   procedure Kernel_3_Uses_Requested_Aperture (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 10);
      OpenCV.Image_Processing.Laplacian
        (Source,
         Destination,
         OpenCV.Image_Processing.Int16_Depth,
         3,
         Border => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 1, 1) = -80
         and then OpenCV.Core.Int16_Access.Get (Destination, 0, 0) = 20,
         "Laplacian Kernel_3 must select OpenCV's 3 by 3 aperture");
   end Kernel_3_Uses_Requested_Aperture;

   procedure Kernel_9_Uses_Requested_Aperture (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 4, 4, 10);
      OpenCV.Image_Processing.Laplacian
        (Source,
         Destination,
         OpenCV.Image_Processing.Int16_Depth,
         Kernel_Size => 9,
         Border      => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (Destination.Rows = 9
         and then Destination.Columns = 9
         and then Destination.Depth = OpenCV.Core.Int16
         and then OpenCV.Core.Int16_Access.Get (Destination, 4, 4) = -14_000,
         "Laplacian Kernel_Size 9 must preserve its exact center response");
   end Kernel_9_Uses_Requested_Aperture;

   procedure Supports_In_Place_Same_Depth (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Image, 1, 1, 10.0);
      OpenCV.Image_Processing.Laplacian
        (Image,
         Image,
         Destination_Depth => OpenCV.Image_Processing.Same_Depth,
         Kernel_Size       => 1,
         Border            => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (Image.Rows = 3
         and then Image.Columns = 3
         and then Image.Depth = OpenCV.Core.Float32
         and then OpenCV.Core.Float32_Access.Get (Image, 1, 1) = -40.0
         and then OpenCV.Core.Float32_Access.Get (Image, 0, 1) = 10.0,
         "Laplacian must support direct Same_Depth in-place operation");
   end Supports_In_Place_Same_Depth;

   procedure Scale_And_Offset_Are_Forwarded (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 10);
      OpenCV.Image_Processing.Laplacian
        (Source,
         Destination,
         OpenCV.Image_Processing.Int16_Depth,
         Scale  => 0.5,
         Offset => 3.0,
         Border => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 1, 1) = -17,
         "Laplacian must forward Scale and Offset to OpenCV");
   end Scale_And_Offset_Are_Forwarded;

   procedure Processes_UInt8_C3_Channels_Independently (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 1, (10, 20, 30));
      OpenCV.Image_Processing.Laplacian
        (Source,
         Destination,
         OpenCV.Image_Processing.Same_Depth,
         Border => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 1)
                  = (10, 20, 30),
         "Laplacian must process UInt8 C3 channels independently");
   end Processes_UInt8_C3_Channels_Independently;

   procedure Float32_Source_Preserves_Depth (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Source, 1, 1, 2.0);
      OpenCV.Image_Processing.Laplacian
        (Source,
         Destination,
         OpenCV.Image_Processing.Float32_Depth,
         Border => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32,
         "Laplacian must produce requested Float32 output");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 1, 1) = -8.0,
         "Laplacian must compute Float32 output");
   end Float32_Source_Preserves_Depth;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source  : OpenCV.Core.Mat;
      Three_D       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      UInt16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Destination   : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Laplacian (Empty_Source, Destination);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Laplacian (Three_D, Destination);
      end Non_Two_Dimensional;

      procedure Incompatible_Depth is
      begin
         OpenCV.Image_Processing.Laplacian
           (UInt16_Source, Destination, OpenCV.Image_Processing.Int16_Depth);
      end Incompatible_Depth;

      procedure Wrap_Border is
      begin
         OpenCV.Image_Processing.Laplacian
           (UInt16_Source, Destination, Border => OpenCV.Core.Wrap);
      end Wrap_Border;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "Laplacian must reject an empty source");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "Laplacian must reject a three-dimensional source");
      Assert_Raises_OpenCV_Error
        (Incompatible_Depth'Access,
         "Laplacian must reject incompatible source/destination depths");
      Assert_Raises_OpenCV_Error
        (Wrap_Border'Access, "Laplacian must reject Wrap border");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Selectors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));

      procedure Check
        (Destination_Depth, Kernel_Size : Interfaces.Integer_32;
         Diagnostic                     : String)
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
                 C_API.Laplacian
                   (Source_Handle,
                    Destination_Handle,
                    Destination_Depth,
                    Kernel_Size,
                    1.0,
                    0.0,
                    C_API.Border_Replicate);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Laplacian selector must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Laplacian selector must identify " & Diagnostic);
      end Check;
   begin
      Check (C_API.Derivative_Int16, 0, "kernel");
      Check (C_API.Derivative_Int16, 2, "kernel");
      Check (C_API.Derivative_Int16, 33, "kernel");
      Check (99, 3, "depth");
   end C_ABI_Rejects_Malformed_Selectors;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Laplacian Kernel_1 replaces destination and preserves source",
            Kernel_1_Replaces_Destination_And_Preserves_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Laplacian Kernel_3 uses requested aperture",
            Kernel_3_Uses_Requested_Aperture'Access));
      Result.Add_Test
        (Caller.Create
           ("Laplacian Kernel_Size 9 uses requested aperture",
            Kernel_9_Uses_Requested_Aperture'Access));
      Result.Add_Test
        (Caller.Create
           ("Laplacian supports Same_Depth in-place operation",
            Supports_In_Place_Same_Depth'Access));
      Result.Add_Test
        (Caller.Create
           ("Laplacian forwards Scale and Offset",
            Scale_And_Offset_Are_Forwarded'Access));
      Result.Add_Test
        (Caller.Create
           ("Laplacian processes UInt8 C3 channels independently",
            Processes_UInt8_C3_Channels_Independently'Access));
      Result.Add_Test
        (Caller.Create
           ("Laplacian accepts Float32 source",
            Float32_Source_Preserves_Depth'Access));
      Result.Add_Test
        (Caller.Create
           ("Laplacian rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Laplacian C ABI rejects malformed selectors",
            C_ABI_Rejects_Malformed_Selectors'Access));
      return Result'Access;
   end Suite;

end Laplacian_Tests;
