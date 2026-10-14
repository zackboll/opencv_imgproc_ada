# IMGPROC-EXT-003A — GNAT 12 native and AArch64 qualification

## Dispositions (not an overall PASS)

* **COMPILER_POLICY_QUALIFIED**: retain the native project's default language
  selection; do not globally force Ada 2022 in generated cross configuration.
* **IMGPROC_GNAT12_UNITS_QUALIFIED**: actual production
  `opencv-image_processing.adb` and
  `internal/opencv-image_processing-internal-c_api.adb` compile independently
  under native and AArch64 GNAT 12, with real Core specifications and matching
  compiler runtimes. This is not a complete dependency build or link.
* **IMGPROC_CXX_AARCH64_OBJECT_QUALIFIED**: the complete unchanged production
  shim compiles with Debian GCC 12 and OpenCV 4.6 headers in the explicit target
  sysroot; readelf establishes ELF64, little-endian, AArch64.
* **CORE_PREREQUISITE_BLOCKED**: complete GNAT 12 builds fail in Core.
* **YOCTO_SCARTHGAP_PENDING**: no Yocto SDK or target execution was qualified.

Neither **GNAT12_NATIVE_QUALIFIED** nor
**GNAT12_AARCH64_CROSS_BUILD_QUALIFIED** is established. Successful source-unit
and C++ object controls cannot be combined into either production claim.

## Source/worktree identity and reconciliation

Fetched both repositories before starting. Initial remote main revisions exactly
matched the requested baselines:

* Imgproc: `fd95ed8f7f9a98a4c5b9544f0962a0e5e7bebad5`.
* Core: `f4bd2167ecc0a74162a00c6597772a2a67ea84b0`.

Created `/home/zboll/git/opencv/imgproc-ext-003a`, branch
`feature/imgproc-ext-003a-gnat12-compatibility`, from fetched Imgproc main.
Existing worktrees/branches were preserved. The original working directories
were not assumed to be main (their HEADs differed from remote main).

Core PR #78 was initially OPEN at
`1536c7411d1dfcd79af3f01dcfc42f74e51a66a7`. During qualification it merged,
advancing main to `c0709f864a2f426c40eeaf1d21486c6d9859a741`.
The reconciliation diff contains cross policy, tests, workflow and documentation
only; no Core production Ada declaration changed. Nevertheless fresh source
exports and independent output directories were used to repeat the compiler
controls, GNAT 16 build/suite, GNAT 12 production attempts and installed consumers
with that exact merged revision. The added CI pins this reconciled Core SHA.
No unmerged Core candidate or Core production edit was used.

Imgproc production sources tested are the starting SHA: the only functional
production change is one generated compiler-policy expression. No manifest,
version, public Ada source, GPR ownership rule, C++ source or ABI assertion changed.
Final feature commit identity and hosted evidence are recorded in the PR, avoiding
a self-referential commit hash in this document.

## Actual environments and identities

Isolated Podman container `imgproc-ext-003a`, image
`localhost/core-ext-003-r2-env:latest` (`a8a79ce24527`, inspect for full digest),
Debian GNU/Linux 12/bookworm, amd64. Existing reference containers were not
modified. New packages were installed only in this disposable container.

| Item | Exact identity |
| --- | --- |
| Native Ada/C++ | gcc/gnat/g++ 12.2.0, Debian `12.2.0-14+deb12u1`, `x86_64-linux-gnu` |
| Native Ada runtime | `/usr/lib/gcc/x86_64-linux-gnu/12/adalib` |
| Cross Ada/C++ | 12.2.0, Debian GNAT/G++ `12.2.0-14cross1`, `aarch64-linux-gnu` |
| Cross Ada runtime | `/usr/lib/gcc-cross/aarch64-linux-gnu/12/adalib` (archive ELF checked) |
| Native comparison | GNAT 16.1.0, `gnat_native_16.1.0_9f74f58a` Alire toolchain |
| GPRbuild | Alire 26.0.1 distribution, reports `26.0.0 (2026-04-15)` |
| Alire | 2.1.1 |
| Native OpenCV | 4.6.0, Debian `4.6.0+dfsg-12` |
| Target Core/Imgproc OpenCV packages | arm64 `4.6.0+dfsg-12`, SONAME `.406` |
| GNATdoc | 26.0.0 (20260415) |

