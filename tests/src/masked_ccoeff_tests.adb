with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Masked_CCOEFF_Tests is
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Point_Coordinate;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  Gate A bound, declared before measurement: an absolute floor of
   --  1.0E-4 plus 2**(-20) (about 8 Float32 ULPs) of the dominant term
   --  Sum(M*T*I). The coefficient cancels two large terms, so the error
   --  scales with that magnitude rather than with the result.
   Floor : constant Long_Float := 1.0E-4;
   Slope : constant Long_Float := 2.0**(-20);

   procedure Oracle (Test : in out Fixture);
   procedure Offset_Invariance (Test : in out Fixture);
   procedure Degenerate (Test : in out Fixture);
   procedure Regions (Test : in out Fixture);
   procedure Rejections (Test : in out Fixture);
   procedure Raw_Selector (Test : in out Fixture);

   function Pattern (Y, X : Integer) return Interfaces.Unsigned_8
   is (Interfaces.Unsigned_8 ((Y * 37 + X * 91 + Y * X * 13) mod 251));

   procedure Fill_Pattern (Image : in out OpenCV.Core.Mat) is
   begin
      for Y in 0 .. Image.Rows - 1 loop
         for X in 0 .. Image.Columns - 1 loop
            OpenCV.Core.UInt8_Access.Set (Image, Y, X, Pattern (Y, X));
         end loop;
      end loop;
   end Fill_Pattern;

   procedure Fill_Constant
     (Image : in out OpenCV.Core.Mat; Value : Interfaces.Unsigned_8) is
   begin
      for Y in 0 .. Image.Rows - 1 loop
         for X in 0 .. Image.Columns - 1 loop
            OpenCV.Core.UInt8_Access.Set (Image, Y, X, Value);
         end loop;
      end loop;
   end Fill_Constant;

   --  Checked integer oracle. Count, ST, SI and STI are exact integers
   --  (fixtures are small); only the final division is floating-point.
   procedure Reference
     (Source, Template, Mask : OpenCV.Core.Mat;
      Y, X                   : Integer;
      Score, Scale           : out Long_Float)
   is
      Count, ST, SI, STI : Long_Long_Integer := 0;
   begin
      for V in 0 .. Template.Rows - 1 loop
         for U in 0 .. Template.Columns - 1 loop
            if OpenCV.Core.UInt8_Access.Get (Mask, V, U) /= 0 then
               declare
                  T : constant Long_Long_Integer :=
                    Long_Long_Integer
                      (OpenCV.Core.UInt8_Access.Get (Template, V, U));
                  I : constant Long_Long_Integer :=
                    Long_Long_Integer
                      (OpenCV.Core.UInt8_Access.Get (Source, Y + V, X + U));
               begin
                  Count := Count + 1;
                  ST := ST + T;
                  SI := SI + I;
                  STI := STI + T * I;
               end;
            end if;
         end loop;
      end loop;
      Scale := Long_Float (STI);
      Score :=
        Long_Float (STI)
        - Long_Float (ST) * Long_Float (SI) / Long_Float (Count);
   end Reference;

   --  Oracle argmax over every window (first maximum in row-major order).
   procedure Oracle_Argmax
     (Source, Template, Mask : OpenCV.Core.Mat;
      Rows, Columns          : Integer;
      Best_X, Best_Y         : out Integer)
   is
      Score, Scale : Long_Float;
      Best         : Long_Float := Long_Float'First;
   begin
      Best_X := 0;
      Best_Y := 0;
      for Y in 0 .. Rows - 1 loop
         for X in 0 .. Columns - 1 loop
            Reference (Source, Template, Mask, Y, X, Score, Scale);
            if Score > Best then
               Best := Score;
               Best_X := X;
               Best_Y := Y;
            end if;
         end loop;
      end loop;
   end Oracle_Argmax;

   procedure Match
     (Source, Template, Mask : OpenCV.Core.Mat;
      Destination            : in out OpenCV.Core.Mat) is
   begin
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Mask,
         Destination,
         OpenCV.Image_Processing.Correlation_Coefficient);
   end Match;

   function Within_Oracle
     (Source, Template, Mask, Scores : OpenCV.Core.Mat;
      Negative, Positive             : out Boolean) return Boolean
   is
      Expected, Scale, Actual : Long_Float;
      Passed                  : Boolean := True;
   begin
      Negative := False;
      Positive := False;
      for Y in 0 .. Scores.Rows - 1 loop
         for X in 0 .. Scores.Columns - 1 loop
            Reference (Source, Template, Mask, Y, X, Expected, Scale);
            Actual :=
              Long_Float (OpenCV.Core.Float32_Access.Get (Scores, Y, X));
            if abs (Actual - Expected) > Floor + Slope * abs (Scale) then
               Passed := False;
            end if;
            Negative := Negative or else Expected < -1.0;
            Positive := Positive or else Expected > 1.0;
         end loop;
      end loop;
      return Passed;
   end Within_Oracle;

   procedure Oracle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 9, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Extrema     : OpenCV.Core.Min_Max_Result;
      Negative    : Boolean;
      Positive    : Boolean;
      Best_X      : Integer;
      Best_Y      : Integer;
   begin
      Fill_Pattern (Source);
      Fill_Constant (Mask, 0);
      for V in 0 .. 2 loop
         for U in 0 .. 3 loop
            OpenCV.Core.UInt8_Access.Set
              (Template,
               V,
               U,
               OpenCV.Core.UInt8_Access.Get (Source, 4 + V, 3 + U));
         end loop;
      end loop;
      --  Nonbinary nonzero bytes all have weight one.
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 1);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 3, 7);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 127);
      OpenCV.Core.UInt8_Access.Set (Mask, 2, 0, 255);
      OpenCV.Core.UInt8_Access.Set (Mask, 2, 3, 2);
      --  An excluded Template pixel must not matter.
      OpenCV.Core.UInt8_Access.Set (Template, 1, 2, 250);
      Match (Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (Destination.Rows = 6
         and then Destination.Columns = 6
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "CCOEFF result layout");
      AUnit.Assertions.Assert
        (Within_Oracle
           (Source, Template, Mask, Destination, Negative, Positive),
         "Float32 scores match the integer oracle within the bound");
      AUnit.Assertions.Assert
        (Negative and then Positive,
         "fixture covers positive and negative coefficients");
      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      Oracle_Argmax (Source, Template, Mask, 6, 6, Best_X, Best_Y);
      AUnit.Assertions.Assert
        (Extrema.Maximum_Location.X = OpenCV.Point_Coordinate (Best_X)
         and then Extrema.Maximum_Location.Y
                  = OpenCV.Point_Coordinate (Best_Y),
         "maximum location agrees with the oracle argmax");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Template, 1, 2) = 250,
         "excluded Template sample unchanged");
   end Oracle;

   procedure Offset_Invariance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 9, (OpenCV.Core.UInt8, 1));
      Template : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Mask     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Offset   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 9, (OpenCV.Core.UInt8, 1));
      Base     : OpenCV.Core.Mat;
      Lifted   : OpenCV.Core.Mat;
      Base_Max : OpenCV.Core.Min_Max_Result;
      Lift_Max : OpenCV.Core.Min_Max_Result;
      Neg, Pos : Boolean;
      Best_X   : Integer;
      Best_Y   : Integer;
   begin
      Fill_Pattern (Source);
      Fill_Constant (Mask, 1);
      for V in 0 .. 2 loop
         for U in 0 .. 3 loop
            OpenCV.Core.UInt8_Access.Set
              (Template,
               V,
               U,
               OpenCV.Core.UInt8_Access.Get (Source, 2 + V, 5 + U));
         end loop;
      end loop;
      --  Pattern values are at most 250 and the offset is 4: no clipping.
      for Y in 0 .. 7 loop
         for X in 0 .. 8 loop
            OpenCV.Core.UInt8_Access.Set
              (Offset, Y, X, OpenCV.Core.UInt8_Access.Get (Source, Y, X) + 4);
         end loop;
      end loop;
      Match (Source, Template, Mask, Base);
      Match (Offset, Template, Mask, Lifted);
      Base_Max := OpenCV.Core.Min_Max_Loc (Base);
      Lift_Max := OpenCV.Core.Min_Max_Loc (Lifted);
      Oracle_Argmax (Source, Template, Mask, 6, 6, Best_X, Best_Y);
      AUnit.Assertions.Assert
        (Base_Max.Maximum_Location.X = OpenCV.Point_Coordinate (Best_X)
         and then Base_Max.Maximum_Location.Y
                  = OpenCV.Point_Coordinate (Best_Y),
         "maximum location agrees with the oracle argmax");
      AUnit.Assertions.Assert
        (Lift_Max.Maximum_Location.X = Base_Max.Maximum_Location.X
         and then Lift_Max.Maximum_Location.Y = Base_Max.Maximum_Location.Y,
         "additive offset keeps the maximum location");
      AUnit.Assertions.Assert
        (Within_Oracle (Offset, Template, Mask, Lifted, Neg, Pos),
         "offset Scene stays within the oracle bound");
      for Y in 0 .. Base.Rows - 1 loop
         for X in 0 .. Base.Columns - 1 loop
            AUnit.Assertions.Assert
              (abs (Long_Float (OpenCV.Core.Float32_Access.Get (Base, Y, X))
                    - Long_Float
                        (OpenCV.Core.Float32_Access.Get (Lifted, Y, X)))
               <= 0.05 + 2.0**(-18) * abs (Base_Max.Maximum),
               "additive offset leaves scores within tolerance");
         end loop;
      end loop;
   end Offset_Invariance;

   function All_Near_Zero
     (Scores : OpenCV.Core.Mat; Bound : Long_Float) return Boolean is
   begin
      for Y in 0 .. Scores.Rows - 1 loop
         for X in 0 .. Scores.Columns - 1 loop
            if abs (Long_Float (OpenCV.Core.Float32_Access.Get (Scores, Y, X)))
              > Bound
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end All_Near_Zero;

   procedure Degenerate (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 6, (OpenCV.Core.UInt8, 1));
      Flat_Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 6, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Flat_Templ  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Single      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Empty_Mask  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Raised      : Boolean := False;
   begin
      Fill_Pattern (Source);
      Fill_Pattern (Template);
      Fill_Constant (Flat_Source, 90);
      Fill_Constant (Flat_Templ, 100);
      Fill_Constant (Mask, 1);
      Fill_Constant (Single, 0);
      Fill_Constant (Empty_Mask, 0);
      OpenCV.Core.UInt8_Access.Set (Single, 1, 1, 255);
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      begin
         Match (Source, Template, Empty_Mask, Destination);
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert
        (Raised and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "all-zero mask rejected and Destination preserved");
      Match (Source, Template, Single, Destination);
      AUnit.Assertions.Assert
        (All_Near_Zero (Destination, 1.0E-3),
         "single included pixel has ideal score zero");
      Match (Source, Flat_Templ, Mask, Destination);
      AUnit.Assertions.Assert
        (All_Near_Zero (Destination, 0.5),
         "constant included Template has ideal score zero");
      Match (Flat_Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (All_Near_Zero (Destination, 0.5),
         "constant Scene windows have ideal score zero");
      Match (Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32,
         "recovery after all-zero mask rejection");
   end Degenerate;

   procedure Regions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 10, (OpenCV.Core.UInt8, 1));
      Parent_Mask : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 7, (OpenCV.Core.UInt8, 1));
      Source      : OpenCV.Core.Mat;
      Template    : OpenCV.Core.Mat;
      Mask        : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat;
      Negative    : Boolean;
      Positive    : Boolean;
      Before      : Interfaces.Unsigned_8;
   begin
      Fill_Pattern (Parent);
      for Y in 0 .. 5 loop
         for X in 0 .. 6 loop
            OpenCV.Core.UInt8_Access.Set
              (Parent_Mask, Y, X, Interfaces.Unsigned_8 ((Y + X) mod 3));
         end loop;
      end loop;
      Source := Parent.Region ((X => 1, Y => 1, Width => 8, Height => 7));
      Template := Source.Region ((X => 2, Y => 1, Width => 4, Height => 3));
      Mask := Parent_Mask.Region ((X => 1, Y => 2, Width => 4, Height => 3));
      Before := OpenCV.Core.UInt8_Access.Get (Parent, 3, 4);
      Match (Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.Float32,
         "Region result geometry");
      AUnit.Assertions.Assert
        (Within_Oracle
           (Source, Template, Mask, Destination, Negative, Positive),
         "noncontinuous Regions agree with the oracle");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Parent, 3, 4) = Before,
         "Region parent pixels unchanged");
      OpenCV.Core.Float32_Access.Set (Destination, 0, 0, 1.0);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Parent, 0, 0) = Pattern (0, 0),
         "Destination is independent storage");
   end Regions;

   procedure Rejections (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Good        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Bad         : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Check
        (Source, Template, Mask : OpenCV.Core.Mat;
         Method                 :
           OpenCV.Image_Processing.Template_Matching_Method :=
             OpenCV.Image_Processing.Correlation_Coefficient)
      is
         Raised : Boolean := False;
      begin
         begin
            OpenCV.Image_Processing.Match_Template
              (Source, Template, Mask, Destination, Method);
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         AUnit.Assertions.Assert (Raised, "specific OpenCV_Error required");
         AUnit.Assertions.Assert
           (Destination.Depth = OpenCV.Core.UInt8
            and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
            "existing destination preserved");
      end Check;
   begin
      Fill_Pattern (Good);
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      Bad := OpenCV.Core.Create (0, 0, (OpenCV.Core.UInt8, 1));
      Check (Bad, Good, Good);
      Bad := OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Check (Good, Bad, Good);
      Bad := OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Check (Good, Good, Bad);
      Bad := OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Check (Good, Good, Bad);
      Bad := OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Check (Good, Bad, Good);
      Check
        (Good,
         Good,
         Good,
         OpenCV.Image_Processing.Normalized_Correlation_Coefficient);
      Fill_Constant (Good, 1);
      Match (Good, Good, Good, Destination);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32, "recovery after rejection");
   end Rejections;

   procedure Raw_Selector (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package API renames OpenCV.Image_Processing.Internal.C_API;
      use type API.Status;
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Weights     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Status      : API.Status := API.Success;

      procedure Run (Selector : Interfaces.Integer_32) is
         procedure Input (S : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            procedure Mask_Input
              (M : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (D : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status := API.Match_Template_Masked (S, S, M, D, Selector);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Mask_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Weights, Mask_Input'Access);
         end Input;
      begin
         Fill_Constant (Destination, 73);
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      end Run;
   begin
      Fill_Pattern (Source);
      Fill_Constant (Weights, 0);
      Run (API.Template_Normalized_Correlation_Coefficient);
      AUnit.Assertions.Assert
        (Status /= API.Success
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "raw CCOEFF_NORMED selector preserves Destination");
      Run (-1);
      AUnit.Assertions.Assert
        (Status /= API.Success
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "raw negative selector preserves Destination");
      Run (API.Template_Correlation_Coefficient);
      AUnit.Assertions.Assert
        (Status /= API.Success
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "raw all-zero mask rejected before native execution");
      Fill_Constant (Weights, 1);
      Run (API.Template_Correlation_Coefficient);
      AUnit.Assertions.Assert
        (Status = API.Success and then Destination.Depth = OpenCV.Core.Float32,
         "raw selector accepted after rejection");
   end Raw_Selector;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Masked CCOEFF oracle", Oracle'Access));
      Result.Add_Test
        (Caller.Create
           ("Masked CCOEFF offset invariance", Offset_Invariance'Access));
      Result.Add_Test
        (Caller.Create ("Masked CCOEFF degenerate", Degenerate'Access));
      Result.Add_Test
        (Caller.Create ("Masked CCOEFF regions", Regions'Access));
      Result.Add_Test
        (Caller.Create ("Masked CCOEFF rejections", Rejections'Access));
      Result.Add_Test
        (Caller.Create ("Masked CCOEFF raw selector", Raw_Selector'Access));
      return Result'Access;
   end Suite;

end Masked_CCOEFF_Tests;
