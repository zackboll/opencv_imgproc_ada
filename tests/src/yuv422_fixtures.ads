with OpenCV.Core;
with OpenCV.Image_Processing;

package YUV422_Fixtures is
   subtype Byte_Value is Natural range 0 .. 255;
   type Pixel_Pair is record
      Y0, Y1, U, V : Byte_Value;
   end record;
   type Pairs is array (Natural range <>) of Pixel_Pair;
   function Packed
     (Width, Height : Positive;
      Layout        : OpenCV.Image_Processing.YUV422_Layout;
      Pixels        : Pairs) return OpenCV.Core.Mat;
end YUV422_Fixtures;
