with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt16_Access;
with OpenCV.Core.Float32_Vec3;
with OpenCV.Core.Float32_Vec3_Access;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing.Internal.C_API;
with Ada.Unchecked_Conversion;
with System;
with OpenCV.Image_Processing;
with OpenCV;

package body Color_Conversion_Tests is

   package IP renames OpenCV.Image_Processing;
   package Raw renames OpenCV.Image_Processing.Internal.C_API;
   use type OpenCV.Float32_Value;
   use type Raw.Status;
   use type System.Address;

   function As_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Input_Mat_Handle,
        System.Address);
   function As_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Output_Mat_Handle,
        System.Address);
   function Raw_Convert
     (Source, Destination : System.Address; Selector : Interfaces.Integer_32)
      return Raw.Status
   with Import, Convention => C, External_Name => "opencv_imgproc_cvt_color";

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;

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

   procedure BGR_To_Gray_Preserves_Geometry_And_Source (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 0, 0, (10, 20, 30));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 1, (255, 0, 0));

      OpenCV.Image_Processing.Convert_Color
        (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);

      AUnit.Assertions.Assert
        (Destination.Rows = Source.Rows
         and then Destination.Columns = Source.Columns
         and then Destination.Channels = 1
         and then Destination.Depth = OpenCV.Core.UInt8,
         "BGR-to-gray output must preserve geometry and have one UInt8"
         & " channel");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 22
         and then OpenCV.Core.UInt8_Access.Get (Destination, 1, 1) = 29,
         "BGR-to-gray output must use OpenCV grayscale coefficients");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Source, 0, 0) = (10, 20, 30)
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Source, 1, 1)
                  = (255, 0, 0),
         "color conversion must not invalidate or modify the source Mat");
   end BGR_To_Gray_Preserves_Geometry_And_Source;

   procedure BGR_To_Gray_Rejects_BGRA_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 4));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Convert is
      begin
         OpenCV.Image_Processing.Convert_Color
           (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);
      end Convert;
   begin
      Assert_Raises_OpenCV_Error
        (Convert'Access,
         "BGR_To_Gray must reject four-channel BGRA source Mats");
   end BGR_To_Gray_Rejects_BGRA_Source;

   procedure BGR_To_Gray_Rejects_Unsupported_Depth (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int16, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Convert is
      begin
         OpenCV.Image_Processing.Convert_Color
           (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);
      end Convert;
   begin
      Assert_Raises_OpenCV_Error
        (Convert'Access, "BGR_To_Gray must reject unsupported source depths");
   end BGR_To_Gray_Rejects_Unsupported_Depth;

   procedure BGR_To_Gray_Rejects_Empty_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (0, 0, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Convert is
      begin
         OpenCV.Image_Processing.Convert_Color
           (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);
      end Convert;
   begin
      Assert_Raises_OpenCV_Error
        (Convert'Access, "BGR_To_Gray must reject empty source Mats");
   end BGR_To_Gray_Rejects_Empty_Source;

   procedure BGR_To_Gray_Rejects_Three_Dimensional_Source
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Convert is
      begin
         OpenCV.Image_Processing.Convert_Color
           (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);
      end Convert;
   begin
      Assert_Raises_OpenCV_Error
        (Convert'Access,
         "BGR_To_Gray must reject three-dimensional source Mats");
   end BGR_To_Gray_Rejects_Three_Dimensional_Source;

   procedure BGR_To_Gray_Accepts_UInt16_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt16, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Convert_Color
        (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);

      AUnit.Assertions.Assert
        (Destination.Rows = Source.Rows
         and then Destination.Columns = Source.Columns
         and then Destination.Depth = OpenCV.Core.UInt16
         and then Destination.Channels = 1,
         "BGR_To_Gray must accept UInt16 C3 and produce UInt16 C1");
   end BGR_To_Gray_Accepts_UInt16_Source;

   procedure BGR_To_Gray_Accepts_Float32_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Source      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 3));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Image_Processing.Convert_Color
        (Source, Destination, OpenCV.Image_Processing.BGR_To_Gray);

      AUnit.Assertions.Assert
        (Destination.Rows = Source.Rows
         and then Destination.Columns = Source.Columns
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "BGR_To_Gray must accept Float32 C3 and produce Float32 C1");
   end BGR_To_Gray_Accepts_Float32_Source;

   function Pixel
     (Image : OpenCV.Core.Mat; Channel : Natural) return Interfaces.Unsigned_8
   is
      Plane : constant OpenCV.Core.Mat := Image.Extract_Channel (Channel);
   begin
      return OpenCV.Core.UInt8_Access.Get (Plane, 0, 0);
   end Pixel;

   procedure Layout_And_Alpha (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      A, B : OpenCV.Core.Mat;
      G    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (S, 0, 0, (10, 20, 30));
      IP.Convert_Color (S, A, IP.BGR_To_RGBA);
      AUnit.Assertions.Assert
        (A.Channels = 4
         and then Pixel (A, 0) = 30
         and then Pixel (A, 1) = 20
         and then Pixel (A, 2) = 10
         and then Pixel (A, 3) = 255,
         "BGR->RGBA inserts max alpha and swaps R/B");
      IP.Convert_Color (A, B, IP.RGBA_To_BGRA);
      AUnit.Assertions.Assert
        (Pixel (B, 0) = 10
         and then Pixel (B, 1) = 20
         and then Pixel (B, 2) = 30
         and then Pixel (B, 3) = 255,
         "RGBA->BGRA preserves alpha");
      IP.Convert_Color (A, B, IP.RGBA_To_BGR);
      AUnit.Assertions.Assert
        (B.Channels = 3 and then Pixel (B, 0) = 10 and then Pixel (B, 2) = 30,
         "RGBA->BGR drops alpha");
      IP.Convert_Color (S, B, IP.BGR_To_RGB);
      AUnit.Assertions.Assert
        (Pixel (B, 0) = 30 and then Pixel (B, 2) = 10, "BGR->RGB exact swap");
      OpenCV.Core.UInt8_Access.Set (G, 0, 0, 77);
      IP.Convert_Color (G, A, IP.Gray_To_BGRA);
      AUnit.Assertions.Assert
        (Pixel (A, 0) = 77
         and then Pixel (A, 1) = 77
         and then Pixel (A, 2) = 77
         and then Pixel (A, 3) = 255,
         "Gray->BGRA copies luminance and inserts alpha");
      IP.Convert_Color (G, A, IP.Gray_To_RGBA);
      AUnit.Assertions.Assert
        (Pixel (A, 0) = 77 and then Pixel (A, 3) = 255,
         "Gray->RGBA inserts opaque alpha");
      IP.Convert_Color (S, A, IP.BGR_To_BGRA);
      IP.Convert_Color (A, B, IP.BGRA_To_BGR);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (B, 0, 0) = (10, 20, 30),
         "add/remove alpha round trip");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (S, 0, 0) = (10, 20, 30),
         "source preserved");
   end Layout_And_Alpha;

   procedure All_Selectors_Dispatch (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Conversion in IP.Color_Conversion loop
         declare
            Name            : constant String :=
              IP.Color_Conversion'Image (Conversion);
            Input_Channels  : constant Positive :=
              (if Name (1 .. 5) = "GRAY_"
               then 1
               elsif Name (1 .. 6) in "BGR565" | "BGR555"
               then 2
               elsif Name (1 .. 5) = "BGRA_" or else Name (1 .. 5) = "RGBA_"
               then 4
               else 3);
            Output_Channels : constant Positive :=
              (if Name (Name'Last - 4 .. Name'Last) = "_GRAY"
               then 1
               elsif Name (Name'Last - 5 .. Name'Last) in "BGR565" | "BGR555"
               then 2
               elsif Name (Name'Last - 4 .. Name'Last) = "_BGRA"
                 or else Name (Name'Last - 4 .. Name'Last) = "_RGBA"
               then 4
               else 3);
            Source          : constant OpenCV.Core.Mat :=
              OpenCV.Core.Create
                (2,
                 2,
                 (OpenCV.Core.UInt8,
                  OpenCV.Core.Channel_Count (Input_Channels)));
            Destination     : OpenCV.Core.Mat;
         begin
            IP.Convert_Color (Source, Destination, Conversion);
            AUnit.Assertions.Assert
              (Destination.Rows = 2
               and then Destination.Columns = 2
               and then Destination.Depth = OpenCV.Core.UInt8
               and then Natural (Destination.Channels) = Output_Channels,
               "dispatch " & Name);
         end;
      end loop;
   end All_Selectors_Dispatch;

   procedure Depth_And_Color_Spaces (Test : in out Fixture) is
      pragma Unreferenced (Test);
      U       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
      F       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 3));
      D, B, H : OpenCV.Core.Mat;
   begin
      OpenCV.Core.UInt16_Access.Set (U, 0, 0, 1_234);
      IP.Convert_Color (U, D, IP.Gray_To_RGBA);
      declare
         Alpha : constant OpenCV.Core.Mat := D.Extract_Channel (3);
      begin
         AUnit.Assertions.Assert
           (D.Depth = OpenCV.Core.UInt16
            and then D.Channels = 4
            and then OpenCV.Core.UInt16_Access.Get (Alpha, 0, 0) = 65_535,
            "UInt16 alpha insertion");
      end;
      OpenCV.Core.Float32_Vec3_Access.Set (F, 0, 0, (0.2, 0.4, 0.8));
      IP.Convert_Color (F, D, IP.BGR_To_BGRA);
      declare
         Alpha : constant OpenCV.Core.Mat := D.Extract_Channel (3);
      begin
         AUnit.Assertions.Assert
           (OpenCV.Core.Float32_Access.Get (Alpha, 0, 0) = 1.0,
            "Float32 alpha is 1.0");
      end;
      for Kind in IP.Color_Conversion range IP.BGR_To_Lab .. IP.RGB_To_Luv loop
         if Kind
            in IP.BGR_To_Lab | IP.RGB_To_Lab | IP.BGR_To_Luv | IP.RGB_To_Luv
         then
            declare
               Inverse : constant IP.Color_Conversion :=
                 (case Kind is
                    when IP.BGR_To_Lab => IP.Lab_To_BGR,
                    when IP.RGB_To_Lab => IP.Lab_To_RGB,
                    when IP.BGR_To_Luv => IP.Luv_To_BGR,
                    when others        => IP.Luv_To_RGB);
            begin
               IP.Convert_Color (F, D, Kind);
               IP.Convert_Color (D, B, Inverse);
               declare
                  V : constant OpenCV.Core.Float32_Vec3.Vector :=
                    OpenCV.Core.Float32_Vec3_Access.Get (B, 0, 0);
               begin
                  for C in 0 .. 2 loop
                     AUnit.Assertions.Assert
                       (abs (V (C)
                             - OpenCV.Core.Float32_Vec3_Access.Get (F, 0, 0)
                                 (C))
                        < 0.02,
                        "normalized Lab/Luv round trip");
                  end loop;
               end;
            end;
         end if;
      end loop;
      IP.Convert_Color (F, H, IP.BGR_To_HSV);
      IP.Convert_Color (H, B, IP.HSV_To_BGR);
      AUnit.Assertions.Assert
        (abs (OpenCV.Core.Float32_Vec3_Access.Get (B, 0, 0) (0) - 0.2) < 0.01,
         "Float32 HSV round trip");
   end Depth_And_Color_Spaces;

   procedure Raw_And_Alias (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S                  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      D                  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      E                  : OpenCV.Core.Mat;
      N                  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 3));
      F                  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 3));
      Hs, Hd, He, Hn, Hf : System.Address := System.Null_Address;
      procedure Input_S (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Hs := As_Address (H);
      end Input_S;
      procedure Input_E (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         He := As_Address (H);
      end Input_E;
      procedure Input_N (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Hn := As_Address (H);
      end Input_N;
      procedure Input_F (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Hf := As_Address (H);
      end Input_F;
      procedure Output_D (H : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Hd := As_Address (H);
      end Output_D;
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (S, 0, 0, (10, 20, 30));
      OpenCV.Core.UInt8_Access.Set (D, 0, 0, 71);
      OpenCV.Core.Module_Interop.With_Input_Handle (S, Input_S'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle (E, Input_E'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle (N, Input_N'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle (F, Input_F'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle (D, Output_D'Access);
      AUnit.Assertions.Assert
        (Raw_Convert (System.Null_Address, Hd, 0) = Raw.Error_Invalid_Argument
         and then Raw_Convert (Hs, System.Null_Address, 0)
                  = Raw.Error_Invalid_Argument
         and then Raw_Convert (Hs, Hd, 999) = Raw.Error_Invalid_Argument
         and then Raw_Convert (Hs, Hd, 4) = Raw.Error_Invalid_Argument
         and then Raw_Convert (He, Hd, 0) = Raw.Error_Invalid_Argument
         and then Raw_Convert (Hn, Hd, 0) = Raw.Error_Invalid_Argument
         and then Raw_Convert (Hf, Hd, 0) = Raw.Error_Invalid_Argument
         and then OpenCV.Core.UInt8_Access.Get (D, 0, 0) = 71,
         "raw rejects malformed inputs without changing destination");
      AUnit.Assertions.Assert
        (Raw_Convert (Hs, Hd, 0) = Raw.Success
         and then OpenCV.Core.UInt8_Access.Get (D, 0, 0) = 22,
         "valid raw call after failures");
      IP.Convert_Color (S, S, IP.BGR_To_RGB);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (S, 0, 0) = (30, 20, 10),
         "same-object conversion uses local native output");
   end Raw_And_Alias;

   procedure Primary_Hue_And_Gray (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Color         : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      H, Back, Gray : OpenCV.Core.Mat;
   begin
      for Primary in 0 .. 2 loop
         declare
            Values : OpenCV.Core.UInt8_Vec3.Vector := (0, 0, 0);
         begin
            Values (Primary) := 255;
            OpenCV.Core.UInt8_Vec3_Access.Set (Color, 0, 0, Values);
            IP.Convert_Color (Color, H, IP.BGR_To_HSV);
            AUnit.Assertions.Assert
              (Pixel (H, 0)
               = Interfaces.Unsigned_8
                   ((case Primary is
                       when 0      => 120,
                       when 1      => 60,
                       when others => 0))
               and then Pixel (H, 1) = 255
               and then Pixel (H, 2) = 255,
               "standard UInt8 HSV primary hue");
            IP.Convert_Color (H, Back, IP.HSV_To_BGR);
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Vec3_Access.Get (Back, 0, 0) = Values,
               "HSV inverse restores primary");
            IP.Convert_Color (Color, H, IP.BGR_To_HLS);
            AUnit.Assertions.Assert
              (Pixel (H, 0)
               = Interfaces.Unsigned_8
                   ((case Primary is
                       when 0      => 120,
                       when 1      => 60,
                       when others => 0))
               and then abs (Integer (Pixel (H, 1)) - 128) <= 1
               and then Pixel (H, 2) = 255,
               "standard UInt8 HLS primary hue/lightness/saturation");
            IP.Convert_Color (H, Back, IP.HLS_To_BGR);
            for Channel in 0 .. 2 loop
               AUnit.Assertions.Assert
                 (abs (Integer (Pixel (Back, Channel))
                       - Integer (Values (Channel)))
                  <= 1,
                  "HLS inverse primary rounding");
            end loop;
         end;
      end loop;
      OpenCV.Core.UInt8_Vec3_Access.Set (Color, 0, 0, (0, 0, 255));
      IP.Convert_Color (Color, Gray, IP.BGR_To_Gray);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Gray, 0, 0) = 76,
         "red grayscale uses BGR ordering");
      IP.Convert_Color (Color, Back, IP.BGR_To_Lab);
      AUnit.Assertions.Assert (Back.Channels = 3, "UInt8 Lab available");
   end Primary_Hue_And_Gray;

   procedure Invalid_Depths_And_Channels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      U16 : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 3));
      F64 : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 3));
      C1  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      C3  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      C4  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 4));
      D   : OpenCV.Core.Mat;
      procedure Reject (S : OpenCV.Core.Mat; K : IP.Color_Conversion) is
         procedure Attempt is
         begin
            IP.Convert_Color (S, D, K);
         end Attempt;
      begin
         Assert_Raises_OpenCV_Error
           (Attempt'Access,
            "wrong depth or channels: " & IP.Color_Conversion'Image (K));
      end Reject;
   begin
      for K in IP.Color_Conversion range IP.BGR_To_HSV .. IP.Luv_To_RGB loop
         Reject (U16, K);
      end loop;
      for K in IP.Color_Conversion loop
         Reject (F64, K);
      end loop;
      Reject (C3, IP.Gray_To_BGR);
      Reject (C4, IP.BGR_To_RGB);
      Reject (C3, IP.BGRA_To_Gray);
      Reject (C4, IP.XYZ_To_BGR);
      Reject (C1, IP.HSV_To_BGR);
      IP.Convert_Color (U16, D, IP.BGR_To_XYZ);
      AUnit.Assertions.Assert
        (D.Depth = OpenCV.Core.UInt16, "UInt16 XYZ linear conversion");
   end Invalid_Depths_And_Channels;

   procedure Linear_Spaces_And_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 3));
      S             : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 3));
      Forward, Back : OpenCV.Core.Mat;
      type Conversion_Pair is record
         Forward, Inverse : IP.Color_Conversion;
      end record;
      Pairs         : constant array (Positive range <>) of Conversion_Pair :=
        ((IP.BGR_To_XYZ, IP.XYZ_To_BGR),
         (IP.RGB_To_XYZ, IP.XYZ_To_RGB),
         (IP.BGR_To_YCrCb, IP.YCrCb_To_BGR),
         (IP.RGB_To_YCrCb, IP.YCrCb_To_RGB),
         (IP.BGR_To_YUV, IP.YUV_To_BGR),
         (IP.RGB_To_YUV, IP.YUV_To_RGB));
   begin
      OpenCV.Core.UInt8_Vec3_Access.Set (S, 0, 0, (40, 90, 170));
      for Pair of Pairs loop
         IP.Convert_Color (S, Forward, Pair.Forward);
         IP.Convert_Color (Forward, Back, Pair.Inverse);
         for Channel in 0 .. 2 loop
            AUnit.Assertions.Assert
              (abs (Integer (Pixel (Back, Channel))
                    - Integer (Pixel (S, Channel)))
               <= 4,
               "linear-space RGB/BGR inverse "
               & IP.Color_Conversion'Image (Pair.Forward));
         end loop;
      end loop;
      OpenCV.Core.Set_To (Parent, (others => 0.0));
      OpenCV.Core.UInt8_Vec3_Access.Set (Parent, 1, 1, (10, 20, 30));
      declare
         R : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 1, Y => 1, Width => 1, Height => 1));
      begin
         IP.Convert_Color (R, Back, IP.BGR_To_RGB);
         AUnit.Assertions.Assert
           (Back.Rows = 1
            and then Back.Columns = 1
            and then OpenCV.Core.UInt8_Vec3_Access.Get (Back, 0, 0)
                     = (30, 20, 10)
            and then OpenCV.Core.UInt8_Vec3_Access.Get (Parent, 1, 1)
                     = (10, 20, 30),
            "noncontinuous Region is logical image and parent preserved");
      end;
   end Linear_Spaces_And_Region;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Color layout and alpha", Layout_And_Alpha'Access));
      Result.Add_Test
        (Caller.Create
           ("Color primary hue and gray", Primary_Hue_And_Gray'Access));
      Result.Add_Test
        (Caller.Create
           ("Color invalid depths and channels",
            Invalid_Depths_And_Channels'Access));
      Result.Add_Test
        (Caller.Create
           ("Color linear spaces and Region",
            Linear_Spaces_And_Region'Access));
      Result.Add_Test
        (Caller.Create
           ("Every color selector dispatches", All_Selectors_Dispatch'Access));
      Result.Add_Test
        (Caller.Create
           ("Color depths and spaces", Depth_And_Color_Spaces'Access));
      Result.Add_Test
        (Caller.Create
           ("Color raw atomicity and alias", Raw_And_Alias'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray preserves geometry, values, and source",
            BGR_To_Gray_Preserves_Geometry_And_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray rejects four-channel BGRA source",
            BGR_To_Gray_Rejects_BGRA_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray rejects unsupported source depth",
            BGR_To_Gray_Rejects_Unsupported_Depth'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray rejects empty source",
            BGR_To_Gray_Rejects_Empty_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray rejects three-dimensional source",
            BGR_To_Gray_Rejects_Three_Dimensional_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray accepts UInt16 source",
            BGR_To_Gray_Accepts_UInt16_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("BGR-to-gray accepts Float32 source",
            BGR_To_Gray_Accepts_Float32_Source'Access));
      return Result'Access;
   end Suite;

end Color_Conversion_Tests;
