with Ada.Numerics;
with OpenCV.Core;
private with Ada.Containers.Indefinite_Vectors;
private with Ada.Containers.Vectors;

package OpenCV.Image_Processing is

   type Phase_Correlation_Result is record
      X_Shift, Y_Shift, Response : OpenCV.Float64_Value;
   end record;
   --  Matching nonempty 2-D Float32/Float64 C1 sources; Window, when
   --  supplied, has the same geometry and type. Invalid inputs raise
   --  OpenCV_Error. No conversion or normalization is performed.
   --  Shift describes Source_2 relative to Source_1: right/down is positive.
   --  Apply the negative shift to Source_2 to align it with Source_1.
   --  Response is native normalized 5x5 peak energy, not a probability or
   --  a guaranteed [0, 1] value. Nonfinite samples retain native behavior.
   --  All inputs are independently snapshotted, including Window. Regions
   --  contribute only logical pixels; aliases are supported and unchanged
   --  on success or failure. Native signed DFT limits raise OpenCV_Error.
   function Phase_Correlate
     (Source_1, Source_2 : OpenCV.Core.Mat) return Phase_Correlation_Result;
   function Phase_Correlate
     (Source_1, Source_2, Window : OpenCV.Core.Mat)
      return Phase_Correlation_Result;

   type Hanning_Window_Depth is
     (Float32_Hanning_Window, Float64_Hanning_Window);
   --  Both dimensions must exceed one (otherwise OpenCV_Error).
   --  Fresh owning C1 Mat of the requested depth and geometry. Preserves
   --  native sqrt(separable Hann product), including native rounding.
   function Create_Hanning_Window
     (Window_Size : OpenCV.Size;
      Depth       : Hanning_Window_Depth := Float64_Hanning_Window)
      return OpenCV.Core.Mat;

   --  Image/pixel accumulation, not histogram accumulation. All inputs are
   --  nonempty 2-D Mats of identical geometry. Base is Float32 or Float64
   --  with Source's channel count. Plain accumulation accepts UInt8, UInt16,
   --  Float32 and Float64 (Float64 requires a Float64 Base), any channels.
   --  Square, product and running average accept UInt8/Float32 C1 or C3.
   --  Product sources have identical types. Invalid inputs raise OpenCV_Error.
   --  Mask overloads require UInt8 C1 of matching geometry: zero preserves
   --  Base, any nonzero sample enables every channel at that pixel.
   --  Each function updates a private Base clone and returns fresh independent
   --  storage only after success. Inputs and Region parents are never
   --  modified; Regions contribute only logical pixels. All input storage
   --  aliases are supported. Native floating overflow is not saturated or
   --  prohibited.
   function Accumulate_Image
     (Source, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;
   function Accumulate_Image
     (Source, Base, Mask : OpenCV.Core.Mat) return OpenCV.Core.Mat;
   function Accumulate_Image_Square
     (Source, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;
   function Accumulate_Image_Square
     (Source, Base, Mask : OpenCV.Core.Mat) return OpenCV.Core.Mat;
   function Accumulate_Image_Product
     (Source_1, Source_2, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;
   function Accumulate_Image_Product
     (Source_1, Source_2, Base, Mask : OpenCV.Core.Mat) return OpenCV.Core.Mat;
   --  Result = (1-Weight)*Base + Weight*Source at enabled pixels.
   --  Weight must be finite and in 0.0 .. 1.0 (otherwise OpenCV_Error).
   function Update_Running_Average
     (Source, Base : OpenCV.Core.Mat; Weight : OpenCV.Float64_Value)
      return OpenCV.Core.Mat;
   function Update_Running_Average
     (Source, Base, Mask : OpenCV.Core.Mat; Weight : OpenCV.Float64_Value)
      return OpenCV.Core.Mat;

   type Integral_Sum_Depth is
     (Int32_Integral, Float32_Integral, Float64_Integral);
   type Integral_Squared_Depth is
     (Float32_Squared_Integral, Float64_Squared_Integral);
   type Integral_Sum_And_Squares_Result is record
      Sum         : OpenCV.Core.Mat;
      Squared_Sum : OpenCV.Core.Mat;
   end record;
   type Integral_Images_Result is record
      Sum         : OpenCV.Core.Mat;
      Squared_Sum : OpenCV.Core.Mat;
      Tilted_Sum  : OpenCV.Core.Mat;
   end record;

   --  Nonempty 2-D UInt8, Float32 or Float64 source. Each channel is
   --  independent; results are fresh (Rows+1, Columns+1) Mats with a zero
   --  top row and left column. A Region is its own logical image.
   --  UInt8/Int32 is rejected if any actual channel total exceeds INT_MAX.
   function Integral_Sum
     (Source    : OpenCV.Core.Mat;
      Sum_Depth : Integral_Sum_Depth := Float64_Integral)
      return OpenCV.Core.Mat;
   function Integral_Sum_And_Squares
     (Source        : OpenCV.Core.Mat;
      Sum_Depth     : Integral_Sum_Depth := Float64_Integral;
      Squared_Depth : Integral_Squared_Depth := Float64_Squared_Integral)
      return Integral_Sum_And_Squares_Result;
   function Integral_Images
     (Source        : OpenCV.Core.Mat;
      Sum_Depth     : Integral_Sum_Depth := Float64_Integral;
      Squared_Depth : Integral_Squared_Depth := Float64_Squared_Integral)
      return Integral_Images_Result;

   type Distance_Transform_Method is
     (Manhattan_Distance,
      Chessboard_Distance,
      Euclidean_3x3,
      Euclidean_5x5,
      Euclidean_Precise);
   type Labeled_Distance_Metric is
     (Manhattan_Label_Distance,
      Euclidean_Label_Distance,
      Chessboard_Label_Distance);
   type Distance_Label_Mode is (Nearest_Zero_Component, Nearest_Zero_Pixel);
   type Labeled_Distance_Transform_Result is record
      Distances : OpenCV.Core.Mat;
      Labels    : OpenCV.Core.Mat;
   end record;

   --  Source is a nonempty 2-D UInt8 C1 image containing at least one zero.
   --  Every nonzero pixel is foreground. Results are fresh, source-preserving
   --  Mats of the same geometry; Regions are independent logical images.
   --  L1 and chessboard distances are exact. Euclidean_3x3 and Euclidean_5x5
   --  use OpenCV's approximate weights; Euclidean_Precise is exact up to
   --  Float32 rounding. The result is Float32 C1.
   function Distance_Transform
     (Source : OpenCV.Core.Mat;
      Method : Distance_Transform_Method := Euclidean_Precise)
      return OpenCV.Core.Mat;

   --  Exact L1 distance, UInt8 C1, saturating at 255.
   function Manhattan_Distance_Transform_UInt8
     (Source : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Distances are Float32 C1, Labels Int32 C1. Component mode groups
   --  8-connected zero pixels; pixel mode assigns row-major positive labels
   --  to individual zeros. Ties have no specified winner. Euclidean labeled
   --  distances use the native 5x5 approximation; precise is unavailable.
   function Distance_Transform_With_Labels
     (Source : OpenCV.Core.Mat;
      Metric : Labeled_Distance_Metric := Euclidean_Label_Distance;
      Labels : Distance_Label_Mode := Nearest_Zero_Component)
      return Labeled_Distance_Transform_Result;

   type Color_Conversion is
     (BGR_To_Gray,
      RGB_To_Gray,
      BGRA_To_Gray,
      RGBA_To_Gray,
      Gray_To_BGR,
      Gray_To_RGB,
      Gray_To_BGRA,
      Gray_To_RGBA,
      BGR_To_RGB,
      RGB_To_BGR,
      BGR_To_BGRA,
      RGB_To_RGBA,
      BGR_To_RGBA,
      RGB_To_BGRA,
      BGRA_To_BGR,
      RGBA_To_RGB,
      RGBA_To_BGR,
      BGRA_To_RGB,
      BGRA_To_RGBA,
      RGBA_To_BGRA,
      BGR_To_XYZ,
      RGB_To_XYZ,
      XYZ_To_BGR,
      XYZ_To_RGB,
      BGR_To_YCrCb,
      RGB_To_YCrCb,
      YCrCb_To_BGR,
      YCrCb_To_RGB,
      BGR_To_YUV,
      RGB_To_YUV,
      YUV_To_BGR,
      YUV_To_RGB,
      BGR_To_HSV,
      RGB_To_HSV,
      HSV_To_BGR,
      HSV_To_RGB,
      BGR_To_HLS,
      RGB_To_HLS,
      HLS_To_BGR,
      HLS_To_RGB,
      BGR_To_Lab,
      RGB_To_Lab,
      Lab_To_BGR,
      Lab_To_RGB,
      BGR_To_Luv,
      RGB_To_Luv,
      Luv_To_BGR,
      Luv_To_RGB);

   type Interpolation_Method is
     (Nearest_Neighbor, Linear, Cubic, Area, Lanczos_4);

   type Polar_Mapping is (Linear_Polar, Logarithmic_Polar);
   type Polar_Direction is (Cartesian_To_Polar, Polar_To_Cartesian);

   type Canny_Aperture is (Sobel_3x3, Sobel_5x5, Sobel_7x7);

   type Canny_Gradient_Norm is (L1_Norm, L2_Norm);

   type Sobel_Kernel_Size is (Kernel_1, Kernel_3, Kernel_5, Kernel_7);

   --  Corner derivatives use 3, 5 or 7; pre-corner detection needs second
   --  derivatives, so the Sobel Kernel_1 selector is not applicable.
   type Corner_Aperture is (Aperture_3, Aperture_5, Aperture_7);
   subtype Corner_Block_Size is Positive range 1 .. 2_147_483_647;
   type Corner_Point_Array is array (Integer range <>) of OpenCV.Float32_Point;
   subtype Corner_Iteration_Limit is Positive range 1 .. 100;
   type Corner_Termination is record
      Maximum_Iterations : Corner_Iteration_Limit := 30;
      Epsilon            : OpenCV.Float64_Value := 0.01;
   end record;
   type Corner_Dead_Zone (Enabled : Boolean := False) is record
      case Enabled is
         when False =>
            null;

         when True =>
            Half_Size : OpenCV.Size;
      end case;
   end record;

   --  All response maps accept nonempty 2-D UInt8/Float32 C1 images, leave
   --  Source unchanged, and treat Regions as independent images. Results are
   --  fresh Float32 C1 Mats (C6 for eigenvalues/vectors). Block sizes must
   --  be at least 2; Wrap borders are unsupported. Errors raise OpenCV_Error.
   function Corner_Minimum_Eigenvalue
     (Source     : OpenCV.Core.Mat;
      Block_Size : Corner_Block_Size := 3;
      Aperture   : Corner_Aperture := Aperture_3;
      Border     : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;
   function Harris_Corner_Response
     (Source     : OpenCV.Core.Mat;
      Block_Size : Corner_Block_Size := 3;
      Aperture   : Corner_Aperture := Aperture_3;
      K          : OpenCV.Float64_Value := 0.04;
      Border     : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;
   --  Six channels per pixel: (lambda1, lambda2, x1, y1, x2, y2).
   function Corner_Eigenvalues_And_Vectors
     (Source     : OpenCV.Core.Mat;
      Block_Size : Corner_Block_Size := 3;
      Aperture   : Corner_Aperture := Aperture_3;
      Border     : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;
   function Pre_Corner_Response
     (Source   : OpenCV.Core.Mat;
      Aperture : Corner_Aperture := Aperture_3;
      Border   : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;

   --  Search_Window is a strictly positive half-size. The image must be at
   --  least (2*Width+5) by (2*Height+5). Every initial point must be finite
   --  and inside [0, Columns) x [0, Rows). Dead-zone half-sizes must be
   --  smaller than the corresponding search half-sizes. Both termination
   --  criteria are active; Epsilon must be finite and nonnegative. An empty
   --  Float32 source samples must all be finite (including for empty Corners);
   --  UInt8 sources need no scan. Nonfinite samples raise OpenCV_Error.
   --  An empty array returns an empty array after image/window/criteria and
   --  Float32 source validation.
   --  Arbitrary Integer bounds are preserved. Inputs remain unchanged even
   --  on failure; Region neighborhoods cannot see parent pixels.
   function Refine_Corners_Subpixel
     (Source        : OpenCV.Core.Mat;
      Corners       : Corner_Point_Array;
      Search_Window : OpenCV.Size;
      Dead_Zone     : Corner_Dead_Zone := (Enabled => False);
      Termination   : Corner_Termination :=
        (Maximum_Iterations => 30, Epsilon => 0.01)) return Corner_Point_Array;

   type Laplacian_Kernel_Size is range 1 .. 31;

   subtype Median_Kernel_Size is Positive range 3 .. 2_147_483_647;

   subtype Bilateral_Diameter is Positive range 1 .. 2_147_483_647;

   subtype Gaussian_Kernel_Size is Positive range 1 .. 2_147_483_647;

   type Gaussian_Kernel_Depth is (Float32_Kernel, Float64_Kernel);

   subtype Derivative_Kernel_Depth is Gaussian_Kernel_Depth;

   type Derivative_Kernel_Normalization is (Unnormalized, Normalized);

   type Derivative_Kernels is record
      Kernel_X : OpenCV.Core.Mat;
      Kernel_Y : OpenCV.Core.Mat;
   end record;

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

   subtype Contour is OpenCV.Point_Array;

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

   type Pixel_Connectivity is (Four_Connected, Eight_Connected);

   type Drawing_Line_Style is
     (Four_Connected_Line, Eight_Connected_Line, Anti_Aliased_Line);

   subtype Drawing_Thickness is Positive range 1 .. 32_767;

   subtype Drawing_Radius is Positive;

   type Drawing_Marker_Kind is
     (Cross_Marker,
      Tilted_Cross_Marker,
      Star_Marker,
      Diamond_Marker,
      Square_Marker,
      Triangle_Up_Marker,
      Triangle_Down_Marker);

   type Text_Font is
     (Hershey_Simplex,
      Hershey_Plain,
      Hershey_Duplex,
      Hershey_Complex,
      Hershey_Triplex,
      Hershey_Complex_Small,
      Hershey_Script_Simplex,
      Hershey_Script_Complex);

   type Text_Metrics is record
      Size     : OpenCV.Size;
      Baseline : Natural;
   end record;

   --  Minimum accumulator votes required for a Hough line or segment.
   subtype Hough_Vote_Threshold is Positive range 1 .. 2_147_483_647;

   --  Integer Canny and accumulator thresholds for gradient Hough circles.
   subtype Hough_Circle_Threshold is Positive range 1 .. 2_147_483_647;

   --  A standard-Hough line in polar form: the points (X, Y) satisfying
   --  X * cos (Angle_Radians) + Y * sin (Angle_Radians) = Rho. Rho is in
   --  pixels relative to the Source origin and may be negative.
   --  Angle_Radians is always in radians.
   type Hough_Line is record
      Rho           : OpenCV.Float32_Value;
      Angle_Radians : OpenCV.Float32_Value;
   end record;

   --  Nonempty results are zero-based; an empty result has range 1 .. 0.
   type Hough_Line_Array is array (Natural range <>) of Hough_Line;

   --  A probabilistic-Hough segment. Endpoint order is unspecified:
   --  (A, B) and (B, A) describe the same segment.
   type Hough_Line_Segment is record
      Start_Point : OpenCV.Point;
      End_Point   : OpenCV.Point;
   end record;

   --  Nonempty results are zero-based; an empty result has range 1 .. 0.
   type Hough_Line_Segment_Array is
     array (Natural range <>) of Hough_Line_Segment;

   --  A gradient-Hough circle. Center and Radius are native binary32
   --  pixel values quantized by the accumulator scale.
   type Hough_Circle is record
      Center : OpenCV.Float32_Point;
      Radius : OpenCV.Float32_Value;
   end record;

   --  Nonempty results are zero-based; an empty result has range 1 .. 0.
   type Hough_Circle_Array is array (Natural range <>) of Hough_Circle;

   --  A standard-Hough line with its accumulator vote count. Votes is
   --  evidence for ranking, not a cross-version constant: raster-line votes
   --  come from OpenCV's binary32 Vec3f output and point-set votes from its
   --  Vec3d output, all integer accumulator counts promoted to Float64.
   --  Raster counts above 2**24 may already have been rounded by binary32.
   type Hough_Line_With_Votes is record
      Rho           : OpenCV.Float32_Value;
      Angle_Radians : OpenCV.Float32_Value;
      Votes         : OpenCV.Float64_Value;
   end record;

   --  Nonempty results are zero-based; an empty result has range 1 .. 0.
   type Hough_Line_With_Votes_Array is
     array (Natural range <>) of Hough_Line_With_Votes;

   --  One degree in radians, the default point-set angle resolution.
   Hough_Degree : constant := Ada.Numerics.Pi / 180.0;

   --  Input points for Find_Hough_Lines_From_Points; any index bounds.
   type Hough_Point_Array is array (Integer range <>) of OpenCV.Float32_Point;

   --  A radius-finding gradient-Hough circle with the support count of its
   --  estimated radius, from OpenCV's binary32 Vec4f output (counts above
   --  2**24 may already have been rounded by binary32).
   type Hough_Circle_With_Votes is record
      Center : OpenCV.Float32_Point;
      Radius : OpenCV.Float32_Value;
      Votes  : OpenCV.Float64_Value;
   end record;

   --  Nonempty results are zero-based; an empty result has range 1 .. 0.
   type Hough_Circle_With_Votes_Array is
     array (Natural range <>) of Hough_Circle_With_Votes;

   --  Centers found by center-only gradient-Hough detection.
   --  Nonempty results are zero-based; an empty result has range 1 .. 0.
   type Hough_Circle_Center_Array is
     array (Natural range <>) of OpenCV.Float32_Point;

   type Component_Label is new Natural;

   Background_Label : constant Component_Label := 0;

   type Component_Statistics is record
      Bounds     : OpenCV.Rect;
      Area       : Natural;
      Centroid_X : OpenCV.Float64_Value;
      Centroid_Y : OpenCV.Float64_Value;
   end record;

   type Connected_Component_Set is private;

   type Morphology_Shape is (Rectangle, Cross, Ellipse);

   type Morphology_Operation is
     (Opening, Closing, Gradient, Top_Hat, Black_Hat);

   subtype Morphology_Iterations is Positive range 1 .. 2_147_483_647;

   type Morphology_Border_Value is private;
   Default_Morphology_Border : constant Morphology_Border_Value;
   --  The all-DBL_MAX scalar is reserved by OpenCV for its neutral default.
   --  Used explicit Constant_Border components for integer sources must be
   --  finite and within signed-int range before OpenCV saturates the result.
   function Explicit_Morphology_Border
     (Value : OpenCV.Scalar) return Morphology_Border_Value;

   type Template_Matching_Method is
     (Squared_Difference,
      Normalized_Squared_Difference,
      Cross_Correlation,
      Normalized_Cross_Correlation,
      Correlation_Coefficient,
      Normalized_Correlation_Coefficient);

   type Warp_Mapping_Direction is
     (Source_To_Destination, Destination_To_Source);

   subtype Affine_Mapping_Direction is Warp_Mapping_Direction;

   --  Nonempty 2-D Source, with exactly the channels named by Conversion.
   --  Layout, Gray, XYZ, YCrCb and YUV accept UInt8/UInt16/Float32;
   --  HSV, HLS, Lab and Luv accept UInt8/Float32. Destination retains
   --  Source geometry/depth; its channel count is fixed by Conversion.
   --  Destination is rebound only on success; Regions are logical images.
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
      Output_Size   : OpenCV.Size;
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
      Kernel_Size : OpenCV.Size;
      Sigma       : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Get_Gaussian_Kernel returns an N x 1 single-channel Gaussian coefficient
   --  vector of the requested Depth. Kernel_Size must be odd. This overload
   --  asks OpenCV to derive sigma from Kernel_Size; there is no public zero
   --  or negative sigma sentinel. Coefficients preserve OpenCV's values and
   --  ordering and may be passed directly to Sep_Filter_2D. Contract
   --  violations and failures reported by OpenCV raise OpenCV.OpenCV_Error.
   function Get_Gaussian_Kernel
     (Kernel_Size : Gaussian_Kernel_Size;
      Depth       : Gaussian_Kernel_Depth := Float64_Kernel)
      return OpenCV.Core.Mat;

   --  This overload is the same Get_Gaussian_Kernel generator with an
   --  explicit Sigma. Sigma must be finite and strictly greater than zero.
   --  Zero and negative values are rejected rather than switching to
   --  automatic sigma.
   function Get_Gaussian_Kernel
     (Kernel_Size : Gaussian_Kernel_Size;
      Sigma       : OpenCV.Float64_Value;
      Depth       : Gaussian_Kernel_Depth := Float64_Kernel)
      return OpenCV.Core.Mat;

   --  Get_Derivative_Kernels generates the separable 1-D Sobel-family
   --  coefficient vectors used by spatial derivatives; it does not filter an
   --  image itself. Kernel_X is the horizontal/X-direction vector and Kernel_Y
   --  is the vertical/Y-direction vector. Both are independently owned
   --  single-channel column vectors (N x 1) of matching Float32 or Float64
   --  depth. Coefficient order is preserved; the generator does not flip
   --  coefficients. The pair may be passed directly to Sep_Filter_2D:
   --
   --    Kernels :=
   --      Get_Derivative_Kernels
   --        (X_Order     => 1,
   --         Y_Order     => 0,
   --         Kernel_Size => Kernel_3);
   --    Sep_Filter_2D
   --      (Source,
   --       Destination,
   --       Kernel_X          => Kernels.Kernel_X,
   --       Kernel_Y          => Kernels.Kernel_Y,
   --       Destination_Depth => Float32_Depth);
   --
   --  X_Order and Y_Order cannot both be zero. Each order must be strictly
   --  less than the effective one-dimensional length in that direction.
   --  Kernel_3, Kernel_5, and Kernel_7 use that kernel size in both
   --  directions. Kernel_1 uses OpenCV's special derivative behavior: a
   --  nonzero-order direction has effective length 3, while a zero-order
   --  direction remains a 1-tap identity, so Kernel_X and Kernel_Y lengths
   --  may differ. Normalized changes coefficient scaling, not derivative
   --  order. There is no public FILTER_SCHARR or -1 kernel-size sentinel;
   --  use Get_Scharr_Kernels for Scharr coefficients. Contract violations
   --  and failures reported by OpenCV raise OpenCV.OpenCV_Error.
   function Get_Derivative_Kernels
     (X_Order       : Derivative_Order;
      Y_Order       : Derivative_Order;
      Kernel_Size   : Sobel_Kernel_Size := Kernel_3;
      Normalization : Derivative_Kernel_Normalization := Unnormalized;
      Depth         : Derivative_Kernel_Depth := Float32_Kernel)
      return Derivative_Kernels;

   --  Get_Scharr_Kernels generates the separable 1-D Scharr first-derivative
   --  coefficient pair for Axis. It does not filter an image itself. Both
   --  returned vectors are independently owned 3 x 1 single-channel Mats of
   --  matching Float32 or Float64 depth. Coefficient order is preserved and
   --  may be passed directly to Sep_Filter_2D. X_Axis maps to X_Order 1 /
   --  Y_Order 0; Y_Axis maps to X_Order 0 / Y_Order 1. Normalized changes
   --  smoothing-vector scaling, not derivative order. The native Scharr
   --  kernel-size sentinel remains private. Contract violations and failures
   --  reported by OpenCV raise OpenCV.OpenCV_Error.
   function Get_Scharr_Kernels
     (Axis          : Derivative_Axis;
      Normalization : Derivative_Kernel_Normalization := Unnormalized;
      Depth         : Derivative_Kernel_Depth := Float32_Kernel)
      return Derivative_Kernels;

   --  Pyramid_Down performs OpenCV's Gaussian-pyramid downsampling of Source.
   --  Source must be a non-empty two-dimensional Mat with depth UInt8, UInt16,
   --  Int16, Float32, or Float64. Channel count is unrestricted. Destination
   --  receives Source's depth and channel count with OpenCV's natural size:
   --  Columns = (Source.Columns + 1) / 2 and Rows = (Source.Rows + 1) / 2.
   --  A Region is processed as its own logical image; parent pixels outside
   --  the Region do not participate.
   --  Replicate, Reflect, Reflect_101, and Wrap are supported;
   --  Constant_Border is rejected. Direct in-place operation is not
   --  supported. Contract violations and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   procedure Pyramid_Down
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Pyramid_Up performs OpenCV's Gaussian-pyramid upsampling of Source.
   --  Source must be a non-empty two-dimensional Mat with depth UInt8, UInt16,
   --  Int16, Float32, or Float64. Channel count is unrestricted. Destination
   --  receives Source's depth and channel count with exactly doubled rows and
   --  columns. A Region is processed as its own logical image, without parent
   --  pixels. OpenCV supports only its default border for this operation, so
   --  no Border parameter is exposed. Direct in-place operation is not
   --  supported. Contract violations and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   procedure Pyramid_Up
     (Source : OpenCV.Core.Mat; Destination : in out OpenCV.Core.Mat);

   --  Pyramid_Up with an explicit Output_Size performs the same Gaussian
   --  upsampling to the requested size. Each extent must equal twice the
   --  Source extent or one less than that (for example 5 -> 9 or 5 -> 10),
   --  so every natural Pyramid_Down geometry, including odd sizes, can be
   --  reversed exactly. Other sizes are rejected before any native
   --  allocation. The Source contract matches the natural overload. The
   --  result is computed into fresh storage and bound to Destination only on
   --  success; on failure Destination is unchanged. Destination may therefore
   --  share Source storage. Contract violations and failures reported by
   --  OpenCV raise OpenCV.OpenCV_Error.
   procedure Pyramid_Up
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Output_Size : OpenCV.Size);

   --  Maximum_Pyramid_Level_Count returns the number of distinct natural
   --  Gaussian levels of Source, including level 0: both extents are halved
   --  as (N + 1) / 2 until they both reach 1. For example 1 x 1 -> 1,
   --  8 x 8 -> 4, and 9 x 7 -> 5. Source must be a non-empty
   --  two-dimensional Mat; otherwise OpenCV.OpenCV_Error is raised.
   function Maximum_Pyramid_Level_Count
     (Source : OpenCV.Core.Mat) return Positive;

   --  Build_Gaussian_Pyramid returns Level_Count images indexed
   --  0 .. Level_Count - 1. Level 0 is an independent copy of Source; each
   --  later level is Pyramid_Down of the previous level with Border. Every
   --  level owns independent storage shared with neither Source nor another
   --  level. Source follows the Pyramid_Down contract (UInt8, UInt16, Int16,
   --  Float32, or Float64; any channel count). A Region is processed as its
   --  own logical image; parent pixels never participate. Replicate, Reflect,
   --  Reflect_101, and Wrap are supported; Constant_Border is rejected.
   --  Level_Count must not exceed Maximum_Pyramid_Level_Count (Source).
   --  Contract violations and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   function Build_Gaussian_Pyramid
     (Source      : OpenCV.Core.Mat;
      Level_Count : Positive;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat_Array;

   --  Working floating depth of a Laplacian pyramid. Automatic_Precision
   --  keeps Float64 sources in Float64 and promotes every other supported
   --  depth to Float32, so negative detail coefficients never saturate.
   type Laplacian_Precision is
     (Automatic_Precision, Float32_Precision, Float64_Precision);

   --  Build_Laplacian_Pyramid converts Source to the selected floating depth,
   --  builds a Gaussian pyramid G (0 .. Level_Count - 1) with Border, and
   --  returns L (0 .. Level_Count - 1) where, for I < Level_Count - 1,
   --  L (I) = G (I) - Pyramid_Up (G (I + 1), Output_Size => size of G (I))
   --  and the last level is the low-frequency base L (N) = G (N). All levels
   --  are Float32 or Float64 with Source's channel count and independent
   --  storage, so callers may edit residuals before reconstruction. Source,
   --  Region, Border, and Level_Count contracts match
   --  Build_Gaussian_Pyramid. Contract violations and failures reported by
   --  OpenCV raise OpenCV.OpenCV_Error.
   function Build_Laplacian_Pyramid
     (Source      : OpenCV.Core.Mat;
      Level_Count : Positive;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101;
      Precision   : Laplacian_Precision := Automatic_Precision)
      return OpenCV.Core.Mat_Array;

   --  Reconstruct_Laplacian_Pyramid inverts Build_Laplacian_Pyramid.
   --  Pyramid is read in array iteration order as fine-to-coarse levels and
   --  may have any index bounds. It must be non-empty; every level must be a
   --  non-empty two-dimensional Mat of one common depth (Float32 or Float64)
   --  and one common channel count, and each following level must have
   --  Rows = (Previous.Rows + 1) / 2 and Columns = (Previous.Columns + 1) / 2.
   --  The whole array is validated before any work begins. Starting from the
   --  last level, each step computes
   --  Current := Pyramid_Up (Current, size of Level) + Level. The result is
   --  an independent Mat of the pyramid's floating depth; it is not narrowed
   --  to any original integer depth (use Convert_To explicitly). Input levels
   --  are never modified. Contract violations and failures reported by
   --  OpenCV raise OpenCV.OpenCV_Error.
   function Reconstruct_Laplacian_Pyramid
     (Pyramid : OpenCV.Core.Mat_Array) return OpenCV.Core.Mat;

   --  Highest Gaussian pyramid level processed by Pyramid_Mean_Shift_Filter;
   --  0 filters Source directly without a pyramid.
   subtype Mean_Shift_Pyramid_Level is Natural range 0 .. 8;

   subtype Mean_Shift_Iteration_Limit is Positive range 1 .. 100;

   --  Per-pixel mean-shift stopping rule. Iteration stops after
   --  Maximum_Iterations or once the combined spatial/color shift is at
   --  most Epsilon. Both criteria are always active. Epsilon must be finite
   --  and nonnegative.
   type Mean_Shift_Termination is record
      Maximum_Iterations : Mean_Shift_Iteration_Limit := 5;
      Epsilon            : OpenCV.Float64_Value := 1.0;
   end record;

   --  Pyramid_Mean_Shift_Filter performs OpenCV's mean-shift filtering
   --  (posterization) stage of mean-shift segmentation. Each pixel is
   --  replaced by the color at which a joint spatial/color mean-shift
   --  converges: pixels within Spatial_Radius in space and Color_Radius in
   --  RGB distance are averaged repeatedly. The result is a filtered color
   --  image; it does not produce connected-region labels.
   --
   --  Source must be a non-empty two-dimensional UInt8 C3 Mat. Destination
   --  receives Source's rows and columns as UInt8 C3. Spatial_Radius must be
   --  finite and positive (OpenCV raises each level's effective radius to at
   --  least 1). Color_Radius must be finite and nonnegative; 0 admits only
   --  identical colors. With Maximum_Pyramid_Level > 0, OpenCV first filters
   --  a natural Gaussian pyramid from its top level and propagates results
   --  downward, halving Spatial_Radius per level; results may differ from
   --  level-0 filtering. Every generated level must stay at least 2 x 2:
   --  requests whose top level would be narrower are rejected (never
   --  silently reduced) because OpenCV's propagation performs invalid
   --  pointer arithmetic on such tiny levels.
   --
   --  Source is snapshotted into a private packed copy, so a Region is its
   --  own logical image and parent pixels never participate; Source is not
   --  modified. The result is computed into fresh storage and bound to
   --  Destination only on success; on failure Destination is unchanged.
   --  Destination may be Source itself or share its storage. Requests whose
   --  native signed-int radius rounding, row offsets, window accumulators,
   --  or stopping expression could overflow are rejected before native
   --  execution. Contract violations and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   procedure Pyramid_Mean_Shift_Filter
     (Source                : OpenCV.Core.Mat;
      Destination           : in out OpenCV.Core.Mat;
      Spatial_Radius        : OpenCV.Float64_Value;
      Color_Radius          : OpenCV.Float64_Value;
      Maximum_Pyramid_Level : Mean_Shift_Pyramid_Level := 1;
      Termination           : Mean_Shift_Termination :=
        (Maximum_Iterations => 5, Epsilon => 1.0));

   --  Match_Template slides Template over Source and writes a score map to
   --  Destination. Source and Template must each be a non-empty
   --  two-dimensional Mat of depth UInt8 or Float32 with 1 to 4 channels, and
   --  they must share the same depth and channel count. Template must fit
   --  entirely inside Source: Template.Rows <= Source.Rows and
   --  Template.Columns <= Source.Columns. A Template equal in size to Source
   --  is valid. Destination is always replaced with a Float32 C1 Mat of
   --  Rows = Source.Rows - Template.Rows + 1 and
   --  Columns = Source.Columns - Template.Columns + 1. Multi-channel inputs
   --  are combined into one score per location; they are not converted to
   --  grayscale. For Squared_Difference and Normalized_Squared_Difference the
   --  best match is the minimum score; for the other four methods the best
   --  match is the maximum. Use OpenCV.Core.Min_Max_Loc on Destination to
   --  recover those extrema. Source and Template are read-only and may share
   --  storage. Destination must not share storage with Source or Template.
   --  Masked template matching is not bound. Contract violations and failures
   --  reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Match_Template
     (Source      : OpenCV.Core.Mat;
      Template    : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Method      : Template_Matching_Method);

   --  Warp_Affine applies a 2x3 affine Transform to Source and writes the
   --  warped image to Destination. Source must be a non-empty two-dimensional
   --  Mat of depth UInt8, UInt16, Int16, Float32, or Float64 with 1 to 4
   --  channels. Transform must be a non-empty two-dimensional 2x3
   --  single-channel Mat of depth Float32 or Float64:
   --
   --     [ M00 M01 M02 ]
   --     [ M10 M11 M12 ]
   --
   --  Output_Size.Width and Output_Size.Height must both be nonzero.
   --  Destination is always replaced with a Mat of Rows = Output_Size.Height,
   --  Columns = Output_Size.Width, and Source's depth and channel count.
   --  Callers do not need to preallocate Destination. No color conversion
   --  occurs. Interpolation is Nearest_Neighbor or Linear; Cubic, Area, and
   --  Lanczos_4 are rejected. Border is Constant_Border or Replicate; Reflect,
   --  Reflect_101, and Wrap are rejected. For Constant_Border, C1 uses
   --  Component_0, C2 uses Components 0..1, C3 uses 0..2, and C4 uses 0..3.
   --  For Replicate, Border_Value is ignored. Source_To_Destination is the
   --  usual forward mapping; Destination_To_Source treats Transform as already
   --  inverted. Source and Transform are read-only and may share storage.
   --  Destination must not share storage with Source or Transform. Direct
   --  in-place operation is not supported. Contract violations and failures
   --  reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Warp_Affine
     (Source        : OpenCV.Core.Mat;
      Transform     : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method := Linear;
      Mapping       : Affine_Mapping_Direction := Source_To_Destination;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  Warp_Perspective applies a 3x3 projective Transform to Source and writes
   --  the warped image to Destination. Source must be a non-empty
   --  two-dimensional Mat of depth UInt8, UInt16, Int16, Float32, or Float64
   --  with 1 to 4 channels. Transform must be a non-empty two-dimensional 3x3
   --  single-channel Mat of depth Float32 or Float64:
   --
   --     [ M00 M01 M02 ]
   --     [ M10 M11 M12 ]
   --     [ M20 M21 M22 ]
   --
   --  Output_Size.Width and Output_Size.Height must both be nonzero.
   --  Destination is always replaced with a Mat of Rows = Output_Size.Height,
   --  Columns = Output_Size.Width, and Source's depth and channel count.
   --  Callers do not need to preallocate Destination. No color conversion
   --  occurs. Interpolation is Nearest_Neighbor or Linear; Cubic, Area, and
   --  Lanczos_4 are rejected. Border is Constant_Border or Replicate; Reflect,
   --  Reflect_101, and Wrap are rejected. For Constant_Border, C1 uses
   --  Component_0, C2 uses Components 0..1, C3 uses 0..2, and C4 uses 0..3.
   --  For Replicate, Border_Value is ignored. Source_To_Destination is the
   --  usual forward mapping; Destination_To_Source treats Transform as already
   --  inverted. Source and Transform are read-only and may share storage.
   --  Destination must not share storage with Source or Transform. Direct
   --  in-place operation is not supported. Singular or poorly conditioned
   --  matrices are not rejected merely for being singular; all nine
   --  coefficients must be finite. Contract violations and failures reported
   --  by OpenCV raise OpenCV.OpenCV_Error.
   procedure Warp_Perspective
     (Source        : OpenCV.Core.Mat;
      Transform     : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method := Linear;
      Mapping       : Warp_Mapping_Direction := Source_To_Destination;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  Polar output X is radial rho and Y is angular phi (one revolution).
   --  Linear rho follows distance; logarithmic rho follows log(distance+1).
   --  In forward mode Center is relative to the Source view; in inverse mode
   --  it is relative to the requested Cartesian destination. Source must be
   --  nonempty 2-D UInt8/UInt16/Int16/Float32/Float64, C1..C4. Output_Size
   --  must be explicit and positive. Both dimensions and Source dimensions
   --  must be < 32767; inverse Source.Rows must be <= 32764 because OpenCV
   --  adds two wrap rows. Radius must be finite and > 0 (linear) or > 1
   --  (logarithmic). Center must be finite. Nearest, Linear, Cubic and
   --  Lanczos_4 are supported; Area is rejected. Outliers are zero-filled.
   --  Destination must not overlap Source, including Regions and aliases.
   --  Successful calls replace Destination with a fresh result of Source's
   --  type. Failed calls leave it unchanged. Round trips are interpolated
   --  and are not guaranteed to reproduce the input exactly.
   procedure Warp_Polar
     (Source         : OpenCV.Core.Mat;
      Destination    : in out OpenCV.Core.Mat;
      Center         : OpenCV.Float32_Point;
      Maximum_Radius : OpenCV.Float64_Value;
      Output_Size    : OpenCV.Size;
      Mapping        : Polar_Mapping := Linear_Polar;
      Direction      : Polar_Direction := Cartesian_To_Polar;
      Interpolation  : Interpolation_Method := Linear);

   --  Remap applies an absolute source-coordinate map. Destination(Row,
   --  Column) samples Source at X = Map_X(Row, Column) and
   --  Y = Map_Y(Row, Column). Source must be a non-empty two-dimensional
   --  Mat of depth UInt8, UInt16, Int16, Float32, or Float64 with 1 to 4
   --  channels and with Rows and Columns less than 32767. Map_X and Map_Y
   --  must be non-empty two-dimensional single-channel Float32 Mats of
   --  identical size, each with Rows and Columns less than 32767. Map
   --  coordinates must be finite and safely convertible through native
   --  integer coordinate tables; they may lie outside Source. Destination
   --  is always replaced with a Mat of Rows = Map_X.Rows,
   --  Columns = Map_X.Columns, and Source's depth and channel count.
   --  Callers do not need to preallocate Destination. No color conversion
   --  occurs. Interpolation is Nearest_Neighbor, Linear, Cubic, or
   --  Lanczos_4; Area is rejected. All public Border_Kind values are
   --  supported. For Constant_Border, C1 uses Component_0, C2 uses
   --  Components 0..1, C3 uses 0..2, and C4 uses 0..3. For other borders,
   --  Border_Value is ignored. Source, Map_X, and Map_Y are read-only and
   --  may share storage. Destination must not share storage with Source,
   --  Map_X, or Map_Y. Direct in-place operation is not supported.
   --  Failed calls leave Destination unchanged. Relative maps are not bound.
   --  Contract
   --  violations and failures reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Map_X         : OpenCV.Core.Mat;
      Map_Y         : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  An absolute Float32 C2 map stores X in component 0 and Y in component 1.
   --  It must be nonempty, two-dimensional, and have both dimensions < 32767.
   --  The Source, interpolation, borders, alias and failure contracts above
   --  also apply to this overload.
   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Map_XY        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  Coordinates are Int16 C2; Coefficients are UInt16 C1 for interpolation
   --  or empty for nearest-only maps. The invariant-bearing pair is private.
   type Fixed_Remap_Maps is private;
   function Is_Empty (Maps : Fixed_Remap_Maps) return Boolean;
   function Is_Nearest_Only (Maps : Fixed_Remap_Maps) return Boolean;

   type Float_Remap_Maps is record
      Map_X : OpenCV.Core.Mat;
      Map_Y : OpenCV.Core.Mat;
   end record;

   --  All input maps are nonempty 2-D Float32 C1+C1 or Float32 C2, with
   --  matching geometry where separate and dimensions < 32767. Conversion
   --  to fixed maps quantizes fractions to 1/32 pixel; nearest-only conversion
   --  discards fractions. Int16 coordinate saturation can lose information.
   function Convert_Remap_To_Fixed
     (Map_X, Map_Y : OpenCV.Core.Mat; Nearest_Neighbor_Only : Boolean := False)
      return Fixed_Remap_Maps;
   function Convert_Remap_To_Fixed
     (Map_XY : OpenCV.Core.Mat; Nearest_Neighbor_Only : Boolean := False)
      return Fixed_Remap_Maps;
   function Interleave_Remap_Maps
     (Map_X, Map_Y : OpenCV.Core.Mat) return OpenCV.Core.Mat;
   function Separate_Remap_Map
     (Map_XY : OpenCV.Core.Mat) return Float_Remap_Maps;
   function Convert_Remap_To_Interleaved_Float
     (Maps : Fixed_Remap_Maps) return OpenCV.Core.Mat;
   function Convert_Remap_To_Separate_Float
     (Maps : Fixed_Remap_Maps) return Float_Remap_Maps;

   --  Coefficient-bearing maps support Nearest, Linear, Cubic and Lanczos_4;
   --  nearest-only maps support Nearest_Neighbor exclusively.
   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Maps          : Fixed_Remap_Maps;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

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
      Kernel_Size : OpenCV.Size;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

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
      Sigma_Color : OpenCV.Float64_Value;
      Sigma_Space : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  This overload is the same Bilateral_Filter operation with an explicit
   --  neighborhood Diameter. Diameter is a positive integer and need not be
   --  odd. OpenCV uses Diameter as the neighborhood size independently of
   --  Sigma_Space; Sigma_Space still weights samples inside that neighborhood.
   --  Direct in-place operation is not supported.
   procedure Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Diameter    : Bilateral_Diameter;
      Sigma_Color : OpenCV.Float64_Value;
      Sigma_Space : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

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
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

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
      Anchor            : OpenCV.Point;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

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
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

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
      Anchor            : OpenCV.Point;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Erode replaces Destination with the neighborhood minimum selected by a
   --  temporary structuring element of Kernel_Size and Shape. Source must be a
   --  non-empty two-dimensional Mat of depth UInt8, UInt16, Int16, Float32, or
   --  Float64; channels are processed independently. Kernel dimensions must be
   --  positive, but need not be odd, and Iterations is at least one.
   --  Constant_Border, Replicate, Reflect, and Reflect_101 are supported; Wrap
   --  is rejected. Constant_Border uses OpenCV's morphology default border
   --  value. Destination receives Source's geometry and element type. Source
   --  remains unchanged unless it is also Destination, which is supported for
   --  in-place erosion. A Region is processed as its own logical image; pixels
   --  in its parent outside the view do not participate. Contract violations
   --  and OpenCV failures raise OpenCV.OpenCV_Error.
   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  Dilate replaces Destination with the neighborhood maximum selected by a
   --  temporary structuring element of Kernel_Size and Shape. It has the same
   --  source depth, channel, kernel-size, iteration, border, destination, and
   --  in-place semantics as Erode. Constant_Border uses OpenCV's morphology
   --  default border value. A Region is processed as its own logical image;
   --  pixels in its parent outside the view do not participate.
   --  Contract violations and OpenCV failures raise
   --  OpenCV.OpenCV_Error.
   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  Apply_Morphology performs Opening, Closing, Gradient, Top_Hat, or
   --  Black_Hat with a temporary structuring element of Kernel_Size and Shape.
   --  Source must be a non-empty two-dimensional Mat of depth UInt8, UInt16,
   --  Int16, Float32, or Float64; channels are processed independently. Kernel
   --  dimensions must be positive, but need not be odd, and Iterations is at
   --  least one. Constant_Border, Replicate, Reflect, and Reflect_101 are
   --  supported; Wrap is rejected. Constant_Border uses OpenCV's morphology
   --  default border value. Destination receives Source's geometry and element
   --  type. Source remains unchanged unless it is also Destination, which is
   --  supported in-place. A Region is processed as its own logical image;
   --  pixels in its parent outside the view do not participate.
   --  Contract violations and OpenCV failures raise
   --  OpenCV.OpenCV_Error.
   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  Custom kernels are nonempty 2-D UInt8 C1 binary masks: zero excludes,
   --  every nonzero value includes. All-zero masks are rejected. Kernel and
   --  Destination must not overlap. Source/Destination in-place is supported.
   --  Regions use only their logical views, including parent-backed in-place.
   --  An explicit Cross anchor also changes the generated mask geometry.
   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);
   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);
   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);
   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);
   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);
   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);
   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);
   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  Canny_Edges finds edges in a non-empty two-dimensional UInt8 C1 Source.
   --  Lower_Threshold and Upper_Threshold must be finite, nonnegative, and
   --  ordered lower to upper. Destination is replaced with a UInt8 C1 Mat of
   --  Source's geometry. Source remains valid and is not modified. Contract
   --  violations and failures reported by OpenCV raise OpenCV.OpenCV_Error.
   procedure Canny_Edges
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Lower_Threshold : OpenCV.Float64_Value;
      Upper_Threshold : OpenCV.Float64_Value;
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
      Scale             : OpenCV.Float64_Value := 1.0;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

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
      Scale             : OpenCV.Float64_Value := 1.0;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

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
      Scale             : OpenCV.Float64_Value := 1.0;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

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
      Threshold_Value : OpenCV.Float64_Value;
      Mode            : Threshold_Mode := Binary;
      Maximum_Value   : OpenCV.Float64_Value := 255.0);

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
      Computed_Threshold : out OpenCV.Float64_Value;
      Method             : Automatic_Threshold_Method := Otsu;
      Mode               : Threshold_Mode := Binary;
      Maximum_Value      : OpenCV.Float64_Value := 255.0);

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
      Bias          : OpenCV.Float64_Value := 0.0;
      Maximum_Value : OpenCV.UInt8_Value := 255);

   --  Equalize_Histogram performs global histogram equalization of a grayscale
   --  UInt8 image. Source must be a non-empty two-dimensional single-channel
   --  UInt8 Mat. There is no implicit conversion from color or from another
   --  depth. The histogram is computed over the supplied Mat view, not over an
   --  enclosing parent image outside that view. Constant images retain their
   --  intensity. Destination may initially be empty or have a different size,
   --  depth, or channel count; on success it receives Source's rows and
   --  columns with UInt8 depth and one channel. Source remains unchanged when
   --  Source and Destination do not share storage. Direct same-object in-place
   --  use is supported:
   --
   --    Equalize_Histogram (Image, Image);
   --
   --  Other Source/Destination storage-sharing combinations are an Ada binding
   --  restriction for this slice and are rejected before native writes. That
   --  includes distinct shallow aliases and partially overlapping source and
   --  destination ROIs; it is not a claim that OpenCV forbids every alias.
   --  Public contract violations raise OpenCV.OpenCV_Error before Destination
   --  is modified. Failures reported by OpenCV after Destination allocation or
   --  native execution raise OpenCV.OpenCV_Error and do not roll back
   --  Destination.
   procedure Equalize_Histogram
     (Source : OpenCV.Core.Mat; Destination : in out OpenCV.Core.Mat);

   --  CLAHE performs Contrast Limited Adaptive Histogram Equalization locally,
   --  unlike Equalize_Histogram, which uses one global histogram. Source is
   --  divided into Tile_Grid_Size.Width by Tile_Grid_Size.Height contextual
   --  regions; Clip_Limit controls contrast limiting in each region. Source
   --  must be a non-empty two-dimensional UInt8 or UInt16 single-channel Mat.
   --  No implicit color or depth conversion is performed. Tile counts need not
   --  divide Source dimensions evenly: OpenCV pads internally as needed.
   --  Destination may initially be empty or incompatible; on success it has
   --  Source's geometry, depth, and one channel. Direct same-object in-place
   --  use, including an ROI, is supported. Distinct Source/Destination Mats
   --  with overlapping storage are rejected before native writes. Contract
   --  violations and native failures raise OpenCV.OpenCV_Error.
   procedure CLAHE
     (Source         : OpenCV.Core.Mat;
      Destination    : in out OpenCV.Core.Mat;
      Clip_Limit     : OpenCV.Float64_Value := 40.0;
      Tile_Grid_Size : OpenCV.Size := (Width => 8, Height => 8));

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
      Offset        : OpenCV.Point := (X => 0, Y => 0)) return Contour_Set;

   function Contour_Count (Self : Contour_Set) return Natural;

   function Get_Contour
     (Self : Contour_Set; Index : Contour_Index) return Contour;

   function Get_Hierarchy
     (Self : Contour_Set; Index : Contour_Index)
      return Contour_Hierarchy_Entry;

   --  Labels the nonzero regions of a non-empty two-dimensional UInt8
   --  single-channel Source. Zero is background and every nonzero value is
   --  foreground. Labels is replaced with a distinct Int32 single-channel Mat
   --  having Source's geometry; zero is Background_Label and foreground labels
   --  are 1 through Component_Count. Components contains Ada-owned foreground
   --  statistics only. Four_Connected and Eight_Connected select 4- and
   --  8-neighborhoods. Foreground label numbering has no spatial-order
   --  guarantee. Source and Labels must not share storage. Contract violations
   --  and OpenCV failures raise OpenCV.OpenCV_Error.
   procedure Connected_Components_With_Stats
     (Source       : OpenCV.Core.Mat;
      Labels       : in out OpenCV.Core.Mat;
      Components   : out Connected_Component_Set;
      Connectivity : Pixel_Connectivity := Eight_Connected);

   --  Returns the foreground count, excluding Background_Label.
   function Component_Count (Self : Connected_Component_Set) return Natural;

   --  Label must designate a foreground component in 1 .. Component_Count.
   --  Background_Label and out-of-range labels raise OpenCV.OpenCV_Error.
   function Get_Component
     (Self : Connected_Component_Set; Label : Component_Label)
      return Component_Statistics;

   --  Drawing primitives mutate Image in place. A shallow Mat alias or a
   --  Region shares that storage, so a drawing made through either header is
   --  visible through the other. Region coordinates are relative to the
   --  Region. Pixels outside a Region are not modified. Image must be
   --  nonempty and two-dimensional, with depth UInt8, UInt16, Int16,
   --  Float32, or Float64 and 1 through 4 channels. Scalar components are
   --  written in channel order; unused components are ignored and there is
   --  no alpha blending. The components used by Image.Channels must be
   --  finite. Coordinates may lie outside Image; OpenCV clips them. Outline
   --  operations use a positive Drawing_Thickness. Anti_Aliased_Line is
   --  accepted only for UInt8 images. Contract violations and OpenCV
   --  failures raise OpenCV.OpenCV_Error.

   procedure Draw_Line
     (Image      : in out OpenCV.Core.Mat;
      Start      : OpenCV.Point;
      Finish     : OpenCV.Point;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Tip_Length is a finite fraction in (0, 1]. Coincident endpoints are
   --  rejected. Unsafe native coordinate arithmetic raises OpenCV_Error.
   procedure Draw_Arrow
     (Image      : in out OpenCV.Core.Mat;
      Start      : OpenCV.Point;
      Finish     : OpenCV.Point;
      Color      : OpenCV.Scalar;
      Tip_Length : OpenCV.Float64_Value := 0.1;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   procedure Draw_Marker
     (Image       : in out OpenCV.Core.Mat;
      Position    : OpenCV.Point;
      Color       : OpenCV.Scalar;
      Kind        : Drawing_Marker_Kind := Cross_Marker;
      Marker_Size : Positive := 20;
      Thickness   : Drawing_Thickness := 1;
      Line_Style  : Drawing_Line_Style := Eight_Connected_Line);

   --  Legacy Hershey selectors: OpenCV 4.x uses strokes; OpenCV 5 uses its
   --  built-in TrueType compatibility renderer. Glyphs and metrics may differ.
   --  Requires a nonempty 2-D UInt8 C1, C3 or C4 image. Text is a byte span,
   --  including embedded NULs; empty text is a no-op after image/color checks.
   --  Bottom_Left_Origin reverses the vertical direction of the glyphs.
   procedure Draw_Text
     (Image              : in out OpenCV.Core.Mat;
      Text               : String;
      Origin             : OpenCV.Point;
      Color              : OpenCV.Scalar;
      Font               : Text_Font := Hershey_Simplex;
      Font_Scale         : OpenCV.Float64_Value := 1.0;
      Thickness          : Drawing_Thickness := 1;
      Bottom_Left_Origin : Boolean := False);

   --  Empty text returns Size (0, 0) and Baseline 0. Otherwise the baseline
   --  is the unadjusted native distance below the bottom-most point.
   function Measure_Text
     (Text       : String;
      Font       : Text_Font := Hershey_Simplex;
      Font_Scale : OpenCV.Float64_Value := 1.0;
      Thickness  : Drawing_Thickness := 1) return Text_Metrics;

   --  Reject heights where 2 * Pixel_Height <= Thickness + 1 (the OpenCV 4
   --  scale would be nonpositive), regardless of the linked OpenCV version.
   function Font_Scale_For_Height
     (Pixel_Height : Positive;
      Font         : Text_Font := Hershey_Simplex;
      Thickness    : Drawing_Thickness := 1) return OpenCV.Float64_Value;

   procedure Draw_Rectangle
     (Image      : in out OpenCV.Core.Mat;
      Bounds     : OpenCV.Rect;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   procedure Fill_Rectangle
     (Image      : in out OpenCV.Core.Mat;
      Bounds     : OpenCV.Rect;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   procedure Draw_Circle
     (Image      : in out OpenCV.Core.Mat;
      Center     : OpenCV.Point;
      Radius     : Drawing_Radius;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   procedure Fill_Circle
     (Image      : in out OpenCV.Core.Mat;
      Center     : OpenCV.Point;
      Radius     : Drawing_Radius;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Axes are the ellipse semi-axis lengths and must both be positive.
   --  Angle, Start_Angle, and End_Angle must be finite. Radians are
   --  converted to degrees in Ada; values are not otherwise normalized.
   --  Fill_Ellipse fills the elliptic sector for a partial interval and
   --  the whole ellipse for a full turn.
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
      Units       : OpenCV.Angle_Unit := OpenCV.Degrees);

   procedure Fill_Ellipse
     (Image       : in out OpenCV.Core.Mat;
      Center      : OpenCV.Point;
      Axes        : OpenCV.Size;
      Angle       : OpenCV.Float64_Value;
      Start_Angle : OpenCV.Float64_Value;
      End_Angle   : OpenCV.Float64_Value;
      Color       : OpenCV.Scalar;
      Line_Style  : Drawing_Line_Style := Eight_Connected_Line;
      Units       : OpenCV.Angle_Unit := OpenCV.Degrees);

   --  Points may use any Natural index bounds. An open or closed polyline
   --  requires at least two points.
   procedure Draw_Polyline
     (Image      : in out OpenCV.Core.Mat;
      Points     : OpenCV.Point_Array;
      Closed     : Boolean := False;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Points may use any Natural index bounds. A polygon requires at least
   --  three points. Concave polygons are filled by OpenCV fillPoly.
   procedure Fill_Polygon
     (Image      : in out OpenCV.Core.Mat;
      Points     : OpenCV.Point_Array;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Select contours in Ada, independently of the linked OpenCV version.
   --  All-overloads use every stored contour; Root overloads include Root and
   --  up to Descendant_Levels generations of children (zero means Root only).
   --  Filled contours use even-odd parity: holes remain empty and islands are
   --  filled again. Offset shifts points in image/Region-local coordinates.
   --  Image and Color obey the ordinary drawing contract above. Structural
   --  errors leave Image unchanged; native drawing errors need not roll back.
   procedure Draw_Contours
     (Image      : in out OpenCV.Core.Mat;
      Contours   : Contour_Set;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line;
      Offset     : OpenCV.Point := (X => 0, Y => 0));

   procedure Draw_Contours
     (Image             : in out OpenCV.Core.Mat;
      Contours          : Contour_Set;
      Root              : Contour_Index;
      Color             : OpenCV.Scalar;
      Descendant_Levels : Natural := 0;
      Thickness         : Drawing_Thickness := 1;
      Line_Style        : Drawing_Line_Style := Eight_Connected_Line;
      Offset            : OpenCV.Point := (X => 0, Y => 0));

   procedure Fill_Contours
     (Image      : in out OpenCV.Core.Mat;
      Contours   : Contour_Set;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line;
      Offset     : OpenCV.Point := (X => 0, Y => 0));

   procedure Fill_Contours
     (Image             : in out OpenCV.Core.Mat;
      Contours          : Contour_Set;
      Root              : Contour_Index;
      Color             : OpenCV.Scalar;
      Descendant_Levels : Natural := 0;
      Line_Style        : Drawing_Line_Style := Eight_Connected_Line;
      Offset            : OpenCV.Point := (X => 0, Y => 0));

   --  Hough detection. Every operation takes a private continuous snapshot
   --  of Source before calling OpenCV, so Source pixels are never modified
   --  and a Region is analysed as its own logical image with its own
   --  borders. Results are Ada-owned copies. Result order is not part of
   --  the contract. Contract violations, native arithmetic limits, and
   --  OpenCV failures raise OpenCV.OpenCV_Error.

   --  Find_Hough_Lines runs the classical standard Hough transform on a
   --  nonempty two-dimensional UInt8 C1 binary Source: zero pixels are
   --  background and every nonzero pixel is a candidate. Distance_Resolution
   --  (pixels) and Angle_Resolution_Radians must be positive and finite.
   --  The angle bounds must be finite with
   --  0 <= Minimum_Angle_Radians < Maximum_Angle_Radians <= Pi. Each result
   --  is an accumulator bin, so Rho and Angle_Radians are quantized by the
   --  requested resolutions. Multiscale srn/stn, OpenCV 5 edge-value
   --  weighting, and accumulator votes are not exposed.
   function Find_Hough_Lines
     (Source                   : OpenCV.Core.Mat;
      Distance_Resolution      : OpenCV.Float64_Value;
      Angle_Resolution_Radians : OpenCV.Float64_Value;
      Vote_Threshold           : Hough_Vote_Threshold;
      Minimum_Angle_Radians    : OpenCV.Float64_Value := 0.0;
      Maximum_Angle_Radians    : OpenCV.Float64_Value := Ada.Numerics.Pi)
      return Hough_Line_Array;

   --  Find_Hough_Line_Segments runs the probabilistic Hough transform on the
   --  same binary Source contract as Find_Hough_Lines. Minimum_Line_Length
   --  and Maximum_Line_Gap are integer pixel counts. A segment is kept when
   --  its X or Y extent reaches Minimum_Line_Length; up to Maximum_Line_Gap
   --  missing pixels may be bridged along a line.
   function Find_Hough_Line_Segments
     (Source                   : OpenCV.Core.Mat;
      Distance_Resolution      : OpenCV.Float64_Value;
      Angle_Resolution_Radians : OpenCV.Float64_Value;
      Vote_Threshold           : Hough_Vote_Threshold;
      Minimum_Line_Length      : OpenCV.Size_Coordinate := 0;
      Maximum_Line_Gap         : OpenCV.Size_Coordinate := 0)
      return Hough_Line_Segment_Array;

   --  Find_Hough_Circles runs OpenCV's classic gradient Hough circle
   --  detector (HOUGH_GRADIENT) on a nonempty two-dimensional UInt8 C1
   --  grayscale Source; it computes its own Sobel/Canny edges.
   --  Accumulator_Scale is the inverse accumulator resolution and must be
   --  finite and at least 1.0. Minimum_Center_Distance must be positive and
   --  finite. Canny_Threshold is the upper Canny threshold (the lower one is
   --  half of it). Accumulator_Threshold is the center-vote threshold.
   --
   --  This overload searches radii from Minimum_Radius up to an automatic
   --  maximum chosen by OpenCV (the larger Source dimension).
   function Find_Hough_Circles
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0)
      return Hough_Circle_Array;

   --  This overload searches the explicit radius interval. Maximum_Radius
   --  must exceed Minimum_Radius; it is never silently widened.
   function Find_Hough_Circles
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0;
      Maximum_Radius          : OpenCV.Size_Coordinate)
      return Hough_Circle_Array;

   --  Hough evidence. Votes are accumulator support counts. OpenCV keeps
   --  only strict local maxima whose count exceeds the requested threshold,
   --  so an accepted line or circle normally reports Votes > threshold.
   --  Magnitudes and ordering may differ between OpenCV generations and
   --  optional backends; use Votes for ranking and evidence, not as a
   --  portable constant.

   --  Find_Hough_Lines_With_Votes has exactly the contract of
   --  Find_Hough_Lines and adds each line's accumulator votes. OpenCV's
   --  optional IPP standard-Hough path is available only to the vote-free
   --  output, so on IPP-enabled builds the two operations need not return
   --  identical lines or ordering.
   function Find_Hough_Lines_With_Votes
     (Source                   : OpenCV.Core.Mat;
      Distance_Resolution      : OpenCV.Float64_Value;
      Angle_Resolution_Radians : OpenCV.Float64_Value;
      Vote_Threshold           : Hough_Vote_Threshold;
      Minimum_Angle_Radians    : OpenCV.Float64_Value := 0.0;
      Maximum_Angle_Radians    : OpenCV.Float64_Value := Ada.Numerics.Pi)
      return Hough_Line_With_Votes_Array;

   --  Find_Hough_Lines_From_Points runs OpenCV's HoughLinesPointSet on an
   --  explicit set of points (any bounds; may be empty; every coordinate
   --  finite). Rho bins start at Minimum_Rho with width Distance_Resolution;
   --  Minimum_Rho < Maximum_Rho is required, and every point must vote
   --  inside the rho range for every searched angle, otherwise the request
   --  is rejected (this makes OpenCV 4.1, which does not bounds-check votes,
   --  behave safely). Angle bounds satisfy
   --  0 <= Minimum_Angle_Radians < Maximum_Angle_Radians <= Pi, and each
   --  resolution must yield at least one bin. At most Maximum_Lines results
   --  are returned; an empty point set returns the empty result.
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
      return Hough_Line_With_Votes_Array;

   --  Find_Hough_Circle_Centers runs the classic gradient detector with the
   --  same Source and parameter contract as Find_Hough_Circles, but skips
   --  radius estimation and reports only candidate centers. Minimum_Radius
   --  still limits how close to each edge pixel center votes are cast.
   function Find_Hough_Circle_Centers
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0)
      return Hough_Circle_Center_Array;

   --  Find_Hough_Circles_With_Votes mirror the two Find_Hough_Circles
   --  overloads (automatic and explicit maximum radius) and add the support
   --  count of each estimated radius. They always estimate radii.
   function Find_Hough_Circles_With_Votes
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0)
      return Hough_Circle_With_Votes_Array;

   function Find_Hough_Circles_With_Votes
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0;
      Maximum_Radius          : OpenCV.Size_Coordinate)
      return Hough_Circle_With_Votes_Array;

   --  Segmentation. Contract violations, native arithmetic limits, and
   --  OpenCV failures raise OpenCV.OpenCV_Error.

   --  Floating_Range compares each candidate with its already-filled
   --  neighbour; Fixed_Range compares every candidate with the seed pixel.
   type Flood_Fill_Range_Mode is (Floating_Range, Fixed_Range);

   subtype Flood_Fill_Mask_Value is OpenCV.UInt8_Value range 1 .. 255;

   --  Pixel_Count is the number of filled pixels. Bounds is the smallest
   --  rectangle containing them, in the coordinates of the supplied Image.
   type Flood_Fill_Result is record
      Pixel_Count : Natural;
      Bounds      : OpenCV.Rect;
   end record;

   --  Fills the connected component containing Seed with New_Value in place.
   --  Image must be a nonempty two-dimensional UInt8 or Float32 Mat with one
   --  or three channels; Seed (X is the column, Y the row) must lie inside
   --  it. A neighbour joins the component when every channel lies within
   --  [reference - Lower_Difference, reference + Upper_Difference], where
   --  the reference follows Range_Mode. The components used by Image's
   --  channels must be finite, and the differences nonnegative. A Region is
   --  filled as its own logical image and mutates its parent's storage;
   --  shallow aliases observe the mutation.
   procedure Flood_Fill
     (Image            : in out OpenCV.Core.Mat;
      Seed             : OpenCV.Point;
      New_Value        : OpenCV.Scalar;
      Result           : out Flood_Fill_Result;
      Lower_Difference : OpenCV.Scalar := (others => 0.0);
      Upper_Difference : OpenCV.Scalar := (others => 0.0);
      Connectivity     : Pixel_Connectivity := Four_Connected;
      Range_Mode       : Flood_Fill_Range_Mode := Floating_Range);

   --  As Flood_Fill, additionally constrained and recorded by Mask. Mask is
   --  a UInt8 C1 Mat of (Image.Rows + 2) x (Image.Columns + 2) that must not
   --  share storage with Image: Image (X, Y) corresponds to Mask (X + 1,
   --  Y + 1). Filling never crosses a nonzero mask pixel. Every filled pixel
   --  is set to Mask_Fill_Value in Mask, and OpenCV sets Mask's one-pixel
   --  outer border to 1. When Mask_Only is True, Image is left unchanged and
   --  New_Value is ignored; Mask and Result are still updated.
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
      Mask_Only        : Boolean := False);

   --  Marker-based watershed. Source is a nonempty two-dimensional UInt8 C3
   --  image and is not modified. Markers is an Int32 C1 Mat of the same
   --  rows and columns, updated in place: on input 0 means unknown and each
   --  positive value seeds a region (negative input values are rejected);
   --  on output unknown pixels carry a propagated region label, and -1 marks
   --  watershed boundaries, including Markers' one-pixel outer border.
   --  Markers must not share storage with Source.
   procedure Watershed
     (Source : OpenCV.Core.Mat; Markers : in out OpenCV.Core.Mat);

   type GrabCut_Label is
     (Definite_Background,
      Definite_Foreground,
      Probable_Background,
      Probable_Foreground);

   --  Numeric mask encoding: Definite_Background 0, Definite_Foreground 1,
   --  Probable_Background 2, Probable_Foreground 3.
   function GrabCut_Label_Value
     (Label : GrabCut_Label) return OpenCV.UInt8_Value;

   --  Inverse of GrabCut_Label_Value. Values above 3 raise OpenCV_Error.
   function To_GrabCut_Label (Value : OpenCV.UInt8_Value) return GrabCut_Label;

   subtype GrabCut_Iterations is Positive range 1 .. 2_147_483_647;

   --  Minimum background and foreground pixel counts required to initialize
   --  GrabCut portably: OpenCV 4.1 clusters each training set into five
   --  Gaussian-mixture components with k-means, which needs five samples.
   GrabCut_Minimum_Training_Pixels : constant := 5;
   GrabCut_Model_Column_Count      : constant Positive := 65;

   --  GrabCut segmentation state: a private label mask plus hidden
   --  background and foreground colour models. The type is limited, so a
   --  state cannot be shallow-copied. A default-initialized state is
   --  uninitialized and is rejected by every operation except Is_Initialized.
   type GrabCut_State is limited private;

   function Is_Initialized (State : GrabCut_State) return Boolean;

   --  Initializes from Source, a nonempty two-dimensional UInt8 C3 image,
   --  and Foreground_Region, which must have positive size, lie entirely
   --  inside Source, and leave at least GrabCut_Minimum_Training_Pixels
   --  pixels both inside and outside. Pixels outside the region start as
   --  Definite_Background and inside as Probable_Foreground; Iterations
   --  rounds of segmentation then run. Source is not modified.
   function Initialize_GrabCut
     (Source            : OpenCV.Core.Mat;
      Foreground_Region : OpenCV.Rect;
      Iterations        : GrabCut_Iterations := 1) return GrabCut_State;

   --  Initializes from Source and a caller-built label mask. Initial_Mask
   --  must be a two-dimensional UInt8 C1 Mat with Source's rows and columns
   --  holding only values 0 .. 3 (see GrabCut_Label_Value), with at least
   --  GrabCut_Minimum_Training_Pixels background (definite or probable) and
   --  foreground (definite or probable) pixels. The state owns a deep copy;
   --  Initial_Mask and Source are not modified.
   function Initialize_GrabCut
     (Source       : OpenCV.Core.Mat;
      Initial_Mask : OpenCV.Core.Mat;
      Iterations   : GrabCut_Iterations := 1) return GrabCut_State;

   --  Combines caller labels with a rectangle: every label outside the
   --  region becomes Definite_Background, while all four labels inside are
   --  preserved before segmentation. Requires five pixels of each training
   --  class in the constrained mask. Source and Initial_Mask are unchanged.
   function Initialize_GrabCut
     (Source            : OpenCV.Core.Mat;
      Initial_Mask      : OpenCV.Core.Mat;
      Foreground_Region : OpenCV.Rect;
      Iterations        : GrabCut_Iterations := 1) return GrabCut_State;

   --  Import learned GrabCut state without running segmentation. Mask must
   --  be UInt8 C1, 2-D, nonempty, with labels 0 .. 3. Each model must be
   --  Float64 C1, 1 x 65, with a valid native GrabCut GMM payload. All inputs
   --  are deep-cloned; sparse classes are allowed in restored masks.
   function Restore_GrabCut_State
     (Mask             : OpenCV.Core.Mat;
      Background_Model : OpenCV.Core.Mat;
      Foreground_Model : OpenCV.Core.Mat) return GrabCut_State;

   --  Explicit independent copy of an initialized state.
   function Clone_GrabCut_State (State : GrabCut_State) return GrabCut_State;

   --  Independent deep clones; modifying these Mats cannot change State.
   function GrabCut_Background_Model
     (State : GrabCut_State) return OpenCV.Core.Mat;
   function GrabCut_Foreground_Model
     (State : GrabCut_State) return OpenCV.Core.Mat;

   --  Runs Iterations further rounds that relearn the colour models and
   --  re-segment the probable pixels. Source must be a UInt8 C3 image with
   --  the state's geometry. Definite labels never change. Source is not
   --  modified.
   procedure Refine_GrabCut
     (Source     : OpenCV.Core.Mat;
      State      : in out GrabCut_State;
      Iterations : GrabCut_Iterations := 1);

   --  Re-segments the probable pixels once with the current colour models
   --  held fixed. Otherwise as Refine_GrabCut.
   procedure Refine_GrabCut_Frozen_Model
     (Source : OpenCV.Core.Mat; State : in out GrabCut_State);

   --  Returns an independent deep copy of the UInt8 C1 label mask. Changing
   --  the returned Mat never affects State.
   function GrabCut_Mask (State : GrabCut_State) return OpenCV.Core.Mat;

   --  Returns the label at a zero-based Row and Column of the state's mask.
   function GrabCut_Label_At
     (State : GrabCut_State; Row : Natural; Column : Natural)
      return GrabCut_Label;

   --  Earth mover distance -------------------------------------------------

   type Earth_Mover_Metric is (Manhattan_EMD, Euclidean_EMD, Chessboard_EMD);
   type Earth_Mover_Result is record
      Distance : OpenCV.Float32_Value;
      Flow     : OpenCV.Core.Mat;
   end record;

   --  Nonempty 2-D Float32 C1 signatures: each row is (weight, coordinates).
   --  Built-in metrics require at least one coordinate and equal column
   --  counts.
   --  Explicit Cost permits weights-only signatures (one column); Cost is
   --  Float32 C1, with Rows = Signature_1.Rows and Columns = Signature_2.Rows.
   --  All weights are finite and nonnegative, each signature has positive
   --  total mass, and its sum must remain finite in Float32. Built-in
   --  coordinates are finite; relevant transport costs are nonnegative and
   --  strictly less than the native 1.0e20 Float32 sentinel. All supplied
   --  cost entries are checked, including entries for zero-weight rows.
   --  Unequal total masses are balanced by an internal zero-cost dummy
   --  cluster;
   --  distance is normalized by the larger mass. Flow (when requested) is a
   --  fresh Float32 C1 Rows_1 x Rows_2 Mat of real transported mass; dummy
   --  mass is not represented. Inputs, including Regions, are deep-snapshotted
   --  into packed storage before the native solve. No lower-bound shortcut is
   --  used. Invalid inputs or native failures raise OpenCV_Error.
   function Earth_Mover_Distance
     (Signature_1, Signature_2 : OpenCV.Core.Mat;
      Metric                   : Earth_Mover_Metric := Euclidean_EMD)
      return OpenCV.Float32_Value;
   function Earth_Mover_Distance_With_Flow
     (Signature_1, Signature_2 : OpenCV.Core.Mat;
      Metric                   : Earth_Mover_Metric := Euclidean_EMD)
      return Earth_Mover_Result;
   function Earth_Mover_Distance_With_Cost
     (Signature_1, Signature_2, Cost : OpenCV.Core.Mat)
      return OpenCV.Float32_Value;
   function Earth_Mover_Distance_With_Cost_And_Flow
     (Signature_1, Signature_2, Cost : OpenCV.Core.Mat)
      return Earth_Mover_Result;

   --  Histogram analysis ---------------------------------------------------

   --  Maximum histogram dimensionality guaranteed on every supported OpenCV
   --  generation. OpenCV 4.x allows dense Mats of up to CV_MAX_DIM (32)
   --  dimensions, but OpenCV 5.0 limits Mat to MatShape::MAX_DIMS (10), and
   --  a dense histogram is stored in one N-dimensional Mat.
   Maximum_Histogram_Dimensions : constant Positive := 10;

   subtype Histogram_Bin_Count is Positive range 1 .. 2_147_483_647;

   --  One uniform histogram axis of a single source. Channel is zero-based
   --  relative to that Source Mat. Bin_Count equal-width bins cover the
   --  half-open range [Lower_Bound, Upper_Bound); samples below Lower_Bound
   --  or at or above Upper_Bound are not counted. Both bounds must be finite
   --  with Lower_Bound < Upper_Bound. Internally this is source position 0.
   type Histogram_Dimension is record
      Channel     : Natural;
      Bin_Count   : Histogram_Bin_Count;
      Lower_Bound : OpenCV.Float32_Value;
      Upper_Bound : OpenCV.Float32_Value;
   end record;

   --  Dimension order is iteration order; any index lower bound is accepted.
   type Histogram_Dimension_Array is
     array (Positive range <>) of Histogram_Dimension;

   --  One uniform axis of a multi-source histogram. Source_Position is the
   --  zero-based position in Mat_Array iteration order, independent of the
   --  array's lower bound: position 0 is Sources'First. Channel is
   --  zero-based within that selected source. Native concatenated channel
   --  numbers are not part of this type.
   type Histogram_Source_Dimension is record
      Source_Position : Natural;
      Channel         : Natural;
      Bin_Count       : Histogram_Bin_Count;
      Lower_Bound     : OpenCV.Float32_Value;
      Upper_Bound     : OpenCV.Float32_Value;
   end record;

   --  Dimension order is iteration order; any index lower bound is accepted.
   type Histogram_Source_Dimension_Array is
     array (Positive range <>) of Histogram_Source_Dimension;

   --  Explicit nonuniform bin edges. Iteration order is the edge sequence;
   --  the array's index bounds are irrelevant. N edges define N - 1 bins
   --  [Edges (I), Edges (I + 1)). At least two edges are required.
   type Histogram_Bin_Boundary_Array is
     array (Positive range <>) of OpenCV.Float32_Value;

   --  One nonuniform axis. The descriptor owns a copy of Boundaries, so the
   --  caller's array may be modified or go out of scope afterwards. Edges
   --  must be finite and strictly increasing. They are not required to lie
   --  inside the numeric range of a particular source depth.
   type Histogram_Nonuniform_Dimension is private;

   function Nonuniform_Histogram_Dimension
     (Channel : Natural; Boundaries : Histogram_Bin_Boundary_Array)
      return Histogram_Nonuniform_Dimension;

   function Nonuniform_Histogram_Source_Dimension
     (Source_Position : Natural;
      Channel         : Natural;
      Boundaries      : Histogram_Bin_Boundary_Array)
      return Histogram_Nonuniform_Dimension;

   --  Dimension order is iteration order; any index lower bound is accepted.
   --  Every axis of one histogram uses this nonuniform mode. Mixed uniform
   --  and nonuniform axes are not supported.
   type Histogram_Nonuniform_Dimension_Array is
     array (Positive range <>) of Histogram_Nonuniform_Dimension;

   --  Every axis of one Histogram uses one binning mode. Uniform axes divide
   --  [Lower_Bound, Upper_Bound) into equal bins. Nonuniform axes use the
   --  stored explicit edges.
   type Histogram_Binning_Mode is (Uniform_Binning, Nonuniform_Binning);

   --  A dense histogram of Float32 bin counts together with the source,
   --  channel, and bin-boundary metadata it was calculated with. A Histogram
   --  is immutable: copies share no mutable state and no operation exposes
   --  its storage. A default-initialized Histogram is empty (zero dimensions,
   --  Uniform_Binning) and is rejected by Compare_Histograms, Back_Project,
   --  and Accumulate_Histogram.
   type Histogram is private;

   function Histogram_Dimension_Count (Value : Histogram) return Natural;

   function Histogram_Binning
     (Value : Histogram) return Histogram_Binning_Mode;

   --  Index is 1 .. Histogram_Dimension_Count; others raise OpenCV_Error.
   --  The returned dimension does not include Source_Position. For a
   --  nonuniform axis this is the envelope: Bin_Count is the number of
   --  intervals, Lower_Bound is the first stored edge, and Upper_Bound is
   --  the last. It is not a claim that the intervals are equal.
   function Get_Histogram_Dimension
     (Value : Histogram; Index : Positive) return Histogram_Dimension;

   --  Zero-based source position stored for Index. Single-source histograms
   --  always report 0. Index outside 1 .. Dimension_Count raises OpenCV_Error.
   function Get_Histogram_Source_Position
     (Value : Histogram; Index : Positive) return Natural;

   --  Exact stored edges for Index, in iteration order. A uniform axis
   --  returns its two range endpoints. A nonuniform axis returns all
   --  Bin_Count + 1 edges. The result is independent of the Histogram.
   --  Index outside 1 .. Dimension_Count raises OpenCV_Error.
   function Get_Histogram_Bin_Boundaries
     (Value : Histogram; Index : Positive) return Histogram_Bin_Boundary_Array;

   --  Returns an independent deep copy of the Float32 C1 bin counts. A
   --  one-dimensional histogram is a Bin_Count x 1 Mat, a two-dimensional
   --  one is Bin_Count (1) x Bin_Count (2), and higher dimensionality is an
   --  N-dimensional Mat with one extent per dimension, in dimension order.
   --  The metadata, not the Mat shape, defines the logical dimensionality.
   function Histogram_Values (Value : Histogram) return OpenCV.Core.Mat;

   --  Counts Source samples into a new dense histogram (no accumulation, no
   --  normalization). Source must be a nonempty two-dimensional UInt8,
   --  UInt16 or Float32 Mat, every Channel must be below Source.Channels,
   --  and Dimensions'Length must be 1 .. Maximum_Histogram_Dimensions. A
   --  Region is treated as the whole image. Source is not modified. Every
   --  stored source position is 0.
   function Calculate_Histogram
     (Source : OpenCV.Core.Mat; Dimensions : Histogram_Dimension_Array)
      return Histogram;

   --  As above, counting only pixels whose Mask value is nonzero. Mask must
   --  be a nonempty two-dimensional UInt8 C1 Mat with Source's rows and
   --  columns; it may share storage with Source. Mask is not modified.
   function Calculate_Histogram
     (Source     : OpenCV.Core.Mat;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Dimension_Array) return Histogram;

   --  Joint histogram of every Sources element. Sources must be nonempty and
   --  may have any array bounds. Each element must be a nonempty 2-D UInt8,
   --  UInt16 or Float32 Mat; every element must share the first element's
   --  rows, columns and depth. Channel counts may differ. Each dimension's
   --  Source_Position is a zero-based iteration position (not the Ada index)
   --  and must be below Sources'Length; its Channel must exist on that
   --  source. Dimensions'Length is 1 .. Maximum_Histogram_Dimensions. No
   --  source is modified. A Region is its logical view.
   function Calculate_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Dimensions : Histogram_Source_Dimension_Array) return Histogram;

   --  As above, counting only locations whose Mask value is nonzero. Mask
   --  must be a nonempty 2-D UInt8 C1 Mat with the common source geometry.
   --  It is applied at the same (row, column) of every source and may share
   --  storage with a source. Mask is not modified.
   function Calculate_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Source_Dimension_Array) return Histogram;

   --  Dense nonuniform histogram of one source. Each axis supplies its own
   --  strictly increasing edges; bin I is [edge I, edge I + 1). Every stored
   --  source position must be 0. Otherwise as the uniform single-source
   --  overload: nonempty 2-D UInt8, UInt16 or Float32 Source, 1 .. 10 axes,
   --  and an optional matching UInt8 C1 Mask. Source and Mask are not
   --  modified.
   function Calculate_Nonuniform_Histogram
     (Source     : OpenCV.Core.Mat;
      Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;
   function Calculate_Nonuniform_Histogram
     (Source     : OpenCV.Core.Mat;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;

   --  Dense nonuniform joint histogram. Source_Position is the zero-based
   --  position in Mat_Array iteration order, as for uniform multi-source
   --  histograms. Every axis is nonuniform.
   function Calculate_Nonuniform_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;
   function Calculate_Nonuniform_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;

   --  OpenCV comparison metrics. None is a normalized similarity score.
   --  Correlation: larger is more similar; identical histograms give 1.
   --  Chi_Square: smaller is closer; asymmetric (Left is the denominator).
   --  Intersection: sum of bin minima; larger is more similar and the scale
   --  depends on the histogram totals.
   --  Hellinger_Distance: OpenCV HISTCMP_BHATTACHARYYA, which computes the
   --  Hellinger distance; smaller is closer and identical gives 0.
   --  Alternative_Chi_Square: symmetric chi-square; smaller is closer.
   --  Kullback_Leibler_Divergence: smaller is closer; asymmetric.
   type Histogram_Comparison_Method is
     (Correlation,
      Chi_Square,
      Intersection,
      Hellinger_Distance,
      Alternative_Chi_Square,
      Kullback_Leibler_Divergence);

   --  Uniform histograms must share dimension count and, per dimension, bin
   --  count and both range endpoints. Nonuniform histograms must both be
   --  nonuniform and share dimension count, bin count, and the exact stored
   --  Float32 edge sequence of every axis; matching only the first and last
   --  edges is not enough. Uniform and nonuniform histograms are never
   --  compared, even when a nonuniform sequence happens to be equal-width.
   --  Source positions and channels may differ: comparison is of bin geometry
   --  and counts, not of sample provenance.
   function Compare_Histograms
     (Left   : Histogram;
      Right  : Histogram;
      Method : Histogram_Comparison_Method) return OpenCV.Float64_Value;

   --  Returns a new Mat with Source's rows and columns and depth and one
   --  channel, holding for each pixel the Distribution bin value of its
   --  selected channels multiplied by Scale (saturated for UInt8 and
   --  UInt16), or 0 when a sample lies outside a bin. Uniform and nonuniform
   --  Distributions both use the edges stored in Distribution; callers do
   --  not resupply them. Every stored source position must be 0; a histogram
   --  that selects another source raises OpenCV_Error. Source must be a
   --  nonempty two-dimensional UInt8, UInt16 or Float32 Mat containing every
   --  stored channel; Scale must be finite. A Region is back-projected in
   --  view coordinates. Source and Distribution are not modified.
   function Back_Project
     (Source       : OpenCV.Core.Mat;
      Distribution : Histogram;
      Scale        : OpenCV.Float64_Value := 1.0) return OpenCV.Core.Mat;

   --  Back-projects Sources through the source positions and channels stored
   --  in Distribution. Sources must be nonempty, share rows, columns and a
   --  supported depth, and contain every stored Source_Position. The result
   --  has the first source's rows, columns and depth, and one channel.
   --  Sources and Distribution are not modified. Array bounds do not affect
   --  stored positions: position 0 is Sources'First.
   function Back_Project
     (Sources      : OpenCV.Core.Mat_Array;
      Distribution : Histogram;
      Scale        : OpenCV.Float64_Value := 1.0) return OpenCV.Core.Mat;

   --  Returns a new histogram with Base's binning mode, source positions,
   --  channels and exact stored edges, and the Float32 sum of Base's bins and
   --  a fresh histogram of Source using those dimensions. Base must already
   --  be calculated, and every stored source position must be 0. Base, Source
   --  and (when present) Mask are not modified. The sum is checked in a wider
   --  type; a nonfinite, negative or non-Float32 sum rejects the whole update.
   --  Counts above 2**24 may lose integer-unit precision because storage is
   --  Float32. This does not call native calcHist with accumulate=true.
   function Accumulate_Histogram
     (Base : Histogram; Source : OpenCV.Core.Mat) return Histogram;
   function Accumulate_Histogram
     (Base : Histogram; Source : OpenCV.Core.Mat; Mask : OpenCV.Core.Mat)
      return Histogram;

   --  As above, using Base's stored source positions, channels and complete
   --  boundary sequences. Sources within this call must share geometry and
   --  depth. Separate accumulation calls need not share geometry with each
   --  other or with the images that produced Base.
   function Accumulate_Histogram
     (Base : Histogram; Sources : OpenCV.Core.Mat_Array) return Histogram;
   function Accumulate_Histogram
     (Base    : Histogram;
      Sources : OpenCV.Core.Mat_Array;
      Mask    : OpenCV.Core.Mat) return Histogram;

private
   type Morphology_Border_Value is record
      Use_Default : Boolean := True;
      Value       : OpenCV.Scalar := (others => 0.0);
   end record;
   Default_Morphology_Border : constant Morphology_Border_Value :=
     (Use_Default => True, Value => (others => 0.0));
   type Fixed_Remap_Maps is record
      Coordinates  : OpenCV.Core.Mat;
      Coefficients : OpenCV.Core.Mat;
   end record;

   package Contour_Vectors is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Natural,
        Element_Type => Contour,
        "="          => OpenCV."=");
   package Hierarchy_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Natural,
        Element_Type => Contour_Hierarchy_Entry);

   type Contour_Set is record
      Contours  : Contour_Vectors.Vector;
      Hierarchy : Hierarchy_Vectors.Vector;
   end record;

   package Component_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Natural,
        Element_Type => Component_Statistics);

   type Connected_Component_Set is record
      Components : Component_Vectors.Vector;
   end record;

   --  The Mats are owned exclusively by the state. Background_Model and
   --  Foreground_Model hold OpenCV's native Float64 1 x 65 mixture models.
   type GrabCut_State is limited record
      Mask             : OpenCV.Core.Mat;
      Background_Model : OpenCV.Core.Mat;
      Foreground_Model : OpenCV.Core.Mat;
      Initialized      : Boolean := False;
   end record;

   function Boundary_Equal (Left, Right : OpenCV.Float32_Value) return Boolean;

   package Histogram_Boundary_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => OpenCV.Float32_Value,
        "="          => Boundary_Equal);

   package Histogram_Dimension_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Histogram_Source_Dimension);

   --  Owns the edge sequence. Uniform axes store exactly two endpoints.
   --  Nonuniform axes store Bin_Count + 1 strictly increasing edges. The
   --  Histogram that owns a vector of these records uses one binning mode
   --  for every axis.
   type Histogram_Axis is record
      Source_Position : Natural := 0;
      Channel         : Natural := 0;
      Bin_Count       : Histogram_Bin_Count := 1;
      Boundaries      : Histogram_Boundary_Vectors.Vector;
   end record;

   package Histogram_Axis_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Histogram_Axis);

   type Histogram_Nonuniform_Dimension is record
      Source_Position : Natural := 0;
      Channel         : Natural := 0;
      Boundaries      : Histogram_Boundary_Vectors.Vector;
   end record;

   --  Values is the dense Float32 histogram produced by this package and
   --  referenced by no other header; Mat assignment is shallow, but no
   --  operation mutates or exposes it, so sharing between copies is never
   --  observable. Axes is the authoritative Ada-owned metadata, including
   --  each axis's source position and complete edge sequence. Single-source
   --  axes store source position 0. Every axis uses the same binning mode.
   type Histogram is record
      Values  : OpenCV.Core.Mat;
      Binning : Histogram_Binning_Mode := Uniform_Binning;
      Axes    : Histogram_Axis_Vectors.Vector;
   end record;
end OpenCV.Image_Processing;
