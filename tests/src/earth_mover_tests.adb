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
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Earth_Mover_Tests is
   pragma Suppress (Validity_Check);
   package IP renames OpenCV.Image_Processing;
   package F renames OpenCV.Core.Float32_Access;
   package Raw renames OpenCV.Image_Processing.Internal.C_API;
   use type OpenCV.Float32_Value;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type Raw.Status;
   use type Interfaces.C.C_float;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   type Values is array (Positive range <>) of OpenCV.Float32_Value;
   function Matrix
     (Rows, Cols : Positive; Data : Values) return OpenCV.Core.Mat
   is
      M : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Cols, (OpenCV.Core.Float32, 1));
   begin
      for R in 0 .. Rows - 1 loop
         for C in 0 .. Cols - 1 loop
            F.Set (M, R, C, Data (Data'First + R * Cols + C));
         end loop;
      end loop;
      return M;
   end Matrix;

   function Near (A, B : OpenCV.Float32_Value) return Boolean
   is (abs (A - B) < 1.0e-4);

   procedure Reject (Attempt : not null access procedure; Message : String) is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, Message);
   end Reject;

   function NaN is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_32, OpenCV.Float32_Value);

   procedure Metrics (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant OpenCV.Core.Mat := Matrix (1, 3, (1.0, 0.0, 0.0));
      B : constant OpenCV.Core.Mat := Matrix (1, 3, (1.0, 3.0, 4.0));
   begin
      for Metric in IP.Earth_Mover_Metric loop
         AUnit.Assertions.Assert
           (Near (IP.Earth_Mover_Distance (A, A, Metric), 0.0), "identity");
      end loop;
      AUnit.Assertions.Assert
        (Near (IP.Earth_Mover_Distance (A, B, IP.Manhattan_EMD), 7.0)
         and then Near (IP.Earth_Mover_Distance (A, B), 5.0)
         and then Near
                    (IP.Earth_Mover_Distance (A, B, IP.Chessboard_EMD), 4.0),
         "L1 L2 chessboard");
   end Metrics;

   procedure Unequal_And_Flow (T : in out Fixture) is
      pragma Unreferenced (T);
      A      : constant OpenCV.Core.Mat :=
        Matrix (2, 2, (1.0, 0.0, 0.0, 999.0));
      B      : constant OpenCV.Core.Mat := Matrix (1, 2, (2.0, 10.0));
      Answer : constant IP.Earth_Mover_Result :=
        IP.Earth_Mover_Distance_With_Flow (A, B);
   begin
      AUnit.Assertions.Assert
        (Near (Answer.Distance, 5.0)
         and then Answer.Flow.Rows = 2
         and then Answer.Flow.Columns = 1
         and then Answer.Flow.Depth = OpenCV.Core.Float32
         and then Answer.Flow.Channels = 1
         and then Near (F.Get (Answer.Flow, 0, 0), 1.0)
         and then Near (F.Get (Answer.Flow, 1, 0), 0.0)
         and then Near (F.Get (A, 1, 1), 999.0),
         "unequal dummy and zero row flow");
   end Unequal_And_Flow;

   procedure Cost_Flow (T : in out Fixture) is
      pragma Unreferenced (T);
      A      : constant OpenCV.Core.Mat := Matrix (2, 1, (1.0, 1.0));
      B      : constant OpenCV.Core.Mat := Matrix (2, 1, (1.0, 1.0));
      C      : constant OpenCV.Core.Mat := Matrix (2, 2, (1.0, 3.0, 4.0, 2.0));
      Answer : constant IP.Earth_Mover_Result :=
        IP.Earth_Mover_Distance_With_Cost_And_Flow (A, B, C);
   begin
      AUnit.Assertions.Assert
        (Near (Answer.Distance, 1.5)
         and then Near (F.Get (Answer.Flow, 0, 0), 1.0)
         and then Near (F.Get (Answer.Flow, 1, 1), 1.0)
         and then Near (F.Get (Answer.Flow, 0, 1), 0.0)
         and then Near (F.Get (C, 0, 0), 1.0),
         "explicit costs and optimal flow");
   end Cost_Flow;

   procedure Cost_Ignores_Coordinates (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 1.0e30));
      B : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, -1.0e30));
      C : constant OpenCV.Core.Mat := Matrix (1, 1, (1 => 2.0));
   begin
      AUnit.Assertions.Assert
        (Near (IP.Earth_Mover_Distance_With_Cost (A, B, C), 2.0),
         "explicit cost ignores coordinates");
   end Cost_Ignores_Coordinates;

   procedure Regions (T : in out Fixture) is
      pragma Unreferenced (T);
      P : constant OpenCV.Core.Mat :=
        Matrix (2, 4, (99.0, 1.0, 0.0, 88.0, 77.0, 1.0, 10.0, 66.0));
      Q : constant OpenCV.Core.Mat := Matrix (1, 4, (99.0, 1.0, 5.0, 88.0));
      A : constant OpenCV.Core.Mat :=
        OpenCV.Core.Region (P, (X => 1, Y => 0, Width => 2, Height => 2));
      B : constant OpenCV.Core.Mat :=
        OpenCV.Core.Region (Q, (X => 1, Y => 0, Width => 2, Height => 1));
   begin
      AUnit.Assertions.Assert
        (Near
           (IP.Earth_Mover_Distance (A, B),
            IP.Earth_Mover_Distance (A.Clone, B.Clone))
         and then Near (F.Get (P, 0, 0), 99.0)
         and then Near (F.Get (Q, 0, 3), 88.0),
         "packed Region signatures");
   end Regions;

   procedure Bad_Signatures (T : in out Fixture) is
      pragma Unreferenced (T);
      Good : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      M    : OpenCV.Core.Mat;
      procedure Try is
         V : constant OpenCV.Float32_Value :=
           IP.Earth_Mover_Distance (M, Good);
         pragma Unreferenced (V);
      begin
         null;
      end Try;
   begin
      Reject (Try'Access, "empty signature");
      M := Matrix (1, 1, (1 => 1.0));
      Reject (Try'Access, "one column");
      M := Matrix (1, 2, (-1.0, 0.0));
      Reject (Try'Access, "negative weight");
      M := Matrix (1, 2, (0.0, 0.0));
      Reject (Try'Access, "zero weight");
      M := Matrix (1, 2, (NaN (16#7FC0_0000#), 0.0));
      Reject (Try'Access, "NaN weight");
      M := Matrix (1, 2, (1.0, NaN (16#7F80_0000#)));
      Reject (Try'Access, "infinite coordinate");
      M := Matrix (1, 2, (1.0, 1.0e20));
      Reject (Try'Access, "sentinel coordinate distance");
      M :=
        Matrix
          (2,
           2,
           (OpenCV.Float32_Value'Last, 0.0, OpenCV.Float32_Value'Last, 0.0));
      Reject (Try'Access, "weight sum overflow");
      M := Matrix (1, 2, (1.0, 3.0));
      AUnit.Assertions.Assert
        (Near (IP.Earth_Mover_Distance (M, Good), 3.0),
         "recover after public rejection");
   end Bad_Signatures;

   procedure Bad_Costs (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant OpenCV.Core.Mat := Matrix (1, 1, (1 => 1.0));
      M : OpenCV.Core.Mat;
      procedure Try is
         V : constant OpenCV.Float32_Value :=
           IP.Earth_Mover_Distance_With_Cost (A, A, M);
         pragma Unreferenced (V);
      begin
         null;
      end Try;
   begin
      Reject (Try'Access, "empty cost");
      M := Matrix (1, 2, (1.0, 2.0));
      Reject (Try'Access, "wrong cost shape");
      for V of
        Values'(NaN (16#7FC0_0000#), NaN (16#7F80_0000#), -1.0, 1.0e20, 2.0e20)
      loop
         M := Matrix (1, 1, (1 => V));
         Reject (Try'Access, "invalid cost value");
      end loop;
      M := Matrix (1, 1, (1 => 3.0));
      AUnit.Assertions.Assert
        (Near (IP.Earth_Mover_Distance_With_Cost (A, A, M), 3.0),
         "recover after cost rejection");
   end Bad_Costs;

   procedure Legacy_Overflow (T : in out Fixture) is
      pragma Unreferenced (T);
      A : OpenCV.Core.Mat :=
        OpenCV.Core.Create (16_000, 2, (OpenCV.Core.Float32, 1));
      B : OpenCV.Core.Mat :=
        OpenCV.Core.Create (16_000, 2, (OpenCV.Core.Float32, 1));
      procedure Try is
         V : constant OpenCV.Float32_Value := IP.Earth_Mover_Distance (A, B);
         pragma Unreferenced (V);
      begin
         null;
      end Try;
   begin
      OpenCV.Core.Set_To (A, (others => 0.0));
      OpenCV.Core.Set_To (B, (others => 0.0));
      F.Set (A, 0, 0, 1.0);
      F.Set (B, 0, 0, 1.0);
      Reject (Try'Access, "legacy full-row signed buffer overflow");
   end Legacy_Overflow;

   procedure Raw_Atomic (T : in out Fixture) is
      pragma Unreferenced (T);
      A      : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      Bad    : constant OpenCV.Core.Mat := Matrix (1, 1, (1 => 1.0));
      Huge   : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 1.0e20));
      Output : OpenCV.Core.Mat := Matrix (1, 1, (1 => 42.0));
      Value  : aliased Interfaces.C.C_float := -17.0;
      Status : Raw.Status;
      procedure With_A (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure With_B (J : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            procedure With_Out
              (K : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Raw.Earth_Mover_Distance_Flow (H, J, 99, J, Value'Access, K);
            end With_Out;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Output, With_Out'Access);
         end With_B;
         procedure With_Huge (J : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure With_Out
              (K : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Raw.Earth_Mover_Distance_Flow (H, J, 1, H, Value'Access, K);
            end With_Out;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Output, With_Out'Access);
         end With_Huge;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Bad, With_B'Access);
         OpenCV.Core.Module_Interop.With_Input_Handle (Huge, With_Huge'Access);
      end With_A;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (A, With_A'Access);
      AUnit.Assertions.Assert
        (Status = Raw.Error_Invalid_Argument
         and then Value = -17.0
         and then Near (F.Get (Output, 0, 0), 42.0),
         "raw rejection is atomic");
      AUnit.Assertions.Assert
        (Near (IP.Earth_Mover_Distance (A, A), 0.0),
         "valid solve after raw rejection");
   end Raw_Atomic;

   procedure Bad_Signature_Layouts (T : in out Fixture) is
      pragma Unreferenced (T);
      Good : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      M    : OpenCV.Core.Mat;
      procedure Try is
         V : constant OpenCV.Float32_Value :=
           IP.Earth_Mover_Distance (M, Good);
         pragma Unreferenced (V);
      begin
         null;
      end Try;
   begin
      M :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(2, 2, 2), (OpenCV.Core.Float32, 1));
      Reject (Try'Access, "N-D signature");
      M := OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Reject (Try'Access, "wrong depth");
      M := OpenCV.Core.Create (1, 2, (OpenCV.Core.Float32, 2));
      Reject (Try'Access, "wrong channel count");
      M := Matrix (1, 3, (1.0, 0.0, 0.0));
      Reject (Try'Access, "mismatched columns");
      M := Matrix (1, 2, (NaN (16#7F80_0000#), 0.0));
      Reject (Try'Access, "infinite weight");
      M := Matrix (1, 2, (1.0, NaN (16#7FC0_0000#)));
      Reject (Try'Access, "NaN coordinate");
      M := Matrix (1, 2, (1.0, OpenCV.Float32_Value'Last));
      declare
         Opposite : constant OpenCV.Core.Mat :=
           Matrix (1, 2, (1.0, -OpenCV.Float32_Value'Last));
         procedure Try_Overflow is
            V : constant OpenCV.Float32_Value :=
              IP.Earth_Mover_Distance (M, Opposite);
            pragma Unreferenced (V);
         begin
            null;
         end Try_Overflow;
      begin
         Reject (Try_Overflow'Access, "Float32 difference overflow");
      end;
   end Bad_Signature_Layouts;

   procedure Bad_Cost_Layouts (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant OpenCV.Core.Mat := Matrix (1, 1, (1 => 1.0));
      M : OpenCV.Core.Mat;
      procedure Try is
         V : constant OpenCV.Float32_Value :=
           IP.Earth_Mover_Distance_With_Cost (A, A, M);
         pragma Unreferenced (V);
      begin
         null;
      end Try;
   begin
      M := OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Reject (Try'Access, "cost depth");
      M := OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 2));
      Reject (Try'Access, "cost channels");
      M := Matrix (2, 1, (1.0, 1.0));
      Reject (Try'Access, "cost rows");
      M := Matrix (1, 2, (1.0, 1.0));
      Reject (Try'Access, "cost columns");
   end Bad_Cost_Layouts;

   procedure Region_Cost (T : in out Fixture) is
      pragma Unreferenced (T);
      A      : constant OpenCV.Core.Mat := Matrix (2, 1, (1.0, 1.0));
      Parent : constant OpenCV.Core.Mat :=
        Matrix (2, 4, (99.0, 1.0, 3.0, 88.0, 77.0, 4.0, 2.0, 66.0));
      Cost   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Region (Parent, (X => 1, Y => 0, Width => 2, Height => 2));
   begin
      AUnit.Assertions.Assert
        (Near
           (IP.Earth_Mover_Distance_With_Cost (A, A, Cost),
            IP.Earth_Mover_Distance_With_Cost (A, A, Cost.Clone))
         and then Near (F.Get (Parent, 0, 0), 99.0)
         and then Near (F.Get (Parent, 1, 3), 66.0),
         "Region cost is packed and parent untouched");
   end Region_Cost;

   procedure Raw_Validation (T : in out Fixture) is
      pragma Unreferenced (T);
      A      : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      Bad    : constant OpenCV.Core.Mat := Matrix (1, 1, (1 => 1.0));
      Value  : aliased Interfaces.C.C_float := -17.0;
      Status : Raw.Status;
      procedure With_A (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure With_B (J : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status := Raw.Earth_Mover_Distance (H, H, 1, J, null);
            AUnit.Assertions.Assert
              (Status = Raw.Error_Invalid_Argument, "null result pointer");
            Status := Raw.Earth_Mover_Distance (J, H, 1, J, Value'Access);
            AUnit.Assertions.Assert
              (Status = Raw.Error_Invalid_Argument and then Value = -17.0,
               "malformed signature");
            Status := Raw.Earth_Mover_Distance (H, H, 3, H, Value'Access);
            AUnit.Assertions.Assert
              (Status = Raw.Error_Invalid_Argument and then Value = -17.0,
               "malformed USER cost");
            Status := Raw.Earth_Mover_Distance (H, H, 1, J, Value'Access);
            AUnit.Assertions.Assert
              (Status = Raw.Success and then Value = 0.0,
               "raw recovery after rejection");
         end With_B;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Bad, With_B'Access);
      end With_A;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (A, With_A'Access);
   end Raw_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Three metrics and identity", Metrics'Access));
      Result.Add_Test
        (Caller.Create ("Unequal mass and flow", Unequal_And_Flow'Access));
      Result.Add_Test
        (Caller.Create ("Explicit cost optimal flow", Cost_Flow'Access));
      Result.Add_Test
        (Caller.Create
           ("Cost ignores coordinates", Cost_Ignores_Coordinates'Access));
      Result.Add_Test
        (Caller.Create ("Region packed signatures", Regions'Access));
      Result.Add_Test
        (Caller.Create ("Invalid signatures", Bad_Signatures'Access));
      Result.Add_Test
        (Caller.Create ("Invalid custom costs", Bad_Costs'Access));
      Result.Add_Test
        (Caller.Create ("Legacy buffer overflow", Legacy_Overflow'Access));
      Result.Add_Test
        (Caller.Create ("Raw failure atomicity", Raw_Atomic'Access));
      Result.Add_Test
        (Caller.Create
           ("Signature layouts and arithmetic", Bad_Signature_Layouts'Access));
      Result.Add_Test
        (Caller.Create ("Cost type and geometry", Bad_Cost_Layouts'Access));
      Result.Add_Test
        (Caller.Create ("Packed Region cost", Region_Cost'Access));
      Result.Add_Test
        (Caller.Create
           ("Raw input validation and recovery", Raw_Validation'Access));
      return Result'Access;
   end Suite;
end Earth_Mover_Tests;
