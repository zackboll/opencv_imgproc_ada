with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with OpenCV.Core.Module_Interop;
with System;

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
   Border_Wrap        : constant Interfaces.Integer_32 := 4;

   Morphology_Rectangle : constant Interfaces.Integer_32 := 0;
   Morphology_Cross     : constant Interfaces.Integer_32 := 1;
   Morphology_Ellipse   : constant Interfaces.Integer_32 := 2;

   Morphology_Open      : constant Interfaces.Integer_32 := 0;
   Morphology_Close     : constant Interfaces.Integer_32 := 1;
   Morphology_Gradient  : constant Interfaces.Integer_32 := 2;
   Morphology_Top_Hat   : constant Interfaces.Integer_32 := 3;
   Morphology_Black_Hat : constant Interfaces.Integer_32 := 4;

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

   Automatic_Threshold_Otsu     : constant Interfaces.Integer_32 := 0;
   Automatic_Threshold_Triangle : constant Interfaces.Integer_32 := 1;

   Adaptive_Threshold_Mean     : constant Interfaces.Integer_32 := 0;
   Adaptive_Threshold_Gaussian : constant Interfaces.Integer_32 := 1;

   Contour_Retrieval_External : constant Interfaces.Integer_32 := 0;
   Contour_Retrieval_List     : constant Interfaces.Integer_32 := 1;
   Contour_Retrieval_CComp    : constant Interfaces.Integer_32 := 2;
   Contour_Retrieval_Tree     : constant Interfaces.Integer_32 := 3;

   Contour_Approximation_None      : constant Interfaces.Integer_32 := 0;
   Contour_Approximation_Simple    : constant Interfaces.Integer_32 := 1;
   Contour_Approximation_TC89_L1   : constant Interfaces.Integer_32 := 2;
   Contour_Approximation_TC89_KCOS : constant Interfaces.Integer_32 := 3;

   type Contours_Handle is new System.Address;
   Null_Contours_Handle : constant Contours_Handle :=
     Contours_Handle (System.Null_Address);

   type Point_I32 is record
      X : Interfaces.Integer_32;
      Y : Interfaces.Integer_32;
   end record
   with Convention => C;

   type Point_I32_Array is array (Natural range <>) of aliased Point_I32
   with Convention => C;

   Derivative_Same_Depth : constant Interfaces.Integer_32 := 0;
   Derivative_Int16      : constant Interfaces.Integer_32 := 1;
   Derivative_Float32    : constant Interfaces.Integer_32 := 2;
   Derivative_Float64    : constant Interfaces.Integer_32 := 3;

   Sobel_Kernel_1 : constant Interfaces.Integer_32 := 1;
   Sobel_Kernel_3 : constant Interfaces.Integer_32 := 3;
   Sobel_Kernel_5 : constant Interfaces.Integer_32 := 5;
   Sobel_Kernel_7 : constant Interfaces.Integer_32 := 7;

   Derivative_X : constant Interfaces.Integer_32 := 0;
   Derivative_Y : constant Interfaces.Integer_32 := 1;

   Gaussian_Kernel_Float32 : constant Interfaces.Integer_32 := 0;
   Gaussian_Kernel_Float64 : constant Interfaces.Integer_32 := 1;

   Derivative_Kernels_Unnormalized : constant Interfaces.Integer_32 := 0;
   Derivative_Kernels_Normalized   : constant Interfaces.Integer_32 := 1;

   Derivative_Kernel_Scharr : constant Interfaces.Integer_32 :=
     Interfaces.Integer_32 (Integer'(-1));

   Template_Squared_Difference                 :
     constant Interfaces.Integer_32 := 0;
   Template_Normalized_Squared_Difference      :
     constant Interfaces.Integer_32 := 1;
   Template_Cross_Correlation                  :
     constant Interfaces.Integer_32 := 2;
   Template_Normalized_Cross_Correlation       :
     constant Interfaces.Integer_32 := 3;
   Template_Correlation_Coefficient            :
     constant Interfaces.Integer_32 := 4;
   Template_Normalized_Correlation_Coefficient :
     constant Interfaces.Integer_32 := 5;

   Warp_Interpolation_Nearest : constant Interfaces.Integer_32 := 0;
   Warp_Interpolation_Linear  : constant Interfaces.Integer_32 := 1;

   Warp_Mapping_Source_To_Destination : constant Interfaces.Integer_32 := 0;
   Warp_Mapping_Destination_To_Source : constant Interfaces.Integer_32 := 1;

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

   function Get_Gaussian_Kernel
     (Destination  : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel_Size  : Interfaces.Integer_32;
      Sigma        : Interfaces.C.double;
      Kernel_Depth : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_get_gaussian_kernel";

   function Get_Derivative_Kernels
     (Kernel_X     : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel_Y     : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      X_Order      : Interfaces.Integer_32;
      Y_Order      : Interfaces.Integer_32;
      Kernel_Size  : Interfaces.Integer_32;
      Normalize    : Interfaces.Integer_32;
      Kernel_Depth : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_get_derivative_kernels";

   function Median_Blur
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel_Size : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_median_blur";

   function Box_Blur
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel_Width  : Interfaces.Integer_32;
      Kernel_Height : Interfaces.Integer_32;
      Border        : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_box_blur";

   function Bilateral_Filter
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Diameter    : Interfaces.Integer_32;
      Sigma_Color : Interfaces.C.double;
      Sigma_Space : Interfaces.C.double;
      Border      : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_bilateral_filter";

   function Filter_2D
     (Source            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination_Depth : Interfaces.Integer_32;
      Anchor_X          : Interfaces.Integer_32;
      Anchor_Y          : Interfaces.Integer_32;
      Offset            : Interfaces.C.double;
      Border            : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_filter_2d";

   function Sep_Filter_2D
     (Source            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel_X          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Kernel_Y          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination_Depth : Interfaces.Integer_32;
      Anchor_X          : Interfaces.Integer_32;
      Anchor_Y          : Interfaces.Integer_32;
      Offset            : Interfaces.C.double;
      Border            : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_sep_filter_2d";

   function Erode
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel_Width  : Interfaces.Integer_32;
      Kernel_Height : Interfaces.Integer_32;
      Shape         : Interfaces.Integer_32;
      Iterations    : Interfaces.Integer_32;
      Border        : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_erode";

   function Dilate
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Kernel_Width  : Interfaces.Integer_32;
      Kernel_Height : Interfaces.Integer_32;
      Shape         : Interfaces.Integer_32;
      Iterations    : Interfaces.Integer_32;
      Border        : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_dilate";

   function Morphology_Ex
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Operation     : Interfaces.Integer_32;
      Kernel_Width  : Interfaces.Integer_32;
      Kernel_Height : Interfaces.Integer_32;
      Shape         : Interfaces.Integer_32;
      Iterations    : Interfaces.Integer_32;
      Border        : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_morphology_ex";

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

   function Automatic_Threshold
     (Source             : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination        : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Maximum_Value      : Interfaces.C.double;
      Method             : Interfaces.Integer_32;
      Mode               : Interfaces.Integer_32;
      Computed_Threshold : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_automatic_threshold";

   function Adaptive_Threshold
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Maximum_Value : Interfaces.Integer_32;
      Method        : Interfaces.Integer_32;
      Mode          : Interfaces.Integer_32;
      Block_Size    : Interfaces.Integer_32;
      Bias          : Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_adaptive_threshold";

   function Find_Contours
     (Source             : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Retrieval_Mode     : Interfaces.Integer_32;
      Approximation_Mode : Interfaces.Integer_32;
      Offset_X           : Interfaces.Integer_32;
      Offset_Y           : Interfaces.Integer_32;
      Result             : access Contours_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_find_contours";

   procedure Contours_Destroy (Result : Contours_Handle)
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_contours_destroy";

   function Contour_Count
     (Result : Contours_Handle; Count : access Interfaces.Integer_32)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_contour_count";

   function Contour_Point_Count
     (Result        : Contours_Handle;
      Contour_Index : Interfaces.Integer_32;
      Count         : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_contour_point_count";

   function Contour_Copy_Points
     (Result        : Contours_Handle;
      Contour_Index : Interfaces.Integer_32;
      Points        : access Point_I32;
      Capacity      : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_contour_copy_points";

   function Contour_Hierarchy
     (Result        : Contours_Handle;
      Contour_Index : Interfaces.Integer_32;
      Next          : access Interfaces.Integer_32;
      Previous      : access Interfaces.Integer_32;
      First_Child   : access Interfaces.Integer_32;
      Parent        : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_contour_hierarchy";

   function Sobel
     (Source            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Destination_Depth : Interfaces.Integer_32;
      X_Order           : Interfaces.Integer_32;
      Y_Order           : Interfaces.Integer_32;
      Kernel_Size       : Interfaces.Integer_32;
      Scale             : Interfaces.C.double;
      Offset            : Interfaces.C.double;
      Border            : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_sobel";

   function Scharr
     (Source            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Destination_Depth : Interfaces.Integer_32;
      Axis              : Interfaces.Integer_32;
      Scale             : Interfaces.C.double;
      Offset            : Interfaces.C.double;
      Border            : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_scharr";

   function Laplacian
     (Source            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Destination_Depth : Interfaces.Integer_32;
      Kernel_Size       : Interfaces.Integer_32;
      Scale             : Interfaces.C.double;
      Offset            : Interfaces.C.double;
      Border            : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_laplacian";

   function Pyramid_Down
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Border      : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_pyr_down";

   function Pyramid_Up
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_pyr_up";

   function Match_Template
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Template    : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Method      : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_match_template";

   function Warp_Affine
     (Source         : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Transform      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination    : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Output_Width   : Interfaces.Integer_32;
      Output_Height  : Interfaces.Integer_32;
      Interpolation  : Interfaces.Integer_32;
      Mapping        : Interfaces.Integer_32;
      Border         : Interfaces.Integer_32;
      Border_Value_0 : Interfaces.C.double;
      Border_Value_1 : Interfaces.C.double;
      Border_Value_2 : Interfaces.C.double;
      Border_Value_3 : Interfaces.C.double) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_warp_affine";

   function Last_Error_Message return String;

end OpenCV.Image_Processing.Internal.C_API;
