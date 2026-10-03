with AUnit.Assertions;
with Interfaces;
with OpenCV.Core.UInt8_Access;

package body YUV420_Fixtures is
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type C.Dimension_Array;
   use type IP.YUV420_Layout;
   use type IP.YUV_Color_Order;

   function Byte
     (Image : C.Mat; Row, Column : Natural; Channel : Natural := 0)
      return Natural is
   begin
      if Image.Channels = 1 then
         return Natural (C.UInt8_Access.Get (Image, Row, Column));
      end if;
      declare
         Part : constant C.Mat := Image.Extract_Channel (Channel);
      begin
         return Natural (C.UInt8_Access.Get (Part, Row, Column));
      end;
   end Byte;

   procedure Set_Byte (Image : in out C.Mat; Row, Column, Value : Natural) is
   begin
      C.UInt8_Access.Set (Image, Row, Column, Interfaces.Unsigned_8 (Value));
   end Set_Byte;

   function Y_Plane (Width, Height : Positive; Luma : Samples) return C.Mat is
      Image : C.Mat := C.Create (Height, Width, (C.UInt8, 1));
   begin
      for I in 0 .. Width * Height - 1 loop
         Set_Byte (Image, I / Width, I mod Width, Luma (Luma'First + I));
      end loop;
      return Image;
   end Y_Plane;

   function Packed
     (Width, Height : Positive;
      Layout        : IP.YUV420_Layout;
      Luma, U, V    : Samples) return C.Mat
   is
      N    : constant Positive := Width * Height;
      Flat : Samples (0 .. N + N / 2 - 1);
   begin
      for I in 0 .. N - 1 loop
         Flat (I) := Luma (Luma'First + I);
      end loop;
      --  Explicit stream layout, independent of native codes/selectors.
      for I in 0 .. N / 4 - 1 loop
         case Layout is
            when IP.I420 =>
               Flat (N + I) := U (U'First + I);
               Flat (N + N / 4 + I) := V (V'First + I);

            when IP.YV12 =>
               Flat (N + I) := V (V'First + I);
               Flat (N + N / 4 + I) := U (U'First + I);

            when IP.NV12 =>
               Flat (N + 2 * I) := U (U'First + I);
               Flat (N + 2 * I + 1) := V (V'First + I);

            when IP.NV21 =>
               Flat (N + 2 * I) := V (V'First + I);
               Flat (N + 2 * I + 1) := U (U'First + I);
         end case;
      end loop;
      return Y_Plane (Width, Height + Height / 2, Flat);
   end Packed;

   function UV_Plane
     (Width, Height : Positive;
      Layout        : IP.YUV420_Semiplanar_Layout;
      U, V          : Samples) return C.Mat
   is
      Flat : C.Mat := C.Create (Height / 2, Width, (C.UInt8, 1));
   begin
      for I in 0 .. Width * Height / 4 - 1 loop
         Set_Byte
           (Flat,
            2 * I / Width,
            2 * I mod Width,
            (if Layout = IP.NV12 then U (U'First + I) else V (V'First + I)));
         Set_Byte
           (Flat,
            2 * I / Width,
            2 * I mod Width + 1,
            (if Layout = IP.NV12 then V (V'First + I) else U (U'First + I)));
      end loop;
      return Flat.Reshape (2);
   end UV_Plane;

   function Color_Image
     (Width, Height : Positive;
      Pixels        : Colors;
      Order         : IP.YUV_Color_Order;
      Alpha         : Integer := -1) return C.Mat
   is
      Channels : constant Positive := (if Alpha < 0 then 3 else 4);
      Flat     : C.Mat := C.Create (Height, Width * Channels, (C.UInt8, 1));
   begin
      for I in 0 .. Width * Height - 1 loop
         declare
            P : constant RGB := Pixels (Pixels'First + I);
            X : constant Natural := (I mod Width) * Channels;
            Y : constant Natural := I / Width;
         begin
            Set_Byte (Flat, Y, X, (if Order = IP.BGR_Order then P.B else P.R));
            Set_Byte (Flat, Y, X + 1, P.G);
            Set_Byte
              (Flat, Y, X + 2, (if Order = IP.BGR_Order then P.R else P.B));
            if Channels = 4 then
               Set_Byte (Flat, Y, X + 3, Alpha);
            end if;
         end;
      end loop;
      return Flat.Reshape (C.Channel_Count (Channels));
   end Color_Image;

   function Read_Plane
     (Image : C.Mat; Layout : IP.YUV420_Planar_Layout; Plane : Plane_Kind)
      return Samples
   is
      Width  : constant Positive := Image.Columns;
      Height : constant Positive := (Image.Rows / 3) * 2;
      N      : constant Positive := Width * Height;
      Count  : constant Positive := (if Plane = Y then N else N / 4);
      Offset : constant Natural :=
        (if Plane = Y
         then 0
         elsif (Plane = U and then Layout = IP.I420)
           or else (Plane = V and then Layout = IP.YV12)
         then N
         else N + N / 4);
      Result : Samples (0 .. Count - 1);
   begin
      for I in Result'Range loop
         Result (I) :=
           Byte (Image, (Offset + I) / Width, (Offset + I) mod Width);
      end loop;
      return Result;
   end Read_Plane;

   procedure Preserved (Left, Right : C.Mat) is
   begin
      AUnit.Assertions.Assert
        (Left.Shape = Right.Shape
         and then Left.Depth = Right.Depth
         and then Left.Channels = Right.Channels,
         "preserved metadata");
      if not Left.Is_Empty then
         declare
            A  : constant C.Mat := Left.Convert_To (C.Float64);
            B  : constant C.Mat := Right.Convert_To (C.Float64);
            FA : constant C.Mat :=
              A.Reshape
                (C.Dimension_Array'(1, OpenCV.Size_Coordinate (A.Total)));
            FB : constant C.Mat :=
              B.Reshape
                (C.Dimension_Array'(1, OpenCV.Size_Coordinate (B.Total)));
            D  : constant C.Mat := C.Abs_Diff (FA, FB);
         begin
            AUnit.Assertions.Assert
              (D.Norm (C.Infinity) = 0.0, "all source values preserved");
         end;
      end if;
   end Preserved;

   procedure Equal (Left, Right : C.Mat) is
   begin
      Preserved (Left, Right);
   end Equal;

   function Saturate (Value : Integer) return Natural
   is (Natural (Integer'Max (0, Integer'Min (255, Value))));

   function Decode_Reference (Y, U, V : Natural) return RGB is
      L  : constant Integer := Integer'Max (0, Y - 16) * 1_220_542;
      UU : constant Integer := U - 128;
      VV : constant Integer := V - 128;
      --  Ada mod implements floor division even for negative numerators.
      function Rounded (N : Integer) return Natural
      is (Saturate ((N - N mod 1_048_576) / 1_048_576));
   begin
      return
        (Rounded (L + 1_673_527 * VV + 524_288),
         Rounded (L - 852_492 * VV - 409_993 * UU + 524_288),
         Rounded (L + 2_116_026 * UU + 524_288));
   end Decode_Reference;

   function Encode_Reference (Pixel : RGB; Plane : Plane_Kind) return Natural
   is
      N : constant Integer :=
        (case Plane is
           when Y =>
             269_484
             * Pixel.R
             + 528_482 * Pixel.G
             + 102_760 * Pixel.B
             + 16 * 1_048_576,
           when U =>
             -155_188 * Pixel.R
             - 305_135 * Pixel.G
             + 460_324 * Pixel.B
             + 128 * 1_048_576,
           when V =>
             460_324
             * Pixel.R
             - 385_875 * Pixel.G
             - 74_448 * Pixel.B
             + 128 * 1_048_576);
   begin
      return Saturate ((N + 524_288) / 1_048_576);
   end Encode_Reference;
end YUV420_Fixtures;
