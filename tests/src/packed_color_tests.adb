with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec2;
with OpenCV.Core.UInt8_Vec2_Access;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt8_Vec4_Access;
with OpenCV.Image_Processing;
with System;

package body Packed_Color_Tests is
   package IP renames OpenCV.Image_Processing;
   package C renames OpenCV.Core;
   package V2 renames C.UInt8_Vec2_Access;
   package V3 renames C.UInt8_Vec3_Access;
   package V4 renames C.UInt8_Vec4_Access;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;
   use type C.Channel_Count;
   use type C.Depth_Type;
   subtype Byte is Interfaces.Unsigned_8;
   subtype Word is Interfaces.Unsigned_16;

   --  Test-only native representation, never a little-endian assumption.
   type Native_Bytes is array (0 .. 1) of Byte
   with Component_Size => 8, Size => 16;
   function Bytes is new Ada.Unchecked_Conversion (Word, Native_Bytes);
   function Native_Word is new Ada.Unchecked_Conversion (Native_Bytes, Word);

   subtype Packed_Conversion is
     IP.Color_Conversion range IP.BGR_To_BGR565 .. IP.BGR555_To_Gray;
   type Layout is record
      Source, Destination : C.Channel_Count;
      Green_Bits          : Positive;
      Swap_Blue           : Boolean;
   end record;
   Layouts : constant array (Packed_Conversion) of Layout :=
     ((3, 2, 6, False),
      (3, 2, 6, True),
      (4, 2, 6, False),
      (4, 2, 6, True),
      (2, 3, 6, False),
      (2, 3, 6, True),
      (2, 4, 6, False),
      (2, 4, 6, True),
      (1, 2, 6, False),
      (2, 1, 6, False),
      (3, 2, 5, False),
      (3, 2, 5, True),
      (4, 2, 5, False),
      (4, 2, 5, True),
      (2, 3, 5, False),
      (2, 3, 5, True),
      (2, 4, 5, False),
      (2, 4, 5, True),
      (1, 2, 5, False),
      (2, 1, 5, False));

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Pack (B, G, R, A : Byte; Green_Bits : Positive) return Word is
      use Interfaces;
   begin
      if Green_Bits = 6 then
         return
           Shift_Right (Word (B), 3)
           or Shift_Left (Word (G and 16#FC#), 3)
           or Shift_Left (Word (R and 16#F8#), 8);
      else
         return
           Shift_Right (Word (B), 3)
           or Shift_Left (Word (G and 16#F8#), 2)
           or Shift_Left (Word (R and 16#F8#), 7)
           or (if A /= 0 then 16#8000# else 0);
      end if;
   end Pack;

   procedure Set_Word (Image : in out C.Mat; X : Integer; W : Word) is
      B : constant Native_Bytes := Bytes (W);
   begin
      V2.Set (Image, 0, X, (B (0), B (1)));
   end Set_Word;

   function Get_Word (Image : C.Mat; X : Integer) return Word is
      B : constant C.UInt8_Vec2.Vector := V2.Get (Image, 0, X);
   begin
      return Native_Word ((B (0), B (1)));
   end Get_Word;

   function Pixel (Image : C.Mat; X, Channel : Natural) return Byte is
      Plane : constant C.Mat := Image.Extract_Channel (Channel);
   begin
      return C.UInt8_Access.Get (Plane, 0, X);
   end Pixel;

   procedure Assert_Equal (Left, Right : C.Mat) is
   begin
      AUnit.Assertions.Assert
        (Left.Rows = Right.Rows
         and then Left.Columns = Right.Columns
         and then Left.Depth = Right.Depth
         and then Left.Channels = Right.Channels,
         "equal metadata");
      for Y in 0 .. Left.Rows - 1 loop
         for X in 0 .. Left.Columns - 1 loop
            for Channel in 0 .. Natural (Left.Channels) - 1 loop
               declare
                  L : constant C.Mat := Left.Extract_Channel (Channel);
                  R : constant C.Mat := Right.Extract_Channel (Channel);
               begin
                  AUnit.Assertions.Assert
                    (C.UInt8_Access.Get (L, Y, X)
                     = C.UInt8_Access.Get (R, Y, X),
                     "equal pixels");
               end;
            end loop;
         end loop;
      end loop;
   end Assert_Equal;

   generic
      Conversion : Packed_Conversion;
   procedure Check_Conversion (Test : in out Fixture);

   procedure Check_Conversion (Test : in out Fixture) is
      pragma Unreferenced (Test);
      L          : constant Layout := Layouts (Conversion);
      S          : C.Mat := C.Create (1, 257, (C.UInt8, L.Source));
      D          : C.Mat;
      Before     : C.Mat;
      B, G, R, A : Byte;
      W          : Word;
   begin
      --  Long rows exercise vector blocks plus a scalar tail; the first
      --  five pixels are blue, green, red, white and black primaries.
      for X in 0 .. 256 loop
         B := Byte ((X * 37) mod 256);
         G := Byte ((X * 73) mod 256);
         R := Byte ((X * 109) mod 256);
         A :=
           (case X mod 4 is
              when 0      => 0,
              when 1      => 1,
              when 2      => 128,
              when others => 255);
         case X is
            when 0      =>
               B := 255;
               G := 0;
               R := 0;

            when 1      =>
               B := 0;
               G := 255;
               R := 0;

            when 2      =>
               B := 0;
               G := 0;
               R := 255;

            when 3      =>
               B := 255;
               G := 255;
               R := 255;

            when 4      =>
               B := 0;
               G := 0;
               R := 0;

            when others =>
               null;
         end case;
         case L.Source is
            when 1      =>
               C.UInt8_Access.Set (S, 0, X, Byte (X mod 256));

            when 2      =>
               Set_Word (S, X, Pack (B, G, R, A, L.Green_Bits));

            when 3      =>
               V3.Set
                 (S, 0, X, (if L.Swap_Blue then (R, G, B) else (B, G, R)));

            when others =>
               V4.Set
                 (S,
                  0,
                  X,
                  (if L.Swap_Blue then (R, G, B, A) else (B, G, R, A)));
         end case;
      end loop;
      Before := S.Clone;
      IP.Convert_Color (S, D, Conversion);
      AUnit.Assertions.Assert
        (D.Rows = 1
         and then D.Columns = 257
         and then D.Depth = C.UInt8
         and then D.Channels = L.Destination,
         "packed output metadata");
      Assert_Equal (S, Before);
      for X in 0 .. 256 loop
         if L.Source /= 2 then
            if L.Source = 1 then
               B := Pixel (S, X, 0);
               G := B;
               R := B;
            else
               B := Pixel (S, X, (if L.Swap_Blue then 2 else 0));
               G := Pixel (S, X, 1);
               R := Pixel (S, X, (if L.Swap_Blue then 0 else 2));
            end if;
            A := (if L.Source = 4 then Pixel (S, X, 3) else 0);
            AUnit.Assertions.Assert
              (Get_Word (D, X) = Pack (B, G, R, A, L.Green_Bits),
               "native packed word fields and alpha");
         else
            W := Get_Word (S, X);
            B := Byte (Interfaces.Shift_Left (W, 3) and 16#F8#);
            G :=
              Byte
                (Interfaces.Shift_Right
                   (W, (if L.Green_Bits = 6 then 3 else 2))
                 and (if L.Green_Bits = 6 then 16#FC# else 16#F8#));
            R :=
              Byte
                (Interfaces.Shift_Right
                   (W, (if L.Green_Bits = 6 then 8 else 7))
                 and 16#F8#);
            if L.Destination = 1 then
               AUnit.Assertions.Assert
                 (Integer (Pixel (D, X, 0))
                  = (Integer (B)
                     * 3735
                     + Integer (G) * 19235
                     + Integer (R) * 9798
                     + 16384)
                    / 32768,
                  "packed Gray uses expanded quantized RGB");
            else
               AUnit.Assertions.Assert
                 (Pixel (D, X, (if L.Swap_Blue then 2 else 0)) = B
                  and then Pixel (D, X, 1) = G
                  and then Pixel (D, X, (if L.Swap_Blue then 0 else 2)) = R,
                  "unpacked colors truncate without bit replication");
               if L.Destination = 4 then
                  AUnit.Assertions.Assert
                    (Pixel (D, X, 3)
                     = (if L.Green_Bits = 6 or else (W and 16#8000#) /= 0
                        then 255
                        else 0),
                     "unpacked alpha flag");
               end if;
            end if;
         end if;
      end loop;
   end Check_Conversion;

   procedure C48 is new Check_Conversion (IP.BGR_To_BGR565);
   procedure C49 is new Check_Conversion (IP.RGB_To_BGR565);
   procedure C50 is new Check_Conversion (IP.BGRA_To_BGR565);
   procedure C51 is new Check_Conversion (IP.RGBA_To_BGR565);
   procedure C52 is new Check_Conversion (IP.BGR565_To_BGR);
   procedure C53 is new Check_Conversion (IP.BGR565_To_RGB);
   procedure C54 is new Check_Conversion (IP.BGR565_To_BGRA);
   procedure C55 is new Check_Conversion (IP.BGR565_To_RGBA);
   procedure C56 is new Check_Conversion (IP.Gray_To_BGR565);
   procedure C57 is new Check_Conversion (IP.BGR565_To_Gray);
   procedure C58 is new Check_Conversion (IP.BGR_To_BGR555);
   procedure C59 is new Check_Conversion (IP.RGB_To_BGR555);
   procedure C60 is new Check_Conversion (IP.BGRA_To_BGR555);
   procedure C61 is new Check_Conversion (IP.RGBA_To_BGR555);
   procedure C62 is new Check_Conversion (IP.BGR555_To_BGR);
   procedure C63 is new Check_Conversion (IP.BGR555_To_RGB);
   procedure C64 is new Check_Conversion (IP.BGR555_To_BGRA);
   procedure C65 is new Check_Conversion (IP.BGR555_To_RGBA);
   procedure C66 is new Check_Conversion (IP.Gray_To_BGR555);
   procedure C67 is new Check_Conversion (IP.BGR555_To_Gray);

   procedure Reject (S : C.Mat; Conversion : Packed_Conversion) is
      D      : C.Mat := C.Create (1, 1, (C.UInt8, 1));
      Raised : Boolean := False;
   begin
      C.UInt8_Access.Set (D, 0, 0, 71);
      begin
         IP.Convert_Color (S, D, Conversion);
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert
        (Raised
         and then D.Channels = 1
         and then C.UInt8_Access.Get (D, 0, 0) = 71,
         "OpenCV_Error and unchanged destination");
   end Reject;

   procedure Alpha_And_Gray_Round_Trips (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S              : C.Mat := C.Create (1, 4, (C.UInt8, 4));
      P, D, G, Color : C.Mat;
      Alphas         : constant array (0 .. 3) of Byte := (0, 1, 128, 255);
   begin
      for X in 0 .. 3 loop
         V4.Set (S, 0, X, (255, 151, 79, Alphas (X)));
      end loop;
      for Packing in
        IP.Color_Conversion range IP.BGRA_To_BGR555 .. IP.RGBA_To_BGR555
      loop
         IP.Convert_Color (S, P, Packing);
         IP.Convert_Color (P, D, IP.BGR555_To_BGRA);
         for X in 0 .. 3 loop
            AUnit.Assertions.Assert
              (Pixel (D, X, 3) = (if X = 0 then 0 else 255),
               "C4 BGR555 boolean alpha round trip");
         end loop;
      end loop;
      IP.Convert_Color (S, P, IP.BGRA_To_BGR565);
      AUnit.Assertions.Assert
        (Get_Word (P, 0) = Get_Word (P, 3), "BGR565 ignores alpha");
      IP.Convert_Color (P, D, IP.BGR565_To_RGBA);
      for X in 0 .. 3 loop
         AUnit.Assertions.Assert
           (Pixel (D, X, 3) = 255, "BGR565 expands opaque alpha");
      end loop;
      Color := C.Create (1, 1, (C.UInt8, 3));
      C.Set_To (Color, (others => 255.0));
      IP.Convert_Color (Color, P, IP.BGR_To_BGR555);
      IP.Convert_Color (P, D, IP.BGR555_To_BGRA);
      AUnit.Assertions.Assert
        (Pixel (D, 0, 3) = 0, "C3 BGR555 leaves alpha clear");
      G := C.Create (1, 1, (C.UInt8, 1));
      C.UInt8_Access.Set (G, 0, 0, 255);
      IP.Convert_Color (G, P, IP.Gray_To_BGR555);
      IP.Convert_Color (P, D, IP.BGR555_To_BGRA);
      AUnit.Assertions.Assert
        (Pixel (D, 0, 0) = 248
         and then Pixel (D, 0, 1) = 248
         and then Pixel (D, 0, 2) = 248
         and then Pixel (D, 0, 3) = 0,
         "Gray BGR555 quantization and clear alpha");
      IP.Convert_Color (P, D, IP.BGR555_To_Gray);
      AUnit.Assertions.Assert
        (Pixel (D, 0, 0) = 248, "quantized BGR555 Gray round trip");
      IP.Convert_Color (G, P, IP.Gray_To_BGR565);
      IP.Convert_Color (P, D, IP.BGR565_To_BGR);
      AUnit.Assertions.Assert
        (Pixel (D, 0, 0) = 248
         and then Pixel (D, 0, 1) = 252
         and then Pixel (D, 0, 2) = 248,
         "Gray BGR565 quantization");
      IP.Convert_Color (P, D, IP.BGR565_To_Gray);
      AUnit.Assertions.Assert
        (Pixel (D, 0, 0) = 250, "quantized BGR565 Gray round trip");
   end Alpha_And_Gray_Round_Trips;

   procedure Invalid_Depths (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Conversion in Packed_Conversion loop
         for Depth in C.Depth_Type loop
            if Depth /= C.UInt8 then
               Reject
                 (C.Create (1, 1, (Depth, Layouts (Conversion).Source)),
                  Conversion);
            end if;
         end loop;
      end loop;
   end Invalid_Depths;

   procedure Invalid_Channels (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Conversion in Packed_Conversion loop
         for Channels in C.Channel_Count range 1 .. 4 loop
            if Channels /= Layouts (Conversion).Source then
               Reject (C.Create (1, 1, (C.UInt8, Channels)), Conversion);
            end if;
         end loop;
      end loop;
   end Invalid_Channels;

   procedure Empty_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : C.Mat;
   begin
      for Conversion in Packed_Conversion loop
         Reject (S, Conversion);
      end loop;
   end Empty_Source;

   procedure ND_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Conversion in Packed_Conversion loop
         Reject
           (C.Create
              (C.Dimension_Array'(2, 2, 2),
               (C.UInt8, Layouts (Conversion).Source)),
            Conversion);
      end loop;
   end ND_Source;

   generic
      Packing : Boolean;
   procedure Check_Region (Test : in out Fixture);
   procedure Check_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : C.Mat :=
        C.Create (3, 5, (C.UInt8, (if Packing then 3 else 2)));
      D, Expected : C.Mat;
      Conversion  : constant Packed_Conversion :=
        (if Packing then IP.BGR_To_BGR565 else IP.BGR565_To_BGR);
   begin
      C.Set_To (Parent, (255.0, 0.0, 255.0, 0.0));
      if Packing then
         V3.Set (Parent, 1, 1, (10, 100, 200));
         V3.Set (Parent, 1, 2, (255, 255, 255));
      else
         V2.Set (Parent, 1, 1, (0, 0));
         V2.Set (Parent, 1, 2, (255, 255));
      end if;
      declare
         R    : constant C.Mat := Parent.Region ((1, 1, 2, 1));
         Copy : constant C.Mat := R.Clone;
      begin
         IP.Convert_Color (R, D, Conversion);
         IP.Convert_Color (Copy, Expected, Conversion);
         Assert_Equal (D, Expected);
         C.Set_To (Parent, (others => 17.0));
         Assert_Equal (D, Expected);
      end;
   end Check_Region;
   procedure Packing_Region is new Check_Region (True);
   procedure Unpacking_Region is new Check_Region (False);

   procedure Same_Object (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S        : C.Mat := C.Create (1, 1, (C.UInt8, 3));
      Expected : C.Mat;
   begin
      V3.Set (S, 0, 0, (255, 150, 77));
      IP.Convert_Color (S, Expected, IP.BGR_To_BGR555);
      IP.Convert_Color (S, S, IP.BGR_To_BGR555);
      Assert_Equal (S, Expected);
      IP.Convert_Color (S, S, IP.BGR555_To_BGR);
      AUnit.Assertions.Assert
        (Pixel (S, 0, 0) = 248
         and then Pixel (S, 0, 1) = 144
         and then Pixel (S, 0, 2) = 72,
         "same-object round trip");
   end Same_Object;

   procedure Shared_Storage (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S      : C.Mat := C.Create (1, 1, (C.UInt8, 3));
      D      : C.Mat := S;
      Before : C.Mat;
   begin
      V3.Set (S, 0, 0, (10, 100, 200));
      Before := S.Clone;
      IP.Convert_Color (S, D, IP.BGR_To_BGR565);
      Assert_Equal (S, Before);
      C.Set_To (D, (others => 0.0));
      Assert_Equal (S, Before);
   end Shared_Storage;

   procedure Destination_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent           : C.Mat := C.Create (3, 4, (C.UInt8, 3));
      D                : C.Mat := Parent.Region ((1, 1, 2, 1));
      Before, Expected : C.Mat;
   begin
      C.Set_To (Parent, (11.0, 123.0, 247.0, 0.0));
      Before := Parent.Clone;
      IP.Convert_Color (D, Expected, IP.BGR_To_BGR565);
      IP.Convert_Color (D, D, IP.BGR_To_BGR565);
      Assert_Equal (D, Expected);
      Assert_Equal (Parent, Before);
   end Destination_Region;

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
      S     : C.Mat := C.Create (1, 1, (C.UInt8, 3));
      D     : C.Mat := C.Create (1, 1, (C.UInt8, 1));
      procedure Check_Source (Image : C.Mat; Selector : Interfaces.Integer_32)
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
         C.Module_Interop.With_Input_Handle (Image, Input'Access);
         AUnit.Assertions.Assert
           (Status = 4
            and then D.Channels = 1
            and then C.UInt8_Access.Get (D, 0, 0) = 71,
            "raw rejection preserves destination");
      end Check_Source;
      procedure Valid_Input (Hs : C.Module_Interop.Input_Mat_Handle) is
         procedure Output (Hd : C.Module_Interop.Output_Mat_Handle) is
         begin
            AUnit.Assertions.Assert
              (Convert (Address (Hs), Address (Hd), 48) = 0,
               "valid raw call recovers after rejection");
         end Output;
      begin
         C.Module_Interop.With_Output_Handle (D, Output'Access);
      end Valid_Input;
      Empty : C.Mat;
   begin
      C.UInt8_Access.Set (D, 0, 0, 71);
      Check_Source (S, 86);
      Check_Source (S, -1);
      Check_Source (S, 999);
      for Conversion in Packed_Conversion loop
         declare
            Selector : constant Interfaces.Integer_32 :=
              Interfaces.Integer_32 (IP.Color_Conversion'Pos (Conversion));
         begin
            Check_Source (Empty, Selector);
            Check_Source
              (C.Create
                 (C.Dimension_Array'(2, 2, 2),
                  (C.UInt8, Layouts (Conversion).Source)),
               Selector);
            for Depth in C.Depth_Type loop
               if Depth /= C.UInt8 then
                  Check_Source
                    (C.Create (1, 1, (Depth, Layouts (Conversion).Source)),
                     Selector);
               end if;
            end loop;
            for Channels in C.Channel_Count range 1 .. 4 loop
               if Channels /= Layouts (Conversion).Source then
                  Check_Source
                    (C.Create (1, 1, (C.UInt8, Channels)), Selector);
               end if;
            end loop;
         end;
      end loop;
      V3.Set (S, 0, 0, (255, 0, 0));
      C.Module_Interop.With_Input_Handle (S, Valid_Input'Access);
      AUnit.Assertions.Assert
        (Get_Word (D, 0) = 31, "valid raw call recovers after rejection");
   end Raw_Rejection;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Packed alpha and Gray round trips",
            Alpha_And_Gray_Round_Trips'Access));
      Result.Add_Test (Caller.Create ("BGR to BGR565", C48'Access));
      Result.Add_Test (Caller.Create ("RGB to BGR565", C49'Access));
      Result.Add_Test (Caller.Create ("BGRA to BGR565", C50'Access));
      Result.Add_Test (Caller.Create ("RGBA to BGR565", C51'Access));
      Result.Add_Test (Caller.Create ("BGR565 to BGR", C52'Access));
      Result.Add_Test (Caller.Create ("BGR565 to RGB", C53'Access));
      Result.Add_Test (Caller.Create ("BGR565 to BGRA", C54'Access));
      Result.Add_Test (Caller.Create ("BGR565 to RGBA", C55'Access));
      Result.Add_Test (Caller.Create ("Gray to BGR565", C56'Access));
      Result.Add_Test (Caller.Create ("BGR565 to Gray", C57'Access));
      Result.Add_Test (Caller.Create ("BGR to BGR555", C58'Access));
      Result.Add_Test (Caller.Create ("RGB to BGR555", C59'Access));
      Result.Add_Test (Caller.Create ("BGRA to BGR555", C60'Access));
      Result.Add_Test (Caller.Create ("RGBA to BGR555", C61'Access));
      Result.Add_Test (Caller.Create ("BGR555 to BGR", C62'Access));
      Result.Add_Test (Caller.Create ("BGR555 to RGB", C63'Access));
      Result.Add_Test (Caller.Create ("BGR555 to BGRA", C64'Access));
      Result.Add_Test (Caller.Create ("BGR555 to RGBA", C65'Access));
      Result.Add_Test (Caller.Create ("Gray to BGR555", C66'Access));
      Result.Add_Test (Caller.Create ("BGR555 to Gray", C67'Access));
      Result.Add_Test
        (Caller.Create
           ("Packed rejects all other depths", Invalid_Depths'Access));
      Result.Add_Test
        (Caller.Create
           ("Packed rejects wrong channels", Invalid_Channels'Access));
      Result.Add_Test
        (Caller.Create ("Packed rejects empty source", Empty_Source'Access));
      Result.Add_Test
        (Caller.Create ("Packed rejects ND source", ND_Source'Access));
      Result.Add_Test
        (Caller.Create ("Region to packed", Packing_Region'Access));
      Result.Add_Test
        (Caller.Create ("Packed Region to color", Unpacking_Region'Access));
      Result.Add_Test
        (Caller.Create ("Packed same-object conversion", Same_Object'Access));
      Result.Add_Test
        (Caller.Create
           ("Packed shared storage rebind", Shared_Storage'Access));
      Result.Add_Test
        (Caller.Create
           ("Packed destination Region rebind", Destination_Region'Access));
      Result.Add_Test
        (Caller.Create
           ("Packed raw rejection atomicity", Raw_Rejection'Access));
      return Result'Access;
   end Suite;
end Packed_Color_Tests;
