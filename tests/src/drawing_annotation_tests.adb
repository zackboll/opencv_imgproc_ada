with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Drawing_Annotation_Tests is
   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.UInt8_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Size_Coordinate;
   use type OpenCV.Core.UInt8_Vec3.Vector;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;
   White  : constant OpenCV.Scalar := (Component_0 => 255.0, others => 0.0);

   function Blank
     (Rows : Positive := 100; Columns : Positive := 160) return OpenCV.Core.Mat
   is
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Columns, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      return Image;
   end Blank;

   function Pixel
     (Image : OpenCV.Core.Mat; X, Y : Natural) return OpenCV.UInt8_Value
   is (OpenCV.Core.UInt8_Access.Get (Image, Integer (Y), Integer (X)));

   procedure Expect_Error
     (Attempt : not null access procedure; Message : String)
   is
      Failed : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Failed := True;
      end;
      AUnit.Assertions.Assert (Failed, Message);
   end Expect_Error;

   procedure Arrow_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Short : OpenCV.Core.Mat := Blank;
      Long  : OpenCV.Core.Mat := Blank;
   begin
      IP.Draw_Arrow (Short, (20, 50), (120, 50), White);
      IP.Draw_Arrow (Long, (20, 50), (120, 50), White, Tip_Length => 0.5);
      AUnit.Assertions.Assert
        (Pixel (Short, 20, 50) = 255
         and then Pixel (Short, 120, 50) = 255
         and then Pixel (Short, 113, 43) = 255,
         "arrow shaft and head must be rendered");
      AUnit.Assertions.Assert
        (Pixel (Short, 85, 15) = 0 and then Pixel (Long, 85, 15) = 255,
         "tip length must change the arrowhead");
   end Arrow_Geometry;

   procedure Arrow_Errors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (8, 8);
      procedure Zero_Tip is
      begin
         IP.Draw_Arrow (Image, (0, 0), (3, 3), White, Tip_Length => 0.0);
      end Zero_Tip;
      procedure Large_Tip is
      begin
         IP.Draw_Arrow (Image, (0, 0), (3, 3), White, Tip_Length => 1.1);
      end Large_Tip;
      procedure Coincident is
      begin
         IP.Draw_Arrow (Image, (2, 2), (2, 2), White);
      end Coincident;
      procedure Overflow is
      begin
         IP.Draw_Arrow
           (Image,
            (OpenCV.Point_Coordinate'First, 1),
            (OpenCV.Point_Coordinate'Last, 1),
            White);
      end Overflow;
   begin
      Expect_Error (Zero_Tip'Access, "zero tip");
      Expect_Error (Large_Tip'Access, "oversized tip");
      Expect_Error (Coincident'Access, "coincident endpoints");
      Expect_Error (Overflow'Access, "integer endpoint delta overflow");
   end Arrow_Errors;

   procedure Markers (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (21, 21);
   begin
      for Kind in IP.Drawing_Marker_Kind loop
         OpenCV.Core.Set_To (Image, (others => 0.0));
         IP.Draw_Marker (Image, (10, 10), White, Kind, Marker_Size => 8);
         AUnit.Assertions.Assert
           (Pixel (Image, 10, 6)
            = (if Kind
                  in IP.Cross_Marker
                   | IP.Star_Marker
                   | IP.Diamond_Marker
                   | IP.Square_Marker
                   | IP.Triangle_Up_Marker
                   | IP.Triangle_Down_Marker
               then 255
               else 0),
            "marker top vertex must match selector " & Kind'Image);
         AUnit.Assertions.Assert
           (Pixel (Image, 6, 6)
            = (if Kind
                  in IP.Tilted_Cross_Marker
                   | IP.Star_Marker
                   | IP.Square_Marker
                   | IP.Triangle_Down_Marker
               then 255
               else 0),
            "marker top-left corner must match selector " & Kind'Image);
      end loop;
   end Markers;

   procedure Marker_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (25, 25);
      procedure Overflow is
      begin
         IP.Draw_Marker
           (Image, (OpenCV.Point_Coordinate'Last, 5), White, Marker_Size => 4);
      end Overflow;
   begin
      IP.Draw_Marker (Image, (12, 12), White, Marker_Size => 4);
      AUnit.Assertions.Assert
        (Pixel (Image, 10, 12) = 255 and then Pixel (Image, 8, 12) = 0,
         "marker size");
      OpenCV.Core.Set_To (Image, (others => 0.0));
      IP.Draw_Marker
        (Image, (12, 12), White, Marker_Size => 4, Thickness => 3);
      AUnit.Assertions.Assert
        (Pixel (Image, 11, 11) = 255, "marker thickness");
      Expect_Error (Overflow'Access, "marker coordinate overflow");
   end Marker_Geometry;

   procedure Text_Rendering (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image   : OpenCV.Core.Mat := Blank;
      Changed : Natural := 0;
   begin
      IP.Draw_Text (Image, "Hi", (10, 50), White);
      for Y in 0 .. 49 loop
         for X in 10 .. 60 loop
            if Pixel (Image, X, Y) /= 0 then
               Changed := Changed + 1;
            end if;
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (Changed > 10 and then Pixel (Image, 0, 0) = 0,
         "text draws localized glyphs");
      for Font in IP.Text_Font loop
         OpenCV.Core.Set_To (Image, (others => 0.0));
         IP.Draw_Text (Image, "A", (10, 50), White, Font => Font);
         AUnit.Assertions.Assert
           (IP.Measure_Text ("A", Font).Size.Width > 0,
            "Hershey selector must route " & Font'Image);
      end loop;
      AUnit.Assertions.Assert
        (IP.Measure_Text ("A", Italic => True).Size.Width > 0,
         "italic flag routes");
   end Text_Rendering;

   procedure Text_Orientation_And_Empty (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Normal       : OpenCV.Core.Mat := Blank;
      Inverted     : OpenCV.Core.Mat := Blank;
      Above, Below : Natural := 0;
      Empty        : constant IP.Text_Metrics := IP.Measure_Text ("");
   begin
      IP.Draw_Text (Normal, "H", (10, 50), White);
      IP.Draw_Text
        (Inverted, "H", (10, 50), White, Bottom_Left_Origin => True);
      IP.Draw_Text (Normal, "", (10, 50), White);
      for Y in 25 .. 49 loop
         for X in 10 .. 35 loop
            if Pixel (Normal, X, Y) /= 0 then
               Above := Above + 1;
            end if;
         end loop;
      end loop;
      for Y in 51 .. 75 loop
         for X in 10 .. 35 loop
            if Pixel (Inverted, X, Y) /= 0 then
               Below := Below + 1;
            end if;
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (Above > 0 and then Below > 0, "bottom-left origin reverses glyphs");
      AUnit.Assertions.Assert
        (Empty.Size.Width = 1
         and then Empty.Size.Height > 0
         and then Empty.Baseline > 0,
         "empty native metrics");
   end Text_Orientation_And_Empty;

   procedure Metrics_And_Height (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Metrics   : constant IP.Text_Metrics := IP.Measure_Text ("ABC");
      Scale     : constant OpenCV.Float64_Value :=
        IP.Font_Scale_For_Height (30);
      At_Height : constant IP.Text_Metrics :=
        IP.Measure_Text ("ABC", Font_Scale => Scale);
      procedure Too_Small is
         S : OpenCV.Float64_Value;
      begin
         S := IP.Font_Scale_For_Height (1, Thickness => 4);
         AUnit.Assertions.Assert (S > 0.0, "unreachable");
      end Too_Small;
   begin
      AUnit.Assertions.Assert
        (Metrics.Size.Width > 20
         and then Metrics.Size.Height > 15
         and then Metrics.Baseline > 0,
         "native bounding metrics and baseline");
      AUnit.Assertions.Assert
        (abs (Integer (At_Height.Size.Height) - 30) <= 1,
         "requested height rounds to native text height");
      Expect_Error (Too_Small'Access, "unusable requested height");
   end Metrics_And_Height;

   procedure Aliases_And_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : constant OpenCV.Core.Mat := Blank (30, 30);
      Alias : constant OpenCV.Core.Mat := Image;
      ROI   : OpenCV.Core.Mat :=
        OpenCV.Core.Region
          (Image, (X => 5, Y => 5, Width => 10, Height => 10));
   begin
      IP.Draw_Marker (ROI, (4, 4), White, Marker_Size => 4);
      AUnit.Assertions.Assert
        (Pixel (Alias, 9, 7) = 255 and then Pixel (Image, 4, 9) = 0,
         "ROI mutation and alias");
   end Aliases_And_Region;

   procedure Raw_Arguments (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Width, Height, Baseline : aliased Interfaces.Integer_32 := 0;
      Scale                   : aliased Interfaces.C.double := 0.0;
      use type Interfaces.C.double;
      Zero                    : constant C_API.Status := 0;
   begin
      AUnit.Assertions.Assert
        (C_API.Measure_Text
           (System.Null_Address,
            -1,
            0,
            1.0,
            0,
            1,
            Width'Access,
            Height'Access,
            Baseline'Access)
         /= Zero,
         "negative raw text length");
      AUnit.Assertions.Assert
        (C_API.Measure_Text
           (System.Null_Address,
            1,
            0,
            1.0,
            0,
            1,
            Width'Access,
            Height'Access,
            Baseline'Access)
         /= Zero,
         "null positive text span");
      AUnit.Assertions.Assert
        (C_API.Measure_Text
           (System.Null_Address,
            0,
            8,
            1.0,
            0,
            1,
            Width'Access,
            Height'Access,
            Baseline'Access)
         /= Zero,
         "invalid font");
      AUnit.Assertions.Assert
        (C_API.Measure_Text
           (System.Null_Address,
            0,
            0,
            1.0,
            2,
            1,
            Width'Access,
            Height'Access,
            Baseline'Access)
         /= Zero,
         "invalid italic boolean");
      AUnit.Assertions.Assert
        (C_API.Measure_Text
           (System.Null_Address,
            0,
            0,
            1.0,
            0,
            1,
            null,
            Height'Access,
            Baseline'Access)
         /= Zero,
         "null metric output");
      AUnit.Assertions.Assert
        (C_API.Font_Scale_For_Height (20, 0, 0, 1, null) /= Zero,
         "null scale output");
      AUnit.Assertions.Assert
        (C_API.Font_Scale_For_Height (20, 0, 2, 1, Scale'Access) /= Zero,
         "invalid scale italic");
      AUnit.Assertions.Assert
        (C_API.Font_Scale_For_Height (20, 0, 0, 1, Scale'Access) = Zero
         and then Scale > 0.0,
         "successful call clears prior ABI error");
   end Raw_Arguments;

   procedure Raw_Drawing (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (12, 12);
      Text  : aliased constant String := "A";
      procedure Check (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
         Zero : constant C_API.Status := 0;
      begin
         AUnit.Assertions.Assert
           (C_API.Draw_Marker (Handle, 5, 5, 255.0, 0.0, 0.0, 0.0, 7, 4, 1, 8)
            /= Zero,
            "raw marker selector");
         AUnit.Assertions.Assert
           (C_API.Draw_Marker
              (Handle,
               Interfaces.Integer_32'Last,
               5,
               255.0,
               0.0,
               0.0,
               0.0,
               0,
               4,
               1,
               8)
            /= Zero,
            "raw marker overflow");
         AUnit.Assertions.Assert
           (C_API.Draw_Arrow
              (Handle,
               Interfaces.Integer_32'First,
               0,
               Interfaces.Integer_32'Last,
               0,
               255.0,
               0.0,
               0.0,
               0.0,
               0.1,
               1,
               8)
            /= Zero,
            "raw arrow subtraction overflow");
         AUnit.Assertions.Assert
           (C_API.Draw_Arrow
              (Handle, 1, 1, 5, 5, 255.0, 0.0, 0.0, 0.0, 0.5, 1, 99)
            /= Zero,
            "raw line selector");
         AUnit.Assertions.Assert
           (C_API.Draw_Text
              (Handle,
               Text'Address,
               1,
               1,
               8,
               255.0,
               0.0,
               0.0,
               0.0,
               0,
               1.0,
               0,
               1,
               8,
               2)
            /= Zero,
            "raw bottom-left boolean");
         AUnit.Assertions.Assert
           (C_API.Draw_Text
              (Handle,
               Text'Address,
               1,
               1,
               8,
               255.0,
               0.0,
               0.0,
               0.0,
               0,
               1.0E12,
               0,
               1,
               8,
               0)
            /= Zero,
            "raw scale overflow");
         AUnit.Assertions.Assert
           (C_API.Draw_Text
              (Handle,
               Text'Address,
               Interfaces.Integer_32'Last,
               1,
               8,
               255.0,
               0.0,
               0.0,
               0.0,
               0,
               1.0,
               0,
               1,
               8,
               0)
            /= Zero,
            "raw text length arithmetic");
         AUnit.Assertions.Assert
           (C_API.Draw_Marker (Handle, 5, 5, 255.0, 0.0, 0.0, 0.0, 0, 4, 1, 1)
            = Zero,
            "successful raw draw after errors");
      end Check;
   begin
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Check'Access);
      AUnit.Assertions.Assert
        (Pixel (Image, 3, 5) = 255, "successful raw marker must mutate image");
   end Raw_Drawing;

   procedure Public_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (10, 10, (OpenCV.Core.UInt16, 1));
      Empty : OpenCV.Core.Mat;
      procedure AA is
      begin
         IP.Draw_Text
           (Image, "A", (1, 8), White, Line_Style => IP.Anti_Aliased_Line);
      end AA;
      procedure Empty_Image is
      begin
         IP.Draw_Marker (Empty, (1, 1), White);
      end Empty_Image;
      procedure Zero_Scale is
      begin
         IP.Draw_Text (Image, "A", (1, 8), White, Font_Scale => 0.0);
      end Zero_Scale;
   begin
      Expect_Error (AA'Access, "AA only on UInt8");
      Expect_Error (Empty_Image'Access, "nonempty drawing image");
      Expect_Error (Zero_Scale'Access, "positive font scale");
   end Public_Validation;

   procedure Text_Bytes_And_Channels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (80, 120, (OpenCV.Core.UInt8, 3));
      Text    : constant String (7 .. 9) := ('A', ASCII.NUL, 'B');
      C       : constant OpenCV.Scalar :=
        (Component_0 => 11.0,
         Component_1 => 22.0,
         Component_2 => 33.0,
         Component_3 => 0.0);
      Changed : Boolean := False;
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      IP.Draw_Text (Image, Text, (10, 50), C);
      for Y in 20 .. 52 loop
         for X in 10 .. 100 loop
            if OpenCV.Core.UInt8_Vec3_Access.Get (Image, Y, X) = (11, 22, 33)
            then
               Changed := True;
            end if;
         end loop;
      end loop;
      AUnit.Assertions.Assert (Changed, "C3 text uses scalar channel order");
      AUnit.Assertions.Assert
        (IP.Measure_Text (Text).Size.Width > IP.Measure_Text ("A").Size.Width,
         "embedded NUL and non-1 lower bound are passed as bytes");
   end Text_Bytes_And_Channels;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Arrow shaft and tip geometry", Arrow_Geometry'Access));
      Result.Add_Test
        (Caller.Create ("Arrow invalid geometry", Arrow_Errors'Access));
      Result.Add_Test (Caller.Create ("Seven marker shapes", Markers'Access));
      Result.Add_Test
        (Caller.Create
           ("Marker size thickness overflow", Marker_Geometry'Access));
      Result.Add_Test
        (Caller.Create
           ("Hershey text and eight fonts", Text_Rendering'Access));
      Result.Add_Test
        (Caller.Create
           ("Text orientation and empty", Text_Orientation_And_Empty'Access));
      Result.Add_Test
        (Caller.Create
           ("Metrics and requested height", Metrics_And_Height'Access));
      Result.Add_Test
        (Caller.Create
           ("Annotation alias and Region", Aliases_And_Region'Access));
      Result.Add_Test
        (Caller.Create
           ("Annotation text bytes and C3", Text_Bytes_And_Channels'Access));
      Result.Add_Test
        (Caller.Create ("Annotation raw ABI", Raw_Arguments'Access));
      Result.Add_Test
        (Caller.Create ("Annotation raw drawing safety", Raw_Drawing'Access));
      Result.Add_Test
        (Caller.Create
           ("Annotation public validation", Public_Validation'Access));
      return Result'Access;
   end Suite;
end Drawing_Annotation_Tests;
