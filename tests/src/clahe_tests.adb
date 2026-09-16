with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt16_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body CLAHE_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;

   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, OpenCV.Float64_Value);
   NaN      : constant OpenCV.Float64_Value :=
     Bits_To_Float64 (16#7FF8_0000_0000_0000#);
   Infinity : constant OpenCV.Float64_Value :=
     Bits_To_Float64 (16#7FF0_0000_0000_0000#);

   function Raw_CLAHE
     (Source, Destination : System.Address;
      Clip_Limit          : Interfaces.C.double;
      Width, Height       : Interfaces.Integer_32) return C_API.Status
   with Import, Convention => C, External_Name => "opencv_imgproc_clahe";

   function To_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Input_Mat_Handle,
        System.Address);
   function To_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Output_Mat_Handle,
        System.Address);

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

   procedure Fill_UInt8 (Image : in out OpenCV.Core.Mat) is
   begin
      for Row in 0 .. Image.Rows - 1 loop
         for Column in 0 .. Image.Columns - 1 loop
            OpenCV.Core.UInt8_Access.Set
              (Image,
               Row,
               Column,
               Interfaces.Unsigned_8 (40 + ((Row * 17 + Column * 11) mod 45)));
         end loop;
      end loop;
   end Fill_UInt8;

   procedure Fill_UInt16 (Image : in out OpenCV.Core.Mat) is
   begin
      for Row in 0 .. Image.Rows - 1 loop
         for Column in 0 .. Image.Columns - 1 loop
            OpenCV.Core.UInt16_Access.Set
              (Image,
               Row,
               Column,
               Interfaces.Unsigned_16
                 (8_000 + ((Row * 3_001 + Column * 1_009) mod 20_000)));
         end loop;
      end loop;
   end Fill_UInt16;

   function Same_UInt8 (Left, Right : OpenCV.Core.Mat) return Boolean is
   begin
      if Left.Rows /= Right.Rows or else Left.Columns /= Right.Columns then
         return False;
      end if;
      for Row in 0 .. Left.Rows - 1 loop
         for Column in 0 .. Left.Columns - 1 loop
            if OpenCV.Core.UInt8_Access.Get (Left, Row, Column)
              /= OpenCV.Core.UInt8_Access.Get (Right, Row, Column)
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Same_UInt8;

   procedure Basic_UInt8 (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 9, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Fill_UInt8 (Source);
      OpenCV.Image_Processing.CLAHE (Source, Destination, 4.0, (2, 3));
      AUnit.Assertions.Assert
        (Destination.Rows = 7
         and then Destination.Columns = 9
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1
         and then not Same_UInt8 (Source, Destination)
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 40,
         "CLAHE must transform a UInt8 C1 image without modifying Source");
   end Basic_UInt8;

   procedure UInt16_Support (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 9, (OpenCV.Core.UInt16, 1));
      Destination : OpenCV.Core.Mat;
   begin
      Fill_UInt16 (Source);
      OpenCV.Image_Processing.CLAHE (Source, Destination, 8.0, (2, 3));
      AUnit.Assertions.Assert
        (Destination.Rows = 7
         and then Destination.Columns = 9
         and then Destination.Depth = OpenCV.Core.UInt16
         and then Destination.Channels = 1
         and then OpenCV.Core.UInt16_Access.Get (Destination, 0, 0) /= 8_000,
         "CLAHE must retain UInt16 C1 type and transform UInt16 values");
   end UInt16_Support;

   procedure Defaults_Match_Explicit (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source                          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 11, (OpenCV.Core.UInt8, 1));
      Default_Result, Explicit_Result : OpenCV.Core.Mat;
   begin
      Fill_UInt8 (Source);
      OpenCV.Image_Processing.CLAHE (Source, Default_Result);
      OpenCV.Image_Processing.CLAHE (Source, Explicit_Result, 40.0, (8, 8));
      AUnit.Assertions.Assert
        (Same_UInt8 (Default_Result, Explicit_Result),
         "default CLAHE parameters must be 40.0 and 8x8");
   end Defaults_Match_Explicit;

   procedure Clip_Limit_Reaches_Native (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (16, 16, (OpenCV.Core.UInt8, 1));
      Low, High : OpenCV.Core.Mat;
   begin
      Fill_UInt8 (Source);
      OpenCV.Image_Processing.CLAHE (Source, Low, 1.0, (2, 2));
      OpenCV.Image_Processing.CLAHE (Source, High, 100.0, (2, 2));
      AUnit.Assertions.Assert
        (not Same_UInt8 (Low, High),
         "different clip limits must produce detectably different output");
   end Clip_Limit_Reaches_Native;

   procedure Tile_Grid_Reaches_Native (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source                          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 12, (OpenCV.Core.UInt8, 1));
      One, Two_By_Three, Three_By_Two : OpenCV.Core.Mat;
   begin
      Fill_UInt8 (Source);
      OpenCV.Image_Processing.CLAHE (Source, One, 4.0, (1, 1));
      OpenCV.Image_Processing.CLAHE (Source, Two_By_Three, 4.0, (2, 3));
      OpenCV.Image_Processing.CLAHE (Source, Three_By_Two, 4.0, (3, 2));
      AUnit.Assertions.Assert
        (not Same_UInt8 (One, Two_By_Three)
         and then not Same_UInt8 (Two_By_Three, Three_By_Two),
         "tile grid dimensions must reach native CLAHE without swapping axes");
   end Tile_Grid_Reaches_Native;

   procedure Noncontiguous_And_In_Place (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent               : OpenCV.Core.Mat :=
        OpenCV.Core.Create (10, 12, (OpenCV.Core.UInt8, 1));
      ROI, Expected, Image : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 200.0));
      ROI := Parent.Region ((X => 2, Y => 2, Width => 7, Height => 5));
      Fill_UInt8 (ROI);
      AUnit.Assertions.Assert
        (not ROI.Is_Continuous, "fixture ROI must be non-contiguous");
      OpenCV.Image_Processing.CLAHE (ROI, Expected, 4.0, (2, 3));
      Image := ROI.Clone;
      OpenCV.Image_Processing.CLAHE (Image, Image, 4.0, (2, 3));
      AUnit.Assertions.Assert
        (Same_UInt8 (Expected, Image),
         "in-place CLAHE must equal independent CLAHE for an ROI pattern");
      OpenCV.Image_Processing.CLAHE (ROI, ROI, 4.0, (2, 3));
      AUnit.Assertions.Assert
        (Same_UInt8 (Expected, ROI)
         and then OpenCV.Core.UInt8_Access.Get (Parent, 0, 0) = 200,
         "in-place CLAHE ROI must preserve pixels outside the ROI");
   end Noncontiguous_And_In_Place;

   procedure Rebinds_And_Rejects_Aliases (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 9, (OpenCV.Core.UInt8, 1));
      Destination   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 3));
      Shared        : OpenCV.Core.Mat;
      Parent        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 10, (OpenCV.Core.UInt8, 1));
      First, Second : OpenCV.Core.Mat;
      procedure Shallow is
      begin
         OpenCV.Image_Processing.CLAHE (Source, Shared);
      end Shallow;
      procedure Overlap is
      begin
         OpenCV.Image_Processing.CLAHE (First, Second);
      end Overlap;
   begin
      Fill_UInt8 (Source);
      OpenCV.Image_Processing.CLAHE (Source, Destination);
      AUnit.Assertions.Assert
        (Destination.Rows = 7
         and then Destination.Columns = 9
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "CLAHE must rebind an incompatible Destination");
      Shared := Source;
      Assert_Raises
        (Shallow'Access, "CLAHE must reject distinct shallow aliases");
      OpenCV.Core.Set_To (Parent, (others => 9.0));
      First := Parent.Region ((X => 0, Y => 0, Width => 6, Height => 6));
      Second := Parent.Region ((X => 2, Y => 2, Width => 6, Height => 6));
      Assert_Raises
        (Overlap'Access, "CLAHE must reject distinct overlapping ROIs");
   end Rebinds_And_Rejects_Aliases;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Valid       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Empty       : OpenCV.Core.Mat;
      Three_D     : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int16       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int16, 1));
      Float32     : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Float64     : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float64, 1));
      Color       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 2));
      procedure Empty_Call is
      begin
         OpenCV.Image_Processing.CLAHE (Empty, Destination);
      end Empty_Call;
      procedure Three_D_Call is
      begin
         OpenCV.Image_Processing.CLAHE (Three_D, Destination);
      end Three_D_Call;
      procedure Int16_Call is
      begin
         OpenCV.Image_Processing.CLAHE (Int16, Destination);
      end Int16_Call;
      procedure Float32_Call is
      begin
         OpenCV.Image_Processing.CLAHE (Float32, Destination);
      end Float32_Call;
      procedure Float64_Call is
      begin
         OpenCV.Image_Processing.CLAHE (Float64, Destination);
      end Float64_Call;
      procedure Color_Call is
      begin
         OpenCV.Image_Processing.CLAHE (Color, Destination);
      end Color_Call;
      procedure Zero is
      begin
         OpenCV.Image_Processing.CLAHE (Valid, Destination, 0.0);
      end Zero;
      procedure Negative is
      begin
         OpenCV.Image_Processing.CLAHE (Valid, Destination, -1.0);
      end Negative;
      procedure Nan_Call is
      begin
         OpenCV.Image_Processing.CLAHE (Valid, Destination, NaN);
      end Nan_Call;
      procedure Inf_Call is
      begin
         OpenCV.Image_Processing.CLAHE (Valid, Destination, Infinity);
      end Inf_Call;
      procedure Zero_Width is
      begin
         OpenCV.Image_Processing.CLAHE (Valid, Destination, 1.0, (0, 1));
      end Zero_Width;
      procedure Zero_Height is
      begin
         OpenCV.Image_Processing.CLAHE (Valid, Destination, 1.0, (1, 0));
      end Zero_Height;
   begin
      Assert_Raises (Empty_Call'Access, "CLAHE must reject an empty source");
      Assert_Raises (Three_D_Call'Access, "CLAHE must reject N-D source");
      Assert_Raises (Int16_Call'Access, "CLAHE must reject Int16 source");
      Assert_Raises (Float32_Call'Access, "CLAHE must reject Float32 source");
      Assert_Raises (Float64_Call'Access, "CLAHE must reject Float64 source");
      Assert_Raises (Color_Call'Access, "CLAHE must reject color source");
      Assert_Raises (Zero'Access, "CLAHE must reject zero clip limit");
      Assert_Raises (Negative'Access, "CLAHE must reject negative clip limit");
      Assert_Raises (Nan_Call'Access, "CLAHE must reject NaN clip limit");
      Assert_Raises (Inf_Call'Access, "CLAHE must reject infinite clip limit");
      Assert_Raises (Zero_Width'Access, "CLAHE must reject zero tile width");
      Assert_Raises (Zero_Height'Access, "CLAHE must reject zero tile height");
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.UInt16
         and then Destination.Channels = 2,
         "public validation failures must preserve Destination");
   end Rejects_Invalid_Public_Inputs;

   procedure Raw_C_ABI_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Status : C_API.Status;
   begin
      Fill_UInt8 (Source);
      Status :=
        Raw_CLAHE (System.Null_Address, System.Null_Address, 1.0, 1, 1);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "raw CLAHE must reject a null source");
      declare
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status :=
              Raw_CLAHE
                (To_Address (Source_Handle), System.Null_Address, 1.0, 1, 1);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      end;
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "raw CLAHE must reject a null destination");
      declare
         Destination : OpenCV.Core.Mat;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Raw_CLAHE
                   (To_Address (Source_Handle),
                    To_Address (Destination_Handle),
                    NaN,
                    1,
                    1);
               AUnit.Assertions.Assert
                 (Status = C_API.Error_Invalid_Argument,
                  "raw CLAHE must reject a non-finite clip limit");
               Status :=
                 Raw_CLAHE
                   (To_Address (Source_Handle),
                    To_Address (Destination_Handle),
                    1.0,
                    0,
                    1);
               AUnit.Assertions.Assert
                 (Status = C_API.Error_Invalid_Argument,
                  "raw CLAHE must reject zero tile width");
               Status :=
                 Raw_CLAHE
                   (To_Address (Source_Handle),
                    To_Address (Destination_Handle),
                    1.0,
                    1,
                    -1);
               AUnit.Assertions.Assert
                 (Status = C_API.Error_Invalid_Argument,
                  "raw CLAHE must reject negative tile height");
               Status :=
                 Raw_CLAHE
                   (To_Address (Source_Handle),
                    To_Address (Destination_Handle),
                    Interfaces.C.double (OpenCV.Float64_Value'Last),
                    1,
                    1);
               AUnit.Assertions.Assert
                 (Status = C_API.Error_Invalid_Argument,
                  "raw CLAHE must reject clip-limit integer overflow");
               Status :=
                 Raw_CLAHE
                   (To_Address (Source_Handle),
                    To_Address (Destination_Handle),
                    4.0,
                    2,
                    2);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      end;
      AUnit.Assertions.Assert
        (Status = C_API.Success,
         "a valid raw CLAHE call must recover after errors");
   end Raw_C_ABI_Safety;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("CLAHE UInt8 basic operation", Basic_UInt8'Access));
      Result.Add_Test
        (Caller.Create ("CLAHE UInt16 support", UInt16_Support'Access));
      Result.Add_Test
        (Caller.Create ("CLAHE defaults", Defaults_Match_Explicit'Access));
      Result.Add_Test
        (Caller.Create ("CLAHE clip limit", Clip_Limit_Reaches_Native'Access));
      Result.Add_Test
        (Caller.Create ("CLAHE tile grid", Tile_Grid_Reaches_Native'Access));
      Result.Add_Test
        (Caller.Create
           ("CLAHE ROI and in-place", Noncontiguous_And_In_Place'Access));
      Result.Add_Test
        (Caller.Create
           ("CLAHE rebinding and aliases",
            Rebinds_And_Rejects_Aliases'Access));
      Result.Add_Test
        (Caller.Create
           ("CLAHE public validation", Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create ("CLAHE raw ABI safety", Raw_C_ABI_Safety'Access));
      return Result'Access;
   end Suite;

end CLAHE_Tests;
