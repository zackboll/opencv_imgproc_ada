# IMGPROC-CI-MACOS-001: standalone macOS GNAT SDK linking

## Refreshed starting identities

- Main: `5f56b40f9cfe76ae0c4f829f9d1eae0861002768`.
- Git tree: `537dffffdd08804a9cb1def88220f832274d5561`.
- No open source PRs when the corrective branch was created.
- Manifest and accepted index: Imgproc `0.2.1`; production Core constraint
  `~0.4.1`, unchanged.
- Published annotated tag `0.2.1`: `be78eb9e937778c224d82aa2dd1d66fba832f318`,
  peeled source `9ce22ae5ab70008e1147475a9e6d7baef82f1df0`, matching the index.
- Accepted indexed Core `0.4.1`: `386c5360ac51f2b62e522853d94290aec4ee14a0`,
  tree `e5a10928b232b85d841ec9a7b174cd7825206fa1`.
- Starting main's [cross-platform run](https://github.com/zackboll/opencv_imgproc_ada/actions/runs/39336877268)
  succeeded on Linux, macOS ARM64, macOS Intel IPP, and Windows/MSYS2.
  ARM64 job `118348474311` records 1178 total, 1178 successful, zero failed
  assertions and zero unexpected errors. Local GNAT 16.1.0 / GPRbuild 26.0.1 /
  Debian 13 / OpenCV 4.10 independently confirms the same inventory.

## Correction and comparison

Historical index failure: <https://github.com/alire-project/alire-index/pull/2230>.
Upstream linker defect: <https://github.com/alire-project/GNAT-FSF-builds/issues/112>.
The affected GNAT bundled linker rejects CLT 27 `libSystem.tbd`'s
`arm64e.x1-macos` target. Earlier success on image `20260907.0351.1` does not
qualify the affected `20261013.0424.1` image.

