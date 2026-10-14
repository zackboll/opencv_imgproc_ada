# IMGPROC-REL-002 — OpenCV 4.1 release blockers

## Sources, scope and preservation

Fetched origin; intended parent remains `release/imgproc-0.2.0-preparation`
at **793ad2302c518fcc8df846f063ce0a8e72e1af86**. New isolated worktree:
`/home/zboll/git/opencv/imgproc-rel-002`, branch
`corrective/imgproc-0.2.0-opencv41`. All existing worktrees, changes and REL-001
evidence are preserved. Core production code was not changed.

The root manifest is byte-identical to the parent: version `0.2.0`, Core
`~0.4.1`, native OpenCV/pkg_config, Windows mingw_w64_gcc/MSYS2 settings,
Arch Rolling exclusion and root build/test actions. Every build uses actual
indexed Core **0.4.1**, origin **386c5360ac51f2b62e522853d94290aec4ee14a0**.
Updated community index: **068f3873c7732229d4d586836882266494a6d50d**.
No production Core path/source pin is introduced. The tests retain only their
repository-required `..` pin to Imgproc under test.

Independent disk-backed evidence: `/home/zboll/.cache/imgproc-rel-002`.
The existing `/tmp` tmpfs is full; no unrelated files were deleted. Two initial
probe compilations and a historical-tag fetch failed for capacity. Subsequent
commands use disk-backed TMPDIR and native GitHub source inspection. Initial
test build attempts exposed style errors and nested-Alire sandbox-prefix
conflicts; these were corrected without suppressing warnings.

## Reproduction before correction

Fresh library/test compilation from the exact parent sources, with only two
suite selectors added to the runner, reproduced each fixture independently:

* `tests/bin/tests bayer`: **43 run, 42 successful, one assertion failure**,
  `textured native BGR/RGB order`, original line 275.
* `tests/bin/tests automatic-threshold`: **4 run, 3 successful, one unexpected
  OpenCV_Error**, native 4.1 `thresh.cpp:1509`, `src.type() == CV_8UC1`.

Original logs are retained as `baseline-bayer41.log`, `baseline-otsu41.log`,
`baseline-loader41.log`, `baseline-root41.log` and build/toolchain logs in
the evidence directory. Both runtime libraries resolve from the same exact
4.1 installation, not the system 4.10 libraries. Alire's system crate reports
the distro package (4.10) on the host; this is not used as native identity.

## Otsu root cause and contract correction

