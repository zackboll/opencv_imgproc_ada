with AUnit.Assertions;
with Interfaces;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt16_Access;

package body Bayer_Fixtures is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type C.Dimension_Array;

   function Pixel (Image : C.Mat; Row, Column : Natural) return Natural
   is (if Image.Depth = C.UInt8
       then Natural (C.UInt8_Access.Get (Image, Row, Column))
       else Natural (C.UInt16_Access.Get (Image, Row, Column)));

   procedure Set_Pixel (Image : in out C.Mat; Row, Column, Value : Natural) is
   begin
      if Image.Depth = C.UInt8 then
         C.UInt8_Access.Set
           (Image, Row, Column, Interfaces.Unsigned_8 (Value));
      else
         C.UInt16_Access.Set
           (Image, Row, Column, Interfaces.Unsigned_16 (Value));
      end if;
   end Set_Pixel;

   function Mosaic
     (Pattern : IP.Bayer_Pattern;
      Depth   : C.Depth_Type := C.UInt8;
      Rows    : Positive := 16;
      Columns : Positive := 16;
      Texture : Boolean := False) return C.Mat
   is
      type Component is (Red, Green, Blue);
      type Tile is array (0 .. 1, 0 .. 1) of Component;
      --  Physical tiles, independent of all native conversion constants.
      Tiles  : constant array (IP.Bayer_Pattern) of Tile :=
        (IP.RGGB => ((Red, Green), (Green, Blue)),
         IP.GRBG => ((Green, Red), (Blue, Green)),
         IP.BGGR => ((Blue, Green), (Green, Red)),
         IP.GBRG => ((Green, Blue), (Red, Green)));
      Values : constant array (Component) of Natural :=
        (if Depth = C.UInt8 then (200, 100, 50) else (50_000, 30_000, 10_000));
      Image  : C.Mat := C.Create (Rows, Columns, (Depth, 1));
   begin
      for Y in 0 .. Rows - 1 loop
         for X in 0 .. Columns - 1 loop
            Set_Pixel
              (Image,
               Y,
               X,
               (if Texture
                then
                  ((X
                    * 17
                    + Y * 31
                    + X * Y * 7
                    + (if X < Columns / 2 then 0 else 83))
                   mod 240)
                  * (if Depth = C.UInt8 then 1 else 251)
                else Values (Tiles (Pattern) (Y mod 2, X mod 2))));
         end loop;
      end loop;
      return Image;
   end Mosaic;

   procedure Equal (Left, Right : C.Mat) is
   begin
      AUnit.Assertions.Assert
        (Left.Dimension_Count = Right.Dimension_Count
         and then Left.Shape = Right.Shape
         and then Left.Depth = Right.Depth
         and then Left.Channels = Right.Channels,
         "equal matrix metadata");
      if Left.Is_Empty then
         return;
      end if;
      for Channel in 0 .. Natural (Left.Channels) - 1 loop
         declare
            A : constant C.Mat := Left.Extract_Channel (Channel);
            B : constant C.Mat := Right.Extract_Channel (Channel);
         begin
            for Y in 0 .. A.Rows - 1 loop
               for X in 0 .. A.Columns - 1 loop
                  AUnit.Assertions.Assert
                    (Pixel (A, Y, X) = Pixel (B, Y, X), "equal pixels");
               end loop;
            end loop;
         end;
      end loop;
   end Equal;
end Bayer_Fixtures;
