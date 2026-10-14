# IMGPROC-REL-001 — Imgproc 0.2.0 release qualification

## Scope and source identities

Proposed release: **opencv_imgproc 0.2.0**, not tagged or published.
Both origins were fetched before qualification and matched the requested mains:

* Imgproc: `98c5fcc449ea0da385a09ca06d0569adc9a86d0f`.
* Core development reference: `23a8a4796691cd3fe552db4aa0e8351e691a53b5`.
* Indexed Imgproc 0.1.0: `88a6a94f309135fb536d1814d106d244a032dc62`.
* Indexed Core 0.4.1: `386c5360ac51f2b62e522853d94290aec4ee14a0`.
* Updated community index: `068f3873c7732229d4d586836882266494a6d50d`,
  branch `stable-1.4.0`.

The isolated branch `release/imgproc-0.2.0-preparation` is at
`/home/zboll/git/opencv/imgproc-rel-001`. Original Imgproc HEAD was
`cc1e7a5c4c642ee8029d0de054a49035d3d844de`; original Core HEAD was
`769d286cc16d782936c45ecd1d7220606e98b81a` (detached). Existing worktrees and
changes were preserved. No Core production code or ABI assertion was changed.
The candidate source commit and final review HEAD are recorded in the review
handoff rather than embedding a self-referential commit hash here.

## Indexed dependency audit and executed evidence

Inspected actual community entries
`index/op/opencv_imgproc/opencv_imgproc-0.1.0.toml` and
`index/op/opencv_core/opencv_core-0.4.1.toml`, their indexed source deployments,
current manifests/GPRs and the Core release-to-development diff.
Core 0.5.0 is not indexed at the recorded index revision.

Imgproc uses Core Mat construction/metadata/Region/Clone/lifetime, typed scalar
and vector element access, Float32 read-only row callbacks, Mat_Array,
returning Add/Subtract, In_Range, Count_Non_Zero, and the Mat module interop
callbacks. These are present in 0.4.1. Its module bridge supplies borrowed
input/output Mat resolvers and is installed in `<prefix>/include` by Core's
GPRinstall artifact rule. The bridge file is unchanged between indexed 0.4.1
and the recorded development main. Imgproc does not require the later reusable
Core destination overloads or later GNAT 12 representation work.

Actual `alr get --only opencv_core=0.4.1` fetched the index-selected immutable
origin. `--only` was used for source inspection, not build qualification.
Fresh root and test workspaces subsequently resolved through the community
index, with `dependencies.shared=false`, no Core pin and no adjacent Core.
All production Ada sources and the complete C++ shim compiled, archived and
linked. Full AUnit execution: **1129 run, 1129 successful, zero failed
assertions and unexpected errors** on both Debian 12/OpenCV 4.6 and Debian
13/OpenCV 4.10. The candidate manifest itself also passed root build and full
AUnit on the host. Its Core requirement is `~0.4.1`, not a speculative 0.5
requirement or a constraint justified by adjacent main.

Test solution: `aunit=26.0.0`, `gnatprove=16.1.0`, `gnatcov=26.2.1`,
`opencv_core=0.4.1`, `pkg_config=1.8.1`, and native OpenCV as below.
The authoritative test crate retains its repository-required `..` pin to
Imgproc under test. This is not a Core override and is not a pin in the
published library. The separate external release consumer contains no pins.
Tool binaries resolve from the index; proof/coverage tools are not library
dependencies. No new proof claim is made for this packaging change.

`scripts/qualify_indexed_release.sh` reproduces root resolution/build, full
AUnit, existing arithmetic boundary regressions, sanitizer-enabled production
corpora and loader diagnostics in a fresh source export. Logs are under
`obj/release-qualification`. Independent task evidence is disk-backed at
`/home/zboll/.cache/imgproc-rel-001`; `/tmp` was already full, so no unrelated
files were removed. The first indexed deployment and one example build failed
for that capacity reason; disk-backed TMPDIR reruns succeeded.

## Installation and consumers

The existing Debian 12 independent-consumer driver passed with exact Core
0.4.1 source (production directories compared with the indexed deployment).
Core and Imgproc were separately GPRinstalled. The complete Imgproc shim was
then compiled against installed Core, with no Core checkout on its search
path. `cmp` verified the installed bridge. A second container had no binding
source mount and no Alire; ordinary GPRbuild compiled and ran both Ada and
mixed Ada/C++ consumers from installed and relocated prefixes.

All four consumers passed Mat creation/access, color conversion, Gaussian
blur, resize, invalid-input/native-error translation, independent output
storage and Region lifetime checks. ELF/`ldd -r` checks passed with no missing
libraries or unresolved symbols, selecting OpenCV Core/Imgproc `.so.406`,
libstdc++ and the Debian runtime closure. These results qualify indexed Core
installation compatibility, not an unpinned candidate-index consumer by
themselves. The new `tests/release_consumer` additionally exercises ordinary
and masked template matching and survivor ownership; its external deployment
must be qualified through the generated candidate index before readiness.

