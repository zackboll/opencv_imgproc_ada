with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float32_Vec3_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt8_Vec4;
with OpenCV.Core.UInt8_Vec4_Access;
with OpenCV.Image_Processing;
with System;

package body Extended_Color_Tests is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   package U3 renames C.UInt8_Vec3_Access;
   package U4 renames C.UInt8_Vec4_Access;
   package F3 renames C.Float32_Vec3_Access;
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type C.UInt8_Vec4.Vector;
   subtype Byte is Interfaces.Unsigned_8;
   subtype Extended is
     IP.Color_Conversion
       range IP.BGR_To_HSV_Full .. IP.Premultiplied_RGBA_To_RGBA;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Channels (K : Extended) return C.Channel_Count
   is (if K in IP.RGBA_To_Premultiplied_RGBA .. IP.Premultiplied_RGBA_To_RGBA
       then 4
       else 3);

   procedure Equal (A, B : C.Mat; Tolerance : Float := 0.0) is
   begin
      AUnit.Assertions.Assert
        (A.Rows = B.Rows
         and then A.Columns = B.Columns
         and then A.Depth = B.Depth
         and then A.Channels = B.Channels,
         "result metadata");
      for Channel in 0 .. Natural (A.Channels) - 1 loop
         declare
            P : constant C.Mat := A.Extract_Channel (Channel);
            Q : constant C.Mat := B.Extract_Channel (Channel);
         begin
            for Y in 0 .. A.Rows - 1 loop
               for X in 0 .. A.Columns - 1 loop
                  if A.Depth = C.UInt8 then
                     AUnit.Assertions.Assert
                       (abs (Integer (C.UInt8_Access.Get (P, Y, X))
                             - Integer (C.UInt8_Access.Get (Q, Y, X)))
                        <= Integer (Tolerance),
                        "UInt8 pixels");
                  else
                     AUnit.Assertions.Assert
                       (abs (Float (C.Float32_Access.Get (P, Y, X))
                             - Float (C.Float32_Access.Get (Q, Y, X)))
                        <= Tolerance,
                        "Float32 pixels");
                  end if;
               end loop;
            end loop;
         end;
      end loop;
   end Equal;

   Colors : constant array (0 .. 8) of C.UInt8_Vec3.Vector :=
     ((0, 0, 0),
      (255, 255, 255),
      (0, 0, 255),
      (0, 255, 0),
      (255, 0, 0),
      (255, 255, 0),
      (255, 0, 255),
      (0, 255, 255),
      (200, 40, 120));
   Hue    : constant array (0 .. 8) of Integer :=
     (0, 0, 0, 85, 171, 128, 213, 43, 192);

   generic
      K : Extended;
      RGB : Boolean;
      HSV : Boolean;
   procedure Full_Forward (Test : in out Fixture);
   procedure Full_Forward (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S                   : C.Mat := C.Create (2, 257, (C.UInt8, 3));
      D, Standard, Before : C.Mat;
   begin
      for Y in 0 .. 1 loop
         for X in 0 .. 256 loop
            declare
               V : constant C.UInt8_Vec3.Vector := Colors (X mod 9);
            begin
               U3.Set (S, Y, X, (if RGB then (V (2), V (1), V (0)) else V));
            end;
         end loop;
      end loop;
      Before := S.Clone;
      IP.Convert_Color (S, D, K);
      IP.Convert_Color
        (S,
         Standard,
         (if HSV
          then (if RGB then IP.RGB_To_HSV else IP.BGR_To_HSV)
          else (if RGB then IP.RGB_To_HLS else IP.BGR_To_HLS)));
      AUnit.Assertions.Assert
        (D.Rows = 2
         and then D.Columns = 257
         and then D.Depth = C.UInt8
         and then D.Channels = 3,
         "FULL forward metadata");
      for X in 0 .. 256 loop
         AUnit.Assertions.Assert
           (abs (Integer (U3.Get (D, 0, X) (0)) - Hue (X mod 9)) <= 1,
            "known FULL hue across vector blocks and scalar tail");
      end loop;
      AUnit.Assertions.Assert
        (U3.Get (D, 0, 6) (0) > 200 and then U3.Get (Standard, 0, 6) (0) < 180,
         "magenta establishes full-byte rather than standard hue");
      AUnit.Assertions.Assert
        (U3.Get (D, 0, 0) (1) = 0
         and then U3.Get (D, 0, 1) (1) = (if HSV then 0 else 255),
         "black/white achromatic encoding");
      Equal (S, Before);
   end Full_Forward;
   procedure HSV_BGR is new Full_Forward (IP.BGR_To_HSV_Full, False, True);
   procedure HSV_RGB is new Full_Forward (IP.RGB_To_HSV_Full, True, True);
   procedure HLS_BGR is new Full_Forward (IP.BGR_To_HLS_Full, False, False);
   procedure HLS_RGB is new Full_Forward (IP.RGB_To_HLS_Full, True, False);

   generic
      K : Extended;
      Standard : IP.Color_Conversion;
      HSV : Boolean;
   procedure Full_Reverse (Test : in out Fixture);
   procedure Full_Reverse (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S                   : C.Mat := C.Create (1, 257, (C.UInt8, 3));
      F                   : C.Mat := C.Create (1, 257, (C.Float32, 3));
      D, Expected, Before : C.Mat;
      Hues                : constant array (0 .. 3) of Byte :=
        (0, 128, 254, 255);
   begin
      for X in 0 .. 256 loop
         U3.Set (S, 0, X, (Hues (X mod 4), (if HSV then 255 else 128), 255));
         F3.Set
           (F,
            0,
            X,
            (OpenCV.Float32_Value (Hues (X mod 4)) * 360.0 / 255.0,
             (if HSV then 1.0 else 128.0 / 255.0),
             1.0));
      end loop;
      Before := S.Clone;
      IP.Convert_Color (S, D, K);
      IP.Convert_Color (F, Expected, Standard);
      for X in 0 .. 256 loop
         for Channel in 0 .. 2 loop
            AUnit.Assertions.Assert
              (abs (Float (U3.Get (D, 0, X) (Channel))
                    - Float (F3.Get (Expected, 0, X) (Channel)) * 255.0)
               < 3.0,
               "FULL reverse uses scale 255, including hue 254/255");
         end loop;
      end loop;
      Equal (S, Before);
   end Full_Reverse;
   procedure HSV_To_BGR is new
     Full_Reverse (IP.HSV_Full_To_BGR, IP.HSV_To_BGR, True);
   procedure HSV_To_RGB is new
     Full_Reverse (IP.HSV_Full_To_RGB, IP.HSV_To_RGB, True);
   procedure HLS_To_BGR is new
     Full_Reverse (IP.HLS_Full_To_BGR, IP.HLS_To_BGR, False);
   procedure HLS_To_RGB is new
     Full_Reverse (IP.HLS_Full_To_RGB, IP.HLS_To_RGB, False);

   generic
      HSV, Reverse_Direction : Boolean;
   procedure Float_Full (Test : in out Fixture);
   procedure Float_Full (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S            : C.Mat := C.Create (1, 257, (C.Float32, 3));
      A, B, Before : C.Mat;
   begin
      for X in 0 .. 256 loop
         F3.Set
           (S,
            0,
            X,
            (if Reverse_Direction
             then (OpenCV.Float32_Value (X) * 359.0 / 256.0, 0.5, 0.75)
             else (0.2, 0.4, OpenCV.Float32_Value (X) / 256.0)));
      end loop;
      Before := S.Clone;
      for RGB in Boolean loop
         declare
            Ordinary : constant IP.Color_Conversion :=
              (if HSV
               then
                 (if Reverse_Direction
                  then (if RGB then IP.HSV_To_RGB else IP.HSV_To_BGR)
                  else (if RGB then IP.RGB_To_HSV else IP.BGR_To_HSV))
               else
                 (if Reverse_Direction
                  then (if RGB then IP.HLS_To_RGB else IP.HLS_To_BGR)
                  else (if RGB then IP.RGB_To_HLS else IP.BGR_To_HLS)));
            Full     : constant Extended :=
              (if HSV
               then
                 (if Reverse_Direction
                  then (if RGB then IP.HSV_Full_To_RGB else IP.HSV_Full_To_BGR)
                  else
                    (if RGB then IP.RGB_To_HSV_Full else IP.BGR_To_HSV_Full))
               else
                 (if Reverse_Direction
                  then (if RGB then IP.HLS_Full_To_RGB else IP.HLS_Full_To_BGR)
                  else
                    (if RGB then IP.RGB_To_HLS_Full else IP.BGR_To_HLS_Full)));
         begin
            IP.Convert_Color (S, A, Ordinary);
            IP.Convert_Color (S, B, Full);
            Equal (A, B, 0.000_01);
         end;
      end loop;
      Equal (S, Before);
   end Float_Full;
   procedure Float_HSV_Forward is new Float_Full (True, False);
   procedure Float_HSV_Reverse is new Float_Full (True, True);
   procedure Float_HLS_Forward is new Float_Full (False, False);
   procedure Float_HLS_Reverse is new Float_Full (False, True);

   generic
      Forward, Backward : Extended;
      Depth : C.Depth_Type;
   procedure Linear_Round_Trip (Test : in out Fixture);
   procedure Linear_Round_Trip (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S                              : C.Mat := C.Create (2, 257, (Depth, 3));
      Space, D, Before, Space_Before : C.Mat;
      Swapped, Swapped_Space         : C.Mat;
      Values                         :
        constant array (0 .. 3) of C.UInt8_Vec3.Vector :=
          ((0, 0, 0), (255, 255, 255), (128, 128, 128), (64, 128, 192));
   begin
      for Y in 0 .. 1 loop
         for X in 0 .. 256 loop
            if Depth = C.UInt8 then
               U3.Set (S, Y, X, Values (X mod 4));
            else
               F3.Set
                 (S,
                  Y,
                  X,
                  (OpenCV.Float32_Value (Values (X mod 4) (0)) / 255.0,
                   OpenCV.Float32_Value (Values (X mod 4) (1)) / 255.0,
                   OpenCV.Float32_Value (Values (X mod 4) (2)) / 255.0));
            end if;
         end loop;
      end loop;
      Before := S.Clone;
      IP.Convert_Color (S, Space, Forward);
      Space_Before := Space.Clone;
      IP.Convert_Color (Space, D, Backward);
      --  Independently establish RGB/BGR order, not just a paired inverse.
      IP.Convert_Color (S, Swapped, IP.BGR_To_RGB);
      case Forward is
         when IP.Linear_BGR_To_Lab =>
            IP.Convert_Color (Swapped, Swapped_Space, IP.Linear_RGB_To_Lab);

         when IP.Linear_RGB_To_Lab =>
            IP.Convert_Color (Swapped, Swapped_Space, IP.Linear_BGR_To_Lab);

         when IP.Linear_BGR_To_Luv =>
            IP.Convert_Color (Swapped, Swapped_Space, IP.Linear_RGB_To_Luv);

         when IP.Linear_RGB_To_Luv =>
            IP.Convert_Color (Swapped, Swapped_Space, IP.Linear_BGR_To_Luv);

         when others               =>
            AUnit.Assertions.Assert (False, "unexpected forward selector");
      end case;
      Equal (Space, Swapped_Space, (if Depth = C.UInt8 then 1.0 else 0.001));
      Equal (S, Before);
      Equal (Space, Space_Before);
      Equal (S, D, (if Depth = C.UInt8 then 8.0 else 0.005));
      if Depth = C.UInt8 then
         AUnit.Assertions.Assert
           (U3.Get (Space, 0, 0) (0) = 0
            and then U3.Get (Space, 0, 1) (0) >= 254,
            "native UInt8 black/white lightness");
      else
         AUnit.Assertions.Assert
           (abs (F3.Get (Space, 0, 0) (0)) < 0.01
            and then abs (F3.Get (Space, 0, 1) (0) - 100.0) < 0.01,
            "native Float32 black/white lightness");
      end if;
   end Linear_Round_Trip;
   procedure Lab_BGR_U8 is new
     Linear_Round_Trip (IP.Linear_BGR_To_Lab, IP.Lab_To_Linear_BGR, C.UInt8);
   procedure Lab_RGB_U8 is new
     Linear_Round_Trip (IP.Linear_RGB_To_Lab, IP.Lab_To_Linear_RGB, C.UInt8);
   procedure Luv_BGR_U8 is new
     Linear_Round_Trip (IP.Linear_BGR_To_Luv, IP.Luv_To_Linear_BGR, C.UInt8);
   procedure Luv_RGB_U8 is new
     Linear_Round_Trip (IP.Linear_RGB_To_Luv, IP.Luv_To_Linear_RGB, C.UInt8);
   procedure Lab_BGR_F32 is new
     Linear_Round_Trip (IP.Linear_BGR_To_Lab, IP.Lab_To_Linear_BGR, C.Float32);
   procedure Lab_RGB_F32 is new
     Linear_Round_Trip (IP.Linear_RGB_To_Lab, IP.Lab_To_Linear_RGB, C.Float32);
   procedure Luv_BGR_F32 is new
     Linear_Round_Trip (IP.Linear_BGR_To_Luv, IP.Luv_To_Linear_BGR, C.Float32);
   procedure Luv_RGB_F32 is new
     Linear_Round_Trip (IP.Linear_RGB_To_Luv, IP.Luv_To_Linear_RGB, C.Float32);

   generic
      Lab : Boolean;
      Depth : C.Depth_Type;
   procedure Transfer_Assumption (Test : in out Fixture);
   procedure Transfer_Assumption (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S    : C.Mat := C.Create (1, 2, (Depth, 3));
      A, B : C.Mat;
   begin
      if Depth = C.UInt8 then
         U3.Set (S, 0, 0, (128, 128, 128));
         U3.Set (S, 0, 1, (64, 128, 192));
      else
         F3.Set (S, 0, 0, (0.5, 0.5, 0.5));
         F3.Set (S, 0, 1, (0.25, 0.5, 0.75));
      end if;
      IP.Convert_Color (S, A, (if Lab then IP.BGR_To_Lab else IP.BGR_To_Luv));
      IP.Convert_Color
        (S, B, (if Lab then IP.Linear_BGR_To_Lab else IP.Linear_BGR_To_Luv));
      for X in 0 .. 1 loop
         if Depth = C.UInt8 then
            AUnit.Assertions.Assert
              (Integer (U3.Get (B, 0, X) (0)) - Integer (U3.Get (A, 0, X) (0))
               > 30,
               "linear UInt8 midtone lightness differs materially from sRGB");
         else
            AUnit.Assertions.Assert
              (F3.Get (B, 0, X) (0) - F3.Get (A, 0, X) (0) > 15.0,
               "linear Float32 midtone differs materially from sRGB");
         end if;
      end loop;
   end Transfer_Assumption;
   procedure Lab_Transfer_U8 is new Transfer_Assumption (True, C.UInt8);
   procedure Lab_Transfer_F32 is new Transfer_Assumption (True, C.Float32);
   procedure Luv_Transfer_U8 is new Transfer_Assumption (False, C.UInt8);
   procedure Luv_Transfer_F32 is new Transfer_Assumption (False, C.Float32);

   generic
      Reverse_Direction : Boolean;
   procedure Alpha_Arithmetic (Test : in out Fixture);
   procedure Alpha_Arithmetic (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S                     : C.Mat := C.Create (1, 257, (C.UInt8, 4));
      D, Before, Round_Trip : C.Mat;
      Alphas                : constant array (0 .. 3) of Byte :=
        (0, 1, 128, 255);
   begin
      for X in 0 .. 256 loop
         U4.Set (S, 0, X, (200, 100, 50, Alphas (X mod 4)));
      end loop;
      Before := S.Clone;
      IP.Convert_Color
        (S,
         D,
         (if Reverse_Direction
          then IP.Premultiplied_RGBA_To_RGBA
          else IP.RGBA_To_Premultiplied_RGBA));
      for X in 0 .. 256 loop
         declare
            A : constant Natural := Natural (Alphas (X mod 4));
         begin
            AUnit.Assertions.Assert
              (U4.Get (D, 0, X) (3) = Byte (A), "alpha preserved");
            for Channel in 0 .. 2 loop
               declare
                  V        : constant Natural :=
                    Natural (U4.Get (S, 0, X) (Channel));
                  Expected : constant Natural :=
                    (if Reverse_Direction
                     then
                       (if A = 0
                        then 0
                        else Natural'Min (255, (V * 255 + A / 2) / A))
                     else (V * A + 128) / 255);
               begin
                  AUnit.Assertions.Assert
                    (U4.Get (D, 0, X) (Channel) = Byte (Expected),
                     "independent alpha formula, including saturation");
               end;
            end loop;
         end;
      end loop;
      Equal (S, Before);
      if not Reverse_Direction then
         IP.Convert_Color (D, Round_Trip, IP.Premultiplied_RGBA_To_RGBA);
         AUnit.Assertions.Assert
           (U4.Get (Round_Trip, 0, 1) (0) = 255
            and then U4.Get (Round_Trip, 0, 1) (1) = 0,
            "low-alpha information loss is expected, not exact round trip");
         AUnit.Assertions.Assert
           (U4.Get (Round_Trip, 0, 3) = U4.Get (S, 0, 3),
            "opaque pixels round trip exactly");
      end if;
   end Alpha_Arithmetic;
   procedure Premultiply is new Alpha_Arithmetic (False);
   procedure Unpremultiply is new Alpha_Arithmetic (True);

   generic
      K : Extended;
      Depth : C.Depth_Type;
   procedure Region_Pixels (Test : in out Fixture);
   procedure Region_Pixels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent              : C.Mat := C.Create (4, 263, (Depth, Channels (K)));
      D, Expected, Before : C.Mat;
   begin
      C.Set_To (Parent, (255.0, 0.0, 255.0, 1.0));
      declare
         R : C.Mat := Parent.Region ((2, 1, 257, 2));
      begin
         C.Set_To
           (R,
            (if Depth = C.Float32
             then (0.2, 0.4, 0.8, 0.0)
             else (200.0, 100.0, 50.0, 128.0)));
         Before := Parent.Clone;
         declare
            Copy : constant C.Mat := R.Clone;
         begin
            IP.Convert_Color (R, D, K);
            IP.Convert_Color (Copy, Expected, K);
            Equal (D, Expected);
         end;
      end;
      Equal (Parent, Before);
      C.Set_To (Parent, (others => 0.0));
      Equal (D, Expected);
   end Region_Pixels;
   procedure HSV_Region is new Region_Pixels (IP.BGR_To_HSV_Full, C.UInt8);
   procedure Lab_Region is new Region_Pixels (IP.Linear_BGR_To_Lab, C.Float32);
   procedure Alpha_Region is new
     Region_Pixels (IP.RGBA_To_Premultiplied_RGBA, C.UInt8);

   generic
      K : Extended;
   procedure Publication (Test : in out Fixture);
   procedure Publication (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S                : C.Mat := C.Create (1, 2, (C.UInt8, Channels (K)));
      D                : C.Mat := S;
      Expected, Before : C.Mat;
      Parent           : C.Mat := C.Create (3, 4, (C.UInt8, Channels (K)));
      R                : C.Mat := Parent.Region ((1, 1, 2, 1));
      Parent_Before    : C.Mat;
      Empty            : C.Mat;
   begin
      C.Set_To (S, (200.0, 100.0, 50.0, 128.0));
      C.Set_To (Parent, (11.0, 123.0, 247.0, 255.0));
      Before := S.Clone;
      Parent_Before := Parent.Clone;
      declare
         Region_Before : constant C.Mat := R.Clone;
      begin
         begin
            IP.Convert_Color (Empty, R, K);
            AUnit.Assertions.Assert (False, "expected Region failure");
         exception
            when OpenCV.OpenCV_Error =>
               null;
         end;
         Equal (R, Region_Before);
         Equal (Parent, Parent_Before);
      end;
      IP.Convert_Color (S, Expected, K);
      IP.Convert_Color (S, D, K);
      Equal (D, Expected);
      Equal (S, Before);
      C.Set_To (D, (others => 0.0));
      Equal (S, Before);
      IP.Convert_Color (S, R, K);
      Equal (R, Expected);
      Equal (Parent, Parent_Before);
      IP.Convert_Color (S, S, K);
      Equal (S, Expected);
   end Publication;
   procedure HSV_Publication is new Publication (IP.BGR_To_HSV_Full);
   procedure Lab_Publication is new Publication (IP.Linear_BGR_To_Lab);
   procedure Alpha_Publication is new
     Publication (IP.RGBA_To_Premultiplied_RGBA);

   procedure Reject (S : C.Mat; K : Extended) is
      D : C.Mat := C.Create (1, 1, (C.UInt8, 1));
   begin
      C.UInt8_Access.Set (D, 0, 0, 71);
      begin
         IP.Convert_Color (S, D, K);
         AUnit.Assertions.Assert (False, "expected OpenCV_Error");
      exception
         when OpenCV.OpenCV_Error =>
            null;
      end;
      AUnit.Assertions.Assert
        (D.Channels = 1 and then C.UInt8_Access.Get (D, 0, 0) = 71,
         "failed public call leaves destination unchanged");
   end Reject;

   procedure Invalid_Depths (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for K in Extended loop
         for Depth in C.Depth_Type loop
            if Depth /= C.UInt8
              and then (Depth /= C.Float32 or else Channels (K) = 4)
            then
               Reject (C.Create (1, 1, (Depth, Channels (K))), K);
            end if;
         end loop;
      end loop;
   end Invalid_Depths;

   procedure Invalid_Channels (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for K in Extended loop
         for Count in C.Channel_Count range 1 .. 4 loop
            if Count /= Channels (K) then
               Reject (C.Create (1, 1, (C.UInt8, Count)), K);
            end if;
         end loop;
      end loop;
   end Invalid_Channels;

   procedure Empty_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : C.Mat;
   begin
      for K in Extended loop
         Reject (Empty, K);
      end loop;
   end Empty_Source;

   procedure ND_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for K in Extended loop
         Reject
           (C.Create (C.Dimension_Array'(2, 2, 2), (C.UInt8, Channels (K))),
            K);
      end loop;
   end ND_Source;

   procedure Raw_Rejection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      function Address is new
        Ada.Unchecked_Conversion
          (C.Module_Interop.Input_Mat_Handle,
           System.Address);
      function Address is new
        Ada.Unchecked_Conversion
          (C.Module_Interop.Output_Mat_Handle,
           System.Address);
      function Convert
        (S, D : System.Address; Selector : Interfaces.Integer_32)
         return Interfaces.Integer_32
      with
        Import,
        Convention    => C,
        External_Name => "opencv_imgproc_cvt_color";
      D     : C.Mat := C.Create (1, 1, (C.UInt8, 1));
      Empty : C.Mat;
      procedure Check
        (S        : C.Mat;
         Selector : Interfaces.Integer_32;
         Expected : Interfaces.Integer_32 := 4)
      is
         Status : Interfaces.Integer_32 := -1;
         procedure Input (Hs : C.Module_Interop.Input_Mat_Handle) is
            procedure Output (Hd : C.Module_Interop.Output_Mat_Handle) is
            begin
               Status := Convert (Address (Hs), Address (Hd), Selector);
            end Output;
         begin
            C.Module_Interop.With_Output_Handle (D, Output'Access);
         end Input;
      begin
         C.Module_Interop.With_Input_Handle (S, Input'Access);
         AUnit.Assertions.Assert (Status = Expected, "raw status");
         if Expected /= 0 then
            AUnit.Assertions.Assert
              (D.Channels = 1 and then C.UInt8_Access.Get (D, 0, 0) = 71,
               "raw failure retains sentinel");
         end if;
      end Check;
      Valid : C.Mat := C.Create (1, 1, (C.UInt8, 4));
   begin
      C.UInt8_Access.Set (D, 0, 0, 71);
      Check (Valid, 86);
      Check (Valid, Interfaces.Integer_32'Last);
      Check (Valid, -1);
      for K in Extended loop
         declare
            Selector : constant Interfaces.Integer_32 :=
              Interfaces.Integer_32 (IP.Color_Conversion'Pos (K));
         begin
            Check (Empty, Selector);
            Check
              (C.Create (C.Dimension_Array'(2, 2, 2), (C.UInt8, Channels (K))),
               Selector);
            for Depth in C.Depth_Type loop
               if Depth /= C.UInt8
                 and then (Depth /= C.Float32 or else Channels (K) = 4)
               then
                  Check (C.Create (1, 1, (Depth, Channels (K))), Selector);
               end if;
            end loop;
            for Count in C.Channel_Count range 1 .. 4 loop
               if Count /= Channels (K) then
                  Check (C.Create (1, 1, (C.UInt8, Count)), Selector);
               end if;
            end loop;
         end;
      end loop;
      U4.Set (Valid, 0, 0, (200, 100, 50, 128));
      Check (Valid, 84, 0);
      AUnit.Assertions.Assert
        (U4.Get (D, 0, 0) = (100, 50, 25, 128), "valid raw recovery");
   end Raw_Rejection;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Test : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Test));
      end Add;
   begin
      Add ("FULL HSV BGR UInt8 chromatic range", HSV_BGR'Access);
      Add ("FULL HSV RGB UInt8 chromatic range", HSV_RGB'Access);
      Add ("FULL HLS BGR UInt8 chromatic range", HLS_BGR'Access);
      Add ("FULL HLS RGB UInt8 chromatic range", HLS_RGB'Access);
      Add ("FULL HSV to BGR UInt8 reverse scale", HSV_To_BGR'Access);
      Add ("FULL HSV to RGB UInt8 reverse scale", HSV_To_RGB'Access);
      Add ("FULL HLS to BGR UInt8 reverse scale", HLS_To_BGR'Access);
      Add ("FULL HLS to RGB UInt8 reverse scale", HLS_To_RGB'Access);
      Add ("Float32 HSV FULL forward equivalence", Float_HSV_Forward'Access);
      Add ("Float32 HSV FULL reverse equivalence", Float_HSV_Reverse'Access);
      Add ("Float32 HLS FULL forward equivalence", Float_HLS_Forward'Access);
      Add ("Float32 HLS FULL reverse equivalence", Float_HLS_Reverse'Access);
      Add ("Linear Lab BGR UInt8 round trip", Lab_BGR_U8'Access);
      Add ("Linear Lab RGB UInt8 round trip", Lab_RGB_U8'Access);
      Add ("Linear Luv BGR UInt8 round trip", Luv_BGR_U8'Access);
      Add ("Linear Luv RGB UInt8 round trip", Luv_RGB_U8'Access);
      Add ("Linear Lab BGR Float32 round trip", Lab_BGR_F32'Access);
      Add ("Linear Lab RGB Float32 round trip", Lab_RGB_F32'Access);
      Add ("Linear Luv BGR Float32 round trip", Luv_BGR_F32'Access);
      Add ("Linear Luv RGB Float32 round trip", Luv_RGB_F32'Access);
      Add ("Linear versus sRGB Lab UInt8", Lab_Transfer_U8'Access);
      Add ("Linear versus sRGB Lab Float32", Lab_Transfer_F32'Access);
      Add ("Linear versus sRGB Luv UInt8", Luv_Transfer_U8'Access);
      Add ("Linear versus sRGB Luv Float32", Luv_Transfer_F32'Access);
      Add ("Premultiply arithmetic and low-alpha loss", Premultiply'Access);
      Add ("Unpremultiply arithmetic and saturation", Unpremultiply'Access);
      Add ("FULL HSV Region logical pixels", HSV_Region'Access);
      Add ("Float32 linear Lab Region logical pixels", Lab_Region'Access);
      Add ("Premultiply Region logical pixels", Alpha_Region'Access);
      Add ("FULL HSV alias and Region rebind", HSV_Publication'Access);
      Add ("Linear Lab alias and Region rebind", Lab_Publication'Access);
      Add ("Premultiply alias and Region rebind", Alpha_Publication'Access);
      Add ("Extended color rejects unsupported depths", Invalid_Depths'Access);
      Add ("Extended color exact channel rejection", Invalid_Channels'Access);
      Add ("Extended color rejects empty source", Empty_Source'Access);
      Add ("Extended color rejects ND source", ND_Source'Access);
      Add
        ("Extended raw ABI failure atomicity and recovery",
         Raw_Rejection'Access);
      return Result'Access;
   end Suite;
end Extended_Color_Tests;
