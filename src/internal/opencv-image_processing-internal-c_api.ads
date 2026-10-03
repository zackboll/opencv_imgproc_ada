with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with OpenCV.Core.Module_Interop;
with System;

package OpenCV.Image_Processing.Internal.C_API is

   type Status is new Interfaces.Integer_32;

   function Phase_Correlate
     (Source_1, Source_2, Window : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      X, Y, Response             : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_phase_correlate";

   function Create_Hanning_Window
     (Width, Height, Depth : Interfaces.Integer_32;
      Result               : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_create_hanning_window";

   function Accumulate_Image
     (Source_1, Source_2, Base, Mask :
        OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Mode                           : Interfaces.Integer_32;
      Weight                         : Interfaces.C.double;
      Result                         :
        OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_accumulate_image";

   type Corner_Point is record
      X, Y : Interfaces.C.C_float;
   end record
   with Convention => C;
   type Corner_Point_Buffer is array (Integer range <>) of aliased Corner_Point
   with Convention => C;

   function Corner_Response
     (Source                     : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination                :
        OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Mode, Block_Size, Aperture : Interfaces.Integer_32;
      K                          : Interfaces.C.double;
      Border                     : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_corner_response";

   function Corner_Subpixel
     (Source                                                       :
        OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Points                                                       :
        access constant Corner_Point;
      Count                                                        :
        Interfaces.Integer_32;
      Result                                                       :
        access Corner_Point;
      Half_Width, Half_Height, Dead_Width, Dead_Height, Iterations :
        Interfaces.Integer_32;
      Epsilon                                                      :
        Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_corner_subpixel";

   function Integral_Sum
     (Source    : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Sum_Depth : Interfaces.Integer_32;
      Sum       : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_integral_sum";
   function Integral_Sum_Squares
     (Source                   : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Sum_Depth, Squared_Depth : Interfaces.Integer_32;
      Sum, Squared             : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_integral_sum_squares";
   function Integral_Complete
     (Source                   : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Sum_Depth, Squared_Depth : Interfaces.Integer_32;
      Sum, Squared, Tilted     : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_integral_complete";

   Success                : constant Status := 0;
   Error_OpenCV           : constant Status := 1;
   Error_Standard_CPP     : constant Status := 2;
   Error_Unknown          : constant Status := 3;
   Error_Invalid_Argument : constant Status := 4;

   EMD_Manhattan  : constant Interfaces.Integer_32 := 0;
   EMD_Euclidean  : constant Interfaces.Integer_32 := 1;
   EMD_Chessboard : constant Interfaces.Integer_32 := 2;
   EMD_User_Cost  : constant Interfaces.Integer_32 := 3;

   function Earth_Mover_Distance
     (Signature_1, Signature_2 : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Metric                   : Interfaces.Integer_32;
      Cost                     : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Distance                 : access Interfaces.C.C_float) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_earth_mover_distance";
   function Earth_Mover_Distance_Flow
     (Signature_1, Signature_2 : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Metric                   : Interfaces.Integer_32;
      Cost                     : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Distance                 : access Interfaces.C.C_float;
      Flow                     : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_earth_mover_distance_flow";

   function Distance_Transform_F32
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Method      : Interfaces.Integer_32;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_distance_transform_f32";
   function Distance_Transform_L1_U8
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_distance_transform_l1_u8";
   function Distance_Transform_Labeled
     (Source             : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Metric, Label_Mode : Interfaces.Integer_32;
      Distances, Labels  : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_distance_transform_labeled";

   BGR_To_Gray                : constant Interfaces.Integer_32 := 0;
   --  Private semantic selectors, independent of OpenCV's numeric codes.
   RGB_To_Gray                : constant Interfaces.Integer_32 := 1;
   BGRA_To_Gray               : constant Interfaces.Integer_32 := 2;
   RGBA_To_Gray               : constant Interfaces.Integer_32 := 3;
   Gray_To_BGR                : constant Interfaces.Integer_32 := 4;
   Gray_To_RGB                : constant Interfaces.Integer_32 := 5;
   Gray_To_BGRA               : constant Interfaces.Integer_32 := 6;
   Gray_To_RGBA               : constant Interfaces.Integer_32 := 7;
   BGR_To_RGB                 : constant Interfaces.Integer_32 := 8;
   RGB_To_BGR                 : constant Interfaces.Integer_32 := 9;
   BGR_To_BGRA                : constant Interfaces.Integer_32 := 10;
   RGB_To_RGBA                : constant Interfaces.Integer_32 := 11;
   BGR_To_RGBA                : constant Interfaces.Integer_32 := 12;
   RGB_To_BGRA                : constant Interfaces.Integer_32 := 13;
   BGRA_To_BGR                : constant Interfaces.Integer_32 := 14;
   RGBA_To_RGB                : constant Interfaces.Integer_32 := 15;
   RGBA_To_BGR                : constant Interfaces.Integer_32 := 16;
   BGRA_To_RGB                : constant Interfaces.Integer_32 := 17;
   BGRA_To_RGBA               : constant Interfaces.Integer_32 := 18;
   RGBA_To_BGRA               : constant Interfaces.Integer_32 := 19;
   BGR_To_XYZ                 : constant Interfaces.Integer_32 := 20;
   RGB_To_XYZ                 : constant Interfaces.Integer_32 := 21;
   XYZ_To_BGR                 : constant Interfaces.Integer_32 := 22;
   XYZ_To_RGB                 : constant Interfaces.Integer_32 := 23;
   BGR_To_YCrCb               : constant Interfaces.Integer_32 := 24;
   RGB_To_YCrCb               : constant Interfaces.Integer_32 := 25;
   YCrCb_To_BGR               : constant Interfaces.Integer_32 := 26;
   YCrCb_To_RGB               : constant Interfaces.Integer_32 := 27;
   BGR_To_YUV                 : constant Interfaces.Integer_32 := 28;
   RGB_To_YUV                 : constant Interfaces.Integer_32 := 29;
   YUV_To_BGR                 : constant Interfaces.Integer_32 := 30;
   YUV_To_RGB                 : constant Interfaces.Integer_32 := 31;
   BGR_To_HSV                 : constant Interfaces.Integer_32 := 32;
   RGB_To_HSV                 : constant Interfaces.Integer_32 := 33;
   HSV_To_BGR                 : constant Interfaces.Integer_32 := 34;
   HSV_To_RGB                 : constant Interfaces.Integer_32 := 35;
   BGR_To_HLS                 : constant Interfaces.Integer_32 := 36;
   RGB_To_HLS                 : constant Interfaces.Integer_32 := 37;
   HLS_To_BGR                 : constant Interfaces.Integer_32 := 38;
   HLS_To_RGB                 : constant Interfaces.Integer_32 := 39;
   BGR_To_Lab                 : constant Interfaces.Integer_32 := 40;
   RGB_To_Lab                 : constant Interfaces.Integer_32 := 41;
   Lab_To_BGR                 : constant Interfaces.Integer_32 := 42;
   Lab_To_RGB                 : constant Interfaces.Integer_32 := 43;
   BGR_To_Luv                 : constant Interfaces.Integer_32 := 44;
   RGB_To_Luv                 : constant Interfaces.Integer_32 := 45;
   Luv_To_BGR                 : constant Interfaces.Integer_32 := 46;
   Luv_To_RGB                 : constant Interfaces.Integer_32 := 47;
   BGR_To_BGR565              : constant Interfaces.Integer_32 := 48;
   RGB_To_BGR565              : constant Interfaces.Integer_32 := 49;
   BGRA_To_BGR565             : constant Interfaces.Integer_32 := 50;
   RGBA_To_BGR565             : constant Interfaces.Integer_32 := 51;
   BGR565_To_BGR              : constant Interfaces.Integer_32 := 52;
   BGR565_To_RGB              : constant Interfaces.Integer_32 := 53;
   BGR565_To_BGRA             : constant Interfaces.Integer_32 := 54;
   BGR565_To_RGBA             : constant Interfaces.Integer_32 := 55;
   Gray_To_BGR565             : constant Interfaces.Integer_32 := 56;
   BGR565_To_Gray             : constant Interfaces.Integer_32 := 57;
   BGR_To_BGR555              : constant Interfaces.Integer_32 := 58;
   RGB_To_BGR555              : constant Interfaces.Integer_32 := 59;
   BGRA_To_BGR555             : constant Interfaces.Integer_32 := 60;
   RGBA_To_BGR555             : constant Interfaces.Integer_32 := 61;
   BGR555_To_BGR              : constant Interfaces.Integer_32 := 62;
   BGR555_To_RGB              : constant Interfaces.Integer_32 := 63;
   BGR555_To_BGRA             : constant Interfaces.Integer_32 := 64;
   BGR555_To_RGBA             : constant Interfaces.Integer_32 := 65;
   Gray_To_BGR555             : constant Interfaces.Integer_32 := 66;
   BGR555_To_Gray             : constant Interfaces.Integer_32 := 67;
   BGR_To_HSV_Full            : constant Interfaces.Integer_32 := 68;
   RGB_To_HSV_Full            : constant Interfaces.Integer_32 := 69;
   HSV_Full_To_BGR            : constant Interfaces.Integer_32 := 70;
   HSV_Full_To_RGB            : constant Interfaces.Integer_32 := 71;
   BGR_To_HLS_Full            : constant Interfaces.Integer_32 := 72;
   RGB_To_HLS_Full            : constant Interfaces.Integer_32 := 73;
   HLS_Full_To_BGR            : constant Interfaces.Integer_32 := 74;
   HLS_Full_To_RGB            : constant Interfaces.Integer_32 := 75;
   Linear_BGR_To_Lab          : constant Interfaces.Integer_32 := 76;
   Linear_RGB_To_Lab          : constant Interfaces.Integer_32 := 77;
   Lab_To_Linear_BGR          : constant Interfaces.Integer_32 := 78;
   Lab_To_Linear_RGB          : constant Interfaces.Integer_32 := 79;
   Linear_BGR_To_Luv          : constant Interfaces.Integer_32 := 80;
   Linear_RGB_To_Luv          : constant Interfaces.Integer_32 := 81;
   Luv_To_Linear_BGR          : constant Interfaces.Integer_32 := 82;
   Luv_To_Linear_RGB          : constant Interfaces.Integer_32 := 83;
   RGBA_To_Premultiplied_RGBA : constant Interfaces.Integer_32 := 84;
   Premultiplied_RGBA_To_RGBA : constant Interfaces.Integer_32 := 85;

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

   type Contour_Span is record
      First_Point : Interfaces.Integer_32;
      Point_Count : Interfaces.Integer_32;
   end record
   with Convention => C;

   type Contour_Span_Array is array (Natural range <>) of aliased Contour_Span
   with Convention => C;

   type Hough_Lines_Handle is new System.Address;
   Null_Hough_Lines_Handle : constant Hough_Lines_Handle :=
     Hough_Lines_Handle (System.Null_Address);

   type Hough_Segments_Handle is new System.Address;
   Null_Hough_Segments_Handle : constant Hough_Segments_Handle :=
     Hough_Segments_Handle (System.Null_Address);

   type Hough_Circles_Handle is new System.Address;
   Null_Hough_Circles_Handle : constant Hough_Circles_Handle :=
     Hough_Circles_Handle (System.Null_Address);

   type Pyramid_Handle is new System.Address;
   Null_Pyramid_Handle : constant Pyramid_Handle :=
     Pyramid_Handle (System.Null_Address);

   type Hough_Line_Evidence_Handle is new System.Address;
   Null_Hough_Line_Evidence_Handle : constant Hough_Line_Evidence_Handle :=
     Hough_Line_Evidence_Handle (System.Null_Address);

   type Hough_Circle_Evidence_Handle is new System.Address;
   Null_Hough_Circle_Evidence_Handle : constant Hough_Circle_Evidence_Handle :=
     Hough_Circle_Evidence_Handle (System.Null_Address);

   Hough_Radius_Automatic    : constant Interfaces.Integer_32 := 0;
   Hough_Radius_Explicit     : constant Interfaces.Integer_32 := 1;
   Hough_Radius_Centers_Only : constant Interfaces.Integer_32 := 2;

   type Point_F32 is record
      X : Interfaces.C.C_float;
      Y : Interfaces.C.C_float;
   end record
   with Convention => C;

   type Point_F32_Array is array (Natural range <>) of aliased Point_F32
   with Convention => C;

   type Hough_Line_Evidence_Record is record
      Rho   : Interfaces.C.double;
      Theta : Interfaces.C.double;
      Votes : Interfaces.C.double;
   end record
   with Convention => C;

   type Hough_Line_Evidence_Record_Array is
     array (Natural range <>) of aliased Hough_Line_Evidence_Record
   with Convention => C;

   type Hough_Circle_Evidence_Record is record
      X      : Interfaces.C.C_float;
      Y      : Interfaces.C.C_float;
      Radius : Interfaces.C.C_float;
      Votes  : Interfaces.C.C_float;
   end record
   with Convention => C;

   type Hough_Circle_Evidence_Record_Array is
     array (Natural range <>) of aliased Hough_Circle_Evidence_Record
   with Convention => C;

   type Hough_Line_Record is record
      Rho   : Interfaces.C.C_float;
      Theta : Interfaces.C.C_float;
   end record
   with Convention => C;

   type Hough_Line_Record_Array is
     array (Natural range <>) of aliased Hough_Line_Record
   with Convention => C;

   type Hough_Segment_Record is record
      X1 : Interfaces.Integer_32;
      Y1 : Interfaces.Integer_32;
      X2 : Interfaces.Integer_32;
      Y2 : Interfaces.Integer_32;
   end record
   with Convention => C;

   type Hough_Segment_Record_Array is
     array (Natural range <>) of aliased Hough_Segment_Record
   with Convention => C;

   type Hough_Circle_Record is record
      X      : Interfaces.C.C_float;
      Y      : Interfaces.C.C_float;
      Radius : Interfaces.C.C_float;
   end record
   with Convention => C;

   type Hough_Circle_Record_Array is
     array (Natural range <>) of aliased Hough_Circle_Record
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

   Drawing_Line_4  : constant Interfaces.Integer_32 := 0;
   Drawing_Line_8  : constant Interfaces.Integer_32 := 1;
   Drawing_Line_AA : constant Interfaces.Integer_32 := 2;

   Drawing_Outline : constant Interfaces.Integer_32 := 0;
   Drawing_Filled  : constant Interfaces.Integer_32 := 1;

   function Last_Error_Message_Pointer return Interfaces.C.Strings.chars_ptr
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_last_error_message";

   function Decode_YUV420
     (Source         : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination    : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Layout, Output : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_decode_yuv420";

   function Decode_YUV420_Two_Plane
     (Y_Plane, UV_Plane : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Layout, Output    : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_decode_yuv420_two_plane";

   function Encode_YUV420_Planar
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Layout, Order : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_encode_yuv420_planar";

   function Extract_YUV420_Luma
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_extract_yuv420_luma";

   function Demosaic_Bayer
     (Source                 : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination            : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Pattern, Method, Order : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_demosaic_bayer";

   function Demosaic_Bayer_Gray
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Pattern     : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_demosaic_bayer_gray";

   function Demosaic_Bayer_Alpha
     (Source         : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination    : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Pattern, Order : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_demosaic_bayer_alpha";

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

   function Get_Gabor_Kernel
     (Destination  : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Width        : Interfaces.Integer_32;
      Height       : Interfaces.Integer_32;
      Sigma        : Interfaces.C.double;
      Orientation  : Interfaces.C.double;
      Wavelength   : Interfaces.C.double;
      Aspect_Ratio : Interfaces.C.double;
      Phase        : Interfaces.C.double;
      Depth        : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_get_gabor_kernel";

   function Get_Structuring_Element
     (Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Width       : Interfaces.Integer_32;
      Height      : Interfaces.Integer_32;
      Shape       : Interfaces.Integer_32;
      Anchor_X    : Interfaces.Integer_32;
      Anchor_Y    : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_get_structuring_element";

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

   type Morphology_Scalar is array (0 .. 3) of aliased Interfaces.C.double
   with Convention => C;

   function Morphology_Request
     (Source                                                  :
        OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination                                             :
        OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Operation                                               :
        Interfaces.Integer_32;
      Kernel_Source                                           :
        Interfaces.Integer_32;
      Kernel                                                  :
        OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Kernel_Width, Kernel_Height, Shape, Explicit_Anchor     :
        Interfaces.Integer_32;
      Anchor_X, Anchor_Y, Iterations, Border, Explicit_Border :
        Interfaces.Integer_32;
      Border_Components                                       :
        access constant Morphology_Scalar) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_morphology_request";

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

   function Equalize_Histogram
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_equalize_histogram";

   function CLAHE
     (Source           : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination      : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Clip_Limit       : Interfaces.C.double;
      Tile_Grid_Width  : Interfaces.Integer_32;
      Tile_Grid_Height : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_clahe";

   function Connected_Components_With_Stats
     (Source       : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Labels       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Stats        : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Centroids    : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Connectivity : Interfaces.Integer_32;
      Label_Count  : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_connected_components_with_stats";

   function Mats_Overlap
     (First   : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Second  : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Overlap : access Interfaces.Unsigned_8) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_mats_overlap";

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

   function Hough_Lines
     (Source    : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Rho       : Interfaces.C.double;
      Theta     : Interfaces.C.double;
      Threshold : Interfaces.Integer_32;
      Min_Theta : Interfaces.C.double;
      Max_Theta : Interfaces.C.double;
      Result    : access Hough_Lines_Handle) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_hough_lines";

   procedure Hough_Lines_Destroy (Result : Hough_Lines_Handle)
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_lines_destroy";

   function Hough_Lines_Count
     (Result : Hough_Lines_Handle; Count : access Interfaces.Integer_32)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_lines_count";

   function Hough_Lines_Copy
     (Result   : Hough_Lines_Handle;
      Lines    : access Hough_Line_Record;
      Capacity : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_lines_copy";

   function Hough_Segments
     (Source          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Rho             : Interfaces.C.double;
      Theta           : Interfaces.C.double;
      Threshold       : Interfaces.Integer_32;
      Min_Line_Length : Interfaces.Integer_32;
      Max_Line_Gap    : Interfaces.Integer_32;
      Result          : access Hough_Segments_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_segments";

   procedure Hough_Segments_Destroy (Result : Hough_Segments_Handle)
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_segments_destroy";

   function Hough_Segments_Count
     (Result : Hough_Segments_Handle; Count : access Interfaces.Integer_32)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_segments_count";

   function Hough_Segments_Copy
     (Result   : Hough_Segments_Handle;
      Segments : access Hough_Segment_Record;
      Capacity : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_segments_copy";

   function Hough_Circles
     (Source                : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Accumulator_Scale     : Interfaces.C.double;
      Min_Distance          : Interfaces.C.double;
      Canny_Threshold       : Interfaces.Integer_32;
      Accumulator_Threshold : Interfaces.Integer_32;
      Radius_Mode           : Interfaces.Integer_32;
      Min_Radius            : Interfaces.Integer_32;
      Max_Radius            : Interfaces.Integer_32;
      Result                : access Hough_Circles_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_circles";

   procedure Hough_Circles_Destroy (Result : Hough_Circles_Handle)
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_circles_destroy";

   function Hough_Circles_Count
     (Result : Hough_Circles_Handle; Count : access Interfaces.Integer_32)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_circles_count";

   function Hough_Circles_Copy
     (Result   : Hough_Circles_Handle;
      Circles  : access Hough_Circle_Record;
      Capacity : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_circles_copy";

   function Hough_Lines_With_Votes
     (Source    : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Rho       : Interfaces.C.double;
      Theta     : Interfaces.C.double;
      Threshold : Interfaces.Integer_32;
      Min_Theta : Interfaces.C.double;
      Max_Theta : Interfaces.C.double;
      Result    : access Hough_Line_Evidence_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_lines_with_votes";

   function Hough_Lines_Point_Set
     (Points        : access constant Point_F32;
      Point_Count   : Interfaces.Integer_32;
      Maximum_Lines : Interfaces.Integer_32;
      Threshold     : Interfaces.Integer_32;
      Min_Rho       : Interfaces.C.double;
      Max_Rho       : Interfaces.C.double;
      Rho_Step      : Interfaces.C.double;
      Min_Theta     : Interfaces.C.double;
      Max_Theta     : Interfaces.C.double;
      Theta_Step    : Interfaces.C.double;
      Result        : access Hough_Line_Evidence_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_lines_point_set";

   procedure Hough_Line_Evidence_Destroy (Result : Hough_Line_Evidence_Handle)
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_line_evidence_destroy";

   function Hough_Line_Evidence_Count
     (Result : Hough_Line_Evidence_Handle;
      Count  : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_line_evidence_count";

   function Hough_Line_Evidence_Copy
     (Result   : Hough_Line_Evidence_Handle;
      Lines    : access Hough_Line_Evidence_Record;
      Capacity : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_line_evidence_copy";

   function Hough_Circles_With_Votes
     (Source                : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Accumulator_Scale     : Interfaces.C.double;
      Min_Distance          : Interfaces.C.double;
      Canny_Threshold       : Interfaces.Integer_32;
      Accumulator_Threshold : Interfaces.Integer_32;
      Radius_Mode           : Interfaces.Integer_32;
      Min_Radius            : Interfaces.Integer_32;
      Max_Radius            : Interfaces.Integer_32;
      Result                : access Hough_Circle_Evidence_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_circles_with_votes";

   procedure Hough_Circle_Evidence_Destroy
     (Result : Hough_Circle_Evidence_Handle)
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_circle_evidence_destroy";

   function Hough_Circle_Evidence_Count
     (Result : Hough_Circle_Evidence_Handle;
      Count  : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_circle_evidence_count";

   function Hough_Circle_Evidence_Copy
     (Result   : Hough_Circle_Evidence_Handle;
      Circles  : access Hough_Circle_Evidence_Record;
      Capacity : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_hough_circle_evidence_copy";

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

   function Pyramid_Up_Sized
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Width       : Interfaces.Integer_32;
      Height      : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_pyr_up_sized";

   function Pyramid_Mean_Shift_Filter
     (Source                : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination           : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Spatial_Radius        : Interfaces.C.double;
      Color_Radius          : Interfaces.C.double;
      Maximum_Pyramid_Level : Interfaces.Integer_32;
      Maximum_Iterations    : Interfaces.Integer_32;
      Epsilon               : Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_pyr_mean_shift_filter";

   function Build_Pyramid
     (Source      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Level_Count : Interfaces.Integer_32;
      Border      : Interfaces.Integer_32;
      Result      : access Pyramid_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_build_pyramid";

   procedure Pyramid_Destroy (Result : Pyramid_Handle)
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_pyramid_destroy";

   function Pyramid_Count
     (Result : Pyramid_Handle; Count : access Interfaces.Integer_32)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_pyramid_count";

   function Pyramid_Copy_Level
     (Result      : Pyramid_Handle;
      Index       : Interfaces.Integer_32;
      Destination : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_pyramid_copy_level";

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

   function Warp_Perspective
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
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_warp_perspective";

   function Warp_Polar
     (Source        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination   : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Center_X      : Interfaces.C.C_float;
      Center_Y      : Interfaces.C.C_float;
      Radius        : Interfaces.C.double;
      Output_Width  : Interfaces.Integer_32;
      Output_Height : Interfaces.Integer_32;
      Mapping       : Interfaces.Integer_32;
      Direction     : Interfaces.Integer_32;
      Interpolation : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_warp_polar";

   function Remap
     (Source         : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Map_X          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Map_Y          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination    : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Interpolation  : Interfaces.Integer_32;
      Border         : Interfaces.Integer_32;
      Border_Value_0 : Interfaces.C.double;
      Border_Value_1 : Interfaces.C.double;
      Border_Value_2 : Interfaces.C.double;
      Border_Value_3 : Interfaces.C.double) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_remap";

   function Remap_Encoded
     (Source         : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Map_1          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Map_2          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Destination    : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Mode           : Interfaces.Integer_32;
      Interpolation  : Interfaces.Integer_32;
      Border         : Interfaces.Integer_32;
      Border_Value_0 : Interfaces.C.double;
      Border_Value_1 : Interfaces.C.double;
      Border_Value_2 : Interfaces.C.double;
      Border_Value_3 : Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_remap_encoded";

   function Convert_Remap_Maps
     (Map_1        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Map_2        : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Output_1     : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Output_2     : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Mode         : Interfaces.Integer_32;
      Nearest_Only : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_convert_remap_maps";

   function Draw_Line
     (Image      : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Start_X    : Interfaces.Integer_32;
      Start_Y    : Interfaces.Integer_32;
      Finish_X   : Interfaces.Integer_32;
      Finish_Y   : Interfaces.Integer_32;
      Color_0    : Interfaces.C.double;
      Color_1    : Interfaces.C.double;
      Color_2    : Interfaces.C.double;
      Color_3    : Interfaces.C.double;
      Thickness  : Interfaces.Integer_32;
      Line_Style : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_draw_line";

   function Draw_Arrow
     (Image                                :
        OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Start_X, Start_Y, Finish_X, Finish_Y : Interfaces.Integer_32;
      Color_0, Color_1, Color_2, Color_3   : Interfaces.C.double;
      Tip_Length                           : Interfaces.C.double;
      Thickness, Line_Style                : Interfaces.Integer_32)
      return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_draw_arrow";

   function Draw_Marker
     (Image                                      :
        OpenCV.Core.Module_Interop.Output_Mat_Handle;
      X, Y                                       : Interfaces.Integer_32;
      Color_0, Color_1, Color_2, Color_3         : Interfaces.C.double;
      Marker, Marker_Size, Thickness, Line_Style : Interfaces.Integer_32)
      return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_draw_marker";

   function Draw_Text
     (Image                              :
        OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Text                               : System.Address;
      Text_Length, X, Y                  : Interfaces.Integer_32;
      Color_0, Color_1, Color_2, Color_3 : Interfaces.C.double;
      Font                               : Interfaces.Integer_32;
      Font_Scale                         : Interfaces.C.double;
      Thickness                          : Interfaces.Integer_32;
      Bottom_Left_Origin                 : Interfaces.Unsigned_8) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_draw_text";

   function Measure_Text
     (Text                    : System.Address;
      Text_Length, Font       : Interfaces.Integer_32;
      Font_Scale              : Interfaces.C.double;
      Thickness               : Interfaces.Integer_32;
      Width, Height, Baseline : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_measure_text";

   function Font_Scale_For_Height
     (Pixel_Height, Font : Interfaces.Integer_32;
      Thickness          : Interfaces.Integer_32;
      Scale              : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_font_scale_for_height";

   function Draw_Rectangle
     (Image      : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Origin_X   : Interfaces.Integer_32;
      Origin_Y   : Interfaces.Integer_32;
      Width      : Interfaces.Integer_32;
      Height     : Interfaces.Integer_32;
      Color_0    : Interfaces.C.double;
      Color_1    : Interfaces.C.double;
      Color_2    : Interfaces.C.double;
      Color_3    : Interfaces.C.double;
      Filled     : Interfaces.Integer_32;
      Thickness  : Interfaces.Integer_32;
      Line_Style : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_draw_rectangle";

   function Draw_Circle
     (Image      : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Center_X   : Interfaces.Integer_32;
      Center_Y   : Interfaces.Integer_32;
      Radius     : Interfaces.Integer_32;
      Color_0    : Interfaces.C.double;
      Color_1    : Interfaces.C.double;
      Color_2    : Interfaces.C.double;
      Color_3    : Interfaces.C.double;
      Filled     : Interfaces.Integer_32;
      Thickness  : Interfaces.Integer_32;
      Line_Style : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_draw_circle";

   function Draw_Ellipse
     (Image       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Center_X    : Interfaces.Integer_32;
      Center_Y    : Interfaces.Integer_32;
      Axis_Width  : Interfaces.Integer_32;
      Axis_Height : Interfaces.Integer_32;
      Angle       : Interfaces.C.double;
      Start_Angle : Interfaces.C.double;
      End_Angle   : Interfaces.C.double;
      Color_0     : Interfaces.C.double;
      Color_1     : Interfaces.C.double;
      Color_2     : Interfaces.C.double;
      Color_3     : Interfaces.C.double;
      Filled      : Interfaces.Integer_32;
      Thickness   : Interfaces.Integer_32;
      Line_Style  : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_draw_ellipse";

   function Draw_Polyline
     (Image       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Points      : access constant Point_I32;
      Point_Count : Interfaces.Integer_32;
      Closed      : Interfaces.Unsigned_8;
      Color_0     : Interfaces.C.double;
      Color_1     : Interfaces.C.double;
      Color_2     : Interfaces.C.double;
      Color_3     : Interfaces.C.double;
      Thickness   : Interfaces.Integer_32;
      Line_Style  : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_draw_polyline";

   function Fill_Polygon
     (Image       : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Points      : access constant Point_I32;
      Point_Count : Interfaces.Integer_32;
      Color_0     : Interfaces.C.double;
      Color_1     : Interfaces.C.double;
      Color_2     : Interfaces.C.double;
      Color_3     : Interfaces.C.double;
      Line_Style  : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_fill_polygon";

   function Draw_Contours
     (Image         : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Points        : access constant Point_I32;
      Point_Count   : Interfaces.Integer_32;
      Contours      : access constant Contour_Span;
      Contour_Count : Interfaces.Integer_32;
      Color_0       : Interfaces.C.double;
      Color_1       : Interfaces.C.double;
      Color_2       : Interfaces.C.double;
      Color_3       : Interfaces.C.double;
      Filled        : Interfaces.Unsigned_8;
      Thickness     : Interfaces.Integer_32;
      Line_Style    : Interfaces.Integer_32;
      Offset_X      : Interfaces.Integer_32;
      Offset_Y      : Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_draw_contours";

   --  Segmentation.

   type Scalar4_Values is array (0 .. 3) of Interfaces.C.double
   with Convention => C;

   type Scalar4 is record
      Values : Scalar4_Values;
   end record
   with Convention => C;

   type Rect_I32 is record
      X      : Interfaces.Integer_32;
      Y      : Interfaces.Integer_32;
      Width  : Interfaces.Integer_32;
      Height : Interfaces.Integer_32;
   end record
   with Convention => C;

   Flood_Fill_Floating_Range : constant Interfaces.Integer_32 := 0;
   Flood_Fill_Fixed_Range    : constant Interfaces.Integer_32 := 1;

   function Flood_Fill
     (Image            : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Seed_X           : Interfaces.Integer_32;
      Seed_Y           : Interfaces.Integer_32;
      New_Value        : access constant Scalar4;
      Lower_Difference : access constant Scalar4;
      Upper_Difference : access constant Scalar4;
      Connectivity     : Interfaces.Integer_32;
      Range_Mode       : Interfaces.Integer_32;
      Pixel_Count      : access Interfaces.Integer_32;
      Bounds           : access Rect_I32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_flood_fill";

   function Flood_Fill_Masked
     (Image            : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Mask             : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Seed_X           : Interfaces.Integer_32;
      Seed_Y           : Interfaces.Integer_32;
      New_Value        : access constant Scalar4;
      Lower_Difference : access constant Scalar4;
      Upper_Difference : access constant Scalar4;
      Connectivity     : Interfaces.Integer_32;
      Range_Mode       : Interfaces.Integer_32;
      Mask_Fill_Value  : Interfaces.Integer_32;
      Mask_Only        : Interfaces.Unsigned_8;
      Pixel_Count      : access Interfaces.Integer_32;
      Bounds           : access Rect_I32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_flood_fill_masked";

   function Watershed
     (Source  : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Markers : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_watershed";

   GrabCut_Init_With_Rect    : constant Interfaces.Integer_32 := 0;
   GrabCut_Init_With_Mask    : constant Interfaces.Integer_32 := 1;
   GrabCut_Eval              : constant Interfaces.Integer_32 := 2;
   GrabCut_Eval_Freeze_Model : constant Interfaces.Integer_32 := 3;

   --  OpenCV 4.1 initializes five-component GMMs with kmeans (K => 5).
   GrabCut_Minimum_Training_Samples : constant := 5;

   --  Native GMM storage: five components of 13 Float64 values each.
   GrabCut_Model_Columns : constant := 65;

   function GrabCut
     (Source           : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Mask             : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Background_Model : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Foreground_Model : OpenCV.Core.Module_Interop.Output_Mat_Handle;
      Rect_X           : Interfaces.Integer_32;
      Rect_Y           : Interfaces.Integer_32;
      Rect_Width       : Interfaces.Integer_32;
      Rect_Height      : Interfaces.Integer_32;
      Iteration_Count  : Interfaces.Integer_32;
      Mode             : Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_grabcut";

   function Validate_GrabCut_Model
     (Model : OpenCV.Core.Module_Interop.Input_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_validate_grabcut_model";

   function Mat_Storage_Overlap
     (First   : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Second  : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Overlap : access Interfaces.Unsigned_8) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_mat_storage_overlap";

   --  Mirrors opencv_imgproc_histogram_dimension. Source position is 0.
   type Histogram_Dimension_Record is record
      Channel     : Interfaces.Integer_32;
      Bin_Count   : Interfaces.Integer_32;
      Lower_Bound : Interfaces.C.C_float;
      Upper_Bound : Interfaces.C.C_float;
   end record
   with Convention => C;

   type Histogram_Dimension_Records is
     array (Positive range <>) of aliased Histogram_Dimension_Record
   with Convention => C;

   --  Mirrors opencv_imgproc_histogram_source_dimension.
   type Histogram_Source_Dimension_Record is record
      Source_Position : Interfaces.Integer_32;
      Channel         : Interfaces.Integer_32;
      Bin_Count       : Interfaces.Integer_32;
      Lower_Bound     : Interfaces.C.C_float;
      Upper_Bound     : Interfaces.C.C_float;
   end record
   with Convention => C;

   type Histogram_Source_Dimension_Records is
     array (Positive range <>) of aliased Histogram_Source_Dimension_Record
   with Convention => C;

   --  Mirrors opencv_imgproc_histogram_nonuniform_dimension. Boundary_Offset
   --  indexes the flat Float32 edge buffer passed with the call.
   type Histogram_Nonuniform_Dimension_Record is record
      Source_Position : Interfaces.Integer_32;
      Channel         : Interfaces.Integer_32;
      Bin_Count       : Interfaces.Integer_32;
      Boundary_Offset : Interfaces.Unsigned_64;
   end record
   with Convention => C;

   type Histogram_Nonuniform_Dimension_Records is
     array (Positive range <>) of aliased Histogram_Nonuniform_Dimension_Record
   with Convention => C;

   type Histogram_Boundary_Values is
     array (Natural range <>) of aliased Interfaces.C.C_float
   with Convention => C;

   type Mat_Handle_Array is
     array (Natural range <>)
     of aliased OpenCV.Core.Module_Interop.Input_Mat_Handle
   with Convention => C;

   Histogram_Maximum_Dimensions : constant := 10;

   Histogram_Compare_Correlation    : constant Interfaces.Integer_32 := 0;
   Histogram_Compare_Chi_Square     : constant Interfaces.Integer_32 := 1;
   Histogram_Compare_Intersection   : constant Interfaces.Integer_32 := 2;
   Histogram_Compare_Hellinger      : constant Interfaces.Integer_32 := 3;
   Histogram_Compare_Chi_Square_Alt : constant Interfaces.Integer_32 := 4;
   Histogram_Compare_KL_Divergence  : constant Interfaces.Integer_32 := 5;

   function Calc_Hist
     (Source          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Dimensions      : access constant Histogram_Dimension_Record;
      Dimension_Count : Interfaces.Integer_32;
      Histogram       : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with Import, Convention => C, External_Name => "opencv_imgproc_calc_hist";

   function Calc_Hist_Masked
     (Source          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Mask            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Dimensions      : access constant Histogram_Dimension_Record;
      Dimension_Count : Interfaces.Integer_32;
      Histogram       : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_calc_hist_masked";

   function Calc_Hist_Multi
     (Sources         :
        access constant OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Source_Count    : Interfaces.Integer_32;
      Dimensions      : access constant Histogram_Source_Dimension_Record;
      Dimension_Count : Interfaces.Integer_32;
      Histogram       : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_calc_hist_multi";

   function Calc_Hist_Multi_Masked
     (Sources         :
        access constant OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Source_Count    : Interfaces.Integer_32;
      Mask            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Dimensions      : access constant Histogram_Source_Dimension_Record;
      Dimension_Count : Interfaces.Integer_32;
      Histogram       : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_calc_hist_multi_masked";

   function Calc_Hist_Nonuniform
     (Sources         :
        access constant OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Source_Count    : Interfaces.Integer_32;
      Mask            : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Masked          : Interfaces.Unsigned_8;
      Dimensions      : access constant Histogram_Nonuniform_Dimension_Record;
      Dimension_Count : Interfaces.Integer_32;
      Boundaries      : access constant Interfaces.C.C_float;
      Boundary_Count  : Interfaces.Unsigned_64;
      Histogram       : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_calc_hist_nonuniform";

   function Calc_Back_Project_Nonuniform
     (Sources         :
        access constant OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Source_Count    : Interfaces.Integer_32;
      Histogram       : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Dimensions      : access constant Histogram_Nonuniform_Dimension_Record;
      Dimension_Count : Interfaces.Integer_32;
      Boundaries      : access constant Interfaces.C.C_float;
      Boundary_Count  : Interfaces.Unsigned_64;
      Scale           : Interfaces.C.double;
      Destination     : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_calc_back_project_nonuniform";

   function Compare_Hist
     (Left   : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Right  : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Method : Interfaces.Integer_32;
      Result : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_compare_hist";

   function Calc_Back_Project
     (Source          : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Histogram       : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Dimensions      : access constant Histogram_Dimension_Record;
      Dimension_Count : Interfaces.Integer_32;
      Scale           : Interfaces.C.double;
      Destination     : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_calc_back_project";

   function Calc_Back_Project_Multi
     (Sources         :
        access constant OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Source_Count    : Interfaces.Integer_32;
      Histogram       : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Dimensions      : access constant Histogram_Source_Dimension_Record;
      Dimension_Count : Interfaces.Integer_32;
      Scale           : Interfaces.C.double;
      Destination     : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_calc_back_project_multi";

   function Add_Histograms
     (Base      : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Increment : OpenCV.Core.Module_Interop.Input_Mat_Handle;
      Result    : OpenCV.Core.Module_Interop.Output_Mat_Handle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_add_histograms";

   function Last_Error_Message return String;

end OpenCV.Image_Processing.Internal.C_API;
