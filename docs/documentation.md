# Public Ada API documentation

Live Pages acceptance is documented in
[IMGPROC-DOC-EXAMPLES-002 qualification](live-publication-qualification.md).
After successful main deployment, the read-only `verify-live` job independently
reconstructs the expected source's site, qualifies both same-run artifacts,
compares every live decoded HTTP entity, checks current Core public bookmarks,
and runs the real-browser example/navigation matrix. PR runs test the verifier
against offline HTTP and adversarial fixtures, never deploy or claim to execute
the main-only job. JSON/log/browser evidence is retained even on failure.

The specification `src/opencv-image_processing.ads` is authoritative. The
generated site is intended for `https://zackboll.github.io/opencv_imgproc_ada/`;
its landing page is `_site/index.html` and the native GNATdoc reference is
`_site/api/index.html`. Do not commit generated HTML.

The tooling is adapted from the qualified `opencv_core_ada` documentation
pipeline (Core `main` `7bcdc3a1b130b8f51f2c97ac9f014578a281e64e`). Campaign
status, inventories and the remaining roadmap are kept in
[the campaign record](gnatdoc-campaign-progress.md).

## Reproduce on Linux — pinned generation environment

Required qualification versions:

| Tool | Release / executable version |
| --- | --- |
| Alire | 2.1.1 |
| GNAT Native | Alire `gnat_native=16.1.0`, executable GNAT 16.1.0 |
| GPRbuild | Alire `gprbuild=26.0.1`, executable 26.0.0 (2026-04-15) |
| GNATdoc | Alire `gnatdoc_bin=26.0.0`, executable 26.0.0 (20260415) |

Also install a supported native OpenCV development library, pkg-config, a
C++17 compiler, a POSIX shell and Python 3.11 or newer. The generator installs
the official v0.1.1 enhancer wheel and hash-pinned optional Markdown dependencies
in an isolated documentation environment, never in Alire.
`alire.toml` resolves indexed Core 0.5.0 without a pin. No neighboring Core
checkout is required:

```sh
git clone https://github.com/zackboll/opencv_imgproc_ada.git imgproc
cd imgproc
alr -n --force toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
sh scripts/generate_docs.sh
```

The script locates the repository root itself. It installs the pinned binary
GNATdoc crate into `.doc-tools/gnatdoc-26.0.0` when absent; Alire verifies the
archive against the index's SHA-256. An existing installation can be reused:

```sh
GNATDOC_PREFIX=/path/to/gnatdoc-26.0.0 sh scripts/generate_docs.sh
```

The script refuses other Alire, GNAT, GPRbuild or GNATdoc versions rather than
silently substituting them. It builds the library through Alire (not the test
crate) to resolve dependencies and generate the normal OpenCV configuration,
then runs:

```sh
alr exec -- "$GNATDOC_PREFIX/bin/gnatdoc" -P docs_api.gpr \
  --backend html --generate public --style leading --warnings -O "$PWD/obj/docs/native/api"
python3 scripts/compare_gnatdoc_warnings.py --fail-on-removed \
  docs/gnatdoc-warning-baseline.txt obj/docs/gnatdoc.log
python3 scripts/validate_docs.py _site
```

`docs_api.gpr` parses `src/` with the production Ada compiler switches.
`docs_internal.gpr` makes `src/internal` available for name resolution, and
both import `opencv_core.gpr` for the Core types. The `Documentation` package
excludes `docs_internal.gpr`, the generated configuration project and
`opencv_core.gpr` (located through `OpenCV_Core'Project_Dir`, because the
attribute requires a resolvable path). Only `OpenCV.Image_Processing` is
published; its private part, the body, `OpenCV.Image_Processing.Internal`,
`OpenCV.Image_Processing.Internal.C_API`, the C++ shim and every Core package
are not. These projects do not import the production project: redeclaring its
sources would violate GPR source ownership. The library projects, ABI,
manifest and dependencies are unchanged.

`_site/` is deleted before each generation. Full diagnostics stay in
`obj/docs/gnatdoc.log` and are not published. `--warnings` stays enabled.
GNATdoc errors, partial-generation diagnostics, warning regressions, missing
public declarations and broken local links fail the script.

## Warning baseline

