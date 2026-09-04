with Interfaces;
with Interfaces.C.Strings;
with OpenCV.Core.Module_Interop;

package OpenCV.Image_Processing.Internal.C_API is

   type Status is new Interfaces.Integer_32;

   Success : constant Status := 0;

   BGR_To_Gray : constant Interfaces.Integer_32 := 0;

   function Last_Error_Message_Pointer return Interfaces.C.Strings.chars_ptr
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_last_error_message";

   function Cvt_Color
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Conversion  : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_cvt_color";

   function Last_Error_Message return String;

end OpenCV.Image_Processing.Internal.C_API;