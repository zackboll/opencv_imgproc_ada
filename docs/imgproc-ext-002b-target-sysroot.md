# IMGPROC-EXT-002B — AArch64 target dependency qualification

## Scope and source preservation

Fetched both origins before work. Remote main exactly matched:

* Imgproc `19ce3641254a3a9f5c97feca10fb3f2ef4a7f2b5`.
* Core `c0709f864a2f426c40eeaf1d21486c6d9859a741`.

Original checkout HEADs were respectively
`cc1e7a5c4c642ee8029d0de054a49035d3d844de` and
`769d286cc16d782936c45ecd1d7220606e98b81a`; neither checkout was reset.
Created `/home/zboll/git/opencv/imgproc-ext-002b`, branch
`feature/imgproc-ext-002b-target-sysroot`, from fetched Imgproc main, and a
detached dependency worktree `/home/zboll/git/opencv/ext-002b-core` at fetched
Core main. Existing worktrees and SDK artifacts were preserved. No production
Ada declaration, C ABI record, layout assertion, manifest, or Core source changed.

Final commit identity, PR URL, and hosted run identities are recorded in the PR
handoff, not as a self-referential SHA here.

## Dispositions

* **TARGET_SYSROOT_QUALIFIED**: genuine Debian 12 arm64 package staging,
  contained headers/libraries, AArch64 ELF checks, compiler/GNAT runtime identity.
* **TARGET_PKGCONFIG_QUALIFIED**: unmodified Debian `opencv4.pc`; advertised
  shared libraries and recursive DT_NEEDED closure resolve to target files.
* **TARGET_OPENCV_LINK_QUALIFIED**: real Core/Imgproc C++ probe links, with
  both `.406` modules in DT_NEEDED and qualified linker input traces.
* **IMGPROC_CXX_OBJECT_QUALIFIED**: unchanged production shim compiles to
  ELF64 little-endian AArch64, using the exact Core source bridge header.
* **CORE_PREREQUISITE_BLOCKED**: no genuine installed AArch64 Core Ada
  project/archive/ALI/identity closure is available. No such artifacts fabricated.
* **PRODUCTION_CROSS_BUILD_PENDING**: final Ada/C++ integration, installation,
  target consumers and target execution have not been established.
* **YOCTO_SCARTHGAP_PENDING**: no actual Scarthgap SDK was found or substituted.

These are independent dispositions, not an aggregate release PASS. No AArch64
executable was run on the x86_64 host.

## Original failure, reproduced without changing predecessor artifacts

A new disposable `imgproc-ext-002b-diagnosis` container used the predecessor
image `a8a79ce24527fb6f00810820297d5dd4ecec4aee137726796ac6a545243d585e`.
The actual `/reference/r2-head/sysroot` has only `libopencv_core.so` and
Core-only reference `usr/lib/pkgconfig/opencv4.pc`, not Debian production
metadata. Its version is 4.6.0, include `/usr/include/opencv4`, library
`/usr/lib`, Cflags `-I${includedir}`, Libs `-L${libdir} -lopencv_core`.
Pkg-config applies the sysroot to those paths. Core ELF is AArch64.

Running the existing `configure_cross_opencv.sh --check` with its actual
cross compilers, GNAT runtime and predecessor CGPR fails:

```text
error: missing or invalid target path: /reference/r2-head/sysroot/usr/lib/libopencv_imgproc.a
```

Classification: incomplete reference packaging, not a reason to weaken checks.
Separately, the old flag allowlist rejects Debian's legitimate broad OpenCV
module list. The replacement resolves and verifies those libraries rather than
accepting arbitrary flags or supplying synthetic metadata.

## Genuine Debian reference construction and provenance

New container `imgproc-ext-002b-target` starts from Debian 12, separate from
all Core reference containers. Local base image repository digest:
`sha256:813017f3d62be4b5891a7acca6a01bdcd4b8513daa81b1ab99d3a50385b26931`.
The checked-in container recipe pins that digest. CI uses its separate Debian
12 container and records package identities.

Install native tools `python3`, `pkg-config`, `binutils`,
`g++-aarch64-linux-gnu`, `gnat-12-aarch64-linux-gnu`, then run:

```sh
sh scripts/prepare_debian12_target.sh /target /evidence/debian
```

The script enables arm64 only in the disposable container, downloads Debian
development/runtime dependency packages with apt, extracts only arm64/all
packages into a NEW staging directory, and retains package archives, versions,
SHA256 sums and apt source configuration. No x86_64 OpenCV library is staged.
The recorded archives are the exact replay inputs; live Debian repositories
may subsequently provide newer security packages, so compare manifests rather
than assuming a future apt invocation is byte-identical.