GNATdoc warnings are measured, not suppressed. After a successful run,
`compare_gnatdoc_warnings.py` maps every warning in the log to one Ada
declaration and compares the result with `docs/gnatdoc-warning-baseline.txt`,
which stores one identity per warning:

```text
filename: enclosing scope: normalized declaration signature: warning: message
```

The signature is the complete declaration with comments removed and
whitespace normalized, so overloads remain distinct and a function keeps its
return profile. The scope includes the enclosing record for components and
the enumeration type for literals. Line and column numbers only locate the
declaration in the current sources: line shifts, comment edits and log
reordering match, while a warning that moves to another declaration is an
addition. Unmapped or ambiguous locations, and warning-shaped lines that are
not the pinned `file:line:column: warning:` form, fail closed.

Imgproc adaptations of the Core comparator, each covered by
`test_compare_gnatdoc_warnings.py`:

- An identifier list such as `X_Shift, Y_Shift, Response : T;` declares one
  identity per name, located at its own column.
- A declaration may span up to 200 lines (`Color_Conversion` spans 87); longer
  unterminated declarations still fail.
- Enumeration literals are located as whole identifiers in code, never as a
  prefix of a longer literal or inside a comment.
- `--fail-on-removed` makes the baseline a ratchet: fixing a warning without
  regenerating the baseline fails, so a fixed warning cannot silently return.
  `generate_docs.sh` always uses it.

After an intentional, reviewed documentation change, regenerate the baseline
from a complete pinned GNATdoc 26.0.0 log and the sources of the same revision:

```sh
python3 scripts/compare_gnatdoc_warnings.py --write-baseline \
    docs/gnatdoc-warning-baseline.txt obj/docs/gnatdoc.log
```

Never replace it with a raw log, and never rewrite it to accept new warnings.
Do not silence a warning with `@exclude`, an empty comment or a changed
generator invocation. The initial baseline recorded 1,357 warnings;
IMGPROC-DOC-002G reached zero, and the baseline is now required to stay empty
(see below).

## Site validation

`validate_docs.py` derives its expectations from `src/*.ads`, never from the
generated output, and modifies nothing:

- The site contains exactly `index.html`, `api/index.html`, `api/gnatdoc.css`,
  the presentation files listed below, and one native page per public
  package. GNATdoc 26.0.0 names package pages with 64-hex hashes; pages are
  identified by their actual `<h1>`, never by a computed filename. Any other
  file, an internal or Core package page, or a missing public package fails.
- `api/index.html` must equal the pinned GNATdoc 26.0.0 serialization rebuilt
  from the discovered pages, including every `target=document-content`, plus
  only the approved presentation changes.
- Every visible-part declaration has exactly one native `h4` section of the
  same kind. Subprogram sections must reproduce the complete normalized
  profile, so removing, adding or altering one overload fails, and private-part
  declarations must not appear. Selected overloads must render their own
  comments in their own section.
- Links must be relative and resolve inside the site, including fragments.
  The only external links in API pages are the two recomputed package-level
  Core type links described below; the landing page may link only to the
  Imgproc and Core repositories and the Core documentation site.
- Scripts, `base`/`object`/`embed`/`form` elements, `meta http-equiv`, event
  handler attributes, duplicate IDs, internal unit names and machine-local
  paths are rejected.
- The landing-page example must be exactly `docs/example.adb`.

`test_validate_docs.py` applies negative mutations to a synthetic fixture in
the pinned serialization and, when `_site` exists, to a copy of the real
generated site: missing stylesheet, broken and redirected anchors, swapped
index targets, duplicate IDs, scripts and handlers, root-absolute, traversal
and external links, internal package pages, stray files, removed or altered
overloads, published private declarations, misplaced overload comments,
leaked paths and changed examples must all be rejected.

## Presentation: theme, type links and Ada highlighting (IMGPROC-DOC-003)

**Historical implementation, retained only as the explicit review oracle.**
Production now follows the R2 released pipeline described below; do not run
these postprocessors on shared-enhanced files. The original pipeline ran three
deterministic, idempotent steps after the warning check; each verifies the
previous ones before writing anything:

1. `install_gnatdoc_theme.py` inserts one viewport `meta` and one stylesheet
   link after GNATdoc's native stylesheet in every API page and copies
   `docs/assets/gnatdoc-theme.css` (responsive layout, light and dark color
   schemes, visible keyboard focus, readable code blocks that scroll inside
   themselves on narrow screens). `api/presentation.json` records every
   page's native HTML outside declaration snippets and the hash of the
   native `gnatdoc.css`; any other change to that HTML or either stylesheet
   fails.
2. `link_gnatdoc_types.py` links type marks inside native declaration
   snippets only: parameter, component, return, array component, subtype and
   derived-type positions, never defaults, constraints or attributes.
   - An Imgproc type links to its own native section anchor, discovered from
     the source-matched section, when exactly one visible-part declaration
     of that name precedes the reference and no parameter or discriminant
     of the same declaration shadows it.
   - `OpenCV.X` and `OpenCV.Core.X` link only when Core's `src/opencv.ads`
     or `src/opencv-core.ads` (from the sibling `../core` checkout) declares
     that type in the visible part of exactly that package. The destination
     is the published Core browser's package bookmark,
     `https://zackboll.github.io/opencv_core_ada/api/index.html?package=OpenCV`
     or `...?package=OpenCV.Core`, the only stable destination its
     navigation supports; no declaration fragment is invented. These links
     carry `target="_top"` so the Core site replaces the whole window
     rather than nesting frames, and are drawn with a dashed underline.
   - Standard types (`Natural`, `Positive`, `Boolean`, `String`) and anything
     unresolved stay unlinked.
   `api/type-crossrefs.json` keeps the original snippets and a hash of the
   page outside them; validation recomputes every link and requires
   byte-identical snippets. The current output has 331 Imgproc and 551
   Core links in 314 snippets; 69 Standard type marks stay unlinked.
   GNATdoc 26.0.0 elides the middle of long enumeration snippets (`…,`);
   the source matcher accepts exactly that elision, and the complete literal
   lists remain under each type's Enumeration Literal heading.
3. `highlight_gnatdoc_ada.py` colors Ada keywords, numbers, strings,
   characters, attributes, comments and operators inside snippets with
   flat `ada-*` spans, keeps type links atomic and proves that removing the
   spans restores the exact snippet text.

`validate_docs.py` then repeats the theme, link and highlighting checks
independently and probes representative overloads (`Phase_Correlate`,
`Gaussian_Blur`, `Find_Contours`) for the exact type identities their own
snippets must link. `test_link_gnatdoc_types.py` covers a synthetic fixture,
and `test_validate_docs.py` mutates the real site: wrong-but-existing type
destinations, fabricated Core declaration fragments, removed links, changed
declaration text, changed descriptions, a tampered theme asset, corrupted or
downgraded manifests and stray presentation files are all rejected.
Repeating the three steps on a finished site is byte-identical.

The optional real-browser harness `scripts/test_gnatdoc_presentation_browser.cjs`
uses an externally installed Playwright module and Google Chrome (never a
site or library dependency). At 1280 and 390 pixels in light and dark it
checks the landing page and API page backgrounds, the absence of horizontal
page overflow, highlighting, that every Core link is an approved package
bookmark opening at top level, that an internal type link lands on the
native anchor, keyboard focus outlines, a Core link replacing the window,
and native navigation with JavaScript disabled:

```sh
python3 -m http.server 8072 --bind 127.0.0.1 --directory _site
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright \
DOC_URL=http://127.0.0.1:8072/ node scripts/test_gnatdoc_presentation_browser.cjs
```

## Operation-level API browser (IMGPROC-DOC-004, historical implementation)

Core's browser searches 195 packages; Imgproc publishes one package with
314 declarations, so its browser works per declaration.
`enhance_gnatdoc_navigation.py` changes only `api/index.html`, adding:

- one hidden search control group (label, search field, Clear button and a
  polite live status), revealed by the script;
- a static "Public API" list in the sidebar with every visible-part
  declaration, grouped into eight collapsible `<details>` categories. Each
  entry is a native link to the declaration's verified anchor in the
  documentation frame and shows its kind and, for overloads, "overload N
  of M"; the full profile is the link title;
- one deferred repository-owned script, `gnatdoc-navigation.js`.

Entries come from the public specification (names, kinds, profiles, overload
order), the reviewed category manifest `docs/api-categories.json` and anchors
discovered from source-matched native sections. The manifest must assign
every public declaration name to exactly one of its eight categories and name
nothing else; a new declaration fails generation until it is categorized. No
filename or anchor is computed.

