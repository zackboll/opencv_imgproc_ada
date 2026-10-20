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
including inside Alire's execution environment. It supplies **no** external
sysroot switch. It retains source/tree, image, Xcode, CLT, compiler, bundled
linker and generated configuration identities, verbose GPRbuild/GCC commands,
linker input traces, Mach-O dependencies and dyld runtime logs. Corrected
executable, relocatable Ada library and consumer links must contain the
generated Xcode sysroot and select Xcode's `libSystem.tbd`, not any CLT SDK.

The immutable old main is built on the same runner first. Its result is
`REPRODUCED_GNAT_FSF_112` only for the observed CLT libSystem / arm64e.x1 /
unknown-architecture failure; successful old builds are `NOT_REPRODUCED`.
Unrelated baseline failures block qualification rather than being mislabeled.

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