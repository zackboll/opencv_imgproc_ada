with Ada.Containers;
with Ada.Exceptions;
with Ada.Unchecked_Deallocation;
with Interfaces;
with Interfaces.C;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Int32_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body OpenCV.Image_Processing is

   procedure Raise_On_Error
     (Status : Internal.C_API.Status; Operation : String);

   procedure Validate_Integral
     (Source        : OpenCV.Core.Mat;
      Sum_Depth     : Integral_Sum_Depth;
      Squared_Depth : Integral_Squared_Depth;
      Squares       : Boolean)
   is
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty
        or else Source.Dimension_Count /= 2
        or else Source.Depth
                not in OpenCV.Core.UInt8
                     | OpenCV.Core.Float32
                     | OpenCV.Core.Float64
        or else (Source.Depth = OpenCV.Core.Float32
                 and then Sum_Depth = Int32_Integral)
        or else (Source.Depth = OpenCV.Core.Float64
                 and then Sum_Depth /= Float64_Integral)
        or else (Squares
                 and then Sum_Depth = Float64_Integral
                 and then Squared_Depth = Float32_Squared_Integral)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Invalid integral source or accumulator depths");
      end if;
   end Validate_Integral;

   function Integral_Sum
     (Source    : OpenCV.Core.Mat;
      Sum_Depth : Integral_Sum_Depth := Float64_Integral)
      return OpenCV.Core.Mat
   is
      Result : OpenCV.Core.Mat;
      Status : Internal.C_API.Status;
      procedure Input (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Output
           (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              Internal.C_API.Integral_Sum
                (Handle, Integral_Sum_Depth'Pos (Sum_Depth), Target);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Result, Output'Access);
      end Input;
   begin
      Validate_Integral (Source, Sum_Depth, Float64_Squared_Integral, False);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "Integral_Sum");
      return Result;
   end Integral_Sum;

   function Integral_Sum_And_Squares
     (Source        : OpenCV.Core.Mat;
      Sum_Depth     : Integral_Sum_Depth := Float64_Integral;
      Squared_Depth : Integral_Squared_Depth := Float64_Squared_Integral)
      return Integral_Sum_And_Squares_Result
   is
      Result : Integral_Sum_And_Squares_Result;
      Status : Internal.C_API.Status;
      procedure Input (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Sum_Output
           (Sum : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure Square_Output
              (Squared : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Integral_Sum_Squares
                   (Handle,
                    Integral_Sum_Depth'Pos (Sum_Depth),
                    Integral_Squared_Depth'Pos (Squared_Depth),
                    Sum,
                    Squared);
            end Square_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Result.Squared_Sum, Square_Output'Access);
         end Sum_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Result.Sum, Sum_Output'Access);
      end Input;
   begin
      Validate_Integral (Source, Sum_Depth, Squared_Depth, True);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "Integral_Sum_And_Squares");
      return Result;
   end Integral_Sum_And_Squares;

   function Integral_Images
     (Source        : OpenCV.Core.Mat;
      Sum_Depth     : Integral_Sum_Depth := Float64_Integral;
      Squared_Depth : Integral_Squared_Depth := Float64_Squared_Integral)
      return Integral_Images_Result
   is
      Result : Integral_Images_Result;
      Status : Internal.C_API.Status;
      procedure Input (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Sum_Output
           (Sum : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure Square_Output
              (Squared : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
               procedure Tilt_Output
                 (Tilted : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    Internal.C_API.Integral_Complete
                      (Handle,
                       Integral_Sum_Depth'Pos (Sum_Depth),
                       Integral_Squared_Depth'Pos (Squared_Depth),
                       Sum,
                       Squared,
                       Tilted);
               end Tilt_Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Result.Tilted_Sum, Tilt_Output'Access);
            end Square_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Result.Squared_Sum, Square_Output'Access);
         end Sum_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Result.Sum, Sum_Output'Access);
      end Input;
   begin
      Validate_Integral (Source, Sum_Depth, Squared_Depth, True);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "Integral_Images");
      return Result;
   end Integral_Images;

   procedure Validate_Distance_Source (Source : OpenCV.Core.Mat) is
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Core.Channel_Count;
      use type Interfaces.Unsigned_8;
   begin
      if Source.Is_Empty
        or else Source.Dimension_Count /= 2
        or else Source.Depth /= OpenCV.Core.UInt8
        or else Source.Channels /= 1
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Distance transform requires a nonempty 2-D UInt8 C1 source");
      end if;
      for Row in 0 .. Source.Rows - 1 loop
         for Column in 0 .. Source.Columns - 1 loop
            if OpenCV.Core.UInt8_Access.Get (Source, Row, Column) = 0 then
               return;
            end if;
         end loop;
      end loop;
      Ada.Exceptions.Raise_Exception
        (OpenCV.OpenCV_Error'Identity,
         "Distance transform requires at least one zero pixel");
   end Validate_Distance_Source;

   function Distance_Transform
     (Source : OpenCV.Core.Mat;
      Method : Distance_Transform_Method := Euclidean_Precise)
      return OpenCV.Core.Mat
   is
      Output : OpenCV.Core.Mat;
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure With_Source
        (Input : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure With_Output
           (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              Internal.C_API.Distance_Transform_F32
                (Input, Distance_Transform_Method'Pos (Method), Target);
         end With_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Output, With_Output'Access);
      end With_Source;
   begin
      Validate_Distance_Source (Source);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, With_Source'Access);
      Raise_On_Error (Status, "Distance_Transform");
      return Output;
   end Distance_Transform;

   function Manhattan_Distance_Transform_UInt8
     (Source : OpenCV.Core.Mat) return OpenCV.Core.Mat
   is
      Output : OpenCV.Core.Mat;
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure With_Source
        (Input : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure With_Output
           (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status := Internal.C_API.Distance_Transform_L1_U8 (Input, Target);
         end With_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Output, With_Output'Access);
      end With_Source;
   begin
      Validate_Distance_Source (Source);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, With_Source'Access);
      Raise_On_Error (Status, "Manhattan_Distance_Transform_UInt8");
      return Output;
   end Manhattan_Distance_Transform_UInt8;

   function Distance_Transform_With_Labels
     (Source : OpenCV.Core.Mat;
      Metric : Labeled_Distance_Metric := Euclidean_Label_Distance;
      Labels : Distance_Label_Mode := Nearest_Zero_Component)
      return Labeled_Distance_Transform_Result
   is
      Output : Labeled_Distance_Transform_Result;
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure With_Source
        (Input : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure With_Distances
           (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure With_Labels
              (Label_Target : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Distance_Transform_Labeled
                   (Input,
                    Labeled_Distance_Metric'Pos (Metric),
                    Distance_Label_Mode'Pos (Labels),
                    Target,
                    Label_Target);
            end With_Labels;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Output.Labels, With_Labels'Access);
         end With_Distances;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Output.Distances, With_Distances'Access);
      end With_Source;
   begin
      Validate_Distance_Source (Source);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, With_Source'Access);
      Raise_On_Error (Status, "Distance_Transform_With_Labels");
      return Output;
   end Distance_Transform_With_Labels;

   function To_C_Contour_Retrieval
     (Retrieval : Contour_Retrieval_Mode) return Interfaces.Integer_32 is
   begin
      case Retrieval is
         when External_Only =>
            return Internal.C_API.Contour_Retrieval_External;

         when Flat_List     =>
            return Internal.C_API.Contour_Retrieval_List;

         when Two_Level     =>
            return Internal.C_API.Contour_Retrieval_CComp;

         when Full_Tree     =>
            return Internal.C_API.Contour_Retrieval_Tree;
      end case;
   end To_C_Contour_Retrieval;

   function To_C_Contour_Approximation
     (Approximation : Contour_Approximation_Mode) return Interfaces.Integer_32
   is
   begin
      case Approximation is
         when Every_Point   =>
            return Internal.C_API.Contour_Approximation_None;

         when Simple        =>
            return Internal.C_API.Contour_Approximation_Simple;

         when Teh_Chin_L1   =>
            return Internal.C_API.Contour_Approximation_TC89_L1;

         when Teh_Chin_KCOS =>
            return Internal.C_API.Contour_Approximation_TC89_KCOS;
      end case;
   end To_C_Contour_Approximation;

   function To_C_Conversion
     (Conversion : Color_Conversion) return Interfaces.Integer_32 is
   begin
      case Conversion is
         when BGR_To_Gray  =>
            return Internal.C_API.BGR_To_Gray;

         when RGB_To_Gray  =>
            return Internal.C_API.RGB_To_Gray;

         when BGRA_To_Gray =>
            return Internal.C_API.BGRA_To_Gray;

         when RGBA_To_Gray =>
            return Internal.C_API.RGBA_To_Gray;

         when Gray_To_BGR  =>
            return Internal.C_API.Gray_To_BGR;

         when Gray_To_RGB  =>
            return Internal.C_API.Gray_To_RGB;

         when Gray_To_BGRA =>
            return Internal.C_API.Gray_To_BGRA;

         when Gray_To_RGBA =>
            return Internal.C_API.Gray_To_RGBA;

         when BGR_To_RGB   =>
            return Internal.C_API.BGR_To_RGB;

         when RGB_To_BGR   =>
            return Internal.C_API.RGB_To_BGR;

         when BGR_To_BGRA  =>
            return Internal.C_API.BGR_To_BGRA;

         when RGB_To_RGBA  =>
            return Internal.C_API.RGB_To_RGBA;

         when BGR_To_RGBA  =>
            return Internal.C_API.BGR_To_RGBA;

         when RGB_To_BGRA  =>
            return Internal.C_API.RGB_To_BGRA;

         when BGRA_To_BGR  =>
            return Internal.C_API.BGRA_To_BGR;

         when RGBA_To_RGB  =>
            return Internal.C_API.RGBA_To_RGB;

         when RGBA_To_BGR  =>
            return Internal.C_API.RGBA_To_BGR;

         when BGRA_To_RGB  =>
            return Internal.C_API.BGRA_To_RGB;

         when BGRA_To_RGBA =>
            return Internal.C_API.BGRA_To_RGBA;

         when RGBA_To_BGRA =>
            return Internal.C_API.RGBA_To_BGRA;

         when BGR_To_XYZ   =>
            return Internal.C_API.BGR_To_XYZ;

         when RGB_To_XYZ   =>
            return Internal.C_API.RGB_To_XYZ;

         when XYZ_To_BGR   =>
            return Internal.C_API.XYZ_To_BGR;

         when XYZ_To_RGB   =>
            return Internal.C_API.XYZ_To_RGB;

         when BGR_To_YCrCb =>
            return Internal.C_API.BGR_To_YCrCb;

         when RGB_To_YCrCb =>
            return Internal.C_API.RGB_To_YCrCb;

         when YCrCb_To_BGR =>
            return Internal.C_API.YCrCb_To_BGR;

         when YCrCb_To_RGB =>
            return Internal.C_API.YCrCb_To_RGB;

         when BGR_To_YUV   =>
            return Internal.C_API.BGR_To_YUV;

         when RGB_To_YUV   =>
            return Internal.C_API.RGB_To_YUV;

         when YUV_To_BGR   =>
            return Internal.C_API.YUV_To_BGR;

         when YUV_To_RGB   =>
            return Internal.C_API.YUV_To_RGB;

         when BGR_To_HSV   =>
            return Internal.C_API.BGR_To_HSV;

         when RGB_To_HSV   =>
            return Internal.C_API.RGB_To_HSV;

         when HSV_To_BGR   =>
            return Internal.C_API.HSV_To_BGR;

         when HSV_To_RGB   =>
            return Internal.C_API.HSV_To_RGB;

         when BGR_To_HLS   =>
            return Internal.C_API.BGR_To_HLS;

         when RGB_To_HLS   =>
            return Internal.C_API.RGB_To_HLS;

         when HLS_To_BGR   =>
            return Internal.C_API.HLS_To_BGR;

         when HLS_To_RGB   =>
            return Internal.C_API.HLS_To_RGB;

         when BGR_To_Lab   =>
            return Internal.C_API.BGR_To_Lab;

         when RGB_To_Lab   =>
            return Internal.C_API.RGB_To_Lab;

         when Lab_To_BGR   =>
            return Internal.C_API.Lab_To_BGR;

         when Lab_To_RGB   =>
            return Internal.C_API.Lab_To_RGB;

         when BGR_To_Luv   =>
            return Internal.C_API.BGR_To_Luv;

         when RGB_To_Luv   =>
            return Internal.C_API.RGB_To_Luv;

         when Luv_To_BGR   =>
            return Internal.C_API.Luv_To_BGR;

         when Luv_To_RGB   =>
            return Internal.C_API.Luv_To_RGB;
      end case;
   end To_C_Conversion;

   function To_C_Interpolation
     (Interpolation : Interpolation_Method) return Interfaces.Integer_32 is
   begin
      case Interpolation is
         when Nearest_Neighbor =>
            return Internal.C_API.Interpolation_Nearest_Neighbor;

         when Linear           =>
            return Internal.C_API.Interpolation_Linear;

         when Cubic            =>
            return Internal.C_API.Interpolation_Cubic;

         when Area             =>
            return Internal.C_API.Interpolation_Area;

         when Lanczos_4        =>
            return Internal.C_API.Interpolation_Lanczos_4;
      end case;
   end To_C_Interpolation;

   function To_C_Border
     (Border : OpenCV.Border_Kind) return Interfaces.Integer_32 is
   begin
      case Border is
         when OpenCV.Constant_Border =>
            return Internal.C_API.Border_Constant;

         when OpenCV.Replicate       =>
            return Internal.C_API.Border_Replicate;

         when OpenCV.Reflect         =>
            return Internal.C_API.Border_Reflect;

         when OpenCV.Reflect_101     =>
            return Internal.C_API.Border_Reflect_101;

         when OpenCV.Wrap            =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Gaussian_Blur does not support Wrap border");
      end case;
   end To_C_Border;

   function To_C_Pyramid_Down_Border
     (Border : OpenCV.Border_Kind) return Interfaces.Integer_32 is
   begin
      case Border is
         when OpenCV.Replicate       =>
            return Internal.C_API.Border_Replicate;

         when OpenCV.Reflect         =>
            return Internal.C_API.Border_Reflect;

         when OpenCV.Reflect_101     =>
            return Internal.C_API.Border_Reflect_101;

         when OpenCV.Wrap            =>
            return Internal.C_API.Border_Wrap;

         when OpenCV.Constant_Border =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Pyramid_Down does not support Constant_Border");
      end case;
   end To_C_Pyramid_Down_Border;

   function To_C_Template_Matching_Method
     (Method : Template_Matching_Method) return Interfaces.Integer_32 is
   begin
      case Method is
         when Squared_Difference                 =>
            return Internal.C_API.Template_Squared_Difference;

         when Normalized_Squared_Difference      =>
            return Internal.C_API.Template_Normalized_Squared_Difference;

         when Cross_Correlation                  =>
            return Internal.C_API.Template_Cross_Correlation;

         when Normalized_Cross_Correlation       =>
            return Internal.C_API.Template_Normalized_Cross_Correlation;

         when Correlation_Coefficient            =>
            return Internal.C_API.Template_Correlation_Coefficient;

         when Normalized_Correlation_Coefficient =>
            return Internal.C_API.Template_Normalized_Correlation_Coefficient;
      end case;
   end To_C_Template_Matching_Method;

   function To_C_Warp_Interpolation
     (Interpolation : Interpolation_Method) return Interfaces.Integer_32 is
   begin
      case Interpolation is
         when Nearest_Neighbor         =>
            return Internal.C_API.Warp_Interpolation_Nearest;

         when Linear                   =>
            return Internal.C_API.Warp_Interpolation_Linear;

         when Cubic | Area | Lanczos_4 =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Warp_Affine supports only Nearest_Neighbor and Linear"
               & " interpolation");
      end case;
   end To_C_Warp_Interpolation;

   function To_C_Warp_Mapping
     (Mapping : Warp_Mapping_Direction) return Interfaces.Integer_32 is
   begin
      case Mapping is
         when Source_To_Destination =>
            return Internal.C_API.Warp_Mapping_Source_To_Destination;

         when Destination_To_Source =>
            return Internal.C_API.Warp_Mapping_Destination_To_Source;
      end case;
   end To_C_Warp_Mapping;

   function To_C_Warp_Border
     (Border : OpenCV.Border_Kind) return Interfaces.Integer_32 is
   begin
      case Border is
         when OpenCV.Constant_Border                            =>
            return Internal.C_API.Border_Constant;

         when OpenCV.Replicate                                  =>
            return Internal.C_API.Border_Replicate;

         when OpenCV.Reflect | OpenCV.Reflect_101 | OpenCV.Wrap =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Warp_Affine supports only Constant_Border and Replicate");
      end case;
   end To_C_Warp_Border;

   function To_C_Remap_Interpolation
     (Interpolation : Interpolation_Method) return Interfaces.Integer_32 is
   begin
      case Interpolation is
         when Nearest_Neighbor =>
            return Internal.C_API.Interpolation_Nearest_Neighbor;

         when Linear           =>
            return Internal.C_API.Interpolation_Linear;

         when Cubic            =>
            return Internal.C_API.Interpolation_Cubic;

         when Lanczos_4        =>
            return Internal.C_API.Interpolation_Lanczos_4;

         when Area             =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Remap does not support Area interpolation");
      end case;
   end To_C_Remap_Interpolation;

   function To_C_Remap_Border
     (Border : OpenCV.Border_Kind) return Interfaces.Integer_32 is
   begin
      case Border is
         when OpenCV.Constant_Border =>
            return Internal.C_API.Border_Constant;

         when OpenCV.Replicate       =>
            return Internal.C_API.Border_Replicate;

         when OpenCV.Reflect         =>
            return Internal.C_API.Border_Reflect;

         when OpenCV.Reflect_101     =>
            return Internal.C_API.Border_Reflect_101;

         when OpenCV.Wrap            =>
            return Internal.C_API.Border_Wrap;
      end case;
   end To_C_Remap_Border;

   function To_C_Canny_Aperture
     (Aperture : Canny_Aperture) return Interfaces.Integer_32 is
   begin
      case Aperture is
         when Sobel_3x3 =>
            return Internal.C_API.Canny_Aperture_3;

         when Sobel_5x5 =>
            return Internal.C_API.Canny_Aperture_5;

         when Sobel_7x7 =>
            return Internal.C_API.Canny_Aperture_7;
      end case;
   end To_C_Canny_Aperture;

   function To_C_Canny_Gradient_Norm
     (Gradient_Norm : Canny_Gradient_Norm) return Interfaces.Integer_32 is
   begin
      case Gradient_Norm is
         when L1_Norm =>
            return Internal.C_API.Canny_Gradient_L1;

         when L2_Norm =>
            return Internal.C_API.Canny_Gradient_L2;
      end case;
   end To_C_Canny_Gradient_Norm;

   function To_C_Derivative_Depth
     (Depth : Derivative_Depth) return Interfaces.Integer_32 is
   begin
      case Depth is
         when Same_Depth    =>
            return Internal.C_API.Derivative_Same_Depth;

         when Int16_Depth   =>
            return Internal.C_API.Derivative_Int16;

         when Float32_Depth =>
            return Internal.C_API.Derivative_Float32;

         when Float64_Depth =>
            return Internal.C_API.Derivative_Float64;
      end case;
   end To_C_Derivative_Depth;

   function To_C_Sobel_Kernel
     (Kernel : Sobel_Kernel_Size) return Interfaces.Integer_32 is
   begin
      case Kernel is
         when Kernel_1 =>
            return Internal.C_API.Sobel_Kernel_1;

         when Kernel_3 =>
            return Internal.C_API.Sobel_Kernel_3;

         when Kernel_5 =>
            return Internal.C_API.Sobel_Kernel_5;

         when Kernel_7 =>
            return Internal.C_API.Sobel_Kernel_7;
      end case;
   end To_C_Sobel_Kernel;

   function To_C_Derivative_Axis
     (Axis : Derivative_Axis) return Interfaces.Integer_32 is
   begin
      case Axis is
         when X_Axis =>
            return Internal.C_API.Derivative_X;

         when Y_Axis =>
            return Internal.C_API.Derivative_Y;
      end case;
   end To_C_Derivative_Axis;

   function To_C_Gaussian_Kernel_Depth
     (Depth : Gaussian_Kernel_Depth) return Interfaces.Integer_32 is
   begin
      case Depth is
         when Float32_Kernel =>
            return Internal.C_API.Gaussian_Kernel_Float32;

         when Float64_Kernel =>
            return Internal.C_API.Gaussian_Kernel_Float64;
      end case;
   end To_C_Gaussian_Kernel_Depth;

   function To_C_Derivative_Kernel_Normalization
     (Normalization : Derivative_Kernel_Normalization)
      return Interfaces.Integer_32 is
   begin
      case Normalization is
         when Unnormalized =>
            return Internal.C_API.Derivative_Kernels_Unnormalized;

         when Normalized   =>
            return Internal.C_API.Derivative_Kernels_Normalized;
      end case;
   end To_C_Derivative_Kernel_Normalization;

   function Effective_Sobel_Kernel_Length
     (Order : Derivative_Order; Kernel_Size : Sobel_Kernel_Size)
      return Positive is
   begin
      case Kernel_Size is
         when Kernel_1 =>
            if Order > 0 then
               return 3;
            else
               return 1;
            end if;

         when Kernel_3 =>
            return 3;

         when Kernel_5 =>
            return 5;

         when Kernel_7 =>
            return 7;
      end case;
   end Effective_Sobel_Kernel_Length;

   function To_C_Threshold_Mode
     (Mode : Threshold_Mode) return Interfaces.Integer_32 is
   begin
      case Mode is
         when Binary          =>
            return Internal.C_API.Threshold_Binary;

         when Binary_Inverse  =>
            return Internal.C_API.Threshold_Binary_Inverse;

         when Truncate        =>
            return Internal.C_API.Threshold_Truncate;

         when To_Zero         =>
            return Internal.C_API.Threshold_To_Zero;

         when To_Zero_Inverse =>
            return Internal.C_API.Threshold_To_Zero_Inverse;
      end case;
   end To_C_Threshold_Mode;

   function To_C_Automatic_Threshold_Method
     (Method : Automatic_Threshold_Method) return Interfaces.Integer_32 is
   begin
      case Method is
         when Otsu     =>
            return Internal.C_API.Automatic_Threshold_Otsu;

         when Triangle =>
            return Internal.C_API.Automatic_Threshold_Triangle;
      end case;
   end To_C_Automatic_Threshold_Method;

   function To_C_Adaptive_Threshold_Method
     (Method : Adaptive_Threshold_Method) return Interfaces.Integer_32 is
   begin
      case Method is
         when Mean     =>
            return Internal.C_API.Adaptive_Threshold_Mean;

         when Gaussian =>
            return Internal.C_API.Adaptive_Threshold_Gaussian;
      end case;
   end To_C_Adaptive_Threshold_Method;

   function To_C_Adaptive_Threshold_Mode
     (Mode : Adaptive_Threshold_Mode) return Interfaces.Integer_32 is
   begin
      case Mode is
         when Binary         =>
            return Internal.C_API.Threshold_Binary;

         when Binary_Inverse =>
            return Internal.C_API.Threshold_Binary_Inverse;
      end case;
   end To_C_Adaptive_Threshold_Mode;

   function To_C_Morphology_Shape
     (Shape : Morphology_Shape) return Interfaces.Integer_32 is
   begin
      case Shape is
         when Rectangle =>
            return Internal.C_API.Morphology_Rectangle;

         when Cross     =>
            return Internal.C_API.Morphology_Cross;

         when Ellipse   =>
            return Internal.C_API.Morphology_Ellipse;
      end case;
   end To_C_Morphology_Shape;

   function Required_Color_Channels
     (Conversion : Color_Conversion) return Positive is
   begin
      case Conversion is
         when Gray_To_BGR | Gray_To_RGB | Gray_To_BGRA | Gray_To_RGBA =>
            return 1;

         when BGRA_To_Gray
            | RGBA_To_Gray
            | BGRA_To_BGR
            | RGBA_To_RGB
            | RGBA_To_BGR
            | BGRA_To_RGB
            | BGRA_To_RGBA
            | RGBA_To_BGRA                                            =>
            return 4;

         when others                                                  =>
            return 3;
      end case;
   end Required_Color_Channels;

   function Nonlinear_Color (Conversion : Color_Conversion) return Boolean is
   begin
      case Conversion is
         when BGR_To_HSV
            | RGB_To_HSV
            | HSV_To_BGR
            | HSV_To_RGB
            | BGR_To_HLS
            | RGB_To_HLS
            | HLS_To_BGR
            | HLS_To_RGB
            | BGR_To_Lab
            | RGB_To_Lab
            | Lab_To_BGR
            | Lab_To_RGB
            | BGR_To_Luv
            | RGB_To_Luv
            | Luv_To_BGR
            | Luv_To_RGB =>
            return True;

         when others     =>
            return False;
      end case;
   end Nonlinear_Color;

   procedure Validate_Conversion
     (Source : OpenCV.Core.Mat; Conversion : Color_Conversion)
   is
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty
        or else Source.Dimension_Count /= 2
        or else Natural (Source.Channels)
                /= Required_Color_Channels (Conversion)
        or else Source.Depth
                not in OpenCV.Core.UInt8
                     | OpenCV.Core.UInt16
                     | OpenCV.Core.Float32
        or else (Nonlinear_Color (Conversion)
                 and then Source.Depth = OpenCV.Core.UInt16)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Color conversion requires a nonempty 2-D source with matching"
            & " channels and a supported depth");
      end if;
   end Validate_Conversion;

   procedure Validate_Resize
     (Source : OpenCV.Core.Mat; Output_Size : OpenCV.Size) is
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Resize requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Resize requires a two-dimensional source Mat");
      end if;

      if Output_Size.Width = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Resize requires a nonzero output width");
      end if;

      if Output_Size.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Resize requires a nonzero output height");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Resize requires a UInt8, UInt16, Int16, Float32, or Float64"
               & " source Mat");
      end case;
   end Validate_Resize;

   procedure Validate_Gaussian_Blur
     (Source      : OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Size;
      Sigma       : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind)
   is
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur requires a two-dimensional source Mat");
      end if;

      if Kernel_Size.Width = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur requires a positive kernel width");
      end if;

      if Kernel_Size.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur requires a positive kernel height");
      end if;

      if Kernel_Size.Width mod 2 = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur requires an odd kernel width");
      end if;

      if Kernel_Size.Height mod 2 = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur requires an odd kernel height");
      end if;

      if Sigma <= 0.0
        or else Sigma /= Sigma
        or else Sigma > OpenCV.Float64_Value'Last
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur requires a positive finite sigma");
      end if;

      if Border = OpenCV.Wrap then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur does not support Wrap border");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Gaussian_Blur requires a UInt8, UInt16, Int16, Float32, or"
               & " Float64 source Mat");
      end case;
   end Validate_Gaussian_Blur;

   procedure Validate_Get_Gaussian_Kernel
     (Kernel_Size : Gaussian_Kernel_Size;
      Sigma       : OpenCV.Float64_Value;
      Automatic   : Boolean)
   is
      use type OpenCV.Float64_Value;
   begin
      if Kernel_Size mod 2 = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Gaussian_Kernel requires an odd kernel size");
      end if;

      if Automatic then
         return;
      end if;

      if Sigma <= 0.0
        or else Sigma /= Sigma
        or else Sigma > OpenCV.Float64_Value'Last
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Gaussian_Kernel requires a positive finite sigma");
      end if;
   end Validate_Get_Gaussian_Kernel;

   procedure Validate_Derivative_Kernel_Orders
     (X_Order     : Derivative_Order;
      Y_Order     : Derivative_Order;
      Kernel_Size : Sobel_Kernel_Size) is
   begin
      if X_Order = 0 and then Y_Order = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Derivative_Kernels requires a nonzero derivative order");
      end if;

      if X_Order >= Effective_Sobel_Kernel_Length (X_Order, Kernel_Size) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Derivative_Kernels X_Order exceeds the effective kernel");
      end if;

      if Y_Order >= Effective_Sobel_Kernel_Length (Y_Order, Kernel_Size) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Derivative_Kernels Y_Order exceeds the effective kernel");
      end if;
   end Validate_Derivative_Kernel_Orders;

   procedure Validate_Pyramid_Source
     (Source : OpenCV.Core.Mat; Operation : String) is
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a two-dimensional source Mat");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               Operation
               & " requires a UInt8, UInt16, Int16, Float32, or"
               & " Float64 source Mat");
      end case;
   end Validate_Pyramid_Source;

   procedure Validate_Pyramid_Down
     (Source : OpenCV.Core.Mat; Border : OpenCV.Border_Kind) is
   begin
      Validate_Pyramid_Source (Source, "Pyramid_Down");

      if Border = OpenCV.Constant_Border then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Pyramid_Down does not support Constant_Border");
      end if;
   end Validate_Pyramid_Down;

   procedure Validate_Match_Template
     (Source : OpenCV.Core.Mat; Template : OpenCV.Core.Mat)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Template requires a non-empty Source");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Template requires a two-dimensional Source");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8 | OpenCV.Core.Float32 =>
            null;

         when others                                  =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Match_Template supports only UInt8 and Float32 inputs");
      end case;

      if Source.Channels > 4 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Template supports only 1 to 4 channels");
      end if;

      if Template.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Template requires a non-empty Template");
      end if;

      if Template.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Template requires a two-dimensional Template");
      end if;

      case Template.Depth is
         when OpenCV.Core.UInt8 | OpenCV.Core.Float32 =>
            null;

         when others                                  =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Match_Template supports only UInt8 and Float32 inputs");
      end case;

      if Template.Channels > 4 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Template supports only 1 to 4 channels");
      end if;

      if Source.Depth /= Template.Depth
        or else Source.Channels /= Template.Channels
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Template Source and Template types must match");
      end if;

      if Template.Rows > Source.Rows or else Template.Columns > Source.Columns
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Template Template must not be larger than Source");
      end if;
   end Validate_Match_Template;

   procedure Validate_Warp_Affine
     (Source        : OpenCV.Core.Mat;
      Transform     : OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method;
      Border        : OpenCV.Border_Kind)
   is
      use type OpenCV.Core.Channel_Count;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Affine requires a non-empty Source");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Affine requires a two-dimensional Source");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Warp_Affine requires a UInt8, UInt16, Int16, Float32, or"
               & " Float64 source Mat");
      end case;

      if Source.Channels > 4 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Affine supports only 1 to 4 channels");
      end if;

      if Transform.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Affine requires a non-empty Transform");
      end if;

      if Transform.Dimension_Count /= 2
        or else Transform.Rows /= 2
        or else Transform.Columns /= 3
        or else Transform.Channels /= 1
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Affine requires a 2x3 single-channel Transform");
      end if;

      case Transform.Depth is
         when OpenCV.Core.Float32 | OpenCV.Core.Float64 =>
            null;

         when others                                    =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Warp_Affine Transform must use Float32 or Float64");
      end case;

      if Output_Size.Width = 0 or else Output_Size.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Affine requires a nonzero Output_Size");
      end if;

      case Interpolation is
         when Nearest_Neighbor | Linear =>
            null;

         when Cubic | Area | Lanczos_4  =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Warp_Affine supports only Nearest_Neighbor and Linear"
               & " interpolation");
      end case;

      if Border /= OpenCV.Constant_Border and then Border /= OpenCV.Replicate
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Affine supports only Constant_Border and Replicate");
      end if;
   end Validate_Warp_Affine;

   procedure Validate_Warp_Perspective
     (Source        : OpenCV.Core.Mat;
      Transform     : OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method;
      Border        : OpenCV.Border_Kind)
   is
      use type OpenCV.Core.Channel_Count;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Perspective requires a non-empty Source");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Perspective requires a two-dimensional Source");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Warp_Perspective requires a UInt8, UInt16, Int16, Float32, or"
               & " Float64 source Mat");
      end case;

      if Source.Channels > 4 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Perspective supports only 1 to 4 channels");
      end if;

      if Transform.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Perspective requires a non-empty Transform");
      end if;

      if Transform.Dimension_Count /= 2
        or else Transform.Rows /= 3
        or else Transform.Columns /= 3
        or else Transform.Channels /= 1
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Perspective requires a 3x3 single-channel Transform");
      end if;

      case Transform.Depth is
         when OpenCV.Core.Float32 | OpenCV.Core.Float64 =>
            null;

         when others                                    =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Warp_Perspective Transform must use Float32 or Float64");
      end case;

      if Output_Size.Width = 0 or else Output_Size.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Perspective requires a nonzero Output_Size");
      end if;

      case Interpolation is
         when Nearest_Neighbor | Linear =>
            null;

         when Cubic | Area | Lanczos_4  =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Warp_Perspective supports only Nearest_Neighbor and Linear"
               & " interpolation");
      end case;

      if Border /= OpenCV.Constant_Border and then Border /= OpenCV.Replicate
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Warp_Perspective supports only Constant_Border and Replicate");
      end if;
   end Validate_Warp_Perspective;

   procedure Validate_Remap_Source
     (Source : OpenCV.Core.Mat; Interpolation : Interpolation_Method)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      Remap_Limit : constant Natural := 32_767;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Remap requires a non-empty Source");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap requires a two-dimensional Source");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Remap requires a UInt8, UInt16, Int16, Float32, or"
               & " Float64 source Mat");
      end case;

      if Source.Channels > 4 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap supports only 1 to 4 channels");
      end if;

      if Source.Rows >= Remap_Limit or else Source.Columns >= Remap_Limit then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap requires Source Rows and Columns less than 32767");
      end if;

      case Interpolation is
         when Nearest_Neighbor | Linear | Cubic | Lanczos_4 =>
            null;

         when Area                                          =>
            raise OpenCV.OpenCV_Error
              with "Remap does not support Area interpolation";
      end case;
   end Validate_Remap_Source;

   procedure Validate_Remap
     (Source        : OpenCV.Core.Mat;
      Map_X         : OpenCV.Core.Mat;
      Map_Y         : OpenCV.Core.Mat;
      Interpolation : Interpolation_Method)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      Remap_Limit : constant Natural := 32_767;
   begin
      Validate_Remap_Source (Source, Interpolation);
      if Map_X.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Remap requires a non-empty Map_X");
      end if;

      if Map_Y.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Remap requires a non-empty Map_Y");
      end if;

      if Map_X.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap requires a two-dimensional Map_X");
      end if;

      if Map_Y.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap requires a two-dimensional Map_Y");
      end if;

      if Map_X.Depth /= OpenCV.Core.Float32 or else Map_X.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap requires a single-channel Float32 Map_X");
      end if;

      if Map_Y.Depth /= OpenCV.Core.Float32 or else Map_Y.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap requires a single-channel Float32 Map_Y");
      end if;

      if Map_X.Rows /= Map_Y.Rows or else Map_X.Columns /= Map_Y.Columns then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap requires Map_X and Map_Y to have identical geometry");
      end if;

      if Map_X.Rows >= Remap_Limit or else Map_X.Columns >= Remap_Limit then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Remap requires map Rows and Columns less than 32767");
      end if;

   end Validate_Remap;

   procedure Validate_Float_Remap_Map
     (Map : OpenCV.Core.Mat; Channels : OpenCV.Core.Channel_Count)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Map.Is_Empty
        or else Map.Dimension_Count /= 2
        or else Map.Depth /= OpenCV.Core.Float32
        or else Map.Channels /= Channels
        or else Map.Rows >= 32_767
        or else Map.Columns >= 32_767
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Invalid Float32 Remap map");
      end if;
   end Validate_Float_Remap_Map;

   procedure Validate_Fixed_Remap_Maps (Maps : Fixed_Remap_Maps) is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Maps.Coordinates.Is_Empty
        or else Maps.Coordinates.Dimension_Count /= 2
        or else Maps.Coordinates.Depth /= OpenCV.Core.Int16
        or else Maps.Coordinates.Channels /= 2
        or else Maps.Coordinates.Rows >= 32_767
        or else Maps.Coordinates.Columns >= 32_767
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Invalid fixed Remap coordinates");
      end if;
      if not Maps.Coefficients.Is_Empty
        and then (Maps.Coefficients.Dimension_Count /= 2
                  or else Maps.Coefficients.Depth /= OpenCV.Core.UInt16
                  or else Maps.Coefficients.Channels /= 1
                  or else Maps.Coefficients.Rows /= Maps.Coordinates.Rows
                  or else Maps.Coefficients.Columns
                          /= Maps.Coordinates.Columns)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Invalid fixed Remap coefficients");
      end if;
   end Validate_Fixed_Remap_Maps;

   procedure Validate_Median_Blur
     (Source : OpenCV.Core.Mat; Kernel_Size : Median_Kernel_Size)
   is
      use type OpenCV.Core.Channel_Count;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Median_Blur requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Median_Blur requires a two-dimensional source Mat");
      end if;

      if Source.Channels /= 1
        and then Source.Channels /= 3
        and then Source.Channels /= 4
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Median_Blur requires a source Mat with 1, 3, or 4 channels");
      end if;

      if Kernel_Size mod 2 = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Median_Blur requires an odd kernel size");
      end if;

      if Kernel_Size = 3 or else Kernel_Size = 5 then
         case Source.Depth is
            when OpenCV.Core.UInt8 | OpenCV.Core.UInt16 | OpenCV.Core.Float32
            =>
               null;

            when others
            =>
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Median_Blur kernel sizes 3 and 5 require a UInt8,"
                  & " UInt16, or Float32 source Mat");
         end case;
      else
         case Source.Depth is
            when OpenCV.Core.UInt8 =>
               null;

            when others            =>
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Median_Blur kernel sizes greater than 5 require a"
                  & " UInt8 source Mat");
         end case;
      end if;
   end Validate_Median_Blur;

   procedure Validate_Box_Blur
     (Source      : OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Size;
      Border      : OpenCV.Border_Kind) is
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Box_Blur requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Box_Blur requires a two-dimensional source Mat");
      end if;

      if Kernel_Size.Width = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Box_Blur requires a positive kernel width");
      end if;

      if Kernel_Size.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Box_Blur requires a positive kernel height");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Box_Blur requires a UInt8, UInt16, Int16, Float32, or"
               & " Float64 source Mat");
      end case;

      if Border = OpenCV.Wrap then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Box_Blur does not support Wrap border");
      end if;
   end Validate_Box_Blur;

   procedure Validate_Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Sigma_Color : OpenCV.Float64_Value;
      Sigma_Space : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Bilateral_Filter requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Bilateral_Filter requires a two-dimensional source Mat");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8 | OpenCV.Core.Float32 =>
            null;

         when others                                  =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Bilateral_Filter requires a UInt8 or Float32 source Mat");
      end case;

      if Source.Channels /= 1 and then Source.Channels /= 3 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Bilateral_Filter requires a source Mat with 1 or 3 channels");
      end if;

      if Sigma_Color <= 0.0
        or else Sigma_Color /= Sigma_Color
        or else Sigma_Color > OpenCV.Float64_Value'Last
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Bilateral_Filter requires a positive finite Sigma_Color");
      end if;

      if Sigma_Space <= 0.0
        or else Sigma_Space /= Sigma_Space
        or else Sigma_Space > OpenCV.Float64_Value'Last
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Bilateral_Filter requires a positive finite Sigma_Space");
      end if;

      if Border = OpenCV.Wrap then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Bilateral_Filter does not support Wrap border");
      end if;
   end Validate_Bilateral_Filter;

   procedure Validate_Filter_2D
     (Source            : OpenCV.Core.Mat;
      Kernel            : OpenCV.Core.Mat;
      Destination_Depth : Filter_Depth;
      Offset            : OpenCV.Float64_Value;
      Border            : OpenCV.Border_Kind)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Filter_2D requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Filter_2D requires a two-dimensional source Mat");
      end if;

      if Kernel.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Filter_2D requires a non-empty kernel Mat");
      end if;

      if Kernel.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Filter_2D requires a two-dimensional kernel Mat");
      end if;

      if Kernel.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Filter_2D requires a single-channel Float32 or Float64 kernel");
      end if;

      case Kernel.Depth is
         when OpenCV.Core.Float32 | OpenCV.Core.Float64 =>
            null;

         when others                                    =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Filter_2D requires a single-channel Float32 or"
               & " Float64 kernel");
      end case;

      if Offset /= Offset
        or else Offset > OpenCV.Float64_Value'Last
        or else Offset < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Filter_2D requires a finite Offset");
      end if;

      if Border = OpenCV.Wrap then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Filter_2D does not support Wrap border");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8                      =>
            null;

         when OpenCV.Core.UInt16 | OpenCV.Core.Int16 =>
            if Destination_Depth = Int16_Depth then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Filter_2D does not support Int16 destination depth for "
                  & "UInt16 or Int16 source Mats");
            end if;

         when OpenCV.Core.Float32                    =>
            if Destination_Depth = Int16_Depth
              or else Destination_Depth = Float64_Depth
            then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Filter_2D supports only Same_Depth or Float32_Depth for "
                  & "Float32 source Mats");
            end if;

         when OpenCV.Core.Float64                    =>
            if Destination_Depth = Int16_Depth
              or else Destination_Depth = Float32_Depth
            then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Filter_2D supports only Same_Depth or Float64_Depth for "
                  & "Float64 source Mats");
            end if;

         when others                                 =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Filter_2D requires a UInt8, UInt16, Int16, Float32, or "
               & "Float64 source Mat");
      end case;
   end Validate_Filter_2D;

   procedure Validate_Filter_2D_Anchor
     (Kernel : OpenCV.Core.Mat; Anchor : OpenCV.Point) is
   begin
      if Anchor.X < 0
        or else Anchor.Y < 0
        or else Integer (Anchor.X) >= Kernel.Columns
        or else Integer (Anchor.Y) >= Kernel.Rows
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Filter_2D anchor lies outside the kernel");
      end if;
   end Validate_Filter_2D_Anchor;

   procedure Validate_Separable_Kernel
     (Kernel : OpenCV.Core.Mat; Name : String)
   is
      use type OpenCV.Core.Channel_Count;
   begin
      if Kernel.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D requires a non-empty " & Name);
      end if;

      if Kernel.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D requires a two-dimensional " & Name);
      end if;

      if Kernel.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D "
            & Name
            & " must be a one-dimensional Float32 or Float64 kernel");
      end if;

      case Kernel.Depth is
         when OpenCV.Core.Float32 | OpenCV.Core.Float64 =>
            null;

         when others                                    =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Sep_Filter_2D "
               & Name
               & " must be a one-dimensional Float32 or Float64 kernel");
      end case;

      if Kernel.Rows /= 1 and then Kernel.Columns /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D "
            & Name
            & " must be a one-dimensional Float32 or Float64 kernel");
      end if;
   end Validate_Separable_Kernel;

   function Separable_Kernel_Length (Kernel : OpenCV.Core.Mat) return Natural
   is
   begin
      if Kernel.Rows = 1 then
         return Kernel.Columns;
      else
         return Kernel.Rows;
      end if;
   end Separable_Kernel_Length;

   procedure Validate_Sep_Filter_2D
     (Source            : OpenCV.Core.Mat;
      Kernel_X          : OpenCV.Core.Mat;
      Kernel_Y          : OpenCV.Core.Mat;
      Destination_Depth : Filter_Depth;
      Offset            : OpenCV.Float64_Value;
      Border            : OpenCV.Border_Kind)
   is
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D requires a two-dimensional source Mat");
      end if;

      Validate_Separable_Kernel (Kernel_X, "Kernel_X");
      Validate_Separable_Kernel (Kernel_Y, "Kernel_Y");

      if Kernel_X.Depth /= Kernel_Y.Depth then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D requires Kernel_X and Kernel_Y to share one"
            & " floating-point depth");
      end if;

      if Offset /= Offset
        or else Offset > OpenCV.Float64_Value'Last
        or else Offset < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D requires a finite Offset");
      end if;

      if Border = OpenCV.Wrap then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D does not support Wrap border");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8                      =>
            null;

         when OpenCV.Core.UInt16 | OpenCV.Core.Int16 =>
            if Destination_Depth = Int16_Depth then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Sep_Filter_2D does not support Int16 destination depth"
                  & " for UInt16 or Int16 source Mats");
            end if;

         when OpenCV.Core.Float32                    =>
            if Destination_Depth = Int16_Depth
              or else Destination_Depth = Float64_Depth
            then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Sep_Filter_2D supports only Same_Depth or Float32_Depth"
                  & " for Float32 source Mats");
            end if;

         when OpenCV.Core.Float64                    =>
            if Destination_Depth = Int16_Depth
              or else Destination_Depth = Float32_Depth
            then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Sep_Filter_2D supports only Same_Depth or Float64_Depth"
                  & " for Float64 source Mats");
            end if;

         when others                                 =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Sep_Filter_2D requires a UInt8, UInt16, Int16, Float32, or"
               & " Float64 source Mat");
      end case;
   end Validate_Sep_Filter_2D;

   procedure Validate_Sep_Filter_2D_Anchor
     (Kernel_X : OpenCV.Core.Mat;
      Kernel_Y : OpenCV.Core.Mat;
      Anchor   : OpenCV.Point) is
   begin
      if Anchor.X < 0
        or else Integer (Anchor.X) >= Separable_Kernel_Length (Kernel_X)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D Anchor.X lies outside Kernel_X");
      end if;

      if Anchor.Y < 0
        or else Integer (Anchor.Y) >= Separable_Kernel_Length (Kernel_Y)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sep_Filter_2D Anchor.Y lies outside Kernel_Y");
      end if;
   end Validate_Sep_Filter_2D_Anchor;

   function Storage_Overlaps
     (First, Second : OpenCV.Core.Mat; Operation : String) return Boolean;

   function Explicit_Morphology_Border
     (Value : OpenCV.Scalar) return Morphology_Border_Value
   is
      Max : constant Long_Float := Long_Float (OpenCV.Float64_Value'Last);
   begin
      if Value.Component_0 = Max
        and then Value.Component_1 = Max
        and then Value.Component_2 = Max
        and then Value.Component_3 = Max
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Reserved morphology border sentinel");
      end if;
      return (Use_Default => False, Value => Value);
   end Explicit_Morphology_Border;

   procedure Morphology_Execute
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Operation       : Interfaces.Integer_32;
      Kernel_Size     : OpenCV.Size;
      Shape           : Morphology_Shape;
      Kernel          : OpenCV.Core.Mat;
      Custom          : Boolean;
      Anchor          : OpenCV.Point;
      Explicit_Anchor : Boolean;
      Iterations      : Morphology_Iterations;
      Border          : OpenCV.Border_Kind;
      Border_Value    : Morphology_Border_Value)
   is
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Mat_Size;
      use type OpenCV.Float64_Value;
      Width  : constant Long_Long_Integer :=
        (if Custom
         then Long_Long_Integer (Kernel.Columns)
         else Long_Long_Integer (Kernel_Size.Width));
      Height : constant Long_Long_Integer :=
        (if Custom
         then Long_Long_Integer (Kernel.Rows)
         else Long_Long_Integer (Kernel_Size.Height));
      Limit  : constant Long_Long_Integer := 2_147_483_647;
      Status : Internal.C_API.Status;
      Scalar : aliased constant Internal.C_API.Morphology_Scalar :=
        (Interfaces.C.double (Border_Value.Value.Component_0),
         Interfaces.C.double (Border_Value.Value.Component_1),
         Interfaces.C.double (Border_Value.Value.Component_2),
         Interfaces.C.double (Border_Value.Value.Component_3));

      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure Call
              (Kernel_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Morphology_Request
                   (Source_Handle,
                    Destination_Handle,
                    Operation,
                    (if Custom then 1 else 0),
                    Kernel_Handle,
                    Interfaces.Integer_32 (Width),
                    Interfaces.Integer_32 (Height),
                    To_C_Morphology_Shape (Shape),
                    (if Explicit_Anchor then 1 else 0),
                    Interfaces.Integer_32 (Anchor.X),
                    Interfaces.Integer_32 (Anchor.Y),
                    Interfaces.Integer_32 (Iterations),
                    To_C_Border (Border),
                    (if Border_Value.Use_Default then 0 else 1),
                    Scalar'Access);
            end Call;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle (Kernel, Call'Access);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      if Source.Is_Empty
        or else Source.Dimension_Count /= 2
        or else Source.Depth
                not in OpenCV.Core.UInt8
                     | OpenCV.Core.UInt16
                     | OpenCV.Core.Int16
                     | OpenCV.Core.Float32
                     | OpenCV.Core.Float64
        or else Border = OpenCV.Wrap
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Invalid morphology source or border");
      end if;
      if Custom
        and then (Kernel.Is_Empty
                  or else Kernel.Dimension_Count /= 2
                  or else Kernel.Depth /= OpenCV.Core.UInt8
                  or else Kernel.Channels /= 1)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Invalid custom morphology kernel");
      end if;
      if Width <= 0
        or else Height <= 0
        or else Width * Height > Limit
        or else Long_Long_Integer (Source.Columns)
                * Long_Long_Integer (Source.Channels)
                > Limit
        or else Width * Long_Long_Integer (Source.Channels) > Limit
        or else (not Custom
                 and then Shape = Ellipse
                 and then Height / 2 > 46340)
        or else (Explicit_Anchor
                 and then (Anchor.X < 0
                           or else Anchor.Y < 0
                           or else Long_Long_Integer (Anchor.X) >= Width
                           or else Long_Long_Integer (Anchor.Y) >= Height))
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Invalid morphology geometry");
      end if;
      if Custom and then Kernel.Count_Non_Zero = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "All-zero morphology kernel");
      end if;
      --  OpenCV collapses a repeated full mask to an expanded rectangle.
      --  The 1x1 copy/no-op is checked first. Sparse generated masks are
      --  classified from their actual mask by the native preflight.
      if Width * Height > 1
        and then Iterations > 1
        and then ((Custom
                   and then Long_Long_Integer (Kernel.Count_Non_Zero)
                            = Width * Height)
                  or else (not Custom and then Shape = Rectangle))
      then
         declare
            A_X : constant Long_Long_Integer :=
              (if Explicit_Anchor
               then Long_Long_Integer (Anchor.X)
               else Width / 2);
            A_Y : constant Long_Long_Integer :=
              (if Explicit_Anchor
               then Long_Long_Integer (Anchor.Y)
               else Height / 2);
            N   : constant Long_Long_Integer := Long_Long_Integer (Iterations);
         begin
            if Width + (N - 1) * (Width - 1) > Limit
              or else Height + (N - 1) * (Height - 1) > Limit
              or else Width + (N - 1) * (Width - 1)
                      > Limit / Long_Long_Integer (Source.Channels)
              or else A_X * N > Limit
              or else A_Y * N > Limit
            then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Morphology iteration expansion overflows int");
            end if;
         end;
      end if;
      if Custom and then Storage_Overlaps (Kernel, Destination, "Morphology")
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "Kernel overlaps destination");
      end if;
      if Border = OpenCV.Constant_Border and then not Border_Value.Use_Default
      then
         for Index in 0 .. Integer'Min (Integer (Source.Channels), 4) - 1 loop
            declare
               V : constant OpenCV.Float64_Value :=
                 (case Index is
                    when 0      =>
                      OpenCV.Float64_Value (Border_Value.Value.Component_0),
                    when 1      =>
                      OpenCV.Float64_Value (Border_Value.Value.Component_1),
                    when 2      =>
                      OpenCV.Float64_Value (Border_Value.Value.Component_2),
                    when others =>
                      OpenCV.Float64_Value (Border_Value.Value.Component_3));
            begin
               if V /= V
                 or else V > OpenCV.Float64_Value'Last
                 or else V < OpenCV.Float64_Value'First
                 or else (Source.Depth = OpenCV.Core.Float32
                          and then abs V
                                   > OpenCV.Float64_Value
                                       (OpenCV.Float32_Value'Last))
                 or else (Source.Depth
                          in OpenCV.Core.UInt8
                           | OpenCV.Core.UInt16
                           | OpenCV.Core.Int16
                          and then (V < OpenCV.Float64_Value (-2_147_483_648.0)
                                    or else V
                                            > OpenCV.Float64_Value
                                                (2_147_483_647.0)))
               then
                  Ada.Exceptions.Raise_Exception
                    (OpenCV.OpenCV_Error'Identity,
                     "Invalid morphology border value");
               end if;
            end;
         end loop;
         if Source.Channels > 4
           and then (Border_Value.Value.Component_0
                     /= Border_Value.Value.Component_1
                     or else Border_Value.Value.Component_0
                             /= Border_Value.Value.Component_2
                     or else Border_Value.Value.Component_0
                             /= Border_Value.Value.Component_3)
         then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity, "C5+ border must be uniform");
         end if;
      end if;
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "Morphology");
   end Morphology_Execute;

   procedure Validate_Canny
     (Source          : OpenCV.Core.Mat;
      Lower_Threshold : OpenCV.Float64_Value;
      Upper_Threshold : OpenCV.Float64_Value)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Canny_Edges requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Canny_Edges requires a two-dimensional source Mat");
      end if;

      if Source.Depth /= OpenCV.Core.UInt8 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Canny_Edges requires a UInt8 source Mat");
      end if;

      if Source.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Canny_Edges requires a source Mat with exactly 1 channel");
      end if;

      if Lower_Threshold /= Lower_Threshold
        or else Lower_Threshold > OpenCV.Float64_Value'Last
        or else Lower_Threshold < 0.0
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Canny_Edges requires a finite nonnegative lower threshold");
      end if;

      if Upper_Threshold /= Upper_Threshold
        or else Upper_Threshold > OpenCV.Float64_Value'Last
        or else Upper_Threshold < 0.0
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Canny_Edges requires a finite nonnegative upper threshold");
      end if;

      if Lower_Threshold > Upper_Threshold then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Canny_Edges requires lower threshold not greater than upper"
            & " threshold");
      end if;
   end Validate_Canny;

   procedure Validate_Derivative
     (Source            : OpenCV.Core.Mat;
      Destination_Depth : Derivative_Depth;
      Scale             : OpenCV.Float64_Value;
      Offset            : OpenCV.Float64_Value;
      Border            : OpenCV.Border_Kind;
      Operation         : String)
   is
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a two-dimensional source Mat");
      elsif Scale /= Scale
        or else Scale > OpenCV.Float64_Value'Last
        or else Scale < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a finite scale");
      elsif Offset /= Offset
        or else Offset > OpenCV.Float64_Value'Last
        or else Offset < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a finite delta");
      elsif Border = OpenCV.Wrap then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " does not support Wrap border");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8                      =>
            null;

         when OpenCV.Core.UInt16 | OpenCV.Core.Int16 =>
            if Destination_Depth = Int16_Depth then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  Operation
                  & " does not support Int16 destination depth for "
                  & "UInt16 or Int16 source Mats");
            end if;

         when OpenCV.Core.Float32                    =>
            if Destination_Depth = Int16_Depth
              or else Destination_Depth = Float64_Depth
            then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  Operation
                  & " supports only Same_Depth or Float32_Depth for "
                  & "Float32 source Mats");
            end if;

         when OpenCV.Core.Float64                    =>
            if Destination_Depth = Int16_Depth
              or else Destination_Depth = Float32_Depth
            then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  Operation
                  & " supports only Same_Depth or Float64_Depth for "
                  & "Float64 source Mats");
            end if;

         when others                                 =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               Operation
               & " requires a UInt8, UInt16, Int16, Float32, or "
               & "Float64 source Mat");
      end case;
   end Validate_Derivative;

   procedure Validate_Sobel
     (Source            : OpenCV.Core.Mat;
      X_Order           : Derivative_Order;
      Y_Order           : Derivative_Order;
      Destination_Depth : Derivative_Depth;
      Kernel_Size       : Sobel_Kernel_Size;
      Scale             : OpenCV.Float64_Value;
      Offset            : OpenCV.Float64_Value;
      Border            : OpenCV.Border_Kind) is
   begin
      Validate_Derivative
        (Source, Destination_Depth, Scale, Offset, Border, "Sobel");

      if X_Order = 0 and then Y_Order = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sobel requires a nonzero X_Order or Y_Order");
      end if;

      if X_Order >= Effective_Sobel_Kernel_Length (X_Order, Kernel_Size)
        or else Y_Order >= Effective_Sobel_Kernel_Length (Y_Order, Kernel_Size)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sobel derivative orders must be less than the effective "
            & "kernel size");
      end if;
   end Validate_Sobel;

   procedure Validate_Threshold
     (Source                         : OpenCV.Core.Mat;
      Threshold_Value, Maximum_Value : OpenCV.Float64_Value)
   is
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Threshold requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Threshold requires a two-dimensional source Mat");
      elsif Threshold_Value /= Threshold_Value
        or else Threshold_Value > OpenCV.Float64_Value'Last
        or else Threshold_Value < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Threshold requires a finite threshold value");
      elsif Maximum_Value /= Maximum_Value
        or else Maximum_Value > OpenCV.Float64_Value'Last
        or else Maximum_Value < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Threshold requires a finite maximum value");
      end if;
      case Source.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Apply_Threshold requires a UInt8, UInt16, Int16, Float32,"
               & " or Float64 source Mat");
      end case;
   end Validate_Threshold;

   procedure Validate_Automatic_Threshold
     (Source        : OpenCV.Core.Mat;
      Method        : Automatic_Threshold_Method;
      Maximum_Value : OpenCV.Float64_Value)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Automatic_Threshold requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Automatic_Threshold requires a two-dimensional source Mat");
      elsif Source.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Automatic_Threshold requires a source Mat with exactly 1"
            & " channel");
      elsif Maximum_Value /= Maximum_Value
        or else Maximum_Value > OpenCV.Float64_Value'Last
        or else Maximum_Value < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Automatic_Threshold requires a finite maximum value");
      end if;

      case Method is
         when Otsu     =>
            case Source.Depth is
               when OpenCV.Core.UInt8 | OpenCV.Core.UInt16 =>
                  null;

               when others                                 =>
                  Ada.Exceptions.Raise_Exception
                    (OpenCV.OpenCV_Error'Identity,
                     "Otsu automatic thresholding requires a UInt8 or UInt16"
                     & " source Mat");
            end case;

         when Triangle =>
            if Source.Depth /= OpenCV.Core.UInt8 then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "Triangle automatic thresholding requires a UInt8 source"
                  & " Mat");
            end if;
      end case;
   end Validate_Automatic_Threshold;

   procedure Validate_Adaptive_Threshold
     (Source     : OpenCV.Core.Mat;
      Block_Size : Adaptive_Block_Size;
      Bias       : OpenCV.Float64_Value)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Adaptive_Threshold requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Adaptive_Threshold requires a two-dimensional source Mat");
      elsif Source.Depth /= OpenCV.Core.UInt8 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Adaptive_Threshold requires a UInt8 source Mat");
      elsif Source.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Adaptive_Threshold requires a source Mat with exactly 1"
            & " channel");
      elsif Block_Size mod 2 = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Adaptive_Threshold requires an odd block size");
      elsif Bias /= Bias
        or else Bias > OpenCV.Float64_Value'Last
        or else Bias < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Adaptive_Threshold requires a finite bias");
      end if;
   end Validate_Adaptive_Threshold;

   procedure Validate_Equalize_Histogram (Source : OpenCV.Core.Mat) is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Equalize_Histogram requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Equalize_Histogram requires a two-dimensional source Mat");
      elsif Source.Depth /= OpenCV.Core.UInt8 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Equalize_Histogram requires a UInt8 source Mat");
      elsif Source.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Equalize_Histogram requires a source Mat with exactly 1"
            & " channel");
      end if;
   end Validate_Equalize_Histogram;

   procedure Validate_CLAHE
     (Source         : OpenCV.Core.Mat;
      Clip_Limit     : OpenCV.Float64_Value;
      Tile_Grid_Size : OpenCV.Size)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Float64_Value;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "CLAHE requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "CLAHE requires a two-dimensional source Mat");
      elsif Source.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "CLAHE requires a source Mat with exactly 1 channel");
      elsif Source.Depth /= OpenCV.Core.UInt8
        and then Source.Depth /= OpenCV.Core.UInt16
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "CLAHE requires a UInt8 or UInt16 source Mat");
      elsif Clip_Limit <= 0.0
        or else Clip_Limit /= Clip_Limit
        or else Clip_Limit > OpenCV.Float64_Value'Last
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "CLAHE requires a positive finite clip limit");
      elsif Tile_Grid_Size.Width = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "CLAHE requires a positive tile grid width");
      elsif Tile_Grid_Size.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "CLAHE requires a positive tile grid height");
      end if;
   end Validate_CLAHE;

   procedure Validate_Contour_Source (Source : OpenCV.Core.Mat) is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Find_Contours requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Find_Contours requires a two-dimensional source Mat");
      elsif Source.Depth /= OpenCV.Core.UInt8 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Find_Contours requires a UInt8 source Mat");
      elsif Source.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Find_Contours requires a single-channel source Mat");
      end if;
   end Validate_Contour_Source;

   procedure Validate_Connected_Component_Source (Source : OpenCV.Core.Mat) is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Connected_Components_With_Stats requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Connected_Components_With_Stats requires a two-dimensional"
            & " source Mat");
      elsif Source.Depth /= OpenCV.Core.UInt8 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Connected_Components_With_Stats requires a UInt8 source Mat");
      elsif Source.Channels /= 1 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Connected_Components_With_Stats requires a single-channel"
            & " source Mat");
      end if;
   end Validate_Connected_Component_Source;

   procedure Validate_Connected_Component_Storage
     (Source, Labels : OpenCV.Core.Mat)
   is
      use type Interfaces.Unsigned_8;
      use type Internal.C_API.Status;

      Overlap : aliased Interfaces.Unsigned_8 := 0;
      Status  : Internal.C_API.Status := Internal.C_API.Success;

      procedure First_Input
        (First_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Second_Input
           (Second_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status :=
              Internal.C_API.Mats_Overlap
                (First_Handle, Second_Handle, Overlap'Access);
         end Second_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Labels, Second_Input'Access);
      end First_Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, First_Input'Access);
      if Status /= Internal.C_API.Success then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "connected-components storage validation failed: "
            & Internal.C_API.Last_Error_Message);
      end if;
      if Overlap /= 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Connected_Components_With_Stats requires Labels not to share"
            & " storage with Source");
      end if;
   end Validate_Connected_Component_Storage;

   function To_C_Connectivity
     (Connectivity : Pixel_Connectivity) return Interfaces.Integer_32 is
   begin
      case Connectivity is
         when Four_Connected  =>
            return 4;

         when Eight_Connected =>
            return 8;
      end case;
   end To_C_Connectivity;

   function To_Optional_Contour_Index
     (Value : Interfaces.Integer_32) return Optional_Contour_Index
   is
      use type Interfaces.Integer_32;
   begin
      if Value < 0 then
         return (Present => False);
      end if;
      return (Present => True, Index => Contour_Index (Value));
   end To_Optional_Contour_Index;

   procedure Validate_Contour_Index
     (Self : Contour_Set; Index : Contour_Index; Operation : String)
   is
      use type Ada.Containers.Count_Type;
   begin
      if Ada.Containers.Count_Type (Index) >= Self.Contours.Length then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " contour index is out of range");
      end if;
   end Validate_Contour_Index;

   procedure Raise_On_Error
     (Status : Internal.C_API.Status; Operation : String)
   is
      use type Internal.C_API.Status;

      Diagnostic : constant String := Internal.C_API.Last_Error_Message;
   begin
      if Status = Internal.C_API.Success then
         return;
      end if;

      if Diagnostic'Length = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Operation & " failed");
      else
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " failed: " & Diagnostic);
      end if;
   end Raise_On_Error;

   procedure Convert_Color
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Conversion  : Color_Conversion)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Convert_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Convert_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Cvt_Color
                (Source_Handle,
                 Destination_Handle,
                 To_C_Conversion (Conversion));
         end Convert_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Convert_Output'Access);
      end Convert_Input;
   begin
      Validate_Conversion (Source, Conversion);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Convert_Input'Access);
      Raise_On_Error (Status, "color conversion");
   end Convert_Color;

   procedure Resize
     (Source        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method := Linear)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Resize_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Resize_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Resize
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.Integer_32 (Output_Size.Width),
                 Interfaces.Integer_32 (Output_Size.Height),
                 To_C_Interpolation (Interpolation));
         end Resize_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Resize_Output'Access);
      end Resize_Input;
   begin
      Validate_Resize (Source, Output_Size);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Resize_Input'Access);
      Raise_On_Error (Status, "resize");
   end Resize;

   procedure Gaussian_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Size;
      Sigma       : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Blur_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Blur_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Gaussian_Blur
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.Integer_32 (Kernel_Size.Width),
                 Interfaces.Integer_32 (Kernel_Size.Height),
                 Interfaces.C.double (Sigma),
                 To_C_Border (Border));
         end Blur_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Blur_Output'Access);
      end Blur_Input;
   begin
      Validate_Gaussian_Blur (Source, Kernel_Size, Sigma, Border);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Blur_Input'Access);
      Raise_On_Error (Status, "Gaussian blur");
   end Gaussian_Blur;

   Automatic_Gaussian_Sigma : constant Interfaces.C.double := 0.0;

   function Apply_Get_Gaussian_Kernel
     (Kernel_Size : Gaussian_Kernel_Size;
      Sigma       : Interfaces.C.double;
      Depth       : Gaussian_Kernel_Depth) return OpenCV.Core.Mat
   is
      use Internal.C_API;

      Destination : OpenCV.Core.Mat;
      Status      : Internal.C_API.Status := Success;

      procedure Kernel_Output
        (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Get_Gaussian_Kernel
             (Destination_Handle,
              Interfaces.Integer_32 (Kernel_Size),
              Sigma,
              To_C_Gaussian_Kernel_Depth (Depth));
      end Kernel_Output;
   begin
      OpenCV.Core.Module_Interop.With_Output_Handle
        (Destination, Kernel_Output'Access);
      Raise_On_Error (Status, "Get_Gaussian_Kernel");
      return Destination;
   end Apply_Get_Gaussian_Kernel;

   function Get_Gaussian_Kernel
     (Kernel_Size : Gaussian_Kernel_Size;
      Depth       : Gaussian_Kernel_Depth := Float64_Kernel)
      return OpenCV.Core.Mat is
   begin
      Validate_Get_Gaussian_Kernel (Kernel_Size, 1.0, Automatic => True);
      return
        Apply_Get_Gaussian_Kernel
          (Kernel_Size, Automatic_Gaussian_Sigma, Depth);
   end Get_Gaussian_Kernel;

   function Get_Gaussian_Kernel
     (Kernel_Size : Gaussian_Kernel_Size;
      Sigma       : OpenCV.Float64_Value;
      Depth       : Gaussian_Kernel_Depth := Float64_Kernel)
      return OpenCV.Core.Mat is
   begin
      Validate_Get_Gaussian_Kernel (Kernel_Size, Sigma, Automatic => False);
      return
        Apply_Get_Gaussian_Kernel
          (Kernel_Size, Interfaces.C.double (Sigma), Depth);
   end Get_Gaussian_Kernel;

   function Apply_Get_Derivative_Kernels
     (X_Order       : Interfaces.Integer_32;
      Y_Order       : Interfaces.Integer_32;
      Kernel_Size   : Interfaces.Integer_32;
      Normalization : Derivative_Kernel_Normalization;
      Depth         : Derivative_Kernel_Depth) return Derivative_Kernels
   is
      use Internal.C_API;

      Result : Derivative_Kernels;
      Status : Internal.C_API.Status := Success;

      procedure Kernel_X_Output
        (Kernel_X_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
         procedure Kernel_Y_Output
           (Kernel_Y_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              Internal.C_API.Get_Derivative_Kernels
                (Kernel_X_Handle,
                 Kernel_Y_Handle,
                 X_Order,
                 Y_Order,
                 Kernel_Size,
                 To_C_Derivative_Kernel_Normalization (Normalization),
                 To_C_Gaussian_Kernel_Depth (Depth));
         end Kernel_Y_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Result.Kernel_Y, Kernel_Y_Output'Access);
      end Kernel_X_Output;
   begin
      OpenCV.Core.Module_Interop.With_Output_Handle
        (Result.Kernel_X, Kernel_X_Output'Access);
      Raise_On_Error (Status, "Get_Derivative_Kernels");
      return Result;
   end Apply_Get_Derivative_Kernels;

   function Get_Derivative_Kernels
     (X_Order       : Derivative_Order;
      Y_Order       : Derivative_Order;
      Kernel_Size   : Sobel_Kernel_Size := Kernel_3;
      Normalization : Derivative_Kernel_Normalization := Unnormalized;
      Depth         : Derivative_Kernel_Depth := Float32_Kernel)
      return Derivative_Kernels is
   begin
      Validate_Derivative_Kernel_Orders (X_Order, Y_Order, Kernel_Size);
      return
        Apply_Get_Derivative_Kernels
          (Interfaces.Integer_32 (X_Order),
           Interfaces.Integer_32 (Y_Order),
           To_C_Sobel_Kernel (Kernel_Size),
           Normalization,
           Depth);
   end Get_Derivative_Kernels;

   function Get_Scharr_Kernels
     (Axis          : Derivative_Axis;
      Normalization : Derivative_Kernel_Normalization := Unnormalized;
      Depth         : Derivative_Kernel_Depth := Float32_Kernel)
      return Derivative_Kernels
   is
      X_Order : Interfaces.Integer_32 := 0;
      Y_Order : Interfaces.Integer_32 := 0;
   begin
      case Axis is
         when X_Axis =>
            X_Order := 1;
            Y_Order := 0;

         when Y_Axis =>
            X_Order := 0;
            Y_Order := 1;
      end case;

      return
        Apply_Get_Derivative_Kernels
          (X_Order,
           Y_Order,
           Internal.C_API.Derivative_Kernel_Scharr,
           Normalization,
           Depth);
   end Get_Scharr_Kernels;

   procedure Pyramid_Down
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Down_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Down_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Pyramid_Down
                (Source_Handle,
                 Destination_Handle,
                 To_C_Pyramid_Down_Border (Border));
         end Down_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Down_Output'Access);
      end Down_Input;
   begin
      Validate_Pyramid_Down (Source, Border);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Down_Input'Access);
      Raise_On_Error (Status, "Pyramid_Down");
   end Pyramid_Down;

   procedure Pyramid_Up
     (Source : OpenCV.Core.Mat; Destination : in out OpenCV.Core.Mat)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Up_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Up_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Pyramid_Up (Source_Handle, Destination_Handle);
         end Up_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Up_Output'Access);
      end Up_Input;
   begin
      Validate_Pyramid_Source (Source, "Pyramid_Up");
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Up_Input'Access);
      Raise_On_Error (Status, "Pyramid_Up");
   end Pyramid_Up;

   --  True when Target is a legal explicit Pyramid_Up extent for Source:
   --  exactly twice Source or one less. Widened so 2 * Source cannot wrap.
   function Is_Pyramid_Up_Extent
     (Source : Natural; Target : OpenCV.Size_Coordinate) return Boolean
   is
      Twice : constant Long_Long_Integer := 2 * Long_Long_Integer (Source);
   begin
      return Long_Long_Integer (Target) in Twice - 1 | Twice;
   end Is_Pyramid_Up_Extent;

   procedure Pyramid_Up
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Output_Size : OpenCV.Size)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Up_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Up_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Pyramid_Up_Sized
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.Integer_32 (Output_Size.Width),
                 Interfaces.Integer_32 (Output_Size.Height));
         end Up_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Up_Output'Access);
      end Up_Input;
   begin
      Validate_Pyramid_Source (Source, "Pyramid_Up");
      if not Is_Pyramid_Up_Extent (Source.Columns, Output_Size.Width)
        or else not Is_Pyramid_Up_Extent (Source.Rows, Output_Size.Height)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Pyramid_Up Output_Size extents must be 2 * Source or"
            & " 2 * Source - 1");
      end if;
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Up_Input'Access);
      Raise_On_Error (Status, "Pyramid_Up");
   end Pyramid_Up;

   --  Natural Gaussian halving used by every pyramid geometry check.
   function Pyramid_Half (Extent : Natural) return Natural
   is (Natural ((Long_Long_Integer (Extent) + 1) / 2));

   function Maximum_Pyramid_Level_Count
     (Source : OpenCV.Core.Mat) return Positive
   is
      Columns : Long_Long_Integer;
      Rows    : Long_Long_Integer;
      Count   : Positive := 1;
   begin
      if Source.Is_Empty or else Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Maximum_Pyramid_Level_Count requires a non-empty"
            & " two-dimensional source Mat");
      end if;

      Columns := Long_Long_Integer (Source.Columns);
      Rows := Long_Long_Integer (Source.Rows);
      while Columns > 1 or else Rows > 1 loop
         Columns := (Columns + 1) / 2;
         Rows := (Rows + 1) / 2;
         Count := Count + 1;
      end loop;
      return Count;
   end Maximum_Pyramid_Level_Count;

   procedure Validate_Pyramid_Build
     (Source      : OpenCV.Core.Mat;
      Level_Count : Positive;
      Border      : OpenCV.Border_Kind;
      Operation   : String) is
   begin
      Validate_Pyramid_Source (Source, Operation);

      if Border = OpenCV.Constant_Border then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " does not support Constant_Border");
      end if;

      if Level_Count > Maximum_Pyramid_Level_Count (Source) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation
            & " Level_Count exceeds the distinct natural pyramid levels");
      end if;
   end Validate_Pyramid_Build;

   --  Destroys a native pyramid result and clears the handle so a later
   --  exception handler cannot free it twice. Destroy accepts null.
   procedure Release_Pyramid (Result : in out Internal.C_API.Pyramid_Handle) is
   begin
      Internal.C_API.Pyramid_Destroy (Result);
      Result := Internal.C_API.Null_Pyramid_Handle;
   end Release_Pyramid;

   function Build_Gaussian_Pyramid
     (Source      : OpenCV.Core.Mat;
      Level_Count : Positive;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat_Array
   is
      use type Interfaces.Integer_32;

      Operation : constant String := "Build_Gaussian_Pyramid";
      Result    : aliased Internal.C_API.Pyramid_Handle :=
        Internal.C_API.Null_Pyramid_Handle;
      Status    : Internal.C_API.Status := Internal.C_API.Success;
      Count     : aliased Interfaces.Integer_32 := 0;

      procedure Build
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Build_Pyramid
             (Source_Handle,
              Interfaces.Integer_32 (Level_Count),
              To_C_Pyramid_Down_Border (Border),
              Result'Access);
      end Build;
   begin
      Validate_Pyramid_Build (Source, Level_Count, Border, Operation);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Build'Access);
      Raise_On_Error (Status, Operation);

      begin
         Raise_On_Error
           (Internal.C_API.Pyramid_Count (Result, Count'Access), Operation);
         if Count /= Interfaces.Integer_32 (Level_Count) then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               Operation & " produced an unexpected level count");
         end if;

         declare
            Levels : OpenCV.Core.Mat_Array (0 .. Level_Count - 1);
         begin
            for Index in Levels'Range loop
               declare
                  procedure Copy
                    (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
                  begin
                     Status :=
                       Internal.C_API.Pyramid_Copy_Level
                         (Result, Interfaces.Integer_32 (Index), Target);
                  end Copy;
               begin
                  OpenCV.Core.Module_Interop.With_Output_Handle
                    (Levels (Index), Copy'Access);
                  Raise_On_Error (Status, Operation);
               end;
            end loop;
            Release_Pyramid (Result);
            return Levels;
         end;
      exception
         when others =>
            Release_Pyramid (Result);
            raise;
      end;
   end Build_Gaussian_Pyramid;

   function Laplacian_Working_Depth
     (Source : OpenCV.Core.Mat; Precision : Laplacian_Precision)
      return OpenCV.Core.Depth_Type
   is
      use type OpenCV.Core.Depth_Type;
   begin
      case Precision is
         when Automatic_Precision =>
            if Source.Depth = OpenCV.Core.Float64 then
               return OpenCV.Core.Float64;
            else
               return OpenCV.Core.Float32;
            end if;

         when Float32_Precision   =>
            return OpenCV.Core.Float32;

         when Float64_Precision   =>
            return OpenCV.Core.Float64;
      end case;
   end Laplacian_Working_Depth;

   function Level_Size (Level : OpenCV.Core.Mat) return OpenCV.Size
   is ((Width  => OpenCV.Size_Coordinate (Level.Columns),
        Height => OpenCV.Size_Coordinate (Level.Rows)));

   function Build_Laplacian_Pyramid
     (Source      : OpenCV.Core.Mat;
      Level_Count : Positive;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101;
      Precision   : Laplacian_Precision := Automatic_Precision)
      return OpenCV.Core.Mat_Array is
   begin
      Validate_Pyramid_Build
        (Source, Level_Count, Border, "Build_Laplacian_Pyramid");

      declare
         --  Convert_To returns an independent copy of the logical image, so
         --  a Region's parent pixels cannot reach the Gaussian build.
         Working  : constant OpenCV.Core.Mat :=
           Source.Convert_To (Laplacian_Working_Depth (Source, Precision));
         Gaussian : constant OpenCV.Core.Mat_Array :=
           Build_Gaussian_Pyramid (Working, Level_Count, Border);
         Levels   : OpenCV.Core.Mat_Array (Gaussian'Range);
      begin
         for Index in Gaussian'First .. Gaussian'Last - 1 loop
            declare
               Up : OpenCV.Core.Mat;
            begin
               Pyramid_Up
                 (Gaussian (Index + 1),
                  Up,
                  Output_Size => Level_Size (Gaussian (Index)));
               Levels (Index) := OpenCV.Core.Subtract (Gaussian (Index), Up);
            end;
         end loop;
         --  Gaussian levels already own independent storage.
         Levels (Levels'Last) := Gaussian (Gaussian'Last);
         return Levels;
      end;
   end Build_Laplacian_Pyramid;

   procedure Validate_Laplacian_Pyramid (Pyramid : OpenCV.Core.Mat_Array) is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;

      procedure Fail (Message : String) is
      begin
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Reconstruct_Laplacian_Pyramid " & Message);
      end Fail;
   begin
      if Pyramid'Length = 0 then
         Fail ("requires a non-empty pyramid");
      end if;

      for Index in Pyramid'Range loop
         declare
            Level : OpenCV.Core.Mat renames Pyramid (Index);
         begin
            if Level.Is_Empty or else Level.Dimension_Count /= 2 then
               Fail ("requires non-empty two-dimensional levels");
            elsif Level.Depth not in OpenCV.Core.Float32 | OpenCV.Core.Float64
            then
               Fail ("requires Float32 or Float64 levels");
            elsif Level.Depth /= Pyramid (Pyramid'First).Depth then
               Fail ("requires one common level depth");
            elsif Level.Channels /= Pyramid (Pyramid'First).Channels then
               Fail ("requires one common channel count");
            elsif Index > Pyramid'First
              and then (Level.Rows /= Pyramid_Half (Pyramid (Index - 1).Rows)
                        or else Level.Columns
                                /= Pyramid_Half (Pyramid (Index - 1).Columns))
            then
               Fail ("requires natural half-size level geometry");
            end if;
         end;
      end loop;
   end Validate_Laplacian_Pyramid;

   function Reconstruct_Laplacian_Pyramid
     (Pyramid : OpenCV.Core.Mat_Array) return OpenCV.Core.Mat
   is
      Current : OpenCV.Core.Mat;
   begin
      Validate_Laplacian_Pyramid (Pyramid);

      Current := Pyramid (Pyramid'Last).Clone;
      for Index in reverse Pyramid'First .. Pyramid'Last - 1 loop
         declare
            Up : OpenCV.Core.Mat;
         begin
            Pyramid_Up
              (Current, Up, Output_Size => Level_Size (Pyramid (Index)));
            Current := OpenCV.Core.Add (Up, Pyramid (Index));
         end;
      end loop;
      return Current;
   end Reconstruct_Laplacian_Pyramid;

   procedure Match_Template
     (Source      : OpenCV.Core.Mat;
      Template    : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Method      : Template_Matching_Method)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Source_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Template_Input
           (Template_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Match_Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Match_Template
                   (Source_Handle,
                    Template_Handle,
                    Destination_Handle,
                    To_C_Template_Matching_Method (Method));
            end Match_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Match_Output'Access);
         end Template_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Template, Template_Input'Access);
      end Source_Input;
   begin
      Validate_Match_Template (Source, Template);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Source_Input'Access);
      Raise_On_Error (Status, "Match_Template");
   end Match_Template;

   procedure Warp_Affine
     (Source        : OpenCV.Core.Mat;
      Transform     : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method := Linear;
      Mapping       : Affine_Mapping_Direction := Source_To_Destination;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0))
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Source_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Transform_Input
           (Transform_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Warp_Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Warp_Affine
                   (Source_Handle,
                    Transform_Handle,
                    Destination_Handle,
                    Interfaces.Integer_32 (Output_Size.Width),
                    Interfaces.Integer_32 (Output_Size.Height),
                    To_C_Warp_Interpolation (Interpolation),
                    To_C_Warp_Mapping (Mapping),
                    To_C_Warp_Border (Border),
                    Interfaces.C.double (Border_Value.Component_0),
                    Interfaces.C.double (Border_Value.Component_1),
                    Interfaces.C.double (Border_Value.Component_2),
                    Interfaces.C.double (Border_Value.Component_3));
            end Warp_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Warp_Output'Access);
         end Transform_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Transform, Transform_Input'Access);
      end Source_Input;
   begin
      Validate_Warp_Affine
        (Source, Transform, Output_Size, Interpolation, Border);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Source_Input'Access);
      Raise_On_Error (Status, "Warp_Affine");
   end Warp_Affine;

   procedure Warp_Perspective
     (Source        : OpenCV.Core.Mat;
      Transform     : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method := Linear;
      Mapping       : Warp_Mapping_Direction := Source_To_Destination;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0))
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Source_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Transform_Input
           (Transform_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Warp_Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Warp_Perspective
                   (Source_Handle,
                    Transform_Handle,
                    Destination_Handle,
                    Interfaces.Integer_32 (Output_Size.Width),
                    Interfaces.Integer_32 (Output_Size.Height),
                    To_C_Warp_Interpolation (Interpolation),
                    To_C_Warp_Mapping (Mapping),
                    To_C_Warp_Border (Border),
                    Interfaces.C.double (Border_Value.Component_0),
                    Interfaces.C.double (Border_Value.Component_1),
                    Interfaces.C.double (Border_Value.Component_2),
                    Interfaces.C.double (Border_Value.Component_3));
            end Warp_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Warp_Output'Access);
         end Transform_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Transform, Transform_Input'Access);
      end Source_Input;
   begin
      Validate_Warp_Perspective
        (Source, Transform, Output_Size, Interpolation, Border);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Source_Input'Access);
      Raise_On_Error (Status, "Warp_Perspective");
   end Warp_Perspective;

   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Map_X         : OpenCV.Core.Mat;
      Map_Y         : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0))
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Source_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Map_X_Input
           (Map_X_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Map_Y_Input
              (Map_Y_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Remap_Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    Internal.C_API.Remap
                      (Source_Handle,
                       Map_X_Handle,
                       Map_Y_Handle,
                       Destination_Handle,
                       To_C_Remap_Interpolation (Interpolation),
                       To_C_Remap_Border (Border),
                       Interfaces.C.double (Border_Value.Component_0),
                       Interfaces.C.double (Border_Value.Component_1),
                       Interfaces.C.double (Border_Value.Component_2),
                       Interfaces.C.double (Border_Value.Component_3));
               end Remap_Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Remap_Output'Access);
            end Map_Y_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Map_Y, Map_Y_Input'Access);
         end Map_X_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Map_X, Map_X_Input'Access);
      end Source_Input;
   begin
      Validate_Remap (Source, Map_X, Map_Y, Interpolation);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Source_Input'Access);
      Raise_On_Error (Status, "Remap");
   end Remap;

   function Is_Empty (Maps : Fixed_Remap_Maps) return Boolean is
   begin
      return Maps.Coordinates.Is_Empty;
   end Is_Empty;

   function Is_Nearest_Only (Maps : Fixed_Remap_Maps) return Boolean is
   begin
      return not Maps.Coordinates.Is_Empty and then Maps.Coefficients.Is_Empty;
   end Is_Nearest_Only;

   procedure Convert_Remap_Impl
     (First, Second      : OpenCV.Core.Mat;
      Output_1, Output_2 : in out OpenCV.Core.Mat;
      Mode               : Interfaces.Integer_32;
      Nearest            : Boolean)
   is
      use Internal.C_API;
      Status : Internal.C_API.Status := Success;
      procedure First_Input
        (First_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Second_Input
           (Second_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure First_Output
              (First_Out : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
               procedure Second_Output
                 (Second_Out : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    Internal.C_API.Convert_Remap_Maps
                      (First_Handle,
                       Second_Handle,
                       First_Out,
                       Second_Out,
                       Mode,
                       (if Nearest then 1 else 0));
               end Second_Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Output_2, Second_Output'Access);
            end First_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Output_1, First_Output'Access);
         end Second_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Second, Second_Input'Access);
      end First_Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (First, First_Input'Access);
      Raise_On_Error (Status, "Convert_Remap_Maps");
   end Convert_Remap_Impl;

   function Convert_Remap_To_Fixed
     (Map_X, Map_Y : OpenCV.Core.Mat; Nearest_Neighbor_Only : Boolean := False)
      return Fixed_Remap_Maps
   is
      Result : Fixed_Remap_Maps;
   begin
      Validate_Float_Remap_Map (Map_X, 1);
      Validate_Float_Remap_Map (Map_Y, 1);
      if Map_X.Rows /= Map_Y.Rows or else Map_X.Columns /= Map_Y.Columns then
         raise OpenCV.OpenCV_Error
           with "Remap maps must have matching geometry";
      end if;
      Convert_Remap_Impl
        (Map_X,
         Map_Y,
         Result.Coordinates,
         Result.Coefficients,
         0,
         Nearest_Neighbor_Only);
      return Result;
   end Convert_Remap_To_Fixed;

   function Convert_Remap_To_Fixed
     (Map_XY : OpenCV.Core.Mat; Nearest_Neighbor_Only : Boolean := False)
      return Fixed_Remap_Maps
   is
      Result    : Fixed_Remap_Maps;
      Empty_Map : OpenCV.Core.Mat;
   begin
      Validate_Float_Remap_Map (Map_XY, 2);
      Convert_Remap_Impl
        (Map_XY,
         Empty_Map,
         Result.Coordinates,
         Result.Coefficients,
         1,
         Nearest_Neighbor_Only);
      return Result;
   end Convert_Remap_To_Fixed;

   function Interleave_Remap_Maps
     (Map_X, Map_Y : OpenCV.Core.Mat) return OpenCV.Core.Mat
   is
      Result, Unused : OpenCV.Core.Mat;
   begin
      Validate_Float_Remap_Map (Map_X, 1);
      Validate_Float_Remap_Map (Map_Y, 1);
      if Map_X.Rows /= Map_Y.Rows or else Map_X.Columns /= Map_Y.Columns then
         raise OpenCV.OpenCV_Error
           with "Remap maps must have matching geometry";
      end if;
      Convert_Remap_Impl (Map_X, Map_Y, Result, Unused, 4, False);
      return Result;
   end Interleave_Remap_Maps;

   function Separate_Remap_Map
     (Map_XY : OpenCV.Core.Mat) return Float_Remap_Maps
   is
      Result    : Float_Remap_Maps;
      Empty_Map : OpenCV.Core.Mat;
   begin
      Validate_Float_Remap_Map (Map_XY, 2);
      Convert_Remap_Impl
        (Map_XY, Empty_Map, Result.Map_X, Result.Map_Y, 5, False);
      return Result;
   end Separate_Remap_Map;

   function Convert_Remap_To_Interleaved_Float
     (Maps : Fixed_Remap_Maps) return OpenCV.Core.Mat
   is
      Result, Unused : OpenCV.Core.Mat;
   begin
      Validate_Fixed_Remap_Maps (Maps);
      Convert_Remap_Impl
        (Maps.Coordinates, Maps.Coefficients, Result, Unused, 2, False);
      return Result;
   end Convert_Remap_To_Interleaved_Float;

   function Convert_Remap_To_Separate_Float
     (Maps : Fixed_Remap_Maps) return Float_Remap_Maps
   is
      Result : Float_Remap_Maps;
   begin
      Validate_Fixed_Remap_Maps (Maps);
      Convert_Remap_Impl
        (Maps.Coordinates,
         Maps.Coefficients,
         Result.Map_X,
         Result.Map_Y,
         3,
         False);
      return Result;
   end Convert_Remap_To_Separate_Float;

   procedure Warp_Polar
     (Source         : OpenCV.Core.Mat;
      Destination    : in out OpenCV.Core.Mat;
      Center         : OpenCV.Float32_Point;
      Maximum_Radius : OpenCV.Float64_Value;
      Output_Size    : OpenCV.Size;
      Mapping        : Polar_Mapping := Linear_Polar;
      Direction      : Polar_Direction := Cartesian_To_Polar;
      Interpolation  : Interpolation_Method := Linear)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Float64_Value;
      use type OpenCV.Float32_Value;
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Warp_Polar
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.C.C_float (Center.X),
                 Interfaces.C.C_float (Center.Y),
                 Interfaces.C.double (Maximum_Radius),
                 Interfaces.Integer_32 (Output_Size.Width),
                 Interfaces.Integer_32 (Output_Size.Height),
                 (if Mapping = Linear_Polar then 0 else 1),
                 (if Direction = Cartesian_To_Polar then 0 else 1),
                 To_C_Remap_Interpolation (Interpolation));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      if Source.Is_Empty
        or else Source.Dimension_Count /= 2
        or else Source.Depth
                not in OpenCV.Core.UInt8
                     | OpenCV.Core.UInt16
                     | OpenCV.Core.Int16
                     | OpenCV.Core.Float32
                     | OpenCV.Core.Float64
        or else Source.Channels > 4
        or else Source.Columns >= 32_767
        or else Source.Rows
                >= (if Direction = Polar_To_Cartesian then 32_765 else 32_767)
      then
         raise OpenCV.OpenCV_Error
           with "Warp_Polar source exceeds remap limits or has invalid type";
      end if;
      if Output_Size.Width = 0
        or else Output_Size.Height = 0
        or else Output_Size.Width >= 32_767
        or else Output_Size.Height >= 32_767
      then
         raise OpenCV.OpenCV_Error
           with "Warp_Polar requires explicit output dimensions below 32767";
      end if;
      if Center.X /= Center.X
        or else Center.Y /= Center.Y
        or else abs Center.X > OpenCV.Float32_Value'Last
        or else abs Center.Y > OpenCV.Float32_Value'Last
        or else Maximum_Radius /= Maximum_Radius
        or else Maximum_Radius > OpenCV.Float64_Value'Last
        or else Maximum_Radius <= (if Mapping = Linear_Polar then 0.0 else 1.0)
      then
         raise OpenCV.OpenCV_Error
           with "Warp_Polar requires finite center and radius (>1 for log)";
      end if;
      if Interpolation = Area then
         raise OpenCV.OpenCV_Error
           with "Warp_Polar does not support Area interpolation";
      end if;
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "Warp_Polar");
   end Warp_Polar;

   procedure Remap_Encoded_Impl
     (Source, First, Second : OpenCV.Core.Mat;
      Destination           : in out OpenCV.Core.Mat;
      Mode                  : Interfaces.Integer_32;
      Interpolation         : Interpolation_Method;
      Border                : OpenCV.Border_Kind;
      Border_Value          : OpenCV.Scalar)
   is
      use Internal.C_API;
      Status : Internal.C_API.Status := Success;
      procedure Source_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure First_Input
           (First_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Second_Input
              (Second_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    Internal.C_API.Remap_Encoded
                      (Source_Handle,
                       First_Handle,
                       Second_Handle,
                       Destination_Handle,
                       Mode,
                       To_C_Remap_Interpolation (Interpolation),
                       To_C_Remap_Border (Border),
                       Interfaces.C.double (Border_Value.Component_0),
                       Interfaces.C.double (Border_Value.Component_1),
                       Interfaces.C.double (Border_Value.Component_2),
                       Interfaces.C.double (Border_Value.Component_3));
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Second_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Second, Second_Input'Access);
         end First_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (First, First_Input'Access);
      end Source_Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Source_Input'Access);
      Raise_On_Error (Status, "Remap");
   end Remap_Encoded_Impl;

   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Map_XY        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0))
   is
      Empty_Map : OpenCV.Core.Mat;
   begin
      Validate_Remap_Source (Source, Interpolation);
      Validate_Float_Remap_Map (Map_XY, 2);
      Remap_Encoded_Impl
        (Source,
         Map_XY,
         Empty_Map,
         Destination,
         0,
         Interpolation,
         Border,
         Border_Value);
   end Remap;

   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Maps          : Fixed_Remap_Maps;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0)) is
   begin
      Validate_Fixed_Remap_Maps (Maps);
      Validate_Remap_Source (Source, Interpolation);
      if Maps.Coefficients.Is_Empty and then Interpolation /= Nearest_Neighbor
      then
         raise OpenCV.OpenCV_Error
           with "Nearest-only map requires Nearest_Neighbor";
      end if;
      Remap_Encoded_Impl
        (Source,
         Maps.Coordinates,
         Maps.Coefficients,
         Destination,
         1,
         Interpolation,
         Border,
         Border_Value);
   end Remap;

   procedure Median_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : Median_Kernel_Size)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Blur_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Blur_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Median_Blur
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.Integer_32 (Kernel_Size));
         end Blur_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Blur_Output'Access);
      end Blur_Input;
   begin
      Validate_Median_Blur (Source, Kernel_Size);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Blur_Input'Access);
      Raise_On_Error (Status, "median blur");
   end Median_Blur;

   procedure Box_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Size;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Blur_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Blur_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Box_Blur
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.Integer_32 (Kernel_Size.Width),
                 Interfaces.Integer_32 (Kernel_Size.Height),
                 To_C_Border (Border));
         end Blur_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Blur_Output'Access);
      end Blur_Input;
   begin
      Validate_Box_Blur (Source, Kernel_Size, Border);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Blur_Input'Access);
      Raise_On_Error (Status, "box blur");
   end Box_Blur;

   procedure Apply_Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Diameter    : Interfaces.Integer_32;
      Sigma_Color : OpenCV.Float64_Value;
      Sigma_Space : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Filter_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Filter_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Bilateral_Filter
                (Source_Handle,
                 Destination_Handle,
                 Diameter,
                 Interfaces.C.double (Sigma_Color),
                 Interfaces.C.double (Sigma_Space),
                 To_C_Border (Border));
         end Filter_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Filter_Output'Access);
      end Filter_Input;
   begin
      Validate_Bilateral_Filter (Source, Sigma_Color, Sigma_Space, Border);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Filter_Input'Access);
      Raise_On_Error (Status, "bilateral filter");
   end Apply_Bilateral_Filter;

   procedure Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Sigma_Color : OpenCV.Float64_Value;
      Sigma_Space : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101) is
   begin
      Apply_Bilateral_Filter
        (Source, Destination, 0, Sigma_Color, Sigma_Space, Border);
   end Bilateral_Filter;

   procedure Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Diameter    : Bilateral_Diameter;
      Sigma_Color : OpenCV.Float64_Value;
      Sigma_Space : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101) is
   begin
      Apply_Bilateral_Filter
        (Source,
         Destination,
         Interfaces.Integer_32 (Diameter),
         Sigma_Color,
         Sigma_Space,
         Border);
   end Bilateral_Filter;

   procedure Apply_Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel            : OpenCV.Core.Mat;
      Anchor_X          : Interfaces.Integer_32;
      Anchor_Y          : Interfaces.Integer_32;
      Destination_Depth : Filter_Depth;
      Offset            : OpenCV.Float64_Value;
      Border            : OpenCV.Border_Kind)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Source_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Kernel_Input
           (Kernel_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Filter_Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Filter_2D
                   (Source_Handle,
                    Destination_Handle,
                    Kernel_Handle,
                    To_C_Derivative_Depth (Destination_Depth),
                    Anchor_X,
                    Anchor_Y,
                    Interfaces.C.double (Offset),
                    To_C_Border (Border));
            end Filter_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Filter_Output'Access);
         end Kernel_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Kernel, Kernel_Input'Access);
      end Source_Input;
   begin
      Validate_Filter_2D (Source, Kernel, Destination_Depth, Offset, Border);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Source_Input'Access);
      Raise_On_Error (Status, "Filter_2D");
   end Apply_Filter_2D;

   procedure Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel            : OpenCV.Core.Mat;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101) is
   begin
      Apply_Filter_2D
        (Source,
         Destination,
         Kernel,
         Interfaces.Integer_32 (-1),
         Interfaces.Integer_32 (-1),
         Destination_Depth,
         Offset,
         Border);
   end Filter_2D;

   procedure Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel            : OpenCV.Core.Mat;
      Anchor            : OpenCV.Point;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101) is
   begin
      Validate_Filter_2D (Source, Kernel, Destination_Depth, Offset, Border);
      Validate_Filter_2D_Anchor (Kernel, Anchor);
      Apply_Filter_2D
        (Source,
         Destination,
         Kernel,
         Interfaces.Integer_32 (Anchor.X),
         Interfaces.Integer_32 (Anchor.Y),
         Destination_Depth,
         Offset,
         Border);
   end Filter_2D;

   procedure Apply_Sep_Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel_X          : OpenCV.Core.Mat;
      Kernel_Y          : OpenCV.Core.Mat;
      Anchor_X          : Interfaces.Integer_32;
      Anchor_Y          : Interfaces.Integer_32;
      Destination_Depth : Filter_Depth;
      Offset            : OpenCV.Float64_Value;
      Border            : OpenCV.Border_Kind)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Source_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Kernel_X_Input
           (Kernel_X_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Kernel_Y_Input
              (Kernel_Y_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Filter_Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    Internal.C_API.Sep_Filter_2D
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_X_Handle,
                       Kernel_Y_Handle,
                       To_C_Derivative_Depth (Destination_Depth),
                       Anchor_X,
                       Anchor_Y,
                       Interfaces.C.double (Offset),
                       To_C_Border (Border));
               end Filter_Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Filter_Output'Access);
            end Kernel_Y_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Kernel_Y, Kernel_Y_Input'Access);
         end Kernel_X_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Kernel_X, Kernel_X_Input'Access);
      end Source_Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Source_Input'Access);
      Raise_On_Error (Status, "Sep_Filter_2D");
   end Apply_Sep_Filter_2D;

   procedure Sep_Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel_X          : OpenCV.Core.Mat;
      Kernel_Y          : OpenCV.Core.Mat;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101) is
   begin
      Validate_Sep_Filter_2D
        (Source, Kernel_X, Kernel_Y, Destination_Depth, Offset, Border);
      Apply_Sep_Filter_2D
        (Source,
         Destination,
         Kernel_X,
         Kernel_Y,
         Interfaces.Integer_32 (-1),
         Interfaces.Integer_32 (-1),
         Destination_Depth,
         Offset,
         Border);
   end Sep_Filter_2D;

   procedure Sep_Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel_X          : OpenCV.Core.Mat;
      Kernel_Y          : OpenCV.Core.Mat;
      Anchor            : OpenCV.Point;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101) is
   begin
      Validate_Sep_Filter_2D
        (Source, Kernel_X, Kernel_Y, Destination_Depth, Offset, Border);
      Validate_Sep_Filter_2D_Anchor (Kernel_X, Kernel_Y, Anchor);
      Apply_Sep_Filter_2D
        (Source,
         Destination,
         Kernel_X,
         Kernel_Y,
         Interfaces.Integer_32 (Anchor.X),
         Interfaces.Integer_32 (Anchor.Y),
         Destination_Depth,
         Offset,
         Border);
   end Sep_Filter_2D;

   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         0,
         Kernel_Size,
         Shape,
         Source,
         False,
         (0, 0),
         False,
         Iterations,
         Border,
         Border_Value);
   end Erode;

   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         1,
         Kernel_Size,
         Shape,
         Source,
         False,
         (0, 0),
         False,
         Iterations,
         Border,
         Border_Value);
   end Dilate;

   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         Interfaces.Integer_32 (Morphology_Operation'Pos (Operation) + 2),
         Kernel_Size,
         Shape,
         Source,
         False,
         (0, 0),
         False,
         Iterations,
         Border,
         Border_Value);
   end Apply_Morphology;

   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         0,
         Kernel_Size,
         Shape,
         Source,
         False,
         Anchor,
         True,
         Iterations,
         Border,
         Border_Value);
   end Erode;

   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         1,
         Kernel_Size,
         Shape,
         Source,
         False,
         Anchor,
         True,
         Iterations,
         Border,
         Border_Value);
   end Dilate;

   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         Interfaces.Integer_32 (Morphology_Operation'Pos (Operation) + 2),
         Kernel_Size,
         Shape,
         Source,
         False,
         Anchor,
         True,
         Iterations,
         Border,
         Border_Value);
   end Apply_Morphology;

   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         0,
         (0, 0),
         Rectangle,
         Kernel,
         True,
         (0, 0),
         False,
         Iterations,
         Border,
         Border_Value);
   end Erode;

   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         1,
         (0, 0),
         Rectangle,
         Kernel,
         True,
         (0, 0),
         False,
         Iterations,
         Border,
         Border_Value);
   end Dilate;

   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         Interfaces.Integer_32 (Morphology_Operation'Pos (Operation) + 2),
         (0, 0),
         Rectangle,
         Kernel,
         True,
         (0, 0),
         False,
         Iterations,
         Border,
         Border_Value);
   end Apply_Morphology;

   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         0,
         (0, 0),
         Rectangle,
         Kernel,
         True,
         Anchor,
         True,
         Iterations,
         Border,
         Border_Value);
   end Erode;

   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         1,
         (0, 0),
         Rectangle,
         Kernel,
         True,
         Anchor,
         True,
         Iterations,
         Border,
         Border_Value);
   end Dilate;

   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border) is
   begin
      Morphology_Execute
        (Source,
         Destination,
         Interfaces.Integer_32 (Morphology_Operation'Pos (Operation) + 2),
         (0, 0),
         Rectangle,
         Kernel,
         True,
         Anchor,
         True,
         Iterations,
         Border,
         Border_Value);
   end Apply_Morphology;

   procedure Canny_Edges
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Lower_Threshold : OpenCV.Float64_Value;
      Upper_Threshold : OpenCV.Float64_Value;
      Aperture        : Canny_Aperture := Sobel_3x3;
      Gradient_Norm   : Canny_Gradient_Norm := L1_Norm)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Canny_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Canny_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Canny
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.C.double (Lower_Threshold),
                 Interfaces.C.double (Upper_Threshold),
                 To_C_Canny_Aperture (Aperture),
                 To_C_Canny_Gradient_Norm (Gradient_Norm));
         end Canny_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Canny_Output'Access);
      end Canny_Input;
   begin
      Validate_Canny (Source, Lower_Threshold, Upper_Threshold);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Canny_Input'Access);
      Raise_On_Error (Status, "Canny edge detection");
   end Canny_Edges;

   procedure Sobel
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      X_Order           : Derivative_Order;
      Y_Order           : Derivative_Order;
      Destination_Depth : Derivative_Depth := Float32_Depth;
      Kernel_Size       : Sobel_Kernel_Size := Kernel_3;
      Scale             : OpenCV.Float64_Value := 1.0;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101)
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Sobel
                (Source_Handle,
                 Destination_Handle,
                 To_C_Derivative_Depth (Destination_Depth),
                 Interfaces.Integer_32 (X_Order),
                 Interfaces.Integer_32 (Y_Order),
                 To_C_Sobel_Kernel (Kernel_Size),
                 Interfaces.C.double (Scale),
                 Interfaces.C.double (Offset),
                 To_C_Border (Border));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      Validate_Sobel
        (Source,
         X_Order,
         Y_Order,
         Destination_Depth,
         Kernel_Size,
         Scale,
         Offset,
         Border);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "Sobel");
   end Sobel;

   procedure Scharr
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Axis              : Derivative_Axis;
      Destination_Depth : Derivative_Depth := Float32_Depth;
      Scale             : OpenCV.Float64_Value := 1.0;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101)
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Scharr
                (Source_Handle,
                 Destination_Handle,
                 To_C_Derivative_Depth (Destination_Depth),
                 To_C_Derivative_Axis (Axis),
                 Interfaces.C.double (Scale),
                 Interfaces.C.double (Offset),
                 To_C_Border (Border));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      Validate_Derivative
        (Source, Destination_Depth, Scale, Offset, Border, "Scharr");
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "Scharr");
   end Scharr;

   procedure Laplacian
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Destination_Depth : Derivative_Depth := Float32_Depth;
      Kernel_Size       : Laplacian_Kernel_Size := 1;
      Scale             : OpenCV.Float64_Value := 1.0;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101)
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Laplacian
                (Source_Handle,
                 Destination_Handle,
                 To_C_Derivative_Depth (Destination_Depth),
                 Interfaces.Integer_32 (Kernel_Size),
                 Interfaces.C.double (Scale),
                 Interfaces.C.double (Offset),
                 To_C_Border (Border));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      Validate_Derivative
        (Source, Destination_Depth, Scale, Offset, Border, "Laplacian");
      if Kernel_Size mod 2 = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Laplacian kernel size must be odd and between 1 and 31");
      end if;
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "Laplacian");
   end Laplacian;

   procedure Apply_Threshold
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Threshold_Value : OpenCV.Float64_Value;
      Mode            : Threshold_Mode := Binary;
      Maximum_Value   : OpenCV.Float64_Value := 255.0)
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Threshold
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.C.double (Threshold_Value),
                 Interfaces.C.double (Maximum_Value),
                 To_C_Threshold_Mode (Mode));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      Validate_Threshold (Source, Threshold_Value, Maximum_Value);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "fixed threshold");
   end Apply_Threshold;

   procedure Apply_Automatic_Threshold
     (Source             : OpenCV.Core.Mat;
      Destination        : in out OpenCV.Core.Mat;
      Computed_Threshold : out OpenCV.Float64_Value;
      Method             : Automatic_Threshold_Method := Otsu;
      Mode               : Threshold_Mode := Binary;
      Maximum_Value      : OpenCV.Float64_Value := 255.0)
   is
      Status   : Internal.C_API.Status := Internal.C_API.Success;
      Computed : aliased Interfaces.C.double;

      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Automatic_Threshold
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.C.double (Maximum_Value),
                 To_C_Automatic_Threshold_Method (Method),
                 To_C_Threshold_Mode (Mode),
                 Computed'Access);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      Validate_Automatic_Threshold (Source, Method, Maximum_Value);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "automatic threshold");
      Computed_Threshold := OpenCV.Float64_Value (Computed);
   end Apply_Automatic_Threshold;

   procedure Apply_Adaptive_Threshold
     (Source        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Block_Size    : Adaptive_Block_Size;
      Method        : Adaptive_Threshold_Method := Mean;
      Mode          : Adaptive_Threshold_Mode := Binary;
      Bias          : OpenCV.Float64_Value := 0.0;
      Maximum_Value : OpenCV.UInt8_Value := 255)
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Adaptive_Threshold
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.Integer_32 (Maximum_Value),
                 To_C_Adaptive_Threshold_Method (Method),
                 To_C_Adaptive_Threshold_Mode (Mode),
                 Interfaces.Integer_32 (Block_Size),
                 Interfaces.C.double (Bias));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      Validate_Adaptive_Threshold (Source, Block_Size, Bias);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "adaptive threshold");
   end Apply_Adaptive_Threshold;

   procedure Equalize_Histogram
     (Source : OpenCV.Core.Mat; Destination : in out OpenCV.Core.Mat)
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;

      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Equalize_Histogram
                (Source_Handle, Destination_Handle);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      Validate_Equalize_Histogram (Source);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "histogram equalization");
   end Equalize_Histogram;

   procedure CLAHE
     (Source         : OpenCV.Core.Mat;
      Destination    : in out OpenCV.Core.Mat;
      Clip_Limit     : OpenCV.Float64_Value := 40.0;
      Tile_Grid_Size : OpenCV.Size := (Width => 8, Height => 8))
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;

      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.CLAHE
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.C.double (Clip_Limit),
                 Interfaces.Integer_32 (Tile_Grid_Size.Width),
                 Interfaces.Integer_32 (Tile_Grid_Size.Height));
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      Validate_CLAHE (Source, Clip_Limit, Tile_Grid_Size);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "CLAHE");
   end CLAHE;

   function Find_Contours
     (Source        : OpenCV.Core.Mat;
      Retrieval     : Contour_Retrieval_Mode := External_Only;
      Approximation : Contour_Approximation_Mode := Simple;
      Offset        : OpenCV.Point := (X => 0, Y => 0)) return Contour_Set
   is
      Result : aliased Internal.C_API.Contours_Handle :=
        Internal.C_API.Null_Contours_Handle;
      Status : Internal.C_API.Status := Internal.C_API.Success;
      Output : Contour_Set;
      use type Interfaces.Integer_32;

      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Find_Contours
             (Source_Handle,
              To_C_Contour_Retrieval (Retrieval),
              To_C_Contour_Approximation (Approximation),
              Interfaces.Integer_32 (Offset.X),
              Interfaces.Integer_32 (Offset.Y),
              Result'Access);
      end Input;

      Count : aliased Interfaces.Integer_32 := 0;
   begin
      Validate_Contour_Source (Source);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "find contours");

      begin
         Status := Internal.C_API.Contour_Count (Result, Count'Access);
         Raise_On_Error (Status, "get contour count");
         if Count > 0 then
            for Index in 0 .. Natural (Count) - 1 loop
               declare
                  Point_Count : aliased Interfaces.Integer_32 := 0;
                  Next        : aliased Interfaces.Integer_32 := -1;
                  Previous    : aliased Interfaces.Integer_32 := -1;
                  First_Child : aliased Interfaces.Integer_32 := -1;
                  Parent      : aliased Interfaces.Integer_32 := -1;
               begin
                  Status :=
                    Internal.C_API.Contour_Point_Count
                      (Result,
                       Interfaces.Integer_32 (Index),
                       Point_Count'Access);
                  Raise_On_Error (Status, "get contour point count");
                  if Point_Count = 0 then
                     declare
                        Empty_Points : Contour (1 .. 0);
                     begin
                        Output.Contours.Append (Empty_Points);
                     end;
                  else
                     declare
                        Raw_Points :
                          Internal.C_API.Point_I32_Array
                            (0 .. Natural (Point_Count) - 1);
                        Points     : Contour (Raw_Points'Range);
                     begin
                        Status :=
                          Internal.C_API.Contour_Copy_Points
                            (Result,
                             Interfaces.Integer_32 (Index),
                             Raw_Points (Raw_Points'First)'Access,
                             Point_Count);
                        Raise_On_Error (Status, "copy contour points");
                        for Point_Index in Points'Range loop
                           Points (Point_Index) :=
                             (X =>
                                OpenCV.Point_Coordinate
                                  (Raw_Points (Point_Index).X),
                              Y =>
                                OpenCV.Point_Coordinate
                                  (Raw_Points (Point_Index).Y));
                        end loop;
                        Output.Contours.Append (Points);
                     end;
                  end if;
                  Status :=
                    Internal.C_API.Contour_Hierarchy
                      (Result,
                       Interfaces.Integer_32 (Index),
                       Next'Access,
                       Previous'Access,
                       First_Child'Access,
                       Parent'Access);
                  Raise_On_Error (Status, "get contour hierarchy");
                  Output.Hierarchy.Append
                    ((Next        => To_Optional_Contour_Index (Next),
                      Previous    => To_Optional_Contour_Index (Previous),
                      First_Child => To_Optional_Contour_Index (First_Child),
                      Parent      => To_Optional_Contour_Index (Parent)));
               end;
            end loop;
         end if;
         Internal.C_API.Contours_Destroy (Result);
         return Output;
      exception
         when others =>
            Internal.C_API.Contours_Destroy (Result);
            raise;
      end;
   end Find_Contours;

   function Contour_Count (Self : Contour_Set) return Natural is
   begin
      return Natural (Self.Contours.Length);
   end Contour_Count;

   function Get_Contour
     (Self : Contour_Set; Index : Contour_Index) return Contour is
   begin
      Validate_Contour_Index (Self, Index, "Get_Contour");
      return Self.Contours.Element (Natural (Index));
   end Get_Contour;

   function Get_Hierarchy
     (Self : Contour_Set; Index : Contour_Index) return Contour_Hierarchy_Entry
   is
   begin
      Validate_Contour_Index (Self, Index, "Get_Hierarchy");
      return Self.Hierarchy.Element (Natural (Index));
   end Get_Hierarchy;

   procedure Connected_Components_With_Stats
     (Source       : OpenCV.Core.Mat;
      Labels       : in out OpenCV.Core.Mat;
      Components   : out Connected_Component_Set;
      Connectivity : Pixel_Connectivity := Eight_Connected)
   is
      Native_Stats     : OpenCV.Core.Mat;
      Native_Centroids : OpenCV.Core.Mat;
      Label_Count      : aliased Interfaces.Integer_32 := 0;
      Status           : Internal.C_API.Status := Internal.C_API.Success;
      Result           : Connected_Component_Set;

      use type Interfaces.Integer_32;

      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Label_Output
           (Label_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure Stats_Output
              (Stats_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
               procedure Centroids_Output
                 (Centroids_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    Internal.C_API.Connected_Components_With_Stats
                      (Source_Handle,
                       Label_Handle,
                       Stats_Handle,
                       Centroids_Handle,
                       To_C_Connectivity (Connectivity),
                       Label_Count'Access);
               end Centroids_Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Native_Centroids, Centroids_Output'Access);
            end Stats_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Native_Stats, Stats_Output'Access);
         end Label_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Labels, Label_Output'Access);
      end Input;
   begin
      Validate_Connected_Component_Source (Source);
      Validate_Connected_Component_Storage (Source, Labels);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      Raise_On_Error (Status, "connected components with statistics");

      if Label_Count <= 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "connected components returned an invalid label count");
      end if;

      for Label in 1 .. Natural (Label_Count) - 1 loop
         Result.Components.Append
           (Component_Statistics'
              (Bounds     =>
                 (X      =>
                    OpenCV.Point_Coordinate
                      (OpenCV.Core.Int32_Access.Get (Native_Stats, Label, 0)),
                  Y      =>
                    OpenCV.Point_Coordinate
                      (OpenCV.Core.Int32_Access.Get (Native_Stats, Label, 1)),
                  Width  =>
                    OpenCV.Size_Coordinate
                      (OpenCV.Core.Int32_Access.Get (Native_Stats, Label, 2)),
                  Height =>
                    OpenCV.Size_Coordinate
                      (OpenCV.Core.Int32_Access.Get (Native_Stats, Label, 3))),
               Area       =>
                 Natural
                   (OpenCV.Core.Int32_Access.Get (Native_Stats, Label, 4)),
               Centroid_X =>
                 OpenCV.Core.Float64_Access.Get (Native_Centroids, Label, 0),
               Centroid_Y =>
                 OpenCV.Core.Float64_Access.Get (Native_Centroids, Label, 1)));
      end loop;
      Components := Result;
   end Connected_Components_With_Stats;

   function Component_Count (Self : Connected_Component_Set) return Natural is
   begin
      return Natural (Self.Components.Length);
   end Component_Count;

   function Get_Component
     (Self : Connected_Component_Set; Label : Component_Label)
      return Component_Statistics
   is
      Count : constant Natural := Component_Count (Self);
   begin
      if Label = Background_Label or else Natural (Label) > Count then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Component requires a foreground label in 1 .."
            & " Component_Count");
      end if;
      return Self.Components.Element (Natural (Label) - 1);
   end Get_Component;

   function Is_Finite (Value : OpenCV.Float64_Value) return Boolean is
      use type OpenCV.Float64_Value;
   begin
      return
        Value = Value
        and then Value <= OpenCV.Float64_Value'Last
        and then Value >= OpenCV.Float64_Value'First;
   end Is_Finite;

   procedure Validate_Drawing_Image
     (Image : OpenCV.Core.Mat; Line_Style : Drawing_Line_Style)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Image.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "drawing requires a non-empty image");
      elsif Image.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "drawing requires a two-dimensional image");
      elsif Image.Channels > 4 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "drawing requires 1 to 4 channels");
      end if;

      case Image.Depth is
         when OpenCV.Core.UInt8
            | OpenCV.Core.UInt16
            | OpenCV.Core.Int16
            | OpenCV.Core.Float32
            | OpenCV.Core.Float64 =>
            null;

         when others              =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "drawing requires a UInt8, UInt16, Int16, Float32, or"
               & " Float64 image");
      end case;

      if Line_Style = Anti_Aliased_Line
        and then Image.Depth /= OpenCV.Core.UInt8
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Anti_Aliased_Line requires a UInt8 image");
      end if;
   end Validate_Drawing_Image;

   procedure Validate_Text_Image (Image : OpenCV.Core.Mat) is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Image.Is_Empty
        or else Image.Dimension_Count /= 2
        or else Image.Depth /= OpenCV.Core.UInt8
        or else (Image.Channels /= 1
                 and then Image.Channels /= 3
                 and then Image.Channels /= 4)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "text requires a nonempty 2-D UInt8 C1, C3 or C4 image");
      end if;
   end Validate_Text_Image;

   procedure Validate_Drawing_Color
     (Image : OpenCV.Core.Mat; Color : OpenCV.Scalar)
   is
      Components : constant array (0 .. 3) of OpenCV.Float64_Value :=
        (OpenCV.Float64_Value (Color.Component_0),
         OpenCV.Float64_Value (Color.Component_1),
         OpenCV.Float64_Value (Color.Component_2),
         OpenCV.Float64_Value (Color.Component_3));
   begin
      for Index in 0 .. Natural (Image.Channels) - 1 loop
         if not Is_Finite (Components (Index)) then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "drawing requires finite color components for every channel");
         end if;
      end loop;
   end Validate_Drawing_Color;

   function To_C_Line_Style
     (Line_Style : Drawing_Line_Style) return Interfaces.Integer_32 is
   begin
      case Line_Style is
         when Four_Connected_Line  =>
            return Internal.C_API.Drawing_Line_4;

         when Eight_Connected_Line =>
            return Internal.C_API.Drawing_Line_8;

         when Anti_Aliased_Line    =>
            return Internal.C_API.Drawing_Line_AA;
      end case;
   end To_C_Line_Style;

   package Selected_Contour_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Natural,
        Element_Type => Contour_Index);

   procedure Render_Contours
     (Image             : in out OpenCV.Core.Mat;
      Contours          : Contour_Set;
      Color             : OpenCV.Scalar;
      Filled            : Boolean;
      Thickness         : Drawing_Thickness;
      Line_Style        : Drawing_Line_Style;
      Offset            : OpenCV.Point;
      Selected_Root     : Boolean;
      Root              : Contour_Index;
      Descendant_Levels : Natural)
   is
      use type Ada.Containers.Count_Type;
      use type Interfaces.Integer_64;

      Selected : Selected_Contour_Vectors.Vector;
      Total    : Interfaces.Integer_64 := 0;
      Count    : Interfaces.Integer_64 := 0;
      Limit    : constant Interfaces.Integer_64 :=
        Interfaces.Integer_64 (Interfaces.Integer_32'Last);

      procedure Bad_Hierarchy is
      begin
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "inconsistent contour hierarchy");
      end Bad_Hierarchy;

      procedure Visit (Index : Contour_Index; Levels : Natural) is
         Node : Contour_Hierarchy_Entry;
      begin
         if Ada.Containers.Count_Type (Index) >= Contours.Contours.Length
           or else Ada.Containers.Count_Type (Index)
                   >= Contours.Hierarchy.Length
         then
            Bad_Hierarchy;
         end if;
         for Existing of Selected loop
            if Existing = Index then
               Bad_Hierarchy;
            end if;
         end loop;
         Selected.Append (Index);
         if Levels = 0 then
            return;
         end if;
         Node := Contours.Hierarchy.Element (Natural (Index));
         declare
            Child : Optional_Contour_Index := Node.First_Child;
         begin
            while Child.Present loop
               if Ada.Containers.Count_Type (Child.Index)
                 >= Contours.Hierarchy.Length
                 or else Ada.Containers.Count_Type (Child.Index)
                         >= Contours.Contours.Length
               then
                  Bad_Hierarchy;
               end if;
               declare
                  Child_Entry : constant Contour_Hierarchy_Entry :=
                    Contours.Hierarchy.Element (Natural (Child.Index));
               begin
                  if not Child_Entry.Parent.Present
                    or else Child_Entry.Parent.Index /= Index
                  then
                     Bad_Hierarchy;
                  end if;
                  Visit (Child.Index, Levels - 1);
                  Child := Child_Entry.Next;
               end;
            end loop;
         end;
      end Visit;

      type Point_Buffer is access Internal.C_API.Point_I32_Array;
      type Span_Buffer is access Internal.C_API.Contour_Span_Array;
      procedure Free is new
        Ada.Unchecked_Deallocation
          (Internal.C_API.Point_I32_Array,
           Point_Buffer);
      procedure Free is new
        Ada.Unchecked_Deallocation
          (Internal.C_API.Contour_Span_Array,
           Span_Buffer);
      Points : Point_Buffer := null;
      Spans  : Span_Buffer := null;
      Status : Internal.C_API.Status;

      procedure Invoke (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
      begin
         Status :=
           Internal.C_API.Draw_Contours
             (Handle,
              Points (0)'Access,
              Interfaces.Integer_32 (Total),
              Spans (0)'Access,
              Interfaces.Integer_32 (Count),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              (if Filled then 1 else 0),
              Interfaces.Integer_32 (Thickness),
              To_C_Line_Style (Line_Style),
              Interfaces.Integer_32 (Offset.X),
              Interfaces.Integer_32 (Offset.Y));
      end Invoke;
   begin
      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      if Selected_Root then
         Validate_Contour_Index (Contours, Root, "Draw_Contours");
         Visit (Root, Descendant_Levels);
      else
         if not Contours.Contours.Is_Empty then
            for Index in 0 .. Natural (Contours.Contours.Length) - 1 loop
               Selected.Append (Contour_Index (Index));
            end loop;
         end if;
      end if;

      for Index of Selected loop
         declare
            Length : constant Interfaces.Integer_64 :=
              Interfaces.Integer_64
                (Contours.Contours.Element (Natural (Index))'Length);
         begin
            if Length > 0 then
               if Count >= Limit or else Length > Limit - Total then
                  Ada.Exceptions.Raise_Exception
                    (OpenCV.OpenCV_Error'Identity,
                     "contour point or contour count exceeds signed int");
               end if;
               Total := Total + Length;
               Count := Count + 1;
            end if;
         end;
      end loop;
      if Count = 0 then
         return;
      end if;

      Points := new Internal.C_API.Point_I32_Array (0 .. Natural (Total) - 1);
      Spans :=
        new Internal.C_API.Contour_Span_Array (0 .. Natural (Count) - 1);
      declare
         Position : Natural := 0;
         Span     : Natural := 0;
      begin
         for Index of Selected loop
            declare
               Shape : constant Contour :=
                 Contours.Contours.Element (Natural (Index));
            begin
               if Shape'Length > 0 then
                  Spans (Span) :=
                    (Interfaces.Integer_32 (Position),
                     Interfaces.Integer_32 (Shape'Length));
                  Span := Span + 1;
                  for Item of Shape loop
                     Points (Position) :=
                       (Interfaces.Integer_32 (Item.X),
                        Interfaces.Integer_32 (Item.Y));
                     Position := Position + 1;
                  end loop;
               end if;
            end;
         end loop;
      end;
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Invoke'Access);
      Raise_On_Error (Status, "Draw_Contours");
      Free (Points);
      Free (Spans);
   exception
      when others =>
         Free (Points);
         Free (Spans);
         raise;
   end Render_Contours;

   procedure Draw_Contours
     (Image      : in out OpenCV.Core.Mat;
      Contours   : Contour_Set;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line;
      Offset     : OpenCV.Point := (X => 0, Y => 0)) is
   begin
      Render_Contours
        (Image,
         Contours,
         Color,
         False,
         Thickness,
         Line_Style,
         Offset,
         False,
         0,
         0);
   end Draw_Contours;

   procedure Draw_Contours
     (Image             : in out OpenCV.Core.Mat;
      Contours          : Contour_Set;
      Root              : Contour_Index;
      Color             : OpenCV.Scalar;
      Descendant_Levels : Natural := 0;
      Thickness         : Drawing_Thickness := 1;
      Line_Style        : Drawing_Line_Style := Eight_Connected_Line;
      Offset            : OpenCV.Point := (X => 0, Y => 0)) is
   begin
      Render_Contours
        (Image,
         Contours,
         Color,
         False,
         Thickness,
         Line_Style,
         Offset,
         True,
         Root,
         Descendant_Levels);
   end Draw_Contours;

   procedure Fill_Contours
     (Image      : in out OpenCV.Core.Mat;
      Contours   : Contour_Set;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line;
      Offset     : OpenCV.Point := (X => 0, Y => 0)) is
   begin
      Render_Contours
        (Image, Contours, Color, True, 1, Line_Style, Offset, False, 0, 0);
   end Fill_Contours;

   procedure Fill_Contours
     (Image             : in out OpenCV.Core.Mat;
      Contours          : Contour_Set;
      Root              : Contour_Index;
      Color             : OpenCV.Scalar;
      Descendant_Levels : Natural := 0;
      Line_Style        : Drawing_Line_Style := Eight_Connected_Line;
      Offset            : OpenCV.Point := (X => 0, Y => 0)) is
   begin
      Render_Contours
        (Image,
         Contours,
         Color,
         True,
         1,
         Line_Style,
         Offset,
         True,
         Root,
         Descendant_Levels);
   end Fill_Contours;

   function To_Degrees
     (Angle : OpenCV.Float64_Value; Units : OpenCV.Angle_Unit)
      return OpenCV.Float64_Value
   is
      use type OpenCV.Float64_Value;
   begin
      if Units = OpenCV.Degrees then
         return Angle;
      end if;

      return
        Angle
        * (OpenCV.Float64_Value (180.0)
           / OpenCV.Float64_Value (Ada.Numerics.Pi));
   end To_Degrees;

   procedure Validate_Drawing_Angles
     (Angle, Start_Angle, End_Angle : OpenCV.Float64_Value) is
   begin
      if not Is_Finite (Angle)
        or else not Is_Finite (Start_Angle)
        or else not Is_Finite (End_Angle)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "drawing ellipse angles must be finite");
      end if;
   end Validate_Drawing_Angles;

   function To_C_Points
     (Points : OpenCV.Point_Array) return Internal.C_API.Point_I32_Array
   is
      Result : Internal.C_API.Point_I32_Array (0 .. Points'Length - 1);
      Index  : Natural := 0;
   begin
      for Point of Points loop
         Result (Index) :=
           (X => Interfaces.Integer_32 (Point.X),
            Y => Interfaces.Integer_32 (Point.Y));
         Index := Index + 1;
      end loop;
      return Result;
   end To_C_Points;

   procedure Draw_Line
     (Image      : in out OpenCV.Core.Mat;
      Start      : OpenCV.Point;
      Finish     : OpenCV.Point;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line)
   is
      Status : Internal.C_API.Status;

      procedure Draw
        (Image_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Draw_Line
             (Image_Handle,
              Interfaces.Integer_32 (Start.X),
              Interfaces.Integer_32 (Start.Y),
              Interfaces.Integer_32 (Finish.X),
              Interfaces.Integer_32 (Finish.Y),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              Interfaces.Integer_32 (Thickness),
              To_C_Line_Style (Line_Style));
      end Draw;
   begin
      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, "Draw_Line");
   end Draw_Line;

   function Font_Selector (Font : Text_Font) return Interfaces.Integer_32
   is (Interfaces.Integer_32 (Text_Font'Pos (Font)));

   function C_Boolean (Value : Boolean) return Interfaces.Unsigned_8
   is (if Value then 1 else 0);

   procedure Validate_Text_Scale (Scale : OpenCV.Float64_Value) is
      use type OpenCV.Float64_Value;
   begin
      if not Is_Finite (Scale) or else Scale <= 0.0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "text scale must be finite and positive");
      end if;
   end Validate_Text_Scale;

   function Text_Address (Text : String) return System.Address
   is (if Text'Length = 0
       then System.Null_Address
       else Text (Text'First)'Address);

   function Text_Length (Text : String) return Interfaces.Integer_32 is
   begin
      if Long_Long_Integer (Text'Length)
        > Long_Long_Integer (Interfaces.Integer_32'Last)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "text length exceeds C ABI range");
      end if;
      return Interfaces.Integer_32 (Text'Length);
   end Text_Length;

   procedure Draw_Arrow
     (Image         : in out OpenCV.Core.Mat;
      Start, Finish : OpenCV.Point;
      Color         : OpenCV.Scalar;
      Tip_Length    : OpenCV.Float64_Value := 0.1;
      Thickness     : Drawing_Thickness := 1;
      Line_Style    : Drawing_Line_Style := Eight_Connected_Line)
   is
      Status : Internal.C_API.Status;
      use type OpenCV.Float64_Value;
      procedure Draw (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Draw_Arrow
             (Handle,
              Interfaces.Integer_32 (Start.X),
              Interfaces.Integer_32 (Start.Y),
              Interfaces.Integer_32 (Finish.X),
              Interfaces.Integer_32 (Finish.Y),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              Interfaces.C.double (Tip_Length),
              Interfaces.Integer_32 (Thickness),
              To_C_Line_Style (Line_Style));
      end Draw;
   begin
      if not Is_Finite (Tip_Length)
        or else Tip_Length <= 0.0
        or else Tip_Length > 1.0
        or else Start = Finish
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "arrow requires distinct endpoints and tip in (0, 1]");
      end if;
      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, "Draw_Arrow");
   end Draw_Arrow;

   procedure Draw_Marker
     (Image       : in out OpenCV.Core.Mat;
      Position    : OpenCV.Point;
      Color       : OpenCV.Scalar;
      Kind        : Drawing_Marker_Kind := Cross_Marker;
      Marker_Size : Positive := 20;
      Thickness   : Drawing_Thickness := 1;
      Line_Style  : Drawing_Line_Style := Eight_Connected_Line)
   is
      Status : Internal.C_API.Status;
      procedure Draw (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Draw_Marker
             (Handle,
              Interfaces.Integer_32 (Position.X),
              Interfaces.Integer_32 (Position.Y),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              Interfaces.Integer_32 (Drawing_Marker_Kind'Pos (Kind)),
              Interfaces.Integer_32 (Marker_Size),
              Interfaces.Integer_32 (Thickness),
              To_C_Line_Style (Line_Style));
      end Draw;
   begin
      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, "Draw_Marker");
   end Draw_Marker;

   procedure Draw_Text
     (Image              : in out OpenCV.Core.Mat;
      Text               : String;
      Origin             : OpenCV.Point;
      Color              : OpenCV.Scalar;
      Font               : Text_Font := Hershey_Simplex;
      Font_Scale         : OpenCV.Float64_Value := 1.0;
      Thickness          : Drawing_Thickness := 1;
      Bottom_Left_Origin : Boolean := False)
   is
      Status : Internal.C_API.Status;
      Length : constant Interfaces.Integer_32 := Text_Length (Text);
      procedure Draw (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Draw_Text
             (Handle,
              Text_Address (Text),
              Length,
              Interfaces.Integer_32 (Origin.X),
              Interfaces.Integer_32 (Origin.Y),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              Font_Selector (Font),
              Interfaces.C.double (Font_Scale),
              Interfaces.Integer_32 (Thickness),
              C_Boolean (Bottom_Left_Origin));
      end Draw;
   begin
      Validate_Text_Scale (Font_Scale);
      Validate_Text_Image (Image);
      Validate_Drawing_Color (Image, Color);
      if Text'Length = 0 then
         return;
      end if;
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, "Draw_Text");
   end Draw_Text;

   function Measure_Text
     (Text       : String;
      Font       : Text_Font := Hershey_Simplex;
      Font_Scale : OpenCV.Float64_Value := 1.0;
      Thickness  : Drawing_Thickness := 1) return Text_Metrics
   is
      Width, Height, Baseline : aliased Interfaces.Integer_32 := 0;
      Status                  : Internal.C_API.Status;
   begin
      Validate_Text_Scale (Font_Scale);
      if Text'Length = 0 then
         return (Size => (Width => 0, Height => 0), Baseline => 0);
      end if;
      Status :=
        Internal.C_API.Measure_Text
          (Text_Address (Text),
           Text_Length (Text),
           Font_Selector (Font),
           Interfaces.C.double (Font_Scale),
           Interfaces.Integer_32 (Thickness),
           Width'Access,
           Height'Access,
           Baseline'Access);
      Raise_On_Error (Status, "Measure_Text");
      return
        (Size     =>
           (Width  => OpenCV.Size_Coordinate (Width),
            Height => OpenCV.Size_Coordinate (Height)),
         Baseline => Natural (Baseline));
   end Measure_Text;

   function Font_Scale_For_Height
     (Pixel_Height : Positive;
      Font         : Text_Font := Hershey_Simplex;
      Thickness    : Drawing_Thickness := 1) return OpenCV.Float64_Value
   is
      Scale  : aliased Interfaces.C.double := 0.0;
      Status : Internal.C_API.Status;
   begin
      if 2 * Long_Long_Integer (Pixel_Height)
        <= Long_Long_Integer (Thickness) + 1
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "requested height cannot yield a positive portable text scale");
      end if;
      Status :=
        Internal.C_API.Font_Scale_For_Height
          (Interfaces.Integer_32 (Pixel_Height),
           Font_Selector (Font),
           Interfaces.Integer_32 (Thickness),
           Scale'Access);
      Raise_On_Error (Status, "Font_Scale_For_Height");
      return OpenCV.Float64_Value (Scale);
   end Font_Scale_For_Height;

   procedure Draw_Or_Fill_Rectangle
     (Image      : in out OpenCV.Core.Mat;
      Bounds     : OpenCV.Rect;
      Color      : OpenCV.Scalar;
      Filled     : Boolean;
      Thickness  : Drawing_Thickness;
      Line_Style : Drawing_Line_Style;
      Operation  : String)
   is
      Status : Internal.C_API.Status;

      procedure Draw
        (Image_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Draw_Rectangle
             (Image_Handle,
              Interfaces.Integer_32 (Bounds.X),
              Interfaces.Integer_32 (Bounds.Y),
              Interfaces.Integer_32 (Bounds.Width),
              Interfaces.Integer_32 (Bounds.Height),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              (if Filled
               then Internal.C_API.Drawing_Filled
               else Internal.C_API.Drawing_Outline),
              Interfaces.Integer_32 (Thickness),
              To_C_Line_Style (Line_Style));
      end Draw;
   begin
      if Bounds.Width = 0 or else Bounds.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "drawing rectangle width and height must be positive");
      end if;

      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, Operation);
   end Draw_Or_Fill_Rectangle;

   procedure Draw_Rectangle
     (Image      : in out OpenCV.Core.Mat;
      Bounds     : OpenCV.Rect;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line) is
   begin
      Draw_Or_Fill_Rectangle
        (Image, Bounds, Color, False, Thickness, Line_Style, "Draw_Rectangle");
   end Draw_Rectangle;

   procedure Fill_Rectangle
     (Image      : in out OpenCV.Core.Mat;
      Bounds     : OpenCV.Rect;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line) is
   begin
      Draw_Or_Fill_Rectangle
        (Image, Bounds, Color, True, 1, Line_Style, "Fill_Rectangle");
   end Fill_Rectangle;

   procedure Draw_Or_Fill_Circle
     (Image      : in out OpenCV.Core.Mat;
      Center     : OpenCV.Point;
      Radius     : Drawing_Radius;
      Color      : OpenCV.Scalar;
      Filled     : Boolean;
      Thickness  : Drawing_Thickness;
      Line_Style : Drawing_Line_Style;
      Operation  : String)
   is
      Status : Internal.C_API.Status;

      procedure Draw
        (Image_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Draw_Circle
             (Image_Handle,
              Interfaces.Integer_32 (Center.X),
              Interfaces.Integer_32 (Center.Y),
              Interfaces.Integer_32 (Radius),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              (if Filled
               then Internal.C_API.Drawing_Filled
               else Internal.C_API.Drawing_Outline),
              Interfaces.Integer_32 (Thickness),
              To_C_Line_Style (Line_Style));
      end Draw;
   begin
      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, Operation);
   end Draw_Or_Fill_Circle;

   procedure Draw_Circle
     (Image      : in out OpenCV.Core.Mat;
      Center     : OpenCV.Point;
      Radius     : Drawing_Radius;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line) is
   begin
      Draw_Or_Fill_Circle
        (Image,
         Center,
         Radius,
         Color,
         False,
         Thickness,
         Line_Style,
         "Draw_Circle");
   end Draw_Circle;

   procedure Fill_Circle
     (Image      : in out OpenCV.Core.Mat;
      Center     : OpenCV.Point;
      Radius     : Drawing_Radius;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line) is
   begin
      Draw_Or_Fill_Circle
        (Image, Center, Radius, Color, True, 1, Line_Style, "Fill_Circle");
   end Fill_Circle;

   procedure Draw_Or_Fill_Ellipse
     (Image       : in out OpenCV.Core.Mat;
      Center      : OpenCV.Point;
      Axes        : OpenCV.Size;
      Angle       : OpenCV.Float64_Value;
      Start_Angle : OpenCV.Float64_Value;
      End_Angle   : OpenCV.Float64_Value;
      Color       : OpenCV.Scalar;
      Filled      : Boolean;
      Thickness   : Drawing_Thickness;
      Line_Style  : Drawing_Line_Style;
      Units       : OpenCV.Angle_Unit;
      Operation   : String)
   is
      Degrees_Angle : OpenCV.Float64_Value;
      Degrees_Start : OpenCV.Float64_Value;
      Degrees_End   : OpenCV.Float64_Value;
      Status        : Internal.C_API.Status;

      procedure Draw
        (Image_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Draw_Ellipse
             (Image_Handle,
              Interfaces.Integer_32 (Center.X),
              Interfaces.Integer_32 (Center.Y),
              Interfaces.Integer_32 (Axes.Width),
              Interfaces.Integer_32 (Axes.Height),
              Interfaces.C.double (Degrees_Angle),
              Interfaces.C.double (Degrees_Start),
              Interfaces.C.double (Degrees_End),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              (if Filled
               then Internal.C_API.Drawing_Filled
               else Internal.C_API.Drawing_Outline),
              Interfaces.Integer_32 (Thickness),
              To_C_Line_Style (Line_Style));
      end Draw;
   begin
      if Axes.Width = 0 or else Axes.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "drawing ellipse axes must be positive");
      end if;

      Validate_Drawing_Angles (Angle, Start_Angle, End_Angle);
      Degrees_Angle := To_Degrees (Angle, Units);
      Degrees_Start := To_Degrees (Start_Angle, Units);
      Degrees_End := To_Degrees (End_Angle, Units);
      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, Operation);
   end Draw_Or_Fill_Ellipse;

   procedure Draw_Ellipse
     (Image       : in out OpenCV.Core.Mat;
      Center      : OpenCV.Point;
      Axes        : OpenCV.Size;
      Angle       : OpenCV.Float64_Value;
      Start_Angle : OpenCV.Float64_Value;
      End_Angle   : OpenCV.Float64_Value;
      Color       : OpenCV.Scalar;
      Thickness   : Drawing_Thickness := 1;
      Line_Style  : Drawing_Line_Style := Eight_Connected_Line;
      Units       : OpenCV.Angle_Unit := OpenCV.Degrees) is
   begin
      Draw_Or_Fill_Ellipse
        (Image,
         Center,
         Axes,
         Angle,
         Start_Angle,
         End_Angle,
         Color,
         False,
         Thickness,
         Line_Style,
         Units,
         "Draw_Ellipse");
   end Draw_Ellipse;

   procedure Fill_Ellipse
     (Image       : in out OpenCV.Core.Mat;
      Center      : OpenCV.Point;
      Axes        : OpenCV.Size;
      Angle       : OpenCV.Float64_Value;
      Start_Angle : OpenCV.Float64_Value;
      End_Angle   : OpenCV.Float64_Value;
      Color       : OpenCV.Scalar;
      Line_Style  : Drawing_Line_Style := Eight_Connected_Line;
      Units       : OpenCV.Angle_Unit := OpenCV.Degrees) is
   begin
      Draw_Or_Fill_Ellipse
        (Image,
         Center,
         Axes,
         Angle,
         Start_Angle,
         End_Angle,
         Color,
         True,
         1,
         Line_Style,
         Units,
         "Fill_Ellipse");
   end Fill_Ellipse;

   procedure Draw_Polyline
     (Image      : in out OpenCV.Core.Mat;
      Points     : OpenCV.Point_Array;
      Closed     : Boolean := False;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line)
   is
      Status : Internal.C_API.Status;

      procedure Draw
        (Image_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
         Native : constant Internal.C_API.Point_I32_Array :=
           To_C_Points (Points);
      begin
         Status :=
           Internal.C_API.Draw_Polyline
             (Image_Handle,
              Native (Native'First)'Access,
              Interfaces.Integer_32 (Native'Length),
              (if Closed then 1 else 0),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              Interfaces.Integer_32 (Thickness),
              To_C_Line_Style (Line_Style));
      end Draw;
   begin
      if Points'Length < 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Draw_Polyline requires at least two points");
      end if;

      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, "Draw_Polyline");
   end Draw_Polyline;

   procedure Fill_Polygon
     (Image      : in out OpenCV.Core.Mat;
      Points     : OpenCV.Point_Array;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line)
   is
      Status : Internal.C_API.Status;

      procedure Draw
        (Image_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
         Native : constant Internal.C_API.Point_I32_Array :=
           To_C_Points (Points);
      begin
         Status :=
           Internal.C_API.Fill_Polygon
             (Image_Handle,
              Native (Native'First)'Access,
              Interfaces.Integer_32 (Native'Length),
              Interfaces.C.double (Color.Component_0),
              Interfaces.C.double (Color.Component_1),
              Interfaces.C.double (Color.Component_2),
              Interfaces.C.double (Color.Component_3),
              To_C_Line_Style (Line_Style));
      end Draw;
   begin
      if Points'Length < 3 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fill_Polygon requires at least three points");
      end if;

      Validate_Drawing_Image (Image, Line_Style);
      Validate_Drawing_Color (Image, Color);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Draw'Access);
      Raise_On_Error (Status, "Fill_Polygon");
   end Fill_Polygon;

   --  Each Release destroys a native Hough result and clears the handle, so
   --  a later exception handler cannot free it twice. Destroy accepts null.
   procedure Release_Hough_Lines
     (Result : in out Internal.C_API.Hough_Lines_Handle) is
   begin
      Internal.C_API.Hough_Lines_Destroy (Result);
      Result := Internal.C_API.Null_Hough_Lines_Handle;
   end Release_Hough_Lines;

   procedure Release_Hough_Segments
     (Result : in out Internal.C_API.Hough_Segments_Handle) is
   begin
      Internal.C_API.Hough_Segments_Destroy (Result);
      Result := Internal.C_API.Null_Hough_Segments_Handle;
   end Release_Hough_Segments;

   procedure Release_Hough_Circles
     (Result : in out Internal.C_API.Hough_Circles_Handle) is
   begin
      Internal.C_API.Hough_Circles_Destroy (Result);
      Result := Internal.C_API.Null_Hough_Circles_Handle;
   end Release_Hough_Circles;

   procedure Raise_Hough_Error (Operation, Message : String) is
   begin
      Ada.Exceptions.Raise_Exception
        (OpenCV.OpenCV_Error'Identity, Operation & " " & Message);
   end Raise_Hough_Error;

   procedure Validate_Hough_Source
     (Source : OpenCV.Core.Mat; Operation : String)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty then
         Raise_Hough_Error (Operation, "requires a non-empty source Mat");
      elsif Source.Dimension_Count /= 2 then
         Raise_Hough_Error
           (Operation, "requires a two-dimensional source Mat");
      elsif Source.Depth /= OpenCV.Core.UInt8 then
         Raise_Hough_Error (Operation, "requires a UInt8 source Mat");
      elsif Source.Channels /= 1 then
         Raise_Hough_Error (Operation, "requires a single-channel source Mat");
      end if;
   end Validate_Hough_Source;

   procedure Validate_Hough_Resolutions
     (Distance_Resolution      : OpenCV.Float64_Value;
      Angle_Resolution_Radians : OpenCV.Float64_Value;
      Operation                : String)
   is
      use type OpenCV.Float64_Value;
   begin
      if not Is_Finite (Distance_Resolution) or else Distance_Resolution <= 0.0
      then
         Raise_Hough_Error
           (Operation, "requires a positive finite distance resolution");
      elsif not Is_Finite (Angle_Resolution_Radians)
        or else Angle_Resolution_Radians <= 0.0
      then
         Raise_Hough_Error
           (Operation, "requires a positive finite angle resolution");
      end if;
   end Validate_Hough_Resolutions;

   procedure Validate_Hough_Angle_Bounds
     (Minimum_Angle_Radians : OpenCV.Float64_Value;
      Maximum_Angle_Radians : OpenCV.Float64_Value;
      Operation             : String)
   is
      use type OpenCV.Float64_Value;
   begin
      if not Is_Finite (Minimum_Angle_Radians)
        or else not Is_Finite (Maximum_Angle_Radians)
      then
         Raise_Hough_Error (Operation, "requires finite angle bounds");
      elsif Minimum_Angle_Radians < 0.0
        or else Maximum_Angle_Radians > Ada.Numerics.Pi
        or else Minimum_Angle_Radians >= Maximum_Angle_Radians
      then
         Raise_Hough_Error
           (Operation, "requires 0 <= Minimum_Angle < Maximum_Angle <= Pi");
      end if;
   end Validate_Hough_Angle_Bounds;

   function Find_Hough_Lines
     (Source                   : OpenCV.Core.Mat;
      Distance_Resolution      : OpenCV.Float64_Value;
      Angle_Resolution_Radians : OpenCV.Float64_Value;
      Vote_Threshold           : Hough_Vote_Threshold;
      Minimum_Angle_Radians    : OpenCV.Float64_Value := 0.0;
      Maximum_Angle_Radians    : OpenCV.Float64_Value := Ada.Numerics.Pi)
      return Hough_Line_Array
   is
      use type Interfaces.Integer_32;

      Operation : constant String := "Find_Hough_Lines";
      Result    : aliased Internal.C_API.Hough_Lines_Handle :=
        Internal.C_API.Null_Hough_Lines_Handle;
      Status    : Internal.C_API.Status := Internal.C_API.Success;
      Count     : aliased Interfaces.Integer_32 := 0;

      procedure Detect
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Hough_Lines
             (Source_Handle,
              Interfaces.C.double (Distance_Resolution),
              Interfaces.C.double (Angle_Resolution_Radians),
              Interfaces.Integer_32 (Vote_Threshold),
              Interfaces.C.double (Minimum_Angle_Radians),
              Interfaces.C.double (Maximum_Angle_Radians),
              Result'Access);
      end Detect;
   begin
      Validate_Hough_Source (Source, Operation);
      Validate_Hough_Resolutions
        (Distance_Resolution, Angle_Resolution_Radians, Operation);
      Validate_Hough_Angle_Bounds
        (Minimum_Angle_Radians, Maximum_Angle_Radians, Operation);

      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Detect'Access);
      Raise_On_Error (Status, Operation);

      begin
         Raise_On_Error
           (Internal.C_API.Hough_Lines_Count (Result, Count'Access),
            Operation);
         if Count <= 0 then
            Release_Hough_Lines (Result);
            return Empty : Hough_Line_Array (1 .. 0);
         end if;

         declare
            Raw    :
              Internal.C_API.Hough_Line_Record_Array
                (0 .. Natural (Count) - 1);
            Output : Hough_Line_Array (Raw'Range);
         begin
            Raise_On_Error
              (Internal.C_API.Hough_Lines_Copy
                 (Result, Raw (Raw'First)'Access, Count),
               Operation);
            for Index in Raw'Range loop
               Output (Index) :=
                 (Rho           => OpenCV.Float32_Value (Raw (Index).Rho),
                  Angle_Radians => OpenCV.Float32_Value (Raw (Index).Theta));
            end loop;
            Release_Hough_Lines (Result);
            return Output;
         end;
      exception
         when others =>
            Release_Hough_Lines (Result);
            raise;
      end;
   end Find_Hough_Lines;

   function Find_Hough_Line_Segments
     (Source                   : OpenCV.Core.Mat;
      Distance_Resolution      : OpenCV.Float64_Value;
      Angle_Resolution_Radians : OpenCV.Float64_Value;
      Vote_Threshold           : Hough_Vote_Threshold;
      Minimum_Line_Length      : OpenCV.Size_Coordinate := 0;
      Maximum_Line_Gap         : OpenCV.Size_Coordinate := 0)
      return Hough_Line_Segment_Array
   is
      use type Interfaces.Integer_32;

      Operation : constant String := "Find_Hough_Line_Segments";
      Result    : aliased Internal.C_API.Hough_Segments_Handle :=
        Internal.C_API.Null_Hough_Segments_Handle;
      Status    : Internal.C_API.Status := Internal.C_API.Success;
      Count     : aliased Interfaces.Integer_32 := 0;

      procedure Detect
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Hough_Segments
             (Source_Handle,
              Interfaces.C.double (Distance_Resolution),
              Interfaces.C.double (Angle_Resolution_Radians),
              Interfaces.Integer_32 (Vote_Threshold),
              Interfaces.Integer_32 (Minimum_Line_Length),
              Interfaces.Integer_32 (Maximum_Line_Gap),
              Result'Access);
      end Detect;
   begin
      Validate_Hough_Source (Source, Operation);
      Validate_Hough_Resolutions
        (Distance_Resolution, Angle_Resolution_Radians, Operation);

      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Detect'Access);
      Raise_On_Error (Status, Operation);

      begin
         Raise_On_Error
           (Internal.C_API.Hough_Segments_Count (Result, Count'Access),
            Operation);
         if Count <= 0 then
            Release_Hough_Segments (Result);
            return Empty : Hough_Line_Segment_Array (1 .. 0);
         end if;

         declare
            Raw    :
              Internal.C_API.Hough_Segment_Record_Array
                (0 .. Natural (Count) - 1);
            Output : Hough_Line_Segment_Array (Raw'Range);
         begin
            Raise_On_Error
              (Internal.C_API.Hough_Segments_Copy
                 (Result, Raw (Raw'First)'Access, Count),
               Operation);
            for Index in Raw'Range loop
               Output (Index) :=
                 (Start_Point =>
                    (X => OpenCV.Point_Coordinate (Raw (Index).X1),
                     Y => OpenCV.Point_Coordinate (Raw (Index).Y1)),
                  End_Point   =>
                    (X => OpenCV.Point_Coordinate (Raw (Index).X2),
                     Y => OpenCV.Point_Coordinate (Raw (Index).Y2)));
            end loop;
            Release_Hough_Segments (Result);
            return Output;
         end;
      exception
         when others =>
            Release_Hough_Segments (Result);
            raise;
      end;
   end Find_Hough_Line_Segments;

   --  Public argument contract shared by every gradient-circle operation.
   procedure Validate_Hough_Circle_Arguments
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Operation               : String)
   is
      use type OpenCV.Float64_Value;
   begin
      Validate_Hough_Source (Source, Operation);
      if not Is_Finite (Accumulator_Scale) or else Accumulator_Scale < 1.0 then
         Raise_Hough_Error
           (Operation, "requires a finite Accumulator_Scale >= 1.0");
      elsif not Is_Finite (Minimum_Center_Distance)
        or else Minimum_Center_Distance <= 0.0
      then
         Raise_Hough_Error
           (Operation, "requires a positive finite Minimum_Center_Distance");
      end if;
   end Validate_Hough_Circle_Arguments;

   function Detect_Hough_Circles
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate;
      Radius_Mode             : Interfaces.Integer_32;
      Maximum_Radius          : OpenCV.Size_Coordinate;
      Operation               : String := "Find_Hough_Circles")
      return Hough_Circle_Array
   is
      use type Interfaces.Integer_32;

      Result : aliased Internal.C_API.Hough_Circles_Handle :=
        Internal.C_API.Null_Hough_Circles_Handle;
      Status : Internal.C_API.Status := Internal.C_API.Success;
      Count  : aliased Interfaces.Integer_32 := 0;

      procedure Detect
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Hough_Circles
             (Source_Handle,
              Interfaces.C.double (Accumulator_Scale),
              Interfaces.C.double (Minimum_Center_Distance),
              Interfaces.Integer_32 (Canny_Threshold),
              Interfaces.Integer_32 (Accumulator_Threshold),
              Radius_Mode,
              Interfaces.Integer_32 (Minimum_Radius),
              Interfaces.Integer_32 (Maximum_Radius),
              Result'Access);
      end Detect;
   begin
      Validate_Hough_Circle_Arguments
        (Source, Accumulator_Scale, Minimum_Center_Distance, Operation);

      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Detect'Access);
      Raise_On_Error (Status, Operation);

      begin
         Raise_On_Error
           (Internal.C_API.Hough_Circles_Count (Result, Count'Access),
            Operation);
         if Count <= 0 then
            Release_Hough_Circles (Result);
            return Empty : Hough_Circle_Array (1 .. 0);
         end if;

         declare
            Raw    :
              Internal.C_API.Hough_Circle_Record_Array
                (0 .. Natural (Count) - 1);
            Output : Hough_Circle_Array (Raw'Range);
         begin
            Raise_On_Error
              (Internal.C_API.Hough_Circles_Copy
                 (Result, Raw (Raw'First)'Access, Count),
               Operation);
            for Index in Raw'Range loop
               Output (Index) :=
                 (Center =>
                    (X => OpenCV.Float32_Value (Raw (Index).X),
                     Y => OpenCV.Float32_Value (Raw (Index).Y)),
                  Radius => OpenCV.Float32_Value (Raw (Index).Radius));
            end loop;
            Release_Hough_Circles (Result);
            return Output;
         end;
      exception
         when others =>
            Release_Hough_Circles (Result);
            raise;
      end;
   end Detect_Hough_Circles;

   function Find_Hough_Circles
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0)
      return Hough_Circle_Array is
   begin
      return
        Detect_Hough_Circles
          (Source,
           Accumulator_Scale,
           Minimum_Center_Distance,
           Canny_Threshold,
           Accumulator_Threshold,
           Minimum_Radius,
           Internal.C_API.Hough_Radius_Automatic,
           0);
   end Find_Hough_Circles;

   function Find_Hough_Circles
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0;
      Maximum_Radius          : OpenCV.Size_Coordinate)
      return Hough_Circle_Array is
   begin
      if Maximum_Radius <= Minimum_Radius then
         Raise_Hough_Error
           ("Find_Hough_Circles",
            "requires Maximum_Radius greater than Minimum_Radius");
      end if;
      return
        Detect_Hough_Circles
          (Source,
           Accumulator_Scale,
           Minimum_Center_Distance,
           Canny_Threshold,
           Accumulator_Threshold,
           Minimum_Radius,
           Internal.C_API.Hough_Radius_Explicit,
           Maximum_Radius);
   end Find_Hough_Circles;

   procedure Release_Hough_Line_Evidence
     (Result : in out Internal.C_API.Hough_Line_Evidence_Handle) is
   begin
      Internal.C_API.Hough_Line_Evidence_Destroy (Result);
      Result := Internal.C_API.Null_Hough_Line_Evidence_Handle;
   end Release_Hough_Line_Evidence;

   procedure Release_Hough_Circle_Evidence
     (Result : in out Internal.C_API.Hough_Circle_Evidence_Handle) is
   begin
      Internal.C_API.Hough_Circle_Evidence_Destroy (Result);
      Result := Internal.C_API.Null_Hough_Circle_Evidence_Handle;
   end Release_Hough_Circle_Evidence;

   --  Copies a successful native line-evidence result into Ada storage and
   --  releases it on every path.
   function Take_Hough_Line_Evidence
     (Result    : in out Internal.C_API.Hough_Line_Evidence_Handle;
      Operation : String) return Hough_Line_With_Votes_Array
   is
      use type Interfaces.Integer_32;

      Count : aliased Interfaces.Integer_32 := 0;
   begin
      Raise_On_Error
        (Internal.C_API.Hough_Line_Evidence_Count (Result, Count'Access),
         Operation);
      if Count <= 0 then
         Release_Hough_Line_Evidence (Result);
         return Empty : Hough_Line_With_Votes_Array (1 .. 0);
      end if;

      declare
         Raw    :
           Internal.C_API.Hough_Line_Evidence_Record_Array
             (0 .. Natural (Count) - 1);
         Output : Hough_Line_With_Votes_Array (Raw'Range);
      begin
         Raise_On_Error
           (Internal.C_API.Hough_Line_Evidence_Copy
              (Result, Raw (Raw'First)'Access, Count),
            Operation);
         for Index in Raw'Range loop
            --  Rho and theta were binary32 in every native source, so the
            --  narrowing below is exact.
            Output (Index) :=
              (Rho           => OpenCV.Float32_Value (Raw (Index).Rho),
               Angle_Radians => OpenCV.Float32_Value (Raw (Index).Theta),
               Votes         => OpenCV.Float64_Value (Raw (Index).Votes));
         end loop;
         Release_Hough_Line_Evidence (Result);
         return Output;
      end;
   exception
      when others =>
         Release_Hough_Line_Evidence (Result);
         raise;
   end Take_Hough_Line_Evidence;

   function Find_Hough_Lines_With_Votes
     (Source                   : OpenCV.Core.Mat;
      Distance_Resolution      : OpenCV.Float64_Value;
      Angle_Resolution_Radians : OpenCV.Float64_Value;
      Vote_Threshold           : Hough_Vote_Threshold;
      Minimum_Angle_Radians    : OpenCV.Float64_Value := 0.0;
      Maximum_Angle_Radians    : OpenCV.Float64_Value := Ada.Numerics.Pi)
      return Hough_Line_With_Votes_Array
   is
      Operation : constant String := "Find_Hough_Lines_With_Votes";
      Result    : aliased Internal.C_API.Hough_Line_Evidence_Handle :=
        Internal.C_API.Null_Hough_Line_Evidence_Handle;
      Status    : Internal.C_API.Status := Internal.C_API.Success;

      procedure Detect
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Hough_Lines_With_Votes
             (Source_Handle,
              Interfaces.C.double (Distance_Resolution),
              Interfaces.C.double (Angle_Resolution_Radians),
              Interfaces.Integer_32 (Vote_Threshold),
              Interfaces.C.double (Minimum_Angle_Radians),
              Interfaces.C.double (Maximum_Angle_Radians),
              Result'Access);
      end Detect;
   begin
      Validate_Hough_Source (Source, Operation);
      Validate_Hough_Resolutions
        (Distance_Resolution, Angle_Resolution_Radians, Operation);
      Validate_Hough_Angle_Bounds
        (Minimum_Angle_Radians, Maximum_Angle_Radians, Operation);

      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Detect'Access);
      Raise_On_Error (Status, Operation);
      return Take_Hough_Line_Evidence (Result, Operation);
   end Find_Hough_Lines_With_Votes;

   function Is_Finite_Coordinate (Value : OpenCV.Float32_Value) return Boolean
   is
      use type OpenCV.Float32_Value;
   begin
      return
        Value = Value
        and then Value <= OpenCV.Float32_Value'Last
        and then Value >= OpenCV.Float32_Value'First;
   end Is_Finite_Coordinate;

   --  Heap storage for the C point span, so a large point set never lands
   --  on the primary or secondary stack.
   type Point_F32_Array_Access is access Internal.C_API.Point_F32_Array;

   procedure Free_Points is new
     Ada.Unchecked_Deallocation
       (Internal.C_API.Point_F32_Array,
        Point_F32_Array_Access);

   function Find_Hough_Lines_From_Points
     (Points                   : Hough_Point_Array;
      Maximum_Lines            : Positive;
      Vote_Threshold           : Hough_Vote_Threshold;
      Minimum_Rho              : OpenCV.Float64_Value;
      Maximum_Rho              : OpenCV.Float64_Value;
      Distance_Resolution      : OpenCV.Float64_Value;
      Minimum_Angle_Radians    : OpenCV.Float64_Value := 0.0;
      Maximum_Angle_Radians    : OpenCV.Float64_Value := Ada.Numerics.Pi;
      Angle_Resolution_Radians : OpenCV.Float64_Value := Hough_Degree)
      return Hough_Line_With_Votes_Array
   is
      use type OpenCV.Float64_Value;

      Operation   : constant String := "Find_Hough_Lines_From_Points";
      --  Beyond binary32 range the native layer rejects the bounds anyway;
      --  staying below it keeps the Float64 span arithmetic finite.
      Native_Span : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (OpenCV.Float32_Value'Last);
      Result      : aliased Internal.C_API.Hough_Line_Evidence_Handle :=
        Internal.C_API.Null_Hough_Line_Evidence_Handle;
      Status      : Internal.C_API.Status := Internal.C_API.Success;
      Native      : Point_F32_Array_Access;
   begin
      Validate_Hough_Resolutions
        (Distance_Resolution, Angle_Resolution_Radians, Operation);
      Validate_Hough_Angle_Bounds
        (Minimum_Angle_Radians, Maximum_Angle_Radians, Operation);
      if not Is_Finite (Minimum_Rho) or else not Is_Finite (Maximum_Rho) then
         Raise_Hough_Error (Operation, "requires finite rho bounds");
      elsif Minimum_Rho >= Maximum_Rho then
         Raise_Hough_Error (Operation, "requires Minimum_Rho < Maximum_Rho");
      elsif abs Minimum_Rho > Native_Span or else abs Maximum_Rho > Native_Span
      then
         Raise_Hough_Error
           (Operation, "requires rho bounds within native binary32 range");
      elsif (Maximum_Rho - Minimum_Rho + 1.0) / Distance_Resolution < 1.0 then
         Raise_Hough_Error
           (Operation, "requires Distance_Resolution to yield a rho bin");
      elsif (Maximum_Angle_Radians - Minimum_Angle_Radians)
        / Angle_Resolution_Radians
        < 1.0
      then
         Raise_Hough_Error
           (Operation, "requires Angle_Resolution_Radians to yield a bin");
      elsif Points'Length > Natural (Interfaces.Integer_32'Last) then
         Raise_Hough_Error (Operation, "has too many points for native code");
      end if;
      for Point of Points loop
         if not Is_Finite_Coordinate (Point.X)
           or else not Is_Finite_Coordinate (Point.Y)
         then
            Raise_Hough_Error (Operation, "requires finite point coordinates");
         end if;
      end loop;

      if Points'Length = 0 then
         return Empty : Hough_Line_With_Votes_Array (1 .. 0);
      end if;

      Native := new Internal.C_API.Point_F32_Array (0 .. Points'Length - 1);
      for Offset in Native'Range loop
         Native (Offset) :=
           (X => Interfaces.C.C_float (Points (Points'First + Offset).X),
            Y => Interfaces.C.C_float (Points (Points'First + Offset).Y));
      end loop;
      Status :=
        Internal.C_API.Hough_Lines_Point_Set
          (Native (Native'First)'Access,
           Interfaces.Integer_32 (Native'Length),
           Interfaces.Integer_32 (Maximum_Lines),
           Interfaces.Integer_32 (Vote_Threshold),
           Interfaces.C.double (Minimum_Rho),
           Interfaces.C.double (Maximum_Rho),
           Interfaces.C.double (Distance_Resolution),
           Interfaces.C.double (Minimum_Angle_Radians),
           Interfaces.C.double (Maximum_Angle_Radians),
           Interfaces.C.double (Angle_Resolution_Radians),
           Result'Access);
      Free_Points (Native);
      Raise_On_Error (Status, Operation);
      return Take_Hough_Line_Evidence (Result, Operation);
   exception
      when others =>
         Free_Points (Native);
         Release_Hough_Line_Evidence (Result);
         raise;
   end Find_Hough_Lines_From_Points;

   function Find_Hough_Circle_Centers
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0)
      return Hough_Circle_Center_Array
   is
      --  The private centers-only mode makes the shim pass OpenCV's -1
      --  maxRadius sentinel; the native radius component is then 0 and is
      --  discarded here.
      Circles : constant Hough_Circle_Array :=
        Detect_Hough_Circles
          (Source,
           Accumulator_Scale,
           Minimum_Center_Distance,
           Canny_Threshold,
           Accumulator_Threshold,
           Minimum_Radius,
           Internal.C_API.Hough_Radius_Centers_Only,
           0,
           Operation => "Find_Hough_Circle_Centers");
   begin
      if Circles'Length = 0 then
         return Empty : Hough_Circle_Center_Array (1 .. 0);
      end if;
      return Centers : Hough_Circle_Center_Array (Circles'Range) do
         for Index in Circles'Range loop
            Centers (Index) := Circles (Index).Center;
         end loop;
      end return;
   end Find_Hough_Circle_Centers;

   --  Radius-finding circles with native Vec4f support counts. Radius_Mode
   --  is only ever Automatic or Explicit here.
   function Detect_Hough_Circles_With_Votes
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate;
      Radius_Mode             : Interfaces.Integer_32;
      Maximum_Radius          : OpenCV.Size_Coordinate)
      return Hough_Circle_With_Votes_Array
   is
      use type Interfaces.Integer_32;

      Operation : constant String := "Find_Hough_Circles_With_Votes";
      Result    : aliased Internal.C_API.Hough_Circle_Evidence_Handle :=
        Internal.C_API.Null_Hough_Circle_Evidence_Handle;
      Status    : Internal.C_API.Status := Internal.C_API.Success;
      Count     : aliased Interfaces.Integer_32 := 0;

      procedure Detect
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Hough_Circles_With_Votes
             (Source_Handle,
              Interfaces.C.double (Accumulator_Scale),
              Interfaces.C.double (Minimum_Center_Distance),
              Interfaces.Integer_32 (Canny_Threshold),
              Interfaces.Integer_32 (Accumulator_Threshold),
              Radius_Mode,
              Interfaces.Integer_32 (Minimum_Radius),
              Interfaces.Integer_32 (Maximum_Radius),
              Result'Access);
      end Detect;
   begin
      Validate_Hough_Circle_Arguments
        (Source, Accumulator_Scale, Minimum_Center_Distance, Operation);

      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Detect'Access);
      Raise_On_Error (Status, Operation);

      begin
         Raise_On_Error
           (Internal.C_API.Hough_Circle_Evidence_Count (Result, Count'Access),
            Operation);
         if Count <= 0 then
            Release_Hough_Circle_Evidence (Result);
            return Empty : Hough_Circle_With_Votes_Array (1 .. 0);
         end if;

         declare
            Raw    :
              Internal.C_API.Hough_Circle_Evidence_Record_Array
                (0 .. Natural (Count) - 1);
            Output : Hough_Circle_With_Votes_Array (Raw'Range);
         begin
            Raise_On_Error
              (Internal.C_API.Hough_Circle_Evidence_Copy
                 (Result, Raw (Raw'First)'Access, Count),
               Operation);
            for Index in Raw'Range loop
               Output (Index) :=
                 (Center =>
                    (X => OpenCV.Float32_Value (Raw (Index).X),
                     Y => OpenCV.Float32_Value (Raw (Index).Y)),
                  Radius => OpenCV.Float32_Value (Raw (Index).Radius),
                  Votes  => OpenCV.Float64_Value (Raw (Index).Votes));
            end loop;
            Release_Hough_Circle_Evidence (Result);
            return Output;
         end;
      exception
         when others =>
            Release_Hough_Circle_Evidence (Result);
            raise;
      end;
   end Detect_Hough_Circles_With_Votes;

   function Find_Hough_Circles_With_Votes
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0)
      return Hough_Circle_With_Votes_Array is
   begin
      return
        Detect_Hough_Circles_With_Votes
          (Source,
           Accumulator_Scale,
           Minimum_Center_Distance,
           Canny_Threshold,
           Accumulator_Threshold,
           Minimum_Radius,
           Internal.C_API.Hough_Radius_Automatic,
           0);
   end Find_Hough_Circles_With_Votes;

   function Find_Hough_Circles_With_Votes
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0;
      Maximum_Radius          : OpenCV.Size_Coordinate)
      return Hough_Circle_With_Votes_Array is
   begin
      if Maximum_Radius <= Minimum_Radius then
         Raise_Hough_Error
           ("Find_Hough_Circles_With_Votes",
            "requires Maximum_Radius greater than Minimum_Radius");
      end if;
      return
        Detect_Hough_Circles_With_Votes
          (Source,
           Accumulator_Scale,
           Minimum_Center_Distance,
           Canny_Threshold,
           Accumulator_Threshold,
           Minimum_Radius,
           Internal.C_API.Hough_Radius_Explicit,
           Maximum_Radius);
   end Find_Hough_Circles_With_Votes;

   --  Segmentation.

   procedure Segmentation_Error (Message : String) is
   begin
      Ada.Exceptions.Raise_Exception (OpenCV.OpenCV_Error'Identity, Message);
   end Segmentation_Error;

   function To_C_Scalar4 (Value : OpenCV.Scalar) return Internal.C_API.Scalar4
   is (Values =>
         (Interfaces.C.double (Value.Component_0),
          Interfaces.C.double (Value.Component_1),
          Interfaces.C.double (Value.Component_2),
          Interfaces.C.double (Value.Component_3)));

   function Scalar_Component
     (Value : OpenCV.Scalar; Index : Natural) return OpenCV.Float64_Value
   is (OpenCV.Float64_Value
         (case Index is
            when 0      => Value.Component_0,
            when 1      => Value.Component_1,
            when 2      => Value.Component_2,
            when others => Value.Component_3));

   procedure Validate_Flood_Fill
     (Image            : OpenCV.Core.Mat;
      Seed             : OpenCV.Point;
      New_Value        : OpenCV.Scalar;
      Lower_Difference : OpenCV.Scalar;
      Upper_Difference : OpenCV.Scalar;
      Use_New_Value    : Boolean)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Float64_Value;
   begin
      if Image.Is_Empty then
         Segmentation_Error ("Flood_Fill requires a non-empty image");
      elsif Image.Dimension_Count /= 2 then
         Segmentation_Error ("Flood_Fill requires a two-dimensional image");
      elsif Image.Depth /= OpenCV.Core.UInt8
        and then Image.Depth /= OpenCV.Core.Float32
      then
         Segmentation_Error ("Flood_Fill requires a UInt8 or Float32 image");
      elsif Image.Channels /= 1 and then Image.Channels /= 3 then
         Segmentation_Error ("Flood_Fill requires one or three channels");
      elsif Seed.X < 0
        or else Seed.Y < 0
        or else Seed.X >= OpenCV.Point_Coordinate (Image.Columns)
        or else Seed.Y >= OpenCV.Point_Coordinate (Image.Rows)
      then
         Segmentation_Error ("Flood_Fill requires Seed inside the image");
      end if;

      for Index in 0 .. Natural (Image.Channels) - 1 loop
         declare
            Value : constant OpenCV.Float64_Value :=
              Scalar_Component (New_Value, Index);
            Lower : constant OpenCV.Float64_Value :=
              Scalar_Component (Lower_Difference, Index);
            Upper : constant OpenCV.Float64_Value :=
              Scalar_Component (Upper_Difference, Index);
         begin
            if (Use_New_Value and then not Is_Finite (Value))
              or else not Is_Finite (Lower)
              or else not Is_Finite (Upper)
            then
               Segmentation_Error
                 ("Flood_Fill requires finite value and difference"
                  & " components for every channel");
            elsif Lower < 0.0 or else Upper < 0.0 then
               Segmentation_Error
                 ("Flood_Fill requires nonnegative differences");
            end if;
         end;
      end loop;
   end Validate_Flood_Fill;

   function To_C_Range_Mode
     (Mode : Flood_Fill_Range_Mode) return Interfaces.Integer_32
   is (case Mode is
         when Floating_Range => Internal.C_API.Flood_Fill_Floating_Range,
         when Fixed_Range    => Internal.C_API.Flood_Fill_Fixed_Range);

   function To_Flood_Fill_Result
     (Count : Interfaces.Integer_32; Bounds : Internal.C_API.Rect_I32)
      return Flood_Fill_Result
   is (Pixel_Count => Natural (Count),
       Bounds      =>
         (X      => OpenCV.Point_Coordinate (Bounds.X),
          Y      => OpenCV.Point_Coordinate (Bounds.Y),
          Width  => OpenCV.Size_Coordinate (Bounds.Width),
          Height => OpenCV.Size_Coordinate (Bounds.Height)));

   procedure Flood_Fill
     (Image            : in out OpenCV.Core.Mat;
      Seed             : OpenCV.Point;
      New_Value        : OpenCV.Scalar;
      Result           : out Flood_Fill_Result;
      Lower_Difference : OpenCV.Scalar := (others => 0.0);
      Upper_Difference : OpenCV.Scalar := (others => 0.0);
      Connectivity     : Pixel_Connectivity := Four_Connected;
      Range_Mode       : Flood_Fill_Range_Mode := Floating_Range)
   is
      C_Value : aliased constant Internal.C_API.Scalar4 :=
        To_C_Scalar4 (New_Value);
      C_Lower : aliased constant Internal.C_API.Scalar4 :=
        To_C_Scalar4 (Lower_Difference);
      C_Upper : aliased constant Internal.C_API.Scalar4 :=
        To_C_Scalar4 (Upper_Difference);
      Count   : aliased Interfaces.Integer_32 := 0;
      Bounds  : aliased Internal.C_API.Rect_I32 := (0, 0, 0, 0);
      Status  : Internal.C_API.Status;

      procedure Fill (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           Internal.C_API.Flood_Fill
             (Handle,
              Interfaces.Integer_32 (Seed.X),
              Interfaces.Integer_32 (Seed.Y),
              C_Value'Access,
              C_Lower'Access,
              C_Upper'Access,
              To_C_Connectivity (Connectivity),
              To_C_Range_Mode (Range_Mode),
              Count'Access,
              Bounds'Access);
      end Fill;
   begin
      Validate_Flood_Fill
        (Image, Seed, New_Value, Lower_Difference, Upper_Difference, True);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Fill'Access);
      Raise_On_Error (Status, "Flood_Fill");
      Result := To_Flood_Fill_Result (Count, Bounds);
   end Flood_Fill;

   --  Byte-level storage overlap, exact for Mats of different element types
   --  (for example a flood-fill mask and image carved from one buffer).
   function Storage_Overlaps
     (First, Second : OpenCV.Core.Mat; Operation : String) return Boolean
   is
      use type Interfaces.Unsigned_8;

      Overlap : aliased Interfaces.Unsigned_8 := 0;
      Status  : Internal.C_API.Status := Internal.C_API.Success;

      procedure First_Input
        (First_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Second_Input
           (Second_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status :=
              Internal.C_API.Mat_Storage_Overlap
                (First_Handle, Second_Handle, Overlap'Access);
         end Second_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Second, Second_Input'Access);
      end First_Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (First, First_Input'Access);
      Raise_On_Error (Status, Operation & " storage validation");
      return Overlap /= 0;
   end Storage_Overlaps;

   procedure Flood_Fill_With_Mask
     (Image            : in out OpenCV.Core.Mat;
      Mask             : in out OpenCV.Core.Mat;
      Seed             : OpenCV.Point;
      New_Value        : OpenCV.Scalar;
      Result           : out Flood_Fill_Result;
      Lower_Difference : OpenCV.Scalar := (others => 0.0);
      Upper_Difference : OpenCV.Scalar := (others => 0.0);
      Connectivity     : Pixel_Connectivity := Four_Connected;
      Range_Mode       : Flood_Fill_Range_Mode := Floating_Range;
      Mask_Fill_Value  : Flood_Fill_Mask_Value := 1;
      Mask_Only        : Boolean := False)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;

      --  OpenCV ignores New_Value in mask-only mode, so it is neither
      --  validated nor passed; a neutral value is used instead.
      Fill_Value : constant OpenCV.Scalar :=
        (if Mask_Only then (others => 0.0) else New_Value);
      C_Value    : aliased constant Internal.C_API.Scalar4 :=
        To_C_Scalar4 (Fill_Value);
      C_Lower    : aliased constant Internal.C_API.Scalar4 :=
        To_C_Scalar4 (Lower_Difference);
      C_Upper    : aliased constant Internal.C_API.Scalar4 :=
        To_C_Scalar4 (Upper_Difference);
      Count      : aliased Interfaces.Integer_32 := 0;
      Bounds     : aliased Internal.C_API.Rect_I32 := (0, 0, 0, 0);
      Status     : Internal.C_API.Status;

      procedure Fill_Image
        (Image_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
         procedure Fill_Mask
           (Mask_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              Internal.C_API.Flood_Fill_Masked
                (Image_Handle,
                 Mask_Handle,
                 Interfaces.Integer_32 (Seed.X),
                 Interfaces.Integer_32 (Seed.Y),
                 C_Value'Access,
                 C_Lower'Access,
                 C_Upper'Access,
                 To_C_Connectivity (Connectivity),
                 To_C_Range_Mode (Range_Mode),
                 Interfaces.Integer_32 (Mask_Fill_Value),
                 (if Mask_Only then 1 else 0),
                 Count'Access,
                 Bounds'Access);
         end Fill_Mask;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Mask, Fill_Mask'Access);
      end Fill_Image;
   begin
      Validate_Flood_Fill
        (Image,
         Seed,
         Fill_Value,
         Lower_Difference,
         Upper_Difference,
         not Mask_Only);
      if Mask.Is_Empty
        or else Mask.Dimension_Count /= 2
        or else Mask.Depth /= OpenCV.Core.UInt8
        or else Mask.Channels /= 1
      then
         Segmentation_Error
           ("Flood_Fill_With_Mask requires a non-empty two-dimensional UInt8"
            & " C1 mask");
      elsif Mask.Rows /= Image.Rows + 2
        or else Mask.Columns /= Image.Columns + 2
      then
         Segmentation_Error
           ("Flood_Fill_With_Mask requires a mask two rows and two columns"
            & " larger than the image");
      elsif Storage_Overlaps (Image, Mask, "Flood_Fill_With_Mask") then
         Segmentation_Error
           ("Flood_Fill_With_Mask requires Mask not to share storage with"
            & " Image");
      end if;

      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Fill_Image'Access);
      Raise_On_Error (Status, "Flood_Fill_With_Mask");
      Result := To_Flood_Fill_Result (Count, Bounds);
   end Flood_Fill_With_Mask;

   procedure Watershed
     (Source : OpenCV.Core.Mat; Markers : in out OpenCV.Core.Mat)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;

      Status : Internal.C_API.Status;

      procedure Segment_Source
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Segment_Markers
           (Markers_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status := Internal.C_API.Watershed (Source_Handle, Markers_Handle);
         end Segment_Markers;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Markers, Segment_Markers'Access);
      end Segment_Source;
   begin
      if Source.Is_Empty
        or else Source.Dimension_Count /= 2
        or else Source.Depth /= OpenCV.Core.UInt8
        or else Source.Channels /= 3
      then
         Segmentation_Error
           ("Watershed requires a non-empty two-dimensional UInt8 C3 source");
      elsif Markers.Is_Empty
        or else Markers.Dimension_Count /= 2
        or else Markers.Depth /= OpenCV.Core.Int32
        or else Markers.Channels /= 1
      then
         Segmentation_Error
           ("Watershed requires non-empty two-dimensional Int32 C1 markers");
      elsif Markers.Rows /= Source.Rows
        or else Markers.Columns /= Source.Columns
      then
         Segmentation_Error
           ("Watershed requires markers with the source rows and columns");
      elsif OpenCV.Core.Min_Max_Loc (Markers).Minimum < 0.0 then
         Segmentation_Error ("Watershed requires nonnegative input markers");
      elsif Storage_Overlaps (Source, Markers, "Watershed") then
         Segmentation_Error
           ("Watershed requires Markers not to share storage with Source");
      end if;

      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Segment_Source'Access);
      Raise_On_Error (Status, "Watershed");
   end Watershed;

   function GrabCut_Label_Value
     (Label : GrabCut_Label) return OpenCV.UInt8_Value
   is (OpenCV.UInt8_Value (GrabCut_Label'Pos (Label)));

   function To_GrabCut_Label (Value : OpenCV.UInt8_Value) return GrabCut_Label
   is
      use type OpenCV.UInt8_Value;
   begin
      if Value > 3 then
         Segmentation_Error ("GrabCut labels are the values 0 .. 3");
      end if;
      return GrabCut_Label'Val (Natural (Value));
   end To_GrabCut_Label;

   function Is_Initialized (State : GrabCut_State) return Boolean
   is (State.Initialized);

   procedure Validate_GrabCut_Source
     (Source : OpenCV.Core.Mat; Operation : String)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty
        or else Source.Dimension_Count /= 2
        or else Source.Depth /= OpenCV.Core.UInt8
        or else Source.Channels /= 3
      then
         Segmentation_Error
           (Operation
            & " requires a non-empty two-dimensional UInt8 C3 source");
      end if;
   end Validate_GrabCut_Source;

   --  Runs native GrabCut on the given state Mats, which must be private to
   --  the caller and distinct from each other and from Source.
   procedure Run_GrabCut
     (Source     : OpenCV.Core.Mat;
      Mask       : in out OpenCV.Core.Mat;
      Background : in out OpenCV.Core.Mat;
      Foreground : in out OpenCV.Core.Mat;
      Region     : OpenCV.Rect;
      Iterations : GrabCut_Iterations;
      Mode       : Interfaces.Integer_32)
   is
      Status : Internal.C_API.Status;

      procedure With_Source
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure With_Mask
           (Mask_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure With_Background
              (Background_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
               procedure With_Foreground
                 (Foreground_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    Internal.C_API.GrabCut
                      (Source_Handle,
                       Mask_Handle,
                       Background_Handle,
                       Foreground_Handle,
                       Interfaces.Integer_32 (Region.X),
                       Interfaces.Integer_32 (Region.Y),
                       Interfaces.Integer_32 (Region.Width),
                       Interfaces.Integer_32 (Region.Height),
                       Interfaces.Integer_32 (Iterations),
                       Mode);
               end With_Foreground;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Foreground, With_Foreground'Access);
            end With_Background;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Background, With_Background'Access);
         end With_Mask;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Mask, With_Mask'Access);
      end With_Source;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, With_Source'Access);
      Raise_On_Error (Status, "GrabCut");
   end Run_GrabCut;

   procedure Validate_GrabCut_Region
     (Rows, Columns, X, Y, Width, Height : Long_Long_Integer) is
   begin
      if Width = 0
        or else Height = 0
        or else X < 0
        or else Y < 0
        or else X + Width > Columns
        or else Y + Height > Rows
      then
         Segmentation_Error
           ("Initialize_GrabCut requires a non-empty Foreground_Region"
            & " inside Source");
      elsif Width * Height < GrabCut_Minimum_Training_Pixels
        or else Rows * Columns - Width * Height
                < GrabCut_Minimum_Training_Pixels
      then
         Segmentation_Error
           ("Initialize_GrabCut requires at least five pixels inside and"
            & " five outside Foreground_Region");
      end if;
   end Validate_GrabCut_Region;

   function Initialize_GrabCut
     (Source            : OpenCV.Core.Mat;
      Foreground_Region : OpenCV.Rect;
      Iterations        : GrabCut_Iterations := 1) return GrabCut_State
   is
      X      : constant Long_Long_Integer :=
        Long_Long_Integer (Foreground_Region.X);
      Y      : constant Long_Long_Integer :=
        Long_Long_Integer (Foreground_Region.Y);
      Width  : constant Long_Long_Integer :=
        Long_Long_Integer (Foreground_Region.Width);
      Height : constant Long_Long_Integer :=
        Long_Long_Integer (Foreground_Region.Height);
   begin
      Validate_GrabCut_Source (Source, "Initialize_GrabCut");
      declare
         Rows    : constant Long_Long_Integer :=
           Long_Long_Integer (Source.Rows);
         Columns : constant Long_Long_Integer :=
           Long_Long_Integer (Source.Columns);
      begin
         Validate_GrabCut_Region (Rows, Columns, X, Y, Width, Height);
      end;

      return State : GrabCut_State do
         Run_GrabCut
           (Source,
            State.Mask,
            State.Background_Model,
            State.Foreground_Model,
            Foreground_Region,
            Iterations,
            Internal.C_API.GrabCut_Init_With_Rect);
         State.Initialized := True;
      end return;
   end Initialize_GrabCut;

   --  The rectangle argument OpenCV ignores outside GC_INIT_WITH_RECT.
   No_Region : constant OpenCV.Rect :=
     (X => 0, Y => 0, Width => 0, Height => 0);

   --  Number of Mask elements whose value lies in Low .. High.
   function Count_Labels
     (Mask : OpenCV.Core.Mat; Low, High : Long_Float) return Long_Long_Integer
   is (Long_Long_Integer
         (OpenCV.Core.Count_Non_Zero
            (OpenCV.Core.In_Range
               (Mask,
                (Component_0 => Low, others => 0.0),
                (Component_0 => High, others => 0.0)))));

   procedure Validate_GrabCut_Mask (Mask : OpenCV.Core.Mat; Operation : String)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Mask.Is_Empty
        or else Mask.Dimension_Count /= 2
        or else Mask.Depth /= OpenCV.Core.UInt8
        or else Mask.Channels /= 1
      then
         Segmentation_Error
           (Operation & " requires a non-empty two-dimensional UInt8 C1 mask");
      elsif Count_Labels (Mask, 4.0, 255.0) /= 0 then
         Segmentation_Error (Operation & " requires mask values in 0 .. 3");
      end if;
   end Validate_GrabCut_Mask;

   procedure Validate_GrabCut_Training
     (Mask : OpenCV.Core.Mat; Operation : String)
   is
      Background : constant Long_Long_Integer :=
        Count_Labels (Mask, 0.0, 0.0) + Count_Labels (Mask, 2.0, 2.0);
      Foreground : constant Long_Long_Integer :=
        Count_Labels (Mask, 1.0, 1.0) + Count_Labels (Mask, 3.0, 3.0);
   begin
      if Background < GrabCut_Minimum_Training_Pixels
        or else Foreground < GrabCut_Minimum_Training_Pixels
      then
         Segmentation_Error
           (Operation
            & " requires at least five background and five"
            & " foreground pixels in the constrained mask");
      end if;
   end Validate_GrabCut_Training;

   function Initialize_GrabCut
     (Source       : OpenCV.Core.Mat;
      Initial_Mask : OpenCV.Core.Mat;
      Iterations   : GrabCut_Iterations := 1) return GrabCut_State is
   begin
      Validate_GrabCut_Source (Source, "Initialize_GrabCut");
      Validate_GrabCut_Mask (Initial_Mask, "Initialize_GrabCut");
      if Initial_Mask.Rows /= Source.Rows
        or else Initial_Mask.Columns /= Source.Columns
      then
         Segmentation_Error
           ("Initialize_GrabCut requires Initial_Mask with the source rows"
            & " and columns");
      end if;
      Validate_GrabCut_Training (Initial_Mask, "Initialize_GrabCut");

      return State : GrabCut_State do
         --  The deep copy keeps the caller's mask unchanged and gives the
         --  state exclusive ownership of the storage OpenCV mutates.
         State.Mask := Initial_Mask.Clone;
         Run_GrabCut
           (Source,
            State.Mask,
            State.Background_Model,
            State.Foreground_Model,
            No_Region,
            Iterations,
            Internal.C_API.GrabCut_Init_With_Mask);
         State.Initialized := True;
      end return;
   end Initialize_GrabCut;

   function Initialize_GrabCut
     (Source            : OpenCV.Core.Mat;
      Initial_Mask      : OpenCV.Core.Mat;
      Foreground_Region : OpenCV.Rect;
      Iterations        : GrabCut_Iterations := 1) return GrabCut_State
   is
      X      : constant Long_Long_Integer :=
        Long_Long_Integer (Foreground_Region.X);
      Y      : constant Long_Long_Integer :=
        Long_Long_Integer (Foreground_Region.Y);
      Width  : constant Long_Long_Integer :=
        Long_Long_Integer (Foreground_Region.Width);
      Height : constant Long_Long_Integer :=
        Long_Long_Integer (Foreground_Region.Height);
   begin
      Validate_GrabCut_Source (Source, "Initialize_GrabCut");
      Validate_GrabCut_Mask (Initial_Mask, "Initialize_GrabCut");
      if Initial_Mask.Rows /= Source.Rows
        or else Initial_Mask.Columns /= Source.Columns
      then
         Segmentation_Error
           ("Initialize_GrabCut requires Initial_Mask with the source rows"
            & " and columns");
      end if;
      if Width = 0
        or else Height = 0
        or else X < 0
        or else Y < 0
        or else X + Width > Long_Long_Integer (Source.Columns)
        or else Y + Height > Long_Long_Integer (Source.Rows)
      then
         Segmentation_Error
           ("Initialize_GrabCut requires a non-empty Foreground_Region"
            & " inside Source");
      end if;

      return State : GrabCut_State do
         State.Mask := Initial_Mask.Clone;
         for Row in 0 .. Source.Rows - 1 loop
            for Column in 0 .. Source.Columns - 1 loop
               if Long_Long_Integer (Row) < Y
                 or else Long_Long_Integer (Row) >= Y + Height
                 or else Long_Long_Integer (Column) < X
                 or else Long_Long_Integer (Column) >= X + Width
               then
                  OpenCV.Core.UInt8_Access.Set
                    (State.Mask,
                     Row,
                     Column,
                     GrabCut_Label_Value (Definite_Background));
               end if;
            end loop;
         end loop;
         Validate_GrabCut_Training (State.Mask, "Initialize_GrabCut");
         Run_GrabCut
           (Source,
            State.Mask,
            State.Background_Model,
            State.Foreground_Model,
            No_Region,
            Iterations,
            Internal.C_API.GrabCut_Init_With_Mask);
         State.Initialized := True;
      end return;
   end Initialize_GrabCut;

   procedure Validate_Imported_GrabCut_Model
     (Model : OpenCV.Core.Mat; Operation : String)
   is
      Status : Internal.C_API.Status;
      procedure Validate (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Status := Internal.C_API.Validate_GrabCut_Model (Handle);
      end Validate;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Model, Validate'Access);
      Raise_On_Error (Status, Operation);
   end Validate_Imported_GrabCut_Model;

   function Restore_GrabCut_State
     (Mask             : OpenCV.Core.Mat;
      Background_Model : OpenCV.Core.Mat;
      Foreground_Model : OpenCV.Core.Mat) return GrabCut_State is
   begin
      Validate_GrabCut_Mask (Mask, "Restore_GrabCut_State");
      Validate_Imported_GrabCut_Model
        (Background_Model, "Restore_GrabCut_State background model");
      Validate_Imported_GrabCut_Model
        (Foreground_Model, "Restore_GrabCut_State foreground model");
      return State : GrabCut_State do
         State.Mask := Mask.Clone;
         State.Background_Model := Background_Model.Clone;
         State.Foreground_Model := Foreground_Model.Clone;
         State.Initialized := True;
      end return;
   end Restore_GrabCut_State;

   function Clone_GrabCut_State (State : GrabCut_State) return GrabCut_State is
   begin
      if not State.Initialized then
         Segmentation_Error
           ("Clone_GrabCut_State requires an initialized state");
      end if;
      return Copy : GrabCut_State do
         Copy.Mask := State.Mask.Clone;
         Copy.Background_Model := State.Background_Model.Clone;
         Copy.Foreground_Model := State.Foreground_Model.Clone;
         Copy.Initialized := True;
      end return;
   end Clone_GrabCut_State;

   function GrabCut_Background_Model
     (State : GrabCut_State) return OpenCV.Core.Mat is
   begin
      if not State.Initialized then
         Segmentation_Error
           ("GrabCut_Background_Model requires an initialized state");
      end if;
      return State.Background_Model.Clone;
   end GrabCut_Background_Model;

   function GrabCut_Foreground_Model
     (State : GrabCut_State) return OpenCV.Core.Mat is
   begin
      if not State.Initialized then
         Segmentation_Error
           ("GrabCut_Foreground_Model requires an initialized state");
      end if;
      return State.Foreground_Model.Clone;
   end GrabCut_Foreground_Model;

   procedure Validate_GrabCut_Refinement
     (Source : OpenCV.Core.Mat; State : GrabCut_State; Operation : String) is
   begin
      if not State.Initialized then
         Segmentation_Error (Operation & " requires an initialized state");
      end if;
      Validate_GrabCut_Source (Source, Operation);
      if Source.Rows /= State.Mask.Rows
        or else Source.Columns /= State.Mask.Columns
      then
         Segmentation_Error
           (Operation & " requires Source with the state's rows and columns");
      end if;
   end Validate_GrabCut_Refinement;

   --  Refines private copies and commits them only after native success, so
   --  a failed refinement leaves State unchanged.
   procedure Refine
     (Source     : OpenCV.Core.Mat;
      State      : in out GrabCut_State;
      Iterations : GrabCut_Iterations;
      Mode       : Interfaces.Integer_32)
   is
      Mask       : OpenCV.Core.Mat := State.Mask.Clone;
      Background : OpenCV.Core.Mat := State.Background_Model.Clone;
      Foreground : OpenCV.Core.Mat := State.Foreground_Model.Clone;
   begin
      Run_GrabCut
        (Source, Mask, Background, Foreground, No_Region, Iterations, Mode);
      State.Mask := Mask;
      State.Background_Model := Background;
      State.Foreground_Model := Foreground;
   end Refine;

   procedure Refine_GrabCut
     (Source     : OpenCV.Core.Mat;
      State      : in out GrabCut_State;
      Iterations : GrabCut_Iterations := 1) is
   begin
      Validate_GrabCut_Refinement (Source, State, "Refine_GrabCut");
      Refine (Source, State, Iterations, Internal.C_API.GrabCut_Eval);
   end Refine_GrabCut;

   procedure Refine_GrabCut_Frozen_Model
     (Source : OpenCV.Core.Mat; State : in out GrabCut_State) is
   begin
      Validate_GrabCut_Refinement
        (Source, State, "Refine_GrabCut_Frozen_Model");
      Refine (Source, State, 1, Internal.C_API.GrabCut_Eval_Freeze_Model);
   end Refine_GrabCut_Frozen_Model;

   function GrabCut_Mask (State : GrabCut_State) return OpenCV.Core.Mat is
   begin
      if not State.Initialized then
         Segmentation_Error ("GrabCut_Mask requires an initialized state");
      end if;
      return State.Mask.Clone;
   end GrabCut_Mask;

   function GrabCut_Label_At
     (State : GrabCut_State; Row : Natural; Column : Natural)
      return GrabCut_Label is
   begin
      if not State.Initialized then
         Segmentation_Error ("GrabCut_Label_At requires an initialized state");
      elsif Row >= State.Mask.Rows or else Column >= State.Mask.Columns then
         Segmentation_Error
           ("GrabCut_Label_At requires Row and Column inside the mask");
      end if;
      return
        To_GrabCut_Label
          (OpenCV.Core.UInt8_Access.Get (State.Mask, Row, Column));
   end GrabCut_Label_At;

   --  Histogram analysis ---------------------------------------------------

   procedure Histogram_Error (Message : String) is
   begin
      Ada.Exceptions.Raise_Exception (OpenCV.OpenCV_Error'Identity, Message);
   end Histogram_Error;

   function Is_Finite_32 (Value : OpenCV.Float32_Value) return Boolean is
      use type OpenCV.Float32_Value;
   begin
      return
        Value = Value
        and then Value <= OpenCV.Float32_Value'Last
        and then Value >= OpenCV.Float32_Value'First;
   end Is_Finite_32;

   --  Source contract shared by calculation and back projection.
   procedure Validate_Histogram_Source
     (Source     : OpenCV.Core.Mat;
      Dimensions : Histogram_Dimension_Array;
      Operation  : String)
   is
      use type OpenCV.Core.Depth_Type;
   begin
      if Source.Is_Empty then
         Histogram_Error (Operation & " requires a non-empty Source");
      elsif Source.Dimension_Count /= 2 then
         Histogram_Error (Operation & " requires a two-dimensional Source");
      elsif Source.Depth /= OpenCV.Core.UInt8
        and then Source.Depth /= OpenCV.Core.UInt16
        and then Source.Depth /= OpenCV.Core.Float32
      then
         Histogram_Error
           (Operation & " requires a UInt8, UInt16 or Float32 Source");
      end if;
      for Dimension of Dimensions loop
         if Dimension.Channel >= Natural (Source.Channels) then
            Histogram_Error
              (Operation & " selects a channel that Source does not have");
         end if;
      end loop;
   end Validate_Histogram_Source;

   procedure Validate_Histogram_Mask
     (Mask : OpenCV.Core.Mat; Rows, Columns : Natural; Operation : String)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      if Mask.Is_Empty
        or else Mask.Dimension_Count /= 2
        or else Mask.Depth /= OpenCV.Core.UInt8
        or else Mask.Channels /= 1
      then
         Histogram_Error
           (Operation & " requires a two-dimensional UInt8 C1 Mask");
      elsif Mask.Rows /= Rows or else Mask.Columns /= Columns then
         Histogram_Error
           (Operation & " requires Mask with the source rows and columns");
      end if;
   end Validate_Histogram_Mask;

   procedure Validate_Bin_Geometry
     (Bin_Count   : Histogram_Bin_Count;
      Lower_Bound : OpenCV.Float32_Value;
      Upper_Bound : OpenCV.Float32_Value;
      Total       : in out Long_Long_Integer;
      Operation   : String)
   is
      use type OpenCV.Float32_Value;
   begin
      if not Is_Finite_32 (Lower_Bound) or else not Is_Finite_32 (Upper_Bound)
      then
         Histogram_Error (Operation & " requires finite dimension bounds");
      elsif not (Lower_Bound < Upper_Bound) then
         Histogram_Error (Operation & " requires Lower_Bound < Upper_Bound");
      end if;
      Total := Total * Long_Long_Integer (Bin_Count);
      if Total > Long_Long_Integer (Interfaces.Integer_32'Last) then
         Histogram_Error
           (Operation & " bin count product exceeds 2_147_483_647");
      end if;
   end Validate_Bin_Geometry;

   procedure Validate_Histogram_Dimensions
     (Dimensions : Histogram_Dimension_Array)
   is
      Total : Long_Long_Integer := 1;
   begin
      if Dimensions'Length = 0
        or else Dimensions'Length > Maximum_Histogram_Dimensions
      then
         Histogram_Error
           ("Calculate_Histogram requires 1 .. 10 histogram dimensions");
      end if;
      for Dimension of Dimensions loop
         Validate_Bin_Geometry
           (Dimension.Bin_Count,
            Dimension.Lower_Bound,
            Dimension.Upper_Bound,
            Total,
            "Calculate_Histogram");
      end loop;
   end Validate_Histogram_Dimensions;

   procedure Validate_Source_Dimensions
     (Dimensions : Histogram_Source_Dimension_Array; Operation : String)
   is
      Total : Long_Long_Integer := 1;
   begin
      if Dimensions'Length = 0
        or else Dimensions'Length > Maximum_Histogram_Dimensions
      then
         Histogram_Error
           (Operation & " requires 1 .. 10 histogram dimensions");
      end if;
      for Dimension of Dimensions loop
         Validate_Bin_Geometry
           (Dimension.Bin_Count,
            Dimension.Lower_Bound,
            Dimension.Upper_Bound,
            Total,
            Operation);
      end loop;
   end Validate_Source_Dimensions;

   --  Every source is nonempty and 2-D, shares the first source's rows,
   --  columns and supported depth, and may have its own channel count.
   procedure Validate_Histogram_Sources
     (Sources : OpenCV.Core.Mat_Array; Operation : String)
   is
      use type OpenCV.Core.Depth_Type;
      First : OpenCV.Core.Mat;
   begin
      if Sources'Length = 0 then
         Histogram_Error (Operation & " requires a non-empty Sources array");
      end if;
      First := Sources (Sources'First);
      if First.Is_Empty then
         Histogram_Error (Operation & " requires a non-empty Source");
      elsif First.Dimension_Count /= 2 then
         Histogram_Error (Operation & " requires a two-dimensional Source");
      elsif First.Depth /= OpenCV.Core.UInt8
        and then First.Depth /= OpenCV.Core.UInt16
        and then First.Depth /= OpenCV.Core.Float32
      then
         Histogram_Error
           (Operation & " requires a UInt8, UInt16 or Float32 Source");
      end if;
      for Source of Sources loop
         if Source.Is_Empty then
            Histogram_Error (Operation & " requires a non-empty Source");
         elsif Source.Dimension_Count /= 2 then
            Histogram_Error (Operation & " requires a two-dimensional Source");
         elsif Source.Depth /= First.Depth
           or else Source.Rows /= First.Rows
           or else Source.Columns /= First.Columns
         then
            Histogram_Error
              (Operation
               & " requires every Source to share rows, columns, and depth");
         end if;
      end loop;
   end Validate_Histogram_Sources;

   procedure Validate_Source_Selection
     (Sources    : OpenCV.Core.Mat_Array;
      Dimensions : Histogram_Source_Dimension_Array;
      Operation  : String)
   is
      Position : Natural;
   begin
      for Dimension of Dimensions loop
         if Dimension.Source_Position >= Sources'Length then
            Histogram_Error
              (Operation
               & " selects a source position that Sources does not have");
         end if;
         Position := Sources'First + Dimension.Source_Position;
         if Dimension.Channel >= Natural (Sources (Position).Channels) then
            Histogram_Error
              (Operation
               & " selects a channel that the chosen Source does not have");
         end if;
      end loop;
   end Validate_Source_Selection;

   function To_Stored
     (Dimension : Histogram_Dimension) return Histogram_Source_Dimension
   is ((Source_Position => 0,
        Channel         => Dimension.Channel,
        Bin_Count       => Dimension.Bin_Count,
        Lower_Bound     => Dimension.Lower_Bound,
        Upper_Bound     => Dimension.Upper_Bound));

   function To_Public
     (Dimension : Histogram_Source_Dimension) return Histogram_Dimension
   is ((Channel     => Dimension.Channel,
        Bin_Count   => Dimension.Bin_Count,
        Lower_Bound => Dimension.Lower_Bound,
        Upper_Bound => Dimension.Upper_Bound));

   function To_C_Source
     (Dimension : Histogram_Source_Dimension)
      return Internal.C_API.Histogram_Source_Dimension_Record
   is ((Source_Position => Interfaces.Integer_32 (Dimension.Source_Position),
        Channel         => Interfaces.Integer_32 (Dimension.Channel),
        Bin_Count       => Interfaces.Integer_32 (Dimension.Bin_Count),
        Lower_Bound     => Interfaces.C.C_float (Dimension.Lower_Bound),
        Upper_Bound     => Interfaces.C.C_float (Dimension.Upper_Bound)));

   function To_C_Histogram_Dimensions
     (Dimensions : Histogram_Dimension_Array)
      return Internal.C_API.Histogram_Dimension_Records
   is
      Result :
        Internal.C_API.Histogram_Dimension_Records (1 .. Dimensions'Length);
      Target : Positive := Result'First;
   begin
      for Dimension of Dimensions loop
         Result (Target) :=
           (Channel     => Interfaces.Integer_32 (Dimension.Channel),
            Bin_Count   => Interfaces.Integer_32 (Dimension.Bin_Count),
            Lower_Bound => Interfaces.C.C_float (Dimension.Lower_Bound),
            Upper_Bound => Interfaces.C.C_float (Dimension.Upper_Bound));
         Target := Target + 1;
      end loop;
      return Result;
   end To_C_Histogram_Dimensions;

   function To_C_Source_Dimensions
     (Dimensions : Histogram_Source_Dimension_Array)
      return Internal.C_API.Histogram_Source_Dimension_Records
   is
      Result :
        Internal.C_API.Histogram_Source_Dimension_Records
          (1 .. Dimensions'Length);
      Target : Positive := Result'First;
   begin
      for Dimension of Dimensions loop
         Result (Target) := To_C_Source (Dimension);
         Target := Target + 1;
      end loop;
      return Result;
   end To_C_Source_Dimensions;

   function Stored_Dimensions
     (Value : Histogram) return Histogram_Dimension_Array
   is
      Result :
        Histogram_Dimension_Array (1 .. Natural (Value.Dimensions.Length));
   begin
      for Index in Result'Range loop
         Result (Index) := To_Public (Value.Dimensions.Element (Index));
      end loop;
      return Result;
   end Stored_Dimensions;

   function Stored_Source_Dimensions
     (Value : Histogram) return Histogram_Source_Dimension_Array
   is
      Result :
        Histogram_Source_Dimension_Array
          (1 .. Natural (Value.Dimensions.Length));
   begin
      for Index in Result'Range loop
         Result (Index) := Value.Dimensions.Element (Index);
      end loop;
      return Result;
   end Stored_Source_Dimensions;

   function All_Source_Positions_Are_Zero (Value : Histogram) return Boolean is
   begin
      for Dimension of Value.Dimensions loop
         if Dimension.Source_Position /= 0 then
            return False;
         end if;
      end loop;
      return True;
   end All_Source_Positions_Are_Zero;

   function Histogram_Dimension_Count (Value : Histogram) return Natural
   is (Natural (Value.Dimensions.Length));

   function Get_Histogram_Dimension
     (Value : Histogram; Index : Positive) return Histogram_Dimension is
   begin
      if Index > Natural (Value.Dimensions.Length) then
         Histogram_Error
           ("Get_Histogram_Dimension index exceeds the dimension count");
      end if;
      return To_Public (Value.Dimensions.Element (Index));
   end Get_Histogram_Dimension;

   function Get_Histogram_Source_Position
     (Value : Histogram; Index : Positive) return Natural is
   begin
      if Index > Natural (Value.Dimensions.Length) then
         Histogram_Error
           ("Get_Histogram_Source_Position index exceeds the dimension count");
      end if;
      return Value.Dimensions.Element (Index).Source_Position;
   end Get_Histogram_Source_Position;

   function Histogram_Values (Value : Histogram) return OpenCV.Core.Mat
   is (Value.Values.Clone);

   --  Calculates into a fresh Histogram that escapes only after success.
   function Build_Histogram
     (Source     : OpenCV.Core.Mat;
      Mask       : OpenCV.Core.Mat;
      Masked     : Boolean;
      Dimensions : Histogram_Dimension_Array) return Histogram
   is
      Records : aliased constant Internal.C_API.Histogram_Dimension_Records :=
        To_C_Histogram_Dimensions (Dimensions);
      Values  : OpenCV.Core.Mat;
      Status  : Internal.C_API.Status := Internal.C_API.Success;

      procedure With_Source
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure With_Output
           (Output_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure With_Mask
              (Mask_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Calc_Hist_Masked
                   (Source_Handle,
                    Mask_Handle,
                    Records (Records'First)'Access,
                    Records'Length,
                    Output_Handle);
            end With_Mask;
         begin
            if Masked then
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Mask, With_Mask'Access);
            else
               Status :=
                 Internal.C_API.Calc_Hist
                   (Source_Handle,
                    Records (Records'First)'Access,
                    Records'Length,
                    Output_Handle);
            end if;
         end With_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Values, With_Output'Access);
      end With_Source;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, With_Source'Access);
      Raise_On_Error (Status, "Calculate_Histogram");
      return Result : Histogram do
         Result.Values := Values;
         for Dimension of Dimensions loop
            Result.Dimensions.Append (To_Stored (Dimension));
         end loop;
      end return;
   end Build_Histogram;

   function Calculate_Histogram
     (Source : OpenCV.Core.Mat; Dimensions : Histogram_Dimension_Array)
      return Histogram
   is
      No_Mask : OpenCV.Core.Mat;
   begin
      Validate_Histogram_Dimensions (Dimensions);
      Validate_Histogram_Source (Source, Dimensions, "Calculate_Histogram");
      return Build_Histogram (Source, No_Mask, False, Dimensions);
   end Calculate_Histogram;

   function Calculate_Histogram
     (Source     : OpenCV.Core.Mat;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Dimension_Array) return Histogram
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
   begin
      Validate_Histogram_Dimensions (Dimensions);
      Validate_Histogram_Source (Source, Dimensions, "Calculate_Histogram");
      Validate_Histogram_Mask
        (Mask, Source.Rows, Source.Columns, "Calculate_Histogram");
      return Build_Histogram (Source, Mask, True, Dimensions);
   end Calculate_Histogram;

   --  Borrows every Sources element through a nested With_Input_Handle. No
   --  handle is stored: each callback remains active until Invoke runs at the
   --  deepest level, and the temporary handle array dies with that call.
   --  Sources must already be nonempty. Index is the zero-based iteration
   --  position, independent of Sources'First.
   procedure With_Source_Handles
     (Sources : OpenCV.Core.Mat_Array;
      Invoke  :
        not null access procedure
          (Handles :
             access constant OpenCV.Core.Module_Interop.Input_Mat_Handle;
           Count   : Interfaces.Integer_32))
   is
      Handles :
        aliased Internal.C_API.Mat_Handle_Array (0 .. Sources'Length - 1);

      procedure Enter (Index : Natural) is
         procedure Capture
           (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Handles (Index) := Handle;
            if Index + 1 = Sources'Length then
               Invoke
                 (Handles (0)'Access, Interfaces.Integer_32 (Sources'Length));
            else
               Enter (Index + 1);
            end if;
         end Capture;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Sources (Sources'First + Index), Capture'Access);
      end Enter;
   begin
      Enter (0);
   end With_Source_Handles;

   function Build_Multi_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Mask       : OpenCV.Core.Mat;
      Masked     : Boolean;
      Dimensions : Histogram_Source_Dimension_Array) return Histogram
   is
      Records :
        aliased constant Internal.C_API.Histogram_Source_Dimension_Records :=
          To_C_Source_Dimensions (Dimensions);
      Values  : OpenCV.Core.Mat;
      Status  : Internal.C_API.Status := Internal.C_API.Success;

      procedure Invoke
        (Handles : access constant OpenCV.Core.Module_Interop.Input_Mat_Handle;
         Count   : Interfaces.Integer_32)
      is
         procedure With_Output
           (Output_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure With_Mask
              (Mask_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Calc_Hist_Multi_Masked
                   (Handles,
                    Count,
                    Mask_Handle,
                    Records (Records'First)'Access,
                    Records'Length,
                    Output_Handle);
            end With_Mask;
         begin
            if Masked then
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Mask, With_Mask'Access);
            else
               Status :=
                 Internal.C_API.Calc_Hist_Multi
                   (Handles,
                    Count,
                    Records (Records'First)'Access,
                    Records'Length,
                    Output_Handle);
            end if;
         end With_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Values, With_Output'Access);
      end Invoke;
   begin
      With_Source_Handles (Sources, Invoke'Access);
      Raise_On_Error (Status, "Calculate_Histogram");
      return Result : Histogram do
         Result.Values := Values;
         for Dimension of Dimensions loop
            Result.Dimensions.Append (Dimension);
         end loop;
      end return;
   end Build_Multi_Histogram;

   function Calculate_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Dimensions : Histogram_Source_Dimension_Array) return Histogram
   is
      No_Mask : OpenCV.Core.Mat;
   begin
      Validate_Source_Dimensions (Dimensions, "Calculate_Histogram");
      Validate_Histogram_Sources (Sources, "Calculate_Histogram");
      Validate_Source_Selection (Sources, Dimensions, "Calculate_Histogram");
      return Build_Multi_Histogram (Sources, No_Mask, False, Dimensions);
   end Calculate_Histogram;

   function Calculate_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Source_Dimension_Array) return Histogram is
   begin
      Validate_Source_Dimensions (Dimensions, "Calculate_Histogram");
      Validate_Histogram_Sources (Sources, "Calculate_Histogram");
      Validate_Source_Selection (Sources, Dimensions, "Calculate_Histogram");
      Validate_Histogram_Mask
        (Mask,
         Sources (Sources'First).Rows,
         Sources (Sources'First).Columns,
         "Calculate_Histogram");
      return Build_Multi_Histogram (Sources, Mask, True, Dimensions);
   end Calculate_Histogram;

   function To_C_Histogram_Comparison
     (Method : Histogram_Comparison_Method) return Interfaces.Integer_32 is
   begin
      case Method is
         when Correlation                 =>
            return Internal.C_API.Histogram_Compare_Correlation;

         when Chi_Square                  =>
            return Internal.C_API.Histogram_Compare_Chi_Square;

         when Intersection                =>
            return Internal.C_API.Histogram_Compare_Intersection;

         when Hellinger_Distance          =>
            return Internal.C_API.Histogram_Compare_Hellinger;

         when Alternative_Chi_Square      =>
            return Internal.C_API.Histogram_Compare_Chi_Square_Alt;

         when Kullback_Leibler_Divergence =>
            return Internal.C_API.Histogram_Compare_KL_Divergence;
      end case;
   end To_C_Histogram_Comparison;

   function Compare_Histograms
     (Left   : Histogram;
      Right  : Histogram;
      Method : Histogram_Comparison_Method) return OpenCV.Float64_Value
   is
      use type Ada.Containers.Count_Type;
      use type OpenCV.Float32_Value;
      Result : aliased Interfaces.C.double := 0.0;
      Status : Internal.C_API.Status := Internal.C_API.Success;

      procedure With_Left
        (Left_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure With_Right
           (Right_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         begin
            Status :=
              Internal.C_API.Compare_Hist
                (Left_Handle,
                 Right_Handle,
                 To_C_Histogram_Comparison (Method),
                 Result'Access);
         end With_Right;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Right.Values, With_Right'Access);
      end With_Left;
   begin
      if Left.Dimensions.Is_Empty or else Right.Dimensions.Is_Empty then
         Histogram_Error ("Compare_Histograms requires calculated histograms");
      elsif Left.Dimensions.Length /= Right.Dimensions.Length then
         Histogram_Error
           ("Compare_Histograms requires the same number of dimensions");
      end if;
      for Index in 1 .. Natural (Left.Dimensions.Length) loop
         declare
            L : constant Histogram_Source_Dimension := Left.Dimensions (Index);
            R : constant Histogram_Source_Dimension :=
              Right.Dimensions (Index);
         begin
            if L.Bin_Count /= R.Bin_Count
              or else L.Lower_Bound /= R.Lower_Bound
              or else L.Upper_Bound /= R.Upper_Bound
            then
               Histogram_Error
                 ("Compare_Histograms requires identical bin counts and"
                  & " ranges in every dimension");
            end if;
         end;
      end loop;
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Left.Values, With_Left'Access);
      Raise_On_Error (Status, "Compare_Histograms");
      return OpenCV.Float64_Value (Result);
   end Compare_Histograms;

   function Back_Project
     (Source       : OpenCV.Core.Mat;
      Distribution : Histogram;
      Scale        : OpenCV.Float64_Value := 1.0) return OpenCV.Core.Mat
   is
      use type OpenCV.Float64_Value;
      Dimensions : constant Histogram_Dimension_Array :=
        Stored_Dimensions (Distribution);
   begin
      if Dimensions'Length = 0 then
         Histogram_Error ("Back_Project requires a calculated histogram");
      elsif not All_Source_Positions_Are_Zero (Distribution) then
         Histogram_Error
           ("Back_Project Source requires every histogram source position to"
            & " be 0; use the Sources overload");
      elsif not Is_Finite (Scale)
        or else abs Scale > OpenCV.Float64_Value (OpenCV.Float32_Value'Last)
      then
         Histogram_Error
           ("Back_Project requires a finite Float32-range Scale");
      end if;
      Validate_Histogram_Source (Source, Dimensions, "Back_Project");

      declare
         Records :
           aliased constant Internal.C_API.Histogram_Dimension_Records :=
             To_C_Histogram_Dimensions (Dimensions);
         Output  : OpenCV.Core.Mat;
         Status  : Internal.C_API.Status := Internal.C_API.Success;

         procedure With_Source
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure With_Histogram
              (Histogram_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure With_Output
                 (Output_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
               is
               begin
                  Status :=
                    Internal.C_API.Calc_Back_Project
                      (Source_Handle,
                       Histogram_Handle,
                       Records (Records'First)'Access,
                       Records'Length,
                       Interfaces.C.double (Scale),
                       Output_Handle);
               end With_Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Output, With_Output'Access);
            end With_Histogram;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Distribution.Values, With_Histogram'Access);
         end With_Source;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Source, With_Source'Access);
         Raise_On_Error (Status, "Back_Project");
         return Output;
      end;
   end Back_Project;

   function Back_Project
     (Sources      : OpenCV.Core.Mat_Array;
      Distribution : Histogram;
      Scale        : OpenCV.Float64_Value := 1.0) return OpenCV.Core.Mat
   is
      use type OpenCV.Float64_Value;
      Dimensions : constant Histogram_Source_Dimension_Array :=
        Stored_Source_Dimensions (Distribution);
      Output     : OpenCV.Core.Mat;
      Status     : Internal.C_API.Status := Internal.C_API.Success;
   begin
      if Dimensions'Length = 0 then
         Histogram_Error ("Back_Project requires a calculated histogram");
      elsif not Is_Finite (Scale)
        or else abs Scale > OpenCV.Float64_Value (OpenCV.Float32_Value'Last)
      then
         Histogram_Error
           ("Back_Project requires a finite Float32-range Scale");
      end if;
      Validate_Histogram_Sources (Sources, "Back_Project");
      Validate_Source_Selection (Sources, Dimensions, "Back_Project");

      declare
         Records :
           aliased constant Internal
                              .C_API
                              .Histogram_Source_Dimension_Records :=
             To_C_Source_Dimensions (Dimensions);

         procedure Invoke
           (Handles :
              access constant OpenCV.Core.Module_Interop.Input_Mat_Handle;
            Count   : Interfaces.Integer_32)
         is
            procedure With_Histogram
              (Histogram_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure With_Output
                 (Output_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
               is
               begin
                  Status :=
                    Internal.C_API.Calc_Back_Project_Multi
                      (Handles,
                       Count,
                       Histogram_Handle,
                       Records (Records'First)'Access,
                       Records'Length,
                       Interfaces.C.double (Scale),
                       Output_Handle);
               end With_Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Output, With_Output'Access);
            end With_Histogram;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Distribution.Values, With_Histogram'Access);
         end Invoke;
      begin
         With_Source_Handles (Sources, Invoke'Access);
      end;
      Raise_On_Error (Status, "Back_Project");
      return Output;
   end Back_Project;

   --  Adds a fresh delta histogram onto a clone of Base. Base is never
   --  passed to native calcHist, so OpenCV cannot reallocate it or convert
   --  its Float32 bins through signed int. The result is published only when
   --  every widened bin sum is a finite Float32.
   function Add_Histogram_Values
     (Base : Histogram; Increment : Histogram) return Histogram
   is
      Sum    : OpenCV.Core.Mat;
      Status : Internal.C_API.Status := Internal.C_API.Success;

      procedure With_Base
        (Base_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure With_Increment
           (Increment_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure With_Sum
              (Sum_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 Internal.C_API.Add_Histograms
                   (Base_Handle, Increment_Handle, Sum_Handle);
            end With_Sum;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Sum, With_Sum'Access);
         end With_Increment;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Increment.Values, With_Increment'Access);
      end With_Base;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Base.Values, With_Base'Access);
      Raise_On_Error (Status, "Accumulate_Histogram");
      return Result : Histogram do
         Result.Values := Sum;
         Result.Dimensions := Base.Dimensions;
      end return;
   end Add_Histogram_Values;

   function Accumulate_Histogram
     (Base : Histogram; Source : OpenCV.Core.Mat) return Histogram
   is
      Dimensions : constant Histogram_Dimension_Array :=
        Stored_Dimensions (Base);
   begin
      if Dimensions'Length = 0 then
         Histogram_Error
           ("Accumulate_Histogram requires a calculated histogram");
      elsif not All_Source_Positions_Are_Zero (Base) then
         Histogram_Error
           ("Accumulate_Histogram Source requires every histogram source"
            & " position to be 0; use the Sources overload");
      end if;
      return
        Add_Histogram_Values (Base, Calculate_Histogram (Source, Dimensions));
   end Accumulate_Histogram;

   function Accumulate_Histogram
     (Base : Histogram; Source : OpenCV.Core.Mat; Mask : OpenCV.Core.Mat)
      return Histogram
   is
      Dimensions : constant Histogram_Dimension_Array :=
        Stored_Dimensions (Base);
   begin
      if Dimensions'Length = 0 then
         Histogram_Error
           ("Accumulate_Histogram requires a calculated histogram");
      elsif not All_Source_Positions_Are_Zero (Base) then
         Histogram_Error
           ("Accumulate_Histogram Source requires every histogram source"
            & " position to be 0; use the Sources overload");
      end if;
      return
        Add_Histogram_Values
          (Base, Calculate_Histogram (Source, Mask, Dimensions));
   end Accumulate_Histogram;

   function Accumulate_Histogram
     (Base : Histogram; Sources : OpenCV.Core.Mat_Array) return Histogram
   is
      Dimensions : constant Histogram_Source_Dimension_Array :=
        Stored_Source_Dimensions (Base);
   begin
      if Dimensions'Length = 0 then
         Histogram_Error
           ("Accumulate_Histogram requires a calculated histogram");
      end if;
      return
        Add_Histogram_Values (Base, Calculate_Histogram (Sources, Dimensions));
   end Accumulate_Histogram;

   function Accumulate_Histogram
     (Base    : Histogram;
      Sources : OpenCV.Core.Mat_Array;
      Mask    : OpenCV.Core.Mat) return Histogram
   is
      Dimensions : constant Histogram_Source_Dimension_Array :=
        Stored_Source_Dimensions (Base);
   begin
      if Dimensions'Length = 0 then
         Histogram_Error
           ("Accumulate_Histogram requires a calculated histogram");
      end if;
      return
        Add_Histogram_Values
          (Base, Calculate_Histogram (Sources, Mask, Dimensions));
   end Accumulate_Histogram;

   procedure Validate_Pyramid_Mean_Shift_Filter
     (Source                : OpenCV.Core.Mat;
      Spatial_Radius        : OpenCV.Float64_Value;
      Color_Radius          : OpenCV.Float64_Value;
      Maximum_Pyramid_Level : Mean_Shift_Pyramid_Level;
      Termination           : Mean_Shift_Termination)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Float64_Value;

      Columns : Long_Long_Integer;
      Rows    : Long_Long_Integer;
   begin
      if Source.Is_Empty
        or else Source.Dimension_Count /= 2
        or else Source.Depth /= OpenCV.Core.UInt8
        or else Source.Channels /= 3
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Pyramid_Mean_Shift_Filter requires a non-empty two-dimensional"
            & " UInt8 C3 source Mat");
      end if;

      if not Is_Finite (Spatial_Radius) or else Spatial_Radius <= 0.0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Pyramid_Mean_Shift_Filter Spatial_Radius must be finite and"
            & " positive");
      end if;

      if not Is_Finite (Color_Radius) or else Color_Radius < 0.0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Pyramid_Mean_Shift_Filter Color_Radius must be finite and"
            & " nonnegative");
      end if;

      if not Is_Finite (Termination.Epsilon) or else Termination.Epsilon < 0.0
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Pyramid_Mean_Shift_Filter Epsilon must be finite and"
            & " nonnegative");
      end if;

      --  Portable policy: every generated level must remain at least 2 x 2.
      Columns := Long_Long_Integer (Source.Columns);
      Rows := Long_Long_Integer (Source.Rows);
      for Level in 1 .. Maximum_Pyramid_Level loop
         Columns := (Columns + 1) / 2;
         Rows := (Rows + 1) / 2;
         if Columns < 2 or else Rows < 2 then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Pyramid_Mean_Shift_Filter pyramid level"
               & Level'Image
               & " would be smaller than 2 x 2");
         end if;
      end loop;
   end Validate_Pyramid_Mean_Shift_Filter;

   procedure Pyramid_Mean_Shift_Filter
     (Source                : OpenCV.Core.Mat;
      Destination           : in out OpenCV.Core.Mat;
      Spatial_Radius        : OpenCV.Float64_Value;
      Color_Radius          : OpenCV.Float64_Value;
      Maximum_Pyramid_Level : Mean_Shift_Pyramid_Level := 1;
      Termination           : Mean_Shift_Termination :=
        (Maximum_Iterations => 5, Epsilon => 1.0))
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Filter_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Filter_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Pyramid_Mean_Shift_Filter
                (Source_Handle,
                 Destination_Handle,
                 Interfaces.C.double (Spatial_Radius),
                 Interfaces.C.double (Color_Radius),
                 Interfaces.Integer_32 (Maximum_Pyramid_Level),
                 Interfaces.Integer_32 (Termination.Maximum_Iterations),
                 Interfaces.C.double (Termination.Epsilon));
         end Filter_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Filter_Output'Access);
      end Filter_Input;
   begin
      Validate_Pyramid_Mean_Shift_Filter
        (Source,
         Spatial_Radius,
         Color_Radius,
         Maximum_Pyramid_Level,
         Termination);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Filter_Input'Access);
      Raise_On_Error (Status, "Pyramid_Mean_Shift_Filter");
   end Pyramid_Mean_Shift_Filter;

end OpenCV.Image_Processing;
