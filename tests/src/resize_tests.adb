with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

package body Resize_Tests is

   use type Interfaces.Unsigned_8;
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

   procedure Nearest_Neighbor_Resizes_And_Preserves_Source
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 10);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 20);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 0, 30);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 40);

      OpenCV.Image_Processing.Resize
        (Source,
         Destination,
         (Width => 4, Height => 4),
         OpenCV.Image_Processing.Nearest_Neighbor);

      AUnit.Assertions.Assert
        (Destination.Rows = 4
         and then Destination.Columns = 4
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "nearest-neighbor resize must produce the requested geometry and"
         & " type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 10
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 2) = 20
         and then OpenCV.Core.UInt8_Access.Get (Destination, 2, 0) = 30
         and then OpenCV.Core.UInt8_Access.Get (Destination, 3, 3) = 40,
         "nearest-neighbor resize must select deterministic source pixels");
      AUnit.Assertions.Assert
        (Source.Rows = 2
         and then Source.Columns = 2
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 10
         and then OpenCV.Core.UInt8_Access.Get (Source, 1, 1) = 40,
         "resize must not invalidate or modify the source Mat");
   end Nearest_Neighbor_Resizes_And_Preserves_Source;

   procedure Linear_Resizes_And_Preserves_Element_Type (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt16, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Resize
        (Source, Destination, (Width => 5, Height => 4));

      AUnit.Assertions.Assert
        (Destination.Rows = 4
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.UInt16
         and then Destination.Channels = 3,
         "linear resize must preserve source depth and channel count");
      AUnit.Assertions.Assert
        (Source.Rows = 2
         and then Source.Columns = 3
         and then Source.Depth = OpenCV.Core.UInt16
         and then Source.Channels = 3,
         "linear resize must leave the source Mat valid and unchanged");
   end Linear_Resizes_And_Preserves_Element_Type;

   procedure Cubic_Resizes_Int16_And_Preserves_Element_Type
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Int16, 2));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Resize
        (Source,
         Destination,
         (Width => 5, Height => 4),
         OpenCV.Image_Processing.Cubic);

      AUnit.Assertions.Assert
        (Destination.Rows = 4
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.Int16
         and then Destination.Channels = 2,
         "cubic resize must preserve Int16 depth and channel count");
   end Cubic_Resizes_Int16_And_Preserves_Element_Type;

   procedure Area_Downsizes_Float32_And_Preserves_Element_Type
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 6, (OpenCV.Core.Float32, 4));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Resize
        (Source,
         Destination,
         (Width => 3, Height => 2),
         OpenCV.Image_Processing.Area);

      AUnit.Assertions.Assert
        (Destination.Rows = 2
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 4,
         "area downsize must preserve Float32 depth and channel count");
   end Area_Downsizes_Float32_And_Preserves_Element_Type;

   procedure Lanczos_4_Resizes_Float64_And_Preserves_Element_Type
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float64, 2));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Resize
        (Source,
         Destination,
         (Width => 5, Height => 4),
         OpenCV.Image_Processing.Lanczos_4);

      AUnit.Assertions.Assert
        (Destination.Rows = 4
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.Float64
         and then Destination.Channels = 2,
         "Lanczos_4 resize must preserve Float64 depth and channel count");
   end Lanczos_4_Resizes_Float64_And_Preserves_Element_Type;

   procedure Resize_Rejects_Empty_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Attempt is
      begin
         OpenCV.Image_Processing.Resize
           (Source, Destination, (Width => 1, Height => 1));
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Resize must reject an empty source Mat");
   end Resize_Rejects_Empty_Source;

   procedure Resize_Rejects_Zero_Width (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Attempt is
      begin
         OpenCV.Image_Processing.Resize
           (Source, Destination, (Width => 0, Height => 1));
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Resize must reject a zero output width");
   end Resize_Rejects_Zero_Width;

   procedure Resize_Rejects_Zero_Height (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Attempt is
      begin
         OpenCV.Image_Processing.Resize
           (Source, Destination, (Width => 1, Height => 0));
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Resize must reject a zero output height");
   end Resize_Rejects_Zero_Height;

   procedure Resize_Rejects_Unsupported_Depth (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int32, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Attempt is
      begin
         OpenCV.Image_Processing.Resize
           (Source, Destination, (Width => 1, Height => 1));
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Resize must reject an unsupported source depth");
   end Resize_Rejects_Unsupported_Depth;

   procedure Resize_Rejects_Three_Dimensional_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Attempt is
      begin
         OpenCV.Image_Processing.Resize
           (Source, Destination, (Width => 1, Height => 1));
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Resize must reject a three-dimensional source Mat");
   end Resize_Rejects_Three_Dimensional_Source;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Nearest-neighbor resize preserves source and type",
            Nearest_Neighbor_Resizes_And_Preserves_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Linear resize preserves source element type",
            Linear_Resizes_And_Preserves_Element_Type'Access));
      Result.Add_Test
        (Caller.Create
           ("Cubic resize preserves Int16 element type",
            Cubic_Resizes_Int16_And_Preserves_Element_Type'Access));
      Result.Add_Test
        (Caller.Create
           ("Area downsize preserves Float32 element type",
            Area_Downsizes_Float32_And_Preserves_Element_Type'Access));
      Result.Add_Test
        (Caller.Create
           ("Lanczos_4 resize preserves Float64 element type",
            Lanczos_4_Resizes_Float64_And_Preserves_Element_Type'Access));
      Result.Add_Test
        (Caller.Create
           ("Resize rejects empty source",
            Resize_Rejects_Empty_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Resize rejects zero output width",
            Resize_Rejects_Zero_Width'Access));
      Result.Add_Test
        (Caller.Create
           ("Resize rejects zero output height",
            Resize_Rejects_Zero_Height'Access));
      Result.Add_Test
        (Caller.Create
           ("Resize rejects unsupported depth",
            Resize_Rejects_Unsupported_Depth'Access));
      Result.Add_Test
        (Caller.Create
           ("Resize rejects three-dimensional source",
            Resize_Rejects_Three_Dimensional_Source'Access));
      return Result'Access;
   end Suite;

end Resize_Tests;