The exact GNAT 16 runtime belongs to its Alire toolchain, not Debian GNAT 12.
Source copies, native12, cross12, explicit-language unit directories and GNAT 16
outputs are separate. Unit tests use new temporary directories for every compile;
no existing ALIs or objects are used. Compiler identity, full diagnostics and
commands remain under `/tmp/imgproc-ext-003a-evidence`; reconciled runs are under
its `reconciled/` directory. Installed evidence is separately retained under
`/tmp/imgproc-ext-003a-installed-retry` and its `-artifacts` sibling; earlier
attempt logs remain under the `-installed-r2` and `-installed-current` paths.

## Reproduction commands

In an export containing sibling real Core and Imgproc crates, select GNAT 16 and
GPRbuild through Alire (never change production manifests):

```sh
alr -n build
alr -n -C tests run
alr exec -- gprbuild -P opencv_imgproc.gpr --subdirs=native12-production \
  --compiler-subst=Ada,gcc-12 -cargs:Ada -gnatwa -gnatwe -Werror
```

Exploration adds `-k` and uses another subdirectory. Keep-going results are
diagnostic evidence only. The non-keep-going native attempt fails in Core.
Alire reports exit 1 wrapping GPRbuild's compilation failure/code 4.

Independent compiler controls, from the Imgproc checkout:

```sh
CORE_SOURCE=/path/to/exact/core ADA_COMPILER=gcc-12 \
  python3 -m unittest discover -s tests -p test_gnat12_language_policy.py -v
CORE_SOURCE=/path/to/exact/core ADA_COMPILER=aarch64-linux-gnu-gcc \
  python3 -m unittest discover -s tests -p test_gnat12_language_policy.py -v
CORE_SOURCE=/path/to/exact/core ADA_COMPILER=/path/to/gnat16/bin/gcc \
  python3 -m unittest discover -s tests -p test_gnat12_language_policy.py -v
```

Each run has four tests, exercising default/2012/2022 controls and actual thin
representations; all four pass on each of the three compilers and both selected
Core revisions. Original explicit-Ada-2022 failures are expected negative tests,
not mocked output or warnings suppressed to achieve success.

Actual target-configured Core prerequisite attempt (fresh output directory):

```sh
alr exec -- gprbuild --config=/reference/r2-head/target.cgpr \
  -P opencv_core.gpr --subdirs=cross12-production \
  -cargs:Ada --sysroot=/reference/r2-head/sysroot -gnatwa -gnatwe -Werror \
  -cargs:C++ --sysroot=/reference/r2-head/sysroot
```

The supplied CGPR selects the actual AArch64 compiler/runtime. This fails before
there is a qualified installed Core archive/ALI closure or cross-identity.json.
Imgproc's fail-closed EXT-002A wrapper is preserved: there is no genuine Core
prefix satisfying its production preflight, so the full Imgproc wrapper build,
cross installation, installed target consumers and target execution are not run.
No target attestation or installed library was fabricated to proceed.

## Diagnostic classification and aggregate analysis

Forced `-gnat2022 -gnatwa -gnatwe -Werror` on the actual thick body produces the
same native/cross eight Imgproc obsolete-array diagnostics:

```text
opencv-image_processing.adb:90:17: warning: array aggregate using () is an obsolescent syntax, use [] instead [-gnatwj]
```

Other array sites: 216:17, 3467:09, 7341:09, 8996:10, 10564:60,
10585:60 and 10784:15. These are null array returns, morphology/drawing scalar
arrays, the nested Values array in a Scalar4 record, and single-Mat arrays.
The outer Scalar4 record aggregate is not an array. Ordinary conditional
parenthesized expressions and C-compatible record aggregates are not rewritten.

Forced Ada 2022 also produces:

```text
opencv-image_processing.adb:7124:35: error: ambiguous call to "Append"
opencv-image_processing.adb:7124:35: error: possible interpretation at a-convec.ads:471, instance at opencv-image_processing.ads:6823
opencv-image_processing.adb:7124:35: error: possible interpretation at a-convec.ads:483, instance at opencv-image_processing.ads:6823
opencv-internal-c_api.ads:565:26: error: C Vec3 size mismatch
```