| Package | arm64 version |
| --- | --- |
| libopencv-dev, Core/Imgproc dev/runtime | 4.6.0+dfsg-12 |
| libc6 | 2.36-9+deb12u14 |
| libstdc++6, libgcc-s1 | 12.2.0-14+deb12u1 |
| libblas3, liblapack3 | 3.11.0-2 |
| libtbb12 | 2021.8.0-2+deb12u1 |

Actual compiler/GNAT packages: `12.2.0-14cross1`, full compiler version
`12.2.0`, triple `aarch64-linux-gnu`. GNAT runtime:
`/usr/lib/gcc-cross/aarch64-linux-gnu/12`, with real adainclude/adalib and
AArch64 `libgnat.a`. Cross GCC startup/static runtime files are separately
compiler-reported and ELF checked. Compiler libstdc++ and sysroot libstdc++
need not have identical package bytes: target GLIBCXX/CXXABI symbol versions
must include the compiler runtime's symbol versions. The probe explicitly
links the staged target libstdc++ runtime.

Layout:

* `/target/usr/include/opencv4/opencv2`: genuine development headers.
* `/target/usr/lib/aarch64-linux-gnu`: OpenCV `.so` symlinks and `.4.6.0` ELFs.
* `/target/usr/lib/aarch64-linux-gnu/pkgconfig/opencv4.pc`: genuine metadata.
* `/target/lib/aarch64-linux-gnu`: libc, loader and GCC shared runtime.
* `/target/usr/lib/aarch64-linux-gnu/{blas,lapack}`: target numerical libraries.

## Independent gates and link contract

Gate A checks target names, compiler triples, contamination environment, GNAT
runtime association/architecture. Gate B checks sysroot, metadata, headers,
OpenCV versions/SONAMEs, concrete advertised libraries and recursive target
dependencies. Read-only `--check-sysroot` runs without installed Core or CGPR:

```sh
export OPENCV_CROSS_TARGET=aarch64-linux-gnu ENV_PREFIX=/target
export OPENCV_CROSS_ADA=aarch64-linux-gnu-gcc
export OPENCV_CROSS_CXX=aarch64-linux-gnu-g++
export OPENCV_CROSS_RUNTIME=/usr/lib/gcc-cross/aarch64-linux-gnu/12
export OPENCV_CROSS_PKG_CONFIG=pkg-config
export PKG_CONFIG_SYSROOT_DIR=/target
export PKG_CONFIG_LIBDIR=/target/usr/lib/aarch64-linux-gnu/pkgconfig
export PKG_CONFIG_PATH=
sh scripts/configure_cross_opencv.sh --check-sysroot
OPENCV_CROSS_CORE_BRIDGE=/core-source/cpp \
  python3 scripts/qualify_target_opencv.py /evidence/NEW-link
```

Gate C remains mandatory in full `--check`, `--prepare`, and `--build`: supplied
target CGPR, installed externally-built Core project/import closure, archives,
ALIs and authentic build attestation. Gate D remains actual production build
and install. A partial result has `production_qualified: false` and cannot
authorize a production workspace. Actual full-check attempt stopped with
`error: OPENCV_CROSS_GPR_CONFIG is required`; Core artifacts were not invented
to get past this diagnostic.

Debian metadata returns `-I/target/usr/include/opencv4`,
`-L/target/usr/lib/aarch64-linux-gnu` and the standard broad module list
(`stitching`, contrib modules, `highgui`, `videoio`, `viz`, `dnn`, etc., ending
in `imgproc`, `core`). This does not add bindings for those modules. Every
advertised shared library and its recursive DT_NEEDED closure is validated;
the independent probe selects explicit resolved Imgproc/Core ELFs only.
Full raw flags, metadata hash and the concrete closure hashes/edges are in
`sysroot.json`; selected arguments are in `command.json`. Unknown library
families, linker arguments, escaped/broken links, ambiguous or unresolved
dependencies and host paths fail closed. Absolute ELF runtime search paths
are interpreted against the target root and must resolve there; they are not
host build search paths.

Core graph includes BLAS, LAPACK, TBB, libstdc++, libm, libgcc and libc;
Imgproc depends on Core and the C++ runtime. BLAS/LAPACK introduce libgfortran.
The executable DT_NEEDED contract is exactly:

