# IMGPROC-REL-005 — Imgproc 0.3.0 release qualification

## Scope and immutable starting identities (2026-10-20)

Fresh remote main is `678fa329e0e3475cd5acfabb05105a101dbb6a38`, merged PR
[#78](https://github.com/zackboll/opencv_imgproc_ada/pull/78). Its tree is
`ee643ed08b2764d4fa854feccf10c795e2084bbf`, identical to independently reviewed
and user-tested R2 `3914528dcd2721f86228fa7eea2f27b558ead921`. No additional main
commits needed reconciliation. Preparation uses isolated worktree
`/home/zboll/git/opencv/imgproc-rel-005`, branch `release/imgproc-0.3.0`;
unrelated worktrees are preserved.

Published 0.2.1 origin is `9ce22ae5ab70008e1147475a9e6d7baef82f1df0`, annotated
tag object `be78eb9e937778c224d82aa2dd1d66fba832f318`, index PR
[2232](https://github.com/alire-project/alire-index/pull/2232), merged. None is
changed. This task creates no tag, GitHub Release or index PR and does not merge
or enable auto-merge on the source release-preparation PR.

The production version is **0.3.0**, Core constraint **`~0.5.0`**. All production
Ada/C++ sources, production GPRs/configuration, cross installer/backend/validators,
vendor qualification driver and installed-consumer/probe fixtures are preserved.
No public semantic validation is duplicated in the C++ shim by this task.

## Dependency proofs and release controls

The official indexed Core 0.5.0 manifest at
`stable-1.4.0/index/op/opencv_core/opencv_core-0.5.0.toml` names immutable origin
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`, tree
`bc9396053cde0eaabae513dddf64ad45084a64ca`. It contains GNAT 12 production fixes;
0.5.2 is not required just for its convenient installer.

Keep these distinct:

1. Actual-minimum campaigns use the immutable official-index snapshot
   `fec6b3b6c6e9eb0e17e6c1ae8bc9c194cea44106`, whose only 0.5.x Core is 0.5.0,
   or pin-free consumer dependency intersection (`Imgproc =0.3.0`, `Core =0.5.0`).
   The minimum harness verifies version, immutable origin and lockfiles; rejects
   production pins; requires **1,178** successful tests, zero failed assertions
   and zero unexpected errors. The test crate's parent Imgproc path pin remains
   the intentional hand-written AUnit mechanism, not a production pin.
2. Ordinary publication consumers retain the unchanged `~0.5.0` constraint and
   use the live official index plus only the temporary candidate entry, fresh
   settings/cache, no pins and no neighbouring source fallback. Record the
   actual selected release even if later compatible Core releases appear.

Platform and current documentation helper checkouts now identify Core 0.5.0.
They are bridge/identity helper sources, not overrides of normal Alire builds;
actual deployed dependencies must be audited separately. Debian installed
consumers use exact Core 0.5.0, with GNAT 16.1 full AUnit and separate genuine
GNAT 12.2 production/installed/relocated campaigns. The latter is not the compile-only
GNAT 12 source-unit workflow. The existing full Debian AArch64 reference retains
Core `aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d` (0.5.2), not lower-bound evidence.

The first local genuine GNAT 12 attempt built and installed Core 0.5.0, then
failed compiling the strict development AUnit harness: `guil_template_tests.adb`
reported two redundant lower-bound-check warnings and Core's private C API Vec
representation compile-time diagnostics. Retained in `gnat12-private` and
`gnat12-artifacts`; this is not a passing or full native GNAT 12 AUnit result.
The separate GNAT 12 campaign therefore qualifies unchanged production libraries
and independent installed/relocated consumers only. Full AUnit remains mandatory
under GNAT 16.1. No production representation check, warning policy, language
mode or Core source is modified to manufacture a GNAT 12 test-harness pass.

Local GNAT 12.2.0 production qualification then **passed**, including fresh
strict Core/Imgproc production builds, install, independent Ada/mixed execution,
relocation and clean loader checks with actual Core 0.5.0 / OpenCV 4.6.0. Evidence:
`gnat12-production-private`, `gnat12-production-artifacts` (status 0). Selected
runtime: `/usr/lib/gcc/x86_64-linux-gnu/12/adalib`; GPRbuild's selected Alire
release is 26.0.1, actual executable banner 26.0.0. This native execution is
separate from Debian AArch64 cross-links and user-reported vendor qualification.

The standalone macOS harness retains old main
`5f56b40f9cfe76ae0c4f829f9d1eae0861002768` with Core 0.4.1
`386c5360ac51f2b62e522853d94290aec4ee14a0`. Current candidate uses actual Core
0.5.0. Both are explicitly **temporary version-pin controlled selections** from
the official index, not pin-free publication-consumer proofs. Old SDK failures
must be classified as the expected GNAT-FSF #112 signature, not unrelated
failures. The corrected executable/library/install/relocation and environment
isolation checks remain intact. Shared-GNATdoc controls deliberately retain
their older Core/Imgproc/enhancer inputs and provenance; applicability results
must distinguish a legitimate skip from integration execution.

## Accepted vendor result: carried forward, not rerun

This is **carried-forward, user-reported vendor build/install qualification from
recorded source `3914528dcd2721f86228fa7eea2f27b558ead921`**, not a vendor command
executed at the new release SHA. User-run terminal output showed production
build/install, independent installed/relocated consumers, retained source-identity
verification and exit status **0**, with **`TARGET_RUNTIME_PENDING`**.

User-identified environment: GNAT Pro **25.0w / GCC 12.3.1**, target
`aarch64-linux-gnu`, runtime
`/usr/local/gnat/aarch64-linux-gnu/lib/gcc/aarch64-linux-gnu/12.3.1/rts-native`,
Scarthgap sysroot `/usr/local/yocto/scarthgap/aarch64`, OpenCV **4.9.0**, existing
Core prefix `/usr/local/lib/aarch64-linux-gnu/ada`. User-side retained root:
`/tmp/imgproc-cross-ux-001-r2.bK7bxmVL`.

The user reported a 35-file, 95,852-byte evidence archive with SHA256
`86ce0d7c22b96fa973fb961874e95408e3eafec9564aa29b86e3445b03ca5d56` and explicitly
waived attachment and independent archive inspection. Archive contents/hash
have **not** been independently verified; the container is not directly
accessible. The build/install gate was accepted on terminal evidence; it is
not reopened for metadata/native-CI/documentation changes. No target/emulator
execution or new vendor Core-version identity is inferred from that evidence.

Byte equivalence of the exercised implementation inputs is checked against R2
using Git blob identities and retained SHA256 inventories. Permitted differences
are release metadata, native release/CI harnesses, release-consumer fixtures and
documentation. The existing shared tree at merge establishes the initial
equivalence; final candidate equivalence is recorded in the PR handoff/evidence
without introducing a self-referential documentation commit.

## Qualification evidence and final-head handoff

The initial four-version campaign retained non-system-prefix loader failures;
the release helper now sets the selected pkg-config library directory explicitly
for standalone probes. A subsequent 4.1 historical-Bayer control failed because
it spoofed 4.5.4 even over real 4.1 headers, selecting unrelated unavailable CCL
enum aliases. The test-only spoof now applies only to newer headers: real old
headers already execute the rejection branch. Neither correction changes any
production source or vendor-exercised input. Earlier candidate run identities
remain evidence of those attempts, not final-head qualification.

Evidence root: `/home/zboll/.cache/imgproc-rel-005`. The source PR handoff and
retained evidence record final commit/tree, local/fetched-remote/PR-head agreement,
clean status, exact-head hosted run URLs, attempts, individual job conclusions,
artifact inspection, compiler/runtime/OpenCV/Core identities and failures/retries.
Do not interpret this preparation record as a claim that pending checks passed.

Required evidence includes strict fresh production builds, full 1,178-test AUnit,
OpenCV 4.1/4.6/4.10/5.0, Linux/macOS ARM64/Intel IPP/Windows, real Homebrew and
MacPorts standalone SDK, installed/relocated Ada/mixed consumers, boundary and
sanitizer regressions, loader checks, Debian AArch64 cross/static tasking/R1/R2
controls, configuration/target-dependency/AdaCore controls, and documentation
**1,596/1,596** with zero warnings plus examples/validators. Compiler versions are
reported from tools, never inferred from OS labels. SDK-dependent skips are not
integration passes.

Baseline merge workflows are refreshed independently from candidate runs:
39377543704 (platform including Windows), 39377543830 (standalone macOS),
39377543691 (Debian consumers), 39377543761 (documentation), 39377543713 (cross
configuration), 39377543769 (GNAT 12 compile-only). Earlier R2/merge success is
baseline evidence, not a substitute for final-head qualification.

After normal commit/push, use normal `alr publish --skip-submit` at the exact
pushed commit **with build verification enabled**. Retain generated manifest/logs,
compare non-origin metadata, verify candidate origin/repository, run upstream
index/schema checks and pin-free minimum/ordinary consumers with deployed-source
identity verification. This manifest is a preflight artifact: regenerate using
the independently approved merge commit in the subsequent publication task.

Only use **READY_FOR_INDEPENDENT_REVIEW** after all required baseline and
candidate checks pass. The deliverable is the open non-draft source PR, auto-merge
disabled. Publication awaits independent approval and merge.