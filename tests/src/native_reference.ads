with Interfaces;
with OpenCV.Core;
with OpenCV.Image_Processing;

package Native_Reference is
   function Version return Natural;
   function Bayer_Matches
     (Source, Output : OpenCV.Core.Mat;
      Pattern        : OpenCV.Image_Processing.Bayer_Pattern;
      Method         : OpenCV.Image_Processing.Bayer_Demosaicing_Method;
      Order          : OpenCV.Image_Processing.Bayer_Color_Order)
      return Boolean;
private
   function Native_Version return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "imgproc_test_native_version";
end Native_Reference;
