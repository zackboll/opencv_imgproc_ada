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
and masked template matching and survivor ownership. Fresh external deployments
passed through the generated candidate index on Debian 13/OpenCV 4.10 and in
a separate Debian 12/OpenCV 4.6 container without binding source mounts.

## Platform and toolchain matrix

| Environment | Executed evidence | Release scope |
| --- | --- | --- |
| Debian 12 x86_64, GNAT 16.1.0, OpenCV 4.6.0 | Candidate root, 1129/1129 AUnit, native boundary/sanitizer suite; exact Core 0.4.1 installed/relocated Ada and mixed consumers pass | Primary native target |
| Debian 13 x86_64, GNAT 16.1.0, OpenCV 4.10.0 | Candidate root, 1129/1129 AUnit, native boundary/sanitizer suite pass | Additional native target |
| Debian 13 x86_64 / source-built OpenCV 4.1.0 | Root build passes; AUnit 1127/1129, one assertion and one unexpected error | Release matrix gate failed; do not silently exclude |
| Debian 13 x86_64 / source-built OpenCV 5.0.0 | Root, AUnit 1129/1129, native boundary/sanitizer suite and loader diagnostics pass | Supplemental native compatibility tested |
| macOS ARM64 | Starting-main hosted Linux/macOS jobs passed; those used development Core, not candidate indexed Core | Candidate hosted qualification required |
| Windows x86_64 / MSYS2 | Candidate hosted provisioning/build/execution not yet established | Report package-download failures separately from compiler failures |
| Arch Rolling | Published 0.1.0 exclusion preserved | Unavailable in candidate manifest |
| Debian 12 GNAT 12 / AArch64 | Previously qualified source-unit/compiler and target-dependency controls only | No full production support |
| AdaCore AArch64 / Yocto Scarthgap | Adapter infrastructure and Debian controls only | No target execution or production qualification |

Alire **2.1.1**, indexed compiler **gnat_native 16.1.0** (GNAT reports 16.1.0),
indexed **gprbuild 26.0.1** (reports 26.0.0, 2026-04-15), GNATdoc **26.0.0**.
Debian 12 consumer image identity:
`5262e03377d9f194cc16c1e5bc295b97dcad7712ac66599b6874bf1a42b17641`.
Primary native packages: `libopencv-dev`, Core406 and Imgproc406
`4.6.0+dfsg-12`, `libstdc++6` `12.2.0-14+deb12u1`, libc6
`2.36-9+deb12u14`. Installed hashes are retained in independent-consumer
evidence, not inferred from the host (Debian 13).

## Documentation and API review

Fresh candidate generation against resolved indexed Core passed with **zero
GNATdoc warnings**, **1512/1512 coverage items**, 314 declaration sections and
184 subprograms. All local links/anchors and five guides validate. Landing
page and five guide programs compiled and executed. Type-link helper controls:
23/23 after adding CLI resolved-Core regression controls; generated-site
validator controls: 43/43. No baseline was relaxed.
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
Candidate source commit `85f9b1d54907410fb89c1edef6434b7edd2ef0ff` passed
`alr -n publish --skip-submit` including its fresh origin build. Generated
manifest: `alire/releases/opencv_imgproc-0.2.0.toml`. A temporary private index
passed `alr index --check`; a fresh consumer resolved Git origins for Imgproc
at that commit and Core at `386c5360ac51f2b62e522853d94290aec4ee14a0`.
The consumer compiled and ran all representative checks, including masked
template matching. Every lockfile entry has `pinned=false`. GPR search paths
name only the new consumer and its own dependency deployments, not original
builder directories or adjacent Core. `ldd -r` passed against native `.so.410`
libraries. Repository/index manifest difference is only the appended immutable
Git origin; dependencies, actions, Arch exclusion and MSYS2 settings match.
The task's final commit may add qualification records/helper controls; any
final manifest must be regenerated for that exact new commit, not reuse the
earlier origin identity.

## OpenCV 4.1 release blocker

After the initial version containers proved to be Core-only, supplemental
full Core/Imgproc native installations were located and actually executed.
OpenCV 4.1 source tag identity is
`371bba8f54560b374fbcd47e7e02f015ac4969ad`. Its full suite returns **1127
successful of 1129**, with these unchanged tests failing:

* `EA textured interior differs from bilinear`: assertion `textured native
  BGR/RGB order` at `bayer_demosaicing_tests.adb:275`.
