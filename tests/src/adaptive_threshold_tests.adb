with Ada.Strings.Fixed;
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

package body Adaptive_Threshold_Tests is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;

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

   procedure Mean_Produces_Exact_Output (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
   begin
      OpenCV.Core.Set_To (Source, (others => 10.0));
      OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 100);
      OpenCV.Image_Processing.Apply_Adaptive_Threshold
        (Source, Destination, 3, Maximum_Value => 200);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 3
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "adaptive mean threshold must replace Destination with UInt8 C1");
      for Row in 0 .. 2 loop
         for Column in 0 .. 2 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Destination, Row, Column)
               = (if Row = 1 and then Column = 1 then 200 else 0),
               "adaptive mean threshold must produce the exact binary output");
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 1, 1) = 100,
         "adaptive threshold must preserve a distinct Source Mat");
   end Mean_Produces_Exact_Output;

   procedure Gaussian_Produces_Exact_Output (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 20.0));
      OpenCV.Core.UInt8_Access.Set (Source, 2, 2, 200);
      OpenCV.Image_Processing.Apply_Adaptive_Threshold
        (Source, Destination, 5, Method => OpenCV.Image_Processing.Gaussian);

      for Row in 0 .. 4 loop
         for Column in 0 .. 4 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Destination, Row, Column)
               = (if Row = 2 and then Column = 2 then 255 else 0),
               "adaptive Gaussian threshold must produce exact binary output");
         end loop;
      end loop;
   end Gaussian_Produces_Exact_Output;

   procedure Inverse_Forwards_Bias (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 10.0));
      OpenCV.Image_Processing.Apply_Adaptive_Threshold
        (Source,
         Destination,
         3,
         Mode          => OpenCV.Image_Processing.Binary_Inverse,
         Bias          => 5.0,
         Maximum_Value => 200);

      for Row in 0 .. 2 loop
         for Column in 0 .. 2 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Destination, Row, Column) = 0,
               "adaptive inverse threshold must subtract Bias from its mean");
         end loop;
      end loop;
   end Inverse_Forwards_Bias;

   procedure Supports_In_Place_Operation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Image, (others => 10.0));
      OpenCV.Core.UInt8_Access.Set (Image, 1, 1, 100);
      OpenCV.Image_Processing.Apply_Adaptive_Threshold (Image, Image, 3);

      AUnit.Assertions.Assert
        (Image.Rows = 3
         and then Image.Columns = 3
         and then Image.Depth = OpenCV.Core.UInt8
         and then Image.Channels = 1,
         "adaptive threshold must preserve in-place geometry and type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Image, 1, 1) = 255
         and then OpenCV.Core.UInt8_Access.Get (Image, 0, 0) = 0,
         "adaptive threshold must support direct in-place operation");
   end Supports_In_Place_Operation;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source  : OpenCV.Core.Mat;
      Three_D       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Float_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      Multi_Channel : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      Valid_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Destination   : OpenCV.Core.Mat;

      procedure Empty is
      begin
         OpenCV.Image_Processing.Apply_Adaptive_Threshold
           (Empty_Source, Destination, 3);
      end Empty;

      procedure Non_Two_Dimensional is
      begin
         OpenCV.Image_Processing.Apply_Adaptive_Threshold
           (Three_D, Destination, 3);
      end Non_Two_Dimensional;

      procedure Non_UInt8 is
      begin
         OpenCV.Image_Processing.Apply_Adaptive_Threshold
           (Float_Source, Destination, 3);
      end Non_UInt8;

      procedure Multi_Channel_Source is
      begin
         OpenCV.Image_Processing.Apply_Adaptive_Threshold
           (Multi_Channel, Destination, 3);
      end Multi_Channel_Source;

      procedure Even_Block_Size is
      begin
         OpenCV.Image_Processing.Apply_Adaptive_Threshold
           (Valid_Source, Destination, 4);
      end Even_Block_Size;
   begin
      Assert_Raises_OpenCV_Error
        (Empty'Access, "adaptive threshold must reject an empty source Mat");
      Assert_Raises_OpenCV_Error
        (Non_Two_Dimensional'Access,
         "adaptive threshold must reject a three-dimensional source Mat");
      Assert_Raises_OpenCV_Error
        (Non_UInt8'Access, "adaptive threshold must reject Float32 source");
      Assert_Raises_OpenCV_Error
        (Multi_Channel_Source'Access,
         "adaptive threshold must reject a multi-channel source Mat");
      Assert_Raises_OpenCV_Error
        (Even_Block_Size'Access, "adaptive threshold must reject even blocks");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));

      procedure Check
        (Maximum_Value, Method, Mode, Block_Size : Interfaces.Integer_32;
         Diagnostic                              : String)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Adaptive_Threshold
                   (Source_Handle,
                    Destination_Handle,
                    Maximum_Value,
                    Method,
                    Mode,
                    Block_Size,
                    0.0);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed adaptive threshold input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed adaptive threshold input must identify " & Diagnostic);
      end Check;
   begin
      Check (255, 99, C_API.Threshold_Binary, 3, "method");
      Check
        (255,
         C_API.Adaptive_Threshold_Mean,
         C_API.Threshold_Truncate,
         3,
         "mode");
      Check
        (255,
         C_API.Adaptive_Threshold_Mean,
         C_API.Threshold_Binary,
         1,
         "block");
      Check
        (255,
         C_API.Adaptive_Threshold_Mean,
         C_API.Threshold_Binary,
         2,
         "block");
      Check
        (-1,
         C_API.Adaptive_Threshold_Mean,
         C_API.Threshold_Binary,
         3,
         "maximum");
      Check
        (256,
         C_API.Adaptive_Threshold_Mean,
         C_API.Threshold_Binary,
         3,
         "maximum");
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Adaptive mean produces exact output",
            Mean_Produces_Exact_Output'Access));
      Result.Add_Test
        (Caller.Create
           ("Adaptive Gaussian produces exact output",
            Gaussian_Produces_Exact_Output'Access));
      Result.Add_Test
        (Caller.Create
           ("Adaptive inverse forwards Bias", Inverse_Forwards_Bias'Access));
      Result.Add_Test
        (Caller.Create
           ("Adaptive threshold supports in-place operation",
            Supports_In_Place_Operation'Access));
      Result.Add_Test
        (Caller.Create
           ("Adaptive threshold rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Adaptive threshold C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Adaptive_Threshold_Tests;
