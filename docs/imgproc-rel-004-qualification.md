# IMGPROC-REL-004 — 0.2.1 corrective release qualification

## Scope and preservation

0.2.1 corrects `Extract_Subpixel_Patch` on OpenCV builds with Intel IPP. It
starts from `main` at **08724e9ce0753546709345d5b657eff714748e04**, the 0.2.0
release commit, on branch `corrective/imgproc-0.2.1-ipp-subpixel`, in a new
worktree. The annotated tag `0.2.0` (object
`b76aaba645ecff8b406e7cf3a07a667f062e7055`) and the 0.2.0 Alire index
submission (alire-project/alire-index#2230, head `d78292e5`) are unchanged.

Public API, Core requirement (`opencv_core = "~0.4.1"`, indexed origin
`386c5360ac51f2b62e522853d94290aec4ee14a0`), native dependencies, Windows
MSYS2 settings, the Arch Rolling exclusion and the root build/test actions are
unchanged. The only manifest change is the version. No other operation's
production code changes.

## Defect and exact native cause

macOS 15 x86_64 index CI (Homebrew OpenCV 5.0.0_5, IPP 2021.9.1) failed
`Subpixel top-right` at `subpixel_patch_tests.adb:140` (1129/1130). For a 3x3
patch at (3, 0) on the 4x4 ramp `40r + 8c`, patch pixel (0,1) samples (3, -1).
Nearest-edge extension gives source (3,0) = 24; the binding returned 16 =
source (2,0). The patch was `[16,16,16 | 16,24,24 | 56,64,64]`; the required
patch is `[16,24,24 | 16,24,24 | 56,64,64]`.

On IPP builds, `cv::getRectSubPix` calls `ippiCopySubpixIntersect` for
`8UC1->8U`, `8UC1->32F` and `32FC1->32F`. In windows crossing both the top and
the right border, every sample with `y < 0` and `x >= cols - 1` receives
`source(0, cols - 2)` instead of `source(0, cols - 1)`. All other samples
follow the clamped bilinear formula.

That rule matched IPP output on **139,098/139,098** pixels: 7,887 random-data
windows, five image shapes, three type paths, and IPP 2026.0.0 and 2021.11.0
(official OpenCV 5.0.0 and 4.10.0 Linux wheels).

The defect does not depend on guard contents, ROI vs continuous layout, 60
stride/alignment variants or CPU dispatch. Wrong values reach 69 grey levels
on random data. For one-column sources IPP reads before the image. Imgproc's
guard copy always provides a replicated row above, so in the binding that read
stayed inside its own allocation.

The binding was byte-identical to native in both IPP states, so the guard
was not at fault. The IPP output contradicts IPP's documented clamped
coordinates. Reported upstream as opencv/opencv#30301. Builds without IPP
were never affected.

## Correction

`cpp/subpixel_patch_guard.hpp` adds:

- `requires_portable_sampler(guard)`, which is `guard.top > 0 && guard.right > 0`;
  such windows always take the guard path;
- `Scoped_Portable_Sampler`, which deselects IPP on the calling thread and
  restores the previous selection on scope exit, including when an exception
  propagates.

`cpp/opencv_imgproc_shim.cpp` wraps the single `cv::getRectSubPix` call in
that scope. The `cv::ipp` selection is thread-local (`CoreTLSData`) in OpenCV
4.1.0, 4.10.0 and 5.0.0, and `samplers.cpp` has no parallel loop. IPP is
therefore never disabled globally, and stays selected for every other request
and every other operation.

Alternative evaluated and rejected: making the request interior to the guard
copy. It is correct under IPP but not bit-identical to 0.2.0's portable
results on non-IPP builds (u8 ±1 in 87 of 11,900 border cases; Float32
differences), and binary32 centre translation is inexact.

## Regression coverage (1130 -> 1140)

The full list of new AUnit tests:

- top+right UInt8 windows: wide, pair, fraction, half, column, all borders
  (exact linear-ramp oracle);
- top+right Float32 and promoted UInt8 (two tests);
- one-column corner;
- `Subpixel IPP selection`, which forces the calling thread's native IPP
  selection on and off through two test-only native helpers and asserts it is
  preserved.

The Linux ELF-wrap runtime test runs every case under both IPP selections. It
asserts the selection observed inside `getRectSubPix` (deselected exactly for
top+right guard calls) and its restoration, and adds top+right and one-column
geometries. The guard test checks the classification and restoration,
including on throw.

## Proof: failure caught, correction exact (Linux x86_64, OpenCV 5.0.0 + IPPICV 2026.0.0)

| Run | Result |
| --- | --- |
| Full AUnit, 0.2.0 shim + new tests | **1130/1140**: the original top-right, 8 new top+right geometries and `IPP selection` fail; one-column passes (guard memory) |
| Full AUnit, corrected tree | **1140/1140** |
| 0.2.0 native runtime test | fails `bilinear oracle` |
| New native test, 0.2.0 call site | fails `IPP selection during the native call` |
| New native test, corrected (ASan/UBSan) | pass: 904 calls, 432 portable, IPP selected in pass 1 |
| Byte-exact binding output, 108 canonical cases | exactly the 36 top+right cases changed. All now equal native IPP-off output, e.g. top-right `16,24,24`, Float32 `0x41C00000`. The other 72 equal native IPP-on output byte for byte |

## Four-version matrix and IPP build (exact commit 57e66a3)

`scripts/qualify_indexed_release.sh` ran in fresh detached worktrees at
`57e66a3db6ad6db44f40d55b2b497021bcbf7ad6` (tree `738f0d48`). Each used
isolated Alire settings, community `stable-1.4.0` at `e88e083e`, GNAT 16.1.0
and gprbuild 26.0.1. Indexed Core 0.4.1 came from git and no dependency was
pinned. Later commits change only `.github/workflows` and this record.

| OpenCV | Environment | AUnit | Native boundary/sanitizer regressions |
| --- | --- | --- | --- |
| 4.1.0 | Debian 13, source build, no IPP | **1140/1140** | all PASS |
| 4.6.0 | Debian 12 container `9216a90e`, no IPP | **1140/1140** | all PASS |
| 4.10.0 | Debian 13 distro, no IPP | **1140/1140** | all PASS |
| 5.0.0 | Debian 13, source build, no IPP | **1140/1140** | all PASS |
| 5.0.0 + IPPICV 2026.0.0 | Debian 13, source build, IPP selected | **1140/1140** | all PASS except masked CCORR consistency (below) |

**Masked CCORR on IPP (not changed by 0.2.1).** Under IPP, native unmasked
`TM_CCORR` leaves residuals up to 4.9e-4 at mathematically zero windows. The
consistency harness's documented qualification policy is
`max(1e-4, 4 ULP)`, and the README states that native DFT rounding is retained
and that the bound "is not a universal backend error guarantee".

With `OPENCV_IPP=disabled` the same harness passes on the same build, and the
0.2.0 tree fails it identically. This is native backend rounding in an
operation outside this release's scope; it is recorded, not changed. The
script steps after it were run separately on this build: masked NSQDIFF and
CCOEFF consistency (sanitized), Bayer gray and the loader check all pass.

## Alire candidate rehearsal and pin-free consumers

A fresh clone at `57e66a3` with `ALIRE_SETTINGS_DIR` isolation ran:

```
alr -n publish --skip-submit . 57e66a3db6ad6db44f40d55b2b497021bcbf7ad6
```

It exited 0. Core 0.4.1 deployed from its origin; both C++ shims and 214 Ada
units compiled. The generated manifest differs from 0.2.0's only in version
and origin. The candidate manifest is not for submission.

Two fresh consumers used a private index holding only that candidate:

- Debian 13 / OpenCV 4.10 host;
- Debian 12 / OpenCV 4.6 container, with no neighbouring sources.

Each resolved `opencv_imgproc 0.2.1` and Core 0.4.1 from git with every
dependency `pinned = false`. Each built and ran PASS, including an exact
top-right `Extract_Subpixel_Patch` assertion, and `ldd -r` was clean.

## Hosted CI

Every run below is at PR head `db9b5720067fe1698c0edf9b78367b31ef61a4d0`, or at
PR #71's synthetic merge `0995ecc0`, whose tree `ac5d42a5` is identical to the
head tree. Core `386c5360`. URL prefix:
`https://github.com/zackboll/opencv_imgproc_ada/actions/runs/`.

| Workflow / job | Run, job | Result |
| --- | --- | --- |
| Cross-Platform (dispatch, attempt 2) Windows x86_64 MSYS2 | 38671463951, 116217768406 | **1140/1140** |
| Cross-Platform (dispatch) Linux x86_64 | 38671463951, 116217769862 | **1140/1140** |
| Cross-Platform (dispatch) macOS ARM64, image 20260907.0351.1 | 38671463951, 116217800096 | **1140/1140** |
| Cross-Platform (dispatch) macOS x86_64, Homebrew OpenCV 5.0.0, IPP 2021.9.1 `y8` selected | 38671463951, 116217770432 | **1140/1140**; guard/IPP checks pass |
| Cross-Platform (PR) Linux / macOS ARM64 / macOS x86_64 IPP | 38671469696 | all **1140/1140** |
| Ada API Documentation | 38671469646, 116215336068 | 0 GNATdoc warnings (delta 0/0), 1512/1512 coverage, 5 guides, 314 navigation entries |
| Debian 12 installed consumers | 38671469618, 116215335553 | installed and relocated Ada and mixed consumers PASS |
| Cross configuration, AdaCore adapter, GNAT 12 source units, AArch64 target dependencies (controls, not qualification) | 38671469619, 38671469620, 38671469731, 38671469598 | success |

Earlier attempts that failed are kept for the record:

- **Dispatch 38670274881 at `57e66a3`:** macOS ARM64 landed on runner image
  20261013.0424.1 (Command Line Tools 27). Every GNAT executable link failed
  with `libSystem.tbd ... unknown architecture arm64e.x1`. Fixed in CI by
  exporting `SDKROOT` from the selected Xcode, the same change proposed as
  alire-project/alire-index-checks#22. That pin passed 6/6 on that image in
  the alire-index harness. The passing ARM64 runs above landed on the older
  image, so this repository's CI has not yet exercised the pin on the CLT 27
  image.
- **Same dispatch:** the new macOS x86_64 guard step compiled OpenCV headers
  through `-I`, and Apple clang reported OpenCV 5's `_Atomic` extension under
  `-Werror`. Fixed by using `-isystem`, as the Linux step does.
- **Dispatch 38671463951, attempt 1:** Windows failed before any build because
  an MSYS2 mirror timed out (`ftp2.osuosl.org ... Operation too slow`). The
  attempt-2 rerun passed.

## Remaining gates

- Independent review and your merge of the source PR.
- Verify the final merged tree, then tag authorization for annotated `0.2.1`.
  Tag `0.2.0` is never moved.
- Exact-tag `alr publish --skip-submit` and fresh pin-free consumers against
  the tag.
- Index transition coordinated on alire-project/alire-index#2230.
- alire-project/alire-index-checks#22 (macOS CLT 27 SDK) is still open
  upstream.
