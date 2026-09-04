with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

package body Automatic_Threshold_Tests is

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

   procedure Assert_Same_UInt8_Pixels
     (Left, Right : OpenCV.Core.Mat; Message : String) is
   begin
      for Row in 0 .. Left.Rows - 1 loop
         for Column in 0 .. Left.Columns - 1 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Left, Row, Column)
               = OpenCV.Core.UInt8_Access.Get (Right, Row, Column),
               Message
               & " at"
               & Natural'Image (Row)
               & ","
               & Natural'Image (Column)
               & ": got"
               & Interfaces.Unsigned_8'Image
                   (OpenCV.Core.UInt8_Access.Get (Left, Row, Column))
               & ", expected"
               & Interfaces.Unsigned_8'Image
                   (OpenCV.Core.UInt8_Access.Get (Right, Row, Column)));
         end loop;
      end loop;
   end Assert_Same_UInt8_Pixels;

   procedure Otsu_UInt8_Agrees_With_Fixed_Threshold (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 4, (OpenCV.Core.UInt8, 1));
      Destination      : OpenCV.Core.Mat;
      Automatic_Result : OpenCV.Core.Mat;
      Expected         : OpenCV.Core.Mat;
      Threshold        : OpenCV.Core.Float64_Value;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 10);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 20);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 180);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 3, 200);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 0, 15);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 25);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 2, 190);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 3, 210);

      OpenCV.Image_Processing.Apply_Automatic_Threshold
        (Source, Destination, Threshold);
      Automatic_Result := Destination.Clone;
      OpenCV.Image_Processing.Apply_Threshold (Source, Expected, Threshold);

      AUnit.Assertions.Assert
        (Automatic_Result.Rows = Source.Rows
         and then Automatic_Result.Columns = Source.Columns
         and then Automatic_Result.Depth = OpenCV.Core.UInt8
         and then Automatic_Result.Channels = 1,
         "Otsu UInt8 must preserve source geometry and type");
      AUnit.Assertions.Assert
        (Threshold = Threshold
         and then Threshold >= 10.0
         and then Threshold <= 210.0,
         "Otsu UInt8 must return a finite threshold in the source range");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 10
         and then OpenCV.Core.UInt8_Access.Get (Source, 1, 3) = 210,
         "Otsu UInt8 must preserve Source");
      Assert_Same_UInt8_Pixels
        (Automatic_Result,
         Expected,
         "Otsu UInt8 output must match returned threshold");
   end Otsu_UInt8_Agrees_With_Fixed_Threshold;

   procedure Otsu_UInt16_Agrees_With_Fixed_Threshold (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Destination      : OpenCV.Core.Mat;
      Automatic_Result : OpenCV.Core.Mat;
      Expected         : OpenCV.Core.Mat;
      High_Values      : OpenCV.Core.Mat;
      Threshold        : OpenCV.Core.Float64_Value;
   begin
      OpenCV.Core.Set_To (Source, (Component_0 => 1_000.0, others => 0.0));
      High_Values := Source.Region ((X => 1, Y => 0, Width => 1, Height => 2));
      OpenCV.Core.Set_To
        (High_Values, (Component_0 => 50_000.0, others => 0.0));

      OpenCV.Image_Processing.Apply_Automatic_Threshold
        (Source,
         Destination,
         Threshold,
         OpenCV.Image_Processing.Otsu,
         OpenCV.Image_Processing.To_Zero);
      Automatic_Result := Destination.Clone;
      OpenCV.Image_Processing.Apply_Threshold
        (Source, Expected, Threshold, OpenCV.Image_Processing.To_Zero);

      AUnit.Assertions.Assert
        (Automatic_Result.Rows = Source.Rows
         and then Automatic_Result.Columns = Source.Columns
         and then Automatic_Result.Depth = OpenCV.Core.UInt16
         and then Automatic_Result.Channels = 1,
         "Otsu UInt16 must preserve source geometry and type");
      AUnit.Assertions.Assert
        (Threshold = Threshold, "Otsu UInt16 must return a finite threshold");
      AUnit.Assertions.Assert
        (Source.Min_Max_Loc.Minimum = 1_000.0
         and then Source.Min_Max_Loc.Maximum = 50_000.0,
         "Otsu UInt16 must preserve Source");
      AUnit.Assertions.Assert
        (Automatic_Result.Compare (Expected, OpenCV.Core.Equal)
           .Min_Max_Loc
           .Minimum
         = 255.0,
         "Otsu UInt16 output must match returned threshold");
   end Otsu_UInt16_Agrees_With_Fixed_Threshold;

   procedure Triangle_UInt8_Agrees_With_Fixed_Threshold (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 4, (OpenCV.Core.UInt8, 1));
      Destination      : OpenCV.Core.Mat;
      Automatic_Result : OpenCV.Core.Mat;
      Expected         : OpenCV.Core.Mat;
      Threshold        : OpenCV.Core.Float64_Value;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 5);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 10);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 20);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 3, 40);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 0, 60);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 100);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 2, 160);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 3, 220);

      OpenCV.Image_Processing.Apply_Automatic_Threshold
        (Source,
         Destination,
         Threshold,
         OpenCV.Image_Processing.Triangle,
         OpenCV.Image_Processing.Binary_Inverse,
         123.0);
      Automatic_Result := Destination.Clone;
      OpenCV.Image_Processing.Apply_Threshold
        (Source,
         Expected,
         Threshold,
         OpenCV.Image_Processing.Binary_Inverse,
         123.0);

      AUnit.Assertions.Assert
        (Automatic_Result.Rows = Source.Rows
         and then Automatic_Result.Columns = Source.Columns
         and then Automatic_Result.Depth = OpenCV.Core.UInt8
         and then Automatic_Result.Channels = 1,
         "Triangle UInt8 must preserve source geometry and type");
      AUnit.Assertions.Assert
        (Threshold = Threshold,
         "Triangle UInt8 must return a finite threshold");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 5
         and then OpenCV.Core.UInt8_Access.Get (Source, 1, 3) = 220,
         "Triangle UInt8 must preserve Source");
      Assert_Same_UInt8_Pixels
        (Automatic_Result,
         Expected,
         "Triangle output must match returned threshold");
   end Triangle_UInt8_Agrees_With_Fixed_Threshold;

   procedure Automatic_Threshold_Rejects_Invalid_Inputs (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Empty_Source  : OpenCV.Core.Mat;
      Three_D       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Multi_Channel : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      Float_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Int16_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int16, 1));
      UInt16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
      Destination   : OpenCV.Core.Mat;
      Threshold     : OpenCV.Core.Float64_Value;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Apply_Automatic_Threshold
           (Empty_Source, Destination, Threshold);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Apply_Automatic_Threshold
           (Three_D, Destination, Threshold);
      end Non_Two_Dimensional;

      procedure Multi_Channel_Source is
      begin
         OpenCV.Image_Processing.Apply_Automatic_Threshold
           (Multi_Channel, Destination, Threshold);
      end Multi_Channel_Source;

      procedure Otsu_Float is
      begin
         OpenCV.Image_Processing.Apply_Automatic_Threshold
           (Float_Source, Destination, Threshold);
      end Otsu_Float;

      procedure Otsu_Int16 is
      begin
         OpenCV.Image_Processing.Apply_Automatic_Threshold
           (Int16_Source, Destination, Threshold);
      end Otsu_Int16;

      procedure Triangle_UInt16 is
      begin
         OpenCV.Image_Processing.Apply_Automatic_Threshold
           (UInt16_Source,
            Destination,
            Threshold,
            OpenCV.Image_Processing.Triangle);
      end Triangle_UInt16;

      procedure Triangle_Float is
      begin
         OpenCV.Image_Processing.Apply_Automatic_Threshold
           (Float_Source,
            Destination,
            Threshold,
            OpenCV.Image_Processing.Triangle);
      end Triangle_Float;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "automatic threshold must reject empty source");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "automatic threshold must reject three-dimensional source");
      Assert_Raises_OpenCV_Error
        (Multi_Channel_Source'Access,
         "automatic threshold must reject multi-channel source");
      Assert_Raises_OpenCV_Error
        (Otsu_Float'Access, "Otsu must reject Float32");
      Assert_Raises_OpenCV_Error (Otsu_Int16'Access, "Otsu must reject Int16");
      Assert_Raises_OpenCV_Error
        (Triangle_UInt16'Access, "Triangle must reject UInt16");
      Assert_Raises_OpenCV_Error
        (Triangle_Float'Access, "Triangle must reject Float32");
   end Automatic_Threshold_Rejects_Invalid_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Otsu UInt8 agrees with fixed threshold",
            Otsu_UInt8_Agrees_With_Fixed_Threshold'Access));
      Result.Add_Test
        (Caller.Create
           ("Otsu UInt16 agrees with fixed threshold",
            Otsu_UInt16_Agrees_With_Fixed_Threshold'Access));
      Result.Add_Test
        (Caller.Create
           ("Triangle UInt8 agrees with fixed threshold",
            Triangle_UInt8_Agrees_With_Fixed_Threshold'Access));
      Result.Add_Test
        (Caller.Create
           ("automatic threshold rejects invalid inputs",
            Automatic_Threshold_Rejects_Invalid_Inputs'Access));
      return Result'Access;
   end Suite;

end Automatic_Threshold_Tests;
