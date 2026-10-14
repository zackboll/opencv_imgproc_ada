# Public Ada API documentation

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
C++17 compiler, a POSIX shell and Python 3.9 or newer (standard library only).
`alire.toml` resolves `opencv_core` from the sibling checkout `../core`, so
use the layout described in the README:

```sh
git clone https://github.com/zackboll/opencv_core_ada.git core
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
  --backend html --generate public --style leading --warnings -O "$PWD/_site/api"
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

- The site contains exactly `index.html`, `api/index.html`, `api/gnatdoc.css`
  and one native page per public package. GNATdoc 26.0.0 names package pages
  with 64-hex hashes; pages are identified by their actual `<h1>`, never by a
  computed filename. Any other file, an internal or Core package page, or a
  missing public package fails.
- `api/index.html` must equal the pinned GNATdoc 26.0.0 serialization rebuilt
  from the discovered pages, including every `target=document-content`.
- Every visible-part declaration has exactly one native `h4` section of the
  same kind. Subprogram sections must reproduce the complete normalized
  profile, so removing, adding or altering one overload fails, and private-part
  declarations must not appear. Selected overloads must render their own
  comments in their own section.
- Links must be relative and resolve inside the site, including fragments.
  API pages have no external links; the landing page may link only to the
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

## CI and Pages review gate

`.github/workflows/documentation.yml` runs for every pull request
(including stacked documentation PRs whose base is another branch), pushes
to `main` and manual dispatch. It checks out Imgproc and Core
`main` side by side, as the cross-platform workflow does. Pull-request runs
have only `contents: read`: they test the tooling, generate and validate the
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

```sh
python3 -m unittest discover -s scripts -p 'test_*.py' -v
sh scripts/generate_docs.sh
python3 -m unittest discover -s scripts -p 'test_validate_docs.py' -v
python3 -m unittest discover -s scripts -p 'test_check_doc_coverage.py' -v
python3 scripts/check_doc_coverage.py --report docs/gnatdoc-coverage-baseline.txt _site
python3 scripts/check_comment_only.py origin/main   # documentation-only changes
alr exec -- gnatformat --check -P opencv_imgproc.gpr src/opencv-image_processing.ads
alr exec -- gprbuild -P docs/example.gpr && obj/docs-example/example
git diff --check
```

The documentation tools use only the Python standard library and are not
dependencies of the library or the `tests` crate.