```text
libopencv_imgproc.so.406
libopencv_core.so.406
libstdc++.so.6
libgcc_s.so.1
libc.so.6
```

The first real probe attempt failed: linker could not find BLAS/LAPACK in
their package subdirectories and its default development search selected
external Debian cross libc files. Corrected probe uses explicit staged
startup/library search, qualified rpath-link directories and target libstdc++.
Only exact compiler-reported startup/static runtime files may be outside the
sysroot; all are target architecture checked. No native development library
resolution is accepted. GCC's x86_64 *build-host* identity in `-v` is not an
include-search contamination; actual include search is inspected separately.

Final local evidence: `/home/zboll/git/opencv/ext-002b-evidence/link-final`.
Probe and production shim readelf: **ELF64, little-endian, AArch64**.
The bridge header is from the exact detached Core source, with SHA256 recorded
in `bridge.json`, not a claimed target installation. Final integration linking
was not attempted because genuine Core target artifacts are unavailable.

## Tests and regression evidence

All original 30 synthetic controls retained; nine additional negative controls
exercise unresolved advertised/transitive dependencies, broken library symlink,
embedded host search and partial-to-production promotion. Two opt-in genuine
sysroot tests use real binaries/metadata, not fixtures. Debian execution:
41 tests pass. Host execution: 39 pass, two genuine SDK tests explicitly skip.
Existing negative controls retain version/SONAME, wrong ELF/class/endian,
compiler triple/runtime, host environment/flags, mixed ALI, Core prerequisite,
wrong sysroot and symlink coverage. Synthetic fixtures are not ELF evidence.

GNAT 16.1 Debian native production build and full suite:
**1129 tests, 1129 successes, zero failures/errors**. Independent Core/Imgproc
installation and installed/relocated Ada and mixed C++ consumers pass.
`consumers/status.log`: exit 0. Core source for this qualification is the exact
requested SHA. GNAT 12 real source-unit controls pass, native and AArch64:
four tests each. Shell syntax and diff whitespace checks pass.

No public semantic validation is duplicated in the C++ shim. Its production
source is unchanged. No SPARK source changed, so a new proof/coverage campaign
is not warranted for these Python/shell controls. Documentation generation:
zero warnings, 1512/1512 coverage items, compiled guides and links pass. The
first documentation attempt lacked a Markdown virtualenv; pinned requirements
were installed in a disposable documentation environment and the rerun passed.

Dedicated hosted `target-dependency.yml` checks exact Imgproc/Core SHAs,
constructs genuine target staging, runs negative and integration tests,
links/inspects the probe, compiles the shim and publishes package/ELF/trace
evidence. Its title explicitly says **not production cross-build**. Existing
Linux/macOS/Windows, consumer, source-unit and documentation workflows remain.

## Yocto Scarthgap readiness and remaining gates

Source the genuine SDK's environment-setup script in a separate shell. Supply
its exact AArch64 target triple, compiler executable paths, target sysroot,
native SDK pkg-config executable, target-only PKG_CONFIG_LIBDIR and correct
PKG_CONFIG_SYSROOT_DIR. Empty PKG_CONFIG_PATH and development search overrides
are required. Environment CC/CXX strings containing CPU/sysroot arguments are
not executable paths: supply driver paths explicitly; retain required SDK
options in a reviewed compiler wrapper or extend the machinery with separately
validated options. Do not silently strip required SDK tuning options.

Supply matching real GNAT runtime (adainclude, adalib, libgnat), GNU readelf,
OpenCV headers and shared development/runtime closure. Version/SONAME and
C++ ABI symbol versions must qualify independently. Gate C additionally needs
the actual installed Core prefix, target CGPR, matching GPR tools and authentic
identity metadata. Native SDK tools are not target libraries. The Debian probe's
multiarch startup search is Debian-specific; a genuine Yocto probe must use
that SDK's qualified layout rather than pretending it is Debian multiarch.

No Scarthgap environment-setup script was found in the inspected SDK locations.
No SDK was downloaded. **YOCTO_SCARTHGAP_PENDING** remains until exact SDK
identity, required compiler options, sysroot/link/runtime and real target
execution are qualified. Debian success is not Yocto qualification.

Next production gate: genuine compatible AArch64 Core Ada build/install,
unchanged ABI checks, complete ALIs/shim artifacts and authentic identity.
Then rerun full Imgproc preflight, production build/install, installed target
consumers, target ABI execution and real Scarthgap qualification. No release
tag, Alire index submission, merge or auto-merge is authorized by partial gates.