The script provides case-insensitive search over name, kind, category title
and profile (every word must match, so `match template` finds
`Match_Template`), category expansion for matches, a count or "No matching
declarations." in the live status, and Clear, which restores the list and
returns focus to the field. Selecting an entry marks it with
`aria-current="page"`, loads its anchor in the frame by replacing the frame's
history entry, and records a bookmark such as
`api/index.html?op=Match_Template&overload=2` in the outer history, so Back,
Forward and reload restore the selection. Lookups ignore identifier case and
canonicalize the URL; unknown or path-like requests select nothing and are
removed from the URL. Destinations always come from the static entries,
never from query or search text. Without JavaScript the controls stay hidden
and the categorized links, compilation unit link and tabs still work.
Declaration pages are unchanged.

Validation rebuilds the expected index from the pinned native serialization,
the theme metadata and the recomputed entries and compares it byte for byte;
the script bytes must equal the repository asset, and it is the only script
allowed, once, in the index. `test_gnatdoc_navigation.py` rejects category
manifest errors, wrong-but-existing destinations, missing entries, inline
handlers, extra scripts, a tampered asset and changed frame targets, and
checks that every declaration has exactly one entry and that enhancement is
idempotent.

`scripts/test_gnatdoc_navigation_browser.cjs` (optional Playwright and
Chrome, as above) qualifies the browser at 1280 and 390 pixels in light and
dark: the 314 entries and eight categories, searches for `gAuSsIaN`, `warp`,
`contours`, `hough`, `match_template`, `match template`, `phase_correlate`
and `color conversion`, overload labels, no-results and Clear, frame
navigation to native anchors, bookmarks, Back, Forward, reload, a copied
case-insensitive bookmark in a fresh context, an unknown request, keyboard
search and selection with visible focus, no page overflow, and
JavaScript-disabled navigation through a category.

## Declaration coverage (IMGPROC-DOC-002A)

`scripts/check_doc_coverage.py` measures documentation by declaration
identity, independently of GNATdoc's warnings. Its inventory comes from the
visible part of `src/*.ads`: the package description; every declaration,
identified by kind, name and, for subprograms, the complete normalized
profile, so each overload is a separate item; every parameter and every
function's return value; every enumeration literal; every record component
and discriminant. It reads the native section of that exact declaration and
requires:

- the members GNATdoc lists to be exactly the source members, in order;
- non-trivial text for each item: at least two words, not merely its name,
  so an empty `@param` or a copied identifier does not count;
- every visible-part comment block to be attached: immediately preceding
  the package or a declaration, or the first block inside the package
  followed by a blank line (the package-description layout GNATformat
  accepts), and every line of it to render inside that description or
  declaration section. Detached, trailing and markup-mangled comments fail.

Undocumented items are ratcheted in `docs/gnatdoc-coverage-baseline.txt`
exactly like warnings (`--fail-on-removed`, `--write-baseline`);
attachment errors and member mismatches can never be baselined.
`generate_docs.sh` runs the check after validation; `--report` prints
coverage by item kind.

### Current status: zero warnings, complete coverage

Since IMGPROC-DOC-002G, GNATdoc reports zero warnings and all 1,512 items
are documented: the package description, 314 declarations (184 subprograms,
99 types, 25 subtypes, 6 constants), 745 parameters, 114 return values, 256
enumeration literals and 82 components and discriminants. Both baselines are
empty and `generate_docs.sh` fails if either records an identity again, so a
new public declaration must be documented completely in the same change.
Neither the zero count nor full coverage proves that every statement is
correct; the per-phase records in the campaign progress file list
corrections made against the body and shim, statements that rest on OpenCV
conventions rather than repository tests, and suspected defects found.

`scripts/check_comment_only.py REVISION` proves that a documentation change
altered only comments: every Ada source under `src/` must have the same
tokens as at `REVISION` once comments and layout are removed, with string
and character literals kept. It qualifies documentation pull requests; it is
not a CI gate, because feature work legitimately changes declarations.

## Landing-page example

The example on `docs/index.html` is `docs/example.adb`, compiled with
assertions and warnings as errors and executed in documentation CI:

