with OpenCV.Core;
private with Ada.Containers.Indefinite_Vectors;
private with Ada.Containers.Vectors;

package OpenCV.Image_Processing is

   type Color_Conversion is (BGR_To_Gray);

   type Interpolation_Method is
     (Nearest_Neighbor, Linear, Cubic, Area, Lanczos_4);

   type Canny_Aperture is (Sobel_3x3, Sobel_5x5, Sobel_7x7);

   type Canny_Gradient_Norm is (L1_Norm, L2_Norm);

   type Sobel_Kernel_Size is (Kernel_1, Kernel_3, Kernel_5, Kernel_7);

   type Laplacian_Kernel_Size is range 1 .. 31;

   subtype Median_Kernel_Size is Positive range 3 .. 2_147_483_647;

   subtype Bilateral_Diameter is Positive range 1 .. 2_147_483_647;

   subtype Derivative_Order is Natural range 0 .. 7;

   type Derivative_Axis is (X_Axis, Y_Axis);

   type Derivative_Depth is
     (Same_Depth, Int16_Depth, Float32_Depth, Float64_Depth);

   subtype Filter_Depth is Derivative_Depth;

   type Threshold_Mode is
     (Binary, Binary_Inverse, Truncate, To_Zero, To_Zero_Inverse);

   type Automatic_Threshold_Method is (Otsu, Triangle);

   type Adaptive_Threshold_Method is (Mean, Gaussian);

   type Adaptive_Threshold_Mode is (Binary, Binary_Inverse);

   subtype Adaptive_Block_Size is Positive range 3 .. 2_147_483_647;

   subtype Contour is OpenCV.Core.Point_Array;

   type Contour_Retrieval_Mode is
     (External_Only, Flat_List, Two_Level, Full_Tree);

   type Contour_Approximation_Mode is
     (Every_Point, Simple, Teh_Chin_L1, Teh_Chin_KCOS);

   type Contour_Index is new Natural;

   type Optional_Contour_Index (Present : Boolean := False) is record
      case Present is
         when False =>
            null;

         when True =>
            Index : Contour_Index;
      end case;
   end record;

   type Contour_Hierarchy_Entry is record
      Next        : Optional_Contour_Index;
      Previous    : Optional_Contour_Index;
      First_Child : Optional_Contour_Index;
      Parent      : Optional_Contour_Index;
   end record;

   type Contour_Set is private;

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

   --  Median_Blur replaces each Source pixel with the median of its square
   --  Kernel_Size neighborhood. Source must be a non-empty two-dimensional Mat
   --  with 1, 3, or 4 channels. Kernel_Size must be odd. Kernel sizes 3 and 5
   --  accept UInt8, UInt16, or Float32; larger kernels accept UInt8 only.
   --  Destination receives Source's rows, columns, depth, and channel count.
   --  Channels are filtered independently. OpenCV uses replicated-border
   --  handling internally; no public Border parameter is exposed. Source
   --  remains unchanged when distinct from Destination; direct in-place
   --  operation is supported. Contract violations and failures reported by
   --  OpenCV raise OpenCV.OpenCV_Error.
   procedure Median_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : Median_Kernel_Size);

   --  Box_Blur replaces each Source pixel with the normalized average of its
   --  Kernel_Size neighborhood. Source must be a non-empty two-dimensional Mat
   --  with depth UInt8, UInt16, Int16, Float32, or Float64. Channels are
   --  processed independently and are not restricted. Kernel width and height
   --  must be positive; they need not be odd or equal. Constant_Border,
   --  Replicate, Reflect, and Reflect_101 are supported; Wrap is rejected.
   --  The kernel uses OpenCV's centered default anchor. Destination receives
   --  Source's rows, columns, depth, and channel count. Source remains
   --  unchanged when distinct from Destination; direct in-place operation is
   --  supported. Contract violations and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   procedure Box_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Core.Size;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  Bilateral_Filter replaces Destination with an edge-preserving smoothing
   --  of Source. Spatial distance and pixel/color distance both weight the
   --  neighborhood average, so strong intensity or color discontinuities are
   --  preserved more than with a linear blur. Source must be a non-empty
   --  two-dimensional Mat of depth UInt8 or Float32 with exactly 1 or 3
   --  channels. For 3-channel Sources, color-distance weighting uses the
   --  combined color difference rather than filtering channels independently.
   --  Sigma_Color and Sigma_Space must be positive and finite. This overload
   --  asks OpenCV to derive the neighborhood diameter from Sigma_Space; there
   --  is no public zero or negative diameter sentinel. Constant_Border,
   --  Replicate, Reflect, and Reflect_101 are supported; Wrap is rejected.
   --  Destination receives Source's rows, columns, depth, and channel count.
   --  Source remains unchanged when Destination is distinct. Direct in-place
   --  operation is not supported. Contract violations and failures reported by
   --  OpenCV raise OpenCV.OpenCV_Error.
   procedure Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Sigma_Color : OpenCV.Core.Float64_Value;
      Sigma_Space : OpenCV.Core.Float64_Value;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  This overload is the same Bilateral_Filter operation with an explicit
   --  neighborhood Diameter. Diameter is a positive integer and need not be
   --  odd. OpenCV uses Diameter as the neighborhood size independently of
   --  Sigma_Space; Sigma_Space still weights samples inside that neighborhood.
   --  Direct in-place operation is not supported.
   procedure Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Diameter    : Bilateral_Diameter;
      Sigma_Color : OpenCV.Core.Float64_Value;
      Sigma_Space : OpenCV.Core.Float64_Value;
      Border      : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  Filter_2D replaces Destination with a linear correlation of Source
   --  against Kernel. This is correlation, not mathematical convolution: the
   --  kernel is not mirrored around the anchor. Source must be a non-empty
   --  two-dimensional Mat of depth UInt8, UInt16, Int16, Float32, or Float64.
   --  Channel count is unrestricted; the same single-channel Kernel is applied
   --  independently to every Source channel. Kernel must be a non-empty
   --  two-dimensional single-channel Float32 or Float64 Mat. Kernel dimensions
   --  need not be odd, square, or normalized. Destination_Depth selects the
   --  output depth using the same supported source/destination combinations as
   --  Sobel and Laplacian. Offset is added to each filtered value and must be
   --  finite. This overload uses OpenCV's centered default anchor; there is no
   --  public (-1, -1) sentinel. Constant_Border, Replicate, Reflect, and
   --  Reflect_101 are supported; Wrap is rejected. Destination receives
   --  Source's rows, columns, and channel count, with the requested depth.
   --  Source remains unchanged when Destination is distinct. Direct in-place
   --  operation is supported when the requested destination depth matches
   --  Source. Contract violations and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   procedure Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel            : OpenCV.Core.Mat;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  This overload is the same Filter_2D correlation with an explicit Kernel
   --  Anchor. Anchor must lie inside Kernel: X and Y are nonnegative and
   --  strictly less than Kernel's columns and rows. There is no public mixed
   --  or centered (-1, -1) sentinel in this overload. Direct in-place
   --  operation is supported when the requested destination depth matches
   --  Source.
   procedure Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel            : OpenCV.Core.Mat;
      Anchor            : OpenCV.Core.Point;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  Sep_Filter_2D replaces Destination with a separable linear filter of
   --  Source. Every Source row is filtered with Kernel_X, then every
   --  intermediate column is filtered with Kernel_Y, and Offset is added to
   --  the final value. Coefficient order is preserved; neither kernel is
   --  flipped. Source must be a non-empty two-dimensional Mat of depth UInt8,
   --  UInt16, Int16, Float32, or Float64. Channel count is unrestricted; the
   --  same Kernel_X and Kernel_Y pair is applied independently to every Source
   --  channel. Each kernel must be a non-empty two-dimensional single-channel
   --  Float32 or Float64 vector (one row or one column). Kernel lengths need
   --  not be odd, equal, normalized, or symmetric. Kernel_X and Kernel_Y must
   --  share the same floating-point depth because native OpenCV requires a
   --  common kernel type. Destination_Depth selects the output depth using
   --  the same supported source/destination combinations as Filter_2D. Offset
   --  is added to each filtered value and must be finite. This overload uses
   --  OpenCV's centered default anchor; there is no public (-1, -1) sentinel.
   --  Constant_Border, Replicate, Reflect, and Reflect_101 are supported;
   --  Wrap is rejected. Destination receives Source's rows, columns, and
   --  channel count, with the requested depth. Source remains unchanged when
   --  Destination is distinct. Direct in-place operation is supported when
   --  the requested destination depth matches Source. Contract violations and
   --  failures reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Sep_Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel_X          : OpenCV.Core.Mat;
      Kernel_Y          : OpenCV.Core.Mat;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  This overload is the same Sep_Filter_2D separable filter with an
   --  explicit Kernel Anchor. Anchor.X indexes Kernel_X and Anchor.Y indexes
   --  Kernel_Y using each kernel's logical length (columns if it is a row
   --  vector, otherwise rows). Both coordinates must be nonnegative and
   --  strictly less than the corresponding logical length. There is no public
   --  mixed or centered (-1, -1) sentinel in this overload. Direct in-place
   --  operation is supported when the requested destination depth matches
   --  Source.
   procedure Sep_Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel_X          : OpenCV.Core.Mat;
      Kernel_Y          : OpenCV.Core.Mat;
      Anchor            : OpenCV.Core.Point;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

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

   --  Sobel computes the X_Order/Y_Order spatial derivative independently for
   --  every Source channel. Source must be a non-empty two-dimensional UInt8,
   --  UInt16, Int16, Float32, or Float64 Mat. X_Order and Y_Order may not both
   --  be zero; each order must be less than Kernel_Size, except Kernel_1 uses
   --  OpenCV's special effective three-tap derivative kernel. Wrap is not
   --  supported. Scale and OpenCV's delta term (Offset) must be finite.
   --  Destination has Source's rows,
   --  columns, and channel count, with depth selected by Destination_Depth:
   --  UInt8 supports Same_Depth, Int16_Depth, Float32_Depth, and
   --  Float64_Depth.
   --  UInt16 and Int16 support Same_Depth, Float32_Depth, and Float64_Depth.
   --  Float32 supports Same_Depth or Float32_Depth; Float64 supports
   --  Same_Depth or Float64_Depth. OpenCV supports direct in-place use when
   --  Destination_Depth is Same_Depth; Source remains unchanged otherwise.
   --  Contract
   --  violations and failures reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Sobel
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      X_Order           : Derivative_Order;
      Y_Order           : Derivative_Order;
      Destination_Depth : Derivative_Depth := Float32_Depth;
      Kernel_Size       : Sobel_Kernel_Size := Kernel_3;
      Scale             : OpenCV.Core.Float64_Value := 1.0;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  Scharr computes the first spatial derivative in Axis independently for
   --  every Source channel. Its source, destination-depth, Scale, Delta, and
   --  Border requirements are the same as Sobel's. OpenCV supports direct
   --  in-place use when Destination_Depth is Same_Depth; Source remains
   --  unchanged otherwise. Contract violations and failures reported by
   --  OpenCV raise OpenCV.OpenCV_Error.
   procedure Scharr
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Axis              : Derivative_Axis;
      Destination_Depth : Derivative_Depth := Float32_Depth;
      Scale             : OpenCV.Core.Float64_Value := 1.0;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

   --  Laplacian computes the sum of the second X and Y derivatives for every
   --  Source channel. Source must be non-empty and two-dimensional with depth
   --  UInt8, UInt16, Int16, Float32, or Float64. Destination_Depth follows the
   --  same source/destination combinations as Sobel. Kernel_Size must be odd
   --  and between 1 and 31. Kernel size 1 uses OpenCV's dedicated 3 by 3
   --  Laplacian aperture. Scale multiplies computed values and Offset is added
   --  before storage; both must be finite. Constant_Border, Replicate,
   --  Reflect, and Reflect_101 are supported; Wrap is rejected. Channels are
   --  processed independently. Destination is replaced with a Mat having
   --  Source's rows, columns, channels, and requested depth. Source remains
   --  unchanged when distinct from Destination. Direct in-place operation is
   --  supported when Destination_Depth is Same_Depth.
   --  Contract violations and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   procedure Laplacian
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Destination_Depth : Derivative_Depth := Float32_Depth;
      Kernel_Size       : Laplacian_Kernel_Size := 1;
      Scale             : OpenCV.Core.Float64_Value := 1.0;
      Offset            : OpenCV.Core.Float64_Value := 0.0;
      Border            : OpenCV.Core.Border_Kind := OpenCV.Core.Reflect_101);

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

   --  Applies an adaptive binary threshold to a non-empty, two-dimensional,
   --  UInt8, single-channel Source. Block_Size must be odd. OpenCV calculates
   --  the local threshold as the arithmetic neighborhood mean or a
   --  Gaussian-weighted neighborhood mean, according to Method, minus Bias.
   --  Bias may be positive, zero, or negative and is passed directly to
   --  OpenCV. Maximum_Value is a UInt8 value, including zero. Destination is
   --  replaced with a UInt8 single-channel Mat having Source's rows and
   --  columns. Source remains unchanged when distinct from Destination; direct
   --  in-place operation is supported. OpenCV controls neighborhood border
   --  handling internally. Contract violations and OpenCV failures raise
   --  OpenCV.OpenCV_Error.
   procedure Apply_Adaptive_Threshold
     (Source        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Block_Size    : Adaptive_Block_Size;
      Method        : Adaptive_Threshold_Method := Mean;
      Mode          : Adaptive_Threshold_Mode := Binary;
      Bias          : OpenCV.Core.Float64_Value := 0.0;
      Maximum_Value : OpenCV.Core.UInt8_Value := 255);

   --  Extracts contours from a non-empty, two-dimensional UInt8 single-channel
   --  Source. Zero pixels are background and nonzero pixels are foreground.
   --  Source remains unchanged. Contours and hierarchy are copied into the
   --  returned Ada-owned Contour_Set. Indices are zero-based. An all-zero
   --  Source returns an empty set. Invalid Source metadata, invalid contour
   --  indices, and OpenCV failures raise OpenCV.OpenCV_Error.
   function Find_Contours
     (Source        : OpenCV.Core.Mat;
      Retrieval     : Contour_Retrieval_Mode := External_Only;
      Approximation : Contour_Approximation_Mode := Simple;
      Offset        : OpenCV.Core.Point := (X => 0, Y => 0))
      return Contour_Set;

   function Contour_Count (Self : Contour_Set) return Natural;

   function Get_Contour
     (Self : Contour_Set; Index : Contour_Index) return Contour;

   function Get_Hierarchy
     (Self : Contour_Set; Index : Contour_Index)
      return Contour_Hierarchy_Entry;

private
   package Contour_Vectors is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Natural,
        Element_Type => Contour,
        "="          => OpenCV.Core."=");
   package Hierarchy_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Natural,
        Element_Type => Contour_Hierarchy_Entry);

   type Contour_Set is record
      Contours  : Contour_Vectors.Vector;
      Hierarchy : Hierarchy_Vectors.Vector;
   end record;
end OpenCV.Image_Processing;
