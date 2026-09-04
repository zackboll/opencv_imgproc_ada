with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;

package body Color_Conversion_Tests is

   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray preserves geometry, values, and source",
            BGR_To_Gray_Preserves_Geometry_And_Source'Access));
      return Result'Access;
   end Suite;

end Color_Conversion_Tests;