## Platform and toolchain matrix

| Environment | Executed evidence | Release scope |
| --- | --- | --- |
| Debian 12 x86_64, GNAT 16.1.0, OpenCV 4.6.0 | Candidate root, 1129/1129 AUnit, native boundary/sanitizer suite; exact Core 0.4.1 installed/relocated Ada and mixed consumers pass | Primary native target |
| Debian 13 x86_64, GNAT 16.1.0, OpenCV 4.10.0 | Candidate root, 1129/1129 AUnit, native boundary/sanitizer suite pass | Additional native target |
| Linux OpenCV 4.1.0 / 5.0.0 | Initial Core-only container attempts lack imgproc headers/library; not a compatibility pass | Retain existing matrix; supplemental qualification pending |
| macOS ARM64 | Starting-main hosted Linux/macOS jobs passed; those used development Core, not candidate indexed Core | Candidate hosted qualification required |
| Windows x86_64 / MSYS2 | Candidate hosted provisioning/build/execution not yet established | Report package-download failures separately from compiler failures |
| Arch Rolling | Published 0.1.0 exclusion preserved | Unavailable in candidate manifest |
| Debian 12 GNAT 12 / AArch64 | Previously qualified source-unit/compiler and target-dependency controls only | No full production support |
| AdaCore AArch64 / Yocto Scarthgap | Adapter infrastructure and Debian controls only | No target execution or production qualification |

Alire **2.1.1**, indexed compiler **gnat_native 16.1.0** (GNAT reports 16.1.0),
indexed **gprbuild 26.0.1** (reports 26.0.0, 2026-04-15), GNATdoc **26.0.0**.
Debian 12 consumer image identity:
`5262e03377d9f194cc16c1e5bc295b97dcad7712ac66599b6874bf1a42b17641`.
Primary native C++/runtime package identities and installed hashes are retained
in the independent-consumer evidence, not inferred from the host (Debian 13).

## Documentation and API review

Fresh candidate generation against resolved indexed Core passed with **zero
GNATdoc warnings**, **1512/1512 coverage items**, 314 declaration sections and
184 subprograms. All local links/anchors and five guides validate. Landing
page and five guide programs compiled and executed. Type-link helper controls:
20/20; generated-site validator controls: 43/43. No baseline was relaxed.
The generator now discovers the resolved Core source, rather than requiring
an adjacent development checkout.

See CHANGELOG for the source comparison and merged PR classification. Contours,
connected components, ordinary matching/Hough, histograms and much geometry
already existed in 0.1.0; they must not be presented as wholly new. Existing
public callable profiles remain, with additive overloads and enum literals.
New literal additions may require client exhaustive case updates; rebuild
clients/shims. Mat ownership remains exclusively Core's. Documented
operation-specific destination behavior is not a new universal guarantee.
The pre-1.0 minor version **0.2.0** appropriately identifies these additions.

## GNAT 12 and target limitations

Preserve the distinctions recorded in IMGPROC-EXT-003A/002B/002C:
Debian GNAT 12 real Imgproc source-unit compilation, AArch64 compiler/source
controls, complete C++ object checks and Debian AArch64 OpenCV dependency
closure are partial controls. Post-Yocto AdaCore adapter fixtures do not
establish a genuine compiler/runtime/sysroot or execution.
Core alignment/representation safety remains an independent prerequisite.
**GNAT12_PRODUCTION_PENDING** and **YOCTO_TARGET_PENDING** remain applicable;
neither needs to delay preparing a native GNAT 16 candidate.

## Publication preflight and remaining gates

Installed Alire supports `publish --skip-submit` and `--for-private-index`.
Only non-submitting validation is permitted. A control preflight of original
main failed: discarded development pins selected Core 0.1.0, then compilation
failed at `opencv_core_module_bridge.hpp`. That is not the corrected candidate.
The final candidate must be committed, checked with its exact immutable source
identity, and consumed from a temporary private index without path/source pins.
Generated manifest must retain native dependencies, Windows settings and Arch
restriction. Repository manifest has no origin; generated manifest adds the
immutable Git origin and must not describe a different source tree.

At this checkpoint, candidate-index preflight/external consumer and candidate
hosted platform checks remain open. Do not interpret successful local checks
as **ALIRE_MANIFEST_QUALIFIED** or **RELEASE_CANDIDATE_READY** until those gates
are recorded. No tag, GitHub Release, public index PR, auto-merge, amendment or
force-push is authorized. Hosted run IDs and final source parity belong in the
final handoff; pending/failed jobs must not be called successful.

No public semantic validation is duplicated in the C++ shim by this task;
the production shim is unchanged.