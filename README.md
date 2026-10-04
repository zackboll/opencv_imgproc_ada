# OpenCV Imgproc for Ada

[![Cross-Platform Bridge CI](https://github.com/zackboll/opencv_imgproc_ada/actions/workflows/cross-platform.yml/badge.svg)](https://github.com/zackboll/opencv_imgproc_ada/actions/workflows/cross-platform.yml)

A thick, idiomatic Ada binding for the **OpenCV Imgproc** module.

`opencv_imgproc_ada` exposes a focused, growing subset of OpenCV image-processing
functionality through strong Ada types, Ada exceptions, Core-owned `Mat`
objects, and Ada-owned contour and connected-component results. C++ implementation details stay behind
a small C ABI and the cross-module `Mat` bridge provided by
[`opencv_core_ada`](https://github.com/zackboll/opencv_core_ada).

This project is intentionally an **Ada API over OpenCV**, not a mechanical
translation of `opencv2/imgproc.hpp`.

> **Version:** `0.1.0-dev`
>
> **Ada package:** `OpenCV.Image_Processing`
>
> **Production dependency:** `opencv_core ~0.1.0`
>
> **Development status:** active, pre-1.0 API
>
> **Current registered test baseline:** **837 AUnit tests**

>
> **Current CI:** Linux x86_64 and macOS ARM64 on pull requests; Linux,
> macOS, and Windows x86_64/MSYS2 on `main` pushes and manual dispatch
>
> **OpenCV generations exercised by CI:** OpenCV 4.x and OpenCV 5.x

## Project names

Several names appear because the GitHub repository, Alire crate, GPR project,
Ada package, and built libraries serve different roles.

| Purpose | Name |
| --- | --- |
| GitHub repository | `opencv_imgproc_ada` |
| Alire crate | `opencv_imgproc` |
| GPR project | `Opencv_Imgproc` |
| Public Ada package | `OpenCV.Image_Processing` |
| Built Ada library | `opencv_imgproc_ada` |
| Private C++ shim | `opencv_imgproc_shim` |
| Required Ada dependency | `opencv_core` |

## Contents

- [Scope](#scope)
- [Design goals](#design-goals)
- [Current feature set](#current-feature-set)
- [Integral images](#integral-images)
- [Image accumulation and running statistics](#image-accumulation-and-running-statistics)
- [Color conversion](#color-conversion)
- [YUV 4:2:0](#yuv-420)
- [YUV 4:2:2](#yuv-422)
- [Bayer demosaicing](#bayer-demosaicing)
- [Resizing](#resizing)
- [Gaussian blur](#gaussian-blur)
- [Gaussian kernel](#gaussian-kernel)
- [Derivative kernels](#derivative-kernels)
- [Image pyramids](#image-pyramids)
- [Template matching](#template-matching)
- [Affine warping](#affine-warping)
- [Perspective warping](#perspective-warping)
- [Remapping](#remapping)
- [Polar transforms](#polar-transforms)
- [Median blur](#median-blur)

- [Box blur](#box-blur)
- [Bilateral filter](#bilateral-filter)
- [Mean-shift filtering](#mean-shift-filtering)
- [Filter 2D](#filter-2d)
- [Sep Filter 2D](#sep-filter-2d)
- [Morphology](#morphology)
- [Canny edge detection](#canny-edge-detection)
- [Spatial derivatives](#spatial-derivatives)
- [Thresholding](#thresholding)
- [Histogram equalization](#histogram-equalization)
- [CLAHE](#clahe)
- [Contour extraction](#contour-extraction)
- [Connected components](#connected-components)
- [Drawing primitives](#drawing-primitives)
- [Hough detection](#hough-detection)
- [Segmentation](#segmentation)
- [Histogram analysis](#histogram-analysis)
- [Earth mover distance](#earth-mover-distance)
- [Corner analysis](#corner-analysis)
- [Shared value types](#shared-value-types)
- [Geometry is a separate module](#geometry-is-a-separate-module)
- [Architecture](#architecture)
- [Cross-module Mat interoperability](#cross-module-mat-interoperability)
- [Safety and error handling](#safety-and-error-handling)
- [OpenCV compatibility and platform model](#opencv-compatibility-and-platform-model)
- [Requirements](#requirements)
- [Building from source](#building-from-source)
- [Running the tests](#running-the-tests)
- [Examples](#examples)
- [Project layout](#project-layout)
- [Current limitations and roadmap](#current-limitations-and-roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Scope

### Corner analysis

`OpenCV.Image_Processing` now offers `Corner_Minimum_Eigenvalue`,
`Harris_Corner_Response`, `Corner_Eigenvalues_And_Vectors`,
`Pre_Corner_Response`, and `Refine_Corners_Subpixel`. The first four return
fresh Float32 maps at the source geometry; the eigenvalue/vector map has six
channels per pixel in OpenCV order `(lambda1, lambda2, x1, y1, x2, y2)`.
All accept only nonempty two-dimensional UInt8 or Float32 single-channel
sources. Responses require block size >= 2 (except pre-corner, which has no
block size), apertures 3/5/7, and Constant, Replicate, Reflect or Reflect_101
borders; Wrap is rejected. Harris k must be finite.

The subpixel operation returns a new Ada-owned `Corner_Point_Array` with the
same index bounds as the input; the input points are unchanged on success or
failure. The positive search-window half-size must fit the image with a
two-pixel halo (`Columns >= 2*Width+5`, `Rows >= 2*Height+5`). Optional
`Corner_Dead_Zone` half-sizes must be strictly smaller than the window. Both
termination criteria are active: 1..100 iterations and finite nonnegative
epsilon. Every initial Float32 point must be finite and satisfy
`0 <= X < Columns`, `0 <= Y < Rows`. An empty array returns an empty array
after source (including Float32 finiteness) and parameter validation. Only
subpixel refinement requires every Float32 source sample to be finite; NaN or
infinity raises `OpenCV_Error`. Response maps retain their existing semantics.
All five operations snapshot the
source before native execution; a Region is its own image and cannot see
pixels in the surrounding parent.

Pinned source review (OpenCV 4.1.0, 4.10.0, 5.0.0): in
`modules/imgproc/src/cornersubpix.cpp`, 4.1 assigns `cI = cI2` before checking
its range; 4.10 and 5.0 check `cI2` with `Rect.contains` before assigning it.
With NaN covariance results, 4.1 can return a NaN point while newer versions
retain the previous finite point. A NaN error normally stops the loop before
another iteration; this is primarily a returned-point portability difference.
In all three versions, `modules/imgproc/src/samplers.cpp` uses `cvFloor(center)`
in `getRectSubPix`; `modules/core/include/opencv2/core/fast_math.hpp` documents
undefined results for `cvFloor` outside INT_MIN..INT_MAX. The public Float32
source check prevents nonfinite samples from reaching iterative refinement.

```ada
declare
   use OpenCV.Image_Processing;
   Initial : constant Corner_Point_Array (5 .. 5) :=
     (5 => (X => 15.2, Y => 15.3));
   Response : constant OpenCV.Core.Mat :=
     Harris_Corner_Response (Image, Block_Size => 3);
   Refined : constant Corner_Point_Array :=
     Refine_Corners_Subpixel
       (Image, Initial, Search_Window => (Width => 3, Height => 3));
begin
   --  Response is Float32 C1; Refined (5) is the new point.
   null;
end;
```

`goodFeaturesToTrack` is intentionally excluded: in OpenCV 5 it belongs to
the separate native Features module, consistent with this crate's module
boundary policy. This is not missing OpenCV 5 Imgproc functionality.

| Corner slice tests | Count |
| --- | ---: |
| Prior baseline | 502 |
| Corner analysis additions | 20 |
| Subpixel regression additions | 3 |
| Current suite | 525 |

### Current feature summary

This crate owns **image-processing operations** that conceptually belong to
OpenCV Imgproc and operate primarily on `OpenCV.Core.Mat`.

The current public surface includes:

- image accumulation, squared/product accumulators, and running weighted averages;
- translational phase correlation and native Hanning window generation;
- BGR-to-grayscale conversion;
- image resize with five interpolation modes;
- Gaussian blur;
- Gaussian kernel generation;
- Sobel and Scharr derivative kernel generation;
- Gaussian pyramid downsampling and upsampling (natural and explicit size);
- multi-level Gaussian pyramids and floating-point Laplacian pyramid
  decomposition and reconstruction;
- unmasked template matching;
- affine warping;
- perspective warping;
- split-Float32 remapping;
- median blur;

- box blur;
- bilateral filter;
- custom-kernel Filter_2D correlation;
- separable Sep_Filter_2D filtering;
- erosion and dilation;
- morphology opening, closing, gradient, top-hat, and black-hat;
- Canny edge detection;
- Sobel, Scharr, and Laplacian derivatives;
- fixed thresholding;
- Otsu and Triangle automatic thresholding;
- mean and Gaussian adaptive thresholding;
- global grayscale histogram equalization;
- contrast limited adaptive histogram equalization (CLAHE);
- connected-component labeling and statistics;
- in-place drawing of lines, arrows, markers, rectangles, circles, ellipses,
  polylines, polygons, contours, and Hershey text; text metrics and height
  scaling;
- contour extraction, hierarchy, approximation modes, and hierarchy-aware
  outline/fill rendering.

Computational contour geometry such as area, arc length, and moments is
**intentionally not part of this crate**. Those operations live in the separate
[`opencv_geometry_ada`](https://github.com/zackboll/opencv_geometry_ada)
repository under `OpenCV.Geometry`.

The project does not attempt to mirror every OpenCV Imgproc symbol. Features
are added as vertically integrated Ada APIs with validation, C ABI coverage,
C++ exception containment, and focused tests.

## Design goals

The binding follows the same principles as `opencv_core_ada`:

- expose an **idiomatic Ada interface**, not C++ syntax;
- keep `cv::Mat`, C++ references, templates, STL containers, RTTI details, and
  C++ exceptions out of the public Ada API;
- use `OpenCV.Core.Mat` as the shared image type across modules;
- use Ada enums and subtypes instead of untyped integer flags;
- validate public semantic requirements in Ada before entering the shim;
- independently validate raw ABI selectors, dimensions, and pointers in the C++
  shim so malformed non-Ada callers cannot bypass basic safety checks;
- translate native failures into `OpenCV.OpenCV_Error`;
- preserve source images unless an operation explicitly documents direct
  in-place support;
- keep OpenCV-version and platform-specific build handling below the public API;
- keep tests and development tools in a separate test crate.

Features are implemented vertically:

```text
Ada application
     |
     v
OpenCV.Image_Processing
     |
     v
private Ada C interop
     |
     v
stable C ABI / C++ shim
     |
     +---- Core module bridge ----> OpenCV.Core Mat ownership
     |
     v
OpenCV Imgproc
```

---

## Phase correlation

`Phase_Correlate (Source_1, Source_2)` and the overload with `Window` return
`Phase_Correlation_Result`, a record with `X_Shift`, `Y_Shift`, and `Response`,
all `OpenCV.Float64_Value`. Inputs must be nonempty two-dimensional C1 Mats
of identical geometry and type, either Float32 or Float64. A supplied Window
must also be nonempty 2-D C1 of the same depth, rows and columns. Invalid
public inputs raise `OpenCV_Error`. No integer conversion, depth promotion,
image normalization, or image-wide finiteness scan occurs.

**Sign convention, verified with controlled translations:** the result is
Source_2's displacement relative to Source_1. Moving a feature right by three
pixels returns approximately +3 X; moving down returns positive Y. To align
Source_2 with Source_1, apply the negative shift to Source_2. This is native
OpenCV's convention, not a negated wrapper convention.

Response is the native sum within the 5x5 weighted peak centroid, divided
by the padded correlation plane size. It indicates peak concentration, not
a calibrated probability. It is not guaranteed exactly in [0, 1]; rounding
can exceed the ideal bounds. Degenerate/nonfinite data can produce numerically
unhelpful shifts or responses. Release-specific response equality is not promised.

Both sources and Window are **always independently cloned** into packed
private snapshots before native execution. Inputs remain unchanged on success
and failure. This explicitly mitigates native shallow assignment followed by
in-place window multiplication when dimensions already equal optimal DFT sizes
(the tests pin 32x32). Regions are independent logical images: no parent pixels
participate. Same-source calls, distinct shared headers, shifted-overlap Regions,
and Window sharing either source's storage are supported without native
iteration-order dependence. Concurrent external mutation is not supported.

The shim calculates the exact installed `getOptimalDFTSize` values before
entry and rejects unsupported values and signed arithmetic overflow, including
`M*N <= INT_MAX`, centroid peak+2, channel-expanded DFT scratch dimensions,
padding byte widths and representable allocations. These are safety bounds,
not arbitrary image-size caps. See the detailed
[pinned source review](docs/phase-correlation-source-review.md).

All three pinned versions (4.1.0, 4.10.0, 5.0.0) supply the portable APIs.
The exact `magSpectrums` difference is **4.1.0 versus 4.10.0/5.0.0**:
4.1 squares special real DC/Nyquist entries; both later tags use absolute
magnitude. The wrapper preserves the installed native algorithm. The
OpenCV 5-only `phaseCorrelateIterative` remains explicitly deferred;
`divSpectrums`, public DFT wrappers, rotation/scale and registration frameworks
are outside this slice.

## Hanning windows

```ada
Window : constant OpenCV.Core.Mat :=
  Create_Hanning_Window ((Width => 32, Height => 32),
                         Depth => Float64_Hanning_Window);
Shift : constant Phase_Correlation_Result :=
  Phase_Correlate (First_Image, Second_Image, Window);
```

`Hanning_Window_Depth` has `Float32_Hanning_Window` and
`Float64_Hanning_Window` (default). Both dimensions must exceed one. Each call
returns a fresh owning Mat with Height rows, Width columns, C1 and the requested
floating depth, directly usable by Phase_Correlate when depths match.
Generation calls native `createHanningWindow`: the full separable Hann product
is square-rooted. It is not a hand-written alternative Hann definition.
OpenCV 5's newer vector cosine paths can change rounding; tests use tolerances
for center, edges and symmetry rather than bit-for-bit coefficients.
Allocation/index products are preflighted, including the double coefficient
buffer and terminal sqrt's signed scalar-plane length.

This slice adds **25 tests** to the **569** baseline: **594/594** locally.

## Current feature set

The table below summarizes the current public operations.

| Area | Public API | Main input requirements | Important behavior |
| --- | --- | --- | --- |
| Motion | `Phase_Correlate` | matching nonempty 2-D Float32/Float64 C1 sources; optional matching window | Float64 shift/response record; independent logical snapshots; inputs unchanged |
| Windows | `Create_Hanning_Window` | Width/Height > 1; Float32 or Float64 selector | fresh owning C1 Mat; native sqrt of separable Hann product |
| Contour rendering | `Draw_Contours`, `Fill_Contours` | one Ada-owned `Contour_Set`; ordinary drawing image contract | all or selected root-relative subtree; even-odd holes/islands; Region-local offset |
| Color | `Convert_Color` | nonempty 2-D, exact selector channels; UInt8/UInt16/Float32 for layout/Gray/XYZ/YCrCb/YUV, UInt8/Float32 for HSV/HLS/Lab/Luv, UInt8 only for packed/alpha | layout, Gray, XYZ, YCrCb, YUV, standard/FULL HSV/HLS, sRGB/linear-light Lab/Luv, packed color and premultiplied RGBA |
| Resize | `Resize` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64` | five interpolation modes; preserves depth/channels |
| Filtering | `Gaussian_Blur` | nonempty 2-D; supported numeric depths | positive odd kernel, positive finite sigma |
| Filtering | `Get_Gaussian_Kernel` | odd positive size | automatic or explicit sigma; Float32/Float64 `N x 1` C1 kernel; usable with `Sep_Filter_2D` |
| Derivatives | `Get_Derivative_Kernels`, `Get_Scharr_Kernels` | odd Sobel size 1/3/5/7 or Scharr axis | Float32/Float64 `N x 1` C1 pair; Kernel_1 may differ in X/Y length; usable with `Sep_Filter_2D` |
| Pyramids | `Pyramid_Down`, `Pyramid_Up` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64` | natural half/double size; explicit `Pyramid_Up` size of `2N` or `2N - 1` per axis; arbitrary channels; Down accepts Wrap and rejects Constant; Up has no Border; in-place unsupported |
| Pyramids | `Build_Gaussian_Pyramid`, `Maximum_Pyramid_Level_Count` | as `Pyramid_Down`; `Level_Count` <= distinct natural levels | zero-based `Mat_Array`; level 0 is an independent clone; every level owns storage; Region-local; Constant rejected |
| Pyramids | `Build_Laplacian_Pyramid`, `Reconstruct_Laplacian_Pyramid` | as `Build_Gaussian_Pyramid`; reconstruction needs a Float32/Float64 natural-geometry `Mat_Array` | Float32/Float64 working depth; editable residuals; low-frequency last level; reconstruction stays floating |
| Matching | `Match_Template` | nonempty 2-D; `UInt8` or `Float32`; C1..C4; matching Source/Template type | Float32 C1 score map; Template must fit in Source; SQDIFF min / others max; Destination must not share input storage |
| Warping | `Warp_Affine` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`; C1..C4 | 2x3 Float32/Float64 C1 Transform; requested Output_Size; Nearest/Linear; Constant/Replicate; Destination must not share input storage |
| Warping | `Warp_Perspective` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`; C1..C4 | 3x3 Float32/Float64 C1 Transform; requested Output_Size; Nearest/Linear; Constant/Replicate; Destination must not share input storage |
| Warping | `Remap` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`; C1..C4; Rows/Columns < 32767 | separate Float32 C1 Map_X/Map_Y; output follows maps; Nearest/Linear/Cubic/Lanczos_4; Area rejected; all public borders; Destination must not share input storage |
| Warping | `Warp_Polar` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`; C1..C4 | explicit output size; linear/log; forward/inverse; Nearest/Linear/Cubic/Lanczos_4; zero outliers; no overlapping destination |
| Filtering | `Median_Blur` | nonempty 2-D; 1/3/4 channels | odd kernel >= 3; 3/5: `UInt8`/`UInt16`/`Float32`; >5: `UInt8` only; in-place supported; internal `BORDER_REPLICATE` |

| Filtering | `Box_Blur` | nonempty 2-D; supported numeric depths | positive width/height; even and non-square kernels valid; arbitrary channels; centered anchor; Wrap rejected; in-place supported |
| Filtering | `Bilateral_Filter` | nonempty 2-D; `UInt8` or `Float32`; 1 or 3 channels | automatic or explicit diameter; positive finite sigmas; Wrap rejected; in-place unsupported |
| Filtering | `Pyramid_Mean_Shift_Filter` | nonempty 2-D `UInt8` C3; every generated pyramid level >= 2 x 2 | mean-shift posterization (not region labeling); positive spatial / nonnegative color radius; level 0 .. 8; explicit 1 .. 100 iterations and epsilon; Region-local snapshot; Destination rebound only on success; aliasing supported |
| Filtering | `Filter_2D` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64` | correlation, not convolution; single-channel Float32/Float64 kernel; destination-depth matrix; Wrap rejected; Same_Depth in-place supported |
| Filtering | `Sep_Filter_2D` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64` | Kernel_X then Kernel_Y; 1-D Float32/Float64 vectors of matching depth; destination-depth matrix; Wrap rejected; Same_Depth in-place supported |
| Morphology | `Erode`, `Dilate` | nonempty 2-D; supported numeric depths | rectangle/cross/ellipse, positive iterations, in-place supported |
| Morphology | `Apply_Morphology` | same as above | opening, closing, gradient, top-hat, black-hat |
| Edges | `Canny_Edges` | nonempty 2-D `UInt8` C1 | 3x3/5x5/7x7 Sobel aperture, L1/L2 norm |
| Derivatives | `Sobel` | nonempty 2-D; supported numeric depths | X/Y orders, kernel 1/3/5/7, scale/offset |
| Derivatives | `Scharr` | nonempty 2-D; supported numeric depths | first derivative on X or Y |
| Derivatives | `Laplacian` | nonempty 2-D; supported numeric depths | odd kernel size 1..31, scale/offset |
| Thresholding | `Apply_Threshold` | nonempty 2-D; supported numeric depths | five fixed-threshold modes |
| Thresholding | `Apply_Automatic_Threshold` | nonempty 2-D C1 | Otsu: `UInt8`/`UInt16`; Triangle: `UInt8` |
| Thresholding | `Apply_Adaptive_Threshold` | nonempty 2-D `UInt8` C1 | mean/Gaussian, odd block size >= 3, in-place supported |
| Histogram | `Equalize_Histogram` | nonempty 2-D `UInt8` C1 | global CDF equalization; constant images retain intensity; same-object in-place supported; other storage-sharing aliases rejected |
| Image statistics | `Accumulate_Image`, `Accumulate_Image_Square`, `Accumulate_Image_Product`, `Update_Running_Average` | nonempty 2-D; floating Base; documented portable depth/channel contracts below | fresh atomic result; optional UInt8 C1 mask; finite Weight in [0,1]; logical Regions and input aliases supported |
| Histogram | `CLAHE` | nonempty 2-D `UInt8`/`UInt16` C1 | local contrast-limited equalization; default clip 40.0 and grid 8x8; same-object in-place supported; other storage-sharing aliases rejected |
| Contours | `Find_Contours` | nonempty 2-D `UInt8` C1 | four retrieval modes, four approximation modes, signed offset |
| Analysis | `Connected_Components_With_Stats` | nonempty 2-D `UInt8` C1 | 4/8-way binary-mask labeling; Int32 C1 labels and Ada-owned foreground statistics |
| Analysis | `Distance_Transform`, `Manhattan_Distance_Transform_UInt8`, `Distance_Transform_With_Labels` | nonempty 2-D `UInt8` C1 with at least one zero | fresh Float32 distances, saturating UInt8 L1, or Float32 distances plus Int32 Voronoi labels |
| Analysis | `Integral_Sum`, `Integral_Sum_And_Squares`, `Integral_Images` | nonempty 2-D `UInt8`, `Float32`, `Float64`; arbitrary valid channel count | fresh, independent-channel `(rows+1) x (cols+1)` integral Mats; Float64 accumulator defaults |
| Drawing | `Draw_Line`, `Draw_Arrow`, `Draw_Marker`, `Draw_Text`, `Measure_Text`, `Font_Scale_For_Height`, rectangles, circles, ellipses, polylines, polygons | shapes: nonempty 2-D `UInt8`, `UInt16`, `Int16`, `Float32`, `Float64` C1..C4; text: nonempty 2-D `UInt8` C1/C3/C4 | in-place annotation; legacy text selectors; shape antialiasing only for `UInt8`; no alpha blending |
| Hough | `Find_Hough_Lines`, `Find_Hough_Line_Segments` | nonempty 2-D `UInt8` C1 binary image | classical polar lines (radians) and probabilistic integer segments; Ada-owned arrays; source-preserving snapshot |
| Hough | `Find_Hough_Circles` | nonempty 2-D `UInt8` C1 grayscale image | classic `HOUGH_GRADIENT`; automatic or explicit maximum radius; Float32 center/radius; source-preserving snapshot |
| Hough | `Find_Hough_Lines_With_Votes`, `Find_Hough_Lines_From_Points` | binary `UInt8` C1 image, or an Ada array of finite Float32 points | polar lines with accumulator votes; point-set rho range must contain every vote (OpenCV 4.1 safety) |
| Hough | `Find_Hough_Circle_Centers`, `Find_Hough_Circles_With_Votes` | nonempty 2-D `UInt8` C1 grayscale image | centers-only gradient detection; radius-finding circles with support votes |
| Segmentation | `Flood_Fill`, `Flood_Fill_With_Mask` | nonempty 2-D `UInt8`/`Float32`, C1/C3; mask `UInt8` C1 `(rows + 2) x (cols + 2)` | in place; floating/fixed range; 4/8 connectivity; area and bounds; mask fill value and mask-only mode |
| Segmentation | `Watershed` | `UInt8` C3 source; `Int32` C1 markers of the same size | markers mutated in place (`-1` boundaries); source preserved; nonnegative input markers; overlap rejected |
| Segmentation | `Initialize_GrabCut`, `Restore_GrabCut_State`, `Clone_GrabCut_State`, `Refine_GrabCut`, `Refine_GrabCut_Frozen_Model` | `UInt8` C3 source; rectangle and/or 0..3 label mask; imported Float64 C1 1 x 65 models | limited private state; masks and models exported as deep clones; restored models validated before evaluation |
| Histogram analysis | `Calculate_Histogram`, `Calculate_Nonuniform_Histogram` | one Mat, or several Mats of the same rows, columns, and `UInt8`/`UInt16`/`Float32` depth; per-axis channel or `(Source_Position, Channel)`; optional `UInt8` C1 mask | dense 1..10-D Float32 counts; one binning mode per histogram, either uniform `[lower, upper)` bins or explicit nonuniform edges |
| Histogram analysis | `Compare_Histograms` | two histograms with the same binning mode and identical bin geometry | six OpenCV metrics; source positions and channels may differ; nonuniform comparison requires the exact edge sequence |
| Histogram analysis | `Back_Project` | one Mat when every stored source position is 0, or enough same-geometry sources for the stored positions | fresh C1 Mat of the first source's size and depth; finite scale |
| Histogram analysis | `Accumulate_Histogram` | a calculated histogram plus a compatible source or source array, optional mask | new histogram; Base is unchanged; Float32 bin sums, not native `accumulate=true` |
| Histogram analysis | `Earth_Mover_Distance`, `Earth_Mover_Distance_With_Flow`, `Earth_Mover_Distance_With_Cost`, `Earth_Mover_Distance_With_Cost_And_Flow` | nonempty 2-D Float32 C1 signatures; optional Float32 C1 transport-cost matrix | exact native EMD, optionally with fresh real-row transport Flow; packed snapshots for Region portability |

The supported general-purpose Imgproc numeric depths are:

```text
UInt8
UInt16
Int16
Float32
Float64
```

Individual operations may intentionally support a narrower set.

---

## YUV 4:2:0

Frame conversion is deliberately **separate from `Color_Conversion`** because
YUV420 changes geometry and can have two independent source planes:

```ada
type YUV420_Layout is (I420, YV12, NV12, NV21);
subtype YUV420_Planar_Layout is YUV420_Layout range I420 .. YV12;
subtype YUV420_Semiplanar_Layout is YUV420_Layout range NV12 .. NV21;
type YUV420_Color_Output is
  (BGR_Output, RGB_Output, BGRA_Output, RGBA_Output);
type YUV_Color_Order is (BGR_Order, RGB_Order);

function Decode_YUV420
  (Source : OpenCV.Core.Mat;
   Layout : YUV420_Layout;
   Output : YUV420_Color_Output := BGR_Output) return OpenCV.Core.Mat;
function Decode_YUV420_Two_Plane
  (Y_Plane, UV_Plane : OpenCV.Core.Mat;
   Layout : YUV420_Semiplanar_Layout;
   Output : YUV420_Color_Output := BGR_Output) return OpenCV.Core.Mat;
function Encode_YUV420_Planar
  (Source : OpenCV.Core.Mat;
   Layout : YUV420_Planar_Layout;
   Order : YUV_Color_Order := BGR_Order) return OpenCV.Core.Mat;
function Extract_YUV420_Luma
  (Source : OpenCV.Core.Mat) return OpenCV.Core.Mat;
```

Logical width `W` and height `H` must both be even and at least 2. The packed
representation is **UInt8 C1, W columns, H + H/2 rows** (canonical OpenCV
`W x 3H/2`). Packed rows must be divisible by 3. All layouts start with
`W*H` Y bytes. In the flat logical row-major stream:

| Layout | Bytes following Y |
|---|---|
| I420 | `W*H/4` U bytes, then `W*H/4` V bytes |
| YV12 | `W*H/4` V bytes, then `W*H/4` U bytes |
| NV12 | interleaved `U,V` pairs |
| NV21 | interleaved `V,U` pairs |

Two-plane decode accepts **only** Y = UInt8 C1 `H x W` and UV = UInt8 C2
`H/2 x W/2`. A C1 chroma byte matrix, C3/C4 UV, alternate depths, ND Mats,
or mismatched dimensions are not accepted.

| Output | Result | Color order |
|---|---|---|
| BGR_Output | UInt8 C3 `H x W` | B, G, R |
| RGB_Output | UInt8 C3 `H x W` | R, G, B |
| BGRA_Output | UInt8 C4 `H x W` | B, G, R, 255 |
| RGBA_Output | UInt8 C4 `H x W` | R, G, B, 255 |

Encoding accepts UInt8 C3/C4 `H x W`, produces I420 or YV12 UInt8 C1
`(H+H/2) x W`, and interprets `BGR_Order` as BGR/BGRA and `RGB_Order` as
RGB/RGBA. **Alpha is ignored**, including 0, 1, 128 and 255: no premultiplication
is performed. **NV12/NV21 encoding and two-plane encoding are not provided.**

This is native **BT.601-style limited-range** conversion: nominal Y 16..235,
Cb/Cr 16..240 with center 128. Every UInt8 byte is accepted, including values
outside those nominal ranges; decode clamps `Y-16` below zero and saturates
RGB. Portable CPU encode/decode use the pinned 20-bit fixed-point coefficients.
Vendor implementations can have different rounding; arbitrary vendor/build
pixel identity is not promised. **Luma extraction copies raw Y bytes exactly**
using `COLOR_YUV2GRAY_420`; it neither subtracts 16 nor rescales to full range.

The reviewed scalar and SIMD encoders compute Y for **every pixel**, but U/V
for each 2x2 block use **only its top-left color sample**, not an average of the
four colors. Changing unsampled colors changes their Y values, not that block's
U/V. YUV420 chroma subsampling and integer quantization are lossy; arbitrary
RGB round trips are not identity transforms.

Every source is copied manually by logical rows into independent packed Mats,
without passing arbitrary parent strides into optional copy/YUV backends.
Inputs stay unchanged, results own fresh storage, and invalid public inputs
raise `OpenCV.OpenCV_Error`. Native arithmetic/address-span limits are checked
before allocation; there are no arbitrary practical image-size caps.

**Regions are standalone logical buffers.** A packed Region must itself contain
the entire valid frame layout; parent plane offsets are never inferred. Y and
UV Regions must describe corresponding planes supplied by the caller; parent
ROI origins are not used to infer chroma phase. Outside-parent pixels cannot
participate. Independent Y and UV snapshots both have byte step W, normalizing
**OpenCV 4.1's shared Y/UV stride** even when the original parent strides differ.

Both packed and separate NV12/NV21 decode intentionally use the same public
`cv::cvtColorTwoPlane` route after snapshots, so the two representations decode
**exactly equally** within a native build. On 4.1 this deliberately bypasses
packed `cvtColor`'s single-buffer HAL/Carotene opportunity; the pair API goes
to CPU dispatch. On 4.10/5.0 the pair API can reach expanded separate-plane HAL
implementations. No global acceleration switch or hint policy is introduced.
I420/YV12 and luma retain their natural native `cvtColor` routes.

**50 focused new AUnit tests**, baseline 730: **780 registered, 780 executed,
780 passed**, zero failed assertions and unexpected errors locally on 4.10.0.
Exact 4.1.0/4.10.0/5.0.0 source findings, backend reachability, bounds, and
runtime limits are recorded in [the source review](docs/yuv420-source-review.md).

---

## YUV 4:2:2

Portable packed **decode and raw luma extraction** are separate from
`Color_Conversion`, without changing the existing YUV420 output enumeration:

```ada
type YUV422_Layout is (UYVY, YUY2, YVYU);
subtype YUV422_Color_Output is YUV420_Color_Output;

function Decode_YUV422
  (Source : OpenCV.Core.Mat;
   Layout : YUV422_Layout;
   Output : YUV422_Color_Output := BGR_Output) return OpenCV.Core.Mat;
function Extract_YUV422_Luma
  (Source : OpenCV.Core.Mat;
   Layout : YUV422_Layout) return OpenCV.Core.Mat;
```

Source is exactly **nonempty 2-D UInt8 C2, H rows and W columns**, with
**H >= 1 and even W >= 2**. Each C2 element contains two consecutive bytes;
two adjacent elements form one chroma pair:

| Layout | Four stream bytes | First C2 column | Second C2 column |
|---|---|---|---|
| UYVY | U, Y0, V, Y1 | U, Y0 | V, Y1 |
| YUY2 | Y0, U, Y1, V | Y0, U | Y1, V |
| YVYU | Y0, V, Y1, U | Y0, V | Y1, U |

U/V are shared by **exactly two horizontal pixels**; Y0 and Y1 remain
independent. This is not C1 with doubled width, UInt16 C1, or four-byte pixels.
Only the three canonical layout names are exposed; VYUY is not supported.

Decode preserves H x W and UInt8 depth. `BGR_Output`/`RGB_Output` return
C3 in B,G,R / R,G,B order; `BGRA_Output`/`RGBA_Output` return C4 in
B,G,R,255 / R,G,B,255 order. **Alpha is always 255.** Conversion uses native
limited-range BT.601-style arithmetic, with 20-bit portable CPU coefficients:
nominal Y 16..235, Cb/Cr 16..240, centered at 128. **All bytes 0..255 are
accepted**, including outside-studio values; native saturation applies.
Vendor/build pixel identity is not promised. No custom matrix, full-range,
BT.709/2020, or public AlgorithmHint selection is added.

Luma is **exact raw Y**, UInt8 C1 H x W: UYVY extracts C2 channel 1;
YUY2 and YVYU extract channel 0. No subtract-16, normalization, color
conversion arithmetic, or chroma participation occurs.

Every operation manually snapshots logical rows into independent packed C2
storage before native entry; results own fresh Core Mat storage and inputs
remain unchanged. **Regions are complete standalone frames.** Outside-parent
bytes cannot affect conversion. The caller must supply the declared logical
byte phase: an odd-column ROI into a UYVY parent can change that phase. The
binding does not infer or rewrite Layout from parent ROI offsets.

**OpenCV 4.1 lacks a native even-width check.** Its pair loop may read the
missing second pixel/chroma and write two output pixels for an odd final
column. Ada and the raw decode shim reject odd widths before native entry.
OpenCV 4.10/5.0 add `FROM_UYVY` even-width validation. Widened native
arithmetic preflight also requires `2*W <= INT_MAX`, `W*H <= INT_MAX`, safe
snapshot/result allocations, and representable original readable address spans.
Reachable 4.x OpenVX RGB(A) output-step narrowing is checked specifically;
arbitrary parent strides are not passed to optional native backends.
Invalid public input raises `OpenCV.OpenCV_Error`.

**Decode only in the portable API:** RGB/BGR/BGRA/RGBA-to-YUV422 encode
codes exist in OpenCV 4.10/5.0 but are absent in 4.1. Encoding is available
only in newer OpenCV releases and intentionally deferred from the portable
4.1/4.10/5.0 baseline. Planar 4:2:2, higher-bit-depth YUV, and UMat remain
outside this slice; this does not complete all YUV422 capabilities.

**32 focused new AUnit tests**, baseline 780: **812 registered, 812 executed,
812 passed**, zero failed assertions and unexpected errors locally on 4.10.0.
Exact-tag backend, numeric, safety and execution limits are recorded in
[the YUV422 source review](docs/yuv422-source-review.md).

---

## Bayer demosaicing

Portable native `cv::demosaicing` is separate from `Color_Conversion`:

```ada
type Bayer_Pattern is (RGGB, GRBG, BGGR, GBRG);
type Bayer_Demosaicing_Method is
  (Bilinear, Variable_Number_Of_Gradients, Edge_Aware);
type Bayer_Color_Order is (BGR_Order, RGB_Order);

function Demosaic_Bayer
  (Source  : OpenCV.Core.Mat;
   Pattern : Bayer_Pattern;
   Method  : Bayer_Demosaicing_Method := Bilinear;
   Order   : Bayer_Color_Order := BGR_Order) return OpenCV.Core.Mat;

function Demosaic_Bayer_To_Gray
  (Source : OpenCV.Core.Mat; Pattern : Bayer_Pattern)
   return OpenCV.Core.Mat;

function Demosaic_Bayer_With_Alpha
  (Source  : OpenCV.Core.Mat;
   Pattern : Bayer_Pattern;
   Order   : Bayer_Color_Order := BGR_Order) return OpenCV.Core.Mat;
```

| Operation | Source depth | Output |
|---|---|---|
| Bilinear color | UInt8 / UInt16 | C3 BGR or RGB |
| Variable Number of Gradients (VNG) | **UInt8 only** | C3 BGR or RGB |
| Edge_Aware | UInt8 / UInt16 | C3 BGR or RGB |
| Direct bilinear Gray | UInt8 / UInt16 | C1 native luminance |
| Bilinear with alpha | UInt8 / UInt16 | C4 BGRA or RGBA |

Every call requires a **nonempty 2-D C1 Source with Width/Height >=3**.
This public minimum avoids native degenerate zero/border-only results.
Other depths (including UInt16 VNG) reject with `OpenCV.OpenCV_Error`;
there is no depth conversion. Results preserve rows, columns, and depth.
The alpha channel comes from native OpenCV: **255 for UInt8, 65535 for
UInt16**. Ada does not insert alpha or implement interpolation.

On affected legacy OpenCV 4.x releases, an additional UInt16 Bayer-to-Gray
safety preflight rejects neighborhoods that would overflow the native signed
fixed-point intermediate. OpenCV **4.5.5+** uses corrected unsigned arithmetic
and needs no such restriction. See the
[source/safety review](docs/bayer-demosaicing-source-review.md#legacy-uint16-gray-signed-overflow-safety).

Patterns are physical **2x2 CFA tiles**, not OpenCV's counterintuitive short
names. For BGR, physical RGGB/GRBG/BGGR/GBRG map to historical BG/GB/RG/GR
codes respectively. RGB aliases exchange red/blue destinations. No native
COLOR_Bayer integer constants are public.

**OpenCV falls back to bilinear demosaicing when either dimension is below 8.**
Requests 3x3 through 7x7 are accepted, not rejected to force gradients.
There is a native 4.1/4.10 quirk: this fallback does not decode VNG aliases for
phase/order and behaves as BGGR/BGR; 5.0 corrects the decoding. The binding
preserves native calls rather than silently substituting a different code.
For accurate phase/order on small images across all versions, select Bilinear
explicitly. VNG at >=8 uses the native gradient algorithm.

All methods first make a **packed independent snapshot** of Source. A Region
is an independent logical Bayer image: outside-parent pixels do not
participate, and a Region equals its clone with the same explicit Pattern.
**Pattern refers to logical Source coordinate (0,0)**. Cropping a parent at odd
row/column offsets changes its Bayer phase; the caller must choose the new
Pattern. The wrapper never infers or rewrites it from parent offsets.

Source and parent storage are preserved. Each call returns a **fresh owning
Core Mat**, independent of Source, shared aliases, and other call results.
Native failure leaves raw destination storage unchanged; exceptions do not
cross the C ABI.

OpenCV 4.1/4.10 VNG processes source storage directly and manually copies
border rows. OpenCV 5.0 instead adds two-pixel **BORDER_REFLECT_101** padding.
The snapshot prevents that padding from extending into Region parent storage.
**Cross-version VNG border values are not promised identical.** The installed
OpenCV algorithm is preserved, with no Ada emulation or backend toggles.

See [the exact-tag source/safety review](docs/bayer-demosaicing-source-review.md)
for signed element-step and row-index bounds, EA's C3 arithmetic, VNG N*147
scratch/padding checks, allocation portability, and SIMD/backend differences.

This slice adds **43 focused AUnit tests**: baseline 687; **730 registered,
730 executed, 730 passed**, zero failed assertions and unexpected errors.
Local execution is OpenCV 4.10.0; 4.1.0/5.0.0 are source-reviewed, not locally
runtime-tested. Allocation-free native arithmetic checks can be run with:

```sh
c++ -std=c++17 -Wall -Wextra -Wpedantic -Werror \
  tests/bayer_layout_test.cpp -o /tmp/bayer_layout_test
/tmp/bayer_layout_test
```

## Color conversion

`Color_Conversion` names the source and destination layouts explicitly. OpenCV
defaults to **BGR** ordering, not RGB. The public operation remains:

```ada
procedure Convert_Color
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Conversion  : Color_Conversion);
```

| Group | Public conversions | Input / output channels | Source depths |
| --- | --- | --- | --- |
| Layout / Gray | `BGR_To_Gray`, `RGB_To_Gray`, `BGRA_To_Gray`, `RGBA_To_Gray`; `Gray_To_BGR`, `Gray_To_RGB`, `Gray_To_BGRA`, `Gray_To_RGBA`; `BGR_To_RGB`, `RGB_To_BGR`; `BGR_To_BGRA`, `RGB_To_RGBA`, `BGR_To_RGBA`, `RGB_To_BGRA`; `BGRA_To_BGR`, `RGBA_To_RGB`, `RGBA_To_BGR`, `BGRA_To_RGB`, `BGRA_To_RGBA`, `RGBA_To_BGRA` | Gray C1, BGR/RGB C3, BGRA/RGBA C4 | UInt8, UInt16, Float32 |
| XYZ | `BGR_To_XYZ`, `RGB_To_XYZ`, `XYZ_To_BGR`, `XYZ_To_RGB` | C3 / C3 | UInt8, UInt16, Float32 |
| YCrCb | `BGR_To_YCrCb`, `RGB_To_YCrCb`, `YCrCb_To_BGR`, `YCrCb_To_RGB` | C3 / C3 | UInt8, UInt16, Float32 |
| 3-channel YUV | `BGR_To_YUV`, `RGB_To_YUV`, `YUV_To_BGR`, `YUV_To_RGB` | C3 / C3 | UInt8, UInt16, Float32 |
| HSV | `BGR_To_HSV`, `RGB_To_HSV`, `HSV_To_BGR`, `HSV_To_RGB` | C3 / C3 | UInt8, Float32 |
| HLS | `BGR_To_HLS`, `RGB_To_HLS`, `HLS_To_BGR`, `HLS_To_RGB` | C3 / C3 | UInt8, Float32 |
| Lab | `BGR_To_Lab`, `RGB_To_Lab`, `Lab_To_BGR`, `Lab_To_RGB` | C3 / C3 | UInt8, Float32 |
| Luv | `BGR_To_Luv`, `RGB_To_Luv`, `Luv_To_BGR`, `Luv_To_RGB` | C3 / C3 | UInt8, Float32 |
| HSV FULL | `BGR_To_HSV_Full`, `RGB_To_HSV_Full`, `HSV_Full_To_BGR`, `HSV_Full_To_RGB` | C3 / C3 | UInt8, Float32 |
| HLS FULL | `BGR_To_HLS_Full`, `RGB_To_HLS_Full`, `HLS_Full_To_BGR`, `HLS_Full_To_RGB` | C3 / C3 | UInt8, Float32 |
| Linear-light Lab | `Linear_BGR_To_Lab`, `Linear_RGB_To_Lab`, `Lab_To_Linear_BGR`, `Lab_To_Linear_RGB` | C3 / C3 | UInt8, Float32 |
| Linear-light Luv | `Linear_BGR_To_Luv`, `Linear_RGB_To_Luv`, `Luv_To_Linear_BGR`, `Luv_To_Linear_RGB` | C3 / C3 | UInt8, Float32 |
| Premultiplied RGBA | `RGBA_To_Premultiplied_RGBA`, `Premultiplied_RGBA_To_RGBA` | C4 / C4 | UInt8 only |
| BGR565 / BGR555 | BGR, RGB, BGRA, RGBA and Gray to/from each packed layout | packed C2; Gray C1; BGR/RGB C3; BGRA/RGBA C4 | UInt8 only |

Source must be nonempty and 2-D with *exactly* the channels implied by its
name. Every result retains the source rows, columns and depth. When alpha is
added in ordinary conversions, OpenCV writes 255 (`UInt8`), 65535 (`UInt16`),
or 1.0 (`Float32`);
removing alpha discards it, while BGRA/RGBA swaps preserve it. Float32 BGR/RGB
is normally scaled to 0..1; **normalize before Float32 Lab/Luv** for meaningful
sRGB-oriented results. No value sanitizer rejects out-of-range finite values.
Ordinary Lab/Luv selectors use sRGB transfer behavior. The explicitly named
linear-light selectors instead consume/produce linear RGB without sRGB
decoding/encoding. OpenCV performs the CIE transform; the binding does not
implement gamma conversion or rescale Lab/Luv. Linear Float32 RGB is normally
0..1, and UInt8 retains native 0..255 encoding; no per-pixel range check is made.

Standard UInt8 HSV/HLS hue uses 0..180-style encoding for the 0..360 degree
circle; FULL uses full-byte 0..255 encoding. Native CPU FULL uses an internal
forward scale of **256** and reverse scale of **255**: these are intentionally
not corrected, and exact UInt8 FULL round trips are not promised. Float32
standard and FULL both use **degree-based hue** (360-degree scale) and are
numerically equivalent in the pinned OpenCV 4.1.0/4.10.0/5.0.0 implementations.
FULL does not rescale floating hue to 0..255 or normalize/sanitize pixels.

Premultiplied RGBA multiplies each color by alpha/255 while preserving alpha.
The native scalar forward expectation is `(color * alpha + 128) / 255`.
The inverse uses saturating `(premultiplied * 255 + alpha / 2) / alpha`;
zero alpha gives zero color. Noncanonical premultiplied color greater than
alpha is accepted and saturates, not rejected. Low-alpha quantization loses
information, so premultiply/unpremultiply is generally **lossy** (opaque
pixels are preserved). Only the named RGBA UInt8 C4 contract is exposed,
without BGRA aliases or Float32/UInt16 variants.

The [extended color source review](docs/extended-color-source-review.md)
documents exact-tag dispatch, SIMD, IPP/HAL reachability and native arithmetic
safety findings. Local runtime validation uses OpenCV 4.10.0 only.

Regions are logical standalone images: no parent pixels outside the Region
participate. Source remains unchanged for distinct Destination; same-object
conversion is supported. Destination is rebound only after successful native
conversion. The raw bridge also checks actual source byte stride and derived
output byte stride for reachable optional IPP paths which narrow them to int.

### Portable packed BGR565 / BGR555

BGR565/BGR555 are exposed as **UInt8 C2** because that is OpenCV's native Mat
representation. The two bytes use the host's native 16-bit byte order.
This API does not define a network/file-format byte order. They are not
UInt16 C1 images; logical rows and columns are unchanged.

All twenty selectors are available through `Convert_Color`:

| Source | BGR565 selector | BGR555 selector | Destination |
| --- | --- | --- | --- |
| BGR C3 | `BGR_To_BGR565` | `BGR_To_BGR555` | packed C2 |
| RGB C3 | `RGB_To_BGR565` | `RGB_To_BGR555` | packed C2 |
| BGRA C4 | `BGRA_To_BGR565` | `BGRA_To_BGR555` | packed C2 |
| RGBA C4 | `RGBA_To_BGR565` | `RGBA_To_BGR555` | packed C2 |
| Gray C1 | `Gray_To_BGR565` | `Gray_To_BGR555` | packed C2 |
| packed C2 | `BGR565_To_BGR` | `BGR555_To_BGR` | BGR C3 |
| packed C2 | `BGR565_To_RGB` | `BGR555_To_RGB` | RGB C3 |
| packed C2 | `BGR565_To_BGRA` | `BGR555_To_BGRA` | BGRA C4 |
| packed C2 | `BGR565_To_RGBA` | `BGR555_To_RGBA` | RGBA C4 |
| packed C2 | `BGR565_To_Gray` | `BGR555_To_Gray` | Gray C1 |

Every source must be nonempty, 2-D, **UInt8**, with exactly the listed channels.
Other depths, including UInt16 and Float32, raise `OpenCV_Error`.

In a native word, BGR565 stores blue in bits 0..4, green in 5..10 and red in
11..15. BGR555 stores blue in 0..4, green in 5..9, red in 10..14 and an alpha
flag in bit 15. RGB/RGBA selectors interpret source channel order but produce
the **same** BGR packed layout, not an RGB packed format.

Native packing truncates low bits. Expansion uses shifts without low-bit
replication: maximum B/R is 248; maximum green is 252 for BGR565 and 248 for
BGR555. Gray packing quantizes each color field; packed-to-Gray applies native
integer luminance coefficients to the expanded colors. Arbitrary Gray round
trips are therefore not exact (white becomes 250 via BGR565, 248 via BGR555).

**Alpha:** BGR565 ignores C4 input alpha and always expands alpha to 255.
BGR555 packs C4 alpha as a boolean nonzero flag: 0 expands to 0; 1, 128 and
255 all expand to 255. **C3 and Gray packing leave the BGR555 alpha bit zero**,
so subsequent BGRA/RGBA expansion has alpha 0, not 255.

Source Regions use only their logical geometry and actual row stride; no
parent pixels participate and no isolation clone is needed. Conversion builds
fresh storage before rebinding Destination. Same-variable and shared-storage
conversion are supported; rebinding an old Destination Region does not modify
its parent, inside or outside the view. Failure leaves Destination unchanged.
Packed paths reject pixel counts above signed-int range because native CPU
and optional Carotene scheduling multiply width by height in signed arithmetic.
See [the pinned source review](docs/packed-color-source-review.md) for exact
native paths, formulas and boundary checks.

```ada
Convert_Color (BGR_Image, Gray_Image, BGR_To_Gray);
Convert_Color (BGR_Image, HSV_Image, BGR_To_HSV);
--  Normalized_Bgr is Float32 C3 with B,G,R in the usual 0..1 range.
Convert_Color (Normalized_Bgr, Lab_Image, BGR_To_Lab);
Convert_Color (Lab_Image, Restored_Bgr, Lab_To_BGR);
```

---

## Resizing

Interpolation methods:

```ada
type Interpolation_Method is
  (Nearest_Neighbor, Linear, Cubic, Area, Lanczos_4);
```

API:

```ada
procedure Resize
  (Source        : OpenCV.Core.Mat;
   Destination   : in out OpenCV.Core.Mat;
   Output_Size   : OpenCV.Size;
   Interpolation : Interpolation_Method := Linear);
```

Requirements:

- source is nonempty and two-dimensional;
- source depth is `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`;
- output width and height are nonzero.

The operation preserves the source element depth and channel count.

---

## Gaussian blur

API:

```ada
procedure Gaussian_Blur
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Kernel_Size : OpenCV.Size;
   Sigma       : OpenCV.Float64_Value;
   Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);
```

The binding currently exposes an isotropic Gaussian blur: the same `Sigma`
value is used for both axes.

Requirements:

- source is nonempty and two-dimensional;
- depth is one of the supported general Imgproc numeric depths;
- kernel width and height are positive and odd;
- `Sigma` is positive and finite.

Supported borders:

```text
Constant_Border
Replicate
Reflect
Reflect_101
```

`Wrap` is rejected.

The output preserves rows, columns, depth, and channel count.

---

## Gaussian kernel

API:

```ada
subtype Gaussian_Kernel_Size is
  Positive range 1 .. 2_147_483_647;

type Gaussian_Kernel_Depth is
  (Float32_Kernel, Float64_Kernel);

function Get_Gaussian_Kernel
  (Kernel_Size : Gaussian_Kernel_Size;
   Depth       : Gaussian_Kernel_Depth := Float64_Kernel)
   return OpenCV.Core.Mat;

function Get_Gaussian_Kernel
  (Kernel_Size : Gaussian_Kernel_Size;
   Sigma       : OpenCV.Float64_Value;
   Depth       : Gaussian_Kernel_Depth := Float64_Kernel)
   return OpenCV.Core.Mat;
```

`Get_Gaussian_Kernel` returns an `N x 1` single-channel Gaussian coefficient
vector. Coefficient order is preserved and may be passed directly to
`Sep_Filter_2D`.

The overload without `Sigma` asks OpenCV to derive sigma from `Kernel_Size`.
There is no public zero or negative sigma sentinel. The overload with `Sigma`
requires a finite value strictly greater than zero; `0.0` does not switch to
automatic sigma.

Requirements:

- `Kernel_Size` is positive and odd;
- explicit `Sigma`, when provided, is finite and strictly greater than zero;
- `Depth` selects `Float32` or `Float64` output.

The returned Mat owns ordinary Core lifetime. Even lengths remain invalid even
though `Sep_Filter_2D` accepts even-length arbitrary kernels.

---

## Derivative kernels

API:

```ada
subtype Derivative_Kernel_Depth is Gaussian_Kernel_Depth;

type Derivative_Kernel_Normalization is
  (Unnormalized, Normalized);

type Derivative_Kernels is record
   Kernel_X : OpenCV.Core.Mat;
   Kernel_Y : OpenCV.Core.Mat;
end record;

function Get_Derivative_Kernels
  (X_Order       : Derivative_Order;
   Y_Order       : Derivative_Order;
   Kernel_Size   : Sobel_Kernel_Size := Kernel_3;
   Normalization : Derivative_Kernel_Normalization := Unnormalized;
   Depth         : Derivative_Kernel_Depth := Float32_Kernel)
   return Derivative_Kernels;

function Get_Scharr_Kernels
  (Axis          : Derivative_Axis;
   Normalization : Derivative_Kernel_Normalization := Unnormalized;
   Depth         : Derivative_Kernel_Depth := Float32_Kernel)
   return Derivative_Kernels;
```

These functions generate separable 1-D derivative coefficient vectors; they do
not filter an image themselves. `Kernel_X` applies in X and `Kernel_Y` applies
in Y. Both are independently owned single-channel column vectors (`N x 1`) of
matching `Float32` or `Float64` depth. Coefficient order is preserved and may
be passed directly to `Sep_Filter_2D`. `Normalized` changes coefficient
scaling, not derivative order.

`Get_Derivative_Kernels` uses the existing Sobel kernel sizes `Kernel_1`,
`Kernel_3`, `Kernel_5`, and `Kernel_7`. `X_Order` and `Y_Order` cannot both be
zero, and each order must be strictly less than the effective one-dimensional
length in that direction. For `Kernel_1`, a nonzero-order direction uses an
effective 3-tap vector while a zero-order direction remains a 1-tap identity,
so the two lengths may differ.

`Get_Scharr_Kernels` is a separate first-derivative API. There is no public
`FILTER_SCHARR` or `-1` kernel-size sentinel. Both Scharr vectors are length 3.

---

## Image pyramids

API:

```ada
procedure Pyramid_Down
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

procedure Pyramid_Up
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat);
```

`Pyramid_Down` performs OpenCV's Gaussian-pyramid downsampling. Destination
keeps Source depth and channel count and uses the natural size:

```text
Destination.Columns = (Source.Columns + 1) / 2
Destination.Rows    = (Source.Rows    + 1) / 2
```

Supported depths are `UInt8`, `UInt16`, `Int16`, `Float32`, and `Float64`.
Channel count is unrestricted. `Replicate`, `Reflect`, `Reflect_101`, and
`Wrap` are accepted; `Constant_Border` is rejected. Source and Destination
must not address overlapping storage, including overlapping Regions. A Source
Region is processed as its own logical image: parent
pixels outside the Region do not participate. Only submatrix sources require
a logical-view copy; ordinary owning Mats stay on the direct path. Extreme
geometries are rejected before native signed-int pyramid intermediate
arithmetic can overflow.

`Pyramid_Up` performs OpenCV's Gaussian-pyramid upsampling. Destination keeps
Source depth and channel count and exactly doubles both dimensions. OpenCV
supports only its default border for this operation, so no `Border` parameter
is exposed. A Source Region is processed as its own logical image, without
parent pixels. Source and Destination must not address overlapping storage,
including overlapping Regions. Extreme geometries are rejected before native
signed-int pyramid intermediate arithmetic can overflow.

`Pyramid_Up(Pyramid_Down(Image))` is generally a smoothed reconstruction, not
the original image.

### Explicit-size upsampling

```ada
procedure Pyramid_Up
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Output_Size : OpenCV.Size);
```

The explicit-size overload calls native `pyrUp` with the requested size, so
odd previous-level geometry can be recovered exactly (for example
`9 -> 5 -> 9` and `7 -> 4 -> 7`). Each extent must be `2 * Source` or
`2 * Source - 1`; other sizes are rejected in Ada before any native work.
OpenCV also accepts `2 * Source + 1`, but its extra **column** is not
portable: OpenCV 4.1-4.6 index it incorrectly for multichannel images, and
every reviewed release leaves it unwritten for one-column sources, so the
binding does not expose that size. (The scalar path does explicitly fill a
`2 * Source + 1` extra row; the column is the problem.) A one-row target
from a one-row source (`1 -> 1`) is legal `2 * Source - 1` geometry; there
OpenCV 4.1 aliases its even and odd destination rows, which is benign because
both formulas coincide for a single source row, and the tests pin the result
to row 0 of the two-row request for integer depths. The result is computed
into fresh storage and bound to Destination only on success; a failed call
leaves Destination unchanged. Signed native ring-buffer arithmetic is checked
against the requested size, and IPP's signed row-step narrowing is checked
for the exact-double size, the only size that reaches IPP.

### Gaussian pyramids

```ada
function Maximum_Pyramid_Level_Count
  (Source : OpenCV.Core.Mat) return Positive;

function Build_Gaussian_Pyramid
  (Source      : OpenCV.Core.Mat;
   Level_Count : Positive;
   Border      : OpenCV.Border_Kind := OpenCV.Reflect_101)
   return OpenCV.Core.Mat_Array;
```

`Level_Count` is the total number of returned images, **including level 0**.
The result is indexed `0 .. Level_Count - 1`: level 0 is an independent copy
of Source and level `I` is `Pyramid_Down` of level `I - 1`.

`Maximum_Pyramid_Level_Count` counts distinct natural levels by repeatedly
applying `(N + 1) / 2` to both extents until both are 1:

```text
1 x 1 -> 1 level
2 x 2 -> 2 levels
3 x 3 -> 3 levels   3 -> 2 -> 1
8 x 8 -> 4 levels   8 -> 4 -> 2 -> 1
9 x 7 -> 5 levels   9x7 -> 5x4 -> 3x2 -> 2x1 -> 1x1
```

Larger `Level_Count` values are rejected before native allocation, so
duplicate 1 x 1 levels are never produced and the native level vector is at
most 32 entries.

Native `cv::buildPyramid` stores level 0 as a shallow header of its input.
The binding never exposes that alias: every returned level, including level
0, owns independent storage shared with neither Source nor another level. The
native result lives in a private shim handle that is destroyed after the
levels are copied, including on every error path.

Source follows the `Pyramid_Down` contract (`UInt8`, `UInt16`, `Int16`,
`Float32`, `Float64`; any channel count). `Replicate`, `Reflect`,
`Reflect_101`, and `Wrap` are supported; `Constant_Border` is rejected. A
Region is processed as its own logical image: it is cloned before native
`buildPyramid`, so parent pixels never influence any level. The whole chain
is checked for signed-int overflow before native execution, including the
per-level `pyrDown_` arithmetic, the OpenCV 4.x OpenVX row-step narrowing,
and the `ipp_buildpyramid` row-step narrowing for default-border
`UInt8`/`Float32` C1/C3 sources.

### Laplacian pyramids

```ada
type Laplacian_Precision is
  (Automatic_Precision, Float32_Precision, Float64_Precision);

function Build_Laplacian_Pyramid
  (Source      : OpenCV.Core.Mat;
   Level_Count : Positive;
   Border      : OpenCV.Border_Kind := OpenCV.Reflect_101;
   Precision   : Laplacian_Precision := Automatic_Precision)
   return OpenCV.Core.Mat_Array;

function Reconstruct_Laplacian_Pyramid
  (Pyramid : OpenCV.Core.Mat_Array) return OpenCV.Core.Mat;
```

Residuals are never computed in an integer type, where negative detail would
saturate. Source is first converted to a floating working depth:

| Precision | Working depth |
| --- | --- |
| `Automatic_Precision` | `Float64` for a Float64 Source, otherwise `Float32` |
| `Float32_Precision` | `Float32` |
| `Float64_Precision` | `Float64` |

With Gaussian levels `G (0 .. N)` of the working image:

```text
L(i) = G(i) - Pyramid_Up(G(i + 1), Output_Size => size of G(i))   for i < N
L(N) = G(N)                                                        low-frequency base
```

The last level is the low-frequency base, not a high-pass residual. Every
level has the working depth, Source's channel count, and independent storage.
Source, Region, border, and `Level_Count` rules match
`Build_Gaussian_Pyramid`.

Reconstruction runs from the coarsest level up:

```text
Current := clone(last)
for each preceding level, finest last:
   Current := Pyramid_Up(Current, Output_Size => size of level) + level
```

The whole `Mat_Array` is validated first. It must be non-empty; every level
must be non-empty and two-dimensional, share one `Float32` or `Float64` depth
and one channel count, and follow the natural geometry
`next = (current + 1) / 2` in both extents. Arrays with any index bounds are
accepted; iteration order is fine-to-coarse. Input levels are never modified.

The result keeps the floating working depth and is **not** narrowed to the
original integer type. Callers that want `UInt8` convert explicitly:

```ada
Restored : constant OpenCV.Core.Mat :=
  Image_Processing.Reconstruct_Laplacian_Pyramid (Pyramid)
    .Convert_To (OpenCV.Core.UInt8);
```

An unmodified pyramid reconstructs the working copy of Source to normal
floating-point tolerance, including odd sizes. Because the result is an
ordinary `Mat_Array`, residuals can be edited before reconstruction, for
example zeroing or scaling `Pyramid (0)` to remove or boost fine detail.

---

## Template matching

API:

```ada
type Template_Matching_Method is
  (Squared_Difference,
   Normalized_Squared_Difference,
   Cross_Correlation,
   Normalized_Cross_Correlation,
   Correlation_Coefficient,
   Normalized_Correlation_Coefficient);

procedure Match_Template
  (Source      : OpenCV.Core.Mat;
   Template    : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Method      : Template_Matching_Method);
```

`Match_Template` slides Template over Source and writes a comparison-score map
to Destination. There is no default `Method`; score interpretation depends on
the selected comparison.

Supported inputs:

- nonempty two-dimensional Source and Template;
- depth `UInt8` or `Float32`;
- 1 to 4 channels;
- identical Source and Template element type (depth and channel count).

Template must fit entirely inside Source:

```text
Template.Rows    <= Source.Rows
Template.Columns <= Source.Columns
```

A Template equal in size to Source is valid. Destination is always rebound to:

```text
Depth    = Float32
Channels = 1
Rows     = Source.Rows    - Template.Rows    + 1
Columns  = Source.Columns - Template.Columns + 1
```

Callers do not need to preallocate Destination. Multi-channel inputs are
combined into one score per candidate location; they are not converted to
grayscale.

Score interpretation:

- `Squared_Difference` and `Normalized_Squared_Difference`: the best match is
  the **minimum**;
- the other four methods: the best match is the **maximum**.

Use `OpenCV.Core.Min_Max_Loc` on the score map:

```ada
Scores  : OpenCV.Core.Mat;
Extrema : OpenCV.Core.Min_Max_Result;

Match_Template
  (Source,
   Template,
   Scores,
   Normalized_Correlation_Coefficient);

Extrema := OpenCV.Core.Min_Max_Loc (Scores);
-- Extrema.Maximum_Location is the best-match top-left for this method.
```

Source and Template are read-only and may share storage, including using the
same Mat or a Template that is a `Region` of Source. Destination must not share
storage with Source or Template.

Masked template matching is not yet bound.

---

## Affine warping

Mapping direction:

```ada
type Warp_Mapping_Direction is
  (Source_To_Destination, Destination_To_Source);

subtype Affine_Mapping_Direction is Warp_Mapping_Direction;
```

API:

```ada
procedure Warp_Affine
  (Source        : OpenCV.Core.Mat;
   Transform     : OpenCV.Core.Mat;
   Destination   : in out OpenCV.Core.Mat;
   Output_Size   : OpenCV.Size;
   Interpolation : Interpolation_Method := Linear;
   Mapping       : Affine_Mapping_Direction := Source_To_Destination;
   Border        : OpenCV.Border_Kind :=
                     OpenCV.Constant_Border;
   Border_Value  : OpenCV.Scalar := (others => 0.0));
```

`Warp_Affine` applies a 2x3 affine `Transform` to `Source` and writes the
warped image to `Destination`. Warp_Affine accepts a caller-supplied 2x3
Float32/Float64 C1 Core Mat transform.

Supported Source:

- nonempty two-dimensional Mat;
- depth `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`;
- 1 to 4 channels.

Transform requirements:

```text
Rows     = 2
Columns  = 3
Channels = 1
Depth    = Float32 or Float64
```

Coefficients are:

```text
[ M00 M01 M02 ]
[ M10 M11 M12 ]
```

`Output_Size.Width` and `Output_Size.Height` must both be nonzero. Destination
is always rebound to:

```text
Rows     = Output_Size.Height
Columns  = Output_Size.Width
Depth    = Source.Depth
Channels = Source.Channels
```

No color conversion occurs. Destination geometry is the requested size, not
inferred from Source.

Supported interpolation:

```text
Nearest_Neighbor
Linear
```

`Cubic`, `Area`, and `Lanczos_4` are rejected. Resize still accepts all five
interpolation methods.

Supported borders:

```text
Constant_Border
Replicate
```

`Reflect`, `Reflect_101`, and `Wrap` are rejected. For `Constant_Border`, C1
uses `Component_0`, C2 uses components 0..1, C3 uses 0..2, and C4 uses 0..3.
For `Replicate`, `Border_Value` is ignored.

Mapping:

- `Source_To_Destination` is the usual forward mapping (native call does not
  set `WARP_INVERSE_MAP`);
- `Destination_To_Source` treats `Transform` as already inverted.

Source and Transform are read-only and may share storage. Destination must
not share storage with Source or Transform.

Example: one-pixel right translation using a Float64 2x3 matrix:

```ada
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Image_Processing;

procedure Translate_Example is
   Source      : OpenCV.Core.Mat :=
     OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
   Transform   : OpenCV.Core.Mat :=
     OpenCV.Core.Create (2, 3, (OpenCV.Core.Float64, 1));
   Destination : OpenCV.Core.Mat;
begin
   OpenCV.Core.Float64_Access.Set (Transform, 0, 0, 1.0);
   OpenCV.Core.Float64_Access.Set (Transform, 0, 1, 0.0);
   OpenCV.Core.Float64_Access.Set (Transform, 0, 2, 1.0);
   OpenCV.Core.Float64_Access.Set (Transform, 1, 0, 0.0);
   OpenCV.Core.Float64_Access.Set (Transform, 1, 1, 1.0);
   OpenCV.Core.Float64_Access.Set (Transform, 1, 2, 0.0);

   OpenCV.Image_Processing.Warp_Affine
     (Source,
      Transform,
      Destination,
      (Width => 3, Height => 3),
      OpenCV.Image_Processing.Nearest_Neighbor);
end Translate_Example;
```

Perspective warping is bound separately as `Warp_Perspective`.

---

## Perspective warping

Mapping direction is shared with affine warping:

```ada
type Warp_Mapping_Direction is
  (Source_To_Destination, Destination_To_Source);

subtype Affine_Mapping_Direction is Warp_Mapping_Direction;
```

API:

```ada
procedure Warp_Perspective
  (Source        : OpenCV.Core.Mat;
   Transform     : OpenCV.Core.Mat;
   Destination   : in out OpenCV.Core.Mat;
   Output_Size   : OpenCV.Size;
   Interpolation : Interpolation_Method := Linear;
   Mapping       : Warp_Mapping_Direction := Source_To_Destination;
   Border        : OpenCV.Border_Kind :=
                     OpenCV.Constant_Border;
   Border_Value  : OpenCV.Scalar := (others => 0.0));
```

`Warp_Perspective` applies a 3x3 projective `Transform` to `Source` and writes
the warped image to `Destination`. Callers construct the matrix with ordinary
Core typed Mat accessors; transform-construction helpers are not bound.

Supported Source:

- nonempty two-dimensional Mat;
- depth `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`;
- 1 to 4 channels.

Transform requirements:

```text
Rows     = 3
Columns  = 3
Channels = 1
Depth    = Float32 or Float64
```

Coefficients are:

```text
[ M00 M01 M02 ]
[ M10 M11 M12 ]
[ M20 M21 M22 ]
```

With `Destination_To_Source`, OpenCV evaluates conceptually:

```text
source_x = (M00*x + M01*y + M02) / (M20*x + M21*y + M22)
source_y = (M10*x + M11*y + M12) / (M20*x + M21*y + M22)
```

`Output_Size.Width` and `Output_Size.Height` must both be nonzero. Destination
is always rebound to:

```text
Rows     = Output_Size.Height
Columns  = Output_Size.Width
Depth    = Source.Depth
Channels = Source.Channels
```

No color conversion occurs. Destination geometry is the requested size, not
inferred from Source.

Supported interpolation:

```text
Nearest_Neighbor
Linear
```

`Cubic`, `Area`, and `Lanczos_4` are rejected. Resize still accepts all five
interpolation methods.

Supported borders:

```text
Constant_Border
Replicate
```

`Reflect`, `Reflect_101`, and `Wrap` are rejected. For `Constant_Border`, C1
uses `Component_0`, C2 uses components 0..1, C3 uses 0..2, and C4 uses 0..3.
For `Replicate`, `Border_Value` is ignored.

Mapping:

- `Source_To_Destination` is the usual forward mapping (native call does not
  set `WARP_INVERSE_MAP`);
- `Destination_To_Source` treats `Transform` as already inverted.

Source and Transform are read-only and may share storage. Destination must
not share storage with Source or Transform. Direct in-place operation is not
supported. Singular or poorly conditioned matrices are not rejected merely
for being singular; all nine coefficients must be finite.

Example: one-pixel right translation using a Float64 3x3 matrix:

```ada
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Image_Processing;

procedure Translate_Perspective_Example is
   Source      : OpenCV.Core.Mat :=
     OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
   Transform   : OpenCV.Core.Mat :=
     OpenCV.Core.Create (3, 3, (OpenCV.Core.Float64, 1));
   Destination : OpenCV.Core.Mat;
begin
   OpenCV.Core.Float64_Access.Set (Transform, 0, 0, 1.0);
   OpenCV.Core.Float64_Access.Set (Transform, 0, 1, 0.0);
   OpenCV.Core.Float64_Access.Set (Transform, 0, 2, 1.0);
   OpenCV.Core.Float64_Access.Set (Transform, 1, 0, 0.0);
   OpenCV.Core.Float64_Access.Set (Transform, 1, 1, 1.0);
   OpenCV.Core.Float64_Access.Set (Transform, 1, 2, 0.0);
   OpenCV.Core.Float64_Access.Set (Transform, 2, 0, 0.0);
   OpenCV.Core.Float64_Access.Set (Transform, 2, 1, 0.0);
   OpenCV.Core.Float64_Access.Set (Transform, 2, 2, 1.0);

   OpenCV.Image_Processing.Warp_Perspective
     (Source,
      Transform,
      Destination,
      (Width => 3, Height => 3),
      OpenCV.Image_Processing.Nearest_Neighbor);
end Translate_Perspective_Example;
```

---

## Polar transforms

`Warp_Polar` binds `cv::warpPolar` for both linear and logarithmic polar images:

```ada
procedure Warp_Polar
  (Source         : OpenCV.Core.Mat;
   Destination    : in out OpenCV.Core.Mat;
   Center         : OpenCV.Float32_Point;
   Maximum_Radius : OpenCV.Float64_Value;
   Output_Size    : OpenCV.Size;
   Mapping        : Polar_Mapping := Linear_Polar;
   Direction      : Polar_Direction := Cartesian_To_Polar;
   Interpolation  : Interpolation_Method := Linear);
```

Forward output X is radial rho and Y is angular phi (one full revolution).
Linear rho follows distance from `Center`; logarithmic rho follows
`log(distance + 1)`. `Center` is local to the supplied Source view in forward
mode, but refers to the requested Cartesian output in inverse mode. In inverse
mode Source is the polar image. `Maximum_Radius` must be finite and > 0 for
linear, > 1 for logarithmic mapping; the actual radial scale must also remain
finite and strictly positive. The Float32 center coordinates must be finite;
off-image centers are allowed within the generated-map arithmetic limits.

Both `Output_Size` dimensions must be explicitly positive and < 32767. Source
rows and columns must be < 32767; inverse Source rows must be **at most
32764** because OpenCV adds one wrap row at each end before `remap`. The
generated Float32 coordinates are preflighted against native remap rounding
limits. Nearest_Neighbor, Linear, Cubic, and Lanczos_4 are available; Area is
rejected. Inverse logarithmic maps with both a sub-0.0001-pixel maximum output distance
and a radial scale below 0.000001 are conservatively rejected: Float32
`magnitude + 1.f` quantization can overflow remap's coordinate rounding.
Otherwise, out-of-source samples are zero-filled. Source is unchanged;
Destination must not overlap it (including aliases and Regions). On success
Destination is rebound to a fresh Mat with the requested size and Source's
depth/channels; validation or native failure leaves it unchanged. Interpolation
and Float32 map quantization mean forward/inverse round trips are not exact.

```ada
Warp_Polar
  (Source         => Frame,
   Destination    => Polar_Image,
   Center         => (X => 120.0, Y => 90.0),
   Maximum_Radius => 80.0,
   Output_Size    => (Width => 160, Height => 256),
   Mapping        => Logarithmic_Polar);

Warp_Polar
  (Source         => Polar_Image,
   Destination    => Reconstructed,
   Center         => (X => 120.0, Y => 90.0),
   Maximum_Radius => 80.0,
   Output_Size    => (Width => 240, Height => 180),
   Mapping        => Logarithmic_Polar,
   Direction      => Polar_To_Cartesian);
```

## Remapping

API:

```ada
procedure Remap
  (Source        : OpenCV.Core.Mat;
   Map_X         : OpenCV.Core.Mat;
   Map_Y         : OpenCV.Core.Mat;
   Destination   : in out OpenCV.Core.Mat;
   Interpolation : Interpolation_Method := Linear;
   Border        : OpenCV.Border_Kind :=
                     OpenCV.Constant_Border;
   Border_Value  : OpenCV.Scalar := (others => 0.0));

procedure Remap
  (Source        : OpenCV.Core.Mat;
   Map_XY        : OpenCV.Core.Mat;
   Destination   : in out OpenCV.Core.Mat;
   Interpolation : Interpolation_Method := Linear;
   Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
   Border_Value  : OpenCV.Scalar := (others => 0.0));

procedure Remap
  (Source        : OpenCV.Core.Mat;
   Maps          : Fixed_Remap_Maps;
   Destination   : in out OpenCV.Core.Mat;
   Interpolation : Interpolation_Method := Linear;
   Border        : OpenCV.Border_Kind := OpenCV.Constant_Border;
   Border_Value  : OpenCV.Scalar := (others => 0.0));
```

`Remap` applies an absolute source-coordinate map. Destination `(Row,
Column)` samples Source at:

```text
X = Map_X(Row, Column)   -- source column
Y = Map_Y(Row, Column)   -- source row
```

Conceptually `dst(x, y) = src(map_x(x, y), map_y(x, y))`. Relative maps
and `WARP_RELATIVE_MAP` are not bound.

Supported Source:

- nonempty two-dimensional Mat;
- depth `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`;
- 1 to 4 channels;
- Rows and Columns less than 32767.

Map requirements:

```text
nonempty 2-D
Channels = 1
Depth    = Float32
Map_X and Map_Y have identical Rows/Columns
Rows and Columns < 32767
all coordinates finite and safely convertible to native integer coordinates
```

Map geometry does not need to match Source. Destination is always rebound
to:

```text
Rows     = Map_X.Rows
Columns  = Map_X.Columns
Depth    = Source.Depth
Channels = Source.Channels
```

Coordinates may lie outside Source; the selected border mode fills those
samples. NaN and +/-Infinity map values are rejected. Extremely large finite
Float32 coordinates can also be rejected: native Remap rounds coordinates into
signed integer/Int16 coordinate tables, and non-nearest interpolation first
multiplies them by the interpolation-table scale (32) in Float32. Ordinary
out-of-image coordinates, such as -1 or a few pixels beyond the source, remain
legal. For eligible separate Float32 C1+C1 map operations, OpenCV 4.x may use
IPP, which narrows source, map, and output byte strides to `int`; those paths
also check the actual byte strides before invoking native Remap.
The UInt8 C1/C3/C4 Linear SIMD path separately narrows the source row stride:
the binding rejects strides above `INT_MAX` before narrowing and the exact
32768-byte boundary admitted by OpenCV 4.1's unsafe SIMD shift. Larger
representable strides remain eligible for the scalar fallback.

Supported interpolation:

```text
Nearest_Neighbor
Linear
Cubic
Lanczos_4
```

`Area` is rejected. Resize still accepts all five interpolation methods.

Supported borders:

```text
Constant_Border
Replicate
Reflect
Reflect_101
Wrap
```

For `Constant_Border`, C1 uses `Component_0`, C2 uses components 0..1, C3
uses 0..2, and C4 uses 0..3. For other borders, `Border_Value` is ignored.
`BORDER_TRANSPARENT` is not bound.

Source, Map_X, and Map_Y are read-only and may share storage. Destination
must not share storage with Source or either map. Direct in-place
operation is not supported.
Destination is rebound only after native Remap succeeds; rejected operations
leave its previous contents intact.

The following absolute map representations are available:

| Representation | Primary map | Secondary map | Intended use |
| --- | --- | --- | --- |
| Separate Float | Float32 C1 X | Float32 C1 Y | simple/editable |
| Interleaved Float | Float32 C2 XY | none | compact Float map |
| Fixed interpolated | Int16 C2 | UInt16 C1 | reusable interpolation map |
| Fixed nearest-only | Int16 C2 | none | nearest only |

All maps contain **absolute** source coordinates. C2 component 0 is X (source
column), component 1 is Y (source row). All map dimensions must be less than
32767. The existing finite/roundable Float32 coordinate checks apply to C2
Remap and Float-to-fixed conversion, and the UInt8 Linear SIMD source-stride
guard also applies to C2 and fixed Remap. IPP's separate-C1+C1-map stride
checks do not apply to the other two representations.

`Fixed_Remap_Maps` is private: its Int16 C2 coordinates and optional UInt16 C1
coefficients cannot be independently mutated. `Float_Remap_Maps` returns fresh
owning separate Float32 C1 Mats. Convert a map once and reuse it with multiple
frames; fixed conversion is lossy. Interpolated coordinates are quantized to
OpenCV's 32-step interpolation table (approximately 1/32 pixel resolution on
reverse conversion); nearest-only maps discard fractions permanently. Extreme
coordinates can also saturate in the fixed Int16 representation. Nearest-only
fixed maps accept only `Nearest_Neighbor`; coefficient-bearing maps accept
Nearest, Linear, Cubic, and Lanczos_4. `Area` remains unsupported. Reverse
nearest-only conversion returns the already-rounded coordinates as Float32.
Conversion and Remap failures leave caller-visible outputs unchanged. Relative
`WARP_RELATIVE_MAP` remains deferred.

```ada
--  Map_X and Map_Y are Float32 C1; Map_XY is Float32 C2 (X then Y).
Remap (Source, Map_XY, Destination, Linear);

Fixed := Convert_Remap_To_Fixed
  (Map_X, Map_Y, Nearest_Neighbor_Only => False);
Remap (Frame, Fixed, Output, Linear);
Remap (Next_Frame, Fixed, Next_Output, Linear);

Fixed := Convert_Remap_To_Fixed
  (Map_XY, Nearest_Neighbor_Only => True);
Remap (Frame, Fixed, Output, Nearest_Neighbor);

Map_XY := Interleave_Remap_Maps (Map_X, Map_Y);
Separate := Separate_Remap_Map (Map_XY);
Restored_XY := Convert_Remap_To_Interleaved_Float (Fixed);
Restored_Separate := Convert_Remap_To_Separate_Float (Fixed);
```

Example: identity remap of a 2x3 UInt8 image:

```ada
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Image_Processing;

procedure Identity_Remap_Example is
   Source      : OpenCV.Core.Mat :=
     OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
   Map_X       : OpenCV.Core.Mat :=
     OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));
   Map_Y       : OpenCV.Core.Mat :=
     OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));
   Destination : OpenCV.Core.Mat;
begin
   OpenCV.Core.Float32_Access.Set (Map_X, 0, 0, 0.0);
   OpenCV.Core.Float32_Access.Set (Map_X, 0, 1, 1.0);
   OpenCV.Core.Float32_Access.Set (Map_X, 0, 2, 2.0);
   OpenCV.Core.Float32_Access.Set (Map_X, 1, 0, 0.0);
   OpenCV.Core.Float32_Access.Set (Map_X, 1, 1, 1.0);
   OpenCV.Core.Float32_Access.Set (Map_X, 1, 2, 2.0);
   OpenCV.Core.Float32_Access.Set (Map_Y, 0, 0, 0.0);
   OpenCV.Core.Float32_Access.Set (Map_Y, 0, 1, 0.0);
   OpenCV.Core.Float32_Access.Set (Map_Y, 0, 2, 0.0);
   OpenCV.Core.Float32_Access.Set (Map_Y, 1, 0, 1.0);
   OpenCV.Core.Float32_Access.Set (Map_Y, 1, 1, 1.0);
   OpenCV.Core.Float32_Access.Set (Map_Y, 1, 2, 1.0);

   OpenCV.Image_Processing.Remap
     (Source,
      Map_X,
      Map_Y,
      Destination,
      OpenCV.Image_Processing.Nearest_Neighbor);
end Identity_Remap_Example;
```

---

## Median blur


API:

```ada
subtype Median_Kernel_Size is
  Positive range 3 .. 2_147_483_647;

procedure Median_Blur
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Kernel_Size : Median_Kernel_Size);
```

`Median_Blur` replaces each pixel with the median of its square aperture.
Channels are processed independently. Destination receives Source's rows,
columns, depth, and channel count.

Requirements:

- source is nonempty and two-dimensional;
- source has 1, 3, or 4 channels;
- `Kernel_Size` is odd and at least 3.

Supported depths:

```text
Kernel 3 or 5:
  UInt8
  UInt16
  Float32

Kernel > 5:
  UInt8 only
```

OpenCV uses `BORDER_REPLICATE` internally. There is no public Border parameter.

Direct in-place operation is supported:

```ada
Median_Blur (Image, Image, 3);
```

When Source and Destination are distinct, Source remains unchanged.

---

## Box blur

API:

```ada
procedure Box_Blur
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Kernel_Size : OpenCV.Size;
   Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);
```

`Box_Blur` replaces each pixel with the normalized average of its
`Kernel_Size` neighborhood. Every kernel coefficient is
`1 / (Width * Height)`. Channels are processed independently and are not
restricted. Destination receives Source's rows, columns, depth, and channel
count.

Requirements:

- source is nonempty and two-dimensional;
- depth is one of the supported general Imgproc numeric depths;
- kernel width and height are positive.

Kernel dimensions need not be odd or equal. Even and non-square kernels such
as `(Width => 2, Height => 4)` are valid. The kernel uses OpenCV's centered
default anchor; no public Anchor parameter is exposed.

Supported borders:

```text
Constant_Border
Replicate
Reflect
Reflect_101
```

`Wrap` is rejected.

Direct in-place operation is supported:

```ada
Box_Blur
  (Source      => Image,
   Destination => Image,
   Kernel_Size => (Width => 3, Height => 3));
```

When Source and Destination are distinct, Source remains unchanged.

---

## Bilateral filter

API:

```ada
subtype Bilateral_Diameter is
  Positive range 1 .. 2_147_483_647;

procedure Bilateral_Filter
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Sigma_Color : OpenCV.Float64_Value;
   Sigma_Space : OpenCV.Float64_Value;
   Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);

procedure Bilateral_Filter
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Diameter    : Bilateral_Diameter;
   Sigma_Color : OpenCV.Float64_Value;
   Sigma_Space : OpenCV.Float64_Value;
   Border      : OpenCV.Border_Kind := OpenCV.Reflect_101);
```

`Bilateral_Filter` is an edge-preserving smoother. Each output pixel is a
weighted average of its neighborhood, combining:

- `Sigma_Space`, which controls similarity in spatial coordinates; and
- `Sigma_Color`, which controls similarity in intensity or color.

A small `Sigma_Color` preserves strong discontinuities more than a large one.
Channels are not filtered independently for C3 sources; color-distance
weighting uses the combined color difference.

The overload without `Diameter` asks OpenCV to derive the neighborhood size
from `Sigma_Space`. The overload with `Diameter` supplies a positive integer
neighborhood size; it need not be odd. There is no public zero or negative
diameter sentinel.

Requirements:

- source is nonempty and two-dimensional;
- depth is `UInt8` or `Float32`;
- channel count is 1 or 3;
- `Sigma_Color` and `Sigma_Space` are positive and finite.

Supported borders:

```text
Constant_Border
Replicate
Reflect
Reflect_101
```

`Wrap` is rejected.

Destination receives Source's rows, columns, depth, and channel count. Direct
in-place operation is not supported:

```ada
--  raises OpenCV.OpenCV_Error
Bilateral_Filter (Image, Image, 5, 25.0, 25.0);
```

When Destination is distinct, Source remains unchanged.

---

## Mean-shift filtering

API:

```ada
subtype Mean_Shift_Pyramid_Level is Natural range 0 .. 8;

subtype Mean_Shift_Iteration_Limit is Positive range 1 .. 100;

type Mean_Shift_Termination is record
   Maximum_Iterations : Mean_Shift_Iteration_Limit := 5;
   Epsilon            : OpenCV.Float64_Value := 1.0;
end record;

procedure Pyramid_Mean_Shift_Filter
  (Source                : OpenCV.Core.Mat;
   Destination           : in out OpenCV.Core.Mat;
   Spatial_Radius        : OpenCV.Float64_Value;
   Color_Radius          : OpenCV.Float64_Value;
   Maximum_Pyramid_Level : Mean_Shift_Pyramid_Level := 1;
   Termination           : Mean_Shift_Termination :=
     (Maximum_Iterations => 5, Epsilon => 1.0));
```

`Pyramid_Mean_Shift_Filter` binds `cv::pyrMeanShiftFiltering`: the
**filtering / posterization** stage of mean-shift segmentation. Every pixel is
moved in joint (x, y, R, G, B) space to the mean of the pixels within
`Spatial_Radius` spatially and `Color_Radius` in RGB distance, repeatedly,
and receives the color at which that process converges. Fine texture is
flattened while strong color edges survive. The result is a filtered
UInt8 C3 image; it is **not** a region-label map. Connected-region labeling
of the posterized result is a separate step.

Requirements:

- Source is nonempty, two-dimensional, `UInt8`, and exactly 3 channels;
- `Spatial_Radius` is finite and strictly positive (OpenCV additionally
  raises each pyramid level's effective radius to at least 1);
- `Color_Radius` is finite and nonnegative; `0` admits only identical
  colors into each neighborhood;
- `Termination.Maximum_Iterations` is `1 .. 100`, and `Termination.Epsilon`
  is finite and nonnegative.

Termination always enables both OpenCV criteria (`MAX_ITER | EPS`). The
default is 5 iterations / epsilon 1, matching OpenCV's own default. No native
flag or clamping behavior is exposed or relied upon.

### Pyramid levels

`Maximum_Pyramid_Level = 0` filters Source directly. For `N > 0`, OpenCV
builds a natural Gaussian pyramid of `N` further ceil-half levels, filters the
top level with `Spatial_Radius / 2 ** N`, and propagates each result down with
`pyrUp`, refining only pixels near color changes. Pyramid processing is
faster for large radii but can produce **different results** from level-0
filtering.

Portable restriction: every generated level `1 .. N` must remain at least
`2 x 2`. OpenCV's propagation step forms a pointer one row past the start of
each smaller level before checking its loop bounds, and advances through an
interior loop whose arithmetic is invalid for one-row or one-column levels.
Such requests are rejected; the level is never silently reduced. For example,
a `2 x 2` Source at level 1 (child `1 x 1`) or a `40 x 3` Source at level 2
(child `10 x 1`) is rejected, while the same Sources succeed at level 0 or 1
respectively.

### Source, Regions, and Destination

The operation snapshots Source into a private packed clone before filtering:

- Source is never modified;
- a Region is a complete logical image; parent pixels outside it never
  influence pyramid construction, filtering, or propagation;
- Destination is computed into fresh storage and rebound **only on
  success**; on any failure it keeps its previous header and data;
- Destination may be Source itself, or a view overlapping Source, and still
  produces the same result as a distinct Destination.

### Native arithmetic safety

OpenCV evaluates `cvRound(sr * sr)`, `cvRound(x0 +/- sp)`, signed-int row
offsets, signed-int window accumulators (`count`, color sums, and the
coordinate sums `sx` / `sy`), and a signed-int stopping expression without
overflow checks. Before native execution the binding validates the whole
requested pyramid with widened arithmetic and rejects requests whose values
could overflow. In particular, a very wide window can overflow the
coordinate sum even on a small image: a `1 x 100_000` Source with a
spatial radius spanning the row is rejected. Every `pyrDown` / `pyrUp`
transition reuses the same checks as `Pyramid_Down` / `Pyramid_Up`.

```ada
Posterized : Mat;
...
Pyramid_Mean_Shift_Filter
  (Photo, Posterized, Spatial_Radius => 12.0, Color_Radius => 30.0,
   Maximum_Pyramid_Level => 2);
```

---

## Filter 2D

API:

```ada
subtype Filter_Depth is Derivative_Depth;

procedure Filter_2D
  (Source            : OpenCV.Core.Mat;
   Destination       : in out OpenCV.Core.Mat;
   Kernel            : OpenCV.Core.Mat;
   Destination_Depth : Filter_Depth := Same_Depth;
   Offset            : OpenCV.Float64_Value := 0.0;
   Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

procedure Filter_2D
  (Source            : OpenCV.Core.Mat;
   Destination       : in out OpenCV.Core.Mat;
   Kernel            : OpenCV.Core.Mat;
   Anchor            : OpenCV.Point;
   Destination_Depth : Filter_Depth := Same_Depth;
   Offset            : OpenCV.Float64_Value := 0.0;
   Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);
```

`Filter_2D` applies a custom linear kernel to every Source channel. This is
**correlation, not mathematical convolution**: the kernel is not mirrored around
the anchor.

```text
dst(x,y) =
  sum kernel(x',y') * src(x + x' - anchor.x, y + y' - anchor.y)
  + Offset
```

The overload without `Anchor` uses OpenCV's centered default. The overload with
`Anchor` requires a real kernel position inside Kernel. There is no public
`(-1, -1)` sentinel.

Kernel requirements:

- nonempty and two-dimensional;
- exactly one channel;
- depth `Float32` or `Float64`.

Kernel dimensions need not be odd, square, or normalized. Examples such as
`1x1`, `1x3`, `2x3`, and `4x2` are valid.

Source depths:

```text
UInt8
UInt16
Int16
Float32
Float64
```

Channel count is unrestricted. The same single-channel kernel is applied
independently to every Source channel.

Destination-depth matrix:

| Source | Supported `Destination_Depth` |
| --- | --- |
| `UInt8` | `Same_Depth`, `Int16_Depth`, `Float32_Depth`, `Float64_Depth` |
| `UInt16` | `Same_Depth`, `Float32_Depth`, `Float64_Depth` |
| `Int16` | `Same_Depth`, `Float32_Depth`, `Float64_Depth` |
| `Float32` | `Same_Depth`, `Float32_Depth` |
| `Float64` | `Same_Depth`, `Float64_Depth` |

`Offset` is added to each filtered value. It must be finite and may be
positive, zero, or negative.

Supported borders:

```text
Constant_Border
Replicate
Reflect
Reflect_101
```

`Wrap` is rejected.

Direct Same_Depth in-place operation is supported:

```ada
Filter_2D
  (Source            => Image,
   Destination       => Image,
   Kernel            => Kernel,
   Destination_Depth => Same_Depth);
```

A depth-changing source/destination alias is rejected.

When Destination is distinct, Source remains unchanged.

---

## Sep Filter 2D

API:

```ada
procedure Sep_Filter_2D
  (Source            : OpenCV.Core.Mat;
   Destination       : in out OpenCV.Core.Mat;
   Kernel_X          : OpenCV.Core.Mat;
   Kernel_Y          : OpenCV.Core.Mat;
   Destination_Depth : Filter_Depth := Same_Depth;
   Offset            : OpenCV.Float64_Value := 0.0;
   Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);

procedure Sep_Filter_2D
  (Source            : OpenCV.Core.Mat;
   Destination       : in out OpenCV.Core.Mat;
   Kernel_X          : OpenCV.Core.Mat;
   Kernel_Y          : OpenCV.Core.Mat;
   Anchor            : OpenCV.Point;
   Destination_Depth : Filter_Depth := Same_Depth;
   Offset            : OpenCV.Float64_Value := 0.0;
   Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);
```

`Sep_Filter_2D` applies a separable linear filter. Every Source row is filtered
with `Kernel_X`, then every intermediate column is filtered with `Kernel_Y`, and
`Offset` is added to the final value. Coefficient order is preserved; neither
kernel is flipped.

The overload without `Anchor` uses OpenCV's centered default. The overload with
`Anchor` requires a real position: `Anchor.X` indexes `Kernel_X` and `Anchor.Y`
indexes `Kernel_Y` by each kernel's logical length. There is no public
`(-1, -1)` sentinel.

Kernel requirements:

- nonempty and two-dimensional;
- exactly one channel;
- depth `Float32` or `Float64`;
- a vector: one row or one column;
- `Kernel_X` and `Kernel_Y` must share the same floating-point depth.

Kernel lengths need not be odd, equal, normalized, or symmetric. Examples such
as `1x1`, `1x3`, `3x1`, `1x4`, and `4x1` are valid. A genuine 2-D matrix such as
`2x2` is rejected. Mixed Float32/Float64 kernel pairs are rejected because
native OpenCV 4 and OpenCV 5 require `kernelX.type() == kernelY.type()`.

Source depths:

```text
UInt8
UInt16
Int16
Float32
Float64
```

Channel count is unrestricted. The same Kernel_X/Kernel_Y pair is applied
independently to every Source channel.

Destination-depth matrix:

| Source | Supported `Destination_Depth` |
| --- | --- |
| `UInt8` | `Same_Depth`, `Int16_Depth`, `Float32_Depth`, `Float64_Depth` |
| `UInt16` | `Same_Depth`, `Float32_Depth`, `Float64_Depth` |
| `Int16` | `Same_Depth`, `Float32_Depth`, `Float64_Depth` |
| `Float32` | `Same_Depth`, `Float32_Depth` |
| `Float64` | `Same_Depth`, `Float64_Depth` |

`Offset` is added to each filtered value. It must be finite and may be
positive, zero, or negative.

Supported borders:

```text
Constant_Border
Replicate
Reflect
Reflect_101
```

`Wrap` is rejected.

Direct Same_Depth in-place operation is supported:

```ada
Sep_Filter_2D
  (Source            => Image,
   Destination       => Image,
   Kernel_X          => Kernel_X,
   Kernel_Y          => Kernel_Y,
   Destination_Depth => Same_Depth);
```

A depth-changing source/destination alias is rejected. Kernel_X and Kernel_Y
may share storage with each other, but neither may alias Destination.

When Destination is distinct, Source remains unchanged.

---

## Morphology

Structuring-element shapes:

```ada
type Morphology_Shape is (Rectangle, Cross, Ellipse);
```

Higher-level operations:

```ada
type Morphology_Operation is
  (Opening, Closing, Gradient, Top_Hat, Black_Hat);
```

Iteration count:

```ada
subtype Morphology_Iterations is Positive range 1 .. 2_147_483_647;
```

Basic operations:

```ada
procedure Erode
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Kernel_Size : OpenCV.Size;
   Shape       : Morphology_Shape := Rectangle;
   Iterations  : Morphology_Iterations := 1;
   Border      : OpenCV.Border_Kind := OpenCV.Constant_Border);

procedure Dilate
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Kernel_Size : OpenCV.Size;
   Shape       : Morphology_Shape := Rectangle;
   Iterations  : Morphology_Iterations := 1;
   Border      : OpenCV.Border_Kind := OpenCV.Constant_Border);
```

Combined morphology:

```ada
procedure Apply_Morphology
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Operation   : Morphology_Operation;
   Kernel_Size : OpenCV.Size;
   Shape       : Morphology_Shape := Rectangle;
   Iterations  : Morphology_Iterations := 1;
   Border      : OpenCV.Border_Kind := OpenCV.Constant_Border);
```

Behavior:

- source must be nonempty and two-dimensional;
- `UInt8`, `UInt16`, `Int16`, `Float32`, and `Float64` are supported;
- channels are processed independently;
- kernel dimensions must be positive but **do not need to be odd**;
- iterations must be positive;
- `Constant_Border`, `Replicate`, `Reflect`, and `Reflect_101` are supported;
- `Wrap` is rejected;
- constant-border morphology uses OpenCV's morphology default border value;
- direct in-place operation is supported, including a parent-backed Region;
- a Source Region is processed as its own logical image: pixels in its parent
  outside the view do not participate. A distinct Destination is rebound to the
  Region's geometry and type; in-place operation changes only the Region's
  pixels, not the rest of its parent.

The same `Erode`, `Dilate`, and `Apply_Morphology` procedures also accept a
custom `Kernel : OpenCV.Core.Mat` in place of `Kernel_Size`. Custom kernels
must be nonempty 2-D `UInt8` C1 masks, including even-sized, non-square and
non-contiguous Region views. Zero excludes a pixel; **any nonzero value**
(including 255) includes it, without weighting. All-zero kernels are rejected.
The logical kernel Region alone participates. Kernel and Destination must not
address overlapping bytes; Source and Destination may be the same Mat, even a
parent-backed Region. All paths isolate the Source Region from its parent.

Both generated and custom overloads accept an optional **explicit-anchor
overload** with `Anchor : OpenCV.Point`, following `Shape` for generated
kernels and `Kernel` for custom kernels. The centered overload remains the
default. An explicit anchor must lie inside the kernel (including (0,0) or
the bottom-right pixel). Rectangle and Ellipse mask geometry does not depend
on the anchor; a generated **Cross mask does**: its intersection is placed at
the explicit anchor, which is also passed to morphology.

```ada
Erode (Source, Destination, Kernel_Size => (3, 3));
Dilate (Source, Destination, (3, 3), Cross, (X => 0, Y => 1));
--  Fill a UInt8 C1 Mat Mask with zeros, then set only included positions.
OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 1);
OpenCV.Core.UInt8_Access.Set (Mask, 1, 0, 255);
OpenCV.Core.UInt8_Access.Set (Mask, 1, 1, 1);
Erode (Source, Destination, Kernel => Mask);
Dilate
  (Source, Destination, Kernel => Mask,
   Border_Value => Explicit_Morphology_Border
     ((Component_0 => 255.0, Component_1 => 0.0,
       Component_2 => 0.0, Component_3 => 0.0)));
```

`Border_Value` defaults to `Default_Morphology_Border`, OpenCV's special
neutral border (maximum for erosion, minimum for dilation), **not zero**.
`Explicit_Morphology_Border (Scalar)` selects an ordinary constant border;
it is ignored unless `Border = Constant_Border`. For C1..C4, scalar components
0..channels-1 map to the corresponding channels. For more than four channels,
explicit borders must have all four components equal (uniform value); the
default remains valid. Used components must be finite, and Float32 sources
also require used values within the finite Float32 range. Integer explicit
borders retain OpenCV's saturating behavior (for example, UInt8 300 becomes
255), not wraparound, but each used component must first lie within the
signed-int range [-2_147_483_648, 2_147_483_647] used by OpenCV's
`scalarToRawData` rounding step. Huge finite values outside that range are
rejected even though they would eventually saturate to the pixel range. The
scalar with all four components equal to `Float64_Value'Last` (native
`DBL_MAX`) is reserved by OpenCV as the default sentinel and cannot be
selected explicitly.

For safety, kernel area, source width times channels, and kernel width times
channels must fit signed 32-bit int. Fully nonzero masks with multiple
iterations must also fit OpenCV's expanded rectangle and anchor arithmetic;
sparse masks retain the full positive iteration domain. A 1x1 mask follows
OpenCV's early copy/no-op even for very large iteration counts. An Ellipse's
generated height is limited to 92681 by OpenCV's signed radius arithmetic.
Opening with two iterations runs two erosions followed by two dilations, not
two alternating erode/dilate pairs. OpenCV 5-only Diamond remains deferred.

### Hit-or-Miss binary pattern queries

Hit-or-Miss is a **separate operation**, not a `Morphology_Operation` value.
Generated Rectangle/Cross/Ellipse masks retain their existing general
morphology domain and cannot select it.

```ada
procedure Hit_Or_Miss
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Kernel      : OpenCV.Core.Mat;
   Iterations  : Morphology_Iterations := 1;
   Border      : OpenCV.Border_Kind := OpenCV.Constant_Border);

procedure Hit_Or_Miss
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Kernel      : OpenCV.Core.Mat;
   Anchor      : OpenCV.Point;
   Iterations  : Morphology_Iterations := 1;
   Border      : OpenCV.Border_Kind := OpenCV.Constant_Border);
```

- Source is nonempty 2-D **UInt8 C1**, containing **exactly 0 (background)
  or 255 (foreground)**. Values such as 1, 127 and 254 raise `OpenCV_Error`;
  the binding never thresholds or normalizes the caller's pixels.
- Kernel is nonempty 2-D **Int8 C1**: **+1 requires foreground**, **-1
  requires background**, **0 is don't-care**. All other values reject.
  This is not the UInt8 zero/nonzero inclusion-mask contract of Erode/Dilate.
- All-don't-care/all-zero kernels deliberately reject as semantically empty
  queries, although native OpenCV copies Source for that case.
- Hit-only and miss-only kernels are supported. A 1x1 +1 kernel returns
  Source; a 1x1 -1 kernel returns its binary complement.
- The centered anchor is `(Kernel.Columns / 2, Kernel.Rows / 2)`, including
  even-sized/non-square kernels. Explicit anchors must be inside the kernel;
  no negative/native-center sentinel is exposed.
- Native `Iterations = N` erodes Source with the hit mask N times and its
  complement with the miss mask N times, then ANDs **once**. It does not
  repeatedly apply the complete Hit-or-Miss transform.
- `Constant_Border`, `Replicate`, `Reflect` and `Reflect_101` are supported;
  Wrap rejects. Constant uses `cv::morphologyDefaultBorderValue()`. Both
  erosion legs use the **same** native morphology border policy; no separately
  complemented external border is invented. No Border_Value overload exists.
- Source Regions are independent logical images through `BORDER_ISOLATED`.
  Source/kernel scans inspect only logical rows/columns with their actual
  step. Non-contiguous kernel Regions ignore the rest of their parent.
- Direct in-place operation, including a parent-backed Region, is supported
  and leaves parent pixels outside the Region unchanged. Distinct Source
  remains unchanged. Kernel/Destination storage overlap rejects.
- Destination has Source's rows/columns, UInt8 C1 type, and exactly **0/255**
  values: a binary match mask. Malformed public input raises `OpenCV_Error`
  before native execution or Destination publication.

Full-rectangle iteration overflow checks apply only to **all +1** or **all
-1** kernels. A mixed +/-1 kernel can have no zeros yet both derived native
erosion masks are sparse; it is not incorrectly subjected to full-mask
expansion limits. The existing morphology arithmetic/alias preflight is reused.

The public Ada layer owns semantic rejection. C++ inspection supplies facts;
the raw native entry point enforces ABI/memory safety and retains memory-safe
native behavior outside the public binary/ternary contract. This Mat-only API
does not enter OpenCL's UMat-destination dispatch. Exact 4.1.0/4.10.0/5.0.0
source review, vendor-path limitations and validation evidence are recorded in
[the pinned Hit-or-Miss review](docs/hit-or-miss-source-review.md).

This slice adds **25 focused AUnit tests** to the 812-test baseline:
**837 registered, 837 executed, 837 passed**, zero failed assertions and
unexpected errors locally on OpenCV 4.10.0. OpenCV 5-only Diamond, thinning,
pruning, reconstruction and binary conversion remain outside this slice.

---

## Canny edge detection

Types:

```ada
type Canny_Aperture is (Sobel_3x3, Sobel_5x5, Sobel_7x7);
type Canny_Gradient_Norm is (L1_Norm, L2_Norm);
```

API:

```ada
procedure Canny_Edges
  (Source          : OpenCV.Core.Mat;
   Destination     : in out OpenCV.Core.Mat;
   Lower_Threshold : OpenCV.Float64_Value;
   Upper_Threshold : OpenCV.Float64_Value;
   Aperture        : Canny_Aperture := Sobel_3x3;
   Gradient_Norm   : Canny_Gradient_Norm := L1_Norm);
```

Requirements:

- source is nonempty;
- source is two-dimensional;
- source is `UInt8` with exactly one channel;
- thresholds are finite and nonnegative;
- `Lower_Threshold <= Upper_Threshold`.

The result is a `UInt8` C1 image with the source geometry.

---

## Spatial derivatives

### Shared destination-depth model

```ada
type Derivative_Depth is
  (Same_Depth, Int16_Depth, Float32_Depth, Float64_Depth);
```

Supported source/destination combinations:

| Source depth | Supported destination depths |
| --- | --- |
| `UInt8` | same, `Int16`, `Float32`, `Float64` |
| `UInt16` | same, `Float32`, `Float64` |
| `Int16` | same, `Float32`, `Float64` |
| `Float32` | same / `Float32` |
| `Float64` | same / `Float64` |

Direct in-place operation is supported when `Destination_Depth = Same_Depth`.

`Scale` and `Offset` must be finite. `Offset` is the Ada-facing name for
OpenCV's derivative `delta` parameter; `delta` is an Ada reserved word.

Supported borders are `Constant_Border`, `Replicate`, `Reflect`, and
`Reflect_101`. `Wrap` is rejected.

### Sobel

```ada
type Sobel_Kernel_Size is
  (Kernel_1, Kernel_3, Kernel_5, Kernel_7);

subtype Derivative_Order is Natural range 0 .. 7;
```

API:

```ada
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
```

`X_Order` and `Y_Order` may not both be zero. Orders are checked against the
effective kernel size. `Kernel_1` preserves OpenCV's special one-dimensional
derivative behavior with an effective three-tap derivative kernel.

### Scharr

```ada
type Derivative_Axis is (X_Axis, Y_Axis);
```

API:

```ada
procedure Scharr
  (Source            : OpenCV.Core.Mat;
   Destination       : in out OpenCV.Core.Mat;
   Axis              : Derivative_Axis;
   Destination_Depth : Derivative_Depth := Float32_Depth;
   Scale             : OpenCV.Float64_Value := 1.0;
   Offset            : OpenCV.Float64_Value := 0.0;
   Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);
```

Scharr exposes first-derivative selection by axis instead of requiring callers
to supply raw `dx`/`dy` integer flags.

### Laplacian

```ada
type Laplacian_Kernel_Size is range 1 .. 31;
```

API:

```ada
procedure Laplacian
  (Source            : OpenCV.Core.Mat;
   Destination       : in out OpenCV.Core.Mat;
   Destination_Depth : Derivative_Depth := Float32_Depth;
   Kernel_Size       : Laplacian_Kernel_Size := 1;
   Scale             : OpenCV.Float64_Value := 1.0;
   Offset            : OpenCV.Float64_Value := 0.0;
   Border            : OpenCV.Border_Kind := OpenCV.Reflect_101);
```

The public numeric subtype admits `1 .. 31`; the implementation requires an odd
kernel size. Kernel size `1` uses OpenCV's dedicated 3x3 Laplacian aperture.

---

## Thresholding

### Fixed threshold

Modes:

```ada
type Threshold_Mode is
  (Binary, Binary_Inverse, Truncate, To_Zero, To_Zero_Inverse);
```

API:

```ada
procedure Apply_Threshold
  (Source          : OpenCV.Core.Mat;
   Destination     : in out OpenCV.Core.Mat;
   Threshold_Value : OpenCV.Float64_Value;
   Mode            : Threshold_Mode := Binary;
   Maximum_Value   : OpenCV.Float64_Value := 255.0);
```

Requirements:

- source is nonempty and two-dimensional;
- source depth is `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`;
- any channel count is accepted;
- threshold and maximum values are finite.

`Maximum_Value` affects `Binary` and `Binary_Inverse`; OpenCV ignores it for the
other fixed modes.

### Automatic threshold

Methods:

```ada
type Automatic_Threshold_Method is (Otsu, Triangle);
```

API:

```ada
procedure Apply_Automatic_Threshold
  (Source             : OpenCV.Core.Mat;
   Destination        : in out OpenCV.Core.Mat;
   Computed_Threshold : out OpenCV.Float64_Value;
   Method             : Automatic_Threshold_Method := Otsu;
   Mode               : Threshold_Mode := Binary;
   Maximum_Value      : OpenCV.Float64_Value := 255.0);
```

Input is single-channel.

| Method | Accepted depth |
| --- | --- |
| `Otsu` | `UInt8`, `UInt16` |
| `Triangle` | `UInt8` |

The threshold selected by OpenCV is returned in `Computed_Threshold`.

### Adaptive threshold

```ada
type Adaptive_Threshold_Method is (Mean, Gaussian);
type Adaptive_Threshold_Mode is (Binary, Binary_Inverse);

subtype Adaptive_Block_Size is
  Positive range 3 .. 2_147_483_647;
```

API:

```ada
procedure Apply_Adaptive_Threshold
  (Source        : OpenCV.Core.Mat;
   Destination   : in out OpenCV.Core.Mat;
   Block_Size    : Adaptive_Block_Size;
   Method        : Adaptive_Threshold_Method := Mean;
   Mode          : Adaptive_Threshold_Mode := Binary;
   Bias          : OpenCV.Float64_Value := 0.0;
   Maximum_Value : OpenCV.UInt8_Value := 255);
```

Requirements:

- nonempty 2-D `UInt8` C1 source;
- odd block size;
- finite bias.

`Bias` is passed directly as OpenCV's adaptive-threshold `C` parameter. Direct
in-place operation is supported.

---

## Histogram equalization

API:

```ada
procedure Equalize_Histogram
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat);
```

`Equalize_Histogram` performs OpenCV's global grayscale histogram equalization.
It computes the histogram of the supplied `UInt8` C1 view, builds a CDF lookup
table, and remaps intensities. There is no implicit conversion from color or
from another depth. Use `CLAHE` below for local contrast-limited equalization.

Requirements:

- source is nonempty and two-dimensional;
- source depth is `UInt8`;
- source has exactly one channel.

Destination may initially be empty or have a different size, depth, or channel
count. On success it receives Source's rows and columns with `UInt8` depth and
one channel.

Constant images retain their intensity. The histogram is computed over the
supplied Mat view, including a non-contiguous ROI, not over an enclosing parent
image outside that view.

Direct same-object in-place use is supported:

```ada
Equalize_Histogram (Image, Image);
```

When Source and Destination do not share storage, Source remains unchanged.
Other Source/Destination storage-sharing combinations are an Ada binding
restriction for this slice and are rejected before native writes. That includes
distinct shallow aliases and partially overlapping source and destination ROIs.
This is not a claim that OpenCV universally forbids every alias.

Public contract violations raise `OpenCV.OpenCV_Error` before Destination is
modified. Failures reported by OpenCV after Destination allocation or native
execution raise `OpenCV.OpenCV_Error` and do not roll back Destination.

---

## CLAHE

API:

```ada
procedure CLAHE
  (Source         : OpenCV.Core.Mat;
   Destination    : in out OpenCV.Core.Mat;
   Clip_Limit     : OpenCV.Float64_Value := 40.0;
   Tile_Grid_Size : OpenCV.Size := (Width => 8, Height => 8));
```

`CLAHE` is local Contrast Limited Adaptive Histogram Equalization. Unlike
`Equalize_Histogram`, which uses one global histogram, it divides the image
into `Tile_Grid_Size.Width` by `Tile_Grid_Size.Height` contextual regions and
interpolates their contrast-limited mappings. The default clip limit is `40.0`
and the default tile grid is `8 x 8`; the size describes tile *counts*, not
pixel dimensions. `Clip_Limit` must be finite and greater than zero.

Source must be nonempty, two-dimensional, single-channel `UInt8` or `UInt16`.
No color conversion, depth conversion, normalization, or scaling is implicit.
Output preserves Source geometry and depth. Tile dimensions need not divide the
image evenly; OpenCV uses Reflect_101 padding internally.

Destination may be empty or incompatible and is rebound on success. Direct
same-object in-place use, including a Mat ROI, is supported. Distinct Mats
whose storage overlaps (including shallow aliases or offset ROIs) are rejected
before native writes. When storage is independent, Source remains unchanged.

```ada
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure CLAHE_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (64, 64, (OpenCV.Core.UInt8, 1));
   Enhanced : OpenCV.Core.Mat;
begin
   OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 48);
   OpenCV.Image_Processing.CLAHE
     (Source, Enhanced, Clip_Limit => 4.0, Tile_Grid_Size => (8, 8));
end CLAHE_Example;
```

---

## Connected components

`Connected_Components_With_Stats` labels the connected foreground regions of a
binary `UInt8` C1 mask using OpenCV's `connectedComponentsWithStats`.

```ada
declare
   Mask       : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.UInt8, 1));
   Labels     : OpenCV.Core.Mat;
   Components : OpenCV.Image_Processing.Connected_Component_Set;
begin
   --  Set nonzero mask pixels as desired.
   OpenCV.Image_Processing.Connected_Components_With_Stats
     (Source       => Mask,
      Labels       => Labels,
      Components   => Components,
      Connectivity => OpenCV.Image_Processing.Eight_Connected);

   for Label in 1 .. OpenCV.Image_Processing.Component_Count (Components) loop
      declare
         Item : constant OpenCV.Image_Processing.Component_Statistics :=
           OpenCV.Image_Processing.Get_Component
             (Components, OpenCV.Image_Processing.Component_Label (Label));
      begin
         null; --  Use Item.Bounds, Item.Area, Item.Centroid_X, Item.Centroid_Y.
      end;
   end loop;
end;
```

Mask semantics are binary: zero is background and every nonzero `UInt8` value
is foreground. `Four_Connected` and `Eight_Connected` select 4-way and 8-way
pixel neighborhoods respectively. `Labels` is always rebound to a distinct
`Int32` C1 Mat with the same rows and columns as `Source`. Its value zero is
`Background_Label`; foreground pixels are labeled from 1 through
`Component_Count`.

`Connected_Component_Set` is Ada-owned and exposes foreground components only:
`Component_Count` excludes the background row. `Get_Component` accepts only a
foreground label and returns its `Bounds`, pixel `Area`, and `Float64`
`Centroid_X`/`Centroid_Y`. Foreground numbering has no guaranteed spatial
order. The operation is not in-place: `Source` and `Labels` must not share
storage, including shallow aliases and overlapping ROIs.

## Contour extraction

Contours are represented entirely in Ada:

```ada
subtype Contour is OpenCV.Point_Array;
```

Retrieval modes:

```ada
type Contour_Retrieval_Mode is
  (External_Only, Flat_List, Two_Level, Full_Tree);
```

These map to:

| Ada | OpenCV |
| --- | --- |
| `External_Only` | `RETR_EXTERNAL` |
| `Flat_List` | `RETR_LIST` |
| `Two_Level` | `RETR_CCOMP` |
| `Full_Tree` | `RETR_TREE` |

Approximation modes:

```ada
type Contour_Approximation_Mode is
  (Every_Point, Simple, Teh_Chin_L1, Teh_Chin_KCOS);
```

These map to:

| Ada | OpenCV |
| --- | --- |
| `Every_Point` | `CHAIN_APPROX_NONE` |
| `Simple` | `CHAIN_APPROX_SIMPLE` |
| `Teh_Chin_L1` | `CHAIN_APPROX_TC89_L1` |
| `Teh_Chin_KCOS` | `CHAIN_APPROX_TC89_KCOS` |

Extraction API:

```ada
function Find_Contours
  (Source        : OpenCV.Core.Mat;
   Retrieval     : Contour_Retrieval_Mode := External_Only;
   Approximation : Contour_Approximation_Mode := Simple;
   Offset        : OpenCV.Point := (X => 0, Y => 0))
  return Contour_Set;
```

Accessors:

```ada
function Contour_Count (Self : Contour_Set) return Natural;

function Get_Contour
  (Self  : Contour_Set;
   Index : Contour_Index) return Contour;

function Get_Hierarchy
  (Self  : Contour_Set;
   Index : Contour_Index) return Contour_Hierarchy_Entry;
```

Input requirements:

- nonempty;
- two-dimensional;
- `UInt8`;
- exactly one channel.

Zero is background and nonzero is foreground. An all-zero image returns an
empty set.

### Hierarchy representation

OpenCV's `-1` sentinel is not exposed as a magic integer. The Ada API uses:

```ada
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
```

Contour indices are zero-based.

### Ownership model

The C++ shim temporarily owns:

```text
vector<vector<cv::Point>>
vector<cv::Vec4i>
```

inside an opaque native result handle. The Ada layer:

1. obtains contour and hierarchy counts;
2. explicitly copies each point as signed 32-bit X/Y coordinates;
3. converts hierarchy sentinels to `Optional_Contour_Index`;
4. stores results in Ada containers;
5. destroys the native temporary result.

The returned `Contour_Set` therefore does not depend on an STL container or
native contour-result lifetime.

`Find_Contours` preserves the source `Mat`.

### Contour rendering

`Draw_Contours (Image, Contours, Color, ...)` outlines **every** stored contour;
`Fill_Contours (Image, Contours, Color, ...)` fills all of them. Overloads with
`Root : Contour_Index` instead select the root and its descendants through
`Descendant_Levels` generations: zero selects only the root, one includes direct
children, two also includes grandchildren, and depths beyond the tree simply
include every reachable descendant. The selection follows `First_Child` and
`Next`, not storage order. Invalid roots or inconsistent internal hierarchy
raise `OpenCV.OpenCV_Error`. Empty all-contour sets are no-ops after normal
image/color/style validation; empty individual contours are skipped.

Filling the selected collection uses OpenCV's even-odd rule. An outer contour
alone fills its interior; adding a hole leaves that interior empty; adding an
island fills the island again. All-contours fill preserves holes and islands
from a single `Find_Contours` result. OpenCV cautions that independently
retrieved, unrelated collections mixed into one fill may yield different
even-odd semantics; this API accepts only one `Contour_Set` per call.

The Ada layer selects and flattens contours into contiguous signed-32-bit
points and `(first_point, point_count)` spans; no hierarchy or native result
handle crosses the draw ABI. OpenCV 4.1 routes `drawContours` through legacy
`CvSeq`/`cvDrawContours` and applies `maxLevel` to the iterator; OpenCV 4.10
traverses hierarchy for fill but iterates all requested outlines directly;
OpenCV 5 selects hierarchy before either branch. Supplying already selected
contours as siblings (with native level 1 and no hierarchy) normalizes these
differences. The native shim checks all spans, accumulated point counts and
point-plus-offset arithmetic before writing any pixels. Native failures after
rasterization begins do not roll back the image.

`Offset` moves every selected point before rasterization. Drawing through a
shallow alias changes shared storage; a `Region` uses local coordinates and
does not change pixels outside the view. The ordinary drawing depth/channel,
color, thickness and line-style rules apply, including UInt8-only antialiasing.
Only raster rendering belongs here; contour area, moments, hulls, and other
computational geometry belong in `opencv_geometry`.

---

## Shared value types

Imgproc reuses shared public values from `OpenCV`, which the `opencv_core`
crate still distributes. `OpenCV.Core` continues to own `Mat`. Imgproc does
not redeclare `Point`, `Point_Array`, `Size`, `Rect`, `Scalar`,
`Make_Scalar`, `Border_Kind`, or `Angle_Unit`.

This relocation is source-breaking. Callers that previously wrote
`OpenCV.Core.Point` or `OpenCV.Core.Reflect_101` must update qualification
to the root `OpenCV` package. Representative spellings:

| Old | New |
| --- | --- |
| `OpenCV.Core.Point` | `OpenCV.Point` |
| `OpenCV.Core.Point_Array` | `OpenCV.Point_Array` |
| `OpenCV.Core.Size` | `OpenCV.Size` |
| `OpenCV.Core.Scalar` | `OpenCV.Scalar` |
| `OpenCV.Core.Make_Scalar` | `OpenCV.Make_Scalar` |
| `OpenCV.Core.Reflect_101` | `OpenCV.Reflect_101` |

`Contour` remains a subtype of the shared point array:

```ada
subtype Contour is OpenCV.Point_Array;
```

---

## Drawing primitives

Drawing operations mutate the supplied `Mat` directly. A normal shallow
assignment shares storage, and a `Region` is drawn in coordinates relative to
that view. Pixels outside the region stay unchanged. There is no hidden clone.

```ada
declare
   Image : OpenCV.Core.Mat :=
     OpenCV.Core.Create (64, 64, (OpenCV.Core.UInt8, 3));
   Mask : OpenCV.Core.Mat :=
     OpenCV.Core.Create (64, 64, (OpenCV.Core.UInt8, 1));
   Outline : constant OpenCV.Scalar :=
     (Component_0 => 0.0, Component_1 => 255.0, Component_2 => 0.0,
      others => 0.0);
begin
   OpenCV.Core.Set_To (Image, (others => 0.0));
   OpenCV.Image_Processing.Draw_Rectangle
     (Image, (X => 8, Y => 8, Width => 20, Height => 12), Outline);
   OpenCV.Image_Processing.Fill_Circle
     (Image, (X => 40, Y => 32), 8, Outline);
   OpenCV.Image_Processing.Draw_Arrow
     (Image, (X => 8, Y => 40), (X => 28, Y => 40), Outline);
   OpenCV.Image_Processing.Draw_Marker
     (Image, (X => 40, Y => 32), Outline,
      Kind => OpenCV.Image_Processing.Diamond_Marker);
   OpenCV.Image_Processing.Draw_Text
     (Image, "Ada", (X => 8, Y => 56), Outline);
   OpenCV.Core.Set_To (Mask, (others => 0.0));
   OpenCV.Image_Processing.Fill_Rectangle
     (Mask, (X => 10, Y => 10, Width => 16, Height => 16),
      (Component_0 => 255.0, others => 0.0));
   --  Draw every extracted contour into Image:
   OpenCV.Image_Processing.Draw_Contours
     (Image, OpenCV.Image_Processing.Find_Contours (Mask), Outline);
end;
```

`Drawing_Line_Style` is separate from connected-component connectivity:

| Literal | Meaning |
| --- | --- |
| `Four_Connected_Line` | 4-connected Bresenham outline |
| `Eight_Connected_Line` | 8-connected Bresenham outline; the default |
| `Anti_Aliased_Line` | Gaussian-filtered outline, accepted only for `UInt8` |

`Draw_*` operations take a positive `Drawing_Thickness` from 1 through 32767.
`Fill_Rectangle`, `Fill_Circle`, `Fill_Ellipse`, `Fill_Polygon`, and
`Fill_Contours` select
OpenCV's filled mode internally. Negative thickness is not part of the public
API. A partial `Fill_Ellipse` interval fills the elliptic sector; a full turn
fills the ellipse. Angles are finite and default to degrees. Radians are
converted in Ada and are not otherwise normalized.

For shapes, the image must be nonempty and two-dimensional, with depth `UInt8`, `UInt16`,
`Int16`, `Float32`, or `Float64`, and 1 through 4 channels. Scalar components
are copied in channel order. The binding does not convert grayscale or color
and does not blend the fourth channel as alpha. Color components used by the
image must be finite. Points may lie outside the image; OpenCV clips them.
Rectangle extents, circle radii, and ellipse axes must still be positive.
Polylines need at least two points and filled polygons at least three. Array
bounds are arbitrary, so an extracted `Contour` can be passed directly.

`Draw_Arrow` requires distinct endpoints and a finite tip fraction in (0, 1].
All seven marker shapes are available; marker size must be positive. The eight
legacy Hershey font selectors are available. OpenCV 4.1/4.10 render through
classic Hershey strokes; OpenCV 5.0 maps the same selectors to built-in
sans/serif/italic TrueType faces. Glyphs and exact metrics can differ. The
binding guarantees selector routing and high-level semantics, not identical
pixels. The legacy italic bit and text line-style selector are not portable
and are not exposed; OpenCV 4.x uses LINE_8 internally. `Draw_Text` requires
a nonempty 2-D `UInt8` image with exactly 1, 3 or 4 channels, including
Regions. It rejects `UInt16`, `Int16`, `Float32`, `Float64` and C2.
`Draw_Text` accepts empty and embedded-NUL byte strings; empty text draws
nothing after image/color validation. The byte span preserves arbitrary Ada
lower bounds and embedded NULs; non-ASCII glyph interpretation depends on
the native OpenCV generation. Font scale must be finite and positive.
`Measure_Text ("")` always returns size `(0, 0)` and baseline `0` without
calling native code. For nonempty text, it returns the native bounding `Size`
and unadjusted baseline (do not add thickness unless
you need the padding shown in OpenCV's layout example).
`Font_Scale_For_Height` computes OpenCV's scale for a positive pixel height;
heights with `2 * Pixel_Height <= Thickness + 1` are rejected before the native
call, using widened arithmetic to preserve OpenCV-4-compatible positivity.
Measured height for a representative requested height can differ by up to
three pixels due to native rounding and generation-specific font metrics.
Nonfinite, nonpositive or geometry-unsafe native scales are also rejected. Native
arithmetic preflights reject extreme coordinates, glyph scales and text lengths
even if the visible image is small. All drawing validation failures raise
`OpenCV.OpenCV_Error`.

This slice does not include subpixel fixed-point shift, alpha blending,
arbitrary public multi-polygon containers, OpenCV 5 custom font faces,
FreeType/arbitrary font loading, or `drawFrameAxes`.

---

## Hough detection

The Hough detectors return Ada-owned value arrays. The three basic detectors
use:

```ada
subtype Hough_Vote_Threshold   is Positive range 1 .. 2_147_483_647;
subtype Hough_Circle_Threshold is Positive range 1 .. 2_147_483_647;

type Hough_Line is record
   Rho           : OpenCV.Float32_Value;
   Angle_Radians : OpenCV.Float32_Value;
end record;

type Hough_Line_Segment is record
   Start_Point : OpenCV.Point;
   End_Point   : OpenCV.Point;
end record;

type Hough_Circle is record
   Center : OpenCV.Float32_Point;
   Radius : OpenCV.Float32_Value;
end record;

--  Hough_Line_Array, Hough_Line_Segment_Array, Hough_Circle_Array:
--  array (Natural range <>) of the record above.
```

Nonempty results are zero-based. Empty results use the null range `1 .. 0`.
Every element is copied into Ada storage, so results do not depend on the
source `Mat` or on any native object.

### Standard polar lines

```ada
function Find_Hough_Lines
  (Source                   : OpenCV.Core.Mat;
   Distance_Resolution      : OpenCV.Float64_Value;
   Angle_Resolution_Radians : OpenCV.Float64_Value;
   Vote_Threshold           : Hough_Vote_Threshold;
   Minimum_Angle_Radians    : OpenCV.Float64_Value := 0.0;
   Maximum_Angle_Radians    : OpenCV.Float64_Value := Ada.Numerics.Pi)
   return Hough_Line_Array;
```

This is the classical standard Hough transform. `Source` must be a nonempty
2-D `UInt8` C1 **binary** image: zero is background and **every nonzero value**
is a candidate pixel (not only 255). Both resolutions must be positive and
finite, and the angle bounds must satisfy
`0 <= Minimum_Angle_Radians < Maximum_Angle_Radians <= Pi`.

A result describes the points satisfying
`X * cos (Angle_Radians) + Y * sin (Angle_Radians) = Rho`, with coordinates
relative to the source origin. `Rho` is in pixels and may be negative.
`Angle_Radians` is always radians. A horizontal line at row `r` appears near
`(Rho => r, Angle_Radians => Pi / 2)`; a vertical line at column `c` appears
near `(c, 0)`, or equivalently `(-c, Pi)`.

Each result is an accumulator bin, so values are quantized by the requested
resolutions; expect agreement with exact geometry to within about one bin.
OpenCV 5.0 reconstructs `Rho` with integer arithmetic where OpenCV 4.x uses a
half-bin offset, so the reported `Rho` can differ by up to half a distance bin
between generations.

### Probabilistic line segments

```ada
function Find_Hough_Line_Segments
  (Source                   : OpenCV.Core.Mat;
   Distance_Resolution      : OpenCV.Float64_Value;
   Angle_Resolution_Radians : OpenCV.Float64_Value;
   Vote_Threshold           : Hough_Vote_Threshold;
   Minimum_Line_Length      : OpenCV.Size_Coordinate := 0;
   Maximum_Line_Gap         : OpenCV.Size_Coordinate := 0)
   return Hough_Line_Segment_Array;
```

The source contract is the same binary `UInt8` C1 image. Length and gap are
integer pixel counts, because OpenCV rounds them to integers internally. A
segment is kept when its X **or** Y extent reaches `Minimum_Line_Length`; up to
`Maximum_Line_Gap` missing pixels may be bridged along a line.

Endpoint order is **not** specified: `(A, B)` and `(B, A)` describe the same
segment. The reference implementation uses a fixed internal random seed, but
endpoints may still differ by a pixel or two across OpenCV builds, so compare
them with a small tolerance.

### Gradient circles

```ada
--  Automatic maximum radius (OpenCV uses the larger source dimension).
function Find_Hough_Circles
  (Source                  : OpenCV.Core.Mat;
   Accumulator_Scale       : OpenCV.Float64_Value;
   Minimum_Center_Distance : OpenCV.Float64_Value;
   Canny_Threshold         : Hough_Circle_Threshold;
   Accumulator_Threshold   : Hough_Circle_Threshold;
   Minimum_Radius          : OpenCV.Size_Coordinate := 0)
   return Hough_Circle_Array;

--  Explicit radius interval; Maximum_Radius must exceed Minimum_Radius.
function Find_Hough_Circles
  (Source                  : OpenCV.Core.Mat;
   Accumulator_Scale       : OpenCV.Float64_Value;
   Minimum_Center_Distance : OpenCV.Float64_Value;
   Canny_Threshold         : Hough_Circle_Threshold;
   Accumulator_Threshold   : Hough_Circle_Threshold;
   Minimum_Radius          : OpenCV.Size_Coordinate := 0;
   Maximum_Radius          : OpenCV.Size_Coordinate)
   return Hough_Circle_Array;
```

Only the portable classic `HOUGH_GRADIENT` method is used. `Source` is a
nonempty 2-D `UInt8` C1 **grayscale** image; the detector computes its own
Sobel gradients and Canny edges (upper threshold `Canny_Threshold`, lower
threshold half of it). Blurring the input first usually improves results.

- `Accumulator_Scale` must be finite and at least `1.0`. OpenCV silently
  clamps smaller values to 1; the Ada API rejects them instead.
- `Minimum_Center_Distance` must be positive and finite.
- `Canny_Threshold` and `Accumulator_Threshold` are positive integers because
  OpenCV rounds them to integers.
- The public API has no zero or negative maximum-radius sentinel. The first
  overload selects OpenCV's automatic maximum privately. The explicit overload
  requires `Maximum_Radius > Minimum_Radius` and never reproduces OpenCV's
  silent widening of an invalid maximum to `Minimum_Radius + 2`.

`Center` and `Radius` are native binary32 pixel values. Centers are quantized
to accumulator cells and radii are histogram estimates, so compare them with a
tolerance of a pixel or two rather than exactly.

### Source preservation and views

OpenCV documents that the line transforms may modify their input. Every Hough
operation therefore runs on a private continuous native **snapshot** (clone)
of `Source`:

1. caller-visible pixels are never modified;
2. a non-contiguous `Region` is analysed as its own logical image: pixels and
   borders outside the view never contribute, and result coordinates are
   relative to the view origin.

The snapshot costs one copy of the source per call and is never exposed.

### Result ordering and omitted outputs

Result order is unspecified for every Hough operation. In the inspected
OpenCV implementations, standard lines and circles are ordered by accumulator
support, while probabilistic segments appear in the order produced by the
randomized point walk and are not sorted. Search results by geometry rather
than relying on an index. The three detectors above do not request
accumulator votes; the evidence operations below do.

### Evidence: accumulator votes, point sets, and circle centers

```ada
type Hough_Line_With_Votes is record
   Rho           : OpenCV.Float32_Value;
   Angle_Radians : OpenCV.Float32_Value;
   Votes         : OpenCV.Float64_Value;
end record;

type Hough_Circle_With_Votes is record
   Center : OpenCV.Float32_Point;
   Radius : OpenCV.Float32_Value;
   Votes  : OpenCV.Float64_Value;
end record;

Hough_Degree : constant := Ada.Numerics.Pi / 180.0;

type Hough_Point_Array is array (Integer range <>) of OpenCV.Float32_Point;
type Hough_Circle_Center_Array is
  array (Natural range <>) of OpenCV.Float32_Point;
--  Hough_Line_With_Votes_Array, Hough_Circle_With_Votes_Array:
--  array (Natural range <>) of the record above.

function Find_Hough_Lines_With_Votes
  (Source                   : OpenCV.Core.Mat;
   Distance_Resolution      : OpenCV.Float64_Value;
   Angle_Resolution_Radians : OpenCV.Float64_Value;
   Vote_Threshold           : Hough_Vote_Threshold;
   Minimum_Angle_Radians    : OpenCV.Float64_Value := 0.0;
   Maximum_Angle_Radians    : OpenCV.Float64_Value := Ada.Numerics.Pi)
   return Hough_Line_With_Votes_Array;

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

function Find_Hough_Circle_Centers
  (Source                  : OpenCV.Core.Mat;
   Accumulator_Scale       : OpenCV.Float64_Value;
   Minimum_Center_Distance : OpenCV.Float64_Value;
   Canny_Threshold         : Hough_Circle_Threshold;
   Accumulator_Threshold   : Hough_Circle_Threshold;
   Minimum_Radius          : OpenCV.Size_Coordinate := 0)
   return Hough_Circle_Center_Array;

--  Two overloads mirroring Find_Hough_Circles: automatic maximum radius,
--  and explicit Maximum_Radius > Minimum_Radius.
function Find_Hough_Circles_With_Votes (...)
   return Hough_Circle_With_Votes_Array;
```

Record fields always use the same order: geometry first (`Rho`,
`Angle_Radians`, or `Center`, `Radius`), then `Votes`. OpenCV's own component
orders differ (`HoughLinesPointSet` returns `(votes, rho, theta)`); the
binding normalizes them. Array bounds follow the other Hough results.

- **Standard lines with votes** have exactly the `Find_Hough_Lines` contract
  and add each bin's accumulator count. OpenCV's optional IPP standard-Hough
  path serves only the vote-free output, so on IPP-enabled builds the two
  operations are not guaranteed to return identical lines or ordering.
- **Point-set lines** run `HoughLinesPointSet` over explicit binary32 points
  (any array bounds, possibly empty; coordinates must be finite). Rho bins
  start at `Minimum_Rho` with width `Distance_Resolution`;
  `Minimum_Rho < Maximum_Rho`, the usual angle bounds, and at least one rho
  and one angle bin are required. `Maximum_Lines` is a cap, not a requested
  count. An empty point set returns an empty result.
- **Point-set range safety.** Every point must vote inside
  `[Minimum_Rho, Maximum_Rho]` for every searched angle. OpenCV 4.1 writes
  out-of-range votes outside its accumulator (later versions drop them), so a
  rho range that does not contain all votes raises `OpenCV.OpenCV_Error` on
  every OpenCV version. Since `|rho| <= sqrt (X**2 + Y**2)`, a range reaching
  a little beyond plus and minus the largest point distance from the origin
  always works.
- **Circle centers** run the classic gradient detector without radius
  estimation (OpenCV's private negative-`maxRadius` mode, never exposed). Only
  centers are returned; OpenCV's placeholder radius is discarded.
  `Minimum_Radius` still limits how close to each edge pixel center votes are
  cast.
- **Circles with votes** always estimate radii and report the support count
  of the chosen radius. They never use centers-only mode, whose native fourth
  component is an accumulator index rather than a vote count.

**Vote semantics.** OpenCV keeps only strict local maxima whose count exceeds
the requested threshold, so accepted results normally report
`Votes > threshold`. `Votes` is stored as `Float64_Value` for one uniform API:
raster-line votes come from OpenCV's `Vec3f` output and circle votes from its
`Vec4f` output (so counts above 2**24 may already be rounded by binary32),
while point-set votes come from `Vec3d`; all are integer accumulator counts.
Magnitudes can differ across OpenCV generations and backends: use votes as
ranking and evidence, not as a cross-version constant.

### Validation and native safety

Public contract violations raise `OpenCV.OpenCV_Error` before native code
runs; out-of-range subtype values raise `Constraint_Error`. The C ABI also
rejects combinations that would overflow OpenCV's native signed `int`
accumulator arithmetic, for example an extremely small `rho` or `theta` on a
large image, a nonzero-pixel count times angle-bin count that overflows the
standard-Hough IPP line estimate, or a radius whose square overflows `int`.
Those also raise `OpenCV.OpenCV_Error`. There is no arbitrary resolution
floor; the limits come from the native arithmetic itself. The raw C ABI
independently rejects malformed sources (empty, N-D, non-`UInt8`, or
multi-channel), nonpositive thresholds, and negative segment length or gap.
For point sets it rejects malformed point spans, nonfinite coordinates or
bounds, bin counts or accumulator products beyond native `int`, and any
point/angle vote whose modelled binary32 column falls outside the
accumulator. Vote-bearing circles refuse the centers-only mode, and
centers-only detection skips only the checks that belong to radius
estimation.

### Examples

Draw a synthetic shape, extract edges, then detect lines and segments:

```ada
Canvas : OpenCV.Core.Mat :=
  OpenCV.Core.Create (100, 100, (OpenCV.Core.UInt8, 1));
Edges  : OpenCV.Core.Mat;
...
OpenCV.Core.Set_To (Canvas, (others => 0.0));
OpenCV.Image_Processing.Fill_Rectangle
  (Canvas,
   (X => 20, Y => 30, Width => 60, Height => 40),
   (Component_0 => 255.0, others => 0.0));
OpenCV.Image_Processing.Canny_Edges (Canvas, Edges, 50.0, 150.0);

declare
   Lines    : constant OpenCV.Image_Processing.Hough_Line_Array :=
     OpenCV.Image_Processing.Find_Hough_Lines
       (Edges, 1.0, Ada.Numerics.Pi / 180.0, 30);
   Segments : constant OpenCV.Image_Processing.Hough_Line_Segment_Array :=
     OpenCV.Image_Processing.Find_Hough_Line_Segments
       (Edges, 1.0, Ada.Numerics.Pi / 180.0, 30,
        Minimum_Line_Length => 20, Maximum_Line_Gap => 3);
begin
   --  Lines holds the rectangle sides as (Rho, Angle_Radians) values;
   --  Segments holds their endpoints in either order. OpenCV keeps only
   --  bins with strictly more than Vote_Threshold votes, so the threshold
   --  must be below the shortest side (40 pixels) to report all four.
   null;
end;
```

Detect a blurred synthetic disc:

```ada
Disc    : OpenCV.Core.Mat :=
  OpenCV.Core.Create (100, 100, (OpenCV.Core.UInt8, 1));
Blurred : OpenCV.Core.Mat;
...
OpenCV.Core.Set_To (Disc, (others => 0.0));
OpenCV.Image_Processing.Fill_Circle
  (Disc, (X => 50, Y => 50), 25, (Component_0 => 255.0, others => 0.0));
OpenCV.Image_Processing.Gaussian_Blur
  (Disc, Blurred, (Width => 5, Height => 5), Sigma => 1.5);

declare
   Circles : constant OpenCV.Image_Processing.Hough_Circle_Array :=
     OpenCV.Image_Processing.Find_Hough_Circles
       (Blurred, 1.0, 40.0, 100, 20,
        Minimum_Radius => 15, Maximum_Radius => 35);
begin
   --  Expect a circle near Center (50, 50) with Radius near 25.
   null;
end;
```

### Deferred

Multiscale `srn`/`stn`, OpenCV 5 weighted Hough (`use_edgeval`), and
`HOUGH_GRADIENT_ALT` are intentionally not part of this slice.

---

## Segmentation

Three segmentation tools share one contract style: in-place mutation is
explicit, sources are never modified, storage overlap between an input and a
mutated Mat is rejected, and semantic contract violations detected by the
binding raise `OpenCV.OpenCV_Error`. Values outside a constrained Ada subtype
such as `GrabCut_Iterations` or `Flood_Fill_Mask_Value` fail the ordinary Ada
range check and raise `Constraint_Error` before the operation runs. The API
was checked against OpenCV 4.1.0, 4.10.0, and
5.0.0 `floodfill.cpp`, `segmentation.cpp`, and `grabcut.cpp`.

### Flood fill

```ada
type Flood_Fill_Range_Mode is (Floating_Range, Fixed_Range);
subtype Flood_Fill_Mask_Value is OpenCV.UInt8_Value range 1 .. 255;

type Flood_Fill_Result is record
   Pixel_Count : Natural;      --  filled pixels
   Bounds      : OpenCV.Rect;  --  smallest rectangle containing them
end record;
```

- **Image:** nonempty 2-D `UInt8` or `Float32`, one or three channels. This
  is OpenCV's documented portable contract; the undocumented `Int32` paths are
  not exposed.
- **Seed:** `X` is the column and `Y` the row, and it must be inside the
  image.
- **Ranges:** a neighbour joins when every channel is within
  `[reference - Lower_Difference, reference + Upper_Difference]`.
  `Floating_Range` compares it with the adjacent filled pixel, so the fill can
  follow a gradual ramp. `Fixed_Range` compares it with the seed pixel. The
  components used by the image's channels must be finite, and the differences
  nonnegative.
- **Connectivity:** reuses `Pixel_Connectivity` (`Four_Connected` default,
  `Eight_Connected`).
- **In place:** `Image` is modified. A `Region` is filled as its own logical
  image in view coordinates and mutates its parent's storage. Shallow aliases
  observe the change.

`Flood_Fill_With_Mask` adds a caller-owned mask:

- `Mask` is `UInt8` C1 with **`Image.Rows + 2` rows and `Image.Columns + 2`
  columns**. `Image (X, Y)` corresponds to `Mask (X + 1, Y + 1)`.
- The fill never crosses a nonzero mask pixel. Filled pixels are set to
  `Mask_Fill_Value` in the mask, and OpenCV sets the mask's one-pixel outer
  border to `1`.
- `Mask_Only => True` leaves `Image` unchanged and ignores `New_Value` (it is
  not even validated). `Mask` and `Result` are still updated.
- `Mask` must not share storage with `Image`.

```ada
declare
   Image  : OpenCV.Core.Mat := ...;   --  UInt8 C1, 100 x 120
   Mask   : OpenCV.Core.Mat := OpenCV.Core.Create (102, 122, (OpenCV.Core.UInt8, 1));
   Result : OpenCV.Image_Processing.Flood_Fill_Result;
begin
   OpenCV.Core.Set_To (Mask, (others => 0.0));
   OpenCV.Image_Processing.Flood_Fill_With_Mask
     (Image, Mask, (X => 10, Y => 20), (others => 0.0), Result,
      Upper_Difference => (Component_0 => 4.0, others => 0.0),
      Mask_Fill_Value  => 255,
      Mask_Only        => True);
   --  Mask (Y + 1, X + 1) = 255 for every pixel in the component.
end;
```

The native flag word (connectivity, `FLOODFILL_FIXED_RANGE`,
`FLOODFILL_MASK_ONLY`, mask value in bits 8..15) is built privately.

### Watershed

```ada
procedure Watershed
  (Source : OpenCV.Core.Mat; Markers : in out OpenCV.Core.Mat);
```

- `Source`: nonempty 2-D `UInt8` C3. It is never modified.
- `Markers`: `Int32` C1 with the same rows and columns, updated in place.
  - On input, `0` means unknown and each positive value seeds a region.
    Negative input values are rejected.
  - On output, unknown pixels carry a propagated label, and `-1` marks
    watershed boundaries, including the one-pixel outer border of `Markers`.
- `Markers` must not share storage with `Source`. It is mutated directly, never
  cloned. A `Markers` Region writes through to its parent.

```ada
declare
   Markers : OpenCV.Core.Mat :=
     OpenCV.Core.Create (Image.Rows, Image.Columns, (OpenCV.Core.Int32, 1));
begin
   OpenCV.Core.Set_To (Markers, (others => 0.0));
   --  Seed label 1 in the background and 2 inside the object, then:
   OpenCV.Image_Processing.Watershed (Image, Markers);
end;
```

### GrabCut

```ada
type GrabCut_Label is
  (Definite_Background,   --  0
   Definite_Foreground,   --  1
   Probable_Background,   --  2
   Probable_Foreground);  --  3

subtype GrabCut_Iterations is Positive range 1 .. 2_147_483_647;
GrabCut_Minimum_Training_Pixels : constant := 5;
GrabCut_Model_Column_Count : constant Positive := 65;

type GrabCut_State is limited private;
```

`GrabCut_State` privately owns the label mask and OpenCV's background and
foreground Gaussian-mixture models. Each native model is Float64 C1 `1 x 65`:
five weights (columns 0..4), 15 means (5..19), and 45 covariance entries
(20..64), five components of 13 values. Exported models are **deep clones**,
never writable aliases into state storage. This interchange format is specific
to OpenCV GrabCut, not a general GMM serialization standard.
The state is **limited**, so it cannot be assigned or shallow-copied. Two states
can never share mutable algorithm storage, and its Mats are released through
normal `OpenCV.Core.Mat` finalization. A default-declared state is
uninitialized (`Is_Initialized` returns `False`), and every other operation
rejects it.

| Operation | Behavior |
| --- | --- |
| `Initialize_GrabCut (Source, Foreground_Region, Iterations)` | Outside the region is `Definite_Background`, inside starts as `Probable_Foreground`, then `Iterations` rounds run |
| `Initialize_GrabCut (Source, Initial_Mask, Iterations)` | Deep-copies a caller label mask (UInt8 C1, same geometry, values 0..3). The caller's mask is unchanged |
| `Initialize_GrabCut (Source, Initial_Mask, Foreground_Region, Iterations)` | Clones the mask, sets **every** pixel outside the rectangle to `Definite_Background`, preserves **all four** caller labels inside, then initializes with native mask mode |
| `Restore_GrabCut_State (Mask, Background_Model, Foreground_Model)` | Validates and clones all three Mats without running GrabCut; sparse restored mask classes are allowed |
| `Clone_GrabCut_State (State)` | Explicit independent deep copy of all three Mats |
| `GrabCut_Background_Model` / `GrabCut_Foreground_Model` | Return independent Float64 C1 `1 x 65` deep clones |
| `Refine_GrabCut (Source, State, Iterations)` | Relearns the models and re-segments the probable pixels (`GC_EVAL`) |
| `Refine_GrabCut_Frozen_Model (Source, State)` | One pass with the models held fixed (`GC_EVAL_FREEZE_MODEL`, always one iteration) |
| `GrabCut_Mask (State)` | Returns a **deep clone**. Changing it never affects `State` |
| `GrabCut_Label_At (State, Row, Column)` | Returns the label at one bounds-checked position |
| `GrabCut_Label_Value` / `To_GrabCut_Label` | Explicit 0..3 conversion. `To_GrabCut_Label` rejects other values |

`Source` is always a nonempty 2-D `UInt8` C3 image and is never modified.
Refinement requires `Source` to match the state's geometry. Definite labels
never change. A failed refinement leaves the state unchanged because the work
is done on private copies that are committed only after success.

**Portability rule.** OpenCV 4.1 always clusters each training set into five
GMM components with `kmeans (K => 5)`, which asserts `N >= K`. OpenCV 4.10 and
5.0 silently reduce `K` for small sets. For one contract across the supported
range, initialization requires at least **five background** (definite or
probable) and **five foreground** (definite or probable) pixels:

- rectangle initialization requires a positive-size rectangle entirely inside
  `Source`, with at least five pixels inside it and five outside it;
- mask initialization requires at least five pixels of each class.
- combined initialization requires five pixels of each class **after** the
  rectangle overwrites outside labels; background seeds inside count too.

The headers of OpenCV 4.1.0, 4.10.0 and 5.0.0 document combining
`GC_INIT_WITH_RECT | GC_INIT_WITH_MASK`, but `RECT = 0` and `MASK = 1`: the
implementations dispatch on equality, so OR selects mask-only mode and ignores
the rectangle. The binding implements the combined behavior explicitly and
calls native `GC_INIT_WITH_MASK`. Coordinates and dimensions refer to the
supplied Source view; neither Source nor the caller's Initial_Mask is changed.
Restoration checks nonempty UInt8 C1 2-D labels 0..3 and nonempty Float64 C1
2-D 1x65 models, rejecting nonfinite payloads, negative weights, no active
component, and active covariance determinants invalid for the native GMM.
Imported models are checked again before native evaluation. Inactive components
may retain stale finite mean/covariance entries (native learning permits this).
OpenCV 4.1 requires five k-means samples per class; 4.10 and 5.0 shrink K
for smaller training sets. All three use the same 65-double GMM layout and
mode dispatch; 5.0 moves the graph header to the geometry module.

```ada
declare
   State : OpenCV.Image_Processing.GrabCut_State :=
     OpenCV.Image_Processing.Initialize_GrabCut
       (Photo, (X => 40, Y => 30, Width => 120, Height => 90), Iterations => 3);
begin
   OpenCV.Image_Processing.Refine_GrabCut (Photo, State);
   if OpenCV.Image_Processing.GrabCut_Label_At (State, 75, 100)
        in OpenCV.Image_Processing.Probable_Foreground
         | OpenCV.Image_Processing.Definite_Foreground
   then
      null;  --  (row 75, column 100) is part of the object.
   end if;
end;
```

Exact boundary pixels differ between OpenCV generations, because 4.1 and
newer releases initialize the mixtures differently. The tests therefore check
stable properties: the label domain, geometry, obvious background, and
obvious foreground.

---

## Histogram analysis

Dense uniform or nonuniform histograms of one image or several images, their
comparison, histogram back projection, and immutable accumulation. The design
was checked against OpenCV 4.1.0, 4.10.0, and 5.0.0 `imgproc.hpp` and
`histogram.cpp` (`calcHist`, `calcBackProject`, `compareHist`,
`histPrepareImages`, `calcHistLookupTables_8u`, `ipp_calchist`). All three
releases share the low-level `calcHist(const Mat*, int nimages, const int*
channels, ...)` and `calcBackProject(const Mat*, int nimages, const int*
channels, ...)` signatures. A histogram uses one `uniform` flag for every
axis. Uniform calls pass `uniform = true`; nonuniform calls pass
`uniform = false`. Every call passes `accumulate = false`.

OpenCV has no mixed uniform/nonuniform call. This binding therefore does not
put both kinds of axis in one histogram, and it does not expand a uniform
axis into explicit edges.

When `uniform` is false, each axis supplies `Bin_Count + 1` strictly
increasing Float32 edges `E0 .. EN`. The bins are `[E0, E1)`, `[E1, E2)`,
through `[E(N-1), EN)`. A sample below the first edge, or at or above the
final edge, is not counted. Back projection uses the same edges. On every
reviewed release the nonuniform UInt8 lookup passes every edge to `cvCeil`.
On the qualifying `calcHist` path only, OpenCV 4.10 and 5.0 also evaluate
`cvFloor` on the first edge inside `ipp_calchist` before that function can
decline the request. `ipp_calcHistParallel` computes `histSize + 1` in signed
int and, for the UInt8/UInt16/Float32 C1 types it actually executes, narrows
the source byte step with `(int)m_src.step`. Back projection never enters IPP.
OpenCV 5 adds a HAL `cv_hal_calcHist` for the same one-source, one-dimension,
channel-0, unmasked shape. Its reference implementation returns not-implemented;
its arguments are a `size_t` step, an `int` width and height, an `int` bin
count, and `const float **` ranges, so it needs no extra narrowing guard.

`histPrepareImages` is the same on all three releases: `nimages` must be
positive, every image must match `images[0]` in size and depth, and channel
numbers are concatenated across images. Channel counts may differ. OpenCV 4.1
has no `nimages > 0` assert before reading `images[0]`. OpenCV 4.x
`calcBackProject` treats a 2-D histogram with `size[1] == 1` as 1-D; OpenCV 5.0
does the same for either a single row or a single column, and its Mat shape is
limited to 10 dimensions. Native dense accumulation on every reviewed release
does `_hist.create(...)`, disables accumulation when that reallocates, converts
the existing bins to signed `int`, increments them, and converts back to
`Float32`.

### Dimensions and ranges

```ada
Maximum_Histogram_Dimensions : constant Positive := 10;

subtype Histogram_Bin_Count is Positive range 1 .. 2_147_483_647;

type Histogram_Dimension is record
   Channel     : Natural;               --  zero-based channel of Source
   Bin_Count   : Histogram_Bin_Count;
   Lower_Bound : OpenCV.Float32_Value;
   Upper_Bound : OpenCV.Float32_Value;
end record;

type Histogram_Dimension_Array is
  array (Positive range <>) of Histogram_Dimension;

type Histogram_Source_Dimension is record
   Source_Position : Natural;          --  zero-based iteration position
   Channel         : Natural;          --  zero-based within that source
   Bin_Count       : Histogram_Bin_Count;
   Lower_Bound     : OpenCV.Float32_Value;
   Upper_Bound     : OpenCV.Float32_Value;
end record;

type Histogram_Bin_Boundary_Array is
  array (Positive range <>) of OpenCV.Float32_Value;

function Nonuniform_Histogram_Dimension
  (Channel : Natural; Boundaries : Histogram_Bin_Boundary_Array)
   return Histogram_Nonuniform_Dimension;

function Nonuniform_Histogram_Source_Dimension
  (Source_Position : Natural;
   Channel         : Natural;
   Boundaries      : Histogram_Bin_Boundary_Array)
   return Histogram_Nonuniform_Dimension;
```

`Histogram_Dimension` selects a channel of one source and is stored with
source position 0. `Source_Position` is the position in `Mat_Array` iteration
order, not the Ada index: for `Sources (10 .. 11)`, position 0 is
`Sources (10)`. Native concatenated channel numbers are not exposed. A
uniform axis divides `[Lower_Bound, Upper_Bound)` into equal bins. A
nonuniform descriptor owns a copy of its edges, so the caller's array may
change afterwards. At least two finite, strictly increasing edges are
required; `N` edges define `N - 1` bins `[edge (I), edge (I + 1))`. Edges are
not required to lie inside the source depth's numeric range. A pixel is
counted only when every selected sample falls in a bin. The same source and
channel may be selected more than once. Every axis of one histogram uses the
same binning mode.

**Why at most 10 dimensions.** OpenCV 4.x supports dense Mat dimensionality up
to `CV_MAX_DIM` (32), but OpenCV 5.0 limits `Mat` to `MatShape::MAX_DIMS`
(10). The product of the bin counts must fit in `2_147_483_647`.

### Calculation

```ada
function Calculate_Histogram
  (Source : OpenCV.Core.Mat; Dimensions : Histogram_Dimension_Array)
   return Histogram;

function Calculate_Histogram
  (Sources    : OpenCV.Core.Mat_Array;
   Dimensions : Histogram_Source_Dimension_Array) return Histogram;

function Calculate_Nonuniform_Histogram
  (Source     : OpenCV.Core.Mat;
   Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;

function Calculate_Nonuniform_Histogram
  (Sources    : OpenCV.Core.Mat_Array;
   Dimensions : Histogram_Nonuniform_Dimension_Array) return Histogram;
```

All four have masked overloads. A single source, and every element of
`Sources`, must be a nonempty 2-D `UInt8`, `UInt16`, or `Float32` Mat. A
single-source nonuniform call requires every stored source position to be 0.
Within one multi-source call every element shares the first element's rows,
columns, and depth; channel counts may differ. `Sources` must be nonempty and
may use any bounds. The optional mask is 2-D `UInt8` C1 of that common
geometry and is applied at the same location in every source. Sources and the
mask are only read. A Region is its logical view; parent pixels outside it
are not sampled.

### The Histogram type

`Histogram_Binning` reports `Uniform_Binning` or `Nonuniform_Binning`. An
empty histogram reports `Uniform_Binning`. `Get_Histogram_Dimension` returns
channel, bin count, and the uniform range or, for a nonuniform axis, the
first and last edges as its envelope. That envelope is not a claim of equal
spacing. `Get_Histogram_Bin_Boundaries` returns the two uniform endpoints or
every stored nonuniform edge, as a new array. `Get_Histogram_Source_Position`
returns the stored position; single-source histograms return 0.
`Histogram_Values` returns a deep Float32 clone. A one-dimensional histogram
is published as `Bin_Count x 1` on every OpenCV release, including OpenCV 5
where the native result is genuinely 1-D.

### Comparison

Uniform comparison requires the same dimension count and, per axis, the same
bin count and both endpoints. Nonuniform comparison requires both histograms
to be nonuniform and, per axis, the same bin count and the exact stored
Float32 edge sequence. Matching only the outer endpoints is not enough, and a
uniform histogram is not compared with a nonuniform one. Source position and
channel are provenance, not bin geometry.

### Back projection

```ada
function Back_Project
  (Source : OpenCV.Core.Mat; Distribution : Histogram;
   Scale : OpenCV.Float64_Value := 1.0) return OpenCV.Core.Mat;

function Back_Project
  (Sources : OpenCV.Core.Mat_Array; Distribution : Histogram;
   Scale : OpenCV.Float64_Value := 1.0) return OpenCV.Core.Mat;
```

The single-source overload requires every stored position to be 0 and
otherwise raises `OpenCV.OpenCV_Error`. The array overload requires enough
sources for every stored position, with the same geometry and depth contract
as calculation. The result is a fresh C1 Mat with the first source's rows,
columns, and depth. Both overloads use the edges stored in `Distribution`;
callers do not resupply nonuniform edges. A nonuniform distribution is passed
to OpenCV with `uniform = false`. A 2-D histogram with a one-bin axis is
given a trailing one-bin axis before `calcBackProject`, repeating that
one-bin axis's native channel and complete edge sequence, so OpenCV does not
collapse it to 1-D.

### Accumulation

```ada
function Accumulate_Histogram
  (Base : Histogram; Source : OpenCV.Core.Mat) return Histogram;

function Accumulate_Histogram
  (Base : Histogram; Sources : OpenCV.Core.Mat_Array) return Histogram;
```

Masked overloads use the same mask contract. The operation calculates a fresh
delta with `accumulate = false`, using Base's stored source positions,
channels, binning mode, and complete edge sequence. It checks every finite
nonnegative bin and adds the widened sums into a new Float32 histogram. The
result keeps Base's exact edges. It does not call native
`calcHist(..., accumulate=true)`: passing the portable `N x 1` shape back to
OpenCV 5 reallocates and silently clears the base, and the native path
accumulates through signed `int`. Base and the sources are not modified.
Separate calls need not share image geometry; only the sources inside one call
must. Counts above `2**24` may lose integer-unit precision because storage is
Float32. An uninitialized histogram is rejected.

### Validation and native safety

Ada validates the public contract and raises `OpenCV.OpenCV_Error`; values
outside `Histogram_Bin_Count` raise `Constraint_Error`. The private C ABI
passes a pointer to fixed-layout `{int32 channel, int32 bin_count, float lower,
float upper}` records plus a count; the native channel, size, and range-pointer
arrays exist only for one call. Before any native arithmetic the shim
independently rejects:

- dimension counts outside 1 .. 10 and null dimension pointers;
- non-positive bin counts and bin products beyond native `int` (OpenCV 5.0
  `setSize` would otherwise compute a wrapped allocation size);
- non-finite or empty ranges, and ranges whose bin scaling would push
  `cvFloor` outside `int` for some `UInt8`/`UInt16` sample;
- unsupported source depths and raw channel indices before inspecting selected
  pixels;
- nonfinite selected Float32 samples. For a uniform axis, a finite sample is
  also rejected when `sample * scale - lower * scale` is outside the native
  `cvFloor` int range. A nonuniform axis compares the sample directly with its
  Float32 edges and does not apply that uniform transform. Ordinary finite
  samples outside the bins remain legal; masked calculation does not inspect
  masked-out pixels;
- every nonuniform UInt8 edge that `cvCeil` cannot convert, and, when the
  request matches the `ipp_calchist` call (one source, one dimension, channel
  0, no mask), a first edge that `cvFloor` cannot convert or a UInt8/UInt16/
  Float32 C1 byte step that does not fit in signed int;
- non-2-D sources and source/mask strides that `histPrepareImages` narrows to
  `int`;
- comparison of empty, non-Float32, or differently shaped histograms (the
  native loop would over-read the second one);
- back projection through a histogram whose shape differs from the dimension
  records, or with a non-finite scale.

Integer-depth back projection pre-scales and clamps the histogram so
`saturate_cast` never converts a value outside `int`. OpenCV treats every 2-D
histogram with a unit axis as 1-D during back projection; the shim adds a
trailing one-bin axis in that case so both channels are still honored.
Results are published only after the native call succeeds.

### Examples

Compare the distribution of one channel in two BGR images:

```ada
declare
   Green     : constant Histogram_Dimension :=
     (Channel => 1, Bin_Count => 32, Lower_Bound => 0.0, Upper_Bound => 256.0);
   Reference : constant Histogram :=
     Calculate_Histogram (Reference_BGR, (1 => Green));
   Candidate : constant Histogram :=
     Calculate_Histogram (Candidate_BGR, (1 => Green));
begin
   Put_Line (Compare_Histograms (Reference, Candidate, Correlation)'Image);
end;
```

Or compare brightness after `Convert_Color`:

```ada
Convert_Color (Reference_BGR, Reference_Gray, BGR_To_Gray);
Convert_Color (Candidate_BGR, Candidate_Gray, BGR_To_Gray);
Distance :=
  Compare_Histograms
    (Calculate_Histogram (Reference_Gray, (1 => (0, 32, 0.0, 256.0))),
     Calculate_Histogram (Candidate_Gray, (1 => (0, 32, 0.0, 256.0))),
     Hellinger_Distance);
```

Locate regions that resemble a reference patch:

```ada
declare
   Model      : constant Histogram :=
     Calculate_Histogram
       (Reference_Patch, ((0, 16, 0.0, 256.0), (1, 16, 0.0, 256.0)));
   Likelihood : constant OpenCV.Core.Mat := Back_Project (Scene, Model, 8.0);
   Binary     : OpenCV.Core.Mat;
   Labels     : OpenCV.Core.Mat;
   Blobs      : Connected_Component_Set;
begin
   Apply_Threshold (Likelihood, Binary, 32.0);
   Connected_Components_With_Stats (Binary, Labels, Blobs);
end;
```

---

## Earth mover distance

`Earth_Mover_Distance` computes exact `cv::EMD` from two nonempty 2-D
`Float32` C1 signatures. Each row is `(weight, coordinate_1, ...)`, with at
least one coordinate and matching column counts. Choose `Manhattan_EMD`
(`DIST_L1`), `Euclidean_EMD` (`DIST_L2`, default), or `Chessboard_EMD`
(`DIST_C`). `Earth_Mover_Distance_With_Flow` also returns a fresh `Float32` C1
`Flow` Mat of size `Signature_1.Rows x Signature_2.Rows`; `Flow(i,j)` is the
mass carried from source row `i` to destination row `j`. Zero-weight rows
carry no flow.

`Earth_Mover_Distance_With_Cost` and
`Earth_Mover_Distance_With_Cost_And_Flow` use `DIST_USER` and an explicit
`Float32` C1 cost matrix sized `Signature_1.Rows x Signature_2.Rows`. In
this mode signatures can contain only weights (one column); when coordinate
columns exist they are ignored for transport costs. The complete cost matrix
is validated, including entries for zero-weight rows.

Weights must be finite, nonnegative and have at least one positive entry per
signature; positive-weight totals must fit finite Float32. Unequal totals are
allowed: OpenCV adds an internal zero-cost dummy cluster to the lighter side
and normalizes EMD by the larger total. Dummy rows/columns are not returned
in Flow. Built-in coordinates must be finite. Each relevant pairwise native
cost, or each explicit cost, must be nonnegative, finite and **strictly less
than `1e20`** (OpenCV's `CV_EMD_INF` sentinel). Both native Float32
subtraction and the L2 Float32 cast of the squared sum are preflighted.

Inputs are never modified. Signatures and explicit costs, including
non-contiguous Regions, are deep-cloned to packed private storage. This is
essential for OpenCV 4.1: its legacy `cvCalcEMD2`/`icvInitEMD` reads signature
rows with contiguous indexing rather than their Mat row step. OpenCV 4.10
and 5.0 use the rewritten `EMDSolver`, which indexes Mat rows and sizes
its buffers differently. The shim preflights the 4.1 signed-int work-buffer
formula using full source row counts, and also bounds the rewritten solver's
active-row signed products. No lower-bound threshold/early-exit shortcut is
exposed: each successful call performs the native transport solve. Invalid
input raises `OpenCV_Error`; the native scalar and flow are published only
after success.

## Geometry is a separate module

OpenCV 5 moved a substantial set of computational geometry APIs out of Imgproc
into a distinct native Geometry module. The Ada bindings follow that conceptual
boundary rather than keeping version-dependent ownership in Imgproc.

Use [`opencv_geometry_ada`](https://github.com/zackboll/opencv_geometry_ada)
for:

```text
Contour_Area
Arc_Length
Compute_Moments
```

and future contour/point geometry operations. Geometry-owned
transform-construction and computational-geometry APIs are intentionally
provided by `opencv_geometry` rather than this crate.

The crates remain independent at the Ada level:

```text
                 opencv_core
                 /         \
                /           \
       opencv_imgproc    opencv_geometry
```

Both define `Contour` as a subtype of `OpenCV.Point_Array`, so a contour
returned by `Find_Contours` can be passed directly to `OpenCV.Geometry`
without copying or conversion.

Imgproc does **not** depend on Geometry.

---

## Architecture

### Public Ada layer

`OpenCV.Image_Processing` is the normal application API.

The layer provides:

- operation-specific enums and constrained subtypes;
- semantic validation before native calls;
- `OpenCV.Core.Mat` input/output values;
- Ada-owned contour structures;
- Ada exceptions instead of status-code handling.

The public package does not expose:

- `cv::Mat`;
- C++ references or pointers;
- STL types;
- C++ exceptions;
- C ABI status values;
- `Interfaces.C` types;
- raw Core handles.

### Private Ada C interop

`OpenCV.Image_Processing.Internal.C_API` contains the fixed-width types,
selectors, status codes, and imports used to call the shim.

It is an implementation layer rather than the intended application API.

### C ABI / C++ shim

The C++ shim exports a small `extern "C"` surface.

Current groups are:

```text
cvt_color
resize
gaussian_blur
get_gaussian_kernel
get_derivative_kernels
pyr_down
pyr_up
median_blur
box_blur
bilateral_filter
filter_2d
erode
dilate
morphology_ex
canny
sobel
scharr
laplacian
threshold
automatic_threshold
adaptive_threshold
find_contours
contour result access/destruction
last_error_message
```

The ABI uses:

- opaque Core `Mat` handles;
- an opaque contour-result handle;
- fixed-width integers;
- `double`;
- a simple signed `int32_t` point record;
- integer selector constants.

No C++ object is passed by value across the boundary.

---

## Cross-module Mat interoperability

Imgproc does not create a second public matrix abstraction. Applications use
`OpenCV.Core.Mat` everywhere.

For a native Imgproc operation, the Ada layer enters callback-scoped Core
interop:

```text
OpenCV.Core.Module_Interop.With_Input_Handle
OpenCV.Core.Module_Interop.With_Output_Handle
```

The Imgproc C++ shim includes Core's installed/internal module bridge and
resolves those opaque handles to borrowed native `cv::Mat` headers for the
duration of the operation.

Important properties:

- Core remains responsible for `Mat` ownership;
- Imgproc does not retain or delete the borrowed native header;
- pixel storage is not copied merely to cross the module boundary;
- an output operation can let OpenCV allocate/rebind the destination header;
- temporary external-buffer views that are unsafe to rebind are rejected by
  Core's output-handle path;
- the module bridge is an implementation interface, not a public raw-pointer API.

This bridge is why the Imgproc shim legitimately depends on the Core shim on
platforms where the shims are shared libraries.

---

## Safety and error handling

The project uses two validation layers deliberately.

### Ada semantic validation

The thick Ada API checks conditions such as:

- empty versus nonempty matrices;
- dimensionality;
- depth and channel constraints;
- output size;
- odd/positive kernel rules;
- derivative depth compatibility;
- finite scales, offsets, sigmas, biases, and thresholds;
- threshold ordering;
- unsupported `Wrap` borders;
- contour indices.

Invalid public calls raise:

```ada
OpenCV.OpenCV_Error
```

before an Imgproc operation is invoked where practical.

### C ABI validation

The C++ shim independently checks raw primitive and selector values. This is
important because the ABI could be called by code other than the thick Ada
layer.

Examples covered by tests include malformed:

- interpolation selectors;
- morphology operations/shapes;
- nonpositive morphology dimensions/iterations;
- derivative selectors/orders;
- adaptive-threshold inputs;
- contour retrieval/approximation selectors.

### Exception containment

The shim catches:

```text
cv::Exception
std::exception
all other C++ exceptions
```

and translates them into stable status values plus a thread-local diagnostic
message.

No C++ exception unwinds into Ada.

The error-message buffer is fixed-size and thread-local, avoiding allocation as
part of the basic error-reporting path.

---

## OpenCV compatibility and platform model

OpenCV is discovered through pkg-config using these package names, in order:

```text
opencv5
opencv4
opencv
```

On macOS, the configuration script also knows about the MacPorts OpenCV 4
pkg-config layout when the ordinary search fails.

The public Ada API is not selected by OpenCV version.

### Current CI matrix

| Platform | OpenCV path | C++ compiler/runtime | Imgproc shim |
| --- | --- | --- | --- |
| Ubuntu 24.04 x86_64 | distribution OpenCV 4.x | GNU `g++` / `libstdc++` | static-PIC |
| macOS ARM64 | Homebrew OpenCV 5.x | Apple `clang++` / `libc++` | relocatable dylib |
| Windows x86_64/MSYS2 | MSYS2 OpenCV 5.x | MSYS2 MinGW64 `g++` | external DLL/import library |

The cross-platform workflow builds and runs the full Imgproc test suite. Which
targets run depends on the event:

| Event | Linux | macOS | Windows/MSYS2 |
| --- | --- | --- | --- |
| pull request opened or updated | runs | runs | skipped |
| push to `main` (after merge) | runs | runs | runs |
| `workflow_dispatch` (manual) | runs | runs | runs |

Pushes to feature branches do not trigger a separate run; review uses the
pull-request run. Windows is therefore not a pull-request gate and is verified
after merge, or on demand through manual dispatch.

### macOS runtime isolation

Homebrew OpenCV is compiled with Apple Clang/libc++. The Imgproc shim therefore
uses Apple `clang++`, not the GNAT toolchain's `g++`.

CI verifies that the dylib reaches:

```text
libopencv_imgproc
libopencv_core
libopencv_core_shim
libc++
```

and does not depend on `libstdc++`.

The Core shim dependency is intentional: Imgproc uses Core's native `Mat`
bridge.

### Windows runtime isolation

On Windows the shim is built externally with the MSYS2 MinGW64 C++ compiler
from the same installation prefix as OpenCV.

The build produces:

```text
lib/libopencv_imgproc_shim.dll
lib/libopencv_imgproc_shim.dll.a
obj/shim/external/opencv_imgproc_shim.o
```

CI verifies:

- the selected C++ compiler is MSYS2 MinGW64 `g++`, not GNAT-FSF `g++`;
- the DLL directly imports OpenCV Imgproc;
- the DLL directly imports `libopencv_core_shim.dll`;
- the OpenCV Imgproc runtime reaches native OpenCV Core;
- the test executable can resolve Imgproc, Core, and MSYS2 runtime DLLs.

---

## Requirements

A normal development build requires:

- **Alire**;
- a GNAT/GPRbuild toolchain supported by the project;
- a C++17 compiler;
- **pkg-config**;
- OpenCV development headers and libraries containing Imgproc and Core;
- `opencv_core_ada`.

The cross-platform CI currently uses:

```text
Alire      2.1.1
GNAT       16.1.0
GPRbuild   26.0.1
```

Those versions make CI reproducible; they are not intended as a statement that
no other compatible versions can work.

The project compiles Ada and C++ with warnings promoted to errors. The C++ shim
uses:

```text
-std=c++17
-Wall
-Wextra
-Wpedantic
-Werror
```

with the narrow Apple Clang exception needed for OpenCV headers that use the C11
`_Atomic` extension.

---

## Building from source

The current development manifest pins Core as a sibling directory:

```toml
[[pins]]
opencv_core = { path='../core' }
```

Use this checkout layout:

```text
workspace/
├── core/
└── imgproc/
```

For example:

```sh
mkdir opencv-ada
cd opencv-ada

git clone https://github.com/zackboll/opencv_core_ada.git core
git clone https://github.com/zackboll/opencv_imgproc_ada.git imgproc

cd imgproc
alr -n build
```

The root Alire pre-build action runs:

```text
scripts/configure_opencv.sh
```

which discovers OpenCV and generates local GPR configuration before the build.

### Linux

Install the OpenCV development package and basic native build tools. On
Ubuntu/Debian this is typically:

```sh
sudo apt-get update
sudo apt-get install -y build-essential libopencv-dev pkg-config
```

Then:

```sh
alr -n build
alr -n -C tests run
```

### macOS

Homebrew:

```sh
brew install opencv
```

If pkg-config does not already see the Homebrew formula, make its metadata
visible:

```sh
export PKG_CONFIG_PATH="$(brew --prefix)/lib/pkgconfig:$(brew --prefix opencv)/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
```

Then:

```sh
alr -n build
alr -n -C tests run
```

The configuration script selects Apple `clang++` and the macOS SDK
automatically.

### Windows / MSYS2

The CI-supported Windows configuration uses Alire's MSYS2 environment and these
packages:

```text
mingw-w64-x86_64-opencv
mingw-w64-x86_64-pkg-config
mingw-w64-x86_64-gcc
```

The configuration script prefers:

```text
x86_64-w64-mingw32-pkg-config
```

so it does not accidentally resolve an unrelated Windows `pkg-config`
installation.

It then selects the MinGW64 `g++` located beside the OpenCV installation,
builds an external Imgproc shim DLL, and links it to the Core bridge import
library supplied by the `opencv_core` dependency.

---

## Running the tests

Tests are a separate Alire crate:

```sh
alr -n -C tests run
```

or:

```sh
alr -C tests build
alr -C tests run
```

The test crate carries development-only dependencies:

```text
AUnit
GNATprove
GNATcov
```

They are not production dependencies of `opencv_imgproc`.

### Current test distribution

The current **837-test** distribution is:

| Suite | Tests |
| --- | ---: |
| Color conversion | 14 |
| Resize | 10 |
| Gaussian blur | 10 |
| Gaussian kernel | 8 |
| Derivative kernels | 10 |
| Image pyramids | 18 |
| Pyramid construction (Gaussian / Laplacian) | 18 |
| Template matching | 10 |
| Affine warping | 13 |
| Perspective warping | 13 |
| Remapping | 22 |
| Polar transforms | 9 |
| Median blur | 10 |
| Box blur | 11 |
| Bilateral filter | 10 |
| Filter 2D | 12 |
| Sep Filter 2D | 12 |
| Laplacian | 9 |
| Morphology | 32 |
| Hit-or-Miss morphology | 25 |
| Canny | 5 |
| Sobel / Scharr derivatives | 11 |
| Fixed threshold | 7 |
| Automatic threshold | 4 |
| Adaptive threshold | 6 |
| Histogram equalization | 12 |
| CLAHE | 9 |
| Contours | 7 |
| Contour drawing and filling | 6 |
| Connected components | 6 |
| Drawing | 11 |
| Drawing annotations | 14 |
| Hough detection | 37 |
| Segmentation (flood fill, watershed, GrabCut) | 35 |
| Mean-shift filtering | 16 |
| Histogram analysis (calculation, comparison, back projection, accumulation) | 39 |
| Earth mover distance | 13 |
| Distance transform | 6 |
| Integral images | 7 |
| Corner analysis and subpixel regressions | 23 |
| Image accumulation and running statistics | 44 |
| Phase correlation and Hanning windows | 25 |
| Kernel generators (Gabor and structuring elements) | 25 |
| Packed BGR565 / BGR555 conversions | 31 |
| Extended FULL hue, linear-light Lab/Luv, premultiplied RGBA | 37 |
| Bayer demosaicing | 43 |
| YUV 4:2:0 frame conversions | 50 |
| Packed YUV 4:2:2 decode and luma | 32 |
| **Total** | **837** |


The suite covers more than simple success paths. It includes:

- exact-value checks;
- source-preservation checks;
- destination rebinding;
- in-place behavior where supported;
- multi-channel independence;
- all supported interpolation/morphology/threshold selectors;
- supported numeric depth combinations;
- invalid matrix geometry/depth/channel combinations;
- non-finite parameter rejection;
- malformed raw C ABI selectors and primitive values;
- contour retrieval and approximation modes;
- contour hierarchy and signed offsets;
- contour source preservation and empty results.

GitHub Actions runs the test crate on Linux and macOS for pull requests, and
additionally on Windows for `main` pushes and manual dispatch.

---

## Reusable kernel generators

All generators return fresh owning `OpenCV.Core.Mat` values:

| Generator | Result and consumer |
|---|---|
| `Get_Gaussian_Kernel` | Gaussian column coefficients for `Sep_Filter_2D` |
| `Get_Derivative_Kernels` | Sobel-family X/Y pair for `Sep_Filter_2D` |
| `Get_Scharr_Kernels` | Scharr X/Y pair for `Sep_Filter_2D` |
| `Get_Gabor_Kernel` | 2-D Float32/Float64 C1 coefficients for `Filter_2D` |
| `Get_Structuring_Element` | UInt8 C1 mask for `Erode`, `Dilate`, `Apply_Morphology` |

`Get_Gabor_Kernel (Kernel_Size, Sigma, Orientation_Radians, Wavelength,
Aspect_Ratio, Phase_Offset_Radians, Depth)` requires **positive odd width and
height**, guaranteeing exact requested geometry. Native automatic sizing is
not exposed: zero/negative dimensions are not sentinels. Sigma is Gaussian
envelope standard deviation, Wavelength is sinusoid wavelength, Aspect_Ratio
is spatial aspect ratio (native gamma), and orientation and phase are finite
**radians**. Phase defaults to pi/2. Sigma, wavelength and aspect ratio must
be finite and strictly positive; angles are not normalized. Depth defaults
to `Float64_Kernel`, with `Float32_Kernel` also supported through the
`Gabor_Kernel_Depth` subtype. Invalid public inputs raise `OpenCV_Error`.

Coefficients are neither normalized nor transposed/reversed by Ada. Native
coordinates (x,y) are stored at (height/2-y,width/2-x), preserving OpenCV's
180-degree coordinate reversal, including its phase consequence. Extreme
finite parameters may produce nonfinite coefficients through native derived
IEEE arithmetic; no arbitrary numerical cutoff is imposed.

`Get_Structuring_Element (Kernel_Size, Shape)` uses the centered anchor
(width/2,height/2). Its explicit-anchor overload requires an anchor inside
the kernel and exposes no negative sentinel. Positive dimensions may be
even. The existing `Morphology_Shape` remains exactly `Rectangle`, `Cross`,
`Ellipse`. Output values are **0/1**, never scaled to 255. Rectangle/Ellipse
geometry ignores the generating anchor; Cross geometry includes its row and
column. Mats retain no anchor metadata: pass the intended explicit anchor
again when applying an off-center Cross. Size (1,1) always yields Rectangle,
even when Cross or Ellipse was requested. OpenCV-5-only `MORPH_DIAMOND` is
deliberately excluded for OpenCV 4 portability.

Native allocation and signed arithmetic limits raise `OpenCV_Error` before
unsafe native work. In particular Ellipse's signed radius-square arithmetic
limits height to 92681 on the 32-bit-int ABI; Rectangle/Cross do not share
that restriction. See [the pinned source review](docs/kernel-generators-source-review.md)
for OpenCV 4.1/4.10/5.0 differences, formulas and safety reasoning.

The kernel-generator slice registered and passed **619 tests** (baseline 594,
25 new kernel-generator tests), including direct filtering and morphology
integration. Local runtime validation uses OpenCV 4.10.0; 4.1.0 and 5.0.0
were source-reviewed, not runtime-tested locally.

The packed-color slice adds 31 focused tests, bringing the complete suite to
**650 registered, executed and passed tests** from baseline 619.

The extended-color slice adds **37 focused tests** from baseline 650:
**687 registered, 687 executed, 687 passed**, zero failed assertions and
zero unexpected errors. Local execution used OpenCV 4.10.0 and a clean detached
Core checkout. Strict Ada compilation includes `-gnatwa -gnatwc -gnatwu
-gnatwn -gnatwe -gnatyM79 -Werror`; C++ uses `-Wall -Wextra -Wpedantic -Werror`.
GNATformat, direct 79-column checks of modified Ada, and `git diff --check`
passed. Normal Alire deployment was blocked by the machine's `pkg-config`
sudo issue; configure scripts and Alire-managed GNAT/GPRbuild were used without
changing production dependencies. GNATprove/coverage were not run for this
non-SPARK, foreign-boundary slice.

## Examples

These examples assume Core and Imgproc are both available to the application.

### BGR to grayscale

```ada
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;

procedure Gray_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));

   Gray : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
begin
   OpenCV.Core.UInt8_Vec3_Access.Set
     (Source, Row => 0, Column => 0, Value => (10, 20, 30));

   OpenCV.Image_Processing.Convert_Color
     (Source,
      Gray,
      OpenCV.Image_Processing.BGR_To_Gray);

   -- Gray is now a UInt8 C1 Mat with Source's 2x2 geometry.
   pragma Assert
     (OpenCV.Core.UInt8_Access.Get (Gray, 0, 0) = 22);
end Gray_Example;
```

### Gaussian blur

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Blur_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.UInt8, 3));

   Blurred : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
begin
   OpenCV.Image_Processing.Gaussian_Blur
     (Source      => Source,
      Destination => Blurred,
      Kernel_Size => (Width => 5, Height => 5),
      Sigma       => 1.2);
end Blur_Example;
```

### Gaussian kernel with Sep_Filter_2D

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Gaussian_Kernel_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.Float32, 1));

   Kernel : constant OpenCV.Core.Mat :=
     OpenCV.Image_Processing.Get_Gaussian_Kernel
       (Kernel_Size => 5,
        Sigma       => 1.2,
        Depth       => OpenCV.Image_Processing.Float32_Kernel);

   Filtered : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
begin
   OpenCV.Image_Processing.Sep_Filter_2D
     (Source      => Source,
      Destination => Filtered,
      Kernel_X    => Kernel,
      Kernel_Y    => Kernel);
end Gaussian_Kernel_Example;
```

### Derivative kernels with Sep_Filter_2D

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Derivative_Kernel_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.Float32, 1));

   Kernels : constant OpenCV.Image_Processing.Derivative_Kernels :=
     OpenCV.Image_Processing.Get_Derivative_Kernels
       (X_Order     => 1,
        Y_Order     => 0,
        Kernel_Size => OpenCV.Image_Processing.Kernel_3);

   Filtered : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
begin
   OpenCV.Image_Processing.Sep_Filter_2D
     (Source            => Source,
      Destination       => Filtered,
      Kernel_X          => Kernels.Kernel_X,
      Kernel_Y          => Kernels.Kernel_Y,
      Destination_Depth => OpenCV.Image_Processing.Float32_Depth);
end Derivative_Kernel_Example;
```

### Image pyramids

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Pyramid_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.UInt8, 3));

   Small          : OpenCV.Core.Mat;
   Restored_Size  : OpenCV.Core.Mat;
begin
   OpenCV.Image_Processing.Pyramid_Down (Source, Small);
   OpenCV.Image_Processing.Pyramid_Up (Small, Restored_Size);
end Pyramid_Example;
```

`Restored_Size` has Source's original geometry, but the reconstruction is
smoothed rather than identical to Source.

### Box blur

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Box_Blur_Example is
   Input : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.UInt8, 3));

   Output : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
begin
   OpenCV.Image_Processing.Box_Blur
     (Source      => Input,
      Destination => Output,
      Kernel_Size => (Width => 3, Height => 3));
end Box_Blur_Example;
```

### Bilateral filter

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Bilateral_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.UInt8, 3));

   Filtered : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
begin
   OpenCV.Image_Processing.Bilateral_Filter
     (Source      => Source,
      Destination => Filtered,
      Diameter    => 9,
      Sigma_Color => 75.0,
      Sigma_Space => 75.0);
end Bilateral_Example;
```

### Filter 2D correlation

```ada
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Image_Processing;

procedure Filter_2D_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));

   Kernel : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));

   Filtered : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
begin
   OpenCV.Core.Float32_Access.Set (Kernel, 0, 0, 1.0);
   OpenCV.Core.Float32_Access.Set (Kernel, 0, 1, 2.0);
   OpenCV.Core.Float32_Access.Set (Kernel, 0, 2, 4.0);

   OpenCV.Image_Processing.Filter_2D
     (Source      => Source,
      Destination => Filtered,
      Kernel      => Kernel);
end Filter_2D_Example;
```

The kernel is applied as correlation, not convolution.

### Separable Filter 2D

```ada
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Image_Processing;

procedure Sep_Filter_2D_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));

   Kernel_X : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 3, (OpenCV.Core.Float32, 1));

   Kernel_Y : OpenCV.Core.Mat :=
     OpenCV.Core.Create (3, 1, (OpenCV.Core.Float32, 1));

   Filtered : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
begin
   OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 0, 1.0);
   OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 1, 2.0);
   OpenCV.Core.Float32_Access.Set (Kernel_X, 0, 2, 4.0);
   OpenCV.Core.Float32_Access.Set (Kernel_Y, 0, 0, 1.0);
   OpenCV.Core.Float32_Access.Set (Kernel_Y, 1, 0, 3.0);
   OpenCV.Core.Float32_Access.Set (Kernel_Y, 2, 0, 5.0);

   OpenCV.Image_Processing.Sep_Filter_2D
     (Source      => Source,
      Destination => Filtered,
      Kernel_X    => Kernel_X,
      Kernel_Y    => Kernel_Y);
end Sep_Filter_2D_Example;
```

Rows are filtered by `Kernel_X`, then columns by `Kernel_Y`.

### Sobel derivative

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Sobel_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.UInt8, 1));

   Dx : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
begin
   OpenCV.Image_Processing.Sobel
     (Source            => Source,
      Destination       => Dx,
      X_Order           => 1,
      Y_Order           => 0,
      Destination_Depth => OpenCV.Image_Processing.Int16_Depth,
      Kernel_Size       => OpenCV.Image_Processing.Kernel_3);
end Sobel_Example;
```

Using a signed derivative destination avoids losing negative gradients from an
unsigned source.

### Adaptive threshold

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Adaptive_Threshold_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (480, 640, (OpenCV.Core.UInt8, 1));

   Binary : OpenCV.Core.Mat :=
     OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
begin
   OpenCV.Image_Processing.Apply_Adaptive_Threshold
     (Source        => Source,
      Destination   => Binary,
      Block_Size    => 11,
      Method        => OpenCV.Image_Processing.Gaussian,
      Mode          => OpenCV.Image_Processing.Binary,
      Bias          => 2.0,
      Maximum_Value => 255);
end Adaptive_Threshold_Example;
```

### Histogram equalization

```ada
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Histogram_Equalization_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));

   Equalized : OpenCV.Core.Mat;
begin
   OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 10);
   OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 20);
   OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 30);
   OpenCV.Core.UInt8_Access.Set (Source, 1, 0, 30);
   OpenCV.Core.UInt8_Access.Set (Source, 1, 1, 40);
   OpenCV.Core.UInt8_Access.Set (Source, 1, 2, 40);

   OpenCV.Image_Processing.Equalize_Histogram (Source, Equalized);
end Histogram_Equalization_Example;
```

### Find contours

```ada
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Contour_Example is
   Source : OpenCV.Core.Mat :=
     OpenCV.Core.Create (100, 100, (OpenCV.Core.UInt8, 1));

   Contours : OpenCV.Image_Processing.Contour_Set;
begin
   OpenCV.Core.Set_To (Source, (others => 0.0));

   -- Draw a small foreground block for the example.
   for Row in 20 .. 40 loop
      for Column in 30 .. 60 loop
         OpenCV.Core.UInt8_Access.Set
           (Source, Row, Column, 255);
      end loop;
   end loop;

   Contours :=
     OpenCV.Image_Processing.Find_Contours
       (Source,
        Retrieval     => OpenCV.Image_Processing.External_Only,
        Approximation => OpenCV.Image_Processing.Simple);

   if OpenCV.Image_Processing.Contour_Count (Contours) > 0 then
      declare
         Shape : constant OpenCV.Image_Processing.Contour :=
           OpenCV.Image_Processing.Get_Contour (Contours, 0);
      begin
         -- Shape is an Ada OpenCV.Point_Array.
         null;
      end;
   end if;
end Contour_Example;
```

### Use an Imgproc contour with Geometry

If the application also depends on `opencv_geometry`:

```ada
with OpenCV.Geometry;
with OpenCV.Image_Processing;

--  ...
declare
   Shape : constant OpenCV.Image_Processing.Contour :=
     OpenCV.Image_Processing.Get_Contour (Contours, 0);

   Area : constant OpenCV.Float64_Value :=
     OpenCV.Geometry.Contour_Area (Shape);
begin
   null;
end;
```

No conversion is needed because both packages use
`OpenCV.Point_Array`.

---

## Project layout

```text
opencv_imgproc_ada/
├── alire.toml
├── opencv_imgproc.gpr
├── opencv_imgproc_shim.gpr
├── LICENSE
│
├── src/
│   ├── opencv-image_processing.ads
│   ├── opencv-image_processing.adb
│   └── internal/
│       ├── opencv-image_processing-internal.ads
│       ├── opencv-image_processing-internal-c_api.ads
│       └── opencv-image_processing-internal-c_api.adb
│
├── cpp/
│   ├── opencv_imgproc_shim.h
│   └── opencv_imgproc_shim.cpp
│
├── scripts/
│   ├── configure_opencv.sh
│   └── build_opencv_shim.sh
│
├── tests/
│   ├── alire.toml
│   ├── tests.gpr
│   └── src/
│       ├── color_conversion_tests.*
│       ├── resize_tests.*
│       ├── gaussian_blur_tests.*
│       ├── gaussian_kernel_tests.*
│       ├── derivative_kernel_tests.*
│       ├── pyramid_tests.*
│       ├── pyramid_construction_tests.*
│       ├── template_matching_tests.*
│       ├── warp_affine_tests.*
│       ├── warp_perspective_tests.*
│       ├── remap_tests.*
│       ├── median_blur_tests.*

│       ├── box_blur_tests.*
│       ├── bilateral_filter_tests.*
│       ├── filter_2d_tests.*
│       ├── sep_filter_2d_tests.*
│       ├── morphology_tests.*
│       ├── canny_edge_tests.*
│       ├── spatial_derivative_tests.*
│       ├── laplacian_tests.*
│       ├── threshold_tests.*
│       ├── automatic_threshold_tests.*
│       ├── adaptive_threshold_tests.*
│       ├── histogram_equalization_tests.*
│       ├── clahe_tests.*
│       ├── contour_tests.*
│       ├── drawing_tests.*
│       ├── connected_component_tests.*
│       └── tests.adb
│
└── .github/
    └── workflows/
        └── cross-platform.yml
```

The repository also carries `.clinerules/` project guidance used during
development.

Generated `config/`, object directories, Alire state, and built libraries are
not source artifacts.

---

## Image accumulation and running statistics

These are **image/pixel accumulators**, distinct from dense histogram
`Accumulate_Histogram`, which collects bin counts from new samples.

```ada
function Accumulate_Image
  (Source, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;
function Accumulate_Image_Square
  (Source, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;
function Accumulate_Image_Product
  (Source_1, Source_2, Base : OpenCV.Core.Mat) return OpenCV.Core.Mat;
function Update_Running_Average
  (Source, Base : OpenCV.Core.Mat; Weight : OpenCV.Float64_Value)
   return OpenCV.Core.Mat;
```

Each has an overload accepting `Mask` after `Base` (before `Weight` for the
running average). Unmasked calls need no empty/null public Mat. The formulas
at each enabled pixel/channel are respectively `Base + Source`,
`Base + Source*Source`, `Base + Source_1*Source_2`, and
`(1-Weight)*Base + Weight*Source`.

### Portable source/accumulator depth matrix

| Source depth | Plain: Float32 Base | Plain: Float64 Base | Square/product/weighted: Float32 or Float64 Base |
| --- | --- | --- | --- |
| UInt8 | yes | yes | yes |
| UInt16 | yes | yes | no (outside shared documented contract) |
| Float32 | yes | yes | yes |
| Float64 | **no** | yes | no (outside shared documented contract) |
| Other depths | no | no | no |

Plain accumulation permits any Core-supported positive channel count.
Square, product, and weighted accumulation permit **C1 or C3 only**. Base
must have the source's channel count. Product sources must have identical
depth and channels. These deliberately documented contracts apply across
OpenCV **4.1.0, 4.10.0, and 5.0.0**; broader internal dispatch handlers do
not expand the public contract.

Every source, Base, and supplied Mask must be **nonempty, 2-D**, with identical
rows and columns. Mask must be **UInt8 C1**; zero leaves the entire Base pixel
unchanged, and **any nonzero value** enables all channels at that pixel.
Mask is read-only. OpenCV 5's Bool-mask extension is not exposed.

`Weight` must be finite and in **0.0 .. 1.0**. NaN, either infinity, and
out-of-range weights are rejected. Zero retains a finite Base and one uses
source-converted values; intermediate weights control forgetting speed.
Otherwise valid floating arithmetic follows native OpenCV, including IEEE
overflow to infinity. There is no saturation or whole-image finiteness scan.
Public contract violations and native failures raise `OpenCV.OpenCV_Error`.

### Atomic results, Regions, and aliases

All four functions return **fresh independent storage**: the native shim
clones Base into a private working accumulator, calls OpenCV on that clone,
and publishes it only after complete success. Source(s), Base, and Mask are
unchanged on success and failure. Normal Core shallow-copy semantics still
apply to subsequent Ada assignments of the returned Mat.

A Region contributes **exactly its logical pixels**, not parent contents.
A Base Region becomes a packed independent result, not an updated parent
view. Source Regions and Mask Regions are read only within their logical
geometry. Same-Mat source/base, distinct headers sharing or overlapping
storage, self-product, and UInt8 source/mask sharing are supported without
depending on native iteration order. As with other Core operations, callers
must not concurrently mutate borrowed inputs during execution.

```ada
Accumulator := Accumulate_Image (Frame, Accumulator);
Squared := Accumulate_Image_Square (Frame, Squared, Selection);
Cross_Product := Accumulate_Image_Product (Frame, Previous, Cross_Product);
Background := Update_Running_Average (Frame, Background, Weight => 0.25);
```

The shim preflights signed native plane/channel indexing, IPP stride and
flattened byte counts, and packed working row size. Conservative limits are
INT_MAX pixels, channel scalars, bytes, and nonempty input strides. Older
OpenVX computes signed `width*height` before declining floating accumulators;
that probe is guarded too. Mat inputs exclude OpenCL; public floating types
exclude OpenVX's integer accumulator kernels. IPP remains enabled after
preflight. OpenCV 5 removes OpenVX accumulation and adds Bool masks; the
portable public contract is unchanged. See the full
[pinned source and validation-boundary review](docs/image-accumulation-source-review.md).

## Integral images

`Integral_Sum (Source, Sum_Depth)` returns a fresh `OpenCV.Core.Mat` containing
the summed-area table. `Integral_Sum_And_Squares (Source, Sum_Depth,
Squared_Depth)` returns `Integral_Sum_And_Squares_Result` with owning `Sum` and
`Squared_Sum` Mats; `Integral_Images` returns `Integral_Images_Result` with
`Sum`, `Squared_Sum`, and `Tilted_Sum`. All results preserve Source's channel
count, accumulate **each channel independently**, and have `(Rows + 1) x
(Columns + 1)` geometry. Row zero and column zero of Sum and Squared_Sum are
zero. `Sum(X,Y)` adds source pixels at `x < X, y < Y`; `Squared_Sum(X,Y)` adds
`source(x,y) * source(x,y)`. The tilted sum follows OpenCV's 45-degree rule:
`Tilted_Sum(X,Y)` adds pixels with `y < Y` and
`abs(x - X + 1) <= Y - y - 1`. Tilted has the same depth as Sum.

Supported sources: `UInt8`, `Float32`, `Float64` (not the undocumented native
`UInt16`/`Int16` dispatch cases). Supported selections:

| Source | Sum alone | Sum + Squared_Sum pairs |
| --- | --- | --- |
| UInt8 | Int32, Float32, Float64 | Int32/Float32, Int32/Float64, Float32/Float32, Float32/Float64, Float64/Float64 |
| Float32 | Float32, Float64 | Float32/Float32, Float32/Float64, Float64/Float64 |
| Float64 | Float64 | Float64/Float64 |

Use the Ada selectors `Int32_Integral`, `Float32_Integral`,
`Float64_Integral`, `Float32_Squared_Integral`, and
`Float64_Squared_Integral`. All three calls default to Float64 Sum (and
Float64 Squared_Sum where present), unlike OpenCV's raw default which chooses
Int32 for UInt8. This predictable default avoids signed accumulator overflow
for large UInt8 images. Explicit UInt8 -> Int32 is rejected if the **actual
total of any channel** exceeds INT_MAX, including Regions. Floating results
follow the selected accumulator's precision and normal IEEE rounding,
Infinity, overflow, and NaN propagation; there is no finite-value scan.

Source is unchanged. A non-contiguous `Region` is its own logical image: no
pixels outside the view participate. Public invalid source/depth combinations
raise `OpenCV.OpenCV_Error`. The native boundary additionally guards signed
`rows+1`, `cols+1`, channel-expanded width and tilted scratch indexing, and
source/output element strides before calling OpenCV. Scalar integral code
narrows element strides to `int`. Some optional C1 IPP paths additionally cast
the original source and output **byte** strides directly to `int`; the binding
checks the real source row step and derived Sum/Squared_Sum byte strides only
for configurations that can reach those IPP branches. Multi-channel and
tilted paths bypass native IPP and retain the broader scalar-safe bounds.
IPP is not required. All outputs are computed locally and their Core Mat
headers rebound only after complete success.

For a C1 Float64 integral result, an axis-aligned rectangle `[x1,x2) x
[y1,y2)` takes four reads (zero-based matrix row, column):

```ada
declare
   Sum : constant OpenCV.Core.Mat := Integral_Sum (Source);
   function S (X, Y : Natural) return OpenCV.Float64_Value is
     (OpenCV.Core.Float64_Access.Get (Sum, Y, X));
   Rectangle_Total : constant OpenCV.Float64_Value :=
     S (X2, Y2) - S (X1, Y2) - S (X2, Y1) + S (X1, Y1);
begin
   --  Use Rectangle_Total.
   null;
end;
```

The example assumes `Source`, `X1`, `X2`, `Y1`, and `Y2` are declared and
`with OpenCV.Core.Float64_Access;` is present. No rectangle helper is added.

## Distance transforms

`Distance_Transform (Source, Method)` accepts a nonempty 2-D `UInt8` C1
foreground mask containing at least one zero pixel. Zero means target/background;
**any** nonzero value means foreground (1 and 255 behave alike). It returns a
fresh `Float32` C1 Mat with the same dimensions. The default method is
`Euclidean_Precise`. Choose `Manhattan_Distance` for |dx| + |dy|,
`Chessboard_Distance` for max(|dx|, |dy|), `Euclidean_3x3` for the fast
OpenCV-weighted approximation (axis weight about 0.955), `Euclidean_5x5` for
the more accurate weighted approximation, or `Euclidean_Precise` for precise
Euclidean distances (subject to Float32 rounding). L1 and chessboard need no
5x5 selection: it produces the same values. Zero pixels return distance zero.
`Manhattan_Distance_Transform_UInt8 (Source)` returns `UInt8` C1 L1 distances
instead, **saturating at 255**. There is no UInt8 Euclidean option.

`Distance_Transform_With_Labels (Source, Metric, Labels)` returns a record with
fresh owning `Distances : Float32 C1` and `Labels : Int32 C1` Mats. The metric
is `Manhattan_Label_Distance`, `Euclidean_Label_Distance` (default), or
`Chessboard_Label_Distance`. `Nearest_Zero_Component` (default) gives each
8-connected zero component a positive label; `Nearest_Zero_Pixel` gives each
zero pixel its own positive label in row-major scan order. Other pixels get a
nearest target's label; equidistant ties are unspecified. OpenCV forces labeled
transforms through its **5x5 approximate** propagation implementation; precise
Euclidean and mask-size selection are deliberately unavailable with labels.

All variants leave Source unchanged. An OpenCV.Core `Region` is processed as a
standalone logical image; pixels outside it do not participate. An all-zero
image produces zero distances. An all-nonzero image is rejected with
`OpenCV_Error`, because the target set is empty and native sentinel values
differ between algorithms/releases. The shim also guards the native signed-int
step, row-offset, padded-temporary and pixel-count arithmetic. On 4.1-compatible
precise transforms its signed `i*i` table construction limits each extent to
46341 pixels (maximum index 46340); `3*rows+1` and `2*columns` must also fit
signed int. Large/noncontiguous Region parent strides can be rejected even
when the Region itself is small.

OpenCV 5 moved the general `DistanceTypes` enum to Geometry, but Imgproc's
`distanceTransform` retains the same integer metric selectors. The shim keeps
private L1/L2/C selector constants so `opencv_imgproc` remains independent of
the Geometry module.

For segmentation, a typical pipeline is a binary foreground mask, then
`Distance_Transform`, then `Apply_Threshold` on the Float32 distance map to
select confident peaks, then `Connected_Components_With_Stats` on a UInt8
peak mask to obtain regions/markers for `Watershed`. Convert the thresholded
peaks to UInt8 explicitly: the threshold operation preserves Float32 depth.
This crate does not yet provide a watershed-marker construction helper.

For a discrete Voronoi map:

```ada
Voronoi : constant Labeled_Distance_Transform_Result :=
  Distance_Transform_With_Labels
    (Source, Euclidean_Label_Distance, Nearest_Zero_Pixel);
--  Voronoi.Distances is Float32 C1; Voronoi.Labels is Int32 C1.
```

## Current limitations and roadmap


The current implementation has a mature safety/build architecture but is still
a **focused subset** of OpenCV Imgproc. Version `0.1.0-dev` should be treated as
pre-1.0.

Notable Imgproc families that are not yet broadly bound include:

- YUV 4:2:2 encoding remains deferred because it is unavailable in the
  OpenCV 4.1 portability baseline; planar and higher-bit-depth YUV422
  representations also remain outside the portable packed decoder;
- deferred morphology operations: Hit-or-Miss and OpenCV 5-only Diamond;
- relative `WARP_RELATIVE_MAP`, exact interpolation variants, and
  calibration/undistortion map generation in the appropriate module;
- deferred Hough capabilities: multiscale `srn`/`stn`, OpenCV 5 weighted
  (`use_edgeval`) Hough, and `HOUGH_GRADIENT_ALT`;
- deferred segmentation capabilities: flood fill on `Int32` images and
  higher-level distance-transform marker-construction convenience;
- `SparseMat` histograms remain deferred until Core supplies a deliberate
  module-interoperability surface for sparse handles; Imgproc will not
  duplicate Core's SparseMat ownership model;
- EMD's input/output lower-bound threshold shortcut (which can skip the exact
  transport solve) remains deferred;
- custom/user-defined distance masks (not part of the portable foundation);
- custom OpenCV 5 font faces and FreeType/arbitrary font loading;
- `drawFrameAxes` (calibration-dependent);
- subpixel fixed-point drawing;
- alpha blending and arbitrary multi-polygon construction;
- additional shape/image analysis that still belongs specifically to Imgproc.


Computational geometry is **not** considered missing Imgproc functionality in
this project architecture. OpenCV 5 gives those operations a separate native
Geometry module, and the Ada project follows that split through
`opencv_geometry`. Geometry-owned transform-construction and
computational-geometry APIs are intentionally provided by `opencv_geometry`
rather than this crate.

Future features should continue to be added vertically:

```text
public Ada design
    -> semantic validation
    -> private Ada C import
    -> hardened C ABI
    -> C++ OpenCV call
    -> focused AUnit coverage
    -> Linux/macOS/Windows CI
```

---

## Contributing

Changes should preserve the existing module boundaries and ABI rules:

- public APIs should remain Ada-shaped;
- do not expose raw C++ objects or pointers through the public package;
- keep `Mat` ownership in `opencv_core`;
- use the Core module bridge for Imgproc operations that need native `Mat`
  access;
- contain all C++ exceptions in the shim;
- add C ABI validation for malformed primitive inputs/selectors;
- add focused AUnit coverage for success, failure, ownership, and important edge
  cases;
- keep production dependencies separate from test/development dependencies;
- preserve Linux, macOS, and Windows C++ runtime isolation.

Before submitting a change, run:

```sh
alr -n build
alr -n -C tests run
git diff --check
```

For a new feature, prefer a complete vertical slice over a large collection of
thin declarations.

---

## License

Apache License 2.0. See [`LICENSE`](LICENSE).

OpenCV is a separate upstream project and is subject to its own licensing and
trademark terms.