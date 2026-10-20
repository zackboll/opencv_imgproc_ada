# IMGPROC-EXT-002C — External AdaCore / post-Yocto integration preflight

Historical preflight evidence. For the complete production workflow and current
vendor gate see [IMGPROC-CROSS-UX-001](imgproc-cross-ux-001-qualification.md).
The original results below are preserved and do not become vendor qualification.

## Scope and exact sources

Both origins were fetched on 2026-10-14. Their remote main revisions exactly
matched the requested baselines; there were no incoming changes to reconcile:

* Imgproc: `d77b79d01e86452171b6931c4de693a18b6dc78b`.
* Core: `23a8a4796691cd3fe552db4aa0e8351e691a53b5`.

The requested worktree path was already occupied by a dirty worktree on
`feature/imgproc-ext-002c-yocto-sdk`. With explicit user approval, the new branch
`feature/imgproc-ext-002c-adacore-cross` uses
`/home/zboll/git/opencv/imgproc-ext-002c-adacore-cross`. Existing branches,
worktrees and edits were preserved. A detached Core reference is at
`/home/zboll/git/opencv/core-ext-002c-reference`; Core production sources were
not edited. No manifests, release versions, public API, ABI assertions or
production semantics were changed.

## Actual external inputs and independent dispositions

No external AdaCore AArch64 compiler/runtime was supplied or found in the
inspected `/opt`, `/usr/local`, Alire toolchain locations or exported cross
environment. Available Alire compilers are **native** GNAT 13.2.1, 15.3.1 and
16.1.0; project tools include GPRbuild 22.0.1 and 26.0.1. These are not an
AdaCore cross-toolchain qualification. Host GCC 12 lacks `gnat1`.

No matching Yocto Scarthgap development sysroot, build/image identity or export
provenance was supplied. No environment-setup script was found in inspected
locations. Existing Debian target staging is not substituted for Yocto.

| Disposition | Result for actual AdaCore/Yocto workflow |
| --- | --- |
| ADACORE_TOOLCHAIN_QUALIFIED | NOT ESTABLISHED: tools/runtime unavailable |
| YOCTO_SYSROOT_QUALIFIED | NOT ESTABLISHED: matching development inputs unavailable |
| ADACORE_YOCTO_ABI_QUALIFIED | NOT ESTABLISHED: real compilation/link/closure unavailable |
| IMGPROC_CXX_AARCH64_QUALIFIED | NOT ESTABLISHED for AdaCore/Yocto; Debian compile-only is separate |
| CORE_PREREQUISITE_BLOCKED | No authentic intended-toolchain target Core installation |
| IMGPROC_CROSS_BUILD_QUALIFIED | NOT ESTABLISHED |
| IMGPROC_CROSS_INSTALL_QUALIFIED | NOT ESTABLISHED |
| TARGET_RUNTIME_PENDING | No target execution performed |

No disposition follows from another. In particular, successful adapter fixture
tests do not establish any toolchain, ABI, Yocto or production qualification.

## Narrow adapter contract

`scripts/adacore_cross.py --check` is a read-only **preflight**, not a build
entry point. It reuses the existing target metadata, ELF, runtime and dependency
closure checks. The original Debian interface retains its compiler-version
equality regression control. The new opt-in preflight permits different Ada/C++
compiler versions, but explicitly reports actual ABI compatibility as unverified.
It still retains the existing conservative compiler/target libstdc++ symbol-set
check; this can reject a compiler runtime with unused newer symbols. Only an
actual linked-output requirement/definition analysis could justify relaxing it.

Required existing inputs:

```text
OPENCV_CROSS_TARGET       explicit AArch64 Linux compiler triple
OPENCV_CROSS_ADA          explicit external Ada compiler executable
OPENCV_CROSS_CXX          explicit independently selected C++ executable
OPENCV_CROSS_RUNTIME      selected compiler runtime with adainclude/adalib/libgnat.a
OPENCV_CROSS_GPR_CONFIG   reviewed target CGPR naming these compilers/runtime/linker
OPENCV_CROSS_GPRBUILD     explicit project builder
OPENCV_CROSS_GPRINSTALL   explicit project installer
ENV_PREFIX               matching target development sysroot, never host /
OPENCV_CROSS_PKG_CONFIG   explicit pkg-config executable
PKG_CONFIG_LIBDIR        target-only contained metadata directories
PKG_CONFIG_SYSROOT_DIR   must match ENV_PREFIX if supplied
```

`CC` and `CXX` are not automatically invoked. A Yocto SDK compiler is not
required. No BitBake invocation, image generation, SDK script sourcing, layer
or recipe is introduced. Search override environments remain forbidden.

New inputs:

* `OPENCV_CROSS_YOCTO_PROVENANCE`: existing JSON file with `release` equal to
  `scarthgap`, nonempty `build_identity`, `image_identity`, `export_method`, and
  `sysroot` equal to the resolved `ENV_PREFIX`. Record build revisions, machine,
  image manifest hashes and staging/SDK export method in these identities.
  This is a recorded caller assertion, **not authenticated Yocto provenance**.
* `OPENCV_CROSS_ADA_FLAGS`, `OPENCV_CROSS_CXX_FLAGS`: optional JSON arrays of
  explicit `-march=`, `-mcpu=`, `-mtune=` or `-mabi=lp64` switches. Shell text,
  search overrides and language-policy changes are rejected. These switches
  are recorded only: compiler/linker support and actual use are **not tested**.

The JSON output records executable hashes/version output, compiler search
directories, reported concrete linker paths/versions/hashes, runtime archive
hash, target metadata/ELF closure, CGPR hash, provenance and requested flags.
It always sets `production_qualified` to false. No evidence artifacts are
created by this preflight; output may be redirected into a private evidence
location. Never publish proprietary toolchain binaries or confidential paths.

If `OPENCV_CROSS_CORE_PREFIX` is absent, output explicitly reports
`CORE_PREREQUISITE_BLOCKED`. If supplied, the existing installed-project,
bridge, archive, target ALI and cross-identity checks must pass. Even then the
result is only `CORE_PREFLIGHT_ONLY`, not an authentic production-build claim.
Do not create an identity attestation to make the check pass. Core's GNAT 12
alignment issues remain compiler-dependent blockers.

### Reproduction

Set the listed variables to actual external inputs in a clean shell, then run:

```sh
cd /home/zboll/git/opencv/imgproc-ext-002c-adacore-cross
python3 scripts/adacore_cross.py --check
python3 -m unittest discover -s tests -p test_adacore_cross.py -v
python3 -m unittest discover -s tests -p test_cross_configuration.py -v
```

Synthetic tests isolate configuration decisions only. Existing negative controls
cover wrong compiler/runtime/ELF, missing headers/libraries/metadata, host paths,
GPR mismatches, absent installed Core/identity/ALIs, source Core, stale workspaces
and partial-to-production promotion. New controls cover explicit missing tools,
independent versions without ABI claims, requested flags, missing linker,
provenance binding and refusal to ignore invalid Core. Actual incompatible libc,
unsupported compiler flags and deployment closure are **not qualified** by mocks.

## Gates still requiring actual external inputs

Before production integration, independently compile/link a minimal Ada program
and separate OpenCV Core/Imgproc C++ probe using the intended drivers, sysroot
and CPU switches. Capture verbose commands, include search, linker input trace,
concrete runtime files and unresolved diagnostics. Inspect ELF64 little-endian
AArch64, ISA requirements, interpreter, DT_NEEDED, RPATH/RUNPATH and required
GLIBC/GLIBCXX/CXXABI/GCC symbol versions against actual target definitions.
Reject host ELF and unsafe library search substitutions. Version equality alone
is neither necessary nor sufficient. Verify Ada compiler/runtime compatibility
through a real compile/bind/link, not only an archive architecture check.

