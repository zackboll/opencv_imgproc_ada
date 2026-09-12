with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
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

package body Pyramid_Tests is

   use type Interfaces.Unsigned_8;
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

   function Nearly_Equal
     (Left, Right : OpenCV.Core.Float32_Value;
      Tolerance   : OpenCV.Core.Float32_Value) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Nearly_Equal;

   procedure Pyramid_Down_Even_Geometry_Rebinds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 8, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
   begin
      OpenCV.Core.Set_To (Source, (others => 80.0));
      OpenCV.Image_Processing.Pyramid_Down (Source, Destination);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 4
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "Pyramid_Down must rebind Destination to natural 4x3 UInt8 C1");

      for Row in 0 .. Destination.Rows - 1 loop
         for Column in 0 .. Destination.Columns - 1 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Destination, Row, Column) = 80,
               "constant UInt8 Pyramid_Down must remain 80");
         end loop;
      end loop;

      AUnit.Assertions.Assert
        (Source.Rows = 6
         and then Source.Columns = 8
         and then OpenCV.Core.UInt8_Access.Get (Source, 0, 0) = 80,
         "Pyramid_Down must not modify a distinct source Mat");
   end Pyramid_Down_Even_Geometry_Rebinds;

   procedure Pyramid_Down_Odd_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 7, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 40.0));
      OpenCV.Image_Processing.Pyramid_Down (Source, Destination);

      AUnit.Assertions.Assert
        (Destination.Rows = 3
         and then Destination.Columns = 4
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1
         and then OpenCV.Core.UInt8_Access.Get (Destination, 1, 1) = 40,
         "Pyramid_Down of 7x5 must use ceiling-half 4x3 geometry");
   end Pyramid_Down_Odd_Geometry;

   procedure Supported_Depths_Are_Preserved (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Check_Down (Depth : OpenCV.Core.Depth_Type; Fill : Long_Float)
      is
         Source      : OpenCV.Core.Mat :=
           OpenCV.Core.Create (4, 4, (Depth, 1));
         Destination : OpenCV.Core.Mat;
      begin
         OpenCV.Core.Set_To (Source, (others => Fill));
         OpenCV.Image_Processing.Pyramid_Down (Source, Destination);
         AUnit.Assertions.Assert
           (Destination.Rows = 2
            and then Destination.Columns = 2
            and then Destination.Depth = Depth
            and then Destination.Channels = 1,
            "Pyramid_Down must preserve supported source depth");
      end Check_Down;

      procedure Check_Up (Depth : OpenCV.Core.Depth_Type; Fill : Long_Float) is
         Source      : OpenCV.Core.Mat :=
           OpenCV.Core.Create (2, 2, (Depth, 1));
         Destination : OpenCV.Core.Mat;
      begin
         OpenCV.Core.Set_To (Source, (others => Fill));
         OpenCV.Image_Processing.Pyramid_Up (Source, Destination);
         AUnit.Assertions.Assert
           (Destination.Rows = 4
            and then Destination.Columns = 4
            and then Destination.Depth = Depth
            and then Destination.Channels = 1,
            "Pyramid_Up must preserve supported source depth");
      end Check_Up;
   begin
      Check_Down (OpenCV.Core.UInt8, 20.0);
      Check_Down (OpenCV.Core.UInt16, 200.0);
      Check_Down (OpenCV.Core.Int16, -12.0);
      Check_Down (OpenCV.Core.Float32, 1.5);
      Check_Down (OpenCV.Core.Float64, 2.25);
      Check_Up (OpenCV.Core.UInt8, 30.0);
      Check_Up (OpenCV.Core.Float32, 0.5);
      Check_Up (OpenCV.Core.Float64, 4.0);
   end Supported_Depths_Are_Preserved;

   procedure Multichannel_Pyramid_Down (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 6, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
      Pixel       : OpenCV.Core.UInt8_Vec3.Vector;
   begin
      OpenCV.Core.Set_To (Source, (10.0, 20.0, 30.0, 0.0));
      OpenCV.Image_Processing.Pyramid_Down (Source, Destination);

      AUnit.Assertions.Assert
        (Destination.Rows = 2
         and then Destination.Columns = 3
         and then Destination.Channels = 3
         and then Destination.Depth = OpenCV.Core.UInt8,
         "Pyramid_Down must preserve UInt8 C3 geometry and channels");

      Pixel := OpenCV.Core.UInt8_Vec3_Access.Get (Destination, 0, 0);
      AUnit.Assertions.Assert
        (Pixel = (10, 20, 30),
         "constant C3 Pyramid_Down must preserve each channel value");
   end Multichannel_Pyramid_Down;

   procedure Pyramid_Down_Border_Modes (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Replicate_Result : OpenCV.Core.Mat;
      Reflect_Result   : OpenCV.Core.Mat;
      Default_Result   : OpenCV.Core.Mat;
      Explicit_Default : OpenCV.Core.Mat;
      Wrap_Result      : OpenCV.Core.Mat;
      Differ           : Boolean := False;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 255);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 3, 128);
      OpenCV.Core.UInt8_Access.Set (Source, 3, 0, 64);

      OpenCV.Image_Processing.Pyramid_Down
        (Source, Replicate_Result, OpenCV.Core.Replicate);
      OpenCV.Image_Processing.Pyramid_Down
        (Source, Reflect_Result, OpenCV.Core.Reflect);
      OpenCV.Image_Processing.Pyramid_Down (Source, Default_Result);
      OpenCV.Image_Processing.Pyramid_Down
        (Source, Explicit_Default, OpenCV.Core.Reflect_101);
      OpenCV.Image_Processing.Pyramid_Down
        (Source, Wrap_Result, OpenCV.Core.Wrap);

      AUnit.Assertions.Assert
        (Replicate_Result.Rows = 2
         and then Reflect_Result.Rows = 2
         and then Wrap_Result.Rows = 2
         and then Default_Result.Rows = 2,
         "all public Pyramid_Down borders must succeed");

      for Row in 0 .. 1 loop
         for Column in 0 .. 1 loop
            if OpenCV.Core.UInt8_Access.Get (Replicate_Result, Row, Column)
              /= OpenCV.Core.UInt8_Access.Get (Wrap_Result, Row, Column)
            then
               Differ := True;
            end if;
         end loop;
      end loop;

      AUnit.Assertions.Assert
        (Differ, "Replicate and Wrap must differ on a nonconstant corner");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Default_Result, 0, 0)
         = OpenCV.Core.UInt8_Access.Get (Explicit_Default, 0, 0)
         and then OpenCV.Core.UInt8_Access.Get (Default_Result, 1, 1)
                  = OpenCV.Core.UInt8_Access.Get (Explicit_Default, 1, 1),
         "default Pyramid_Down border must match Reflect_101");
   end Pyramid_Down_Border_Modes;

   procedure Pyramid_Up_Geometry_Rebinds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 2));
   begin
      OpenCV.Core.Set_To (Source, (others => 50.0));
      OpenCV.Image_Processing.Pyramid_Up (Source, Destination);

      AUnit.Assertions.Assert
        (Destination.Rows = 6
         and then Destination.Columns = 8
         and then Destination.Depth = OpenCV.Core.UInt8
         and then Destination.Channels = 1,
         "Pyramid_Up must rebind Destination to doubled UInt8 C1 geometry");
   end Pyramid_Up_Geometry_Rebinds;

   procedure Pyramid_Up_Constant_Float32 (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.5));
      OpenCV.Image_Processing.Pyramid_Up (Source, Destination);

      AUnit.Assertions.Assert
        (Destination.Rows = 4
         and then Destination.Columns = 6
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "Pyramid_Up must double a Float32 C1 source");

      for Row in 0 .. Destination.Rows - 1 loop
         for Column in 0 .. Destination.Columns - 1 loop
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (OpenCV.Core.Float32_Access.Get (Destination, Row, Column),
                  0.5,
                  1.0E-5),
               "constant Float32 Pyramid_Up must remain 0.5");
         end loop;
      end loop;
   end Pyramid_Up_Constant_Float32;

   procedure Down_Then_Up_Is_Smoothed_Reconstruction (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.Float32, 1));
      Down   : OpenCV.Core.Mat;
      Up     : OpenCV.Core.Mat;
      Differ : Boolean := False;
   begin
      for Row in 0 .. 7 loop
         for Column in 0 .. 7 loop
            OpenCV.Core.Float32_Access.Set
              (Source, Row, Column, OpenCV.Core.Float32_Value (Row + Column));
         end loop;
      end loop;

      OpenCV.Image_Processing.Pyramid_Down (Source, Down);
      OpenCV.Image_Processing.Pyramid_Up (Down, Up);

      AUnit.Assertions.Assert
        (Down.Rows = 4
         and then Down.Columns = 4
         and then Up.Rows = 8
         and then Up.Columns = 8
         and then Up.Depth = OpenCV.Core.Float32,
         "down then up must restore original 8x8 Float32 geometry");
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Source, 0, 7) = 7.0
         and then Source.Rows = 8,
         "composition must not modify Source");

      for Row in 0 .. 7 loop
         for Column in 0 .. 7 loop
            if not Nearly_Equal
                     (OpenCV.Core.Float32_Access.Get (Up, Row, Column),
                      OpenCV.Core.Float32_Access.Get (Source, Row, Column),
                      1.0E-5)
            then
               Differ := True;
            end if;
         end loop;
      end loop;

      AUnit.Assertions.Assert
        (Differ,
         "Pyramid_Up of Pyramid_Down must be a smoothed reconstruction");
   end Down_Then_Up_Is_Smoothed_Reconstruction;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Source   : OpenCV.Core.Mat;
      Three_D        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int32_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.Int32, 1));
      Float16_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.Float16, 1));
      Valid_Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Destination    : OpenCV.Core.Mat;

      procedure Empty_Down is
      begin
         OpenCV.Image_Processing.Pyramid_Down (Empty_Source, Destination);
      end Empty_Down;

      procedure Three_D_Down is
      begin
         OpenCV.Image_Processing.Pyramid_Down (Three_D, Destination);
      end Three_D_Down;

      procedure Int32_Down is
      begin
         OpenCV.Image_Processing.Pyramid_Down (Int32_Source, Destination);
      end Int32_Down;

      procedure Float16_Down is
      begin
         OpenCV.Image_Processing.Pyramid_Down (Float16_Source, Destination);
      end Float16_Down;

      procedure Constant_Border is
      begin
         OpenCV.Image_Processing.Pyramid_Down
           (Valid_Source, Destination, OpenCV.Core.Constant_Border);
      end Constant_Border;

      procedure Aliased_Down is
      begin
         OpenCV.Image_Processing.Pyramid_Down (Valid_Source, Valid_Source);
      end Aliased_Down;

      procedure Empty_Up is
      begin
         OpenCV.Image_Processing.Pyramid_Up (Empty_Source, Destination);
      end Empty_Up;

      procedure Three_D_Up is
      begin
         OpenCV.Image_Processing.Pyramid_Up (Three_D, Destination);
      end Three_D_Up;

      procedure Int32_Up is
      begin
         OpenCV.Image_Processing.Pyramid_Up (Int32_Source, Destination);
      end Int32_Up;

      procedure Float16_Up is
      begin
         OpenCV.Image_Processing.Pyramid_Up (Float16_Source, Destination);
      end Float16_Up;

      procedure Aliased_Up is
      begin
         OpenCV.Image_Processing.Pyramid_Up (Valid_Source, Valid_Source);
      end Aliased_Up;
   begin
      OpenCV.Core.Set_To (Valid_Source, (others => 10.0));
      Assert_Raises_OpenCV_Error
        (Empty_Down'Access, "Pyramid_Down must reject an empty source");
      Assert_Raises_OpenCV_Error
        (Three_D_Down'Access, "Pyramid_Down must reject a 3-D source");
      Assert_Raises_OpenCV_Error
        (Int32_Down'Access, "Pyramid_Down must reject Int32");
      Assert_Raises_OpenCV_Error
        (Float16_Down'Access, "Pyramid_Down must reject Float16");
      Assert_Raises_OpenCV_Error
        (Constant_Border'Access, "Pyramid_Down must reject Constant_Border");
      Assert_Raises_OpenCV_Error
        (Aliased_Down'Access, "Pyramid_Down must reject in-place aliasing");
      Assert_Raises_OpenCV_Error
        (Empty_Up'Access, "Pyramid_Up must reject an empty source");
      Assert_Raises_OpenCV_Error
        (Three_D_Up'Access, "Pyramid_Up must reject a 3-D source");
      Assert_Raises_OpenCV_Error
        (Int32_Up'Access, "Pyramid_Up must reject Int32");
      Assert_Raises_OpenCV_Error
        (Float16_Up'Access, "Pyramid_Up must reject Float16");
      Assert_Raises_OpenCV_Error
        (Aliased_Up'Access, "Pyramid_Up must reject in-place aliasing");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Int32_Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.Int32, 1));
      Three_D      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));

      procedure Check_Down
        (Source     : OpenCV.Core.Mat;
         Border     : Interfaces.Integer_32;
         Diagnostic : String)
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
                 C_API.Pyramid_Down
                   (Source_Handle, Destination_Handle, Border);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Pyramid_Down C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Pyramid_Down C ABI input must identify " & Diagnostic);
      end Check_Down;

      procedure Check_Up (Source : OpenCV.Core.Mat; Diagnostic : String) is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status := C_API.Pyramid_Up (Source_Handle, Destination_Handle);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Pyramid_Up C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Pyramid_Up C ABI input must identify " & Diagnostic);
      end Check_Up;

      procedure Check_Aliased_Down is
         Status : C_API.Status := C_API.Success;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Pyramid_Down
                   (Source_Handle,
                    Destination_Handle,
                    C_API.Border_Reflect_101);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (UInt8_Source, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "aliased Pyramid_Down C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "aliased") /= 0,
            "aliased Pyramid_Down C ABI input must identify distinct storage");
      end Check_Aliased_Down;

      procedure Check_Aliased_Up is
         Status : C_API.Status := C_API.Success;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status := C_API.Pyramid_Up (Source_Handle, Destination_Handle);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (UInt8_Source, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "aliased Pyramid_Up C ABI input must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "aliased") /= 0,
            "aliased Pyramid_Up C ABI input must identify distinct storage");
      end Check_Aliased_Up;

      procedure Check_Success_Down (Border : Interfaces.Integer_32) is
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
                 C_API.Pyramid_Down
                   (Source_Handle, Destination_Handle, Border);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "valid Pyramid_Down C ABI border must succeed");
         AUnit.Assertions.Assert
           (Destination.Rows = 2 and then Destination.Columns = 2,
            "valid Pyramid_Down C ABI call must use natural size");
      end Check_Success_Down;

      procedure Check_Success_Up is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status := C_API.Pyramid_Up (Source_Handle, Destination_Handle);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "valid Pyramid_Up C ABI call must succeed");
         AUnit.Assertions.Assert
           (Destination.Rows = 8 and then Destination.Columns = 8,
            "valid Pyramid_Up C ABI call must double dimensions");
      end Check_Success_Up;
   begin
      OpenCV.Core.Set_To (UInt8_Source, (others => 40.0));
      Check_Down (Int32_Source, C_API.Border_Reflect_101, "CV_64F");
      Check_Down (Three_D, C_API.Border_Reflect_101, "two-dimensional");
      Check_Down (UInt8_Source, C_API.Border_Constant, "Constant_Border");
      Check_Down (UInt8_Source, 99, "border");
      Check_Aliased_Down;
      Check_Success_Down (C_API.Border_Replicate);
      Check_Success_Down (C_API.Border_Wrap);
      Check_Up (Int32_Source, "CV_64F");
      Check_Up (Three_D, "two-dimensional");
      Check_Aliased_Up;
      Check_Success_Up;
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Pyramid_Down even geometry rebinds Destination",
            Pyramid_Down_Even_Geometry_Rebinds'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid_Down odd geometry uses ceiling half",
            Pyramid_Down_Odd_Geometry'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid operations preserve supported depths",
            Supported_Depths_Are_Preserved'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid_Down preserves UInt8 C3 channels",
            Multichannel_Pyramid_Down'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid_Down accepts Replicate Reflect Wrap and default",
            Pyramid_Down_Border_Modes'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid_Up geometry rebinds Destination",
            Pyramid_Up_Geometry_Rebinds'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid_Up preserves a constant Float32 image",
            Pyramid_Up_Constant_Float32'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid_Down then Pyramid_Up is a smoothed reconstruction",
            Down_Then_Up_Is_Smoothed_Reconstruction'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid operations reject invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Pyramid C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Pyramid_Tests;
