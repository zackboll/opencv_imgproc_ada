# EMD lower-bound and early exit: exact-tag source review

## Evidence and scope

Reviewed exact upstream tags, not a moving branch:

| Tag | Commit |
|---|---|
| [4.1.0](https://github.com/opencv/opencv/tree/4.1.0) | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| [4.10.0](https://github.com/opencv/opencv/tree/4.10.0) | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| [5.0.0](https://github.com/opencv/opencv/tree/5.0.0) | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

For every tag, inspected `modules/imgproc/include/opencv2/imgproc.hpp`,
`modules/imgproc/CMakeLists.txt` and `cmake/OpenCVModule.cmake`. Implementations:

- [4.1 `emd.cpp`](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/emd.cpp):
  `cv::EMD` (1150-1172) calls `cvCalcEMD2`, then `icvInitEMD`.
- [4.10 `emd_new.cpp`](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/emd_new.cpp):
  `cv::EMD` (933-1001) calls `EMDSolver::init`, `solve`, `calcFlow`.
  Also inspected `emd.cpp`: its corresponding symbol is **EMD_legacy**,
  not `EMD`. It does not dispatch or replace `emd_new.cpp`'s public symbol.
- [5.0 `emd_new.cpp`](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/emd_new.cpp):
  byte-identical to 4.10's reviewed file. No legacy `emd.cpp` remains.

`ocv_define_module` uses `ocv_glob_module_sources`; the latter includes
`src/*.cpp` recursively (4.1 line 767; 4.10 line 821; 5.0 line 820).
There is no alternate HAL/vendor EMD dispatch in these entry points.
5.0's Imgproc also depends on Geometry, but EMD itself remains Imgproc.

Local runtime evidence is **OpenCV 4.10.0, Linux x86_64**. The final production
shim's exact-public-header syntax checks establish **source compatibility
only**. Neither 4.1.0 nor 5.0.0 runtime execution is claimed.

## Declaration, input/output parameter, and prose discrepancy

All three headers declare:

```cpp
float EMD(InputArray signature1, InputArray signature2, int distType,
          InputArray cost = noArray(), float* lowerBound = 0,
          OutputArray flow = noArray());
```

Each signature is Float32 C1, with one weight column followed by coordinates.
Built-in metrics need at least one coordinate and matching column counts.
Only L1, L2 and C (Chebyshev) are exposed here. The center-distance bound needs
a metric: native explicitly rejects a nonnull lowerBound with user Cost
(4.1 lines 212-214; 4.10/5.0 lines 973-974). No callback or Cost overload is
introduced.

The headers correctly describe lowerBound as **input/output**, initialized by
the caller, and say that a center distance greater than or equal to the initial
value skips EMD. However, they subsequently advise setting it to zero to
calculate both EMD and center distance (4.1 lines 3183-3191; 4.10 3370-3378;
5.0 3159-3167). That advice contradicts both the preceding inclusive rule and
the actual source. The binding follows the source, not this zero advice.

4.1 `icvInitEMD`, lines 458-462:

```cpp
lb = dist_func(xs, xd, user_param) / state->weight;
i = *lower_bound <= lb;
*lower_bound = lb;
if (i) return 1;
```

`cvCalcEMD2` returns `*lower_bound` immediately when that result is positive
(255-258). 4.10/5.0 `checkLowerBound`, lines 263-266:

```cpp
const float lb = dfunc(xs, xd, dims) / this->weight;
const bool result = (lowerBound <= lb);
lowerBound = lb;
return result;
```

`init` returns false on that branch (208-211), and `cv::EMD` returns
`*lowerBound` (995-997), without `solve` or `calcFlow`. **Equality exits.**
For a nonnegative metric bound, threshold **zero requests bound-only**, even
when the bound is zero but transport distance is positive. It is not a request
to compute exact EMD too.

## Mass accumulation and availability

Both implementations use `float s_sum`, `float d_sum`, `float diff`.
They scan rows in order, adding only weights greater than zero (4.1 377-405;
4.10/5.0 `calcSums`, 274-303). Zero weights do not contribute; negative weights
are errors. The binding's existing scan checks finite/nonnegative weights,
positive total, widened total overflow, and each native Float32 addition.
It now retains those **same Float32 totals**, rather than performing a second
scan or using a real-number/Ada-wide sum to classify availability.

The native branch is (4.1 412-427; 4.10/5.0 310-325):

```cpp
diff = s_sum - d_sum;
if (fabs(diff) >= CV_EMD_EPS * s_sum) { /* unequal, add dummy */ }
```

`CV_EMD_EPS` is Float32 `1e-5`. Thus availability requires the **strict**
`abs(Sum_1 - Sum_2) < 1e-5f * Sum_1`, evaluated after Float32 accumulation
and subtraction. The reference mass is **Signature_1**, not the maximum or
average: the tolerance is asymmetric. The denominator for the bound is native
`weight = max(s_sum, d_sum)` (4.1 431; 4.10/5.0 329), even when the totals
are slightly different but inside tolerance; this is not exact mass equality.

Outside tolerance, no center bound is calculated and the input lowerBound
value remains untouched. Native still computes transport, possibly inserting
a zero-cost dummy cluster, normalized by the larger total. The binding never
mistakes that untouched input for evidence: it returns Available=False,
Lower_Bound=0, Exact=True and the exact native distance, even at threshold zero.

Tests use exact binary32 totals `0x3f80002a` (1 + 42*2^-23, about 5e-6 relative)
and `0x3f8000a8` (1 + 168*2^-23, about 2e-5). Neither is near the boundary.

## Weighted centers and metric arithmetic

4.1 lines 433-458 and 4.10/5.0 `checkLowerBound` (242-263) zero two Float32
coordinate arrays, then scan **all** rows and dimensions:

```cpp
xs[i] += coordinate1 * weight1;
xd[i] += coordinate2 * weight2;
lb = metric(xs, xd) / weight;
```

Products and weighted sums are native Float32. These are weighted sums, not
separately normalized centroids. Their difference is passed to the same
native metric functions used for pairwise costs, then divided by native mass.
There is no public Ada center formula or alternate transport solver.

The metric helpers (4.1 1098-1147; 4.10/5.0 34-69) subtract Float32 operands
before widening to double. L1 sums absolute differences in double and narrows
to float. L2 sums squared differences in double, **narrows the squared sum to
float before sqrt**, then returns float. C takes the largest absolute
difference, returning float. Hence finite coordinates and finite weights can
still produce nonfinite centers or an overflowing center-distance L2 cast,
even when the pairwise metric preflight passes.

These floating operations do not create a new integer/pointer hazard; legal
rounding and finite precision are not rejected. After native success, distance
must be finite and an available lower bound must be finite and nonnegative.
Otherwise the shim returns the OpenCV-error category and publishes **none** of
the scalar/flag outputs; Ada raises `OpenCV.OpenCV_Error`. This protects a
complete numeric result, not a duplicate public input policy. Native C's
maximum comparison can ignore NaN differences; the binding does not claim to
detect every overflowing intermediate when the returned scalar is finite.
Tests cover nonfinite returned center arithmetic and L2, plus accepted large
finite coordinates with a finite native result.

The default is `OpenCV.Float32_Value'Last`, the largest finite binary32 value.
Under the existing strictly-below-1e20 pairwise-cost input contract, ordinary
valid bounds are far below this threshold: the default computes exact distance
plus native bound evidence. Nonfinite native results are errors, not evidence.

## Allocations, indexing, and Region portability

4.1 allocates its **full legacy work buffer before** the bound check
(342-363), then builds idx1/idx2/s/d. Early exit avoids transport initialization
and simplex work, not that allocation. Its bound adds two distinct hazards:

1. `sz1 = size1 * (dims+1)` and `sz2 = size2 * (dims+1)` are signed int,
   and the loop increments its signed index up to the full product (435-455).
   The existing last-row weight/coordinate-pointer check alone is insufficient.
   The bounded path checks each full rows*columns product against INT_MAX.
2. Center arrays occupy scratch **after** the idx1/idx2/s/d prefix (365-375,
   438-442). The allocation is max(legacy_buffer_size, 2*dims*sizeof(float)),
   not prefix + centers. For very wide, short signatures that maximum can
   omit room for the prefix, causing out-of-bounds writes. The bounded path
   requires prefix + center bytes <= native allocated bytes. A 129-column,
   one-row regression rejects this before native memory access.

Both conditions are documented inline as **ABI safety**, not arbitrary
dimension policy. They apply only when native will calculate the bound.
The existing exact four APIs and their native domain remain unchanged.

4.10/5.0 allocate the linear idx/weight arrays first, calculate sums and bound,
then allocate the larger `area2` cost/delta/is_x arrays and transport nodes
only if the bound does not exit (`init`, 200-231). Their center AutoBuffer uses
`dims*2` and zero-fill byte counts (242-247), covered by the retained dimension
bounds. No additional unsafe pointer/integer behavior was found in this path.

The shared `emd_execute` retains `emd_layout_fits`,
`emd_signature_index_fits`, `emd_weights_safe`, and `emd_costs_safe`.
**The binding retains its full native-safety preflight even when EMD may
early-exit**, including pairwise costs. The shortcut avoids the native
transport/simplex solve; it does not promise linear-time end-to-end rejection.
No second, less-safe bounded input domain is added.

Signatures are deep-cloned to packed private Mats after preflight. This is
necessary for 4.1's step-blind signature indexing and also supplies one uniform
Region behavior on newer versions. Non-contiguous Regions match their packed
clones in distance, bound and both flags; parent data outside Regions is
excluded and all inputs remain unchanged. Core retains Mat ownership.

## Flow and flag interpretation

All three `cv::EMD` wrappers create and zero a requested Flow **before** the
center check (4.1 1163-1168; 4.10/5.0 954-963). An early return leaves that
zero matrix, not a transport solution. The bounded API therefore has **no
Flow**. Callers requiring transport use the existing always-exact
`Earth_Mover_Distance_With_Flow` instead. No explicit-Cost bound is offered
because the native bound requires a metric, not arbitrary user costs.

The binding derives Exact from the source branch using Float32 values:

```text
Exact := not Available or else not (Initial_Threshold <= Returned_Bound)
```

It never compares Distance=Lower_Bound to infer early exit: exact EMD can
legitimately equal its bound. The private C ABI uses scalar outputs and uint8_t
0/1 flags, never exposes a native pointer-valued lowerBound concept to Ada,
requires all output pointers, and publishes from locals only after complete
success. Raw negative finite thresholds retain safe native behavior; finite
nonnegative threshold policy belongs only to thick Ada.

## Validation-boundary review and verification scope

Retained semantic-looking duplicates and concrete reasons:

- Existing signature/cost Float32 C1 layouts and compatible dimensions:
  typed row reads, shim scans and 4.1 packed indexing require these layouts.
- Existing weight and pairwise-cost checks: protect native Float32
  solver/sentinel arithmetic. Their contracts and checks were not weakened.
- Existing allocation/stride/index bounds: protect signed native arithmetic.
- New full signature product and remaining-center-scratch checks: prevent
  signed overflow and out-of-bounds center writes in 4.1, as detailed above.
- New finite distance/available-bound numeric result check: prevents partial
  publication of invalid numeric evidence. It is not public input validation.

Metric selector and required output pointers are raw ABI validation. No
finite/nonnegative threshold policy is duplicated in C++. Availability is an
interpretation of native output, not an input rejection.

Baseline **837** tests plus **18** focused registrations gives **855**.
The original 13 EMD registrations are unchanged; the new suite explicitly
checks all four original exact APIs as well. New coverage includes metric
bounds, inclusive exits, zero-bound-positive-EMD, default exactness, unequal
mass, native tolerance, Regions, threshold errors, derived nonfinite results,
legacy scratch safety, output atomicity and raw/Ada policy separation.
No SPARK-compatible unit is materially changed: foreign wrappers are
runtime-checked and tested, not formally proven. GNATprove/GNATcov results are
not claimed. Strict builds, formatting, full AUnit, exact-header source checks
and CI execution are recorded separately in the feature/PR report.

### Local verification results

- AUnit: **855 registered, 855 executed, 855 passed**, zero failed assertions
  and unexpected errors. Baseline 837/837, 18 new registrations, all 13
  unchanged EMD tests passed. Both normal Alire execution and the clean-Core
  strict-build executable passed the full suite.
- All project-owned library/test Ada bodies force-compiled using Alire-managed
  GNAT 16.1.0 / GPRbuild 26.0.1 with **-gnatwa -gnatwc -gnatwu -gnatwn
  -gnatwe -gnatyM79 -Werror**, no warnings. IEEE NaN/Infinity fixtures use the
  existing EMD test convention for disabling validity interception, not a
  warning suppression; public rejection still specifically requires
  `OpenCV.OpenCV_Error`.
- Production C++ object: **-std=c++17 -Wall -Wextra -Wpedantic -Werror**, PASS.
  Existing EMD index, Bayer, YUV420, YUV422 and morphology-expansion boundary
  helpers also compiled with those switches and passed locally.
- Final production shim syntax checks against the exact public Core/Imgproc
  (and 5.0 Geometry) headers above: all three PASS. Installed generated module
  configuration was used; algorithm declarations came from the exact tags.
  This is source compatibility only, not runtime validation on 4.1/5.0.
- GNATformat plus check mode on all modified Ada, direct 79-column check and
  `git diff --check`: PASS.
- Normal `alr -n build` and `alr -n -C tests run`: PASS. Final strict builds,
  link and full suite used clean detached Core
  **36c2791aedb3fab3f3b585651f7b92666feb5528**, under Core's release policy,
  because the sibling Core contained unrelated work. Production dependency
  metadata was not changed. Project-owned Imgproc/test Ada retained strict
  switches; dependency Ada was not subjected to Imgproc-only gates.