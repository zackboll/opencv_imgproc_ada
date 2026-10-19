with Ada.Unchecked_Conversion;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Native_Reference;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Line_Segment_Detector_Tests is
   pragma Suppress (Validity_Check);
   package IP renames OpenCV.Image_Processing;
   package C renames OpenCV.Image_Processing.Internal.C_API;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   use type C.Status;
   use type IP.LSD_Segment_Array;
   use type IP.LSD_Refinement;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result     : aliased AUnit.Test_Suites.Test_Suite;
   Empty      : constant IP.LSD_Segment_Array (1 .. 0) := (others => <>);
   Horizontal : constant IP.LSD_Segment_Array :=
     (3 => ((10.25, 30.0), (90.5, 30.0), 2.0, 0.125, False, 0.0));
   Vertical   : constant IP.LSD_Segment_Array :=
     (5 => ((50.0, 10.0), (50.0, 90.0), 2.0, 0.125, False, 0.0));

   function Available return Boolean
   is (Native_Reference.Version >= 40504);

   function Blank
     (Channels : OpenCV.Core.Channel_Count := 1) return OpenCV.Core.Mat
   is
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (128, 128, (OpenCV.Core.UInt8, Channels));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      return Image;
   end Blank;

   function Pattern (Kind : Positive) return OpenCV.Core.Mat is
      Image : OpenCV.Core.Mat := Blank;
      White : constant OpenCV.Scalar := (255.0, 0.0, 0.0, 0.0);
   begin
      case Kind is
         when 1      =>
            IP.Draw_Line (Image, (12, 40), (112, 40), White, 2);

         when 2      =>
            IP.Draw_Line (Image, (40, 12), (40, 112), White, 2);

         when 3      =>
            IP.Draw_Line (Image, (12, 15), (110, 105), White, 2);

         when 4      =>
            IP.Draw_Rectangle (Image, (20, 20, 80, 80), White, 2);

         when others =>
            IP.Draw_Line (Image, (12, 30), (112, 30), White, 2);
            IP.Draw_Line (Image, (12, 90), (112, 90), White, 2);
      end case;
      return Image;
   end Pattern;

   procedure Expect_Error (Action : not null access procedure) is
   begin
      Action.all;
      Assert (False, "expected OpenCV_Error");
   exception
      when OpenCV.OpenCV_Error =>
         null;
   end Expect_Error;

   procedure Detection (Kind : Positive; Mode : IP.LSD_Refinement) is
      Image  : constant OpenCV.Core.Mat := Pattern (Kind);
      Before : constant OpenCV.Core.Mat := Image.Clone;
   begin
      if not Available then
         declare
            procedure Attempt is
               Lines : constant IP.LSD_Segment_Array :=
                 IP.Detect_Line_Segments
                   (Image, (Refinement => Mode, others => <>));
            begin
               Assert (Lines'Length = 0, "unsupported result must not escape");
            end Attempt;
         begin
            Expect_Error (Attempt'Access);
         end;
         return;
      end if;
      declare
         Lines    : constant IP.LSD_Segment_Array :=
           IP.Detect_Line_Segments (Image, (Refinement => Mode, others => <>));
         Subpixel : Boolean := False;
      begin
         Assert
           (Lines'Length > 0 and then Lines'First = 0, "real LSD detections");
         for S of Lines loop
            Assert (S.Width > 0.0 and then S.Precision > 0.0, "diagnostics");
            Assert
              (S.Has_NFA = (Mode = IP.Advanced_Refinement),
               "NFA availability");
            if not S.Has_NFA then
               Assert (S.NFA = 0.0, "no fabricated NFA");
            end if;
            Subpixel :=
              Subpixel
              or else abs (S.Start_Point.X
                           - OpenCV.Float32_Value (Integer (S.Start_Point.X)))
                      > 0.01
              or else abs (S.Start_Point.Y
                           - OpenCV.Float32_Value (Integer (S.Start_Point.Y)))
                      > 0.01;
         end loop;
         Assert (Subpixel, "native fractional coordinates preserved");
      end;
      for R in 0 .. 127 loop
         for Col in 0 .. 127 loop
            Assert
              (OpenCV.Core.UInt8_Access.Get (Image, R, Col)
               = OpenCV.Core.UInt8_Access.Get (Before, R, Col),
               "source preserved");
         end loop;
      end loop;
   end Detection;

   procedure Horizontal_Test (F : in out Fixture) is
      pragma Unreferenced (F);
   begin
      Detection (1, IP.Standard_Refinement);
   end Horizontal_Test;
   procedure Vertical_Test (F : in out Fixture) is
      pragma Unreferenced (F);
   begin
      Detection (2, IP.Standard_Refinement);
   end Vertical_Test;
   procedure Diagonal_Test (F : in out Fixture) is
      pragma Unreferenced (F);
   begin
      Detection (3, IP.Standard_Refinement);
   end Diagonal_Test;
   procedure Rectangle_Test (F : in out Fixture) is
      pragma Unreferenced (F);
   begin
      Detection (4, IP.Standard_Refinement);
   end Rectangle_Test;
   procedure Separated_Test (F : in out Fixture) is
      pragma Unreferenced (F);
   begin
      Detection (5, IP.Standard_Refinement);
   end Separated_Test;
   procedure No_Refinement_Test (F : in out Fixture) is
      pragma Unreferenced (F);
   begin
      Detection (3, IP.No_Refinement);
   end No_Refinement_Test;
   procedure Advanced_Test (F : in out Fixture) is
      pragma Unreferenced (F);
   begin
      Detection (4, IP.Advanced_Refinement);
   end Advanced_Test;

   procedure Blank_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      procedure Attempt is
         Lines : constant IP.LSD_Segment_Array :=
           IP.Detect_Line_Segments (Blank);
      begin
         Assert
           (Lines'Length = 0 and then Lines'First = 1,
            "null array convention");
      end Attempt;
   begin
      if Available then
         Attempt;
      else
         Expect_Error (Attempt'Access);
      end if;
   end Blank_Test;

   procedure Parameters_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      Image : constant OpenCV.Core.Mat := Pattern (1);
      P     : IP.LSD_Parameters;
      procedure Attempt is
         Lines : constant IP.LSD_Segment_Array :=
           IP.Detect_Line_Segments (Image, P);
      begin
         Assert (Lines'Length > 0, "valid parameter variation");
      end Attempt;
   begin
      for I in 1 .. 11 loop
         P := (others => <>);
         case I is
            when 1      =>
               P.Scale := 0.0;

            when 2      =>
               P.Scale := 1.1;

            when 3      =>
               P.Sigma_Scale := 0.0;

            when 4      =>
               P.Quantization := -1.0;

            when 5      =>
               P.Angle_Degrees := 0.0;

            when 6      =>
               P.Angle_Degrees := 180.0;

            when 7      =>
               P.Density := -0.1;

            when 8      =>
               P.Density := 1.0;

            when 9      =>
               P.Scale := 1.0E-20;

            when 10     =>
               P.Sigma_Scale := 1.0E30;

            when others =>
               P.Bin_Count := Positive'Last;
         end case;
         Expect_Error (Attempt'Access);
      end loop;
      P :=
        (Scale         => 1.0,
         Sigma_Scale   => 1.0,
         Quantization  => 1.0,
         Angle_Degrees => 30.0,
         Density       => 0.5,
         Bin_Count     => 512,
         others        => <>);
      if Available then
         Attempt;
      else
         Expect_Error (Attempt'Access);
      end if;
   end Parameters_Test;

   procedure Nonfinite_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      function From_Bits is new
        Ada.Unchecked_Conversion
          (Interfaces.Unsigned_64,
           OpenCV.Float64_Value);
      P : IP.LSD_Parameters;
      procedure Attempt is
         Lines : constant IP.LSD_Segment_Array :=
           IP.Detect_Line_Segments (Blank, P);
      begin
         Assert (Lines'Length = 0, "nonfinite result");
      end Attempt;
   begin
      for I in 1 .. 2 loop
         declare
            pragma Suppress (Range_Check);
            V : constant OpenCV.Float64_Value :=
              From_Bits
                ((if I = 1
                  then 16#7FF8_0000_0000_0000#
                  else 16#7FF0_0000_0000_0000#));
         begin
            for J in 1 .. 6 loop
               P := (others => <>);
               case J is
                  when 1      =>
                     P.Scale := V;

                  when 2      =>
                     P.Sigma_Scale := V;

                  when 3      =>
                     P.Quantization := V;

                  when 4      =>
                     P.Angle_Degrees := V;

                  when 5      =>
                     P.Density := V;

                  when others =>
                     P.Log_Epsilon := V;
               end case;
               Expect_Error (Attempt'Access);
            end loop;
         end;
      end loop;
   end Nonfinite_Test;

   procedure Contract_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      Image : OpenCV.Core.Mat;
      procedure Attempt is
         Lines : constant IP.LSD_Segment_Array :=
           IP.Detect_Line_Segments (Image);
      begin
         Assert (Lines'Length = 0, "invalid source");
      end Attempt;
   begin
      Expect_Error (Attempt'Access);
      Image := OpenCV.Core.Create (10, 10, (OpenCV.Core.Float32, 1));
      Expect_Error (Attempt'Access);
      Image := Blank (3);
      Expect_Error (Attempt'Access);
      Image :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(4, 4, 4), (OpenCV.Core.UInt8, 1));
      Expect_Error (Attempt'Access);
   end Contract_Test;

   procedure Region_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      Parent : OpenCV.Core.Mat := Pattern (4);
      ROI    : OpenCV.Core.Mat := Parent.Region ((30, 30, 60, 60));
      procedure Attempt is
         Lines : constant IP.LSD_Segment_Array :=
           IP.Detect_Line_Segments (ROI);
      begin
         Assert (Lines'Length = 0, "outside ROI rectangle ignored");
      end Attempt;
   begin
      Assert (not ROI.Is_Continuous, "noncontiguous fixture");
      if not Available then
         Expect_Error (Attempt'Access);
         return;
      end if;
      Attempt;
      IP.Draw_Line (ROI, (5, 25), (55, 25), (255.0, 0.0, 0.0, 0.0), 2);
      declare
         Lines : constant IP.LSD_Segment_Array :=
           IP.Detect_Line_Segments (ROI);
         Copy  : constant IP.LSD_Segment_Array :=
           IP.Detect_Line_Segments (ROI.Clone);
      begin
         Assert
           (Lines = Copy and then Lines'Length > 0,
            "logical ROI matches clone");
         OpenCV.Core.Set_To (Parent, (others => 0.0));
         ROI := Blank;
         Assert (ROI.Rows = 128, "replacement source valid");
         Assert (Lines = Copy, "Ada results independent of Mats and detector");
      end;
   end Region_Test;

   procedure Render_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      Image : constant OpenCV.Core.Mat := Blank;
      Alias : constant OpenCV.Core.Mat := Image;
      procedure Attempt is
         Output : constant OpenCV.Core.Mat :=
           IP.Render_Line_Segments (Image, Horizontal);
      begin
         Assert
           (Output.Channels = 3 and then Output.Depth = OpenCV.Core.UInt8,
            "fresh C3 render");
         Assert
           (OpenCV.Core.UInt8_Vec3_Access.Get (Output, 30, 20) (0) = 0
            and then OpenCV.Core.UInt8_Vec3_Access.Get (Output, 30, 20) (2)
                     = 255,
            "native red BGR");
         Assert
           (OpenCV.Core.UInt8_Access.Get (Alias, 30, 20) = 0,
            "alias preserved");
      end Attempt;
   begin
      if Available then
         Attempt;
         declare
            Output : OpenCV.Core.Mat := IP.Render_Line_Segments (Image, Empty);
         begin
            Assert
              (Output.Rows = 128 and then Output.Channels = 3, "empty render");
            OpenCV.Core.Set_To (Output, (others => 255.0));
            Assert
              (OpenCV.Core.UInt8_Access.Get (Image, 0, 0) = 0,
               "fresh storage");
            Output :=
              IP.Render_Line_Segments (Blank (3), Horizontal & Vertical);
            Assert
              (OpenCV.Core.UInt8_Vec3_Access.Get (Output, 50, 50) (2) = 255,
               "multiple native segments");
         end;
      else
         Expect_Error (Attempt'Access);
      end if;
   end Render_Test;

   procedure Endpoint_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      Lines : IP.LSD_Segment_Array := Horizontal;
      function From_Bits is new
        Ada.Unchecked_Conversion
          (Interfaces.Unsigned_32,
           OpenCV.Float32_Value);
      procedure Attempt is
         Image : constant OpenCV.Core.Mat :=
           IP.Render_Line_Segments (Blank, Lines);
      begin
         Assert (Image.Channels = 3, "unsafe render");
      end Attempt;
   begin
      Lines (3).Start_Point.X := OpenCV.Float32_Value'Last;
      Expect_Error (Attempt'Access);
      declare
         pragma Suppress (Range_Check);
      begin
         Lines (3).Start_Point.X := From_Bits (16#7FC0_0000#);
         Expect_Error (Attempt'Access);
         Lines (3).Start_Point.X := From_Bits (16#7F80_0000#);
         Expect_Error (Attempt'Access);
      end;
   end Endpoint_Test;

   procedure Comparison_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      Count : Natural := 42;
      Image : OpenCV.Core.Mat := Blank;
      procedure Attempt is
      begin
         IP.Compare_Line_Segments
           ((128, 128), Horizontal, Vertical, Count, Image);
      end Attempt;
   begin
      if not Available then
         Expect_Error (Attempt'Access);
         Assert
           (Count = 42 and then Image.Channels = 1, "unsupported atomicity");
         return;
      end if;
      Assert
        (IP.Compare_Line_Segments ((128, 128), Empty, Empty) = 0,
         "empty sets");
      Assert
        (IP.Compare_Line_Segments ((128, 128), Horizontal, Horizontal) = 0,
         "equal sets");
      Assert
        (IP.Compare_Line_Segments ((128, 128), Horizontal, Empty) > 0,
         "one empty set");
      Attempt;
      Assert
        (Count > 0
         and then Count
                  = IP.Compare_Line_Segments
                      ((128, 128), Horizontal, Vertical),
         "native mismatch reproducible");
      Assert
        (Image.Rows = 128
         and then Image.Columns = 128
         and then Image.Channels = 3
         and then Image.Depth = OpenCV.Core.UInt8,
         "comparison geometry and depth");
      Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Image, 30, 20) (0) = 255,
         "first blue");
      Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Image, 50, 50) (2) = 255,
         "second red");
      IP.Compare_Line_Segments ((128, 128), Empty, Empty, Count, Image);
      Assert
        (Count = 0
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Image, 30, 20) (0) = 0,
         "black empty visualization");
   end Comparison_Test;

   procedure Canvas_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      Size  : OpenCV.Size := (0, 1);
      Count : Natural := 99;
      Image : OpenCV.Core.Mat := Blank;
      procedure Attempt is
      begin
         IP.Compare_Line_Segments (Size, Empty, Empty, Count, Image);
      end Attempt;
   begin
      Expect_Error (Attempt'Access);
      Size := (OpenCV.Size_Coordinate'Last, OpenCV.Size_Coordinate'Last);
      Expect_Error (Attempt'Access);
      Assert
        (Count = 99 and then Image.Channels = 1,
         "rejection preserves outputs");
   end Canvas_Test;

   procedure Raw_Test (F : in out Fixture) is
      pragma Unreferenced (F);
      Count  : aliased Interfaces.Integer_32 := 23;
      Handle : constant C.LSD_Handle := C.Null_LSD_Handle;
   begin
      Assert
        (C.LSD_Count (Handle, Count'Access) /= C.Success and then Count = 0,
         "null count handle initialized");
      Assert (C.LSD_Copy (Handle, null, -1) /= C.Success, "negative capacity");
      Assert
        (C.LSD_Compare_Only (128, 128, null, 1, null, 0, Count'Access)
         /= C.Success,
         "null nonempty buffer");
      C.LSD_Destroy (Handle);
   end Raw_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("LSD blank/default/unsupported", Blank_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD horizontal", Horizontal_Test'Access));
      Result.Add_Test (Caller.Create ("LSD vertical", Vertical_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD diagonal/subpixel", Diagonal_Test'Access));
      Result.Add_Test (Caller.Create ("LSD rectangle", Rectangle_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD separated structures", Separated_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD no refinement", No_Refinement_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD advanced NFA", Advanced_Test'Access));
      Result.Add_Test
        (Caller.Create
           ("LSD parameter ranges/recovery", Parameters_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD NaN/infinity", Nonfinite_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD source contract", Contract_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD isolated ROI/ownership", Region_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD native rendering", Render_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD endpoint safety", Endpoint_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD native comparison", Comparison_Test'Access));
      Result.Add_Test
        (Caller.Create ("LSD canvas rejection atomicity", Canvas_Test'Access));
      Result.Add_Test (Caller.Create ("LSD raw ABI errors", Raw_Test'Access));
      return Result'Access;
   end Suite;
end Line_Segment_Detector_Tests;
