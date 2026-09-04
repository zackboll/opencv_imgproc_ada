with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;

package body Gaussian_Blur_Tests is

   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
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

   procedure Float32_Impulse_Blurs_And_Preserves_Source (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Float32_Access.Set (Source, 1, 1, 100.0);

      OpenCV.Image_Processing.Gaussian_Blur
        (Source,
         Destination,
         (Width => 3, Height => 3),
         1.0,
         OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (Destination.Rows = Source.Rows
         and then Destination.Columns = Source.Columns
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "Gaussian blur must preserve Float32 impulse geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 1, 1) < 100.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 1, 0) > 0.0,
         "Gaussian blur must spread an impulse to neighboring pixels");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Source, 1, 1) = 100.0,
         "Gaussian blur must not modify the source Mat");
   end Float32_Impulse_Blurs_And_Preserves_Source;

   procedure UInt8_Multi_Channel_Accepts_Replicate (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 0, (10, 20, 30));
      OpenCV.Image_Processing.Gaussian_Blur
        (Source,
         Destination,
         (Width => 3, Height => 3),
         1.0,
         OpenCV.Core.Replicate);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 3,
         "Gaussian blur must preserve UInt8 multi-channel element type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Source, 0, 0) = (10, 20, 30),
         "Gaussian blur must preserve multi-channel source values");
   end UInt8_Multi_Channel_Accepts_Replicate;

   procedure UInt16_Accepts_Reflect (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Gaussian_Blur
        (Source,
         Destination,
         (Width => 3, Height => 3),
         1.0,
         OpenCV.Core.Reflect);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.UInt16
         and then Destination.Channels = 1,
         "Gaussian blur must accept UInt16 with Reflect border");
   end UInt16_Accepts_Reflect;

   procedure Int16_Accepts_Reflect_101 (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int16, 2));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Gaussian_Blur
        (Source,
         Destination,
         (Width => 3, Height => 3),
         1.0,
         OpenCV.Core.Reflect_101);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Int16
         and then Destination.Channels = 2,
         "Gaussian blur must accept Int16 with Reflect_101 border");
   end Int16_Accepts_Reflect_101;

   procedure Float64_Accepts_Default_Border (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float64, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Gaussian_Blur
        (Source, Destination, (Width => 3, Height => 3), 1.0);
      AUnit.Assertions.Assert
        (Destination.Rows = 2
         and then Destination.Columns = 2
         and then Destination.Depth = OpenCV.Core.Float64
         and then Destination.Channels = 1,
         "Gaussian blur default border must accept Float64 source");
   end Float64_Accepts_Default_Border;

   procedure Gaussian_Blur_Rejects_Empty_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      procedure Attempt is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source, Destination, (Width => 3, Height => 3), 1.0);
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Gaussian blur must reject an empty source Mat");
   end Gaussian_Blur_Rejects_Empty_Source;

   procedure Gaussian_Blur_Rejects_Three_Dimensional_Source
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      procedure Attempt is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source, Destination, (Width => 3, Height => 3), 1.0);
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access,
         "Gaussian blur must reject a three-dimensional source Mat");
   end Gaussian_Blur_Rejects_Three_Dimensional_Source;

   procedure Gaussian_Blur_Rejects_Unsupported_Depth (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int32, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      procedure Attempt is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source, Destination, (Width => 3, Height => 3), 1.0);
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Gaussian blur must reject Int32 source Mats");
   end Gaussian_Blur_Rejects_Unsupported_Depth;

   procedure Gaussian_Blur_Rejects_Invalid_Kernel_And_Sigma
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      procedure Zero_Width is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source, Destination, (Width => 0, Height => 3), 1.0);
      end Zero_Width;
      procedure Zero_Height is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source, Destination, (Width => 3, Height => 0), 1.0);
      end Zero_Height;
      procedure Even_Width is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source, Destination, (Width => 2, Height => 3), 1.0);
      end Even_Width;
      procedure Even_Height is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source, Destination, (Width => 3, Height => 2), 1.0);
      end Even_Height;
      procedure Nonpositive_Sigma is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source, Destination, (Width => 3, Height => 3), 0.0);
      end Nonpositive_Sigma;
   begin
      Assert_Raises_OpenCV_Error
        (Zero_Width'Access, "Gaussian blur must reject zero kernel width");
      Assert_Raises_OpenCV_Error
        (Zero_Height'Access, "Gaussian blur must reject zero kernel height");
      Assert_Raises_OpenCV_Error
        (Even_Width'Access, "Gaussian blur must reject even kernel width");
      Assert_Raises_OpenCV_Error
        (Even_Height'Access, "Gaussian blur must reject even kernel height");
      Assert_Raises_OpenCV_Error
        (Nonpositive_Sigma'Access,
         "Gaussian blur must reject non-positive sigma");
   end Gaussian_Blur_Rejects_Invalid_Kernel_And_Sigma;

   procedure Gaussian_Blur_Rejects_Wrap_Border (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      procedure Attempt is
      begin
         OpenCV.Image_Processing.Gaussian_Blur
           (Source,
            Destination,
            (Width => 3, Height => 3),
            1.0,
            OpenCV.Core.Wrap);
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Gaussian blur must reject Wrap border");
   end Gaussian_Blur_Rejects_Wrap_Border;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur blurs Float32 impulse and preserves source",
            Float32_Impulse_Blurs_And_Preserves_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur accepts UInt8 multi-channel Replicate input",
            UInt8_Multi_Channel_Accepts_Replicate'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur accepts UInt16 Reflect input",
            UInt16_Accepts_Reflect'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur accepts Int16 Reflect_101 input",
            Int16_Accepts_Reflect_101'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur uses its default border for Float64 input",
            Float64_Accepts_Default_Border'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur rejects empty source",
            Gaussian_Blur_Rejects_Empty_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur rejects three-dimensional source",
            Gaussian_Blur_Rejects_Three_Dimensional_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur rejects unsupported depth",
            Gaussian_Blur_Rejects_Unsupported_Depth'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur rejects invalid kernels and sigma",
            Gaussian_Blur_Rejects_Invalid_Kernel_And_Sigma'Access));
      Result.Add_Test
        (Caller.Create
           ("Gaussian blur rejects Wrap border",
            Gaussian_Blur_Rejects_Wrap_Border'Access));
      return Result'Access;
   end Suite;

end Gaussian_Blur_Tests;
