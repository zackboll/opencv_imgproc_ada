with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Histogram_Equalization_Tests is

   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;

   package C_API renames OpenCV.Image_Processing.Internal.C_API;

   use type C_API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Raw_Equalize_Histogram
     (Source : System.Address; Destination : System.Address)
      return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_equalize_histogram";

   function To_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Input_Mat_Handle,
        System.Address);
   function To_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Output_Mat_Handle,
        System.Address);

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

   procedure Fill_Nonuniform_Pattern (Image : in out OpenCV.Core.Mat) is
   begin
      OpenCV.Core.UInt8_Access.Set (Image, 0, 0, 10);
      OpenCV.Core.UInt8_Access.Set (Image, 0, 1, 20);
      OpenCV.Core.UInt8_Access.Set (Image, 0, 2, 30);
      OpenCV.Core.UInt8_Access.Set (Image, 1, 0, 30);
      OpenCV.Core.UInt8_Access.Set (Image, 1, 1, 40);
      OpenCV.Core.UInt8_Access.Set (Image, 1, 2, 40);
   end Fill_Nonuniform_Pattern;

   procedure Assert_Nonuniform_Result
     (Image : OpenCV.Core.Mat; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Image.Rows = 2
         and then Image.Columns = 3
         and then Image.Depth = OpenCV.Core.UInt8
         and then Image.Channels = 1
         and then OpenCV.Core.UInt8_Access.Get (Image, 0, 0) = 0
         and then OpenCV.Core.UInt8_Access.Get (Image, 0, 1) = 51
         and then OpenCV.Core.UInt8_Access.Get (Image, 0, 2) = 153
         and then OpenCV.Core.UInt8_Access.Get (Image, 1, 0) = 153
         and then OpenCV.Core.UInt8_Access.Get (Image, 1, 1) = 255
         and then OpenCV.Core.UInt8_Access.Get (Image, 1, 2) = 255,
         Message);
   end Assert_Nonuniform_Result;

   procedure Assert_Source_Pattern_Unchanged
     (Image : OpenCV.Core.Mat; Message : String) is
   begin
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Image, 0, 0) = 10
         and then OpenCV.Core.UInt8_Access.Get (Image, 0, 1) = 20
         and then OpenCV.Core.UInt8_Access.Get (Image, 0, 2) = 30
         and then OpenCV.Core.UInt8_Access.Get (Image, 1, 0) = 30
         and then OpenCV.Core.UInt8_Access.Get (Image, 1, 1) = 40
         and then OpenCV.Core.UInt8_Access.Get (Image, 1, 2) = 40,
         Message);
   end Assert_Source_Pattern_Unchanged;

   --  OpenCV's global equalizeHist builds a CDF LUT, not min/max scaling.
   --  For this 2x3 image the histogram is:
   --    10:1, 20:1, 30:2, 40:2  (six pixels)
   --  The first nonempty bin maps to 0. Remaining mass is 5 pixels, so the
   --  LUT scale is 255 / 5 = 51:
   --    10 -> 0
   --    20 -> 51
   --    30 -> 153
   --    40 -> 255
   --  Linear min/max scaling of 10..40 would instead yield
   --  0, 85, 170, 255.
   procedure Exact_Nonuniform_Histogram (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Fill_Nonuniform_Pattern (Source);
      OpenCV.Image_Processing.Equalize_Histogram (Source, Destination);
      Assert_Nonuniform_Result
        (Destination,
         "equalize histogram must use the CDF LUT, not min/max scaling");
   end Exact_Nonuniform_Histogram;

   procedure Evenly_Populated_Levels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 5);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 10);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 0, 200);
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 250);
      OpenCV.Image_Processing.Equalize_Histogram (Source, Destination);

      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 0
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 1) = 85
         and then OpenCV.Core.UInt8_Access.Get (Destination, 1, 0) = 170
         and then OpenCV.Core.UInt8_Access.Get (Destination, 1, 1) = 255,
         "four equally frequent levels must map to 0, 85, 170, and 255");
   end Evenly_Populated_Levels;

   procedure Uniform_Full_Range_Ramp (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (16, 16, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Index in 0 .. 255 loop
         OpenCV.Core.UInt8_Access.Set
           (Source, Index / 16, Index mod 16, Interfaces.Unsigned_8 (Index));
      end loop;

      OpenCV.Image_Processing.Equalize_Histogram (Source, Destination);

      for Index in 0 .. 255 loop
         AUnit.Assertions.Assert
           (OpenCV.Core.UInt8_Access.Get
              (Destination, Index / 16, Index mod 16)
            = Interfaces.Unsigned_8 (Index),
            "a uniform 0..255 ramp must be unchanged by equalization");
      end loop;
   end Uniform_Full_Range_Ramp;

   procedure Constant_And_Single_Pixel_Images (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Check_Constant
        (Rows, Columns : Natural; Intensity : Interfaces.Unsigned_8)
      is
         Source      : OpenCV.Core.Mat :=
           OpenCV.Core.Create (Rows, Columns, (OpenCV.Core.UInt8, 1));
         Destination : OpenCV.Core.Mat;
      begin
         OpenCV.Core.Set_To
           (Source, (Component_0 => Long_Float (Intensity), others => 0.0));
         OpenCV.Image_Processing.Equalize_Histogram (Source, Destination);
         AUnit.Assertions.Assert
           (Destination.Rows = Rows
            and then Destination.Columns = Columns
            and then Destination.Depth = OpenCV.Core.UInt8
            and then Destination.Channels = 1,
            "constant equalization must preserve geometry and type");
         for Row in 0 .. Integer (Rows) - 1 loop
            for Column in 0 .. Integer (Columns) - 1 loop
               AUnit.Assertions.Assert
                 (OpenCV.Core.UInt8_Access.Get (Destination, Row, Column)
                  = Intensity,
                  "constant images must retain their intensity");
            end loop;
         end loop;
      end Check_Constant;
   begin
      Check_Constant (3, 3, 0);
      Check_Constant (2, 4, 37);
      Check_Constant (1, 3, 255);
      Check_Constant (1, 1, 0);
      Check_Constant (1, 1, 37);
      Check_Constant (1, 1, 255);
   end Constant_And_Single_Pixel_Images;

   procedure Preserves_Independent_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Fill_Nonuniform_Pattern (Source);
      OpenCV.Image_Processing.Equalize_Histogram (Source, Destination);
      Assert_Source_Pattern_Unchanged
        (Source, "equalize histogram must not modify an independent Source");
   end Preserves_Independent_Source;

   procedure Rebinds_Empty_And_Incompatible_Destination (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source            : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Empty_Destination : OpenCV.Core.Mat;
      Typed_Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
   begin
      Fill_Nonuniform_Pattern (Source);
      OpenCV.Image_Processing.Equalize_Histogram (Source, Empty_Destination);
      Assert_Nonuniform_Result
        (Empty_Destination,
         "empty Destination must be replaced with the equalized image");

      OpenCV.Image_Processing.Equalize_Histogram (Source, Typed_Destination);
      Assert_Nonuniform_Result
        (Typed_Destination,
         "incompatible Destination must be rebound to UInt8 C1 Source size");
   end Rebinds_Empty_And_Incompatible_Destination;

   procedure Noncontiguous_Source_ROI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      ROI         : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 200.0));
      ROI := Parent.Region ((X => 1, Y => 1, Width => 3, Height => 2));
      Fill_Nonuniform_Pattern (ROI);
      AUnit.Assertions.Assert
        (not ROI.Is_Continuous,
         "ROI fixture must have a row stride larger than its logical width");

      OpenCV.Image_Processing.Equalize_Histogram (ROI, Destination);
      Assert_Nonuniform_Result
        (Destination, "equalization must use only the ROI histogram");
      Assert_Source_Pattern_Unchanged
        (ROI, "independent equalization must not modify the source ROI");

      for Row in 0 .. 3 loop
         for Column in 0 .. 4 loop
            if Row = 0 or else Row = 3 or else Column = 0 or else Column = 4
            then
               AUnit.Assertions.Assert
                 (OpenCV.Core.UInt8_Access.Get (Parent, Row, Column) = 200,
                  "parent pixels outside the ROI must remain unchanged");
            end if;
         end loop;
      end loop;
   end Noncontiguous_Source_ROI;

   procedure Supports_Direct_In_Place (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Independent : OpenCV.Core.Mat;
   begin
      Fill_Nonuniform_Pattern (Image);
      OpenCV.Image_Processing.Equalize_Histogram (Image, Independent);
      Fill_Nonuniform_Pattern (Image);
      OpenCV.Image_Processing.Equalize_Histogram (Image, Image);
      Assert_Nonuniform_Result
        (Image,
         "same-object in-place equalization must match independent output");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Independent, 0, 0)
         = OpenCV.Core.UInt8_Access.Get (Image, 0, 0)
         and then OpenCV.Core.UInt8_Access.Get (Independent, 1, 2)
                  = OpenCV.Core.UInt8_Access.Get (Image, 1, 2),
         "in-place pixels must match the independent Destination");
   end Supports_Direct_In_Place;

   procedure Supports_In_Place_ROI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.UInt8, 1));
      ROI    : OpenCV.Core.Mat;
      Alias  : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 200.0));
      ROI := Parent.Region ((X => 1, Y => 1, Width => 3, Height => 2));
      Fill_Nonuniform_Pattern (ROI);
      Alias := ROI;
      OpenCV.Image_Processing.Equalize_Histogram (ROI, ROI);
      Assert_Nonuniform_Result
        (ROI, "in-place ROI equalization must update ROI pixels");
      Assert_Nonuniform_Result
        (Alias,
         "a shallow alias of the in-place ROI must observe the same storage");

      for Row in 0 .. 3 loop
         for Column in 0 .. 4 loop
            if Row = 0 or else Row = 3 or else Column = 0 or else Column = 4
            then
               AUnit.Assertions.Assert
                 (OpenCV.Core.UInt8_Access.Get (Parent, Row, Column) = 200,
                  "pixels outside an in-place ROI must remain unchanged");
            end if;
         end loop;
      end loop;
   end Supports_In_Place_ROI;

   procedure Rejects_Unsupported_Aliases (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Shared : OpenCV.Core.Mat;
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      First  : OpenCV.Core.Mat;
      Second : OpenCV.Core.Mat;

      procedure Distinct_Shallow is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (Source, Shared);
      end Distinct_Shallow;

      procedure Overlapping_ROIs is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (First, Second);
      end Overlapping_ROIs;
   begin
      Fill_Nonuniform_Pattern (Source);
      Shared := Source;
      Assert_Raises_OpenCV_Error
        (Distinct_Shallow'Access, "distinct shallow aliases must be rejected");
      Assert_Source_Pattern_Unchanged
        (Source, "rejected shallow aliasing must not modify Source");
      Assert_Source_Pattern_Unchanged
        (Shared, "rejected shallow aliasing must not modify Destination");

      OpenCV.Core.Set_To (Parent, (others => 7.0));
      First := Parent.Region ((X => 0, Y => 0, Width => 3, Height => 3));
      Second := Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      OpenCV.Core.UInt8_Access.Set (First, 0, 0, 9);
      OpenCV.Core.UInt8_Access.Set (Second, 2, 2, 11);
      Assert_Raises_OpenCV_Error
        (Overlapping_ROIs'Access,
         "partially overlapping source/destination ROIs must be rejected");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (First, 0, 0) = 9
         and then OpenCV.Core.UInt8_Access.Get (Second, 2, 2) = 11
         and then OpenCV.Core.UInt8_Access.Get (Parent, 1, 1) = 7,
         "rejected overlapping ROIs must remain unchanged");
   end Rejects_Unsupported_Aliases;

   procedure Rejects_Invalid_Public_Sources (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source   : OpenCV.Core.Mat;
      Three_D        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      UInt16_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Float32_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Int16_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int16, 1));
      Int32_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int32, 1));
      Multi_Channel  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Marker         : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));

      procedure Assert_Preserved_Destination
        (Attempt : not null access procedure; Message : String) is
      begin
         OpenCV.Core.Set_To (Marker, (Component_0 => 9.0, others => 0.0));
         Assert_Raises_OpenCV_Error (Attempt, Message);
         AUnit.Assertions.Assert
           (Marker.Rows = 1
            and then Marker.Columns = 2
            and then Marker.Depth = OpenCV.Core.UInt16
            and then Marker.Channels = 2,
            "validation failure must preserve Destination");
      end Assert_Preserved_Destination;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (Empty_Source, Marker);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (Three_D, Marker);
      end Non_Two_Dimensional;

      procedure UInt16 is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (UInt16_Source, Marker);
      end UInt16;

      procedure Float32 is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (Float32_Source, Marker);
      end Float32;

      procedure Int16 is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (Int16_Source, Marker);
      end Int16;

      procedure Int32 is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (Int32_Source, Marker);
      end Int32;

      procedure Multi is
      begin
         OpenCV.Image_Processing.Equalize_Histogram (Multi_Channel, Marker);
      end Multi;
   begin
      Assert_Preserved_Destination
        (Empty'Access, "equalize histogram must reject an empty source Mat");
      Assert_Preserved_Destination
        (Non_Two_Dimensional'Access,
         "equalize histogram must reject a three-dimensional source Mat");
      Assert_Preserved_Destination
        (UInt16'Access, "equalize histogram must reject UInt16 source");
      Assert_Preserved_Destination
        (Float32'Access, "equalize histogram must reject Float32 source");
      Assert_Preserved_Destination
        (Int16'Access, "equalize histogram must reject Int16 source");
      Assert_Preserved_Destination
        (Int32'Access, "equalize histogram must reject Int32 source");
      Assert_Preserved_Destination
        (Multi'Access,
         "equalize histogram must reject a multi-channel source");
   end Rejects_Invalid_Public_Sources;

   procedure C_ABI_Safety_And_Error_Translation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Valid         : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      UInt16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Three_D       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Parent        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      First         : OpenCV.Core.Mat;
      Second        : OpenCV.Core.Mat;
      Status        : C_API.Status := C_API.Success;

      procedure Call
        (Source : OpenCV.Core.Mat; Destination : in out OpenCV.Core.Mat)
      is
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Equalize_Histogram (Source_Handle, Destination_Handle);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      end Call;
   begin
      Fill_Nonuniform_Pattern (Valid);
      Status :=
        Raw_Equalize_Histogram (System.Null_Address, System.Null_Address);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "null source C ABI input must return invalid argument");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "invalid source")
         /= 0,
         "null source C ABI input must identify the source handle");

      declare
         Destination : OpenCV.Core.Mat;
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Raw_Equalize_Histogram
                (System.Null_Address, To_Address (Destination_Handle));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "null source with a valid destination must be invalid");
      end;

      declare
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status :=
              Raw_Equalize_Histogram
                (To_Address (Source_Handle), System.Null_Address);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Valid, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "null destination C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index
              (C_API.Last_Error_Message, "invalid destination")
            /= 0,
            "null destination C ABI input must identify the destination");
      end;

      declare
         Destination : OpenCV.Core.Mat;
      begin
         Call (Three_D, Destination);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "higher-dimensional C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index
              (C_API.Last_Error_Message, "two-dimensional")
            /= 0,
            "higher-dimensional C ABI input must identify the 2-D guard");
      end;

      declare
         Destination : OpenCV.Core.Mat;
      begin
         Call (UInt16_Source, Destination);
         AUnit.Assertions.Assert
           (Status /= C_API.Success,
            "unsupported UInt16 C ABI input must fail");
      end;

      OpenCV.Core.Set_To (Parent, (others => 8.0));
      First := Parent.Region ((X => 0, Y => 0, Width => 3, Height => 3));
      Second := Parent.Region ((X => 1, Y => 1, Width => 3, Height => 3));
      Call (First, Second);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "overlapping C ABI views must return invalid argument");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "share storage")
         /= 0,
         "overlapping C ABI views must identify shared storage");

      declare
         Destination : OpenCV.Core.Mat;
      begin
         Call (Valid, Destination);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "a valid C ABI call after an error must succeed");
         Assert_Nonuniform_Result
           (Destination,
            "diagnostic state must recover for a subsequent valid call");
      end;
   end C_ABI_Safety_And_Error_Translation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram exact nonuniform CDF",
            Exact_Nonuniform_Histogram'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram evenly populated levels",
            Evenly_Populated_Levels'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram uniform full-range ramp",
            Uniform_Full_Range_Ramp'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram constant and single-pixel images",
            Constant_And_Single_Pixel_Images'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram preserves independent source",
            Preserves_Independent_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram rebinds empty and incompatible destination",
            Rebinds_Empty_And_Incompatible_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram uses a noncontiguous source ROI",
            Noncontiguous_Source_ROI'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram supports direct in-place operation",
            Supports_Direct_In_Place'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram supports in-place ROI operation",
            Supports_In_Place_ROI'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram rejects unsupported aliases",
            Rejects_Unsupported_Aliases'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram rejects invalid public sources",
            Rejects_Invalid_Public_Sources'Access));
      Result.Add_Test
        (Caller.Create
           ("Equalize histogram C ABI safety and error translation",
            C_ABI_Safety_And_Error_Translation'Access));
      return Result'Access;
   end Suite;

end Histogram_Equalization_Tests;
