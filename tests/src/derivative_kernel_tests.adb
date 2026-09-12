with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Derivative_Kernel_Tests is

   use type Interfaces.Integer_32;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
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

   procedure Assert_Column_Vector
     (Kernel      : OpenCV.Core.Mat;
      Length      : Natural;
      Depth       : OpenCV.Core.Depth_Type;
      Description : String) is
   begin
      AUnit.Assertions.Assert
        (Kernel.Rows = Length
         and then Kernel.Columns = 1
         and then Kernel.Channels = 1
         and then Kernel.Depth = Depth,
         Description);
   end Assert_Column_Vector;

   procedure Sobel_X_Kernel_3_Float32 (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Kernels : OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (X_Order     => 1,
           Y_Order     => 0,
           Kernel_Size => OpenCV.Image_Processing.Kernel_3,
           Depth       => OpenCV.Image_Processing.Float32_Kernel);
   begin
      Assert_Column_Vector
        (Kernels.Kernel_X,
         3,
         OpenCV.Core.Float32,
         "Sobel X Kernel_3 Kernel_X must be 3x1 Float32 C1");
      Assert_Column_Vector
        (Kernels.Kernel_Y,
         3,
         OpenCV.Core.Float32,
         "Sobel X Kernel_3 Kernel_Y must be 3x1 Float32 C1");

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 0, 0) = -1.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 1, 0) = 0.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 2, 0)
                  = 1.0,
         "Sobel X Kernel_3 Kernel_X must be [-1, 0, 1]");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 0, 0) = 1.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 1, 0) = 2.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 2, 0)
                  = 1.0,
         "Sobel X Kernel_3 Kernel_Y must be [1, 2, 1]");

      declare
         Original_Y : constant OpenCV.Core.Float32_Value :=
           OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 1, 0);
      begin
         OpenCV.Core.Float32_Access.Set (Kernels.Kernel_X, 0, 0, 42.0);
         AUnit.Assertions.Assert
           (OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 1, 0)
            = Original_Y,
            "Kernel_X and Kernel_Y must have independent Core ownership");
      end;
   end Sobel_X_Kernel_3_Float32;

   procedure Sobel_Y_Kernel_3_Float64 (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Kernels : constant OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (X_Order     => 0,
           Y_Order     => 1,
           Kernel_Size => OpenCV.Image_Processing.Kernel_3,
           Depth       => OpenCV.Image_Processing.Float64_Kernel);
   begin
      Assert_Column_Vector
        (Kernels.Kernel_X,
         3,
         OpenCV.Core.Float64,
         "Sobel Y Kernel_3 Kernel_X must be 3x1 Float64 C1");
      Assert_Column_Vector
        (Kernels.Kernel_Y,
         3,
         OpenCV.Core.Float64,
         "Sobel Y Kernel_3 Kernel_Y must be 3x1 Float64 C1");

      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Kernels.Kernel_X, 0, 0) = 1.0
         and then OpenCV.Core.Float64_Access.Get (Kernels.Kernel_X, 1, 0) = 2.0
         and then OpenCV.Core.Float64_Access.Get (Kernels.Kernel_X, 2, 0)
                  = 1.0,
         "Sobel Y Kernel_3 Kernel_X must be [1, 2, 1]");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Kernels.Kernel_Y, 0, 0) = -1.0
         and then OpenCV.Core.Float64_Access.Get (Kernels.Kernel_Y, 1, 0) = 0.0
         and then OpenCV.Core.Float64_Access.Get (Kernels.Kernel_Y, 2, 0)
                  = 1.0,
         "Sobel Y Kernel_3 Kernel_Y must be [-1, 0, 1]");
   end Sobel_Y_Kernel_3_Float64;

   procedure Normalized_Sobel_Coefficients (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Unnormalized : constant OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (X_Order       => 1,
           Y_Order       => 0,
           Kernel_Size   => OpenCV.Image_Processing.Kernel_3,
           Normalization => OpenCV.Image_Processing.Unnormalized,
           Depth         => OpenCV.Image_Processing.Float64_Kernel);
      Normalized   : constant OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (X_Order       => 1,
           Y_Order       => 0,
           Kernel_Size   => OpenCV.Image_Processing.Kernel_3,
           Normalization => OpenCV.Image_Processing.Normalized,
           Depth         => OpenCV.Image_Processing.Float64_Kernel);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Normalized.Kernel_X, 0, 0) = -0.5
         and then OpenCV.Core.Float64_Access.Get (Normalized.Kernel_X, 1, 0)
                  = 0.0
         and then OpenCV.Core.Float64_Access.Get (Normalized.Kernel_X, 2, 0)
                  = 0.5,
         "normalized Sobel X Kernel_X must be [-0.5, 0.0, 0.5]");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Normalized.Kernel_Y, 0, 0) = 0.25
         and then OpenCV.Core.Float64_Access.Get (Normalized.Kernel_Y, 1, 0)
                  = 0.5
         and then OpenCV.Core.Float64_Access.Get (Normalized.Kernel_Y, 2, 0)
                  = 0.25,
         "normalized Sobel X Kernel_Y must be [0.25, 0.5, 0.25]");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Normalized.Kernel_X, 2, 0)
         /= OpenCV.Core.Float64_Access.Get (Unnormalized.Kernel_X, 2, 0)
         and then OpenCV.Core.Float64_Access.Get (Normalized.Kernel_Y, 1, 0)
                  /= OpenCV.Core.Float64_Access.Get
                       (Unnormalized.Kernel_Y, 1, 0),
         "Normalized must change coefficient scaling");
   end Normalized_Sobel_Coefficients;

   procedure Second_Derivative_Kernel_3 (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Kernels : constant OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (X_Order     => 2,
           Y_Order     => 0,
           Kernel_Size => OpenCV.Image_Processing.Kernel_3);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 0, 0) = 1.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 1, 0)
                  = -2.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 2, 0)
                  = 1.0,
         "second-derivative Kernel_X must be [1, -2, 1]");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 0, 0) = 1.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 1, 0) = 2.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 2, 0)
                  = 1.0,
         "second-derivative Kernel_Y must be [1, 2, 1]");
   end Second_Derivative_Kernel_3;

   procedure Kernel_1_Effective_Length (Test : in out Fixture) is
      pragma Unreferenced (Test);

      First  : constant OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (X_Order     => 1,
           Y_Order     => 0,
           Kernel_Size => OpenCV.Image_Processing.Kernel_1);
      Second : constant OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (X_Order     => 2,
           Y_Order     => 0,
           Kernel_Size => OpenCV.Image_Processing.Kernel_1);
   begin
      Assert_Column_Vector
        (First.Kernel_X,
         3,
         OpenCV.Core.Float32,
         "Kernel_1 X derivative Kernel_X must be 3x1");
      Assert_Column_Vector
        (First.Kernel_Y,
         1,
         OpenCV.Core.Float32,
         "Kernel_1 X derivative Kernel_Y must be 1x1");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (First.Kernel_X, 0, 0) = -1.0
         and then OpenCV.Core.Float32_Access.Get (First.Kernel_X, 1, 0) = 0.0
         and then OpenCV.Core.Float32_Access.Get (First.Kernel_X, 2, 0) = 1.0,
         "Kernel_1 X derivative Kernel_X must be [-1, 0, 1]");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (First.Kernel_Y, 0, 0) = 1.0,
         "Kernel_1 X derivative Kernel_Y must be [1]");

      Assert_Column_Vector
        (Second.Kernel_X,
         3,
         OpenCV.Core.Float32,
         "Kernel_1 second derivative Kernel_X must be 3x1");
      Assert_Column_Vector
        (Second.Kernel_Y,
         1,
         OpenCV.Core.Float32,
         "Kernel_1 second derivative Kernel_Y must be 1x1");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Second.Kernel_X, 0, 0) = 1.0
         and then OpenCV.Core.Float32_Access.Get (Second.Kernel_X, 1, 0) = -2.0
         and then OpenCV.Core.Float32_Access.Get (Second.Kernel_X, 2, 0) = 1.0,
         "Kernel_1 second derivative Kernel_X must be [1, -2, 1]");
   end Kernel_1_Effective_Length;

   procedure Scharr_X_Unnormalized (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Kernels : constant OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Scharr_Kernels
          (OpenCV.Image_Processing.X_Axis);
   begin
      Assert_Column_Vector
        (Kernels.Kernel_X,
         3,
         OpenCV.Core.Float32,
         "Scharr X Kernel_X must be 3x1 Float32 C1");
      Assert_Column_Vector
        (Kernels.Kernel_Y,
         3,
         OpenCV.Core.Float32,
         "Scharr X Kernel_Y must be 3x1 Float32 C1");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 0, 0) = -1.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 1, 0) = 0.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_X, 2, 0)
                  = 1.0,
         "Scharr X Kernel_X must be [-1, 0, 1]");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 0, 0) = 3.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 1, 0)
                  = 10.0
         and then OpenCV.Core.Float32_Access.Get (Kernels.Kernel_Y, 2, 0)
                  = 3.0,
         "Scharr X Kernel_Y must be [3, 10, 3]");
   end Scharr_X_Unnormalized;

   procedure Scharr_Y_Normalized_Float64 (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Kernels  : constant OpenCV.Image_Processing.Derivative_Kernels :=
        OpenCV.Image_Processing.Get_Scharr_Kernels
          (Axis          => OpenCV.Image_Processing.Y_Axis,
           Normalization => OpenCV.Image_Processing.Normalized,
           Depth         => OpenCV.Image_Processing.Float64_Kernel);
      Three_32 : constant OpenCV.Core.Float64_Value := 3.0 / 32.0;
      Ten_32   : constant OpenCV.Core.Float64_Value := 10.0 / 32.0;
   begin
      Assert_Column_Vector
        (Kernels.Kernel_X,
         3,
         OpenCV.Core.Float64,
         "normalized Scharr Y Kernel_X must be 3x1 Float64 C1");
      Assert_Column_Vector
        (Kernels.Kernel_Y,
         3,
         OpenCV.Core.Float64,
         "normalized Scharr Y Kernel_Y must be 3x1 Float64 C1");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Kernels.Kernel_X, 0, 0) = Three_32
         and then OpenCV.Core.Float64_Access.Get (Kernels.Kernel_X, 1, 0)
                  = Ten_32
         and then OpenCV.Core.Float64_Access.Get (Kernels.Kernel_X, 2, 0)
                  = Three_32,
         "normalized Scharr Y Kernel_X must be [3/32, 10/32, 3/32]");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Kernels.Kernel_Y, 0, 0) = -1.0
         and then OpenCV.Core.Float64_Access.Get (Kernels.Kernel_Y, 1, 0) = 0.0
         and then OpenCV.Core.Float64_Access.Get (Kernels.Kernel_Y, 2, 0)
                  = 1.0,
         "normalized Scharr Y Kernel_Y must be [-1, 0, 1]");
   end Scharr_Y_Normalized_Float64;

   procedure Composes_With_Sep_Filter_2D (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source         : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.Float32, 1));
      Separable      : OpenCV.Core.Mat;
      Native         : OpenCV.Core.Mat;
      Scharr_Sep     : OpenCV.Core.Mat;
      Scharr_Nat     : OpenCV.Core.Mat;
      Kernels        : OpenCV.Image_Processing.Derivative_Kernels;
      Scharr_Kernels : OpenCV.Image_Processing.Derivative_Kernels;
   begin
      for Row in 0 .. 6 loop
         for Column in 0 .. 6 loop
            OpenCV.Core.Float32_Access.Set
              (Source,
               Row,
               Column,
               OpenCV.Core.Float32_Value (Row + 2 * Column));
         end loop;
      end loop;

      Kernels :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (X_Order     => 1,
           Y_Order     => 0,
           Kernel_Size => OpenCV.Image_Processing.Kernel_3,
           Depth       => OpenCV.Image_Processing.Float32_Kernel);

      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Separable,
         Kernels.Kernel_X,
         Kernels.Kernel_Y,
         Destination_Depth => OpenCV.Image_Processing.Same_Depth,
         Border            => OpenCV.Core.Reflect_101);

      OpenCV.Image_Processing.Sobel
        (Source,
         Native,
         X_Order           => 1,
         Y_Order           => 0,
         Destination_Depth => OpenCV.Image_Processing.Same_Depth,
         Kernel_Size       => OpenCV.Image_Processing.Kernel_3,
         Scale             => 1.0,
         Offset            => 0.0,
         Border            => OpenCV.Core.Reflect_101);

      for Row in 0 .. 6 loop
         for Column in 0 .. 6 loop
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (OpenCV.Core.Float32_Access.Get (Separable, Row, Column),
                  OpenCV.Core.Float32_Access.Get (Native, Row, Column),
                  1.0E-5),
               "Get_Derivative_Kernels plus Sep_Filter_2D must match Sobel");
         end loop;
      end loop;

      Scharr_Kernels :=
        OpenCV.Image_Processing.Get_Scharr_Kernels
          (OpenCV.Image_Processing.X_Axis);

      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Scharr_Sep,
         Scharr_Kernels.Kernel_X,
         Scharr_Kernels.Kernel_Y,
         Destination_Depth => OpenCV.Image_Processing.Same_Depth,
         Border            => OpenCV.Core.Reflect_101);

      OpenCV.Image_Processing.Scharr
        (Source,
         Scharr_Nat,
         Axis              => OpenCV.Image_Processing.X_Axis,
         Destination_Depth => OpenCV.Image_Processing.Same_Depth,
         Scale             => 1.0,
         Offset            => 0.0,
         Border            => OpenCV.Core.Reflect_101);

      for Row in 0 .. 6 loop
         for Column in 0 .. 6 loop
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (OpenCV.Core.Float32_Access.Get (Scharr_Sep, Row, Column),
                  OpenCV.Core.Float32_Access.Get (Scharr_Nat, Row, Column),
                  1.0E-5),
               "Get_Scharr_Kernels plus Sep_Filter_2D must match Scharr");
         end loop;
      end loop;
   end Composes_With_Sep_Filter_2D;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Discard : OpenCV.Image_Processing.Derivative_Kernels;

      procedure Zero_Orders is
      begin
         Discard := OpenCV.Image_Processing.Get_Derivative_Kernels (0, 0);
      end Zero_Orders;

      procedure Kernel_1_Order_3 is
      begin
         Discard :=
           OpenCV.Image_Processing.Get_Derivative_Kernels
             (3, 0, OpenCV.Image_Processing.Kernel_1);
      end Kernel_1_Order_3;

      procedure Kernel_3_Order_3 is
      begin
         Discard :=
           OpenCV.Image_Processing.Get_Derivative_Kernels
             (3, 0, OpenCV.Image_Processing.Kernel_3);
      end Kernel_3_Order_3;

      procedure Kernel_5_Order_5 is
      begin
         Discard :=
           OpenCV.Image_Processing.Get_Derivative_Kernels
             (5, 0, OpenCV.Image_Processing.Kernel_5);
      end Kernel_5_Order_5;

      procedure Kernel_7_Order_7 is
      begin
         Discard :=
           OpenCV.Image_Processing.Get_Derivative_Kernels
             (7, 0, OpenCV.Image_Processing.Kernel_7);
      end Kernel_7_Order_7;
   begin
      Assert_Raises_OpenCV_Error
        (Zero_Orders'Access, "Get_Derivative_Kernels must reject X=0 Y=0");
      Assert_Raises_OpenCV_Error
        (Kernel_1_Order_3'Access,
         "Get_Derivative_Kernels must reject X=3 Kernel_1");
      Assert_Raises_OpenCV_Error
        (Kernel_3_Order_3'Access,
         "Get_Derivative_Kernels must reject X=3 Kernel_3");
      Assert_Raises_OpenCV_Error
        (Kernel_5_Order_5'Access,
         "Get_Derivative_Kernels must reject X=5 Kernel_5");
      Assert_Raises_OpenCV_Error
        (Kernel_7_Order_7'Access,
         "Get_Derivative_Kernels must reject X=7 Kernel_7");

      Discard :=
        OpenCV.Image_Processing.Get_Derivative_Kernels
          (1, 1, OpenCV.Image_Processing.Kernel_3);
      Assert_Column_Vector
        (Discard.Kernel_X,
         3,
         OpenCV.Core.Float32,
         "mixed X=1 Y=1 Kernel_3 must be accepted");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Check
        (X_Order, Y_Order, Kernel_Size, Normalize, Kernel_Depth :
           Interfaces.Integer_32;
         Diagnostic                                             : String)
      is
         Kernel_X : OpenCV.Core.Mat;
         Kernel_Y : OpenCV.Core.Mat;
         Status   : C_API.Status := C_API.Success;

         procedure Kernel_X_Output
           (Kernel_X_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure Kernel_Y_Output
              (Kernel_Y_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
            begin
               Status :=
                 C_API.Get_Derivative_Kernels
                   (Kernel_X_Handle,
                    Kernel_Y_Handle,
                    X_Order,
                    Y_Order,
                    Kernel_Size,
                    Normalize,
                    Kernel_Depth);
            end Kernel_Y_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Kernel_Y, Kernel_Y_Output'Access);
         end Kernel_X_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Kernel_X, Kernel_X_Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Get_Derivative_Kernels C ABI input must return"
            & " invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Get_Derivative_Kernels C ABI input must identify "
            & Diagnostic);
      end Check;

      procedure Check_Aliased_Outputs is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;

         procedure Output
           (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              C_API.Get_Derivative_Kernels
                (Handle,
                 Handle,
                 1,
                 0,
                 C_API.Sobel_Kernel_3,
                 C_API.Derivative_Kernels_Unnormalized,
                 C_API.Gaussian_Kernel_Float32);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "aliased Get_Derivative_Kernels outputs must return"
            & " invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "distinct")
            /= 0,
            "aliased Get_Derivative_Kernels outputs must identify distinct");
      end Check_Aliased_Outputs;

      procedure Check_Success
        (X_Order, Y_Order, Kernel_Size : Interfaces.Integer_32;
         Description                   : String)
      is
         Kernel_X : OpenCV.Core.Mat;
         Kernel_Y : OpenCV.Core.Mat;
         Status   : C_API.Status := C_API.Error_Unknown;

         procedure Kernel_X_Output
           (Kernel_X_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure Kernel_Y_Output
              (Kernel_Y_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
            begin
               Status :=
                 C_API.Get_Derivative_Kernels
                   (Kernel_X_Handle,
                    Kernel_Y_Handle,
                    X_Order,
                    Y_Order,
                    Kernel_Size,
                    C_API.Derivative_Kernels_Unnormalized,
                    C_API.Gaussian_Kernel_Float32);
            end Kernel_Y_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Kernel_Y, Kernel_Y_Output'Access);
         end Kernel_X_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Kernel_X, Kernel_X_Output'Access);
         AUnit.Assertions.Assert (Status = C_API.Success, Description);
         AUnit.Assertions.Assert
           (Kernel_X.Columns = 1
            and then Kernel_Y.Columns = 1
            and then Kernel_X.Depth = OpenCV.Core.Float32,
            Description & " must produce column vectors");
      end Check_Success;
   begin
      Check
        (-1,
         0,
         C_API.Sobel_Kernel_3,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "nonnegative");
      Check
        (1,
         -1,
         C_API.Sobel_Kernel_3,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "nonnegative");
      Check
        (0,
         0,
         C_API.Sobel_Kernel_3,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "nonzero");
      Check
        (1,
         0,
         0,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "kernel size");
      Check
        (1,
         0,
         2,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "kernel size");
      Check
        (1,
         0,
         9,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "kernel size");
      Check
        (3,
         0,
         C_API.Sobel_Kernel_1,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "effective");
      Check
        (3,
         0,
         C_API.Sobel_Kernel_3,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "effective");
      Check
        (0,
         0,
         C_API.Derivative_Kernel_Scharr,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "nonzero");
      Check
        (1,
         1,
         C_API.Derivative_Kernel_Scharr,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "Scharr");
      Check
        (2,
         0,
         C_API.Derivative_Kernel_Scharr,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "Scharr");
      Check
        (1,
         0,
         -2,
         C_API.Derivative_Kernels_Unnormalized,
         C_API.Gaussian_Kernel_Float32,
         "kernel size");
      Check
        (1,
         0,
         C_API.Sobel_Kernel_3,
         -1,
         C_API.Gaussian_Kernel_Float32,
         "normalize");
      Check
        (1,
         0,
         C_API.Sobel_Kernel_3,
         2,
         C_API.Gaussian_Kernel_Float32,
         "normalize");
      Check
        (1,
         0,
         C_API.Sobel_Kernel_3,
         C_API.Derivative_Kernels_Unnormalized,
         99,
         "depth");
      Check_Aliased_Outputs;
      Check_Success
        (1,
         0,
         C_API.Sobel_Kernel_3,
         "valid Sobel C ABI Get_Derivative_Kernels");
      Check_Success
        (1,
         0,
         C_API.Derivative_Kernel_Scharr,
         "valid Scharr C ABI Get_Derivative_Kernels");
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Get_Derivative_Kernels Sobel X Kernel_3 Float32",
            Sobel_X_Kernel_3_Float32'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Derivative_Kernels Sobel Y Kernel_3 Float64",
            Sobel_Y_Kernel_3_Float64'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Derivative_Kernels normalized Sobel coefficients",
            Normalized_Sobel_Coefficients'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Derivative_Kernels second derivative",
            Second_Derivative_Kernel_3'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Derivative_Kernels Kernel_1 effective length",
            Kernel_1_Effective_Length'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Scharr_Kernels X unnormalized",
            Scharr_X_Unnormalized'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Scharr_Kernels Y normalized Float64",
            Scharr_Y_Normalized_Float64'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Derivative_Kernels composes with Sep_Filter_2D",
            Composes_With_Sep_Filter_2D'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Derivative_Kernels rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Derivative_Kernels C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Derivative_Kernel_Tests;
