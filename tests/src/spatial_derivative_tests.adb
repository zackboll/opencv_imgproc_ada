with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Ada.Strings.Fixed;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Int16_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Spatial_Derivative_Tests is

   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
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

   procedure Sobel_X_Produces_Exact_Signed_Derivative (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 4 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, Interfaces.Unsigned_8 (Column * 10));
         end loop;
      end loop;

      OpenCV.Image_Processing.Sobel
        (Source,
         Destination,
         1,
         0,
         OpenCV.Image_Processing.Int16_Depth,
         Border => OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.Int16
         and then Destination.Channels = 1,
         "Sobel X must preserve geometry and channels with requested depth");
      for Row in 0 .. 2 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.Int16_Access.Get (Destination, Row, 0) = 40
            and then OpenCV.Core.Int16_Access.Get (Destination, Row, 1) = 80
            and then OpenCV.Core.Int16_Access.Get (Destination, Row, 2) = 80
            and then OpenCV.Core.Int16_Access.Get (Destination, Row, 3) = 80
            and then OpenCV.Core.Int16_Access.Get (Destination, Row, 4) = 40,
            "Sobel X must produce exact 3x3 derivative values");
      end loop;
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 1, 2) = 20,
         "Sobel must not modify a distinct source Mat");
   end Sobel_X_Produces_Exact_Signed_Derivative;

   procedure Sobel_Y_Produces_Exact_Derivative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 4 loop
         for Column in 0 .. 2 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, Interfaces.Unsigned_8 (Row * 10));
         end loop;
      end loop;

      OpenCV.Image_Processing.Sobel
        (Source,
         Destination,
         0,
         1,
         OpenCV.Image_Processing.Int16_Depth,
         Border => OpenCV.Core.Replicate);

      for Column in 0 .. 2 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.Int16_Access.Get (Destination, 0, Column) = 40
            and then OpenCV.Core.Int16_Access.Get (Destination, 1, Column) = 80
            and then OpenCV.Core.Int16_Access.Get (Destination, 2, Column) = 80
            and then OpenCV.Core.Int16_Access.Get (Destination, 3, Column) = 80
            and then OpenCV.Core.Int16_Access.Get (Destination, 4, Column)
                     = 40,
            "Sobel Y must produce exact 3x3 derivative values");
      end loop;
   end Sobel_Y_Produces_Exact_Derivative;

   procedure Sobel_Preserves_Negative_Gradient (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 4 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, Interfaces.Unsigned_8 ((4 - Column) * 10));
         end loop;
      end loop;

      OpenCV.Image_Processing.Sobel
        (Source,
         Destination,
         1,
         0,
         OpenCV.Image_Processing.Int16_Depth,
         Border => OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 1, 2) = -80,
         "Int16 Sobel output must preserve negative gradients");
   end Sobel_Preserves_Negative_Gradient;

   procedure Scharr_Axis_Selects_First_Derivative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 4 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, Interfaces.Unsigned_8 (Column * 10));
         end loop;
      end loop;

      OpenCV.Image_Processing.Scharr
        (Source,
         Destination,
         OpenCV.Image_Processing.X_Axis,
         OpenCV.Image_Processing.Int16_Depth,
         Border => OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 1, 2) = 320,
         "Scharr X axis must select OpenCV's first X derivative");
   end Scharr_Axis_Selects_First_Derivative;

   procedure Sobel_Supports_In_Place_Same_Depth (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 5, (OpenCV.Core.Int16, 1));
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 4 loop
            OpenCV.Core.Int16_Access.Set
              (Image, Row, Column, Interfaces.Integer_16 (Column * 10));
         end loop;
      end loop;

      OpenCV.Image_Processing.Sobel
        (Image,
         Image,
         1,
         0,
         OpenCV.Image_Processing.Same_Depth,
         Border => OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (Image.Depth = OpenCV.Core.Int16
         and then OpenCV.Core.Int16_Access.Get (Image, 1, 2) = 80,
         "Sobel must preserve direct in-place Same_Depth operation");
   end Sobel_Supports_In_Place_Same_Depth;

   procedure Sobel_Kernel_1_Produces_Exact_Derivative (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 4 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, Interfaces.Unsigned_8 (Column * 10));
         end loop;
      end loop;

      OpenCV.Image_Processing.Sobel
        (Source,
         Destination,
         1,
         0,
         OpenCV.Image_Processing.Int16_Depth,
         OpenCV.Image_Processing.Kernel_1,
         Border => OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 1, 0) = 10
         and then OpenCV.Core.Int16_Access.Get (Destination, 1, 2) = 20
         and then OpenCV.Core.Int16_Access.Get (Destination, 1, 4) = 10,
         "Sobel Kernel_1 must use OpenCV's one-dimensional derivative kernel");
   end Sobel_Kernel_1_Produces_Exact_Derivative;

   procedure Sobel_Kernel_5_Forwards_Scale_And_Offset (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 4 loop
         for Column in 0 .. 4 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, Interfaces.Unsigned_8 (Column * 10));
         end loop;
      end loop;

      OpenCV.Image_Processing.Sobel
        (Source,
         Destination,
         1,
         0,
         OpenCV.Image_Processing.Int16_Depth,
         OpenCV.Image_Processing.Kernel_5,
         Scale  => 0.5,
         Offset => 3.0,
         Border => OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 2, 2) = 643,
         "Sobel Kernel_5 must forward Scale and Offset to OpenCV");
   end Sobel_Kernel_5_Forwards_Scale_And_Offset;

   procedure Scharr_Y_Produces_Exact_Derivative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 4 loop
         for Column in 0 .. 2 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, Interfaces.Unsigned_8 (Row * 10));
         end loop;
      end loop;

      OpenCV.Image_Processing.Scharr
        (Source,
         Destination,
         OpenCV.Image_Processing.Y_Axis,
         OpenCV.Image_Processing.Int16_Depth,
         Border => OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 2, 1) = 320,
         "Scharr Y axis must select OpenCV's first Y derivative");
   end Scharr_Y_Produces_Exact_Derivative;

   procedure Sobel_Processes_UInt8_C3_Channels_Independently
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 5, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 4 loop
            OpenCV.Core.UInt8_Vec3_Access.Set
              (Source,
               Row,
               Column,
               (Interfaces.Unsigned_8 (Column * 10),
                Interfaces.Unsigned_8 (Column * 20),
                Interfaces.Unsigned_8 (Column * 30)));
         end loop;
      end loop;

      OpenCV.Image_Processing.Sobel
        (Source,
         Destination,
         1,
         0,
         OpenCV.Image_Processing.Same_Depth,
         Border => OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 1, 2)
                  = (80, 160, 240),
         "Sobel must differentiate UInt8 C3 channels independently");
   end Sobel_Processes_UInt8_C3_Channels_Independently;

   procedure C_ABI_Rejects_Malformed_Derivative_Selectors
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));

      procedure Check_Sobel
        (X_Order, Y_Order, Kernel_Size, Destination_Depth :
           Interfaces.Integer_32;
         Diagnostic                                       : String)
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
                 C_API.Sobel
                   (Source_Handle,
                    Destination_Handle,
                    Destination_Depth,
                    X_Order,
                    Y_Order,
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
            "malformed Sobel C ABI selector must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Sobel C ABI selector must identify " & Diagnostic);
      end Check_Sobel;

      procedure Check_Scharr is
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
                 C_API.Scharr
                   (Source_Handle,
                    Destination_Handle,
                    C_API.Derivative_Int16,
                    99,
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
            "malformed Scharr C ABI axis must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "axis") /= 0,
            "malformed Scharr C ABI axis must identify axis");
      end Check_Scharr;
   begin
      Check_Sobel
        (-1, 0, C_API.Sobel_Kernel_3, C_API.Derivative_Int16, "orders");
      Check_Sobel (1, 0, 99, C_API.Derivative_Int16, "kernel");
      Check_Sobel (1, 0, C_API.Sobel_Kernel_3, 99, "depth");
      Check_Sobel
        (0, 0, C_API.Sobel_Kernel_3, C_API.Derivative_Int16, "orders");
      Check_Scharr;
   end C_ABI_Rejects_Malformed_Derivative_Selectors;

   procedure Derivatives_Reject_Invalid_Parameters (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt16, 1));
      Destination : OpenCV.Core.Mat;
      procedure No_Derivative is
      begin
         OpenCV.Image_Processing.Sobel (Source, Destination, 0, 0);
      end No_Derivative;
      procedure Incompatible_Depth is
      begin
         OpenCV.Image_Processing.Scharr
           (Source,
            Destination,
            OpenCV.Image_Processing.X_Axis,
            OpenCV.Image_Processing.Int16_Depth);
      end Incompatible_Depth;
      procedure Wrap_Border is
      begin
         OpenCV.Image_Processing.Sobel
           (Source, Destination, 1, 0, Border => OpenCV.Core.Wrap);
      end Wrap_Border;
   begin
      Assert_Raises_OpenCV_Error
        (No_Derivative'Access, "Sobel must reject zero derivative order");
      Assert_Raises_OpenCV_Error
        (Incompatible_Depth'Access,
         "derivatives must reject incompatible source/destination depths");
      Assert_Raises_OpenCV_Error
        (Wrap_Border'Access, "derivatives must reject Wrap border");
   end Derivatives_Reject_Invalid_Parameters;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Sobel X produces exact signed derivative",
            Sobel_X_Produces_Exact_Signed_Derivative'Access));
      Result.Add_Test
        (Caller.Create
           ("Sobel Y produces exact derivative",
            Sobel_Y_Produces_Exact_Derivative'Access));
      Result.Add_Test
        (Caller.Create
           ("Sobel preserves negative gradient",
            Sobel_Preserves_Negative_Gradient'Access));
      Result.Add_Test
        (Caller.Create
           ("Scharr axis selects first derivative",
            Scharr_Axis_Selects_First_Derivative'Access));
      Result.Add_Test
        (Caller.Create
           ("Sobel supports in-place Same_Depth operation",
            Sobel_Supports_In_Place_Same_Depth'Access));
      Result.Add_Test
        (Caller.Create
           ("Sobel Kernel_1 produces exact derivative",
            Sobel_Kernel_1_Produces_Exact_Derivative'Access));
      Result.Add_Test
        (Caller.Create
           ("Sobel Kernel_5 forwards Scale and Offset",
            Sobel_Kernel_5_Forwards_Scale_And_Offset'Access));
      Result.Add_Test
        (Caller.Create
           ("Scharr Y produces exact derivative",
            Scharr_Y_Produces_Exact_Derivative'Access));
      Result.Add_Test
        (Caller.Create
           ("Sobel processes UInt8 C3 channels independently",
            Sobel_Processes_UInt8_C3_Channels_Independently'Access));
      Result.Add_Test
        (Caller.Create
           ("derivative C ABI rejects malformed selectors",
            C_ABI_Rejects_Malformed_Derivative_Selectors'Access));
      Result.Add_Test
        (Caller.Create
           ("Derivatives reject invalid parameters",
            Derivatives_Reject_Invalid_Parameters'Access));
      return Result'Access;
   end Suite;

end Spatial_Derivative_Tests;
