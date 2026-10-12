with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Guil_Template_Tests is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   package U renames C.UInt8_Access;
   package API renames IP.Internal.C_API;
   use AUnit.Assertions;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.UInt8_Value;
   use type IP.Guil_Template_Match_Array;
   use type API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Blank (Rows, Columns : Natural) return C.Mat is
      M : C.Mat := C.Create (Rows, Columns, (C.UInt8, 1));
   begin
      C.Set_To (M, (others => 0.0));
      return M;
   end Blank;

   procedure Paint (M : in out C.Mat; X0, Y0, X1, Y1 : Natural) is
   begin
      for Y in Y0 .. Y1 loop
         for X in X0 .. X1 loop
            if Y in 0 .. M.Rows - 1 and then X in 0 .. M.Columns - 1 then
               U.Set (M, Y, X, 255);
            end if;
         end loop;
      end loop;
   end Paint;

   function Shape return C.Mat is
      M : C.Mat := Blank (48, 40);
   begin
      Paint (M, 6, 7, 32, 9);
      Paint (M, 31, 8, 33, 22);
      Paint (M, 14, 22, 32, 24);
      Paint (M, 14, 25, 16, 38);
      Paint (M, 6, 20, 14, 22);
      Paint (M, 8, 10, 12, 14);
      return M;
   end Shape;

   function Narrow return IP.Guil_Search_Parameters
   is ((Canny_Low          => 50,
        Canny_High         => 100,
        Minimum_Angle      => 0.0,
        Maximum_Angle      => 2.0,
        Angle_Step         => 1.0,
        Minimum_Scale      => 0.98,
        Maximum_Scale      => 1.02,
        Scale_Step         => 0.02,
        Angle_Threshold    => 50,
        Scale_Threshold    => 50,
        Position_Threshold => 100));
   function Place
     (Template                        : C.Mat;
      Angle                           : Integer;
      Num, Den, OX, OY, Rows, Columns : Natural) return C.Mat
   is
      Scene : C.Mat := Blank (Rows, Columns);
      CX    : constant Integer := Template.Columns / 2;
      CY    : constant Integer := Template.Rows / 2;
      Min_X : Integer := Integer'Last;
      Max_X : Integer := Integer'First;
      Min_Y : Integer := Integer'Last;
      Max_Y : Integer := Integer'First;
   begin
      for Y in 0 .. Template.Rows - 1 loop
         for X in 0 .. Template.Columns - 1 loop
            if U.Get (Template, Y, X) /= 0 then
               declare
                  DX : constant Integer := (X - CX) * Integer (Num);
                  DY : constant Integer := (Y - CY) * Integer (Num);
                  RX : Integer;
                  RY : Integer;
               begin
                  if Angle = 0 then
                     RX := DX / Integer (Den);
                     RY := DY / Integer (Den);
                  elsif Angle = 90 then
                     RX := DY / Integer (Den);
                     RY := -(DX / Integer (Den));
                  else
                     RX := -(DX / Integer (Den));
                     RY := -(DY / Integer (Den));
                  end if;
                  Min_X := Integer'Min (Min_X, RX);
                  Max_X := Integer'Max (Max_X, RX);
                  Min_Y := Integer'Min (Min_Y, RY);
                  Max_Y := Integer'Max (Max_Y, RY);
               end;
            end if;
         end loop;
      end loop;
      declare
         Shift_X : constant Integer := Integer (OX) - (Min_X + Max_X) / 2;
         Shift_Y : constant Integer := Integer (OY) - (Min_Y + Max_Y) / 2;
      begin
         for Y in 0 .. Template.Rows - 1 loop
            for X in 0 .. Template.Columns - 1 loop
               if U.Get (Template, Y, X) /= 0 then
                  declare
                     DX : constant Integer := (X - CX) * Integer (Num);
                     DY : constant Integer := (Y - CY) * Integer (Num);
                     RX : Integer;
                     RY : Integer;
                  begin
                     if Angle = 0 then
                        RX := DX / Integer (Den);
                        RY := DY / Integer (Den);
                     elsif Angle = 90 then
                        RX := DY / Integer (Den);
                        RY := -(DX / Integer (Den));
                     else
                        RX := -(DX / Integer (Den));
                        RY := -(DY / Integer (Den));
                     end if;
                     Paint
                       (Scene,
                        Natural (Shift_X + RX),
                        Natural (Shift_Y + RY),
                        Natural (Shift_X + RX),
                        Natural (Shift_Y + RY));
                  end;
               end if;
            end loop;
         end loop;
      end;
      return Scene;
   end Place;

   procedure Expect
     (Matches            : IP.Guil_Template_Match_Array;
      X, Y, Scale, Angle : OpenCV.Float32_Value;
      Tolerance          : OpenCV.Float32_Value := 2.0)
   is
      Found : Boolean := False;
      Votes : Natural := 0;
   begin
      Assert (Matches'First = 0, "nonempty zero-based array");
      for M of Matches loop
         if abs (M.Center.X - X) <= Tolerance
           and then abs (M.Center.Y - Y) <= Tolerance
           and then M.Scale = Scale
           and then M.Angle_Degrees = Angle
           and then M.Position_Votes > Votes
         then
            Assert
              (M.Scale_Votes > 0 and then M.Angle_Votes > 0,
               "positive native votes");
            Votes := M.Position_Votes;
            Found := True;
         end if;
      end loop;
      Assert (Found, "transformed center, scale and degree angle");
      for M of Matches loop
         if M.Scale = Scale and then M.Angle_Degrees = Angle then
            Assert
              (M.Position_Votes <= Votes
               or else abs (M.Center.X - X) > Tolerance
               or else abs (M.Center.Y - Y) > Tolerance,
               "known center is not weaker than another same-pose peak");
         end if;
      end loop;
   end Expect;

   procedure Translation (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
      S : constant C.Mat := Place (T, 0, 1, 1, 70, 60, 160, 180);
      A : constant IP.Guil_Template_Match_Array :=
        IP.Find_Guil_Template_Matches (T, S, Narrow);
      B : constant IP.Guil_Template_Match_Array :=
        IP.Find_Guil_Template_Matches (T, T, Narrow);
   begin
      Assert (A'Length >= 1 and then B'Length >= 1, "unscaled match exists");
      Expect (A, 70.0, 60.0, 1.0, 0.0);
      Expect (B, 20.0, 24.0, 1.0, 0.0);
   end Translation;
   procedure Empty_Results (F : in out Fixture) is
      pragma Unreferenced (F);
      T    : constant C.Mat := Shape;
      B    : constant C.Mat := Blank (48, 40);
      procedure Check (A : IP.Guil_Template_Match_Array) is
      begin
         Assert
           (A'Length = 0 and then A'First = 1 and then A'Last = 0,
            "empty null range 1 .. 0");
      end Check;
      High : IP.Guil_Search_Parameters := Narrow;
   begin
      Check (IP.Find_Guil_Template_Matches (B, T, Narrow));
      Check (IP.Find_Guil_Template_Matches (T, B, Narrow));
      Check
        (IP.Find_Guil_Template_Matches (Blank (1, 1), Blank (1, 1), Narrow));
      High.Position_Threshold := 100_000;
      Check (IP.Find_Guil_Template_Matches (T, T, High));
   end Empty_Results;

   procedure Rotations (F : in out Fixture) is
      pragma Unreferenced (F);
      T    : constant C.Mat := Shape;
      R90  : IP.Guil_Search_Parameters := Narrow;
      R180 : IP.Guil_Search_Parameters := Narrow;
   begin
      R90.Minimum_Angle := 89.0;
      R90.Maximum_Angle := 91.0;
      R180.Minimum_Angle := 179.0;
      R180.Maximum_Angle := 181.0;
      Expect
        (IP.Find_Guil_Template_Matches
           (T, Place (T, 90, 1, 1, 70, 60, 180, 200), R90),
         70.0,
         60.0,
         1.0,
         90.0,
         8.0);
      Expect
        (IP.Find_Guil_Template_Matches
           (T, Place (T, 180, 1, 1, 70, 60, 180, 200), R180),
         70.0,
         60.0,
         1.0,
         180.0);
   end Rotations;

   procedure Scales (F : in out Fixture) is
      pragma Unreferenced (F);
      T     : constant C.Mat := Shape;
      Small : IP.Guil_Search_Parameters := Narrow;
      Large : IP.Guil_Search_Parameters := Narrow;
   begin
      Small.Minimum_Scale := 0.74;
      Small.Maximum_Scale := 0.76;
      Small.Scale_Step := 0.01;
      Small.Angle_Threshold := 20;
      Small.Scale_Threshold := 10;
      Small.Position_Threshold := 20;
      Large.Minimum_Scale := 1.24;
      Large.Maximum_Scale := 1.26;
      Large.Scale_Step := 0.01;
      Large.Angle_Threshold := 20;
      Large.Scale_Threshold := 10;
      Large.Position_Threshold := 20;
      Expect
        (IP.Find_Guil_Template_Matches
           (T, Place (T, 0, 3, 4, 70, 60, 180, 200), Small),
         70.0,
         60.0,
         0.75,
         0.0);
      Expect
        (IP.Find_Guil_Template_Matches
           (T, Place (T, 0, 5, 4, 90, 80, 240, 260), Large),
         90.0,
         80.0,
         1.25,
         0.0);
   end Scales;

   procedure Combined (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
      P : IP.Guil_Search_Parameters := Narrow;
   begin
      P.Minimum_Angle := 89.0;
      P.Maximum_Angle := 91.0;
      P.Minimum_Scale := 1.24;
      P.Maximum_Scale := 1.26;
      P.Scale_Step := 0.01;
      P.Angle_Threshold := 15;
      P.Scale_Threshold := 8;
      P.Position_Threshold := 8;
      Expect
        (IP.Find_Guil_Template_Matches
           (T, Place (T, 90, 5, 4, 90, 80, 260, 280), P),
         90.0,
         80.0,
         1.25,
         90.0);
   end Combined;
   procedure Multiple (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
      A : constant C.Mat := Place (T, 0, 1, 1, 40, 35, 180, 220);
      B : constant C.Mat := Place (T, 0, 1, 1, 140, 110, 180, 220);
      S : C.Mat := Blank (180, 220);
   begin
      for Y in 0 .. S.Rows - 1 loop
         for X in 0 .. S.Columns - 1 loop
            if U.Get (A, Y, X) /= 0 or else U.Get (B, Y, X) /= 0 then
               U.Set (S, Y, X, 255);
            end if;
         end loop;
      end loop;
      declare
         M : constant IP.Guil_Template_Match_Array :=
           IP.Find_Guil_Template_Matches (T, S, Narrow);
      begin
         Assert (M'Length >= 2, "both copies detected");
         Expect (M, 40.0, 35.0, 1.0, 0.0);
         Expect (M, 140.0, 110.0, 1.0, 0.0);
      end;
   end Multiple;

   procedure Distractor (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
      S : C.Mat := Place (T, 0, 1, 1, 40, 35, 180, 220);
   begin
      Paint (S, 150, 120, 190, 155);
      Expect
        (IP.Find_Guil_Template_Matches (T, S, Narrow), 40.0, 35.0, 1.0, 0.0);
   end Distractor;

   procedure Thresholds_And_Ranges (F : in out Fixture) is
      pragma Unreferenced (F);
      T      : constant C.Mat := Shape;
      S      : constant C.Mat := Place (T, 0, 1, 1, 70, 60, 160, 180);
      Strict : IP.Guil_Search_Parameters := Narrow;
      Broad  : IP.Guil_Search_Parameters := Narrow;
   begin
      Strict.Position_Threshold := 100_000;
      Assert
        (IP.Find_Guil_Template_Matches (T, S, Strict)'Length = 0,
         "position threshold removes the match");
      Broad.Maximum_Angle := 20.0;
      Broad.Angle_Step := 5.0;
      Broad.Minimum_Scale := 0.8;
      Broad.Maximum_Scale := 1.3;
      Broad.Scale_Step := 0.1;
      declare
         N : constant IP.Guil_Template_Match_Array :=
           IP.Find_Guil_Template_Matches (T, S, Narrow);
         W : constant IP.Guil_Template_Match_Array :=
           IP.Find_Guil_Template_Matches (T, S, Broad);
      begin
         Assert
           (N'Length >= 1 and then W'Length > N'Length,
            "broader search admits neighboring hypotheses");
         Expect (W, 70.0, 60.0, 1.0, 0.0);
      end;
   end Thresholds_And_Ranges;
   procedure Regions (F : in out Fixture) is
      pragma Unreferenced (F);
      T  : constant C.Mat := Shape;
      S  : constant C.Mat := Place (T, 0, 1, 1, 70, 60, 160, 180);
      TP : C.Mat := Blank (70, 70);
      SP : C.Mat := Blank (200, 220);
   begin
      C.Set_To (TP, (Component_0 => 197.0, others => 0.0));
      C.Set_To (SP, (Component_0 => 213.0, others => 0.0));
      for Y in 0 .. T.Rows - 1 loop
         for X in 0 .. T.Columns - 1 loop
            U.Set (TP, Y + 5, X + 6, U.Get (T, Y, X));
         end loop;
      end loop;
      for Y in 0 .. S.Rows - 1 loop
         for X in 0 .. S.Columns - 1 loop
            U.Set (SP, Y + 8, X + 9, U.Get (S, Y, X));
         end loop;
      end loop;
      declare
         TR : constant C.Mat := TP.Region ((6, 5, 40, 48));
         SR : constant C.Mat := SP.Region ((9, 8, 180, 160));
         A  : constant IP.Guil_Template_Match_Array :=
           IP.Find_Guil_Template_Matches (T, S, Narrow);
      begin
         Assert
           (not TR.Is_Continuous and then not SR.Is_Continuous,
            "both inputs noncontinuous");
         Assert
           (IP.Find_Guil_Template_Matches (TR, S, Narrow) = A,
            "Template Region isolation");
         Assert
           (IP.Find_Guil_Template_Matches (T, SR, Narrow) = A,
            "Scene Region isolation");
         Assert
           (IP.Find_Guil_Template_Matches (TR, SR, Narrow) = A,
            "both Region isolation");
      end;
      Assert
        (U.Get (TP, 0, 0) = 197 and then U.Get (SP, 0, 0) = 213,
         "parents preserved");
   end Regions;

   procedure Preservation (F : in out Fixture) is
      pragma Unreferenced (F);
      T  : constant C.Mat := Shape;
      S  : constant C.Mat := Place (T, 0, 1, 1, 70, 60, 160, 180);
      TC : constant C.Mat := T.Clone;
      SC : constant C.Mat := S.Clone;
      A  : constant IP.Guil_Template_Match_Array :=
        IP.Find_Guil_Template_Matches (T, S, Narrow);
   begin
      for Call in 1 .. 3 loop
         Assert
           (IP.Find_Guil_Template_Matches (T, S, Narrow) = A,
            "independent repeated calls");
      end loop;
      for Y in 0 .. T.Rows - 1 loop
         for X in 0 .. T.Columns - 1 loop
            Assert (U.Get (T, Y, X) = U.Get (TC, Y, X), "Template unchanged");
         end loop;
      end loop;
      for Y in 0 .. S.Rows - 1 loop
         for X in 0 .. S.Columns - 1 loop
            Assert (U.Get (S, Y, X) = U.Get (SC, Y, X), "Scene unchanged");
         end loop;
      end loop;
   end Preservation;
   procedure Invalid (F : in out Fixture) is
      pragma Unreferenced (F);
      T        : constant C.Mat := Shape;
      E        : C.Mat;
      Wrong    : constant C.Mat := C.Create (3, 3, (C.Float32, 1));
      Channels : constant C.Mat := C.Create (3, 3, (C.UInt8, 3));
      ND       : constant C.Mat :=
        C.Create (C.Dimension_Array'(2, 2, 2), (C.UInt8, 1));
      procedure Reject (P : IP.Guil_Search_Parameters) is
         Raised : Boolean := False;
      begin
         begin
            declare
               M : constant IP.Guil_Template_Match_Array :=
                 IP.Find_Guil_Template_Matches (T, T, P);
            begin
               Assert
                 (M'Length = 0, "invalid parameters unexpectedly accepted");
            end;
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         Assert (Raised, "specific public OpenCV_Error");
      end Reject;
      procedure Reject_Mats (A, B : C.Mat) is
         Raised : Boolean := False;
      begin
         begin
            declare
               M : constant IP.Guil_Template_Match_Array :=
                 IP.Find_Guil_Template_Matches (A, B, Narrow);
            begin
               Assert (M'Length = 0, "invalid Mat unexpectedly accepted");
            end;
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         Assert (Raised, "specific public OpenCV_Error");
      end Reject_Mats;
      Bad      : IP.Guil_Search_Parameters := Narrow;
   begin
      Bad.Canny_Low := 100;
      Bad.Canny_High := 50;
      Reject (Bad);
      Bad := Narrow;
      Bad.Minimum_Angle := -1.0;
      Reject (Bad);
      Bad := Narrow;
      Bad.Maximum_Angle := 361.0;
      Reject (Bad);
      Bad := Narrow;
      Bad.Angle_Step := 0.0;
      Reject (Bad);
      Bad := Narrow;
      Bad.Minimum_Scale := 0.0;
      Reject (Bad);
      Bad := Narrow;
      Bad.Scale_Step := -0.1;
      Reject (Bad);
      Bad := Narrow;
      Bad.Angle_Step := OpenCV.Float64_Value'Invalid_Value;
      Reject (Bad);
      Reject_Mats (E, T);
      Reject_Mats (T, E);
      Reject_Mats (Wrong, T);
      Reject_Mats (T, Channels);
      Reject_Mats (ND, T);
      Expect
        (IP.Find_Guil_Template_Matches (T, T, Narrow), 20.0, 24.0, 1.0, 0.0);
   end Invalid;
   function Raw
     (T, S      : System.Address;
      P         : API.Guil_Parameters;
      Positions : System.Address;
      Votes     : System.Address) return API.Status
   with Import, Convention => C, External_Name => "opencv_imgproc_guil_detect";

   function Input_Address is new
     Ada.Unchecked_Conversion
       (C.Module_Interop.Input_Mat_Handle,
        System.Address);
   function Output_Address is new
     Ada.Unchecked_Conversion
       (C.Module_Interop.Output_Mat_Handle,
        System.Address);

   procedure Raw_Failure (F : in out Fixture) is
      pragma Unreferenced (F);
      T      : constant C.Mat := Shape;
      P      : C.Mat := Blank (2, 2);
      V      : C.Mat := Blank (2, 2);
      Status : API.Status := API.Success;
      Good   : constant API.Guil_Parameters :=
        (0.0, 2.0, 1.0, 0.98, 1.02, 0.02, 50, 100, 50, 50, 100);
      Bad    : constant API.Guil_Parameters :=
        (10.0, 2.0, 1.0, 0.98, 1.02, 0.02, 50, 100, 50, 50, 100);
      procedure Input (TH : C.Module_Interop.Input_Mat_Handle) is
         procedure Positions (PH : C.Module_Interop.Output_Mat_Handle) is
            procedure Votes (VH : C.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Raw
                   (System.Null_Address,
                    Input_Address (TH),
                    Good,
                    Output_Address (PH),
                    Output_Address (VH));
               Assert (Status = API.Error_Invalid_Argument, "null input");
               Status := API.Guil_Detect (TH, TH, Good, PH, PH);
               Assert (Status = API.Error_Invalid_Argument, "same outputs");
               Status := API.Guil_Detect (TH, TH, Bad, PH, VH);
               Assert (Status = API.Error_Invalid_Argument, "invalid range");
               Assert
                 (U.Get (P, 0, 0) = 77 and then U.Get (V, 0, 0) = 88,
                  "raw failure atomicity");
               Status := API.Guil_Detect (TH, TH, Good, PH, VH);
               Assert (Status = API.Success, "raw recovery");
            end Votes;
         begin
            C.Module_Interop.With_Output_Handle (V, Votes'Access);
         end Positions;
      begin
         C.Module_Interop.With_Output_Handle (P, Positions'Access);
      end Input;
   begin
      C.Set_To (P, (Component_0 => 77.0, others => 0.0));
      C.Set_To (V, (Component_0 => 88.0, others => 0.0));
      C.Module_Interop.With_Input_Handle (T, Input'Access);
   end Raw_Failure;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Guil translation", Translation'Access));
      Result.Add_Test (Caller.Create ("Guil empty", Empty_Results'Access));
      Result.Add_Test (Caller.Create ("Guil rotation", Rotations'Access));
      Result.Add_Test (Caller.Create ("Guil scale", Scales'Access));
      Result.Add_Test (Caller.Create ("Guil combined", Combined'Access));
      Result.Add_Test (Caller.Create ("Guil multiple", Multiple'Access));
      Result.Add_Test (Caller.Create ("Guil distractor", Distractor'Access));
      Result.Add_Test
        (Caller.Create ("Guil thresholds", Thresholds_And_Ranges'Access));
      Result.Add_Test (Caller.Create ("Guil Regions", Regions'Access));
      Result.Add_Test
        (Caller.Create ("Guil preservation", Preservation'Access));
      Result.Add_Test (Caller.Create ("Guil invalid", Invalid'Access));
      Result.Add_Test (Caller.Create ("Guil raw failure", Raw_Failure'Access));
      return Result'Access;
   end Suite;
   --  GUIL_TESTS_CONTINUE
end Guil_Template_Tests;
