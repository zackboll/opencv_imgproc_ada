# IMGPROC-GNATDOC-009R1 — complete Core census; policy review required

**Disposition: `CORE_POLICY_REVIEW_REQUIRED`. Production is unchanged.**

R1 resolves the missing-link experiment: the official unmodified enhancer
successfully emits all **586** source-owned Core link occurrences using genuine
direct-fragment URLs. It does **not** authorize the changed production navigation
semantics. The explicit stopping condition in task §5 applies: material behavior
changes require independent approval before production promotion.

## Fresh state and retained controls

Starting PR #81 head `dc2cdb81754ca097fc586a85f2f75c4223704a00`, tree
`c6723f998960431c1c4f0a9e631a528d56e825fa`, matches both local and freshly fetched
remote. Refreshed main remains `3b44846687354f344d078104fe6101bfb7997534`, tree
`d30dc701e2fd7811e3a85a957872f9194f4e4c76`. PR #80's merge is that main commit;
its head was `882bfbf3c195f33288bc2d1bf301df6842dfb298`. There is no new main
change to merge at this checkpoint. Final feature commit/tree and hosted status
are recorded in the PR checkpoint comment rather than a self-reference.

The release installer is unchanged. Fresh independent recheck verifies official
wheel SHA-256 `b0949aba6736515bf2ebe14fc7cc30c816a176257fc4524564285397b8aaf97d`,
tag object `14463739818eb4c78b93ad42ecc4a4077cbec2bc`, commit
`4ee95e8c95b8c7f54397a07e3e1c507783c115aa`, tree
`c5cff2cff52e595f71202bf97c513b7e0f46c918`, installed package/metadata/asset
bytes, launcher, CLI version and hash-pinned Markdown dependencies. The release
GitHub API was independently refreshed; no local upstream edits or monkey-patches.

All prior GNATDOC-009 files and their hashes are preserved. Historical 008/008C
authorities, inventories, scripts and workflows remain unchanged. R1 files are
additive. The unchanged historical applicability policy sees new evidence and
requires a historical run; its success must never authorize these current links.

Production generation, Ada/C++ sources, Alire manifest, all PR #80 rendering code,
examples, guides, empty warning/coverage baselines and Pages deployment conditions
are unchanged. Only the PR-only non-deployable acquisition workflow is extended
with R1 parser/redirect controls and review evidence upload. It has no Pages
permission or deployment job.

## Complete occurrence reconstruction

`core-destination-proposal.json` retains every occurrence, not just unique names:

* 586 occurrence IDs = genuine Imgproc native declaration anchor plus decoded
  type-mark offset; grouped by distinct Core type and Imgproc declaration anchor.
* Exact Imgproc source declaration identity/profile, source-file hash, declaration
  hash, native page/anchor/snippet/hash, mark spelling and offsets.
* Exact source-resolved Core identity/owner, original production package-query URL
  and `target=_top` semantics, proposed direct-fragment URL and proof reference.
* Original snippets are reconstructed byte-for-byte through the unchanged legacy
  `render` / `resolve` / `type_positions` implementation and compared with the
  actual production snippets after removing only known syntax markup.

The required count remains **586**. Nothing was manufactured to achieve it.
The released output independently matches **every occurrence's anchor, offset,
end offset, label, type identity and exact proposed URL**. Wrong-owner, wrong-URL,
wrong-offset, wrong-label and duplicated-ledger mutations are rejected; totals
alone cannot pass the check. Two early probe defects (HTMLParser's reserved
`offset` attribute and same-document browser hash navigation) were corrected in
the consumer probes, not the enhancer; failed observations are retained.

## Core 0.5.0 authority and hosting compatibility

