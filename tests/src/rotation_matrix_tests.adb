with Ada.Numerics;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Rotation_Matrix_Tests is

   use type Interfaces.Unsigned_8;
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

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Core.Float32_Value);

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Core.Float64_Value);

   NaN_Bits_32   : constant Interfaces.Unsigned_32 := 16#7FC0_0000#;
   Inf_Bits_32   : constant Interfaces.Unsigned_32 := 16#7F80_0000#;
   Infinity_Bits : constant Interfaces.Unsigned_64 := 16#7FF0_0000_0000_0000#;
   Neg_Inf_Bits  : constant Interfaces.Unsigned_64 := 16#FFF0_0000_0000_0000#;
   NaN_Bits      : constant Interfaces.Unsigned_64 := 16#7FF8_0000_0000_0000#;
   Coeff_Tol     : constant OpenCV.Core.Float64_Value := 1.0E-12;

   function Nearly_Equal
     (Left, Right : OpenCV.Core.Float64_Value;
      Tolerance   : OpenCV.Core.Float64_Value := Coeff_Tol) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Nearly_Equal;

   procedure Assert_Is_2x3_Float64_C1
     (Transform : OpenCV.Core.Mat; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Transform.Rows = 2
         and then Transform.Columns = 3
         and then Transform.Channels = 1
         and then Transform.Depth = OpenCV.Core.Float64,
         Message);
   end Assert_Is_2x3_Float64_C1;

   procedure Assert_Coefficients
     (Transform                    : OpenCV.Core.Mat;
      M00, M01, M02, M10, M11, M12 : OpenCV.Core.Float64_Value;
      Message                      : String) is
   begin
      AUnit.Assertions.Assert
        (Nearly_Equal (OpenCV.Core.Float64_Access.Get (Transform, 0, 0), M00)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 0, 1), M01)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 0, 2), M02)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 1, 0), M10)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 1, 1), M11)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 1, 2), M12),
         Message);
   end Assert_Coefficients;

   procedure Identity_At_Origin (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D
          ((X => 0.0, Y => 0.0), 0.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform,
         "identity Get_Rotation_Matrix_2D must return a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         1.0,
         0.0,
         0.0,
         0.0,
         1.0,
         0.0,
         "identity Get_Rotation_Matrix_2D must be [1 0 0; 0 1 0]");
   end Identity_At_Origin;

   procedure Zero_Angle_Nonzero_Center_Is_Identity (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D
          ((X => 10.0, Y => 20.0), 0.0, 1.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform,
         "zero-angle rotation about a nonzero center must remain 2x3 Float64");
      Assert_Coefficients
        (Transform,
         1.0,
         0.0,
         0.0,
         0.0,
         1.0,
         0.0,
         "zero-angle Scale 1 must not invent a translation");
   end Zero_Angle_Nonzero_Center_Is_Identity;

   procedure Ninety_Degree_Coefficients (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Center    : constant OpenCV.Core.Float32_Point := (X => 10.0, Y => 20.0);
      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D (Center, 90.0);
      --  90 degrees: alpha = 0, beta = 1
      --  [  0  1  (1-0)*10 - 1*20 ] = [ 0  1  -10 ]
      --  [ -1  0   1*10 + (1-0)*20] = [-1  0   30 ]
   begin
      Assert_Is_2x3_Float64_C1
        (Transform, "90-degree rotation must return a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         0.0,
         1.0,
         -10.0,
         -1.0,
         0.0,
         30.0,
         "90-degree rotation must match the documented alpha/beta formula");
   end Ninety_Degree_Coefficients;

   procedure Scale_Around_Nonzero_Center (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D
          ((X => 10.0, Y => 20.0), 0.0, 2.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform, "scaled identity must remain a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         2.0,
         0.0,
         -10.0,
         0.0,
         2.0,
         -20.0,
         "Scale 2 about a nonzero center must scale around that center");
   end Scale_Around_Nonzero_Center;

   procedure Negative_Angle_Flips_Beta (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Center   : constant OpenCV.Core.Float32_Point := (X => 10.0, Y => 20.0);
      Positive : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D (Center, 90.0);
      Negative : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D (Center, -90.0);
      Pos_Beta : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Access.Get (Positive, 0, 1);
      Neg_Beta : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Access.Get (Negative, 0, 1);
   begin
      AUnit.Assertions.Assert
        (Pos_Beta > 0.0, "positive 90 degrees must produce a positive beta");
      AUnit.Assertions.Assert
        (Neg_Beta < 0.0, "negative 90 degrees must produce a negative beta");
      AUnit.Assertions.Assert
        (Nearly_Equal (Neg_Beta, -Pos_Beta),
         "negating the angle must negate beta");
   end Negative_Angle_Flips_Beta;

   procedure Radians_Match_Degrees (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Center  : constant OpenCV.Core.Float32_Point := (X => 7.5, Y => 3.25);
      Degrees : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D
          (Center, 90.0, 1.0, OpenCV.Core.Degrees);
      Radians : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D
          (Center,
           OpenCV.Core.Float64_Value (Ada.Numerics.Pi / 2.0),
           1.0,
           OpenCV.Core.Radians);
   begin
      Assert_Coefficients
        (Radians,
         OpenCV.Core.Float64_Access.Get (Degrees, 0, 0),
         OpenCV.Core.Float64_Access.Get (Degrees, 0, 1),
         OpenCV.Core.Float64_Access.Get (Degrees, 0, 2),
         OpenCV.Core.Float64_Access.Get (Degrees, 1, 0),
         OpenCV.Core.Float64_Access.Get (Degrees, 1, 1),
         OpenCV.Core.Float64_Access.Get (Degrees, 1, 2),
         "pi/2 radians must match 90 degrees");
   end Radians_Match_Degrees;

   procedure Zero_Scale_Is_Accepted (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D
          ((X => 4.0, Y => 8.0), 0.0, 0.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform, "zero Scale must still return a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         0.0,
         0.0,
         4.0,
         0.0,
         0.0,
         8.0,
         "zero Scale about a center must map that center to itself");
   end Zero_Scale_Is_Accepted;

   procedure Negative_Scale_Is_Accepted (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D
          ((X => 5.0, Y => 6.0), 0.0, -1.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform, "negative Scale must still return a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         -1.0,
         0.0,
         10.0,
         0.0,
         -1.0,
         12.0,
         "negative finite Scale must remain accepted");
   end Negative_Scale_Is_Accepted;

   procedure Composes_With_Warp_Affine (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Transform   : constant OpenCV.Core.Mat :=
        OpenCV.Image_Processing.Get_Rotation_Matrix_2D
          ((X => 1.0, Y => 1.0), 90.0);
      Destination : OpenCV.Core.Mat;
   begin
      for Row in 0 .. 2 loop
         for Column in 0 .. 2 loop
            OpenCV.Core.UInt8_Access.Set
              (Source,
               Row,
               Column,
               Interfaces.Unsigned_8 (10 * Row + Column + 1));
         end loop;
      end loop;

      OpenCV.Image_Processing.Warp_Affine
        (Source,
         Transform,
         Destination,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Nearest_Neighbor);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "Warp_Affine must accept Get_Rotation_Matrix_2D without conversion");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 1, 1)
         = OpenCV.Core.UInt8_Access.Get (Source, 1, 1),
         "90-degree rotation about the image center must keep"
         & " the center pixel");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 1, 0)
         = OpenCV.Core.UInt8_Access.Get (Source, 0, 1),
         "90-degree counter-clockwise rotation must map (1,0) to (0,1)");
   end Composes_With_Warp_Affine;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Discard : OpenCV.Core.Mat;

      procedure Nan_Center_X is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (NaN_Bits_32);
         Discard :=
           OpenCV.Image_Processing.Get_Rotation_Matrix_2D
             ((X => Value, Y => 0.0), 0.0);
      end Nan_Center_X;

      procedure Inf_Center_Y is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (Inf_Bits_32);
         Discard :=
           OpenCV.Image_Processing.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => Value), 0.0);
      end Inf_Center_Y;

      procedure Nan_Angle is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         Discard :=
           OpenCV.Image_Processing.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => 0.0), Value);
      end Nan_Angle;

      procedure Inf_Angle is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Infinity_Bits);
         Discard :=
           OpenCV.Image_Processing.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => 0.0), Value);
      end Inf_Angle;

      procedure Nan_Scale is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         Discard :=
           OpenCV.Image_Processing.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => 0.0), 0.0, Value);
      end Nan_Scale;

      procedure Inf_Scale is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Neg_Inf_Bits);
         Discard :=
           OpenCV.Image_Processing.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => 0.0), 0.0, Value);
      end Inf_Scale;
   begin
      Assert_Raises_OpenCV_Error
        (Nan_Center_X'Access,
         "Get_Rotation_Matrix_2D must reject a NaN Center.X");
      Assert_Raises_OpenCV_Error
        (Inf_Center_Y'Access,
         "Get_Rotation_Matrix_2D must reject an infinite Center.Y");
      Assert_Raises_OpenCV_Error
        (Nan_Angle'Access, "Get_Rotation_Matrix_2D must reject a NaN Angle");
      Assert_Raises_OpenCV_Error
        (Inf_Angle'Access,
         "Get_Rotation_Matrix_2D must reject an infinite Angle");
      Assert_Raises_OpenCV_Error
        (Nan_Scale'Access, "Get_Rotation_Matrix_2D must reject a NaN Scale");
      Assert_Raises_OpenCV_Error
        (Inf_Scale'Access,
         "Get_Rotation_Matrix_2D must reject an infinite Scale");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Check
        (Center_X      : Interfaces.C.C_float;
         Center_Y      : Interfaces.C.C_float;
         Angle_Degrees : Interfaces.C.double;
         Scale         : Interfaces.C.double)
      is
         pragma Suppress (Validity_Check);
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;

         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              C_API.Get_Rotation_Matrix_2D
                (Destination_Handle, Center_X, Center_Y, Angle_Degrees, Scale);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Get_Rotation_Matrix_2D C ABI input must return"
            & " invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "finite") /= 0,
            "malformed Get_Rotation_Matrix_2D C ABI input must mention"
            & " finite");
      end Check;

      procedure Check_Bits
        (Center_X_Bits : Interfaces.Unsigned_32;
         Center_Y_Bits : Interfaces.Unsigned_32;
         Angle_Bits    : Interfaces.Unsigned_64;
         Scale_Bits    : Interfaces.Unsigned_64)
      is
         pragma Suppress (Validity_Check);
         Center_X : Interfaces.C.C_float;
         Center_Y : Interfaces.C.C_float;
         Angle    : Interfaces.C.double;
         Scale    : Interfaces.C.double;
      begin
         Center_X := Interfaces.C.C_float (Bits_To_Float32 (Center_X_Bits));
         Center_Y := Interfaces.C.C_float (Bits_To_Float32 (Center_Y_Bits));
         Angle := Interfaces.C.double (Bits_To_Float64 (Angle_Bits));
         Scale := Interfaces.C.double (Bits_To_Float64 (Scale_Bits));
         Check (Center_X, Center_Y, Angle, Scale);
      end Check_Bits;

      procedure Check_Success is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;

         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              C_API.Get_Rotation_Matrix_2D
                (Destination_Handle, 0.0, 0.0, 0.0, 1.0);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "valid Get_Rotation_Matrix_2D C ABI input must succeed");
         Assert_Is_2x3_Float64_C1
           (Destination,
            "valid Get_Rotation_Matrix_2D C ABI call must return 2x3 Float64");
      end Check_Success;

      Zero_Bits_32 : constant Interfaces.Unsigned_32 := 0;
      One_Bits_64  : constant Interfaces.Unsigned_64 :=
        16#3FF0_0000_0000_0000#;
   begin
      Check_Bits (NaN_Bits_32, Zero_Bits_32, 0, One_Bits_64);
      Check_Bits (Zero_Bits_32, Inf_Bits_32, 0, One_Bits_64);
      Check_Bits (Zero_Bits_32, Zero_Bits_32, NaN_Bits, One_Bits_64);
      Check_Bits (Zero_Bits_32, Zero_Bits_32, Infinity_Bits, One_Bits_64);
      Check_Bits (Zero_Bits_32, Zero_Bits_32, 0, NaN_Bits);
      Check_Bits (Zero_Bits_32, Zero_Bits_32, 0, Neg_Inf_Bits);
      Check_Success;
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D identity at origin",
            Identity_At_Origin'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D zero angle at nonzero center is identity",
            Zero_Angle_Nonzero_Center_Is_Identity'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D 90-degree coefficients",
            Ninety_Degree_Coefficients'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D scale around a nonzero center",
            Scale_Around_Nonzero_Center'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D negative angle flips beta",
            Negative_Angle_Flips_Beta'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D radians match degrees",
            Radians_Match_Degrees'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D zero scale is accepted",
            Zero_Scale_Is_Accepted'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D negative scale is accepted",
            Negative_Scale_Is_Accepted'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D composes with Warp_Affine",
            Composes_With_Warp_Affine'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Rotation_Matrix_Tests;
