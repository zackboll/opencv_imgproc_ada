with Ada.Numerics;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Hough_Detection_Tests is

   --  Negative-path tests deliberately hold NaN and infinity in Float64
   --  variables so they can be passed to the public API.
   pragma Suppress (Validity_Check);

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.C_float;
   use type Interfaces.C.double;
   use type OpenCV.Float64_Value;

   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;
   use type C_API.Hough_Lines_Handle;
   use type C_API.Hough_Segments_Handle;
   use type C_API.Hough_Circles_Handle;
   use type C_API.Hough_Line_Record;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Pi       : constant := Ada.Numerics.Pi;
   Degree   : constant := Pi / 180.0;
   White    : constant OpenCV.Scalar := (Component_0 => 255.0, others => 0.0);
   NaN_Bits : constant Interfaces.Unsigned_64 := 16#7FF8_0000_0000_0000#;
   Inf_Bits : constant Interfaces.Unsigned_64 := 16#7FF0_0000_0000_0000#;

   --  A non-static zero so out-of-range subtype conversions are checked at
   --  run time instead of being rejected by the compiler.
   function Zero_Value return Integer
   with No_Inline;

   function Zero_Value return Integer is
   begin
      return 0;
   end Zero_Value;

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, OpenCV.Float64_Value);

   function Non_Finite
     (Bits : Interfaces.Unsigned_64) return OpenCV.Float64_Value
   is
      pragma Suppress (Range_Check);
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float64 (Bits);
   end Non_Finite;

   function Raw_Hough_Lines
     (Source    : System.Address;
      Rho       : Interfaces.C.double;
      Theta     : Interfaces.C.double;
      Threshold : Interfaces.Integer_32;
      Min_Theta : Interfaces.C.double;
      Max_Theta : Interfaces.C.double;
      Result    : access C_API.Hough_Lines_Handle) return C_API.Status
   with Import, Convention => C, External_Name => "opencv_imgproc_hough_lines";

   procedure Assert_Raises
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
   end Assert_Raises;

   procedure Assert_Constraint
     (Attempt : not null access procedure; Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when Constraint_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, Message);
   end Assert_Constraint;

   procedure Assert_Invalid (Status : C_API.Status; Fragment, Message : String)
   is
   begin
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment)
                  /= 0,
         Message & " (diagnostic: " & C_API.Last_Error_Message & ")");
   end Assert_Invalid;

   function Blank (Rows, Columns : Natural) return OpenCV.Core.Mat is
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Columns, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      return Image;
   end Blank;

   function Same_Pixels (Left, Right : OpenCV.Core.Mat) return Boolean is
   begin
      if Left.Rows /= Right.Rows or else Left.Columns /= Right.Columns then
         return False;
      end if;
      for Row in 0 .. Left.Rows - 1 loop
         for Column in 0 .. Left.Columns - 1 loop
            if OpenCV.Core.UInt8_Access.Get (Left, Row, Column)
              /= OpenCV.Core.UInt8_Access.Get (Right, Row, Column)
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Same_Pixels;

   function Near
     (Actual : OpenCV.Float32_Value; Expected, Tolerance : Float)
      return Boolean
   is (abs (Float (Actual) - Expected) <= Tolerance);

   function Has_Line
     (Lines              : IP.Hough_Line_Array;
      Rho, Theta         : Float;
      Rho_Tol, Theta_Tol : Float) return Boolean is
   begin
      for Line of Lines loop
         if Near (Line.Rho, Rho, Rho_Tol)
           and then Near (Line.Angle_Radians, Theta, Theta_Tol)
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Line;

   function Close
     (Actual, Expected : OpenCV.Point; Tolerance : Natural) return Boolean
   is (abs (Integer (Actual.X) - Integer (Expected.X)) <= Tolerance
       and then abs (Integer (Actual.Y) - Integer (Expected.Y)) <= Tolerance);

   --  Endpoint order is not part of the contract: (A, B) matches (B, A).
   function Has_Segment
     (Segments  : IP.Hough_Line_Segment_Array;
      A, B      : OpenCV.Point;
      Tolerance : Natural) return Boolean is
   begin
      for Segment of Segments loop
         if (Close (Segment.Start_Point, A, Tolerance)
             and then Close (Segment.End_Point, B, Tolerance))
           or else (Close (Segment.Start_Point, B, Tolerance)
                    and then Close (Segment.End_Point, A, Tolerance))
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Segment;

   function Has_Circle
     (Circles                : IP.Hough_Circle_Array;
      X, Y, Radius           : Float;
      Center_Tol, Radius_Tol : Float) return Boolean is
   begin
      for Circle of Circles loop
         if Near (Circle.Center.X, X, Center_Tol)
           and then Near (Circle.Center.Y, Y, Center_Tol)
           and then Near (Circle.Radius, Radius, Radius_Tol)
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Circle;

   function Image (Value : OpenCV.Float32_Value) return String
   is (Integer'Image (Integer (Float (Value) * 10.0)) & "/10");

   --  Lists detected circles in assertion diagnostics.
   function Describe (Circles : IP.Hough_Circle_Array) return String is
   begin
      if Circles'Length = 0 then
         return " found none";
      end if;
      return
        " found ("
        & Image (Circles (Circles'First).Center.X)
        & ","
        & Image (Circles (Circles'First).Center.Y)
        & " r"
        & Image (Circles (Circles'First).Radius)
        & ")"
        & (if Circles'Length > 1
           then Describe (Circles (Circles'First + 1 .. Circles'Last))
           else "");
   end Describe;

   --  Lists detected lines in assertion diagnostics.
   function Describe (Lines : IP.Hough_Line_Array) return String is
   begin
      if Lines'Length = 0 then
         return " found none";
      end if;
      return
        " ("
        & Image (Lines (Lines'First).Rho)
        & ","
        & Image (Lines (Lines'First).Angle_Radians)
        & ")"
        & (if Lines'Length > 1
           then Describe (Lines (Lines'First + 1 .. Lines'Last))
           else "");
   end Describe;

   --  A blurred grayscale fixture, Rows x Columns, with one filled disc. A
   --  filled disc has a single intensity edge at Radius; an outlined ring
   --  would have inner and outer edges that bias the radius estimate.
   function Ring
     (Rows, Columns : Natural; Center : OpenCV.Point; Radius : Positive)
      return OpenCV.Core.Mat
   is
      Image   : OpenCV.Core.Mat := Blank (Rows, Columns);
      Blurred : OpenCV.Core.Mat;
   begin
      IP.Fill_Circle (Image, Center, Radius, White);
      IP.Gaussian_Blur
        (Image, Blurred, (Width => 5, Height => 5), Sigma => 1.5);
      return Blurred;
   end Ring;

   --  Standard-line tolerances. A result is an accumulator bin, so it may
   --  differ from the exact geometry by one bin in each axis. OpenCV 5.0
   --  also reconstructs rho with integer (numrho - 1) / 2 where 4.x uses
   --  (numrho - 1) * 0.5, which can move rho by half a distance bin.
   Rho_Tolerance   : constant Float := 1.5;
   Theta_Tolerance : constant Float := 1.5 * Degree;

   function Lines_Of
     (Image     : OpenCV.Core.Mat;
      Threshold : IP.Hough_Vote_Threshold;
      Minimum   : OpenCV.Float64_Value := 0.0;
      Maximum   : OpenCV.Float64_Value := Ada.Numerics.Pi)
      return IP.Hough_Line_Array
   is (IP.Find_Hough_Lines (Image, 1.0, Degree, Threshold, Minimum, Maximum));

   --  Probabilistic segments walk pixel by pixel, so endpoints are compared
   --  with a two-pixel tolerance rather than exactly.
   Endpoint_Tolerance : constant := 2;

   function Segments_Of
     (Image     : OpenCV.Core.Mat;
      Threshold : IP.Hough_Vote_Threshold;
      Length    : OpenCV.Size_Coordinate := 0;
      Gap       : OpenCV.Size_Coordinate := 0)
      return IP.Hough_Line_Segment_Array
   is (IP.Find_Hough_Line_Segments
         (Image, 1.0, Degree, Threshold, Length, Gap));

   procedure Lines_Horizontal (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (60, 80);
   begin
      IP.Draw_Line (Image, (X => 5, Y => 20), (X => 74, Y => 20), White);
      declare
         Lines : constant IP.Hough_Line_Array := Lines_Of (Image, 50);
      begin
         AUnit.Assertions.Assert
           (Lines'Length > 0 and then Lines'First = 0,
            "a nonempty line result must be zero-based");
         AUnit.Assertions.Assert
           (Has_Line (Lines, 20.0, Pi / 2.0, Rho_Tolerance, Theta_Tolerance),
            "a horizontal line at row 20 must give rho ~ 20, theta ~ Pi/2");
      end;
   end Lines_Horizontal;

   procedure Lines_Vertical (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (60, 80);
   begin
      IP.Draw_Line (Image, (X => 30, Y => 5), (X => 30, Y => 54), White);
      declare
         Lines : constant IP.Hough_Line_Array := Lines_Of (Image, 40);
      begin
         --  (rho, 0) and (-rho, Pi) describe the same vertical line.
         AUnit.Assertions.Assert
           (Has_Line (Lines, 30.0, 0.0, Rho_Tolerance, Theta_Tolerance)
            or else Has_Line
                      (Lines, -30.0, Pi, Rho_Tolerance, Theta_Tolerance),
            "a vertical line at column 30 must give rho ~ 30, theta ~ 0");
      end;
   end Lines_Vertical;

   procedure Lines_Polar_Interpretation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (80, 80);
   begin
      --  x + y = 60: normal angle Pi/4, rho = 60 / sqrt 2.
      IP.Draw_Line (Image, (X => 0, Y => 60), (X => 60, Y => 0), White);
      declare
         Lines : constant IP.Hough_Line_Array := Lines_Of (Image, 45);
      begin
         AUnit.Assertions.Assert
           (Has_Line (Lines, 42.426, Pi / 4.0, Rho_Tolerance, Theta_Tolerance),
            "x + y = 60 must give rho ~ 42.43, theta ~ Pi/4");
      end;

      --  x - y = 20: normal angle 3*Pi/4 gives negative rho = -20 / sqrt 2.
      OpenCV.Core.Set_To (Image, (others => 0.0));
      IP.Draw_Line (Image, (X => 20, Y => 0), (X => 79, Y => 59), White);
      declare
         Lines : constant IP.Hough_Line_Array := Lines_Of (Image, 45);
      begin
         AUnit.Assertions.Assert
           (Has_Line
              (Lines, -14.142, 3.0 * Pi / 4.0, Rho_Tolerance, Theta_Tolerance),
            "x - y = 20 must give negative rho ~ -14.14, theta ~ 3*Pi/4");
      end;
   end Lines_Polar_Interpretation;

   procedure Lines_Restricted_Angles (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (60, 80);
   begin
      IP.Draw_Line (Image, (X => 5, Y => 20), (X => 74, Y => 20), White);
      IP.Draw_Line (Image, (X => 40, Y => 2), (X => 40, Y => 57), White);
      declare
         All_Lines  : constant IP.Hough_Line_Array := Lines_Of (Image, 45);
         Restricted : constant IP.Hough_Line_Array :=
           Lines_Of (Image, 45, Pi / 4.0, 3.0 * Pi / 4.0);
      begin
         AUnit.Assertions.Assert
           (Has_Line (All_Lines, 40.0, 0.0, Rho_Tolerance, Theta_Tolerance),
            "the full range must contain the vertical line");
         AUnit.Assertions.Assert
           (Has_Line
              (Restricted, 20.0, Pi / 2.0, Rho_Tolerance, Theta_Tolerance),
            "the restricted range must still contain the horizontal line");
         for Line of Restricted loop
            AUnit.Assertions.Assert
              (Float (Line.Angle_Radians) >= Pi / 4.0 - 0.001
               and then Float (Line.Angle_Radians) <= 3.0 * Pi / 4.0 + 0.001,
               "restricted results must lie within the requested angles");
         end loop;
      end;
   end Lines_Restricted_Angles;

   procedure Lines_Empty_And_Foreground (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (40, 40);
   begin
      declare
         Lines : constant IP.Hough_Line_Array := Lines_Of (Image, 10);
      begin
         AUnit.Assertions.Assert
           (Lines'Length = 0 and then Lines'First = 1 and then Lines'Last = 0,
            "an all-zero image must return the null range 1 .. 0");
      end;

      --  Any nonzero value is foreground, not only 255.
      IP.Draw_Line
        (Image,
         (X => 2, Y => 15),
         (X => 37, Y => 15),
         (Component_0 => 7.0, others => 0.0));
      declare
         Lines : constant IP.Hough_Line_Array := Lines_Of (Image, 30);
      begin
         AUnit.Assertions.Assert
           (Has_Line (Lines, 15.0, Pi / 2.0, Rho_Tolerance, Theta_Tolerance),
            "a line drawn with value 7 must be detected");
      end;
   end Lines_Empty_And_Foreground;

   --  Mirrors the README composition: drawn shape -> Canny -> Hough.
   procedure Lines_From_Canny_Edges (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Canvas : OpenCV.Core.Mat := Blank (100, 100);
      Edges  : OpenCV.Core.Mat;
   begin
      IP.Fill_Rectangle
        (Canvas, (X => 20, Y => 30, Width => 60, Height => 40), White);
      IP.Canny_Edges (Canvas, Edges, 50.0, 150.0);
      declare
         --  The 40-pixel vertical sides need a threshold below 40 because
         --  OpenCV keeps only bins with strictly more votes than it.
         Lines    : constant IP.Hough_Line_Array := Lines_Of (Edges, 30);
         Segments : constant IP.Hough_Line_Segment_Array :=
           Segments_Of (Edges, 30, 20, 3);
      begin
         --  Canny may place an edge on either side of an intensity step, so
         --  each side is accepted within two pixels of the drawn boundary.
         AUnit.Assertions.Assert
           (Has_Line (Lines, 30.5, Pi / 2.0, 2.0, Theta_Tolerance)
            and then Has_Line (Lines, 69.5, Pi / 2.0, 2.0, Theta_Tolerance)
            and then Has_Line (Lines, 20.5, 0.0, 2.0, Theta_Tolerance)
            and then Has_Line (Lines, 79.5, 0.0, 2.0, Theta_Tolerance),
            "all four rectangle sides must be found as polar lines;"
            & Describe (Lines));
         AUnit.Assertions.Assert
           (Has_Segment (Segments, (X => 20, Y => 30), (X => 79, Y => 30), 3)
            and then Has_Segment
                       (Segments, (X => 20, Y => 30), (X => 20, Y => 69), 3),
            "rectangle sides must be found as segments");
      end;
   end Lines_From_Canny_Edges;

   procedure Lines_Source_And_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : OpenCV.Core.Mat := Blank (50, 70);
   begin
      --  Parent row 15 lies inside the Region; parent row 5 lies outside.
      IP.Draw_Line (Parent, (X => 0, Y => 5), (X => 69, Y => 5), White);
      IP.Draw_Line (Parent, (X => 12, Y => 15), (X => 57, Y => 15), White);
      declare
         Before : constant OpenCV.Core.Mat := Parent.Clone;
         View   : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 10, Y => 10, Width => 50, Height => 30));
         Lines  : constant IP.Hough_Line_Array := Lines_Of (View, 30);
      begin
         AUnit.Assertions.Assert
           (not View.Is_Continuous,
            "the fixture Region must be a strided view");
         AUnit.Assertions.Assert
           (Has_Line (Lines, 5.0, Pi / 2.0, Rho_Tolerance, Theta_Tolerance),
            "Region coordinates must be relative to the Region origin");
         AUnit.Assertions.Assert
           (not Has_Line (Lines, -5.0, Pi / 2.0, 3.0, Theta_Tolerance),
            "pixels outside the Region must not contribute");
         AUnit.Assertions.Assert
           (Same_Pixels (Parent, Before),
            "Find_Hough_Lines must preserve Source");
      end;
   end Lines_Source_And_Region;

   procedure Lines_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image   : constant OpenCV.Core.Mat := Blank (8, 8);
      Empty   : OpenCV.Core.Mat;
      Three_D : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Wide    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt16, 1));
      Color   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 3));
      Rho     : OpenCV.Float64_Value := 1.0;
      Theta   : OpenCV.Float64_Value := Degree;
      Minimum : OpenCV.Float64_Value := 0.0;
      Maximum : OpenCV.Float64_Value := Pi;
      Source  : OpenCV.Core.Mat;
      Ignore  : Natural := 0;

      procedure Call is
      begin
         Ignore :=
           IP.Find_Hough_Lines
             (Source, Rho, Theta, 1, Minimum, Maximum)'Length;
      end Call;

      procedure Bad_Threshold is
      begin
         Ignore :=
           IP.Find_Hough_Lines
             (Image, 1.0, Degree, IP.Hough_Vote_Threshold (Zero_Value))'Length;
      end Bad_Threshold;

      procedure Expect (Message : String) is
      begin
         Assert_Raises (Call'Access, Message);
         Source := Image;
         Rho := 1.0;
         Theta := Degree;
         Minimum := 0.0;
         Maximum := Pi;
      end Expect;
   begin
      Source := Empty;
      Expect ("an empty source must be rejected");
      Source := Three_D;
      Expect ("a 3-D source must be rejected");
      Source := Wide;
      Expect ("a UInt16 source must be rejected");
      Source := Color;
      Expect ("a three-channel source must be rejected");
      Rho := 0.0;
      Expect ("a zero distance resolution must be rejected");
      Rho := -1.0;
      Expect ("a negative distance resolution must be rejected");
      Rho := Non_Finite (NaN_Bits);
      Expect ("a NaN distance resolution must be rejected");
      Theta := 0.0;
      Expect ("a zero angle resolution must be rejected");
      Theta := -Degree;
      Expect ("a negative angle resolution must be rejected");
      Theta := Non_Finite (Inf_Bits);
      Expect ("an infinite angle resolution must be rejected");
      Minimum := -0.1;
      Expect ("a negative minimum angle must be rejected");
      Maximum := Pi + 0.01;
      Expect ("a maximum angle above Pi must be rejected");
      Minimum := 1.0;
      Maximum := 1.0;
      Expect ("an empty angle range must be rejected");
      Minimum := 2.0;
      Maximum := 1.0;
      Expect ("a reversed angle range must be rejected");
      Minimum := Non_Finite (NaN_Bits);
      Expect ("a NaN minimum angle must be rejected");
      Assert_Constraint
        (Bad_Threshold'Access, "a zero vote threshold must be rejected");
   end Lines_Invalid_Inputs;

   procedure Segments_Horizontal_And_Vertical (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (60, 80);
   begin
      IP.Draw_Line (Image, (X => 10, Y => 20), (X => 69, Y => 20), White);
      declare
         Segments : constant IP.Hough_Line_Segment_Array :=
           Segments_Of (Image, 30, 20, 2);
      begin
         AUnit.Assertions.Assert
           (Segments'Length > 0 and then Segments'First = 0,
            "a nonempty segment result must be zero-based");
         AUnit.Assertions.Assert
           (Has_Segment
              (Segments,
               (X => 10, Y => 20),
               (X => 69, Y => 20),
               Endpoint_Tolerance),
            "the horizontal segment must span its drawn endpoints");
      end;

      OpenCV.Core.Set_To (Image, (others => 0.0));
      IP.Draw_Line (Image, (X => 35, Y => 5), (X => 35, Y => 54), White);
      AUnit.Assertions.Assert
        (Has_Segment
           (Segments_Of (Image, 30, 20, 2),
            (X => 35, Y => 5),
            (X => 35, Y => 54),
            Endpoint_Tolerance),
         "the vertical segment must span its drawn endpoints");
   end Segments_Horizontal_And_Vertical;

   procedure Segments_Diagonal_Order_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (60, 60);
   begin
      IP.Draw_Line (Image, (X => 50, Y => 50), (X => 8, Y => 8), White);
      declare
         Segments : constant IP.Hough_Line_Segment_Array :=
           Segments_Of (Image, 25, 20, 2);
      begin
         --  Has_Segment accepts either endpoint order, so asking for the
         --  reverse of the drawn order must succeed as well.
         AUnit.Assertions.Assert
           (Has_Segment
              (Segments,
               (X => 8, Y => 8),
               (X => 50, Y => 50),
               Endpoint_Tolerance)
            and then Has_Segment
                       (Segments,
                        (X => 50, Y => 50),
                        (X => 8, Y => 8),
                        Endpoint_Tolerance),
            "the diagonal segment must match in either endpoint order");
      end;
   end Segments_Diagonal_Order_Independent;

   procedure Segments_Length_And_Gap (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Blank (40, 100);
   begin
      --  A 21-pixel segment: kept at minimum length 15, dropped at 40.
      IP.Draw_Line (Image, (X => 10, Y => 10), (X => 30, Y => 10), White);
      AUnit.Assertions.Assert
        (Has_Segment
           (Segments_Of (Image, 10, 15),
            (X => 10, Y => 10),
            (X => 30, Y => 10),
            Endpoint_Tolerance),
         "a segment longer than the minimum length must be kept");
      AUnit.Assertions.Assert
        (Segments_Of (Image, 10, 40)'Length = 0,
         "a segment shorter than the minimum length must be dropped");

      --  Two collinear 30-pixel pieces separated by a 6-pixel gap.
      OpenCV.Core.Set_To (Image, (others => 0.0));
      IP.Draw_Line (Image, (X => 10, Y => 25), (X => 39, Y => 25), White);
      IP.Draw_Line (Image, (X => 46, Y => 25), (X => 75, Y => 25), White);
      AUnit.Assertions.Assert
        (Has_Segment
           (Segments_Of (Image, 20, 50, 10),
            (X => 10, Y => 25),
            (X => 75, Y => 25),
            Endpoint_Tolerance),
         "a gap within Maximum_Line_Gap must be bridged");
      declare
         Split : constant IP.Hough_Line_Segment_Array :=
           Segments_Of (Image, 20, 20, 2);
      begin
         AUnit.Assertions.Assert
           (not Has_Segment
                  (Split,
                   (X => 10, Y => 25),
                   (X => 75, Y => 25),
                   Endpoint_Tolerance)
            and then Has_Segment
                       (Split,
                        (X => 10, Y => 25),
                        (X => 39, Y => 25),
                        Endpoint_Tolerance),
            "a gap wider than Maximum_Line_Gap must split the segment");
      end;
   end Segments_Length_And_Gap;

   procedure Segments_Empty_Source_And_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : OpenCV.Core.Mat := Blank (50, 70);
   begin
      declare
         Segments : constant IP.Hough_Line_Segment_Array :=
           Segments_Of (Parent, 5);
      begin
         AUnit.Assertions.Assert
           (Segments'First = 1 and then Segments'Last = 0,
            "an all-zero image must return the null range 1 .. 0");
      end;

      IP.Draw_Line (Parent, (X => 12, Y => 25), (X => 57, Y => 25), White);
      declare
         Before   : constant OpenCV.Core.Mat := Parent.Clone;
         View     : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 10, Y => 10, Width => 50, Height => 30));
         Segments : constant IP.Hough_Line_Segment_Array :=
           Segments_Of (View, 20, 20, 2);
      begin
         AUnit.Assertions.Assert
           (not View.Is_Continuous,
            "the fixture Region must be a strided view");
         AUnit.Assertions.Assert
           (Has_Segment
              (Segments,
               (X => 2, Y => 15),
               (X => 47, Y => 15),
               Endpoint_Tolerance),
            "Region segments must use Region-relative coordinates");
         AUnit.Assertions.Assert
           (Same_Pixels (Parent, Before),
            "Find_Hough_Line_Segments must preserve Source");
      end;
   end Segments_Empty_Source_And_Region;

   procedure Segments_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : constant OpenCV.Core.Mat := Blank (8, 8);
      Empty  : OpenCV.Core.Mat;
      Float  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.Float32, 1));
      Two    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 2));
      Rho    : OpenCV.Float64_Value := 1.0;
      Theta  : OpenCV.Float64_Value := Degree;
      Source : OpenCV.Core.Mat;
      Ignore : Natural := 0;

      procedure Call is
      begin
         Ignore := IP.Find_Hough_Line_Segments (Source, Rho, Theta, 1)'Length;
      end Call;

      procedure Bad_Threshold is
      begin
         Ignore :=
           IP.Find_Hough_Line_Segments
             (Image, 1.0, Degree, IP.Hough_Vote_Threshold (Zero_Value))'Length;
      end Bad_Threshold;

      procedure Bad_Length is
      begin
         Ignore :=
           IP.Find_Hough_Line_Segments
             (Image,
              1.0,
              Degree,
              1,
              OpenCV.Size_Coordinate (Zero_Value - 1))'Length;
      end Bad_Length;

      procedure Expect (Message : String) is
      begin
         Assert_Raises (Call'Access, Message);
         Source := Image;
         Rho := 1.0;
         Theta := Degree;
      end Expect;
   begin
      Source := Empty;
      Expect ("an empty source must be rejected");
      Source := Float;
      Expect ("a Float32 source must be rejected");
      Source := Two;
      Expect ("a two-channel source must be rejected");
      Rho := 0.0;
      Expect ("a zero distance resolution must be rejected");
      Rho := Non_Finite (Inf_Bits);
      Expect ("an infinite distance resolution must be rejected");
      Theta := -1.0;
      Expect ("a negative angle resolution must be rejected");
      Theta := Non_Finite (NaN_Bits);
      Expect ("a NaN angle resolution must be rejected");
      Assert_Constraint
        (Bad_Threshold'Access, "a zero vote threshold must be rejected");
      Assert_Constraint
        (Bad_Length'Access, "a negative minimum length must be rejected");
   end Segments_Invalid_Inputs;

   --  Circle tolerances. With Accumulator_Scale 1.0 the center is quantized
   --  to an accumulator cell center ((x + 0.5) * dp), and the radius is a
   --  histogram estimate over the blurred disc edge in 0.1 * dp bins. Two
   --  pixels for the center and three for the radius accept that
   --  quantization while still rejecting any other plausible circle.
   Center_Tolerance : constant Float := 2.0;
   Radius_Tolerance : constant Float := 3.0;

   procedure Circles_Automatic_Radius (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : constant OpenCV.Core.Mat :=
        Ring (100, 100, (X => 50, Y => 50), 25);
   begin
      declare
         Circles : constant IP.Hough_Circle_Array :=
           IP.Find_Hough_Circles (Image, 1.0, 40.0, 100, 20, 10);
      begin
         AUnit.Assertions.Assert
           (Circles'Length > 0 and then Circles'First = 0,
            "a nonempty circle result must be zero-based;"
            & Describe (Circles));
         AUnit.Assertions.Assert
           (Has_Circle
              (Circles, 50.0, 50.0, 25.0, Center_Tolerance, Radius_Tolerance),
            "the automatic-radius overload must find the drawn circle;"
            & Describe (Circles));
      end;
   end Circles_Automatic_Radius;

   procedure Circles_Explicit_Radius (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : constant OpenCV.Core.Mat :=
        Ring (100, 100, (X => 50, Y => 50), 25);
   begin
      AUnit.Assertions.Assert
        (Has_Circle
           (IP.Find_Hough_Circles
              (Image,
               1.0,
               40.0,
               100,
               20,
               Minimum_Radius => 15,
               Maximum_Radius => 35),
            50.0,
            50.0,
            25.0,
            Center_Tolerance,
            Radius_Tolerance),
         "an explicit range containing the radius must find the circle");
      AUnit.Assertions.Assert
        (not Has_Circle
               (IP.Find_Hough_Circles
                  (Image,
                   1.0,
                   40.0,
                   100,
                   20,
                   Minimum_Radius => 5,
                   Maximum_Radius => 12),
                50.0,
                50.0,
                25.0,
                Center_Tolerance,
                Radius_Tolerance),
         "a radius range excluding the circle must not report it");
   end Circles_Explicit_Radius;

   procedure Circles_Two_Separated (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image   : OpenCV.Core.Mat := Blank (100, 180);
      Blurred : OpenCV.Core.Mat;
   begin
      IP.Fill_Circle (Image, (X => 45, Y => 50), 22, White);
      IP.Fill_Circle (Image, (X => 135, Y => 50), 22, White);
      IP.Gaussian_Blur
        (Image, Blurred, (Width => 5, Height => 5), Sigma => 1.5);
      declare
         Circles : constant IP.Hough_Circle_Array :=
           IP.Find_Hough_Circles
             (Blurred,
              1.0,
              40.0,
              100,
              20,
              Minimum_Radius => 12,
              Maximum_Radius => 32);
      begin
         AUnit.Assertions.Assert
           (Has_Circle
              (Circles, 45.0, 50.0, 22.0, Center_Tolerance, Radius_Tolerance)
            and then Has_Circle
                       (Circles,
                        135.0,
                        50.0,
                        22.0,
                        Center_Tolerance,
                        Radius_Tolerance),
            "both separated circles must be detected");
      end;
   end Circles_Two_Separated;

   procedure Circles_Empty_Source_And_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Flat   : constant OpenCV.Core.Mat := Blank (60, 60);
      Parent : OpenCV.Core.Mat := Blank (120, 140);
   begin
      declare
         Circles : constant IP.Hough_Circle_Array :=
           IP.Find_Hough_Circles (Flat, 1.0, 20.0, 100, 20);
      begin
         AUnit.Assertions.Assert
           (Circles'First = 1 and then Circles'Last = 0,
            "a featureless image must return the null range 1 .. 0");
      end;

      --  Region origin (20, 10); the ring is centered at Region (50, 50).
      IP.Fill_Circle (Parent, (X => 70, Y => 60), 25, White);
      declare
         Blurred : OpenCV.Core.Mat;
      begin
         IP.Gaussian_Blur
           (Parent, Blurred, (Width => 5, Height => 5), Sigma => 1.5);
         Parent := Blurred;
      end;
      declare
         Before  : constant OpenCV.Core.Mat := Parent.Clone;
         View    : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 20, Y => 10, Width => 100, Height => 100));
         Circles : constant IP.Hough_Circle_Array :=
           IP.Find_Hough_Circles
             (View,
              1.0,
              40.0,
              100,
              20,
              Minimum_Radius => 15,
              Maximum_Radius => 35);
      begin
         AUnit.Assertions.Assert
           (not View.Is_Continuous,
            "the fixture Region must be a strided view");
         AUnit.Assertions.Assert
           (Has_Circle
              (Circles, 50.0, 50.0, 25.0, Center_Tolerance, Radius_Tolerance),
            "Region circles must use Region-relative coordinates");
         AUnit.Assertions.Assert
           (Same_Pixels (Parent, Before),
            "Find_Hough_Circles must preserve Source");
      end;
   end Circles_Empty_Source_And_Region;

   procedure Circles_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image    : constant OpenCV.Core.Mat := Blank (16, 16);
      Empty    : OpenCV.Core.Mat;
      Three_D  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 4, 2 => 4, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Signed   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.Int16, 1));
      Color    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 3));
      Scale    : OpenCV.Float64_Value := 1.0;
      Distance : OpenCV.Float64_Value := 5.0;
      Minimum  : OpenCV.Size_Coordinate := 0;
      Maximum  : OpenCV.Size_Coordinate := 8;
      Source   : OpenCV.Core.Mat;
      Ignore   : Natural := 0;

      procedure Automatic is
      begin
         Ignore :=
           IP.Find_Hough_Circles (Source, Scale, Distance, 100, 20)'Length;
      end Automatic;

      procedure Explicit is
      begin
         Ignore :=
           IP.Find_Hough_Circles
             (Image, 1.0, 5.0, 100, 20, Minimum, Maximum)'Length;
      end Explicit;

      procedure Bad_Canny is
      begin
         Ignore :=
           IP.Find_Hough_Circles
             (Image,
              1.0,
              5.0,
              IP.Hough_Circle_Threshold (Zero_Value),
              20)'Length;
      end Bad_Canny;

      procedure Bad_Accumulator is
      begin
         Ignore :=
           IP.Find_Hough_Circles
             (Image,
              1.0,
              5.0,
              100,
              IP.Hough_Circle_Threshold (Zero_Value))'Length;
      end Bad_Accumulator;

      procedure Expect (Message : String) is
      begin
         Assert_Raises (Automatic'Access, Message);
         Source := Image;
         Scale := 1.0;
         Distance := 5.0;
      end Expect;
   begin
      Source := Empty;
      Expect ("an empty source must be rejected");
      Source := Three_D;
      Expect ("a 3-D source must be rejected");
      Source := Signed;
      Expect ("an Int16 source must be rejected");
      Source := Color;
      Expect ("a three-channel source must be rejected");
      Scale := 0.5;
      Expect ("Accumulator_Scale below 1 must be rejected, not clamped");
      Scale := Non_Finite (NaN_Bits);
      Expect ("a NaN Accumulator_Scale must be rejected");
      Distance := 0.0;
      Expect ("a zero center distance must be rejected");
      Distance := Non_Finite (Inf_Bits);
      Expect ("an infinite center distance must be rejected");
      Assert_Constraint
        (Bad_Canny'Access, "a zero Canny threshold must be rejected");
      Assert_Constraint
        (Bad_Accumulator'Access,
         "a zero accumulator threshold must be rejected");
      Minimum := 8;
      Maximum := 8;
      Assert_Raises
        (Explicit'Access,
         "Maximum_Radius equal to Minimum_Radius is rejected");
      Minimum := 9;
      Assert_Raises
        (Explicit'Access, "Maximum_Radius below Minimum_Radius is rejected");
      Minimum := 0;
      Maximum := 0;
      Assert_Raises
        (Explicit'Access, "an explicit zero Maximum_Radius is rejected");
   end Circles_Invalid_Inputs;

   procedure Raw_Lines_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image                            : OpenCV.Core.Mat := Blank (100, 100);
      Handle                           : aliased C_API.Hough_Lines_Handle :=
        C_API.Null_Hough_Lines_Handle;
      Status                           : C_API.Status;
      Rho, Theta, Min_Theta, Max_Theta : Interfaces.C.double;

      procedure Detect (Source : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Status :=
           C_API.Hough_Lines
             (Source, Rho, Theta, 10, Min_Theta, Max_Theta, Handle'Access);
      end Detect;

      procedure Expect (Fragment, Message : String) is
      begin
         Handle := C_API.Null_Hough_Lines_Handle;
         OpenCV.Core.Module_Interop.With_Input_Handle (Image, Detect'Access);
         Assert_Invalid (Status, Fragment, Message);
         AUnit.Assertions.Assert
           (Handle = C_API.Null_Hough_Lines_Handle,
            Message & ": the output handle must be null on failure");
         Rho := 1.0;
         Theta := Degree;
         Min_Theta := 0.0;
         Max_Theta := Pi;
      end Expect;
   begin
      IP.Draw_Line (Image, (X => 5, Y => 40), (X => 94, Y => 40), White);
      Rho := 1.0e-30;
      Theta := Degree;
      Min_Theta := 0.0;
      Max_Theta := Pi;
      Expect ("rho bins", "a tiny rho must not overflow numrho");
      Rho := 1.0e40;
      Expect ("binary32", "a rho beyond binary32 must be rejected");
      Rho := 1.0e-45;
      Expect ("positive in binary32", "a rho whose inverse overflows fails");
      Rho := Interfaces.C.double (Non_Finite (NaN_Bits));
      Expect ("binary32", "a NaN rho must be rejected");
      Theta := 1.0e-12;
      Expect ("angle bins", "a tiny theta must not overflow numangle");
      Theta := -1.0;
      Expect ("positive", "a negative theta must be rejected");
      Rho := 0.001;
      Theta := 1.0e-6;
      Expect ("indexing", "the accumulator index product must fit int");
      Min_Theta := Interfaces.C.double (Non_Finite (NaN_Bits));
      Expect ("angle bounds", "a NaN angle bound must be rejected");

      --  A coarse but safe resolution is accepted and simply finds nothing.
      Rho := 1000.0;
      Handle := C_API.Null_Hough_Lines_Handle;
      OpenCV.Core.Module_Interop.With_Input_Handle (Image, Detect'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Handle /= C_API.Null_Hough_Lines_Handle,
         "a coarse padded standard accumulator must still be accepted");
      C_API.Hough_Lines_Destroy (Handle);

      Status :=
        Raw_Hough_Lines
          (System.Null_Address, 1.0, Degree, 10, 0.0, Pi, Handle'Access);
      Assert_Invalid (Status, "source", "a null source must be rejected");
      Status :=
        Raw_Hough_Lines (System.Null_Address, 1.0, Degree, 10, 0.0, Pi, null);
      Assert_Invalid (Status, "output", "a null output pointer is rejected");
   end Raw_Lines_Geometry;

   procedure Raw_Segments_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image      : OpenCV.Core.Mat := Blank (100, 100);
      Handle     : aliased C_API.Hough_Segments_Handle :=
        C_API.Null_Hough_Segments_Handle;
      Status     : C_API.Status;
      Rho, Theta : Interfaces.C.double;
      Threshold  : Interfaces.Integer_32;

      procedure Detect (Source : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Status :=
           C_API.Hough_Segments
             (Source, Rho, Theta, Threshold, 10, 2, Handle'Access);
      end Detect;

      procedure Expect (Fragment, Message : String) is
      begin
         Handle := C_API.Null_Hough_Segments_Handle;
         OpenCV.Core.Module_Interop.With_Input_Handle (Image, Detect'Access);
         Assert_Invalid (Status, Fragment, Message);
         AUnit.Assertions.Assert
           (Handle = C_API.Null_Hough_Segments_Handle,
            Message & ": the output handle must be null on failure");
         Rho := 1.0;
         Theta := Degree;
         Threshold := 10;
      end Expect;
   begin
      IP.Draw_Line (Image, (X => 5, Y => 40), (X => 94, Y => 40), White);
      Rho := 1.0e-30;
      Theta := Degree;
      Threshold := 10;
      Expect ("rho bins", "a tiny rho must not overflow numrho");
      Theta := 1.0e-12;
      Expect ("angle bins", "a tiny theta must not overflow numangle");
      Rho := 0.001;
      Theta := 1.0e-6;
      Expect ("sizing", "the probabilistic accumulator size must fit int");
      --  An unpadded accumulator with zero rho bins would be written out
      --  of bounds by the first vote.
      Rho := 1000.0;
      Expect ("too coarse", "a rho yielding no usable bins is rejected");
      Threshold := Interfaces.Integer_32'First;
      Expect ("threshold", "an INT_MIN threshold must not underflow");
   end Raw_Segments_Geometry;

   procedure Raw_Circles_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image                  : constant OpenCV.Core.Mat :=
        Ring (100, 100, (X => 50, Y => 50), 25);
      Handle                 : aliased C_API.Hough_Circles_Handle :=
        C_API.Null_Hough_Circles_Handle;
      Status                 : C_API.Status;
      Scale, Distance        : Interfaces.C.double;
      Mode, Minimum, Maximum : Interfaces.Integer_32;

      procedure Detect (Source : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Status :=
           C_API.Hough_Circles
             (Source,
              Scale,
              Distance,
              100,
              20,
              Mode,
              Minimum,
              Maximum,
              Handle'Access);
      end Detect;

      procedure Reset is
      begin
         Scale := 1.0;
         Distance := 40.0;
         Mode := C_API.Hough_Radius_Explicit;
         Minimum := 15;
         Maximum := 35;
      end Reset;

      procedure Expect (Fragment, Message : String) is
      begin
         Handle := C_API.Null_Hough_Circles_Handle;
         OpenCV.Core.Module_Interop.With_Input_Handle (Image, Detect'Access);
         Assert_Invalid (Status, Fragment, Message);
         AUnit.Assertions.Assert
           (Handle = C_API.Null_Hough_Circles_Handle,
            Message & ": the output handle must be null on failure");
         Reset;
      end Expect;
   begin
      Reset;
      Scale := 0.5;
      Expect ("at least 1", "a raw dp below 1 must be rejected");
      Scale := Interfaces.C.double (Non_Finite (NaN_Bits));
      Expect ("at least 1", "a NaN dp must be rejected");
      Distance := Interfaces.C.double (Non_Finite (NaN_Bits));
      Expect ("center distance", "a NaN minimum distance must be rejected");
      Distance := -1.0;
      Expect ("center distance", "a negative minimum distance is rejected");
      Minimum := -1;
      Expect ("nonnegative", "a negative minimum radius must be rejected");
      Maximum := -1;
      Expect ("exceed", "a negative centers-only sentinel must be rejected");
      Minimum := 20;
      Maximum := 20;
      Expect ("exceed", "max_radius == min_radius must not be rewritten");
      Mode := C_API.Hough_Radius_Automatic;
      Maximum := 30;
      Expect ("max_radius 0", "automatic mode requires max_radius 0");
      Mode := 7;
      Expect ("radius mode", "an unknown radius mode must be rejected");
      Maximum := 50_000;
      Expect ("int arithmetic", "maxRadius squared must fit int");
      Minimum := Interfaces.Integer_32'Last - 1;
      Maximum := Interfaces.Integer_32'Last;
      Expect ("int arithmetic", "INT_MAX radii must not overflow natively");
      Minimum := 2_000_000;
      Maximum := 2_000_001;
      Expect ("int arithmetic", "a huge radius must be rejected");
      Scale := 1.0e6;
      Minimum := 10;
      Maximum := 11;
      Expect ("empty", "a radius range with zero histogram bins is rejected");

      --  A valid automatic-radius request succeeds after all failures.
      Mode := C_API.Hough_Radius_Automatic;
      Maximum := 0;
      Handle := C_API.Null_Hough_Circles_Handle;
      OpenCV.Core.Module_Interop.With_Input_Handle (Image, Detect'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Handle /= C_API.Null_Hough_Circles_Handle,
         "a valid automatic-radius request must succeed after failures");
      C_API.Hough_Circles_Destroy (Handle);

      --  A 2.1-million-column source keeps rows * cols within int, but the
      --  native x * 1024 fixed-point accumulator coordinate would overflow.
      declare
         Wide : constant OpenCV.Core.Mat := Blank (1, 2_100_000);

         procedure Detect_Wide
           (Source : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status :=
              C_API.Hough_Circles
                (Source,
                 1.0,
                 40.0,
                 100,
                 20,
                 C_API.Hough_Radius_Explicit,
                 1,
                 20,
                 Handle'Access);
         end Detect_Wide;
      begin
         Handle := C_API.Null_Hough_Circles_Handle;
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Wide, Detect_Wide'Access);
         Assert_Invalid
           (Status, "fixed-point", "a very wide source must be rejected");
      end;
   end Raw_Circles_Geometry;

   procedure Raw_Result_Handles (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat := Blank (60, 80);
      Lines  : aliased C_API.Hough_Lines_Handle :=
        C_API.Null_Hough_Lines_Handle;
      Count  : aliased Interfaces.Integer_32 := -1;
      Status : C_API.Status;

      procedure Detect (Source : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Status :=
           C_API.Hough_Lines (Source, 1.0, Degree, 40, 0.0, Pi, Lines'Access);
      end Detect;
   begin
      --  Null result handles are rejected, and destroy accepts null.
      Assert_Invalid
        (C_API.Hough_Lines_Count (C_API.Null_Hough_Lines_Handle, Count'Access),
         "arguments",
         "a null line result must be rejected");
      Assert_Invalid
        (C_API.Hough_Segments_Count
           (C_API.Null_Hough_Segments_Handle, Count'Access),
         "arguments",
         "a null segment result must be rejected");
      Assert_Invalid
        (C_API.Hough_Circles_Count
           (C_API.Null_Hough_Circles_Handle, Count'Access),
         "arguments",
         "a null circle result must be rejected");
      Assert_Invalid
        (C_API.Hough_Segments_Copy (C_API.Null_Hough_Segments_Handle, null, 0),
         "result",
         "copying from a null segment result must be rejected");
      Assert_Invalid
        (C_API.Hough_Circles_Copy (C_API.Null_Hough_Circles_Handle, null, 0),
         "result",
         "copying from a null circle result must be rejected");
      C_API.Hough_Lines_Destroy (C_API.Null_Hough_Lines_Handle);
      C_API.Hough_Segments_Destroy (C_API.Null_Hough_Segments_Handle);
      C_API.Hough_Circles_Destroy (C_API.Null_Hough_Circles_Handle);

      IP.Draw_Line (Image, (X => 5, Y => 20), (X => 74, Y => 20), White);
      OpenCV.Core.Module_Interop.With_Input_Handle (Image, Detect'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "raw line detection must succeed");
      Status := C_API.Hough_Lines_Count (Lines, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count > 0,
         "a detected line result must report a positive count");
      Assert_Invalid
        (C_API.Hough_Lines_Count (Lines, null),
         "arguments",
         "a null count output must be rejected");
      declare
         Marker : constant C_API.Hough_Line_Record :=
           (Rho => -7.0, Theta => -7.0);
         Buffer : C_API.Hough_Line_Record_Array (0 .. Natural (Count)) :=
           (others => Marker);
      begin
         Assert_Invalid
           (C_API.Hough_Lines_Copy (Lines, Buffer (0)'Access, -1),
            "capacity",
            "a negative capacity must be rejected");
         Assert_Invalid
           (C_API.Hough_Lines_Copy (Lines, Buffer (0)'Access, Count - 1),
            "capacity",
            "an insufficient capacity must be rejected");
         AUnit.Assertions.Assert
           (Buffer (0) = Marker, "a rejected copy must not write any record");
         Assert_Invalid
           (C_API.Hough_Lines_Copy (Lines, null, Count),
            "buffer",
            "a null buffer must be rejected");
         Status :=
           C_API.Hough_Lines_Copy (Lines, Buffer (0)'Access, Count + 1);
         AUnit.Assertions.Assert
           (Status = C_API.Success
            and then Buffer (Natural (Count)) = Marker
            and then Buffer (0) /= Marker,
            "a larger capacity must copy exactly Count records");
      end;
      C_API.Hough_Lines_Destroy (Lines);
   end Raw_Result_Handles;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Routine : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Routine));
      end Add;
   begin
      Add ("Hough lines horizontal", Lines_Horizontal'Access);
      Add ("Hough lines vertical", Lines_Vertical'Access);
      Add
        ("Hough lines polar interpretation",
         Lines_Polar_Interpretation'Access);
      Add ("Hough lines restricted angles", Lines_Restricted_Angles'Access);
      Add
        ("Hough lines empty and nonzero foreground",
         Lines_Empty_And_Foreground'Access);
      Add ("Hough lines from Canny edges", Lines_From_Canny_Edges'Access);
      Add
        ("Hough lines source preservation and Region",
         Lines_Source_And_Region'Access);
      Add ("Hough lines invalid inputs", Lines_Invalid_Inputs'Access);
      Add
        ("Hough segments horizontal and vertical",
         Segments_Horizontal_And_Vertical'Access);
      Add
        ("Hough segments diagonal endpoint order",
         Segments_Diagonal_Order_Independent'Access);
      Add ("Hough segments length and gap", Segments_Length_And_Gap'Access);
      Add
        ("Hough segments empty, source preservation and Region",
         Segments_Empty_Source_And_Region'Access);
      Add ("Hough segments invalid inputs", Segments_Invalid_Inputs'Access);
      Add ("Hough circles automatic radius", Circles_Automatic_Radius'Access);
      Add ("Hough circles explicit radius", Circles_Explicit_Radius'Access);
      Add ("Hough circles two separated", Circles_Two_Separated'Access);
      Add
        ("Hough circles empty, source preservation and Region",
         Circles_Empty_Source_And_Region'Access);
      Add ("Hough circles invalid inputs", Circles_Invalid_Inputs'Access);
      Add ("Hough raw C ABI line geometry", Raw_Lines_Geometry'Access);
      Add ("Hough raw C ABI segment geometry", Raw_Segments_Geometry'Access);
      Add ("Hough raw C ABI circle geometry", Raw_Circles_Geometry'Access);
      Add ("Hough raw C ABI result handles", Raw_Result_Handles'Access);
      return Result'Access;
   end Suite;

   --  @@TESTS@@

end Hough_Detection_Tests;
