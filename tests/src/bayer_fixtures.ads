with OpenCV.Core;
with OpenCV.Image_Processing;

package Bayer_Fixtures is
   function Mosaic
     (Pattern : OpenCV.Image_Processing.Bayer_Pattern;
      Depth   : OpenCV.Core.Depth_Type := OpenCV.Core.UInt8;
      Rows    : Positive := 16;
      Columns : Positive := 16;
      Texture : Boolean := False) return OpenCV.Core.Mat;

   procedure Equal (Left, Right : OpenCV.Core.Mat);
   function Pixel
     (Image : OpenCV.Core.Mat; Row, Column : Natural) return Natural;
   procedure Set_Pixel
     (Image : in out OpenCV.Core.Mat; Row, Column, Value : Natural);
end Bayer_Fixtures;