```sh
alr exec -- gprbuild -P docs/example.gpr
obj/docs-example/example
```

## Developer guides (IMGPROC-DOC-005)

Five guides in `docs/guides/` are rendered into `_site/guides/` by
`scripts/render_gnatdoc_guides.py`, adapted from Core's DOC-072 renderer:

| Guide | Covers |
| --- | --- |
| `filtering-and-transforms.md` | Destination models, smoothing, derivatives, kernels, pyramids, resizing, warps, remapping |
| `color-and-image-representation.md` | Mat depths and channels, shallow copies and Regions, color conversion, YUV, Bayer, color maps |
| `features-and-structural-analysis.md` | Edges, corners, subpixel refinement, Hough detection, histograms, integral images, accumulation, EMD |
| `segmentation-contours-and-morphology.md` | Thresholds, morphology, distances, flood fill, watershed, GrabCut, contours, components, drawing |
| `template-matching-and-registration.md` | The six matching methods, masked matching and zero-energy policies, generalized Hough, phase correlation |

The renderer uses the pinned `markdown-it-py` (`docs/requirements.txt`, run
through `DOC_PYTHON`) and enforces a narrower contract than Markdown: no raw
HTML or images; fences only in `ada`, `sh` or `text`; links only to guide
headings, other guides, `https` pages on github.com and zackboll.github.io,
or `api:Name` and `api:Name/N`. An `api:` link resolves to the verified
native anchor of that declaration (overload N in source order) taken from
the operation browser's entries; an unknown name or overload fails. Every
`ada` fence must be exactly one program from `docs/examples/`, and every
example must appear in a guide. `docs/examples/examples.gpr` compiles the
five examples with `-gnat2022 -gnata -gnatwa -Werror` and the workflow runs
them, so every Ada statement shown in a guide is compiled and its assertions
are executed. Each guide page also lists native API entry points and links
to its Markdown source.

Validation reconstructs every guide page and the guide stylesheet and
compares bytes; the landing page must link to all five guides.
`test_gnatdoc_guides.py` rejects missing or extra pages, wrong but existing
API anchors and guide links, missing headings, changed code or text,
scripts, a tampered stylesheet, unknown declarations or overloads, Ada code
that is not a compiled example, examples missing from the guides, unapproved
links and raw HTML. The optional `scripts/test_gnatdoc_guides_browser.cjs`
checks all five guides at 1280 and 390 pixels, light and dark, with and
without JavaScript: navigation state, source links, absence of page overflow,
scrollable code and tables, API links landing on the named declaration,
cross-guide links, keyboard focus and the skip link.

## CI and Pages review gate

`.github/workflows/documentation.yml` runs for every pull request
(including stacked documentation PRs whose base is another branch), pushes
to `main` and manual dispatch. It checks out exact Imgproc head and the immutable
indexed Core source witness; production builds use the Alire-resolved dependency.
Pull-request jobs have read-only contents/artifact/deployment access: they test the tooling, generate and validate the
site, repeat the validator mutations on the generated site, regenerate to
prove byte-identical output, compile and run the example, and upload the site
and `gnatdoc.log` as review artifacts. They never configure or deploy Pages.

Only `refs/heads/main` runs upload a Pages artifact. A separate job that
depends on the successful build deploys it with `pages: write`,
`id-token: write` and the `github-pages` environment. Superseded runs are
cancelled. Manual runs on other branches validate but cannot publish. No PAT
or `gh-pages` branch is used. Pages must be configured once by a repository
administrator: **Settings → Pages → Build and deployment → Source: GitHub
Actions**, with the `github-pages` environment restricted to `main`. Until
then the `main` run fails at `Configure Pages` and publishes nothing.

## Comment convention

Use adjacent **leading** `--` comments: GNATdoc runs with `--style leading`,
and a blank line between a comment and its declaration detaches the comment.
A comment placed after a declaration documents the *next* declaration, so
existing trailing comments must be moved when their declaration is
documented. Use `@param`, `@return` and `@exception` with names matching the
actual declaration; tag text may continue on the following comment lines.
In GNATdoc 26.0.0, enumeration literals are documented in the type's leading
block with `@enum` (`@value` is not recognized) and record components,
including discriminants and variant components, with `@field`. Write
`@exception OpenCV_Error`: GNATdoc splits a dotted name such as
`OpenCV.OpenCV_Error` at the dot. The package description is the first
comment block inside the package, followed by a blank line; GNATformat
inserts a blank line between a comment and `package`, which would detach a
leading package comment. For example:

```ada
--  Blurs Source with an isotropic Gaussian kernel.
--  @param Source Nonempty 2-D Mat, borrowed and not modified.
--  @param Destination Receives a Mat of Source's geometry and type.
--  @exception OpenCV_Error Invalid input or an OpenCV failure.
procedure Gaussian_Blur
  (Source      : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat; ...
```

Comments are rendered as Markdown-like text. A pair of `*` characters
becomes emphasis, so a formula such as `A*B + C*D` written in prose loses
both asterisks; backslash escapes are not supported. Put formulas in a
backtick code span (`` `(1 - W) * B + W * S` ``), or in an indented block: a
bare `--` line, lines with at least five spaces after `--`, then a bare `--`
line. Lines starting with `- ` or `* ` form bullet lists and a bare `--` line
separates paragraphs.

Describe purpose, depth and channel restrictions, geometry, parameter ranges,
result representation, ownership and aliasing, Regions, masks, exceptions and
meaningful numerical or OpenCV-version limitations, from the specification,
implementation, tests and reviewed source research rather than from the C++
name. A zero warning count is not proof of accuracy. Do not change
declarations or behavior to improve generated output.

## Testing the documentation tooling

### Linked, syntax-highlighted Ada examples (IMGPROC-DOC-EXAMPLES-001)

`scripts/render_gnatdoc_examples.py` is the reusable example renderer. The
landing template has one `<!-- compiled Ada example -->` marker, replaced from
`docs/example.adb`; no manually maintained HTML copy of that program exists.
The Markdown renderer delegates only `ada` fences to the helper. Shell and text
fences retain the pinned Markdown renderer's original output. Every guide Ada
fence must still equal exactly one program in `docs/examples/`, including its
final newline, and every program must occur in a guide. Neither `.adb` sources
nor their behavior is changed for presentation.

The helper reuses `highlight_gnatdoc_ada.py`: keywords, comments, strings,
character literals, numbers, attributes and operators receive the existing
theme classes. HTML is escaped before coloring. Existing type anchors remain
atomic, so tag names and attributes cannot be highlighted. Stripping the exact
approved spans and anchors and decoding entities must recover the full source,
including indentation, spelling, whitespace and final newline. The native
declaration highlighter/linker and its integrity manifest are unchanged.

Links are not word replacements. A deliberately bounded resolver recognizes
object type marks, `use [all] type` references, local subtype bases, conversions
and qualifications. It reads the actual public specifications and considers
explicit initial `with`/`use` clauses, case-insensitively. All local defining
names conservatively shadow throughout an example, even outside a nested block;
this can omit a safe link but cannot authorize one from a shadowed name.
Multiple visible declarations, unknown use contexts, unsupported aliases,
nested packages/subprograms, generic/task/record scopes and malformed tokens
remain unlinked. Standard types also remain plain. Unsupported examples still
receive coloring; this is not a complete Ada semantic front end.

Comments and literals are atomic lexical tokens, never type candidates.
Variables, procedure/function calls, record selectors and named associations
are not inferred to be types. A conversion-looking name receives a link only
if its unique visible declaration really is a public type or subtype. Private
and internal declarations are excluded from the source inventory.

Imgproc destinations are discovered from source-matched native GNATdoc type
sections in the generated package page: no filename or anchor hash is computed.
Core identities are independently checked against the resolved build dependency's
visible specifications. The eight verified stable symbols in `CORE_SYMBOLS`
use qualified `https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=...`
bookmarks. Other source-confirmed Core types fall back to the verified package
bookmark rather than an invented declaration destination. The current examples
use seven of those symbols; `OpenCV.Size` is additionally exercised synthetically.

Core's public contract was inspected at commit
`aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d` (`docs/documentation.md`,
`scripts/enhance_gnatdoc_navigation.py`, and `docs/assets/gnatdoc-navigation.js`)
and in the published hidden symbol index. Symbol routing needs Core's existing
JavaScript; with JavaScript disabled its native package/sidebar links remain
functional, but the query does not automatically select a declaration. Coloring
and example links themselves never need JavaScript. Browser tests explicitly
exercise this honest native-navigation fallback rather than claiming no-JS
symbol routing. They can use the exact successful Core Documentation artifact
via `CORE_DOC_SITE`, preserving the published URL/origin through Playwright
request fulfillment; without it they use the real published site, never a stub.

