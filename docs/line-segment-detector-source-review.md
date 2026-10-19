# IMGPROC-API-003: Line Segment Detector source review

## Authority and compatibility

Both `modules/imgproc/include/opencv2/imgproc.hpp` and
`modules/imgproc/src/lsd.cpp` were inspected at these exact upstream tags:

| OpenCV | Header | Implementation | Finding |
|---|---|---|---|
| 4.1.0 | [declaration](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/include/opencv2/imgproc.hpp) | [source](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/lsd.cpp) | Declared, constructor and detect throw `StsNotImplemented` |
| 4.5.3 | [declaration](https://github.com/opencv/opencv/blob/4.5.3/modules/imgproc/include/opencv2/imgproc.hpp) | [source](https://github.com/opencv/opencv/blob/4.5.3/modules/imgproc/src/lsd.cpp) | Same removed-implementation stub |
| 4.5.4 | [declaration](https://github.com/opencv/opencv/blob/4.5.4/modules/imgproc/include/opencv2/imgproc.hpp) | [source](https://github.com/opencv/opencv/blob/4.5.4/modules/imgproc/src/lsd.cpp) | Functional implementation restored |
| 4.6.0 | [declaration](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/include/opencv2/imgproc.hpp) | [source](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/src/lsd.cpp) | Functional, legacy rectangle/NFA calculations |
| 4.10.0 | [declaration](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/include/opencv2/imgproc.hpp) | [source](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/lsd.cpp) | Functional, revised rectangle/NFA, stable gradient sorting |
| 5.0.0 | [declaration](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/include/opencv2/imgproc.hpp) | [source](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/lsd.cpp) | Functional, refinement argument is `LineSegmentDetectorModes` |

The C++ preprocessor removes all detector calls for versions before 4.5.4.
Detection, rendering, and comparison return `ERROR_OPENCV` with an explicit
restoration diagnostic; thick Ada translates this to `OpenCV_Error`. No stub
constructor is invoked, and there is no Hough fallback. OpenCV 5 receives an
explicit enum conversion after selector decoding; 4.x receives an explicit int.
The 4.5.3/4.5.4 boundary is source-reviewed, not runtime-qualified here.

## Public API and ownership

All declarations remain in `OpenCV.Image_Processing`:

* `LSD_Refinement`, `LSD_Parameters`, `LSD_Segment`, `LSD_Segment_Array`.
* `Detect_Line_Segments`, `Render_Line_Segments`.
* `Compare_Line_Segments` count function and count/visualization procedure.

Use LSD for gradient-oriented subpixel segments and per-region evidence on
grayscale images. Use `Find_Hough_Line_Segments` (HoughLinesP) for integer
segments voted from a binary edge image with explicit Hough thresholds/gaps.
Neither is a fallback for the other.

Detection accepts a nonempty 2-D UInt8 C1 Core Mat. Each invocation creates a
local `cv::Ptr<LineSegmentDetector>`, clones the logical source (not its parent),
and requests native Vec4f endpoints, double widths and double precisions.
Advanced mode additionally requests native NFA. A noncontiguous Region is
supported; its coordinates start at its own origin, not the parent's origin.
Cloning prevents Gaussian border sampling from including pixels outside it.

Results follow Detect/Count/Copy/Destroy. The opaque result owns only a vector
of value records, never a borrowed Core handle. Ada copies into a zero-based
array or returns a null array with bounds 1 .. 0. Cleanup is exception-safe on
both sides. No detector, Mat, or endpoint pointer survives in public results.
Native order and gradient endpoint orientation are unchanged. Different native
versions can choose different orders and results: 4.6 uses `sort`, whereas 4.10
uses `stable_sort`, and the NFA algorithms differ. Tests compare exact independent
native references on the same build, not exact cross-version detections.

### Complete configuration

| Field | Default | Meaning and Ada semantic range |
|---|---|---|
| Refinement | Standard_Refinement | None, standard region-density refinement, or advanced precision/NFA refinement |
| Scale | 0.8 | Image sampling scale, 0 < Scale <= 1 |
| Sigma_Scale | 0.6 | Gaussian sigma numerator, > 0; sigma = numerator / Scale when downsampling |
| Quantization | 2.0 | Gradient-norm quantization error bound, >= 0 |
| Angle_Degrees | 22.5 | Gradient angle tolerance, 0 < angle < 180 |
| Log_Epsilon | 0.0 | Advanced detection threshold, accept -log10(NFA) > threshold |
| Density | 0.7 | Minimum aligned-region density, 0 <= density < 1 |
| Bin_Count | 1024 | Positive gradient pseudo-ordering bin count |

Every real parameter is finite. `Bin_Count` is a Positive (GNAT signed 32-bit
Integer on supported targets); a narrower source-derived native bound below
also applies. Standard and no-refinement modes set `Has_NFA=False, NFA=0`.
Width is the enclosing region width in source pixels. Precision is native
`rec.p`, the angular probability (initially Angle_Degrees/180, not radians or
endpoint error). Advanced NFA is native logarithmic evidence, not a probability:
-1, 0, 1 indicate approximately 10, 1, 0.1 mean false alarms. Upstream documents
10% precision, and version-specific numeric behavior is preserved.

### Visualization and comparison

Rendering accepts UInt8 C1/C3 and produces fresh UInt8 C3 storage. Native
`drawSegments` paints red BGR; input aliases are unchanged. Only endpoints are
consumed from supplied records. Empty rendering clones/converts without calling
4.x's inconsistent empty-line validation. Comparison uses native rasterized
mismatching-pixel count, with a positive caller-specified canvas. Optional
visualization starts black; first/second/overlap are blue/red/magenta. Empty vs
empty returns zero and a black visualization, including on 4.x. Native lines are
passed as typed CV_32FC4 Mats even when one set is empty. Procedure outputs are
assigned only after success. Unsupported versions reject empty operations too.

## Source-level numeric and ABI audit

These are runtime preflights, not formal proofs. Foreign OpenCV behavior remains
trusted except for the audited guards and observed tests. All safety preflights
are independently enforced in C++; public semantic policy remains in Ada.

* **Gaussian sizing:** `flsd` casts `ceil(sigma*sqrt(6*ln(10)))` to unsigned,
  then computes `1+2*h` and signed filter padding. Require finite h, kernel and
  source-plus-padding representability. Scale=1 does not use this Gaussian.
* **Scaled dimensions:** inspect products as double before cvRound. Reject
  nonfinite, out-of-int-range and rounded-zero dimensions before last-row/column
  indexing. Reuse the existing exact-resize layout guard for coefficients,
  buffers, signed pixel area, 2x-area redirect and pointer extents.
* **Gradient buffers:** bound area below INT_MAX and bound vector/Mat storage by
  PTRDIFF_MAX/(2*sizeof(double)+32). Gradient arithmetic itself is safe for
  UInt8: DA/BC are in [-255,255], norm <=255. `used` and `angles` protect boundary
  modgrad accesses; short-circuit `isAligned` rejects NOTDEF boundaries.
* **Gradient bin casts:** `max_grad` is computed only above the gradient
  threshold, but *all* norms are binned. The maximum/minimum-nonzero UInt8 norm
  ratio is <512. Require bins <= INT_MAX/512 (4,194,303), preventing a bin's
  float-to-int overflow. These versions sort a vector; they do not allocate an
  N_BINS-sized histogram.
* **Angles and rho:** preserve a normal positive p even after ten possible
  halvings (p >= DBL_MIN*1024), with p<1, and finite quant/sin(prec). Check the
  computed min-region size before size_t conversion. No arbitrary angle floor
  such as one degree is imposed.
* **Rectangle/NFA scan:** older rect_nfa truncates vertices to int, computes
  integer-divided edge slopes and accumulates x across rows; newer code uses
  ceil/slope intersections. A fitted rectangle is bounded by 4*(w+h) from
  the origin; slope differences by 8*(w+h). The conservative source-derived
  provisional preflight 16*(w+h)^2 < INT_MAX was intended to protect accumulated
  coordinates, casts and subtractions. **The sanitizer campaign disproved its
  sufficiency for newer rect_nfa:** near-horizontal edges produce enormous
  slope extrapolations despite small image geometry. It is not a complete safety
  guard and must not be approved as one. See the blocker below.
* **Refinement:** region-size/index arithmetic stays within the bounded pixel
  area. Floating density/variance/NFA calculations are native; outputs are
  checked finite before any Ada scalar conversion. Native assertions are
  translated, not replaced with custom detections or fabricated evidence.
* **Drawing endpoint casts:** finite Float32 endpoints have absolute value at
  most the largest Float32 below (INT_MAX-1)/2 (1,073,741,760). This protects
  cvRound and signed differences before native clipping; off-image endpoints
  are otherwise allowed.
* **Comparison:** positive area <= INT_MAX/3 protects signed countNonZero and
  4.x unsigned `i*3+2` visualization indexing before allocations. Fresh
  visualization is continuous. No source output alias is mutated.
* **Native outputs:** validate segment and optional diagnostic vector shapes,
  types and matching counts before typed reads. Validate representation and
  finite values before copying. Count/capacity/pointer extents cannot overflow.
* **C ABI:** 48-byte standard-layout record, 8-byte alignment, offsets
  0/4/8/12/16/24/32/40/44 for x1/y1/x2/y2/width/precision/nfa/has_nfa/reserved.
  C++ static assertions, explicit Ada representation, C11 header syntax and
  native/AArch64 compiler controls check it. Flags are int32, reserved is zero.
  Mat handles come only from Core's module bridge; arbitrary forged/dangling
  pointers cannot be validated. Output publication is atomic. Every throwing
  export catches and translates cv/std/unknown exceptions to thread-local errors.

### Validation-boundary disposition

Retained duplicated conditions protect concrete native arithmetic: finite
scale/sigma/quant/angle, kernel/scaled geometry, p/rho/min-region conversions,
bin casts, rectangle scan bounds, endpoint rounding/differences and comparison
area/indexing. Each has an `ABI safety` explanation in C++. Source depth/channel
semantics remain Ada-only, with raw callers subject to OpenCV's own assertions.
Output checks protect typed reads or publication, not friendly diagnostics.

## Qualification evidence and unresolved blocker

Baseline: 1,158 registered AUnit cases, all passing. New suite: 17 cases;
full suite: 1,175 passing on each of 4.1.0/4.6.0/4.10.0/5.0.0 (GNAT 16.1.0,
Alire 2.1.1 development profile). Native harness is
`sh tests/run_lsd_native.sh`, selecting PKG_CONFIG_PATH, OPENCV_TEST_PACKAGE
(opencv5 for 5.0) and OPENCV_CORE_TEST_PREFIX for indexed Core 0.4.1.
Native counts below are assertion totals, **not** AUnit cases.

| Version | Native-reference assertions | Expected ABI rejections | Instrumented OpenCV ASan/UBSan |
|---|---:|---:|---|
| 4.1.0 | 3 (explicit unavailable operations) | 4 | Pass, no stub calls |
| 4.6.0 | 319 | 129 | **Blocked**, native exact-resize SIMD misaligned short load |
| 4.10.0 | 348 | 132 | **Blocked**, same finding |
| 5.0.0 | 348 | 132 | **Blocked**, same finding |

Sanitizer libraries are locally built exact tags, RelWithDebInfo, with C++ flags
`-include cstdint -fsanitize=address,undefined,float-cast-overflow
-fno-omit-frame-pointer` (C flags omit `-include cstdint`); the harness and both
production shims enable all three sanitizer groups too. The first functional
failure is native `intrin_sse.hpp::v_lut_pairs` loading `const short` from an odd
address, called by `resize.cpp::hlineResizeCn<uint8_t,ufixedpoint16,2,true,1>`
inside LSD `flsd` at scale .8. The clone cannot fix this: the odd offset belongs
to OpenCV's internal Gaussian/resize buffer. Sanitizers remain enabled and no
global optimization switch is changed. This is **not a sanitizer pass** and
prevents READY_FOR_INDEPENDENT_REVIEW. Further safety review/qualification is
required; no fully qualified safe-LSD claim is made by this work-in-progress.

A second campaign, `sh tests/run_lsd_native.sh --scale-one` with the same
instrumented libraries, deliberately excluded downsampling without disabling
optimization or any sanitizer:

| Version | Scale-one result |
|---|---|
| 4.6.0 | Pass: 157 native assertions, 65 expected ABI rejections |
| 4.10.0 | **Fail:** lsd.cpp:996, rect_nfa converts approximately -7.31835e15 to int |
| 5.0.0 | **Fail:** same rect_nfa float-cast overflow |

The latter failures arise in Advanced refinement on a 128x128 fixture during
`rect_improve`, before returned-output checks can intervene. Postchecking finite
diagnostics cannot repair undefined behavior that already occurred. A small
image-size cap is therefore not a valid fix. Dependency-level native repairs or
a deliberately narrowed public support contract require explicit direction;
the current implementation is not safe for approval or merge.

GNAT 12 native and AArch64 compile-only controls each passed all four tests in
Debian 12 containers, including the actual LSD C/Ada record representation.
C11 header syntax, native C++ layout and AArch64 C++ layout checks passed.
GNATdoc generated 329 declaration sections (193 subprograms), zero warnings,
and 1,596/1,596 documented inventory items (100%). Cross-configuration controls
ran 41 tests (2 genuine-SDK tests explicitly skipped); AdaCore adapter controls
passed 9 tests. These are not production platform qualification substitutes.

Hosted Linux/macOS ARM64/macOS Intel-IPP, Debian installed-consumer and GNAT 12
source-unit results must be read from the PR checks. Windows MSYS2 remains
manual/post-merge and has not been qualified. Frozen GNATdoc shadow authority
is not modified. No merge, tag, release or Alire-index submission is authorized.