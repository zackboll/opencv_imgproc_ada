with AUnit.Assertions;
with Ada.Numerics.Long_Elementary_Functions;
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

package body Masked_NSQDIFF_Tests is
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Image_Processing.Template_Matching_Method;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Sentinel : constant OpenCV.Float32_Value := OpenCV.Float32_Value'Last;

   function Reference
     (Source   : OpenCV.Core.Mat;
      Template : OpenCV.Core.Mat;
      Mask     : OpenCV.Core.Mat;
      Y, X     : Integer) return Long_Float;

   procedure Oracle (Test : in out Fixture);
   procedure Above_One (Test : in out Fixture);
   procedure Zero_Window (Test : in out Fixture);
   procedure Degenerate (Test : in out Fixture);
   procedure Regions (Test : in out Fixture);
   procedure Rejections (Test : in out Fixture);
   procedure Raw_Selector (Test : in out Fixture);

   function Reference
     (Source   : OpenCV.Core.Mat;
      Template : OpenCV.Core.Mat;
      Mask     : OpenCV.Core.Mat;
      Y, X     : Integer) return Long_Float
   is
      Numer, Template_Energy, Scene_Energy : Long_Float := 0.0;
   begin
      for V in 0 .. Template.Rows - 1 loop
         for U in 0 .. Template.Columns - 1 loop
            if OpenCV.Core.UInt8_Access.Get (Mask, V, U) /= 0 then
               declare
                  T : constant Long_Float :=
                    Long_Float (OpenCV.Core.UInt8_Access.Get (Template, V, U));
                  I : constant Long_Float :=
                    Long_Float
                      (OpenCV.Core.UInt8_Access.Get (Source, Y + V, X + U));
                  D : constant Long_Float := T - I;
               begin
                  Numer := Numer + D * D;
                  Template_Energy := Template_Energy + T * T;
                  Scene_Energy := Scene_Energy + I * I;
               end;
            end if;
         end loop;
      end loop;
      if Scene_Energy = 0.0 then
         return Long_Float (Sentinel);
      end if;
      return
        Numer
        / Ada.Numerics.Long_Elementary_Functions.Sqrt
            (Template_Energy * Scene_Energy);
   end Reference;

   procedure Match
     (Source, Template, Mask : OpenCV.Core.Mat;
      Destination            : in out OpenCV.Core.Mat) is
   begin
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Mask,
         Destination,
         OpenCV.Image_Processing.Normalized_Squared_Difference);
   end Match;

   procedure Oracle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Extrema     : OpenCV.Core.Min_Max_Result;
   begin
      for Y in 0 .. 3 loop
         for X in 0 .. 4 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Y, X, Interfaces.Unsigned_8 (20 + Y * 3 + X));
         end loop;
      end loop;
      OpenCV.Core.UInt8_Access.Set (Template, 0, 0, 20);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 1, 200);
      OpenCV.Core.UInt8_Access.Set (Template, 1, 0, 23);
      OpenCV.Core.UInt8_Access.Set (Template, 1, 1, 24);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 9);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 0);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 0, 255);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 1);
      Match (Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 4
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "NSQDIFF result layout");
      for Y in 0 .. 2 loop
         for X in 0 .. 3 loop
            AUnit.Assertions.Assert
              (abs (OpenCV.Core.Float32_Access.Get (Destination, Y, X)
                    - OpenCV.Float32_Value
                        (Reference (Source, Template, Mask, Y, X)))
               <= 0.0001,
               "widened NSQDIFF oracle");
         end loop;
      end loop;
      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Minimum_Location.X = 0
         and then Extrema.Minimum_Location.Y = 0,
         "minimum is the perfect included match");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Template, 0, 1) = 200,
         "excluded template sample unchanged");
   end Oracle;

   procedure Above_One (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 1);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 255);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 0, 255);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 1);
      Match (Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) > 1.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 1) <= 0.0001,
         "normalized SQDIFF is not clamped to one");
   end Above_One;

   procedure Zero_Window (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Neighbor    : OpenCV.Float32_Value;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 8);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 0, 4);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 1, 6);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 1);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 1);
      Match (Source, Template, Mask, Destination);
      Neighbor :=
        OpenCV.Float32_Value (Reference (Source, Template, Mask, 0, 1));
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = Sentinel
         and then abs (OpenCV.Core.Float32_Access.Get (Destination, 0, 1)
                       - Neighbor)
                  <= 0.0001
         and then Neighbor > 0.0
         and then Neighbor < Sentinel,
         "zero Scene window is Float32'Last and neighbor stays native");
   end Zero_Window;

   procedure Degenerate (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Black       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Raised      : Boolean := False;
   begin
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      for Y in 0 .. 1 loop
         for X in 0 .. 1 loop
            OpenCV.Core.UInt8_Access.Set (Source, Y, X, 5);
            OpenCV.Core.UInt8_Access.Set (Black, Y, X, 0);
            OpenCV.Core.UInt8_Access.Set (Mask, Y, X, 0);
         end loop;
      end loop;
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 1);
      begin
         Match (Source, Black, Mask, Destination);
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert
        (Raised and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "black included template rejected");
      Raised := False;
      begin
         Match (Source, Source, Black, Destination);
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert
        (Raised and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "all-zero mask rejected");
      Match (Source, Source, Mask, Destination);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32,
         "recovery after normalized-SQDIFF rejection");
   end Degenerate;

   procedure Regions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 6, (OpenCV.Core.UInt8, 1));
      Source, Template : OpenCV.Core.Mat;
      Mask             : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination      : OpenCV.Core.Mat;
      Before           : Interfaces.Unsigned_8;
   begin
      for Y in 0 .. 4 loop
         for X in 0 .. 5 loop
            OpenCV.Core.UInt8_Access.Set
              (Parent, Y, X, Interfaces.Unsigned_8 (30 + Y * 6 + X));
         end loop;
      end loop;
      Source := Parent.Region ((X => 1, Y => 1, Width => 4, Height => 3));
      Template := Source.Region ((X => 1, Y => 0, Width => 2, Height => 2));
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 1);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 4);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 0, 0);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 9);
      Before := OpenCV.Core.UInt8_Access.Get (Parent, 0, 0);
      Match (Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Parent, 0, 0) = Before
         and then Destination.Rows = 2
         and then Destination.Columns = 3
         and then abs (OpenCV.Core.Float32_Access.Get (Destination, 0, 1))
                  <= 0.0001,
         "Region isolation keeps the overlapping perfect match");
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
             OpenCV.Image_Processing.Normalized_Squared_Difference)
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
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      for Y in 0 .. 1 loop
         for X in 0 .. 1 loop
            OpenCV.Core.UInt8_Access.Set (Good, Y, X, 6);
         end loop;
      end loop;
      Bad := OpenCV.Core.Create (0, 0, (OpenCV.Core.UInt8, 1));
      Check (Bad, Good, Good);
      Bad := OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Check (Good, Bad, Good);
      Bad := OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Check (Good, Good, Bad);
      Bad := OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Check (Good, Good, Bad);
      Check
        (Good,
         Good,
         Good,
         OpenCV.Image_Processing.Normalized_Correlation_Coefficient);
      Match (Good, Good, Good, Destination);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32, "recovery after rejection");
   end Rejections;

   procedure Raw_Selector (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package API renames OpenCV.Image_Processing.Internal.C_API;
      use type API.Status;
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Status      : API.Status := API.Success;
      procedure Input (S : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Output (D : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              API.Match_Template_Masked
                (S, S, S, D, API.Template_Normalized_Correlation_Coefficient);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 4);
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      AUnit.Assertions.Assert
        (Status /= API.Success
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "raw coefficient selector preserves Destination");
   end Raw_Selector;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Masked NSQDIFF oracle", Oracle'Access));
      Result.Add_Test
        (Caller.Create ("Masked NSQDIFF above one", Above_One'Access));
      Result.Add_Test
        (Caller.Create ("Masked NSQDIFF zero window", Zero_Window'Access));
      Result.Add_Test
        (Caller.Create ("Masked NSQDIFF degenerate", Degenerate'Access));
      Result.Add_Test
        (Caller.Create ("Masked NSQDIFF regions", Regions'Access));
      Result.Add_Test
        (Caller.Create ("Masked NSQDIFF rejections", Rejections'Access));
      Result.Add_Test
        (Caller.Create ("Masked NSQDIFF raw selector", Raw_Selector'Access));
      return Result'Access;
   end Suite;

end Masked_NSQDIFF_Tests;