* `Otsu UInt16 agrees with fixed threshold`: `OpenCV_Error`, native 4.1
  `thresh.cpp:1509`, assertion `src.type() == CV_8UC1`. Exact-tag source
  inspection confirms this Otsu path only accepts UInt8.

Loader evidence confirms both Core and Imgproc come from the same native
4.1 installation, not mixed system 4.10 libraries. These are not missing
indexed Ada Core declarations or an unreleased Core prerequisite. No test,
public validation or shim was weakened to hide them. The unchanged full-suite
gate must be repaired or its support contract explicitly reviewed before
release readiness; this task does not silently narrow the requested matrix.

The supplemental 5.0 installation passes all 1129 tests and native corpora.
Upstream 5.0 tag identity: `40738fb16ceddb5fb3fea747585f7ce6abb0605b`;
the reused full installation came from a tag source archive whose SHA256 is
`b0528f5a1d379d59d4701cb28c36e22214cc51cf64594e5b56f2d3e6c0233095`.
Both 4.1 and 5.0 native libraries are external OpenCV builds, not Ada Core
source overrides. Alire reports the installed distro OpenCV package as 4.10
on this host even when pkg-config/compiler/loader select these source-built
versions; its system-crate model is not the runtime identity.

| Native library | SHA256 |
| --- | --- |
| 4.1 Core | `70453b18476d399b3a09ce50431cd22f1da1d5eabc6e12cea4d93538b1499bbf` |
| 4.1 Imgproc | `be6e0204a6cdb3abc3e380fc831bb7a381fec05fc820cce7d5fda9a371c584a4` |
| 5.0 Core | `4c30edbfff25b04b6934f7968f1ab2cc646447df2360138caaae640323d3f7b2` |
| 5.0 Imgproc | `ba5c0be27bd4829a3cea27cbaf4b0e3a0730e5368291352b443730831fdd6e44` |

The exact candidate manifest additionally passed the existing Debian 12
installed/relocated Ada and mixed consumer driver with exit zero, in fresh
task evidence. Primary 4.6 and 4.10 boundary/sanitizer suites both completed
successfully. This is separate from the failed 4.1 full suite.

## Disposition and hosted evidence

* **CORE_INDEXED_DEPENDENCY_QUALIFIED**: Core 0.4.1 works; no Core 0.5
  functionality is required by the executed source.
* **PIN_FREE_ALIRE_QUALIFIED**: candidate library and private-index external
  consumer build/run without development pins.
* **RELEASE_PLATFORM_QUALIFIED**: primary Debian 12/GNAT 16.1/OpenCV 4.6
  native build/tests/installed consumers pass, with the scope stated above.
* **ALIRE_MANIFEST_QUALIFIED**: non-submitting publication assistant and
  temporary-index consumer pass for the recorded candidate source commit.
* **RELEASE_CANDIDATE_READY**: **NOT ESTABLISHED**, because the required 4.1
  matrix has two actual test failures and candidate hosted checks are pending.
* **CORE_RELEASE_PREREQUISITE_BLOCKED**: **not applicable**.
* **GNAT12_PRODUCTION_PENDING**, **YOCTO_TARGET_PENDING**: remain applicable.

Starting-main hosted runs (development dependency evidence only) completed:
cross-platform `38514688407` (Linux, macOS, Windows success), documentation
`38514688396`, installed consumers `38514688399`, source-unit controls
`38514688395`, cross configuration `38514688385`. These do not substitute for
the candidate's indexed-Core hosted checks. Candidate workflow_dispatch runs
were requested at `85f9b1d54907410fb89c1edef6434b7edd2ef0ff`:
cross-platform `38516899037`, documentation `38516900877`, independent
installed consumers `38516903129`. Pending jobs are not passes. These runs
precede the follow-up directing native CI probes to the resolved Core prefix;
final-source dispatch identities/status are recorded in the handoff.

No release review PR is opened while the mandatory matrix gate is failing.
The preparation branch is retained for inspection, with ordinary commits and
no amendment or force-push. No tag, GitHub Release, public index PR or auto-merge
was created. Remaining blockers to opening an Alire PR: resolve the two 4.1
failures without weakening tests, complete exact-final-source hosted checks,
review the preparation PR, then separately authorize tagging/publication.

No public semantic validation is duplicated in the C++ shim by this task;
the production shim is unchanged.