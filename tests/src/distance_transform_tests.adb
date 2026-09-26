with Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Int32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Distance_Transform_Tests is
   package IP renames OpenCV.Image_Processing;
   package C_API renames IP.Internal.C_API;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type C_API.Status;
   use type IP.Distance_Transform_Method;
   use type IP.Distance_Label_Mode;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function To_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Input_Mat_Handle,
        System.Address);
   function To_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Output_Mat_Handle,
        System.Address);
   function Raw_F32
     (Source      : System.Address;
      Method      : Interfaces.Integer_32;
      Destination : System.Address) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_distance_transform_f32";
   function Raw_U8 (Source, Destination : System.Address) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_distance_transform_l1_u8";
   function Raw_Labeled
     (Source            : System.Address;
      Metric, Mode      : Interfaces.Integer_32;
      Distances, Labels : System.Address) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_distance_transform_labeled";

   procedure Set
     (M : in out OpenCV.Core.Mat; R, C : Natural; V : OpenCV.UInt8_Value := 0)
   is
   begin
      OpenCV.Core.UInt8_Access.Set (M, R, C, V);
   end Set;
   function U (M : OpenCV.Core.Mat; R, C : Natural) return OpenCV.UInt8_Value
   is (OpenCV.Core.UInt8_Access.Get (M, R, C));
   function F (M : OpenCV.Core.Mat; R, C : Natural) return OpenCV.Float32_Value
   is (OpenCV.Core.Float32_Access.Get (M, R, C));
   function L
     (M : OpenCV.Core.Mat; R, C : Natural) return Interfaces.Integer_32
   is (OpenCV.Core.Int32_Access.Get (M, R, C));
   procedure Near (Actual, Expected, Tolerance : OpenCV.Float32_Value) is
   begin
      AUnit.Assertions.Assert
        (abs (Actual - Expected) <= Tolerance,
         "distance actual"
         & OpenCV.Float32_Value'Image (Actual)
         & " expected"
         & OpenCV.Float32_Value'Image (Expected));
   end Near;

   procedure Metrics (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : OpenCV.Core.Mat := OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (S, (others => 255.0));
      Set (S, 4, 4);
      for M in IP.Distance_Transform_Method loop
         declare
            D : constant OpenCV.Core.Mat := IP.Distance_Transform (S, M);
         begin
            AUnit.Assertions.Assert
              (D.Rows = 9
               and then D.Columns = 9
               and then D.Depth = OpenCV.Core.Float32
               and then D.Channels = 1,
               "Float32 result metadata");
            Near (F (D, 4, 4), 0.0, 0.0);
            if M = IP.Manhattan_Distance then
               Near (F (D, 6, 7), 5.0, 0.0);
               Near (F (D, 4, 7), 3.0, 0.0);
               Near (F (D, 6, 4), 2.0, 0.0);
            elsif M = IP.Chessboard_Distance then
               Near (F (D, 5, 5), 1.0, 0.0);
               Near (F (D, 6, 7), 3.0, 0.0);
            elsif M = IP.Euclidean_3x3 then
               Near (F (D, 4, 5), 0.955, 0.002);
               Near (F (D, 5, 5), 1.3693, 0.002);
            elsif M = IP.Euclidean_5x5 then
               Near (F (D, 4, 5), 1.0, 0.002);
               Near
                 (F (D, 6, 7),
                  OpenCV.Float32_Value
                    (Ada.Numerics.Elementary_Functions.Sqrt (13.0)),
                  0.02);
            else
               Near
                 (F (D, 6, 7),
                  OpenCV.Float32_Value
                    (Ada.Numerics.Elementary_Functions.Sqrt (13.0)),
                  0.0001);
            end if;
         end;
      end loop;
      AUnit.Assertions.Assert
        (U (S, 4, 4) = 0 and then U (S, 6, 7) = 255, "source preserved");
      declare
         Three : constant OpenCV.Core.Mat :=
           IP.Distance_Transform (S, IP.Euclidean_3x3);
         Five  : constant OpenCV.Core.Mat :=
           IP.Distance_Transform (S, IP.Euclidean_5x5);
         Exact : constant OpenCV.Float32_Value :=
           OpenCV.Float32_Value
             (Ada.Numerics.Elementary_Functions.Sqrt (13.0));
      begin
         AUnit.Assertions.Assert
           (abs (F (Five, 6, 7) - Exact) < abs (F (Three, 6, 7) - Exact),
            "5x5 approximation improves on 3x3 for offset (3,2)");
      end;
      Set (S, 6, 7, 1);
      Near
        (F (IP.Distance_Transform (S, IP.Manhattan_Distance), 6, 7), 5.0, 0.0);
   end Metrics;

   procedure U8_And_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 300, (OpenCV.Core.UInt8, 1));
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (S, (others => 1.0));
      Set (S, 0, 0);
      declare
         D : constant OpenCV.Core.Mat :=
           IP.Manhattan_Distance_Transform_UInt8 (S);
      begin
         AUnit.Assertions.Assert
           (D.Depth = OpenCV.Core.UInt8
            and then D.Channels = 1
            and then D.Rows = 1
            and then D.Columns = 300,
            "UInt8 result metadata");
         AUnit.Assertions.Assert
           (U (D, 0, 2) = 2
            and then U (D, 0, 255) = 255
            and then U (D, 0, 299) = 255,
            "Manhattan distance saturates at 255");
      end;
      OpenCV.Core.Set_To (Parent, (others => 1.0));
      Set (Parent, 0, 2);
      Set (Parent, 2, 2);
      declare
         R : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
         D : constant OpenCV.Core.Mat :=
           IP.Distance_Transform (R, IP.Manhattan_Distance);
      begin
         Near (F (D, 0, 1), 1.0, 0.0);
         Near (F (D, 1, 1), 0.0, 0.0);
      end;
   end U8_And_Region;

   procedure Labels_And_Zeros (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : OpenCV.Core.Mat := OpenCV.Core.Create (7, 9, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (S, (others => 255.0));
      Set (S, 2, 1);
      Set (S, 2, 2);
      Set (S, 2, 7);
      for Metric in IP.Labeled_Distance_Metric loop
         for Mode in IP.Distance_Label_Mode loop
            declare
               R : constant IP.Labeled_Distance_Transform_Result :=
                 IP.Distance_Transform_With_Labels (S, Metric, Mode);
            begin
               AUnit.Assertions.Assert
                 (R.Distances.Depth = OpenCV.Core.Float32
                  and then R.Labels.Depth = OpenCV.Core.Int32
                  and then R.Distances.Channels = 1
                  and then R.Labels.Channels = 1
                  and then R.Distances.Rows = 7
                  and then R.Labels.Columns = 9,
                  "labeled output geometry and types");
               AUnit.Assertions.Assert
                 (L (R.Labels, 2, 1) > 0
                  and then L (R.Labels, 2, 7) > 0
                  and then L (R.Labels, 2, 1) /= L (R.Labels, 2, 7)
                  and then L (R.Labels, 2, 3) = L (R.Labels, 2, 2)
                  and then L (R.Labels, 2, 6) = L (R.Labels, 2, 7),
                  "nearest zero labels");
               AUnit.Assertions.Assert
                 ((L (R.Labels, 2, 1) = L (R.Labels, 2, 2))
                  = (Mode = IP.Nearest_Zero_Component),
                  "label grouping");
               Near (F (R.Distances, 2, 3), 1.0, 0.05);
               Near (F (R.Distances, 2, 2), 0.0, 0.0);
            end;
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (U (S, 2, 1) = 0 and then U (S, 2, 3) = 255,
         "labeled source preserved");
      OpenCV.Core.Set_To (S, (others => 0.0));
      Near (F (IP.Distance_Transform (S), 4, 5), 0.0, 0.0);
   end Labels_And_Zeros;

   procedure Labeled_Metric_Discrimination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : OpenCV.Core.Mat := OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (S, (others => 255.0));
      Set (S, 2, 2);
      for Metric in IP.Labeled_Distance_Metric loop
         declare
            R : constant IP.Labeled_Distance_Transform_Result :=
              IP.Distance_Transform_With_Labels
                (S, Metric, IP.Nearest_Zero_Pixel);
         begin
            AUnit.Assertions.Assert
              (L (R.Labels, 2, 2) = 1
               and then L (R.Labels, 4, 4) = L (R.Labels, 2, 2),
               "offset pixel receives the isolated zero's label");
            case Metric is
               when IP.Manhattan_Label_Distance  =>
                  Near (F (R.Distances, 4, 4), 4.0, 0.0);

               when IP.Chessboard_Label_Distance =>
                  Near (F (R.Distances, 4, 4), 2.0, 0.0);

               when IP.Euclidean_Label_Distance  =>
                  Near
                    (F (R.Distances, 4, 4),
                     OpenCV.Float32_Value
                       (Ada.Numerics.Elementary_Functions.Sqrt (8.0)),
                     0.05);
            end case;
         end;
      end loop;
   end Labeled_Metric_Discrimination;

   procedure Public_Invalid (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty   : OpenCV.Core.Mat;
      Bad16   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Bad32   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Bad3    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      ND      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      No_Zero : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      procedure Check (S : OpenCV.Core.Mat) is
         Raised : Boolean := False;
      begin
         begin
            declare
               D : constant OpenCV.Core.Mat := IP.Distance_Transform (S);
            begin
               pragma Unreferenced (D);
               AUnit.Assertions.Assert (False, "invalid source accepted");
            end;
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         AUnit.Assertions.Assert (Raised, "invalid source rejected");
         Raised := False;
         begin
            declare
               D : constant OpenCV.Core.Mat :=
                 IP.Manhattan_Distance_Transform_UInt8 (S);
            begin
               pragma Unreferenced (D);
               AUnit.Assertions.Assert (False, "invalid UInt8 accepted");
            end;
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         AUnit.Assertions.Assert (Raised, "invalid UInt8 source rejected");
         Raised := False;
         begin
            declare
               D : constant IP.Labeled_Distance_Transform_Result :=
                 IP.Distance_Transform_With_Labels (S);
            begin
               pragma Unreferenced (D);
               AUnit.Assertions.Assert (False, "invalid labels accepted");
            end;
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         AUnit.Assertions.Assert (Raised, "invalid labeled source rejected");
      end Check;
   begin
      OpenCV.Core.Set_To (No_Zero, (others => 1.0));
      Check (Empty);
      Check (Bad16);
      Check (Bad32);
      Check (Bad3);
      Check (ND);
      Check (No_Zero);
   end Public_Invalid;

   procedure Raw_Atomic (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S              : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      D              : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      U8             : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Lbl            : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int32, 1));
      Empty          : OpenCV.Core.Mat;
      Wrong_Depth    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Wrong_Channels : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Wrong_Dims     : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      No_Zero        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Hs, Hd, Hu, Hl : System.Address := System.Null_Address;
      procedure Input (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Hs := To_Address (H);
      end Input;
      procedure Out_D (H : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Hd := To_Address (H);
      end Out_D;
      procedure Out_U (H : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Hu := To_Address (H);
      end Out_U;
      procedure Out_L (H : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Hl := To_Address (H);
      end Out_L;
      procedure Invalid_Source
        (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         AUnit.Assertions.Assert
           (Raw_F32 (To_Address (H), 4, Hd) = C_API.Error_Invalid_Argument
            and then Raw_U8 (To_Address (H), Hu) = C_API.Error_Invalid_Argument
            and then Raw_Labeled (To_Address (H), 1, 0, Hd, Hl)
                     = C_API.Error_Invalid_Argument,
            "raw invalid source rejected for every entry point");
      end Invalid_Source;
   begin
      OpenCV.Core.Set_To (S, (others => 1.0));
      Set (S, 1, 1);
      OpenCV.Core.Set_To (D, (others => 42.0));
      OpenCV.Core.Set_To (U8, (others => 43.0));
      OpenCV.Core.Set_To (Lbl, (others => 44.0));
      OpenCV.Core.Module_Interop.With_Input_Handle (S, Input'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle (D, Out_D'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle (U8, Out_U'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle (Lbl, Out_L'Access);
      OpenCV.Core.Set_To (No_Zero, (others => 255.0));
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Empty, Invalid_Source'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Wrong_Depth, Invalid_Source'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Wrong_Channels, Invalid_Source'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Wrong_Dims, Invalid_Source'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (No_Zero, Invalid_Source'Access);
      AUnit.Assertions.Assert
        (Raw_F32 (Hs, 99, Hd) = C_API.Error_Invalid_Argument
         and then Raw_Labeled (Hs, 99, 0, Hd, Hl)
                  = C_API.Error_Invalid_Argument
         and then Raw_Labeled (Hs, 0, 99, Hd, Hl)
                  = C_API.Error_Invalid_Argument
         and then Raw_Labeled (Hs, 0, 0, Hd, Hd) = C_API.Error_Invalid_Argument
         and then Raw_U8 (System.Null_Address, Hu)
                  = C_API.Error_Invalid_Argument,
         "raw selectors, aliases and null handles rejected");
      Near (F (D, 0, 0), 42.0, 0.0);
      AUnit.Assertions.Assert
        (U (U8, 0, 0) = 43 and then L (Lbl, 0, 0) = 44,
         "rejected raw calls preserve outputs");
      AUnit.Assertions.Assert
        (Raw_Labeled (Hs, 1, 1, Hd, Hl) = C_API.Success,
         "valid call after rejected calls");
      Near (F (D, 1, 1), 0.0, 0.0);
   end Raw_Atomic;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Distance metrics", Metrics'Access));
      Result.Add_Test
        (Caller.Create ("UInt8 saturation and Region", U8_And_Region'Access));
      Result.Add_Test
        (Caller.Create ("Voronoi labels and zeros", Labels_And_Zeros'Access));
      Result.Add_Test
        (Caller.Create
           ("Labeled metrics discriminate non-axis offsets",
            Labeled_Metric_Discrimination'Access));
      Result.Add_Test
        (Caller.Create ("Invalid distance sources", Public_Invalid'Access));
      Result.Add_Test
        (Caller.Create ("Raw failure atomicity", Raw_Atomic'Access));
      return Result'Access;
   end Suite;
end Distance_Transform_Tests;
