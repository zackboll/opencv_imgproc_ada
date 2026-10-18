with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Int16_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Canny_Edge_Tests is

   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Size_Coordinate;
   use type OpenCV.Float64_Value;

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

   procedure Set_Vertical_Step (Image : in out OpenCV.Core.Mat) is
   begin
      for Row in 0 .. Integer (Image.Rows) - 1 loop
         for Column in 0 .. Integer (Image.Columns) - 1 loop
            OpenCV.Core.UInt8_Access.Set (Image, Row, Column, 0);
         end loop;

         for Column in 4 .. Integer (Image.Columns) - 1 loop
            OpenCV.Core.UInt8_Access.Set (Image, Row, Column, 255);
         end loop;
      end loop;
   end Set_Vertical_Step;

   function Has_Edge_In_Column_Range
     (Image : OpenCV.Core.Mat; First, Last : Integer) return Boolean is
   begin
      for Row in 0 .. Integer (Image.Rows) - 1 loop
         for Column in First .. Last loop
            if OpenCV.Core.UInt8_Access.Get (Image, Row, Column) /= 0 then
               return True;
            end if;
         end loop;
      end loop;

      return False;
   end Has_Edge_In_Column_Range;

   procedure Default_Canny_Finds_Step_And_Preserves_Source
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 10, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
   begin
      Set_Vertical_Step (Source);
      OpenCV.Image_Processing.Canny_Edges (Source, Destination, 50.0, 100.0);

      AUnit.Assertions.Assert
        (Destination.Rows = Source.Rows
         and then Destination.Columns = Source.Columns
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "default Canny must produce a UInt8 C1 Mat with source geometry");
      AUnit.Assertions.Assert
        (Has_Edge_In_Column_Range (Destination, 3, 4),
         "default Canny must detect the vertical step");
      AUnit.Assertions.Assert
        (not Has_Edge_In_Column_Range (Destination, 0, 1),
         "default Canny must leave the flat region without edges");
      AUnit.Assertions.Assert
        (Source.Rows = 8
         and then Source.Columns = 10
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 3) = 0
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 4) = 255,
         "Canny must not invalidate or modify the source Mat");
   end Default_Canny_Finds_Step_And_Preserves_Source;

   procedure Sobel_5x5_L2_Succeeds (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 10, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Set_Vertical_Step (Source);
      OpenCV.Image_Processing.Canny_Edges
        (Source,
         Destination,
         50.0,
         100.0,
         OpenCV.Image_Processing.Sobel_5x5,
         OpenCV.Image_Processing.L2_Norm);
      AUnit.Assertions.Assert
        (Has_Edge_In_Column_Range (Destination, 3, 4),
         "Sobel 5x5 L2 Canny must detect the vertical step");
   end Sobel_5x5_L2_Succeeds;

   procedure Sobel_7x7_Succeeds (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 10, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Set_Vertical_Step (Source);
      OpenCV.Image_Processing.Canny_Edges
        (Source, Destination, 50.0, 100.0, OpenCV.Image_Processing.Sobel_7x7);
      AUnit.Assertions.Assert
        (Has_Edge_In_Column_Range (Destination, 3, 4),
         "Sobel 7x7 Canny must detect the vertical step");
   end Sobel_7x7_Succeeds;

   procedure Canny_Rejects_Invalid_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Empty_Source  : OpenCV.Core.Mat;
      Three_D       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      UInt16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Color_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Destination   : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Canny_Edges
           (Empty_Source, Destination, 1.0, 2.0);
      end Empty;
      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Canny_Edges (Three_D, Destination, 1.0, 2.0);
      end Non_Two_Dimensional;
      procedure Unsupported_Depth is
      begin
         OpenCV.Image_Processing.Canny_Edges
           (UInt16_Source, Destination, 1.0, 2.0);
      end Unsupported_Depth;
      procedure Color is
      begin
         OpenCV.Image_Processing.Canny_Edges
           (Color_Source, Destination, 1.0, 2.0);
      end Color;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "Canny must reject empty input");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "Canny must reject three-dimensional input");
      Assert_Raises_OpenCV_Error
        (Unsupported_Depth'Access, "Canny must reject UInt16 input");
      Assert_Raises_OpenCV_Error
        (Color'Access, "Canny must reject UInt8 C3 input");
   end Canny_Rejects_Invalid_Source;

   procedure Canny_Rejects_Invalid_Thresholds (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;

      procedure Negative_Lower is
      begin
         OpenCV.Image_Processing.Canny_Edges (Source, Destination, -1.0, 2.0);
      end Negative_Lower;
      procedure Negative_Upper is
      begin
         OpenCV.Image_Processing.Canny_Edges (Source, Destination, 1.0, -2.0);
      end Negative_Upper;
      procedure Reversed is
      begin
         OpenCV.Image_Processing.Canny_Edges (Source, Destination, 3.0, 2.0);
      end Reversed;
   begin
      Assert_Raises_OpenCV_Error
        (Negative_Lower'Access,
         "Canny must reject a negative lower threshold");
      Assert_Raises_OpenCV_Error
        (Negative_Upper'Access,
         "Canny must reject a negative upper threshold");
      Assert_Raises_OpenCV_Error
        (Reversed'Access, "Canny must reject reversed thresholds");
   end Canny_Rejects_Invalid_Thresholds;

   procedure Derivative_Patterns (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      use type Interfaces.Integer_32;
      use type Interfaces.Integer_16;
      function Matches
        (X, Y, D   : OpenCV.Core.Module_Interop.Input_Mat_Handle;
         Low, High : Interfaces.C.double;
         Norm      : Interfaces.Integer_32) return Interfaces.Integer_32
      with
        Import,
        Convention    => C,
        External_Name => "imgproc_test_gradient_canny_reference";
   begin
      for Channels of OpenCV.Core.Dimension_Array'(1, 3) loop
         for Norm in Canny_Gradient_Norm loop
            for Vertical in Boolean loop
               declare
                  PX    : OpenCV.Core.Mat :=
                    OpenCV.Core.Create
                      (9,
                       13,
                       (OpenCV.Core.Int16,
                        OpenCV.Core.Channel_Count (Channels)));
                  PY    : OpenCV.Core.Mat :=
                    OpenCV.Core.Create
                      (9,
                       13,
                       (OpenCV.Core.Int16,
                        OpenCV.Core.Channel_Count (Channels)));
                  X     : OpenCV.Core.Mat := PX.Region ((1, 1, 9, 7));
                  Y     : OpenCV.Core.Mat := PY.Region ((1, 1, 9, 7));
                  D     : OpenCV.Core.Mat :=
                    OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
                  Old   : constant OpenCV.Core.Mat := D;
                  Check : Interfaces.Integer_32 := -1;
                  procedure XI
                    (HX : OpenCV.Core.Module_Interop.Input_Mat_Handle)
                  is
                     procedure YI
                       (HY : OpenCV.Core.Module_Interop.Input_Mat_Handle)
                     is
                        procedure DI
                          (HD : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
                        begin
                           Check :=
                             Matches
                               (HX,
                                HY,
                                HD,
                                50.0,
                                100.0,
                                Canny_Gradient_Norm'Pos (Norm));
                        end DI;
                     begin
                        OpenCV.Core.Module_Interop.With_Input_Handle
                          (D, DI'Access);
                     end YI;
                  begin
                     OpenCV.Core.Module_Interop.With_Input_Handle
                       (Y, YI'Access);
                  end XI;
               begin
                  OpenCV.Core.Set_To (PX, (others => 0.0));
                  OpenCV.Core.Set_To (PY, (others => 0.0));
                  OpenCV.Core.Set_To (D, (others => 17.0));
                  declare
                     Stripe : OpenCV.Core.Mat :=
                       (if Vertical
                        then X.Region ((4, 0, 1, 7))
                        else Y.Region ((0, 3, 9, 1)));
                  begin
                     OpenCV.Core.Set_To (Stripe, (others => 200.0));
                  end;
                  Canny_Edges (X, Y, D, 50.0, 100.0, Norm);
                  OpenCV.Core.Module_Interop.With_Input_Handle (X, XI'Access);
                  AUnit.Assertions.Assert
                    (Check = 1, "native derivative Canny equality");
                  AUnit.Assertions.Assert
                    (D.Rows = 7
                     and then D.Columns = 9
                     and then D.Depth = OpenCV.Core.UInt8
                     and then D.Channels = 1,
                     "derivative output metadata");
                  AUnit.Assertions.Assert
                    (OpenCV.Core.UInt8_Access.Get (D, 3, 4) = 255,
                     "controlled derivative edge");
                  AUnit.Assertions.Assert
                    (Old.Rows = 1
                     and then OpenCV.Core.UInt8_Access.Get (Old, 0, 0) = 17,
                     "fresh result leaves old destination aliases unchanged");
                  if Channels = 1 then
                     AUnit.Assertions.Assert
                       (OpenCV.Core.Int16_Access.Get
                          ((if Vertical then X else Y), 3, 4)
                        = 200,
                        "derivatives preserved");
                  end if;
                  Canny_Edges (X, Y, D, 50.0, 100.0, Norm);
               end;
            end loop;
         end loop;
      end loop;
   end Derivative_Patterns;

   procedure Derivative_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      X    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 1));
      Y    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 1));
      D    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Bad  : OpenCV.Core.Mat;
      Low  : OpenCV.Float64_Value := 1.0;
      High : OpenCV.Float64_Value := 2.0;
      procedure Attempt is
      begin
         Canny_Edges (X, Bad, D, Low, High);
      end Attempt;
      procedure Alias is
      begin
         Canny_Edges (X, Y, X, 1.0, 2.0);
      end Alias;
   begin
      OpenCV.Core.Set_To (X, (others => 0.0));
      OpenCV.Core.Set_To (Y, (others => 0.0));
      OpenCV.Core.Set_To (D, (others => 19.0));
      Assert_Raises_OpenCV_Error (Attempt'Access, "empty derivative");
      Bad := OpenCV.Core.Create (2, 3, (OpenCV.Core.Int16, 1));
      Assert_Raises_OpenCV_Error (Attempt'Access, "geometry mismatch");
      Bad := OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt16, 1));
      Assert_Raises_OpenCV_Error (Attempt'Access, "wrong depth");
      Bad := OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 2));
      Assert_Raises_OpenCV_Error (Attempt'Access, "wrong channels");
      Bad :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(3, 3, 3), (OpenCV.Core.Int16, 1));
      Assert_Raises_OpenCV_Error (Attempt'Access, "3-D derivative");
      Bad := Y;
      Low := -1.0;
      Assert_Raises_OpenCV_Error (Attempt'Access, "negative threshold");
      Low := 3.0;
      Assert_Raises_OpenCV_Error (Attempt'Access, "reversed threshold");
      Low := 1.0;
      High := 2_147_483_648.0;
      Assert_Raises_OpenCV_Error (Attempt'Access, "unsafe integer threshold");
      High := 2.0;
      Assert_Raises_OpenCV_Error (Alias'Access, "self alias");
      OpenCV.Core.Set_To (X, (others => 32767.0));
      OpenCV.Core.Set_To (Bad, (others => 32767.0));
      Assert_Raises_OpenCV_Error (Attempt'Access, "native direction overflow");
      AUnit.Assertions.Assert
        (D.Rows = 1 and then OpenCV.Core.UInt8_Access.Get (D, 0, 0) = 19,
         "rejected derivative calls preserve destination");
      OpenCV.Core.Set_To (X, (others => 0.0));
      Canny_Edges (X, Y, D, 1.0, 2.0);
   end Derivative_Invalid_Inputs;

   procedure Derivative_Nonfinite_And_ABI (Test : in out Fixture) is
      --  Deliberate IEEE nonfinite arguments exercise public validation.
      pragma Suppress (Validity_Check);
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      package API renames OpenCV.Image_Processing.Internal.C_API;
      use type API.Status;
      function From_Bits is new
        Ada.Unchecked_Conversion
          (Interfaces.Unsigned_64,
           OpenCV.Float64_Value);
      X      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 1));
      Y      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 1));
      D      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Low    : OpenCV.Float64_Value := 0.0;
      High   : OpenCV.Float64_Value := 1.0;
      Status : API.Status := API.Success;
      procedure Attempt is
      begin
         Canny_Edges (X, Y, D, Low, High);
      end Attempt;
      procedure Raw_X (HX : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Raw_Y (HY : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            procedure Raw_D (HD : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
            begin
               Status := API.Canny_Derivatives (HX, HY, HD, 0.0, 1.0, 99);
            end Raw_D;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle (D, Raw_D'Access);
         end Raw_Y;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Y, Raw_Y'Access);
      end Raw_X;
   begin
      OpenCV.Core.Set_To (X, (others => 0.0));
      OpenCV.Core.Set_To (Y, (others => 0.0));
      OpenCV.Core.Set_To (D, (others => 31.0));
      Low := From_Bits (16#7FF8_0000_0000_0000#);
      Assert_Raises_OpenCV_Error (Attempt'Access, "NaN lower threshold");
      Low := 0.0;
      High := From_Bits (16#7FF8_0000_0000_0000#);
      Assert_Raises_OpenCV_Error (Attempt'Access, "NaN upper threshold");
      High := From_Bits (16#7FF0_0000_0000_0000#);
      Assert_Raises_OpenCV_Error (Attempt'Access, "infinite upper threshold");
      Low := High;
      High := 1.0;
      Assert_Raises_OpenCV_Error (Attempt'Access, "infinite lower threshold");
      Low := From_Bits (16#FFF0_0000_0000_0000#);
      Assert_Raises_OpenCV_Error (Attempt'Access, "negative infinity");
      OpenCV.Core.Module_Interop.With_Input_Handle (X, Raw_X'Access);
      AUnit.Assertions.Assert
        (Status = API.Error_Invalid_Argument,
         "raw derivative norm selector rejected");
      OpenCV.Core.Set_To (X, (others => -32768.0));
      OpenCV.Core.Set_To (Y, (others => -32768.0));
      declare
         procedure L2 is
         begin
            Canny_Edges (X, Y, D, 0.0, 1.0, L2_Norm);
         end L2;
      begin
         Assert_Raises_OpenCV_Error (L2'Access, "native L2 signed overflow");
      end;
      AUnit.Assertions.Assert
        (D.Rows = 1 and then OpenCV.Core.UInt8_Access.Get (D, 0, 0) = 31,
         "nonfinite and ABI rejection atomicity");
   end Derivative_Nonfinite_And_ABI;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Derivative Canny nonfinite thresholds and malformed ABI",
            Derivative_Nonfinite_And_ABI'Access));
      Result.Add_Test
        (Caller.Create
           ("Derivative Canny C1/C3 L1/L2 regions native oracle and reuse",
            Derivative_Patterns'Access));
      Result.Add_Test
        (Caller.Create
           ("Derivative Canny invalid inputs atomicity and recovery",
            Derivative_Invalid_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Default Canny finds a step and preserves source",
            Default_Canny_Finds_Step_And_Preserves_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Sobel 5x5 L2 Canny succeeds", Sobel_5x5_L2_Succeeds'Access));
      Result.Add_Test
        (Caller.Create
           ("Sobel 7x7 Canny succeeds", Sobel_7x7_Succeeds'Access));
      Result.Add_Test
        (Caller.Create
           ("Canny rejects invalid source Mats",
            Canny_Rejects_Invalid_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Canny rejects invalid thresholds",
            Canny_Rejects_Invalid_Thresholds'Access));
      return Result'Access;
   end Suite;

end Canny_Edge_Tests;