The Append argument is a named contour-hierarchy **record** aggregate, not an
obsolete array. The overload ambiguity is language-mode-dependent: default and
Ada 2012 compile this unchanged expression on GNAT 12 and 16. There is no
justification to rewrite it as an array or change the supported native policy.
The Core Vec3 diagnostic on this failed-unit path is secondary, not independent
measurement of an ABI mismatch: unchanged real declarations compile successfully
in the thin-body and default thick-body controls. No representation gate removed.

No Imgproc unit examined requires Ada 2022: the entire thick body passes default
and explicit Ada 2012; the thin body also passes Ada 2022. Native Alire generated
flags leave language unspecified; GNAT's default is Ada 2012. GNAT 16 exhibits
the same forced-mode negative control. Core's typed_access body's pre-existing
local Ada 2022 GPR switch remains intact. Removing only Imgproc's generated global
override preserves that per-project/per-unit responsibility and warning policy.

Core's first independently established native and cross production failure:

```text
opencv-core-float16_vec2_buffer_access.adb:23:41: error: condition is not known at compile time
opencv-core-float16_vec2_buffer_access.adb:31:39: error: condition is not known at compile time
opencv-core-float16_vec2_buffer_access.adb:39:04: error: instantiation error at opencv-core-internal-typed_continuous_borrowing.adb:28
opencv-core-float16_vec2_buffer_access.adb:39:04: error: condition is not known at compile time
```

Line 23 tests Buffer_Array'Component_Size; line 31 tests Vector'Alignment;
the shared generic line 28 tests Element_Type'Alignment. These are GNAT 12
compile-time/static-expression and generic-instantiation limitations, not an
independently proven wrong layout. Mat view and row borrowing units likewise
report unknown compile-time conditions. Initial keep-going Core logs retain all
diagnostics including later C Vec3 messages. Core PR #78 fixes language policy,
not these conditions. No Core alignment candidate was copied or altered.

## C++ object and selected ABI evidence

Compiled the complete actual production shim, not a minimal surrogate:

```sh
g++-12 -std=c++17 -Wall -Wextra -Werror -fPIC \
  -I/path/to/core/cpp -I/usr/include/opencv4 \
  -c cpp/opencv_imgproc_shim.cpp -o /separate/native/shim.o
aarch64-linux-gnu-g++ --sysroot=/reference/r2-head/sysroot \
  -std=c++17 -Wall -Wextra -Werror -fPIC -I/path/to/core/cpp \
  -I/reference/r2-head/sysroot/usr/include/opencv4 -H \
  -c cpp/opencv_imgproc_shim.cpp -o /separate/cross/shim.o
readelf -h /separate/native/shim.o /separate/cross/shim.o
g++-12 -std=c++17 -Wall -Wextra -Werror -Icpp \
  -c tests/gnat12_abi_layout.cpp -o /separate/native/layout.o
aarch64-linux-gnu-g++ -std=c++17 -Wall -Wextra -Werror -Icpp \
  -c tests/gnat12_abi_layout.cpp -o /separate/cross/layout.o
```

All four compilations pass. ELF machine types are x86-64 and AArch64 respectively.
Target OpenCV header trace uses the explicit sysroot; standard C++/C headers
come from Debian's AArch64 cross-toolchain include directories and sysroot, not
the x86-64 library/header paths. Target libopencv_imgproc.so.406 is independently
ELF64 little-endian AArch64. Debian supplies architecture-independent OpenCV
headers shared between development packages. The reference sysroot headers
match the installed 4.6 declaration. The compile-only shim command does not
resolve OpenCV libraries via host pkg-config. Target-only opencv4.pc is absent in
this partial sysroot; no target link/pkg-config production qualification is
claimed. This is an additional integration limitation, not a shim object failure.

`-gnatR3` on the actual thin body establishes both native and target layouts.
The C test includes the actual production header; it does not redefine ABI
records. Size/alignment in bytes and ordered field offsets:

| Ada / C record family | size/alignment | field offsets |
| --- | --- | --- |
| Guil parameters | 72/8 Object_Size | 0,8,16,24,32,40,48,52,56,60,64 |
| Corner_Point / Point_F32; Point_I32 | 8/4 | 0,4 |
| Contour span | 8/4 | 0,4 |
| Hough line evidence | 24/8 | 0,8,16 |
| Hough circle evidence | 16/4 | 0,4,8,12 |
| Hough line | 8/4 | 0,4 |
| Hough segment | 16/4 | 0,4,8,12 |
| Hough circle | 12/4 | 0,4,8 |
| Hit-or-miss facts | 5/1 | 0,1,2,3,4 |
| Scalar4 | 32/8 | Values at 0; double stride 8 |
| Rect_I32 | 16/4 | 0,4,8,12 |
| Histogram dimension | 16/4 | 0,4,8,12 |
| Histogram source dimension | 20/4 | 0,4,8,12,16 |
| Histogram nonuniform dimension | 24/8 | 0,4,8,16 |