The final validator reconstructs every guide **and the complete landing page**
from authoritative inputs and compares exact bytes. A generated manifest cannot
authorize a different link, changed source, extra attribute or missing example.
All local fragments are independently resolved. Mutation tests in
`scripts/test_gnatdoc_examples.py` cover wrong existing type/operation anchors,
Core identity substitution, links in comments/literals, changed/dropped/duplicated
tokens, missing/duplicated examples, malformed nesting, scripts/handlers and
unsafe URLs. Existing validation, warning and coverage ratchets remain required.
Fresh generation and repeated enhancement must be byte-identical.

Code uses the existing light/dark palette and type-reference visual language,
with underlining, hover/focus feedback and a visible keyboard outline. Labelled,
focusable code regions scroll horizontally without widening the document.
The Playwright guide suite covers the landing example and every guide at
1280px/390px, light/dark, JavaScript enabled/disabled, exact native type targets,
Core public symbol navigation, keyboard activation and Back/Forward. This is
Linux/Chromium qualification, not a blanket accessibility or cross-browser claim.

For future guides, add the complete compiled program and its exactly matching
Ada fence, register/build/run it through the existing guide workflow, and extend
the browser inventory. No colored HTML belongs in `.adb` files. If a new Core
type needs a declaration bookmark, independently verify its published symbol
contract and native identity before extending `CORE_SYMBOLS`; otherwise keep
the package fallback. The helper's source/context/renderer separation is suitable
for later reuse in Core, Geometry, Features or the shared enhancer. R2 preserves
this renderer rather than substituting the toolkit's authored renderer. Reviewed
shared facilities were `syntax.py`, `guides.py` and the stable-bookmark contract
at enhancer `65c29b3a1154c54f2fbb3e112bec48598c751c8a`; the historical shadow
authority and qualification evidence remain frozen.

```sh
sh scripts/generate_docs.sh
export DOC_PYTHON="$PWD/.doc-tools/enhancer-0.1.1/bin/python"
export DOC_CORE_SOURCE=$(alr exec -- printenv OPENCV_CORE_ALIRE_PREFIX)
"$DOC_PYTHON" scripts/review_legacy_docs.py --native obj/docs/native \
  --output /tmp/imgproc-legacy-review --core "$DOC_CORE_SOURCE"
export DOC_LEGACY_ORACLE=/tmp/imgproc-legacy-review
"$DOC_PYTHON" -m unittest discover -s scripts -p 'test_*.py' -v
python3 scripts/check_doc_coverage.py --report docs/gnatdoc-coverage-baseline.txt _site
python3 scripts/check_comment_only.py origin/main   # documentation-only changes
alr exec -- gnatformat --check -P opencv_imgproc.gpr src/opencv-image_processing.ads
alr exec -- gprbuild -P docs/example.gpr && obj/docs-example/example
alr exec -- gprbuild -P docs/examples/examples.gpr   # then run obj/docs-examples/*
git diff --check
```

The released enhancer, pinned guide renderer (`markdown-it-py==3.0.0` and
`mdurl==0.1.2`) and independent consumer scripts are documentation-only. None of them, nor
the optional Playwright harnesses, is a dependency of the library or the
`tests` crate.

## GNATDOC-009R2: released production candidate

**Qualification blocker:** the fresh hosted community index now selects Core
0.5.2 for the unchanged `~0.5.0` manifest, whereas this campaign explicitly
requires source-authorized 0.5.0. The new identity gate rejects this rather than
silently authorizing a dependency. See `docs/evidence/gnatdoc009/r2/BLOCKER.md`.
The migration is not ready for merge; local cached-0.5.0 success is not a fresh
hosted qualification. Do not bypass the gate with a pin or rewrite old evidence.

