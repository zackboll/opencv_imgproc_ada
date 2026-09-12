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

package body Sep_Filter_2D_Tests is

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

   function Row_Kernel_1x3
     (A, B, C : OpenCV.Core.Float32_Value) return OpenCV.Core.Mat
   is
      Kernel : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, A);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 1, B);
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 2, C);
      return Kernel;
   end Row_Kernel_1x3;

   function Column_Kernel_3x1
     (A, B, C : OpenCV.Core.Float32_Value) return OpenCV.Core.Mat
   is
      Kernel : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 1, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, A);
      OpenCV.Core.Float32_Access.Set (Kernel, 1, 0, B);
      OpenCV.Core.Float32_Access.Set (Kernel, 2, 0, C);
      return Kernel;
   end Column_Kernel_3x1;

   procedure Fill_5x5_Sequence (Source : in out OpenCV.Core.Mat) is
      Value : OpenCV.Core.Float32_Value := 1.0;
   begin
      for Row in 0 .. 4 loop
         for Column in 0 .. 4 loop
            OpenCV.Core.Float32_Access.Set (Source, Row, Column, Value);
            Value := Value + 1.0;
         end loop;
      end loop;
   end Fill_5x5_Sequence;

   procedure Float32_Identity_Rebinds_Destination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
      Kernel_X    : constant OpenCV.Core.Mat := Identity_Kernel;
      Kernel_Y    : constant OpenCV.Core.Mat := Identity_Kernel;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Source, 1, 1, 2.5);
      OpenCV.Core.Float32_Access.Set (Source, 2, 2, 4.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source, Destination, Kernel_X, Kernel_Y);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "Sep_Filter_2D must replace Destination with Source geometry"
         & " and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 1.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 1, 1) = 2.5
         and then OpenCV.Core.Float32_Access.Get (Destination, 2, 2) = 4.0,
         "identity Sep_Filter_2D must copy Float32 source pixels");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Source, 1, 1) = 2.5,
         "Sep_Filter_2D must not modify a distinct source Mat");
   end Float32_Identity_Rebinds_Destination;

   procedure Asymmetric_Kernels_Preserve_Order (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
      Kernel_X    : constant OpenCV.Core.Mat := Row_Kernel_1x3 (1.0, 2.0, 4.0);
      Kernel_Y    : constant OpenCV.Core.Mat :=
        Column_Kernel_3x1 (1.0, 3.0, 5.0);
   begin
      Fill_5x5_Sequence (Source);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source, Destination, Kernel_X, Kernel_Y);

      --  Centered 3x3 neighborhood around (2,2) is:
      --    7  8  9
      --   12 13 14
      --   17 18 19
      --  Horizontal pass with [1,2,4] then vertical [1,3,5]:
      --    row0 = 7+16+36 = 59
      --    row1 = 12+26+56 = 94
      --    row2 = 17+36+76 = 129
      --    result = 59 + 282 + 645 = 986
      --  Flipping either kernel would produce a different integer.
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 2, 2) = 986.0,
         "Sep_Filter_2D must apply unflipped Kernel_X then Kernel_Y");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 2, 2) /= 734.0
         and then OpenCV.Core.Float32_Access.Get (Destination, 2, 2) /= 734.0,
         "Sep_Filter_2D must not match a flipped-kernel result");
   end Asymmetric_Kernels_Preserve_Order;

   procedure UInt8_To_Int16_Preserves_Negative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Kernel_X    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
      Kernel_Y    : constant OpenCV.Core.Mat := Identity_Kernel;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 10);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 20);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 40);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 0, -1.0);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 1, 0.0);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 2, 1.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Destination,
         Kernel_X,
         Kernel_Y,
         OpenCV.Image_Processing.Int16_Depth,
         Border => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Int16
         and then Destination.Rows = 1
         and then Destination.Columns = 3,
         "Sep_Filter_2D must produce requested Int16 destination");
      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 0, 1) = 30,
         "Sep_Filter_2D must apply Kernel_X as an unflipped derivative");
      AUnit.Assertions.Assert
        (OpenCV.Core.Int16_Access.Get (Destination, 0, 0) = 20,
         "Sep_Filter_2D Constant_Border derivative must stay signed");
      AUnit.Assertions.Assert
        (Source.Depth = OpenCV.Core.UInt8
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 1) = 20,
         "Sep_Filter_2D must leave a distinct UInt8 source unchanged");
   end UInt8_To_Int16_Preserves_Negative;

   procedure UInt16_To_Float32_Destination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
      Destination : OpenCV.Core.Mat;
      Kernel_X    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Kernel_Y    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.UInt16_Access.Set (Source, 0, 0, 4);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 0, 2.0);
      OpenCV.Core.Float32_Access.Set (Kernel_Y, 0, 0, 3.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Destination,
         Kernel_X,
         Kernel_Y,
         OpenCV.Image_Processing.Float32_Depth);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32,
         "Sep_Filter_2D must produce requested Float32 destination");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 24.0,
         "Sep_Filter_2D must scale a UInt16 source into Float32");
   end UInt16_To_Float32_Destination;

   procedure Float64_Source_And_Kernels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
      Destination : OpenCV.Core.Mat;
      Kernel_X    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
      Kernel_Y    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
   begin
      OpenCV.Core.Float64_Access.Set (Source, 0, 0, 3.0);
      OpenCV.Core.Float64_Access.Set (Kernel_X, 0, 0, 2.0);
      OpenCV.Core.Float64_Access.Set (Kernel_Y, 0, 0, 4.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source, Destination, Kernel_X, Kernel_Y);

      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float64,
         "Sep_Filter_2D must preserve Float64 Same_Depth");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Destination, 0, 0) = 24.0,
         "Sep_Filter_2D must accept Float64 kernels");
   end Float64_Source_And_Kernels;

   procedure UInt8_C3_Channels_Are_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
      Kernel_X    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Kernel_Y    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 0, (10, 20, 30));
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 0, 2.0);
      OpenCV.Core.Float32_Access.Set (Kernel_Y, 0, 0, 1.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source, Destination, Kernel_X, Kernel_Y);

      AUnit.Assertions.Assert
        (Destination.Channels = 3
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 0)
                  = (20, 40, 60),
         "Sep_Filter_2D must apply kernels independently to C3 channels");
   end UInt8_C3_Channels_Are_Independent;

   procedure Explicit_Anchor_Indexes_Each_Kernel (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.Float32, 1));
      Centered        : OpenCV.Core.Mat;
      Explicit_Result : OpenCV.Core.Mat;
      Kernel_X        : constant OpenCV.Core.Mat :=
        Row_Kernel_1x3 (1.0, 2.0, 4.0);
      Kernel_Y        : constant OpenCV.Core.Mat :=
        Column_Kernel_3x1 (1.0, 3.0, 5.0);
      Even_X          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.Float32, 1));
      Even_Y          : constant OpenCV.Core.Mat := Identity_Kernel;
      Even_Result     : OpenCV.Core.Mat;
   begin
      Fill_5x5_Sequence (Source);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source, Centered, Kernel_X, Kernel_Y);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Explicit_Result,
         Kernel_X,
         Kernel_Y,
         Anchor => (X => 0, Y => 0));

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Centered, 2, 2) = 986.0,
         "centered Sep_Filter_2D must use the default kernel centers");
      --  Anchor (0,0) uses src(y, x) * 1 * 1 + later terms from later pixels.
      --  At (2,2): 13*1*1 + 14*2*1 + 15*4*1 + next rows 18/19/20 *3 and
      --  23/24/25 *5 = 13+28+60 + 54+114+240 + 115+240+500 = 1364.
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Explicit_Result, 2, 2) = 1364.0,
         "explicit Sep_Filter_2D Anchor.X/Y must index Kernel_X/Kernel_Y");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Centered, 2, 2)
         /= OpenCV.Core.Float32_Access.Get (Explicit_Result, 2, 2),
         "explicit Sep_Filter_2D anchor must differ from centered");

      OpenCV.Core.Float32_Access.Set (Even_X, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Even_X, 0, 1, 2.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Even_Result,
         Even_X,
         Even_Y,
         Anchor => (X => 0, Y => 0),
         Border => OpenCV.Core.Constant_Border);
      --  Even-length Kernel_X with Anchor.X = 0 at (2,2): 13*1 + 14*2 = 41.
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Even_Result, 2, 2) = 41.0,
         "Sep_Filter_2D must accept an even-length Kernel_X");
   end Explicit_Anchor_Indexes_Each_Kernel;

   procedure Offset_Is_Added_To_Result (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
      Kernel      : constant OpenCV.Core.Mat := Identity_Kernel;
   begin
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 5.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source, Destination, Kernel, Kernel, Offset => 3.0);

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 8.0,
         "Sep_Filter_2D must add Offset to the filtered result");
   end Offset_Is_Added_To_Result;

   procedure Corner_Borders_Use_Requested_Selectors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      Kernel_X         : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
      Kernel_Y         : constant OpenCV.Core.Mat := Identity_Kernel;
      Constant_Result  : OpenCV.Core.Mat;
      Replicate_Result : OpenCV.Core.Mat;
      Default_Result   : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 5.0);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 1, 0.0);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 2, 0.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Constant_Result,
         Kernel_X,
         Kernel_Y,
         Border => OpenCV.Core.Constant_Border);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source,
         Replicate_Result,
         Kernel_X,
         Kernel_Y,
         Border => OpenCV.Core.Replicate);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Source, Default_Result, Kernel_X, Kernel_Y);

      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Constant_Result, 0, 0) = 0.0
         and then OpenCV.Core.Float32_Access.Get (Replicate_Result, 0, 0)
                  = 5.0,
         "Constant_Border and Replicate must produce different"
         & " Sep_Filter_2D corners");
      AUnit.Assertions.Assert
        (Default_Result.Rows = 3
         and then Default_Result.Columns = 3
         and then Default_Result.Depth = OpenCV.Core.Float32,
         "default Reflect_101 Sep_Filter_2D must succeed");
   end Corner_Borders_Use_Requested_Selectors;

   procedure Supports_Same_Depth_In_Place (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
      Kernel_X : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));
      Kernel_Y : constant OpenCV.Core.Mat := Identity_Kernel;
   begin
      OpenCV.Core.Float32_Access.Set (Image, 0, 0, 3.0);
      OpenCV.Core.Float32_Access.Set (Image, 0, 1, 6.0);
      OpenCV.Core.Float32_Access.Set (Image, 0, 2, 9.0);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 1, 1.0);
      OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 2, 1.0);
      OpenCV.Image_Processing.Sep_Filter_2D
        (Image,
         Image,
         Kernel_X,
         Kernel_Y,
         Destination_Depth => OpenCV.Image_Processing.Same_Depth,
         Border            => OpenCV.Core.Constant_Border);

      AUnit.Assertions.Assert
        (Image.Depth = OpenCV.Core.Float32
         and then OpenCV.Core.Float32_Access.Get (Image, 0, 1) = 18.0,
         "Sep_Filter_2D must support direct Same_Depth in-place operation");
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
        OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 2));
      UInt8_Kernel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Matrix_Kernel  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Mixed_Y        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
      Valid_Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Valid_Kernel   : constant OpenCV.Core.Mat := Identity_Kernel;
      Column_X       : constant OpenCV.Core.Mat :=
        Column_Kernel_3x1 (1.0, 0.0, 0.0);
      Destination    : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Empty_Source, Destination, Valid_Kernel, Valid_Kernel);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Three_D_Source, Destination, Valid_Kernel, Valid_Kernel);
      end Non_Two_Dimensional;

      procedure Unsupported_Source_Depth is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Int32_Source, Destination, Valid_Kernel, Valid_Kernel);
      end Unsupported_Source_Depth;

      procedure Empty_Kernel_X is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source, Destination, Empty_Kernel, Valid_Kernel);
      end Empty_Kernel_X;

      procedure Empty_Kernel_Y is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source, Destination, Valid_Kernel, Empty_Kernel);
      end Empty_Kernel_Y;

      procedure Non_Two_Dimensional_Kernel_X is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source, Destination, Three_D_Kernel, Valid_Kernel);
      end Non_Two_Dimensional_Kernel_X;

      procedure Two_Channel_Kernel_X is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source, Destination, Two_Channel, Valid_Kernel);
      end Two_Channel_Kernel_X;

      procedure UInt8_Kernel_X is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source, Destination, UInt8_Kernel, Valid_Kernel);
      end UInt8_Kernel_X;

      procedure Matrix_Kernel_X is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source, Destination, Matrix_Kernel, Valid_Kernel);
      end Matrix_Kernel_X;

      procedure Mixed_Kernel_Depths is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source, Destination, Valid_Kernel, Mixed_Y);
      end Mixed_Kernel_Depths;

      procedure UInt16_To_Int16 is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (UInt16_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            OpenCV.Image_Processing.Int16_Depth);
      end UInt16_To_Int16;

      procedure Int16_To_Int16 is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Int16_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            OpenCV.Image_Processing.Int16_Depth);
      end Int16_To_Int16;

      procedure Float32_To_Float64 is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Float32_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            OpenCV.Image_Processing.Float64_Depth);
      end Float32_To_Float64;

      procedure Float64_To_Float32 is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Float64_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            OpenCV.Image_Processing.Float32_Depth);
      end Float64_To_Float32;

      procedure Negative_Anchor_X is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            (X => -1, Y => 0));
      end Negative_Anchor_X;

      procedure Negative_Anchor_Y is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            (X => 0, Y => -1));
      end Negative_Anchor_Y;

      procedure Anchor_X_Equals_Length is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Destination,
            Column_X,
            Valid_Kernel,
            (X => 3, Y => 0));
      end Anchor_X_Equals_Length;

      procedure Anchor_Y_Equals_Length is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Destination,
            Valid_Kernel,
            Column_X,
            (X => 0, Y => 3));
      end Anchor_Y_Equals_Length;

      procedure Nan_Offset is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            Offset => Value);
      end Nan_Offset;

      procedure Positive_Inf_Offset is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Infinity_Bits);
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            Offset => Value);
      end Positive_Inf_Offset;

      procedure Negative_Inf_Offset is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Neg_Inf_Bits);
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            Offset => Value);
      end Negative_Inf_Offset;

      procedure Wrap_Border is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Destination,
            Valid_Kernel,
            Valid_Kernel,
            Border => OpenCV.Core.Wrap);
      end Wrap_Border;

      procedure Depth_Changing_Alias is
      begin
         OpenCV.Image_Processing.Sep_Filter_2D
           (Valid_Source,
            Valid_Source,
            Valid_Kernel,
            Valid_Kernel,
            OpenCV.Image_Processing.Int16_Depth);
      end Depth_Changing_Alias;
   begin
      OpenCV.Core.Float64_Access.Set (Mixed_Y, 0, 0, 1.0);
      Assert_Raises_OpenCV_Error
        (Empty'Access, "Sep_Filter_2D must reject an empty source Mat");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "Sep_Filter_2D must reject a three-dimensional source Mat");
      Assert_Raises_OpenCV_Error
        (Unsupported_Source_Depth'Access,
         "Sep_Filter_2D must reject Int32 source Mats");
      Assert_Raises_OpenCV_Error
        (Empty_Kernel_X'Access, "Sep_Filter_2D must reject an empty Kernel_X");
      Assert_Raises_OpenCV_Error
        (Empty_Kernel_Y'Access, "Sep_Filter_2D must reject an empty Kernel_Y");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional_Kernel_X'Access,
         "Sep_Filter_2D must reject a three-dimensional Kernel_X");
      Assert_Raises_OpenCV_Error
        (Two_Channel_Kernel_X'Access,
         "Sep_Filter_2D must reject a two-channel Kernel_X");
      Assert_Raises_OpenCV_Error
        (UInt8_Kernel_X'Access, "Sep_Filter_2D must reject a UInt8 Kernel_X");
      Assert_Raises_OpenCV_Error
        (Matrix_Kernel_X'Access, "Sep_Filter_2D must reject a 2x2 Kernel_X");
      Assert_Raises_OpenCV_Error
        (Mixed_Kernel_Depths'Access,
         "Sep_Filter_2D must reject mixed kernel depths");
      Assert_Raises_OpenCV_Error
        (UInt16_To_Int16'Access, "Sep_Filter_2D must reject UInt16 to Int16");
      Assert_Raises_OpenCV_Error
        (Int16_To_Int16'Access, "Sep_Filter_2D must reject Int16 to Int16");
      Assert_Raises_OpenCV_Error
        (Float32_To_Float64'Access,
         "Sep_Filter_2D must reject Float32 to Float64");
      Assert_Raises_OpenCV_Error
        (Float64_To_Float32'Access,
         "Sep_Filter_2D must reject Float64 to Float32");
      Assert_Raises_OpenCV_Error
        (Negative_Anchor_X'Access,
         "Sep_Filter_2D must reject a negative Anchor.X");
      Assert_Raises_OpenCV_Error
        (Negative_Anchor_Y'Access,
         "Sep_Filter_2D must reject a negative Anchor.Y");
      Assert_Raises_OpenCV_Error
        (Anchor_X_Equals_Length'Access,
         "Sep_Filter_2D must reject Anchor.X equal to Kernel_X length");
      Assert_Raises_OpenCV_Error
        (Anchor_Y_Equals_Length'Access,
         "Sep_Filter_2D must reject Anchor.Y equal to Kernel_Y length");
      Assert_Raises_OpenCV_Error
        (Nan_Offset'Access, "Sep_Filter_2D must reject a NaN Offset");
      Assert_Raises_OpenCV_Error
        (Positive_Inf_Offset'Access, "Sep_Filter_2D must reject +Inf Offset");
      Assert_Raises_OpenCV_Error
        (Negative_Inf_Offset'Access, "Sep_Filter_2D must reject -Inf Offset");
      Assert_Raises_OpenCV_Error
        (Wrap_Border'Access, "Sep_Filter_2D must reject Wrap border");
      Assert_Raises_OpenCV_Error
        (Depth_Changing_Alias'Access,
         "Sep_Filter_2D must reject a depth-changing alias");
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
      Matrix_Kernel : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Mixed_Y       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
      Valid_Kernel  : constant OpenCV.Core.Mat := Identity_Kernel;
      Column_X      : constant OpenCV.Core.Mat :=
        Column_Kernel_3x1 (1.0, 0.0, 0.0);

      procedure Check
        (Source            : OpenCV.Core.Mat;
         Kernel_X          : OpenCV.Core.Mat;
         Kernel_Y          : OpenCV.Core.Mat;
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
            procedure Kernel_X_Input
              (Kernel_X_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Kernel_Y_Input
                 (Kernel_Y_Handle :
                    OpenCV.Core.Module_Interop.Input_Mat_Handle)
               is
                  procedure Output
                    (Destination_Handle :
                       OpenCV.Core.Module_Interop.Output_Mat_Handle) is
                  begin
                     Status :=
                       C_API.Sep_Filter_2D
                         (Source_Handle,
                          Destination_Handle,
                          Kernel_X_Handle,
                          Kernel_Y_Handle,
                          Destination_Depth,
                          Anchor_X,
                          Anchor_Y,
                          Offset,
                          Border);
                  end Output;
               begin
                  OpenCV.Core.Module_Interop.With_Output_Handle
                    (Destination, Output'Access);
               end Kernel_Y_Input;
            begin
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Kernel_Y, Kernel_Y_Input'Access);
            end Kernel_X_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Kernel_X, Kernel_X_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Sep_Filter_2D C ABI input must return"
            & " invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Sep_Filter_2D C ABI input must identify " & Diagnostic);
      end Check;

      procedure Check_Bits
        (Source            : OpenCV.Core.Mat;
         Kernel_X          : OpenCV.Core.Mat;
         Kernel_Y          : OpenCV.Core.Mat;
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
            Kernel_X,
            Kernel_Y,
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
                    C_API.Sep_Filter_2D
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_Handle,
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
            "Sep_Filter_2D C ABI (-1, -1) must accept a shared kernel");
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
                    C_API.Sep_Filter_2D
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_Handle,
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
            "depth-changing Sep_Filter_2D alias must return"
            & " invalid argument");
      end Check_Depth_Changing_Alias;

      procedure Check_Kernel_Destination_Alias
        (Use_Kernel_Y : Boolean; Message : String)
      is
         Kernel : OpenCV.Core.Mat := Identity_Kernel;
         Status : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Kernel_X_Input
              (Kernel_X_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Kernel_Y_Input
                 (Kernel_Y_Handle :
                    OpenCV.Core.Module_Interop.Input_Mat_Handle)
               is
                  procedure Output
                    (Destination_Handle :
                       OpenCV.Core.Module_Interop.Output_Mat_Handle) is
                  begin
                     Status :=
                       C_API.Sep_Filter_2D
                         (Source_Handle,
                          Destination_Handle,
                          Kernel_X_Handle,
                          Kernel_Y_Handle,
                          C_API.Derivative_Same_Depth,
                          -1,
                          -1,
                          0.0,
                          C_API.Border_Reflect_101);
                  end Output;
               begin
                  OpenCV.Core.Module_Interop.With_Output_Handle
                    (Kernel, Output'Access);
               end Kernel_Y_Input;
            begin
               if Use_Kernel_Y then
                  OpenCV.Core.Module_Interop.With_Input_Handle
                    (Kernel, Kernel_Y_Input'Access);
               else
                  OpenCV.Core.Module_Interop.With_Input_Handle
                    (Valid_Kernel, Kernel_Y_Input'Access);
               end if;
            end Kernel_X_Input;
         begin
            if Use_Kernel_Y then
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Valid_Kernel, Kernel_X_Input'Access);
            else
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Kernel, Kernel_X_Input'Access);
            end if;
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument, Message);
      end Check_Kernel_Destination_Alias;
   begin
      OpenCV.Core.Float64_Access.Set (Mixed_Y, 0, 0, 1.0);
      Check
        (UInt8_Source,
         Valid_Kernel,
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
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "kernel_x");
      Check
        (UInt8_Source,
         Valid_Kernel,
         UInt8_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "kernel_y");
      Check
        (UInt8_Source,
         Two_Channel,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "channel");
      Check
        (UInt8_Source,
         Matrix_Kernel,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "vector");
      Check
        (Three_D,
         Valid_Kernel,
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
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "kernel_x");
      Check
        (UInt8_Source,
         Valid_Kernel,
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
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         -2,
         -2,
         0.0,
         C_API.Border_Reflect_101,
         "anchor");
      Check
        (UInt8_Source,
         Column_X,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         3,
         0,
         0.0,
         C_API.Border_Reflect_101,
         "anchor");
      Check
        (UInt8_Source,
         Valid_Kernel,
         Column_X,
         C_API.Derivative_Same_Depth,
         0,
         3,
         0.0,
         C_API.Border_Reflect_101,
         "anchor");
      Check
        (UInt8_Source,
         Valid_Kernel,
         Mixed_Y,
         C_API.Derivative_Same_Depth,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "type");
      Check_Bits
        (UInt8_Source,
         Valid_Kernel,
         Valid_Kernel,
         C_API.Derivative_Same_Depth,
         NaN_Bits,
         "offset");
      Check
        (UInt8_Source,
         Valid_Kernel,
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
         Valid_Kernel,
         C_API.Derivative_Int16,
         -1,
         -1,
         0.0,
         C_API.Border_Reflect_101,
         "combination");
      Check_Success;
      Check_Depth_Changing_Alias;
      Check_Kernel_Destination_Alias
        (False, "kernel_x/destination alias must return invalid argument");
      Check_Kernel_Destination_Alias
        (True, "kernel_y/destination alias must return invalid argument");
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D Float32 identity kernels rebind destination",
            Float32_Identity_Rebinds_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D asymmetric kernels preserve coefficient order",
            Asymmetric_Kernels_Preserve_Order'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D UInt8 to Int16 preserves a signed result",
            UInt8_To_Int16_Preserves_Negative'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D UInt16 to Float32 destination",
            UInt16_To_Float32_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D Float64 source accepts Float64 kernels",
            Float64_Source_And_Kernels'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D processes UInt8 C3 channels independently",
            UInt8_C3_Channels_Are_Independent'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D explicit anchor indexes each kernel",
            Explicit_Anchor_Indexes_Each_Kernel'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D Offset is added to the result",
            Offset_Is_Added_To_Result'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D uses requested Constant and Replicate borders",
            Corner_Borders_Use_Requested_Selectors'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D supports Same_Depth in-place operation",
            Supports_Same_Depth_In_Place'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Sep_Filter_2D C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Sep_Filter_2D_Tests;
