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
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt16_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Histogram_Analysis_Tests is

   --  Negative-path tests deliberately hold NaN and Infinity in floating
   --  variables so they can reach the public API and the raw ABI.
   pragma Suppress (Validity_Check);

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.C.double;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Mat_Size;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;

   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   package U8 renames OpenCV.Core.UInt8_Access;
   package U16 renames OpenCV.Core.UInt16_Access;
   package F32 renames OpenCV.Core.Float32_Access;
   use type C_API.Status;
   use type IP.Histogram_Dimension;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_32, OpenCV.Float32_Value);
   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, OpenCV.Float64_Value);

   function NaN32 return OpenCV.Float32_Value is
      pragma Suppress (Range_Check);
   begin
      return Bits_To_Float32 (16#7FC0_0000#);
   end NaN32;

   function Infinity32 return OpenCV.Float32_Value is
      pragma Suppress (Range_Check);
   begin
      return Bits_To_Float32 (16#7F80_0000#);
   end Infinity32;

   function NaN64 return OpenCV.Float64_Value is
      pragma Suppress (Range_Check);
   begin
      return Bits_To_Float64 (16#7FF8_0000_0000_0000#);
   end NaN64;

   function Infinity64 return OpenCV.Float64_Value is
      pragma Suppress (Range_Check);
   begin
      return Bits_To_Float64 (16#7FF0_0000_0000_0000#);
   end Infinity64;

   function Gray (Value : Long_Float) return OpenCV.Scalar
   is ((Component_0 => Value, others => 0.0));

   function Filled
     (Rows, Columns : Natural;
      Kind          : OpenCV.Core.Mat_Type;
      Value         : OpenCV.Scalar := Gray (0.0)) return OpenCV.Core.Mat
   is
      Image : OpenCV.Core.Mat := OpenCV.Core.Create (Rows, Columns, Kind);
   begin
      OpenCV.Core.Set_To (Image, Value);
      return Image;
   end Filled;

   --  A genuine 2 x 2 x 2 UInt8 C1 Mat.
   function Cube return OpenCV.Core.Mat
   is (OpenCV.Core.Create
         (OpenCV.Core.Dimension_Array'(2, 2, 2), (OpenCV.Core.UInt8, 1)));

   --  A 1 x N UInt8 C1 image holding Values in order.
   function Row8 (Values : OpenCV.Core.Dimension_Array) return OpenCV.Core.Mat
   is
      Image  : OpenCV.Core.Mat :=
        Filled (1, Values'Length, (OpenCV.Core.UInt8, 1));
      Column : Natural := 0;
   begin
      for Value of Values loop
         U8.Set (Image, 0, Column, Interfaces.Unsigned_8 (Value));
         Column := Column + 1;
      end loop;
      return Image;
   end Row8;

   function Dimension
     (Bins         : Positive;
      Lower, Upper : OpenCV.Float32_Value;
      Channel      : Natural := 0) return IP.Histogram_Dimension
   is ((Channel     => Channel,
        Bin_Count   => Bins,
        Lower_Bound => Lower,
        Upper_Bound => Upper));

   --  Bin Index (zero-based) of a one-dimensional histogram.
   function Bin (Value : IP.Histogram; Index : Natural) return Long_Float
   is (Long_Float (F32.Get (IP.Histogram_Values (Value), Index, 0)));

   function Same (Left, Right : OpenCV.Core.Mat) return Boolean
   is (Left.Rows = Right.Rows
       and then Left.Columns = Right.Columns
       and then OpenCV.Core.Count_Non_Zero
                  (OpenCV.Core.Reshape (OpenCV.Core.Abs_Diff (Left, Right), 1))
                = 0);

   function Near
     (Left, Right : Long_Float; Tolerance : Long_Float := 1.0e-6)
      return Boolean
   is (abs (Left - Right) <= Tolerance);

   procedure Assert_Raises
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
   end Assert_Raises;

   procedure Assert_Invalid (Status : C_API.Status; Fragment, Message : String)
   is
   begin
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment)
                  /= 0,
         Message & " (diagnostic: " & C_API.Last_Error_Message & ")");
   end Assert_Invalid;

   --  A C3 UInt8 image whose pixels are the listed (B, G, R) triples on one
   --  row.
   type Pixel_Array is
     array (Positive range <>) of OpenCV.Core.UInt8_Vec3.Vector;

   function Row_C3 (Pixels : Pixel_Array) return OpenCV.Core.Mat is
      Image  : OpenCV.Core.Mat :=
        Filled (1, Pixels'Length, (OpenCV.Core.UInt8, 3));
      Column : Natural := 0;
   begin
      for Pixel of Pixels loop
         OpenCV.Core.UInt8_Vec3_Access.Set (Image, 0, Column, Pixel);
         Column := Column + 1;
      end loop;
      return Image;
   end Row_C3;

   Quarters : constant IP.Histogram_Dimension := Dimension (4, 0.0, 256.0);

   procedure UInt8_Exact_Counts (Test : in out Fixture) is
      pragma Unreferenced (Test);
      H : constant IP.Histogram :=
        IP.Calculate_Histogram
          (Row8 ((0, 0, 10, 49, 50, 99, 100, 200)),
           (1 => Dimension (4, 0.0, 100.0)));
      V : constant OpenCV.Core.Mat := IP.Histogram_Values (H);
   begin
      AUnit.Assertions.Assert
        (V.Depth = OpenCV.Core.Float32
         and then V.Channels = 1
         and then V.Rows = 4
         and then V.Columns = 1,
         "a 1-D histogram is a Float32 C1 Bin_Count x 1 Mat");
      AUnit.Assertions.Assert
        (Bin (H, 0) = 3.0
         and then Bin (H, 1) = 1.0
         and then Bin (H, 2) = 1.0
         and then Bin (H, 3) = 1.0,
         "each 25-wide bin holds its exact count; 100 and 200 are ignored");
   end UInt8_Exact_Counts;

   procedure Range_Boundaries (Test : in out Fixture) is
      pragma Unreferenced (Test);
      H : constant IP.Histogram :=
        IP.Calculate_Histogram
          (Row8 ((9, 10, 10, 14, 15, 19, 20, 21)),
           (1 => Dimension (2, 10.0, 20.0)));
   begin
      AUnit.Assertions.Assert
        (Bin (H, 0) = 3.0, "values on the lower bound are counted");
      AUnit.Assertions.Assert
        (Bin (H, 1) = 2.0,
         "the upper bound and values outside the range are ignored");
   end Range_Boundaries;

   procedure UInt16_Histogram (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat := Filled (1, 4, (OpenCV.Core.UInt16, 1));
      H      : IP.Histogram;
   begin
      U16.Set (Source, 0, 0, 1_000);
      U16.Set (Source, 0, 1, 30_000);
      U16.Set (Source, 0, 2, 40_000);
      U16.Set (Source, 0, 3, 65_535);
      H := IP.Calculate_Histogram (Source, (1 => Dimension (2, 0.0, 65536.0)));
      AUnit.Assertions.Assert
        (Bin (H, 0) = 2.0 and then Bin (H, 1) = 2.0,
         "UInt16 samples are counted over the full 16-bit range");
   end UInt16_Histogram;

   procedure Float32_Histogram (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat := Filled (1, 6, (OpenCV.Core.Float32, 1));
      Values : constant array (0 .. 5) of OpenCV.Float32_Value :=
        (-1.5, 0.0, 0.49, 0.5, 0.99, 1.0);
      H      : IP.Histogram;
   begin
      for Column in Values'Range loop
         F32.Set (Source, 0, Column, Values (Column));
      end loop;
      H := IP.Calculate_Histogram (Source, (1 => Dimension (2, 0.0, 1.0)));
      AUnit.Assertions.Assert
        (Bin (H, 0) = 2.0 and then Bin (H, 1) = 2.0,
         "Float32 samples use [0, 1); -1.5 and 1.0 are ignored");
   end Float32_Histogram;

   procedure Channel_Selection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat :=
        Row_C3 (((10, 20, 30), (10, 20, 30), (10, 20, 30), (200, 20, 30)));
      Blue   : constant IP.Histogram :=
        IP.Calculate_Histogram (Source, (1 => Dimension (8, 0.0, 256.0, 0)));
      Red    : constant IP.Histogram :=
        IP.Calculate_Histogram (Source, (1 => Dimension (8, 0.0, 256.0, 2)));
   begin
      AUnit.Assertions.Assert
        (Bin (Blue, 0) = 3.0 and then Bin (Blue, 6) = 1.0,
         "channel 0 counts the blue samples");
      AUnit.Assertions.Assert
        (Bin (Red, 0) = 4.0 and then Bin (Red, 6) = 0.0,
         "channel 2 counts only the red samples");
   end Channel_Selection;

   Joint_Source : constant Pixel_Array :=
     ((10, 20, 0), (10, 200, 0), (200, 200, 0), (200, 200, 0));

   procedure Joint_2D (Test : in out Fixture) is
      pragma Unreferenced (Test);
      H : constant IP.Histogram :=
        IP.Calculate_Histogram
          (Row_C3 (Joint_Source),
           (Dimension (2, 0.0, 256.0, 0), Dimension (2, 0.0, 256.0, 1)));
      V : constant OpenCV.Core.Mat := IP.Histogram_Values (H);
   begin
      AUnit.Assertions.Assert
        (V.Rows = 2 and then V.Columns = 2,
         "a 2-D histogram is bins0 x bins1");
      AUnit.Assertions.Assert
        (F32.Get (V, 0, 0) = 1.0
         and then F32.Get (V, 0, 1) = 1.0
         and then F32.Get (V, 1, 0) = 0.0
         and then F32.Get (V, 1, 1) = 2.0,
         "joint bins count channel pairs");
   end Joint_2D;

   procedure Joint_3D (Test : in out Fixture) is
      pragma Unreferenced (Test);
      H : constant IP.Histogram :=
        IP.Calculate_Histogram
          (Row_C3 (((10, 20, 30), (10, 20, 230), (200, 20, 230))),
           (Dimension (2, 0.0, 256.0, 0),
            Dimension (2, 0.0, 256.0, 1),
            Dimension (2, 0.0, 256.0, 2)));
      V : constant OpenCV.Core.Mat := IP.Histogram_Values (H);
   begin
      AUnit.Assertions.Assert
        (V.Dimension_Count = 3 and then V.Total = 8,
         "a 3-D histogram is an N-D Mat with one extent per dimension");
      AUnit.Assertions.Assert
        (F32.Get (V, (0, 0, 0)) = 1.0
         and then F32.Get (V, (0, 0, 1)) = 1.0
         and then F32.Get (V, (1, 0, 1)) = 1.0
         and then F32.Get (V, (1, 1, 1)) = 0.0,
         "3-D bins are indexed in dimension order");
   end Joint_3D;

   procedure Ten_Dimensions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Axes : constant IP.Histogram_Dimension_Array (1 .. 10) :=
        (others => Dimension (2, 0.0, 256.0));
      H    : constant IP.Histogram :=
        IP.Calculate_Histogram (Row8 ((5, 200, 7)), Axes);
      V    : constant OpenCV.Core.Mat := IP.Histogram_Values (H);
   begin
      AUnit.Assertions.Assert
        (IP.Histogram_Dimension_Count (H) = IP.Maximum_Histogram_Dimensions
         and then V.Dimension_Count = 10
         and then V.Total = 1_024,
         "the portable maximum of ten dimensions is supported");
      AUnit.Assertions.Assert
        (F32.Get (V, (1 .. 10 => 0)) = 2.0
         and then F32.Get (V, (1 .. 10 => 1)) = 1.0,
         "a channel repeated in every dimension lands on the diagonal");
   end Ten_Dimensions;

   procedure Arbitrary_Lower_Bound (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Axes : constant IP.Histogram_Dimension_Array (7 .. 8) :=
        (Dimension (2, 0.0, 256.0, 0), Dimension (2, 0.0, 256.0, 1));
      H    : constant IP.Histogram :=
        IP.Calculate_Histogram (Row_C3 (Joint_Source), Axes);
      V    : constant OpenCV.Core.Mat := IP.Histogram_Values (H);
   begin
      AUnit.Assertions.Assert
        (IP.Get_Histogram_Dimension (H, 1) = Axes (7)
         and then IP.Get_Histogram_Dimension (H, 2) = Axes (8),
         "metadata is renumbered from 1 in iteration order");
      AUnit.Assertions.Assert
        (F32.Get (V, 1, 1) = 2.0 and then F32.Get (V, 0, 1) = 1.0,
         "an array indexed 7 .. 8 produces the same joint counts");
   end Arbitrary_Lower_Bound;

   function Sample8 return OpenCV.Core.Mat
   is (Row8 ((0, 10, 70, 80, 130, 140, 200, 250)));

   procedure Masked_Histogram (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : constant OpenCV.Core.Mat := Sample8;
      Original : constant OpenCV.Core.Mat := Source.Clone;
      All_On   : constant OpenCV.Core.Mat :=
        Filled (1, 8, (OpenCV.Core.UInt8, 1), Gray (7.0));
      Partial  : OpenCV.Core.Mat := Filled (1, 8, (OpenCV.Core.UInt8, 1));
      Copy     : OpenCV.Core.Mat;
      Full     : constant IP.Histogram :=
        IP.Calculate_Histogram (Source, (1 => Quarters));
      Masked   : IP.Histogram;
   begin
      Masked := IP.Calculate_Histogram (Source, All_On, (1 => Quarters));
      AUnit.Assertions.Assert
        (Same (IP.Histogram_Values (Masked), IP.Histogram_Values (Full)),
         "an all-nonzero mask equals the unmasked histogram");

      U8.Set (Partial, 0, 0, 1);
      U8.Set (Partial, 0, 2, 255);
      U8.Set (Partial, 0, 3, 9);
      U8.Set (Partial, 0, 7, 1);
      Copy := Partial.Clone;
      Masked := IP.Calculate_Histogram (Source, Partial, (1 => Quarters));
      AUnit.Assertions.Assert
        (Bin (Masked, 0) = 1.0
         and then Bin (Masked, 1) = 2.0
         and then Bin (Masked, 2) = 0.0
         and then Bin (Masked, 3) = 1.0,
         "only pixels under nonzero mask values are counted");
      AUnit.Assertions.Assert
        (Same (Source, Original) and then Same (Partial, Copy),
         "Source and Mask are unchanged");

      --  Read-only aliasing between Source and Mask is accepted.
      Masked := IP.Calculate_Histogram (Source, Source, (1 => Quarters));
      AUnit.Assertions.Assert
        (Bin (Masked, 0) = 1.0, "a mask aliasing Source excludes only 0");
   end Masked_Histogram;

   procedure Region_Histogram (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : constant OpenCV.Core.Mat :=
        Filled (4, 6, (OpenCV.Core.UInt8, 1));
      View   : OpenCV.Core.Mat;
      H      : IP.Histogram;
   begin
      View :=
        OpenCV.Core.Region (Parent, (X => 1, Y => 1, Width => 3, Height => 2));
      OpenCV.Core.Set_To (View, Gray (200.0));
      H := IP.Calculate_Histogram (View, (1 => Quarters));
      AUnit.Assertions.Assert
        (Bin (H, 3) = 6.0 and then Bin (H, 0) = 0.0,
         "a Region view is counted as the whole image");
   end Region_Histogram;

   procedure Metadata_And_Clone (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Axis   : constant IP.Histogram_Dimension := Dimension (4, 0.0, 256.0, 1);
      H      : constant IP.Histogram :=
        IP.Calculate_Histogram (Row_C3 (Joint_Source), (1 => Axis));
      Copy   : constant IP.Histogram := H;
      Values : OpenCV.Core.Mat := IP.Histogram_Values (H);
      Empty  : IP.Histogram;

      procedure Bad_Index is
         Unused : constant IP.Histogram_Dimension :=
           IP.Get_Histogram_Dimension (H, 2);
      begin
         null;
      end Bad_Index;
   begin
      AUnit.Assertions.Assert
        (IP.Histogram_Dimension_Count (H) = 1
         and then IP.Get_Histogram_Dimension (H, 1) = Axis
         and then IP.Histogram_Dimension_Count (Empty) = 0,
         "metadata accessors return the stored dimensions");
      Assert_Raises (Bad_Index'Access, "an invalid dimension index fails");

      F32.Set (Values, 0, 0, 99.0);
      AUnit.Assertions.Assert
        (Bin (H, 0) = 1.0 and then Bin (Copy, 0) = 1.0,
         "modifying the Histogram_Values clone leaves the histogram intact");
      AUnit.Assertions.Assert
        (IP.Histogram_Values (Empty).Is_Empty,
         "an empty histogram yields an empty Mat");
   end Metadata_And_Clone;

   procedure Invalid_Calculation_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Sample8;
      Mask   : constant OpenCV.Core.Mat :=
        Filled (1, 8, (OpenCV.Core.UInt8, 1), Gray (1.0));

      procedure Try
        (Image : OpenCV.Core.Mat; Axes : IP.Histogram_Dimension_Array)
      is
         Unused : constant IP.Histogram :=
           IP.Calculate_Histogram (Image, Axes);
      begin
         null;
      end Try;

      procedure Try_Mask (Image : OpenCV.Core.Mat) is
         Unused : constant IP.Histogram :=
           IP.Calculate_Histogram (Source, Image, (1 => Quarters));
      begin
         null;
      end Try_Mask;

      procedure Empty_Source is
         Empty : OpenCV.Core.Mat;
      begin
         Try (Empty, (1 => Quarters));
      end Empty_Source;

      procedure N_D_Source is
      begin
         Try (Cube, (1 => Quarters));
      end N_D_Source;

      procedure Int16_Source is
      begin
         Try (Filled (2, 2, (OpenCV.Core.Int16, 1)), (1 => Quarters));
      end Int16_Source;

      procedure Float64_Source is
      begin
         Try (Filled (2, 2, (OpenCV.Core.Float64, 1)), (1 => Quarters));
      end Float64_Source;

      procedure No_Dimensions is
         None : constant IP.Histogram_Dimension_Array (1 .. 0) :=
           (others => Quarters);
      begin
         Try (Source, None);
      end No_Dimensions;

      procedure Eleven_Dimensions is
      begin
         Try (Source, (1 .. 11 => Dimension (1, 0.0, 256.0)));
      end Eleven_Dimensions;

      procedure Bad_Channel is
      begin
         Try (Source, (1 => Dimension (4, 0.0, 256.0, 1)));
      end Bad_Channel;

      procedure NaN_Range is
      begin
         Try (Source, (1 => Dimension (4, NaN32, 256.0)));
      end NaN_Range;

      procedure Infinite_Range is
      begin
         Try (Source, (1 => Dimension (4, 0.0, Infinity32)));
      end Infinite_Range;

      procedure Equal_Bounds is
      begin
         Try (Source, (1 => Dimension (4, 5.0, 5.0)));
      end Equal_Bounds;

      procedure Reversed_Bounds is
      begin
         Try (Source, (1 => Dimension (4, 9.0, 5.0)));
      end Reversed_Bounds;

      procedure Huge_Product is
      begin
         Try (Source, (1 .. 2 => Dimension (65_536, 0.0, 256.0)));
      end Huge_Product;

      procedure Float32_Mask is
      begin
         Try_Mask (Filled (1, 8, (OpenCV.Core.Float32, 1)));
      end Float32_Mask;

      procedure C3_Mask is
      begin
         Try_Mask (Filled (1, 8, (OpenCV.Core.UInt8, 3)));
      end C3_Mask;

      procedure Wrong_Geometry_Mask is
      begin
         Try_Mask (Filled (1, 7, (OpenCV.Core.UInt8, 1)));
      end Wrong_Geometry_Mask;

      procedure Empty_Mask is
         Empty : OpenCV.Core.Mat;
      begin
         Try_Mask (Empty);
      end Empty_Mask;
   begin
      Assert_Raises (Empty_Source'Access, "an empty source is rejected");
      Assert_Raises (N_D_Source'Access, "an N-D source is rejected");
      Assert_Raises (Int16_Source'Access, "Int16 is unsupported");
      Assert_Raises (Float64_Source'Access, "Float64 is unsupported");
      Assert_Raises (No_Dimensions'Access, "zero dimensions are rejected");
      Assert_Raises
        (Eleven_Dimensions'Access, "11 dimensions exceed the portable limit");
      Assert_Raises (Bad_Channel'Access, "a missing channel is rejected");
      Assert_Raises (NaN_Range'Access, "a NaN bound is rejected");
      Assert_Raises (Infinite_Range'Access, "an infinite bound is rejected");
      Assert_Raises (Equal_Bounds'Access, "lower = upper is rejected");
      Assert_Raises (Reversed_Bounds'Access, "lower > upper is rejected");
      Assert_Raises
        (Huge_Product'Access, "a bin product beyond native int is rejected");
      Assert_Raises (Float32_Mask'Access, "a Float32 mask is rejected");
      Assert_Raises (C3_Mask'Access, "a three-channel mask is rejected");
      Assert_Raises
        (Wrong_Geometry_Mask'Access, "a mismatched mask is rejected");
      Assert_Raises (Empty_Mask'Access, "an empty mask is rejected");
      AUnit.Assertions.Assert
        (Mask.Rows = 1, "the valid mask fixture is untouched");
   end Invalid_Calculation_Inputs;

   function Record_Of
     (Bins    : Interfaces.Integer_32;
      Lower   : Interfaces.C.C_float;
      Upper   : Interfaces.C.C_float;
      Channel : Interfaces.Integer_32 := 0)
      return C_API.Histogram_Dimension_Record
   is ((Channel     => Channel,
        Bin_Count   => Bins,
        Lower_Bound => Lower,
        Upper_Bound => Upper));

   Good_Record : constant C_API.Histogram_Dimension_Record :=
     Record_Of (4, 0.0, 256.0);

   No_Mat : OpenCV.Core.Mat;

   --  Raw calcHist on Source into Output (optionally masked). A null
   --  dimension pointer is passed when Records is empty.
   function Raw_Calc
     (Source  : OpenCV.Core.Mat;
      Records : C_API.Histogram_Dimension_Records;
      Count   : Interfaces.Integer_32;
      Output  : in out OpenCV.Core.Mat;
      Mask    : OpenCV.Core.Mat := No_Mat;
      Masked  : Boolean := False) return C_API.Status
   is
      Local  : aliased constant C_API.Histogram_Dimension_Records := Records;
      Status : C_API.Status := C_API.Success;

      function First return access constant C_API.Histogram_Dimension_Record
      is (if Local'Length = 0 then null else Local (Local'First)'Access);

      procedure On_Source
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure On_Output
           (Output_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure On_Mask
              (Mask_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            begin
               Status :=
                 C_API.Calc_Hist_Masked
                   (Source_Handle, Mask_Handle, First, Count, Output_Handle);
            end On_Mask;
         begin
            if Masked then
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Mask, On_Mask'Access);
            else
               Status :=
                 C_API.Calc_Hist (Source_Handle, First, Count, Output_Handle);
            end if;
         end On_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Output, On_Output'Access);
      end On_Source;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, On_Source'Access);
      return Status;
   end Raw_Calc;

   function Marker return OpenCV.Core.Mat
   is (Filled (1, 1, (OpenCV.Core.UInt16, 2)));

   function Is_Marker (Image : OpenCV.Core.Mat) return Boolean
   is (Image.Depth = OpenCV.Core.UInt16
       and then Image.Channels = 2
       and then Image.Rows = 1);

   NaN_F : constant Interfaces.C.C_float := Interfaces.C.C_float (NaN32);
   Inf_F : constant Interfaces.C.C_float := Interfaces.C.C_float (Infinity32);

   procedure Raw_Calculation_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Sample8;
      Output : OpenCV.Core.Mat := Marker;
      One    : constant C_API.Histogram_Dimension_Records :=
        (1 => Good_Record);
      None   : C_API.Histogram_Dimension_Records (1 .. 0);

      procedure Expect (Status : C_API.Status; Fragment, Message : String) is
      begin
         Assert_Invalid (Status, Fragment, Message);
         AUnit.Assertions.Assert
           (Is_Marker (Output), Message & ": output must be unchanged");
      end Expect;

      procedure Expect_Failure (Status : C_API.Status; Message : String) is
      begin
         AUnit.Assertions.Assert (Status /= C_API.Success, Message);
         AUnit.Assertions.Assert
           (Is_Marker (Output), Message & ": output must be unchanged");
      end Expect_Failure;

      function One_Record
        (Bins         : Interfaces.Integer_32;
         Lower, Upper : Interfaces.C.C_float;
         Channel      : Interfaces.Integer_32 := 0) return C_API.Status
      is (Raw_Calc
            (Source,
             (1 => Record_Of (Bins, Lower, Upper, Channel)),
             1,
             Output));
   begin
      Expect
        (Raw_Calc (Source, (1 .. 11 => Record_Of (1, 0.0, 256.0)), 11, Output),
         "1 .. 10",
         "the raw ABI rejects 11 dimensions");
      Expect (Raw_Calc (Source, One, 0, Output), "1 .. 10", "count 0 fails");
      Expect (Raw_Calc (Source, One, -1, Output), "1 .. 10", "count -1 fails");
      Expect (Raw_Calc (Source, None, 1, Output), "null", "null dimensions");
      Expect (One_Record (0, 0.0, 256.0), "positive", "zero bins");
      Expect (One_Record (-4, 0.0, 256.0), "positive", "negative bins");
      Expect (One_Record (4, NaN_F, 256.0), "finite", "NaN range");
      Expect (One_Record (4, 0.0, Inf_F), "finite", "infinite range");
      Expect (One_Record (4, 5.0, 5.0), "lower < upper", "equal bounds");
      Expect (One_Record (4, 9.0, 5.0), "lower < upper", "reversed bounds");
      Expect
        (One_Record (1_000_000, 0.0, 1.0e-30),
         "scaling",
         "a range whose native bin scaling overflows int");
      Expect
        (Raw_Calc
           (Source, (1 .. 2 => Record_Of (65_536, 0.0, 256.0)), 2, Output),
         "product",
         "a bin product beyond native int");
      Expect
        (Raw_Calc (Cube, One, 1, Output), "two-dimensional", "an N-D source");
      Expect (One_Record (4, 0.0, 256.0, 1), "channel", "missing channel");
      Expect (One_Record (4, 0.0, 256.0, -1), "channel", "negative channel");
      AUnit.Assertions.Assert
        (Raw_Calc
           (Row_C3 (((10, 20, 30), (10, 20, 30))),
            (1 => Record_Of (4, 0.0, 256.0, 2)),
            1,
            Output)
         = C_API.Success
         and then F32.Get (Output, 0, 0) = 2.0,
         "the last valid raw channel succeeds");
      Output := Marker;
      Expect
        (Raw_Calc (Filled (2, 2, (OpenCV.Core.Float64, 1)), One, 1, Output),
         "depth",
         "a Float64 source is rejected by the raw ABI");
      Expect_Failure
        (Raw_Calc
           (Source,
            One,
            1,
            Output,
            Filled (1, 8, (OpenCV.Core.Float32, 1)),
            Masked => True),
         "a Float32 mask is rejected by OpenCV");
      Expect_Failure
        (Raw_Calc
           (Source,
            One,
            1,
            Output,
            Filled (1, 7, (OpenCV.Core.UInt8, 1)),
            Masked => True),
         "a mismatched mask is rejected by OpenCV");
      AUnit.Assertions.Assert
        (Raw_Calc (Source, One, 1, Output) = C_API.Success
         and then Output.Rows = 4
         and then Output.Columns = 1
         and then Output.Depth = OpenCV.Core.Float32,
         "a valid raw call publishes the bins x 1 Float32 histogram");
   end Raw_Calculation_Validation;

   Halves : constant IP.Histogram_Dimension := Dimension (2, 0.0, 256.0);

   --  Two-bin histograms: A = [3, 1], B = [2, 2], C = [1, 3].
   function Hist_A return IP.Histogram
   is (IP.Calculate_Histogram (Row8 ((0, 0, 0, 200)), (1 => Halves)));
   function Hist_B return IP.Histogram
   is (IP.Calculate_Histogram (Row8 ((0, 0, 200, 200)), (1 => Halves)));
   function Hist_C return IP.Histogram
   is (IP.Calculate_Histogram (Row8 ((0, 200, 200, 200)), (1 => Halves)));

   function Compare
     (Left, Right : IP.Histogram; Method : IP.Histogram_Comparison_Method)
      return Long_Float
   is (Long_Float (IP.Compare_Histograms (Left, Right, Method)));

   procedure Compare_Identical (Test : in out Fixture) is
      pragma Unreferenced (Test);
      A : constant IP.Histogram := Hist_A;
   begin
      AUnit.Assertions.Assert
        (Near (Compare (A, A, IP.Correlation), 1.0),
         "identical correlation is 1");
      AUnit.Assertions.Assert
        (Near (Compare (A, A, IP.Chi_Square), 0.0)
         and then Near (Compare (A, A, IP.Alternative_Chi_Square), 0.0),
         "identical chi-square distances are 0");
      AUnit.Assertions.Assert
        (Near (Compare (A, A, IP.Hellinger_Distance), 0.0, 1.0e-4),
         "identical Hellinger distance is 0");
      AUnit.Assertions.Assert
        (Near (Compare (A, A, IP.Kullback_Leibler_Divergence), 0.0),
         "identical KL divergence is 0");
      AUnit.Assertions.Assert
        (Compare (A, A, IP.Intersection) = 4.0,
         "identical intersection equals the histogram mass");
   end Compare_Identical;

   procedure Compare_Different (Test : in out Fixture) is
      pragma Unreferenced (Test);
      A : constant IP.Histogram := Hist_A;
      B : constant IP.Histogram := Hist_B;
      C : constant IP.Histogram := Hist_C;
   begin
      AUnit.Assertions.Assert
        (Near (Compare (A, C, IP.Correlation), -1.0),
         "mirrored distributions are perfectly anti-correlated");
      AUnit.Assertions.Assert
        (Near (Compare (A, B, IP.Chi_Square), 4.0 / 3.0)
         and then Near (Compare (B, A, IP.Chi_Square), 1.0),
         "chi-square is asymmetric: Left is the denominator");
      AUnit.Assertions.Assert
        (Near
           (Compare (A, B, IP.Alternative_Chi_Square), 2.0 * (0.2 + 1.0 / 3.0))
         and then Near
                    (Compare (A, B, IP.Alternative_Chi_Square),
                     Compare (B, A, IP.Alternative_Chi_Square)),
         "alternative chi-square is 2 * sum (d^2 / (a + b)) and symmetric");
      AUnit.Assertions.Assert
        (Near
           (Compare (A, B, IP.Kullback_Leibler_Divergence),
            3.0 * 0.405_465_108_108_164_4 - 0.693_147_180_559_945_3)
         and then Near
                    (Compare (B, A, IP.Kullback_Leibler_Divergence),
                     -2.0 * 0.405_465_108_108_164_4
                     + 2.0 * 0.693_147_180_559_945_3),
         "KL divergence matches sum (p log (p / q)) and is asymmetric");
      AUnit.Assertions.Assert
        (Compare (A, B, IP.Intersection) = 3.0,
         "intersection sums bin minima and is not normalized");
      AUnit.Assertions.Assert
        (Compare (A, B, IP.Hellinger_Distance)
         < Compare (A, C, IP.Hellinger_Distance),
         "a closer distribution has a smaller Hellinger distance");
   end Compare_Different;

   procedure Compare_Compatibility (Test : in out Fixture) is
      pragma Unreferenced (Test);
      A     : constant IP.Histogram := Hist_A;
      Other : IP.Histogram;
      Empty : IP.Histogram;

      procedure Try is
         Unused : constant Long_Float := Compare (A, Other, IP.Intersection);
      begin
         null;
      end Try;

      procedure Try_Empty is
         Unused : constant Long_Float := Compare (Empty, A, IP.Intersection);
      begin
         null;
      end Try_Empty;
   begin
      Other :=
        IP.Calculate_Histogram
          (Row_C3 (((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 200))),
           (1 => Dimension (2, 0.0, 256.0, 2)));
      AUnit.Assertions.Assert
        (Compare (A, Other, IP.Intersection) = 4.0,
         "histograms from different channels are comparable");
      Other :=
        IP.Calculate_Histogram
          (Row_C3 (Joint_Source), (Halves, Dimension (2, 0.0, 256.0, 1)));
      Assert_Raises (Try'Access, "different dimensionality is rejected");
      Other :=
        IP.Calculate_Histogram
          (Row8 ((0, 0)), (1 => Dimension (3, 0.0, 256.0)));
      Assert_Raises (Try'Access, "a different bin count is rejected");
      Other :=
        IP.Calculate_Histogram
          (Row8 ((0, 0)), (1 => Dimension (2, 0.0, 128.0)));
      Assert_Raises (Try'Access, "a different upper bound is rejected");
      Other :=
        IP.Calculate_Histogram
          (Row8 ((0, 0)), (1 => Dimension (2, 1.0, 256.0)));
      Assert_Raises (Try'Access, "a different lower bound is rejected");
      Assert_Raises (Try_Empty'Access, "an empty histogram is rejected");
      AUnit.Assertions.Assert
        (Bin (A, 0) = 3.0 and then Bin (A, 1) = 1.0,
         "comparison does not modify the histograms");
   end Compare_Compatibility;

   Raw_Result : aliased Interfaces.C.double := 0.0;

   function Raw_Compare
     (Left, Right : OpenCV.Core.Mat;
      Method      : Interfaces.Integer_32;
      Null_Result : Boolean := False) return C_API.Status
   is
      Status : C_API.Status := C_API.Success;

      procedure On_Left
        (Left_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure On_Right
           (Right_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status :=
              C_API.Compare_Hist
                (Left_Handle,
                 Right_Handle,
                 Method,
                 (if Null_Result then null else Raw_Result'Access));
         end On_Right;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Right, On_Right'Access);
      end On_Left;
   begin
      Raw_Result := 42.0;
      OpenCV.Core.Module_Interop.With_Input_Handle (Left, On_Left'Access);
      if Status /= C_API.Success and then not Null_Result then
         AUnit.Assertions.Assert
           (Raw_Result = 0.0, "a failed raw comparison must zero the result");
      end if;
      return Status;
   end Raw_Compare;

   procedure Raw_Compare_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      A     : constant OpenCV.Core.Mat := IP.Histogram_Values (Hist_A);
      Short : constant OpenCV.Core.Mat :=
        Filled (3, 1, (OpenCV.Core.Float32, 1));
      Wide  : constant OpenCV.Core.Mat :=
        Filled (1, 2, (OpenCV.Core.Float32, 1));
      F64   : constant OpenCV.Core.Mat :=
        Filled (2, 1, (OpenCV.Core.Float64, 1));
      Empty : OpenCV.Core.Mat;
   begin
      Assert_Invalid
        (Raw_Compare (A, A, 6), "method", "an unknown method is rejected");
      Assert_Invalid
        (Raw_Compare (A, A, -1), "method", "a negative method is rejected");
      Assert_Invalid
        (Raw_Compare (A, F64, C_API.Histogram_Compare_Intersection),
         "Float32",
         "a Float64 histogram is rejected");
      Assert_Invalid
        (Raw_Compare (A, Short, C_API.Histogram_Compare_Intersection),
         "shape",
         "a shorter second histogram would be over-read");
      Assert_Invalid
        (Raw_Compare (A, Wide, C_API.Histogram_Compare_Intersection),
         "shape",
         "a transposed histogram is rejected");
      Assert_Invalid
        (Raw_Compare (A, Empty, C_API.Histogram_Compare_Intersection),
         "nonempty",
         "an empty histogram is rejected");
      Assert_Invalid
        (Raw_Compare
           (A, A, C_API.Histogram_Compare_Intersection, Null_Result => True),
         "null",
         "a null result pointer is rejected");
      AUnit.Assertions.Assert
        (Raw_Compare (A, A, C_API.Histogram_Compare_Intersection)
         = C_API.Success
         and then Raw_Result = 4.0,
         "a valid raw comparison succeeds");
   end Raw_Compare_Validation;

   procedure Back_Project_UInt8 (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Model    : constant IP.Histogram :=
        IP.Calculate_Histogram (Sample8, (1 => Quarters));
      --  Bins: [2, 2, 2, 2]. Query 5 -> bin 0, 150 -> bin 2.
      Query    : constant OpenCV.Core.Mat := Row8 ((5, 150, 255));
      Original : constant OpenCV.Core.Mat := Query.Clone;
      Before   : constant OpenCV.Core.Mat := IP.Histogram_Values (Model);
      Result   : constant OpenCV.Core.Mat := IP.Back_Project (Query, Model);
      Scaled   : constant OpenCV.Core.Mat :=
        IP.Back_Project (Query, Model, 50.0);
      Negative : constant OpenCV.Core.Mat :=
        IP.Back_Project (Query, Model, -3.0);
      Huge     : constant OpenCV.Core.Mat :=
        IP.Back_Project (Query, Model, 1.0e30);
   begin
      AUnit.Assertions.Assert
        (Result.Depth = OpenCV.Core.UInt8
         and then Result.Channels = 1
         and then Result.Rows = 1
         and then Result.Columns = 3,
         "back projection keeps source geometry and depth, with one channel");
      AUnit.Assertions.Assert
        (U8.Get (Result, 0, 0) = 2
         and then U8.Get (Result, 0, 1) = 2
         and then U8.Get (Result, 0, 2) = 2,
         "each pixel receives its bin count");
      AUnit.Assertions.Assert
        (U8.Get (Scaled, 0, 0) = 100, "Scale multiplies the bin value");
      AUnit.Assertions.Assert
        (U8.Get (Negative, 0, 0) = 0 and then U8.Get (Huge, 0, 0) = 255,
         "integer results saturate for negative and huge scales");
      AUnit.Assertions.Assert
        (Same (Query, Original)
         and then Same (IP.Histogram_Values (Model), Before),
         "Source and histogram are unchanged");
   end Back_Project_UInt8;

   procedure Back_Project_Channels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Row_C3 (Joint_Source);
      Red    : constant IP.Histogram :=
        IP.Calculate_Histogram
          (Row8 ((10, 10, 10, 200)), (1 => Dimension (2, 0.0, 256.0, 0)));
      --  The histogram's channel 0 applies to the later Source's channel 0.
      Mapped : constant OpenCV.Core.Mat := IP.Back_Project (Source, Red);
      Joint  : constant IP.Histogram :=
        IP.Calculate_Histogram
          (Source,
           (Dimension (2, 0.0, 256.0, 0), Dimension (2, 0.0, 256.0, 1)));
      Paired : constant OpenCV.Core.Mat := IP.Back_Project (Source, Joint);
      Green  : constant IP.Histogram :=
        IP.Calculate_Histogram (Source, (1 => Dimension (4, 0.0, 256.0, 1)));
      By_G   : constant OpenCV.Core.Mat := IP.Back_Project (Source, Green);
   begin
      AUnit.Assertions.Assert
        (U8.Get (Mapped, 0, 0) = 3 and then U8.Get (Mapped, 0, 3) = 1,
         "a 1-D histogram maps the stored channel of a C3 source");
      AUnit.Assertions.Assert
        (By_G.Channels = 1
         and then U8.Get (By_G, 0, 0) = 1
         and then U8.Get (By_G, 0, 1) = 3,
         "a selected green channel is looked up in a C3 source");
      AUnit.Assertions.Assert
        (U8.Get (Paired, 0, 0) = 1
         and then U8.Get (Paired, 0, 1) = 1
         and then U8.Get (Paired, 0, 2) = 2,
         "a 2-D joint histogram maps channel pairs");
   end Back_Project_Channels;

   procedure Back_Project_Unit_Axis (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat :=
        Row_C3 (((10, 20, 0), (10, 200, 0), (200, 20, 0)));
      --  Second axis has one bin covering [0, 128): green 200 is excluded.
      Joint  : constant IP.Histogram :=
        IP.Calculate_Histogram
          (Source,
           (Dimension (2, 0.0, 256.0, 0), Dimension (1, 0.0, 128.0, 1)));
      Result : constant OpenCV.Core.Mat := IP.Back_Project (Source, Joint);
   begin
      AUnit.Assertions.Assert
        (U8.Get (Result, 0, 0) = 1
         and then U8.Get (Result, 0, 1) = 0
         and then U8.Get (Result, 0, 2) = 1,
         "a one-bin second axis still filters by its channel range");

      declare
         --  Leading one-bin axis over blue [0, 128); green split in halves.
         Leading : constant IP.Histogram :=
           IP.Calculate_Histogram
             (Source,
              (Dimension (1, 0.0, 128.0, 0), Dimension (2, 0.0, 256.0, 1)));
         Mapped  : constant OpenCV.Core.Mat :=
           IP.Back_Project (Source, Leading);
      begin
         AUnit.Assertions.Assert
           (U8.Get (Mapped, 0, 0) = 1
            and then U8.Get (Mapped, 0, 1) = 1
            and then U8.Get (Mapped, 0, 2) = 0,
            "a one-bin first axis keeps both channels");
      end;
   end Back_Project_Unit_Axis;

   procedure Back_Project_Depths (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Wide   : OpenCV.Core.Mat := Filled (1, 3, (OpenCV.Core.UInt16, 1));
      Real   : OpenCV.Core.Mat := Filled (1, 3, (OpenCV.Core.Float32, 1));
      Axis16 : constant IP.Histogram_Dimension := Dimension (2, 0.0, 65536.0);
      Axis32 : constant IP.Histogram_Dimension := Dimension (2, 0.0, 1.0);
      H16    : IP.Histogram;
      H32    : IP.Histogram;
      Out16  : OpenCV.Core.Mat;
      Out32  : OpenCV.Core.Mat;
   begin
      U16.Set (Wide, 0, 0, 100);
      U16.Set (Wide, 0, 1, 50_000);
      U16.Set (Wide, 0, 2, 200);
      H16 := IP.Calculate_Histogram (Wide, (1 => Axis16));
      Out16 := IP.Back_Project (Wide, H16, 1_000.0);
      AUnit.Assertions.Assert
        (Out16.Depth = OpenCV.Core.UInt16
         and then Out16.Channels = 1
         and then U16.Get (Out16, 0, 0) = 2_000
         and then U16.Get (Out16, 0, 1) = 1_000,
         "UInt16 back projection keeps UInt16 depth and scales");

      F32.Set (Real, 0, 0, 0.25);
      F32.Set (Real, 0, 1, 0.75);
      F32.Set (Real, 0, 2, 1.5);
      H32 := IP.Calculate_Histogram (Real, (1 => Axis32));
      Out32 := IP.Back_Project (Real, H32, 0.5);
      AUnit.Assertions.Assert
        (Out32.Depth = OpenCV.Core.Float32
         and then F32.Get (Out32, 0, 0) = 0.5
         and then F32.Get (Out32, 0, 1) = 0.5
         and then F32.Get (Out32, 0, 2) = 0.0,
         "Float32 back projection is unsaturated; out-of-range gives 0");
   end Back_Project_Depths;

   procedure Back_Project_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : constant OpenCV.Core.Mat :=
        Filled (5, 7, (OpenCV.Core.UInt8, 1));
      View   : OpenCV.Core.Mat;
      Model  : constant IP.Histogram :=
        IP.Calculate_Histogram (Sample8, (1 => Quarters));
      Result : OpenCV.Core.Mat;
   begin
      View :=
        OpenCV.Core.Region (Parent, (X => 2, Y => 1, Width => 4, Height => 3));
      OpenCV.Core.Set_To (View, Gray (150.0));
      Result := IP.Back_Project (View, Model, 10.0);
      AUnit.Assertions.Assert
        (Result.Rows = 3
         and then Result.Columns = 4
         and then OpenCV.Core.Count_Non_Zero (Result) = 12
         and then U8.Get (Result, 2, 3) = 20,
         "a Region back-projects to a Region-sized output");
      AUnit.Assertions.Assert
        (U8.Get (Parent, 0, 0) = 0 and then U8.Get (Parent, 1, 2) = 150,
         "the parent image is unchanged");
   end Back_Project_Region;

   procedure Back_Project_Invalid (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Color_Model : constant IP.Histogram :=
        IP.Calculate_Histogram
          (Row_C3 (Joint_Source), (1 => Dimension (2, 0.0, 256.0, 2)));
      Model       : constant IP.Histogram :=
        IP.Calculate_Histogram (Sample8, (1 => Quarters));
      Empty_Model : IP.Histogram;
      Scale       : OpenCV.Float64_Value := 1.0;
      Image       : OpenCV.Core.Mat := Sample8;

      procedure Try (Distribution : IP.Histogram) is
         Unused : constant OpenCV.Core.Mat :=
           IP.Back_Project (Image, Distribution, Scale);
      begin
         null;
      end Try;

      procedure Missing_Channel is
      begin
         Try (Color_Model);
      end Missing_Channel;

      procedure Empty_Histogram is
      begin
         Try (Empty_Model);
      end Empty_Histogram;

      procedure Bad_Scale is
      begin
         Try (Model);
      end Bad_Scale;
   begin
      Assert_Raises
        (Missing_Channel'Access,
         "a histogram channel absent from the later Source is rejected");
      Assert_Raises (Empty_Histogram'Access, "an empty histogram is rejected");
      Scale := NaN64;
      Assert_Raises (Bad_Scale'Access, "a NaN scale is rejected");
      Scale := Infinity64;
      Assert_Raises (Bad_Scale'Access, "an infinite scale is rejected");
      Scale := 1.0e300;
      Assert_Raises (Bad_Scale'Access, "a scale beyond Float32 is rejected");
      Scale := 1.0;
      Image := Filled (2, 2, (OpenCV.Core.Int16, 1));
      Assert_Raises (Bad_Scale'Access, "an Int16 source is rejected");
      Image := No_Mat;
      Assert_Raises (Bad_Scale'Access, "an empty source is rejected");
   end Back_Project_Invalid;

   function Raw_Back_Project
     (Source    : OpenCV.Core.Mat;
      Histogram : OpenCV.Core.Mat;
      Records   : C_API.Histogram_Dimension_Records;
      Count     : Interfaces.Integer_32;
      Scale     : Interfaces.C.double;
      Output    : in out OpenCV.Core.Mat) return C_API.Status
   is
      Local  : aliased constant C_API.Histogram_Dimension_Records := Records;
      Status : C_API.Status := C_API.Success;

      procedure On_Source
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure On_Histogram
           (Histogram_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure On_Output
              (Output_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Calc_Back_Project
                   (Source_Handle,
                    Histogram_Handle,
                    Local (Local'First)'Access,
                    Count,
                    Scale,
                    Output_Handle);
            end On_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Output, On_Output'Access);
         end On_Histogram;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Histogram, On_Histogram'Access);
      end On_Source;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, On_Source'Access);
      return Status;
   end Raw_Back_Project;

   function Raw_Back_Project_Null_Output
     (Source, Histogram : OpenCV.Core.Mat) return C_API.Status
   is
      function Raw
        (Source, Histogram : System.Address;
         Dimensions        : access constant C_API.Histogram_Dimension_Record;
         Count             : Interfaces.Integer_32;
         Scale             : Interfaces.C.double;
         Destination       : System.Address) return C_API.Status
      with
        Import,
        Convention    => C,
        External_Name => "opencv_imgproc_calc_back_project";
      function To_Address is new
        Ada.Unchecked_Conversion
          (OpenCV.Core.Module_Interop.Input_Mat_Handle,
           System.Address);
      Local  : aliased constant C_API.Histogram_Dimension_Record :=
        Good_Record;
      Status : C_API.Status := C_API.Success;

      procedure On_Source
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure On_Histogram
           (Histogram_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status :=
              Raw
                (To_Address (Source_Handle),
                 To_Address (Histogram_Handle),
                 Local'Access,
                 1,
                 1.0,
                 System.Null_Address);
         end On_Histogram;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Histogram, On_Histogram'Access);
      end On_Source;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, On_Source'Access);
      return Status;
   end Raw_Back_Project_Null_Output;

   procedure Raw_Back_Project_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Sample8;
      Hist   : constant OpenCV.Core.Mat :=
        IP.Histogram_Values (IP.Calculate_Histogram (Source, (1 => Quarters)));
      Output : OpenCV.Core.Mat := Marker;
      One    : constant C_API.Histogram_Dimension_Records :=
        (1 => Good_Record);

      procedure Expect (Status : C_API.Status; Fragment, Message : String) is
      begin
         Assert_Invalid (Status, Fragment, Message);
         AUnit.Assertions.Assert
           (Is_Marker (Output), Message & ": output must be unchanged");
      end Expect;

   begin
      Expect
        (Raw_Back_Project
           (Source, Hist, (1 => Record_Of (5, 0.0, 256.0)), 1, 1.0, Output),
         "matching",
         "a histogram shape mismatch is rejected");
      Expect
        (Raw_Back_Project
           (Source,
            Filled (1, 4, (OpenCV.Core.Float32, 1)),
            One,
            1,
            1.0,
            Output),
         "matching",
         "a transposed 1-D histogram is rejected");
      Expect
        (Raw_Back_Project
           (Source,
            Filled (4, 1, (OpenCV.Core.Float64, 1)),
            One,
            1,
            1.0,
            Output),
         "Float32",
         "a Float64 histogram is rejected");
      Expect
        (Raw_Back_Project
           (Source, Hist, (1 .. 2 => Good_Record), 2, 1.0, Output),
         "matching",
         "a dimension count that disagrees with the histogram fails");
      Expect
        (Raw_Back_Project
           (Source, Hist, (1 .. 11 => Good_Record), 11, 1.0, Output),
         "1 .. 10",
         "11 dimensions are rejected");
      Expect
        (Raw_Back_Project (Source, Hist, One, 0, 1.0, Output),
         "1 .. 10",
         "zero dimensions are rejected");
      Expect
        (Raw_Back_Project (Source, Hist, One, -3, 1.0, Output),
         "1 .. 10",
         "a negative dimension count is rejected");
      Expect
        (Raw_Back_Project
           (Source, Hist, One, 1, Interfaces.C.double (NaN64), Output),
         "scale",
         "a NaN scale is rejected");
      Expect
        (Raw_Back_Project
           (Source, Hist, One, 1, Interfaces.C.double (Infinity64), Output),
         "scale",
         "an infinite scale is rejected");
      Expect
        (Raw_Back_Project
           (Source, Hist, (1 => Record_Of (4, 0.0, 256.0, 1)), 1, 1.0, Output),
         "channel",
         "a missing channel is rejected before scanning");
      Expect
        (Raw_Back_Project
           (Source,
            Hist,
            (1 => Record_Of (4, 0.0, 256.0, -1)),
            1,
            1.0,
            Output),
         "channel",
         "a negative channel is rejected before scanning");
      Expect
        (Raw_Back_Project
           (Filled (2, 2, (OpenCV.Core.Int16, 1)), Hist, One, 1, 1.0, Output),
         "depth",
         "an Int16 source is rejected");
      Assert_Invalid
        (Raw_Back_Project_Null_Output (Source, Hist),
         "destination",
         "a null output handle is rejected");
      AUnit.Assertions.Assert
        (Raw_Back_Project (Source, Hist, One, 1, 1.0, Output) = C_API.Success
         and then Output.Depth = OpenCV.Core.UInt8
         and then Output.Columns = 8,
         "a valid raw back projection succeeds");
   end Raw_Back_Project_Validation;

   procedure Float32_Index_Preflight (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat := Filled (1, 2, (OpenCV.Core.Float32, 1));
      Mask   : OpenCV.Core.Mat := Filled (1, 2, (OpenCV.Core.UInt8, 1));
      Hist   : constant OpenCV.Core.Mat :=
        Filled (2, 1, (OpenCV.Core.Float32, 1), Gray (3.0));
      Output : OpenCV.Core.Mat := Marker;
      Axis   : constant C_API.Histogram_Dimension_Records :=
        (1 => Record_Of (2, 0.0, 1.0));
      Unsafe : constant array (1 .. 4) of OpenCV.Float32_Value :=
        (NaN32, Infinity32, -Infinity32, 1.0e30);
   begin
      F32.Set (Source, 0, 1, 0.25);
      U8.Set (Mask, 0, 0, 0);
      U8.Set (Mask, 0, 1, 255);
      for Index in Unsafe'Range loop
         F32.Set (Source, 0, 0, Unsafe (Index));
         Assert_Invalid
           (Raw_Calc (Source, Axis, 1, Output),
            (if Index < 4 then "nonfinite" else "cvFloor int range"),
            "unsafe Float32 calculation sample is rejected");
         AUnit.Assertions.Assert
           (Is_Marker (Output), "rejected calculation preserves output");
         Assert_Invalid
           (Raw_Back_Project (Source, Hist, Axis, 1, 1.0, Output),
            (if Index < 4 then "nonfinite" else "cvFloor int range"),
            "unsafe Float32 back projection sample is rejected");
         AUnit.Assertions.Assert
           (Is_Marker (Output), "rejected back projection preserves output");
         AUnit.Assertions.Assert
           (Raw_Calc (Source, Axis, 1, Output, Mask, True) = C_API.Success
            and then F32.Get (Output, 0, 0) = 1.0
            and then F32.Get (Output, 1, 0) = 0.0,
            "masked-out unsafe Float32 sample is ignored");
         Output := Marker;
      end loop;
      F32.Set (Source, 0, 0, 2.0);
      AUnit.Assertions.Assert
        (Raw_Calc (Source, Axis, 1, Output) = C_API.Success
         and then F32.Get (Output, 0, 0) = 1.0,
         "safe out-of-range sample does not increment a bin");
      AUnit.Assertions.Assert
        (Raw_Back_Project (Source, Hist, Axis, 1, 1.0, Output) = C_API.Success
         and then F32.Get (Output, 0, 0) = 0.0
         and then F32.Get (Output, 0, 1) = 3.0,
         "safe out-of-range sample back-projects to zero");
      declare
         Repeated : constant C_API.Histogram_Dimension_Records :=
           (Record_Of (2, 0.0, 1.0), Record_Of (2, 0.0, 1.0e-30));
         Joint    : constant OpenCV.Core.Mat :=
           Filled (2, 2, (OpenCV.Core.Float32, 1));
      begin
         F32.Set (Source, 0, 0, 0.25);
         Output := Marker;
         Assert_Invalid
           (Raw_Calc (Source, Repeated, 2, Output),
            "cvFloor int range",
            "repeated channel is checked with each dimension's scale");
         AUnit.Assertions.Assert
           (Is_Marker (Output), "repeated-channel rejection preserves bins");
         Assert_Invalid
           (Raw_Back_Project (Source, Joint, Repeated, 2, 1.0, Output),
            "cvFloor int range",
            "back projection checks repeated channel per dimension");
         AUnit.Assertions.Assert
           (Is_Marker (Output), "repeated-channel rejection preserves output");
      end;
   end Float32_Index_Preflight;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Routine : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Routine));
      end Add;
   begin
      Add ("Histogram UInt8 exact counts", UInt8_Exact_Counts'Access);
      Add ("Histogram range boundaries", Range_Boundaries'Access);
      Add ("Histogram UInt16 source", UInt16_Histogram'Access);
      Add ("Histogram Float32 source", Float32_Histogram'Access);
      Add ("Histogram channel selection", Channel_Selection'Access);
      Add ("Histogram 2-D joint", Joint_2D'Access);
      Add ("Histogram 3-D joint", Joint_3D'Access);
      Add ("Histogram ten dimensions", Ten_Dimensions'Access);
      Add
        ("Histogram arbitrary array lower bound",
         Arbitrary_Lower_Bound'Access);
      Add ("Histogram mask", Masked_Histogram'Access);
      Add ("Histogram Region source", Region_Histogram'Access);
      Add ("Histogram metadata and clone", Metadata_And_Clone'Access);
      Add
        ("Histogram invalid calculation inputs",
         Invalid_Calculation_Inputs'Access);
      Add
        ("Histogram raw C ABI calculation", Raw_Calculation_Validation'Access);
      Add ("Histogram comparison identical", Compare_Identical'Access);
      Add ("Histogram comparison different", Compare_Different'Access);
      Add ("Histogram comparison compatibility", Compare_Compatibility'Access);
      Add ("Histogram raw C ABI comparison", Raw_Compare_Validation'Access);
      Add ("Back projection UInt8", Back_Project_UInt8'Access);
      Add ("Back projection channels", Back_Project_Channels'Access);
      Add ("Back projection unit axis", Back_Project_Unit_Axis'Access);
      Add ("Back projection depths", Back_Project_Depths'Access);
      Add ("Back projection Region", Back_Project_Region'Access);
      Add ("Back projection invalid inputs", Back_Project_Invalid'Access);
      Add ("Back projection raw C ABI", Raw_Back_Project_Validation'Access);
      Add
        ("Float32 histogram index preflight", Float32_Index_Preflight'Access);
      return Result'Access;
   end Suite;

end Histogram_Analysis_Tests;
