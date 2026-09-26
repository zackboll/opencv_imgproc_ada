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
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Int16_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt16_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Drawing_Tests is

   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;

   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Long_Float);
   function Bits_To_Angle is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, OpenCV.Float64_Value);

   function Non_Finite (Bits : Interfaces.Unsigned_64) return Long_Float is
      pragma Suppress (Range_Check);
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float64 (Bits);
   end Non_Finite;

   function Non_Finite_Angle
     (Bits : Interfaces.Unsigned_64) return OpenCV.Float64_Value
   is
      pragma Suppress (Range_Check);
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Angle (Bits);
   end Non_Finite_Angle;

   function Raw_Draw_Line
     (Image                     : System.Address;
      Start_X, Start_Y          : Interfaces.Integer_32;
      Finish_X, Finish_Y        : Interfaces.Integer_32;
      Color_0, Color_1, Color_2 : Interfaces.C.double;
      Color_3                   : Interfaces.C.double;
      Thickness                 : Interfaces.Integer_32;
      Line_Style                : Interfaces.Integer_32) return C_API.Status
   with Import, Convention => C, External_Name => "opencv_imgproc_draw_line";

   White : constant OpenCV.Scalar := (Component_0 => 255.0, others => 0.0);

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

   function Pixel
     (Image : OpenCV.Core.Mat; Row, Column : Natural) return OpenCV.UInt8_Value
   is (OpenCV.Core.UInt8_Access.Get (Image, Integer (Row), Integer (Column)));

   procedure Lines (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Line
        (Image, (X => 1, Y => 1), (X => 5, Y => 1), White);
      AUnit.Assertions.Assert
        (Pixel (Image, 1, 1) = 255
         and then Pixel (Image, 1, 5) = 255
         and then Pixel (Image, 0, 1) = 0,
         "horizontal 8-connected line must paint its endpoints");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Line
        (Image,
         (X => 2, Y => 1),
         (X => 2, Y => 5),
         White,
         Line_Style => OpenCV.Image_Processing.Four_Connected_Line);
      AUnit.Assertions.Assert
        (Pixel (Image, 1, 2) = 255
         and then Pixel (Image, 5, 2) = 255
         and then Pixel (Image, 3, 3) = 0,
         "vertical 4-connected line must stay in its column");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Line
        (Image, (X => 1, Y => 1), (X => 5, Y => 5), White);
      AUnit.Assertions.Assert
        (Pixel (Image, 1, 1) = 255
         and then Pixel (Image, 3, 3) = 255
         and then Pixel (Image, 5, 5) = 255,
         "8-connected diagonal must include its midpoint");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Line
        (Image, (X => 1, Y => 2), (X => 5, Y => 2), White, Thickness => 3);
      AUnit.Assertions.Assert
        (Pixel (Image, 2, 3) = 255
         and then Pixel (Image, 1, 3) = 255
         and then Pixel (Image, 3, 3) = 255,
         "thickness greater than one must widen the line");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Line
        (Image, (X => -2, Y => 3), (X => 3, Y => 3), White);
      AUnit.Assertions.Assert
        (Pixel (Image, 3, 0) = 255 and then Pixel (Image, 3, 3) = 255,
         "a line starting outside the image must be clipped");
   end Lines;

   procedure Antialiasing (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 1));
      Other : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt16, 1));
      Found : Boolean := False;

      procedure Reject is
      begin
         OpenCV.Image_Processing.Draw_Line
           (Other,
            (X => 0, Y => 0),
            (X => 3, Y => 3),
            White,
            Line_Style => OpenCV.Image_Processing.Anti_Aliased_Line);
      end Reject;
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Line
        (Image,
         (X => 1, Y => 1),
         (X => 6, Y => 7),
         White,
         Line_Style => OpenCV.Image_Processing.Anti_Aliased_Line);
      for Row in 0 .. 8 loop
         for Column in 0 .. 8 loop
            if Pixel (Image, Row, Column) > 0
              and then Pixel (Image, Row, Column) < 255
            then
               Found := True;
            end if;
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (Found, "UInt8 antialiasing must produce an intermediate intensity");
      Assert_Raises (Reject'Access, "non-UInt8 antialiasing must be rejected");
   end Antialiasing;

   procedure Rectangles (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));

      procedure Zero_Width is
      begin
         OpenCV.Image_Processing.Draw_Rectangle
           (Image, (X => 1, Y => 1, Width => 0, Height => 2), White);
      end Zero_Width;
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Rectangle
        (Image, (X => 2, Y => 2, Width => 3, Height => 3), White);
      AUnit.Assertions.Assert
        (Pixel (Image, 2, 2) = 255
         and then Pixel (Image, 2, 4) = 255
         and then Pixel (Image, 4, 4) = 255
         and then Pixel (Image, 3, 3) = 0,
         "rectangle outline must paint corners and leave its interior empty");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Image, (X => 2, Y => 2, Width => 3, Height => 2), White);
      AUnit.Assertions.Assert
        (Pixel (Image, 2, 2) = 255
         and then Pixel (Image, 3, 4) = 255
         and then Pixel (Image, 4, 2) = 0,
         "filled rectangle must cover its extent and stop at the next row");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Image, (X => -1, Y => 1, Width => 3, Height => 2), White);
      AUnit.Assertions.Assert
        (Pixel (Image, 1, 0) = 255
         and then Pixel (Image, 1, 1) = 255
         and then Pixel (Image, 1, 2) = 0,
         "a rectangle partly outside the image must be clipped");
      Assert_Raises
        (Zero_Width'Access, "a zero-width rectangle must be rejected");
   end Rectangles;

   procedure Rectangle_Extreme_Clipping (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
   begin
      --  X + Width exceeds Integer_32'Last; OpenCV 4.1's Rect overload would
      --  overflow before clipping.
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Image,
         (X => 2, Y => 1, Width => OpenCV.Size_Coordinate'Last, Height => 2),
         White);
      AUnit.Assertions.Assert
        (Pixel (Image, 1, 2) = 255
         and then Pixel (Image, 2, 7) = 255
         and then Pixel (Image, 1, 1) = 0
         and then Pixel (Image, 3, 7) = 0,
         "a fill whose far corner exceeds Integer_32'Last must be clipped");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Rectangle
        (Image,
         (X      => 1,
          Y      => 3,
          Width  => OpenCV.Size_Coordinate'Last,
          Height => OpenCV.Size_Coordinate'Last),
         White);
      AUnit.Assertions.Assert
        (Pixel (Image, 3, 1) = 255
         and then Pixel (Image, 3, 7) = 255
         and then Pixel (Image, 7, 1) = 255
         and then Pixel (Image, 5, 4) = 0
         and then Pixel (Image, 2, 1) = 0,
         "an outline with both far edges beyond Integer_32'Last must draw"
         & " only its visible near edges");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Rectangle
        (Image,
         (X => -3, Y => -3, Width => OpenCV.Size_Coordinate'Last, Height => 6),
         White);
      AUnit.Assertions.Assert
        (Pixel (Image, 2, 0) = 255
         and then Pixel (Image, 2, 7) = 255
         and then Pixel (Image, 1, 1) = 0
         and then Pixel (Image, 3, 3) = 0,
         "a negative origin with a huge extent must draw its clipped bottom"
         & " edge only");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Image,
         (X      => OpenCV.Point_Coordinate'First,
          Y      => OpenCV.Point_Coordinate'First,
          Width  => OpenCV.Size_Coordinate'Last,
          Height => OpenCV.Size_Coordinate'Last),
         White);
      AUnit.Assertions.Assert
        (Pixel (Image, 0, 0) = 0 and then Pixel (Image, 7, 7) = 0,
         "a rectangle ending at -2 must be entirely clipped");
   end Rectangle_Extreme_Clipping;

   procedure Circles (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Circle (Image, (X => 4, Y => 4), 2, White);
      AUnit.Assertions.Assert
        (Pixel (Image, 4, 6) = 255
         and then Pixel (Image, 4, 2) = 255
         and then Pixel (Image, 4, 4) = 0,
         "circle outline must include cardinal points and leave the center");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Circle (Image, (X => 4, Y => 4), 2, White);
      AUnit.Assertions.Assert
        (Pixel (Image, 4, 4) = 255
         and then Pixel (Image, 4, 6) = 255
         and then Pixel (Image, 4, 7) = 0,
         "filled circle must include its center and stop outside the radius");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Circle (Image, (X => 4, Y => 0), 2, White);
      AUnit.Assertions.Assert
        (Pixel (Image, 0, 4) = 255
         and then Pixel (Image, 1, 4) = 255
         and then Pixel (Image, 0, 1) = 0,
         "a circle near the edge must be clipped");
   end Circles;

   procedure Ellipses (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (15, 15, (OpenCV.Core.UInt8, 1));
      Radians : OpenCV.Core.Mat :=
        OpenCV.Core.Create (15, 15, (OpenCV.Core.UInt8, 1));
      Same    : Boolean := True;

      procedure Bad_Angle is
         pragma Suppress (Validity_Check);
         Angle : constant OpenCV.Float64_Value :=
           Non_Finite_Angle (16#7FF8_0000_0000_0000#);
      begin
         OpenCV.Image_Processing.Draw_Ellipse
           (Image,
            (X => 7, Y => 7),
            (Width => 4, Height => 2),
            Angle,
            0.0,
            90.0,
            White);
      end Bad_Angle;

      procedure Zero_Axis is
      begin
         OpenCV.Image_Processing.Draw_Ellipse
           (Image,
            (X => 7, Y => 7),
            (Width => 0, Height => 2),
            0.0,
            0.0,
            360.0,
            White);
      end Zero_Axis;
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Ellipse
        (Image,
         (X => 7, Y => 7),
         (Width => 4, Height => 2),
         0.0,
         0.0,
         360.0,
         White);
      AUnit.Assertions.Assert
        (Pixel (Image, 7, 11) = 255
         and then Pixel (Image, 7, 3) = 255
         and then Pixel (Image, 7, 7) = 0,
         "full ellipse outline must reach both horizontal vertices");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Ellipse
        (Image,
         (X => 7, Y => 7),
         (Width => 4, Height => 2),
         0.0,
         0.0,
         180.0,
         White);
      AUnit.Assertions.Assert
        (Pixel (Image, 9, 7) = 255
         and then Pixel (Image, 7, 11) = 255
         and then Pixel (Image, 5, 7) = 0,
         "a partial ellipse must omit the opposite arc");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Ellipse
        (Image,
         (X => 7, Y => 7),
         (Width => 3, Height => 2),
         0.0,
         0.0,
         360.0,
         White);
      AUnit.Assertions.Assert
        (Pixel (Image, 7, 7) = 255
         and then Pixel (Image, 7, 10) = 255
         and then Pixel (Image, 7, 11) = 0,
         "a filled full ellipse must include its center");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Ellipse
        (Image,
         (X => 7, Y => 7),
         (Width => 4, Height => 2),
         90.0,
         0.0,
         360.0,
         White);
      AUnit.Assertions.Assert
        (Pixel (Image, 3, 7) = 255 and then Pixel (Image, 11, 7) = 255,
         "a rotated ellipse must move its major axis");

      OpenCV.Core.Set_To (Radians, (others => 0.0));
      OpenCV.Image_Processing.Draw_Ellipse
        (Radians,
         (X => 7, Y => 7),
         (Width => 4, Height => 2),
         OpenCV.Float64_Value (Ada.Numerics.Pi) / 2.0,
         0.0,
         OpenCV.Float64_Value (2.0) * OpenCV.Float64_Value (Ada.Numerics.Pi),
         White,
         Units => OpenCV.Radians);
      for Row in 0 .. 14 loop
         for Column in 0 .. 14 loop
            if Pixel (Image, Row, Column) /= Pixel (Radians, Row, Column) then
               Same := False;
            end if;
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (Same, "radian ellipse angles must match the equivalent degrees");
      Assert_Raises
        (Bad_Angle'Access, "a nonfinite ellipse angle must be rejected");
      Assert_Raises (Zero_Axis'Access, "a zero ellipse axis must be rejected");
   end Ellipses;

   procedure Polylines (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image         : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
      Open_Points   : constant OpenCV.Point_Array (5 .. 7) :=
        ((X => 1, Y => 1), (X => 5, Y => 1), (X => 5, Y => 4));
      Closed_Points : constant OpenCV.Point_Array :=
        ((X => 1, Y => 1),
         (X => 4, Y => 1),
         (X => 4, Y => 4),
         (X => 1, Y => 4));

      procedure Too_Few is
      begin
         OpenCV.Image_Processing.Draw_Polyline
           (Image, OpenCV.Point_Array'(1 => (X => 1, Y => 1)), False, White);
      end Too_Few;
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Polyline (Image, Open_Points, False, White);
      AUnit.Assertions.Assert
        (Pixel (Image, 1, 1) = 255
         and then Pixel (Image, 1, 5) = 255
         and then Pixel (Image, 4, 5) = 255
         and then Pixel (Image, 4, 1) = 0,
         "an open polyline with a nonzero lower bound must not close itself");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Draw_Polyline
        (Image, Closed_Points, True, White);
      AUnit.Assertions.Assert
        (Pixel (Image, 1, 1) = 255
         and then Pixel (Image, 4, 1) = 255
         and then Pixel (Image, 1, 4) = 255,
         "a closed polyline must include the return edge");
      Assert_Raises (Too_Few'Access, "a one-point polyline must be rejected");
   end Polylines;

   procedure Polygons (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 1));
      Triangle : constant OpenCV.Point_Array (3 .. 5) :=
        ((X => 1, Y => 1), (X => 5, Y => 1), (X => 1, Y => 5));
      Concave  : constant OpenCV.Point_Array :=
        ((X => 1, Y => 1),
         (X => 7, Y => 1),
         (X => 4, Y => 4),
         (X => 7, Y => 7),
         (X => 1, Y => 7));

      procedure Too_Few is
      begin
         OpenCV.Image_Processing.Fill_Polygon
           (Image,
            OpenCV.Point_Array'(1 => (X => 1, Y => 1), 2 => (X => 2, Y => 2)),
            White);
      end Too_Few;
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Polygon (Image, Triangle, White);
      AUnit.Assertions.Assert
        (Pixel (Image, 1, 1) = 255
         and then Pixel (Image, 2, 2) = 255
         and then Pixel (Image, 4, 4) = 0,
         "a triangle with a nonzero lower bound must fill its interior");

      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Image_Processing.Fill_Polygon (Image, Concave, White);
      AUnit.Assertions.Assert
        (Pixel (Image, 2, 2) = 255
         and then Pixel (Image, 4, 4) = 255
         and then Pixel (Image, 4, 6) = 0,
         "a concave polygon must leave the reflex exterior empty");
      Assert_Raises (Too_Few'Access, "a two-point polygon must be rejected");
   end Polygons;

   procedure Channels_Depths_And_Aliases (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Gray     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Color    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 3));
      Four     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 4));
      Wide     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt16, 1));
      Signed   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Int16, 1));
      Single   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Float32, 1));
      Double   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Float64, 1));
      Alias    : OpenCV.Core.Mat;
      Parent   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 6, (OpenCV.Core.UInt8, 1));
      Region   : OpenCV.Core.Mat;
      Channels : OpenCV.Core.Mat_Array (1 .. 4);
      Paint    : constant OpenCV.Scalar :=
        (Component_0 => 11.0,
         Component_1 => 22.0,
         Component_2 => 33.0,
         Component_3 => 44.0);
   begin
      OpenCV.Core.Set_To (Gray, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Gray, (X => 1, Y => 1, Width => 1, Height => 1), White);
      AUnit.Assertions.Assert
        (Pixel (Gray, 1, 1) = 255, "C1 drawing must use Component_0");

      OpenCV.Core.Set_To (Color, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Color, (X => 1, Y => 1, Width => 1, Height => 1), Paint);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Color, 1, 1) = (11, 22, 33),
         "C3 drawing must copy the first three scalar components");

      OpenCV.Core.Set_To (Four, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Four, (X => 1, Y => 1, Width => 1, Height => 1), Paint);
      Channels := OpenCV.Core.Split (Four);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Channels (1), 1, 1) = 11
         and then OpenCV.Core.UInt8_Access.Get (Channels (2), 1, 1) = 22
         and then OpenCV.Core.UInt8_Access.Get (Channels (3), 1, 1) = 33
         and then OpenCV.Core.UInt8_Access.Get (Channels (4), 1, 1) = 44,
         "C4 drawing must copy the fourth component without blending");

      OpenCV.Core.Set_To (Wide, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Wide, (X => 1, Y => 1, Width => 1, Height => 1), White);
      OpenCV.Core.Set_To (Signed, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Signed, (X => 1, Y => 1, Width => 1, Height => 1), White);
      OpenCV.Core.Set_To (Single, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Single, (X => 1, Y => 1, Width => 1, Height => 1), White);
      OpenCV.Core.Set_To (Double, (others => 0.0));
      OpenCV.Image_Processing.Fill_Rectangle
        (Double, (X => 1, Y => 1, Width => 1, Height => 1), White);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt16_Access.Get (Wide, 1, 1) = 255
         and then OpenCV.Core.Int16_Access.Get (Signed, 1, 1) = 255
         and then OpenCV.Core.Float32_Access.Get (Single, 1, 1) = 255.0
         and then OpenCV.Core.Float64_Access.Get (Double, 1, 1) = 255.0,
         "drawing must accept the documented numeric depths");

      OpenCV.Core.Set_To (Gray, (others => 0.0));
      Alias := Gray;
      OpenCV.Image_Processing.Draw_Line
        (Alias, (X => 0, Y => 2), (X => 4, Y => 2), White);
      AUnit.Assertions.Assert
        (Pixel (Gray, 2, 2) = 255,
         "drawing through a shallow alias must modify the original Mat");

      OpenCV.Core.Set_To (Parent, (others => 7.0));
      Region := Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      OpenCV.Image_Processing.Fill_Rectangle
        (Region, (X => 0, Y => 0, Width => 2, Height => 2), White);
      AUnit.Assertions.Assert
        (Pixel (Parent, 1, 1) = 255
         and then Pixel (Parent, 2, 2) = 255
         and then Pixel (Parent, 0, 0) = 7
         and then Pixel (Parent, 1, 4) = 7,
         "drawing into a Region must update only pixels inside it");
   end Channels_Depths_And_Aliases;

   procedure Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Empty       : OpenCV.Core.Mat;
      Three_D     : OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int32_Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int32, 1));
      Five        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 5));

      procedure Empty_Call is
      begin
         OpenCV.Image_Processing.Draw_Line
           (Empty, (X => 0, Y => 0), (X => 1, Y => 1), White);
      end Empty_Call;

      procedure Three_D_Call is
      begin
         OpenCV.Image_Processing.Draw_Line
           (Three_D, (X => 0, Y => 0), (X => 1, Y => 1), White);
      end Three_D_Call;

      procedure Depth_Call is
      begin
         OpenCV.Image_Processing.Draw_Line
           (Int32_Image, (X => 0, Y => 0), (X => 1, Y => 1), White);
      end Depth_Call;

      procedure Channel_Call is
      begin
         OpenCV.Image_Processing.Draw_Line
           (Five, (X => 0, Y => 0), (X => 1, Y => 1), White);
      end Channel_Call;

      procedure Color_Call is
      begin
         OpenCV.Image_Processing.Draw_Line
           (Image,
            (X => 0, Y => 0),
            (X => 1, Y => 1),
            (Component_0 => Non_Finite (16#7FF8_0000_0000_0000#),
             others      => 0.0));
      end Color_Call;
   begin
      Assert_Raises (Empty_Call'Access, "drawing must reject an empty Mat");
      Assert_Raises (Three_D_Call'Access, "drawing must reject a 3-D Mat");
      Assert_Raises (Depth_Call'Access, "drawing must reject Int32 depth");
      Assert_Raises (Channel_Call'Access, "drawing must reject five channels");
      Assert_Raises
        (Color_Call'Access, "drawing must reject a nonfinite used color");
   end Invalid_Inputs;

   procedure Raw_C_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Status : C_API.Status;

      procedure Bad_Style
        (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           C_API.Draw_Line (Handle, 0, 0, 3, 3, 1.0, 0.0, 0.0, 0.0, 1, 99);
      end Bad_Style;

      procedure Bad_Radius
        (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           C_API.Draw_Circle
             (Handle,
              1,
              1,
              0,
              1.0,
              0.0,
              0.0,
              0.0,
              C_API.Drawing_Outline,
              1,
              C_API.Drawing_Line_8);
      end Bad_Radius;

      procedure Bad_Points
        (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           C_API.Fill_Polygon
             (Handle, null, 3, 1.0, 0.0, 0.0, 0.0, C_API.Drawing_Line_8);
      end Bad_Points;

      procedure Recover (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
      begin
         Status :=
           C_API.Draw_Line
             (Handle, 0, 1, 3, 1, 9.0, 0.0, 0.0, 0.0, 1, C_API.Drawing_Line_8);
      end Recover;
   begin
      Status :=
        Raw_Draw_Line
          (System.Null_Address,
           0,
           0,
           1,
           1,
           1.0,
           0.0,
           0.0,
           0.0,
           1,
           C_API.Drawing_Line_8);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "image")
                  /= 0,
         "a null drawing image must be rejected with a diagnostic");
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Bad_Style'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "style")
                  /= 0,
         "a bad line-style selector must be rejected with a diagnostic");
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Bad_Radius'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "radius")
                  /= 0,
         "a nonpositive raw radius must be rejected with a diagnostic");
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Bad_Points'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "points")
                  /= 0,
         "a null point array must be rejected with a diagnostic");
      OpenCV.Core.Set_To (Image, (others => 0.0));
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Recover'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Pixel (Image, 1, 2) = 9,
         "a valid drawing must succeed after a prior ABI failure");
   end Raw_C_ABI;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Drawing lines", Lines'Access));
      Result.Add_Test
        (Caller.Create ("Drawing antialiasing", Antialiasing'Access));
      Result.Add_Test
        (Caller.Create ("Drawing rectangles", Rectangles'Access));
      Result.Add_Test
        (Caller.Create
           ("Drawing rectangle extreme clipping",
            Rectangle_Extreme_Clipping'Access));
      Result.Add_Test (Caller.Create ("Drawing circles", Circles'Access));
      Result.Add_Test (Caller.Create ("Drawing ellipses", Ellipses'Access));
      Result.Add_Test (Caller.Create ("Drawing polylines", Polylines'Access));
      Result.Add_Test (Caller.Create ("Drawing polygons", Polygons'Access));
      Result.Add_Test
        (Caller.Create
           ("Drawing channels depths and aliases",
            Channels_Depths_And_Aliases'Access));
      Result.Add_Test
        (Caller.Create ("Drawing invalid inputs", Invalid_Inputs'Access));
      Result.Add_Test (Caller.Create ("Drawing raw C ABI", Raw_C_ABI'Access));
      return Result'Access;
   end Suite;

end Drawing_Tests;
