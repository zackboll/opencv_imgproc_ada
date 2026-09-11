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
   use type OpenCV.Core.Float32_Value;
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
         Border => OpenCV.Core.Replicate);

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
         Border => OpenCV.Core.Reflect);

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
         Border     => OpenCV.Core.Reflect_101);

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
         Border => OpenCV.Core.Replicate);

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
         Border => OpenCV.Core.Reflect);

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
         Border     => OpenCV.Core.Reflect_101);

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
            Border => OpenCV.Core.Wrap);
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
            Border => OpenCV.Core.Wrap);
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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
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
