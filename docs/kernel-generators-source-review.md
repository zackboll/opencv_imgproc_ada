# Portable kernel generators: pinned source review

Reviewed exact OpenCV tags **4.1.0**, **4.10.0**, and **5.0.0**.
Runtime validation in this development environment uses **4.10.0 only**.
The other two versions were source-reviewed, not runtime-tested locally.

## Authoritative sources

For each tag below, the inspected paths are:

- `modules/imgproc/include/opencv2/imgproc.hpp`: declarations, defaults,
  parameter documentation and `MorphShapes`.
- `modules/imgproc/src/gabor.cpp`: complete generator.
- `modules/imgproc/src/morph.dispatch.cpp`: `getStructuringElement`.
- `modules/imgproc/src/filterengine.hpp`: `normalizeAnchor`.
- `modules/core/src/matrix.cpp`: `setSize`, allocator, header finalization.
- `modules/core/src/alloc.cpp`: `fastMalloc`.
- `modules/core/include/opencv2/core/saturate.hpp`: double-to-int conversion.

Source roots (append the paths above):

- https://github.com/opencv/opencv/tree/4.1.0
- https://github.com/opencv/opencv/tree/4.10.0
- https://github.com/opencv/opencv/tree/5.0.0

## Gabor geometry, parameters and ordering

The three `gabor.cpp` files are identical. Positive width gives
`xmax = width / 2`, `xmin = -xmax`; height is analogous. Output extent is
`2 * floor(size / 2) + 1`. Even explicit sizes therefore grow by one.
The Ada contract deliberately requires both dimensions positive and odd,
returning the exact requested geometry. No automatic-size sentinel is exposed.

Native nonpositive dimensions select automatic extents independently:
`cvRound(max(abs(3*sigma_x*cos(theta)), abs(3*sigma_y*sin(theta))))`
for x, swapping sine/cosine for y. This involves floating-to-int conversion;
the private ABI rejects nonpositive extents before those branches.

All versions use:

```
sigma_x = sigma
sigma_y = sigma / gamma
ex = -0.5 / (sigma_x * sigma_x)
ey = -0.5 / (sigma_y * sigma_y)
cscale = 2*pi / lambda
xr = x*cos(theta) + y*sin(theta)
yr = -x*sin(theta) + y*cos(theta)
v = exp(ex*xr*xr + ey*yr*yr) * cos(cscale*xr + psi)
kernel(ymax-y, xmax-x) = v
```

There is no coefficient normalization. Both coordinates are reversed in
storage, equivalent to a 180-degree rotation of the sampled coordinate grid,
not a transpose. For an asymmetric phase this changes the apparent sinusoidal
phase relative to increasing array coordinates. The binding preserves this
layout exactly; `Filter_2D` continues to perform its existing correlation.
Default phase is pi/2 and default native depth is Float64. The public subtype
reuses Float32/Float64 kernel selectors, never packed OpenCV depth constants.

Ada requires positive finite sigma, wavelength and aspect ratio, and finite
orientation/phase in radians. Angles are not normalized; parameters are not
replaced by absolute values. Finite positive extremes can overflow/underflow
`sigma/gamma`, squares, reciprocals or `2*pi/lambda`; subsequent arithmetic
can produce NaN/Inf coefficients. These are ordinary native IEEE numerical
results, not integer conversion or indexing inputs in the explicit-size path.
This API retains that behavior rather than introducing arbitrary numerical
cutoffs or rejecting native results. It does not promise finite coefficients
for every finite input. Float32 narrowing can also lose precision.

### Signed and allocation safety

For positive odd `d <= INT_MAX`, `m = d/2 <= INT_MAX/2`, `-m` is representable,
`m-(-m)+1 = d`, and indices `m-x` range from zero to `d-1`.
Each loop's final increment is `m+1 <= INT_MAX/2+1`, safely representable.
All `x*c+y*s` arithmetic is double, not signed integer multiplication.
The shim recomputes output extents in int64 before native entry, including
for raw positive even requests (which are safe and retain native semantics).

Row bytes, element count and total bytes are bounded by division before
multiplication. The limit is the smaller of `PTRDIFF_MAX` and
`SIZE_MAX - 64 - sizeof(void*)`, preserving pointer offsets and the portable
`fastMalloc` alignment/header addition. This also bounds the signed int64
product used by 4.1 `setSize`; 4.10 uses uint64 there, while 5.0 rewrites
shape/step handling. All three default allocators multiply size_t extents.
There is no arbitrary small kernel-size cap.

## Structuring elements

Portable shapes are Rectangle, Cross and Ellipse (native selectors 0, 1, 2).
OpenCV 5.0 adds `MORPH_DIAMOND = 3` and a Manhattan-distance branch;
4.1/4.10 have neither. Diamond is intentionally absent from the public enum
and rejected by the private decoder, including on OpenCV 5.
Portable shape branches have the same arithmetic in all three tags.