Alire still resolves unpinned indexed Core **0.5.0**, source commit
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`, tree
`bc9396053cde0eaabae513dddf64ad45084a64ca`. A fresh detached acquisition builds
using the same toolchain, and **all `src/` bytes match the actual Alire-resolved
source**. No adjacent development checkout supplies the production dependency.

Core's genuine native documentation is freshly generated with GNATdoc 26.0.0,
public scope and leading comments. Creating the proper object directories before
generation eliminates the prior exploratory missing-directory warnings; the new
native log is empty. Every referenced type matches an exact public source-owned
type/subtype declaration and its genuine native page, anchor and full snippet.
Source-file, declaration, native-page, native-anchor and snippet hashes are bound.

Current hosted source commit: `aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d`.
Successful Core run: `39361137547`; review artifact ID: `12238050173`; ZIP hash:
`fd328d27efc3196b5861d11c73561c2d22451e2a0fcf2b6477d7c6e0f853cc37`.
Pages deployment ID: `7190346920`, with successful status tied to that source and
workflow run. Fresh acquisition validates the ZIP digest/member safety and
compares the actual HTTPS site to **all 209 artifact files**, including all HTML,
JavaScript, CSS and JSON. No redirects are accepted.

Both pinned and hosted Git sources are inspected independently of destination
metadata. All 14 referenced public declarations have equal source declaration
text/profile in those two revisions. Their genuine native snippets are identical
to the hosted snippets. The hosted Core revision does contain other API additions:
this is a **bounded compatibility proof for the referenced types**, not a claim
that entire versions are identical.

The unversioned Pages URL is **mutable**, not immutable. A future production
acceptance policy must fail closed on changed indexed source, declaration/native
identity, deployment/artifact identity, hosted bytes, occurrence ledger or URL.
Any update requires fresh independent qualification and explicit policy review.
The proposed mapping never uses `.invalid`, `?package=` or `?symbol=`.

## Live browser campaign

`core-candidate-browser-final.json` records the eight combinations of 1280/390px,
light/dark and JavaScript enabled/disabled, against actual HTTPS without request
interception. In each combination:

* All 14 direct-fragment destinations load without redirect and match artifact
  page bytes, package owner, unique fragment, visible declaration heading and
  exact native type snippet.
* Generated links for each type are keyboard-activated from the actual shared API
  iframe under the `/opencv_imgproc_ada/` project prefix. Loaded declaration text
  is checked, followed by actual iframe Back/Forward navigation.
* Unexpected console/page/network errors fail. The genuine Core host's optional
  `/favicon.ico` 404 is explicitly observed and classified, not intercepted or
  silently treated as a successful resource. Other 4xx responses are rejected.

Earlier failed attempts remain: a hash-only `goto` has no Response; waiting on an
old iframe target races the document load; `page.goBack(waitUntil=load)` waits on
an outer lifecycle for a joint iframe-history entry; optional favicon 404 was
initially unclassified. The final campaign waits on actual frame URL and target
content and retains the exact optional-resource exception. No sleeps or altered
expected type identities were used.

## Decision required before production

**Two material changes affect all 586 API Core links:**

1. Package-overview query navigation becomes direct declaration navigation.
2. Legacy links specify `target=_top`; v0.1.0 emits no target, so Core stays inside
   the Imgproc iframe. The outer URL continues identifying an Imgproc declaration.

The first transition is the requested candidate direction, but must be explicitly
classified in the destination policy. The second was not established in the prior
campaign and is independently demonstrated by Chromium. Both must be accepted by
independent review, or a separately reviewed upstream capability must preserve
the required top-level behavior. There is no consumer HTML rewrite, injected
script, local patch or invented fallback in this PR. This is not an upstream
defect claim: it is an observed behavior change requiring policy approval.

`policy-review.json` deliberately says `policy_approved: false`. The generator's
proposal cannot approve itself. The candidate TOML is evidence only and is not
read by production. No production destination authority is falsely minted from
successful output hashes.

## Local additions and retained API qualification

All **348** original local occurrences retain their source identity, type-mark
offset and genuine anchor. Shared filename-plus-fragment links resolve to the
same native package page and fragment as old same-page links.

Two additions are independently source-proven:

* `Background_Label : constant Component_Label := 0` (public source line 1939)
  links to public `type Component_Label is new Natural` (line 1935).
* `Default_Morphology_Border : constant Morphology_Border_Value` (line 2038)
  links to the **public partial view** `type Morphology_Border_Value is private`
  (line 2033), not its private completion.

Both references occur in defining constant type-mark positions; they are valid
proposed improvements, not output-authorized count changes. Their source/native
proof and exact anchors are in `candidate-reconciliation.json`. No valid link is
suppressed just to reproduce 348.

The candidate has 329 exact source-order operation entries and native sections,
1,596/1,596 documented elements, zero documentation warnings, 350 local links and
586 exact Core occurrences. Two fresh released enhancements are byte-identical;
repeat enhancement is byte-idempotent. The six existing examples compile and run
again unchanged. PR #80's source fidelity, highlight and authored renderer remain
intact. Full shared authored-output qualification has **not** been performed past
the Core policy gate; neither a weaker renderer nor a duplicate production API
postprocessing path has been enabled.

## Hosted state and artifact boundary

The starting-head acquisition workflow has now succeeded, unlike the queued
observation recorded in GNATDOC-009. Its actual uploaded receipt artifact ID
`12321453034` was downloaded and matched ZIP digest
`b7c8460f0af6a2eb93cf335d5e137c0bbab7467dd4d2a21bb66a6b2e2c9bf8c3`.
It contains installation receipts, **not a qualified Imgproc Pages candidate**.
Other current job outcomes are recorded separately with individual queued,
running, successful and skipped jobs; final-head outcomes belong in the PR.

No complete shared production site, production Pages artifact equality or
exact-final-head qualification claim is made. Remaining downstream gates are
authored parity, full-site semantic classifications, complete shared production
browser/security controls, main-only workflow promotion, complete Pages inventory
and project-prefix validation, and independently downloaded final candidate
artifact comparison. Deployment and public HTTPS acceptance remain post-merge.

PR #81 must remain non-draft, open, unmerged and auto-merge disabled.