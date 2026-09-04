with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

package body Canny_Edge_Tests is

   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float64_Value;

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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
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