The public API already allowed native UInt16 rejection on 4.1. Direct
`cv::threshold` reproduces it before destination creation. Upstream tags
4.1/4.2/4.3 accept only CV_8UC1 on the Otsu branch; 4.4 introduces CV_16UC1.
Authoritative introduction:
[`b8cf5d8d5f0550d216160e2f1d1cf028ca903ae5`](https://github.com/opencv/opencv/commit/b8cf5d8d5f0550d216160e2f1d1cf028ca903ae5).
This boundary is established by tag source; real runtime evidence in this task
is rejection on 4.1 and success on 4.6/4.10/5.0, not execution of 4.2/4.3/4.4.

The **same registered test** now requires exactly one behavior per runtime:

* Before 4.4: specifically OpenCV_Error; all source samples unchanged;
  Computed_Threshold retains its -123 sentinel; preexisting destination
  geometry/depth/pixels remain unchanged on this native early-rejection path.
* 4.4 and later: success, finite threshold within sample range, every source
  sample unchanged, correct output metadata, and exact equality to fixed
  Apply_Threshold using the returned value.

`Native_Reference.Version` obtains the linked library version through native
`cv::getVersionMajor/Minor/Revision` and requires header/runtime agreement.
There is no caller-controlled compatibility flag, skip, broad exception catch
or accepting success and failure interchangeably. Public comments clarify the
before-4.4 boundary. The direct-destination ownership contract and existing
success-only threshold assignment are unchanged; no general destination
failure-atomicity promise is invented. No custom Otsu implementation was added.

After correction: automatic-threshold **4/4** on 4.1.

## Bayer root cause and stronger oracle

Standalone `tests/opencv41_reference.cpp` reproduces the original 32x32 texture
formula for all RGGB/GRBG/BGGR/GBRG patterns, BGR/RGB selectors, supported
UInt8/UInt16 depths, bilinear/EA/VNG methods, interior and border pixels.
It records numeric conversion codes and first differing pixel values.

The mapping is correct. Native 4.1 EA has asymmetric scalar interpolation:
one diagonal branch uses `sum >> 2`, the opposite uses `(sum + 2) >> 2`.
The original texture produces **16 interior and 16 outside-interior sample
differences per pattern/depth**, each exactly **one intensity unit**. Example:
UInt16 RGGB at (0,15), BGR channel 2 = 33257, reversed RGB = 33258.
This is rounding, not a channel-order alias error or wholesale red/blue swap.
It occurs with optimization enabled and disabled, including scalar UInt16,
so SIMD-versus-scalar alone does not explain it.

Upstream rounding repair:
[`1fb6c6e6e570b06ddeb6116b01052f06193fdc06`](https://github.com/opencv/opencv/commit/1fb6c6e6e570b06ddeb6116b01052f06193fdc06).
Exact tags show old rounding in 4.5.0 and corrected rounding in 4.5.1.
Actual 4.6/4.10/5.0 probes produce zero reversed-channel differences.
No execution of intermediate versions is implied.

Smallest correction: **tests and documentation only**, not production pixels.
The original registered textured fixture remains and still requires EA to
differ from bilinear. Exact comparison against direct native selectors now
covers every pixel including borders. A new registered physical texture test
covers all four patterns, both supported depths and both output orders:

* Exact all-pixel native oracle, using independent numeric selectors rather
  than the production mapping function.
* Independent physical CFA tile checks: the measured sample is in the requested
  channel at every interior coordinate.
* Negative controls require wrong-order native results to be rejected.
* Source immutability and metadata checked for every case.
* Existing known-color, Region snapshot, owning result/lifetime, invalid layout,
  VNG depth, arithmetic/span and exception regressions remain registered.
* Newer qualified versions retain exact reversed-channel equality as an
  additional assertion. Legacy EA uses the stricter native+physical oracles
  instead of a blanket tolerance.

After correction: Bayer **44/44** on 4.1. Existing 1129 registered tests remain;
the new oracle control makes the complete suite **1130**. Public comments state
the native rounding limitation without promising cross-version bit equivalence.
No production mapping, shim, algorithm, ownership or safety check changed, so
newer production output bits are unchanged by construction.

## Full actual version matrix

| OpenCV | Environment | AUnit | Native boundary/sanitizer corpus |
| --- | --- | --- | --- |
| 4.1.0 | Debian 13 x86_64, source-built installation | **1130/1130**, 0 failures/errors | PASS |
| 4.6.0 | Debian 12 x86_64, distro libraries | **1130/1130**, 0 failures/errors | PASS |
| 4.10.0 | Debian 13 x86_64, distro libraries | **1130/1130**, 0 failures/errors | PASS |
| 5.0.0 | Debian 13 x86_64, source-built installation | **1130/1130**, 0 failures/errors | PASS |

All use GNAT **16.1.0**, Alire **2.1.1**, indexed GPRbuild **26.0.1**
(reports 26.0.0, 2026-04-15). GNAT runtime:
`gnat_native_16.1.0_9f74f58a/lib/gcc/x86_64-pc-linux-gnu/16.1.0/adalib`;
Alire toolchain linker reports binutils **2.46.1**. Host probe C++ is GCC
**14.2.0**, system linker **2.44**; Debian 12 probe C++ **12.2.0**, linker
**2.40**. Actual C++ driver and runtime are recorded per build.

OpenCV 4.1 tag: **371bba8f54560b374fbcd47e7e02f015ac4969ad**.
5.0 tag: **40738fb16ceddb5fb3fea747585f7ce6abb0605b**, reused complete native
installation from the existing source archive (provenance in REL-001).

| Version/module | Actual library | SHA256 |
| --- | --- | --- |
| 4.1 Core | `/tmp/ocv/inst-4.1.0/lib/libopencv_core.so.4.1.0` | `70453b18476d399b3a09ce50431cd22f1da1d5eabc6e12cea4d93538b1499bbf` |
| 4.1 Imgproc | `/tmp/ocv/inst-4.1.0/lib/libopencv_imgproc.so.4.1.0` | `be6e0204a6cdb3abc3e380fc831bb7a381fec05fc820cce7d5fda9a371c584a4` |
| 4.6 Core | `/usr/lib/x86_64-linux-gnu/libopencv_core.so.4.6.0` | `5be065497078dc28beac3ab90bef80d168cb2a444d930d2a8ed467717cc3b79a` |
| 4.6 Imgproc | `/usr/lib/x86_64-linux-gnu/libopencv_imgproc.so.4.6.0` | `178d8d3b40c703fefcb57a3cb8aec0faf5f024d830271ef2971fe885e23929de` |
| 4.10 Core | `/usr/lib/x86_64-linux-gnu/libopencv_core.so.4.10.0` | `f858246820b4cfa078c0c0776ac08d56d2e664c7be89fd214b3dfe777bfab2fe` |
| 4.10 Imgproc | `/usr/lib/x86_64-linux-gnu/libopencv_imgproc.so.4.10.0` | `423afee50896b6f58c477d1696f973adc8c9dcd9cf3e9efdffedf0b8f89b234e` |
| 5.0 Core | `/home/zboll/.cache/video-task004/install-5.0.0/lib/libopencv_core.so.5.0.0` | `4c30edbfff25b04b6934f7968f1ab2cc646447df2360138caaae640323d3f7b2` |
| 5.0 Imgproc | `/home/zboll/.cache/video-task004/install-5.0.0/lib/libopencv_imgproc.so.5.0.0` | `ba5c0be27bd4829a3cea27cbaf4b0e3a0730e5368291352b443730831fdd6e44` |

Each matrix loader log checks both libraries and absence of unresolved symbols.
Native campaigns include all existing arithmetic boundaries and ASan/UBSan
production corpora: subpixel, spatial gradient, squared-box, Ballard/Guil,
all five masked matching paths, plus Bayer gray legacy safety regression.
New standalone native Bayer/Otsu probes pass ASan/UBSan on every version with
optimized execution on and off. Installed OpenCV itself is not sanitizer-built;
claims cover instrumented probes/shims, not every native library instruction.

## Indexed dependency, installation and documentation

Fresh sandboxed root/test builds select community-index Core 0.4.1. The full
production C++ shim compiles and links; installed bridge discovery is tested.
Debian 12 independent GPRinstall driver passes with exact release Core source
(compared with indexed deployment), followed by separate source-free,
Alire-free installed/relocated Ada and mixed C++ consumers, all four PASS.
ELF and `ldd -r` checks select `.so.406` Core/Imgproc and report no missing
library or undefined symbol. Native reference helpers stay in the test crate;
the public library has no new test dependency or API.

GNATdoc generation: **zero warnings**, **1512/1512 coverage**, full links/type
links/search navigation and five guides validated. Landing page plus all five
guide programs compile and run. Helper controls: type links **23/23**,
generated-site validator **43/43**, navigation/guides **25/25**. No baseline
was weakened. Modified test Ada sources are GNATformatted. Public source changes
are comments only; no SPARK-compatible implementation changed or new proof
claim is made.

## Exact commit preflight, review and hosted scope

The final immutable correction SHA, generated index origin, fresh unpinned
consumer results and local/remote/PR HEAD parity are recorded in the handoff.
Only `alr publish --skip-submit` and a temporary private index are permitted.
No tag, GitHub Release, public Alire PR, merge, amend or force-push is authorized.

The correction PR targets the exact intended release parent, not unrelated
main. Existing platform/documentation/installed-consumer and source/cross
controls are retained. The standalone matrix runner provides independently
executed exact-source OpenCV 4.1/4.6/4.10/5.0 evidence; ordinary hosted CI does
not substitute its current packaged OpenCV for this pinned version matrix.
Final source identity checks compare tested exports with the committed tree.
The first corrective hosted macOS run built the production library but failed
compiling the new test oracle (`limits` not found). The helper now uses the
same explicit SDK sysroot and existing C11-header-extension policy as the
production Apple configuration; this is a test-toolchain correction, not a
binding change. Original hosted diagnostics are retained; corrected-head
results must be checked again. Windows provisioning status is independent.

Parent candidate hosted runs **38517425873** (all three platform jobs),
**38517428098** (documentation) and **38517430338** (installed consumers) all
completed **success**. Corrected-head hosted IDs/conclusions belong in the
handoff; pending jobs must not be described as complete. Windows provisioning
failures, if any, must be separated from compilation failures.

Local dispositions: **OPENCV41_BAYER_QUALIFIED**, **OPENCV41_OTSU_QUALIFIED**,
**FOUR_VERSION_MATRIX_QUALIFIED**. **PIN_FREE_ALIRE_QUALIFIED** additionally
requires fresh final-origin consumer evidence. **RELEASE_CANDIDATE_READY** is
not inferred while required corrected-head hosted checks/review remain open.
GNAT 12 production and actual AdaCore/Yocto target execution remain outside
the supported native GNAT 16 scope, as recorded in REL-001.

No public semantic validation is duplicated in the C++ shim. Production shim
source is unchanged; no new validation-boundary guards were introduced.