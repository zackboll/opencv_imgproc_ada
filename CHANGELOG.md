# Changelog

## 0.2.1 — corrective release, proposed

Release preparation is tracked in
[IMGPROC-REL-004 qualification](docs/imgproc-rel-004-qualification.md).
Patch release of 0.2.0 with the same public API and `opencv_core = "~0.4.1"`.

### Fixed

* `Extract_Subpixel_Patch` returned wrong pixels on OpenCV builds with Intel
  IPP (for example Homebrew's x86_64 bottles) when the patch window crossed
  both the top and the right border of Source. IPP's
  `ippiCopySubpixIntersect`, used by `cv::getRectSubPix` for UInt8 and
  Float32 single-channel sources, fills samples above the image at or beyond
  the last column from column `Columns - 2` instead of `Columns - 1`
  ([opencv/opencv#30301](https://github.com/opencv/opencv/issues/30301)).
  This affected UInt8, `Promote_To_Float32` and Float32 C1 results. Exactly
  those requests are now sampled with OpenCV's portable implementation by
  deselecting IPP on the calling thread for that one call, restoring the
  caller's selection afterwards. Results on builds without IPP are unchanged,
  and IPP stays enabled for all other requests and operations.

### Tests and qualification

* Ten AUnit regressions cover top+right windows for UInt8, Float32 and
  promoted output, a one-column Source, and the caller's IPP selection
  forced on and off (1140 tests).
* The native ELF-wrap test runs every case with IPP selected and deselected
  and asserts the IPP selection seen by the native call; the guard test checks
  the geometry classification and selection restoration.
* New hosted job: macOS x86_64 with Homebrew's IPP-enabled OpenCV.

## 0.2.0 — tagged 2026-10-14, not published to the Alire index; superseded by 0.2.1

Release preparation is tracked in
[IMGPROC-REL-001 qualification](docs/imgproc-rel-001-qualification.md).
The native release candidate uses indexed `opencv_core` 0.4.1; GNAT 12
production and AdaCore/Yocto target support are not included in this claim.
IMGPROC-REL-002 resolves the two OpenCV 4.1 test-contract failures: UInt16
Otsu now enforces the documented native rejection, and textured edge-aware
Bayer checks use exact independent native selectors and physical CFA samples
instead of assuming equal rounding after channel reversal. No production
pixel algorithm, channel mapping or ownership behavior changed. The complete
four-version suite now has 1130 tests; release readiness still requires
exact-candidate hosted qualification and review.

### Added since indexed 0.1.0

The comparison baseline is published source
`88a6a94f309135fb536d1814d106d244a032dc62`, not the development version string.
Merged feature PRs #26–#51 add:

* Portable masked template matching for five methods: squared difference,
  normalized squared difference, cross correlation, normalized cross
  correlation, and correlation coefficient. Masked normalized correlation
  coefficient remains unsupported. Binary-mask, zero-energy, numerical and
  destination-lifetime rules are documented explicitly.
* Squared-box filtering, linear blending, safe spatial gradients and subpixel
  patches; Gabor/structuring-element kernel generators and Hit-or-Miss
  morphology; bit-exact linear resize.
* Packed BGR565/BGR555 and extended color conversions, Bayer demosaicing,
  YUV420 frame/two-plane conversion and YUV422 decoding/luma extraction,
  built-in and custom color maps.
* Ballard and Guil generalized Hough matching; corner response maps and
  subpixel corner refinement; phase correlation and Hanning windows.
* Image accumulation, squared/product accumulation and running averages;
  EMD lower-bound early exit and portable Int32 flood fill.

Contours, connected components, ordinary Hough/template matching, histograms,
EMD, geometric transformations, filtering and morphology already existed in
0.1.0. They remain in the release and now have expanded API documentation and
developer guides; they are not all newly introduced by 0.2.0.

### Documentation and integration

Merged PRs #52–#62 provide public API documentation, complete declaration/member
coverage, navigation, type links and five compiled developer guides. PRs
#63–#68 add Windows provisioning corrections, installed/relocated Ada and
mixed C++ consumers, explicit cross-configuration and target-dependency
controls, partial GNAT 12 source-unit checks and post-Yocto adapter preflight.
Infrastructure controls are not target-execution qualification.

### Compatibility and release packaging

* No existing public subprogram is removed or has its callable profile changed
  in the source comparison. New overloads/types are additive. Color conversion
  and interpolation enumerations gain literals; exhaustive client `case`
  statements may require updating. This pre-1.0 minor release is not a binary
  replacement: rebuild clients and cooperating shims together.
* Core remains the sole owner of Mat lifetime and shallow-copy semantics.
  Destination behavior is operation-specific: new masked matching publishes
  fresh owning storage only on success, whereas existing operations may reuse
  destination storage. Documentation makes those differences explicit; no
  universal failure-atomicity or deep-copy guarantee is introduced.
* The library manifest removes the adjacent Core development pin and selects
  `opencv_core = "~0.4.1"`. Native `opencv`, `pkg_config`, Windows
  `mingw_w64_gcc`, the MSYS2 library path and the approved Arch Rolling
  unavailability restriction are retained explicitly.
* OpenCV 4.1/4.6/4.10/5.0 compatibility remains operation-specific. This release
  does not add unimplemented masked TM_CCOEFF_NORMED, remap exact modes, or
  general Yocto/GNAT 12 production support.