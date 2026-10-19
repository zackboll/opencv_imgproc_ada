# IMGPROC-API-003-R1 — Portable native LSD baseline

Existing PR #76; no replacement PR. Reviewed starting HEAD:
`85dd67dcd29dc321cb10c7d298d1c09e7492320a`.
Starting origin/main remains `47418ab0a3d31e783a97ba585d9a8112ac5fec7d`.

## Implemented contract

* Detection: **Scale=1.0 only**, **No_Refinement/Standard_Refinement**.
* Portable default: Standard, scale **1.0**, not OpenCV native 0.8.
* All non-unit scales and Advanced explicitly rejected in Ada and independently
  at the C ABI before detector construction. NFA unavailable (`False`, zero).
* Existing public types, fields, ownership architecture and package retained.
* Native subpixel gradient-oriented endpoints, width/precision, independent
  Ada results and source-preserving logical/strided Regions.
* Native red-BGR rendering and pixel-mismatch comparison/visualization remain
  available, including portable empty sets and fresh Core-owned output storage.
* OpenCV <4.5.4 explicitly unavailable without invoking removed constructor.
* Constructor always receives the validated unscoped refinement enum, compatible
  with actual 4.x int and 5.x enum declarations despite historical Bayer macros.

## Unsafe paths excluded, not repaired or hidden

Scale=1 excludes flsd's Gaussian/resize branch and its SIMD misaligned-short
load (independently reported in OpenCV #29238). Modes 0/1 cannot enter flsd's
`doRefine >= LSD_REFINE_ADV` block, so rect_improve/rect_nfa cannot execute.
The disproved rectangle bound was removed. No private OpenCV patches, global
optimization changes, sanitizer suppression, or replacement algorithm.

## Local qualification

* Full AUnit: **1,178/1,178** on each of 4.1.0, 4.6.0, 4.10.0, 5.0.0.
  Reviewed baseline 1,175; three new focused regression cases; 20 LSD cases.
* Native references / expected ABI rejections: 4.1 **3/4**, each functional
  version **4,566/560**. Counts are native assertions, not AUnit cases.
* ASan/UBSan/float-cast-overflow with instrumented exact-tag OpenCV itself:
  **PASS on all four versions** for the reduced contract. Broad small-image,
  contrast, near-axis, texture and strided-ROI corpus; failure-on-diagnostic.
* Installed and historical Bayer paths pass 4.6/4.10/5.0. Installed 4.1 passes;
  legacy simulation on actual 4.1 is unavailable because unrelated CCL aliases
  are absent. The historical simulation is unchanged.
* GNAT 12 native/AArch64 source-unit controls: four tests each passed.
  C11 header and native/AArch64 C++ layout controls passed.
* Cross configuration: 41 tests (two genuine-SDK controls explicitly skipped);
  external AdaCore adapter: nine tests passed.
* Existing 329-declaration/193-subprogram/1,596-item documentation inventory
  retained. Frozen GNATdoc historical authority unchanged.

## Hosted qualification and review

**HOSTED_CI_PENDING** until exact corrective HEAD passes Linux, macOS ARM64
(including historical Bayer), macOS Intel IPP, GNAT 12, API documentation,
Debian installed consumers, cross configuration, AArch64 target dependencies,
shared GNATdoc applicability and external AdaCore adapter controls.
Windows remains skipped/manual, not qualified.

Retained duplicated C++ guards protect scale/mode path exclusion, finite native
casts, positive p/rho/min-region conversions, image/buffer geometry, bin casts,
endpoint differences/rounding and comparison area/byte indexing. Each has a
specific ABI-safety reason; there is no second public depth/channel contract.

See [source review, historical evidence and R1 results](line-segment-detector-source-review.md).
Do not merge, enable auto-merge, tag, release, submit to Alire or start another feature.