`normalizeAnchor` substitutes width/2 and height/2 independently for -1,
then asserts containment in `Rect(0,0,width,height)`. Ada resolves the center
itself, exposes no sentinel, and validates every explicit anchor. Raw invalid
anchors safely reach the native containment assertion before mask indexing;
its exception is translated. Rectangle and Ellipse geometry ignores Anchor;
Cross includes precisely the generating anchor's row and column. The Mat
does not retain this anchor. A later morphology call needs its intended
application anchor explicitly, especially for an off-center Cross.

All versions force `Size(1,1)` to Rectangle after normalizing the anchor.
Output is fresh UInt8 C1 of exact requested positive dimensions (even sizes
allowed), with values zero and one, not 255.

### Ellipse arithmetic

All three tags compute `r=height/2`, `c=width/2`, and
`inv_r2 = r ? 1./((double)r*r) : 0`. The reciprocal uses double multiplication,
but **`r*r - dy*dy` inside sqrt uses signed int multiplication first**.
`dy=i-r` has absolute value at most r for positive heights, including even
heights. Thus the exact safe radius is `floor(sqrt(INT_MAX)) = 46340` on
the targeted 32-bit-int ABI, allowing heights through **92681**, rejecting
92682 before any allocation. The shim tests `int64(r)*r <= INT_MAX` rather
than hardcoding a height cap. Rectangle/Cross do not inherit this restriction.

With that bound, the sqrt input is finite and nonnegative; `saturate_cast<int>`
uses `cvRound`. Its mathematical result dx is in [0,c]. Ordinary double
rounding near the maximum c cannot add a full half unit to that endpoint.
The shim also checks widened `2*c+1 <= INT_MAX`, protecting `c+dx+1`.
`c-dx` is nonnegative and representable; `i-r`, abs(dy), `j1+1` for a
contained Cross anchor, and loop increments are representable. Rectangle
and Cross accept the full positive signed dimension domain subject to
allocation-byte bounds. No allocation failure is relied on to prevent an
Ellipse arithmetic overflow.

## Publication and validation boundary

Both functions decode selectors, obtain a borrowed Core output Mat, preflight
native arithmetic, generate into a local Mat, then move it into the output
only on success. Exceptions are contained by the established status/diagnostic
translation. Existing output Mats remain unchanged on every failure.

Duplicated positive-extent checks are retained solely for ABI safety: Gabor
otherwise selects potentially unsafe cvRound automatic sizing; structuring
extents must be safe before unsigned products and division in preflight.
Allocation and Ellipse guards are native arithmetic safety, not duplicated
friendly semantic policy. Gabor oddness, meaningful finite parameters and
explicit-anchor policy live only in Ada. No result metadata postcondition
checks duplicate native documented behavior.

## Tests and tolerances

25 focused registered tests extend the 594-test baseline to 619. They cover
metadata, independent ownership, formula/order, defaults and angle changes,
public failures and recovery, raw selector/safety failures and atomicity,
both coefficient depths through Filter_2D, and all three masks through
Erode/Dilate/Opening, plus explicit Cross-anchor integration.
Formula samples use absolute tolerance 1e-12 (double/libm roundoff at unit
scale); Float32 comparisons allow 1e-7 (one unit-scale single rounding).
Filtering assertions test nontrivial output without fragile full-image
floating equality. Morphology comparisons are exact UInt8 comparisons.

## Local verification

- Full AUnit: 619 registered/executed/passed; zero failures or errors.
- Imgproc library units and test-crate units were force-compiled with the
  configured Alire-managed GNAT 16.1/GPRbuild 26 toolchain, warnings as errors,
  unused warnings, warning-suppression diagnostics and `-gnatyM79`.
- The test project's existing `-gnatwa` and development style checks remain
  enabled. No suppression or dependency-metadata changes were introduced.
- C++ object compilation: C++17, `-Wall -Wextra -Wpedantic -Werror`.
- GNATformat check, direct modified-Ada 79-column check and diff whitespace
  check pass.

Normal `alr -n build` and test-environment discovery were blocked by the
known pkg-config sudo deployment issue. Used `scripts/configure_opencv.sh`
and the existing generated projects with Alire-managed toolchain and AUnit.
The sibling Core checkout was clean and left unchanged. A diagnostic forced
strict rebuild of the entire dependency closure encountered four pre-existing
Core unused-formal warnings in `typed_external_mat_view`; the strict checks
were then scoped to the affected Imgproc library/test crates using GPRbuild
`-u`, with the dependency built under its own configured policy. This is not
a claim that Core's entire source passes Imgproc's additional warning flags.
No SPARK-compatible units were materially changed; GNATprove and coverage
were not run for these foreign-call wrappers.