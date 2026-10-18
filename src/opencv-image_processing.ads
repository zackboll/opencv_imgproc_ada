with Ada.Numerics;
with OpenCV.Core;
private with Ada.Containers.Indefinite_Vectors;
private with Ada.Containers.Vectors;

package OpenCV.Image_Processing is

   --  Thick Ada binding to the OpenCV Imgproc module. Every operation
   --  works on OpenCV.Core.Mat values and the shared value types of the
   --  root OpenCV package (Point, Size, Rect, Scalar, Border_Kind and the
   --  element value types); this package defines only Imgproc-specific
   --  types.
   --
   --  Conventions shared by all operations:
   --
   --  - Images are borrowed for the duration of a call and never retained.
   --    A Mat of mode in is read and not modified; operations that modify
   --    an image take it as in out and say so.
   --  - Element types are written as a Core depth and channel count, so
   --    "UInt8 C3" is depth UInt8 with three channels. Images are
   --    two-dimensional unless stated otherwise.
   --  - Coordinates are zero-based. Point X is the column and Y the row;
   --    Size Width counts columns and Height counts rows.
   --  - A Region is a Mat header viewing part of another Mat. Operations
   --    that snapshot or isolate their inputs say so and treat a Region as
   --    its own logical image. Otherwise a Region is passed to OpenCV as a
   --    submatrix, and OpenCV's border extrapolation may read pixels of the
   --    parent just outside it (OpenCV looks outside a submatrix unless
   --    asked not to). Pixels outside a Region are written only where an
   --    operation says so.
   --  - Each operation states whether it returns fresh owning storage,
   --    replaces a Destination, or writes into existing storage, and which
   --    input and output aliases are supported.
   --  - Contract violations and failures reported by OpenCV raise
   --    OpenCV.OpenCV_Error. A value outside an Ada subtype range raises
   --    Constraint_Error before the operation runs.
   --  - Behavior notes that depend on the OpenCV release refer to the
   --    reviewed OpenCV 4.1, 4.10 and 5.0 sources. Floating-point results
   --    retain native rounding; bit identity across OpenCV releases,
   --    platforms and optional acceleration backends is not promised
   --    unless stated.
   --
   --  Drawing primitives mutate Image in place. A shallow Mat alias or a
   --  Region shares that storage, so a drawing made through either header
   --  is visible through the other. Region coordinates are relative to the
   --  Region. Pixels outside a Region are not modified. Image must be
   --  nonempty and two-dimensional, with depth UInt8, UInt16, Int16,
   --  Float32, or Float64 and 1 through 4 channels. Scalar components are
   --  written in channel order; unused components are ignored and there is
   --  no alpha blending. The components used by Image.Channels must be
   --  finite. Coordinates may lie outside Image; OpenCV clips them.
   --  Outline operations use a positive Drawing_Thickness.
   --  Anti_Aliased_Line is accepted only for UInt8 images. Contract
   --  violations and OpenCV failures raise OpenCV.OpenCV_Error.
   --
   --  Hough detection. Every operation takes a private continuous snapshot
   --  of Source before calling OpenCV, so Source pixels are never modified
   --  and a Region is analysed as its own logical image with its own
   --  borders. Results are Ada-owned copies. Result order is not part of
   --  the contract. Contract violations, native arithmetic limits, and
   --  OpenCV failures raise OpenCV.OpenCV_Error.
   --
   --  Hough evidence. Votes are accumulator support counts. OpenCV keeps
   --  only strict local maxima whose count exceeds the requested
   --  threshold, so an accepted line or circle normally reports Votes >
   --  threshold. Magnitudes and ordering may differ between OpenCV
   --  generations and optional backends; use Votes for ranking and
   --  evidence, not as a portable constant.
   --
   --  Segmentation. Contract violations, native arithmetic limits, and
   --  OpenCV failures raise OpenCV.OpenCV_Error.

   --  Normalization Squared_Box_Filter applies to the sum of squared
   --  samples in each window.
   --  @enum Mean_Square Divide the window sum by the effective kernel area
   --  `Width * Height`, giving the local mean of the squares.
   --  @enum Sum_Of_Squares Return the unnormalized window sum of squares.
   type Squared_Box_Mode is (Mean_Square, Sum_Of_Squares);

   --  Native squared box filtering (cv::sqrBoxFilter): for every pixel and
   --  channel, sums the squares of the Source samples in a Kernel_Size
   --  window and, for Mean_Square, divides by the effective kernel area.
   --  Returns fresh independent Float64 storage with Source's rows, columns
   --  and channel count; Source is unchanged.
   --
   --  Source must be nonempty 2-D UInt8 or Float32 with 1 or 3 channels.
   --  The window for column X starts at `X - Width / 2` and spans Width
   --  columns, and rows likewise, so positive odd, even and oversized
   --  kernels are all accepted. Normalized nonconstant singleton axes
   --  reduce to one: with Mean_Square and a Border other than
   --  Constant_Border, a one-column or one-row Source uses a kernel
   --  dimension of one on that axis; Constant_Border and Sum_Of_Squares
   --  keep the requested dimensions. The UInt8 effective area is at most
   --  33025 (native signed accumulator) and the Float32 area at most
   --  2_147_483_647; other unsafe native signed arithmetic is rejected.
   --
   --  Regions are isolated: only the Region's logical pixels are read and
   --  border extrapolation never reaches the parent. Float32 retains native
   --  incremental rounding and NaN/Inf propagation, which can persist
   --  beyond the ideal mathematical local window; tiny finite residuals
   --  after large values may be lost. This is not an exact per-window sum.
   --  @param Source Image whose squared samples are summed.
   --  @param Kernel_Size Window width and height in pixels; both must be
   --  positive and may be even or exceed the image.
   --  @param Mode Mean_Square (default) divides by the effective area;
   --  Sum_Of_Squares returns the plain sum.
   --  @param Border Extrapolation outside Source: Constant_Border (zero
   --  samples, still counted in the Mean_Square area), Replicate, Reflect
   --  or Reflect_101 (default). Wrap is rejected.
   --  @return Fresh owning Float64 Mat with one squared-window value per
   --  Source pixel and channel.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  unsupported Source, a zero kernel dimension, Wrap, an effective area
   --  above its limit, unsafe native arithmetic, or a native failure.
   function Squared_Box_Filter
     (Source      : OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Size;
      Mode        : Squared_Box_Mode := Mean_Square;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;

   --  Native cv::blendLinear: a per-pixel weighted blend of two images,
   --  returned as fresh independent owning storage with the sources' rows,
   --  columns, depth and channel count. The native binary32 formula per
   --  channel is
   --
   --       (Source_1 * Weight_1 + Source_2 * Weight_2)
   --         / (Weight_1 + Weight_2 + 1.0e-5f)
   --
   --  One weight per pixel from each map applies to all channels. Weights
   --  need not sum to one: `(1, 1)` approximates the average and `(1, 0)`
   --  retains the epsilon bias. UInt8 then uses native rounding/saturation.
   --  Both-zero weights yield zero for finite sources; Float32 NaN, Inf and
   --  overflow retain native IEEE behavior (including `Inf * 0`). Float32
   --  cross-platform bit identity is not promised.
   --
   --  Sources: nonempty 2-D UInt8 or Float32 with identical depth, channels
   --  and geometry. Any Core-valid channel count is accepted when
   --  `Columns * Channels <= INT_MAX` (native representation allows up to
   --  512 channels in OpenCV 4.1/4.10 and 128 in 5.0). Weights: nonempty
   --  2-D Float32 C1 with the sources' geometry, every sample finite and
   --  in the range 0.0 .. 1.0.
   --
   --  All inputs remain unchanged; read-sharing/overlapping aliases work.
   --  Regions contribute only logical pixels, with original row strides.
   --  Concurrent external mutation is unsupported. Publication is atomic.
   --  @param Source_1 First image, weighted by Weight_1.
   --  @param Source_2 Second image, weighted by Weight_2; same depth,
   --  channel count and geometry as Source_1.
   --  @param Weight_1 Float32 C1 per-pixel weights for Source_1.
   --  @param Weight_2 Float32 C1 per-pixel weights for Source_2.
   --  @return Fresh owning Mat with the blended pixels, typed like the
   --  sources.
   --  @exception OpenCV_Error Raised for an empty, non-2-D,
   --  mismatched or unsupported input, a weight sample that is nonfinite or
   --  outside 0.0 .. 1.0, an oversized channel-expanded width, or a native
   --  failure.
   function Blend_Linear
     (Source_1, Source_2, Weight_1, Weight_2 : OpenCV.Core.Mat)
      return OpenCV.Core.Mat;

   --  Translation estimated by Phase_Correlate: the native subpixel
   --  displacement of Source_2 relative to Source_1, in pixels, and the
   --  strength of the correlation peak. Right/down is positive.
   --  @field X_Shift Column (X) displacement of Source_2 relative to
   --  Source_1; positive when Source_2 content lies to the right.
   --  @field Y_Shift Row (Y) displacement of Source_2 relative to
   --  Source_1; positive when Source_2 content lies lower.
   --  @field Response Native normalized 5x5 peak energy: the energy of the
   --  weighted peak centroid divided by the padded DFT plane size. It
   --  indicates peak concentration; it is not a probability or a
   --  guaranteed [0, 1] value, and rounding can exceed the ideal bounds.
   type Phase_Correlation_Result is record
      X_Shift, Y_Shift, Response : OpenCV.Float64_Value;
   end record;

   --  Estimates the translation between two images of identical type and
   --  geometry with native cv::phaseCorrelate, without a window.
   --  Shift describes Source_2 relative to Source_1: right/down is positive.
   --  Apply the negative shift to Source_2 to align it with Source_1.
   --
   --  Sources must be nonempty 2-D Float32 or Float64 C1 Mats with
   --  identical depth, rows and columns. No conversion, normalization or
   --  finiteness scan is performed; nonfinite samples retain native
   --  behavior and can give numerically unhelpful results. Both sources are
   --  independently snapshotted into packed private copies before native
   --  execution: Regions contribute only logical pixels, the same or
   --  overlapping storage may be passed twice, and inputs are unchanged on
   --  success or failure. Concurrent external mutation is unsupported.
   --  The native transform pads to optimal DFT sizes; unsupported sizes
   --  and signed-arithmetic or allocation limits of the padded plane raise
   --  OpenCV_Error. Response is not promised to match across releases:
   --  OpenCV 4.1 squares special DC/Nyquist spectrum entries where 4.10
   --  and 5.0 use their absolute value.
   --  @param Source_1 Reference image.
   --  @param Source_2 Image whose displacement relative to Source_1 is
   --  measured.
   --  @return Shift of Source_2 and peak Response.
   --  @exception OpenCV_Error Empty, non-2-D, non-floating or
   --  multichannel source, mismatched sources, native DFT size limits, or
   --  an OpenCV failure.
   function Phase_Correlate
     (Source_1, Source_2 : OpenCV.Core.Mat) return Phase_Correlation_Result;

   --  Windowed Phase_Correlate: Window multiplies both sources before the
   --  native DFT (cv::phaseCorrelate window argument). Window must be a
   --  nonempty 2-D C1 Mat with the sources' depth, rows and columns, for
   --  example from Create_Hanning_Window; an empty Window is rejected.
   --  Window is snapshotted like the sources, so it may share storage with
   --  either source and is never modified. Source requirements, the
   --  right/down-positive shift of Source_2 relative to Source_1, Response,
   --  Region, alias and limit rules are those of the two-source overload.
   --  @param Source_1 Reference image.
   --  @param Source_2 Image whose displacement relative to Source_1 is
   --  measured.
   --  @param Window Weighting window applied to both sources.
   --  @return Shift of Source_2 and peak Response.
   --  @exception OpenCV_Error Invalid or mismatched sources, empty
   --  or mismatched Window, native DFT size limits, or an OpenCV failure.
   function Phase_Correlate
     (Source_1, Source_2, Window : OpenCV.Core.Mat)
      return Phase_Correlation_Result;

   --  Element depth of a window created by Create_Hanning_Window.
   --  @enum Float32_Hanning_Window Float32 C1 window coefficients.
   --  @enum Float64_Hanning_Window Float64 C1 window coefficients, the
   --  Create_Hanning_Window default.
   type Hanning_Window_Depth is
     (Float32_Hanning_Window, Float64_Hanning_Window);

   --  Creates a two-dimensional Hann window with native
   --  cv::createHanningWindow, for example as a Phase_Correlate Window.
   --  Each coefficient is the square root of the separable product of a
   --  horizontal and a vertical Hann coefficient, with native rounding.
   --  The window is symmetric, its first and last rows and columns are
   --  zero up to rounding, and an odd-sized window is approximately 1.0 at
   --  its center. OpenCV 5.0 vector cosine paths can round differently
   --  from 4.1 and 4.10; bit-for-bit coefficients are not promised.
   --  @param Window_Size Window columns (Width) and rows (Height). Both
   --  must exceed one, and `Width * Height` must not exceed `2**31 - 1`.
   --  @param Depth Coefficient depth; defaults to Float64_Hanning_Window.
   --  @return Fresh owning C1 Mat of the requested depth with
   --  Window_Size.Height rows and Window_Size.Width columns.
   --  @exception OpenCV_Error A dimension is at most one, the
   --  allocation or index preflight overflows, or OpenCV fails.
   function Create_Hanning_Window
     (Window_Size : OpenCV.Size;
      Depth       : Hanning_Window_Depth := Float64_Hanning_Window)
      return OpenCV.Core.Mat;

   --  Image/pixel accumulation, not histogram accumulation: returns
   --  `Base + Source` at every pixel and channel. Accumulate_Image,
   --  Accumulate_Image_Square, Accumulate_Image_Product and
   --  Update_Running_Average share this contract. All inputs are nonempty
   --  2-D Mats of identical geometry. Base is Float32 or Float64 with
   --  Source's channel count. Plain accumulation accepts UInt8, UInt16,
   --  Float32 and Float64 (Float64 requires a Float64 Base), any channels.
   --  Square, product and running average accept UInt8/Float32 C1 or C3.
   --
   --  Each function updates a private Base clone and returns fresh
   --  independent storage, with Base's geometry, depth and channel count,
   --  only after success; nothing is modified on failure. Inputs and
   --  Region parents are never modified; Regions contribute only logical
   --  pixels, and a Base Region yields a packed independent result. All
   --  input storage aliases are supported, including identical and
   --  overlapping inputs. Native floating overflow is not saturated or
   --  prohibited: arithmetic follows IEEE, including overflow to infinity.
   --  Each input's pixel count, channel-sample count, byte count and row
   --  stride must not exceed 2_147_483_647 (native int layout limits).
   --  @param Source UInt8, UInt16, Float32 or Float64 image (Float64
   --  requires a Float64 Base) added to Base; any channel count.
   --  @param Base Float32 or Float64 accumulator of Source's geometry and
   --  channel count. It is read, not updated.
   --  @return Fresh Mat typed like Base holding `Base + Source`.
   --  @exception OpenCV_Error Raised for an empty or non-2-D input,
   --  mismatched geometry or channel count, an unsupported depth pair,
   --  an input beyond the native layout limits, or a native failure.
   function Accumulate_Image
     (Source, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Masked Accumulate_Image: the result holds `Base + Source` only at
   --  pixels whose Mask sample is nonzero and Base's values elsewhere. Any
   --  nonzero Mask value enables every channel at that pixel. Depths,
   --  geometry, fresh-result publication, Region, aliasing and layout
   --  rules are those of the unmasked overload.
   --  @param Source Image added at enabled pixels: UInt8, UInt16, Float32
   --  or Float64 (Float64 requires a Float64 Base), any channel count.
   --  @param Base Float32 or Float64 accumulator of Source's geometry and
   --  channel count. It is read, not updated.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with Source's rows and
   --  columns; zero preserves Base. It may share storage with Source.
   --  @return Fresh Mat typed like Base holding the masked sum.
   --  @exception OpenCV_Error Raised for an invalid Source or Base
   --  as for the unmasked overload, or for a Mask that is empty, not 2-D,
   --  not UInt8 C1 or of different geometry.
   function Accumulate_Image
     (Source, Base, Mask : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Squared accumulation: returns `Base + Source * Source` at every pixel
   --  and channel, in fresh storage typed like Base. Source is UInt8 or
   --  Float32 with one or three channels; Base is Float32 or Float64 with
   --  Source's geometry and channel count. Otherwise as Accumulate_Image:
   --  nonempty 2-D inputs, private Base clone published only after
   --  success, logical Regions, all aliases supported, native layout
   --  limits, and unsaturated IEEE floating arithmetic.
   --  @param Source UInt8 or Float32 C1 or C3 image whose squares are
   --  added.
   --  @param Base Float32 or Float64 accumulator of Source's geometry and
   --  channel count. It is read, not updated.
   --  @return Fresh Mat typed like Base holding the squared sum.
   --  @exception OpenCV_Error Raised for an empty or non-2-D input,
   --  mismatched geometry or channel count, an unsupported depth or
   --  channel count, an input beyond the native layout limits, or a native
   --  failure.
   function Accumulate_Image_Square
     (Source, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Masked Accumulate_Image_Square: adds `Source * Source` only at pixels
   --  whose Mask sample is nonzero; elsewhere the result keeps Base. Any
   --  nonzero Mask value enables every channel at that pixel. Otherwise as
   --  the unmasked overload.
   --  @param Source UInt8 or Float32 C1 or C3 image whose squares are
   --  added at enabled pixels.
   --  @param Base Float32 or Float64 accumulator of Source's geometry and
   --  channel count. It is read, not updated.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with Source's rows and
   --  columns; zero preserves Base. It may share storage with Source.
   --  @return Fresh Mat typed like Base holding the masked squared sum.
   --  @exception OpenCV_Error Raised for an invalid Source or Base
   --  as for the unmasked overload, or for a Mask that is empty, not 2-D,
   --  not UInt8 C1 or of different geometry.
   function Accumulate_Image_Square
     (Source, Base, Mask : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Product accumulation: returns `Base + Source_1 * Source_2` at every
   --  pixel and channel, in fresh storage typed like Base. The sources are
   --  UInt8 or Float32 C1 or C3 with identical depth, channel count and
   --  geometry; they may be the same Mat. Base is Float32 or Float64 with
   --  their geometry and channel count. Otherwise as Accumulate_Image:
   --  nonempty 2-D inputs, private Base clone published only after
   --  success, logical Regions, all aliases supported, native layout
   --  limits, and unsaturated IEEE floating arithmetic.
   --  @param Source_1 First UInt8 or Float32 C1 or C3 factor image.
   --  @param Source_2 Second factor image, typed and sized like Source_1.
   --  @param Base Float32 or Float64 accumulator of the sources' geometry
   --  and channel count. It is read, not updated.
   --  @return Fresh Mat typed like Base holding the product sum.
   --  @exception OpenCV_Error Raised for an empty or non-2-D input,
   --  sources of different type or geometry, an unsupported depth or
   --  channel count, a mismatched Base, an input beyond the native layout
   --  limits, or a native failure.
   function Accumulate_Image_Product
     (Source_1, Source_2, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Masked Accumulate_Image_Product: adds `Source_1 * Source_2` only at
   --  pixels whose Mask sample is nonzero; elsewhere the result keeps
   --  Base. Any nonzero Mask value enables every channel at that pixel.
   --  Otherwise as the unmasked overload.
   --  @param Source_1 First UInt8 or Float32 C1 or C3 factor image.
   --  @param Source_2 Second factor image, typed and sized like Source_1.
   --  @param Base Float32 or Float64 accumulator of the sources' geometry
   --  and channel count. It is read, not updated.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with the sources' rows
   --  and columns; zero preserves Base.
   --  @return Fresh Mat typed like Base holding the masked product sum.
   --  @exception OpenCV_Error Raised for invalid sources or Base as
   --  for the unmasked overload, or for a Mask that is empty, not 2-D, not
   --  UInt8 C1 or of different geometry.
   function Accumulate_Image_Product
     (Source_1, Source_2, Base, Mask : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Running (exponentially weighted) average: the result is
   --  `(1 - Weight) * Base + Weight * Source` at every pixel and channel,
   --  in fresh storage typed like Base. Weight must be finite and in
   --  0.0 .. 1.0 (otherwise OpenCV_Error). Zero retains a finite Base; one
   --  yields the source values converted to Base's depth. Native code may
   --  round Weight to the accumulator precision or, on IPP paths, to
   --  Float32. Source is UInt8 or Float32 C1 or C3; Base is Float32 or
   --  Float64 with Source's geometry and channel count. Otherwise as
   --  Accumulate_Image: nonempty 2-D inputs, private Base clone published
   --  only after success, logical Regions, all aliases supported, native
   --  layout limits, and unsaturated IEEE floating arithmetic.
   --  @param Source UInt8 or Float32 C1 or C3 image blended into Base.
   --  @param Base Float32 or Float64 running average of Source's geometry
   --  and channel count. It is read, not updated.
   --  @param Weight Finite weight of Source in 0.0 .. 1.0; larger values
   --  forget Base faster.
   --  @return Fresh Mat typed like Base holding the updated average.
   --  @exception OpenCV_Error Raised for a NaN, infinite or
   --  out-of-range Weight, an empty or non-2-D input, mismatched geometry
   --  or channel count, an unsupported depth or channel count, an input
   --  beyond the native layout limits, or a native failure.
   function Update_Running_Average
     (Source, Base : OpenCV.Core.Mat; Weight : OpenCV.Float64_Value)
      return OpenCV.Core.Mat;

   --  Masked Update_Running_Average: the result is
   --  `(1 - Weight) * Base + Weight * Source` only at pixels whose Mask
   --  sample is nonzero and Base elsewhere. Any nonzero Mask value enables
   --  every channel at that pixel. Otherwise as the unmasked overload.
   --  @param Source UInt8 or Float32 C1 or C3 image blended into Base at
   --  enabled pixels.
   --  @param Base Float32 or Float64 running average of Source's geometry
   --  and channel count. It is read, not updated.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with Source's rows and
   --  columns; zero preserves Base. It may share storage with Source.
   --  @param Weight Finite weight of Source in 0.0 .. 1.0.
   --  @return Fresh Mat typed like Base holding the masked average.
   --  @exception OpenCV_Error Raised for an invalid Weight, Source
   --  or Base as for the unmasked overload, or for a Mask that is empty,
   --  not 2-D, not UInt8 C1 or of different geometry.
   function Update_Running_Average
     (Source, Base, Mask : OpenCV.Core.Mat; Weight : OpenCV.Float64_Value)
      return OpenCV.Core.Mat;

   --  Depth of the summed-area (Sum) and tilted-sum outputs of
   --  Integral_Sum, Integral_Sum_And_Squares and Integral_Images. UInt8
   --  sources accept every literal, Float32 sources Float32_Integral or
   --  Float64_Integral, and Float64 sources only Float64_Integral; other
   --  pairings raise OpenCV_Error.
   --  @enum Int32_Integral Int32 sums, for UInt8 sources only. Rejected
   --  when the actual total of any channel exceeds 2_147_483_647.
   --  @enum Float32_Integral Float32 sums, for UInt8 or Float32 sources,
   --  with Float32 rounding.
   --  @enum Float64_Integral Float64 sums, for every supported source
   --  depth; the default of every integral function.
   type Integral_Sum_Depth is
     (Int32_Integral, Float32_Integral, Float64_Integral);

   --  Depth of the Squared_Sum output of Integral_Sum_And_Squares and
   --  Integral_Images.
   --  @enum Float32_Squared_Integral Float32 squared sums. Rejected together
   --  with a Float64_Integral Sum, and therefore for Float64 sources.
   --  @enum Float64_Squared_Integral Float64 squared sums, accepted with
   --  every Sum depth; the default.
   type Integral_Squared_Depth is
     (Float32_Squared_Integral, Float64_Squared_Integral);

   --  Result of Integral_Sum_And_Squares: two fresh owning Mats with
   --  Source's channel count and (Source.Rows + 1) x (Source.Columns + 1)
   --  geometry, each with a zero first row and first column. Channels are
   --  summed independently.
   --  @field Sum Summed-area table: the element at row Y, column X is the
   --  sum of source pixels with row < Y and column < X. Its depth is
   --  selected by Sum_Depth.
   --  @field Squared_Sum Sum of squared source samples over the same
   --  rectangles as Sum. Its depth is selected by Squared_Depth.
   type Integral_Sum_And_Squares_Result is record
      Sum         : OpenCV.Core.Mat;
      Squared_Sum : OpenCV.Core.Mat;
   end record;

   --  Result of Integral_Images: three fresh owning Mats with Source's
   --  channel count and (Source.Rows + 1) x (Source.Columns + 1) geometry.
   --  Channels are summed independently.
   --  @field Sum Summed-area table: the element at row Y, column X is the
   --  sum of source pixels with row < Y and column < X; the first row and
   --  column are zero. Its depth is selected by Sum_Depth.
   --  @field Squared_Sum Sum of squared source samples over the same
   --  rectangles as Sum, with a zero first row and column. Its depth is
   --  selected by Squared_Depth.
   --  @field Tilted_Sum OpenCV's 45-degree rotated sum: the element at row
   --  Y, column X adds source pixels (x, y) with y < Y and
   --  `abs (x - X + 1) <= Y - y - 1`. It has the same depth as Sum.
   type Integral_Images_Result is record
      Sum         : OpenCV.Core.Mat;
      Squared_Sum : OpenCV.Core.Mat;
      Tilted_Sum  : OpenCV.Core.Mat;
   end record;

   --  Computes the summed-area table of Source: the element at row Y,
   --  column X is the sum of source pixels with row < Y and column < X.
   --  With S (row, column) denoting that element, the rectangle
   --  [X1, X2) x [Y1, Y2) totals
   --  `S (Y2, X2) - S (Y1, X2) - S (Y2, X1) + S (Y1, X1)`.
   --
   --  Nonempty 2-D UInt8, Float32 or Float64 source with any channel
   --  count. Each channel is independent; the result is a fresh (Rows+1,
   --  Columns+1) Mat with Source's channel count and a zero top row and
   --  left column. A Region is its own logical image: pixels outside it do
   --  not participate. Source is unchanged. The sum is computed privately
   --  and published only after success. UInt8/Int32 is rejected if any
   --  actual channel total exceeds INT_MAX. Floating sums follow the
   --  selected precision and IEEE rounding, overflow and NaN propagation;
   --  there is no finite-value scan. Geometry, channel-expanded widths and
   --  strides that would overflow OpenCV's native int arithmetic are
   --  rejected.
   --  @param Source Nonempty 2-D UInt8, Float32 or Float64 image to
   --  integrate.
   --  @param Sum_Depth Depth of the result; see Integral_Sum_Depth for the
   --  pairings each source depth accepts. Defaults to Float64_Integral.
   --  @return Fresh owning summed-area Mat.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  unsupported-depth Source, an unsupported Sum_Depth, an Int32 total
   --  overflow, a native int arithmetic limit, or a native failure.
   function Integral_Sum
     (Source    : OpenCV.Core.Mat;
      Sum_Depth : Integral_Sum_Depth := Float64_Integral)
      return OpenCV.Core.Mat;

   --  Computes the summed-area table and the integral of squared samples
   --  of Source in one native call (see Integral_Sum_And_Squares_Result).
   --  The Source contract, geometry, Region, Int32 overflow and native
   --  limit rules are those of Integral_Sum. Both Mats are fresh owning
   --  storage published only after complete success. Accepted
   --  (Sum_Depth, Squared_Depth) pairs: UInt8 accepts all except
   --  (Float64_Integral, Float32_Squared_Integral); Float32 accepts
   --  (Float32, Float32), (Float32, Float64) and (Float64, Float64);
   --  Float64 accepts only (Float64, Float64).
   --  @param Source Nonempty 2-D UInt8, Float32 or Float64 image to
   --  integrate.
   --  @param Sum_Depth Depth of the Sum component; defaults to
   --  Float64_Integral.
   --  @param Squared_Depth Depth of the Squared_Sum component; defaults to
   --  Float64_Squared_Integral.
   --  @return Record holding the fresh Sum and Squared_Sum Mats.
   --  @exception OpenCV_Error Raised for an invalid Source, an
   --  unsupported depth pair, an Int32 total overflow, a native int
   --  arithmetic limit, or a native failure.
   function Integral_Sum_And_Squares
     (Source        : OpenCV.Core.Mat;
      Sum_Depth     : Integral_Sum_Depth := Float64_Integral;
      Squared_Depth : Integral_Squared_Depth := Float64_Squared_Integral)
      return Integral_Sum_And_Squares_Result;

   --  Computes the summed-area table, the squared-sample integral and
   --  OpenCV's 45-degree tilted sum of Source in one native call (see
   --  Integral_Images_Result). Tilted_Sum has Sum's depth. Source contract,
   --  depth pairs, geometry, Region, Int32 overflow and publication rules
   --  are those of Integral_Sum_And_Squares; the tilted scratch indexing
   --  adds its own native int bound on the channel-expanded width.
   --  @param Source Nonempty 2-D UInt8, Float32 or Float64 image to
   --  integrate.
   --  @param Sum_Depth Depth of the Sum and Tilted_Sum components; defaults
   --  to Float64_Integral.
   --  @param Squared_Depth Depth of the Squared_Sum component; defaults to
   --  Float64_Squared_Integral.
   --  @return Record holding the fresh Sum, Squared_Sum and Tilted_Sum
   --  Mats.
   --  @exception OpenCV_Error Raised for an invalid Source, an
   --  unsupported depth pair, an Int32 total overflow, a native int
   --  arithmetic limit, or a native failure.
   function Integral_Images
     (Source        : OpenCV.Core.Mat;
      Sum_Depth     : Integral_Sum_Depth := Float64_Integral;
      Squared_Depth : Integral_Squared_Depth := Float64_Squared_Integral)
      return Integral_Images_Result;

   --  Metric and propagation mask of Distance_Transform. Distances are in
   --  pixels, from each pixel to the nearest zero pixel.
   --  @enum Manhattan_Distance Exact L1 distance `|dx| + |dy|`.
   --  @enum Chessboard_Distance Exact chessboard distance
   --  `max (|dx|, |dy|)`.
   --  @enum Euclidean_3x3 Fast approximation with OpenCV's 3x3 weights
   --  (axis step about 0.955, diagonal step about 1.3693).
   --  @enum Euclidean_5x5 Approximation with OpenCV's 5x5 weights (axis step
   --  1.0), closer to the true distance than Euclidean_3x3.
   --  @enum Euclidean_Precise Exact Euclidean distance up to Float32
   --  rounding. Each Source dimension is limited to 46341 pixels.
   type Distance_Transform_Method is
     (Manhattan_Distance,
      Chessboard_Distance,
      Euclidean_3x3,
      Euclidean_5x5,
      Euclidean_Precise);

   --  Metric of Distance_Transform_With_Labels. OpenCV computes every
   --  labeled transform by 5x5 mask propagation; no precise mode exists.
   --  @enum Manhattan_Label_Distance Exact L1 distance `|dx| + |dy|`.
   --  @enum Euclidean_Label_Distance Euclidean distance approximated with
   --  OpenCV's 5x5 weights.
   --  @enum Chessboard_Label_Distance Exact chessboard distance
   --  `max (|dx|, |dy|)`.
   type Labeled_Distance_Metric is
     (Manhattan_Label_Distance,
      Euclidean_Label_Distance,
      Chessboard_Label_Distance);

   --  How Distance_Transform_With_Labels numbers the zero pixels.
   --  @enum Nearest_Zero_Component Each 8-connected component of zero pixels
   --  receives one positive label.
   --  @enum Nearest_Zero_Pixel Each zero pixel receives its own positive
   --  label, assigned in row-major scan order (a discrete Voronoi map).
   type Distance_Label_Mode is (Nearest_Zero_Component, Nearest_Zero_Pixel);

   --  Result of Distance_Transform_With_Labels: two fresh owning Mats with
   --  the rows and columns of Source.
   --  @field Distances Float32 C1 distance from each pixel to its nearest
   --  zero pixel; zero pixels hold 0.0.
   --  @field Labels Int32 C1 positive label of a nearest zero component or
   --  zero pixel, as selected by Distance_Label_Mode. Zero pixels carry
   --  their own label; equidistant ties have no specified winner.
   type Labeled_Distance_Transform_Result is record
      Distances : OpenCV.Core.Mat;
      Labels    : OpenCV.Core.Mat;
   end record;

   --  Computes the distance from every pixel of Source to the nearest zero
   --  pixel. Source is a nonempty 2-D UInt8 C1 image containing at least one
   --  zero. Zero pixels are targets with distance 0; every nonzero pixel is
   --  foreground (1 and 255 behave alike). Results are fresh,
   --  source-preserving Mats of the same geometry; Regions are independent
   --  logical images whose parent pixels do not participate. L1 and
   --  chessboard distances are exact. Euclidean_3x3 and Euclidean_5x5 use
   --  OpenCV's approximate weights; Euclidean_Precise is exact up to Float32
   --  rounding. The result is Float32 C1.
   --
   --  The shim rejects images whose row stride, pixel count, row offsets or
   --  padded temporary exceed native signed-int arithmetic, so a small
   --  Region of a very large parent can be rejected. Euclidean_Precise also
   --  limits each dimension to 46341 (OpenCV 4.1 table arithmetic).
   --  @param Source Nonempty 2-D UInt8 C1 mask; zero marks the targets.
   --  @param Method Metric and mask; defaults to Euclidean_Precise.
   --  @return Fresh owning Float32 C1 distance Mat with Source's rows and
   --  columns.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D,
   --  not UInt8 C1 or has no zero pixel, when a native size limit is
   --  exceeded, or when OpenCV fails.
   function Distance_Transform
     (Source : OpenCV.Core.Mat;
      Method : Distance_Transform_Method := Euclidean_Precise)
      return OpenCV.Core.Mat;

   --  Exact L1 distance, UInt8 C1, saturating at 255. Each pixel receives
   --  `|dx| + |dy|` to its nearest zero pixel. Source requirements, Region
   --  behavior and native size limits are those of Distance_Transform with
   --  Manhattan_Distance. There is no UInt8 Euclidean variant.
   --  @param Source Nonempty 2-D UInt8 C1 mask containing at least one zero
   --  pixel; zero marks the targets.
   --  @return Fresh owning UInt8 C1 distance Mat with Source's rows and
   --  columns; distances above 255 are stored as 255.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D,
   --  not UInt8 C1 or has no zero pixel, when a native size limit is
   --  exceeded, or when OpenCV fails.
   function Manhattan_Distance_Transform_UInt8
     (Source : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Computes distances to the nearest zero pixel together with the label
   --  of that zero. Source requirements, Region behavior and native size
   --  limits are those of Distance_Transform. Distances are Float32 C1,
   --  Labels Int32 C1. Component mode groups 8-connected zero pixels; pixel
   --  mode assigns row-major positive labels to individual zeros. Ties have
   --  no specified winner. Euclidean labeled distances use the native 5x5
   --  approximation; precise is unavailable.
   --  @param Source Nonempty 2-D UInt8 C1 mask containing at least one zero
   --  pixel; zero marks the labeled targets.
   --  @param Metric Distance metric; defaults to Euclidean_Label_Distance.
   --  @param Labels Labeling of the zero pixels; defaults to
   --  Nearest_Zero_Component.
   --  @return Record whose Distances and Labels are fresh owning Mats with
   --  Source's rows and columns.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D,
   --  not UInt8 C1 or has no zero pixel, when a native size limit is
   --  exceeded, or when OpenCV fails.
   function Distance_Transform_With_Labels
     (Source : OpenCV.Core.Mat;
      Metric : Labeled_Distance_Metric := Euclidean_Label_Distance;
      Labels : Distance_Label_Mode := Nearest_Zero_Component)
      return Labeled_Distance_Transform_Result;

   --  Selects the per-pixel color conversion performed by Convert_Color. Each
   --  name gives the Source layout, then the Destination layout, and each
   --  unpacked layout stores its channels in the order its name spells: BGR is
   --  B, G, R; BGRA is B, G, R, alpha; XYZ is X, Y, Z; YCrCb is Y, Cr, Cb; YUV
   --  is Y, U, V; HSV is H, S, V; HLS is H, L, S; Lab is L, a, b; Luv is L, u,
   --  v. OpenCV's default order is BGR, not RGB. Gray is C1, BGR565 and BGR555
   --  are packed C2, BGRA and RGBA are C4, and every other layout is C3.
   --  Destination keeps Source rows, columns and depth.
   --
   --  Source depths: layout, Gray, XYZ, YCrCb and YUV selectors accept UInt8,
   --  UInt16 or Float32; HSV, HLS, Lab and Luv selectors, including the FULL
   --  and linear-light ones, accept UInt8 or Float32; packed BGR565/BGR555 and
   --  premultiplied selectors accept UInt8 only.
   --
   --  Gray is OpenCV's weighted luminance (UInt8 pure blue gives 29, pure
   --  red 76). Appended alpha is the depth maximum: 255 (UInt8), 65535
   --  (UInt16) or 1.0 (Float32). Removing alpha discards it; BGRA/RGBA swaps
   --  keep it. YUV here is per-pixel C3 YUV, not a subsampled frame; see
   --  Decode_YUV420 and Decode_YUV422. Standard (non-FULL) UInt8 HSV/HLS hue
   --  is degrees / 2 (red 0, green 60, blue 120) and S, V and L use 0..255;
   --  Float32 hue is degrees. Ordinary Lab/Luv selectors apply sRGB transfer
   --  decoding (forward) and encoding (reverse). Float32 BGR/RGB is
   --  normally 0..1: normalize it before Float32 Lab/Luv. Lab/Luv lightness
   --  is 0..100 for Float32 and encoded as 0..255 for UInt8. No pixel value is
   --  range-checked or sanitized.
   --
   --  Packed conversions require UInt8. BGR565/BGR555 use UInt8 C2, OpenCV's
   --  native Mat representation: two bytes per native 16-bit word. Byte order
   --  is host-native, not a network/file-format byte order. BGR565 holds blue
   --  in bits 0..4, green in 5..10 and red in 11..15; BGR555 holds blue
   --  in 0..4, green in 5..9, red in 10..14 and an alpha flag in bit 15.
   --  RGB/RGBA selectors interpret channel order, not a new packed layout.
   --  Packing truncates; unpacking does not replicate low color bits, so
   --  unpacked blue and red reach at most 248 and green 252 (BGR565) or 248
   --  (BGR555). BGR565 ignores input alpha and expands alpha to 255. BGR555
   --  uses bit 15 as nonzero-alpha flag; C3 and Gray packing leave it zero.
   --
   --  FULL HSV/HLS and linear-light Lab/Luv require UInt8/Float32 C3. UInt8
   --  FULL hue has full-byte encoding (0..255 for the whole circle); native
   --  forward scale is 256, reverse scale 255, so exact round trips are not
   --  promised. Float32 standard/FULL hue remains degrees and both paths are
   --  equivalent in reviewed OpenCV 4.1/4.10/5.0 implementations. Linear
   --  Lab/Luv omits sRGB transfer encoding/decoding, unlike ordinary Lab/Luv
   --  selectors. Float32 RGB is normally 0..1; no pixel sanitizer or manual
   --  Lab/Luv rescaling is applied. Native UInt8 encoding is retained.
   --  Premultiplied selectors require UInt8 C4 in named RGBA order, preserve
   --  alpha, and multiply color by alpha/255. Reverse saturates even for
   --  noncanonical color > alpha; zero alpha yields zero color. Quantization
   --  makes the inverse lossy, especially at low alpha.
   --  @enum BGR_To_Gray BGR C3 to Gray C1 luminance; UInt8/UInt16/Float32.
   --  @enum RGB_To_Gray RGB C3 to Gray C1 luminance; UInt8/UInt16/Float32.
   --  @enum BGRA_To_Gray BGRA C4 to Gray C1 luminance, discarding alpha;
   --  UInt8/UInt16/Float32.
   --  @enum RGBA_To_Gray RGBA C4 to Gray C1 luminance, discarding alpha;
   --  UInt8/UInt16/Float32.
   --  @enum Gray_To_BGR Gray C1 to BGR C3, Gray copied into B, G and R;
   --  UInt8/UInt16/Float32.
   --  @enum Gray_To_RGB Gray C1 to RGB C3, Gray copied into R, G and B;
   --  UInt8/UInt16/Float32.
   --  @enum Gray_To_BGRA Gray C1 to BGRA C4, Gray copied into B, G and R,
   --  maximum alpha; UInt8/UInt16/Float32.
   --  @enum Gray_To_RGBA Gray C1 to RGBA C4, Gray copied into R, G and B,
   --  maximum alpha; UInt8/UInt16/Float32.
   --  @enum BGR_To_RGB BGR C3 to RGB C3, exchanging B and R;
   --  UInt8/UInt16/Float32.
   --  @enum RGB_To_BGR RGB C3 to BGR C3, exchanging R and B;
   --  UInt8/UInt16/Float32.
   --  @enum BGR_To_BGRA BGR C3 to BGRA C4, appending maximum alpha;
   --  UInt8/UInt16/Float32.
   --  @enum RGB_To_RGBA RGB C3 to RGBA C4, appending maximum alpha;
   --  UInt8/UInt16/Float32.
   --  @enum BGR_To_RGBA BGR C3 to RGBA C4, exchanging B and R and appending
   --  maximum alpha; UInt8/UInt16/Float32.
   --  @enum RGB_To_BGRA RGB C3 to BGRA C4, exchanging R and B and appending
   --  maximum alpha; UInt8/UInt16/Float32.
   --  @enum BGRA_To_BGR BGRA C4 to BGR C3, discarding alpha;
   --  UInt8/UInt16/Float32.
   --  @enum RGBA_To_RGB RGBA C4 to RGB C3, discarding alpha;
   --  UInt8/UInt16/Float32.
   --  @enum RGBA_To_BGR RGBA C4 to BGR C3, exchanging R and B and discarding
   --  alpha; UInt8/UInt16/Float32.
   --  @enum BGRA_To_RGB BGRA C4 to RGB C3, exchanging B and R and discarding
   --  alpha; UInt8/UInt16/Float32.
   --  @enum BGRA_To_RGBA BGRA C4 to RGBA C4, exchanging B and R and keeping
   --  alpha; UInt8/UInt16/Float32.
   --  @enum RGBA_To_BGRA RGBA C4 to BGRA C4, exchanging R and B and keeping
   --  alpha; UInt8/UInt16/Float32.
   --  @enum BGR_To_XYZ BGR C3 to XYZ C3; UInt8/UInt16/Float32.
   --  @enum RGB_To_XYZ RGB C3 to XYZ C3; UInt8/UInt16/Float32.
   --  @enum XYZ_To_BGR XYZ C3 to BGR C3; UInt8/UInt16/Float32.
   --  @enum XYZ_To_RGB XYZ C3 to RGB C3; UInt8/UInt16/Float32.
   --  @enum BGR_To_YCrCb BGR C3 to YCrCb C3; UInt8/UInt16/Float32.
   --  @enum RGB_To_YCrCb RGB C3 to YCrCb C3; UInt8/UInt16/Float32.
   --  @enum YCrCb_To_BGR YCrCb C3 to BGR C3; UInt8/UInt16/Float32.
   --  @enum YCrCb_To_RGB YCrCb C3 to RGB C3; UInt8/UInt16/Float32.
   --  @enum BGR_To_YUV BGR C3 to per-pixel YUV C3; UInt8/UInt16/Float32.
   --  @enum RGB_To_YUV RGB C3 to per-pixel YUV C3; UInt8/UInt16/Float32.
   --  @enum YUV_To_BGR Per-pixel YUV C3 to BGR C3; UInt8/UInt16/Float32.
   --  @enum YUV_To_RGB Per-pixel YUV C3 to RGB C3; UInt8/UInt16/Float32.
   --  @enum BGR_To_HSV BGR C3 to HSV C3 with standard hue encoding;
   --  UInt8/Float32.
   --  @enum RGB_To_HSV RGB C3 to HSV C3 with standard hue encoding;
   --  UInt8/Float32.
   --  @enum HSV_To_BGR HSV C3 with standard hue encoding to BGR C3;
   --  UInt8/Float32.
   --  @enum HSV_To_RGB HSV C3 with standard hue encoding to RGB C3;
   --  UInt8/Float32.
   --  @enum BGR_To_HLS BGR C3 to HLS C3 with standard hue encoding;
   --  UInt8/Float32.
   --  @enum RGB_To_HLS RGB C3 to HLS C3 with standard hue encoding;
   --  UInt8/Float32.
   --  @enum HLS_To_BGR HLS C3 with standard hue encoding to BGR C3;
   --  UInt8/Float32.
   --  @enum HLS_To_RGB HLS C3 with standard hue encoding to RGB C3;
   --  UInt8/Float32.
   --  @enum BGR_To_Lab sRGB-encoded BGR C3 to Lab C3; UInt8/Float32.
   --  @enum RGB_To_Lab sRGB-encoded RGB C3 to Lab C3; UInt8/Float32.
   --  @enum Lab_To_BGR Lab C3 to sRGB-encoded BGR C3; UInt8/Float32.
   --  @enum Lab_To_RGB Lab C3 to sRGB-encoded RGB C3; UInt8/Float32.
   --  @enum BGR_To_Luv sRGB-encoded BGR C3 to Luv C3; UInt8/Float32.
   --  @enum RGB_To_Luv sRGB-encoded RGB C3 to Luv C3; UInt8/Float32.
   --  @enum Luv_To_BGR Luv C3 to sRGB-encoded BGR C3; UInt8/Float32.
   --  @enum Luv_To_RGB Luv C3 to sRGB-encoded RGB C3; UInt8/Float32.
   --  @enum BGR_To_BGR565 BGR C3 to packed BGR565 C2; UInt8 only.
   --  @enum RGB_To_BGR565 RGB C3 to the same packed BGR565 C2 layout; UInt8
   --  only.
   --  @enum BGRA_To_BGR565 BGRA C4 to packed BGR565 C2, ignoring alpha; UInt8
   --  only.
   --  @enum RGBA_To_BGR565 RGBA C4 to packed BGR565 C2, ignoring alpha; UInt8
   --  only.
   --  @enum BGR565_To_BGR Packed BGR565 C2 to BGR C3; UInt8 only.
   --  @enum BGR565_To_RGB Packed BGR565 C2 to RGB C3; UInt8 only.
   --  @enum BGR565_To_BGRA Packed BGR565 C2 to BGRA C4 with alpha 255; UInt8
   --  only.
   --  @enum BGR565_To_RGBA Packed BGR565 C2 to RGBA C4 with alpha 255; UInt8
   --  only.
   --  @enum Gray_To_BGR565 Gray C1 to packed BGR565 C2, quantizing Gray into
   --  each color field; UInt8 only.
   --  @enum BGR565_To_Gray Packed BGR565 C2 to Gray C1, the native integer
   --  luminance of the unpacked colors (Gray 255 round-trips to 250); UInt8
   --  only.
   --  @enum BGR_To_BGR555 BGR C3 to packed BGR555 C2 with bit 15 clear; UInt8
   --  only.
   --  @enum RGB_To_BGR555 RGB C3 to the same packed BGR555 C2 layout with
   --  bit 15 clear; UInt8 only.
   --  @enum BGRA_To_BGR555 BGRA C4 to packed BGR555 C2, setting bit 15 when
   --  alpha is nonzero; UInt8 only.
   --  @enum RGBA_To_BGR555 RGBA C4 to packed BGR555 C2, setting bit 15 when
   --  alpha is nonzero; UInt8 only.
   --  @enum BGR555_To_BGR Packed BGR555 C2 to BGR C3, dropping bit 15; UInt8
   --  only.
   --  @enum BGR555_To_RGB Packed BGR555 C2 to RGB C3, dropping bit 15; UInt8
   --  only.
   --  @enum BGR555_To_BGRA Packed BGR555 C2 to BGRA C4, alpha 255 when bit 15
   --  is set and 0 otherwise; UInt8 only.
   --  @enum BGR555_To_RGBA Packed BGR555 C2 to RGBA C4, alpha 255 when bit 15
   --  is set and 0 otherwise; UInt8 only.
   --  @enum Gray_To_BGR555 Gray C1 to packed BGR555 C2, quantizing Gray into
   --  each color field, bit 15 clear; UInt8 only.
   --  @enum BGR555_To_Gray Packed BGR555 C2 to Gray C1, the native integer
   --  luminance of the unpacked colors, ignoring bit 15 (Gray 255 round-trips
   --  to 248); UInt8 only.
   --  @enum BGR_To_HSV_Full BGR C3 to HSV C3 with FULL hue encoding;
   --  UInt8/Float32.
   --  @enum RGB_To_HSV_Full RGB C3 to HSV C3 with FULL hue encoding;
   --  UInt8/Float32.
   --  @enum HSV_Full_To_BGR HSV C3 with FULL hue encoding to BGR C3;
   --  UInt8/Float32.
   --  @enum HSV_Full_To_RGB HSV C3 with FULL hue encoding to RGB C3;
   --  UInt8/Float32.
   --  @enum BGR_To_HLS_Full BGR C3 to HLS C3 with FULL hue encoding;
   --  UInt8/Float32.
   --  @enum RGB_To_HLS_Full RGB C3 to HLS C3 with FULL hue encoding;
   --  UInt8/Float32.
   --  @enum HLS_Full_To_BGR HLS C3 with FULL hue encoding to BGR C3;
   --  UInt8/Float32.
   --  @enum HLS_Full_To_RGB HLS C3 with FULL hue encoding to RGB C3;
   --  UInt8/Float32.
   --  @enum Linear_BGR_To_Lab Linear-light BGR C3 to Lab C3, without sRGB
   --  decoding; UInt8/Float32.
   --  @enum Linear_RGB_To_Lab Linear-light RGB C3 to Lab C3, without sRGB
   --  decoding; UInt8/Float32.
   --  @enum Lab_To_Linear_BGR Lab C3 to linear-light BGR C3, without sRGB
   --  encoding; UInt8/Float32.
   --  @enum Lab_To_Linear_RGB Lab C3 to linear-light RGB C3, without sRGB
   --  encoding; UInt8/Float32.
   --  @enum Linear_BGR_To_Luv Linear-light BGR C3 to Luv C3, without sRGB
   --  decoding; UInt8/Float32.
   --  @enum Linear_RGB_To_Luv Linear-light RGB C3 to Luv C3, without sRGB
   --  decoding; UInt8/Float32.
   --  @enum Luv_To_Linear_BGR Luv C3 to linear-light BGR C3, without sRGB
   --  encoding; UInt8/Float32.
   --  @enum Luv_To_Linear_RGB Luv C3 to linear-light RGB C3, without sRGB
   --  encoding; UInt8/Float32.
   --  @enum RGBA_To_Premultiplied_RGBA RGBA C4 to premultiplied RGBA C4; each
   --  of R, G and B becomes `(C * A + 128) / 255` (native scalar integer form)
   --  and alpha A is kept; UInt8 only.
   --  @enum Premultiplied_RGBA_To_RGBA Premultiplied RGBA C4 to RGBA C4; each
   --  of R, G and B becomes the saturated integer `(C * 255 + A / 2) / A`,
   --  or 0 when A is 0, and alpha A is kept; UInt8 only.
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
      Luv_To_RGB,
      BGR_To_BGR565,
      RGB_To_BGR565,
      BGRA_To_BGR565,
      RGBA_To_BGR565,
      BGR565_To_BGR,
      BGR565_To_RGB,
      BGR565_To_BGRA,
      BGR565_To_RGBA,
      Gray_To_BGR565,
      BGR565_To_Gray,
      BGR_To_BGR555,
      RGB_To_BGR555,
      BGRA_To_BGR555,
      RGBA_To_BGR555,
      BGR555_To_BGR,
      BGR555_To_RGB,
      BGR555_To_BGRA,
      BGR555_To_RGBA,
      Gray_To_BGR555,
      BGR555_To_Gray,
      BGR_To_HSV_Full,
      RGB_To_HSV_Full,
      HSV_Full_To_BGR,
      HSV_Full_To_RGB,
      BGR_To_HLS_Full,
      RGB_To_HLS_Full,
      HLS_Full_To_BGR,
      HLS_Full_To_RGB,
      Linear_BGR_To_Lab,
      Linear_RGB_To_Lab,
      Lab_To_Linear_BGR,
      Lab_To_Linear_RGB,
      Linear_BGR_To_Luv,
      Linear_RGB_To_Luv,
      Luv_To_Linear_BGR,
      Luv_To_Linear_RGB,
      RGBA_To_Premultiplied_RGBA,
      Premultiplied_RGBA_To_RGBA);

   --  Resampling interpolation, passed to OpenCV as the native INTER_* flag
   --  named below. Each operation accepts a subset and rejects the rest
   --  with OpenCV_Error: Resize accepts all six (Linear_Exact only for
   --  UInt8, UInt16 and Int16 sources); Warp_Affine and Warp_Perspective
   --  accept Nearest_Neighbor and Linear; Warp_Polar and every Remap
   --  overload accept Nearest_Neighbor, Linear, Cubic and Lanczos_4.
   --  @enum Nearest_Neighbor Nearest-neighbor sampling (INTER_NEAREST).
   --  @enum Linear Bilinear interpolation (INTER_LINEAR); the default of
   --  every operation taking this type.
   --  @enum Cubic Bicubic interpolation (INTER_CUBIC).
   --  @enum Area Pixel-area resampling (INTER_AREA); Resize only.
   --  @enum Lanczos_4 Lanczos interpolation (INTER_LANCZOS4).
   --  @enum Linear_Exact Native fixed-point bilinear interpolation with
   --  deterministic integer rounding (INTER_LINEAR_EXACT); Resize only,
   --  for UInt8, UInt16 and Int16 sources.
   type Interpolation_Method is
     (Nearest_Neighbor, Linear, Cubic, Area, Lanczos_4, Linear_Exact);

   --  Radial scale of a Warp_Polar polar image, whose X coordinate is the
   --  radius rho.
   --  @enum Linear_Polar Rho is proportional to the distance from Center
   --  (native WARP_POLAR_LINEAR).
   --  @enum Logarithmic_Polar Rho follows `log(distance + 1)` (native
   --  WARP_POLAR_LOG); requires Maximum_Radius > 1.
   type Polar_Mapping is (Linear_Polar, Logarithmic_Polar);

   --  Direction of a Warp_Polar transform.
   --  @enum Cartesian_To_Polar Forward transform: Source is a Cartesian
   --  image and Destination the polar image (X = rho, Y = angle).
   --  @enum Polar_To_Cartesian Inverse transform (native
   --  WARP_INVERSE_MAP): Source is a polar image and Destination its
   --  Cartesian reconstruction.
   type Polar_Direction is (Cartesian_To_Polar, Polar_To_Cartesian);

   --  Sobel aperture Canny_Edges uses to compute the image gradient.
   --  @enum Sobel_3x3 Three-by-three Sobel aperture (the default).
   --  @enum Sobel_5x5 Five-by-five Sobel aperture.
   --  @enum Sobel_7x7 Seven-by-seven Sobel aperture.
   type Canny_Aperture is (Sobel_3x3, Sobel_5x5, Sobel_7x7);

   --  Norm Canny_Edges uses for the gradient magnitude it thresholds.
   --  @enum L1_Norm Sum of the absolute X and Y derivatives (the default).
   --  @enum L2_Norm Euclidean magnitude: square root of the sum of the
   --  squared X and Y derivatives.
   type Canny_Gradient_Norm is (L1_Norm, L2_Norm);

   --  Aperture of the Sobel-family derivative kernels used by Sobel and
   --  Get_Derivative_Kernels. A derivative order along an axis must be
   --  less than the effective kernel length on that axis.
   --  @enum Kernel_1 OpenCV's special case without smoothing: an axis with
   --  nonzero order (up to 2) uses an effective 3-tap derivative kernel,
   --  such as `[-1, 0, 1]`, and an axis with order zero a 1-tap identity.
   --  @enum Kernel_3 Three-tap kernels on both axes (orders up to 2).
   --  @enum Kernel_5 Five-tap kernels on both axes (orders up to 4).
   --  @enum Kernel_7 Seven-tap kernels on both axes (orders up to 6).
   type Sobel_Kernel_Size is (Kernel_1, Kernel_3, Kernel_5, Kernel_7);

   --  Sobel derivative aperture of the corner response maps, passed to
   --  OpenCV as aperture size 3, 5 or 7. Pre-corner detection needs second
   --  derivatives, so the Sobel Kernel_1 selector is not applicable.
   --  @enum Aperture_3 3x3 Sobel aperture, the default of every corner map.
   --  @enum Aperture_5 5x5 Sobel aperture.
   --  @enum Aperture_7 7x7 Sobel aperture.
   type Corner_Aperture is (Aperture_3, Aperture_5, Aperture_7);

   --  Side length, in pixels, of the square neighborhood over which the
   --  corner maps accumulate the derivative covariance (native box filter
   --  size). The subtype admits 1, but every operation taking it requires
   --  at least 2 and raises OpenCV_Error for 1.
   subtype Corner_Block_Size is Positive range 1 .. 2_147_483_647;

   --  Float32 corner positions for Refine_Corners_Subpixel, in pixels
   --  (X = column, Y = row). Any Integer index range is allowed; refined
   --  results keep the bounds of the input array.
   type Corner_Point_Array is array (Integer range <>) of OpenCV.Float32_Point;

   --  Maximum number of Refine_Corners_Subpixel iterations, 1 through 100.
   subtype Corner_Iteration_Limit is Positive range 1 .. 100;

   --  Termination criteria of Refine_Corners_Subpixel. Both criteria are
   --  always passed to native cornerSubPix (MAX_ITER and EPS), so
   --  refinement stops at Maximum_Iterations or earlier once the native
   --  Epsilon accuracy criterion is met.
   --  @field Maximum_Iterations Iteration limit; default 30.
   --  @field Epsilon Native EPS accuracy threshold; default 0.01.
   --  Refine_Corners_Subpixel requires it finite and nonnegative.
   type Corner_Termination is record
      Maximum_Iterations : Corner_Iteration_Limit := 30;
      Epsilon            : OpenCV.Float64_Value := 0.01;
   end record;

   --  Optional central dead zone of the Refine_Corners_Subpixel search
   --  window, given as a half-size and passed to native cornerSubPix as its
   --  zeroZone. When disabled (the default) the native no-zone value
   --  (-1, -1) is passed.
   --  @field Enabled Discriminant selecting whether a dead zone is used;
   --  default False.
   --  @field Half_Size Exists only when Enabled is True: dead-zone half
   --  width and half height in pixels. Each must be smaller than the
   --  matching Search_Window half-size; (0, 0) is accepted.
   type Corner_Dead_Zone (Enabled : Boolean := False) is record
      case Enabled is
         when False =>
            null;

         when True =>
            Half_Size : OpenCV.Size;
      end case;
   end record;

   --  Minimum-eigenvalue corner response map (native cv::cornerMinEigenVal):
   --  per pixel, the smaller eigenvalue of the covariance matrix of Sobel
   --  derivatives accumulated over a Block_Size by Block_Size neighborhood.
   --  Source must be a nonempty 2-D UInt8 or Float32 C1 Mat. It is copied
   --  into a packed private snapshot before native execution, so Source is
   --  unchanged and a Region is an independent image whose borders never
   --  read parent pixels. Native signed-int layout limits on the Source
   --  size and Block_Size raise OpenCV_Error.
   --  @param Source Image to analyse.
   --  @param Block_Size Covariance neighborhood side length; at least 2.
   --  Default 3.
   --  @param Aperture Sobel derivative aperture; default Aperture_3.
   --  @param Border Constant_Border, Replicate, Reflect or Reflect_101
   --  (the default); Wrap is rejected.
   --  @return Fresh owning Float32 C1 Mat with Source's rows and columns.
   --  @exception OpenCV_Error Unsupported Source type or layout,
   --  Block_Size 1, Wrap border, native size limits, or an OpenCV failure.
   function Corner_Minimum_Eigenvalue
     (Source     : OpenCV.Core.Mat;
      Block_Size : Corner_Block_Size := 3;
      Aperture   : Corner_Aperture := Aperture_3;
      Border     : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;

   --  Harris corner response map (native cv::cornerHarris), computed from
   --  the Block_Size covariance of Sobel derivatives with Harris free
   --  parameter K. Source requirements, snapshot and Region isolation,
   --  border support and native limits are those of
   --  Corner_Minimum_Eigenvalue.
   --  @param Source Nonempty 2-D UInt8 or Float32 C1 image to analyse.
   --  @param Block_Size Covariance neighborhood side length; at least 2.
   --  Default 3.
   --  @param Aperture Sobel derivative aperture; default Aperture_3.
   --  @param K Harris detector free parameter; must be finite. Default
   --  0.04.
   --  @param Border Constant_Border, Replicate, Reflect or Reflect_101
   --  (the default); Wrap is rejected.
   --  @return Fresh owning Float32 C1 Mat with Source's rows and columns.
   --  @exception OpenCV_Error Unsupported Source type or layout,
   --  Block_Size 1, nonfinite K, Wrap border, native size limits, or an
   --  OpenCV failure.
   function Harris_Corner_Response
     (Source     : OpenCV.Core.Mat;
      Block_Size : Corner_Block_Size := 3;
      Aperture   : Corner_Aperture := Aperture_3;
      K          : OpenCV.Float64_Value := 0.04;
      Border     : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;

   --  Per-pixel eigenvalues and eigenvectors of the Block_Size covariance
   --  matrix of Sobel derivatives (native cv::cornerEigenValsAndVecs).
   --  Six channels per pixel: (lambda1, lambda2, x1, y1, x2, y2).
   --  Source requirements, snapshot and Region isolation, border support
   --  and native limits are those of Corner_Minimum_Eigenvalue.
   --  @param Source Nonempty 2-D UInt8 or Float32 C1 image to analyse.
   --  @param Block_Size Covariance neighborhood side length; at least 2.
   --  Default 3.
   --  @param Aperture Sobel derivative aperture; default Aperture_3.
   --  @param Border Constant_Border, Replicate, Reflect or Reflect_101
   --  (the default); Wrap is rejected.
   --  @return Fresh owning Float32 C6 Mat with Source's rows and columns,
   --  channels in the OpenCV order above.
   --  @exception OpenCV_Error Unsupported Source type or layout,
   --  Block_Size 1, Wrap border, native size limits, or an OpenCV failure.
   function Corner_Eigenvalues_And_Vectors
     (Source     : OpenCV.Core.Mat;
      Block_Size : Corner_Block_Size := 3;
      Aperture   : Corner_Aperture := Aperture_3;
      Border     : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;

   --  Pre-corner feature response map (native cv::preCornerDetect), built
   --  from Sobel derivatives up to second order; it has no block size and
   --  is zero on flat image areas. Source requirements, snapshot and
   --  Region isolation, border support and native limits are those of
   --  Corner_Minimum_Eigenvalue.
   --  @param Source Nonempty 2-D UInt8 or Float32 C1 image to analyse.
   --  @param Aperture Sobel derivative aperture; default Aperture_3.
   --  @param Border Constant_Border, Replicate, Reflect or Reflect_101
   --  (the default); Wrap is rejected.
   --  @return Fresh owning Float32 C1 Mat with Source's rows and columns.
   --  @exception OpenCV_Error Unsupported Source type or layout,
   --  Wrap border, native size limits, or an OpenCV failure.
   function Pre_Corner_Response
     (Source   : OpenCV.Core.Mat;
      Aperture : Corner_Aperture := Aperture_3;
      Border   : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat;

   --  Refines approximate corner positions to subpixel accuracy with native
   --  cv::cornerSubPix and returns the refined points in a new array with
   --  the bounds of Corners; Corners is never modified.
   --
   --  Source must be a nonempty 2-D UInt8 or Float32 C1 Mat. Every sample
   --  of a Float32 Source must be finite: the whole logical image is
   --  scanned, even when Corners is empty; UInt8 sources need no scan.
   --  Source is copied into a packed private snapshot, so it is unchanged
   --  even on failure and Region neighborhoods never see parent pixels.
   --  Every initial point must be finite with `0 <= X < Columns` and
   --  `0 <= Y < Rows`. An empty Corners returns an empty array with the
   --  same bounds after the source, window, dead-zone and termination
   --  checks. Native signed-int limits on Source size and window scratch
   --  raise OpenCV_Error. If the native covariance degenerates, OpenCV 4.1
   --  can return a NaN point where 4.10 and 5.0 keep the previous finite
   --  estimate.
   --  @param Source Image containing the corners.
   --  @param Corners Initial estimates; any Integer bounds and at most
   --  `2**31 - 1` points.
   --  @param Search_Window Search half-size: Width columns and Height rows,
   --  both positive. The native search window spans `2 * Width + 1` by
   --  `2 * Height + 1` pixels, and Source must have at least
   --  `2 * Width + 5` columns and `2 * Height + 5` rows.
   --  @param Dead_Zone Optional central dead zone, disabled by default;
   --  enabled half-sizes must be smaller than those of Search_Window.
   --  @param Termination Iteration limit and Epsilon (finite and
   --  nonnegative); default 30 iterations and 0.01.
   --  @return Refined Float32 points, index for index, with the bounds of
   --  Corners.
   --  @exception OpenCV_Error Invalid Source, nonfinite Float32
   --  sample, invalid Search_Window, Dead_Zone, Epsilon or initial point,
   --  native layout limits, or an OpenCV failure.
   function Refine_Corners_Subpixel
     (Source        : OpenCV.Core.Mat;
      Corners       : Corner_Point_Array;
      Search_Window : OpenCV.Size;
      Dead_Zone     : Corner_Dead_Zone := (Enabled => False);
      Termination   : Corner_Termination :=
        (Maximum_Iterations => 30, Epsilon => 0.01)) return Corner_Point_Array;

   --  Aperture size of Laplacian, in pixels. Laplacian accepts only odd
   --  values: 1 selects OpenCV's dedicated 3 x 3 Laplacian aperture and
   --  3 through 31 select that aperture size.
   type Laplacian_Kernel_Size is range 1 .. 31;

   --  Side length, in pixels, of Median_Blur's square aperture. The subtype
   --  excludes values below 3; Median_Blur also requires an odd value.
   subtype Median_Kernel_Size is Positive range 3 .. 2_147_483_647;

   --  Explicit neighborhood diameter, in pixels, for Bilateral_Filter. The
   --  subtype excludes OpenCV's zero or negative automatic-diameter
   --  sentinel; any positive value, odd or even, is accepted.
   subtype Bilateral_Diameter is Positive range 1 .. 2_147_483_647;

   --  Number of coefficients of a Get_Gaussian_Kernel vector. The generator
   --  requires an odd value; with automatic sigma, 1 yields the single
   --  coefficient 1.0.
   subtype Gaussian_Kernel_Size is Positive range 1 .. 2_147_483_647;

   --  Element depth of the single-channel coefficient Mats returned by the
   --  kernel generators Get_Gaussian_Kernel, Get_Derivative_Kernels,
   --  Get_Scharr_Kernels and Get_Gabor_Kernel.
   --  @enum Float32_Kernel Coefficients are stored as Float32 C1.
   --  @enum Float64_Kernel Coefficients are stored as Float64 C1.
   type Gaussian_Kernel_Depth is (Float32_Kernel, Float64_Kernel);

   --  Coefficient depth of Get_Derivative_Kernels and Get_Scharr_Kernels,
   --  with the Gaussian_Kernel_Depth literals.
   subtype Derivative_Kernel_Depth is Gaussian_Kernel_Depth;

   --  Coefficient depth of Get_Gabor_Kernel, with the Gaussian_Kernel_Depth
   --  literals.
   subtype Gabor_Kernel_Depth is Gaussian_Kernel_Depth;

   --  Coefficient scaling of Get_Derivative_Kernels and Get_Scharr_Kernels.
   --  It never changes the derivative order or the vector lengths.
   --  @enum Unnormalized OpenCV's integer coefficients, such as `[-1, 0, 1]`
   --  with `[1, 2, 1]` for a first-order 3-tap Sobel pair.
   --  @enum Normalized OpenCV's normalized scaling, such as `[-0.5, 0, 0.5]`
   --  with `[0.25, 0.5, 0.25]` for that pair; for Scharr only the smoothing
   --  vector is scaled.
   type Derivative_Kernel_Normalization is (Unnormalized, Normalized);

   --  Separable coefficient pair returned by Get_Derivative_Kernels and
   --  Get_Scharr_Kernels, ready for Sep_Filter_2D. Each component is an
   --  independently owned N x 1 single-channel column vector; both have the
   --  requested depth, and their lengths may differ (Kernel_1).
   --  @field Kernel_X Coefficients applied along X, that is within each
   --  row (Sep_Filter_2D's Kernel_X).
   --  @field Kernel_Y Coefficients applied along Y, that is within each
   --  column (Sep_Filter_2D's Kernel_Y).
   type Derivative_Kernels is record
      Kernel_X : OpenCV.Core.Mat;
      Kernel_Y : OpenCV.Core.Mat;
   end record;

   --  Order of a spatial derivative along one axis; 0 means no derivative
   --  on that axis. Sobel and Get_Derivative_Kernels also require at least
   --  one nonzero order and each order below the effective kernel length.
   subtype Derivative_Order is Natural range 0 .. 7;

   --  Axis of the first derivative computed by Scharr and
   --  Get_Scharr_Kernels.
   --  @enum X_Axis Horizontal derivative: X order 1, Y order 0.
   --  @enum Y_Axis Vertical derivative: X order 0, Y order 1.
   type Derivative_Axis is (X_Axis, Y_Axis);

   --  Destination depth of Sobel, Scharr and Laplacian, and through
   --  Filter_Depth of Filter_2D and Sep_Filter_2D. Supported per Source
   --  depth: UInt8 accepts every literal; UInt16 and Int16 accept
   --  Same_Depth, Float32_Depth and Float64_Depth; Float32 accepts
   --  Same_Depth or Float32_Depth; Float64 accepts Same_Depth or
   --  Float64_Depth. Other combinations raise OpenCV.OpenCV_Error.
   --  @enum Same_Depth Destination keeps Source's depth.
   --  @enum Int16_Depth Destination is Int16 (UInt8 Sources only).
   --  @enum Float32_Depth Destination is Float32.
   --  @enum Float64_Depth Destination is Float64.
   type Derivative_Depth is
     (Same_Depth, Int16_Depth, Float32_Depth, Float64_Depth);

   --  Destination depth of Filter_2D and Sep_Filter_2D, with the literals
   --  and supported Source combinations of Derivative_Depth.
   subtype Filter_Depth is Derivative_Depth;

   --  Per-sample rule of Apply_Threshold and Apply_Automatic_Threshold for a
   --  Source sample S, threshold T and maximum value M. The comparison is
   --  strict: a sample equal to T counts as not above it.
   --  @enum Binary M where S > T, otherwise 0.
   --  @enum Binary_Inverse 0 where S > T, otherwise M.
   --  @enum Truncate T where S > T, otherwise S unchanged.
   --  @enum To_Zero S unchanged where S > T, otherwise 0.
   --  @enum To_Zero_Inverse 0 where S > T, otherwise S unchanged.
   type Threshold_Mode is
     (Binary, Binary_Inverse, Truncate, To_Zero, To_Zero_Inverse);

   --  Algorithm Apply_Automatic_Threshold uses to select the threshold from
   --  a single-channel Source.
   --  @enum Otsu Otsu's method; accepts UInt8 and UInt16 Sources. OpenCV
   --  before 4.4 rejects UInt16 with OpenCV_Error.
   --  @enum Triangle Triangle method; accepts UInt8 Sources only.
   type Automatic_Threshold_Method is (Otsu, Triangle);

   --  Local mean that Apply_Adaptive_Threshold computes over the
   --  Block_Size by Block_Size neighborhood of each pixel.
   --  @enum Mean Arithmetic mean of the neighborhood.
   --  @enum Gaussian Gaussian-weighted mean of the neighborhood.
   type Adaptive_Threshold_Method is (Mean, Gaussian);

   --  Output rule of Apply_Adaptive_Threshold for a pixel compared with its
   --  local threshold (local mean minus Bias), with maximum value M.
   --  @enum Binary M for pixels above the local threshold, otherwise 0.
   --  @enum Binary_Inverse 0 for pixels above the local threshold,
   --  otherwise M.
   type Adaptive_Threshold_Mode is (Binary, Binary_Inverse);

   --  Side length, in pixels, of the square neighborhood used by
   --  Apply_Adaptive_Threshold. The subtype admits values from 3; the value
   --  must also be odd, and an even value raises OpenCV.OpenCV_Error.
   subtype Adaptive_Block_Size is Positive range 3 .. 2_147_483_647;

   --  The boundary points of one shape, as a subtype of the shared point
   --  array. Any OpenCV.Point_Array, with any Natural bounds, is a Contour,
   --  and an extracted Contour can be passed directly to Draw_Polyline or
   --  Fill_Polygon. Get_Contour returns zero-based arrays; a contour without
   --  points has the null range 1 .. 0.
   subtype Contour is OpenCV.Point_Array;

   --  Which contours Find_Contours retrieves and how their hierarchy entries
   --  are linked. Each literal selects the OpenCV retrieval mode named below.
   --  @enum External_Only Only the extreme outer contours (OpenCV
   --  RETR_EXTERNAL); First_Child and Parent are absent for every contour. The
   --  Find_Contours default.
   --  @enum Flat_List Every contour without hierarchical relationships (OpenCV
   --  RETR_LIST): First_Child and Parent are always absent.
   --  @enum Two_Level Every contour in a two-level hierarchy (OpenCV
   --  RETR_CCOMP): external boundaries of components at the top level and
   --  boundaries of their holes at the second level. A contour inside a hole
   --  is again placed at the top level.
   --  @enum Full_Tree Every contour with the full hierarchy of nested contours
   --  (OpenCV RETR_TREE); for example an outer boundary, a hole inside it and
   --  an island inside the hole form parent, child and grandchild.
   type Contour_Retrieval_Mode is
     (External_Only, Flat_List, Two_Level, Full_Tree);

   --  How Find_Contours stores the points of each boundary. Each literal
   --  selects the OpenCV chain approximation method named below.
   --  @enum Every_Point Every boundary point is kept (OpenCV
   --  CHAIN_APPROX_NONE); consecutive points are horizontal, vertical or
   --  diagonal neighbors. A filled 4 x 4 square yields 12 points.
   --  @enum Simple Horizontal, vertical and diagonal runs are compressed to
   --  their end points (OpenCV CHAIN_APPROX_SIMPLE), so an upright rectangle
   --  yields its four corners. The Find_Contours default.
   --  @enum Teh_Chin_L1 Teh-Chin chain approximation, OpenCV's
   --  CHAIN_APPROX_TC89_L1 flavor.
   --  @enum Teh_Chin_KCOS Teh-Chin chain approximation, OpenCV's
   --  CHAIN_APPROX_TC89_KCOS flavor.
   type Contour_Approximation_Mode is
     (Every_Point, Simple, Teh_Chin_L1, Teh_Chin_KCOS);

   --  Zero-based position of a contour in a Contour_Set. Valid values are
   --  0 .. Contour_Count - 1; hierarchy links use the same numbering.
   type Contour_Index is new Natural;

   --  A contour hierarchy link that may be absent, replacing OpenCV's -1
   --  sentinel. The default value is absent.
   --  @field Present True when the link designates a contour; False when
   --  OpenCV reported no such contour (a negative native index).
   --  @field Index Zero-based index of the linked contour in the same
   --  Contour_Set. Exists only in the variant where Present is True.
   type Optional_Contour_Index (Present : Boolean := False) is record
      case Present is
         when False =>
            null;

         when True =>
            Index : Contour_Index;
      end case;
   end record;

   --  Topology of one contour in a Contour_Set, as reported by OpenCV for the
   --  Contour_Retrieval_Mode used by Find_Contours. A link is absent when
   --  there is no such contour; a present link is a Contour_Index of the same
   --  set.
   --  @field Next Next contour at the same hierarchy level.
   --  @field Previous Previous contour at the same hierarchy level.
   --  @field First_Child First contour one level below this one, nested inside
   --  it.
   --  @field Parent Contour one level above this one, enclosing it.
   type Contour_Hierarchy_Entry is record
      Next        : Optional_Contour_Index;
      Previous    : Optional_Contour_Index;
      First_Child : Optional_Contour_Index;
      Parent      : Optional_Contour_Index;
   end record;

   --  Ada-owned result of Find_Contours: the points and hierarchy entry of
   --  every contour, indexed by Contour_Index. Points are copied as signed
   --  32-bit coordinates, so the set does not depend on any native OpenCV
   --  result; assignment copies it. A default-initialized set is empty.
   type Contour_Set is private;

   --  Pixel neighborhood that defines connectivity for connected-component
   --  labeling and flood fill. Unrelated to Drawing_Line_Style.
   --  @enum Four_Connected Pixels connect through their four horizontal and
   --  vertical neighbors only, so diagonal pixels stay separate.
   --  @enum Eight_Connected Pixels also connect through their four diagonal
   --  neighbors.
   type Pixel_Connectivity is (Four_Connected, Eight_Connected);

   --  Rasterization of drawn lines and shape edges, separate from
   --  Pixel_Connectivity. Every operation with a Line_Style parameter defaults
   --  to Eight_Connected_Line.
   --  @enum Four_Connected_Line 4-connected lines (OpenCV LINE_4): successive
   --  pixels share an edge.
   --  @enum Eight_Connected_Line 8-connected lines (OpenCV LINE_8): successive
   --  pixels may also touch diagonally.
   --  @enum Anti_Aliased_Line Antialiased lines (OpenCV LINE_AA) with
   --  intermediate edge intensities. Accepted only for UInt8 images; other
   --  depths raise OpenCV.OpenCV_Error, where OpenCV would silently draw
   --  LINE_8 instead.
   type Drawing_Line_Style is
     (Four_Connected_Line, Eight_Connected_Line, Anti_Aliased_Line);

   --  Thickness in pixels of drawn lines and outlines, and the glyph stroke
   --  thickness of text. The upper bound keeps OpenCV's signed raster offsets
   --  in range. Fill operations take no thickness: they select OpenCV's filled
   --  mode internally, and negative thickness is not part of the API.
   subtype Drawing_Thickness is Positive range 1 .. 32_767;

   --  Circle radius in pixels. Zero is excluded because OpenCV would draw a
   --  degenerate point.
   subtype Drawing_Radius is Positive;

   --  Marker shape for Draw_Marker, centered on the marker Position. Each
   --  literal selects the OpenCV marker type at the same position, from
   --  MARKER_CROSS through MARKER_TRIANGLE_DOWN.
   --  @enum Cross_Marker Upright crosshair: one horizontal and one vertical
   --  stroke through Position.
   --  @enum Tilted_Cross_Marker Crosshair tilted by 45 degrees: two diagonal
   --  strokes through Position.
   --  @enum Star_Marker Combination of Cross_Marker and Tilted_Cross_Marker.
   --  @enum Diamond_Marker Square outline rotated by 45 degrees, with vertices
   --  above, below and beside Position.
   --  @enum Square_Marker Axis-aligned square outline around Position.
   --  @enum Triangle_Up_Marker Triangle outline pointing up, with its apex
   --  above Position.
   --  @enum Triangle_Down_Marker Triangle outline pointing down, with a
   --  horizontal top edge above Position.
   type Drawing_Marker_Kind is
     (Cross_Marker,
      Tilted_Cross_Marker,
      Star_Marker,
      Diamond_Marker,
      Square_Marker,
      Triangle_Up_Marker,
      Triangle_Down_Marker);

   --  Legacy Hershey font selector for Draw_Text, Measure_Text and
   --  Font_Scale_For_Height. Each literal selects the OpenCV Hershey font at
   --  the same position, from FONT_HERSHEY_SIMPLEX through
   --  FONT_HERSHEY_SCRIPT_COMPLEX. OpenCV 4.1 and 4.10 render classic Hershey
   --  strokes; OpenCV 5.0 maps the same selectors to built-in sans-serif,
   --  serif and italic TrueType faces, so glyphs and exact metrics can differ
   --  between generations. The legacy italic flag is not exposed.
   --  @enum Hershey_Simplex Normal-size sans-serif font; the default.
   --  @enum Hershey_Plain Small sans-serif font.
   --  @enum Hershey_Duplex Normal-size sans-serif font, more complex than
   --  Hershey_Simplex.
   --  @enum Hershey_Complex Normal-size serif font.
   --  @enum Hershey_Triplex Normal-size serif font, more complex than
   --  Hershey_Complex.
   --  @enum Hershey_Complex_Small Smaller version of Hershey_Complex.
   --  @enum Hershey_Script_Simplex Hand-writing style font.
   --  @enum Hershey_Script_Complex More complex variant of
   --  Hershey_Script_Simplex.
   type Text_Font is
     (Hershey_Simplex,
      Hershey_Plain,
      Hershey_Duplex,
      Hershey_Complex,
      Hershey_Triplex,
      Hershey_Complex_Small,
      Hershey_Script_Simplex,
      Hershey_Script_Complex);

   --  Native text extent reported by Measure_Text, in pixels.
   --  @field Size Width and Height of the text's bounding box as reported by
   --  OpenCV for the font, scale and thickness; (0, 0) for empty text.
   --  @field Baseline Native baseline value, unadjusted by the binding: the
   --  distance from the bottom-most text point up to the text baseline. Zero
   --  for empty text. OpenCV's layout example adds the thickness to it for
   --  padding; the binding does not.
   type Text_Metrics is record
      Size     : OpenCV.Size;
      Baseline : Natural;
   end record;

   --  Accumulator vote threshold, 1 through 2_147_483_647, of the Hough
   --  line, segment and point-set operations and of
   --  Find_Ballard_Template_Matches. It is not itself an accepted count:
   --  standard lines and Ballard matches need strictly more votes than the
   --  threshold. Each operation states how its results relate to it.
   subtype Hough_Vote_Threshold is Positive range 1 .. 2_147_483_647;

   --  One Find_Ballard_Template_Matches detection: where the Template
   --  center lies in the Scene and how much accumulator support that
   --  translation has.
   --  @field Center Scene-local position, in pixels, of the integer
   --  Template center (Template.Columns / 2, Template.Rows / 2). Native
   --  values lie on the integer pixel lattice and are finite and
   --  nonnegative; binary32 cannot represent every integer above `2**24`.
   --  @field Votes Native Int32 accumulator votes, decoded exactly and never
   --  through Float32; strictly greater than the Vote_Threshold used.
   type Ballard_Template_Match is record
      Center : OpenCV.Float32_Point;
      Votes  : Natural;
   end record;

   --  Result of Find_Ballard_Template_Matches. Nonempty results are
   --  zero-based; an empty result has range 1 .. 0. Element order is not a
   --  ranking.
   type Ballard_Template_Match_Array is
     array (Natural range <>) of Ballard_Template_Match;

   --  Finds translated copies of Template in Scene with OpenCV's generalized
   --  Hough Ballard detector, one match per accepted accumulator peak.
   --  Translation-only native Ballard on nonempty 2-D UInt8 C1 images:
   --  fixed levels=360, dp=1, minDist=1, scale=1, angle=0. Rotation and
   --  scale search is Find_Guil_Template_Matches.
   --
   --  Inputs are unchanged; Regions are isolated logical images. Both
   --  inputs are copied into private packed snapshots before preprocessing,
   --  so parent pixels never take part and results use Region-local
   --  coordinates. Native preprocessing is Canny (3x3 aperture, L1
   --  magnitude) plus Float32 Sobel derivatives, with no silent threshold
   --  scaling. Template edges form an orientation-indexed R-table relative
   --  to the Template center (Columns / 2, Rows / 2); a Template without
   --  edges yields an empty result. Centers are Scene-local pixels. Votes
   --  must strictly exceed Vote_Threshold, and a peak must also satisfy the
   --  native local-maximum conditions; several matches may be returned.
   --
   --  Invalid inputs or unsafe native arithmetic raise OpenCV_Error. The
   --  arithmetic restrictions are derived from the native code, not
   --  arbitrary caps; for example a Scene of more than 268435454 pixels
   --  (16384 x 16384) is rejected because its possible peak count would
   --  overflow native output conversion. Synchronous and costly for large
   --  edge sets: many Template edges in one orientation bin multiply the
   --  work at each Scene edge, and private images, derivatives, a
   --  Scene-sized histogram and result buffers are allocated.
   --  @param Template Shape to find: a nonempty 2-D UInt8 C1 grayscale
   --  image whose Canny edges build the R-table.
   --  @param Scene Image to search: a nonempty 2-D UInt8 C1 grayscale
   --  image. Result centers are in its pixel coordinates.
   --  @param Vote_Threshold Accumulator votes that a match must strictly
   --  exceed; default 20.
   --  @param Canny_Low Lower Canny threshold, used as given; it must be less
   --  than Canny_High. Default 50.
   --  @param Canny_High Upper Canny threshold, used as given; default 100.
   --  @return Fresh Ada array of detections. Nonempty bounds start at zero;
   --  empty is 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Template or Scene, Canny_Low >= Canny_High, unsafe
   --  native arithmetic, an unrepresentable decoded vote, or an OpenCV
   --  failure.
   function Find_Ballard_Template_Matches
     (Template       : OpenCV.Core.Mat;
      Scene          : OpenCV.Core.Mat;
      Vote_Threshold : Hough_Vote_Threshold := 20;
      Canny_Low      : Positive := 50;
      Canny_High     : Positive := 100) return Ballard_Template_Match_Array;

   --  One Find_Guil_Template_Matches detection: the Scene position, scale
   --  and rotation of a Template instance, with the native support of each.
   --  @field Center Scene-local position, in pixels, of the integer
   --  Template center (Template.Columns / 2, Template.Rows / 2); finite and
   --  nonnegative.
   --  @field Scale Native positive scale estimate of the instance relative
   --  to Template (1.0 is unscaled); finite and not renormalized.
   --  @field Angle_Degrees Native rotation estimate in degrees, never
   --  radians; finite and not normalized by this binding.
   --  @field Position_Votes Native Int32 position votes, decoded exactly;
   --  at least the Position_Threshold used.
   --  @field Scale_Votes Native Int32 scale votes, decoded exactly; at
   --  least the Scale_Threshold used.
   --  @field Angle_Votes Native Int32 angle votes, decoded exactly; at
   --  least the Angle_Threshold used.
   type Guil_Template_Match is record
      Center         : OpenCV.Float32_Point;
      Scale          : OpenCV.Float32_Value;
      Angle_Degrees  : OpenCV.Float32_Value;
      Position_Votes : Natural;
      Scale_Votes    : Natural;
      Angle_Votes    : Natural;
   end record;

   --  Result of Find_Guil_Template_Matches. Nonempty results are
   --  zero-based; an empty result has range 1 .. 0. Element order is not a
   --  ranking.
   type Guil_Template_Match_Array is
     array (Natural range <>) of Guil_Template_Match;

   --  Canny thresholds, angle and scale search windows, and vote thresholds
   --  of Find_Guil_Template_Matches. The defaults (Canny 50/100, angles
   --  0 .. 360 by 5 degrees, scales 0.5 .. 2.0 by 0.05, vote thresholds
   --  100/100/20) are convenient starting values, not measured
   --  recommendations; a narrow window is much faster and less ambiguous.
   --  All floats must be finite. Native histogram bin counts are
   --  `ceil ((Maximum - Minimum) * (1 / Step))`, the reciprocal product
   --  rather than direct division, and must fit native int arithmetic.
   --  @field Canny_Low Lower Canny threshold, used as given;
   --  0 < Canny_Low < Canny_High.
   --  @field Canny_High Upper Canny threshold, used as given.
   --  @field Minimum_Angle Lowest searched rotation in degrees;
   --  0.0 <= Minimum_Angle < Maximum_Angle.
   --  @field Maximum_Angle Highest searched rotation in degrees; at most
   --  360.0 degrees.
   --  @field Angle_Step Angle histogram step in degrees; greater than 0.0
   --  and less than 360.0.
   --  @field Minimum_Scale Lowest searched scale factor;
   --  0.0 < Minimum_Scale < Maximum_Scale.
   --  @field Maximum_Scale Highest searched scale factor.
   --  @field Scale_Step Scale histogram step; must be positive.
   --  @field Angle_Threshold Angle votes that a hypothesis must meet or
   --  exceed.
   --  @field Scale_Threshold Scale votes that a hypothesis must meet or
   --  exceed.
   --  @field Position_Threshold Position votes that a hypothesis must meet
   --  or exceed.
   type Guil_Search_Parameters is record
      Canny_Low          : Positive := 50;
      Canny_High         : Positive := 100;
      Minimum_Angle      : OpenCV.Float64_Value := 0.0;
      Maximum_Angle      : OpenCV.Float64_Value := 360.0;
      Angle_Step         : OpenCV.Float64_Value := 5.0;
      Minimum_Scale      : OpenCV.Float64_Value := 0.5;
      Maximum_Scale      : OpenCV.Float64_Value := 2.0;
      Scale_Step         : OpenCV.Float64_Value := 0.05;
      Angle_Threshold    : Positive := 100;
      Scale_Threshold    : Positive := 100;
      Position_Threshold : Positive := 20;
   end record;

   --  Finds rotated and scaled copies of Template in Scene with OpenCV's
   --  generalized Hough Guil detector. Each match reports a Scene-local
   --  center, a native positive scale, an angle in degrees and three native
   --  vote counts; Find_Ballard_Template_Matches is the translation-only
   --  alternative.
   --
   --  Native Guil on nonempty 2-D UInt8 C1 images. Inputs are unchanged.
   --  Regions are isolated logical images: both inputs are copied into
   --  private packed snapshots, so parent pixels never take part. Template
   --  center is (Columns / 2, Rows / 2). Centers are Scene-local pixels.
   --  Angle_Degrees is degrees, never radians, and is not normalized by this
   --  binding. Scale is the native positive estimate. Votes are decoded
   --  from Int32, never through Float32. A hypothesis is kept only when each
   --  vote count meets or exceeds its threshold. Fixed levels=360, xi=90
   --  degrees, angle epsilon=1 degree, dp=1, minimum distance=1 (no native
   --  peak-grid filtering), and 1000 features per orientation bin; none of
   --  these is a public option.
   --
   --  Parameters must satisfy 0 <= Minimum_Angle < Maximum_Angle <= 360,
   --  0 < Angle_Step < 360, 0 < Minimum_Scale < Maximum_Scale, and
   --  Scale_Step > 0. All floats must be finite, and
   --  0 < Canny_Low < Canny_High. Invalid inputs or unsafe native arithmetic
   --  raise OpenCV_Error: searches whose native contour area, histogram
   --  index, per-cell vote or output-copy width cannot be represented are
   --  rejected. In particular the angle-bin count times the scale-bin count
   --  times the Scene area must not exceed 134217727 (INT_MAX / 16), so the
   --  default 72 x 30 bins admit Scenes of at most 62137 pixels; narrower
   --  windows admit larger Scenes. Feature construction is quadratic in edge
   --  count and repeats across accepted angle/scale hypotheses, so a dense
   --  high-resolution edge image is costly.
   --  @param Template Shape to find: a nonempty 2-D UInt8 C1 grayscale
   --  image whose Canny edges build the features.
   --  @param Scene Image to search: a nonempty 2-D UInt8 C1 grayscale
   --  image. Result centers are in its pixel coordinates.
   --  @param Parameters Canny thresholds, angle and scale windows and vote
   --  thresholds; see Guil_Search_Parameters for meanings and defaults.
   --  @return Fresh Ada array of detections. Nonempty bounds start at zero;
   --  empty is 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Template or Scene, a nonfinite or out-of-range
   --  parameter, Canny_Low >= Canny_High, unsafe native arithmetic, an
   --  invalid native result, or an OpenCV failure.
   function Find_Guil_Template_Matches
     (Template   : OpenCV.Core.Mat;
      Scene      : OpenCV.Core.Mat;
      Parameters : Guil_Search_Parameters :=
        (Canny_Low          => 50,
         Canny_High         => 100,
         Minimum_Angle      => 0.0,
         Maximum_Angle      => 360.0,
         Angle_Step         => 5.0,
         Minimum_Scale      => 0.5,
         Maximum_Scale      => 2.0,
         Scale_Step         => 0.05,
         Angle_Threshold    => 100,
         Scale_Threshold    => 100,
         Position_Threshold => 20)) return Guil_Template_Match_Array;

   --  Integer Canny and accumulator thresholds for gradient Hough circles,
   --  1 through 2_147_483_647: the upper Canny threshold and the
   --  accumulator vote threshold. They are integers because OpenCV rounds
   --  both to integers.
   subtype Hough_Circle_Threshold is Positive range 1 .. 2_147_483_647;

   --  A standard-Hough line in polar form: the points (X, Y) satisfying
   --  `X * cos (Angle_Radians) + Y * sin (Angle_Radians) = Rho`, with X the
   --  column and Y the row. Each line is an accumulator bin quantized by the
   --  requested resolutions. A horizontal line at row r appears near
   --  (r, Pi / 2); a vertical line at column c appears near (c, 0), or
   --  equivalently (-c, Pi).
   --  @field Rho Signed distance from the Source origin to the line along
   --  its normal, in pixels; may be negative.
   --  @field Angle_Radians Direction of the line normal; always in radians.
   type Hough_Line is record
      Rho           : OpenCV.Float32_Value;
      Angle_Radians : OpenCV.Float32_Value;
   end record;

   --  Result of Find_Hough_Lines. Nonempty results are zero-based; an empty
   --  result has range 1 .. 0.
   type Hough_Line_Array is array (Natural range <>) of Hough_Line;

   --  A probabilistic-Hough segment. Endpoint order is unspecified:
   --  (A, B) and (B, A) describe the same segment. Endpoints are integer
   --  pixel positions and may differ by a pixel or two across OpenCV
   --  builds.
   --  @field Start_Point One endpoint, in Source pixel coordinates.
   --  @field End_Point The other endpoint, in Source pixel coordinates.
   type Hough_Line_Segment is record
      Start_Point : OpenCV.Point;
      End_Point   : OpenCV.Point;
   end record;

   --  Result of Find_Hough_Line_Segments. Nonempty results are zero-based;
   --  an empty result has range 1 .. 0.
   type Hough_Line_Segment_Array is
     array (Natural range <>) of Hough_Line_Segment;

   --  A gradient-Hough circle. Center and Radius are native binary32
   --  pixel values quantized by the accumulator scale: centers come from
   --  accumulator cells and radii from histogram estimates, so compare them
   --  with a tolerance of a pixel or two rather than exactly.
   --  @field Center Circle center in Source pixel coordinates.
   --  @field Radius Estimated circle radius in pixels.
   type Hough_Circle is record
      Center : OpenCV.Float32_Point;
      Radius : OpenCV.Float32_Value;
   end record;

   --  Result of Find_Hough_Circles. Nonempty results are zero-based; an
   --  empty result has range 1 .. 0.
   type Hough_Circle_Array is array (Natural range <>) of Hough_Circle;

   --  A standard-Hough line with its accumulator vote count. Votes is
   --  evidence for ranking, not a cross-version constant: raster-line votes
   --  come from OpenCV's binary32 Vec3f output and point-set votes from its
   --  Vec3d output, all integer accumulator counts promoted to Float64.
   --  Raster counts above `2**24` may already have been rounded by binary32.
   --  The line is the set of points satisfying
   --  `X * cos (Angle_Radians) + Y * sin (Angle_Radians) = Rho`; OpenCV's
   --  point-set order (votes, rho, theta) is normalized to this layout.
   --  @field Rho Signed distance from the coordinate origin (the Source
   --  origin for raster lines) to the line along its normal.
   --  @field Angle_Radians Direction of the line normal; always in radians.
   --  @field Votes Accumulator support count of the line's bin, an integer
   --  stored as Float64.
   type Hough_Line_With_Votes is record
      Rho           : OpenCV.Float32_Value;
      Angle_Radians : OpenCV.Float32_Value;
      Votes         : OpenCV.Float64_Value;
   end record;

   --  Result of Find_Hough_Lines_With_Votes and
   --  Find_Hough_Lines_From_Points. Nonempty results are zero-based; an
   --  empty result has range 1 .. 0.
   type Hough_Line_With_Votes_Array is
     array (Natural range <>) of Hough_Line_With_Votes;

   --  One degree in radians (Pi / 180), the default point-set angle
   --  resolution of Find_Hough_Lines_From_Points.
   Hough_Degree : constant := Ada.Numerics.Pi / 180.0;

   --  Input points for Find_Hough_Lines_From_Points; any index bounds,
   --  including a null range. X and Y are binary32 coordinates in the same
   --  frame as the returned Rho; that operation rejects nonfinite values.
   type Hough_Point_Array is array (Integer range <>) of OpenCV.Float32_Point;

   --  A radius-finding gradient-Hough circle with the support count of its
   --  estimated radius, from OpenCV's binary32 Vec4f output (counts above
   --  `2**24` may already have been rounded by binary32).
   --  @field Center Circle center in Source pixel coordinates, quantized to
   --  accumulator cells.
   --  @field Radius Estimated circle radius in pixels, a histogram
   --  estimate.
   --  @field Votes Support count of the chosen radius, an integer stored as
   --  Float64; ranking evidence, not a cross-version constant.
   type Hough_Circle_With_Votes is record
      Center : OpenCV.Float32_Point;
      Radius : OpenCV.Float32_Value;
      Votes  : OpenCV.Float64_Value;
   end record;

   --  Result of Find_Hough_Circles_With_Votes. Nonempty results are
   --  zero-based; an empty result has range 1 .. 0.
   type Hough_Circle_With_Votes_Array is
     array (Natural range <>) of Hough_Circle_With_Votes;

   --  Centers found by center-only gradient-Hough detection
   --  (Find_Hough_Circle_Centers), in Source pixel coordinates.
   --  Nonempty results are zero-based; an empty result has range 1 .. 0.
   type Hough_Circle_Center_Array is
     array (Natural range <>) of OpenCV.Float32_Point;

   --  Portable connected-component selector. SAUF uses CCL_WU and BBDT uses
   --  CCL_GRANA on OpenCV 4.1; Spaghetti requires OpenCV 4.5.2 or later.
   --  @enum Native_Default Preserve the installed OpenCV default.
   --  @enum SAUF Row-major label ordering as guaranteed by OpenCV.
   --  @enum BBDT No spatial ordering; uses SAUF for 4-connectivity.
   --  @enum Spaghetti No spatial label-order guarantee; unavailable on 4.1.
   type Connected_Component_Algorithm is
     (Native_Default, SAUF, BBDT, Spaghetti);

   --  Storage of published labels. Both choices use private Int32 native
   --  staging, avoiding unsafe native UInt16 provisional-label overflow.
   --  @enum UInt16_Labels IDs 0 .. 65535; 65536 labels including background.
   --  @enum Int32_Labels Nonnegative signed 32-bit IDs, subject to native
   --  geometry and allocation limits.
   type Connected_Component_Label_Depth is (UInt16_Labels, Int32_Labels);

   --  Pixel value of the Labels image of connected-component operations:
   --  Background_Label for background pixels and 1 .. Component_Count for the
   --  foreground components. Get_Component accepts foreground labels.
   type Component_Label is new Natural;

   --  Label of every background (zero) Source pixel. The background has no
   --  entry in a Connected_Component_Set, so Get_Component rejects it.
   Background_Label : constant Component_Label := 0;

   --  Statistics of one foreground component, in the coordinates of the
   --  labeled Source (relative to it when Source is a Region).
   --  @field Bounds Smallest axis-aligned rectangle containing every pixel of
   --  the component: X and Y are its first column and row, Width and Height
   --  its extents in pixels.
   --  @field Area Number of pixels in the component.
   --  @field Centroid_X Mean column (X) of the component's pixels.
   --  @field Centroid_Y Mean row (Y) of the component's pixels.
   type Component_Statistics is record
      Bounds     : OpenCV.Rect;
      Area       : Natural;
      Centroid_X : OpenCV.Float64_Value;
      Centroid_Y : OpenCV.Float64_Value;
   end record;

   --  Ada-owned foreground statistics from Connected_Components_With_Stats,
   --  indexed by Component_Label 1 .. Component_Count; the background has no
   --  entry. The set is copied out of OpenCV's statistics, so it does not
   --  depend on native storage; assignment copies it. A default-initialized
   --  set is empty.
   type Connected_Component_Set is private;

   --  Shape of a generated structuring element, built by
   --  Get_Structuring_Element and by the Kernel_Size morphology overloads.
   --  Any 1 x 1 element is a single included pixel whatever the shape.
   --  @enum Rectangle Every pixel of the Kernel_Size box is included.
   --  @enum Cross Only the anchor's row and column are included; the
   --  centered anchor is (Width / 2, Height / 2).
   --  @enum Ellipse An elliptical footprint fitted to the box, symmetric
   --  about its center. Native signed radius arithmetic limits the height
   --  to 92681.
   type Morphology_Shape is (Rectangle, Cross, Ellipse);

   --  Fresh UInt8 C1 mask with native 0/1 values and exact positive size,
   --  for use as the Kernel of Erode, Dilate and Apply_Morphology. Values
   --  are 1 for included and 0 for excluded pixels, never 255. Even and
   --  non-square dimensions are supported. Size (1, 1) is always Rectangle.
   --  Only Cross geometry depends on Anchor; Mat retains no anchor metadata.
   --  Pass the intended anchor again when applying a custom Cross kernel.
   --  The centered overload uses (Width / 2, Height / 2). Ellipse height is
   --  limited to 92681; native allocation limits also apply.
   --  @param Kernel_Size Mask width (columns) and height (rows); both
   --  must be positive.
   --  @param Shape Generated shape; defaults to Rectangle.
   --  @return Fresh owning UInt8 C1 mask of exactly Kernel_Size.
   --  @exception OpenCV_Error Raised when a dimension is zero, when
   --  the Ellipse or allocation limits are exceeded, or when OpenCV fails.
   function Get_Structuring_Element
     (Kernel_Size : OpenCV.Size; Shape : Morphology_Shape := Rectangle)
      return OpenCV.Core.Mat;

   --  As the centered overload, but builds the mask around an explicit
   --  Anchor, which must lie inside the Kernel_Size box; no negative center
   --  sentinel exists. Rectangle and Ellipse masks ignore Anchor; a Cross
   --  includes the row and column through Anchor. The returned Mat does not
   --  record Anchor, so pass the same Anchor to the morphology operation.
   --  @param Kernel_Size Mask width (columns) and height (rows); both
   --  must be positive.
   --  @param Shape Generated shape; no default in this overload.
   --  @param Anchor Kernel position, inside the mask, through which a Cross
   --  passes.
   --  @return Fresh owning UInt8 C1 mask of exactly Kernel_Size.
   --  @exception OpenCV_Error Raised when a dimension is zero, when
   --  Anchor lies outside the mask, when the Ellipse or allocation limits
   --  are exceeded, or when OpenCV fails.
   function Get_Structuring_Element
     (Kernel_Size : OpenCV.Size;
      Shape       : Morphology_Shape;
      Anchor      : OpenCV.Point) return OpenCV.Core.Mat;

   --  Compound operation of Apply_Morphology, built from erosion and
   --  dilation with the same structuring element.
   --  @enum Opening Erosion followed by dilation; removes small bright
   --  features.
   --  @enum Closing Dilation followed by erosion; fills small dark holes.
   --  @enum Gradient Dilation minus erosion, a morphological edge map.
   --  @enum Top_Hat Source minus its opening; keeps small bright features.
   --  @enum Black_Hat Closing of Source minus Source; keeps small dark
   --  features.
   type Morphology_Operation is
     (Opening, Closing, Gradient, Top_Hat, Black_Hat);

   --  Repetition count of morphology. Erode and Dilate apply the elementary
   --  step Iterations times. Apply_Morphology repeats each constituent step:
   --  Opening with 2 performs two erosions and then two dilations, not two
   --  complete openings. Hit_Or_Miss erodes each leg Iterations times.
   subtype Morphology_Iterations is Positive range 1 .. 2_147_483_647;

   --  Constant border value used by morphology when Border is
   --  Constant_Border: either OpenCV's neutral default
   --  (Default_Morphology_Border) or an explicit Scalar created by
   --  Explicit_Morphology_Border. Other borders ignore it.
   type Morphology_Border_Value is private;

   --  OpenCV's special neutral border, not zero: outside pixels act as the
   --  maximum for erosion and the minimum for dilation, so they never
   --  affect the result. Valid for every Source depth and channel count.
   Default_Morphology_Border : constant Morphology_Border_Value;

   --  Selects an ordinary constant border value for Constant_Border
   --  morphology; it is ignored for other borders. For C1 .. C4 Sources,
   --  components 0 .. Channels - 1 map to the channels; Sources with more
   --  than four channels require all four components equal. The value is
   --  checked when an operation runs: the components used must be finite,
   --  Float32 Sources need them within the finite Float32 range, and
   --  integer Sources need them within the signed-int range
   --  -2_147_483_648 .. 2_147_483_647 before OpenCV rounds and saturates
   --  them to the pixel range (300 becomes 255 for UInt8, not a wrapped
   --  value). The all-DBL_MAX scalar is reserved by OpenCV for its neutral
   --  default and is rejected here.
   --  @param Value Border value in channel order; not every component
   --  equal to Float64_Value'Last (native DBL_MAX).
   --  @return Explicit border value wrapping Value.
   --  @exception OpenCV_Error Raised when every component of Value
   --  equals Float64_Value'Last.
   function Explicit_Morphology_Border
     (Value : OpenCV.Scalar) return Morphology_Border_Value;

   --  Comparison computed by Match_Template at every placement of Template
   --  over Source, as the corresponding OpenCV `TM_*` selector. Scores are
   --  Float32 values with native rounding. Use OpenCV.Core.Min_Max_Loc on
   --  the score map: the best match is the minimum for the two
   --  squared-difference methods and the maximum for the other four. The
   --  masked Match_Template overload does not support
   --  Normalized_Correlation_Coefficient and documents its masked formulas
   --  and zero-energy rules.
   --  @enum Squared_Difference TM_SQDIFF: sum of squared Template and window
   --  differences, ideally zero for a perfect match. Lower is better: the
   --  best match is the minimum.
   --  @enum Normalized_Squared_Difference TM_SQDIFF_NORMED: squared
   --  difference divided by `sqrt (template energy * window energy)`. Lower
   --  is better: the best match is the minimum.
   --  @enum Cross_Correlation TM_CCORR: unnormalized sum of Template and
   --  window products, growing with brightness. Higher is better: the best
   --  match is the maximum.
   --  @enum Normalized_Cross_Correlation TM_CCORR_NORMED: cosine similarity
   --  of Template and window. Higher is better: the best match is the
   --  maximum.
   --  @enum Correlation_Coefficient TM_CCOEFF: mean-centered correlation
   --  (the covariance numerator); it is not scale-normalized and not
   --  limited to [-1, 1]. Higher is better: the best match is the maximum.
   --  @enum Normalized_Correlation_Coefficient TM_CCOEFF_NORMED:
   --  mean-centered and scale-normalized correlation coefficient. Higher is
   --  better: the best match is the maximum. Unmasked overload only.
   type Template_Matching_Method is
     (Squared_Difference,
      Normalized_Squared_Difference,
      Cross_Correlation,
      Normalized_Cross_Correlation,
      Correlation_Coefficient,
      Normalized_Correlation_Coefficient);

   --  How Warp_Affine and Warp_Perspective interpret their Transform.
   --  @enum Source_To_Destination Transform maps Source coordinates to
   --  Destination coordinates: the usual forward warp, which OpenCV
   --  inverts internally. A +1 X translation moves content right.
   --  @enum Destination_To_Source Transform is already inverted and maps
   --  each Destination pixel to the Source position it samples (native
   --  WARP_INVERSE_MAP). A +1 X translation moves content left.
   type Warp_Mapping_Direction is
     (Source_To_Destination, Destination_To_Source);

   --  Warp_Mapping_Direction under the name used by Warp_Affine; the
   --  values and their meaning are identical.
   subtype Affine_Mapping_Direction is Warp_Mapping_Direction;

   --  Plane order of a YUV 4:2:0 frame of logical W columns and H rows, with
   --  one Y byte per pixel and one U and one V byte per 2x2 pixel block. The
   --  packed UInt8 C1 form (W columns, H + H/2 rows) is read as one row-major
   --  byte stream that starts with the W x H Y plane; U and V each occupy
   --  `W * H / 4` bytes.
   --  @enum I420 Planar: the Y plane, then the U plane, then the V plane.
   --  @enum YV12 Planar: the Y plane, then the V plane, then the U plane.
   --  @enum NV12 Semiplanar: the Y plane, then interleaved U,V byte pairs.
   --  @enum NV21 Semiplanar: the Y plane, then interleaved V,U byte pairs.
   type YUV420_Layout is (I420, YV12, NV12, NV21);

   --  The planar layouts I420 and YV12, the only ones Encode_YUV420_Planar
   --  produces; NV12/NV21 encoding is not provided.
   subtype YUV420_Planar_Layout is YUV420_Layout range I420 .. YV12;

   --  The semiplanar layouts NV12 and NV21, whose chroma is one interleaved
   --  plane; the only layouts Decode_YUV420_Two_Plane accepts.
   subtype YUV420_Semiplanar_Layout is YUV420_Layout range NV12 .. NV21;

   --  Channel layout of a decoded YUV 4:2:0 or 4:2:2 frame: a UInt8 image with
   --  the frame's H rows and W columns.
   --  @enum BGR_Output C3 in B, G, R order.
   --  @enum RGB_Output C3 in R, G, B order.
   --  @enum BGRA_Output C4 in B, G, R, alpha order; alpha is always 255.
   --  @enum RGBA_Output C4 in R, G, B, alpha order; alpha is always 255.
   type YUV420_Color_Output is
     (BGR_Output, RGB_Output, BGRA_Output, RGBA_Output);

   --  Channel order of the color Source of Encode_YUV420_Planar. A C4 Source's
   --  alpha is ignored, not premultiplied.
   --  @enum BGR_Order Source is BGR (C3) or BGRA (C4).
   --  @enum RGB_Order Source is RGB (C3) or RGBA (C4).
   type YUV_Color_Order is (BGR_Order, RGB_Order);

   --  Decodes a packed YUV 4:2:0 frame to UInt8 color with native OpenCV.
   --  Packed sources/results are UInt8 C1, W columns and H+H/2 rows. Logical
   --  W/H are positive even values, at least 2, so Source has a row count that
   --  is a multiple of 3 and H is two thirds of it. I420 is Y,U,V; YV12 is
   --  Y,V,U; NV12 is Y then U,V pairs; NV21 is Y then V,U pairs.
   --
   --  All YUV 4:2:0 operations take packed independent snapshots, leave inputs
   --  unchanged and return fresh owning Mats. Violations raise OpenCV_Error. A
   --  packed Region must itself contain a complete standalone frame: parent
   --  plane offsets and ROI origins are never inferred. Packed NV12/NV21
   --  frames are split into Y and UV planes and decoded by the same native
   --  cvtColorTwoPlane route as Decode_YUV420_Two_Plane, so both
   --  representations of a frame decode to identical pixels within one native
   --  build.
   --
   --  Native BT.601 limited-range conversion (nominal Y 16..235 and
   --  U/V 16..240, centered on 128) accepts all byte values: `Y - 16` is
   --  clamped at zero and RGB saturates. Vendor rounding can differ from the
   --  portable 20-bit CPU arithmetic. Decode_YUV420 returns UInt8 H x W C3
   --  BGR/RGB or C4 BGRA/RGBA, with alpha 255.
   --  @param Source Packed frame: nonempty 2-D UInt8 C1 with an even column
   --  count of at least 2 and a row count that is a positive multiple of 3.
   --  @param Layout Plane order of Source.
   --  @param Output Channel layout of the result; BGR_Output by default.
   --  @return Fresh owning UInt8 Mat of H rows and W columns: C3 B,G,R or
   --  R,G,B, or C4 B,G,R,255 or R,G,B,255, as selected by Output.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D or not
   --  UInt8 C1; when its column count is odd or below 2 or its row count is
   --  not a positive multiple of 3; when a native signed-arithmetic or
   --  address-span limit is exceeded (for example `W * H`
   --  above 2_147_483_647); or when OpenCV fails.
   function Decode_YUV420
     (Source : OpenCV.Core.Mat;
      Layout : YUV420_Layout;
      Output : YUV420_Color_Output := BGR_Output) return OpenCV.Core.Mat;

   --  Decodes a semiplanar YUV 4:2:0 frame supplied as separate planes, with
   --  native cvtColorTwoPlane. Y: nonempty 2-D UInt8 C1 H x W. UV: UInt8 C2
   --  H/2 x W/2. Caller supplies corresponding planes/Regions; no chroma phase
   --  is inferred. Independent packed snapshots have equal byte step W,
   --  normalizing OpenCV 4.1's shared-stride assumption. Both semiplanar
   --  decode forms use cvtColorTwoPlane, with exact representation equality:
   --  within one native build the result equals Decode_YUV420 of the same
   --  frame packed.
   --
   --  Inputs stay unchanged and only the logical pixels of Regions
   --  participate. Conversion is the native BT.601 limited-range arithmetic
   --  described for Decode_YUV420: all byte values are accepted and vendor
   --  rounding can differ from the portable 20-bit CPU arithmetic.
   --  @param Y_Plane Luma plane: nonempty 2-D UInt8 C1 of H rows and W
   --  columns, with W and H even and at least 2.
   --  @param UV_Plane Interleaved chroma plane: nonempty 2-D UInt8 C2 of
   --  exactly H/2 rows and W/2 columns; each element is the U,V (NV12) or V,U
   --  (NV21) pair of one 2x2 pixel block.
   --  @param Layout Element order of UV_Plane: NV12 or NV21.
   --  @param Output Channel layout of the result; BGR_Output by default.
   --  @return Fresh owning UInt8 Mat of H rows and W columns: C3 B,G,R or
   --  R,G,B, or C4 B,G,R,255 or R,G,B,255, as selected by Output.
   --  @exception OpenCV_Error Raised when a plane is empty, not 2-D, not UInt8
   --  or has the wrong channel count; when W or H is odd or below 2; when
   --  UV_Plane is not exactly H/2 x W/2; when a native signed-arithmetic or
   --  address-span limit is exceeded (for example `W * H`
   --  above 2_147_483_647); or when OpenCV fails.
   function Decode_YUV420_Two_Plane
     (Y_Plane  : OpenCV.Core.Mat;
      UV_Plane : OpenCV.Core.Mat;
      Layout   : YUV420_Semiplanar_Layout;
      Output   : YUV420_Color_Output := BGR_Output) return OpenCV.Core.Mat;

   --  Encodes a color image as a packed planar YUV 4:2:0 frame with native
   --  cv::cvtColor. Nonempty 2-D UInt8 C3/C4, even W/H >=2. BGR_Order means
   --  BGR/BGRA; RGB_Order means RGB/RGBA. Alpha is ignored, not premultiplied.
   --  Native encoding computes Y per pixel and samples U/V at the top-left
   --  pixel of each 2x2 block, without averaging. Subsampling is lossy. The
   --  native BT.601 limited-range encoder maps black to Y,U,V 16,128,128 and
   --  white to 235,128,128.
   --
   --  Source is copied into an independent packed snapshot first, so a Region
   --  is encoded as its own frame and Source is unchanged. NV12/NV21 encoding
   --  is not provided.
   --  @param Source Color image: nonempty 2-D UInt8 C3 or C4 of H rows and W
   --  columns, with W and H even and at least 2.
   --  @param Layout Plane order of the result: I420 or YV12.
   --  @param Order Channel order of Source; BGR_Order by default.
   --  @return Fresh owning packed frame: UInt8 C1 of W columns and H + H/2
   --  rows.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D, not UInt8,
   --  or not C3 or C4; when its row or column count is odd or below 2; when a
   --  native signed-arithmetic or address-span limit is exceeded (for example
   --  `W * H` above 2_147_483_647); or when OpenCV fails.
   function Encode_YUV420_Planar
     (Source : OpenCV.Core.Mat;
      Layout : YUV420_Planar_Layout;
      Order  : YUV_Color_Order := BGR_Order) return OpenCV.Core.Mat;

   --  Copies the luma plane of a packed YUV 4:2:0 frame of any layout. Raw Y
   --  bytes, UInt8 C1 H x W, with no subtract-16 or rescaling. Chroma does not
   --  participate. Source is validated as for Decode_YUV420 and copied into an
   --  independent packed snapshot first; a packed Region must itself contain a
   --  complete standalone frame.
   --  @param Source Packed frame: nonempty 2-D UInt8 C1 with an even column
   --  count of at least 2 and a row count that is a positive multiple of 3.
   --  @return Fresh owning UInt8 C1 Mat of H rows (two thirds of Source's
   --  rows) and W columns: the first H rows of Source, byte for byte.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D or not
   --  UInt8 C1; when its column count is odd or below 2 or its row count is
   --  not a positive multiple of 3; when a native arithmetic or address-span
   --  limit is exceeded; or when OpenCV fails.
   function Extract_YUV420_Luma
     (Source : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Byte order of a packed YUV 4:2:2 frame stored as UInt8 C2. Each C2
   --  element holds two consecutive stream bytes, and the elements at
   --  columns 2k and 2k+1 of a row hold two horizontal pixels, Y0 and Y1,
   --  sharing one U and one V sample. VYUY and planar 4:2:2 are not supported.
   --  @enum UYVY Stream U, Y0, V, Y1: elements (U, Y0) and (V, Y1); Y is
   --  channel 1.
   --  @enum YUY2 Stream Y0, U, Y1, V: elements (Y0, U) and (Y1, V); Y is
   --  channel 0.
   --  @enum YVYU Stream Y0, V, Y1, U: elements (Y0, V) and (Y1, U); Y is
   --  channel 0.
   type YUV422_Layout is (UYVY, YUY2, YVYU);

   --  Result layout of Decode_YUV422: the YUV420_Color_Output literals with
   --  the same meaning, C3 BGR/RGB or C4 BGRA/RGBA with alpha 255.
   subtype YUV422_Color_Output is YUV420_Color_Output;

   --  Decodes a packed YUV 4:2:2 frame to UInt8 color with native
   --  cv::cvtColor. Nonempty 2-D UInt8 C2, H >=1, even W >=2. Each C2 element
   --  is two stream bytes: UYVY = U,Y0,V,Y1; YUY2 = Y0,U,Y1,V; YVYU =
   --  Y0,V,Y1,U. Each U/V pair serves two horizontal pixels. Results are fresh
   --  owning H x W UInt8 Mats; Source stays unchanged. Independent logical-row
   --  snapshots treat Regions as standalone frames. Caller supplies the
   --  declared byte phase: odd-column parent ROIs may change it; Layout is
   --  never inferred from the parent's ROI origin. Invalid sources/native
   --  arithmetic spans raise OpenCV.OpenCV_Error. OpenCV 4.1 lacks the native
   --  even-width check; Ada and the shim enforce it before pair reads. Decode
   --  uses native limited-range BT.601 arithmetic (nominal Y 16..235 and
   --  U/V 16..240, centered on 128), accepting all UInt8 values with native
   --  saturation. Vendor/build pixel identity is not promised. Decode_YUV422
   --  returns C3 BGR/RGB or C4 BGRA/RGBA, alpha 255; geometry is preserved.
   --  @param Source Packed frame: nonempty 2-D UInt8 C2 with at least one row
   --  and an even column count of at least 2.
   --  @param Layout Byte order of Source.
   --  @param Output Channel layout of the result; BGR_Output by default.
   --  @return Fresh owning UInt8 Mat with Source's rows and columns: C3 B,G,R
   --  or R,G,B, or C4 B,G,R,255 or R,G,B,255, as selected by Output.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D or not
   --  UInt8 C2; when its column count is odd or below 2; when `2 * W` or
   --  `W * H` exceeds 2_147_483_647 or another native arithmetic or
   --  address-span limit is exceeded; or when OpenCV fails.
   function Decode_YUV422
     (Source : OpenCV.Core.Mat;
      Layout : YUV422_Layout;
      Output : YUV422_Color_Output := BGR_Output) return OpenCV.Core.Mat;

   --  Exact raw Y bytes, C1, no subtract-16, scaling or chroma participation.
   --  UYVY uses source channel 1; YUY2/YVYU use channel 0. The frame contract
   --  is the same as for Decode_YUV422: nonempty 2-D UInt8 C2 with an even
   --  width, copied by logical rows into an independent snapshot, with a
   --  Region treated as a standalone frame in the caller's byte phase. YUV422
   --  encoding is intentionally deferred: OpenCV 4.1 lacks it.
   --  @param Source Packed frame: nonempty 2-D UInt8 C2 with at least one row
   --  and an even column count of at least 2.
   --  @param Layout Byte order of Source, which selects the Y channel.
   --  @return Fresh owning UInt8 C1 Mat with Source's rows and columns holding
   --  each pixel's Y byte unchanged.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D or not
   --  UInt8 C2; when its column count is odd or below 2; when a native
   --  arithmetic or address-span limit is exceeded (for example `2 * W`
   --  above 2_147_483_647); or when OpenCV fails.
   function Extract_YUV422_Luma
     (Source : OpenCV.Core.Mat; Layout : YUV422_Layout) return OpenCV.Core.Mat;

   --  Physical 2x2 color filter array tile at logical Source (0,0), named row
   --  by row: the first two letters are the colors at columns 0 and 1 of
   --  row 0, the last two those of row 1. These are physical names, not
   --  OpenCV's short code names: RGGB, GRBG, BGGR and GBRG select OpenCV's
   --  BayerBG, BayerGB, BayerRG and BayerGR codes respectively. Cropping at an
   --  odd row or column offset changes the phase; the caller supplies the
   --  pattern at the Region's own (0,0).
   --  @enum RGGB Row 0 is R, G; row 1 is G, B.
   --  @enum GRBG Row 0 is G, R; row 1 is B, G.
   --  @enum BGGR Row 0 is B, G; row 1 is G, R.
   --  @enum GBRG Row 0 is G, B; row 1 is R, G.
   type Bayer_Pattern is (RGGB, GRBG, BGGR, GBRG);

   --  Native interpolation algorithm used by Demosaic_Bayer.
   --  Demosaic_Bayer_To_Gray and Demosaic_Bayer_With_Alpha always interpolate
   --  bilinearly.
   --  @enum Bilinear Native bilinear interpolation; UInt8 or UInt16 Source.
   --  @enum Variable_Number_Of_Gradients Native Variable Number of Gradients
   --  (VNG) interpolation; UInt8 Source only. When either dimension is
   --  below 8, OpenCV runs bilinear demosaicing instead (see Demosaic_Bayer).
   --  @enum Edge_Aware Native edge-aware interpolation; UInt8 or UInt16
   --  Source.
   type Bayer_Demosaicing_Method is
     (Bilinear, Variable_Number_Of_Gradients, Edge_Aware);

   --  Color channel order of a demosaiced result.
   --  @enum BGR_Order B, G, R for C3 results, or B, G, R, alpha for C4.
   --  @enum RGB_Order R, G, B for C3 results, or R, G, B, alpha for C4.
   type Bayer_Color_Order is (BGR_Order, RGB_Order);

   --  Demosaics a single-channel Bayer mosaic to color with native
   --  cv::demosaicing. Pattern describes the physical 2x2 CFA at logical
   --  Source (0,0). Cropping does not automatically adjust the parent's Bayer
   --  phase. Every Bayer operation requires nonempty 2-D C1 UInt8/UInt16, at
   --  least 3x3. VNG requires UInt8. No depth conversion is performed.
   --
   --  Source is unchanged; an independent packed snapshot isolates Regions
   --  from parent pixels. Results are fresh owning Mats of the same size and
   --  depth. Invalid sources raise OpenCV.OpenCV_Error.
   --
   --  For Variable_Number_Of_Gradients, OpenCV falls back to bilinear
   --  demosaicing when either dimension is below 8. In OpenCV 4.1/4.10 that
   --  fallback decodes every Pattern and Order as BGGR/BGR; 5.0 honors them,
   --  so select Bilinear for correct phase and order on small images across
   --  releases. OpenCV 5 VNG uses two-pixel reflected (Reflect_101) padding;
   --  cross-version VNG border values are not promised identical. The
   --  installed algorithm is preserved. Demosaic_Bayer returns C3 BGR or RGB
   --  according to Order.
   --  Legacy edge-aware interpolation (including OpenCV 4.1) can round
   --  diagonal color averages differently for the BGR and RGB selectors.
   --  Channel order is preserved, but reversing channels need not produce
   --  bit-identical samples; native selector results are retained.
   --  @param Source Bayer mosaic: nonempty 2-D C1 UInt8 or UInt16 of at
   --  least 3 rows and 3 columns; UInt8 for Variable_Number_Of_Gradients.
   --  @param Pattern CFA tile at logical Source (0,0).
   --  @param Method Interpolation algorithm; Bilinear by default.
   --  @param Order Channel order of the result; BGR_Order by default.
   --  @return Fresh owning C3 Mat with Source's rows, columns and depth, in
   --  B,G,R or R,G,B order as selected by Order.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D, not C1,
   --  smaller than 3x3, not UInt8 or UInt16, or UInt16 with
   --  Variable_Number_Of_Gradients; when a native signed-arithmetic or
   --  address-span limit is exceeded; or when OpenCV fails.
   function Demosaic_Bayer
     (Source  : OpenCV.Core.Mat;
      Pattern : Bayer_Pattern;
      Method  : Bayer_Demosaicing_Method := Bilinear;
      Order   : Bayer_Color_Order := BGR_Order) return OpenCV.Core.Mat;

   --  Direct native Bayer luminance, C1 (not color followed by conversion),
   --  interpolated bilinearly at Pattern's phase. In a uniform area of the
   --  mosaic the value is the native fixed-point
   --  `(4899 * R + 9617 * G + 1868 * B + 8192) / 16384`; UInt8 SIMD rounding
   --  can differ by one.
   --
   --  Source requirements, snapshot isolation and Pattern phase are as for
   --  Demosaic_Bayer: nonempty 2-D C1 UInt8/UInt16 of at least 3x3, copied
   --  into an independent packed snapshot, with Pattern at logical (0,0). On
   --  OpenCV 4.x before 4.5.5, a UInt16 Source is rejected when the four green
   --  neighbors of any interior red or blue site sum above 223300, which would
   --  overflow native signed arithmetic; later releases have no such
   --  restriction.
   --  @param Source Bayer mosaic: nonempty 2-D C1 UInt8 or UInt16 of at
   --  least 3 rows and 3 columns.
   --  @param Pattern CFA tile at logical Source (0,0).
   --  @return Fresh owning C1 Mat with Source's rows, columns and depth.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D, not C1,
   --  smaller than 3x3, or not UInt8 or UInt16; when the legacy UInt16
   --  neighbor limit above applies; when a native signed-arithmetic or
   --  address-span limit is exceeded; or when OpenCV fails.
   function Demosaic_Bayer_To_Gray
     (Source : OpenCV.Core.Mat; Pattern : Bayer_Pattern)
      return OpenCV.Core.Mat;

   --  Bilinear C4 BGRA/RGBA; native alpha is 255/65535 for UInt8/UInt16.
   --  Source requirements, snapshot isolation and Pattern phase are as for
   --  Demosaic_Bayer: nonempty 2-D C1 UInt8/UInt16 of at least 3x3, copied
   --  into an independent packed snapshot, with Pattern at logical (0,0).
   --  @param Source Bayer mosaic: nonempty 2-D C1 UInt8 or UInt16 of at
   --  least 3 rows and 3 columns.
   --  @param Pattern CFA tile at logical Source (0,0).
   --  @param Order Color channel order of the result; BGR_Order by default.
   --  @return Fresh owning C4 Mat with Source's rows, columns and depth, in
   --  B,G,R,alpha or R,G,B,alpha order as selected by Order.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D, not C1,
   --  smaller than 3x3, or not UInt8 or UInt16; when a native
   --  signed-arithmetic or address-span limit is exceeded; or when OpenCV
   --  fails.
   function Demosaic_Bayer_With_Alpha
     (Source  : OpenCV.Core.Mat;
      Pattern : Bayer_Pattern;
      Order   : Bayer_Color_Order := BGR_Order) return OpenCV.Core.Mat;

   --  Built-in colormap applied by Apply_Color_Map: a native OpenCV table
   --  of 256 UInt8 BGR entries indexed by a grayscale byte. Portable
   --  OpenCV 4.1/4.10/5 set; no Turbo or DeepGreen. The twenty table
   --  definitions are identical in the reviewed releases.
   --  @enum Autumn_Map Native `COLORMAP_AUTUMN`: B 0, G equal to the index and
   --  R 255, from red at 0 to yellow at 255.
   --  @enum Bone_Map Native `COLORMAP_BONE` table.
   --  @enum Jet_Map Native `COLORMAP_JET`: BGR 128,0,0 at index 0 and
   --  BGR 0,0,128 at 255.
   --  @enum Winter_Map Native `COLORMAP_WINTER` table.
   --  @enum Rainbow_Map Native `COLORMAP_RAINBOW` table.
   --  @enum Ocean_Map Native `COLORMAP_OCEAN` table.
   --  @enum Summer_Map Native `COLORMAP_SUMMER` table.
   --  @enum Spring_Map Native `COLORMAP_SPRING` table.
   --  @enum Cool_Map Native `COLORMAP_COOL` table.
   --  @enum HSV_Map Native `COLORMAP_HSV` table.
   --  @enum Pink_Map Native `COLORMAP_PINK` table.
   --  @enum Hot_Map Native `COLORMAP_HOT` table.
   --  @enum Parula_Map Native `COLORMAP_PARULA` table.
   --  @enum Magma_Map Native `COLORMAP_MAGMA` table.
   --  @enum Inferno_Map Native `COLORMAP_INFERNO` table.
   --  @enum Plasma_Map Native `COLORMAP_PLASMA` table.
   --  @enum Viridis_Map Native `COLORMAP_VIRIDIS`: BGR 84,1,68 at index 0 and
   --  BGR 37,231,253 at 255.
   --  @enum Cividis_Map Native `COLORMAP_CIVIDIS` table.
   --  @enum Twilight_Map Native `COLORMAP_TWILIGHT`: indices 0 and 255 both
   --  give BGR 226,217,226.
   --  @enum Twilight_Shifted_Map Native `COLORMAP_TWILIGHT_SHIFTED` table.
   type Built_In_Color_Map is
     (Autumn_Map,
      Bone_Map,
      Jet_Map,
      Winter_Map,
      Rainbow_Map,
      Ocean_Map,
      Summer_Map,
      Spring_Map,
      Cool_Map,
      HSV_Map,
      Pink_Map,
      Hot_Map,
      Parula_Map,
      Magma_Map,
      Inferno_Map,
      Plasma_Map,
      Viridis_Map,
      Cividis_Map,
      Twilight_Map,
      Twilight_Shifted_Map);

   --  Maps Source through a built-in colormap with native cv::applyColorMap.
   --  Nonempty 2-D UInt8 C1 or C3 Source. C1 bytes index the table; C3 is BGR
   --  converted to grayscale first, NOT independent B/G/R maps. Fresh owning
   --  UInt8 C3 BGR result with Source geometry. Logical-row snapshots isolate
   --  Regions and permit Destination = Source. Publication occurs only after
   --  success; failures raise OpenCV.OpenCV_Error and leave Destination
   --  unchanged. Separate input storage is never modified. Destination is
   --  rebound to the result; its previous storage, shallow copies and a
   --  Region's parent are not written.
   --  @param Source Image to map: nonempty 2-D UInt8 C1 (table indices) or C3
   --  (BGR, converted to grayscale first).
   --  @param Destination Receives the fresh UInt8 C3 BGR result with Source's
   --  rows and columns; unchanged on failure. It may be Source.
   --  @param Map Built-in table to apply.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D, not UInt8,
   --  or not C1 or C3; when `Rows * Columns * 3` exceeds 2_147_483_647 or a
   --  snapshot span is not addressable; or when OpenCV fails.
   procedure Apply_Color_Map
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Map         : Built_In_Color_Map);

   --  Maps Source through a caller-supplied BGR table with native
   --  cv::applyColorMap. Source, its grayscale conversion, the fresh UInt8 C3
   --  BGR result and the publication of Destination only after success are as
   --  for the Built_In_Color_Map overload. Lookup_Table must be 2-D UInt8
   --  C3, 256 rows x 1 column (not 1x256). Row I contains the BGR triple for
   --  grayscale byte I, I = 0 .. 255. Custom C1 tables are intentionally
   --  excluded: OpenCV 4.1 returns C3 with them, whereas 4.10/5 return C1. The
   --  table is also snapshotted; noncontiguous Regions and Destination =
   --  Lookup_Table are supported, as are Destination = Source and Source/table
   --  shared storage. No scaling or interpolation is added.
   --  @param Source Image to map: nonempty 2-D UInt8 C1 (table indices) or C3
   --  (BGR, converted to grayscale first).
   --  @param Destination Receives the fresh UInt8 C3 BGR result with Source's
   --  rows and columns; unchanged on failure. It may be Source or
   --  Lookup_Table.
   --  @param Lookup_Table Color table: nonempty 2-D UInt8 C3 of 256 rows and 1
   --  column, row I holding the B, G, R output for grayscale byte I.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D, not UInt8,
   --  or not C1 or C3; when Lookup_Table is not a nonempty 2-D UInt8 C3 Mat
   --  of 256 rows and 1 column; when `Rows * Columns * 3`
   --  exceeds 2_147_483_647 or a snapshot span is not addressable; or when
   --  OpenCV fails.
   procedure Apply_Color_Map
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Lookup_Table : OpenCV.Core.Mat);

   --  Converts every pixel of Source between the color layouts named by
   --  Conversion with native cv::cvtColor. Nonempty 2-D Source, with exactly
   --  the channels named by Conversion. Layout, Gray, XYZ, YCrCb and YUV
   --  accept UInt8/UInt16/Float32; HSV, HLS, Lab and Luv (standard, FULL and
   --  linear-light) accept UInt8/Float32; BGR565/BGR555 and premultiplied
   --  selectors accept UInt8 only. Destination retains Source geometry/depth;
   --  its channel count is fixed by Conversion. Pixel values are not
   --  range-checked or normalized.
   --
   --  Source is read in place and Regions are logical images: only a Region's
   --  own pixels participate. The result is built in private native storage,
   --  and Destination is rebound to it only on success; on failure Destination
   --  is unchanged. The previous Destination storage, its shallow copies and a
   --  Region's parent are never written. Destination may be Source itself or
   --  share Source's storage.
   --  @param Source Image to convert, with exactly the channel count and an
   --  accepted depth of Conversion's source layout.
   --  @param Destination Receives the result: a fresh owning Mat with Source's
   --  rows, columns and depth and the channel count of Conversion's
   --  destination layout. It may be Source.
   --  @param Conversion Source and destination layouts; see Color_Conversion.
   --  @exception OpenCV_Error Raised when Source is empty or not 2-D, has a
   --  channel count other than Conversion's source layout, or has a depth
   --  Conversion does not accept; when `Rows * Columns`, or for HSV, HLS, Lab
   --  and Luv selectors `Columns * 3`, exceeds 2_147_483_647; when a row
   --  stride exceeds the limit of a reachable optional native backend (IPP,
   --  Carotene or FastCV); or when OpenCV fails.
   procedure Convert_Color
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Conversion  : Color_Conversion);

   --  Resamples Source to Output_Size with native cv::resize. The result
   --  has Output_Size.Height rows, Output_Size.Width columns and Source's
   --  depth and channel count; no color conversion occurs. Source must be
   --  a nonempty 2-D Mat of depth UInt8, UInt16, Int16, Float32 or Float64,
   --  and Output_Size must have nonzero width and height. Same-size
   --  resizing copies the source.
   --
   --  Destination is the direct native output: OpenCV reuses its storage
   --  when it already has the result size and type (shallow copies of
   --  Destination and a Region's parent then see the result) and otherwise
   --  rebinds it to new storage. Ada validation and the Linear_Exact layout
   --  preflight raise before Destination is touched.
   --
   --  Linear_Exact is Resize-only fixed-point bilinear interpolation for
   --  UInt8, UInt16, and Int16, with deterministic integer rounding and any
   --  channel count. It is not lossless or mathematically exact, and can
   --  differ from Linear. Float32/Float64 exact requests are rejected
   --  rather than silently falling back to Linear. Native exact 2x
   --  downscaling in both axes may use bit-equivalent Area (except for C2).
   --  An exact Region source uses only its logical pixels. Native signed
   --  coefficient, line-buffer and allocation limits of exact resizing
   --  raise OpenCV_Error.
   --  @param Source Image to resample.
   --  @param Destination Receives the resized image.
   --  @param Output_Size Result columns (Width) and rows (Height).
   --  @param Interpolation Resampling method; every Interpolation_Method
   --  value is accepted, Linear_Exact only for integer sources. Default
   --  Linear.
   --  @exception OpenCV_Error Empty, non-2-D or unsupported-depth
   --  Source, zero Output_Size dimension, Float32/Float64 Linear_Exact
   --  request, exact layout overflow, or an OpenCV failure.
   procedure Resize
     (Source        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method := Linear);

   --  Gaussian_Blur convolves Source with an isotropic Gaussian kernel
   --  (native cv::GaussianBlur): the same Sigma applies along X and Y.
   --  Source must be a non-empty two-dimensional Mat with depth UInt8,
   --  UInt16, Int16, Float32, or Float64. Destination receives Source's
   --  rows, columns, depth, and channel count as a direct native output:
   --  storage that already has that size and type is reused (shallow copies
   --  and a Region's parent see the result); otherwise Destination is
   --  rebound to new storage.
   --  @param Source Image to smooth.
   --  @param Destination Receives the smoothed image.
   --  @param Kernel_Size Kernel width and height in pixels; both positive
   --  and odd.
   --  @param Sigma Gaussian standard deviation in pixels, used for both
   --  axes; positive and finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported-depth Source, a zero or even kernel dimension, a
   --  nonpositive or nonfinite Sigma, Wrap, or a failure reported by OpenCV.
   procedure Gaussian_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Size;
      Sigma       : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Get_Gaussian_Kernel returns an N x 1 single-channel Gaussian coefficient
   --  vector of the requested Depth (native cv::getGaussianKernel), where N
   --  is Kernel_Size, as fresh owning storage. This overload asks OpenCV to
   --  derive sigma from Kernel_Size; there is no public zero or negative
   --  sigma sentinel. Coefficients preserve OpenCV's values and ordering:
   --  they are symmetric and sum to 1 within rounding, and Kernel_Size 1
   --  yields exactly 1.0. The vector may be passed directly to
   --  Sep_Filter_2D as Kernel_X and Kernel_Y.
   --  @param Kernel_Size Number of coefficients N; must be odd.
   --  @param Depth Coefficient depth; Float64_Kernel by default.
   --  @return Fresh N x 1 coefficient vector.
   --  @exception OpenCV_Error Raised for an even Kernel_Size or a
   --  failure reported by OpenCV.
   function Get_Gaussian_Kernel
     (Kernel_Size : Gaussian_Kernel_Size;
      Depth       : Gaussian_Kernel_Depth := Float64_Kernel)
      return OpenCV.Core.Mat;

   --  This overload is the same Get_Gaussian_Kernel generator with an
   --  explicit Sigma: it returns a fresh owning N x 1 single-channel vector
   --  of symmetric Gaussian coefficients of the requested Depth, in
   --  OpenCV's order. Zero and negative values are rejected rather than
   --  switching to automatic sigma. Used as both Sep_Filter_2D kernels, it
   --  gives the Gaussian_Blur result for the same size and Sigma, up to
   --  rounding.
   --  @param Kernel_Size Number of coefficients N; must be odd.
   --  @param Sigma Gaussian standard deviation in coefficient (pixel)
   --  units; must be finite and strictly greater than zero.
   --  @param Depth Coefficient depth; Float64_Kernel by default.
   --  @return Fresh N x 1 coefficient vector.
   --  @exception OpenCV_Error Raised for an even Kernel_Size, a zero,
   --  negative or nonfinite Sigma, or a failure reported by OpenCV.
   function Get_Gaussian_Kernel
     (Kernel_Size : Gaussian_Kernel_Size;
      Sigma       : OpenCV.Float64_Value;
      Depth       : Gaussian_Kernel_Depth := Float64_Kernel)
      return OpenCV.Core.Mat;

   --  Generates a Gabor filter kernel (native cv::getGaborKernel) for use
   --  with Filter_2D: a fresh owning C1 Mat of the requested Depth with
   --  exactly Kernel_Size.Height rows and Kernel_Size.Width columns. For
   --  integer offsets x, y from the center, theta = Orientation_Radians,
   --  lambda = Wavelength, gamma = Aspect_Ratio and psi =
   --  Phase_Offset_Radians, each coefficient is
   --
   --       xr = x * cos (theta) + y * sin (theta)
   --       yr = -x * sin (theta) + y * cos (theta)
   --       v  = exp (-(xr**2 + (gamma * yr)**2) / (2 * Sigma**2)) *
   --              cos (2 * pi * xr / lambda + psi)
   --
   --  Native automatic sizing is deliberately not exposed. Coefficients are
   --  not normalized, and the binding adds no reversal or transposition:
   --  native coordinates (x, y) are stored at row `Height / 2 - y` and
   --  column `Width / 2 - x`, OpenCV's 180-degree coordinate reversal,
   --  which also affects the apparent phase. Extreme finite parameters
   --  retain native IEEE behavior and may produce nonfinite coefficients
   --  through derived expressions; Float32 narrowing can lose precision.
   --  @param Kernel_Size Kernel width and height in pixels; both positive
   --  and odd. There is no automatic-size sentinel.
   --  @param Sigma Standard deviation of the Gaussian envelope along xr, in
   --  pixels; positive and finite.
   --  @param Orientation_Radians Angle theta of the rotated xr axis, along
   --  which the sinusoid varies; finite radians, not normalized.
   --  @param Wavelength Wavelength lambda of the sinusoidal factor, in
   --  pixels; positive and finite.
   --  @param Aspect_Ratio Spatial aspect ratio gamma: the envelope's
   --  standard deviation along yr is `Sigma / Aspect_Ratio`; positive and
   --  finite.
   --  @param Phase_Offset_Radians Phase offset psi of the sinusoid; finite
   --  radians, not normalized. Defaults to pi / 2.
   --  @param Depth Coefficient depth; Float64_Kernel by default.
   --  @return Fresh Height x Width coefficient Mat.
   --  @exception OpenCV_Error Raised for a zero or even dimension, a
   --  nonpositive or nonfinite Sigma, Wavelength or Aspect_Ratio, a
   --  nonfinite angle, an allocation size limit, or a native failure.
   function Get_Gabor_Kernel
     (Kernel_Size          : OpenCV.Size;
      Sigma                : OpenCV.Float64_Value;
      Orientation_Radians  : OpenCV.Float64_Value;
      Wavelength           : OpenCV.Float64_Value;
      Aspect_Ratio         : OpenCV.Float64_Value;
      Phase_Offset_Radians : OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Ada.Numerics.Pi / 2.0);
      Depth                : Gabor_Kernel_Depth := Float64_Kernel)
      return OpenCV.Core.Mat;

   --  Get_Derivative_Kernels generates the separable 1-D Sobel-family
   --  coefficient vectors used by spatial derivatives (native
   --  cv::getDerivKernels); it does not filter an image itself. Kernel_X is
   --  the horizontal/X-direction vector and Kernel_Y is the
   --  vertical/Y-direction vector. Both are independently owned fresh
   --  single-channel column vectors (N x 1) of matching Float32 or Float64
   --  depth. Coefficient order is preserved; the generator does not flip
   --  coefficients. The pair may be passed directly to Sep_Filter_2D:
   --
   --       Kernels :=
   --         Get_Derivative_Kernels
   --           (X_Order     => 1,
   --            Y_Order     => 0,
   --            Kernel_Size => Kernel_3);
   --       Sep_Filter_2D
   --         (Source,
   --          Destination,
   --          Kernel_X          => Kernels.Kernel_X,
   --          Kernel_Y          => Kernels.Kernel_Y,
   --          Destination_Depth => Float32_Depth);
   --
   --  That request yields Kernel_X `[-1, 0, 1]` and Kernel_Y `[1, 2, 1]`.
   --  Kernel_3, Kernel_5, and Kernel_7 use that kernel size in both
   --  directions. Kernel_1 uses OpenCV's special derivative behavior: a
   --  nonzero-order direction has effective length 3, while a zero-order
   --  direction remains a 1-tap identity, so Kernel_X and Kernel_Y lengths
   --  may differ. There is no public FILTER_SCHARR or -1 kernel-size
   --  sentinel; use Get_Scharr_Kernels for Scharr coefficients.
   --  @param X_Order Derivative order along X; strictly less than the
   --  effective Kernel_X length.
   --  @param Y_Order Derivative order along Y; strictly less than the
   --  effective Kernel_Y length. X_Order and Y_Order cannot both be zero.
   --  @param Kernel_Size Sobel aperture selecting the vector lengths;
   --  Kernel_3 by default.
   --  @param Normalization Coefficient scaling; Normalized changes scaling,
   --  not derivative order. Unnormalized by default.
   --  @param Depth Depth of both vectors; Float32_Kernel by default.
   --  @return Fresh Kernel_X/Kernel_Y coefficient pair.
   --  @exception OpenCV_Error Raised when both orders are zero, an
   --  order is not less than its effective length, or OpenCV fails.
   function Get_Derivative_Kernels
     (X_Order       : Derivative_Order;
      Y_Order       : Derivative_Order;
      Kernel_Size   : Sobel_Kernel_Size := Kernel_3;
      Normalization : Derivative_Kernel_Normalization := Unnormalized;
      Depth         : Derivative_Kernel_Depth := Float32_Kernel)
      return Derivative_Kernels;

   --  Get_Scharr_Kernels generates the separable 1-D Scharr first-derivative
   --  coefficient pair for Axis. It does not filter an image itself. Both
   --  returned vectors are independently owned fresh 3 x 1 single-channel
   --  Mats of matching Float32 or Float64 depth. Coefficient order is
   --  preserved and may be passed directly to Sep_Filter_2D. X_Axis maps to
   --  X_Order 1 / Y_Order 0, giving Kernel_X `[-1, 0, 1]` and the smoothing
   --  vector Kernel_Y `[3, 10, 3]`; Y_Axis maps to X_Order 0 / Y_Order 1
   --  and swaps the roles. Normalized changes smoothing-vector scaling (to
   --  `[3, 10, 3] / 32`), not the derivative vector or order. The native
   --  Scharr kernel-size sentinel remains private.
   --  @param Axis Direction of the first derivative.
   --  @param Normalization Smoothing-vector scaling; Unnormalized by
   --  default.
   --  @param Depth Depth of both vectors; Float32_Kernel by default.
   --  @return Fresh Kernel_X/Kernel_Y coefficient pair, each of length 3.
   --  @exception OpenCV_Error Raised for a failure reported by OpenCV.
   function Get_Scharr_Kernels
     (Axis          : Derivative_Axis;
      Normalization : Derivative_Kernel_Normalization := Unnormalized;
      Depth         : Derivative_Kernel_Depth := Float32_Kernel)
      return Derivative_Kernels;

   --  Pyramid_Down performs OpenCV's Gaussian-pyramid downsampling of Source
   --  (native cv::pyrDown). Source must be a non-empty two-dimensional Mat
   --  with depth UInt8, UInt16, Int16, Float32, or Float64. Channel count is
   --  unrestricted. Destination receives Source's depth and channel count
   --  with OpenCV's natural size: Columns = (Source.Columns + 1) / 2 and
   --  Rows = (Source.Rows + 1) / 2. A Region is processed as its own logical
   --  image (OpenCV receives a private copy); parent pixels outside the
   --  Region do not participate.
   --
   --  Destination is a direct native output: storage that already has the
   --  result's size and type is reused (shallow copies and a Region's parent
   --  see the result); otherwise Destination is rebound to new storage.
   --  Direct in-place operation is not supported: a Destination that is
   --  Source or shares or overlaps its storage, including overlapping
   --  Regions, is rejected. Extreme geometries are rejected before native
   --  signed-int pyramid arithmetic can overflow.
   --  @param Source Image to downsample.
   --  @param Destination Receives the half-size image.
   --  @param Border Extrapolation outside Source: Replicate, Reflect,
   --  Reflect_101 (default), or Wrap. Constant_Border is rejected.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported-depth Source, Constant_Border, aliased or overlapping
   --  Source and Destination storage, an unsafe geometry, or a failure
   --  reported by OpenCV.
   procedure Pyramid_Down
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Pyramid_Up performs OpenCV's Gaussian-pyramid upsampling of Source
   --  (native cv::pyrUp). Source must be a non-empty two-dimensional Mat
   --  with depth UInt8, UInt16, Int16, Float32, or Float64. Channel count is
   --  unrestricted. Destination receives Source's depth and channel count
   --  with exactly doubled rows and columns. A Region is processed as its
   --  own logical image, without parent pixels. OpenCV supports only its
   --  default border (Reflect_101) for this operation, so no Border
   --  parameter is exposed. Pyramid_Up after Pyramid_Down is generally a
   --  smoothed reconstruction, not the original image.
   --
   --  Destination is a direct native output: storage that already has the
   --  result's size and type is reused (shallow copies and a Region's parent
   --  see the result); otherwise Destination is rebound to new storage.
   --  Direct in-place operation is not supported: a Destination that is
   --  Source or shares or overlaps its storage, including overlapping
   --  Regions, is rejected. Extreme geometries are rejected before native
   --  signed-int pyramid arithmetic can overflow.
   --  @param Source Image to upsample.
   --  @param Destination Receives the double-size image.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported-depth Source, aliased or overlapping Source and
   --  Destination storage, an unsafe geometry, or a failure reported by
   --  OpenCV.
   procedure Pyramid_Up
     (Source : OpenCV.Core.Mat; Destination : in out OpenCV.Core.Mat);

   --  Pyramid_Up with an explicit Output_Size performs the same Gaussian
   --  upsampling (native cv::pyrUp, default border) to the requested size.
   --  Each extent must equal twice the Source extent or one less than that
   --  (for example 5 -> 9 or 5 -> 10), so every natural Pyramid_Down
   --  geometry, including odd sizes, can be reversed exactly. Other sizes,
   --  including OpenCV's nonportable twice-plus-one extent, are rejected
   --  before any native allocation. The Source contract matches the natural
   --  overload. The result is computed into fresh storage and bound to
   --  Destination only on success; on failure Destination is unchanged.
   --  Destination may therefore share Source storage.
   --  @param Source Image to upsample.
   --  @param Destination Rebound on success to the upsampled image, with
   --  Source's depth and channel count.
   --  @param Output_Size Requested Width (columns) and Height (rows); each
   --  is `2 * N` or `2 * N - 1` for the corresponding Source extent N.
   --  @exception OpenCV_Error Raised for an invalid Source, an
   --  Output_Size extent other than `2 * N` or `2 * N - 1`, an unsafe
   --  geometry, or a failure reported by OpenCV.
   procedure Pyramid_Up
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Output_Size : OpenCV.Size);

   --  Maximum_Pyramid_Level_Count returns the number of distinct natural
   --  Gaussian levels of Source, including level 0: both extents are halved
   --  as (N + 1) / 2 until they both reach 1. For example 1 x 1 -> 1,
   --  8 x 8 -> 4, and 9 x 7 -> 5. Only the geometry is inspected; depth and
   --  channel count are not checked. The result is the largest Level_Count
   --  accepted by Build_Gaussian_Pyramid and Build_Laplacian_Pyramid.
   --  @param Source Non-empty two-dimensional Mat whose rows and columns
   --  are measured.
   --  @return Number of distinct natural levels; at least 1.
   --  @exception OpenCV_Error Raised when Source is empty or not
   --  two-dimensional.
   function Maximum_Pyramid_Level_Count
     (Source : OpenCV.Core.Mat) return Positive;

   --  Build_Gaussian_Pyramid returns Level_Count images indexed
   --  0 .. Level_Count - 1 (native cv::buildPyramid). Level 0 is an
   --  independent copy of Source; each later level is Pyramid_Down of the
   --  previous level with Border. Every level owns independent storage
   --  shared with neither Source nor another level. Source follows the
   --  Pyramid_Down contract (UInt8, UInt16, Int16, Float32, or Float64; any
   --  channel count). A Region is processed as its own logical image (it is
   --  cloned first); parent pixels never participate. The whole chain is
   --  checked for native signed-int overflow before any level is built.
   --  @param Source Image that forms level 0.
   --  @param Level_Count Total number of levels, including level 0; must
   --  not exceed Maximum_Pyramid_Level_Count (Source).
   --  @param Border Extrapolation for every downsampling step: Replicate,
   --  Reflect, Reflect_101 (default), or Wrap. Constant_Border is rejected.
   --  @return Fresh array of Level_Count independent Mats, finest first.
   --  @exception OpenCV_Error Raised for an invalid Source,
   --  Constant_Border, a Level_Count above the distinct level count, an
   --  unsafe geometry, or a failure reported by OpenCV.
   function Build_Gaussian_Pyramid
     (Source      : OpenCV.Core.Mat;
      Level_Count : Positive;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return OpenCV.Core.Mat_Array;

   --  Working floating depth of a Laplacian pyramid. Residuals are never
   --  computed in an integer type, so negative detail coefficients never
   --  saturate.
   --  @enum Automatic_Precision Keeps Float64 sources in Float64 and
   --  promotes every other supported depth to Float32.
   --  @enum Float32_Precision Always Float32, narrowing a Float64 Source.
   --  @enum Float64_Precision Always Float64, for every supported depth.
   type Laplacian_Precision is
     (Automatic_Precision, Float32_Precision, Float64_Precision);

   --  Build_Laplacian_Pyramid converts Source to the selected floating depth
   --  (a private copy of its logical pixels), builds a Gaussian pyramid
   --  G (0 .. N) with Border, where N = Level_Count - 1, and returns
   --  L (0 .. N) where, for I < N,
   --
   --       L (I) = G (I) - Pyramid_Up (G (I + 1),
   --                                   Output_Size => size of G (I))
   --
   --  and the last level is the low-frequency base L (N) = G (N), not a
   --  residual. Pyramid_Up always uses OpenCV's default border. All levels
   --  are Float32 or Float64 with Source's channel count and independent
   --  storage, so callers may edit residuals before reconstruction. Source,
   --  Region, Border, and Level_Count contracts match
   --  Build_Gaussian_Pyramid.
   --  @param Source Image to decompose.
   --  @param Level_Count Total number of levels including the base; must
   --  not exceed Maximum_Pyramid_Level_Count (Source).
   --  @param Border Extrapolation of the Gaussian downsampling steps:
   --  Replicate, Reflect, Reflect_101 (default), or Wrap. Constant_Border
   --  is rejected.
   --  @param Precision Working floating depth of every level;
   --  Automatic_Precision by default.
   --  @return Fresh array indexed 0 .. Level_Count - 1: residuals finest
   --  first, then the low-frequency base.
   --  @exception OpenCV_Error Raised for an invalid Source,
   --  Constant_Border, a Level_Count above the distinct level count, an
   --  unsafe geometry, or a failure reported by OpenCV.
   function Build_Laplacian_Pyramid
     (Source      : OpenCV.Core.Mat;
      Level_Count : Positive;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101;
      Precision   : Laplacian_Precision := Automatic_Precision)
      return OpenCV.Core.Mat_Array;

   --  Reconstruct_Laplacian_Pyramid inverts Build_Laplacian_Pyramid.
   --  Starting from a copy of the last level, each step towards the first
   --  level computes
   --
   --       Current := Pyramid_Up (Current, size of Level) + Level
   --
   --  An unmodified pyramid reconstructs the floating working copy of its
   --  Source to normal floating-point tolerance, including odd sizes. The
   --  result is an independent Mat of the pyramid's floating depth; it is
   --  not narrowed to any original integer depth (use Convert_To
   --  explicitly). Input levels are never modified.
   --  @param Pyramid Levels read in array iteration order as fine-to-coarse
   --  levels, with any index bounds. It must be non-empty; every level must
   --  be a non-empty two-dimensional Mat of one common depth (Float32 or
   --  Float64) and one common channel count, and each following level must
   --  have Rows = (Previous.Rows + 1) / 2 and Columns =
   --  (Previous.Columns + 1) / 2. The whole array is validated before any
   --  work begins.
   --  @return Fresh reconstructed image with the first level's geometry,
   --  depth and channel count.
   --  @exception OpenCV_Error Raised when Pyramid violates its
   --  contract or OpenCV reports a failure.
   function Reconstruct_Laplacian_Pyramid
     (Pyramid : OpenCV.Core.Mat_Array) return OpenCV.Core.Mat;

   --  Highest Gaussian pyramid level processed by Pyramid_Mean_Shift_Filter;
   --  0 filters Source directly without a pyramid. A level N above zero
   --  builds N further natural half-size levels and starts filtering at
   --  the top with `Spatial_Radius / 2**N`.
   subtype Mean_Shift_Pyramid_Level is Natural range 0 .. 8;

   --  Maximum number of mean-shift iterations per pixel, 1 through 100;
   --  the type of Mean_Shift_Termination.Maximum_Iterations.
   subtype Mean_Shift_Iteration_Limit is Positive range 1 .. 100;

   --  Per-pixel mean-shift stopping rule. Iteration stops after
   --  Maximum_Iterations or once the combined spatial/color shift is at
   --  most Epsilon. Both criteria are always active (native MAX_ITER and
   --  EPS). Epsilon must be finite and nonnegative; Pyramid_Mean_Shift_Filter
   --  checks it. The defaults, 5 iterations and 1.0, match OpenCV's own.
   --  @field Maximum_Iterations Iteration limit for each pixel's mean-shift
   --  (1 through 100; default 5).
   --  @field Epsilon Shift threshold (default 1.0). The native shift measure
   --  is the absolute X plus absolute Y displacement in pixels plus the
   --  squared RGB color change of one iteration.
   type Mean_Shift_Termination is record
      Maximum_Iterations : Mean_Shift_Iteration_Limit := 5;
      Epsilon            : OpenCV.Float64_Value := 1.0;
   end record;

   --  Pyramid_Mean_Shift_Filter performs OpenCV's mean-shift filtering
   --  (posterization) stage of mean-shift segmentation (native
   --  cv::pyrMeanShiftFiltering). Each pixel is replaced by the color at
   --  which a joint spatial/color mean-shift converges: pixels within
   --  Spatial_Radius in space and Color_Radius in RGB distance are averaged
   --  repeatedly. The result is a filtered color image; it does not produce
   --  connected-region labels.
   --
   --  Source must be a non-empty two-dimensional UInt8 C3 Mat. With
   --  Maximum_Pyramid_Level > 0, OpenCV first filters a natural Gaussian
   --  pyramid from its top level and propagates results downward, halving
   --  Spatial_Radius per level; results may differ from level-0 filtering.
   --  Every generated level must stay at least 2 x 2: requests whose top
   --  level would be smaller are rejected (never silently reduced) because
   --  OpenCV's propagation performs invalid pointer arithmetic on such tiny
   --  levels.
   --
   --  Source is snapshotted into a private packed copy, so a Region is its
   --  own logical image and parent pixels never participate; Source is not
   --  modified. The result is computed into fresh storage and bound to
   --  Destination only on success; on failure Destination is unchanged.
   --  Destination may be Source itself or share its storage. Requests whose
   --  native signed-int radius rounding, row offsets, window accumulators,
   --  or stopping expression could overflow are rejected before native
   --  execution.
   --  @param Source UInt8 C3 image to filter.
   --  @param Destination Rebound on success to a fresh UInt8 C3 image with
   --  Source's rows and columns.
   --  @param Spatial_Radius Spatial window radius in pixels at level 0;
   --  must be finite and positive (OpenCV raises each level's effective
   --  radius to at least 1).
   --  @param Color_Radius Color window radius as a Euclidean RGB distance;
   --  must be finite and nonnegative, and 0 admits only identical colors.
   --  @param Maximum_Pyramid_Level Highest pyramid level processed, 1 by
   --  default; 0 filters Source directly without a pyramid.
   --  @param Termination Per-pixel iteration limit and shift threshold;
   --  Termination.Epsilon must be finite and nonnegative.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  non-UInt8 C3 Source, an invalid radius or Epsilon, a generated level
   --  smaller than 2 x 2, a native arithmetic overflow risk, or a failure
   --  reported by OpenCV.
   procedure Pyramid_Mean_Shift_Filter
     (Source                : OpenCV.Core.Mat;
      Destination           : in out OpenCV.Core.Mat;
      Spatial_Radius        : OpenCV.Float64_Value;
      Color_Radius          : OpenCV.Float64_Value;
      Maximum_Pyramid_Level : Mean_Shift_Pyramid_Level := 1;
      Termination           : Mean_Shift_Termination :=
        (Maximum_Iterations => 5, Epsilon => 1.0));

   --  Match_Template slides Template over Source and writes a score map to
   --  Destination: the score at (X, Y) compares Template with the Source
   --  window whose top-left pixel is (X, Y). Source and Template must each
   --  be a non-empty two-dimensional Mat of depth UInt8 or Float32 with 1 to
   --  4 channels, and they must share the same depth and channel count.
   --  Template must fit entirely inside Source: Template.Rows <= Source.Rows
   --  and Template.Columns <= Source.Columns. A Template equal in size to
   --  Source is valid. Multi-channel inputs are combined into one score per
   --  location; they are not converted to grayscale. For Squared_Difference
   --  and Normalized_Squared_Difference the best match is the minimum score;
   --  for the other four methods the best match is the maximum. Use
   --  OpenCV.Core.Min_Max_Loc on Destination to recover those extrema; the
   --  extremum location is the best match's top-left pixel in Source.
   --
   --  Destination receives a Float32 C1 Mat of
   --  `Rows = Source.Rows - Template.Rows + 1` and
   --  `Columns = Source.Columns - Template.Columns + 1` as direct native
   --  output: OpenCV reuses Destination's storage when it already has that
   --  size and type (shallow copies of Destination and a Region's parent then
   --  see the result) and otherwise rebinds Destination to new storage, so
   --  callers need not preallocate it. Source and Template are read-only and
   --  may share storage, including the same Mat or a Template that is a
   --  Region of Source. Destination must not share storage with Source or
   --  Template: the same Mat, or a Destination whose data starts at Source's
   --  or Template's data, is rejected; other overlaps are not detected.
   --  Inputs are validated before OpenCV runs. Contract violations and
   --  failures reported by OpenCV raise OpenCV.OpenCV_Error.
   --  @param Source Image searched: nonempty 2-D UInt8 or Float32 with 1 to
   --  4 channels.
   --  @param Template Patch compared at every placement: same depth and
   --  channel count as Source, and no larger than Source in either
   --  dimension.
   --  @param Destination Receives the Float32 C1 score map by direct native
   --  output; must not share storage with Source or Template.
   --  @param Method Comparison to compute, with no default; see
   --  Template_Matching_Method for score meanings and best-match extrema.
   --  @exception OpenCV_Error Raised for an empty or non-2-D Source
   --  or Template, an unsupported depth or channel count, mismatched Source
   --  and Template types, a Template larger than Source, a Destination
   --  sharing Source or Template storage, or an OpenCV failure.
   procedure Match_Template
     (Source      : OpenCV.Core.Mat;
      Template    : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Method      : Template_Matching_Method);

   --  Masked Match_Template scores only the Template pixels that Mask
   --  includes, otherwise sliding Template over Source like the unmasked
   --  overload. Masked matching accepts nonempty 2-D UInt8 C1 inputs
   --  (Source, Template and Mask). Mask must match Template dimensions and
   --  Template must fit Source. A zero mask byte excludes a pixel; every
   --  nonzero mask byte (1, 127 and 255 alike) includes a pixel with weight
   --  one. Supported methods are exactly Squared_Difference (the default),
   --  Normalized_Squared_Difference, Cross_Correlation,
   --  Normalized_Cross_Correlation and Correlation_Coefficient;
   --  Normalized_Correlation_Coefficient (TM_CCOEFF_NORMED) is not
   --  supported and raises OpenCV_Error. Intensities stay in original UInt8
   --  units (0 .. 255); the binding passes owning unscaled Float32 copies
   --  and an exact 0/1 Float32 mask, avoiding OpenCV 4.1's UInt8 scaling by
   --  1/255.
   --
   --  Private logical snapshots isolate Regions and shared storage: only
   --  logical pixels are read, parent pixels never participate, and inputs
   --  are unchanged. Destination receives fresh owning Float32 C1 storage
   --  only on success, sized Source minus Template plus one
   --  (`Source.Rows - Template.Rows + 1` rows by
   --  `Source.Columns - Template.Columns + 1` columns); on failure it is
   --  unchanged, and its old storage is never reused. Distinct Mat headers
   --  that share pixel storage with an input are supported, but the same Mat
   --  object as Destination and as an input is rejected. Snapshot cost is
   --  linear in input pixels. Requests whose native correlation arithmetic
   --  or byte extents cannot be represented are rejected before native
   --  execution; this includes a Template area above `INT_MAX / 4` for
   --  Cross_Correlation and for the OpenCV 4.1 compositions below.
   --
   --  Squared_Difference scores are unnormalized sums of squared
   --  differences (lower is better); an all-zero mask yields zero scores.
   --
   --  Cross_Correlation is the unnormalized sum of included intensity
   --  products in original UInt8 units: choose the maximum-scoring location.
   --  It supports black Templates and all-zero masks, with zero correlation.
   --  Native unmasked correlation uses an owning zeroed Float32 Template on
   --  every supported OpenCV version. Scores retain native rounding.
   --
   --  Normalized_Cross_Correlation scores are native cosine similarities
   --  (higher is better) and require at least one pixel where both Mask and
   --  Template are nonzero. Ideal defined scores lie in [0, 1]; native
   --  rounding is retained, including values slightly outside that interval.
   --  A Scene (Source) window whose included samples are all zero receives
   --  exact Float32 +0.0 through a binding-owned compatibility rule.
   --  Positive-energy windows preserve native scores without clipping or
   --  nonfinite repair.
   --
   --  Normalized_Squared_Difference is the included squared error divided by
   --  `sqrt (template energy * scene energy)`. Lower is better, and a perfect
   --  match is zero. Scores are not clamped to [0, 1]. The method requires
   --  positive masked Template energy, at least one pixel where both Mask
   --  and Template are nonzero; an all-zero mask is rejected. A Scene window
   --  whose included samples are all zero receives exact Float32'Last
   --  (IEEE 16#7F7F_FFFF#), a finite worst-match sentinel. That is not the
   --  NCC +0.0 rule: zero would rank the undefined window as a perfect match.
   --  OpenCV 4.10 and 5 call native masked TM_SQDIFF_NORMED. OpenCV 4.1
   --  composes native masked SQDIFF, native Scene-energy correlation, and
   --  native normalization. Positive-energy scores are not repaired; a
   --  nonfinite one raises OpenCV_Error instead of being published.
   --
   --  The zero-window check of both normalized methods adds packed Scene
   --  support and one output-row bitset; work is proportional to
   --  `output rows * active mask pixels * output columns / 64`.
   --
   --  Correlation_Coefficient is the unnormalized masked covariance numerator
   --  `R = Sum(M*T*I) - Sum(M*T)*Sum(M*I)/Sum(M)`: both means are taken over
   --  included pixels only. It is mean-centered but not scale-normalized, so
   --  it is not a Pearson coefficient and is not limited to [-1, 1]. Higher
   --  is better. Scores may be positive, zero or negative (an inverted
   --  pattern scores negative), and a score near zero is not a landmark.
   --  Adding a constant offset to Source or Template leaves the ideal score
   --  unchanged; Float32 cancellation leaves a small error, so compare with
   --  a tolerance that scales with the correlation magnitude, not exactly.
   --  Multiplying intensities by a positive factor scales the score. A
   --  constant included Template, a constant Scene window, and a single
   --  included pixel all have ideal score zero and are accepted. An all-zero
   --  mask has an undefined mean and is rejected. OpenCV 4.10 and 5 call
   --  native masked TM_CCOEFF. OpenCV 4.1 composes the same result from
   --  native unmasked correlation of the centered Template and of the mask,
   --  including the native residual-mean correction. Scores retain native
   --  rounding without clamping. Example:
   --
   --     Match_Template
   --       (Scene, Patch, Mask, Scores, Correlation_Coefficient);
   --     Best := OpenCV.Core.Min_Max_Loc (Scores).Maximum_Location;
   --     --  Best is the best match; an offset Scene still finds it.
   --
   --  TM_CCOEFF_NORMED and contract violations raise OpenCV_Error.
   --  @param Source Image searched (the Scene): nonempty 2-D UInt8 C1.
   --  @param Template Patch compared at every placement: nonempty 2-D UInt8
   --  C1, no larger than Source in either dimension.
   --  @param Mask Pixel selector with Template's dimensions: nonempty 2-D
   --  UInt8 C1, zero excludes and nonzero includes with weight one.
   --  @param Destination Rebound to the fresh Float32 C1 score map only on
   --  success; unchanged on failure.
   --  @param Method One of the five supported methods; default
   --  Squared_Difference.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 input, a Mask whose dimensions differ from Template's, a
   --  Template larger than Source, Normalized_Correlation_Coefficient, no
   --  pixel with nonzero Mask and Template (normalized methods), an all-zero
   --  Mask (Correlation_Coefficient), Destination being the same Mat as an
   --  input, unrepresentable native arithmetic, a nonfinite normalized
   --  squared-difference score, or an OpenCV failure.
   procedure Match_Template
     (Source      : OpenCV.Core.Mat;
      Template    : OpenCV.Core.Mat;
      Mask        : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Method      : Template_Matching_Method := Squared_Difference);

   --  Warp_Affine applies a 2x3 affine Transform to Source with native
   --  cv::warpAffine and writes the warped image to Destination. Source must
   --  be a nonempty 2-D Mat of depth UInt8, UInt16, Int16, Float32, or
   --  Float64 with 1 to 4 channels. Transform must be a nonempty 2-D 2x3
   --  single-channel Mat of depth Float32 or Float64 whose six coefficients
   --  are all finite:
   --
   --     [ M00 M01 M02 ]
   --     [ M10 M11 M12 ]
   --
   --  The result has Rows = Output_Size.Height, Columns = Output_Size.Width,
   --  and Source's depth and channel count; its geometry is not inferred
   --  from Source and no color conversion occurs. Destination is the direct
   --  native output: OpenCV reuses its storage when it already has that
   --  size and type (shallow copies of Destination and a Region's parent
   --  then see the result) and otherwise rebinds it to new storage, so
   --  callers do not need to preallocate it. Rejected arguments leave
   --  Destination unchanged. Source and Transform are read-only and may
   --  share storage. Destination must not share storage with Source or
   --  Transform; the same Mat or the same data start is rejected. Direct
   --  in-place operation is not supported.
   --  @param Source Image to warp.
   --  @param Transform 2x3 affine coefficient matrix, interpreted according
   --  to Mapping.
   --  @param Destination Receives the warped image.
   --  @param Output_Size Result columns (Width) and rows (Height); both
   --  must be nonzero.
   --  @param Interpolation Nearest_Neighbor or Linear (the default); Cubic,
   --  Area, Lanczos_4 and Linear_Exact are rejected.
   --  @param Mapping Source_To_Destination (the default) is the usual
   --  forward mapping; Destination_To_Source treats Transform as already
   --  inverted.
   --  @param Border Constant_Border (the default) or Replicate; Reflect,
   --  Reflect_101 and Wrap are rejected.
   --  @param Border_Value Fill value for Constant_Border: C1 uses
   --  Component_0, C2 uses Components 0..1, C3 uses 0..2, and C4 uses 0..3.
   --  Ignored for Replicate. Default all zero.
   --  @exception OpenCV_Error Invalid Source or Transform, nonfinite
   --  coefficient, zero Output_Size dimension, unsupported Interpolation or
   --  Border, Destination sharing storage with an input, or an OpenCV
   --  failure.
   procedure Warp_Affine
     (Source        : OpenCV.Core.Mat;
      Transform     : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method := Linear;
      Mapping       : Affine_Mapping_Direction := Source_To_Destination;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  Warp_Perspective applies a 3x3 projective Transform to Source with
   --  native cv::warpPerspective and writes the warped image to Destination.
   --  Source must be a nonempty 2-D Mat of depth UInt8, UInt16, Int16,
   --  Float32, or Float64 with 1 to 4 channels. Transform must be a
   --  nonempty 2-D 3x3 single-channel Mat of depth Float32 or Float64:
   --
   --     [ M00 M01 M02 ]
   --     [ M10 M11 M12 ]
   --     [ M20 M21 M22 ]
   --
   --  With Destination_To_Source, Destination pixel (x, y) samples Source at
   --
   --     X = (M00 * x + M01 * y + M02) / (M20 * x + M21 * y + M22)
   --     Y = (M10 * x + M11 * y + M12) / (M20 * x + M21 * y + M22)
   --
   --  Singular or poorly conditioned matrices are not rejected merely for
   --  being singular; all nine coefficients must be finite. The result has
   --  Rows = Output_Size.Height, Columns = Output_Size.Width, and Source's
   --  depth and channel count; no color conversion occurs. Destination is
   --  the direct native output: OpenCV reuses its storage when it already
   --  has that size and type (shallow copies of Destination and a Region's
   --  parent then see the result) and otherwise rebinds it to new storage,
   --  so callers do not need to preallocate it. Rejected arguments leave
   --  Destination unchanged. Source and Transform are read-only and may
   --  share storage. Destination must not share storage with Source or
   --  Transform; the same Mat or the same data start is rejected. Direct
   --  in-place operation is not supported.
   --  @param Source Image to warp.
   --  @param Transform 3x3 projective coefficient matrix, interpreted
   --  according to Mapping.
   --  @param Destination Receives the warped image.
   --  @param Output_Size Result columns (Width) and rows (Height); both
   --  must be nonzero.
   --  @param Interpolation Nearest_Neighbor or Linear (the default); Cubic,
   --  Area, Lanczos_4 and Linear_Exact are rejected.
   --  @param Mapping Source_To_Destination (the default) is the usual
   --  forward mapping; Destination_To_Source treats Transform as already
   --  inverted.
   --  @param Border Constant_Border (the default) or Replicate; Reflect,
   --  Reflect_101 and Wrap are rejected.
   --  @param Border_Value Fill value for Constant_Border: C1 uses
   --  Component_0, C2 uses Components 0..1, C3 uses 0..2, and C4 uses 0..3.
   --  Ignored for Replicate. Default all zero.
   --  @exception OpenCV_Error Invalid Source or Transform, nonfinite
   --  coefficient, zero Output_Size dimension, unsupported Interpolation or
   --  Border, Destination sharing storage with an input, or an OpenCV
   --  failure.
   procedure Warp_Perspective
     (Source        : OpenCV.Core.Mat;
      Transform     : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Output_Size   : OpenCV.Size;
      Interpolation : Interpolation_Method := Linear;
      Mapping       : Warp_Mapping_Direction := Source_To_Destination;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  Converts between Cartesian and polar images with native
   --  cv::warpPolar. Polar output X is radial rho and Y is angular phi (one
   --  revolution). Linear rho follows distance; logarithmic rho follows
   --  `log(distance + 1)`. Maximum_Radius (or its logarithm) spans the polar
   --  image width: Output_Size.Width in forward mode, Source.Columns in
   --  inverse mode. In forward mode Center is relative to the Source view
   --  (Region-local); in inverse mode Source is the polar image and Center
   --  is relative to the requested Cartesian destination. Off-image centers
   --  are allowed within the generated-map arithmetic limits.
   --
   --  Source must be nonempty 2-D UInt8/UInt16/Int16/Float32/Float64,
   --  C1..C4, with Rows and Columns < 32767; inverse Source.Rows must be
   --  <= 32764 because OpenCV adds a wrap row at each end. In inverse mode
   --  those wrap rows come from the Region itself, never its parent.
   --  Outliers are zero-filled. Generated Float32 map coordinates are
   --  preflighted against native remap rounding limits, so extreme
   --  centers or radii, tiny inverse logarithmic scales and unsafe source
   --  strides are rejected.
   --
   --  Destination must not overlap Source, including Regions and aliases.
   --  Successful calls replace Destination with a fresh result of
   --  Output_Size and Source's type, computed privately and published only
   --  on success; failed calls leave it unchanged. Round trips are
   --  interpolated and are not guaranteed to reproduce the input exactly.
   --  @param Source Cartesian image (forward) or polar image (inverse).
   --  @param Destination Receives the transformed image.
   --  @param Center Transform center in pixels (X = column, Y = row); must
   --  be finite.
   --  @param Maximum_Radius Source radius mapped across the polar width;
   --  must be finite and > 0 (linear) or > 1 (logarithmic).
   --  @param Output_Size Explicit result columns (Width) and rows
   --  (Height), each nonzero and < 32767. In forward mode Width counts rho
   --  samples and Height angle samples.
   --  @param Mapping Linear_Polar (the default) or Logarithmic_Polar.
   --  @param Direction Cartesian_To_Polar (the default) or
   --  Polar_To_Cartesian.
   --  @param Interpolation Nearest_Neighbor, Linear (the default), Cubic or
   --  Lanczos_4; Area and Linear_Exact are rejected.
   --  @exception OpenCV_Error Invalid Source type or size, invalid
   --  Output_Size, nonfinite Center, invalid Maximum_Radius, unsupported
   --  Interpolation, unsafe generated coordinates or strides, Destination
   --  overlapping Source, or an OpenCV failure.
   procedure Warp_Polar
     (Source         : OpenCV.Core.Mat;
      Destination    : in out OpenCV.Core.Mat;
      Center         : OpenCV.Float32_Point;
      Maximum_Radius : OpenCV.Float64_Value;
      Output_Size    : OpenCV.Size;
      Mapping        : Polar_Mapping := Linear_Polar;
      Direction      : Polar_Direction := Cartesian_To_Polar;
      Interpolation  : Interpolation_Method := Linear);

   --  Remap applies an absolute source-coordinate map with native cv::remap.
   --  Destination(Row, Column) samples Source at X = Map_X(Row, Column)
   --  (source column) and Y = Map_Y(Row, Column) (source row). Relative maps
   --  are not bound. Source must be a nonempty 2-D Mat of depth UInt8,
   --  UInt16, Int16, Float32, or Float64 with 1 to 4 channels and with Rows
   --  and Columns less than 32767. Map_X and Map_Y must be nonempty 2-D
   --  single-channel Float32 Mats of identical size, each with Rows and
   --  Columns less than 32767; map geometry need not match Source. Every
   --  map coordinate V must be finite and safely convertible through native
   --  integer coordinate tables: `abs (V) < 2.0**31` for Nearest_Neighbor
   --  and `abs (32.0 * V) < 2.0**31` for the other methods, evaluated in
   --  Float32. Coordinates may lie outside Source; Border then supplies the
   --  samples.
   --
   --  The result is computed privately; only after native Remap succeeds
   --  is Destination replaced with fresh storage of Rows = Map_X.Rows,
   --  Columns = Map_X.Columns, and Source's depth and channel count.
   --  Callers do not need to preallocate Destination, and failed calls
   --  leave it unchanged. No color conversion occurs. Source, Map_X, and
   --  Map_Y are read-only and may share storage. Destination must not share
   --  storage with Source, Map_X, or Map_Y; the same Mat or the same data
   --  start is rejected. Direct in-place operation is not supported.
   --  Native stride limits also raise OpenCV_Error: a UInt8 C1/C3/C4 Linear
   --  Source row stride above `2**31 - 1` or exactly 32768 bytes, and, for
   --  Constant_Border calls that OpenCV 4.x may route to IPP, Source, map or
   --  result byte strides above `2**31 - 1`.
   --  @param Source Image to sample.
   --  @param Map_X Source column (X) coordinate for each Destination pixel.
   --  @param Map_Y Source row (Y) coordinate for each Destination pixel.
   --  @param Destination Receives the remapped image.
   --  @param Interpolation Nearest_Neighbor, Linear (the default), Cubic, or
   --  Lanczos_4; Area and Linear_Exact are rejected.
   --  @param Border Any Border_Kind value; default Constant_Border.
   --  @param Border_Value Fill value for Constant_Border: C1 uses
   --  Component_0, C2 uses Components 0..1, C3 uses 0..2, and C4 uses 0..3.
   --  Ignored for other borders. Default all zero.
   --  @exception OpenCV_Error Invalid Source or maps, unsafe map
   --  coordinate or stride, unsupported Interpolation, Destination sharing
   --  storage with an input, or an OpenCV failure.
   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Map_X         : OpenCV.Core.Mat;
      Map_Y         : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  Remap with one absolute Float32 C2 map, which stores X (source
   --  column) in component 0 and Y (source row) in component 1. It must be
   --  nonempty, two-dimensional, and have both dimensions < 32767; its
   --  coordinates obey the finiteness and rounding limits of the
   --  separate-map overload. On success Destination is replaced with fresh
   --  storage of Map_XY's rows and columns and Source's depth and channel
   --  count. The Source, interpolation, borders, alias, UInt8 Linear stride
   --  and failure contracts of the separate-map overload also apply; its
   --  IPP stride checks do not.
   --  @param Source Image to sample.
   --  @param Map_XY Source (X, Y) coordinates for each Destination pixel.
   --  @param Destination Receives the remapped image.
   --  @param Interpolation Nearest_Neighbor, Linear (the default), Cubic, or
   --  Lanczos_4; Area and Linear_Exact are rejected.
   --  @param Border Any Border_Kind value; default Constant_Border.
   --  @param Border_Value Fill value for Constant_Border, used per channel
   --  as in the separate-map overload; ignored for other borders.
   --  @exception OpenCV_Error Invalid Source or Map_XY, unsafe map
   --  coordinate or stride, unsupported Interpolation, Destination sharing
   --  storage with an input, or an OpenCV failure.
   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Map_XY        : OpenCV.Core.Mat;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  Native fixed-point absolute remap maps, created by
   --  Convert_Remap_To_Fixed for repeated use with the fixed-map Remap.
   --  Coordinates are Int16 C2; Coefficients are UInt16 C1 for interpolation
   --  or empty for nearest-only maps. The invariant-bearing pair is private,
   --  so neither part can be mutated independently. A default-initialized
   --  value holds no maps (Is_Empty) and is rejected by Remap and by the
   --  conversions back to Float32.
   type Fixed_Remap_Maps is private;

   --  Reports whether Maps holds no coordinate map, as a default-initialized
   --  Fixed_Remap_Maps value does.
   --  @param Maps Fixed maps to inspect.
   --  @return True when the Int16 coordinate map is empty.
   function Is_Empty (Maps : Fixed_Remap_Maps) return Boolean;

   --  Reports whether Maps is a nonempty nearest-only map: coordinates
   --  without interpolation coefficients, usable only with Nearest_Neighbor.
   --  @param Maps Fixed maps to inspect.
   --  @return True when coordinates are present and coefficients absent;
   --  False for empty and for coefficient-bearing maps.
   function Is_Nearest_Only (Maps : Fixed_Remap_Maps) return Boolean;

   --  A pair of separate absolute Float32 C1 remap maps, as accepted by the
   --  separate-map Remap and returned by Separate_Remap_Map and
   --  Convert_Remap_To_Separate_Float (both components then fresh owning
   --  storage of identical geometry).
   --  @field Map_X Source column (X) coordinate for each Destination pixel.
   --  @field Map_Y Source row (Y) coordinate for each Destination pixel.
   type Float_Remap_Maps is record
      Map_X : OpenCV.Core.Mat;
      Map_Y : OpenCV.Core.Mat;
   end record;

   --  Converts separate absolute Float32 maps to native fixed-point maps
   --  (cv::convertMaps to Int16 C2) for the fixed-map Remap. Map_X and
   --  Map_Y must be nonempty 2-D Float32 C1 Mats of identical geometry
   --  with dimensions < 32767, and their coordinates must satisfy the
   --  rounding limits of the separate-map Remap (the Nearest_Neighbor limit
   --  when Nearest_Neighbor_Only). Conversion to fixed maps quantizes
   --  fractions to 1/32 pixel; nearest-only conversion rounds to integer
   --  coordinates and discards fractions. Int16 coordinate saturation can
   --  lose information. Inputs are unchanged.
   --  @param Map_X Source column (X) coordinates.
   --  @param Map_Y Source row (Y) coordinates.
   --  @param Nearest_Neighbor_Only True omits interpolation coefficients,
   --  producing a nearest-only map; default False.
   --  @return Fresh owning fixed maps with the input geometry.
   --  @exception OpenCV_Error Invalid map type or geometry, unsafe
   --  coordinate, or an OpenCV failure.
   function Convert_Remap_To_Fixed
     (Map_X, Map_Y : OpenCV.Core.Mat; Nearest_Neighbor_Only : Boolean := False)
      return Fixed_Remap_Maps;

   --  Converts one absolute Float32 C2 map (component 0 = X, component 1 =
   --  Y) to native fixed-point maps. Map_XY must be nonempty and 2-D with
   --  dimensions < 32767. Coordinate limits, 1/32-pixel quantization,
   --  nearest-only rounding and Int16 saturation are as for the
   --  separate-map overload. Map_XY is unchanged.
   --  @param Map_XY Source (X, Y) coordinates.
   --  @param Nearest_Neighbor_Only True omits interpolation coefficients,
   --  producing a nearest-only map; default False.
   --  @return Fresh owning fixed maps with Map_XY's geometry.
   --  @exception OpenCV_Error Invalid map type or geometry, unsafe
   --  coordinate, or an OpenCV failure.
   function Convert_Remap_To_Fixed
     (Map_XY : OpenCV.Core.Mat; Nearest_Neighbor_Only : Boolean := False)
      return Fixed_Remap_Maps;

   --  Combines separate Float32 C1 maps into one Float32 C2 map with Map_X
   --  in component 0 and Map_Y in component 1, for the Map_XY Remap. Both
   --  inputs must be nonempty 2-D Float32 C1 Mats of identical geometry
   --  with dimensions < 32767; values are copied without a coordinate
   --  check. Inputs are unchanged.
   --  @param Map_X Source column (X) coordinates.
   --  @param Map_Y Source row (Y) coordinates.
   --  @return Fresh owning Float32 C2 Mat with the input geometry.
   --  @exception OpenCV_Error Invalid map type or geometry, or an
   --  OpenCV failure.
   function Interleave_Remap_Maps
     (Map_X, Map_Y : OpenCV.Core.Mat) return OpenCV.Core.Mat;

   --  Splits a Float32 C2 map into separate Float32 C1 maps: component 0
   --  becomes Map_X and component 1 Map_Y. Map_XY must be nonempty and 2-D
   --  with dimensions < 32767; values are copied without a coordinate
   --  check. Map_XY is unchanged.
   --  @param Map_XY Interleaved source (X, Y) coordinates.
   --  @return Fresh owning Float32 C1 maps with Map_XY's geometry.
   --  @exception OpenCV_Error Invalid map type or geometry, or an
   --  OpenCV failure.
   function Separate_Remap_Map
     (Map_XY : OpenCV.Core.Mat) return Float_Remap_Maps;

   --  Reconstructs one absolute Float32 C2 map (component 0 = X,
   --  component 1 = Y) from fixed maps with native cv::convertMaps.
   --  Coefficient-bearing maps yield coordinates quantized to 1/32 pixel;
   --  nearest-only maps yield their already-rounded integer coordinates.
   --  Maps must not be empty.
   --  @param Maps Fixed maps from Convert_Remap_To_Fixed.
   --  @return Fresh owning Float32 C2 Mat with the maps' geometry.
   --  @exception OpenCV_Error Empty or invalid Maps, or an OpenCV
   --  failure.
   function Convert_Remap_To_Interleaved_Float
     (Maps : Fixed_Remap_Maps) return OpenCV.Core.Mat;

   --  Reconstructs separate absolute Float32 C1 maps from fixed maps with
   --  native cv::convertMaps. Coefficient-bearing maps yield coordinates
   --  quantized to 1/32 pixel; nearest-only maps yield their
   --  already-rounded integer coordinates. Maps must not be empty.
   --  @param Maps Fixed maps from Convert_Remap_To_Fixed.
   --  @return Fresh owning Float32 C1 Map_X and Map_Y with the maps'
   --  geometry.
   --  @exception OpenCV_Error Empty or invalid Maps, or an OpenCV
   --  failure.
   function Convert_Remap_To_Separate_Float
     (Maps : Fixed_Remap_Maps) return Float_Remap_Maps;

   --  Remap with fixed maps from Convert_Remap_To_Fixed, which can be
   --  reused for many frames. Coefficient-bearing maps support
   --  Nearest_Neighbor, Linear, Cubic and Lanczos_4; nearest-only maps support
   --  Nearest_Neighbor exclusively, and empty maps are rejected. On success
   --  Destination is replaced with fresh storage of the maps' rows and
   --  columns and Source's depth and channel count. The Source, border,
   --  alias, UInt8 Linear stride and failure contracts of the separate-map
   --  overload also apply; its Float32 coordinate and IPP stride checks do
   --  not.
   --  @param Source Image to sample.
   --  @param Maps Fixed source-coordinate maps.
   --  @param Destination Receives the remapped image.
   --  @param Interpolation Nearest_Neighbor, Linear (the default), Cubic, or
   --  Lanczos_4 for coefficient-bearing maps; only Nearest_Neighbor for
   --  nearest-only maps. Area and Linear_Exact are rejected.
   --  @param Border Any Border_Kind value; default Constant_Border.
   --  @param Border_Value Fill value for Constant_Border, used per channel
   --  as in the separate-map overload; ignored for other borders.
   --  @exception OpenCV_Error Invalid Source, empty or invalid Maps,
   --  interpolation not supported by Maps, unsafe stride, Destination
   --  sharing storage with an input, or an OpenCV failure.
   procedure Remap
     (Source        : OpenCV.Core.Mat;
      Maps          : Fixed_Remap_Maps;
      Destination   : in out OpenCV.Core.Mat;
      Interpolation : Interpolation_Method := Linear;
      Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value  : OpenCV.Scalar := (others => 0.0));

   --  Median_Blur replaces each Source pixel with the median of its square
   --  Kernel_Size neighborhood (native cv::medianBlur). Source must be a
   --  non-empty two-dimensional Mat with 1, 3, or 4 channels. Kernel sizes 3
   --  and 5 accept UInt8, UInt16, or Float32; larger kernels accept UInt8
   --  only. Channels are filtered independently. OpenCV uses
   --  replicated-border handling internally; no public Border parameter is
   --  exposed.
   --
   --  Destination receives Source's rows, columns, depth, and channel count
   --  as a direct native output: storage that already has that size and
   --  type is reused (shallow copies and a Region's parent see the result);
   --  otherwise Destination is rebound to new storage. Direct in-place
   --  operation (Destination is Source) is supported; Source remains
   --  unchanged when distinct from Destination.
   --  @param Source Image to filter.
   --  @param Destination Receives the median-filtered image.
   --  @param Kernel_Size Side length of the square aperture in pixels; must
   --  be odd (the subtype excludes values below 3).
   --  @exception OpenCV_Error Raised for an empty or non-2-D Source,
   --  a channel count other than 1, 3, or 4, an even Kernel_Size, a depth
   --  not accepted for Kernel_Size, or a failure reported by OpenCV.
   procedure Median_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : Median_Kernel_Size);

   --  Box_Blur replaces each Source pixel with the normalized average of its
   --  Kernel_Size neighborhood (native cv::blur): every coefficient is
   --  `1 / (Width * Height)`. Source must be a non-empty two-dimensional Mat
   --  with depth UInt8, UInt16, Int16, Float32, or Float64. Channels are
   --  processed independently and are not restricted. The kernel uses
   --  OpenCV's centered default anchor; no Anchor parameter is exposed.
   --
   --  Destination receives Source's rows, columns, depth, and channel count
   --  as a direct native output: storage that already has that size and
   --  type is reused (shallow copies and a Region's parent see the result);
   --  otherwise Destination is rebound to new storage. Direct in-place
   --  operation (Destination is Source) is supported; Source remains
   --  unchanged when distinct from Destination.
   --  @param Source Image to average.
   --  @param Destination Receives the box-filtered image.
   --  @param Kernel_Size Neighborhood width and height in pixels; both must
   --  be positive and need not be odd or equal.
   --  @param Border Extrapolation outside Source: Constant_Border (zero
   --  samples), Replicate, Reflect, or Reflect_101 (default). Wrap is
   --  rejected.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported-depth Source, a zero kernel dimension, Wrap, or a failure
   --  reported by OpenCV.
   procedure Box_Blur
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel_Size : OpenCV.Size;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Native cv::boxFilter over Source's logical image (a Region does not
   --  read its parent). Source is nonempty 2-D UInt8, UInt16, Int16, Float32
   --  or Float64; channels are independent. UInt8 accepts all Filter_Depths;
   --  UInt16 accepts Same_Depth or either floating depth; Int16 also accepts
   --  Int16_Depth; floating sources accept either float depth or Same_Depth.
   --  Integer outputs round and saturate using OpenCV's conversions. Floating
   --  outputs retain native rounding, overflow and nonfinite propagation;
   --  incremental sums need not equal independently summed windows.
   --
   --  Destination is rebound to fresh owning storage after success, keeping
   --  Source's dimensions and channels. Distinct overlapping headers are safe;
   --  Source and Destination must not be the same Ada object. Other aliases
   --  of Destination, including a Region's parent, remain unchanged. Invalid
   --  inputs and native failures leave Destination unchanged. Normalized
   --  nonconstant singleton axes use an effective kernel dimension of one.
   --  @param Source Image to filter; preserved.
   --  @param Destination Receives an independently owned result.
   --  @param Kernel_Size Positive rectangle; even sizes allowed.
   --  @param Destination_Depth Output depth; Same_Depth by default.
   --  @param Normalize True computes the mean; False computes the sum.
   --  @param Border Constant_Border (zero), Replicate, Reflect or Reflect_101.
   --  @exception OpenCV_Error Unsupported inputs, Wrap, unsafe native layout
   --  or accumulator arithmetic, identical objects, or native failure.
   procedure Box_Filter
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel_Size       : OpenCV.Size;
      Destination_Depth : Filter_Depth := Same_Depth;
      Normalize         : Boolean := True;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Box_Filter with an explicit nonnegative anchor inside Kernel_Size.
   --  All other semantics and safety limits match the centered overload.
   --  @param Source Image to filter; preserved.
   --  @param Destination Receives an independently owned result.
   --  @param Kernel_Size Positive rectangular neighborhood.
   --  @param Anchor Zero-based kernel position aligned with each output pixel.
   --  @param Destination_Depth Output depth; Same_Depth by default.
   --  @param Normalize True computes the mean; False computes the sum.
   --  @param Border Extrapolation outside the logical image; Wrap is rejected.
   --  @exception OpenCV_Error Invalid anchor or any centered-overload error.
   procedure Box_Filter
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel_Size       : OpenCV.Size;
      Anchor            : OpenCV.Point;
      Destination_Depth : Filter_Depth := Same_Depth;
      Normalize         : Boolean := True;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Bilateral_Filter replaces Destination with an edge-preserving smoothing
   --  of Source (native cv::bilateralFilter). Spatial distance and
   --  pixel/color distance both weight the neighborhood average, so strong
   --  intensity or color discontinuities are preserved more than with a
   --  linear blur. Source must be a non-empty two-dimensional Mat of depth
   --  UInt8 or Float32 with exactly 1 or 3 channels. For 3-channel Sources,
   --  color-distance weighting uses the combined color difference rather
   --  than filtering channels independently. This overload asks OpenCV to
   --  derive the neighborhood diameter from Sigma_Space; there is no public
   --  zero or negative diameter sentinel.
   --
   --  Destination receives Source's rows, columns, depth, and channel count
   --  as a direct native output: storage that already has that size and
   --  type is reused (shallow copies and a Region's parent see the result);
   --  otherwise Destination is rebound to new storage. Direct in-place
   --  operation is not supported: Destination being Source, or a header
   --  whose data starts at Source's first element, is rejected. Source
   --  remains unchanged when Destination is distinct.
   --  @param Source Image to smooth.
   --  @param Destination Receives the filtered image; must not alias Source.
   --  @param Sigma_Color Standard deviation of the intensity/color-distance
   --  weight; a small value preserves discontinuities more. Positive and
   --  finite.
   --  @param Sigma_Space Standard deviation of the spatial-distance weight,
   --  in pixels; it also determines the neighborhood diameter. Positive and
   --  finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported Source, a nonpositive or nonfinite sigma, Wrap, a
   --  Destination aliasing Source, or a failure reported by OpenCV.
   procedure Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Sigma_Color : OpenCV.Float64_Value;
      Sigma_Space : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  This overload is the same Bilateral_Filter operation with an explicit
   --  neighborhood Diameter. Diameter is a positive integer and need not be
   --  odd. OpenCV uses Diameter as the neighborhood size independently of
   --  Sigma_Space; Sigma_Space still weights samples inside that
   --  neighborhood. Source requirements, borders, and the direct native
   --  Destination output match the automatic overload. Direct in-place
   --  operation is not supported.
   --  @param Source UInt8 or Float32 image with 1 or 3 channels to smooth.
   --  @param Destination Receives the filtered image with Source's
   --  geometry and type; must not alias Source.
   --  @param Diameter Neighborhood diameter in pixels; any positive value.
   --  @param Sigma_Color Standard deviation of the intensity/color-distance
   --  weight; positive and finite.
   --  @param Sigma_Space Standard deviation of the spatial-distance weight
   --  in pixels, applied inside the Diameter neighborhood; positive and
   --  finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an invalid Source, a
   --  nonpositive or nonfinite sigma, Wrap, a Destination aliasing Source,
   --  or a failure reported by OpenCV.
   procedure Bilateral_Filter
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Diameter    : Bilateral_Diameter;
      Sigma_Color : OpenCV.Float64_Value;
      Sigma_Space : OpenCV.Float64_Value;
      Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Filter_2D replaces Destination with a linear correlation of Source
   --  against Kernel (native cv::filter2D). This is correlation, not
   --  mathematical convolution: the kernel is not mirrored around the
   --  anchor. For every channel,
   --
   --       Destination (x, y) = Offset + sum over kernel positions (i, j)
   --         of Kernel (i, j) * Source (x + i - Anchor.X, y + j - Anchor.Y)
   --
   --  where i is a kernel column, j a kernel row, and Anchor the kernel
   --  position aligned with the output pixel. This overload uses OpenCV's
   --  centered default anchor; there is no public (-1, -1) sentinel. Source
   --  must be a non-empty two-dimensional Mat of depth UInt8, UInt16, Int16,
   --  Float32, or Float64. Channel count is unrestricted; the same
   --  single-channel Kernel is applied independently to every Source
   --  channel. Kernel dimensions need not be odd, square, or normalized.
   --
   --  Destination receives Source's rows, columns, and channel count, with
   --  the requested depth, as a direct native output: storage that already
   --  has that size and type is reused (shallow copies and a Region's
   --  parent see the result); otherwise Destination is rebound to new
   --  storage. Direct in-place operation is supported when the requested
   --  destination depth matches Source; a depth-changing alias (Destination
   --  is Source or starts at its first element) is rejected. Source remains
   --  unchanged when Destination is distinct.
   --  @param Source Image to filter.
   --  @param Destination Receives the filtered image.
   --  @param Kernel Correlation coefficients: a non-empty two-dimensional
   --  single-channel Float32 or Float64 Mat of any size. It must not share
   --  Destination's storage.
   --  @param Destination_Depth Output depth, Same_Depth by default; the
   --  supported source/destination combinations are those of Sobel and
   --  Laplacian (see Derivative_Depth).
   --  @param Offset Value added to each filtered value; must be finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported Source or Kernel, an unsupported depth combination, a
   --  nonfinite Offset, Wrap, a rejected alias, or a failure reported by
   --  OpenCV.
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
   --  or centered (-1, -1) sentinel in this overload. Source, Kernel, depth,
   --  Offset, border, and direct native Destination rules match the
   --  centered overload. Direct in-place operation is supported when the
   --  requested destination depth matches Source.
   --  @param Source Image to filter.
   --  @param Destination Receives the filtered image.
   --  @param Kernel Non-empty two-dimensional single-channel Float32 or
   --  Float64 correlation coefficients; must not share Destination's
   --  storage.
   --  @param Anchor Kernel position aligned with each output pixel:
   --  column X and row Y within Kernel.
   --  @param Destination_Depth Output depth, Same_Depth by default; see
   --  Derivative_Depth for the supported combinations.
   --  @param Offset Value added to each filtered value; must be finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an Anchor outside Kernel,
   --  any input rejected by the centered overload, or a failure reported by
   --  OpenCV.
   procedure Filter_2D
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Kernel            : OpenCV.Core.Mat;
      Anchor            : OpenCV.Point;
      Destination_Depth : Filter_Depth := Same_Depth;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Sep_Filter_2D replaces Destination with a separable linear filter of
   --  Source (native cv::sepFilter2D). Every Source row is filtered with
   --  Kernel_X, then every intermediate column is filtered with Kernel_Y,
   --  and Offset is added to the final value. Coefficient order is
   --  preserved; neither kernel is flipped. Source must be a non-empty
   --  two-dimensional Mat of depth UInt8, UInt16, Int16, Float32, or
   --  Float64. Channel count is unrestricted; the same Kernel_X and Kernel_Y
   --  pair is applied independently to every Source channel. Kernel lengths
   --  need not be odd, equal, normalized, or symmetric. Kernel_X and
   --  Kernel_Y must share the same floating-point depth because native
   --  OpenCV requires a common kernel type; they may share storage with each
   --  other. This overload uses OpenCV's centered default anchor; there is
   --  no public (-1, -1) sentinel.
   --
   --  Destination receives Source's rows, columns, and channel count, with
   --  the requested depth, as a direct native output: storage that already
   --  has that size and type is reused (shallow copies and a Region's
   --  parent see the result); otherwise Destination is rebound to new
   --  storage. Direct in-place operation is supported when the requested
   --  destination depth matches Source; a depth-changing alias (Destination
   --  is Source or starts at its first element) is rejected. Source remains
   --  unchanged when Destination is distinct.
   --  @param Source Image to filter.
   --  @param Destination Receives the filtered image.
   --  @param Kernel_X Row (X) coefficients: a non-empty two-dimensional
   --  single-channel Float32 or Float64 vector, one row or one column. It
   --  must not share Destination's storage.
   --  @param Kernel_Y Column (Y) coefficients with the same requirements
   --  and the same depth as Kernel_X.
   --  @param Destination_Depth Output depth, Same_Depth by default, using
   --  the same supported source/destination combinations as Filter_2D (see
   --  Derivative_Depth).
   --  @param Offset Value added to each filtered value; must be finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported Source, a kernel that is not a non-empty Float32 or
   --  Float64 C1 vector, kernels of different depths, an unsupported depth
   --  combination, a nonfinite Offset, Wrap, a rejected alias, or a failure
   --  reported by OpenCV.
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
   --  strictly less than the corresponding logical length. There is no
   --  public mixed or centered (-1, -1) sentinel in this overload. Source,
   --  kernel, depth, Offset, border, and direct native Destination rules
   --  match the centered overload. Direct in-place operation is supported
   --  when the requested destination depth matches Source.
   --  @param Source Image to filter.
   --  @param Destination Receives the filtered image.
   --  @param Kernel_X Row (X) coefficients: a non-empty single-channel
   --  Float32 or Float64 row or column vector, not sharing Destination's
   --  storage.
   --  @param Kernel_Y Column (Y) coefficients with the same requirements
   --  and the same depth as Kernel_X.
   --  @param Anchor Index into Kernel_X (X) and Kernel_Y (Y) of the
   --  coefficient aligned with each output pixel.
   --  @param Destination_Depth Output depth, Same_Depth by default; see
   --  Derivative_Depth for the supported combinations.
   --  @param Offset Value added to each filtered value; must be finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an Anchor coordinate outside
   --  its kernel, any input rejected by the centered overload, or a failure
   --  reported by OpenCV.
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
   --  temporary structuring element of Kernel_Size and Shape, generated as
   --  by Get_Structuring_Element and anchored at (Width / 2, Height / 2).
   --  Source must be a non-empty two-dimensional Mat of depth UInt8, UInt16,
   --  Int16, Float32, or Float64; channels are processed independently.
   --  Kernel dimensions must be positive, but need not be odd, and
   --  Iterations is at least one. Constant_Border, Replicate, Reflect, and
   --  Reflect_101 are supported; Wrap is rejected. Constant_Border uses
   --  Border_Value, by default OpenCV's neutral morphology border value.
   --
   --  Destination receives Source's geometry and element type as a direct
   --  native output: OpenCV writes into its storage when it already has that
   --  size and type, so shallow copies and a Region's parent see the
   --  result, and otherwise rebinds it to new storage. Source remains
   --  unchanged unless it is also Destination, which is supported for
   --  in-place erosion; for a parent-backed Region only the view's pixels
   --  change. A Region is processed as its own logical image; pixels in its
   --  parent outside the view do not participate.
   --
   --  Native signed-int limits apply: the kernel area, Source columns times
   --  channels and kernel width times channels must fit a 32-bit int, and a
   --  fully nonzero kernel with Iterations above one must also fit OpenCV's
   --  expanded-rectangle and anchor arithmetic. Ellipse height is limited
   --  to 92681. A 1 x 1 kernel copies Source for any Iterations.
   --  @param Source Image to erode.
   --  @param Destination Receives the eroded image.
   --  @param Kernel_Size Width (columns) and height (rows) of the generated
   --  structuring element; both must be positive.
   --  @param Shape Generated element shape; defaults to Rectangle.
   --  @param Iterations Number of successive erosions; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source, a zero
   --  kernel dimension, Wrap, an invalid explicit Border_Value, a native
   --  arithmetic limit, or an OpenCV failure.
   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  Dilate replaces Destination with the neighborhood maximum selected by a
   --  temporary structuring element of Kernel_Size and Shape, anchored at
   --  (Width / 2, Height / 2). It has the same source depth, channel,
   --  kernel-size, iteration, border, destination, in-place and native-limit
   --  semantics as Erode: Destination receives Source's geometry and element
   --  type as a direct native output, and Source may also be Destination.
   --  Constant_Border uses Border_Value, by default OpenCV's neutral
   --  morphology border value. A Region is processed as its own logical
   --  image; pixels in its parent outside the view do not participate.
   --  @param Source Image to dilate.
   --  @param Destination Receives the dilated image.
   --  @param Kernel_Size Width (columns) and height (rows) of the generated
   --  structuring element; both must be positive.
   --  @param Shape Generated element shape; defaults to Rectangle.
   --  @param Iterations Number of successive dilations; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source, a zero
   --  kernel dimension, Wrap, an invalid explicit Border_Value, a native
   --  arithmetic limit, or an OpenCV failure.
   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  Apply_Morphology performs Opening, Closing, Gradient, Top_Hat, or
   --  Black_Hat with a temporary structuring element of Kernel_Size and
   --  Shape, anchored at (Width / 2, Height / 2). Each constituent erosion
   --  and dilation is repeated Iterations times. Source must be a non-empty
   --  two-dimensional Mat of depth UInt8, UInt16, Int16, Float32, or
   --  Float64; channels are processed independently. Kernel dimensions must
   --  be positive, but need not be odd, and Iterations is at least one.
   --  Constant_Border, Replicate, Reflect, and Reflect_101 are supported;
   --  Wrap is rejected. Constant_Border uses Border_Value, by default
   --  OpenCV's neutral morphology border value. Destination receives
   --  Source's geometry and element type as a direct native output, as for
   --  Erode. Source remains unchanged unless it is also Destination, which
   --  is supported in-place. A Region is processed as its own logical image;
   --  pixels in its parent outside the view do not participate. The native
   --  signed-int limits of Erode apply.
   --  @param Source Image to transform.
   --  @param Destination Receives the result of Operation.
   --  @param Operation Compound operation to perform.
   --  @param Kernel_Size Width (columns) and height (rows) of the generated
   --  structuring element; both must be positive.
   --  @param Shape Generated element shape; defaults to Rectangle.
   --  @param Iterations Repetitions of each constituent erosion and
   --  dilation; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source, a zero
   --  kernel dimension, Wrap, an invalid explicit Border_Value, a native
   --  arithmetic limit, or an OpenCV failure.
   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape := Rectangle;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  As the centered Kernel_Size Erode, but with an explicit Anchor inside
   --  the Kernel_Size box, where (0, 0) is the top-left element pixel; no
   --  negative center sentinel exists. An explicit Cross anchor also changes
   --  the generated mask geometry: its row and column pass through Anchor.
   --  Rectangle and Ellipse masks do not depend on Anchor, but their
   --  footprint shifts with it. Source, Destination, border, in-place,
   --  Region and native-limit behavior are those of the centered overload.
   --  @param Source Image to erode.
   --  @param Destination Receives the eroded image (direct native output
   --  with Source's geometry and element type).
   --  @param Kernel_Size Width (columns) and height (rows) of the generated
   --  structuring element; both must be positive.
   --  @param Shape Generated element shape; no default in this overload.
   --  @param Anchor Element position aligned with each output pixel; it
   --  must lie inside the element.
   --  @param Iterations Number of successive erosions; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source, a zero
   --  kernel dimension, an Anchor outside the element, Wrap, an invalid
   --  explicit Border_Value, a native arithmetic limit, or an OpenCV
   --  failure.
   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  As the centered Kernel_Size Dilate, but with an explicit Anchor inside
   --  the Kernel_Size box, where (0, 0) is the top-left element pixel; no
   --  negative center sentinel exists. A generated Cross passes through
   --  Anchor; Rectangle and Ellipse masks do not depend on Anchor, but their
   --  footprint shifts with it. Source, Destination, border, in-place,
   --  Region and native-limit behavior are those of the centered overload.
   --  @param Source Image to dilate.
   --  @param Destination Receives the dilated image (direct native output
   --  with Source's geometry and element type).
   --  @param Kernel_Size Width (columns) and height (rows) of the generated
   --  structuring element; both must be positive.
   --  @param Shape Generated element shape; no default in this overload.
   --  @param Anchor Element position aligned with each output pixel; it
   --  must lie inside the element.
   --  @param Iterations Number of successive dilations; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source, a zero
   --  kernel dimension, an Anchor outside the element, Wrap, an invalid
   --  explicit Border_Value, a native arithmetic limit, or an OpenCV
   --  failure.
   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel_Size  : OpenCV.Size;
      Shape        : Morphology_Shape;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  As the centered Kernel_Size Apply_Morphology, but with an explicit
   --  Anchor inside the Kernel_Size box, where (0, 0) is the top-left
   --  element pixel; no negative center sentinel exists. A generated Cross
   --  passes through Anchor; Rectangle and Ellipse masks do not depend on
   --  Anchor, but their footprint shifts with it. The same Anchor is used by
   --  every constituent erosion and dilation. Source, Destination, border,
   --  in-place, Region and native-limit behavior are those of the centered
   --  overload.
   --  @param Source Image to transform.
   --  @param Destination Receives the result of Operation (direct native
   --  output with Source's geometry and element type).
   --  @param Operation Compound operation to perform.
   --  @param Kernel_Size Width (columns) and height (rows) of the generated
   --  structuring element; both must be positive.
   --  @param Shape Generated element shape; no default in this overload.
   --  @param Anchor Element position aligned with each output pixel; it
   --  must lie inside the element.
   --  @param Iterations Repetitions of each constituent erosion and
   --  dilation; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source, a zero
   --  kernel dimension, an Anchor outside the element, Wrap, an invalid
   --  explicit Border_Value, a native arithmetic limit, or an OpenCV
   --  failure.
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

   --  As the centered Kernel_Size Erode, but with a caller-supplied
   --  structuring element anchored at (Kernel.Columns / 2, Kernel.Rows / 2).
   --  Custom kernels are nonempty 2-D UInt8 C1 binary masks: zero excludes,
   --  every nonzero value includes, without weighting. All-zero masks are
   --  rejected. Even-sized, non-square and non-contiguous Region kernels are
   --  accepted; only the kernel's logical view participates and Kernel is
   --  not modified. Kernel and Destination must not overlap.
   --  Source/Destination in-place is supported. Regions use only their
   --  logical views, including parent-backed in-place. Border, Destination
   --  and native-limit behavior are those of the Kernel_Size overload; the
   --  expanded-rectangle limit applies when every Kernel element is nonzero.
   --  @param Source Image to erode.
   --  @param Destination Receives the eroded image (direct native output
   --  with Source's geometry and element type).
   --  @param Kernel Structuring element: nonempty 2-D UInt8 C1 mask whose
   --  nonzero elements are included.
   --  @param Iterations Number of successive erosions; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source or Kernel,
   --  an all-zero Kernel, Kernel storage overlapping Destination, Wrap, an
   --  invalid explicit Border_Value, a native arithmetic limit, or an OpenCV
   --  failure.
   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  As the centered Kernel_Size Dilate, but with a caller-supplied
   --  structuring element anchored at (Kernel.Columns / 2, Kernel.Rows / 2).
   --  Kernel is a nonempty 2-D UInt8 C1 mask: zero excludes, every nonzero
   --  value includes, without weighting; all-zero masks are rejected. Even,
   --  non-square and non-contiguous Region kernels are accepted; only the
   --  kernel's logical view participates and Kernel is not modified. Kernel
   --  and Destination must not overlap; Source/Destination in-place is
   --  supported, including a parent-backed Region. Border, Destination and
   --  native-limit behavior are those of the Kernel_Size overload.
   --  @param Source Image to dilate.
   --  @param Destination Receives the dilated image (direct native output
   --  with Source's geometry and element type).
   --  @param Kernel Structuring element: nonempty 2-D UInt8 C1 mask whose
   --  nonzero elements are included.
   --  @param Iterations Number of successive dilations; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source or Kernel,
   --  an all-zero Kernel, Kernel storage overlapping Destination, Wrap, an
   --  invalid explicit Border_Value, a native arithmetic limit, or an OpenCV
   --  failure.
   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  As the centered Kernel_Size Apply_Morphology, but with a
   --  caller-supplied structuring element anchored at
   --  (Kernel.Columns / 2, Kernel.Rows / 2). Kernel is a nonempty 2-D UInt8
   --  C1 mask: zero excludes, every nonzero value includes, without
   --  weighting; all-zero masks are rejected. Even, non-square and
   --  non-contiguous Region kernels are accepted; only the kernel's logical
   --  view participates and Kernel is not modified. Kernel and Destination
   --  must not overlap; Source/Destination in-place is supported, including
   --  a parent-backed Region. Border, Destination and native-limit behavior
   --  are those of the Kernel_Size overload.
   --  @param Source Image to transform.
   --  @param Destination Receives the result of Operation (direct native
   --  output with Source's geometry and element type).
   --  @param Operation Compound operation to perform.
   --  @param Kernel Structuring element: nonempty 2-D UInt8 C1 mask whose
   --  nonzero elements are included.
   --  @param Iterations Repetitions of each constituent erosion and
   --  dilation; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source or Kernel,
   --  an all-zero Kernel, Kernel storage overlapping Destination, Wrap, an
   --  invalid explicit Border_Value, a native arithmetic limit, or an OpenCV
   --  failure.
   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel       : OpenCV.Core.Mat;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  As the custom-Kernel Erode, but with an explicit Anchor inside Kernel,
   --  where (0, 0) is the top-left kernel element; no negative center
   --  sentinel exists. The kernel's footprint shifts with Anchor. Kernel
   --  requirements, overlap rejection, Border, Destination, in-place,
   --  Region and native-limit behavior are those of the centered overload.
   --  @param Source Image to erode.
   --  @param Destination Receives the eroded image (direct native output
   --  with Source's geometry and element type).
   --  @param Kernel Structuring element: nonempty 2-D UInt8 C1 mask whose
   --  nonzero elements are included.
   --  @param Anchor Kernel position aligned with each output pixel; it must
   --  lie inside Kernel.
   --  @param Iterations Number of successive erosions; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source or Kernel,
   --  an all-zero Kernel, an Anchor outside Kernel, Kernel storage
   --  overlapping Destination, Wrap, an invalid explicit Border_Value, a
   --  native arithmetic limit, or an OpenCV failure.
   procedure Erode
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  As the custom-Kernel Dilate, but with an explicit Anchor inside
   --  Kernel, where (0, 0) is the top-left kernel element; no negative
   --  center sentinel exists. The kernel's footprint shifts with Anchor.
   --  Kernel requirements, overlap rejection, Border, Destination, in-place,
   --  Region and native-limit behavior are those of the centered overload.
   --  @param Source Image to dilate.
   --  @param Destination Receives the dilated image (direct native output
   --  with Source's geometry and element type).
   --  @param Kernel Structuring element: nonempty 2-D UInt8 C1 mask whose
   --  nonzero elements are included.
   --  @param Anchor Kernel position aligned with each output pixel; it must
   --  lie inside Kernel.
   --  @param Iterations Number of successive dilations; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source or Kernel,
   --  an all-zero Kernel, an Anchor outside Kernel, Kernel storage
   --  overlapping Destination, Wrap, an invalid explicit Border_Value, a
   --  native arithmetic limit, or an OpenCV failure.
   procedure Dilate
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  As the custom-Kernel Apply_Morphology, but with an explicit Anchor
   --  inside Kernel, where (0, 0) is the top-left kernel element; no
   --  negative center sentinel exists. Every constituent erosion and
   --  dilation uses Anchor. Kernel requirements, overlap rejection, Border,
   --  Destination, in-place, Region and native-limit behavior are those of
   --  the centered overload.
   --  @param Source Image to transform.
   --  @param Destination Receives the result of Operation (direct native
   --  output with Source's geometry and element type).
   --  @param Operation Compound operation to perform.
   --  @param Kernel Structuring element: nonempty 2-D UInt8 C1 mask whose
   --  nonzero elements are included.
   --  @param Anchor Kernel position aligned with each output pixel; it must
   --  lie inside Kernel.
   --  @param Iterations Repetitions of each constituent erosion and
   --  dilation; defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @param Border_Value Constant border value, used only with
   --  Constant_Border; defaults to Default_Morphology_Border.
   --  @exception OpenCV_Error Raised for an invalid Source or Kernel,
   --  an all-zero Kernel, an Anchor outside Kernel, Kernel storage
   --  overlapping Destination, Wrap, an invalid explicit Border_Value, a
   --  native arithmetic limit, or an OpenCV failure.
   procedure Apply_Morphology
     (Source       : OpenCV.Core.Mat;
      Destination  : in out OpenCV.Core.Mat;
      Operation    : Morphology_Operation;
      Kernel       : OpenCV.Core.Mat;
      Anchor       : OpenCV.Point;
      Iterations   : Morphology_Iterations := 1;
      Border       : OpenCV.Border_Kind := OpenCV.Constant_Border;
      Border_Value : Morphology_Border_Value := Default_Morphology_Border);

   --  Native Hit-or-Miss returns a UInt8 C1 0/255 match mask of Source size.
   --  Source must be nonempty 2-D UInt8 C1 with exactly 0/255 pixels. Kernel
   --  must be nonempty 2-D Int8 C1: +1 requires foreground, -1 background,
   --  and 0 is don't-care. All-zero kernels deliberately reject native copy
   --  behavior. Hit-only and miss-only kernels are supported. Violations
   --  raise OpenCV_Error. No conversion/thresholding is performed.
   --  Center is (Kernel.Columns / 2, Kernel.Rows / 2), even for even sizes.
   --  Iterations erodes each hit/complemented-miss leg N times, then ANDs
   --  once; it does not repeat the complete transform. Supported borders
   --  are Constant_Border, Replicate, Reflect and Reflect_101, not Wrap.
   --  Both legs use the same native default morphology border policy, not
   --  separately complemented external values: with Constant_Border,
   --  outside pixels satisfy both +1 and -1 entries, so matches touching
   --  the edge can appear that Replicate would not produce. There is no
   --  Border_Value parameter.
   --
   --  Destination is a direct native output with Source's rows and columns
   --  and type UInt8 C1: OpenCV writes into its storage when it already has
   --  that size and type, so shallow copies and a Region's parent see the
   --  result, and otherwise rebinds it to new storage. Invalid public input
   --  is rejected before native execution. Regions are isolated logical
   --  images. Direct in-place operation, including a Region, is supported;
   --  Kernel/Destination storage overlap rejects. Distinct Source remains
   --  unchanged. Only the logical view of a Kernel Region is inspected. The
   --  morphology signed-int limits apply; the expanded-rectangle limit
   --  concerns only kernels that are entirely +1 or entirely -1.
   --  @param Source Binary image of exactly 0 (background) and 255
   --  (foreground) pixels.
   --  @param Destination Receives the 0/255 match mask.
   --  @param Kernel Pattern of +1 (foreground), -1 (background) and 0
   --  (don't-care) entries, with at least one nonzero entry.
   --  @param Iterations Erosions applied to each leg before the single AND;
   --  defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @exception OpenCV_Error Raised when Source is not a nonempty
   --  2-D UInt8 C1 image of 0/255 values, when Kernel is not a nonempty 2-D
   --  Int8 C1 pattern of -1/0/+1 with a nonzero entry, for Wrap,
   --  Kernel/Destination overlap or a native arithmetic limit, or when
   --  OpenCV fails.
   procedure Hit_Or_Miss
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel      : OpenCV.Core.Mat;
      Iterations  : Morphology_Iterations := 1;
      Border      : OpenCV.Border_Kind := OpenCV.Constant_Border);

   --  As the centered Hit_Or_Miss, but the pattern is anchored at Anchor,
   --  where (0, 0) is the top-left kernel element. Explicit Anchor is inside
   --  Kernel: no negative center sentinel. Source and Kernel requirements,
   --  Iterations, borders, Destination, in-place, Region and limit behavior
   --  are those of the centered overload.
   --  @param Source Binary image of exactly 0 (background) and 255
   --  (foreground) pixels.
   --  @param Destination Receives the 0/255 match mask (direct native output
   --  with Source's rows and columns).
   --  @param Kernel Pattern of +1 (foreground), -1 (background) and 0
   --  (don't-care) entries, with at least one nonzero entry.
   --  @param Anchor Kernel position aligned with each tested pixel; it must
   --  lie inside Kernel.
   --  @param Iterations Erosions applied to each leg before the single AND;
   --  defaults to 1.
   --  @param Border Extrapolation of pixels outside Source; defaults to
   --  Constant_Border.
   --  @exception OpenCV_Error Raised when Source is not a nonempty
   --  2-D UInt8 C1 image of 0/255 values, when Kernel is not a nonempty 2-D
   --  Int8 C1 pattern of -1/0/+1 with a nonzero entry, when Anchor lies
   --  outside Kernel, for Wrap, Kernel/Destination overlap or a native
   --  arithmetic limit, or when OpenCV fails.
   procedure Hit_Or_Miss
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Kernel      : OpenCV.Core.Mat;
      Anchor      : OpenCV.Point;
      Iterations  : Morphology_Iterations := 1;
      Border      : OpenCV.Border_Kind := OpenCV.Constant_Border);

   --  Canny_Edges finds edges in a non-empty two-dimensional UInt8 C1 Source
   --  (native cv::Canny). Lower_Threshold and Upper_Threshold must be
   --  finite, nonnegative, and ordered lower to upper. Destination receives
   --  a UInt8 C1 edge map of Source's geometry, nonzero at edge pixels and
   --  zero elsewhere, as a direct native output: storage that already has
   --  that size and type is reused (shallow copies and a Region's parent see
   --  the result); otherwise Destination is rebound to new storage.
   --  @param Source Single-channel UInt8 image to analyse.
   --  @param Destination Receives the edge map.
   --  @param Lower_Threshold Lower hysteresis threshold on the gradient
   --  magnitude; finite, nonnegative, and not above Upper_Threshold.
   --  @param Upper_Threshold Upper hysteresis threshold on the gradient
   --  magnitude; finite and nonnegative.
   --  @param Aperture Sobel aperture of the gradient; Sobel_3x3 by default.
   --  @param Gradient_Norm Gradient magnitude norm; L1_Norm by default.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  non-UInt8 C1 Source, a negative, nonfinite, or misordered threshold,
   --  or a failure reported by OpenCV.
   procedure Canny_Edges
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Lower_Threshold : OpenCV.Float64_Value;
      Upper_Threshold : OpenCV.Float64_Value;
      Aperture        : Canny_Aperture := Sobel_3x3;
      Gradient_Norm   : Canny_Gradient_Norm := L1_Norm);

   --  Native derivative-input cv::Canny; gradients are not recomputed.
   --  Derivatives must be nonempty 2-D Int16 C1 or C3 with identical geometry
   --  and type. C3 selects the channel with greatest magnitude per pixel.
   --  Noncontiguous Regions are supported and both derivatives are preserved.
   --  Destination must not overlap either derivative (including self); after
   --  success it receives fresh owning UInt8 C1 storage of their geometry.
   --  Previous Destination aliases and Region parents are not modified.
   --  Rejected calls and native failures leave Destination unchanged.
   --
   --  Native signed arithmetic is checked before execution: L2 rejects pairs
   --  whose squared magnitude exceeds Integer_32'Last; both norms reject
   --  samples whose native direction-classification branch would overflow.
   --  Padded map/ring-buffer sizes and byte extents are bounded as well.
   --  No samples or thresholds are silently clamped by the binding.
   --  @param Derivative_X Signed horizontal derivatives.
   --  @param Derivative_Y Signed vertical derivatives.
   --  @param Destination Receives the edge map (values zero or 255).
   --  @param Lower_Threshold Finite nonnegative lower hysteresis threshold.
   --  @param Upper_Threshold Finite threshold not below Lower_Threshold.
   --  @param Gradient_Norm L1_Norm (default) or L2_Norm.
   --  @exception OpenCV_Error Invalid derivatives, thresholds, aliasing,
   --  unsafe native arithmetic/layout, or native failure. L1 thresholds above
   --  2_147_483_647 are rejected before native integer conversion.
   --  L2 thresholds must fit finite Float32 for optional IPP dispatch.
   procedure Canny_Edges
     (Derivative_X    : OpenCV.Core.Mat;
      Derivative_Y    : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Lower_Threshold : OpenCV.Float64_Value;
      Upper_Threshold : OpenCV.Float64_Value;
      Gradient_Norm   : Canny_Gradient_Norm := L1_Norm);

   --  Result depth of Extract_Subpixel_Patch.
   --  @enum Preserve_Source_Depth The patch has Source's depth, UInt8 or
   --  Float32 (the default).
   --  @enum Promote_To_Float32 The patch is Float32: UInt8 sources are
   --  promoted and Float32 sources remain Float32.
   type Subpixel_Patch_Output_Depth is
     (Preserve_Source_Depth, Promote_To_Float32);

   --  Native bilinear extraction (cv::getRectSubPix) of a patch centered at
   --  a subpixel Center, with nearest-edge extension. Channels are
   --  interpolated independently; patch pixel (R, C) samples Source at
   --
   --     X = Center.X - (Patch_Size.Width - 1) / 2 + C
   --     Y = Center.Y - (Patch_Size.Height - 1) / 2 + R
   --
   --  Source must be nonempty 2-D UInt8/Float32 C1/C3. Patch dimensions
   --  must be positive; they may exceed Source. Center must be finite and
   --  inside Source (`0 <= X < Columns`, `0 <= Y < Rows`), and is
   --  Region-local. Source values may be nonfinite and propagate natively
   --  into the samples that use them. UInt8 results use native fixed-point
   --  rounding. Source is unchanged and a Region's parent pixels never
   --  participate: requests touching the border sample a private
   --  replicated guard copy with the same logical geometry. A patch
   --  crossing both the top and the right border is sampled by OpenCV's
   --  portable implementation even where Intel IPP is enabled, whose corner
   --  replication there is wrong. Arithmetic and backend representability
   --  limits can reject extreme dimensions or strides.
   --  @param Source Image to sample.
   --  @param Patch_Size Patch columns (Width) and rows (Height); both
   --  nonzero.
   --  @param Center Patch center in Source pixel coordinates (X = column,
   --  Y = row).
   --  @param Output_Depth Result depth; default Preserve_Source_Depth.
   --  @return Fresh independent owning Mat with Patch_Size.Height rows,
   --  Patch_Size.Width columns, Source's channel count and the depth
   --  selected by Output_Depth.
   --  @exception OpenCV_Error Unsupported Source, zero Patch_Size
   --  dimension, nonfinite or outside Center, native arithmetic or stride
   --  limits, or an OpenCV failure.
   function Extract_Subpixel_Patch
     (Source       : OpenCV.Core.Mat;
      Patch_Size   : OpenCV.Size;
      Center       : OpenCV.Float32_Point;
      Output_Depth : Subpixel_Patch_Output_Depth := Preserve_Source_Depth)
      return OpenCV.Core.Mat;

   --  First-derivative pair returned by Spatial_Gradient. Each component is
   --  a fresh independent Int16 C1 Mat with the Source geometry, sharing
   --  storage with neither Source nor the other component.
   --  @field X_Derivative Horizontal derivative: 3x3 Sobel with X order 1.
   --  @field Y_Derivative Vertical derivative: 3x3 Sobel with Y order 1.
   type Spatial_Gradient_Result is record
      X_Derivative : OpenCV.Core.Mat;
      Y_Derivative : OpenCV.Core.Mat;
   end record;

   --  Native fixed 3x3 first-order Sobel pair (cv::spatialGradient), with
   --  no kernel-size selector. Source must be nonempty, exactly 2-D UInt8
   --  C1. Each result is a fresh independent Int16 C1 Mat with Source
   --  geometry and mathematical range -1020 .. 1020, so no saturation or
   --  wrap occurs. Source remains unchanged. Regions are logical images:
   --  parent pixels never participate. A one-column Source is computed
   --  through a private two-column copy with the same Sobel semantics,
   --  avoiding an unsafe native read.
   --  @param Source UInt8 C1 image to differentiate.
   --  @param Border Extrapolation outside Source: Reflect_101 (default) or
   --  Replicate only.
   --  @return Fresh X_Derivative/Y_Derivative pair.
   --  @exception OpenCV_Error Raised for an invalid Source, any
   --  other Border, or a native failure.
   function Spatial_Gradient
     (Source : OpenCV.Core.Mat;
      Border : OpenCV.Border_Kind := OpenCV.Reflect_101)
      return Spatial_Gradient_Result;

   --  Sobel computes the X_Order/Y_Order spatial derivative independently for
   --  every Source channel (native cv::Sobel) and stores
   --  `Scale * derivative + Offset`, where Offset is OpenCV's delta term.
   --  Source must be a non-empty two-dimensional UInt8, UInt16, Int16,
   --  Float32, or Float64 Mat. X_Order and Y_Order may not both be zero;
   --  each order must be less than Kernel_Size, except Kernel_1 uses
   --  OpenCV's special effective three-tap derivative kernel.
   --
   --  Destination has Source's rows, columns, and channel count, with depth
   --  selected by Destination_Depth: UInt8 supports Same_Depth, Int16_Depth,
   --  Float32_Depth, and Float64_Depth. UInt16 and Int16 support Same_Depth,
   --  Float32_Depth, and Float64_Depth. Float32 supports Same_Depth or
   --  Float32_Depth; Float64 supports Same_Depth or Float64_Depth. A UInt8
   --  Same_Depth result cannot hold negative derivatives. Destination is a
   --  direct native output: storage that already has the result's size and
   --  type is reused (shallow copies and a Region's parent see the result);
   --  otherwise Destination is rebound to new storage. OpenCV supports
   --  direct in-place use only when Destination_Depth is Same_Depth; Source
   --  remains unchanged when Destination is distinct. A Region Source is
   --  passed to OpenCV directly, and native Sobel may inspect parent pixels
   --  around the Region; pass a Clone to isolate it.
   --  @param Source Image to differentiate.
   --  @param Destination Receives the scaled derivative image.
   --  @param X_Order Derivative order along X (columns).
   --  @param Y_Order Derivative order along Y (rows).
   --  @param Destination_Depth Output depth; Float32_Depth by default.
   --  @param Kernel_Size Sobel aperture; Kernel_3 by default.
   --  @param Scale Factor applied to each derivative value; must be finite.
   --  @param Offset Value added after scaling (OpenCV's delta); must be
   --  finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is not supported.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported Source, an unsupported depth combination, both orders
   --  zero or an order not below the effective kernel length, a nonfinite
   --  Scale or Offset, Wrap, or a failure reported by OpenCV.
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
   --  every Source channel (native cv::Scharr) with the 3x3 Scharr kernel
   --  whose separable factors Get_Scharr_Kernels returns: `[-1, 0, 1]`
   --  along Axis and `[3, 10, 3]` across it. It stores
   --  `Scale * derivative + Offset`. Its source, destination-depth, Scale,
   --  Delta (Offset), and Border requirements are the same as Sobel's.
   --  Destination is a direct native output with Source's rows, columns, and
   --  channel count: storage that already has the result's size and type is
   --  reused (shallow copies and a Region's parent see the result);
   --  otherwise Destination is rebound to new storage. OpenCV supports
   --  direct in-place use only when Destination_Depth is Same_Depth; Source
   --  remains unchanged when Destination is distinct.
   --  @param Source Image to differentiate.
   --  @param Destination Receives the scaled derivative image.
   --  @param Axis Direction of the first derivative.
   --  @param Destination_Depth Output depth; Float32_Depth by default (see
   --  Derivative_Depth for the supported combinations).
   --  @param Scale Factor applied to each derivative value; must be finite.
   --  @param Offset Value added after scaling (OpenCV's delta); must be
   --  finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported Source, an unsupported depth combination, a nonfinite
   --  Scale or Offset, Wrap, or a failure reported by OpenCV.
   procedure Scharr
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Axis              : Derivative_Axis;
      Destination_Depth : Derivative_Depth := Float32_Depth;
      Scale             : OpenCV.Float64_Value := 1.0;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Laplacian computes the sum of the second X and Y derivatives for every
   --  Source channel (native cv::Laplacian). Source must be non-empty and
   --  two-dimensional with depth UInt8, UInt16, Int16, Float32, or Float64.
   --  Destination_Depth follows the same source/destination combinations as
   --  Sobel. Kernel size 1 uses OpenCV's dedicated 3 by 3 Laplacian
   --  aperture. Scale multiplies computed values and Offset is added before
   --  storage. Channels are processed independently.
   --
   --  Destination receives Source's rows, columns, channels, and requested
   --  depth as a direct native output: storage that already has that size
   --  and type is reused (shallow copies and a Region's parent see the
   --  result); otherwise Destination is rebound to new storage. Source
   --  remains unchanged when distinct from Destination. Direct in-place
   --  operation is supported when Destination_Depth is Same_Depth.
   --  @param Source Image to differentiate.
   --  @param Destination Receives the scaled Laplacian image.
   --  @param Destination_Depth Output depth; Float32_Depth by default (see
   --  Derivative_Depth for the supported combinations).
   --  @param Kernel_Size Aperture size; must be odd and between 1 and 31.
   --  @param Scale Factor applied to each computed value; must be finite.
   --  @param Offset Value added after scaling (OpenCV's delta); must be
   --  finite.
   --  @param Border Extrapolation outside Source: Constant_Border,
   --  Replicate, Reflect, or Reflect_101 (default). Wrap is rejected.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, or
   --  unsupported Source, an unsupported depth combination, an even
   --  Kernel_Size, a nonfinite Scale or Offset, Wrap, or a failure reported
   --  by OpenCV.
   procedure Laplacian
     (Source            : OpenCV.Core.Mat;
      Destination       : in out OpenCV.Core.Mat;
      Destination_Depth : Derivative_Depth := Float32_Depth;
      Kernel_Size       : Laplacian_Kernel_Size := 1;
      Scale             : OpenCV.Float64_Value := 1.0;
      Offset            : OpenCV.Float64_Value := 0.0;
      Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

   --  Applies a fixed threshold independently to every channel of Source,
   --  using the per-sample rule selected by Mode (see Threshold_Mode).
   --  Source must be non-empty, two-dimensional, and UInt8, UInt16, Int16,
   --  Float32, or Float64; any channel count is accepted. Threshold_Value
   --  and Maximum_Value must be finite. Destination receives Source's rows,
   --  columns, depth, and channel count as a direct native output: OpenCV
   --  writes into its storage when it already has that size and type, so
   --  shallow copies and a Region's parent see the result, and otherwise
   --  rebinds it to new storage. Source remains unchanged. Maximum_Value
   --  affects only Binary and Binary_Inverse; it is ignored by Truncate,
   --  To_Zero, and To_Zero_Inverse.
   --  @param Source Image whose samples are compared with Threshold_Value.
   --  @param Destination Receives the thresholded image.
   --  @param Threshold_Value Threshold compared with every sample, in
   --  Source's sample units.
   --  @param Mode Per-sample rule; defaults to Binary.
   --  @param Maximum_Value Value written by Binary and Binary_Inverse;
   --  defaults to 255.0.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D or
   --  of another depth, when Threshold_Value or Maximum_Value is not
   --  finite, or when OpenCV fails.
   procedure Apply_Threshold
     (Source          : OpenCV.Core.Mat;
      Destination     : in out OpenCV.Core.Mat;
      Threshold_Value : OpenCV.Float64_Value;
      Mode            : Threshold_Mode := Binary;
      Maximum_Value   : OpenCV.Float64_Value := 255.0);

   --  Applies Otsu or Triangle automatic thresholding to a non-empty,
   --  two-dimensional, single-channel Source. Maximum_Value must be finite.
   --  Otsu accepts UInt8 and UInt16 Sources; Triangle accepts UInt8 only.
   --  OpenCV before 4.4 rejects UInt16 Otsu with OpenCV_Error. The result
   --  equals Apply_Threshold with Computed_Threshold, Mode and Maximum_Value.
   --  Destination is replaced with a single-channel Mat having Source's
   --  rows, columns, and depth, as a direct native output: OpenCV writes
   --  into its storage when it already has that size and type, so shallow
   --  copies and a Region's parent see the result, and otherwise rebinds it
   --  to new storage. Computed_Threshold receives OpenCV's selected value on
   --  success. Source remains unchanged. Maximum_Value affects only Binary
   --  and Binary_Inverse; it is ignored by the other threshold modes.
   --  @param Source Single-channel image from which the threshold is
   --  selected and to which it is applied.
   --  @param Destination Receives the thresholded image.
   --  @param Computed_Threshold Receives the threshold OpenCV selected, in
   --  Source's sample units; assigned only on success.
   --  @param Method Threshold selection algorithm; defaults to Otsu.
   --  @param Mode Per-sample rule applied with the selected threshold;
   --  defaults to Binary.
   --  @param Maximum_Value Value written by Binary and Binary_Inverse;
   --  defaults to 255.0.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D,
   --  not single-channel or of a depth Method does not accept, when
   --  Maximum_Value is not finite, or when OpenCV fails.
   procedure Apply_Automatic_Threshold
     (Source             : OpenCV.Core.Mat;
      Destination        : in out OpenCV.Core.Mat;
      Computed_Threshold : out OpenCV.Float64_Value;
      Method             : Automatic_Threshold_Method := Otsu;
      Mode               : Threshold_Mode := Binary;
      Maximum_Value      : OpenCV.Float64_Value := 255.0);

   --  Applies an adaptive binary threshold to a non-empty, two-dimensional,
   --  UInt8, single-channel Source. Block_Size must be odd. OpenCV
   --  calculates the local threshold as the arithmetic neighborhood mean or
   --  a Gaussian-weighted neighborhood mean, according to Method, minus
   --  Bias. Bias must be finite; it may be positive, zero, or negative and
   --  is passed directly to OpenCV. Maximum_Value is a UInt8 value,
   --  including zero. Destination is replaced with a UInt8 single-channel
   --  Mat having Source's rows and columns, as a direct native output:
   --  OpenCV writes into its storage when it already has that size and
   --  type, so shallow copies and a Region's parent see the result, and
   --  otherwise rebinds it to new storage. Source remains unchanged when
   --  distinct from Destination; direct in-place operation is supported.
   --  OpenCV controls neighborhood border handling internally.
   --  @param Source UInt8 C1 image to binarize.
   --  @param Destination Receives the UInt8 C1 binary image; may be the
   --  same Mat as Source.
   --  @param Block_Size Odd side length, in pixels, of the neighborhood.
   --  @param Method Local mean weighting; defaults to Mean.
   --  @param Mode Output rule; defaults to Binary.
   --  @param Bias Finite value subtracted from the local mean to form the
   --  local threshold; defaults to 0.0.
   --  @param Maximum_Value Value written for selected pixels; defaults
   --  to 255.
   --  @exception OpenCV_Error Raised when Source is empty, not 2-D,
   --  not UInt8 or not single-channel, when Block_Size is even, when Bias
   --  is not finite, or when OpenCV fails.
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
   --  columns with UInt8 depth and one channel. OpenCV writes Destination
   --  directly: it reuses Destination's storage when Destination already
   --  is a UInt8 C1 Mat of Source's size (shallow copies of Destination
   --  and a Region's parent then see the result) and otherwise rebinds
   --  Destination to new storage. Source remains unchanged when
   --  Source and Destination do not share storage. Direct same-object in-place
   --  use is supported:
   --
   --     Equalize_Histogram (Image, Image);
   --
   --  Other Source/Destination storage-sharing combinations are an Ada binding
   --  restriction for this slice and are rejected before native writes. That
   --  includes distinct shallow aliases and partially overlapping source and
   --  destination ROIs; it is not a claim that OpenCV forbids every alias.
   --  Source.Rows times Source.Columns must not exceed 2_147_483_647
   --  because OpenCV counts pixels in 32-bit histogram bins.
   --  Public contract violations raise OpenCV.OpenCV_Error before Destination
   --  is modified. Failures reported by OpenCV after Destination allocation or
   --  native execution raise OpenCV.OpenCV_Error and do not roll back
   --  Destination.
   --  @param Source Nonempty 2-D UInt8 C1 image whose own pixels define the
   --  histogram; it is not modified unless it is Destination itself.
   --  @param Destination Receives the equalized UInt8 C1 image of Source's
   --  size; may be Source itself but must not otherwise share storage
   --  with Source.
   --  @exception OpenCV_Error Raised for an empty, non-2-D, non-UInt8
   --  or multi-channel Source, a pixel count above 2_147_483_647, a
   --  Destination that shares storage with a distinct Source, or a native
   --  failure.
   procedure Equalize_Histogram
     (Source : OpenCV.Core.Mat; Destination : in out OpenCV.Core.Mat);

   --  CLAHE performs Contrast Limited Adaptive Histogram Equalization locally,
   --  unlike Equalize_Histogram, which uses one global histogram. Source is
   --  divided into Tile_Grid_Size.Width by Tile_Grid_Size.Height contextual
   --  regions; Clip_Limit controls contrast limiting in each region. Source
   --  must be a non-empty two-dimensional UInt8 or UInt16 single-channel Mat.
   --  No implicit color or depth conversion is performed. Tile counts need not
   --  divide Source dimensions evenly: OpenCV pads internally as needed,
   --  using Reflect_101. Clip_Limit must be finite and greater than zero;
   --  both tile counts must be positive.
   --  Destination may initially be empty or incompatible; on success it has
   --  Source's geometry, depth, and one channel. Direct same-object in-place
   --  use, including an ROI, is supported. Distinct Source/Destination Mats
   --  with overlapping storage are rejected before native writes. Contract
   --  violations and native failures raise OpenCV.OpenCV_Error.
   --
   --  When Source is Destination itself or a non-continuous Region, CLAHE
   --  runs on a private snapshot, so padding uses only that view's pixels,
   --  and the result is then copied into Destination. Otherwise OpenCV
   --  writes Destination directly and reads Source in place; a continuous
   --  Region (for example full-width rows) then remains a view of its
   --  parent, and padding of a size not divisible by the tile counts can
   --  read parent pixels just outside the Region. In both cases
   --  Destination's storage is reused when it already is a Mat of
   --  Source's size and type (shallow copies of Destination and a Region's
   --  parent then see the result); otherwise Destination is rebound to new
   --  storage. When storage is independent, Source remains unchanged.
   --  Tile counts, the padded geometry and the tile area must fit native
   --  int arithmetic, and Clip_Limit must not exceed
   --  `2147483647.0 * 65536.0 / Tile_Area`, where Tile_Area is the pixel
   --  count of one padded tile.
   --  @param Source Nonempty 2-D UInt8 or UInt16 C1 image to equalize.
   --  @param Destination Receives the equalized image with Source's
   --  geometry and depth; may be Source itself but must not otherwise
   --  share storage with Source.
   --  @param Clip_Limit Contrast limit applied to each tile histogram;
   --  finite and greater than zero. Defaults to 40.0.
   --  @param Tile_Grid_Size Number of tiles across (Width) and down
   --  (Height), not pixel dimensions; both positive. Defaults to 8 x 8.
   --  @exception OpenCV_Error Raised for an empty, non-2-D,
   --  multi-channel or unsupported-depth Source, a nonpositive or
   --  nonfinite Clip_Limit, a zero tile count, native int limits, a
   --  Destination that shares storage with a distinct Source, or a native
   --  failure.
   procedure CLAHE
     (Source         : OpenCV.Core.Mat;
      Destination    : in out OpenCV.Core.Mat;
      Clip_Limit     : OpenCV.Float64_Value := 40.0;
      Tile_Grid_Size : OpenCV.Size := (Width => 8, Height => 8));

   --  Extracts the contours of a binary image with cv::findContours. Zero
   --  Source pixels are background and nonzero pixels are foreground. Contour
   --  points lie on foreground boundary pixels (a filled rectangle yields its
   --  corner pixels under Simple), shifted by Offset. Contours and hierarchy
   --  are copied into the returned Ada-owned Contour_Set and the native result
   --  is released. Indices are zero-based. An all-zero Source returns an empty
   --  set.
   --  @param Source Binary image: a nonempty two-dimensional UInt8 C1 Mat. It
   --  remains unchanged.
   --  @param Retrieval Which contours are returned and how their hierarchy
   --  entries are linked; defaults to External_Only.
   --  @param Approximation How the boundary points of each contour are stored;
   --  defaults to Simple.
   --  @param Offset Added to every returned point, for example to express
   --  contours of a Region in its parent's coordinates. Hierarchy links are
   --  unaffected. Defaults to (0, 0).
   --  @return A fresh Ada-owned Contour_Set, independent of Source and of
   --  native storage.
   --  @exception OpenCV_Error Raised when Source is empty, not
   --  two-dimensional, not UInt8 or not single-channel, when a native contour
   --  index or count is invalid or exceeds the C ABI range, and when OpenCV
   --  fails.
   function Find_Contours
     (Source        : OpenCV.Core.Mat;
      Retrieval     : Contour_Retrieval_Mode := External_Only;
      Approximation : Contour_Approximation_Mode := Simple;
      Offset        : OpenCV.Point := (X => 0, Y => 0)) return Contour_Set;

   --  Returns the number of contours stored in Self.
   --  @param Self Contour set to inspect.
   --  @return Number of stored contours, zero for an empty set. Valid indices
   --  are 0 .. Contour_Count (Self) - 1.
   function Contour_Count (Self : Contour_Set) return Natural;

   --  Returns a copy of the points of one stored contour.
   --  @param Self Contour set to read.
   --  @param Index Zero-based contour position; must be less than
   --  Contour_Count (Self).
   --  @return The contour's points in stored order, as a zero-based Contour
   --  independent of Self; a contour without points has the null range 1 .. 0.
   --  @exception OpenCV_Error Raised when Index is not less than Contour_Count
   --  (Self).
   function Get_Contour
     (Self : Contour_Set; Index : Contour_Index) return Contour;

   --  Returns the hierarchy entry of one stored contour.
   --  @param Self Contour set to read.
   --  @param Index Zero-based contour position; must be less than
   --  Contour_Count (Self).
   --  @return The contour's Next, Previous, First_Child and Parent links, as
   --  produced by the Retrieval mode passed to Find_Contours.
   --  @exception OpenCV_Error Raised when Index is not less than Contour_Count
   --  (Self).
   function Get_Hierarchy
     (Self : Contour_Set; Index : Contour_Index)
      return Contour_Hierarchy_Entry;

   --  Labels the connected nonzero regions of a binary mask with
   --  cv::connectedComponentsWithStats and collects per-component statistics.
   --  Zero is background and every nonzero value is foreground. Zero in Labels
   --  is Background_Label and foreground labels are 1 through Component_Count.
   --  Foreground label numbering has no spatial-order guarantee. Labels is a
   --  direct native output: OpenCV reuses its storage when it already is an
   --  Int32 C1 Mat with Source's rows and columns (shallow copies of Labels
   --  and a Region's parent then see the labels) and otherwise rebinds it to
   --  new storage. The operation is not in place: Source and Labels must not
   --  share storage. Native safety preflight rejects unrepresentable geometry,
   --  pixel counts above INT_MAX - 2 and unsafe strides before writing Labels.
   --  On OpenCV 4.1 only, it also rejects masks with no background pixels
   --  (signed bounds overflow in statistics finalization), and odd heights
   --  when native getNumThreads() > 1 and rows / getNumThreads() >= 2 (unsafe
   --  parallel chunk indexing). OpenCV 4.6, 4.10 and 5.0 do not have these two
   --  version-specific restrictions. No global thread setting or native
   --  algorithm selection is changed. Preflight rejection preserves Source
   --  and previous Labels storage, including its shallow aliases/parent.
   --  @param Source Binary mask: a nonempty two-dimensional UInt8 C1 Mat.
   --  @param Labels Receives the Int32 C1 label image with Source's rows and
   --  columns. Must not share storage with Source, including the same Mat, a
   --  shallow alias or an overlapping Region; this is checked before any
   --  native write.
   --  @param Components Receives the Ada-owned statistics of the foreground
   --  components only; assigned only after success.
   --  @param Connectivity Four_Connected or Eight_Connected select 4- and
   --  8-neighborhoods; defaults to Eight_Connected.
   --  @exception OpenCV_Error Raised when Source is empty, not
   --  two-dimensional, not UInt8 or not single-channel, when Labels shares
   --  storage with Source, when OpenCV returns an invalid label count, and
   --  when native safety preflight rejects the call, and when OpenCV fails.
   procedure Connected_Components_With_Stats
     (Source       : OpenCV.Core.Mat;
      Labels       : in out OpenCV.Core.Mat;
      Components   : out Connected_Component_Set;
      Connectivity : Pixel_Connectivity := Eight_Connected);

   --  Labels nonzero pixels with cv::connectedComponents, without statistics.
   --  Source is preserved. Noncontiguous Regions are supported; only their
   --  pixels participate and coordinates are Region-local. The operation
   --  borrows Core handles only for the call and never retains them.
   --  Labels is always rebound to fresh storage after validation; its old
   --  aliases and Region parent remain unchanged on success and failure.
   --  Int32 staging plus a checked UInt16 conversion costs temporary storage
   --  and an additional scan. No native UInt16 labeling is performed.
   --  @param Source Nonempty two-dimensional UInt8 C1 mask. Zero is
   --  background; every nonzero byte, not just 255, is foreground.
   --  @param Labels Receives a C1 image with Source geometry. The same object,
   --  shallow aliases and overlapping Regions of Source are rejected before
   --  native execution; previous storage is unchanged on rejection.
   --  @param Total_Labels Total including background (always label zero), even
   --  when no background pixels exist. Undefined when an exception is raised.
   --  @param Connectivity Four- or eight-neighbor connectivity.
   --  @param Label_Depth Published UInt16 or Int32 storage.
   --  @param Algorithm Native selection; only SAUF guarantees row-major IDs.
   --  @exception OpenCV_Error Invalid source, overlap, unavailable algorithm,
   --  unsafe native geometry/path, UInt16 overflow or native failure. OpenCV
   --  4.1 odd-height parallel paths are rejected without changing global
   --  thread settings. Allocation failures can also raise Storage_Error.
   procedure Connected_Components
     (Source       : OpenCV.Core.Mat;
      Labels       : in out OpenCV.Core.Mat;
      Total_Labels : out Natural;
      Connectivity : Pixel_Connectivity := Eight_Connected;
      Label_Depth  : Connected_Component_Label_Depth := Int32_Labels;
      Algorithm    : Connected_Component_Algorithm := Native_Default);

   --  Statistics variant with the same staging, Region, alias, label-depth,
   --  algorithm and failure-publication rules as Connected_Components. The
   --  legacy overload above retains direct-output/storage-reuse behavior.
   --  @param Source Nonempty two-dimensional UInt8 C1 mask, preserved.
   --  @param Labels Fresh C1 output published only after Ada statistics exist.
   --  @param Components Ada-owned foreground statistics, indexed by the actual
   --  output labels 1 .. Component_Count. Bounds and centroids are local;
   --  area counts pixels. As an out parameter it is unspecified on exceptions.
   --  @param Label_Depth Required to distinguish this overload from legacy.
   --  @param Connectivity Four- or eight-neighbor connectivity.
   --  @param Algorithm Native selector; unavailable algorithms fail.
   --  @exception OpenCV_Error Same failures as Connected_Components, or bad
   --  statistics shape/numeric representation. Labels is unchanged on failure
   --  before publication; no preservation is promised for Components on error.
   --  OpenCV 4.1 statistics with no background pixels are rejected: native
   --  absent-background bounds finalization has signed arithmetic overflow.
   procedure Connected_Components_With_Stats
     (Source       : OpenCV.Core.Mat;
      Labels       : in out OpenCV.Core.Mat;
      Components   : out Connected_Component_Set;
      Label_Depth  : Connected_Component_Label_Depth;
      Connectivity : Pixel_Connectivity := Eight_Connected;
      Algorithm    : Connected_Component_Algorithm := Native_Default);

   --  Returns the foreground count, excluding Background_Label.
   --  @param Self Statistics set to inspect.
   --  @return Number of foreground components, zero when there is none. Valid
   --  Get_Component labels are 1 .. Component_Count.
   function Component_Count (Self : Connected_Component_Set) return Natural;

   --  Returns the statistics of one foreground component. Label must designate
   --  a foreground component in 1 .. Component_Count.
   --  @param Self Statistics set to read.
   --  @param Label Foreground label as stored in the Labels image.
   --  @return Copy of the component's Bounds, Area and centroid.
   --  @exception OpenCV_Error Raised when Label is Background_Label or greater
   --  than Component_Count (Self).
   function Get_Component
     (Self : Connected_Component_Set; Label : Component_Label)
      return Component_Statistics;

   --  Draws the straight segment from Start to Finish into Image in place with
   --  cv::line, under the package drawing rules. Both endpoints are painted;
   --  parts outside Image are clipped.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Start First endpoint; may lie outside Image.
   --  @param Finish Second endpoint; may lie outside Image.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Thickness Line thickness in pixels; defaults to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when Image or a used Color component
   --  violates the drawing rules, when Anti_Aliased_Line is used with a
   --  non-UInt8 Image, and when OpenCV fails.
   procedure Draw_Line
     (Image      : in out OpenCV.Core.Mat;
      Start      : OpenCV.Point;
      Finish     : OpenCV.Point;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Draws an arrow into Image in place with cv::arrowedLine, under the
   --  package drawing rules: the shaft from Start to Finish and, at Finish, an
   --  arrowhead of two strokes at 45 degrees to the shaft, each Tip_Length
   --  times the Start-to-Finish distance long. Tip_Length is a finite fraction
   --  in (0, 1]. Coincident endpoints are rejected. Unsafe native coordinate
   --  arithmetic raises OpenCV_Error: the endpoint differences and the
   --  arrowhead coordinates must fit the signed 32-bit range.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Start Tail of the arrow; may lie outside Image.
   --  @param Finish Tip of the arrow, where the arrowhead is drawn; must
   --  differ from Start.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Tip_Length Arrowhead stroke length as a fraction of the arrow
   --  length: finite, greater than 0.0 and at most 1.0. Defaults to 0.1.
   --  @param Thickness Thickness of shaft and arrowhead in pixels; defaults
   --  to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when Tip_Length is outside (0, 1] or not
   --  finite, when Start equals Finish, when the native coordinate arithmetic
   --  would overflow, when Image or a used Color component violates the
   --  drawing rules, when Anti_Aliased_Line is used with a non-UInt8 Image,
   --  and when OpenCV fails.
   procedure Draw_Arrow
     (Image      : in out OpenCV.Core.Mat;
      Start      : OpenCV.Point;
      Finish     : OpenCV.Point;
      Color      : OpenCV.Scalar;
      Tip_Length : OpenCV.Float64_Value := 0.1;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Draws a marker of shape Kind centered on Position into Image in place
   --  with cv::drawMarker, under the package drawing rules. The marker extends
   --  Marker_Size / 2 pixels from Position horizontally and vertically, and
   --  Position plus or minus that half size must fit the signed 32-bit range.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Position Marker center; may lie outside Image.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Kind Marker shape; defaults to Cross_Marker.
   --  @param Marker_Size Overall marker width and height in pixels; defaults
   --  to 20.
   --  @param Thickness Stroke thickness in pixels; defaults to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when a marker endpoint would leave the
   --  signed 32-bit range, when Image or a used Color component violates the
   --  drawing rules, when Anti_Aliased_Line is used with a non-UInt8 Image,
   --  and when OpenCV fails.
   procedure Draw_Marker
     (Image       : in out OpenCV.Core.Mat;
      Position    : OpenCV.Point;
      Color       : OpenCV.Scalar;
      Kind        : Drawing_Marker_Kind := Cross_Marker;
      Marker_Size : Positive := 20;
      Thickness   : Drawing_Thickness := 1;
      Line_Style  : Drawing_Line_Style := Eight_Connected_Line);

   --  Renders Text into Image in place with cv::putText. Legacy Hershey
   --  selectors: OpenCV 4.x uses strokes; OpenCV 5 uses its built-in TrueType
   --  compatibility renderer. Glyphs and metrics may differ. Requires a
   --  nonempty 2-D UInt8 C1, C3 or C4 image, including a Region; this is
   --  narrower than the package drawing rules, whose color, alias and clipping
   --  rules otherwise apply. Text is a byte span, including embedded NULs,
   --  with any lower bound; how non-ASCII bytes are rendered depends on the
   --  OpenCV generation. Empty text is a no-op after the Font_Scale, image and
   --  color checks. There is no line-style choice: the binding always requests
   --  OpenCV LINE_8. Glyphs extend right of Origin and, by default, upward
   --  from it. Bottom_Left_Origin reverses the vertical direction of the
   --  glyphs.
   --
   --  For nonempty text, a conservative native-arithmetic preflight requires
   --  `Font_Scale <= 1.0e6 / 65536.0` (about 15.26) and
   --  `Text'Length * Font_Scale * 512.0 + Thickness < 1.0e6`; each Origin
   --  coordinate must also stay at least
   --  `(Text'Length + 1) * Font_Scale * 512.0 + Thickness + 64.0` (rounded up)
   --  inside the signed 32-bit range.
   --  @param Image Target modified in place: a nonempty 2-D UInt8 C1, C3 or C4
   --  Mat or Region.
   --  @param Text Bytes to render, passed with their exact length.
   --  @param Origin Bottom-left corner of the text in Image coordinates; may
   --  lie outside Image.
   --  @param Color Text value in channel order; the components used by Image's
   --  channels must be finite.
   --  @param Font Font selector; defaults to Hershey_Simplex.
   --  @param Font_Scale Font scale factor: finite, positive and within the
   --  preflight bound. Defaults to 1.0.
   --  @param Thickness Glyph stroke thickness; defaults to 1.
   --  @param Bottom_Left_Origin When True the glyphs are vertically reversed
   --  and extend downward from Origin; defaults to False.
   --  @exception OpenCV_Error Raised when Font_Scale is not finite and
   --  positive, when Image is not a nonempty 2-D UInt8 C1, C3 or C4 Mat, when
   --  a used Color component is not finite, when the text geometry or Origin
   --  fails the preflight, and when OpenCV fails.
   procedure Draw_Text
     (Image              : in out OpenCV.Core.Mat;
      Text               : String;
      Origin             : OpenCV.Point;
      Color              : OpenCV.Scalar;
      Font               : Text_Font := Hershey_Simplex;
      Font_Scale         : OpenCV.Float64_Value := 1.0;
      Thickness          : Drawing_Thickness := 1;
      Bottom_Left_Origin : Boolean := False);

   --  Measures the rendered extent of Text with cv::getTextSize, without
   --  drawing. Empty text returns Size (0, 0) and Baseline 0 without calling
   --  OpenCV; Font_Scale is still validated. Otherwise the result is the
   --  native bounding Size and the unadjusted native baseline, which is the
   --  distance from the bottom-most text point up to the baseline. Metrics
   --  depend on the OpenCV generation (see Text_Font). Nonempty text is
   --  subject to the Draw_Text Font_Scale and text-length preflight.
   --  @param Text Bytes to measure, passed with their exact length, including
   --  embedded NULs and any lower bound.
   --  @param Font Font selector; defaults to Hershey_Simplex.
   --  @param Font_Scale Font scale factor: finite, positive and within the
   --  Draw_Text preflight bound. Defaults to 1.0.
   --  @param Thickness Glyph stroke thickness; defaults to 1.
   --  @return The text's bounding Size and Baseline, in pixels.
   --  @exception OpenCV_Error Raised when Font_Scale is not finite and
   --  positive, when nonempty text fails the preflight, and when OpenCV fails.
   function Measure_Text
     (Text       : String;
      Font       : Text_Font := Hershey_Simplex;
      Font_Scale : OpenCV.Float64_Value := 1.0;
      Thickness  : Drawing_Thickness := 1) return Text_Metrics;

   --  Returns the font scale at which Font, drawn with Thickness, has the
   --  requested pixel height, as computed by cv::getFontScaleFromHeight.
   --  Reject heights where `2 * Pixel_Height <= Thickness + 1` (the OpenCV 4
   --  scale would be nonpositive), regardless of the linked OpenCV version;
   --  the comparison uses widened arithmetic. A nonfinite or nonpositive
   --  native scale, or one outside the Draw_Text preflight bounds for a single
   --  character, is also rejected. Text measured at the returned scale can
   --  differ from Pixel_Height by a few pixels because of native rounding and
   --  generation-specific font metrics.
   --  @param Pixel_Height Desired text height in pixels, comparable with the
   --  Size.Height reported by Measure_Text.
   --  @param Font Font selector; defaults to Hershey_Simplex.
   --  @param Thickness Intended glyph stroke thickness; defaults to 1.
   --  @return Positive finite scale, usable as Font_Scale.
   --  @exception OpenCV_Error Raised when `2 * Pixel_Height <= Thickness + 1`,
   --  when the native scale is not finite and positive or fails the preflight,
   --  and when OpenCV fails.
   function Font_Scale_For_Height
     (Pixel_Height : Positive;
      Font         : Text_Font := Hershey_Simplex;
      Thickness    : Drawing_Thickness := 1) return OpenCV.Float64_Value;

   --  Outlines the rectangle Bounds in Image in place with cv::rectangle,
   --  under the package drawing rules. The outline runs through the border
   --  pixels of columns `Bounds.X .. Bounds.X + Bounds.Width - 1` and rows
   --  `Bounds.Y .. Bounds.Y + Bounds.Height - 1`; the interior is not filled.
   --  Width and Height must be positive. The far corner is saturated to the
   --  signed 32-bit range, so extents reaching beyond it are clipped instead
   --  of overflowing.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Bounds Rectangle to outline, with positive Width and Height; it
   --  may extend outside Image.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Thickness Outline thickness in pixels; defaults to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when Bounds.Width or Bounds.Height is
   --  zero, when Image or a used Color component violates the drawing rules,
   --  when Anti_Aliased_Line is used with a non-UInt8 Image, and when OpenCV
   --  fails.
   procedure Draw_Rectangle
     (Image      : in out OpenCV.Core.Mat;
      Bounds     : OpenCV.Rect;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Fills the rectangle Bounds in Image in place with cv::rectangle in
   --  OpenCV's filled mode, under the package drawing rules. Every pixel of
   --  columns `Bounds.X .. Bounds.X + Bounds.Width - 1` and rows
   --  `Bounds.Y .. Bounds.Y + Bounds.Height - 1` inside Image is painted.
   --  Width and Height must be positive. As for Draw_Rectangle, the far corner
   --  is saturated, so huge extents are clipped.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Bounds Rectangle to fill, with positive Width and Height; it may
   --  extend outside Image.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Line_Style Edge rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when Bounds.Width or Bounds.Height is
   --  zero, when Image or a used Color component violates the drawing rules,
   --  when Anti_Aliased_Line is used with a non-UInt8 Image, and when OpenCV
   --  fails.
   procedure Fill_Rectangle
     (Image      : in out OpenCV.Core.Mat;
      Bounds     : OpenCV.Rect;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Outlines the circle of Radius around Center in Image in place with
   --  cv::circle, under the package drawing rules. The outline runs Radius
   --  pixels from Center; the interior is not filled.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Center Circle center; may lie outside Image.
   --  @param Radius Circle radius in pixels.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Thickness Outline thickness in pixels; defaults to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when Image or a used Color component
   --  violates the drawing rules, when Anti_Aliased_Line is used with a
   --  non-UInt8 Image, and when OpenCV fails.
   procedure Draw_Circle
     (Image      : in out OpenCV.Core.Mat;
      Center     : OpenCV.Point;
      Radius     : Drawing_Radius;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Fills the disc of Radius around Center, including Center, in Image in
   --  place with cv::circle in OpenCV's filled mode, under the package drawing
   --  rules.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Center Disc center; may lie outside Image.
   --  @param Radius Disc radius in pixels.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Line_Style Edge rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when Image or a used Color component
   --  violates the drawing rules, when Anti_Aliased_Line is used with a
   --  non-UInt8 Image, and when OpenCV fails.
   procedure Fill_Circle
     (Image      : in out OpenCV.Core.Mat;
      Center     : OpenCV.Point;
      Radius     : Drawing_Radius;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Outlines an elliptic arc in Image in place with cv::ellipse, under the
   --  package drawing rules. The ellipse is centered on Center with semi-axes
   --  Axes and rotated by Angle; the arc runs from Start_Angle to End_Angle,
   --  so a full turn draws the closed outline. With Angle zero, Axes.Width
   --  lies along X and arc angles increase from the +X direction toward +Y
   --  (downward); an Angle of 90 degrees turns Axes.Width vertical. Axes are
   --  the ellipse semi-axis lengths and must both be positive. Angle,
   --  Start_Angle, and End_Angle must be finite. Radians are converted to
   --  degrees in Ada; values are not otherwise normalized.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Center Ellipse center; may lie outside Image.
   --  @param Axes Semi-axis lengths in pixels, Width for the first axis and
   --  Height for the second; both must be positive.
   --  @param Angle Rotation of the ellipse, in Units; must be finite.
   --  @param Start_Angle Start of the arc, in Units; must be finite.
   --  @param End_Angle End of the arc, in Units; must be finite.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Thickness Outline thickness in pixels; defaults to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @param Units Unit of Angle, Start_Angle and End_Angle; defaults to
   --  Degrees.
   --  @exception OpenCV_Error Raised when an axis is zero, when an angle is
   --  not finite, when Image or a used Color component violates the drawing
   --  rules, when Anti_Aliased_Line is used with a non-UInt8 Image, and when
   --  OpenCV fails.
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

   --  Fills an ellipse or elliptic sector in Image in place with cv::ellipse
   --  in OpenCV's filled mode, under the package drawing rules. The geometry
   --  is that of Draw_Ellipse. Fill_Ellipse fills the elliptic sector for a
   --  partial interval and the whole ellipse, including Center, for a full
   --  turn. Axes are the ellipse semi-axis lengths and must both be positive.
   --  Angle, Start_Angle, and End_Angle must be finite. Radians are converted
   --  to degrees in Ada; values are not otherwise normalized.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Center Ellipse center; may lie outside Image.
   --  @param Axes Semi-axis lengths in pixels, Width for the first axis and
   --  Height for the second; both must be positive.
   --  @param Angle Rotation of the ellipse, in Units; must be finite.
   --  @param Start_Angle Start of the sector, in Units; must be finite.
   --  @param End_Angle End of the sector, in Units; must be finite.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Line_Style Edge rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @param Units Unit of Angle, Start_Angle and End_Angle; defaults to
   --  Degrees.
   --  @exception OpenCV_Error Raised when an axis is zero, when an angle is
   --  not finite, when Image or a used Color component violates the drawing
   --  rules, when Anti_Aliased_Line is used with a non-UInt8 Image, and when
   --  OpenCV fails.
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

   --  Draws the connected segments through Points, in array order, into Image
   --  in place with cv::polylines, under the package drawing rules. When
   --  Closed is True a segment from the last point back to the first is added.
   --  Points may use any Natural index bounds, so an extracted Contour can be
   --  passed directly. An open or closed polyline requires at least two
   --  points.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Points Vertices in drawing order, at least two; they may lie
   --  outside Image.
   --  @param Closed True to join the last point back to the first; defaults to
   --  False.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Thickness Line thickness in pixels; defaults to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when Points has fewer than two elements,
   --  when Image or a used Color component violates the drawing rules, when
   --  Anti_Aliased_Line is used with a non-UInt8 Image, and when OpenCV fails.
   procedure Draw_Polyline
     (Image      : in out OpenCV.Core.Mat;
      Points     : OpenCV.Point_Array;
      Closed     : Boolean := False;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Fills the polygon with vertices Points, in array order, in Image in
   --  place, under the package drawing rules. Points may use any Natural index
   --  bounds. A polygon requires at least three points. Concave polygons are
   --  filled by OpenCV fillPoly, leaving their concave notches empty.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Points Polygon vertices, at least three; the polygon closes from
   --  the last point back to the first. They may lie outside Image.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Line_Style Edge rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @exception OpenCV_Error Raised when Points has fewer than three
   --  elements, when Image or a used Color component violates the drawing
   --  rules, when Anti_Aliased_Line is used with a non-UInt8 Image, and when
   --  OpenCV fails.
   procedure Fill_Polygon
     (Image      : in out OpenCV.Core.Mat;
      Points     : OpenCV.Point_Array;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line);

   --  Outlines every contour stored in Contours into Image in place with
   --  cv::drawContours, under the package drawing rules. Select contours in
   --  Ada, independently of the linked OpenCV version: all-contours overloads
   --  use every stored contour (the Root overloads select a subtree), contours
   --  without points are skipped, and the selection is passed to OpenCV as
   --  independent contours without native hierarchy. Offset shifts points in
   --  image/Region-local coordinates. Image and Color obey the ordinary
   --  drawing contract, including UInt8-only Anti_Aliased_Line. When no
   --  selected contour has points the call is a no-op after Image, Color and
   --  Line_Style validation. Counts and point-plus-Offset sums are checked
   --  before any pixel is written: structural errors leave Image unchanged;
   --  native drawing errors need not roll back.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Contours Contour set to draw, normally from Find_Contours.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Thickness Outline thickness in pixels; defaults to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @param Offset Added to every point before rasterization, in Image
   --  (Region-local) coordinates; defaults to (0, 0).
   --  @exception OpenCV_Error Raised when Image or a used Color component
   --  violates the drawing rules, when Anti_Aliased_Line is used with a
   --  non-UInt8 Image, when the selected point or contour count exceeds the
   --  signed 32-bit range, when a point plus Offset leaves that range, and
   --  when OpenCV fails.
   procedure Draw_Contours
     (Image      : in out OpenCV.Core.Mat;
      Contours   : Contour_Set;
      Color      : OpenCV.Scalar;
      Thickness  : Drawing_Thickness := 1;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line;
      Offset     : OpenCV.Point := (X => 0, Y => 0));

   --  Outlines the contour Root and up to Descendant_Levels generations of its
   --  descendants into Image in place; otherwise as the all-contours
   --  Draw_Contours. Contours are selected in Ada, independently of the linked
   --  OpenCV version, by following First_Child and Next links rather than
   --  storage order: zero levels means Root only, and a depth beyond the tree
   --  includes every reachable descendant. Contours without points are
   --  skipped. Offset shifts points in image/Region-local coordinates. Image
   --  and Color obey the ordinary drawing contract. Structural errors,
   --  including an invalid Root, leave Image unchanged; native drawing errors
   --  need not roll back.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Contours Contour set containing Root, normally from
   --  Find_Contours.
   --  @param Root Index of the selected subtree's root; must be less than
   --  Contour_Count (Contours).
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Descendant_Levels Generations below Root to include: zero selects
   --  Root only, one adds its children, two also adds grandchildren. Defaults
   --  to 0.
   --  @param Thickness Outline thickness in pixels; defaults to 1.
   --  @param Line_Style Rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @param Offset Added to every point before rasterization, in Image
   --  (Region-local) coordinates; defaults to (0, 0).
   --  @exception OpenCV_Error Raised when Root is not less than Contour_Count
   --  (Contours), when the hierarchy reached from Root is inconsistent, when
   --  Image or a used Color component violates the drawing rules, when
   --  Anti_Aliased_Line is used with a non-UInt8 Image, when the selected
   --  point count or a point plus Offset exceeds the signed 32-bit range, and
   --  when OpenCV fails.
   procedure Draw_Contours
     (Image             : in out OpenCV.Core.Mat;
      Contours          : Contour_Set;
      Root              : Contour_Index;
      Color             : OpenCV.Scalar;
      Descendant_Levels : Natural := 0;
      Thickness         : Drawing_Thickness := 1;
      Line_Style        : Drawing_Line_Style := Eight_Connected_Line;
      Offset            : OpenCV.Point := (X => 0, Y => 0));

   --  Fills every contour stored in Contours into Image in place with
   --  cv::drawContours in OpenCV's filled mode, under the package drawing
   --  rules. Filled contours use even-odd parity over the whole selection: an
   --  outer contour alone fills its interior, an added hole remains empty, and
   --  an island inside the hole is filled again, so holes and islands of one
   --  Find_Contours result are preserved. Select contours in Ada,
   --  independently of the linked OpenCV version: all-contours overloads use
   --  every stored contour (the Root overloads select a subtree), and contours
   --  without points are skipped. Offset shifts points in image/Region-local
   --  coordinates. Image and Color obey the ordinary drawing contract,
   --  including UInt8-only Anti_Aliased_Line. When no selected contour has
   --  points the call is a no-op after Image, Color and Line_Style validation.
   --  Structural errors leave Image unchanged; native drawing errors need not
   --  roll back.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Contours Contour set to fill, normally from Find_Contours.
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Line_Style Edge rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @param Offset Added to every point before rasterization, in Image
   --  (Region-local) coordinates; defaults to (0, 0).
   --  @exception OpenCV_Error Raised when Image or a used Color component
   --  violates the drawing rules, when Anti_Aliased_Line is used with a
   --  non-UInt8 Image, when the selected point or contour count exceeds the
   --  signed 32-bit range, when a point plus Offset leaves that range, and
   --  when OpenCV fails.
   procedure Fill_Contours
     (Image      : in out OpenCV.Core.Mat;
      Contours   : Contour_Set;
      Color      : OpenCV.Scalar;
      Line_Style : Drawing_Line_Style := Eight_Connected_Line;
      Offset     : OpenCV.Point := (X => 0, Y => 0));

   --  Fills the contour Root and up to Descendant_Levels generations of its
   --  descendants into Image in place, with even-odd parity over that
   --  selection; otherwise as the all-contours Fill_Contours. With zero levels
   --  Root is filled including the area of its holes, one level empties its
   --  child holes, and two refills islands inside them. Contours are selected
   --  in Ada, independently of the linked OpenCV version, by following
   --  First_Child and Next links rather than storage order; a depth beyond the
   --  tree includes every reachable descendant. Contours without points are
   --  skipped. Offset shifts points in image/Region-local coordinates. Image
   --  and Color obey the ordinary drawing contract. Structural errors,
   --  including an invalid Root, leave Image unchanged; native drawing errors
   --  need not roll back.
   --  @param Image Target modified in place: a nonempty 2-D UInt8, UInt16,
   --  Int16, Float32 or Float64 Mat or Region with 1 to 4 channels.
   --  @param Contours Contour set containing Root, normally from
   --  Find_Contours.
   --  @param Root Index of the selected subtree's root; must be less than
   --  Contour_Count (Contours).
   --  @param Color Value written in channel order; the components used by
   --  Image's channels must be finite.
   --  @param Descendant_Levels Generations below Root to include: zero selects
   --  Root only, one adds its children, two also adds grandchildren. Defaults
   --  to 0.
   --  @param Line_Style Edge rasterization; defaults to Eight_Connected_Line.
   --  Anti_Aliased_Line requires a UInt8 Image.
   --  @param Offset Added to every point before rasterization, in Image
   --  (Region-local) coordinates; defaults to (0, 0).
   --  @exception OpenCV_Error Raised when Root is not less than Contour_Count
   --  (Contours), when the hierarchy reached from Root is inconsistent, when
   --  Image or a used Color component violates the drawing rules, when
   --  Anti_Aliased_Line is used with a non-UInt8 Image, when the selected
   --  point count or a point plus Offset exceeds the signed 32-bit range, and
   --  when OpenCV fails.
   procedure Fill_Contours
     (Image             : in out OpenCV.Core.Mat;
      Contours          : Contour_Set;
      Root              : Contour_Index;
      Color             : OpenCV.Scalar;
      Descendant_Levels : Natural := 0;
      Line_Style        : Drawing_Line_Style := Eight_Connected_Line;
      Offset            : OpenCV.Point := (X => 0, Y => 0));

   --  Find_Hough_Lines runs the classical standard Hough transform on a
   --  nonempty two-dimensional UInt8 C1 binary Source: zero pixels are
   --  background and every nonzero pixel (not only 255) is a candidate.
   --  Distance_Resolution (pixels) and Angle_Resolution_Radians must be
   --  positive and finite. The angle bounds must be finite with
   --  0 <= Minimum_Angle_Radians < Maximum_Angle_Radians <= Pi. OpenCV keeps
   --  accumulator bins that are strict local maxima with more than
   --  Vote_Threshold votes. Each result is an accumulator bin, so Rho and
   --  Angle_Radians are quantized by the requested resolutions; expect
   --  agreement with exact geometry within about one bin. OpenCV 5.0
   --  reconstructs Rho with integer arithmetic where OpenCV 4.x uses a
   --  half-bin offset, so Rho can differ by up to half a distance bin
   --  between generations. Multiscale srn/stn, OpenCV 5 edge-value
   --  weighting, and accumulator votes are not exposed;
   --  Find_Hough_Lines_With_Votes reports votes.
   --
   --  OpenCV narrows the resolutions and angle bounds to binary32 and sizes
   --  its accumulator with signed int arithmetic. Requests that would
   --  overflow it are rejected: a Source whose pixel count or
   --  `2 * (Rows + Columns) + 1` exceeds native int range, a resolution
   --  whose bin counts or accumulator size exceed native int range, a
   --  Distance_Resolution too coarse for the accumulator's vote
   --  columns, or a nonzero-pixel count times angle-bin count beyond native
   --  int range (the IPP line estimate, checked on every build). There is
   --  no arbitrary resolution floor.
   --  @param Source Binary image to analyse: nonempty 2-D UInt8 C1, with
   --  every nonzero pixel a candidate.
   --  @param Distance_Resolution Rho bin width in pixels; positive and
   --  finite.
   --  @param Angle_Resolution_Radians Angle bin width in radians; positive
   --  and finite.
   --  @param Vote_Threshold Accumulator votes that a reported line must
   --  strictly exceed.
   --  @param Minimum_Angle_Radians Lowest searched angle, in radians;
   --  finite, at least 0.0 and below Maximum_Angle_Radians. Default 0.0.
   --  @param Maximum_Angle_Radians Highest searched angle, in radians;
   --  finite and at most Pi. Default Pi.
   --  @return Fresh Ada array of lines in unspecified order. Nonempty
   --  results start at zero; when no line is found the result is the null
   --  range 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Source, a nonpositive or nonfinite resolution, invalid
   --  angle bounds, native accumulator arithmetic that cannot be
   --  represented, or an OpenCV failure.
   function Find_Hough_Lines
     (Source                   : OpenCV.Core.Mat;
      Distance_Resolution      : OpenCV.Float64_Value;
      Angle_Resolution_Radians : OpenCV.Float64_Value;
      Vote_Threshold           : Hough_Vote_Threshold;
      Minimum_Angle_Radians    : OpenCV.Float64_Value := 0.0;
      Maximum_Angle_Radians    : OpenCV.Float64_Value := Ada.Numerics.Pi)
      return Hough_Line_Array;

   --  Find_Hough_Line_Segments runs the probabilistic Hough transform on the
   --  same binary Source contract as Find_Hough_Lines (zero is background,
   --  every nonzero pixel a candidate), without angle bounds.
   --  Minimum_Line_Length and Maximum_Line_Gap are integer pixel counts,
   --  because OpenCV rounds them to integers. A segment is kept when its X
   --  or Y extent reaches Minimum_Line_Length; up to Maximum_Line_Gap
   --  missing pixels may be bridged along a line. The native walk uses a
   --  fixed internal random seed, but endpoints may still differ by a pixel
   --  or two across OpenCV builds, so compare them with a small tolerance.
   --
   --  Requests whose native int accumulator or fixed-point walk arithmetic
   --  would overflow are rejected: the Source limits of Find_Hough_Lines, a
   --  resolution whose accumulator sizing exceeds native int range, a
   --  Distance_Resolution too coarse for the accumulator, and any Source
   --  with more than 32765 rows or columns (OpenCV 4.1 and 4.10 walk
   --  segments in 16.16 fixed point; the limit applies on every version).
   --  @param Source Binary image to analyse: nonempty 2-D UInt8 C1, with
   --  every nonzero pixel a candidate.
   --  @param Distance_Resolution Rho bin width in pixels; positive and
   --  finite.
   --  @param Angle_Resolution_Radians Angle bin width in radians; positive
   --  and finite.
   --  @param Vote_Threshold Accumulator vote threshold for the candidate
   --  lines of the probabilistic walk.
   --  @param Minimum_Line_Length Shortest kept segment, as its X or Y
   --  extent in pixels; default 0.
   --  @param Maximum_Line_Gap Largest bridged run of missing pixels along a
   --  line; default 0.
   --  @return Fresh Ada array of segments in unspecified order, each with
   --  unspecified endpoint order. Nonempty results start at zero; when no
   --  segment is found the result is the null range 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Source, a nonpositive or nonfinite resolution, native
   --  accumulator or walk arithmetic that cannot be represented, or an
   --  OpenCV failure.
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
   --  grayscale Source; it computes its own Sobel/Canny edges, so blurring
   --  the input first usually improves results. Accumulator_Scale is the
   --  inverse accumulator resolution and must be finite and at least 1.0
   --  (OpenCV would silently clamp smaller values; this API rejects them).
   --  Minimum_Center_Distance must be positive and finite. Canny_Threshold
   --  is the upper Canny threshold (the lower one is half of it, but at
   --  least one). Accumulator_Threshold is the center-vote threshold; OpenCV
   --  also applies it to radius support when estimating radii.
   --
   --  This overload searches radii from Minimum_Radius up to an automatic
   --  maximum chosen by OpenCV (the larger Source dimension). Radius
   --  estimation squares that maximum in native int, so a Source with more
   --  than 46340 rows or columns is rejected. Also rejected: a radius range
   --  that yields no radius-histogram bin at this Accumulator_Scale (for
   --  example Minimum_Radius not below the larger Source dimension), an
   --  accumulator whose padded size exceeds native int indexing, and
   --  `(larger Source dimension + Minimum_Radius + 2) * 1024` beyond native
   --  int range (the fixed-point voting walk).
   --  @param Source Grayscale image to analyse: nonempty 2-D UInt8 C1.
   --  @param Accumulator_Scale Inverse accumulator resolution (OpenCV dp),
   --  finite and at least 1.0; the value 1.0 keeps Source resolution.
   --  @param Minimum_Center_Distance Minimum distance between detected
   --  centers (OpenCV minDist); positive and finite.
   --  @param Canny_Threshold Upper threshold of the internal Canny edge
   --  detector; the lower one is half of it, but at least one.
   --  @param Accumulator_Threshold Accumulator vote threshold for circle
   --  centers, also applied to radius support.
   --  @param Minimum_Radius Smallest searched radius in pixels; default 0.
   --  With the automatic maximum it must leave a nonempty radius range.
   --  @return Fresh Ada array of circles in unspecified order. Nonempty
   --  results start at zero; when no circle is found the result is the
   --  null range 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Source, an invalid Accumulator_Scale or
   --  Minimum_Center_Distance, an empty radius range, native arithmetic that
   --  cannot be represented, or an OpenCV failure.
   function Find_Hough_Circles
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0)
      return Hough_Circle_Array;

   --  This overload of Find_Hough_Circles has the same HOUGH_GRADIENT
   --  detector, Source, threshold and result contract as the
   --  automatic-maximum overload, but searches the explicit radius interval
   --  Minimum_Radius .. Maximum_Radius. Maximum_Radius must exceed
   --  Minimum_Radius; it is never silently widened (OpenCV would rewrite an
   --  invalid maximum to Minimum_Radius + 2). Maximum_Radius must be at most
   --  46340, because radius estimation squares it in native int, and the
   --  interval must yield at least one radius-histogram bin at this
   --  Accumulator_Scale. The accumulator and fixed-point limits of the other
   --  overload also apply.
   --  @param Source Grayscale image to analyse: nonempty 2-D UInt8 C1.
   --  @param Accumulator_Scale Inverse accumulator resolution (OpenCV dp),
   --  finite and at least 1.0.
   --  @param Minimum_Center_Distance Minimum distance between detected
   --  centers (OpenCV minDist); positive and finite.
   --  @param Canny_Threshold Upper threshold of the internal Canny edge
   --  detector; the lower one is half of it, but at least one.
   --  @param Accumulator_Threshold Accumulator vote threshold for circle
   --  centers, also applied to radius support.
   --  @param Minimum_Radius Smallest searched radius in pixels; default 0.
   --  @param Maximum_Radius Largest searched radius in pixels; greater than
   --  Minimum_Radius and at most 46340.
   --  @return Fresh Ada array of circles in unspecified order. Nonempty
   --  results start at zero; when no circle is found the result is the
   --  null range 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Source, an invalid Accumulator_Scale or
   --  Minimum_Center_Distance, Maximum_Radius <= Minimum_Radius, an empty
   --  radius range, native arithmetic that cannot be represented, or an
   --  OpenCV failure.
   function Find_Hough_Circles
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0;
      Maximum_Radius          : OpenCV.Size_Coordinate)
      return Hough_Circle_Array;

   --  Find_Hough_Lines_With_Votes has exactly the contract of
   --  Find_Hough_Lines and adds each line's accumulator votes. OpenCV's
   --  optional IPP standard-Hough path is available only to the vote-free
   --  output, so on IPP-enabled builds the two operations need not return
   --  identical lines or ordering. Votes come from OpenCV's binary32 Vec3f
   --  output: integer counts, normally above Vote_Threshold, which may
   --  already have been rounded when above `2**24`.
   --  @param Source Binary image to analyse: nonempty 2-D UInt8 C1, with
   --  every nonzero pixel a candidate.
   --  @param Distance_Resolution Rho bin width in pixels; positive and
   --  finite.
   --  @param Angle_Resolution_Radians Angle bin width in radians; positive
   --  and finite.
   --  @param Vote_Threshold Accumulator votes that a reported line must
   --  strictly exceed.
   --  @param Minimum_Angle_Radians Lowest searched angle, in radians;
   --  finite, at least 0.0 and below Maximum_Angle_Radians. Default 0.0.
   --  @param Maximum_Angle_Radians Highest searched angle, in radians;
   --  finite and at most Pi. Default Pi.
   --  @return Fresh Ada array of lines with votes, in unspecified order.
   --  Nonempty results start at zero; when no line is found the result is
   --  the null range 1 .. 0.
   --  @exception OpenCV_Error Raised for the same conditions as
   --  Find_Hough_Lines: an invalid Source, resolution or angle bound,
   --  native accumulator arithmetic that cannot be represented, or an
   --  OpenCV failure.
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
   --  behave safely). Since `abs (Rho) <= sqrt (X**2 + Y**2)`, a range
   --  reaching a little beyond plus and minus the largest point distance
   --  from the origin always works. Angle bounds satisfy
   --  0 <= Minimum_Angle_Radians < Maximum_Angle_Radians <= Pi, and each
   --  resolution must yield at least one bin: both
   --  `(Maximum_Rho - Minimum_Rho + 1) / Distance_Resolution` and the angle
   --  span divided by Angle_Resolution_Radians must be at least 1. At most
   --  Maximum_Lines results are returned; an empty point set returns the
   --  empty result without calling OpenCV. Votes come from OpenCV's Vec3d
   --  output, so they are exact integer counts. Rho bounds must lie within
   --  binary32 range, and requests whose native bin counts, accumulator
   --  indexing or binary32 vote arithmetic cannot be represented are
   --  rejected.
   --  @param Points Points that vote, as binary32 coordinates; any bounds,
   --  possibly empty, every coordinate finite.
   --  @param Maximum_Lines Upper bound on the number of returned lines, a
   --  cap rather than a requested count.
   --  @param Vote_Threshold Accumulator vote threshold; OpenCV keeps lines
   --  whose votes exceed it.
   --  @param Minimum_Rho Start of the first rho bin and lower rho bound, in
   --  point coordinate units; finite and below Maximum_Rho.
   --  @param Maximum_Rho Upper rho bound, in point coordinate units; finite.
   --  @param Distance_Resolution Rho bin width; positive and finite.
   --  @param Minimum_Angle_Radians Lowest searched angle, in radians;
   --  finite, at least 0.0 and below Maximum_Angle_Radians. Default 0.0.
   --  @param Maximum_Angle_Radians Highest searched angle, in radians;
   --  finite and at most Pi. Default Pi.
   --  @param Angle_Resolution_Radians Angle bin width in radians; positive
   --  and finite. Default Hough_Degree.
   --  @return Fresh Ada array of lines with votes, in unspecified order.
   --  Nonempty results start at zero; when no line is found the result is
   --  the null range 1 .. 0.
   --  @exception OpenCV_Error Raised for a nonfinite point
   --  coordinate, invalid or nonfinite rho or angle bounds, a resolution
   --  that is not positive and finite or yields no bin, a point voting
   --  outside the rho range, native arithmetic that cannot be represented,
   --  or an OpenCV failure.
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
   --  still limits how close to each edge pixel center votes are cast, and
   --  OpenCV's automatic maximum (the larger Source dimension) still bounds
   --  the voting walk. It uses OpenCV's private centers-only mode, never
   --  exposed, and discards OpenCV's placeholder radius. Because no radius
   --  is estimated, the radius-estimation limits of Find_Hough_Circles (the
   --  46340 maximum radius and a nonempty radius histogram) do not apply;
   --  the accumulator and fixed-point limits do.
   --  @param Source Grayscale image to analyse: nonempty 2-D UInt8 C1.
   --  @param Accumulator_Scale Inverse accumulator resolution (OpenCV dp),
   --  finite and at least 1.0.
   --  @param Minimum_Center_Distance Minimum distance between detected
   --  centers (OpenCV minDist); positive and finite.
   --  @param Canny_Threshold Upper threshold of the internal Canny edge
   --  detector; the lower one is half of it, but at least one.
   --  @param Accumulator_Threshold Accumulator vote threshold for circle
   --  centers.
   --  @param Minimum_Radius Smallest radius, in pixels, at which center
   --  votes are cast from each edge pixel; default 0.
   --  @return Fresh Ada array of centers in Source pixel coordinates, in
   --  unspecified order. Nonempty results start at zero; when no center is
   --  found the result is the null range 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Source, an invalid Accumulator_Scale or
   --  Minimum_Center_Distance, native accumulator arithmetic that cannot be
   --  represented, or an OpenCV failure.
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
   --  count of each estimated radius. They always estimate radii and never
   --  use the centers-only mode, whose native fourth component is an
   --  accumulator index rather than a vote count. This overload has the
   --  contract of the automatic-maximum Find_Hough_Circles: radii from
   --  Minimum_Radius up to the larger Source dimension, which must be at
   --  most 46340, with the same rejections. Votes come from OpenCV's
   --  binary32 Vec4f output: integer counts that may already have been
   --  rounded when above `2**24`.
   --  @param Source Grayscale image to analyse: nonempty 2-D UInt8 C1.
   --  @param Accumulator_Scale Inverse accumulator resolution (OpenCV dp),
   --  finite and at least 1.0.
   --  @param Minimum_Center_Distance Minimum distance between detected
   --  centers (OpenCV minDist); positive and finite.
   --  @param Canny_Threshold Upper threshold of the internal Canny edge
   --  detector; the lower one is half of it, but at least one.
   --  @param Accumulator_Threshold Accumulator vote threshold for circle
   --  centers, also applied to radius support.
   --  @param Minimum_Radius Smallest searched radius in pixels; default 0.
   --  With the automatic maximum it must leave a nonempty radius range.
   --  @return Fresh Ada array of circles with votes, in unspecified order.
   --  Nonempty results start at zero; when no circle is found the result
   --  is the null range 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Source, an invalid Accumulator_Scale or
   --  Minimum_Center_Distance, an empty radius range, native arithmetic that
   --  cannot be represented, or an OpenCV failure.
   function Find_Hough_Circles_With_Votes
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0)
      return Hough_Circle_With_Votes_Array;

   --  This overload of Find_Hough_Circles_With_Votes mirrors the
   --  explicit-interval Find_Hough_Circles: radii from Minimum_Radius to
   --  Maximum_Radius, which must exceed Minimum_Radius (never silently
   --  widened) and be at most 46340, with the same rejections. Like the
   --  other overload it always estimates radii and reports, for each
   --  circle, the support count of the chosen radius from OpenCV's binary32
   --  Vec4f output (counts above `2**24` may already have been rounded).
   --  @param Source Grayscale image to analyse: nonempty 2-D UInt8 C1.
   --  @param Accumulator_Scale Inverse accumulator resolution (OpenCV dp),
   --  finite and at least 1.0.
   --  @param Minimum_Center_Distance Minimum distance between detected
   --  centers (OpenCV minDist); positive and finite.
   --  @param Canny_Threshold Upper threshold of the internal Canny edge
   --  detector; the lower one is half of it, but at least one.
   --  @param Accumulator_Threshold Accumulator vote threshold for circle
   --  centers, also applied to radius support.
   --  @param Minimum_Radius Smallest searched radius in pixels; default 0.
   --  @param Maximum_Radius Largest searched radius in pixels; greater than
   --  Minimum_Radius and at most 46340.
   --  @return Fresh Ada array of circles with votes, in unspecified order.
   --  Nonempty results start at zero; when no circle is found the result
   --  is the null range 1 .. 0.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  non-UInt8 C1 Source, an invalid Accumulator_Scale or
   --  Minimum_Center_Distance, Maximum_Radius <= Minimum_Radius, an empty
   --  radius range, native arithmetic that cannot be represented, or an
   --  OpenCV failure.
   function Find_Hough_Circles_With_Votes
     (Source                  : OpenCV.Core.Mat;
      Accumulator_Scale       : OpenCV.Float64_Value;
      Minimum_Center_Distance : OpenCV.Float64_Value;
      Canny_Threshold         : Hough_Circle_Threshold;
      Accumulator_Threshold   : Hough_Circle_Threshold;
      Minimum_Radius          : OpenCV.Size_Coordinate := 0;
      Maximum_Radius          : OpenCV.Size_Coordinate)
      return Hough_Circle_With_Votes_Array;

   --  Reference value that a flood-fill candidate pixel is compared with.
   --  Floating_Range compares each candidate with its already-filled
   --  neighbour; Fixed_Range compares every candidate with the seed pixel.
   --  @enum Floating_Range Compare with the adjacent pixel already in the
   --  component, so the fill can follow a gradual ramp.
   --  @enum Fixed_Range Compare with the seed pixel, so every filled pixel
   --  lies within the differences of the seed value.
   type Flood_Fill_Range_Mode is (Floating_Range, Fixed_Range);

   --  Nonzero byte that Flood_Fill_With_Mask writes into its Mask for every
   --  filled pixel; a fill enters only zero mask pixels.
   subtype Flood_Fill_Mask_Value is OpenCV.UInt8_Value range 1 .. 255;

   --  Outcome of a successful flood fill, also reported in mask-only mode.
   --  Pixel_Count is the number of filled pixels. Bounds is the smallest
   --  rectangle containing them, in the coordinates of the supplied Image.
   --  @field Pixel_Count Number of pixels in the filled component.
   --  @field Bounds Smallest rectangle containing the filled pixels, in the
   --  supplied Image's coordinates (a Region's own coordinates).
   type Flood_Fill_Result is record
      Pixel_Count : Natural;
      Bounds      : OpenCV.Rect;
   end record;

   --  Fills the connected component containing Seed with New_Value in place.
   --  Image must be a nonempty two-dimensional UInt8, Int32, or Float32 Mat
   --  with one or three channels; Seed (X is the column, Y the row) is
   --  inside it. A neighbour joins the component when every channel lies
   --  within `reference - Lower_Difference .. reference + Upper_Difference`,
   --  where the reference follows Range_Mode. The components used by
   --  Image's channels must be finite, and the differences nonnegative;
   --  unused components are ignored. A Region is filled as its own logical
   --  image and mutates its parent's storage; shallow aliases observe the
   --  mutation. Validation failures leave Image unchanged.
   --
   --  Int32 requires each channel's stored maximum minus minimum <= INT_MAX
   --  to prevent native signed subtraction overflow (including mask-only).
   --  Active Int32 New_Value lies in Int32_Value'First .. Int32_Value'Last;
   --  differences lie in 0 .. Int32_Value'Last. Native rounding of New_Value
   --  and flooring of differences preserve fractional Scalar semantics.
   --  Float32 Images need the components used within the finite Float32
   --  range; UInt8 components must not exceed INT_MAX in magnitude. Native
   --  segment coordinates limit Image to 65535 rows and 65535 columns, and
   --  its pixel count and row-offset arithmetic must fit a signed int.
   --  @param Image Image filled in place.
   --  @param Seed Starting pixel, inside Image.
   --  @param New_Value Replacement value in channel order; components beyond
   --  Image's channel count are ignored.
   --  @param Result Receives the filled pixel count and bounds; assigned
   --  only on success.
   --  @param Lower_Difference Nonnegative per-channel amount a neighbour may
   --  lie below the reference; defaults to zero.
   --  @param Upper_Difference Nonnegative per-channel amount a neighbour may
   --  lie above the reference; defaults to zero.
   --  @param Connectivity Neighbourhood used for growth; defaults to
   --  Four_Connected.
   --  @param Range_Mode Choice of reference value; defaults to
   --  Floating_Range.
   --  @exception OpenCV_Error Raised for an empty, non-2-D or
   --  unsupported Image, a Seed outside Image, a nonfinite or out-of-range
   --  component in use, a negative difference, an Int32 span or native size
   --  limit, or an OpenCV failure.
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
   --  New_Value is ignored (not even validated); Mask and Result are still
   --  updated. Mask must be nonempty and is modified in place.
   --
   --  Image, Seed, difference, connectivity, Region, Int32 and native-limit
   --  rules are those of Flood_Fill; the Int32 span rule also applies in
   --  mask-only mode. Validation failures leave Image and Mask unchanged,
   --  including the mask border.
   --  @param Image Image filled in place; unchanged when Mask_Only is True.
   --  @param Mask UInt8 C1 guide and record of the fill, two rows and two
   --  columns larger than Image, updated in place.
   --  @param Seed Starting pixel, inside Image.
   --  @param New_Value Replacement value in channel order; ignored when
   --  Mask_Only is True.
   --  @param Result Receives the filled pixel count and bounds; assigned
   --  only on success.
   --  @param Lower_Difference Nonnegative per-channel amount a neighbour may
   --  lie below the reference; defaults to zero.
   --  @param Upper_Difference Nonnegative per-channel amount a neighbour may
   --  lie above the reference; defaults to zero.
   --  @param Connectivity Neighbourhood used for growth; defaults to
   --  Four_Connected.
   --  @param Range_Mode Choice of reference value; defaults to
   --  Floating_Range.
   --  @param Mask_Fill_Value Byte written into Mask for each filled pixel;
   --  defaults to 1.
   --  @param Mask_Only When True, only Mask and Result are updated; defaults
   --  to False.
   --  @exception OpenCV_Error Raised for any Flood_Fill rejection, an
   --  empty or non-UInt8-C1 Mask, a Mask not two rows and columns larger
   --  than Image, Mask storage shared with Image, or an OpenCV failure.
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
   --
   --  Markers is mutated directly, never cloned: shallow copies observe the
   --  labels, and a Markers Region writes through to its parent while
   --  parent elements outside the Region stay unchanged (the Region's own
   --  outer border becomes -1). Strides and pixel count must fit OpenCV's
   --  signed-int offset and node-pool arithmetic. Validation failures
   --  leave Markers unchanged.
   --  @param Source Nonempty 2-D UInt8 C3 image whose colours guide the
   --  flooding.
   --  @param Markers Int32 C1 seed labels on input and region labels with
   --  -1 boundaries on output, updated in place.
   --  @exception OpenCV_Error Raised when Source is not a nonempty
   --  2-D UInt8 C3 image, when Markers is not a nonempty 2-D Int32 C1 Mat
   --  of Source's rows and columns or holds a negative value, when Markers
   --  shares storage with Source, for a native size limit, or when OpenCV
   --  fails.
   procedure Watershed
     (Source : OpenCV.Core.Mat; Markers : in out OpenCV.Core.Mat);

   --  Per-pixel GrabCut label, stored in the state mask with OpenCV's
   --  numeric encoding (see GrabCut_Label_Value). Segmentation never
   --  changes a definite label and moves probable pixels only between the
   --  two probable labels.
   --  @enum Definite_Background Value 0: fixed background.
   --  @enum Definite_Foreground Value 1: fixed foreground.
   --  @enum Probable_Background Value 2: likely background, re-estimated by
   --  segmentation.
   --  @enum Probable_Foreground Value 3: likely foreground, re-estimated by
   --  segmentation.
   type GrabCut_Label is
     (Definite_Background,
      Definite_Foreground,
      Probable_Background,
      Probable_Foreground);

   --  Numeric mask encoding: Definite_Background 0, Definite_Foreground 1,
   --  Probable_Background 2, Probable_Foreground 3.
   --  @param Label Label to encode.
   --  @return The byte 0 .. 3 that represents Label in a GrabCut mask.
   function GrabCut_Label_Value
     (Label : GrabCut_Label) return OpenCV.UInt8_Value;

   --  Inverse of GrabCut_Label_Value. Values above 3 raise OpenCV_Error.
   --  @param Value GrabCut mask byte, 0 .. 3.
   --  @return The label that Value encodes.
   --  @exception OpenCV_Error Raised when Value is greater than 3.
   function To_GrabCut_Label (Value : OpenCV.UInt8_Value) return GrabCut_Label;

   --  Number of GrabCut rounds to run; each round relearns the colour
   --  models and re-segments the probable pixels.
   subtype GrabCut_Iterations is Positive range 1 .. 2_147_483_647;

   --  Minimum background and foreground pixel counts required to initialize
   --  GrabCut portably: OpenCV 4.1 clusters each training set into five
   --  Gaussian-mixture components with k-means, which needs five samples.
   --  OpenCV 4.10 and 5.0 would reduce the component count instead.
   --  Restore_GrabCut_State does not apply this minimum.
   GrabCut_Minimum_Training_Pixels : constant := 5;

   --  Columns of each Float64 C1 1 x 65 native GrabCut mixture model: five
   --  component weights (columns 0 .. 4), 15 means (5 .. 19), and five
   --  3 x 3 covariance matrices (20 .. 64). The layout is specific to
   --  OpenCV GrabCut and the same in OpenCV 4.1, 4.10 and 5.0.
   GrabCut_Model_Column_Count : constant Positive := 65;

   --  GrabCut segmentation state: a private label mask plus hidden
   --  background and foreground colour models. The type is limited, so a
   --  state cannot be shallow-copied. A default-initialized state is
   --  uninitialized and is rejected by every operation except Is_Initialized.
   --  Each state exclusively owns its Mats, which are released by normal
   --  Mat finalization; two states never share mutable storage.
   type GrabCut_State is limited private;

   --  Reports whether State holds a label mask and models, that is, whether
   --  it was produced by Initialize_GrabCut, Restore_GrabCut_State or
   --  Clone_GrabCut_State. It never raises.
   --  @param State State to query; it may be default-initialized.
   --  @return True for an initialized state, False for a default-initialized
   --  one.
   function Is_Initialized (State : GrabCut_State) return Boolean;

   --  Initializes from Source, a nonempty two-dimensional UInt8 C3 image,
   --  and Foreground_Region, which must have positive size, lie entirely
   --  inside Source, and leave at least GrabCut_Minimum_Training_Pixels
   --  pixels both inside and outside. Pixels outside the region start as
   --  Definite_Background and inside as Probable_Foreground; Iterations
   --  rounds of segmentation then run. Source is not modified.
   --  Foreground_Region coordinates are relative to the supplied Source
   --  view. Exact labels near object boundaries can differ between OpenCV
   --  4.1 and later releases, whose mixture initialization differs. The
   --  pixel count must fit OpenCV's signed-int graph-size arithmetic.
   --  @param Source Nonempty 2-D UInt8 C3 image to segment.
   --  @param Foreground_Region Rectangle that contains the object; pixels
   --  outside it are definite background.
   --  @param Iterations Segmentation rounds to run; defaults to 1.
   --  @return New initialized state with a UInt8 C1 label mask of Source's
   --  rows and columns and the learned models.
   --  @exception OpenCV_Error Raised when Source is not a nonempty
   --  2-D UInt8 C3 image, when Foreground_Region is empty, extends outside
   --  Source or leaves fewer than five pixels inside or outside, for a
   --  native size limit, or when OpenCV fails.
   function Initialize_GrabCut
     (Source            : OpenCV.Core.Mat;
      Foreground_Region : OpenCV.Rect;
      Iterations        : GrabCut_Iterations := 1) return GrabCut_State;

   --  Initializes from Source and a caller-built label mask. Initial_Mask
   --  must be a two-dimensional UInt8 C1 Mat with Source's rows and columns
   --  holding only values 0 .. 3 (see GrabCut_Label_Value), with at least
   --  GrabCut_Minimum_Training_Pixels background (definite or probable) and
   --  foreground (definite or probable) pixels. The state owns a deep copy;
   --  Initial_Mask and Source are not modified. Iterations rounds of
   --  segmentation then run; definite labels keep their values. Source
   --  requirements and size limits are those of the rectangle overload.
   --  @param Source Nonempty 2-D UInt8 C3 image to segment.
   --  @param Initial_Mask Nonempty UInt8 C1 label mask of Source's geometry,
   --  values 0 .. 3.
   --  @param Iterations Segmentation rounds to run; defaults to 1.
   --  @return New initialized state owning a segmented copy of Initial_Mask
   --  and the learned models.
   --  @exception OpenCV_Error Raised for an invalid Source, an
   --  Initial_Mask that is empty, not 2-D UInt8 C1, of another geometry or
   --  holds a value above 3, fewer than five background or foreground
   --  pixels, a native size limit, or an OpenCV failure.
   function Initialize_GrabCut
     (Source       : OpenCV.Core.Mat;
      Initial_Mask : OpenCV.Core.Mat;
      Iterations   : GrabCut_Iterations := 1) return GrabCut_State;

   --  Combines caller labels with a rectangle: every label outside the
   --  region becomes Definite_Background, while all four labels inside are
   --  preserved before segmentation. Requires five pixels of each training
   --  class in the constrained mask. Source and Initial_Mask are unchanged.
   --  The binding applies the rectangle to a private copy of Initial_Mask
   --  and runs native mask initialization, because OpenCV's combined
   --  rectangle-or-mask flag selects mask mode alone. Foreground_Region must
   --  have positive size and lie inside Source; background labels inside it
   --  count towards the five background pixels. Otherwise as the mask
   --  overload.
   --  @param Source Nonempty 2-D UInt8 C3 image to segment.
   --  @param Initial_Mask Nonempty UInt8 C1 label mask of Source's geometry,
   --  values 0 .. 3; its labels inside Foreground_Region are kept.
   --  @param Foreground_Region Rectangle outside which every label becomes
   --  Definite_Background.
   --  @param Iterations Segmentation rounds to run; defaults to 1.
   --  @return New initialized state owning the constrained, segmented mask
   --  and the learned models.
   --  @exception OpenCV_Error Raised for an invalid Source or
   --  Initial_Mask, an empty Foreground_Region or one outside Source, fewer
   --  than five pixels of either class in the constrained mask, a native
   --  size limit, or an OpenCV failure.
   function Initialize_GrabCut
     (Source            : OpenCV.Core.Mat;
      Initial_Mask      : OpenCV.Core.Mat;
      Foreground_Region : OpenCV.Rect;
      Iterations        : GrabCut_Iterations := 1) return GrabCut_State;

   --  Import learned GrabCut state without running segmentation. Mask must
   --  be UInt8 C1, 2-D, nonempty, with labels 0 .. 3. Each model must be
   --  Float64 C1, 1 x 65, with a valid native GrabCut GMM payload. All inputs
   --  are deep-cloned; sparse classes are allowed in restored masks.
   --  A valid payload is finite, has nonnegative weights and at least one
   --  active (positive-weight) component, and every active covariance has
   --  a determinant and inverse usable by the native mixture model;
   --  inactive components may hold stale finite values. Later refinement
   --  requires a Source with Mask's rows and columns.
   --  @param Mask Label mask, for example from GrabCut_Mask.
   --  @param Background_Model Background mixture model, for example from
   --  GrabCut_Background_Model.
   --  @param Foreground_Model Foreground mixture model, for example from
   --  GrabCut_Foreground_Model.
   --  @return New initialized state owning deep copies of the three Mats.
   --  @exception OpenCV_Error Raised when Mask is not a nonempty 2-D
   --  UInt8 C1 Mat of labels 0 .. 3, or when a model has the wrong shape or
   --  type or an invalid payload.
   function Restore_GrabCut_State
     (Mask             : OpenCV.Core.Mat;
      Background_Model : OpenCV.Core.Mat;
      Foreground_Model : OpenCV.Core.Mat) return GrabCut_State;

   --  Explicit independent copy of an initialized state: the mask and both
   --  models are deep-copied, so refining either state never affects the
   --  other.
   --  @param State Initialized state to copy.
   --  @return New initialized state equal to State.
   --  @exception OpenCV_Error Raised when State is not initialized.
   function Clone_GrabCut_State (State : GrabCut_State) return GrabCut_State;

   --  Returns State's background mixture model as a Float64 C1 1 x 65 Mat
   --  (see GrabCut_Model_Column_Count). Independent deep clones; modifying
   --  these Mats cannot change State.
   --  @param State Initialized state to read.
   --  @return Fresh owning copy of the background model.
   --  @exception OpenCV_Error Raised when State is not initialized.
   function GrabCut_Background_Model
     (State : GrabCut_State) return OpenCV.Core.Mat;

   --  Returns State's foreground mixture model as a Float64 C1 1 x 65 Mat
   --  (see GrabCut_Model_Column_Count). The result is an independent deep
   --  clone; modifying it cannot change State.
   --  @param State Initialized state to read.
   --  @return Fresh owning copy of the foreground model.
   --  @exception OpenCV_Error Raised when State is not initialized.
   function GrabCut_Foreground_Model
     (State : GrabCut_State) return OpenCV.Core.Mat;

   --  Runs Iterations further rounds that relearn the colour models and
   --  re-segment the probable pixels. Source must be a UInt8 C3 image with
   --  the state's geometry. Definite labels never change. Source is not
   --  modified. The work is done on private copies committed only after
   --  success, so a failed refinement leaves State unchanged. Imported
   --  models are validated again before native evaluation.
   --  @param Source Nonempty 2-D UInt8 C3 image with the rows and columns of
   --  State's mask.
   --  @param State Initialized state, updated in place.
   --  @param Iterations Refinement rounds to run; defaults to 1.
   --  @exception OpenCV_Error Raised when State is not initialized,
   --  when Source is invalid or of another geometry, for an invalid model,
   --  a native size limit, or an OpenCV failure.
   procedure Refine_GrabCut
     (Source     : OpenCV.Core.Mat;
      State      : in out GrabCut_State;
      Iterations : GrabCut_Iterations := 1);

   --  Re-segments the probable pixels once with the current colour models
   --  held fixed. Otherwise as Refine_GrabCut: the models are not changed,
   --  Source must match the state's geometry, definite labels never change,
   --  and a failure leaves State unchanged.
   --  @param Source Nonempty 2-D UInt8 C3 image with the rows and columns of
   --  State's mask.
   --  @param State Initialized state whose mask is updated in place.
   --  @exception OpenCV_Error Raised when State is not initialized,
   --  when Source is invalid or of another geometry, for an invalid model,
   --  a native size limit, or an OpenCV failure.
   procedure Refine_GrabCut_Frozen_Model
     (Source : OpenCV.Core.Mat; State : in out GrabCut_State);

   --  Returns an independent deep copy of the UInt8 C1 label mask. Changing
   --  the returned Mat never affects State.
   --  @param State Initialized state to read.
   --  @return Fresh owning UInt8 C1 mask of labels 0 .. 3 with the state's
   --  rows and columns.
   --  @exception OpenCV_Error Raised when State is not initialized.
   function GrabCut_Mask (State : GrabCut_State) return OpenCV.Core.Mat;

   --  Returns the label at a zero-based Row and Column of the state's mask.
   --  @param State Initialized state to read.
   --  @param Row Zero-based mask row, less than the mask's row count.
   --  @param Column Zero-based mask column, less than the mask's column
   --  count.
   --  @return The label stored at Row and Column.
   --  @exception OpenCV_Error Raised when State is not initialized or
   --  Row or Column lies outside the mask.
   function GrabCut_Label_At
     (State : GrabCut_State; Row : Natural; Column : Natural)
      return GrabCut_Label;

   --  Built-in ground distance between the coordinate vectors of two
   --  signature rows, used by the Earth Mover's Distance functions.
   --  OpenCV subtracts coordinates in Float32, accumulates in Float64 and
   --  returns a Float32 cost.
   --  @enum Manhattan_EMD L1 distance (OpenCV DIST_L1): the sum of absolute
   --  coordinate differences.
   --  @enum Euclidean_EMD L2 distance (OpenCV DIST_L2): the square root of
   --  the sum of squared differences, narrowed to Float32 before the root.
   --  This is the default metric.
   --  @enum Chessboard_EMD Chebyshev distance (OpenCV DIST_C): the largest
   --  absolute coordinate difference.
   type Earth_Mover_Metric is (Manhattan_EMD, Euclidean_EMD, Chessboard_EMD);

   --  Exact transport result of Earth_Mover_Distance_With_Flow and
   --  Earth_Mover_Distance_With_Cost_And_Flow.
   --  @field Distance Native Float32 Earth Mover's Distance, normalized by
   --  the larger total signature mass.
   --  @field Flow Fresh owning Float32 C1 Mat with Signature_1.Rows rows and
   --  Signature_2.Rows columns. The element at row I, column J is the real
   --  mass moved from row I of Signature_1 to row J of Signature_2; mass
   --  exchanged with the internal dummy cluster is not represented, and
   --  zero-weight rows carry no flow.
   type Earth_Mover_Result is record
      Distance : OpenCV.Float32_Value;
      Flow     : OpenCV.Core.Mat;
   end record;

   --  Exact Earth Mover's Distance between two weighted signatures under a
   --  built-in Metric, computed by native cv::EMD with a full transport
   --  solve.
   --
   --  Nonempty 2-D Float32 C1 signatures: each row is (weight, coordinates).
   --  Built-in metrics require at least one coordinate; both signatures
   --  always have equal column counts.
   --  All weights are finite and nonnegative, each signature has positive
   --  total mass, and its sum must remain finite in Float32. Built-in
   --  coordinates are finite; relevant transport costs (between rows of
   --  positive weight, including every Float32 coordinate difference and
   --  the Float32 L2 squared sum) are finite, nonnegative and strictly less
   --  than the native 1.0e20 Float32 sentinel.
   --  Unequal total masses are balanced by an internal zero-cost dummy
   --  cluster; distance is normalized by the larger mass. Inputs, including
   --  Regions, are deep-snapshotted into packed storage before the native
   --  solve and are never modified. No lower-bound shortcut is used.
   --  Signature sizes whose OpenCV 4.1 work buffer or signed row indexing
   --  would overflow int (for example two 16_000-row signatures) are
   --  rejected. A nonfinite native distance is not returned.
   --  @param Signature_1 First signature; its rows index the rows of a
   --  transport flow.
   --  @param Signature_2 Second signature, with Signature_1's column count.
   --  @param Metric Ground distance between coordinate vectors; defaults to
   --  Euclidean_EMD.
   --  @return The native Float32 distance.
   --  @exception OpenCV_Error Raised for an invalid signature shape
   --  or type, unequal column counts, an invalid weight, mass, coordinate
   --  or cost, a native size limit, a nonfinite result, or a native
   --  failure.
   function Earth_Mover_Distance
     (Signature_1, Signature_2 : OpenCV.Core.Mat;
      Metric                   : Earth_Mover_Metric := Euclidean_EMD)
      return OpenCV.Float32_Value;

   --  As Earth_Mover_Distance (same signature, metric, safety and snapshot
   --  contract, always an exact native solve), also returning the optimal
   --  flow. Flow is a fresh Float32 C1 Rows_1 x Rows_2 Mat of real
   --  transported mass; dummy mass is not represented. Distance and Flow
   --  are published only after success.
   --  @param Signature_1 First signature; its rows index the Flow rows.
   --  @param Signature_2 Second signature, with Signature_1's column count;
   --  its rows index the Flow columns.
   --  @param Metric Ground distance between coordinate vectors; defaults to
   --  Euclidean_EMD.
   --  @return Distance and fresh owning Flow (see Earth_Mover_Result).
   --  @exception OpenCV_Error Raised for the conditions listed for
   --  Earth_Mover_Distance.
   function Earth_Mover_Distance_With_Flow
     (Signature_1, Signature_2 : OpenCV.Core.Mat;
      Metric                   : Earth_Mover_Metric := Euclidean_EMD)
      return Earth_Mover_Result;

   --  Exact Earth Mover's Distance with an explicit ground-cost matrix
   --  instead of a built-in metric (native DIST_USER), always solved in
   --  full. Explicit Cost permits weights-only signatures (one column); Cost
   --  is Float32 C1, with Rows = Signature_1.Rows and Columns =
   --  Signature_2.Rows. The element at row I, column J is the cost of
   --  moving mass from row I of Signature_1 to row J of Signature_2. All
   --  supplied cost entries are checked, including entries for zero-weight
   --  rows: each must be finite, nonnegative and strictly less than the
   --  native 1.0e20 Float32 sentinel. Coordinate columns, when present, are
   --  ignored, but both signatures still need equal column counts. Weight,
   --  mass, normalization, native size and snapshot rules (Cost included)
   --  are those of Earth_Mover_Distance.
   --  @param Signature_1 First signature; its rows index the Cost rows.
   --  @param Signature_2 Second signature, with Signature_1's column count;
   --  its rows index the Cost columns.
   --  @param Cost Nonempty 2-D Float32 C1 transport-cost matrix of
   --  Signature_1.Rows x Signature_2.Rows; it is not modified.
   --  @return The native Float32 distance.
   --  @exception OpenCV_Error Raised for an invalid signature or
   --  Cost shape or type, unequal column counts, an invalid weight, mass
   --  or cost entry, a native size limit, a nonfinite result, or a native
   --  failure.
   function Earth_Mover_Distance_With_Cost
     (Signature_1, Signature_2, Cost : OpenCV.Core.Mat)
      return OpenCV.Float32_Value;

   --  As Earth_Mover_Distance_With_Cost (same signature, Cost, safety and
   --  snapshot contract, always an exact native solve), also returning the
   --  optimal flow. Flow is a fresh Float32 C1 Rows_1 x Rows_2 Mat of real
   --  transported mass; dummy mass is not represented. Distance and Flow
   --  are published only after success.
   --  @param Signature_1 First signature; its rows index the Cost and Flow
   --  rows.
   --  @param Signature_2 Second signature, with Signature_1's column count;
   --  its rows index the Cost and Flow columns.
   --  @param Cost Nonempty 2-D Float32 C1 transport-cost matrix of
   --  Signature_1.Rows x Signature_2.Rows; it is not modified.
   --  @return Distance and fresh owning Flow (see Earth_Mover_Result).
   --  @exception OpenCV_Error Raised for the conditions listed for
   --  Earth_Mover_Distance_With_Cost.
   function Earth_Mover_Distance_With_Cost_And_Flow
     (Signature_1, Signature_2, Cost : OpenCV.Core.Mat)
      return Earth_Mover_Result;

   --  Result of Earth_Mover_Distance_With_Lower_Bound. Never infer
   --  exactness from Distance = Lower_Bound: an exact distance can equal
   --  its bound.
   --  @field Distance The exact native distance when Exact_Distance_Computed
   --  is True; otherwise the early-exit value, equal to Lower_Bound.
   --  @field Lower_Bound OpenCV's weighted-center bound when
   --  Lower_Bound_Available is True: the Metric distance between the
   --  weight-scaled coordinate sums of the two signatures divided by the
   --  larger native mass. It is 0.0 when no bound is available.
   --  @field Lower_Bound_Available True when the native Float32 masses
   --  satisfy `abs (Sum_1 - Sum_2) < 1.0e-5 * Sum_1`, so OpenCV computed
   --  the bound.
   --  @field Exact_Distance_Computed True when the native transport solve
   --  ran; False only when an available bound reached the threshold.
   type Earth_Mover_Bounded_Result is record
      Distance                : OpenCV.Float32_Value;
      Lower_Bound             : OpenCV.Float32_Value;
      Lower_Bound_Available   : Boolean;
      Exact_Distance_Computed : Boolean;
   end record;

   --  Same signature and native-safety contract as exact built-in EMD above.
   --  Threshold must be finite and nonnegative. When native Float32 masses
   --  satisfy `abs (Sum_1 - Sum_2) < 1.0e-5 * Sum_1`, OpenCV calculates its
   --  weighted-center bound. If Bound >= Threshold, it skips transport:
   --  Distance = Lower_Bound and Exact_Distance_Computed = False.
   --  Equality exits too; zero requests bound-only whenever available.
   --  Default largest finite Float32 requests exact distance plus the bound.
   --  Unequal masses: Available = False, Bound = 0, exact solve still runs.
   --  Full safety preflight and packed Region snapshots precede the shortcut.
   --  Nonfinite native results raise OpenCV_Error. No Cost overload (native
   --  bound requires a metric) or Flow (early-exit zeros are not transport).
   --  When the bound is available, checks guarding OpenCV 4.1's bound
   --  arithmetic also reject a signature whose `Rows * Columns` exceeds
   --  2_147_483_647, or signatures whose bound scratch would not fit the
   --  native work buffer (for example very wide one-row signatures). A
   --  negative or nonfinite available bound is an error. Inputs are never
   --  modified.
   --  @param Signature_1 First signature, as for Earth_Mover_Distance; its
   --  mass is the reference of the availability tolerance.
   --  @param Signature_2 Second signature, with Signature_1's column count.
   --  @param Metric Ground distance used for transport and for the bound;
   --  defaults to Euclidean_EMD.
   --  @param Early_Exit_Threshold Finite, nonnegative threshold compared
   --  with an available bound; the default OpenCV.Float32_Value'Last
   --  computes the exact distance and still reports the bound.
   --  @return Distance, bound and the two availability and exactness flags.
   --  @exception OpenCV_Error Raised for a negative or nonfinite
   --  Early_Exit_Threshold, any condition listed for Earth_Mover_Distance,
   --  a bound-path native layout limit, or a negative or nonfinite native
   --  bound.
   function Earth_Mover_Distance_With_Lower_Bound
     (Signature_1, Signature_2 : OpenCV.Core.Mat;
      Metric                   : Earth_Mover_Metric := Euclidean_EMD;
      Early_Exit_Threshold     : OpenCV.Float32_Value :=
        OpenCV.Float32_Value'Last) return Earth_Mover_Bounded_Result;

   --  Maximum histogram dimensionality guaranteed on every supported OpenCV
   --  generation. OpenCV 4.x allows dense Mats of up to CV_MAX_DIM (32)
   --  dimensions, but OpenCV 5.0 limits Mat to MatShape::MAX_DIMS (10), and
   --  a dense histogram is stored in one N-dimensional Mat.
   Maximum_Histogram_Dimensions : constant Positive := 10;

   --  Number of bins on one histogram axis. In addition, the product of the
   --  bin counts of all axes of one histogram must not exceed
   --  2_147_483_647; a larger product raises OpenCV_Error when the
   --  histogram is calculated.
   subtype Histogram_Bin_Count is Positive range 1 .. 2_147_483_647;

   --  One uniform histogram axis of a single source. Channel is zero-based
   --  relative to that Source Mat. Bin_Count equal-width bins cover the
   --  half-open range [Lower_Bound, Upper_Bound); samples below Lower_Bound
   --  or at or above Upper_Bound are not counted. Both bounds must be finite
   --  with Lower_Bound < Upper_Bound. Internally this is source position 0.
   --  @field Channel Zero-based channel of Source sampled on this axis; it
   --  must be below Source.Channels. Several axes may select one channel.
   --  @field Bin_Count Number of equal-width bins on this axis.
   --  @field Lower_Bound Finite inclusive lower edge of the first bin.
   --  @field Upper_Bound Finite exclusive upper edge of the last bin,
   --  greater than Lower_Bound.
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
   --  @field Source_Position Zero-based position of the sampled source in
   --  Sources iteration order; it must be below Sources'Length.
   --  @field Channel Zero-based channel within the selected source; it must
   --  be below that source's channel count.
   --  @field Bin_Count Number of equal-width bins on this axis.
   --  @field Lower_Bound Finite inclusive lower edge of the first bin.
   --  @field Upper_Bound Finite exclusive upper edge of the last bin,
   --  greater than Lower_Bound.
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
   --  inside the numeric range of a particular source depth. Descriptors
   --  are built, and their edges validated, by
   --  Nonuniform_Histogram_Dimension and
   --  Nonuniform_Histogram_Source_Dimension.
   type Histogram_Nonuniform_Dimension is private;

   --  Returns a single-source nonuniform axis (source position 0) that
   --  counts Channel of the Source into the bins defined by Boundaries: N
   --  edges define N - 1 bins [Edges (I), Edges (I + 1)). The descriptor
   --  owns a copy of the edges. Channel is checked against the Source when
   --  the histogram is calculated.
   --  @param Channel Zero-based channel of the Source sampled on this axis.
   --  @param Boundaries At least two finite, strictly increasing edges in
   --  iteration order; the array's index bounds are irrelevant.
   --  @return Axis descriptor with Boundaries'Length - 1 bins.
   --  @exception OpenCV_Error Raised for fewer than two edges, a
   --  nonfinite edge, or edges that are not strictly increasing.
   function Nonuniform_Histogram_Dimension
     (Channel : Natural; Boundaries : Histogram_Bin_Boundary_Array)
      return Histogram_Nonuniform_Dimension;

   --  Returns a nonuniform axis of a multi-source histogram that counts
   --  Channel of the source at Source_Position into the bins defined by
   --  Boundaries, as for Nonuniform_Histogram_Dimension. Source_Position
   --  and Channel are checked against the sources when the histogram is
   --  calculated; single-source operations require position 0.
   --  @param Source_Position Zero-based position in Mat_Array iteration
   --  order; position 0 is Sources'First, whatever the array's bounds.
   --  @param Channel Zero-based channel within the selected source.
   --  @param Boundaries At least two finite, strictly increasing edges in
   --  iteration order; the array's index bounds are irrelevant.
   --  @return Axis descriptor with Boundaries'Length - 1 bins.
   --  @exception OpenCV_Error Raised for fewer than two edges, a
   --  nonfinite edge, or edges that are not strictly increasing.
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
   --  @enum Uniform_Binning Each axis divides its range into Bin_Count
   --  equal bins; produced by Calculate_Histogram and reported by a
   --  default-initialized Histogram.
   --  @enum Nonuniform_Binning Each axis uses its stored explicit edge
   --  sequence; produced by Calculate_Nonuniform_Histogram.
   type Histogram_Binning_Mode is (Uniform_Binning, Nonuniform_Binning);

   --  A dense histogram of Float32 bin counts together with the source,
   --  channel, and bin-boundary metadata it was calculated with. A Histogram
   --  is immutable: copies share no mutable state and no operation exposes
   --  its storage. A default-initialized Histogram is empty (zero dimensions,
   --  Uniform_Binning) and is rejected by Compare_Histograms, Back_Project,
   --  and Accumulate_Histogram.
   type Histogram is private;

   --  Returns the number of axes of Value: 1 .. Maximum_Histogram_Dimensions
   --  for a calculated histogram and 0 for a default-initialized one.
   --  @param Value Histogram to inspect.
   --  @return The stored dimension count.
   function Histogram_Dimension_Count (Value : Histogram) return Natural;

   --  Returns the binning mode shared by every axis of Value. A
   --  default-initialized Histogram reports Uniform_Binning.
   --  @param Value Histogram to inspect.
   --  @return Uniform_Binning or Nonuniform_Binning.
   function Histogram_Binning
     (Value : Histogram) return Histogram_Binning_Mode;

   --  Index is 1 .. Histogram_Dimension_Count; others raise OpenCV_Error.
   --  The returned dimension does not include Source_Position. For a
   --  nonuniform axis this is the envelope: Bin_Count is the number of
   --  intervals, Lower_Bound is the first stored edge, and Upper_Bound is
   --  the last. It is not a claim that the intervals are equal.
   --  @param Value Histogram to inspect.
   --  @param Index One-based axis number in dimension order.
   --  @return Channel, bin count and range or edge envelope of that axis.
   --  @exception OpenCV_Error Raised when Index exceeds
   --  Histogram_Dimension_Count (Value).
   function Get_Histogram_Dimension
     (Value : Histogram; Index : Positive) return Histogram_Dimension;

   --  Zero-based source position stored for Index. Single-source histograms
   --  always report 0. Index outside 1 .. Dimension_Count raises OpenCV_Error.
   --  @param Value Histogram to inspect.
   --  @param Index One-based axis number in dimension order.
   --  @return Zero-based position, in the Sources iteration order used for
   --  calculation, of the source sampled on that axis.
   --  @exception OpenCV_Error Raised when Index exceeds
   --  Histogram_Dimension_Count (Value).
   function Get_Histogram_Source_Position
     (Value : Histogram; Index : Positive) return Natural;

   --  Exact stored edges for Index, in iteration order. A uniform axis
   --  returns its two range endpoints. A nonuniform axis returns all
   --  Bin_Count + 1 edges. The result is independent of the Histogram.
   --  Index outside 1 .. Dimension_Count raises OpenCV_Error.
   --  @param Value Histogram to inspect.
   --  @param Index One-based axis number in dimension order.
   --  @return New array, indexed from 1, of that axis's stored Float32
   --  edges.
   --  @exception OpenCV_Error Raised when Index exceeds
   --  Histogram_Dimension_Count (Value).
   function Get_Histogram_Bin_Boundaries
     (Value : Histogram; Index : Positive) return Histogram_Bin_Boundary_Array;

   --  Returns an independent deep copy of the Float32 C1 bin counts. A
   --  one-dimensional histogram is a Bin_Count x 1 Mat, a two-dimensional
   --  one is Bin_Count (1) x Bin_Count (2), and higher dimensionality is an
   --  N-dimensional Mat with one extent per dimension, in dimension order.
   --  The metadata, not the Mat shape, defines the logical dimensionality.
   --  The one-dimensional Bin_Count x 1 shape is the same on every
   --  supported OpenCV release.
   --  @param Value Histogram whose bin counts are copied.
   --  @return Fresh owning Float32 C1 Mat of bin counts; changing it never
   --  affects Value.
   function Histogram_Values (Value : Histogram) return OpenCV.Core.Mat;

   --  Counts Source samples into a new dense histogram (no accumulation, no
   --  normalization). Source must be a nonempty two-dimensional UInt8,
   --  UInt16 or Float32 Mat, every Channel must be below Source.Channels,
   --  and Dimensions'Length must be 1 .. Maximum_Histogram_Dimensions. A
   --  Region is treated as the whole image. Source is not modified. Every
   --  stored source position is 0.
   --
   --  Each pixel adds one to the bin addressed by its selected samples,
   --  only when every selected sample falls in a bin of its axis. The
   --  result has Uniform_Binning, the given channels and ranges, and fresh
   --  Float32 counts published only after success. Each dimension needs
   --  finite bounds with Lower_Bound < Upper_Bound, and the product of all
   --  bin counts must not exceed 2_147_483_647. Native int limits also
   --  apply: Rows times Columns and the row stride in elements must fit
   --  int; for UInt8 and UInt16 the bin coordinates of 0 and of the
   --  largest sample (255 or 65535) must lie inside int; every evaluated
   --  Float32 sample must be finite and its bin coordinate
   --  `(Sample - Lower_Bound) * Bin_Count / (Upper_Bound - Lower_Bound)`
   --  must lie inside int. Finite samples outside the bins remain legal.
   --  @param Source Nonempty 2-D UInt8, UInt16 or Float32 image to sample.
   --  @param Dimensions Axes in dimension order (any index bounds), each
   --  selecting a Source channel and its uniform bins.
   --  @return Fresh immutable Histogram of Float32 counts.
   --  @exception OpenCV_Error Raised for an invalid Source, a missing
   --  channel, a dimension count outside 1 .. 10, invalid bounds, an
   --  excessive bin product, a native int limit, a nonfinite or
   --  out-of-range Float32 sample, or a native failure.
   function Calculate_Histogram
     (Source : OpenCV.Core.Mat; Dimensions : Histogram_Dimension_Array)
      return Histogram;

   --  Masked single-source Calculate_Histogram: as the unmasked overload,
   --  counting only pixels whose Mask value is nonzero. Mask must
   --  be a nonempty two-dimensional UInt8 C1 Mat with Source's rows and
   --  columns; it may share storage with Source. Mask is not modified.
   --  Masked-out Float32 samples are not inspected. The Mask row stride
   --  must fit native int.
   --  @param Source Nonempty 2-D UInt8, UInt16 or Float32 image to sample.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with Source's rows and
   --  columns; nonzero samples select pixels.
   --  @param Dimensions Axes in dimension order (any index bounds), each
   --  selecting a Source channel and its uniform bins.
   --  @return Fresh immutable Histogram of the selected pixels' counts.
   --  @exception OpenCV_Error Raised for any condition of the
   --  unmasked overload or for a Mask that is empty, not 2-D, not UInt8 C1,
   --  of different geometry, or with an excessive row stride.
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
   --
   --  A location is counted only when every selected sample falls in a bin
   --  of its axis. The result has Uniform_Binning and stores each axis's
   --  source position, channel and range; its fresh Float32 counts are
   --  published only after success. Bounds, bin product, native int and
   --  Float32 sample rules are those of the single-source overload, applied
   --  to every selected sample.
   --  @param Sources Images sampled at the same row and column; position 0
   --  is Sources'First.
   --  @param Dimensions Axes in dimension order (any index bounds), each
   --  selecting a source position, a channel and its uniform bins.
   --  @return Fresh immutable joint Histogram of Float32 counts.
   --  @exception OpenCV_Error Raised for an empty Sources array, an
   --  invalid or mismatched source, an invalid source position or channel,
   --  a dimension count outside 1 .. 10, invalid bounds, an excessive bin
   --  product, a native int limit, a nonfinite or out-of-range Float32
   --  sample, or a native failure.
   function Calculate_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Dimensions : Histogram_Source_Dimension_Array) return Histogram;

   --  Masked multi-source Calculate_Histogram: as the unmasked overload,
   --  counting only locations whose Mask value is nonzero. Mask
   --  must be a nonempty 2-D UInt8 C1 Mat with the common source geometry.
   --  It is applied at the same (row, column) of every source and may share
   --  storage with a source. Mask is not modified. Masked-out Float32
   --  samples are not inspected.
   --  @param Sources Images sampled at the same row and column; position 0
   --  is Sources'First.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with the common source
   --  rows and columns; nonzero samples select locations.
   --  @param Dimensions Axes in dimension order (any index bounds), each
   --  selecting a source position, a channel and its uniform bins.
   --  @return Fresh immutable joint Histogram of the selected locations.
   --  @exception OpenCV_Error Raised for any condition of the
   --  unmasked overload or for a Mask that is empty, not 2-D, not UInt8 C1,
   --  of different geometry, or with an excessive row stride.
   function Calculate_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Source_Dimension_Array) return Histogram;

   --  Dense nonuniform histogram of one source. Each axis supplies its own
   --  strictly increasing edges; bin I is [edge I, edge I + 1). Every stored
   --  source position must be 0. Otherwise as the uniform single-source
   --  overload: nonempty 2-D UInt8, UInt16 or Float32 Source, 1 .. 10 axes,
   --  channels below Source.Channels, a bin product of at most
   --  2_147_483_647, the same Source size and stride limits, and fresh
   --  Float32 counts published only after success. Source is not modified;
   --  a Region is its own image.
   --
   --  The result has Nonuniform_Binning and keeps each axis's exact edges.
   --  Float32 samples are compared directly with the edges and must be
   --  finite. For UInt8 sources every edge must lie strictly between
   --  -2_147_483_647.0 and 2_147_483_647.0. A request that can reach
   --  OpenCV's IPP path (one axis on channel 0 and no mask) also needs its
   --  first edge in that interval and, for a one-channel Source, a byte
   --  row stride that fits int.
   --  @param Source Nonempty 2-D UInt8, UInt16 or Float32 image to sample.
   --  @param Dimensions Nonuniform axes in dimension order (any index
   --  bounds); every source position must be 0.
   --  @return Fresh immutable Histogram of Float32 counts.
   --  @exception OpenCV_Error Raised for an invalid Source, a nonzero
   --  source position, a missing channel, a dimension count outside
   --  1 .. 10, an excessive bin product, an edge or native int limit, a
   --  nonfinite Float32 sample, or a native failure.
   function Calculate_Nonuniform_Histogram
     (Source     : OpenCV.Core.Mat;
      Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;

   --  Masked single-source Calculate_Nonuniform_Histogram: as the unmasked
   --  overload, counting only pixels whose matching UInt8 C1 Mask value is
   --  nonzero. Mask is a nonempty 2-D UInt8 C1 Mat with Source's rows and
   --  columns and a row stride that fits int. Source and Mask are not
   --  modified; masked-out Float32 samples are not inspected.
   --  @param Source Nonempty 2-D UInt8, UInt16 or Float32 image to sample.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with Source's rows and
   --  columns; nonzero samples select pixels.
   --  @param Dimensions Nonuniform axes in dimension order (any index
   --  bounds); every source position must be 0.
   --  @return Fresh immutable Histogram of the selected pixels' counts.
   --  @exception OpenCV_Error Raised for any condition of the
   --  unmasked overload or for a Mask that is empty, not 2-D, not UInt8 C1,
   --  of different geometry, or with an excessive row stride.
   function Calculate_Nonuniform_Histogram
     (Source     : OpenCV.Core.Mat;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;

   --  Dense nonuniform joint histogram. Source_Position is the zero-based
   --  position in Mat_Array iteration order, as for uniform multi-source
   --  histograms. Every axis is nonuniform. Sources follow the uniform
   --  multi-source contract (nonempty array; nonempty 2-D UInt8, UInt16 or
   --  Float32 elements sharing the first element's rows, columns and depth;
   --  channel counts may differ). Edge, bin product, native int and Float32
   --  sample rules are those of the single-source nonuniform overload. The
   --  result has Nonuniform_Binning, stores each axis's source position,
   --  channel and exact edges, and is published only after success. No
   --  source is modified; a Region is its logical view.
   --  @param Sources Images sampled at the same row and column; position 0
   --  is Sources'First.
   --  @param Dimensions Nonuniform axes in dimension order (any index
   --  bounds), each selecting a source position and a channel.
   --  @return Fresh immutable joint Histogram of Float32 counts.
   --  @exception OpenCV_Error Raised for an empty Sources array, an
   --  invalid or mismatched source, an invalid source position or channel,
   --  a dimension count outside 1 .. 10, an excessive bin product, an edge
   --  or native int limit, a nonfinite Float32 sample, or a native failure.
   function Calculate_Nonuniform_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;

   --  Masked multi-source Calculate_Nonuniform_Histogram: as the unmasked
   --  overload, counting only locations whose Mask value is nonzero. Mask
   --  is a nonempty 2-D UInt8 C1 Mat with the common source geometry,
   --  applied at the same (row, column) of every source. Sources and Mask
   --  are not modified; masked-out Float32 samples are not inspected.
   --  @param Sources Images sampled at the same row and column; position 0
   --  is Sources'First.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with the common source
   --  rows and columns; nonzero samples select locations.
   --  @param Dimensions Nonuniform axes in dimension order (any index
   --  bounds), each selecting a source position and a channel.
   --  @return Fresh immutable joint Histogram of the selected locations.
   --  @exception OpenCV_Error Raised for any condition of the
   --  unmasked overload or for a Mask that is empty, not 2-D, not UInt8 C1,
   --  of different geometry, or with an excessive row stride.
   function Calculate_Nonuniform_Histogram
     (Sources    : OpenCV.Core.Mat_Array;
      Mask       : OpenCV.Core.Mat;
      Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;

   --  OpenCV comparison metrics. None is a normalized similarity score.
   --  In the formulas, Left and Right are corresponding bin values and each
   --  sum runs over all bins; zero bins follow native OpenCV handling.
   --  @enum Correlation Correlation coefficient of the bin values: larger
   --  is more similar and identical histograms give 1.
   --  @enum Chi_Square `sum ((Left - Right) ** 2 / Left)`: smaller is
   --  closer and identical gives 0; asymmetric (Left is the denominator).
   --  @enum Intersection `sum (min (Left, Right))`, the sum of bin minima:
   --  larger is more similar and the scale depends on the histogram
   --  totals (identical histograms give their total count).
   --  @enum Hellinger_Distance OpenCV HISTCMP_BHATTACHARYYA, which computes
   --  the Hellinger distance; smaller is closer and identical gives 0.
   --  @enum Alternative_Chi_Square Symmetric chi-square
   --  `2 * sum ((Left - Right) ** 2 / (Left + Right))`; smaller is closer
   --  and identical gives 0.
   --  @enum Kullback_Leibler_Divergence `sum (Left * log (Left / Right))`:
   --  smaller is closer and identical gives 0; asymmetric.
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
   --  and counts, not of sample provenance. Both histograms must be
   --  calculated: a default-initialized Histogram is rejected. Neither
   --  histogram is modified.
   --  @param Left First histogram; the reference of the asymmetric methods
   --  (the Chi_Square denominator and the Kullback_Leibler_Divergence
   --  weights).
   --  @param Right Second histogram, with Left's binning mode and bin
   --  geometry.
   --  @param Method Comparison metric; see Histogram_Comparison_Method.
   --  @return The native Float64 metric value.
   --  @exception OpenCV_Error Raised for a default-initialized
   --  histogram, different binning modes, dimension counts, bin counts or
   --  edges, or a native failure.
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
   --
   --  The result is fresh owning storage published only after success.
   --  Scale must also have a magnitude of at most OpenCV.Float32_Value'Last.
   --  For UInt8 and UInt16 results the product is formed in Float32 and
   --  rounded; Float32 results are not saturated. The Source size, stride
   --  and Float32 sample rules of calculation apply, as does the UInt8
   --  nonuniform edge limit.
   --  @param Source Nonempty 2-D UInt8, UInt16 or Float32 image whose
   --  pixels are looked up.
   --  @param Distribution Calculated histogram whose stored channels and
   --  edges select the bins.
   --  @param Scale Finite factor applied to each bin value; defaults to
   --  1.0.
   --  @return Fresh one-channel Mat of Source's size and depth.
   --  @exception OpenCV_Error Raised for a default-initialized
   --  Distribution, a nonzero stored source position, an invalid Scale, an
   --  invalid Source or missing channel, a native int or edge limit, a
   --  nonfinite Float32 sample, or a native failure.
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
   --
   --  Each location receives the bin value addressed by its selected
   --  samples multiplied by Scale, or 0 when a sample lies outside a bin.
   --  Uniform and nonuniform Distributions use their stored edges. Scale
   --  must be finite with a magnitude of at most OpenCV.Float32_Value'Last;
   --  UInt8 and UInt16 results are rounded and saturated. Sources are
   --  nonempty 2-D UInt8, UInt16 or Float32 Mats whose selected channels
   --  exist; Regions are their logical views. The result is fresh owning
   --  storage published only after success; the size, stride and Float32
   --  sample rules of calculation apply, as does the UInt8 nonuniform edge
   --  limit.
   --  @param Sources Images looked up at the same row and column.
   --  @param Distribution Calculated histogram whose stored source
   --  positions, channels and edges select the bins.
   --  @param Scale Finite factor applied to each bin value; defaults to
   --  1.0.
   --  @return Fresh one-channel Mat with the first source's size and depth.
   --  @exception OpenCV_Error Raised for a default-initialized
   --  Distribution, an invalid Scale, an empty or invalid Sources array, a
   --  missing source position or channel, a native int or edge limit, a
   --  nonfinite Float32 sample, or a native failure.
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
   --  Counts above `2 ** 24` may lose integer-unit precision because storage
   --  is Float32. This does not call native calcHist with accumulate=true.
   --
   --  Source follows the calculation contract of Base's binning mode
   --  (Calculate_Histogram or Calculate_Nonuniform_Histogram); its
   --  geometry need not match the images that produced Base.
   --  @param Base Calculated histogram whose stored source positions are
   --  all 0; it supplies the axes and the counts to add to.
   --  @param Source Image sampled with Base's channels and bins.
   --  @return New Histogram holding the summed counts and Base's metadata.
   --  @exception OpenCV_Error Raised for a default-initialized Base,
   --  a nonzero stored source position, any calculation error for Source,
   --  or a bin sum that is not a finite Float32.
   function Accumulate_Histogram
     (Base : Histogram; Source : OpenCV.Core.Mat) return Histogram;

   --  Masked single-source Accumulate_Histogram: as the unmasked overload,
   --  but only pixels whose Mask value is nonzero are added. Mask follows
   --  the masked calculation contract: nonempty 2-D UInt8 C1 with Source's
   --  rows and columns. Base, Source and Mask are not modified.
   --  @param Base Calculated histogram whose stored source positions are
   --  all 0; it supplies the axes and the counts to add to.
   --  @param Source Image sampled with Base's channels and bins.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with Source's rows and
   --  columns; nonzero samples select pixels.
   --  @return New Histogram holding the summed counts and Base's metadata.
   --  @exception OpenCV_Error Raised for any condition of the
   --  unmasked overload or an invalid Mask.
   function Accumulate_Histogram
     (Base : Histogram; Source : OpenCV.Core.Mat; Mask : OpenCV.Core.Mat)
      return Histogram;

   --  Multi-source Accumulate_Histogram: returns a new histogram with
   --  Base's binning mode, source positions, channels and exact edges, and
   --  the Float32 sum of Base's bins and a fresh histogram of Sources,
   --  using Base's stored source positions, channels and complete
   --  boundary sequences. Every stored position must be below
   --  Sources'Length; position 0 is Sources'First. Sources within this
   --  call must share geometry and depth and follow the multi-source
   --  calculation contract of Base's binning mode. Separate accumulation
   --  calls need not share geometry with each other or with the images
   --  that produced Base. Base must be calculated; Base and Sources are
   --  not modified. A nonfinite, negative or non-Float32 sum rejects the
   --  whole update, and counts above `2 ** 24` may lose integer-unit
   --  precision. Native calcHist accumulation is not used.
   --  @param Base Calculated histogram supplying the axes and the counts to
   --  add to.
   --  @param Sources Images sampled with Base's source positions, channels
   --  and bins.
   --  @return New Histogram holding the summed counts and Base's metadata.
   --  @exception OpenCV_Error Raised for a default-initialized Base,
   --  any calculation error for Sources, or a bin sum that is not a finite
   --  Float32.
   function Accumulate_Histogram
     (Base : Histogram; Sources : OpenCV.Core.Mat_Array) return Histogram;

   --  Masked multi-source Accumulate_Histogram: as the unmasked
   --  multi-source overload, but only locations whose Mask value is nonzero
   --  are added. Mask is a nonempty 2-D UInt8 C1 Mat with the common source
   --  rows and columns, applied at the same location of every source.
   --  Base, Sources and Mask are not modified.
   --  @param Base Calculated histogram supplying the axes and the counts to
   --  add to.
   --  @param Sources Images sampled with Base's source positions, channels
   --  and bins.
   --  @param Mask Nonempty 2-D UInt8 C1 selection with the common source
   --  rows and columns; nonzero samples select locations.
   --  @return New Histogram holding the summed counts and Base's metadata.
   --  @exception OpenCV_Error Raised for any condition of the
   --  unmasked multi-source overload or an invalid Mask.
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

   --  Element equality for the private histogram bin-boundary vectors:
   --  the ordinary floating-point "=" of the two boundary values. Not part
   --  of the public API.
   --  @param Left First boundary value.
   --  @param Right Second boundary value.
   --  @return True when Left and Right compare equal.
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
