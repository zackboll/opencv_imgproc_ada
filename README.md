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
> **Current registered test baseline:** **343 AUnit tests**

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
- [Color conversion](#color-conversion)
- [Resizing](#resizing)
- [Gaussian blur](#gaussian-blur)
- [Gaussian kernel](#gaussian-kernel)
- [Derivative kernels](#derivative-kernels)
- [Image pyramids](#image-pyramids)
- [Template matching](#template-matching)
- [Affine warping](#affine-warping)
- [Perspective warping](#perspective-warping)
- [Remapping](#remapping)
- [Median blur](#median-blur)

- [Box blur](#box-blur)
- [Bilateral filter](#bilateral-filter)
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

This crate owns **image-processing operations** that conceptually belong to
OpenCV Imgproc and operate primarily on `OpenCV.Core.Mat`.

The current public surface includes:

- BGR-to-grayscale conversion;
- image resize with five interpolation modes;
- Gaussian blur;
- Gaussian kernel generation;
- Sobel and Scharr derivative kernel generation;
- Gaussian pyramid downsampling and upsampling;
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
- in-place drawing of lines, rectangles, circles, ellipses, polylines,
  and polygons;
- contour extraction, hierarchy, and approximation modes.

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

## Current feature set

The table below summarizes the current public operations.

| Area | Public API | Main input requirements | Important behavior |
| --- | --- | --- | --- |
| Color | `Convert_Color` | nonempty 2-D BGR C3; `UInt8`, `UInt16`, or `Float32` | currently `BGR_To_Gray` only |
| Resize | `Resize` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64` | five interpolation modes; preserves depth/channels |
| Filtering | `Gaussian_Blur` | nonempty 2-D; supported numeric depths | positive odd kernel, positive finite sigma |
| Filtering | `Get_Gaussian_Kernel` | odd positive size | automatic or explicit sigma; Float32/Float64 `N x 1` C1 kernel; usable with `Sep_Filter_2D` |
| Derivatives | `Get_Derivative_Kernels`, `Get_Scharr_Kernels` | odd Sobel size 1/3/5/7 or Scharr axis | Float32/Float64 `N x 1` C1 pair; Kernel_1 may differ in X/Y length; usable with `Sep_Filter_2D` |
| Pyramids | `Pyramid_Down`, `Pyramid_Up` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64` | natural half/double size; arbitrary channels; Down accepts Wrap and rejects Constant; Up has no Border; in-place unsupported |
| Matching | `Match_Template` | nonempty 2-D; `UInt8` or `Float32`; C1..C4; matching Source/Template type | Float32 C1 score map; Template must fit in Source; SQDIFF min / others max; Destination must not share input storage |
| Warping | `Warp_Affine` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`; C1..C4 | 2x3 Float32/Float64 C1 Transform; requested Output_Size; Nearest/Linear; Constant/Replicate; Destination must not share input storage |
| Warping | `Warp_Perspective` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`; C1..C4 | 3x3 Float32/Float64 C1 Transform; requested Output_Size; Nearest/Linear; Constant/Replicate; Destination must not share input storage |
| Warping | `Remap` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`; C1..C4; Rows/Columns < 32767 | separate Float32 C1 Map_X/Map_Y; output follows maps; Nearest/Linear/Cubic/Lanczos_4; Area rejected; all public borders; Destination must not share input storage |
| Filtering | `Median_Blur` | nonempty 2-D; 1/3/4 channels | odd kernel >= 3; 3/5: `UInt8`/`UInt16`/`Float32`; >5: `UInt8` only; in-place supported; internal `BORDER_REPLICATE` |

| Filtering | `Box_Blur` | nonempty 2-D; supported numeric depths | positive width/height; even and non-square kernels valid; arbitrary channels; centered anchor; Wrap rejected; in-place supported |
| Filtering | `Bilateral_Filter` | nonempty 2-D; `UInt8` or `Float32`; 1 or 3 channels | automatic or explicit diameter; positive finite sigmas; Wrap rejected; in-place unsupported |
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
| Histogram | `CLAHE` | nonempty 2-D `UInt8`/`UInt16` C1 | local contrast-limited equalization; default clip 40.0 and grid 8x8; same-object in-place supported; other storage-sharing aliases rejected |
| Contours | `Find_Contours` | nonempty 2-D `UInt8` C1 | four retrieval modes, four approximation modes, signed offset |
| Analysis | `Connected_Components_With_Stats` | nonempty 2-D `UInt8` C1 | 4/8-way binary-mask labeling; Int32 C1 labels and Ada-owned foreground statistics |
| Analysis | `Distance_Transform`, `Manhattan_Distance_Transform_UInt8`, `Distance_Transform_With_Labels` | nonempty 2-D `UInt8` C1 with at least one zero | fresh Float32 distances, saturating UInt8 L1, or Float32 distances plus Int32 Voronoi labels |
| Drawing | `Draw_Line`, `Draw_Rectangle`, `Fill_Rectangle`, `Draw_Circle`, `Fill_Circle`, `Draw_Ellipse`, `Fill_Ellipse`, `Draw_Polyline`, `Fill_Polygon` | nonempty 2-D; `UInt8`, `UInt16`, `Int16`, `Float32`, or `Float64`; C1..C4 | in-place; positive geometry; off-image coordinates clipped; antialiasing only for `UInt8`; no alpha blending |
| Hough | `Find_Hough_Lines`, `Find_Hough_Line_Segments` | nonempty 2-D `UInt8` C1 binary image | classical polar lines (radians) and probabilistic integer segments; Ada-owned arrays; source-preserving snapshot |
| Hough | `Find_Hough_Circles` | nonempty 2-D `UInt8` C1 grayscale image | classic `HOUGH_GRADIENT`; automatic or explicit maximum radius; Float32 center/radius; source-preserving snapshot |
| Segmentation | `Flood_Fill`, `Flood_Fill_With_Mask` | nonempty 2-D `UInt8`/`Float32`, C1/C3; mask `UInt8` C1 `(rows + 2) x (cols + 2)` | in place; floating/fixed range; 4/8 connectivity; area and bounds; mask fill value and mask-only mode |
| Segmentation | `Watershed` | `UInt8` C3 source; `Int32` C1 markers of the same size | markers mutated in place (`-1` boundaries); source preserved; nonnegative input markers; overlap rejected |
| Segmentation | `Initialize_GrabCut`, `Refine_GrabCut`, `Refine_GrabCut_Frozen_Model` | `UInt8` C3 source; rectangle or 0..3 label mask with at least 5 background and 5 foreground pixels | limited private `GrabCut_State` with hidden models; `GrabCut_Mask` returns a clone; `GrabCut_Label` values |
| Histogram analysis | `Calculate_Histogram` | nonempty 2-D `UInt8`/`UInt16`/`Float32`; selected channels; optional `UInt8` C1 mask | dense uniform 1..10-D Float32 counts; `[lower, upper)` ranges; private `Histogram` owns metadata; `Histogram_Values` returns a clone |
| Histogram analysis | `Compare_Histograms` | two histograms with identical bin counts and ranges | six OpenCV metrics; channels may differ |
| Histogram analysis | `Back_Project` | nonempty 2-D `UInt8`/`UInt16`/`Float32` containing the stored channels | fresh C1 Mat of source size and depth; finite scale; uses the histogram's own metadata |

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

## Color conversion

The current color conversion enum is:

```ada
type Color_Conversion is (BGR_To_Gray);
```

API:

```ada
procedure Convert_Color
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Conversion  : Color_Conversion);
```

`BGR_To_Gray` requires:

- a nonempty source;
- exactly two dimensions;
- exactly three channels;
- depth `UInt8`, `UInt16`, or `Float32`.

The destination is rebound/replaced with a one-channel `Mat` having the same
rows, columns, and depth as the source.

The source remains valid and unchanged.

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
`Wrap` are accepted; `Constant_Border` is rejected. Direct in-place use is
unsupported.

`Pyramid_Up` performs OpenCV's Gaussian-pyramid upsampling. Destination keeps
Source depth and channel count and exactly doubles both dimensions. OpenCV
supports only its default border for this operation, so no `Border` parameter
is exposed. Direct in-place use is unsupported.

`Pyramid_Up(Pyramid_Down(Image))` is generally a smoothed reconstruction, not
the original image. `buildPyramid` is not bound.

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
all coordinates finite
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
samples. NaN and +/-Infinity map values are rejected.

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

Interleaved `CV_32FC2` maps, fixed-point maps, relative maps, and
`Convert_Maps` are not yet bound.

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
- direct in-place operation is supported.

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
   Outline : constant OpenCV.Scalar :=
     (Component_0 => 0.0, Component_1 => 255.0, Component_2 => 0.0,
      others => 0.0);
begin
   OpenCV.Core.Set_To (Image, (others => 0.0));
   OpenCV.Image_Processing.Draw_Rectangle
     (Image, (X => 8, Y => 8, Width => 20, Height => 12), Outline);
   OpenCV.Image_Processing.Fill_Circle
     (Image, (X => 40, Y => 32), 8, Outline);
end;
```

`Drawing_Line_Style` is separate from connected-component connectivity:

| Literal | Meaning |
| --- | --- |
| `Four_Connected_Line` | 4-connected Bresenham outline |
| `Eight_Connected_Line` | 8-connected Bresenham outline; the default |
| `Anti_Aliased_Line` | Gaussian-filtered outline, accepted only for `UInt8` |

`Draw_*` operations take a positive `Drawing_Thickness` from 1 through 32767.
`Fill_Rectangle`, `Fill_Circle`, `Fill_Ellipse`, and `Fill_Polygon` select
OpenCV's filled mode internally. Negative thickness is not part of the public
API. A partial `Fill_Ellipse` interval fills the elliptic sector; a full turn
fills the ellipse. Angles are finite and default to degrees. Radians are
converted in Ada and are not otherwise normalized.

The image must be nonempty and two-dimensional, with depth `UInt8`, `UInt16`,
`Int16`, `Float32`, or `Float64`, and 1 through 4 channels. Scalar components
are copied in channel order. The binding does not convert grayscale or color
and does not blend the fourth channel as alpha. Color components used by the
image must be finite. Points may lie outside the image; OpenCV clips them.
Rectangle extents, circle radii, and ellipse axes must still be positive.
Polylines need at least two points and filled polygons at least three. Array
bounds are arbitrary, so an extracted `Contour` can be passed directly.

This slice does not include text, markers, arrows, `drawContours`, subpixel
fixed-point shift, alpha blending, or multi-polygon holes.

---

## Hough detection

Three Hough detectors return Ada-owned value arrays:

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

Result order is unspecified for all three detectors. In the inspected OpenCV
implementations, standard lines and circles are ordered by accumulator
support, while probabilistic segments appear in the order produced by the
randomized point walk and are not sorted. Search results by geometry rather
than relying on an index. The optional accumulator-vote components (`Vec3f`
lines and `Vec4f` circles) are not requested, so vote semantics are not part
of this pre-1.0 API.

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

Multiscale `srn`/`stn`, OpenCV 5 weighted Hough (`use_edgeval`),
`HoughLinesPointSet`, `HOUGH_GRADIENT_ALT`, centers-only circle output, and
accumulator votes are intentionally not part of this slice.

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

type GrabCut_State is limited private;
```

`GrabCut_State` privately owns the label mask and OpenCV's background and
foreground Gaussian-mixture models. The native models (Float64 `1 x 65`, five
components of 13 values) are an implementation detail and are never exposed.
The state is **limited**, so it cannot be assigned or shallow-copied. Two states
can never share mutable algorithm storage, and its Mats are released through
normal `OpenCV.Core.Mat` finalization. A default-declared state is
uninitialized (`Is_Initialized` returns `False`), and every other operation
rejects it.

| Operation | Behavior |
| --- | --- |
| `Initialize_GrabCut (Source, Foreground_Region, Iterations)` | Outside the region is `Definite_Background`, inside starts as `Probable_Foreground`, then `Iterations` rounds run |
| `Initialize_GrabCut (Source, Initial_Mask, Iterations)` | Deep-copies a caller label mask (UInt8 C1, same geometry, values 0..3). The caller's mask is unchanged |
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

Dense, uniform, single-source histograms, their comparison, and histogram
back projection. The design was checked against OpenCV 4.1.0, 4.10.0, and
5.0.0 `imgproc.hpp` and `histogram.cpp` (`calcHist`, `calcBackProject`,
`compareHist`, `histPrepareImages`, `calcHist_8u`, `calcHist_<T>`,
`calcHistLookupTables_8u`, `calcBackProj_`). All three releases share the
low-level `calcHist(const Mat*, int, const int*, ...)` signature, which the
shim calls with `nimages = 1`, `uniform = true`, and `accumulate = false`.

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
```

Each dimension selects one source channel and divides the half-open range
`[Lower_Bound, Upper_Bound)` into `Bin_Count` equal-width bins. Samples below
`Lower_Bound` or at/above `Upper_Bound` are not counted. Bounds must be finite
with `Lower_Bound < Upper_Bound`. A multidimensional histogram counts joint
occurrences: a pixel is counted once, in the bin addressed by all of its
selected channel values, and only when every one is in range. The same
channel may appear in several dimensions. The array may start at any index;
dimension order is iteration order.

**Why at most 10 dimensions.** OpenCV 4.x supports dense Mat dimensionality up
to `CV_MAX_DIM` (32), but OpenCV 5.0 introduced `MatShape::MAX_DIMS = 10`, and
its `Mat::setSize` asserts `_dims <= MatShape::MAX_DIMS`. Because dense
`calcHist` stores its result in an N-dimensional Mat, this binding guarantees
up to 10 histogram dimensions on every supported OpenCV generation. This is a
deliberate portable contract, not an arbitrary restriction. The product of all
bin counts must also fit in `2_147_483_647`.

### Calculation

```ada
type Histogram is private;

function Calculate_Histogram
  (Source : OpenCV.Core.Mat; Dimensions : Histogram_Dimension_Array)
   return Histogram;

function Calculate_Histogram
  (Source     : OpenCV.Core.Mat;
   Mask       : OpenCV.Core.Mat;
   Dimensions : Histogram_Dimension_Array) return Histogram;
```

`Source` must be a nonempty two-dimensional `UInt8`, `UInt16`, or `Float32`
Mat, and every `Channel` must be below `Source.Channels`. The optional `Mask`
must be a nonempty two-dimensional `UInt8` C1 Mat with the source rows and
columns; a pixel is counted where the mask is nonzero. Source and mask are only
read, so they may share storage. A Region is treated as the whole image.

The result holds dense `Float32` counts. It is **not** normalized and never
accumulates into an earlier histogram.

### The Histogram type

```ada
function Histogram_Dimension_Count (Value : Histogram) return Natural;
function Get_Histogram_Dimension
  (Value : Histogram; Index : Positive) return Histogram_Dimension;
function Histogram_Values (Value : Histogram) return OpenCV.Core.Mat;
```

A `Histogram` owns its dense Float32 Mat and an Ada copy of the dimension
metadata it was calculated with. The native Mat carries no channel or range
information, so the metadata is authoritative: comparison and back projection
use it, and callers cannot substitute different metadata. The type is
immutable; copies are independent values and no operation exposes the private
Mat. `Histogram_Values` always returns a **deep clone**, so modifying the
returned Mat never changes the histogram. Its shape is `Bin_Count x 1` for one
dimension, `Bin_Count (1) x Bin_Count (2)` for two, and an N-dimensional Mat
with one extent per dimension otherwise. (OpenCV 5.0 natively produces a
genuine 1-D Mat where 4.x produces `N x 1`; the shim publishes `N x 1` on
every release.) A default-initialized `Histogram` has zero dimensions and is
rejected by comparison and back projection.

### Comparison

```ada
type Histogram_Comparison_Method is
  (Correlation,
   Chi_Square,
   Intersection,
   Hellinger_Distance,
   Alternative_Chi_Square,
   Kullback_Leibler_Divergence);

function Compare_Histograms
  (Left   : Histogram;
   Right  : Histogram;
   Method : Histogram_Comparison_Method) return OpenCV.Float64_Value;
```

| Method | OpenCV selector | Better match | Notes |
| --- | --- | --- | --- |
| `Correlation` | `HISTCMP_CORREL` | larger | identical histograms give 1; range -1 .. 1 |
| `Chi_Square` | `HISTCMP_CHISQR` | smaller | asymmetric: `Left` is the denominator |
| `Intersection` | `HISTCMP_INTERSECT` | larger | sum of bin minima; scale depends on histogram totals |
| `Hellinger_Distance` | `HISTCMP_BHATTACHARYYA` | smaller | OpenCV's "Bhattacharyya" computes the Hellinger distance; identical gives 0 |
| `Alternative_Chi_Square` | `HISTCMP_CHISQR_ALT` | smaller | symmetric chi-square variant |
| `Kullback_Leibler_Divergence` | `HISTCMP_KL_DIV` | smaller | asymmetric; empty `Right` bins use OpenCV's `1e-10` substitute |

None of these values is a normalized similarity score. Both histograms must
have the same number of dimensions and, per dimension, the same bin count and
lower and upper bounds; a mismatch raises `OpenCV.OpenCV_Error`. Channel
numbers need not match, so distributions from different channels or images
can be compared. Neither histogram is modified.

### Back projection

```ada
function Back_Project
  (Source       : OpenCV.Core.Mat;
   Distribution : Histogram;
   Scale        : OpenCV.Float64_Value := 1.0) return OpenCV.Core.Mat;
```

Each output pixel receives `Scale` times the histogram bin addressed by the
pixel's selected channels, or 0 when any selected value is outside its range.
Channels and ranges come from `Distribution`. The result is a fresh
single-channel Mat with the source rows, columns, and depth; `UInt8` and
`UInt16` results saturate, `Float32` results do not. `Scale` may be any finite
value within the Float32 range (OpenCV narrows it to `float`), including
negative values. A Region is back-projected in view coordinates and produces a
Region-sized output. Source and histogram are unchanged; no in-place form is
offered.

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
- nonfinite selected Float32 samples (NaN or Infinity) and finite samples
  whose per-dimension uniform-bin coordinate `sample * scale - lower * scale`
  is outside the native `cvFloor` int range. Ordinary finite samples outside
  `[lower, upper)` remain legal when this conversion is safe; masked histogram
  calculation does not inspect masked-out pixels;
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

The current **344-test** baseline is:

| Suite | Tests |
| --- | ---: |
| Color conversion | 7 |
| Resize | 10 |
| Gaussian blur | 10 |
| Gaussian kernel | 8 |
| Derivative kernels | 10 |
| Image pyramids | 10 |
| Template matching | 10 |
| Affine warping | 13 |
| Perspective warping | 13 |
| Remapping | 13 |
| Median blur | 10 |
| Box blur | 11 |
| Bilateral filter | 10 |
| Filter 2D | 12 |
| Sep Filter 2D | 12 |
| Laplacian | 9 |
| Morphology | 19 |
| Canny | 5 |
| Sobel / Scharr derivatives | 11 |
| Fixed threshold | 7 |
| Automatic threshold | 4 |
| Adaptive threshold | 6 |
| Histogram equalization | 12 |
| CLAHE | 9 |
| Contours | 7 |
| Connected components | 6 |
| Drawing | 11 |
| Hough detection | 24 |
| Segmentation (flood fill, watershed, GrabCut) | 29 |
| Histogram analysis (calculation, comparison, back projection) | 26 |
| **Total** | **344** |


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

- the larger OpenCV color-conversion matrix beyond `BGR_To_Gray`;
- custom morphology kernels, anchors, and arbitrary constant border values;
- additional map encodings and `Convert_Maps`;
- polar transforms;
- Laplacian pyramids and `buildPyramid`;
- deferred Hough capabilities: multiscale `srn`/`stn`, OpenCV 5 weighted
  (`use_edgeval`) Hough, `HoughLinesPointSet`, `HOUGH_GRADIENT_ALT`,
  centers-only circle output, and optional accumulator votes;
- deferred segmentation capabilities: flood fill on `Int32` images,
  combined `GC_INIT_WITH_RECT | GC_INIT_WITH_MASK` initialization, exposing or
  importing GrabCut models, mean-shift segmentation, and higher-level
  distance-transform marker-construction convenience;
- advanced histogram capabilities: multi-image histograms, nonuniform bin
  boundaries, accumulation/update, `SparseMat` histograms, and EMD (a future
  sparse-histogram abstraction may revisit the dense 10-dimension limit);
- custom/user-defined distance masks (not part of the portable foundation);
- integral images;
- text rendering and text metrics;
- markers, arrows, and `drawContours` as its own operation;
- subpixel fixed-point drawing;
- alpha blending and multi-polygon holes;
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