Compile the unchanged production shim with its actual GPR flags including
`-std=c++17 -Wall -Wextra -Wpedantic -Werror` and target headers. An exact Core
source bridge can establish compile-only evidence, not installed-Core integration.
The existing Debian probe has Debian-specific search directories and is **not**
presented as an AdaCore/Yocto link driver by this adapter.

Then require a genuinely installed target Core Ada/shim archive closure, ALIs,
GPR projects, bridge, matching runtime/OpenCV ABI and authentic build identity.
Only afterward perform complete Imgproc build/install and independent installed
and relocated Ada/mixed consumers. Preserve per-unit Ada language selection,
warnings-as-errors and every representation check; never globally force Ada 2022.

## Deployment contract

Deploy application binaries and every actual DT_NEEDED runtime dependency:
OpenCV Core/Imgproc plus their transitive libraries, target libc/loader,
libstdc++, libgcc_s and any dynamically selected GNAT runtime. Core/Imgproc Ada
and C++ shim shared libraries must also be deployed if built dynamically; static
archives are build/install inputs rather than runtime files. Install GPR/ALI,
headers and archives in the development staging prefix for consumers.

Use ordinary installation/copy/package artifacts outside BitBake. Configure
target loader paths through standard directories, target ld.so configuration
or reviewed relative application RUNPATHs; original host/build-only paths must
not be required. Validate the deployed library closure on the actual target
filesystem. Execution requires hardware or an independently qualified emulator;
cross-link success is not execution evidence.

No public semantic validation is duplicated in the C++ shim. Its source is
unchanged; no new SPARK/Ada source requires formatting or proof analysis.

## Regression evidence for this change

* Host configuration controls: 39 passed, two real-sysroot tests explicitly
  skipped; new adapter controls: nine passed.
* Existing real Debian 12 AArch64 target staging: all 41 controls passed,
  OpenCV 4.6 Core/Imgproc C++ probe cross-linked and unchanged production shim
  compiled with exact Core source bridge. These are Debian-only results, not
  AdaCore/Yocto evidence. Target outputs were checked by the existing ELF and
  dependency controls; no target execution was attempted.
* GNAT 12 source-unit controls: four native and four AArch64 tests passed using
  actual compiler frontends in the existing qualified container image and exact
  Core revision above. Expected forced-Ada-2022 rejection is a negative control,
  not a successful full Core/Imgproc production build.
* GNAT 16.1 native build, full AUnit suite: **1129/1129 successful**, zero failed
  assertions or unexpected errors. Independent native installation and both
  installed/relocated Ada and mixed C++ consumers passed (driver status zero).
* Documentation helper controls: warning comparison 36 passed, comment-only six
  passed, coverage 20 passed/two generated-site checks skipped. Full fresh site
  generation/coverage is delegated to the preserved hosted documentation job;
  local helper tests do not substitute for it.
* Diff whitespace checks passed. No Ada formatting/proof campaign was needed.

The first host GCC 12 attempt failed because its Ada frontend was missing. The
first container regression attempt hit a full `/tmp` tmpfs; no unrelated files
were removed. Reruns used disk-backed evidence and succeeded. Private evidence
is in `/home/zboll/git/opencv/imgproc-ext-002c-evidence`, with GNAT 12 output in
`/home/zboll/git/opencv/imgproc-ext-002c-gnat12.log`. These native/debian evidence
directories are not target deployment inputs or public toolchain artifacts.

The existing Linux/macOS/Windows, Debian consumers, source-unit, target-dependency
and documentation workflows remain unchanged. The added hosted adapter job runs
synthetic tests only and does not download or expose proprietary AdaCore tools.
Final PR HEAD parity and hosted conclusions are reported in the review handoff;
pending jobs must not be reported as passing.