Core 0.5.1 (`64d8a60b59acfe4334045280e430c4774b5cad89`) conditionally passes
`--sysroot=<generated Cxx_Sysroot>` to both executable `Linker_Options` and
relocatable Ada `Library_Options` for Apple_Clang.
[Geometry PR 54](https://github.com/zackboll/opencv_geometry_ada/pull/54)
uses the same approach, but its macOS shim is External_Relocatable. Imgproc's
macOS shim is **Relocatable**, built by Apple clang++ with its existing
`-isysroot`. Only the two missing **Ada** link paths are changed here.

Windows import options, Linux Static_PIC/GNU branches, C++ driver, libc++, Core
module bridge, provider discovery, native shim options and rpath behavior are
unchanged. No public semantic validation is duplicated in the C++ shim; the
shim is unchanged. No production source, public API, private ABI, AUnit
registration, manifest constraint, availability policy, version, release tag
or index entry is changed.

## Standalone evidence contract

`.github/workflows/macos-standalone-sdk.yml` runs native ARM64 Homebrew and
MacPorts jobs independently, using GNAT 16.1.0 and GPRbuild 26.0.1. Core is
version-selected from the accepted index at 0.4.1, and its immutable origin is
checked in both library and test lockfiles. No Core 0.5.1 substitution or
committed test dependency change is permitted.

`tests/macos/qualify_standalone_sdk.sh` requires SDKROOT and LIBRARY_PATH unset,
including at the actual Ada tool boundary after Alire environment injection.
The initial Homebrew job on commit `9791d55` exposed a deployed compiler
manifest reintroducing LIBRARY_PATH through `alr exec`; the guard stopped before
either old or new link. The harness therefore runs normal recursive Alire
pre-build actions, then GPRbuild/GPRinstall via `alr exec -- env -u SDKROOT -u
LIBRARY_PATH`. This removes variables, never adds an SDK workaround. It
supplies **no** external
sysroot switch. It retains source/tree, image, Xcode, CLT, compiler, bundled
linker and generated configuration identities, verbose GPRbuild/GCC commands,
linker input traces, Mach-O dependencies and dyld runtime logs. Corrected
executable, relocatable Ada library and consumer links must contain the
generated Xcode sysroot and select Xcode's `libSystem.tbd`, not any CLT SDK.

The immutable old main is built on the same runner first. Its result is
`REPRODUCED_GNAT_FSF_112` only for the observed CLT libSystem / arm64e.x1 /
unknown-architecture failure; successful old builds are `NOT_REPRODUCED`.
Unrelated baseline failures block qualification rather than being mislabeled.
Fresh-runner qualification also requires building the normal library closure
before the test-native-oracle action: that oracle links Core's dylib. The
initial direct-action harness exposed this ordering requirement before any
Ada executable link; it was not an upstream linker reproduction.

The complete AUnit inventory must remain 1178/1178. The script also builds the
normal library, explicitly links a relocatable Ada library, installs the normal
library recursively with GPRinstall, and builds/runs independent installed and
prefix-relocated consumers. Source library directories are hidden; consumers
run outside the checkout with only installed GPR_PROJECT_PATH. Installed GPRs
are never rewritten. Installation defects must be reported before any further
corrective change.

## Results and limitations

Initial local checks: normal release build, explicit Linux relocatable Ada
library build, 1178/1178 AUnit, Bash syntax and Git whitespace checks pass.
Native macOS, Windows, Debian 12 isolated consumers and the remaining hosted
controls require exact-head CI; Linux local results do not prove macOS linking.

Final tested/pushed/PR SHA, tree, hosted run links and disposition are recorded
in the corrective PR after CI. Stop at independent review: no merge, release,
retagging, force-push or index PR is authorized.

## R1: portable native-thread test (reviewed head cfcc517)

The original test assumed `setNumThreads(2)` implies `getNumThreads() == 2`,
and attempted to restore a preference from a reported count. Neither is a
portable public contract. Exact-tag `parallel.cpp` and `utility.hpp` were
inspected for OpenCV 4.1.0, 4.6.0, 4.9.0, 4.10.0 and 5.0.0:

- `utility.hpp` documents backend-dependent counts and GCD support only for
  nonpositive requests. Its historical GCD “512” text is not the implementation:
  all five inspected `parallel.cpp` versions return CPU count for GCD, and mark
  positive-limit setting unsupported. Later versions can delegate to a runtime
  parallel API. A compiled framework is not proof of active backend selection.
- OpenCV 4.1.0 `connectedcomponents.cpp:3933-3939` dispatches parallel labeling
  when a framework exists, reported threads exceed one, and rows/threads >= 2.
  Imgproc's existing safety preflight conservatively uses the latter two
  conditions plus odd height, failing closed without the private backend query.
  The test oracle follows this actual binding guard, not a requested count.

Sources are the exact tags under
`https://github.com/opencv/opencv/blob/<version>/modules/core/src/parallel.cpp`,
`modules/core/include/opencv2/core/utility.hpp`, and the 4.1.0
`modules/imgproc/src/connectedcomponents.cpp` dispatch cited above.

The existing AUnit registration remains in the 1178-case suite. It spawns a
single-case child of the same executable and asserts successful completion.
Only that child tunes threads; its exit discards all changed native state.
The parent never attempts to reconstruct a hidden preference. A test-only suite
selector and optional Suite parameter support isolation, not skipped coverage.

Diagnostics report runtime version, request, reported count and the compiled
parallel-framework line from `getBuildInformation()`. Active backend is
explicitly **not queried**, rather than inferred from the provider. Negative
helper/error results fail the test. Geometry is bounded before multiplication:
for a count above one, odd rows = 2 * count + 1 (count <= 4096); otherwise the
ordinary odd case takes the safe branch and reports rejection unexercised.
Both connectivities check the real 4.1 gate; newer versions must label the odd
case successfully. After requesting one, the same geometry is reevaluated using
the newly reported count, never assumed serial. Even-height execution always
checks recovery. Rejection checks all source/destination/Region/alias values;
success checks count, statistics, all labels, parent exterior and retained
storage through mutation. Rejected storage is reused by an even view to check
immediate recovery. The registration count is not increased by child execution.

The reviewed MacPorts artifact established runtime 4.9.0 and a failed exact-two
assumption, but did not measure a backend or effective count. R1 qualification
must supply those diagnostics and pass full AUnit, relocatable-library linking,
GPRinstall, installed and relocated consumers before MacPorts is qualified.
Results and exact corrective SHA/tree are recorded in PR #77 after verification.
The root GPR SDK correction and all production sources/manifests are unchanged
by R1. No claim of AdaCore or production AArch64 cross-runtime support follows.

R1 initial local strict-development results: 1178/1178 on each of 4.1.0,
4.6.0, 4.10.0 and 5.0.0, zero failed assertions or unexpected errors. The 4.1.0
pthread build reports requested=2/observed=2, rows=5, unsafe_4.1=TRUE; both
connectivity rejection assertions and immediate even-view recovery pass.
4.6.0 and 5.0.0 report compiled pthreads; system 4.10.0 reports compiled TBB.
All explicitly leave active backend unqueried. GNATformat, 79-column checks
and warning-free GNAT 16.1 development compilation pass.
`tests/qualify_native_thread_versions.sh` repeats the source-prefix matrix in
isolated project copies through the tests Alire environment; native loader
evidence ensures the intended version is used. MacPorts/hosted results require
the final pushed head and are not inferred from these local results.

### Measured R1 native-provider results

Corrective test commit `0972587f9345e0aafe1b776c05d286413bbaac96`, tree
`352f87ea7f87303f2602b15e34852be38bb1af0e`, passed the local four-version
matrix again after commit. Hosted standalone run
<https://github.com/zackboll/opencv_imgproc_ada/actions/runs/39358337639>
produced these downloaded and independently inspected artifacts:

- Homebrew `12235854662`: runtime 5.0.0, compiled TBB 2023.1; requests 2/1
  report 2/1. Full 1178/1178 and all library/install/consumer stages pass.
- MacPorts `12236293972`: runtime **4.9.0**, compiled framework **GCD**;
  query(-1), request(2), request(1), request(2) all report **3**. Active backend
  is explicitly unqueried, not inferred from compiled support. Odd rows=7
  successfully label under both requests; even rows=16 also succeed. The 4.1
  rejection path is correctly reported unexercised on this 4.9 runtime, not
  falsely claimed covered. Positive 4.1 rejection evidence is the separate
  qualifying 4.1 pthread configuration described above.

MacPorts full AUnit is **1178/1178**, zero failed assertions/errors; its
explicit relocatable Ada library, recursive GPRinstall, independent installed
consumer and prefix-relocated consumer all pass. The old immutable main
reproduces GNAT-FSF #112 for **both** providers. Image macos26 /
20261013.0424.1 selects Xcode 26.6 / SDK 26.5, while CLT is 27. Both variables
are removed at each Ada tool boundary. Actual GNAT commands and full traces
select Xcode's `libSystem.tbd`, not CLT, for corrected executable, relocatable
Ada library and both consumers. No external sysroot switch or installed-GPR
rewrite is used; dyld proves installed/relocated prefix shim loading while
source libraries are hidden. This is now actual MacPorts installation evidence,
not an inference from successful executable linking.

Exact-head hosted Linux/Windows, Debian 12 consumers, documentation and compiler/
configuration controls pass at the test commit. Remaining platform results and
the final documentation-only head's complete CI audit are recorded in PR #77;
older-head results are not represented as final-head hosted qualification.