Guil Value_Size is 544 bits (68 bytes), Object_Size 576 bits (72 bytes): tail
padding is not a mismatch. Array Component_Size agrees with each C element's
sizeof, including the 12-byte circle and 24-byte nonuniform dimension. Additional
buffer strides: Float32 boundaries 4, morphology scalar/double 8, borrowed Mat
handle pointer 8; Status and selectors 4, boolean facts 1. Opaque handles expose
no C++ object layout. Mat lifetime/layout remains Core-owned; the existing module
bridge is used without competing handles or ownership rules.

These selected data layouts agree on both sides; this is not complete ABI
qualification of all calls, Core object representation or target integration.
No target executable was run, and calling-convention execution is not established.

## Native regression and tooling

GNAT 16.1 production build and full AUnit suite pass against initial and
reconciled Core: **1129 tests, 1129 successes, zero failures/errors**.
Debian 12/OpenCV 4.6 independent Core/Imgproc GPRinstall and installed/relocated
Ada and mixed C++ consumers pass, with ELF/dependency checks, using the existing
`scripts/qualify_debian12_consumers.sh` and reconciled Core source worktree.
An initial consumer driver failed because its source identity check correctly
rejected a git-archive Core export; retry used a genuine detached worktree.
The first reconciled consumer rerun exhausted the shared `/tmp` filesystem while
copying toolchains. Removed only redundant task-created toolchain copies (not
logs or predecessor worktrees), then used a new evidence directory for retry.
One keep-going diagnostic rerun encountered an Alire fingerprint failure after
that capacity incident; the already-selected GPRbuild executable with the explicit
target CGPR reproduced the complete Core diagnostics (exit 4) independently.

GNATdoc generation with the repository script passes: **zero warnings** and
**1512/1512 documentation coverage items**, complete links/anchors and compiled
guides. Initial guide generation found missing markdown_it; installed the pinned
docs requirements in a disposable venv, then reran successfully. No gate weakened.
Synthetic cross controls: **30/30** on host and Debian Python 3.11.
Shell syntax and git diff checks pass. No Ada/SPARK source changed, so Ada
formatting and a new proof campaign are not applicable. ShellCheck was not
available locally; hosted existing cross workflow retains that check.

Only OpenCV **4.6** was executed in this task; no 4.1/4.10/5.0 result is implied.
Existing Linux/macOS/Windows, documentation, installed-consumer and synthetic
cross workflows remain unchanged. New hosted job explicitly labels real source
controls as non-production qualification and uploads exact source/compiler/
runtime diagnostics. Hosted run IDs/conclusions belong to the final PR handoff;
local Linux results do not imply hosted or macOS/Windows success.
Inspected parent hosted cross-platform run `38505302034`: Linux and macOS pass;
Windows fails deploying the MSYS2 OpenCV system package before compilation.
Parent cross controls `38505301866`, installed consumers `38505301943`, and
documentation `38505301956` pass. This existing Windows failure is not hidden or
fixed speculatively by this compiler-policy task.
Initial feature compiler workflow runs `38506706853` and `38506703305` failed
before compiler controls because Git rejected container checkout ownership.
The follow-up trusts only the two exact checkout paths (not a wildcard) before
checking SHAs; it does not weaken source identity or compiler tests.

## Next executable gate

Independently correct and qualify Core's GNAT 12 compile-time component-size /
alignment and generic representation-condition failures without relaxing checks.
Then build genuine native and target Core libraries with matching runtimes;
complete target-only OpenCV pkg-config/sysroot closure and authentic Core build
identity before invoking Imgproc's unchanged fail-closed production cross wrapper.
Only after complete production compilation, tests, ABI/integration and target
gates pass should full GNAT 12 or Yocto support be claimed.

No public semantic validation is duplicated in the C++ shim by this task;
production shim source is unchanged.