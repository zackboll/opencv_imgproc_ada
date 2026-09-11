with OpenCV.Core;

package OpenCV.Image_Processing is

   type Color_Conversion is (BGR_To_Gray);

   type Interpolation_Method is
     (Nearest_Neighbor, Linear, Cubic, Area, Lanczos_4);

   type Canny_Aperture is (Sobel_3x3, Sobel_5x5, Sobel_7x7);

   type Canny_Gradient_Norm is (L1_Norm, L2_Norm);

   type Threshold_Mode is
     (Binary, Binary_Inverse, Truncate, To_Zero, To_Zero_Inverse);

   type Automatic_Threshold_Method is (Otsu, Triangle);

   type Morphology_Shape is (Rectangle, Cross, Ellipse);

   type Morphology_Operation is
     (Opening, Closing, Gradient, Top_Hat, Black_Hat);

   subtype Morphology_Iterations is Positive range 1 .. 2_147_483_647;

   --  BGR_To_Gray converts a non-empty, two-dimensional, three-channel BGR
   --  Source whose depth is UInt8, UInt16, or Float32. Destination is replaced
   --  with a Mat having Source's rows, columns, and depth, and exactly one
   --  channel. Source remains valid and is not modified. Empty Sources and
   --  unsupported Source dimensions, channel counts, or depths raise
   --  OpenCV.OpenCV_Error before the imgproc shim is called. Failures reported
   --  by OpenCV also raise OpenCV.OpenCV_Error.
   procedure Convert_Color
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Conversion  : Color_Conversion);

   --  Resize replaces Destination with a Mat of Output_Size whose depth and
   --  channel count equal Source's. Source must be a non-empty two-dimensional
   --  Mat with depth UInt8, UInt16, Int16, Float32, or Float64. Output_Size
   --  must have nonzero width and height. Source remains valid and is not
   --  modified. Contract violations and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   procedure Resize
     (Source        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Core.Size;
      Interpolation : Interpolation_Method := Linear);

   --  Gaussian_Blur convolves Source with an isotropic Gaussian kernel.
   --  Source must be a non-empty two-dimensional Mat with depth UInt8, UInt16,
   --  Int16, Float32, or Float64. Kernel_Size dimensions must be positive and
   --  odd, and Sigma must be positive and finite. Constant_Border, Replicate,
   --  Reflect, and Reflect_101 are supported; Wrap is rejected. Destination is
   --  replaced with a Mat having Source's rows, columns, depth, and channel
   --  count. Source remains valid and is not modified. Contract violations and
   --  failures reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Gaussian_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Core.Size;
      Sigma       : OpenCV.Core.Float64_Value;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  Erode replaces Destination with the neighborhood minimum selected by a
   --  temporary structuring element of Kernel_Size and Shape. Source must be a
   --  non-empty two-dimensional Mat of depth UInt8, UInt16, Int16, Float32, or
   --  Float64; channels are processed independently. Kernel dimensions must be
   --  positive, but need not be odd, and Iterations is at least one.
   --  Constant_Border, Replicate, Reflect, and Reflect_101 are supported; Wrap
   --  is rejected. Constant_Border uses OpenCV's morphology default border
   --  value. Destination receives Source's geometry and element type. Source
   --  remains unchanged unless it is also Destination, which is supported for
   --  in-place erosion. Contract violations and OpenCV failures raise
   --  OpenCV.OpenCV_Error.
   procedure Erode
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Core.Size;
      Shape       : Morphology_Shape := Rectangle;
      Iterations  : Morphology_Iterations := 1;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Constant_Border);

   --  Dilate replaces Destination with the neighborhood maximum selected by a
   --  temporary structuring element of Kernel_Size and Shape. It has the same
   --  source depth, channel, kernel-size, iteration, border, destination, and
   --  in-place semantics as Erode. Constant_Border uses OpenCV's morphology
   --  default border value. Contract violations and OpenCV failures raise
   --  OpenCV.OpenCV_Error.
   procedure Dilate
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Core.Size;
      Shape       : Morphology_Shape := Rectangle;
      Iterations  : Morphology_Iterations := 1;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Constant_Border);

   --  Apply_Morphology performs Opening, Closing, Gradient, Top_Hat, or
   --  Black_Hat with a temporary structuring element of Kernel_Size and Shape.
   --  Source must be a non-empty two-dimensional Mat of depth UInt8, UInt16,
   --  Int16, Float32, or Float64; channels are processed independently. Kernel
   --  dimensions must be positive, but need not be odd, and Iterations is at
   --  least one. Constant_Border, Replicate, Reflect, and Reflect_101 are
   --  supported; Wrap is rejected. Constant_Border uses OpenCV's morphology
   --  default border value. Destination receives Source's geometry and element
   --  type. Source remains unchanged unless it is also Destination, which is
   --  supported in-place. Contract violations and OpenCV failures raise
   --  OpenCV.OpenCV_Error.
   procedure Apply_Morphology
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Operation   : Morphology_Operation;
      Kernel_Size : OpenCV.Core.Size;
      Shape       : Morphology_Shape := Rectangle;
      Iterations  : Morphology_Iterations := 1;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Constant_Border);

   --  Canny_Edges finds edges in a non-empty two-dimensional UInt8 C1 Source.
   --  Lower_Threshold and Upper_Threshold must be finite, nonnegative, and
   --  ordered lower to upper. Destination is replaced with a UInt8 C1 Mat of
   --  Source's geometry. Source remains valid and is not modified. Contract
   --  violations and failures reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Canny_Edges
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Lower_Threshold : OpenCV.Core.Float64_Value;
      Upper_Threshold : OpenCV.Core.Float64_Value;
      Aperture        : Canny_Aperture := Sobel_3x3;
      Gradient_Norm   : Canny_Gradient_Norm := L1_Norm);

   --  Applies a fixed threshold independently to every channel of Source.
   --  Source must be non-empty, two-dimensional, and UInt8, UInt16, Int16,
   --  Float32, or Float64; any channel count is accepted. Threshold_Value and
   --  Maximum_Value must be finite. Destination is replaced with Source's
   --  rows,
   --  columns, depth, and channel count. Source remains unchanged.
   --  Maximum_Value affects only Binary and Binary_Inverse; it is ignored by
   --  Truncate, To_Zero, and To_Zero_Inverse.
   procedure Apply_Threshold
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Threshold_Value : OpenCV.Core.Float64_Value;
      Mode            : Threshold_Mode := Binary;
      Maximum_Value   : OpenCV.Core.Float64_Value := 255.0);

   --  Applies Otsu or Triangle automatic thresholding to a non-empty,
   --  two-dimensional, single-channel Source. Maximum_Value must be finite.
   --  Otsu accepts UInt8 and UInt16 Sources; Triangle accepts UInt8 only.
   --  Destination is replaced with a single-channel Mat having Source's rows,
   --  columns, and depth. Computed_Threshold receives OpenCV's selected value
   --  on success. Source remains unchanged. Maximum_Value affects only Binary
   --  and Binary_Inverse; it is ignored by the other threshold modes. Contract
   --  violations and failures reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Apply_Automatic_Threshold
     (Source             : OpenCV.Core.Mat;
      Destination        : in out OpenCV.Core.Mat;
      Computed_Threshold : out OpenCV.Core.Float64_Value;
      Method             : Automatic_Threshold_Method := Otsu;
      Mode               : Threshold_Mode := Binary;
      Maximum_Value      : OpenCV.Core.Float64_Value := 255.0);

end OpenCV.Image_Processing;
