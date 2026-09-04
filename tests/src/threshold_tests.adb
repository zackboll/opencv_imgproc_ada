with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;

package body Threshold_Tests is

   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.Float64_Value;
   use type OpenCV.Core.UInt8_Vec3.Vector;

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

   procedure UInt8_Binary_Uses_Default_Mode_And_Rebinds_Destination
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 9);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 10);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 11);

      OpenCV.Image_Processing.Apply_Threshold
        (Source, Destination, 10.0, Maximum_Value => 42.0);

      AUnit.Assertions.Assert
        (Destination.Rows = 1
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "Binary threshold must rebind Destination with Source's"
         & " element type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 0
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 1) = 0
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 2) = 42,
         "Binary threshold must use a strict greater-than comparison");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 9
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 1) = 10
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 2) = 11,
         "thresholding must not modify Source");
   end UInt8_Binary_Uses_Default_Mode_And_Rebinds_Destination;

   procedure UInt16_Binary_Inverse_Produces_Exact_Value (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
      Destination : OpenCV.Core.Mat;
      Output      : OpenCV.Core.Min_Max_Result;
   begin
      OpenCV.Core.Set_To (Source, (Component_0 => 100.0, others => 0.0));
      OpenCV.Image_Processing.Apply_Threshold
        (Source,
         Destination,
         100.0,
         OpenCV.Image_Processing.Binary_Inverse,
         1_000.0);
      Output := Destination.Min_Max_Loc;

      AUnit.Assertions.Assert
        (Output.Minimum = 1_000.0 and then Output.Maximum = 1_000.0,
         "UInt16 Binary_Inverse must retain Maximum_Value at equality");
      AUnit.Assertions.Assert
        (Source.Min_Max_Loc.Minimum = 100.0,
         "UInt16 thresholding must preserve Source");
   end UInt16_Binary_Inverse_Produces_Exact_Value;

   procedure Int16_Truncate_Produces_Exact_Value (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int16, 1));
      Destination : OpenCV.Core.Mat;
      Output      : OpenCV.Core.Min_Max_Result;
   begin
      OpenCV.Core.Set_To (Source, (Component_0 => 20.0, others => 0.0));
      OpenCV.Image_Processing.Apply_Threshold
        (Source, Destination, 7.0, OpenCV.Image_Processing.Truncate);
      Output := Destination.Min_Max_Loc;

      AUnit.Assertions.Assert
        (Output.Minimum = 7.0 and then Output.Maximum = 7.0,
         "Int16 Truncate must replace values above the threshold");
      AUnit.Assertions.Assert
        (Source.Min_Max_Loc.Maximum = 20.0,
         "Int16 thresholding must preserve Source");
   end Int16_Truncate_Produces_Exact_Value;

   procedure Float32_To_Zero_Produces_Exact_Values (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, -1.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 1, 2.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 2, 3.0);
      OpenCV.Image_Processing.Apply_Threshold
        (Source, Destination, 2.0, OpenCV.Image_Processing.To_Zero);

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 0.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 1) = 0.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 2) = 3.0,
         "Float32 To_Zero must retain only values strictly above threshold");
   end Float32_To_Zero_Produces_Exact_Values;

   procedure Float64_To_Zero_Inverse_Produces_Exact_Values
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float64, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Float64_Access.Set (Source, 0, 0, 1.0);
      OpenCV.Core.Float64_Access.Set (Source, 0, 1, 2.0);
      OpenCV.Core.Float64_Access.Set (Source, 0, 2, 3.0);
      OpenCV.Image_Processing.Apply_Threshold
        (Source, Destination, 2.0, OpenCV.Image_Processing.To_Zero_Inverse);

      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Destination, 0, 0) = 1.0
         and then OpenCV.Core.Float64_Access.Get (Destination, 0, 1) = 2.0
         and then OpenCV.Core.Float64_Access.Get (Destination, 0, 2) = 0.0,
         "Float64 To_Zero_Inverse must retain values at or below threshold");
   end Float64_To_Zero_Inverse_Produces_Exact_Values;

   procedure Multi_Channel_Threshold_Preserves_Channel_Count
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 0, (9, 10, 11));
      OpenCV.Image_Processing.Apply_Threshold
        (Source, Destination, 10.0, Maximum_Value => 77.0);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 0)
                  = (0, 0, 77),
         "thresholding must process every UInt8 channel independently");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Source, 0, 0) = (9, 10, 11),
         "multi-channel thresholding must preserve Source");
   end Multi_Channel_Threshold_Preserves_Channel_Count;

   procedure Threshold_Rejects_Invalid_Sources (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Empty_Source : OpenCV.Core.Mat;
      Three_D      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int32_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int32, 1));
      Destination  : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Apply_Threshold
           (Empty_Source, Destination, 1.0);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Apply_Threshold (Three_D, Destination, 1.0);
      end Non_Two_Dimensional;

      procedure Unsupported_Depth is
      begin
         OpenCV.Image_Processing.Apply_Threshold
           (Int32_Source, Destination, 1.0);
      end Unsupported_Depth;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "thresholding must reject an empty source Mat");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "thresholding must reject a three-dimensional source Mat");
      Assert_Raises_OpenCV_Error
        (Unsupported_Depth'Access, "thresholding must reject an Int32 source");
   end Threshold_Rejects_Invalid_Sources;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("UInt8 Binary threshold uses defaults and rebinds destination",
            UInt8_Binary_Uses_Default_Mode_And_Rebinds_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("UInt16 Binary_Inverse threshold produces exact value",
            UInt16_Binary_Inverse_Produces_Exact_Value'Access));
      Result.Add_Test
        (Caller.Create
           ("Int16 Truncate threshold produces exact value",
            Int16_Truncate_Produces_Exact_Value'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 To_Zero threshold produces exact values",
            Float32_To_Zero_Produces_Exact_Values'Access));
      Result.Add_Test
        (Caller.Create
           ("Float64 To_Zero_Inverse threshold produces exact values",
            Float64_To_Zero_Inverse_Produces_Exact_Values'Access));
      Result.Add_Test
        (Caller.Create
           ("multi-channel threshold preserves channel count",
            Multi_Channel_Threshold_Preserves_Channel_Count'Access));
      Result.Add_Test
        (Caller.Create
           ("threshold rejects invalid source Mats",
            Threshold_Rejects_Invalid_Sources'Access));
      return Result'Access;
   end Suite;

end Threshold_Tests;
