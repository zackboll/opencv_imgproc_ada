with OpenCV.Core;

package OpenCV.Image_Processing is

   type Color_Conversion is (BGR_To_Gray);

   procedure Convert_Color
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Conversion  : Color_Conversion);

end OpenCV.Image_Processing;
