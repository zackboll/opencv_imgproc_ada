# IMGPROC-API-003 — BLOCKED: native LSD safety qualification

This PR is an implementation and reproducible blocker report, **not ready for
approval or merge**. Auto-merge must remain disabled. Independent review has
not been requested as a readiness disposition.

Starting origin/main: `47418ab0a3d31e783a97ba585d9a8112ac5fec7d` (merged PR #75).
No duplicate branch/PR was found; the working tree was clean before work.

## Implemented

* Public `LSD_Refinement`, `LSD_Parameters`, `LSD_Segment`, `LSD_Segment_Array`.
* `Detect_Line_Segments`, `Render_Line_Segments`, and count-only / visualized
  `Compare_Line_Segments`, in the existing public package.
* Invocation-local native detector; subpixel gradient-oriented Vec4f endpoints;
  width/precision and optional Advanced NFA; Ada-owned copied results.
* Native red-BGR rendering and native raster mismatch count/visualization,
  fresh output ownership, empty-set behavior and isolated noncontiguous ROI input.
* Pre-4.5.4 compile-time unsupported errors without stub constructor calls;
  explicit OpenCV 5 enum conversion.
* 17 focused AUnit cases, native-reference/malformed-ABI harness, C/Ada layout
  controls, GNATdoc and source-audit documentation.

## Validation

* Full AUnit on 4.1.0, 4.6.0, 4.10.0, 5.0.0: **1,175/1,175 each**.
  Baseline: 1,158. These counts are registered AUnit cases.
* Four-version independent native reference harness: pass. Reference assertion /
  ABI rejection counts: 4.1 3/4; 4.6 319/129; 4.10 348/132; 5.0 348/132.
* Instrumented OpenCV: 4.1 unsupported paths pass. Functional versions fail at
  native exact-resize SIMD misaligned short loads for scale .8.
* Scale-one sanitizer campaign: 4.6 passes (157 references/65 rejections);
  **4.10 and 5.0 fail in advanced rect_nfa with float-to-int overflow**.
* GNAT 12 native and AArch64 compile-only: four tests pass each, including actual
  Ada record representation. C11 shim-header and native/AArch64 C++ layout pass.
* GNATdoc: zero warnings, 329 declarations, 193 subprograms, 1,596/1,596 covered
  documentation items. Frozen shared-shadow authority unchanged.
* Cross configuration: 41 tests, two genuine-SDK tests skipped; adapter: 9 pass.
* Hosted platform and installed-consumer results: **HOSTED_CI_PENDING** at PR
  creation. Windows MSYS2 unqualified/manual, never reported as passed.

## Blocking decision

The small-image Advanced failure disproves the provisional geometric scan bound.
Output checks cannot repair UB that already happened in native code. Completing
the requested safety contract needs dependency-level native fixes, or an
explicitly approved reduced support contract. Neither native algorithm replacement,
sanitizer disabling nor global optimization disabling was introduced.

Retained duplicated safety checks cover finite native casts, Gaussian sizing,
scaled layout/buffer arithmetic, bin conversion, provisional rectangle scan
bounds, endpoint rounding/differences, and comparison area/byte indexing; their
specific reasons and limitations are in the source-review document. Public
depth/channel/refinement semantics are owned by Ada, not reimplemented as a
second C++ public contract.

See [full source review and blockers](line-segment-detector-source-review.md).
Do not merge, tag, release, submit to Alire, or start another feature.