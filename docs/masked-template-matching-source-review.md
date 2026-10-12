# Portable masked template matching: source review and qualification

## Exact upstream sources

Inspected the checked-out exact tags (confirmed with `git describe --exact-match`):

- [4.1.0 templmatch.cpp](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/templmatch.cpp)
- [4.10.0 templmatch.cpp](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/templmatch.cpp)
- [5.0.0 templmatch.cpp](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/templmatch.cpp)

The public native declaration is `matchTemplate(image, templ, result, method,
mask = noArray())`. Masked calls dispatch to `matchTemplateMask` before the
unmasked IPP/common implementation. This adapter uses Mat, not UMat/OpenCL.

### Canonical input strategy

4.1.0 lines 775–794 convert UInt8 image and template with scale `1/255`.
Later tags lines 772–784 use scale one. 4.1.0 also mistakenly derives mask
depth/channel metadata from image metadata; equivalent Float32 C1 inputs avoid
that discrepancy. The production shim snapshots logical pixels row by row into
three owning Float32 C1 matrices. Image/template bytes become exact floats in
0..255. Each mask byte becomes exactly 0 or 1, not byte/255. Thus all three
versions skip their UInt8 conversion paths. There is no output rescaling.

The adapter calls native `TM_SQDIFF` only. No correlation algorithm is
implemented by the binding, and no negative result is clamped. Other historical
masked methods, even if available in newer versions, are explicitly rejected.

### Remaining numerical differences

4.1.0 lines 801–822 square the image, square the mask, compute template energy
using `meanStdDev(mask * template)` and multiply variance-plus-mean-square by
template area. It computes two correlations, then separately subtracts twice
the correlation and adds template energy. Later versions lines 799–811 use
`norm(template * mask, NORM_L2SQR)` for energy and the expression
`-2 * correlation + image_square_correlation + energy`. 5.0.0's SQDIFF path is
the same as 4.10.0. These differences change intermediate Float32 rounding.
For binary masks `mask == mask^2`, so 4.1.0's image-square correlation against
mask rather than mask-square has identical mathematical semantics.

All three `crossCorr` implementations select Float64 DFT intermediates for
Float32 inputs and convert correlation blocks back to Float32. Their block
scale is 4.5, minimum block size 256, optimal DFT sizes, spectral multiplication,
and inverse scaling are equivalent. 4.1.0 takes explicit correlation size/type
arguments; later versions use the allocated output. Native DFT/backend/compiler
differences remain possible; bit-identical scores are not a public promise.

### Regions and publication

`crossCorr` can use `locateROI`/`adjustROI` when BORDER_ISOLATED is absent.
Only private owning snapshots reach it, with no parent pixels or ROI offsets.
The snapshot reads only each input's logical columns, including noncontinuous
and overlapping Regions. Inputs are not written. Concurrent unsynchronized
mutation during a call is not supported; later mutations cannot affect output.

Native result allocation is Float32 C1, with width `image.cols-template.cols+1`
and corresponding height. The shim computes in a local Mat and move-publishes
only after success. Existing output storage is never reused. Distinct input and
destination headers may share pixel storage safely; identical native objects
are rejected because publication would mutate an input header.

## Arithmetic and pointer preflight

`cpp/masked_template_layout_fits.hpp` is an allocation-free widened planner.
It checks positive logical geometry before any adapter indexing/allocation,
input/template/output signed plane sizes, Float32 row widths and byte spans,
`image + template - 1` signed expressions, and representable `cvRound(4.5*T)`.
It derives actual native block and optimal DFT sizes, bounds the Float64 DFT row
step cast to int, DFT signed plane products/backend probes and allocation span,
ceiling tile-count addition and signed
tile-count product. C1 avoids the native multichannel scratch products and
channel-expanded widths entirely. Template area is bounded before native
reduction/Mat plane processing. These bounds are representability restrictions,
not practical image-size caps. Representable dimensions can still exhaust memory;
allocation exceptions are translated without publishing an output.

Row reads use size-sized strides. `(rows-1)*step+cols` must fit ptrdiff_t before
access; zero/undersized/overflowing strides are rejected. Trusted Core handles
must designate valid live Mats and actual backing storage. Neither this shim nor
the Core bridge can validate arbitrary forged/dangling nonnull pointers.
Upstream DFT internals are trusted; this review does not assert a proof of all
upstream allocations or backend implementation arithmetic.

