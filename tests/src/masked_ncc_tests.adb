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

package body Masked_NCC_Tests is
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Image_Processing.Template_Matching_Method;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Score
     (Source   : OpenCV.Core.Mat;
      Template : OpenCV.Core.Mat;
      Mask     : OpenCV.Core.Mat;
      Y, X     : Integer) return Long_Float;
   procedure Positive_Energy (Test : in out Fixture);
   procedure Brightness (Test : in out Fixture);
   procedure Corruption (Test : in out Fixture);
   procedure Uniform_And_Sparse (Test : in out Fixture);
   procedure Zero_Window (Test : in out Fixture);
   procedure Degenerate (Test : in out Fixture);
   procedure Regions (Test : in out Fixture);
   procedure Rejections (Test : in out Fixture);
   procedure Raw_Rejection (Test : in out Fixture);

   function Score
     (Source   : OpenCV.Core.Mat;
      Template : OpenCV.Core.Mat;
      Mask     : OpenCV.Core.Mat;
      Y, X     : Integer) return Long_Float
   is
      Numerator, Template_Energy, Scene_Energy : Long_Float := 0.0;
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
               begin
                  Numerator := Numerator + T * I;
                  Template_Energy := Template_Energy + T * T;
                  Scene_Energy := Scene_Energy + I * I;
               end;
            end if;
         end loop;
      end loop;
      return
        Numerator
        / Ada.Numerics.Long_Elementary_Functions.Sqrt
            (Template_Energy * Scene_Energy);
   end Score;

   procedure Positive_Energy (Test : in out Fixture) is
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
      OpenCV.Core.UInt8_Access.Set (Template, 0, 1, 21);
      OpenCV.Core.UInt8_Access.Set (Template, 1, 0, 23);
      OpenCV.Core.UInt8_Access.Set (Template, 1, 1, 24);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 3);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 7);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 0, 255);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 1);
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Mask,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);
      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 4
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "NCC result layout");
      for Y in 0 .. 2 loop
         for X in 0 .. 3 loop
            AUnit.Assertions.Assert
              (abs (OpenCV.Core.Float32_Access.Get (Destination, Y, X)
                    - OpenCV.Float32_Value
                        (Score (Source, Template, Mask, Y, X)))
               <= 0.0001,
               "widened NCC oracle");
         end loop;
      end loop;
      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Maximum_Location.X = 0
         and then Extrema.Maximum_Location.Y = 0
         and then abs (Extrema.Maximum - 1.0) <= 0.0001,
         "exact translated maximum is one");
   end Positive_Energy;

   procedure Brightness (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Scaled      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Extrema     : OpenCV.Core.Min_Max_Result;
   begin
      for Y in 0 .. 2 loop
         for X in 0 .. 3 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Y, X, Interfaces.Unsigned_8 (10 + Y * 5 + X * 2));
         end loop;
      end loop;
      for Y in 0 .. 1 loop
         for X in 0 .. 1 loop
            declare
               Value : constant Interfaces.Unsigned_8 :=
                 OpenCV.Core.UInt8_Access.Get (Source, Y + 1, X + 1);
            begin
               OpenCV.Core.UInt8_Access.Set (Template, Y, X, Value);
               OpenCV.Core.UInt8_Access.Set (Scaled, Y, X, Value * 2);
               OpenCV.Core.UInt8_Access.Set (Mask, Y, X, 1);
            end;
         end loop;
      end loop;
      OpenCV.Image_Processing.Match_Template
        (Source,
         Scaled,
         Mask,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);
      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Maximum_Location.X = 1
         and then Extrema.Maximum_Location.Y = 1
         and then abs (Extrema.Maximum - 1.0) <= 0.0001,
         "positive brightness scale preserves the match");
   end Brightness;

   procedure Corruption (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Extrema     : OpenCV.Core.Min_Max_Result;
   begin
      for Y in 0 .. 2 loop
         for X in 0 .. 3 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Y, X, Interfaces.Unsigned_8 (30 + X * 7 + Y));
         end loop;
      end loop;
      for Y in 0 .. 1 loop
         for X in 0 .. 1 loop
            OpenCV.Core.UInt8_Access.Set
              (Template, Y, X, OpenCV.Core.UInt8_Access.Get (Source, Y, X));
            OpenCV.Core.UInt8_Access.Set (Mask, Y, X, 1);
         end loop;
      end loop;
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 255);
      OpenCV.Core.UInt8_Access.Set (Template, 1, 1, 0);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 0);
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Mask,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);
      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Maximum_Location.X = 0
         and then Extrema.Maximum_Location.Y = 0
         and then abs (Extrema.Maximum - 1.0) <= 0.0001,
         "excluded corruption restores the landmark");
   end Corruption;

   procedure Uniform_And_Sparse (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Y in 0 .. 2 loop
         for X in 0 .. 2 loop
            OpenCV.Core.UInt8_Access.Set (Source, Y, X, 40);
         end loop;
      end loop;
      for Y in 0 .. 1 loop
         for X in 0 .. 1 loop
            OpenCV.Core.UInt8_Access.Set (Template, Y, X, 0);
            OpenCV.Core.UInt8_Access.Set (Mask, Y, X, 0);
         end loop;
      end loop;
      OpenCV.Core.UInt8_Access.Set (Template, 1, 0, 12);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 0, 200);
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Mask,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);
      for Y in 0 .. 1 loop
         for X in 0 .. 1 loop
            AUnit.Assertions.Assert
              (abs (OpenCV.Core.Float32_Access.Get (Destination, Y, X) - 1.0)
               <= 0.0001,
               "uniform sparse score is one");
         end loop;
      end loop;
   end Uniform_And_Sparse;

   procedure Zero_Window (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 0);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 8);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 0, 6);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 1, 6);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 1);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 1);
      for Neighbor in 8 .. 10 loop
         OpenCV.Core.UInt8_Access.Set
           (Source, 0, 2, Interfaces.Unsigned_8 (Neighbor));
         OpenCV.Image_Processing.Match_Template
           (Source,
            Template,
            Mask,
            Destination,
            OpenCV.Image_Processing.Normalized_Cross_Correlation);
         AUnit.Assertions.Assert
           (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 0.0,
            "portable zero-energy window");
         AUnit.Assertions.Assert
           (abs (OpenCV.Core.Float32_Access.Get (Destination, 0, 1)
                 - OpenCV.Float32_Value (Score (Source, Template, Mask, 0, 1)))
            <= 0.0001,
            "adjacent positive window");
      end loop;
      --  The positive neighbor is excluded from the first sparse window.
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 0);
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Mask,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);
      for Column in 0 .. 1 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.Float32_Access.Get (Destination, 0, Column) = 0.0,
            "multiple sparse zero-energy windows");
      end loop;
   end Zero_Window;

   procedure Degenerate (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Good        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Zero_Image  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      procedure Expect (Template, Mask : OpenCV.Core.Mat) is
         Raised : Boolean := False;
      begin
         begin
            OpenCV.Image_Processing.Match_Template
              (Good,
               Template,
               Mask,
               Destination,
               OpenCV.Image_Processing.Normalized_Cross_Correlation);
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         AUnit.Assertions.Assert (Raised, "degenerate NCC rejected");
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
            "destination preserved");
      end Expect;
   begin
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      for Y in 0 .. 1 loop
         for X in 0 .. 1 loop
            OpenCV.Core.UInt8_Access.Set (Good, Y, X, 8);
            OpenCV.Core.UInt8_Access.Set (Zero_Image, Y, X, 0);
         end loop;
      end loop;
      Expect (Zero_Image, Good);
      Expect (Good, Zero_Image);
      OpenCV.Image_Processing.Match_Template
        (Good, Good, Zero_Image, Destination);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 0.0,
         "all-zero mask remains valid SQDIFF");
      OpenCV.Image_Processing.Match_Template
        (Good,
         Good,
         Good,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);
      AUnit.Assertions.Assert
        (abs (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) - 1.0)
         <= 0.0001,
         "recovery after degenerate rejection");
   end Degenerate;

   procedure Regions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 7, (OpenCV.Core.UInt8, 1));
      Source      : OpenCV.Core.Mat;
      Template    : OpenCV.Core.Mat;
      Mask_Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat;
      Before      : Interfaces.Unsigned_8;
   begin
      for Y in 0 .. 5 loop
         for X in 0 .. 6 loop
            OpenCV.Core.UInt8_Access.Set
              (Parent, Y, X, Interfaces.Unsigned_8 (11 + Y * 4 + X));
         end loop;
      end loop;
      for Y in 0 .. 3 loop
         for X in 0 .. 3 loop
            OpenCV.Core.UInt8_Access.Set (Mask_Parent, Y, X, 255);
         end loop;
      end loop;
      Source := Parent.Region ((X => 1, Y => 1, Width => 5, Height => 4));
      Template := Parent.Region ((X => 3, Y => 2, Width => 2, Height => 2));
      Mask := Mask_Parent.Region ((X => 1, Y => 1, Width => 2, Height => 2));
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 0);
      Before := OpenCV.Core.UInt8_Access.Get (Parent, 0, 0);
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Mask,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Parent, 0, 0) = Before
         and then Destination.Rows = 3
         and then Destination.Columns = 4
         and then abs (OpenCV.Core.Float32_Access.Get (Destination, 1, 2)
                       - 1.0)
                  <= 0.0001,
         "Region isolation and immutability");
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
             OpenCV.Image_Processing.Normalized_Cross_Correlation)
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
      for Method in OpenCV.Image_Processing.Template_Matching_Method loop
         if Method /= OpenCV.Image_Processing.Squared_Difference
           and then Method
                    /= OpenCV.Image_Processing.Normalized_Squared_Difference
           and then Method /= OpenCV.Image_Processing.Cross_Correlation
           and then Method
                    /= OpenCV.Image_Processing.Normalized_Cross_Correlation
           and then Method /= OpenCV.Image_Processing.Correlation_Coefficient
         then
            Check (Good, Good, Good, Method);
         end if;
      end loop;
      OpenCV.Image_Processing.Match_Template
        (Good,
         Good,
         Good,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32, "recovery after rejection");
   end Rejections;

   procedure Raw_Rejection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package API renames OpenCV.Image_Processing.Internal.C_API;
      use type API.Status;
      Empty       : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Status      : API.Status := API.Success;
      procedure Input (S : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Output (D : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              API.Match_Template_Masked
                (S, S, S, D, API.Template_Normalized_Cross_Correlation);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      OpenCV.Core.Module_Interop.With_Input_Handle (Empty, Input'Access);
      AUnit.Assertions.Assert
        (Status /= API.Success
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "raw malformed NCC rejection preserves Destination");
   end Raw_Rejection;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Masked NCC oracle", Positive_Energy'Access));
      Result.Add_Test
        (Caller.Create ("Masked NCC brightness", Brightness'Access));
      Result.Add_Test
        (Caller.Create ("Masked NCC corruption", Corruption'Access));
      Result.Add_Test
        (Caller.Create
           ("Masked NCC uniform sparse", Uniform_And_Sparse'Access));
      Result.Add_Test
        (Caller.Create ("Masked NCC zero window", Zero_Window'Access));
      Result.Add_Test
        (Caller.Create ("Masked NCC degenerate", Degenerate'Access));
      Result.Add_Test (Caller.Create ("Masked NCC regions", Regions'Access));
      Result.Add_Test
        (Caller.Create ("Masked NCC rejections", Rejections'Access));
      Result.Add_Test
        (Caller.Create ("Masked NCC raw ABI", Raw_Rejection'Access));
      return Result'Access;
   end Suite;
end Masked_NCC_Tests;
