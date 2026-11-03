# CORRECTIVE_WORK_REQUIRED — current index no longer resolves required Core 0.5.0

The requested production qualification cannot pass under all current constraints.
This is a source-authority conflict, not an enhancer failure, Core HTTPS mismatch,
or the historical sibling-checkout defect. The new gate fails closed as intended.

## Reproduction and immutable hosted evidence

At source head `21755b35d7cb5d4b39ad763ae33fb478e3ffecba`, tree
`67c41d55a22d8d4996e5968544442ed6843dc1f7`, fresh hosted production workflow
`40440467745`, job `121979380468`, selected **opencv_core 0.5.2** with the
unchanged production manifest `opencv_core = "~0.5.0"`. It successfully built
the library and generated pristine GNATdoc with zero warnings, then rejected:

```text
Dependencies automatically updated as follows:
   +  opencv_core 0.5.2 (new)
Note: Deploying opencv_core=0.5.2...
...
GNATdoc: 0 documentation warnings
GNATdoc warning delta: 0 added, 0 removed
ValueError: documentation requires normal indexed Core 0.5.0 resolution
```

Full exact job log: `hosted-build21755b3.log`. Run, jobs and diagnostics artifact
API records are retained beside this report. Diagnostics artifact **12706322367**
was independently downloaded by immutable ID; ZIP SHA-256
`4c2f9a7fccb374a3a50ad0feb2f3c283a3a7a1d0186c327feba6df792cbc7e05`
matches GitHub's digest. All three pristine native files are byte-identical to
the locally generated Core-0.5.0 input; `gnatdoc.log` is empty. This does **not**
prove that Core-0.5.2 source semantics are authorized by the Core-0.5.0 policy.
No complete hosted candidate was produced, so final-site artifact equality
cannot be claimed. No Pages upload or deployment ran on the PR.

Independently checked community-index commit
`842d7165e3e1e644f4d03563e7a4f35c05415af4`, tree
`aa53a4c447d70f364e066bffe40002a73a09a737`, contains
`index/op/opencv_core/opencv_core-0.5.2.toml`, blob
`43b687eb5606b9948af4b973c589b435d9e5d347`. The immutable manifest is retained
as `index-core-0.5.2-immutable.toml`; it declares version 0.5.2 with source
`aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d`. Required indexed 0.5.0 instead
identifies `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`.

To reproduce, use an isolated fresh exact-head checkout, Alire 2.1.1 with the
current community index, GNAT 16.1.0, GPRbuild 26.0.1 and native OpenCV, then
run `sh scripts/generate_docs.sh`. Do not copy a prior `alire/alire.lock` or
cached-index solution into that checkout: an old local 0.5.0 solution explains
why the local qualification passed while the genuinely fresh hosted build did
not. The hosted log is direct evidence of the actual current-index selection.

## Why this is not silently corrected here

The task explicitly requires normal indexed **0.5.0**, forbids changing library
manifests, and requires fresh hosted reconstruction. Forcing an older solution,
pinning a dependency, altering the index, substituting cached source, widening
the authority to 0.5.2, or declaring identical native Imgproc HTML sufficient
would bypass one of those requirements. None was done.

### Narrow follow-up decision

Choose and independently review one of:

1. Authorize a documentation-only exact indexed-0.5.0 resolution mechanism for
   both build and main-only live reconstruction, without changing public library
   policy; establish how this satisfies the intended normal-index requirement.
2. Authorize a renewed source/native dependency qualification against normally
   resolved Core 0.5.2, with explicit source deltas and exact member/declaration
   comparisons. Do not update old R1 records or merely rewrite counts.

The agent has not made either architecture/dependency-authority decision.
Afterward rerun affected local gates and exact-final-head hosted production CI,
download the actual final review artifact and compare every byte, and obtain
independent final Core URL policy acceptance. Required CI must not be weakened.

## Qualification retained, not overstated

At `21755b3`, official acquisition run **40440467783** passed; artifact
**12706450174**, ZIP SHA-256
`6883b2a7b1e406b83b2021ba973753fddc1b53b664b96d4a64f27ff561b614d3`, was
downloaded and checked. Hosted install/recheck receipts match each other and
all immutable local identities (version, tag, source/tree, wheel/provenance/
checksum, 123 installed members including Markdown, and renderer identities).
This acquisition receipt is not a production candidate artifact.

Exact-head local isolated generation, final source/native/full-site mutations,
live-verifier tests, and parity/repeat checks passed with verified indexed
Core 0.5.0. Full real Chromium API and authored matrices passed and are retained.
All 209 current Core publication files were independently compared before and
after the campaign; all 14 referenced destinations remain compatible. Production
policy is still a proposal for independent merge review, not agent approval.

The complete local **historical** 008C campaign passed against its intended
fixed historical consumer, enhancer `53a321915da2c5a02a54581040673b61f8595b25`
and Core 0.4.1: native/source checks, 36 rejected consumer mutations, full
browser matrix, source-order navigation parity and readiness binding. It tested
isolated historical head `4e3d1b9f4da2c800619e78fefddd11a14892f450`, carrying
integration from `69ccb14`. Its success does not qualify current production,
or the later final-head historical hosted run. Reports live under
`historical-local/` in this additive R2 directory. Historical authority files,
workflow, applicability policy and `.invalid` offline authority remain unchanged.

Current-head Windows is **skipped**, not passed. Other platform checks still
pending at this blocker checkpoint are not credited as successful. The older
main Windows/macOS failures remain independently preserved in `baseline/`.

PR #81 remains open, non-draft, unmerged, auto-merge disabled. No release, tag,
Alire publication, upstream toolkit change or feature-branch deployment.
No public semantic validation is duplicated in the C++ shim; it is unchanged.