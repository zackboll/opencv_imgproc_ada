with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Ada.Strings.Fixed;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Morphology_Tests is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Float32_Value;
   use type OpenCV.Core.UInt8_Vec3.Vector;

   package C_API renames OpenCV.Image_Processing.Internal.C_API;

   use type C_API.Status;

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

   procedure Assert_UInt8_Image
     (Image : OpenCV.Core.Mat; Data : String; Label : String) is
   begin
      for Row in 0 .. Integer (Image.Rows) - 1 loop
         for Column in 0 .. Integer (Image.Columns) - 1 loop
            declare
               Position : constant Positive :=
                 Positive (Row * Integer (Image.Columns) + Column + 1);
               Expected : constant Interfaces.Unsigned_8 :=
                 (if Data (Position) = '1' then 255 else 0);
            begin
               AUnit.Assertions.Assert
                 (OpenCV.Core.UInt8_Access.Get (Image, Row, Column) = Expected,
                  Label
                  & " differs at row"
                  & Row'Image
                  & ", column"
                  & Column'Image);
            end;
         end loop;
      end loop;
   end Assert_UInt8_Image;

   procedure Set_UInt8_Image (Image : in out OpenCV.Core.Mat; Data : String) is
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      for Row in 0 .. Integer (Image.Rows) - 1 loop
         for Column in 0 .. Integer (Image.Columns) - 1 loop
            declare
               Position : constant Positive :=
                 Positive (Row * Integer (Image.Columns) + Column + 1);
            begin
               if Data (Position) = '1' then
                  OpenCV.Core.UInt8_Access.Set (Image, Row, Column, 255);
               end if;
            end;
         end loop;
      end loop;
   end Set_UInt8_Image;

   procedure Assert_Constant_Image
     (Image : OpenCV.Core.Mat; Value : Interfaces.Unsigned_8; Label : String)
   is
   begin
      for Row in 0 .. Integer (Image.Rows) - 1 loop
         for Column in 0 .. Integer (Image.Columns) - 1 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Image, Row, Column) = Value,
               Label & " at" & Row'Image & "," & Column'Image);
         end loop;
      end loop;
   end Assert_Constant_Image;

   procedure Erosion_Region_Uses_Logical_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Source      : OpenCV.Core.Mat :=
        Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
   begin
      OpenCV.Core.Set_To (Parent, (others => 0.0));
      OpenCV.Core.Set_To (Source, (100.0, others => 0.0));
      OpenCV.Image_Processing.Erode
        (Source, Destination, (3, 3), Border => OpenCV.Reflect);
      Assert_Constant_Image (Destination, 100, "isolated erosion");
      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.UInt8,
         "distinct destination must be rebound to Region geometry and type");
      for Row in 0 .. 4 loop
         for Column in 0 .. 4 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Parent, Row, Column)
               = (if Row in 1 .. 3 and then Column in 1 .. 3 then 100 else 0),
               "erosion must preserve parent including outside Region");
         end loop;
      end loop;
   end Erosion_Region_Uses_Logical_Boundary;

   procedure Dilation_Region_Uses_Logical_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Source      : OpenCV.Core.Mat :=
        Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (200.0, others => 0.0));
      OpenCV.Core.Set_To (Source, (10.0, others => 0.0));
      OpenCV.Image_Processing.Dilate
        (Source, Destination, (3, 3), Border => OpenCV.Replicate);
      Assert_Constant_Image (Destination, 10, "isolated dilation");
      for Row in 0 .. 4 loop
         for Column in 0 .. 4 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Parent, Row, Column)
               = (if Row in 1 .. 3 and then Column in 1 .. 3 then 10 else 200),
               "dilation must not alter the parent");
         end loop;
      end loop;
   end Dilation_Region_Uses_Logical_Boundary;

   procedure Gradient_Region_Uses_Logical_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Source      : OpenCV.Core.Mat :=
        Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 0.0));
      OpenCV.Core.Set_To (Source, (100.0, others => 0.0));
      OpenCV.Image_Processing.Apply_Morphology
        (Source,
         Destination,
         OpenCV.Image_Processing.Gradient,
         (3, 3),
         Border => OpenCV.Reflect_101);
      Assert_Constant_Image (Destination, 0, "isolated gradient");
      Assert_Constant_Image (Source, 100, "gradient source Region");
   end Gradient_Region_Uses_Logical_Boundary;

   procedure In_Place_Region_Erosion_Only_Changes_View (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Parent     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Source     : OpenCV.Core.Mat :=
        Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      Standalone : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Expected   : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 0.0));
      OpenCV.Core.Set_To (Source, (100.0, others => 0.0));
      OpenCV.Core.Set_To (Standalone, (100.0, others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 200);
      OpenCV.Core.UInt8_Access.Set (Standalone, 1, 1, 200);
      OpenCV.Image_Processing.Erode
        (Standalone, Expected, (3, 3), Border => OpenCV.Reflect);
      OpenCV.Image_Processing.Erode
        (Source, Source, (3, 3), Border => OpenCV.Reflect);
      for Row in 0 .. 4 loop
         for Column in 0 .. 4 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Parent, Row, Column)
               = (if Row in 1 .. 3 and then Column in 1 .. 3
                  then
                    OpenCV.Core.UInt8_Access.Get
                      (Expected, Row - 1, Column - 1)
                  else 0),
               "in-place erosion must modify only the parent-backed view");
         end loop;
      end loop;
   end In_Place_Region_Erosion_Only_Changes_View;

   procedure Rectangle_Erosion_Uses_Defaults_And_Replaces_Destination
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.Float64, 2));
   begin
      Set_UInt8_Image (Source, "0000001110011100111000000");
      OpenCV.Image_Processing.Erode
        (Source, Destination, (Width => 3, Height => 3));

      Assert_UInt8_Image
        (Destination, "0000000000001000000000000", "rectangle erosion");
      Assert_UInt8_Image
        (Source, "0000001110011100111000000", "erosion source");
      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "erosion must replace Destination with Source geometry and type");
   end Rectangle_Erosion_Uses_Defaults_And_Replaces_Destination;

   procedure Rectangle_Dilation_Uses_Defaults (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 2, 2, 255);
      OpenCV.Image_Processing.Dilate
        (Source, Destination, (Width => 3, Height => 3));

      Assert_UInt8_Image
        (Destination, "0000001110011100111000000", "rectangle dilation");
      Assert_UInt8_Image
        (Source, "0000000000001000000000000", "dilation source");
   end Rectangle_Dilation_Uses_Defaults;

   procedure Cross_Dilation_Processes_Channels_Independently
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 1, (10, 20, 30));
      OpenCV.Image_Processing.Dilate
        (Source,
         Destination,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Cross,
         Border => OpenCV.Replicate);

      AUnit.Assertions.Assert
        (Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 0)
                  = (0, 0, 0)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 1)
                  = (10, 20, 30)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 1, 0)
                  = (10, 20, 30)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 1, 1)
                  = (10, 20, 30),
         "cross dilation must process each channel with a cross footprint");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Source, 1, 1) = (10, 20, 30),
         "multi-channel dilation must preserve Source");
   end Cross_Dilation_Processes_Channels_Independently;

   procedure Ellipse_Dilation_Uses_Elliptical_Footprint (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 255);
      OpenCV.Image_Processing.Dilate
        (Source,
         Destination,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Ellipse,
         Border => OpenCV.Reflect);

      Assert_UInt8_Image (Destination, "010111010", "ellipse dilation");
   end Ellipse_Dilation_Uses_Elliptical_Footprint;

   procedure Multiple_Iterations_Accept_Float32_And_Even_Kernel
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 5, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Source, 0, 2, 8.0);
      OpenCV.Image_Processing.Dilate
        (Source,
         Destination,
         (Width => 2, Height => 1),
         Iterations => 2,
         Border     => OpenCV.Reflect_101);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32
         and then Destination.Rows = 1
         and then Destination.Columns = 5
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 1) = 0.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 2) = 8.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 4) = 8.0,
         "two dilations with an even kernel must preserve Float32 type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Source, 0, 2) = 8.0,
         "repeated dilation must preserve Source");
   end Multiple_Iterations_Accept_Float32_And_Even_Kernel;

   procedure In_Place_Erosion_Is_Supported (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
   begin
      Set_UInt8_Image (Image, "0000001110011100111000000");
      OpenCV.Image_Processing.Erode (Image, Image, (Width => 3, Height => 3));
      Assert_UInt8_Image
        (Image, "0000000000001000000000000", "in-place erosion");
   end In_Place_Erosion_Is_Supported;

   procedure Opening_Removes_Isolated_Foreground (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.Float64, 2));
   begin
      Set_UInt8_Image (Source, "0000101110011100111000000");
      OpenCV.Image_Processing.Apply_Morphology
        (Source, Destination, OpenCV.Image_Processing.Opening, (3, 3));

      Assert_UInt8_Image
        (Destination, "0000001110011100111000000", "opening result");
      Assert_UInt8_Image
        (Source, "0000101110011100111000000", "opening source");
      AUnit.Assertions.Assert
        (Destination.Rows = 5
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "opening must replace Destination with Source geometry and type");
   end Opening_Removes_Isolated_Foreground;

   procedure Closing_Fills_A_Dark_Hole_In_Place (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt8, 1));
   begin
      Set_UInt8_Image
        (Image,
         "0000000"
         & "0000000"
         & "0011100"
         & "0010100"
         & "0011100"
         & "0000000"
         & "0000000");
      OpenCV.Image_Processing.Apply_Morphology
        (Image,
         Image,
         OpenCV.Image_Processing.Closing,
         (Width => 3, Height => 3),
         Border => OpenCV.Replicate);

      Assert_UInt8_Image
        (Image,
         "0000000"
         & "0000000"
         & "0011100"
         & "0011100"
         & "0011100"
         & "0000000"
         & "0000000",
         "in-place closing result");
   end Closing_Fills_A_Dark_Hole_In_Place;

   procedure Gradient_Produces_The_Exact_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Set_UInt8_Image
        (Source,
         "0000000"
         & "0000000"
         & "0011100"
         & "0011100"
         & "0011100"
         & "0000000"
         & "0000000");
      OpenCV.Image_Processing.Apply_Morphology
        (Source,
         Destination,
         OpenCV.Image_Processing.Gradient,
         (Width => 3, Height => 3));

      Assert_UInt8_Image
        (Destination,
         "0000000"
         & "0111110"
         & "0111110"
         & "0110110"
         & "0111110"
         & "0111110"
         & "0000000",
         "gradient result");
   end Gradient_Produces_The_Exact_Boundary;

   procedure Top_Hat_Extracts_A_Bright_Feature (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Set_UInt8_Image (Source, "0000101110011100111000000");
      OpenCV.Image_Processing.Apply_Morphology
        (Source,
         Destination,
         OpenCV.Image_Processing.Top_Hat,
         (Width => 3, Height => 3));

      Assert_UInt8_Image
        (Destination, "0000100000000000000000000", "top hat result");
   end Top_Hat_Extracts_A_Bright_Feature;

   procedure Black_Hat_Extracts_A_Dark_Feature (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 7, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Set_UInt8_Image
        (Source,
         "0000000"
         & "0000000"
         & "0011100"
         & "0010100"
         & "0011100"
         & "0000000"
         & "0000000");
      OpenCV.Image_Processing.Apply_Morphology
        (Source,
         Destination,
         OpenCV.Image_Processing.Black_Hat,
         (Width => 3, Height => 3));

      Assert_UInt8_Image
        (Destination,
         "0000000"
         & "0000000"
         & "0000000"
         & "0001000"
         & "0000000"
         & "0000000"
         & "0000000",
         "black hat result");
   end Black_Hat_Extracts_A_Dark_Feature;

   procedure Gradient_Processes_Cross_Channels_Independently
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 1, (10, 20, 30));
      OpenCV.Image_Processing.Apply_Morphology
        (Source,
         Destination,
         OpenCV.Image_Processing.Gradient,
         (Width => 3, Height => 3),
         OpenCV.Image_Processing.Cross,
         Border => OpenCV.Reflect);

      AUnit.Assertions.Assert
        (Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 1)
                  = (10, 20, 30)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 1, 0)
                  = (10, 20, 30)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 1, 1)
                  = (10, 20, 30)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 1, 2)
                  = (10, 20, 30)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 2, 1)
                  = (10, 20, 30),
         "gradient must process each channel with a cross footprint");
   end Gradient_Processes_Cross_Channels_Independently;

   procedure Top_Hat_Accepts_Float32_Even_Kernel_And_Iterations
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 5, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Source, 0, 2, 8.0);
      OpenCV.Image_Processing.Apply_Morphology
        (Source,
         Destination,
         OpenCV.Image_Processing.Top_Hat,
         (Width => 2, Height => 1),
         Iterations => 2,
         Border     => OpenCV.Reflect_101);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32
         and then Destination.Rows = 1
         and then Destination.Columns = 5
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 2) = 8.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 0, 1) = 0.0
         and then OpenCV.Core.Float32_Access.Get (Source, 0, 2) = 8.0,
         "top hat must accept Float32, even kernels, and multiple iterations");
   end Top_Hat_Accepts_Float32_Even_Kernel_And_Iterations;

   procedure Morphology_Rejects_Invalid_Sources (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Empty       : OpenCV.Core.Mat;
      Three_D     : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int32_Image : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int32, 1));
      Destination : OpenCV.Core.Mat;
      procedure Empty_Attempt is
      begin
         OpenCV.Image_Processing.Erode
           (Empty, Destination, (Width => 1, Height => 1));
      end Empty_Attempt;
      procedure Three_D_Attempt is
      begin
         OpenCV.Image_Processing.Dilate
           (Three_D, Destination, (Width => 1, Height => 1));
      end Three_D_Attempt;
      procedure Depth_Attempt is
      begin
         OpenCV.Image_Processing.Erode
           (Int32_Image, Destination, (Width => 1, Height => 1));
      end Depth_Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Empty_Attempt'Access, "morphology must reject an empty Source");
      Assert_Raises_OpenCV_Error
        (Three_D_Attempt'Access, "morphology must reject a 3-D Source");
      Assert_Raises_OpenCV_Error
        (Depth_Attempt'Access, "morphology must reject an Int32 Source");
   end Morphology_Rejects_Invalid_Sources;

   procedure Morphology_Rejects_Zero_Kernel_Dimensions (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      procedure Zero_Width is
      begin
         OpenCV.Image_Processing.Erode
           (Source, Destination, (Width => 0, Height => 1));
      end Zero_Width;
      procedure Zero_Height is
      begin
         OpenCV.Image_Processing.Dilate
           (Source, Destination, (Width => 1, Height => 0));
      end Zero_Height;
   begin
      Assert_Raises_OpenCV_Error
        (Zero_Width'Access, "erosion must reject zero kernel width");
      Assert_Raises_OpenCV_Error
        (Zero_Height'Access, "dilation must reject zero kernel height");
   end Morphology_Rejects_Zero_Kernel_Dimensions;

   procedure Morphology_Rejects_Wrap_Border (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      procedure Attempt is
      begin
         OpenCV.Image_Processing.Dilate
           (Source,
            Destination,
            (Width => 1, Height => 1),
            Border => OpenCV.Wrap);
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "morphology must reject Wrap border");
   end Morphology_Rejects_Wrap_Border;

   procedure Apply_Morphology_Rejects_Wrap_Border (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      procedure Attempt is
      begin
         OpenCV.Image_Processing.Apply_Morphology
           (Source,
            Destination,
            OpenCV.Image_Processing.Opening,
            (Width => 1, Height => 1),
            Border => OpenCV.Wrap);
      end Attempt;
   begin
      Assert_Raises_OpenCV_Error
        (Attempt'Access, "Apply_Morphology must reject Wrap border");
   end Apply_Morphology_Rejects_Wrap_Border;

   procedure C_ABI_Rejects_Nonpositive_Primitives (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;

      type C_Operation is (Erosion, Dilation);

      procedure Check
        (Operation     : C_Operation;
         Kernel_Width  : Interfaces.Integer_32;
         Kernel_Height : Interfaces.Integer_32;
         Iterations    : Interfaces.Integer_32;
         Diagnostic    : String)
      is
         Status : C_API.Status := C_API.Success;

         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               case Operation is
                  when Erosion  =>
                     Status :=
                       C_API.Erode
                         (Source_Handle,
                          Destination_Handle,
                          Kernel_Width,
                          Kernel_Height,
                          C_API.Morphology_Rectangle,
                          Iterations,
                          C_API.Border_Constant);

                  when Dilation =>
                     Status :=
                       C_API.Dilate
                         (Source_Handle,
                          Destination_Handle,
                          Kernel_Width,
                          Kernel_Height,
                          C_API.Morphology_Rectangle,
                          Iterations,
                          C_API.Border_Constant);
               end case;
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);

         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed morphology C input must return invalid argument");

         declare
            Message : constant String := C_API.Last_Error_Message;
         begin
            AUnit.Assertions.Assert
              (Ada.Strings.Fixed.Index (Message, Diagnostic) /= 0,
               "malformed morphology C input must identify " & Diagnostic);
         end;
      end Check;
   begin
      Check (Erosion, 0, 1, 1, "width");
      Check (Dilation, 1, 0, 1, "height");
      Check (Erosion, 1, 1, 0, "iterations");
      Check (Dilation, -1, 1, 1, "width");
   end C_ABI_Rejects_Nonpositive_Primitives;

   procedure C_ABI_Rejects_Malformed_Morphology_Operation
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Status      : C_API.Status := C_API.Success;

      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              C_API.Morphology_Ex
                (Source_Handle,
                 Destination_Handle,
                 99,
                 1,
                 1,
                 C_API.Morphology_Rectangle,
                 1,
                 C_API.Border_Constant);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "malformed morphology operation must return invalid argument");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "operation") /= 0,
         "malformed morphology operation must identify operation");
   end C_ABI_Rejects_Malformed_Morphology_Operation;

   procedure Custom_Masks_And_Anchors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Mask   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Result : OpenCV.Core.Mat;
      Other  : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 2, 2, 90);
      OpenCV.Core.Set_To (Mask, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 1);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 0, 1);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 1);
      Dilate (Source, Result, Mask);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Result, 3, 3) = 0,
         "sparse kernel must not become a rectangle");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Result, 2, 3) = 90,
         "sparse kernel must include the left neighbor");
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 255);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 0, 255);
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 255);
      Dilate (Source, Other, Mask);
      for Row in 0 .. 4 loop
         for Col in 0 .. 4 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Result, Row, Col)
               = OpenCV.Core.UInt8_Access.Get (Other, Row, Col),
               "nonzero magnitude must not weight pixels");
         end loop;
      end loop;
      Dilate (Source, Other, Mask, Anchor => (0, 0));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Other, 2, 2) = 0,
         "custom anchor shifts neighborhood");
      Dilate (Source, Other, (3, 3), Cross, (0, 0));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Other, 2, 2) = 90,
         "Cross mask uses explicit anchor as its intersection");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Other, 1, 1) = 0,
         "off-center Cross must not reuse centered mask");
      Dilate (Source, Other, (3, 3), Rectangle, (0, 0));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Other, 3, 3) = 0,
         "off-center rectangle anchor shifts footprint");
   end Custom_Masks_And_Anchors;

   procedure Custom_Validation_And_Border (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      Image  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Mask   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Result : OpenCV.Core.Mat;
      procedure Empty_Erode is
      begin
         Erode (Image, Result, Mask);
      end Empty_Erode;
      procedure Empty_Dilate is
      begin
         Dilate (Image, Result, Mask);
      end Empty_Dilate;
      procedure Empty_Opening is
      begin
         Apply_Morphology (Image, Result, Opening, Mask);
      end Empty_Opening;
      procedure Overlap is
      begin
         Erode (Image, Mask, Mask);
      end Overlap;
      procedure Bad_Anchor is
      begin
         Dilate (Image, Result, Mask, (3, 0));
      end Bad_Anchor;
      procedure Overflow is
      begin
         Erode (Image, Result, (3, 3), Iterations => 1_073_741_825);
      end Overflow;
      procedure Sentinel is
         Max : constant Long_Float := Long_Float (OpenCV.Float64_Value'Last);
         V   : constant Morphology_Border_Value :=
           Explicit_Morphology_Border ((others => Max));
         pragma Unreferenced (V);
      begin
         null;
      end Sentinel;
   begin
      OpenCV.Core.Set_To (Image, (100.0, others => 0.0));
      OpenCV.Core.Set_To (Mask, (others => 0.0));
      Assert_Raises_OpenCV_Error (Empty_Erode'Access, "empty erosion kernel");
      Assert_Raises_OpenCV_Error
        (Empty_Dilate'Access, "empty dilation kernel");
      Assert_Raises_OpenCV_Error
        (Empty_Opening'Access, "empty opening kernel");
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 1);
      Assert_Raises_OpenCV_Error
        (Overlap'Access, "kernel/destination overlap");
      Assert_Raises_OpenCV_Error (Bad_Anchor'Access, "anchor outside kernel");
      Assert_Raises_OpenCV_Error (Overflow'Access, "iteration expansion");
      Assert_Raises_OpenCV_Error (Sentinel'Access, "reserved sentinel");
      Erode (Image, Result, (3, 3));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Result, 0, 0) = 100,
         "default erosion border must be neutral");
      Erode
        (Image,
         Result,
         (3, 3),
         Border_Value => Explicit_Morphology_Border ((others => 0.0)));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Result, 0, 0) = 0,
         "explicit zero erosion border lowers edge");
      Dilate
        (Image,
         Result,
         (3, 3),
         Border_Value =>
           Explicit_Morphology_Border ((Component_0 => 300.0, others => 0.0)));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Result, 0, 0) = 255,
         "integer border saturates rather than wraps");
      Erode (Image, Result, (1, 1), Iterations => 2_147_483_647);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Result, 0, 0) = 100,
         "1x1 early exit with huge iteration count");
   end Custom_Validation_And_Border;

   procedure Custom_Region_And_Dispatch (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      Parent     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Source     : OpenCV.Core.Mat :=
        Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      Standalone : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      K_Parent   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Kernel     : OpenCV.Core.Mat :=
        K_Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      Expected   : OpenCV.Core.Mat;
      Output     : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 0.0));
      OpenCV.Core.Set_To (Source, (100.0, others => 0.0));
      OpenCV.Core.Set_To (Standalone, (100.0, others => 0.0));
      OpenCV.Core.Set_To (K_Parent, (255.0, others => 0.0));
      OpenCV.Core.Set_To (Kernel, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Kernel, 1, 1, 1);
      OpenCV.Core.UInt8_Access.Set (Kernel, 0, 1, 1);
      OpenCV.Core.UInt8_Access.Set (Kernel, 1, 0, 1);
      Erode (Standalone, Expected, Kernel, Border => OpenCV.Replicate);
      Erode (Source, Source, Kernel, Border => OpenCV.Replicate);
      for Row in 0 .. 4 loop
         for Col in 0 .. 4 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Parent, Row, Col)
               = (if Row in 1 .. 3 and then Col in 1 .. 3
                  then
                    OpenCV.Core.UInt8_Access.Get (Expected, Row - 1, Col - 1)
                  else 0),
               "custom Region isolation and in-place mutation");
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (K_Parent, Row, Col)
               = (if Row in 1 .. 3 and then Col in 1 .. 3
                  then OpenCV.Core.UInt8_Access.Get (Kernel, Row - 1, Col - 1)
                  else 255),
               "kernel parent stays unchanged");
         end loop;
      end loop;
      for Op in Morphology_Operation loop
         Apply_Morphology (Standalone, Output, Op, Kernel);
         AUnit.Assertions.Assert
           (not Output.Is_Empty, "every custom operation dispatches");
      end loop;
   end Custom_Region_And_Dispatch;

   procedure Raw_Zero_Kernel (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Kernel : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Output : OpenCV.Core.Mat;
      Status : C_API.Status;
      procedure Input (S : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure K_Input (K : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            procedure Dest (D : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
            begin
               Status :=
                 C_API.Morphology_Request
                   (S,
                    D,
                    0,
                    1,
                    K,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    C_API.Border_Constant,
                    0,
                    null);
            end Dest;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Output, Dest'Access);
         end K_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Kernel, K_Input'Access);
      end Input;
   begin
      OpenCV.Core.Set_To (Kernel, (others => 0.0));
      OpenCV.Core.Module_Interop.With_Input_Handle (Image, Input'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "raw all-zero kernel must be rejected");
   end Raw_Zero_Kernel;

   procedure Border_Floats_And_Iterations (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      F32    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      F64    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float64, 1));
      Output : OpenCV.Core.Mat;
      Mask   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      procedure Too_Large is
      begin
         Erode
           (F32,
            Output,
            (3, 3),
            Border_Value =>
              Explicit_Morphology_Border
                ((Component_0 => Long_Float'Last, others => 0.0)));
      end Too_Large;
      procedure Custom_Overflow is
      begin
         Erode (F32, Output, Mask, Iterations => 1_073_741_825);
      end Custom_Overflow;
   begin
      OpenCV.Core.Set_To (F32, (10.0, others => 0.0));
      OpenCV.Core.Set_To (F64, (10.0, others => 0.0));
      OpenCV.Core.Set_To (Mask, (1.0, others => 0.0));
      Assert_Raises_OpenCV_Error (Too_Large'Access, "Float32 overflow border");
      Assert_Raises_OpenCV_Error
        (Custom_Overflow'Access, "custom full-mask expansion");
      Erode
        (F32,
         Output,
         (3, 3),
         Border_Value =>
           Explicit_Morphology_Border ((Component_0 => 2.5, others => 0.0)));
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Output, 0, 0) = 2.5,
         "Float32 explicit border");
      Erode
        (F64,
         Output,
         (3, 3),
         Border_Value =>
           Explicit_Morphology_Border ((Component_0 => 2.5, others => 0.0)));
      OpenCV.Core.Set_To (Mask, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 1);
      Erode (F32, Output, Mask, Iterations => 3);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Output, 0, 0) = 10.0,
         "sparse iterations do not collapse as a full rectangle");
   end Border_Floats_And_Iterations;

   procedure Overlapping_Regions_And_Custom_In_Place (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      Parent          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      K               : constant OpenCV.Core.Mat :=
        Parent.Region ((X => 0, Y => 0, Width => 3, Height => 3));
      D               : OpenCV.Core.Mat :=
        Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      Distinct_Kernel : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Image           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Expected        : OpenCV.Core.Mat;
      procedure Bad is
      begin
         Dilate (Image, D, K);
      end Bad;
   begin
      OpenCV.Core.Set_To (Parent, (1.0, others => 0.0));
      OpenCV.Core.Set_To (Distinct_Kernel, (1.0, others => 0.0));
      OpenCV.Core.Set_To (Image, (20.0, others => 0.0));
      Assert_Raises_OpenCV_Error (Bad'Access, "overlapping kernel Region");
      Dilate (Image, Expected, Distinct_Kernel);
      Dilate (Image, Image, Distinct_Kernel);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Image, 1, 1)
         = OpenCV.Core.UInt8_Access.Get (Expected, 1, 1),
         "custom in-place dilation");
      Erode (Image, Expected, Distinct_Kernel);
      Erode (Image, Image, Distinct_Kernel);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Image, 1, 1)
         = OpenCV.Core.UInt8_Access.Get (Expected, 1, 1),
         "custom in-place erosion");
      Apply_Morphology (Image, Expected, Opening, Distinct_Kernel);
      Apply_Morphology (Image, Image, Opening, Distinct_Kernel);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Image, 1, 1)
         = OpenCV.Core.UInt8_Access.Get (Expected, 1, 1),
         "custom in-place opening");
   end Overlapping_Regions_And_Custom_In_Place;

   procedure Multichannel_Explicit_Border (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use OpenCV.Image_Processing;
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      Output : OpenCV.Core.Mat;
      Value  : OpenCV.Core.UInt8_Vec3.Vector;
   begin
      OpenCV.Core.Set_To (Source, (10.0, 20.0, 30.0, 0.0));
      Dilate
        (Source,
         Output,
         (3, 3),
         Border_Value => Explicit_Morphology_Border ((40.0, 50.0, 60.0, 0.0)));
      Value := OpenCV.Core.UInt8_Vec3_Access.Get (Output, 0, 0);
      AUnit.Assertions.Assert
        (Value (0) = 40 and then Value (1) = 50 and then Value (2) = 60,
         "C3 explicit border maps components independently");
   end Multichannel_Explicit_Border;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("custom masks and anchors", Custom_Masks_And_Anchors'Access));
      Result.Add_Test
        (Caller.Create
           ("custom validation and explicit borders",
            Custom_Validation_And_Border'Access));
      Result.Add_Test
        (Caller.Create
           ("custom Region and operations",
            Custom_Region_And_Dispatch'Access));
      Result.Add_Test
        (Caller.Create ("raw all-zero kernel", Raw_Zero_Kernel'Access));
      Result.Add_Test
        (Caller.Create
           ("float borders and iterations",
            Border_Floats_And_Iterations'Access));
      Result.Add_Test
        (Caller.Create
           ("custom overlapping Regions and in-place",
            Overlapping_Regions_And_Custom_In_Place'Access));
      Result.Add_Test
        (Caller.Create
           ("C3 explicit border", Multichannel_Explicit_Border'Access));
      Result.Add_Test
        (Caller.Create
           ("erosion Region uses logical boundary",
            Erosion_Region_Uses_Logical_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("dilation Region uses logical boundary",
            Dilation_Region_Uses_Logical_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("gradient Region uses logical boundary",
            Gradient_Region_Uses_Logical_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("in-place Region erosion only changes view",
            In_Place_Region_Erosion_Only_Changes_View'Access));
      Result.Add_Test
        (Caller.Create
           ("rectangle erosion uses defaults and replaces destination",
            Rectangle_Erosion_Uses_Defaults_And_Replaces_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("rectangle dilation uses defaults",
            Rectangle_Dilation_Uses_Defaults'Access));
      Result.Add_Test
        (Caller.Create
           ("cross dilation processes channels independently",
            Cross_Dilation_Processes_Channels_Independently'Access));
      Result.Add_Test
        (Caller.Create
           ("ellipse dilation uses elliptical footprint",
            Ellipse_Dilation_Uses_Elliptical_Footprint'Access));
      Result.Add_Test
        (Caller.Create
           ("multiple iterations accept Float32 and an even kernel",
            Multiple_Iterations_Accept_Float32_And_Even_Kernel'Access));
      Result.Add_Test
        (Caller.Create
           ("in-place erosion is supported",
            In_Place_Erosion_Is_Supported'Access));
      Result.Add_Test
        (Caller.Create
           ("opening removes isolated foreground",
            Opening_Removes_Isolated_Foreground'Access));
      Result.Add_Test
        (Caller.Create
           ("closing fills a dark hole in place",
            Closing_Fills_A_Dark_Hole_In_Place'Access));
      Result.Add_Test
        (Caller.Create
           ("gradient produces the exact boundary",
            Gradient_Produces_The_Exact_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("top hat extracts a bright feature",
            Top_Hat_Extracts_A_Bright_Feature'Access));
      Result.Add_Test
        (Caller.Create
           ("black hat extracts a dark feature",
            Black_Hat_Extracts_A_Dark_Feature'Access));
      Result.Add_Test
        (Caller.Create
           ("gradient processes cross channels independently",
            Gradient_Processes_Cross_Channels_Independently'Access));
      Result.Add_Test
        (Caller.Create
           ("top hat accepts Float32 even kernel and iterations",
            Top_Hat_Accepts_Float32_Even_Kernel_And_Iterations'Access));
      Result.Add_Test
        (Caller.Create
           ("morphology rejects invalid sources",
            Morphology_Rejects_Invalid_Sources'Access));
      Result.Add_Test
        (Caller.Create
           ("morphology rejects zero kernel dimensions",
            Morphology_Rejects_Zero_Kernel_Dimensions'Access));
      Result.Add_Test
        (Caller.Create
           ("morphology rejects Wrap border",
            Morphology_Rejects_Wrap_Border'Access));
      Result.Add_Test
        (Caller.Create
           ("Apply_Morphology rejects Wrap border",
            Apply_Morphology_Rejects_Wrap_Border'Access));
      Result.Add_Test
        (Caller.Create
           ("morphology C ABI rejects nonpositive primitive inputs",
            C_ABI_Rejects_Nonpositive_Primitives'Access));
      Result.Add_Test
        (Caller.Create
           ("morphology C ABI rejects malformed operation",
            C_ABI_Rejects_Malformed_Morphology_Operation'Access));
      return Result'Access;
   end Suite;

end Morphology_Tests;
