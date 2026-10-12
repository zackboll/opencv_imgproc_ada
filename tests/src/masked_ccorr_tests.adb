with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Masked_CCORR_Tests is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Point_Coordinate;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   procedure Check (S, T, M : OpenCV.Core.Mat; D : in out OpenCV.Core.Mat) is
      Best   : Interfaces.Unsigned_64 := 0;
      BX, BY : Integer := 0;
      Count  : Natural := 0;
   begin
      OpenCV.Image_Processing.Match_Template
        (S, T, M, D, OpenCV.Image_Processing.Cross_Correlation);
      AUnit.Assertions.Assert
        (D.Rows = S.Rows - T.Rows + 1
         and then D.Columns = S.Columns - T.Columns + 1
         and then D.Depth = OpenCV.Core.Float32
         and then D.Channels = 1,
         "CCORR Float32 geometry");
      for Y in 0 .. D.Rows - 1 loop
         for X in 0 .. D.Columns - 1 loop
            declare
               Sum : Interfaces.Unsigned_64 := 0;
            begin
               for V in 0 .. T.Rows - 1 loop
                  for U in 0 .. T.Columns - 1 loop
                     if OpenCV.Core.UInt8_Access.Get (M, V, U) /= 0 then
                        declare
                           Term : constant Interfaces.Unsigned_64 :=
                             Interfaces.Unsigned_64
                               (OpenCV.Core.UInt8_Access.Get (T, V, U))
                             * Interfaces.Unsigned_64
                                 (OpenCV.Core.UInt8_Access.Get
                                    (S, Y + V, X + U));
                        begin
                           AUnit.Assertions.Assert
                             (Sum <= Interfaces.Unsigned_64'Last - Term,
                              "checked UInt64 accumulation");
                           Sum := Sum + Term;
                        end;
                     end if;
                  end loop;
               end loop;
               declare
                  Expected : constant OpenCV.Float32_Value :=
                    OpenCV.Float32_Value (Sum);
                  ULP      : constant OpenCV.Float32_Value :=
                    OpenCV.Float32_Value'Adjacent
                      (Expected, OpenCV.Float32_Value'Last)
                    - Expected;
                  Limit    : constant Long_Float :=
                    Long_Float'Max (1.0E-4, 4.0 * Long_Float (ULP));
               begin
                  AUnit.Assertions.Assert
                    (abs (Long_Float (OpenCV.Core.Float32_Access.Get (D, Y, X))
                          - Long_Float (Expected))
                     <= Limit,
                     "independent integer oracle with fixed ULP ceiling");
               end;
               if Sum > Best then
                  Best := Sum;
                  BX := X;
                  BY := Y;
                  Count := 1;
               elsif Sum = Best then
                  Count := Count + 1;
               end if;
            end;
         end loop;
      end loop;
      if Count = 1 then
         declare
            Extrema : constant OpenCV.Core.Min_Max_Result :=
              OpenCV.Core.Min_Max_Loc (D);
         begin
            AUnit.Assertions.Assert
              (Extrema.Maximum_Location.X = OpenCV.Point_Coordinate (BX)
               and then Extrema.Maximum_Location.Y
                        = OpenCV.Point_Coordinate (BY),
               "unique oracle maximum location");
         end;
      end if;
   end Check;

   procedure Oracle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : OpenCV.Core.Mat := OpenCV.Core.Create (5, 7, (OpenCV.Core.UInt8, 1));
      T : OpenCV.Core.Mat := OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      M : OpenCV.Core.Mat := OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      D : OpenCV.Core.Mat;
   begin
      for Y in 0 .. 4 loop
         for X in 0 .. 6 loop
            OpenCV.Core.UInt8_Access.Set
              (S, Y, X, Interfaces.Unsigned_8 ((Y * 37 + X * 17) mod 256));
         end loop;
      end loop;
      for Mode in 0 .. 3 loop
         for Y in 0 .. 1 loop
            for X in 0 .. 2 loop
               OpenCV.Core.UInt8_Access.Set
                 (T, Y, X, Interfaces.Unsigned_8 (255 - Y * 13 - X * 7));
               OpenCV.Core.UInt8_Access.Set
                 (M,
                  Y,
                  X,
                  (if Mode = 0
                   then 255
                   elsif Mode = 1
                   then (if X = Y then 7 else 0)
                   elsif Mode = 2
                   then (if X = 0 and then Y = 0 then 127 else 0)
                   else 0));
            end loop;
         end loop;
         Check (S, T, M, D);
         if Mode = 3 then
            for Y in 0 .. D.Rows - 1 loop
               for X in 0 .. D.Columns - 1 loop
                  AUnit.Assertions.Assert
                    (OpenCV.Core.Float32_Access.Get (D, Y, X) = 0.0,
                     "zero mask numeric zero permits either sign");
               end loop;
            end loop;
         end if;
      end loop;
   end Oracle;

   procedure Landmark (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : OpenCV.Core.Mat := OpenCV.Core.Create (1, 5, (OpenCV.Core.UInt8, 1));
      T : OpenCV.Core.Mat := OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      M : OpenCV.Core.Mat := OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      D : OpenCV.Core.Mat;
   begin
      for X in 0 .. 4 loop
         OpenCV.Core.UInt8_Access.Set (S, 0, X, 0);
      end loop;
      OpenCV.Core.UInt8_Access.Set (S, 0, 3, 19);
      OpenCV.Core.UInt8_Access.Set (S, 0, 4, 255);
      OpenCV.Core.UInt8_Access.Set (T, 0, 0, 19);
      OpenCV.Core.UInt8_Access.Set (T, 0, 1, 255);
      OpenCV.Core.UInt8_Access.Set (M, 0, 0, 7);
      OpenCV.Core.UInt8_Access.Set (M, 0, 1, 0);
      Check (S, T, M, D);
      AUnit.Assertions.Assert
        (abs (OpenCV.Core.Float32_Access.Get (D, 0, 3) - 361.0) < 1.0E-4,
         "excluded Source corruption and Template corruption");
      OpenCV.Core.UInt8_Access.Set (T, 0, 1, 1);
      Check (S, T, M, D);
      OpenCV.Core.UInt8_Access.Set (S, 0, 3, 38);
      Check (S, T, M, D);
      AUnit.Assertions.Assert
        (abs (OpenCV.Core.Float32_Access.Get (D, 0, 3) - 722.0) < 1.0E-4,
         "brightness scales unnormalized score");
   end Landmark;

   procedure Regions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 9, (OpenCV.Core.UInt8, 1));
      D      : OpenCV.Core.Mat;
      Saved  : OpenCV.Float32_Value;
   begin
      for Y in 0 .. 5 loop
         for X in 0 .. 8 loop
            OpenCV.Core.UInt8_Access.Set
              (Parent, Y, X, Interfaces.Unsigned_8 (Y * 13 + X * 3 + 1));
         end loop;
      end loop;
      declare
         S      : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 1, Y => 1, Width => 6, Height => 4));
         T      : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 2, Y => 2, Width => 3, Height => 2));
         M      : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 3, Y => 2, Width => 3, Height => 2));
         Packed : OpenCV.Core.Mat;
      begin
         D := Parent.Region ((X => 0, Y => 0, Width => 1, Height => 1));
         Check (S, T, M, D);
         Check (S.Clone, T.Clone, M.Clone, Packed);
         for Y in 0 .. D.Rows - 1 loop
            for X in 0 .. D.Columns - 1 loop
               AUnit.Assertions.Assert
                 (OpenCV.Core.Float32_Access.Get (D, Y, X)
                  = OpenCV.Core.Float32_Access.Get (Packed, Y, X),
                  "isolated overlapping noncontinuous Regions");
            end loop;
         end loop;
      end;
      for Y in 0 .. 5 loop
         for X in 0 .. 8 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Parent, Y, X)
               = Interfaces.Unsigned_8 (Y * 13 + X * 3 + 1),
               "all inputs and parent unchanged");
         end loop;
      end loop;
      Saved := OpenCV.Core.Float32_Access.Get (D, 0, 0);
      OpenCV.Core.UInt8_Access.Set (Parent, 1, 1, 255);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (D, 0, 0) = Saved,
         "owning output outlives inputs and parent mutation");
   end Regions;

   procedure Degenerate (Test : in out Fixture) is
      pragma Unreferenced (Test);
      D : OpenCV.Core.Mat;
   begin
      for Rows in 1 .. 3 loop
         for Cols in 1 .. 4 loop
            declare
               S : OpenCV.Core.Mat :=
                 OpenCV.Core.Create (Rows, Cols, (OpenCV.Core.UInt8, 1));
               T : OpenCV.Core.Mat :=
                 OpenCV.Core.Create (Rows, Cols, (OpenCV.Core.UInt8, 1));
               M : OpenCV.Core.Mat :=
                 OpenCV.Core.Create (Rows, Cols, (OpenCV.Core.UInt8, 1));
            begin
               for Mode in 0 .. 2 loop
                  for Y in 0 .. Rows - 1 loop
                     for X in 0 .. Cols - 1 loop
                        OpenCV.Core.UInt8_Access.Set
                          (S, Y, X, (if Mode = 0 then 0 else 255));
                        OpenCV.Core.UInt8_Access.Set
                          (T, Y, X, (if Mode = 1 then 0 else 255));
                        OpenCV.Core.UInt8_Access.Set (M, Y, X, 127);
                     end loop;
                  end loop;
                  Check (S, T, M, D);
               end loop;
            end;
         end loop;
      end loop;
   end Degenerate;

   procedure Rejections (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Good   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Bad, D : OpenCV.Core.Mat;
      procedure Reject (S, T, M : OpenCV.Core.Mat) is
         Raised : Boolean := False;
      begin
         D := OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
         OpenCV.Core.UInt8_Access.Set (D, 0, 0, 73);
         begin
            OpenCV.Image_Processing.Match_Template
              (S, T, M, D, OpenCV.Image_Processing.Cross_Correlation);
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         AUnit.Assertions.Assert
           (Raised
            and then D.Depth = OpenCV.Core.UInt8
            and then OpenCV.Core.UInt8_Access.Get (D, 0, 0) = 73,
            "specific error and failure atomicity");
      end Reject;
   begin
      for Y in 0 .. 1 loop
         for X in 0 .. 1 loop
            OpenCV.Core.UInt8_Access.Set (Good, Y, X, 9);
         end loop;
      end loop;
      Reject (Bad, Good, Good);
      Reject (Good, Bad, Good);
      Reject (Good, Good, Bad);
      Bad := OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Reject (Bad, Good, Good);
      Bad := OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Reject (Good, Bad, Good);
      Bad := OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Reject (Good, Good, Bad);
      Reject (Bad, Good, Good);
      Check (Good, Good, Good, D);
   end Rejections;

   procedure Raw_Selector (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package API renames OpenCV.Image_Processing.Internal.C_API;
      use type API.Status;
      S      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      D      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Status : API.Status := API.Success;
      procedure Input (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Output (O : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status := API.Match_Template_Masked (H, H, H, O, -1);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (D, Output'Access);
      end Input;
   begin
      OpenCV.Core.UInt8_Access.Set (S, 0, 0, 9);
      OpenCV.Core.UInt8_Access.Set (D, 0, 0, 73);
      OpenCV.Core.Module_Interop.With_Input_Handle (S, Input'Access);
      AUnit.Assertions.Assert
        (Status /= API.Success
         and then OpenCV.Core.UInt8_Access.Get (D, 0, 0) = 73,
         "raw selector rejection preserves destination");
      Check (S, S, S, D);
   end Raw_Selector;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Masked CCORR oracle", Oracle'Access));
      Result.Add_Test
        (Caller.Create ("Masked CCORR landmark", Landmark'Access));
      Result.Add_Test (Caller.Create ("Masked CCORR Regions", Regions'Access));
      Result.Add_Test
        (Caller.Create ("Masked CCORR degenerate", Degenerate'Access));
      Result.Add_Test
        (Caller.Create ("Masked CCORR rejections", Rejections'Access));
      Result.Add_Test
        (Caller.Create ("Masked CCORR raw selector", Raw_Selector'Access));
      return Result'Access;
   end Suite;
end Masked_CCORR_Tests;
