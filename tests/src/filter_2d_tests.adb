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
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt16_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Filter_2D_Tests is

   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.Float64_Value;
   use type OpenCV.Core.Point_Coordinate;
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

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Core.Float64_Value);

   Infinity_Bits : constant Interfaces.Unsigned_64 := 16#7FF0_0000_0000_0000#;
   Neg_Inf_Bits  : constant Interfaces.Unsigned_64 := 16#FFF0_0000_0000_0000#;
   NaN_Bits      : constant Interfaces.Unsigned_64 := 16#7FF8_0000_0000_0000#;

   function Identity_Kernel return OpenCV.Core.Mat is
      Kernel : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, 1.0);
      return Kernel;
   end Identity_Kernel;

   function Asymmetric_Kernel return OpenCV.Core.Mat is
      Kernel : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 1, 2.0);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 2, 4.0);
      return Kernel;
   end Asymmetric_Kernel;

   procedure Float32_Identity_Rebinds_Destination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
      Kernel      : constant OpenCV.Core.Mat := Identity_Kernel;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Source, 1, 1, 2.5);
      OpenCV.Core.Float32_Access.Set (Source, 2, 2, 4.0);
      OpenCV.Image_Processing.Filter_2D (Source, Destination, Kernel);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "Filter_2D must replace Destination with Source geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 1.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 1, 1) = 2.5
         and then OpenCV.Core.Float32_Access.Get (Destination, 2, 2) = 4.0,
         "identity Filter_2D must copy Float32 source pixels");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Source, 1, 1) = 2.5,
         "Filter_2D must not modify a distinct source Mat");
   end Float32_Identity_Rebinds_Destination;

   procedure Asymmetric_Kernel_Is_Correlation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 5, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
      Kernel      : constant OpenCV.Core.Mat := Asymmetric_Kernel;
   begin
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 1, 2.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 2, 4.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 3, 8.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 4, 16.0);
      OpenCV.Image_Processing.Filter_2D
        (Source, Destination, Kernel, Border => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 2) = 42.0,
         "Filter_2D must apply the unflipped kernel as correlation");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 2) /= 24.0,
         "Filter_2D must not match flipped-kernel convolution");
   end Asymmetric_Kernel_Is_Correlation;

   procedure UInt8_To_Int16_Preserves_Negative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Kernel      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 10);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, -1.0);
      OpenCV.Image_Processing.Filter_2D
        (Source, Destination, Kernel, OpenCV.Image_Processing.Int16_Depth);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Int16
         and then Destination.Rows = 1
         and then Destination.Columns = 1,
         "Filter_2D must produce requested Int16 destination");
      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 0, 0) = -10,
         "Filter_2D must preserve a negative Int16 result");
      AUnit.Assertions.Assert
        (Source.Depth = OpenCV.Core.UInt8
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 10,
         "Filter_2D must leave a distinct UInt8 source unchanged");
   end UInt8_To_Int16_Preserves_Negative;

   procedure UInt16_To_Float32_Destination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
      Destination : OpenCV.Core.Mat;
      Kernel      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.UInt16_Access.Set (Source, 0, 0, 4);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, 2.0);
      OpenCV.Image_Processing.Filter_2D
        (Source, Destination, Kernel, OpenCV.Image_Processing.Float32_Depth);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32,
         "Filter_2D must produce requested Float32 destination");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 8.0,
         "Filter_2D must scale a UInt16 source into Float32");
   end UInt16_To_Float32_Destination;

   procedure Float64_Source_And_Kernel (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
      Destination : OpenCV.Core.Mat;
      Kernel      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
   begin
      OpenCV.Core.Float64_Access.Set (Source, 0, 0, 3.0);
      OpenCV.Core.Float64_Access.Set (Kernel, 0, 0, 2.0);
      OpenCV.Image_Processing.Filter_2D (Source, Destination, Kernel);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float64,
         "Filter_2D must preserve Float64 Same_Depth");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Destination, 0, 0) = 6.0,
         "Filter_2D must accept a Float64 kernel");
   end Float64_Source_And_Kernel;

   procedure UInt8_C3_Channels_Are_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
      Kernel      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 0, (10, 20, 30));
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, 2.0);
      OpenCV.Image_Processing.Filter_2D (Source, Destination, Kernel);

      AUnit.Assertions.Assert
        (Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 0)
                  = (20, 40, 60),
         "Filter_2D must apply the same kernel independently to C3 channels");
   end UInt8_C3_Channels_Are_Independent;

   procedure Explicit_Anchor_Changes_Result (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 5, (OpenCV.Core.Float32, 1));
      Centered        : OpenCV.Core.Mat;
      Explicit_Result : OpenCV.Core.Mat;
      Kernel          : constant OpenCV.Core.Mat := Asymmetric_Kernel;
   begin
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 1, 2.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 2, 4.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 3, 8.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 4, 16.0);
      OpenCV.Image_Processing.Filter_2D
        (Source, Centered, Kernel, Border => OpenCV.Core.Constant_Border);
      OpenCV.Image_Processing.Filter_2D
        (Source,
         Explicit_Result,
         Kernel,
         Anchor => (X => 0, Y => 0),
         Border => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Centered, 0, 1) = 21.0,
         "centered Filter_2D must use the default kernel center");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Explicit_Result, 0, 1) = 42.0,
         "explicit Filter_2D anchor must reach OpenCV");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Centered, 0, 1)
         /= OpenCV.Core.Float32_Access.Get (Explicit_Result, 0, 1),
         "explicit Filter_2D anchor must differ from the centered overload");
   end Explicit_Anchor_Changes_Result;

   procedure Offset_Is_Added_To_Result (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
      Kernel      : constant OpenCV.Core.Mat := Identity_Kernel;
   begin
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 5.0);
      OpenCV.Image_Processing.Filter_2D
        (Source, Destination, Kernel, Offset => 3.0);

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 8.0,
         "Filter_2D must add Offset to the filtered result");
   end Offset_Is_Added_To_Result;

   procedure Corner_Borders_Use_Requested_Selectors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Kernel           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
      Constant_Result  : OpenCV.Core.Mat;
      Replicate_Result : OpenCV.Core.Mat;
      Default_Result   : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 5.0);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 1, 0.0);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 2, 0.0);
      OpenCV.Image_Processing.Filter_2D
        (Source,
         Constant_Result,
         Kernel,
         Border => OpenCV.Core.Constant_Border);
      OpenCV.Image_Processing.Filter_2D
        (Source, Replicate_Result, Kernel, Border => OpenCV.Core.Replicate);
      OpenCV.Image_Processing.Filter_2D (Source, Default_Result, Kernel);

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Constant_Result, 0, 0) = 0.0
         and then OpenCV.Core.Float32_Access.Get (Replicate_Result, 0, 0)
                  = 5.0,
         "Constant_Border and Replicate must produce different Filter_2D"
         & " corners");
      AUnit.Assertions.Assert
        (Default_Result.Rows = 3
         and then Default_Result.Columns = 3
         and then Default_Result.Depth = OpenCV.Core.Float32,
         "default Reflect_101 Filter_2D must succeed");
   end Corner_Borders_Use_Requested_Selectors;

   procedure Supports_Same_Depth_In_Place (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Kernel : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.Float32_Access.Set (Image, 0, 0, 3.0);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, 2.0);
      OpenCV.Image_Processing.Filter_2D
        (Image,
         Image,
         Kernel,
         Destination_Depth => OpenCV.Image_Processing.Same_Depth);

      AUnit.Assertions.Assert
        (Image.Depth = OpenCV.Core.Float32
         and then OpenCV.Core.Float32_Access.Get (Image, 0, 0) = 6.0,
         "Filter_2D must support direct Same_Depth in-place operation");
   end Supports_Same_Depth_In_Place;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source   : OpenCV.Core.Mat;
      Empty_Kernel   : OpenCV.Core.Mat;
      Three_D_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Three_D_Kernel : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.Float32, 1));
      Int32_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int32, 1));
      UInt16_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Int16_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int16, 1));
      Float32_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Float64_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float64, 1));
      Two_Channel    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 2));
      UInt8_Kernel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Int16_Kernel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int16, 1));
      Valid_Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Valid_Kernel   : constant OpenCV.Core.Mat := Identity_Kernel;
      Destination    : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Empty_Source, Destination, Valid_Kernel);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Three_D_Source, Destination, Valid_Kernel);
      end Non_Two_Dimensional;

      procedure Unsupported_Source_Depth is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Int32_Source, Destination, Valid_Kernel);
      end Unsupported_Source_Depth;

      procedure Empty_Kernel_Source is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Empty_Kernel);
      end Empty_Kernel_Source;

      procedure Non_Two_Dimensional_Kernel is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Three_D_Kernel);
      end Non_Two_Dimensional_Kernel;

      procedure Two_Channel_Kernel is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Two_Channel);
      end Two_Channel_Kernel;

      procedure UInt8_Kernel_Source is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, UInt8_Kernel);
      end UInt8_Kernel_Source;

      procedure Int16_Kernel_Source is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Int16_Kernel);
      end Int16_Kernel_Source;

      procedure UInt16_To_Int16 is
      begin
         OpenCV.Image_Processing.Filter_2D
           (UInt16_Source,
            Destination,
            Valid_Kernel,
            OpenCV.Image_Processing.Int16_Depth);
      end UInt16_To_Int16;

      procedure Int16_To_Int16 is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Int16_Source,
            Destination,
            Valid_Kernel,
            OpenCV.Image_Processing.Int16_Depth);
      end Int16_To_Int16;

      procedure Float32_To_Float64 is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Float32_Source,
            Destination,
            Valid_Kernel,
            OpenCV.Image_Processing.Float64_Depth);
      end Float32_To_Float64;

      procedure Float64_To_Float32 is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Float64_Source,
            Destination,
            Valid_Kernel,
            OpenCV.Image_Processing.Float32_Depth);
      end Float64_To_Float32;

      procedure Negative_Anchor_X is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Valid_Kernel, (X => -1, Y => 0));
      end Negative_Anchor_X;

      procedure Negative_Anchor_Y is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Valid_Kernel, (X => 0, Y => -1));
      end Negative_Anchor_Y;

      procedure Anchor_X_Equals_Columns is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Valid_Kernel, (X => 1, Y => 0));
      end Anchor_X_Equals_Columns;

      procedure Anchor_Y_Equals_Rows is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Valid_Kernel, (X => 0, Y => 1));
      end Anchor_Y_Equals_Rows;

      procedure Nan_Offset is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Valid_Kernel, Offset => Value);
      end Nan_Offset;

      procedure Positive_Inf_Offset is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Infinity_Bits);
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Valid_Kernel, Offset => Value);
      end Positive_Inf_Offset;

      procedure Negative_Inf_Offset is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Neg_Inf_Bits);
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source, Destination, Valid_Kernel, Offset => Value);
      end Negative_Inf_Offset;

      procedure Wrap_Border is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source,
            Destination,
            Valid_Kernel,
            Border => OpenCV.Core.Wrap);
      end Wrap_Border;

      procedure Depth_Changing_Alias is
      begin
         OpenCV.Image_Processing.Filter_2D
           (Valid_Source,
            Valid_Source,
            Valid_Kernel,
            OpenCV.Image_Processing.Int16_Depth);
      end Depth_Changing_Alias;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "Filter_2D must reject an empty source Mat");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "Filter_2D must reject a three-dimensional source Mat");
      Assert_Raises_OpenCV_Error
        (Unsupported_Source_Depth'Access,
         "Filter_2D must reject Int32 source Mats");
      Assert_Raises_OpenCV_Error
        (Empty_Kernel_Source'Access, "Filter_2D must reject an empty kernel");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional_Kernel'Access,
         "Filter_2D must reject a three-dimensional kernel");
      Assert_Raises_OpenCV_Error
        (Two_Channel_Kernel'Access,
         "Filter_2D must reject a two-channel kernel");
      Assert_Raises_OpenCV_Error
        (UInt8_Kernel_Source'Access, "Filter_2D must reject a UInt8 kernel");
      Assert_Raises_OpenCV_Error
        (Int16_Kernel_Source'Access, "Filter_2D must reject an Int16 kernel");
      Assert_Raises_OpenCV_Error
        (UInt16_To_Int16'Access, "Filter_2D must reject UInt16 to Int16");
      Assert_Raises_OpenCV_Error
        (Int16_To_Int16'Access, "Filter_2D must reject Int16 to Int16");
      Assert_Raises_OpenCV_Error
        (Float32_To_Float64'Access,
         "Filter_2D must reject Float32 to Float64");
      Assert_Raises_OpenCV_Error
        (Float64_To_Float32'Access,
         "Filter_2D must reject Float64 to Float32");
      Assert_Raises_OpenCV_Error
        (Negative_Anchor_X'Access,
         "Filter_2D must reject a negative anchor X");
      Assert_Raises_OpenCV_Error
        (Negative_Anchor_Y'Access,
         "Filter_2D must reject a negative anchor Y");
      Assert_Raises_OpenCV_Error
        (Anchor_X_Equals_Columns'Access,
         "Filter_2D must reject an anchor X equal to kernel columns");
      Assert_Raises_OpenCV_Error
        (Anchor_Y_Equals_Rows'Access,
         "Filter_2D must reject an anchor Y equal to kernel rows");
      Assert_Raises_OpenCV_Error
        (Nan_Offset'Access, "Filter_2D must reject a NaN Offset");
      Assert_Raises_OpenCV_Error
        (Positive_Inf_Offset'Access, "Filter_2D must reject +Inf Offset");
      Assert_Raises_OpenCV_Error
        (Negative_Inf_Offset'Access, "Filter_2D must reject -Inf Offset");
      Assert_Raises_OpenCV_Error
        (Wrap_Border'Access, "Filter_2D must reject Wrap border");
      Assert_Raises_OpenCV_Error
        (Depth_Changing_Alias'Access,
         "Filter_2D must reject a depth-changing source/destination alias");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Int32_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int32, 1));
      UInt16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt16, 1));
      Three_D       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Three_D_K     : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.Float32, 1));
      UInt8_Kernel  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Two_Channel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 2));
      Valid_Kernel  : constant OpenCV.Core.Mat := Identity_Kernel;

      procedure Check
        (Source            : OpenCV.Core.Mat;
         Kernel            : OpenCV.Core.Mat;
         Destination_Depth : Interfaces.Integer_32;
         Anchor_X          : Interfaces.Integer_32;
         Anchor_Y          : Interfaces.Integer_32;
         Offset            : Interfaces.C.double;
         Border            : Interfaces.Integer_32;
         Diagnostic        : String)
      is
         pragma Suppress (Validity_Check);
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Kernel_Input
              (Kernel_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle)
               is
                  pragma Suppress (Validity_Check);
               begin
                  Status :=
                    C_API.Filter_2D
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_Handle,
                       Destination_Depth,
                       Anchor_X,
                       Anchor_Y,
                       Offset,
                       Border);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Kernel_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Kernel, Kernel_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Filter_2D C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Filter_2D C ABI input must identify " & Diagnostic);
      end Check;

      procedure Check_Bits
        (Source            : OpenCV.Core.Mat;
         Kernel            : OpenCV.Core.Mat;
         Destination_Depth : Interfaces.Integer_32;
         Offset_Bits       : Interfaces.Unsigned_64;
         Diagnostic        : String)
      is
         pragma Suppress (Validity_Check);
         Offset : Interfaces.C.double;
      begin
         Offset := Interfaces.C.double (Bits_To_Float64 (Offset_Bits));
         Check
           (Source,
            Kernel,
            Destination_Depth,
            -1,
            -1,
            Offset,
            C_API.Border_Reflect_101,
            Diagnostic);
      end Check_Bits;

      procedure Check_Success is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Kernel_Input
              (Kernel_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Filter_2D
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_Handle,
                       C_API.Derivative_Same_Depth,
                       -1,
                       -1,
                       0.0,
                       C_API.Border_Reflect_101);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Kernel_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Valid_Kernel, Kernel_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "Filter_2D C ABI (-1, -1) must be accepted as centered anchor");
      end Check_Success;

      procedure Check_Depth_Changing_Alias is
         Image  : OpenCV.Core.Mat :=
           OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
         Status : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Kernel_Input
              (Kernel_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Filter_2D
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_Handle,
                       C_API.Derivative_Int16,
                       -1,
                       -1,
                       0.0,
                       C_API.Border_Reflect_101);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Image, Output'Access);
            end Kernel_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Valid_Kernel, Kernel_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Image, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "depth-changing Filter_2D alias must return invalid argument");
      end Check_Depth_Changing_Alias;

      procedure Check_Kernel_Destination_Alias is
         Kernel : OpenCV.Core.Mat := Identity_Kernel;
         Status : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Kernel_Input
              (Kernel_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Filter_2D
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_Handle,
                       C_API.Derivative_Same_Depth,
                       -1,
                       -1,
                       0.0,
                       C_API.Border_Reflect_101);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Kernel, Output'Access);
            end Kernel_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Kernel, Kernel_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "kernel/destination Filter_2D alias must return invalid argument");
      end Check_Kernel_Destination_Alias;
   begin
      Check
        (UInt8_Source,
         Valid_Kernel,
         99,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "depth");
      Check
        (Int32_Source,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "CV_64F");
      Check
        (UInt8_Source,
         UInt8_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "kernel");
      Check
        (UInt8_Source,
         Two_Channel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "channel");
      Check
        (Three_D,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "two-dimensional");
      Check
        (UInt8_Source,
         Three_D_K,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "kernel");
      Check
        (UInt8_Source,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         0,
         0.0,
         C_API.Border_Reflect_101,
         "anchor");
      Check
        (UInt8_Source,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         0,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "anchor");
      Check
        (UInt8_Source,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -2,
         -2,
         0.0,
         C_API.Border_Reflect_101,
         "anchor");
      Check
        (UInt8_Source,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         1,
         0,
         0.0,
         C_API.Border_Reflect_101,
         "anchor");
      Check_Bits
        (UInt8_Source,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         NaN_Bits,
         "offset");
      Check
        (UInt8_Source,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         99,
         "border");
      Check
        (UInt16_Source,
         Valid_Kernel,
         C_API.Derivative_Int16,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "combination");
      Check_Success;
      Check_Depth_Changing_Alias;
      Check_Kernel_Destination_Alias;
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Filter_2D Float32 identity kernel rebinds destination",
            Float32_Identity_Rebinds_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D asymmetric kernel proves correlation",
            Asymmetric_Kernel_Is_Correlation'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D UInt8 to Int16 preserves a negative result",
            UInt8_To_Int16_Preserves_Negative'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D UInt16 to Float32 destination",
            UInt16_To_Float32_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D Float64 source accepts a Float64 kernel",
            Float64_Source_And_Kernel'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D processes UInt8 C3 channels independently",
            UInt8_C3_Channels_Are_Independent'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D explicit anchor reaches OpenCV",
            Explicit_Anchor_Changes_Result'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D Offset is added to the result",
            Offset_Is_Added_To_Result'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D uses requested Constant and Replicate borders",
            Corner_Borders_Use_Requested_Selectors'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D supports Same_Depth in-place operation",
            Supports_Same_Depth_In_Place'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Filter_2D C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Filter_2D_Tests;
