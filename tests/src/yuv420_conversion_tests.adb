with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with System;
with YUV420_Fixtures;

package body YUV420_Conversion_Tests is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   package F renames YUV420_Fixtures;
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type F.Samples;
   use type IP.YUV_Color_Order;
   use type Interfaces.Integer_32;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Frame
     (Layout : IP.YUV420_Layout;
      Y      : Natural := 100;
      U      : Natural := 90;
      V      : Natural := 200;
      Width  : Positive := 4;
      Height : Positive := 4) return C.Mat
   is (F.Packed
         (Width,
          Height,
          Layout,
          F.Samples'(0 .. Width * Height - 1 => Y),
          F.Samples'(0 .. Width * Height / 4 - 1 => U),
          F.Samples'(0 .. Width * Height / 4 - 1 => V)));

   function Colors
     (Order  : IP.YUV_Color_Order := IP.BGR_Order;
      Alpha  : Integer := -1;
      Width  : Positive := 4;
      Height : Positive := 4) return C.Mat
   is (F.Color_Image
         (Width,
          Height,
          F.Colors'(0 .. Width * Height - 1 => (200, 100, 50)),
          Order,
          Alpha));

   procedure Metadata
     (Image : C.Mat; Rows, Columns : Positive; Channels : C.Channel_Count) is
   begin
      AUnit.Assertions.Assert
        (Image.Rows = Rows
         and then Image.Columns = Columns
         and then Image.Depth = C.UInt8
         and then Image.Channels = Channels
         and then Image.Is_Continuous,
         "packed owning result metadata");
   end Metadata;

   generic
      Layout : IP.YUV420_Layout;
      Kind : Natural;
   procedure Decode (Test : in out Fixture);
   procedure Decode (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Y         : constant Natural :=
        (case Kind is
           when 0      => 16,
           when 1      => 235,
           when others => 100);
      U         : constant Natural := (if Kind = 2 then 90 else 128);
      V         : constant Natural := (if Kind = 2 then 200 else 128);
      S         : constant C.Mat := Frame (Layout, Y, U, V);
      Before    : constant C.Mat := S.Clone;
      Reference : constant F.RGB := F.Decode_Reference (Y, U, V);
   begin
      for Output in IP.YUV420_Color_Output loop
         declare
            D      : constant C.Mat := IP.Decode_YUV420 (S, Layout, Output);
            Is_RGB : constant Boolean :=
              Output in IP.RGB_Output | IP.RGBA_Output;
         begin
            Metadata
              (D,
               4,
               4,
               (if Output in IP.BGR_Output | IP.RGB_Output then 3 else 4));
            for Row in 0 .. 3 loop
               for Column in 0 .. 3 loop
                  --  These selected samples are stable for reviewed CPU and
                  --  Carotene scalar tails; no general vendor exactness claim.
                  AUnit.Assertions.Assert
                    (F.Byte (D, Row, Column, 0)
                     = (if Is_RGB then Reference.R else Reference.B)
                     and then F.Byte (D, Row, Column, 1) = Reference.G
                     and then F.Byte (D, Row, Column, 2)
                              = (if Is_RGB then Reference.B else Reference.R),
                     "native limited-range color and channel order");
                  if D.Channels = 4 then
                     AUnit.Assertions.Assert
                       (F.Byte (D, Row, Column, 3) = 255,
                        "opaque decode alpha");
                  end if;
               end loop;
            end loop;
            F.Equal (S, Before);
         end;
      end loop;
   end Decode;
   procedure D00 is new Decode (IP.I420, 0);
   procedure D01 is new Decode (IP.I420, 1);
   procedure D02 is new Decode (IP.I420, 2);
   procedure D10 is new Decode (IP.YV12, 0);
   procedure D11 is new Decode (IP.YV12, 1);
   procedure D12 is new Decode (IP.YV12, 2);
   procedure D20 is new Decode (IP.NV12, 0);
   procedure D21 is new Decode (IP.NV12, 1);
   procedure D22 is new Decode (IP.NV12, 2);
   procedure D30 is new Decode (IP.NV21, 0);
   procedure D31 is new Decode (IP.NV21, 1);
   procedure D32 is new Decode (IP.NV21, 2);

   procedure Minimum_And_Clipping (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Layout in IP.YUV420_Layout loop
         for Value of F.Samples'(0, 255) loop
            declare
               S : constant C.Mat :=
                 Frame (Layout, Value, 128, 128, Width => 2, Height => 2);
               D : constant C.Mat := IP.Decode_YUV420 (S, Layout);
               L : constant C.Mat := IP.Extract_YUV420_Luma (S);
            begin
               Metadata (D, 2, 2, 3);
               for Channel in 0 .. 2 loop
                  AUnit.Assertions.Assert
                    (F.Byte (D, 0, 0, Channel) = Value,
                     "out-of-studio bytes saturate, never reject");
               end loop;
               AUnit.Assertions.Assert
                 (F.Byte (L, 0, 0) = Value, "luma never rescales");
            end;
         end loop;
      end loop;
   end Minimum_And_Clipping;

   generic
      Layout : IP.YUV420_Semiplanar_Layout;
      Regions : Boolean;
   procedure Pair (Test : in out Fixture);
   procedure Pair (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Y         : constant F.Samples :=
        (16, 32, 100, 235, 0, 255, 78, 154, 62, 100, 115, 204, 17, 34, 67, 89);
      U         : constant F.Samples := (90, 128, 16, 240);
      V         : constant F.Samples := (16, 200, 240, 64);
      Packed    : constant C.Mat := F.Packed (4, 4, Layout, Y, U, V);
      Y_Parent  : C.Mat := C.Create (6, 11, (C.UInt8, 1));
      UV_Parent : C.Mat := C.Create (5, 9, (C.UInt8, 2));
      Y_Source  : C.Mat := F.Y_Plane (4, 4, Y);
      UV_Source : C.Mat := F.UV_Plane (4, 4, Layout, U, V);
   begin
      if Regions then
         Y_Parent.Set_To ((others => 201.0));
         UV_Parent.Set_To ((others => 57.0));
         declare
            Y_View  : C.Mat := Y_Parent.Region ((2, 1, 4, 4));
            UV_View : C.Mat := UV_Parent.Region ((1, 2, 2, 2));
         begin
            Y_Source.Copy_To (Y_View);
            UV_Source.Copy_To (UV_View);
            Y_Source := Y_View;
            UV_Source := UV_View;
         end;
      end if;
      declare
         YC  : constant C.Mat := Y_Source.Clone;
         UVC : constant C.Mat := UV_Source.Clone;
      begin
         for Output in IP.YUV420_Color_Output loop
            declare
               A        : constant C.Mat :=
                 IP.Decode_YUV420 (Packed, Layout, Output);
               B        : constant C.Mat :=
                 IP.Decode_YUV420_Two_Plane
                   (Y_Source, UV_Source, Layout, Output);
               Expected : constant C.Mat :=
                 IP.Decode_YUV420_Two_Plane (YC, UVC, Layout, Output);
            begin
               F.Equal (A, B);
               F.Equal (B, Expected);
               F.Equal (Y_Source, YC);
               F.Equal (UV_Source, UVC);
               if Regions then
                  Y_Parent.Set_To ((others => 19.0));
                  UV_Parent.Set_To ((others => 243.0));
                  YC.Copy_To (Y_Source);
                  UVC.Copy_To (UV_Source);
                  F.Equal
                    (Expected,
                     IP.Decode_YUV420_Two_Plane
                       (Y_Source, UV_Source, Layout, Output));
               end if;
            end;
         end loop;
         declare
            A      : constant C.Mat :=
              IP.Decode_YUV420_Two_Plane (Y_Source, UV_Source, Layout);
            Before : constant C.Mat := A.Clone;
         begin
            Y_Parent.Set_To ((others => 0.0));
            UV_Parent.Set_To ((others => 255.0));
            F.Equal (A, Before);
         end;
      end;
   end Pair;
   procedure P0 is new Pair (IP.NV12, False);
   procedure P1 is new Pair (IP.NV21, False);
   procedure P2 is new Pair (IP.NV12, True);
   procedure P3 is new Pair (IP.NV21, True);

   generic
      Layout : IP.YUV420_Layout;
   procedure Luma (Test : in out Fixture);
   procedure Luma (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Y      : constant F.Samples := (0, 16, 32, 64, 100, 235, 240, 255);
      A      : constant C.Mat :=
        F.Packed (4, 2, Layout, Y, (1, 99), (240, 11));
      B      : constant C.Mat :=
        F.Packed (4, 2, Layout, Y, (255, 0), (0, 255));
      Before : constant C.Mat := A.Clone;
      D      : constant C.Mat := IP.Extract_YUV420_Luma (A);
   begin
      Metadata (D, 2, 4, 1);
      F.Equal (D, F.Y_Plane (4, 2, Y));
      F.Equal (D, IP.Extract_YUV420_Luma (B));
      F.Equal (A, Before);
   end Luma;
   procedure L0 is new Luma (IP.I420);
   procedure L1 is new Luma (IP.YV12);
   procedure L2 is new Luma (IP.NV12);
   procedure L3 is new Luma (IP.NV21);

   generic
      Layout : IP.YUV420_Planar_Layout;
      Order : IP.YUV_Color_Order;
      Alpha : Integer;
   procedure Encode (Test : in out Fixture);
   procedure Encode (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Values : constant F.Colors :=
        ((0, 0, 0),
         (255, 255, 255),
         (200, 100, 50),
         (255, 0, 0),
         (0, 255, 0),
         (0, 0, 255));
   begin
      for Color of Values loop
         declare
            S      : constant C.Mat :=
              F.Color_Image (4, 2, F.Colors'(0 .. 7 => Color), Order, Alpha);
            Before : constant C.Mat := S.Clone;
            D      : constant C.Mat :=
              IP.Encode_YUV420_Planar (S, Layout, Order);
         begin
            Metadata (D, 3, 4, 1);
            for Plane in F.Plane_Kind loop
               for Value of F.Read_Plane (D, Layout, Plane) loop
                  AUnit.Assertions.Assert
                    (Value = F.Encode_Reference (Color, Plane),
                     "independently read native Y/U/V bytes");
               end loop;
            end loop;
            F.Equal (S, Before);
         end;
      end loop;
   end Encode;
   procedure E0 is new Encode (IP.I420, IP.BGR_Order, -1);
   procedure E1 is new Encode (IP.I420, IP.RGB_Order, -1);
   procedure E2 is new Encode (IP.I420, IP.BGR_Order, 128);
   procedure E3 is new Encode (IP.I420, IP.RGB_Order, 0);
   procedure E4 is new Encode (IP.YV12, IP.BGR_Order, -1);
   procedure E5 is new Encode (IP.YV12, IP.RGB_Order, -1);
   procedure E6 is new Encode (IP.YV12, IP.BGR_Order, 1);
   procedure E7 is new Encode (IP.YV12, IP.RGB_Order, 255);

   generic
      Width : Positive;
   procedure Sampling (Test : in out Fixture);
   procedure Sampling (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Pixels  : F.Colors (0 .. Width * 4 - 1);
      Changed : F.Colors (Pixels'Range);
   begin
      for I in Pixels'Range loop
         Pixels (I) := (I * 19 mod 256, I * 47 mod 256, I * 113 mod 256);
         Changed (I) :=
           (if (I / Width) mod 2 = 0 and then (I mod Width) mod 2 = 0
            then Pixels (I)
            else (255, 255, 255));
      end loop;
      for Layout in IP.YUV420_Planar_Layout loop
         for Order in IP.YUV_Color_Order loop
            for Alpha in -1 .. 0 loop
               declare
                  S     : constant C.Mat :=
                    F.Color_Image (Width, 4, Pixels, Order, Alpha);
                  T     : constant C.Mat :=
                    F.Color_Image (Width, 4, Changed, Order, Alpha);
                  D     : constant C.Mat :=
                    IP.Encode_YUV420_Planar (S, Layout, Order);
                  Other : constant C.Mat :=
                    IP.Encode_YUV420_Planar (T, Layout, Order);
                  Y     : constant F.Samples := F.Read_Plane (D, Layout, F.Y);
               begin
                  for I in Y'Range loop
                     AUnit.Assertions.Assert
                       (Y (I) = F.Encode_Reference (Pixels (I), F.Y),
                        "every Y sample is per-pixel");
                  end loop;
                  for Plane in F.U .. F.V loop
                     declare
                        UV : constant F.Samples :=
                          F.Read_Plane (D, Layout, Plane);
                     begin
                        for I in UV'Range loop
                           AUnit.Assertions.Assert
                             (UV (I)
                              = F.Encode_Reference
                                  (Pixels
                                     ((I / (Width / 2))
                                      * 2
                                      * Width
                                      + (I mod (Width / 2)) * 2),
                                   Plane),
                              "chroma samples top-left, never averages");
                        end loop;
                        AUnit.Assertions.Assert
                          (UV = F.Read_Plane (Other, Layout, Plane),
                           "unsampled colors do not affect chroma");
                     end;
                  end loop;
               end;
            end loop;
         end loop;
      end loop;
   end Sampling;
   procedure S0 is new Sampling (4);
   procedure S1 is new Sampling (66);

   procedure Alpha_Ignored (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Layout in IP.YUV420_Planar_Layout loop
         for Order in IP.YUV_Color_Order loop
            declare
               Expected : constant C.Mat :=
                 IP.Encode_YUV420_Planar (Colors (Order, 0), Layout, Order);
            begin
               for Alpha of F.Samples'(1, 128, 255) loop
                  F.Equal
                    (Expected,
                     IP.Encode_YUV420_Planar
                       (Colors (Order, Alpha), Layout, Order));
               end loop;
            end;
         end loop;
      end loop;
   end Alpha_Ignored;

   procedure Plane_Order (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat := Colors;
      I : constant C.Mat := IP.Encode_YUV420_Planar (S, IP.I420);
      V : constant C.Mat := IP.Encode_YUV420_Planar (S, IP.YV12);
   begin
      for Plane in F.Plane_Kind loop
         AUnit.Assertions.Assert
           (F.Read_Plane (I, IP.I420, Plane)
            = F.Read_Plane (V, IP.YV12, Plane),
            "only plane order differs");
      end loop;
      AUnit.Assertions.Assert
        (F.Read_Plane (I, IP.I420, F.U) /= F.Read_Plane (I, IP.I420, F.V),
         "asymmetric color distinguishes U from V");
   end Plane_Order;

   generic
      Kind : Natural;
      Layout : IP.YUV420_Layout := IP.YV12;
      Alpha : Integer := 128;
   procedure Region (Test : in out Fixture);
   procedure Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant C.Mat :=
        (if Kind = 0 then Colors (Alpha => Alpha) else Frame (Layout));
      Parent : C.Mat :=
        C.Create
          (Source.Rows + 3,
           Source.Columns + 7,
           (Source.Depth, Source.Channels));
      View   : C.Mat :=
        Parent.Region
          ((2,
            1,
            OpenCV.Size_Coordinate (Source.Columns),
            OpenCV.Size_Coordinate (Source.Rows)));
      function Convert (S : C.Mat) return C.Mat
      is (case Kind is
            when 0      => IP.Encode_YUV420_Planar (S, IP.I420),
            when 1      => IP.Decode_YUV420 (S, Layout),
            when others => IP.Extract_YUV420_Luma (S));
   begin
      Parent.Set_To ((others => 91.0));
      Source.Copy_To (View);
      declare
         Snapshot : constant C.Mat := View.Clone;
         D        : constant C.Mat := Convert (View);
         Before   : constant C.Mat := D.Clone;
      begin
         F.Equal (D, Convert (Snapshot));
         F.Equal (View, Source);
         Parent.Set_To ((others => 255.0));
         Source.Copy_To (View);
         F.Equal (D, Convert (View));
         Parent.Set_To ((others => 0.0));
         F.Equal (D, Before);
      end;
   end Region;
   procedure R0 is new Region (0);
   procedure R1 is new Region (1);
   procedure R2 is new Region (2);
   procedure R3 is new Region (1, IP.NV12);
   procedure R4 is new Region (0, IP.YV12, -1);

   procedure Independence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S      : constant C.Mat := Frame (IP.NV12);
      Y      : constant C.Mat := F.Y_Plane (4, 4, F.Samples'(0 .. 15 => 100));
      UV     : constant C.Mat :=
        F.UV_Plane (4, 4, IP.NV12, (90, 90, 90, 90), (200, 200, 200, 200));
      RGB    : constant C.Mat := Colors;
      Before : constant C.Mat := S.Clone;
   begin
      for Kind in 0 .. 3 loop
         declare
            function Convert return C.Mat
            is (case Kind is
                  when 0      => IP.Decode_YUV420 (S, IP.NV12),
                  when 1      => IP.Decode_YUV420_Two_Plane (Y, UV, IP.NV12),
                  when 2      => IP.Encode_YUV420_Planar (RGB, IP.I420),
                  when others => IP.Extract_YUV420_Luma (S));
            A    : C.Mat := Convert;
            B    : constant C.Mat := Convert;
            Copy : constant C.Mat := B.Clone;
         begin
            A.Set_To ((others => 0.0));
            F.Equal (B, Copy);
            F.Equal (S, Before);
            F.Equal (RGB, Colors);
            F.Equal (Y, F.Y_Plane (4, 4, F.Samples'(0 .. 15 => 100)));
            AUnit.Assertions.Assert
              (F.Byte (UV, 0, 0, 0) = 90, "borrowed UV remains usable");
         end;
      end loop;
   end Independence;

   procedure Round_Trip (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat := Colors;
      D : constant C.Mat :=
        IP.Decode_YUV420 (IP.Encode_YUV420_Planar (S, IP.I420), IP.I420);
   begin
      for Channel in 0 .. 2 loop
         AUnit.Assertions.Assert
           (abs (Integer (F.Byte (S, 0, 0, Channel))
                 - Integer (F.Byte (D, 0, 0, Channel)))
            <= 2,
            "constant-color lossy quantization bounded by two bytes");
      end loop;
   end Round_Trip;

   procedure Textured_Loss (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Pixels : F.Colors (0 .. 15);
   begin
      for I in Pixels'Range loop
         Pixels (I) := (100 + I, 105 + I, 110 + I);
      end loop;
      declare
         S : constant C.Mat := F.Color_Image (4, 4, Pixels, IP.BGR_Order);
         D : constant C.Mat :=
           IP.Decode_YUV420 (IP.Encode_YUV420_Planar (S, IP.YV12), IP.YV12);
      begin
         for Row in 0 .. 3 loop
            for Column in 0 .. 3 loop
               for Channel in 0 .. 2 loop
                  AUnit.Assertions.Assert
                    (abs (Integer (F.Byte (S, Row, Column, Channel))
                          - Integer (F.Byte (D, Row, Column, Channel)))
                     <= 3,
                     "near-neutral texture has bounded lossy error");
               end loop;
            end loop;
         end loop;
      end;
   end Textured_Loss;

   function Bad
     (Rows     : Positive := 6;
      Columns  : Positive := 4;
      Depth    : C.Depth_Type := C.UInt8;
      Channels : C.Channel_Count := 1;
      ND       : Boolean := False) return C.Mat
   is
      S : C.Mat :=
        (if ND
         then C.Create (C.Dimension_Array'(2, 2, 2), (Depth, Channels))
         else C.Create (Rows, Columns, (Depth, Channels)));
   begin
      S.Set_To ((others => 37.0));
      return S;
   end Bad;

   procedure Reject (S : C.Mat; Kind : Natural; UV : C.Mat) is
      Before    : constant C.Mat := S.Clone;
      UV_Before : constant C.Mat := UV.Clone;
      Raised    : Boolean := False;
   begin
      begin
         declare
            D : constant C.Mat :=
              (case Kind is
                 when 0      => IP.Decode_YUV420 (S, IP.I420),
                 when 1      => IP.Extract_YUV420_Luma (S),
                 when 2      => IP.Encode_YUV420_Planar (S, IP.I420),
                 when others => IP.Decode_YUV420_Two_Plane (S, UV, IP.NV12));
         begin
            AUnit.Assertions.Assert (D.Is_Empty, "invalid call returned");
         end;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, "specific OpenCV_Error rejection");
      F.Preserved (S, Before);
      F.Preserved (UV, UV_Before);
   end Reject;

   generic
      Kind : Natural;
   procedure Rejections (Test : in out Fixture);
   procedure Rejections (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty    : C.Mat;
      UV       : constant C.Mat := Bad (2, 2, Channels => 2);
      Channels : constant C.Channel_Count := (if Kind = 2 then 3 else 1);
      procedure Check (S : C.Mat) is
      begin
         Reject (S, Kind, UV);
      end Check;
   begin
      Check (Empty);
      Check (Bad (Channels => Channels, ND => True));
      Check (Bad (Depth => C.UInt16, Channels => Channels));
      Check (Bad (Depth => C.Float32, Channels => Channels));
      Check (Bad (Channels => 2));
      Check (Bad (Columns => 3, Channels => Channels));
      Check (Bad (Columns => 1, Channels => Channels));
      if Kind < 2 then
         Check (Bad (Rows => 4));
         Check (Bad (Rows => 2));
      elsif Kind = 2 then
         Check (Bad (Channels => 1));
         Check (Bad (Rows => 3, Channels => 3));
         Check (Bad (Rows => 1, Channels => 4));
      else
         declare
            Y : constant C.Mat := Bad (4, 4);
         begin
            Reject (Y, Kind, Empty);
            Reject (Y, Kind, Bad (2, 4));
            Reject (Y, Kind, Bad (2, 2, Channels => 3));
            Reject (Y, Kind, Bad (2, 2, Channels => 4));
            Reject (Y, Kind, Bad (2, 2, Depth => C.UInt16, Channels => 2));
            Reject (Y, Kind, Bad (2, 2, Depth => C.Float32, Channels => 2));
            Reject (Y, Kind, Bad (2, 2, Channels => 2, ND => True));
            Reject (Y, Kind, Bad (2, 3, Channels => 2));
            Reject (Y, Kind, Bad (3, 2, Channels => 2));
            Check (Bad (4, 4, Channels => 3));
            Check (Bad (3, 4));
         end;
      end if;
   end Rejections;
   procedure J0 is new Rejections (0);
   procedure J1 is new Rejections (1);
   procedure J2 is new Rejections (2);
   procedure J3 is new Rejections (3);

   function Address is new
     Ada.Unchecked_Conversion
       (C.Module_Interop.Input_Mat_Handle,
        System.Address);
   function Address is new
     Ada.Unchecked_Conversion
       (C.Module_Interop.Output_Mat_Handle,
        System.Address);
   function Raw_Decode
     (S, D : System.Address; Layout, Output : Interfaces.Integer_32)
      return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_decode_yuv420";
   function Raw_Pair
     (Y, UV, D : System.Address; Layout, Output : Interfaces.Integer_32)
      return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_decode_yuv420_two_plane";
   function Raw_Encode
     (S, D : System.Address; Layout, Order : Interfaces.Integer_32)
      return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_encode_yuv420_planar";
   function Raw_Luma (S, D : System.Address) return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_extract_yuv420_luma";

   procedure Raw_Call
     (Kind        : Natural;
      S, UV       : C.Mat;
      D           : in out C.Mat;
      Layout      : Interfaces.Integer_32;
      Selector    : Interfaces.Integer_32 := 0;
      Expected    : Interfaces.Integer_32 := 4;
      Nulls       : Natural := 0;
      Alias_Input : Natural := 0)
   is
      Status : Interfaces.Integer_32 := -1;
      procedure Input (HS : C.Module_Interop.Input_Mat_Handle) is
         procedure Chroma (HUV : C.Module_Interop.Input_Mat_Handle) is
            procedure Output (HD : C.Module_Interop.Output_Mat_Handle) is
               A    : constant System.Address :=
                 (if Nulls = 1
                  then System.Null_Address
                  elsif Alias_Input = 1
                  then Address (HD)
                  else Address (HS));
               B    : constant System.Address :=
                 (if Nulls = 2
                  then System.Null_Address
                  elsif Alias_Input = 2
                  then Address (HD)
                  else Address (HUV));
               Dest : constant System.Address :=
                 (if Nulls = 3 then System.Null_Address else Address (HD));
            begin
               Status :=
                 (case Kind is
                    when 0      => Raw_Decode (A, Dest, Layout, Selector),
                    when 1      => Raw_Pair (A, B, Dest, Layout, Selector),
                    when 2      => Raw_Encode (A, Dest, Layout, Selector),
                    when others => Raw_Luma (A, Dest));
            end Output;
         begin
            C.Module_Interop.With_Output_Handle (D, Output'Access);
         end Chroma;
      begin
         C.Module_Interop.With_Input_Handle (UV, Chroma'Access);
      end Input;
   begin
      C.Module_Interop.With_Input_Handle (S, Input'Access);
      AUnit.Assertions.Assert (Status = Expected, "raw YUV420 status");
   end Raw_Call;

   generic
      Kind : Natural;
   procedure Raw_Atomic (Test : in out Fixture);
   procedure Raw_Atomic (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty  : C.Mat;
      S      : constant C.Mat :=
        (case Kind is
           when 1      => Bad (4, 4),
           when 2      => Colors,
           when others => Frame (IP.I420));
      UV     : constant C.Mat := Bad (2, 2, Channels => 2);
      D      : C.Mat := Bad (2, 2);
      Shared : constant C.Mat := D;
      Layout : constant Interfaces.Integer_32 := (if Kind = 1 then 2 else 0);
      procedure Check
        (Source : C.Mat;
         Chroma : C.Mat;
         L      : Interfaces.Integer_32;
         O      : Interfaces.Integer_32 := 0;
         Nulls  : Natural := 0)
      is
         Before      : constant C.Mat := D.Clone;
         Source_Copy : constant C.Mat := Source.Clone;
         UV_Copy     : constant C.Mat := Chroma.Clone;
      begin
         Raw_Call (Kind, Source, Chroma, D, L, O, Nulls => Nulls);
         F.Equal (D, Before);
         F.Preserved (Source, Source_Copy);
         F.Preserved (Chroma, UV_Copy);
         F.Set_Byte (D, 0, 0, 71);
         AUnit.Assertions.Assert
           (F.Byte (Shared, 0, 0) = 71,
            "failure retained shared storage identity");
         F.Set_Byte (D, 0, 0, 37);
      end Check;
   begin
      if Kind /= 3 then
         Check (S, UV, -1);
         Check (S, UV, 4);
         Check (S, UV, Layout, -1);
         Check (S, UV, Layout, 4);
         if Kind = 1 then
            Check (S, UV, 0);
         elsif Kind = 2 then
            Check (S, UV, 2);
            Check (S, UV, 0, 2);
         end if;
      end if;
      Check (Empty, UV, Layout);
      Check (Bad (ND => True), UV, Layout);
      Check (Bad (Depth => C.UInt16), UV, Layout);
      Check (Bad (Depth => C.Float32), UV, Layout);
      Check (Bad (Channels => 2), UV, Layout);
      Check (Bad (Columns => 3), UV, Layout);
      Check (Bad (Rows => 1), UV, Layout);
      if Kind = 1 then
         Check (S, Empty, Layout);
         Check (S, Bad (2, 4), Layout);
         Check (S, Bad (2, 2, Channels => 3), Layout);
         Check (S, Bad (2, 2, Channels => 4), Layout);
         Check (S, Bad (2, 2, Depth => C.UInt16, Channels => 2), Layout);
         Check (S, Bad (2, 2, Depth => C.Float32, Channels => 2), Layout);
         Check (S, Bad (2, 2, Channels => 2, ND => True), Layout);
         Check (S, Bad (3, 2, Channels => 2), Layout);
         Check (S, Bad (2, 3, Channels => 2), Layout);
         Check (Bad (3, 4), UV, Layout);
         Check (S, UV, Layout, Nulls => 2);
      elsif Kind = 2 then
         Check (Bad (Channels => 1), UV, Layout);
         Check (Bad (Depth => C.UInt16, Channels => 3), UV, Layout);
         Check (Bad (Depth => C.Float32, Channels => 4), UV, Layout);
         Check (Bad (Channels => 3, ND => True), UV, Layout);
         Check (Bad (Rows => 3, Channels => 3), UV, Layout);
         Check (Bad (Columns => 3, Channels => 4), UV, Layout);
      else
         Check (Bad (Rows => 4), UV, Layout);
      end if;
      Check (S, UV, Layout, Nulls => 1);
      Check (S, UV, Layout, Nulls => 3);
      Raw_Call (Kind, S, UV, D, Layout, Expected => 0);
      F.Equal
        (D,
         (case Kind is
            when 0      => IP.Decode_YUV420 (S, IP.I420),
            when 1      => IP.Decode_YUV420_Two_Plane (S, UV, IP.NV12),
            when 2      => IP.Encode_YUV420_Planar (S, IP.I420),
            when others => IP.Extract_YUV420_Luma (S)));
   end Raw_Atomic;
   procedure A0 is new Raw_Atomic (0);
   procedure A1 is new Raw_Atomic (1);
   procedure A2 is new Raw_Atomic (2);
   procedure A3 is new Raw_Atomic (3);

   procedure Raw_Aliasing (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UV : constant C.Mat :=
        F.UV_Plane (4, 4, IP.NV12, (90, 90, 90, 90), (200, 200, 200, 200));
      Y  : constant C.Mat := F.Y_Plane (4, 4, F.Samples'(0 .. 15 => 100));
   begin
      for Kind in 0 .. 3 loop
         declare
            S        : constant C.Mat :=
              (case Kind is
                 when 1      => Y,
                 when 2      => Colors,
                 when others => Frame (IP.NV12));
            D        : C.Mat := S.Clone;
            Layout   : constant Interfaces.Integer_32 :=
              (if Kind = 2 then 0 else 2);
            Expected : constant C.Mat :=
              (case Kind is
                 when 0      => IP.Decode_YUV420 (S, IP.NV12),
                 when 1      => IP.Decode_YUV420_Two_Plane (S, UV, IP.NV12),
                 when 2      => IP.Encode_YUV420_Planar (S, IP.I420),
                 when others => IP.Extract_YUV420_Luma (S));
         begin
            Raw_Call (Kind, S, UV, D, Layout, Expected => 0, Alias_Input => 1);
            F.Equal (D, Expected);
            if Kind = 1 then
               D := UV.Clone;
               Raw_Call
                 (Kind, S, UV, D, Layout, Expected => 0, Alias_Input => 2);
               F.Equal (D, Expected);
            end if;
         end;
      end loop;
   end Raw_Aliasing;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Test : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Test));
      end Add;
   begin
      Add ("I420 black all outputs", D00'Access);
      Add ("I420 white all outputs", D01'Access);
      Add ("I420 asymmetric chroma all outputs", D02'Access);
      Add ("YV12 black all outputs", D10'Access);
      Add ("YV12 white all outputs", D11'Access);
      Add ("YV12 asymmetric chroma all outputs", D12'Access);
      Add ("NV12 black all outputs", D20'Access);
      Add ("NV12 white all outputs", D21'Access);
      Add ("NV12 asymmetric chroma all outputs", D22'Access);
      Add ("NV21 black all outputs", D30'Access);
      Add ("NV21 white all outputs", D31'Access);
      Add ("NV21 asymmetric chroma all outputs", D32'Access);
      Add
        ("Minimum frames and full-byte saturation",
         Minimum_And_Clipping'Access);
      Add ("NV12 exact packed and two-plane equality", P0'Access);
      Add ("NV21 exact packed and two-plane equality", P1'Access);
      Add ("NV12 different parent strides normalized", P2'Access);
      Add ("NV21 different parent strides normalized", P3'Access);
      Add ("I420 raw spatial luma", L0'Access);
      Add ("YV12 raw spatial luma", L1'Access);
      Add ("NV12 raw spatial luma", L2'Access);
      Add ("NV21 raw spatial luma", L3'Access);
      Add ("BGR to I420 exact planes", E0'Access);
      Add ("RGB to I420 exact planes", E1'Access);
      Add ("BGRA to I420 exact planes", E2'Access);
      Add ("RGBA to I420 exact planes", E3'Access);
      Add ("BGR to YV12 exact planes", E4'Access);
      Add ("RGB to YV12 exact planes", E5'Access);
      Add ("BGRA to YV12 exact planes", E6'Access);
      Add ("RGBA to YV12 exact planes", E7'Access);
      Add ("Scalar top-left chroma and per-pixel luma", S0'Access);
      Add ("SIMD and tail top-left chroma sampling", S1'Access);
      Add ("Encode ignores all alpha values", Alpha_Ignored'Access);
      Add ("I420 YV12 independent plane order", Plane_Order'Access);
      Add ("Encode C4 Region snapshot", R0'Access);
      Add ("Encode C3 Region snapshot", R4'Access);
      Add ("Packed standalone Region decode", R1'Access);
      Add ("Semiplanar standalone Region decode", R3'Access);
      Add ("Luma Region snapshot", R2'Access);
      Add ("All YUV420 results independent", Independence'Access);
      Add ("Constant-color lossy round trip", Round_Trip'Access);
      Add ("Near-neutral textured lossy round trip", Textured_Loss'Access);
      Add ("Packed decode public rejection", J0'Access);
      Add ("Luma public rejection", J1'Access);
      Add ("Encode public rejection", J2'Access);
      Add ("Two-plane public rejection", J3'Access);
      Add ("Packed raw atomicity and recovery", A0'Access);
      Add ("Two-plane raw atomicity and recovery", A1'Access);
      Add ("Encode raw atomicity and recovery", A2'Access);
      Add ("Luma raw atomicity and recovery", A3'Access);
      Add ("Raw same-handle source publication", Raw_Aliasing'Access);
      return Result'Access;
   end Suite;
end YUV420_Conversion_Tests;
