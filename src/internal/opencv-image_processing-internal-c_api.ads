with Interfaces;
with Interfaces.C.Strings;
with OpenCV.Core.Module_Interop;

package OpenCV.Image_Processing.Internal.C_API is

   type Status is new Interfaces.Integer_32;

   Success                : constant Status := 0;
   Error_OpenCV           : constant Status := 1;
   Error_Standard_CPP     : constant Status := 2;
   Error_Unknown          : constant Status := 3;
   Error_Invalid_Argument : constant Status := 4;

   BGR_To_Gray : constant Interfaces.Integer_32 := 0;

   Interpolation_Nearest_Neighbor : constant Interfaces.Integer_32 := 0;
   Interpolation_Linear           : constant Interfaces.Integer_32 := 1;
   Interpolation_Cubic            : constant Interfaces.Integer_32 := 2;
   Interpolation_Area             : constant Interfaces.Integer_32 := 3;
   Interpolation_Lanczos_4        : constant Interfaces.Integer_32 := 4;

   Border_Constant    : constant Interfaces.Integer_32 := 0;
   Border_Replicate   : constant Interfaces.Integer_32 := 1;
   Border_Reflect     : constant Interfaces.Integer_32 := 2;
   Border_Reflect_101 : constant Interfaces.Integer_32 := 3;

   Canny_Aperture_3 : constant Interfaces.Integer_32 := 0;
   Canny_Aperture_5 : constant Interfaces.Integer_32 := 1;
   Canny_Aperture_7 : constant Interfaces.Integer_32 := 2;

   Canny_Gradient_L1 : constant Interfaces.Integer_32 := 0;
   Canny_Gradient_L2 : constant Interfaces.Integer_32 := 1;

   Threshold_Binary          : constant Interfaces.Integer_32 := 0;
   Threshold_Binary_Inverse  : constant Interfaces.Integer_32 := 1;
   Threshold_Truncate        : constant Interfaces.Integer_32 := 2;
   Threshold_To_Zero         : constant Interfaces.Integer_32 := 3;
   Threshold_To_Zero_Inverse : constant Interfaces.Integer_32 := 4;

   function Last_Error_Message_Pointer return Interfaces.C.Strings.chars_ptr
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_last_error_message";

   function Cvt_Color
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Conversion  : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_cvt_color";

   function Resize
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Width         : Interfaces.Integer_32;
      Height        : Interfaces.Integer_32;
      Interpolation : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_resize";

   function Gaussian_Blur
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel_Width  : Interfaces.Integer_32;
      Kernel_Height : Interfaces.Integer_32;
      Sigma         : Interfaces.C.double;
      Border        : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_gaussian_blur";

   function Canny
     (Source          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination     : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Lower_Threshold : Interfaces.C.double;
      Upper_Threshold : Interfaces.C.double;
      Aperture        : Interfaces.Integer_32;
      Gradient_Norm   : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_canny";

   function Threshold
     (Source          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination     : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Threshold_Value : Interfaces.C.double;
      Maximum_Value   : Interfaces.C.double;
      Mode            : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_threshold";

   function Last_Error_Message return String;

end OpenCV.Image_Processing.Internal.C_API;
