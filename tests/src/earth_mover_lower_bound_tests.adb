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

package body Earth_Mover_Lower_Bound_Tests is
   --  Deliberately construct IEEE NaN/Infinity, as in existing EMD fixtures.
   --  Keep validity checking from intercepting them before public validation.
   pragma Suppress (Validity_Check);
   package IP renames OpenCV.Image_Processing;
   package F renames OpenCV.Core.Float32_Access;
   package Raw renames OpenCV.Image_Processing.Internal.C_API;
   use type OpenCV.Float32_Value;
   use type Interfaces.C.C_float;
   use type Interfaces.Unsigned_8;
   use type Raw.Status;

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

   function From_Bits is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_32, OpenCV.Float32_Value);

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

   procedure Check_Metric
     (Metric : IP.Earth_Mover_Metric; Expected : OpenCV.Float32_Value)
   is
      A : constant OpenCV.Core.Mat := Matrix (1, 3, (1.0, 0.0, 0.0));
      B : constant OpenCV.Core.Mat := Matrix (1, 3, (1.0, 3.0, 4.0));
      R : constant IP.Earth_Mover_Bounded_Result :=
        IP.Earth_Mover_Distance_With_Lower_Bound (A, B, Metric);
   begin
      AUnit.Assertions.Assert
        (R.Lower_Bound_Available
         and then R.Exact_Distance_Computed
         and then Near (R.Distance, Expected)
         and then Near (R.Lower_Bound, Expected),
         "default computes exact even when distance equals bound");
   end Check_Metric;

   procedure Manhattan (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Check_Metric (IP.Manhattan_EMD, 7.0);
   end Manhattan;

   procedure Euclidean (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Check_Metric (IP.Euclidean_EMD, 5.0);
   end Euclidean;

   procedure Chessboard (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Check_Metric (IP.Chessboard_EMD, 4.0);
   end Chessboard;

   procedure Check_Exit (Threshold : OpenCV.Float32_Value) is
      A : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      B : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 10.0));
      R : constant IP.Earth_Mover_Bounded_Result :=
        IP.Earth_Mover_Distance_With_Lower_Bound
          (A, B, Early_Exit_Threshold => Threshold);
   begin
      AUnit.Assertions.Assert
        (R.Lower_Bound_Available
         and then not R.Exact_Distance_Computed
         and then Near (R.Distance, 10.0)
         and then Near (R.Lower_Bound, 10.0),
         "native threshold shortcut");
   end Check_Exit;

   procedure Below_Bound (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Check_Exit (5.0);
   end Below_Bound;

   procedure Equal_Bound (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Check_Exit (10.0);
   end Equal_Bound;

   procedure Zero_Threshold (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant OpenCV.Core.Mat := Matrix (2, 2, (0.5, -1.0, 0.5, 1.0));
      B : constant OpenCV.Core.Mat := Matrix (2, 2, (0.5, -2.0, 0.5, 2.0));
      R : constant IP.Earth_Mover_Bounded_Result :=
        IP.Earth_Mover_Distance_With_Lower_Bound
          (A, B, Early_Exit_Threshold => 0.0);
   begin
      AUnit.Assertions.Assert
        (R.Lower_Bound_Available
         and then not R.Exact_Distance_Computed
         and then R.Lower_Bound = 0.0
         and then R.Distance = 0.0
         and then Near (IP.Earth_Mover_Distance (A, B), 1.0),
         "zero means bound-only, not exact-plus-bound");
   end Zero_Threshold;

   procedure Positive_Threshold (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant OpenCV.Core.Mat := Matrix (2, 2, (0.5, -1.0, 0.5, 1.0));
      B : constant OpenCV.Core.Mat := Matrix (2, 2, (0.5, -2.0, 0.5, 2.0));
      R : constant IP.Earth_Mover_Bounded_Result :=
        IP.Earth_Mover_Distance_With_Lower_Bound
          (A, B, Early_Exit_Threshold => 0.5);
   begin
      AUnit.Assertions.Assert
        (R.Lower_Bound_Available
         and then R.Exact_Distance_Computed
         and then R.Lower_Bound = 0.0
         and then R.Distance > 0.0
         and then Near (R.Distance, IP.Earth_Mover_Distance (A, B)),
         "positive threshold continues past zero bound");
   end Positive_Threshold;

   procedure Default_Exactness (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant OpenCV.Core.Mat :=
        Matrix (3, 3, (0.25, -1.0, 2.0, 0.25, 3.0, 4.0, 0.5, 5.0, -6.0));
   begin
      for Offset in 0 .. 2 loop
         declare
            B : constant OpenCV.Core.Mat :=
              Matrix
                (2,
                 3,
                 (0.5, OpenCV.Float32_Value (Offset), 1.0, 0.5, -2.0, -3.0));
         begin
            for Metric in IP.Earth_Mover_Metric loop
               declare
                  R : constant IP.Earth_Mover_Bounded_Result :=
                    IP.Earth_Mover_Distance_With_Lower_Bound (A, B, Metric);
               begin
                  AUnit.Assertions.Assert
                    (R.Lower_Bound_Available
                     and then R.Exact_Distance_Computed
                     and then R.Distance
                              = IP.Earth_Mover_Distance (A, B, Metric)
                     and then R.Lower_Bound <= R.Distance + 1.0e-4,
                     "default exactness and bound across distributions");
               end;
            end loop;
         end;
      end loop;
   end Default_Exactness;

   procedure Unequal_Mass (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      B : constant OpenCV.Core.Mat := Matrix (1, 2, (2.0, 10.0));
   begin
      for Threshold of Values'(0.0, 123.0) loop
         declare
            R : constant IP.Earth_Mover_Bounded_Result :=
              IP.Earth_Mover_Distance_With_Lower_Bound
                (A, B, Early_Exit_Threshold => Threshold);
         begin
            AUnit.Assertions.Assert
              (not R.Lower_Bound_Available
               and then R.Lower_Bound = 0.0
               and then R.Exact_Distance_Computed
               and then R.Distance = IP.Earth_Mover_Distance (A, B)
               and then Near (R.Distance, 5.0),
               "dummy-cluster exact solve, never publish input threshold");
         end;
      end loop;
   end Unequal_Mass;

   procedure Check_Tolerance
     (Second_Mass : OpenCV.Float32_Value; Available : Boolean)
   is
      A : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      B : constant OpenCV.Core.Mat := Matrix (1, 2, (Second_Mass, 10.0));
      R : constant IP.Earth_Mover_Bounded_Result :=
        IP.Earth_Mover_Distance_With_Lower_Bound
          (A, B, Early_Exit_Threshold => 0.0);
   begin
      AUnit.Assertions.Assert
        (R.Lower_Bound_Available = Available
         and then R.Exact_Distance_Computed = not Available,
         "strict native Float32 tolerance relative to first mass");
      if Available then
         AUnit.Assertions.Assert (Near (R.Lower_Bound, 10.0), "center bound");
      else
         AUnit.Assertions.Assert
           (R.Lower_Bound = 0.0
            and then R.Distance = IP.Earth_Mover_Distance (A, B),
            "outside tolerance computes exact");
      end if;
   end Check_Tolerance;

   procedure Inside_Tolerance (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      --  1 + 42 * 2**(-23): about 5e-6, well inside 1e-5.
      Check_Tolerance (From_Bits (16#3F80_002A#), True);
   end Inside_Tolerance;

   procedure Outside_Tolerance (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      --  1 + 168 * 2**(-23): about 2e-5, well outside 1e-5.
      Check_Tolerance (From_Bits (16#3F80_00A8#), False);
   end Outside_Tolerance;

   procedure Regions (T : in out Fixture) is
      pragma Unreferenced (T);
      P : constant OpenCV.Core.Mat :=
        Matrix (2, 4, (-99.0, 0.5, -1.0, 999.0, -88.0, 0.5, 1.0, 888.0));
      Q : constant OpenCV.Core.Mat :=
        Matrix (2, 4, (-77.0, 0.5, 0.0, 777.0, -66.0, 0.5, 4.0, 666.0));
      A : constant OpenCV.Core.Mat :=
        P.Region ((X => 1, Y => 0, Width => 2, Height => 2));
      B : constant OpenCV.Core.Mat :=
        Q.Region ((X => 1, Y => 0, Width => 2, Height => 2));
   begin
      for Threshold of Values'(0.0, OpenCV.Float32_Value'Last) loop
         declare
            R : constant IP.Earth_Mover_Bounded_Result :=
              IP.Earth_Mover_Distance_With_Lower_Bound
                (A, B, Early_Exit_Threshold => Threshold);
            C : constant IP.Earth_Mover_Bounded_Result :=
              IP.Earth_Mover_Distance_With_Lower_Bound
                (A.Clone, B.Clone, Early_Exit_Threshold => Threshold);
         begin
            AUnit.Assertions.Assert
              (R.Distance = C.Distance
               and then R.Lower_Bound = C.Lower_Bound
               and then R.Lower_Bound_Available = C.Lower_Bound_Available
               and then R.Exact_Distance_Computed = C.Exact_Distance_Computed,
               "non-contiguous Regions match packed clones in both paths");
         end;
      end loop;
      for R in 0 .. 1 loop
         for C in 0 .. 3 loop
            declare
               Expected_P : constant Values :=
                 (-99.0, 0.5, -1.0, 999.0, -88.0, 0.5, 1.0, 888.0);
               Expected_Q : constant Values :=
                 (-77.0, 0.5, 0.0, 777.0, -66.0, 0.5, 4.0, 666.0);
            begin
               AUnit.Assertions.Assert
                 (F.Get (P, R, C) = Expected_P (1 + R * 4 + C)
                  and then F.Get (Q, R, C) = Expected_Q (1 + R * 4 + C),
                  "borrowed inputs and all parent pixels unchanged");
            end;
         end loop;
      end loop;
   end Regions;

   procedure Reject_Threshold (Threshold : OpenCV.Float32_Value) is
      A : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      procedure Attempt is
         R : constant IP.Earth_Mover_Bounded_Result :=
           IP.Earth_Mover_Distance_With_Lower_Bound
             (A, A, Early_Exit_Threshold => Threshold);
      begin
         AUnit.Assertions.Assert (R.Exact_Distance_Computed, "unreachable");
      end Attempt;
   begin
      Reject (Attempt'Access, "public threshold must raise OpenCV_Error");
   end Reject_Threshold;

   procedure Negative_Threshold (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Reject_Threshold (-1.0);
   end Negative_Threshold;

   procedure Infinite_Threshold (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Reject_Threshold (From_Bits (16#7F80_0000#));
   end Infinite_Threshold;

   procedure NaN_Threshold (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Reject_Threshold (From_Bits (16#7FC0_0000#));
   end NaN_Threshold;

   procedure Derived_Nonfinite (T : in out Fixture) is
      pragma Unreferenced (T);
      A    : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0e20, 1.0e20));
      B    : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0e10, 0.0));
      C    : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0e10, 1.0e10));
      Safe : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 1.0e30));
      procedure Product_Overflow is
         R : constant IP.Earth_Mover_Bounded_Result :=
           IP.Earth_Mover_Distance_With_Lower_Bound (A, A, IP.Manhattan_EMD);
      begin
         AUnit.Assertions.Assert (R.Exact_Distance_Computed, "unreachable");
      end Product_Overflow;
      procedure Squared_Overflow is
         R : constant IP.Earth_Mover_Bounded_Result :=
           IP.Earth_Mover_Distance_With_Lower_Bound (B, C);
      begin
         AUnit.Assertions.Assert (R.Exact_Distance_Computed, "unreachable");
      end Squared_Overflow;
   begin
      Reject (Product_Overflow'Access, "nonfinite weighted center rejected");
      Reject (Squared_Overflow'Access, "nonfinite center L2 rejected");
      declare
         R : constant IP.Earth_Mover_Bounded_Result :=
           IP.Earth_Mover_Distance_With_Lower_Bound (Safe, Safe);
      begin
         AUnit.Assertions.Assert
           (R.Exact_Distance_Computed
            and then R.Lower_Bound_Available
            and then R.Distance = 0.0
            and then R.Lower_Bound = 0.0,
            "large finite coordinates and legal rounding remain accepted");
      end;
   end Derived_Nonfinite;

   procedure Exact_APIs (T : in out Fixture) is
      pragma Unreferenced (T);
      A         : constant OpenCV.Core.Mat :=
        Matrix (2, 2, (0.5, -1.0, 0.5, 1.0));
      B         : constant OpenCV.Core.Mat :=
        Matrix (2, 2, (0.5, -2.0, 0.5, 2.0));
      Cost      : constant OpenCV.Core.Mat :=
        Matrix (2, 2, (1.0, 3.0, 3.0, 1.0));
      Flow      : constant IP.Earth_Mover_Result :=
        IP.Earth_Mover_Distance_With_Flow (A, B);
      User_Flow : constant IP.Earth_Mover_Result :=
        IP.Earth_Mover_Distance_With_Cost_And_Flow (A, B, Cost);
   begin
      AUnit.Assertions.Assert
        (Near (IP.Earth_Mover_Distance (A, B), 1.0)
         and then Near (Flow.Distance, 1.0)
         and then Near (IP.Earth_Mover_Distance_With_Cost (A, B, Cost), 1.0)
         and then Near (User_Flow.Distance, 1.0)
         and then Near (F.Get (Flow.Flow, 0, 0), 0.5)
         and then Near (F.Get (User_Flow.Flow, 1, 1), 0.5),
         "all four original APIs still solve transport, not zero bound");
   end Exact_APIs;

   procedure Raw_Boundary (T : in out Fixture) is
      pragma Unreferenced (T);
      A         : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0, 0.0));
      Bad       : constant OpenCV.Core.Mat := Matrix (1, 2, (1.0e20, 1.0e20));
      Wide      : constant OpenCV.Core.Mat :=
        Matrix (1, 129, (1 => 1.0, 2 .. 129 => 0.0));
      Distance  : aliased Interfaces.C.C_float := -17.0;
      Bound     : aliased Interfaces.C.C_float := -18.0;
      Available : aliased Interfaces.Unsigned_8 := 19;
      Exact     : aliased Interfaces.Unsigned_8 := 20;
      Status    : Raw.Status;
      procedure With_A (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure With_Wide (J : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
         begin
            Status :=
              Raw.Earth_Mover_Distance_Lower_Bound
                (J,
                 J,
                 1,
                 0.0,
                 Distance'Access,
                 Bound'Access,
                 Available'Access,
                 Exact'Access);
            AUnit.Assertions.Assert
              (Status = Raw.Error_Invalid_Argument
               and then Distance = -17.0
               and then Bound = -18.0
               and then Available = 19
               and then Exact = 20,
               "legacy centers need scratch after the weight/index prefix");
         end With_Wide;
         procedure With_Bad (J : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
         begin
            for Missing in 0 .. 3 loop
               Status :=
                 Raw.Earth_Mover_Distance_Lower_Bound
                   (H,
                    H,
                    1,
                    0.0,
                    (if Missing = 0 then null else Distance'Access),
                    (if Missing = 1 then null else Bound'Access),
                    (if Missing = 2 then null else Available'Access),
                    (if Missing = 3 then null else Exact'Access));
               AUnit.Assertions.Assert
                 (Status = Raw.Error_Invalid_Argument, "all outputs required");
            end loop;
            Status :=
              Raw.Earth_Mover_Distance_Lower_Bound
                (J,
                 J,
                 0,
                 0.0,
                 Distance'Access,
                 Bound'Access,
                 Available'Access,
                 Exact'Access);
            AUnit.Assertions.Assert
              (Status = Raw.Error_OpenCV
               and then Distance = -17.0
               and then Bound = -18.0
               and then Available = 19
               and then Exact = 20,
               "numeric failure publishes nothing");
            Status :=
              Raw.Earth_Mover_Distance_Lower_Bound
                (H,
                 H,
                 3,
                 0.0,
                 Distance'Access,
                 Bound'Access,
                 Available'Access,
                 Exact'Access);
            AUnit.Assertions.Assert
              (Status = Raw.Error_Invalid_Argument, "no USER metric");
            Status :=
              Raw.Earth_Mover_Distance_Lower_Bound
                (H,
                 H,
                 1,
                 -1.0,
                 Distance'Access,
                 Bound'Access,
                 Available'Access,
                 Exact'Access);
            AUnit.Assertions.Assert
              (Status = Raw.Success
               and then Distance = 0.0
               and then Bound = 0.0
               and then Available = 1
               and then Exact = 0,
               "raw negative threshold is safe; semantic policy is Ada-only");
         end With_Bad;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Wide, With_Wide'Access);
         OpenCV.Core.Module_Interop.With_Input_Handle (Bad, With_Bad'Access);
      end With_A;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (A, With_A'Access);
   end Raw_Boundary;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("EMD bound: Manhattan default", Manhattan'Access));
      Result.Add_Test
        (Caller.Create ("EMD bound: Euclidean default", Euclidean'Access));
      Result.Add_Test
        (Caller.Create ("EMD bound: Chessboard default", Chessboard'Access));
      Result.Add_Test
        (Caller.Create ("EMD bound: below-bound exit", Below_Bound'Access));
      Result.Add_Test
        (Caller.Create ("EMD bound: inclusive exit", Equal_Bound'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: zero is bound-only", Zero_Threshold'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: positive continues", Positive_Threshold'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: default exactness", Default_Exactness'Access));
      Result.Add_Test
        (Caller.Create ("EMD bound: unequal mass", Unequal_Mass'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: inside tolerance", Inside_Tolerance'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: outside tolerance", Outside_Tolerance'Access));
      Result.Add_Test
        (Caller.Create ("EMD bound: Region isolation", Regions'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: negative threshold", Negative_Threshold'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: infinite threshold", Infinite_Threshold'Access));
      Result.Add_Test
        (Caller.Create ("EMD bound: NaN threshold", NaN_Threshold'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: derived nonfinite", Derived_Nonfinite'Access));
      Result.Add_Test
        (Caller.Create ("EMD bound: original APIs exact", Exact_APIs'Access));
      Result.Add_Test
        (Caller.Create
           ("EMD bound: raw atomicity and policy", Raw_Boundary'Access));
      return Result'Access;
   end Suite;
end Earth_Mover_Lower_Bound_Tests;
