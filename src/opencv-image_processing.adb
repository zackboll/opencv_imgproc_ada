with Ada.Exceptions;
with Interfaces;
with Interfaces.C;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing.Internal.C_API;

package body OpenCV.Image_Processing is

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
         when BGR_To_Gray =>
            return Internal.C_API.BGR_To_Gray;
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
     (Border : OpenCV.Core.Border_Kind) return Interfaces.Integer_32 is
   begin
      case Border is
         when OpenCV.Core.Constant_Border =>
            return Internal.C_API.Border_Constant;

         when OpenCV.Core.Replicate       =>
            return Internal.C_API.Border_Replicate;

         when OpenCV.Core.Reflect         =>
            return Internal.C_API.Border_Reflect;

         when OpenCV.Core.Reflect_101     =>
            return Internal.C_API.Border_Reflect_101;

         when OpenCV.Core.Wrap            =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Gaussian_Blur does not support Wrap border");
      end case;
   end To_C_Border;

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

   function To_C_Morphology_Operation
     (Operation : Morphology_Operation) return Interfaces.Integer_32 is
   begin
      case Operation is
         when Opening   =>
            return Internal.C_API.Morphology_Open;

         when Closing   =>
            return Internal.C_API.Morphology_Close;

         when Gradient  =>
            return Internal.C_API.Morphology_Gradient;

         when Top_Hat   =>
            return Internal.C_API.Morphology_Top_Hat;

         when Black_Hat =>
            return Internal.C_API.Morphology_Black_Hat;
      end case;
   end To_C_Morphology_Operation;

   procedure Validate_BGR_To_Gray (Source : OpenCV.Core.Mat) is
      use type OpenCV.Core.Channel_Count;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "BGR_To_Gray requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "BGR_To_Gray requires a two-dimensional source Mat");
      end if;

      if Source.Channels /= 3 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "BGR_To_Gray requires a source Mat with exactly 3 channels");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8 | OpenCV.Core.UInt16 | OpenCV.Core.Float32 =>
            null;

         when others                                                       =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "BGR_To_Gray requires a UInt8, UInt16, or Float32 source Mat");
      end case;
   end Validate_BGR_To_Gray;

   procedure Validate_Conversion
     (Source : OpenCV.Core.Mat; Conversion : Color_Conversion) is
   begin
      case Conversion is
         when BGR_To_Gray =>
            Validate_BGR_To_Gray (Source);
      end case;
   end Validate_Conversion;

   procedure Validate_Resize
     (Source : OpenCV.Core.Mat; Output_Size : OpenCV.Core.Size)
   is
      use type OpenCV.Core.Size_Coordinate;
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
      Kernel_Size : OpenCV.Core.Size;
      Sigma       : OpenCV.Core.Float64_Value;
      Border      : OpenCV.Core.Border_Kind)
   is
      use type OpenCV.Core.Border_Kind;
      use type OpenCV.Core.Float64_Value;
      use type OpenCV.Core.Size_Coordinate;
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
        or else Sigma > OpenCV.Core.Float64_Value'Last
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Gaussian_Blur requires a positive finite sigma");
      end if;

      if Border = OpenCV.Core.Wrap then
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

   procedure Validate_Morphology
     (Source      : OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Core.Size;
      Border      : OpenCV.Core.Border_Kind;
      Operation   : String)
   is
      use type OpenCV.Core.Border_Kind;
      use type OpenCV.Core.Size_Coordinate;
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

      if Kernel_Size.Width = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a positive kernel width");
      end if;

      if Kernel_Size.Height = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a positive kernel height");
      end if;

      if Border = OpenCV.Core.Wrap then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " does not support Wrap border");
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
   end Validate_Morphology;

   procedure Validate_Canny
     (Source          : OpenCV.Core.Mat;
      Lower_Threshold : OpenCV.Core.Float64_Value;
      Upper_Threshold : OpenCV.Core.Float64_Value)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Core.Float64_Value;
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
        or else Lower_Threshold > OpenCV.Core.Float64_Value'Last
        or else Lower_Threshold < 0.0
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Canny_Edges requires a finite nonnegative lower threshold");
      end if;

      if Upper_Threshold /= Upper_Threshold
        or else Upper_Threshold > OpenCV.Core.Float64_Value'Last
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
      Scale             : OpenCV.Core.Float64_Value;
      Offset            : OpenCV.Core.Float64_Value;
      Border            : OpenCV.Core.Border_Kind;
      Operation         : String)
   is
      use type OpenCV.Core.Border_Kind;
      use type OpenCV.Core.Float64_Value;
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
        or else Scale > OpenCV.Core.Float64_Value'Last
        or else Scale < OpenCV.Core.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a finite scale");
      elsif Offset /= Offset
        or else Offset > OpenCV.Core.Float64_Value'Last
        or else Offset < OpenCV.Core.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a finite delta");
      elsif Border = OpenCV.Core.Wrap then
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
      Scale             : OpenCV.Core.Float64_Value;
      Offset            : OpenCV.Core.Float64_Value;
      Border            : OpenCV.Core.Border_Kind)
   is
      Effective_Kernel_Size : Derivative_Order;
   begin
      Validate_Derivative
        (Source, Destination_Depth, Scale, Offset, Border, "Sobel");

      if X_Order = 0 and then Y_Order = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sobel requires a nonzero X_Order or Y_Order");
      end if;

      case Kernel_Size is
         when Kernel_1 | Kernel_3 =>
            Effective_Kernel_Size := 3;

         when Kernel_5            =>
            Effective_Kernel_Size := 5;

         when Kernel_7            =>
            Effective_Kernel_Size := 7;
      end case;

      if X_Order >= Effective_Kernel_Size
        or else Y_Order >= Effective_Kernel_Size
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Sobel derivative orders must be less than the effective "
            & "kernel size");
      end if;
   end Validate_Sobel;

   procedure Validate_Threshold
     (Source                         : OpenCV.Core.Mat;
      Threshold_Value, Maximum_Value : OpenCV.Core.Float64_Value)
   is
      use type OpenCV.Core.Float64_Value;
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
        or else Threshold_Value > OpenCV.Core.Float64_Value'Last
        or else Threshold_Value < OpenCV.Core.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Threshold requires a finite threshold value");
      elsif Maximum_Value /= Maximum_Value
        or else Maximum_Value > OpenCV.Core.Float64_Value'Last
        or else Maximum_Value < OpenCV.Core.Float64_Value'First
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
      Maximum_Value : OpenCV.Core.Float64_Value)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Core.Float64_Value;
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
        or else Maximum_Value > OpenCV.Core.Float64_Value'Last
        or else Maximum_Value < OpenCV.Core.Float64_Value'First
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
      Bias       : OpenCV.Core.Float64_Value)
   is
      use type OpenCV.Core.Channel_Count;
      use type OpenCV.Core.Depth_Type;
      use type OpenCV.Core.Float64_Value;
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
        or else Bias > OpenCV.Core.Float64_Value'Last
        or else Bias < OpenCV.Core.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Apply_Adaptive_Threshold requires a finite bias");
      end if;
   end Validate_Adaptive_Threshold;

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
      Output_Size   : OpenCV.Core.Size;
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
      Kernel_Size : OpenCV.Core.Size;
      Sigma       : OpenCV.Core.Float64_Value;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101)
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

   type Basic_Morphology_Operation is (Erosion, Dilation);

   procedure Apply_Basic_Morphology
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Core.Size;
      Shape       : Morphology_Shape;
      Iterations  : Morphology_Iterations;
      Border      : OpenCV.Core.Border_Kind;
      Operation   : Basic_Morphology_Operation)
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;

      procedure Morphology_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Morphology_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            Kernel_Width  : constant Interfaces.Integer_32 :=
              Interfaces.Integer_32 (Kernel_Size.Width);
            Kernel_Height : constant Interfaces.Integer_32 :=
              Interfaces.Integer_32 (Kernel_Size.Height);
            C_Shape       : constant Interfaces.Integer_32 :=
              To_C_Morphology_Shape (Shape);
            C_Iterations  : constant Interfaces.Integer_32 :=
              Interfaces.Integer_32 (Iterations);
            C_Border      : constant Interfaces.Integer_32 :=
              To_C_Border (Border);
         begin
            case Operation is
               when Erosion  =>
                  Status :=
                    Internal.C_API.Erode
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_Width,
                       Kernel_Height,
                       C_Shape,
                       C_Iterations,
                       C_Border);

               when Dilation =>
                  Status :=
                    Internal.C_API.Dilate
                      (Source_Handle,
                       Destination_Handle,
                       Kernel_Width,
                       Kernel_Height,
                       C_Shape,
                       C_Iterations,
                       C_Border);
            end case;
         end Morphology_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Morphology_Output'Access);
      end Morphology_Input;

      Name : constant String :=
        (case Operation is
           when Erosion  => "Erode",
           when Dilation => "Dilate");
   begin
      Validate_Morphology (Source, Kernel_Size, Border, Name);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Morphology_Input'Access);
      Raise_On_Error (Status, Name);
   end Apply_Basic_Morphology;

   procedure Erode
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Core.Size;
      Shape       : Morphology_Shape := Rectangle;
      Iterations  : Morphology_Iterations := 1;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Constant_Border) is
   begin
      Apply_Basic_Morphology
        (Source, Destination, Kernel_Size, Shape, Iterations, Border, Erosion);
   end Erode;

   procedure Dilate
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Core.Size;
      Shape       : Morphology_Shape := Rectangle;
      Iterations  : Morphology_Iterations := 1;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Constant_Border) is
   begin
      Apply_Basic_Morphology
        (Source,
         Destination,
         Kernel_Size,
         Shape,
         Iterations,
         Border,
         Dilation);
   end Dilate;

   procedure Apply_Morphology
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Operation   : Morphology_Operation;
      Kernel_Size : OpenCV.Core.Size;
      Shape       : Morphology_Shape := Rectangle;
      Iterations  : Morphology_Iterations := 1;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Constant_Border)
   is
      Status : Internal.C_API.Status := Internal.C_API.Success;

      procedure Morphology_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Morphology_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Internal.C_API.Morphology_Ex
                (Source_Handle,
                 Destination_Handle,
                 To_C_Morphology_Operation (Operation),
                 Interfaces.Integer_32 (Kernel_Size.Width),
                 Interfaces.Integer_32 (Kernel_Size.Height),
                 To_C_Morphology_Shape (Shape),
                 Interfaces.Integer_32 (Iterations),
                 To_C_Border (Border));
         end Morphology_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Morphology_Output'Access);
      end Morphology_Input;

      Name : constant String :=
        (case Operation is
           when Opening   => "Opening",
           when Closing   => "Closing",
           when Gradient  => "Gradient",
           when Top_Hat   => "Top_Hat",
           when Black_Hat => "Black_Hat");
   begin
      Validate_Morphology (Source, Kernel_Size, Border, Name);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Morphology_Input'Access);
      Raise_On_Error (Status, Name);
   end Apply_Morphology;

   procedure Canny_Edges
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Lower_Threshold : OpenCV.Core.Float64_Value;
      Upper_Threshold : OpenCV.Core.Float64_Value;
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
      Scale             : OpenCV.Core.Float64_Value := 1.0;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101)
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
      Scale             : OpenCV.Core.Float64_Value := 1.0;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101)
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
      Scale             : OpenCV.Core.Float64_Value := 1.0;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101)
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
      Threshold_Value : OpenCV.Core.Float64_Value;
      Mode            : Threshold_Mode := Binary;
      Maximum_Value   : OpenCV.Core.Float64_Value := 255.0)
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
      Computed_Threshold : out OpenCV.Core.Float64_Value;
      Method             : Automatic_Threshold_Method := Otsu;
      Mode               : Threshold_Mode := Binary;
      Maximum_Value      : OpenCV.Core.Float64_Value := 255.0)
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
      Computed_Threshold := OpenCV.Core.Float64_Value (Computed);
   end Apply_Automatic_Threshold;

   procedure Apply_Adaptive_Threshold
     (Source        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Block_Size    : Adaptive_Block_Size;
      Method        : Adaptive_Threshold_Method := Mean;
      Mode          : Adaptive_Threshold_Mode := Binary;
      Bias          : OpenCV.Core.Float64_Value := 0.0;
      Maximum_Value : OpenCV.Core.UInt8_Value := 255)
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

   function Find_Contours
     (Source        : OpenCV.Core.Mat;
      Retrieval     : Contour_Retrieval_Mode := External_Only;
      Approximation : Contour_Approximation_Mode := Simple;
      Offset        : OpenCV.Core.Point := (X => 0, Y => 0)) return Contour_Set
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
                                OpenCV.Core.Point_Coordinate
                                  (Raw_Points (Point_Index).X),
                              Y =>
                                OpenCV.Core.Point_Coordinate
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

end OpenCV.Image_Processing;
