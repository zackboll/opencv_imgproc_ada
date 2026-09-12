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
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Gaussian_Kernel_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.C.double;
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

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Core.Float64_Value);

   Infinity_Bits : constant Interfaces.Unsigned_64 := 16#7FF0_0000_0000_0000#;
   Neg_Inf_Bits  : constant Interfaces.Unsigned_64 := 16#FFF0_0000_0000_0000#;
   NaN_Bits      : constant Interfaces.Unsigned_64 := 16#7FF8_0000_0000_0000#;

   function Nearly_Equal
     (Left, Right : OpenCV.Core.Float64_Value;
      Tolerance   : OpenCV.Core.Float64_Value) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Nearly_Equal;

   function Nearly_Equal
     (Left, Right : OpenCV.Core.Float32_Value;
      Tolerance   : OpenCV.Core.Float32_Value) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Nearly_Equal;

   procedure Default_Float64_Automatic_Kernel (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Kernel : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Gaussian_Kernel (5);
      Sum    : OpenCV.Core.Float64_Value := 0.0;
      Center : OpenCV.Core.Float64_Value;
      Edge   : OpenCV.Core.Float64_Value;
   begin
      AUnit.Assertions.Assert
        (Kernel.Rows = 5
         and then Kernel.Columns = 1
         and then Kernel.Channels = 1
         and then Kernel.Depth = OpenCV.Core.Float64,
         "automatic Get_Gaussian_Kernel must return a 5x1 Float64 C1 Mat");

      for Row in 0 .. 4 loop
         declare
            Value : constant OpenCV.Core.Float64_Value :=
              OpenCV.Core.Float64_Access.Get (Kernel, Row, 0);
         begin
            Sum := Sum + Value;
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (Value,
                  OpenCV.Core.Float64_Access.Get (Kernel, 4 - Row, 0),
                  1.0E-12),
               "automatic Gaussian kernel coefficients must be symmetric");
         end;
      end loop;

      Center := OpenCV.Core.Float64_Access.Get (Kernel, 2, 0);
      Edge := OpenCV.Core.Float64_Access.Get (Kernel, 0, 0);
      AUnit.Assertions.Assert
        (Nearly_Equal (Sum, 1.0, 1.0E-12),
         "automatic Gaussian kernel coefficients must sum to approximately 1");
      AUnit.Assertions.Assert
        (Center > Edge,
         "automatic Gaussian kernel center must exceed the edge coefficient");
   end Default_Float64_Automatic_Kernel;

   procedure Float32_Output_Kernel (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Kernel : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Gaussian_Kernel
          (5, OpenCV.Image_Processing.Float32_Kernel);
      Sum    : OpenCV.Core.Float32_Value := 0.0;
   begin
      AUnit.Assertions.Assert
        (Kernel.Rows = 5
         and then Kernel.Columns = 1
         and then Kernel.Channels = 1
         and then Kernel.Depth = OpenCV.Core.Float32,
         "Float32 Get_Gaussian_Kernel must return a 5x1 Float32 C1 Mat");

      for Row in 0 .. 4 loop
         declare
            Value : constant OpenCV.Core.Float32_Value :=
              OpenCV.Core.Float32_Access.Get (Kernel, Row, 0);
         begin
            Sum := Sum + Value;
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (Value,
                  OpenCV.Core.Float32_Access.Get (Kernel, 4 - Row, 0),
                  1.0E-6),
               "Float32 Gaussian kernel coefficients must be symmetric");
         end;
      end loop;

      AUnit.Assertions.Assert
        (Nearly_Equal (Sum, 1.0, 1.0E-6),
         "Float32 Gaussian kernel coefficients must sum to approximately 1");
   end Float32_Output_Kernel;

   procedure Explicit_Sigma_Changes_Coefficients (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Narrow : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Gaussian_Kernel
          (5, 0.4, OpenCV.Image_Processing.Float64_Kernel);
      Wide   : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Gaussian_Kernel
          (5, 2.5, OpenCV.Image_Processing.Float64_Kernel);
      Differ : Boolean := False;
   begin
      for Row in 0 .. 4 loop
         declare
            Narrow_Value : constant OpenCV.Core.Float64_Value :=
              OpenCV.Core.Float64_Access.Get (Narrow, Row, 0);
            Wide_Value   : constant OpenCV.Core.Float64_Value :=
              OpenCV.Core.Float64_Access.Get (Wide, Row, 0);
         begin
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (Narrow_Value,
                  OpenCV.Core.Float64_Access.Get (Narrow, 4 - Row, 0),
                  1.0E-12),
               "narrow explicit Gaussian kernel must remain symmetric");
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (Wide_Value,
                  OpenCV.Core.Float64_Access.Get (Wide, 4 - Row, 0),
                  1.0E-12),
               "wide explicit Gaussian kernel must remain symmetric");
            if not Nearly_Equal (Narrow_Value, Wide_Value, 1.0E-9) then
               Differ := True;
            end if;
         end;
      end loop;

      AUnit.Assertions.Assert
        (Differ, "distinct explicit sigmas must change Gaussian coefficients");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Narrow, 2, 0)
         > OpenCV.Core.Float64_Access.Get (Wide, 2, 0),
         "a smaller sigma must concentrate more weight at the kernel center");
   end Explicit_Sigma_Changes_Coefficients;

   procedure Automatic_Sigma_Is_Deterministic (Test : in out Fixture) is
      pragma Unreferenced (Test);

      First  : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Gaussian_Kernel
          (7, OpenCV.Image_Processing.Float64_Kernel);
      Second : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Gaussian_Kernel
          (7, OpenCV.Image_Processing.Float64_Kernel);
   begin
      for Row in 0 .. 6 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.Float64_Access.Get (First, Row, 0)
            = OpenCV.Core.Float64_Access.Get (Second, Row, 0),
            "automatic Get_Gaussian_Kernel must be deterministic");
      end loop;
   end Automatic_Sigma_Is_Deterministic;

   procedure Composes_With_Sep_Filter_2D (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.Float32, 1));
      Separable : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Blurred   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Kernel    : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Gaussian_Kernel
          (Kernel_Size => 5,
           Sigma       => 1.2,
           Depth       => OpenCV.Image_Processing.Float32_Kernel);
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Source, 3, 3, 100.0);

      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Separable,
         Kernel_X => Kernel,
         Kernel_Y => Kernel,
         Border   => OpenCV.Core.Reflect_101);

      OpenCV.Image_Processing.Gaussian_Blur
        (Source,
         Blurred,
         (Width => 5, Height => 5),
         1.2,
         OpenCV.Core.Reflect_101);

      for Row in 0 .. 6 loop
         for Column in 0 .. 6 loop
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (OpenCV.Core.Float32_Access.Get (Separable, Row, Column),
                  OpenCV.Core.Float32_Access.Get (Blurred, Row, Column),
                  1.0E-4),
               "Get_Gaussian_Kernel plus Sep_Filter_2D must match"
               & " Gaussian_Blur");
         end loop;
      end loop;
   end Composes_With_Sep_Filter_2D;

   procedure Size_One_Is_Identity (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Kernel : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Gaussian_Kernel (1);
   begin
      AUnit.Assertions.Assert
        (Kernel.Rows = 1
         and then Kernel.Columns = 1
         and then Kernel.Channels = 1
         and then Kernel.Depth = OpenCV.Core.Float64,
         "size-1 Get_Gaussian_Kernel must return a 1x1 Float64 C1 Mat");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Kernel, 0, 0) = 1.0,
         "size-1 automatic Gaussian kernel coefficient must be exactly 1");
   end Size_One_Is_Identity;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Discard : OpenCV.Core.Mat;

      procedure Even_Size is
      begin
         Discard := OpenCV.Image_Processing.Get_Gaussian_Kernel (4);
      end Even_Size;

      procedure Zero_Sigma is
      begin
         Discard := OpenCV.Image_Processing.Get_Gaussian_Kernel (5, 0.0);
      end Zero_Sigma;

      procedure Negative_Sigma is
      begin
         Discard := OpenCV.Image_Processing.Get_Gaussian_Kernel (5, -1.0);
      end Negative_Sigma;

      procedure Nan_Sigma is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         Discard := OpenCV.Image_Processing.Get_Gaussian_Kernel (5, Value);
      end Nan_Sigma;

      procedure Positive_Inf_Sigma is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Infinity_Bits);
         Discard := OpenCV.Image_Processing.Get_Gaussian_Kernel (5, Value);
      end Positive_Inf_Sigma;

      procedure Negative_Inf_Sigma is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Neg_Inf_Bits);
         Discard := OpenCV.Image_Processing.Get_Gaussian_Kernel (5, Value);
      end Negative_Inf_Sigma;
   begin
      Assert_Raises_OpenCV_Error
        (Even_Size'Access, "Get_Gaussian_Kernel must reject an even size");
      Assert_Raises_OpenCV_Error
        (Zero_Sigma'Access, "Get_Gaussian_Kernel must reject Sigma 0.0");
      Assert_Raises_OpenCV_Error
        (Negative_Sigma'Access,
         "Get_Gaussian_Kernel must reject a negative Sigma");
      Assert_Raises_OpenCV_Error
        (Nan_Sigma'Access, "Get_Gaussian_Kernel must reject a NaN Sigma");
      Assert_Raises_OpenCV_Error
        (Positive_Inf_Sigma'Access,
         "Get_Gaussian_Kernel must reject +Inf Sigma");
      Assert_Raises_OpenCV_Error
        (Negative_Inf_Sigma'Access,
         "Get_Gaussian_Kernel must reject -Inf Sigma");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Check
        (Kernel_Size  : Interfaces.Integer_32;
         Sigma        : Interfaces.C.double;
         Kernel_Depth : Interfaces.Integer_32;
         Diagnostic   : String)
      is
         pragma Suppress (Validity_Check);
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;

         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              C_API.Get_Gaussian_Kernel
                (Destination_Handle, Kernel_Size, Sigma, Kernel_Depth);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Get_Gaussian_Kernel C ABI input must return"
            & " invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Get_Gaussian_Kernel C ABI input must identify "
            & Diagnostic);
      end Check;

      procedure Check_Bits
        (Kernel_Size  : Interfaces.Integer_32;
         Sigma_Bits   : Interfaces.Unsigned_64;
         Kernel_Depth : Interfaces.Integer_32;
         Diagnostic   : String)
      is
         pragma Suppress (Validity_Check);
         Sigma : Interfaces.C.double;
      begin
         Sigma := Interfaces.C.double (Bits_To_Float64 (Sigma_Bits));
         Check (Kernel_Size, Sigma, Kernel_Depth, Diagnostic);
      end Check_Bits;

      procedure Check_Success is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;

         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              C_API.Get_Gaussian_Kernel
                (Destination_Handle, 3, 0.0, C_API.Gaussian_Kernel_Float64);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "C ABI sigma 0.0 must be accepted as automatic"
            & " Get_Gaussian_Kernel");
         AUnit.Assertions.Assert
           (Destination.Rows = 3
            and then Destination.Columns = 1
            and then Destination.Depth = OpenCV.Core.Float64,
            "automatic C ABI Get_Gaussian_Kernel must return a 3x1 Float64"
            & " Mat");
      end Check_Success;
   begin
      Check (0, 1.0, C_API.Gaussian_Kernel_Float64, "positive");
      Check (-3, 1.0, C_API.Gaussian_Kernel_Float64, "positive");
      Check (4, 1.0, C_API.Gaussian_Kernel_Float64, "odd");
      Check (5, -1.0, C_API.Gaussian_Kernel_Float64, "sigma");
      Check_Bits (5, NaN_Bits, C_API.Gaussian_Kernel_Float64, "sigma");
      Check (5, 1.0, 99, "depth");
      Check_Success;
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Get_Gaussian_Kernel default Float64 automatic kernel",
            Default_Float64_Automatic_Kernel'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Gaussian_Kernel Float32 output",
            Float32_Output_Kernel'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Gaussian_Kernel explicit sigma changes coefficients",
            Explicit_Sigma_Changes_Coefficients'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Gaussian_Kernel automatic sigma is deterministic",
            Automatic_Sigma_Is_Deterministic'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Gaussian_Kernel composes with Sep_Filter_2D",
            Composes_With_Sep_Filter_2D'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Gaussian_Kernel size 1 is identity",
            Size_One_Is_Identity'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Gaussian_Kernel rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Gaussian_Kernel C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Gaussian_Kernel_Tests;