`scripts/install_released_gnatdoc.py` acquires only the official HTTPS v0.1.1
wheel, checks its complete inventory and SHA-256
`8b896683a65623a7e7d626701a4cd68c8b89cb65792f9ffd5525bfa8cfa257ab`,
independently fetches annotated tag `6d3bc1167179ec7cb90c2a6bdf91050b6057f6b4`,
commit `dd100f026e13cdd9e97b283d50130241d71bdb9d`, tree
`2873e5f7e0c200ec24a6706610d3bc0527303a7d`, and compares every packaged module
and asset with tagged source. It checks exact installed bytes, distribution
metadata, non-editable origin, launcher, CLI version, release provenance and
checksum receipt before execution. Optional Markdown wheels are independently
hash-checked. No development checkout, rebuilt wheel or toolkit patch is used.

`generate_docs.sh` builds the indexed library, generates pristine public native
output under `obj/docs/native`, enforces zero warnings, and source-matches its
declarations before enhancement. `assemble_shared_docs.py` stages only the API,
rechecks the installed release, runs `inventory`, `enhance`, and independent
`verify`, then invokes the consumer source/native oracle. The API-only toolkit
verification **does not qualify authored pages**. The original PR #80 example
renderer separately assembles the landing page and all five guides, preserving
source text, whitespace, final newlines and lexical reconstruction. Consumer
full-site validation reconstructs those pages and assets, checks their links,
security and complete inventory, and rechecks actual files before upload.

The explicit opt-in candidate TOML is `docs/gnatdoc-enhancer.toml`:

```toml
[presentation]
theme = true
syntax_highlighting = true
type_links = true
external_type_target = "_top"
```

API Core type links use genuine native declaration fragments and replace the
top-level browser URL. Local Imgproc links remain local. Authored examples keep
their separately source-qualified `?symbol=` Core destinations and honest no-JS
native-package fallback. Generic-instance navigation is not reauthorized by
this API policy. No JavaScript navigation workaround or arbitrary rewriting is
permitted.

The indexed Core authority is 0.5.0 source
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`; it is distinct from the mutable
Core publication. R2 pins deployment `7348179998`, source
`33a2a4f3b83606a5c779b8a93abeb6c91fa49a21`, tree
`454fb0fa3a128e638a1d7d85f345c7904f296877`, run `40433988181`, review artifact
`12702919800`, and Pages artifact `12703258126`. `qualify_current_core.py`
compares all 209 hosted files, artifact equality, and all 14 referenced exact
source/native declarations before and after browser qualification. A changed
deployment requires renewed comparison; live bytes cannot authorize themselves.

Acceptance remains one package, 329 declarations and source-order operation
destinations, 1,596/1,596 documented elements, zero warnings, 586 Core occurrences
across 14 identities, 350 local links, and six compiled/executed examples.
The two extra local links are `Background_Label` → `Component_Label` and
`Default_Morphology_Border` → the public `Morphology_Border_Value` view.
All 348 original local links are retained. Authored code retains 55 links
(eight Imgproc, 47 Core); no API count substitutes for that separate proof.

`review_legacy_docs.py` is the documented, separately invoked oracle from the
same pristine input, not a second production generator.
`compare_production_docs.py` classifies every file. Historical assets and
postprocessors remain for comparison only. The authored stylesheet restores
consumer-owned focus/layout rules absent from the toolkit API theme without
modifying released assets. Browser qualification uses actual project-prefix
Chromium, 1280px/390px, light/dark and JS on/off, source-order destinations,
local links, actual live HTTPS top-level Core navigation, reload and history,
and all authored examples. This is not a claim of other-browser accessibility.

R1 and GNATDOC-008/008C evidence stays frozen. Historical shadow qualification
runs against its own historical source and enhancer identities, never current
API hashes. Release-browser compatibility is not production-policy approval.
R2's additive policy proposal remains **subject to independent merge review**;
R1's `policy_approved: false` is unchanged. Current evidence and remaining gates
are in `docs/evidence/gnatdoc009/r2/`.

PRs qualify candidate artifacts but never deploy Pages. Main-only `verify-live`
reconstructs the exact deployed source using the official wheel, compares both
same-run artifacts, independently checks public HTTPS, and runs authored browser
tests. To roll back, normally revert the migration commit(s) and let the normal
main build/deploy/live-verification chain run; never overwrite artifacts or
weaken provenance checks. A Core publication mismatch blocks acceptance pending
an explicit renewed source/native/artifact comparison and independent review.
