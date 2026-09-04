with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV;

package body Color_Conversion_Tests is

   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;

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

   procedure BGR_To_Gray_Preserves_Geometry_And_Source (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 0, (10, 20, 30));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 1, (255, 0, 0));

      OpenCV.Image_Processing.Convert_Color
        (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);

      AUnit.Assertions.Assert
        (Destination.Rows = Source.Rows
         and then Destination.Columns = Source.Columns
         and then Destination.Channels = 1
         and then Destination.Depth = OpenCV.Core.UInt8,
         "BGR-to-gray output must preserve geometry and have one UInt8"
         & " channel");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 22
         and then OpenCV.Core.UInt8_Access.Get (Destination, 1, 1) = 29,
         "BGR-to-gray output must use OpenCV grayscale coefficients");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Source, 0, 0) = (10, 20, 30)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Source, 1, 1)
                  = (255, 0, 0),
         "color conversion must not invalidate or modify the source Mat");
   end BGR_To_Gray_Preserves_Geometry_And_Source;

   procedure BGR_To_Gray_Rejects_BGRA_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 4));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Convert is
      begin
         OpenCV.Image_Processing.Convert_Color
           (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);
      end Convert;
   begin
      Assert_Raises_OpenCV_Error
        (Convert'Access,
         "BGR_To_Gray must reject four-channel BGRA source Mats");
   end BGR_To_Gray_Rejects_BGRA_Source;

   procedure BGR_To_Gray_Rejects_Unsupported_Depth (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int16, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Convert is
      begin
         OpenCV.Image_Processing.Convert_Color
           (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);
      end Convert;
   begin
      Assert_Raises_OpenCV_Error
        (Convert'Access,
         "BGR_To_Gray must reject unsupported source depths");
   end BGR_To_Gray_Rejects_Unsupported_Depth;

   procedure BGR_To_Gray_Rejects_Empty_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (0, 0, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Convert is
      begin
         OpenCV.Image_Processing.Convert_Color
           (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);
      end Convert;
   begin
      Assert_Raises_OpenCV_Error
        (Convert'Access, "BGR_To_Gray must reject empty source Mats");
   end BGR_To_Gray_Rejects_Empty_Source;

   procedure BGR_To_Gray_Rejects_Three_Dimensional_Source
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Convert is
      begin
         OpenCV.Image_Processing.Convert_Color
           (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);
      end Convert;
   begin
      Assert_Raises_OpenCV_Error
        (Convert'Access,
         "BGR_To_Gray must reject three-dimensional source Mats");
   end BGR_To_Gray_Rejects_Three_Dimensional_Source;

   procedure BGR_To_Gray_Accepts_UInt16_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt16, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Convert_Color
        (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);

      AUnit.Assertions.Assert
        (Destination.Rows = Source.Rows
         and then Destination.Columns = Source.Columns
         and then Destination.Depth = OpenCV.Core.UInt16
         and then Destination.Channels = 1,
         "BGR_To_Gray must accept UInt16 C3 and produce UInt16 C1");
   end BGR_To_Gray_Accepts_UInt16_Source;

   procedure BGR_To_Gray_Accepts_Float32_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Convert_Color
        (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);

      AUnit.Assertions.Assert
        (Destination.Rows = Source.Rows
         and then Destination.Columns = Source.Columns
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "BGR_To_Gray must accept Float32 C3 and produce Float32 C1");
   end BGR_To_Gray_Accepts_Float32_Source;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray preserves geometry, values, and source",
            BGR_To_Gray_Preserves_Geometry_And_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray rejects four-channel BGRA source",
            BGR_To_Gray_Rejects_BGRA_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray rejects unsupported source depth",
            BGR_To_Gray_Rejects_Unsupported_Depth'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray rejects empty source",
            BGR_To_Gray_Rejects_Empty_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray rejects three-dimensional source",
            BGR_To_Gray_Rejects_Three_Dimensional_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray accepts UInt16 source",
            BGR_To_Gray_Accepts_UInt16_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray accepts Float32 source",
            BGR_To_Gray_Accepts_Float32_Source'Access));
      return Result'Access;
   end Suite;

end Color_Conversion_Tests;