### Validation-boundary review

Retained semantic-looking C++ checks have concrete ABI-safety purposes:

- nonempty 2-D UInt8 C1: the adapter explicitly indexes UInt8 rows;
- mask/template size equality: native elementwise products require matching spans;
- template fitting source: prevents negative result extents and unsafe allocation;
- SQDIFF selector: prevents access to unreviewed historical arithmetic branches;
- identical destination object: publication would mutate an input's native header.

These guards have `ABI safety:` comments. Public semantic validation remains in
thick Ada; the shim duplicates only conditions needed by this narrow adapter.
All exceptions are contained and translated using the established error model.

## Numerical acceptance policy (fixed before running)

Independent oracle: widened integer accumulation of squared UInt8 differences,
ignoring zero mask bytes, at every output coordinate. Exact comparison is used
for zero masks, singleton maximum differences, and bounded constant row/column
fixtures. Other corpus samples allow absolute error at most
`2^-19 * active_pixel_count * 65025`, approximately 1.91 ppm of the maximum
possible mathematical score. The same bound applies to cross-version sample
differences. This conservative rounding allowance covers two Float32 correlation
roundings and final subtraction/addition in the bounded regression corpus.
It is not a formal universal error bound for arbitrary DFT backends/dimensions.
The tolerance was not increased after inspecting observations.

Every output is recorded as raw IEEE Float32 bits, alongside geometry/types,
active count, result shape, and hexadecimal minimum score/location. Comparison
reports absolute, relative, ULP, nonfinite, and coordinate differences.
All minima, including deterministic zero-mask ties, must agree across versions.

The 41-case corpus covers full/binary/zero masks, simultaneous overlapping
Regions, equal-size matrices, singleton/odd/even templates, long rows/columns,
maximum UInt8 difference, distractors, a small distinctive visible region,
excluded source corruption and excluded template corruption. AUnit separately
demonstrates that excluding corrupted source/template pixels restores the known
landmark minimum rather than merely accepting a native call.

Exact-version local qualification uses installed prefixes 4.1.0 and 5.0.0 under
`~/.cache/video-task004`, and system 4.10.0. The executable checks header/runtime
versions; the runner checks resolved Core/Imgproc loader directories and records
include/library paths. Re-run from the repository root:

```sh
sh tests/qualify_masked_template_versions.sh PREFIX_410 PREFIX_4100 PREFIX_500
```

GCC and Clang 19 qualification results: 4.1.0/4.10.0 max absolute 1, max relative 1, max ULP
1065353216; 4.1.0/5.0.0 max absolute 2, max relative 2.2903803795022866e-7,
max ULP 2; 4.10.0/5.0.0 max absolute 3, max relative 1, max ULP 1065353216.
There were zero nonfinite samples and zero different minimum locations.
Large ULP/relative values are cancellation near zero, not hidden by the report.
All-zero masks produced exact zero maps on every version and are allowed.

Sanitizer instrumentation covers the entire compiled production Imgproc shim,
Core shim, adapter/planner, and harness. The dynamically linked OpenCV libraries
are not sanitizer-instrumented. Hosted Linux runs the bounded production corpus
against its installed OpenCV only; it does not perform exact-version comparison.

## Local validation

Starting main: `615ee6bbc56e7fb5ac5a5f4a817c0400b54ac53a`.
Fresh baseline: 1095/1095 AUnit PASS. Final suite: 1101/1101 PASS;
masked selector: 6/6; unchanged unmasked selector: 10/10.
Alire build, GNATformat, modified Ada 79-column checks, shell syntax and
`git diff --check` passed. GCC and Clang 19 compile the full production shims
and harness as C++17 with `-Wall -Wextra -Wpedantic -Werror`; both sanitizer
runs passed. Clang ASan/UBSan qualification ran all three exact versions.

Affected Ada units were force-compiled with `-gnatwa -gnatwc -gnatwu -gnatwn
-gnatwe -gnatyM79 -Werror` successfully. A forced all-dependency strict build
failed on existing long lines in external AUnit units (`aunit-io.ads`,
`aunit-time_measure.ads`, and reporter bodies). No external dependency was edited
or warnings suppressed. The ordinary full build/test passes. No SPARK-designated
unit changed and no GNATprove campaign was run. Independent diff and final-head
hosted CI review remain required; this report does not declare merge readiness.