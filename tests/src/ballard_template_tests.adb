with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Ballard_Template_Tests is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   package U renames C.UInt8_Access;
   package API renames IP.Internal.C_API;
   use AUnit.Assertions;
   use type OpenCV.Float32_Value;
   use type OpenCV.UInt8_Value;
   use type IP.Ballard_Template_Match_Array;
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

   function Shape return C.Mat is
      M : C.Mat := Blank (31, 29);
   begin
      for Y in 6 .. 23 loop
         for X in 5 .. 21 loop
            if not (Y <= 14 and then X >= 13) then
               U.Set (M, Y, X, 255);
            end if;
         end loop;
      end loop;
      U.Set (M, 22, 6, 0);
      return M;
   end Shape;

   procedure Paste (Template : C.Mat; Scene : in out C.Mat; X, Y : Natural) is
   begin
      for R in 0 .. Template.Rows - 1 loop
         for Col in 0 .. Template.Columns - 1 loop
            U.Set (Scene, R + Y, Col + X, U.Get (Template, R, Col));
         end loop;
      end loop;
   end Paste;

   procedure Check_Known
     (Matches : IP.Ballard_Template_Match_Array; X, Y : OpenCV.Float32_Value)
   is
      Found : Boolean := False;
   begin
      Assert (Matches'First = 0, "nonempty zero-based array");
      for M of Matches loop
         if M.Center.X = X and then M.Center.Y = Y then
            Assert (M.Votes = 68, "exact Int32 vote decoding");
            Found := True;
         end if;
      end loop;
      Assert (Found, "known translated template center");
   end Check_Known;

   procedure Translation (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
      S : C.Mat := Blank (99, 111);
   begin
      Paste (T, S, 37, 28);
      declare
         A : constant IP.Ballard_Template_Match_Array :=
           IP.Find_Ballard_Template_Matches (T, S);
         B : constant IP.Ballard_Template_Match_Array :=
           IP.Find_Ballard_Template_Matches (T, T);
      begin
         Assert (A'Length = 1 and then B'Length = 1, "single strong match");
         Check_Known (A, 51.0, 43.0);
         Check_Known (B, 14.0, 15.0);
      end;
   end Translation;

   procedure Empty_Results (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
      B : constant C.Mat := Blank (31, 29);
      procedure Check (A : IP.Ballard_Template_Match_Array) is
      begin
         Assert
           (A'Length = 0 and then A'First = 1 and then A'Last = 0,
            "empty null range 1 .. 0");
      end Check;
   begin
      Check (IP.Find_Ballard_Template_Matches (B, T));
      Check (IP.Find_Ballard_Template_Matches (T, B));
      Check (IP.Find_Ballard_Template_Matches (T, T, 10000));
      Check (IP.Find_Ballard_Template_Matches (Blank (1, 1), Blank (1, 1)));
   end Empty_Results;

   procedure Multiple (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
      S : C.Mat := Blank (140, 180);
   begin
      Paste (T, S, 12, 17);
      Paste (T, S, 111, 85);
      declare
         A : constant IP.Ballard_Template_Match_Array :=
           IP.Find_Ballard_Template_Matches (T, S);
      begin
         Assert (A'Length = 2, "two separated copies");
         Check_Known (A, 26.0, 32.0);
         Check_Known (A, 125.0, 100.0);
      end;
   end Multiple;

   procedure Thresholds (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
   begin
      Check_Known (IP.Find_Ballard_Template_Matches (T, T, 67), 14.0, 15.0);
      Assert
        (IP.Find_Ballard_Template_Matches (T, T, 68)'Length = 0,
         "votes strictly greater than threshold");
      Check_Known
        (IP.Find_Ballard_Template_Matches (T, T, 20, 10, 30), 14.0, 15.0);
      Check_Known
        (IP.Find_Ballard_Template_Matches (T, T, 20, 100, 200), 14.0, 15.0);
   end Thresholds;

   procedure Regions (F : in out Fixture) is
      pragma Unreferenced (F);
      T  : constant C.Mat := Shape;
      S  : C.Mat := Blank (99, 111);
      TP : C.Mat := Blank (40, 40);
      SP : C.Mat := Blank (120, 130);
   begin
      C.Set_To (TP, (Component_0 => 197.0, others => 0.0));
      C.Set_To (SP, (Component_0 => 213.0, others => 0.0));
      Paste (T, S, 37, 28);
      Paste (T, TP, 3, 4);
      Paste (S, SP, 4, 5);
      declare
         TR : constant C.Mat := TP.Region ((3, 4, 29, 31));
         SR : constant C.Mat := SP.Region ((4, 5, 111, 99));
         A  : constant IP.Ballard_Template_Match_Array :=
           IP.Find_Ballard_Template_Matches (T, S);
      begin
         Assert
           (not TR.Is_Continuous and then not SR.Is_Continuous,
            "both inputs noncontinuous");
         Assert
           (IP.Find_Ballard_Template_Matches (TR, S) = A,
            "Template Region isolation");
         Assert
           (IP.Find_Ballard_Template_Matches (T, SR) = A,
            "Scene Region isolation");
         Assert
           (IP.Find_Ballard_Template_Matches (TR, SR) = A,
            "both Region isolation");
         Check_Known (A, 51.0, 43.0);
      end;
      Assert
        (U.Get (TP, 0, 0) = 197 and then U.Get (SP, 0, 0) = 213,
         "parents preserved");
   end Regions;

   procedure Preservation (F : in out Fixture) is
      pragma Unreferenced (F);
      T : constant C.Mat := Shape;
      S : C.Mat := Blank (99, 111);
   begin
      Paste (T, S, 37, 28);
      declare
         TC : constant C.Mat := T.Clone;
         SC : constant C.Mat := S.Clone;
         A  : constant IP.Ballard_Template_Match_Array :=
           IP.Find_Ballard_Template_Matches (T, S);
      begin
         for Call in 1 .. 3 loop
            Assert
              (IP.Find_Ballard_Template_Matches (T, S) = A,
               "independent repeated calls");
         end loop;
         for Y in 0 .. T.Rows - 1 loop
            for X in 0 .. T.Columns - 1 loop
               Assert
                 (U.Get (T, Y, X) = U.Get (TC, Y, X), "Template unchanged");
            end loop;
         end loop;
         for Y in 0 .. S.Rows - 1 loop
            for X in 0 .. S.Columns - 1 loop
               Assert (U.Get (S, Y, X) = U.Get (SC, Y, X), "Scene unchanged");
            end loop;
         end loop;
         C.Set_To (S, (others => 0.0));
         Check_Known (A, 51.0, 43.0);
      end;
   end Preservation;

   procedure Invalid (F : in out Fixture) is
      pragma Unreferenced (F);
      T        : constant C.Mat := Shape;
      E        : C.Mat;
      Wrong    : constant C.Mat := C.Create (3, 3, (C.Float32, 1));
      Channels : constant C.Mat := C.Create (3, 3, (C.UInt8, 3));
      ND       : constant C.Mat :=
        C.Create (C.Dimension_Array'(2, 2, 2), (C.UInt8, 1));
      procedure Reject (A, B : C.Mat; Low, High : Positive := 100) is
         Raised : Boolean := False;
      begin
         begin
            declare
               M : constant IP.Ballard_Template_Match_Array :=
                 IP.Find_Ballard_Template_Matches (A, B, 20, Low, High);
            begin
               Assert (M'Length = 0, "invalid input unexpectedly accepted");
            end;
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         Assert (Raised, "specific public OpenCV_Error");
      end Reject;
   begin
      Reject (T, T);
      Reject (T, T, 100, 50);
      Reject (E, T, 50, 100);
      Reject (T, E, 50, 100);
      Reject (Wrong, T, 50, 100);
      Reject (T, Wrong, 50, 100);
      Reject (Channels, T, 50, 100);
      Reject (T, Channels, 50, 100);
      Reject (ND, T, 50, 100);
      Reject (T, ND, 50, 100);
      Check_Known (IP.Find_Ballard_Template_Matches (T, T), 14.0, 15.0);
   end Invalid;

   function Raw
     (T, S                 : System.Address;
      Low, High, Threshold : Interfaces.Integer_32;
      P, V                 : System.Address) return API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_ballard_detect";

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
      procedure Input (TH : C.Module_Interop.Input_Mat_Handle) is
         procedure Positions (PH : C.Module_Interop.Output_Mat_Handle) is
            procedure Votes (VH : C.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Raw
                   (System.Null_Address,
                    Input_Address (TH),
                    50,
                    100,
                    20,
                    Output_Address (PH),
                    Output_Address (VH));
               Assert (Status = API.Error_Invalid_Argument, "null input");
               Status := API.Ballard_Detect (TH, TH, 50, 100, 20, PH, PH);
               Assert (Status = API.Error_Invalid_Argument, "same outputs");
               Status := API.Ballard_Detect (TH, TH, 100, 50, 20, PH, VH);
               Assert (Status = API.Error_OpenCV, "native error translation");
               Assert
                 (U.Get (P, 0, 0) = 77 and then U.Get (V, 0, 0) = 88,
                  "raw failure atomicity");
               Status := API.Ballard_Detect (TH, TH, 50, 100, 20, PH, VH);
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
      Result.Add_Test
        (Caller.Create ("Ballard translation", Translation'Access));
      Result.Add_Test (Caller.Create ("Ballard empty", Empty_Results'Access));
      Result.Add_Test (Caller.Create ("Ballard multiple", Multiple'Access));
      Result.Add_Test
        (Caller.Create ("Ballard thresholds", Thresholds'Access));
      Result.Add_Test (Caller.Create ("Ballard Regions", Regions'Access));
      Result.Add_Test
        (Caller.Create ("Ballard preservation", Preservation'Access));
      Result.Add_Test (Caller.Create ("Ballard invalid", Invalid'Access));
      Result.Add_Test
        (Caller.Create ("Ballard raw failure", Raw_Failure'Access));
      return Result'Access;
   end Suite;
end Ballard_Template_Tests;
