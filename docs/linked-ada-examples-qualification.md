# IMGPROC-DOC-EXAMPLES-001 qualification

Documentation-only branch: `docs/linked-ada-examples`. Starting `origin/main`
commit `496d5d074c9bc987f625d484deb45bcdad174aa0`, tree
`4745352fc3bba1c7bd10a21d0fbcef560aafe7fc`. No open PRs were present at
acquisition. DOC-003 presentation (#60), DOC-004 navigation (#61) and DOC-005
guides (#62) were already merged. The historical campaign and shared-enhancer
shadow records are not rewritten by this task.

The final tested/pushed commit and hosted CI run belong in the PR, rather than
a self-referential commit field in this file.

## Inputs and scope

- Existing Alire 2.1.1, GNAT 16.1.0, GPRbuild Alire 26.0.1 / executable
  26.0.0, GNATdoc 26.0.0 (20260415), Markdown 3.0.0 / mdurl 0.1.2.
- Core source identity is the build-resolved indexed Core 0.5.0
  (`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`), not an adjacent development
  checkout. No dependency or Alire index changes.
- Core bookmark implementation/contract inspected at
  `aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d`; successful hosted Documentation
  run [39361137547](https://github.com/zackboll/opencv_core_ada/actions/runs/39361137547).
  Its exact-head `ada-api-aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d` artifact
  supplies real Core HTML/CSS/JavaScript for local browser qualification.
  Playwright serves those bytes at the published cross-origin URLs, not stub
  pages. The live published symbol index was independently inspected too.
- Shared enhancer `65c29b3a1154c54f2fbb3e112bec48598c751c8a` reviewed for
  reusable lexical, source/native target and guide reconstruction facilities.
  No enhancer upgrade, production migration or edits to another repository.
- Production source, API/ABI, Alire manifests, compiled example sources and
  frozen shadow authority/evidence have no diff from the starting commit.

## Six rendered and compiled examples

| Page / program | Imgproc links | Core links | Source round trip | Compile/run |
| --- | ---: | ---: | --- | --- |
| Landing / `example.adb` | 0 | 3 | Exact, including final newline | Pass |
| Filtering / `filtering_and_transforms.adb` | 0 | 8 | Exact | Pass |
| Color / `color_and_representation.adb` | 0 | 7 | Exact | Pass |
| Features / `features_and_analysis.adb` | 2 | 11 | Exact | Pass |
| Segmentation / `segmentation_and_contours.adb` | 5 | 6 | Exact | Pass |
| Matching / `matching_and_registration.adb` | 1 | 12 | Exact | Pass |

Total: **55 links**, eight Imgproc occurrences and 47 Core occurrences.
Every guide fence still matches exactly one compiled source file. All six
programs compile under their existing assertions/warnings-as-errors projects
and execute without changes.

## Observed native Imgproc type/subtype inventory

The package page observed from its actual `<h1>` is
`api/ad8b3be9bb56aa3f11561f0f1cb2bee4bf63f69bb56f01ea00bdc4a8c048172f.html`.
The renderer discovers these fragments from source-matched sections; this
record is evidence, not a generated-link configuration or hash recipe.

| Public `OpenCV.Image_Processing` identity | Observed fragment |
| --- | --- |
| `Component_Label` | `6455cdd6cf3116fe5cae2e9a6e41d67c6016255c8d18812c6794e34d0e51c93c` |
| `Component_Statistics` | `79107e078def6b4d491d8f52aeb40d91b009913167be82d9aa73c82d819fe397` |
| `Connected_Component_Set` | `54082d399e45861809a5539c5cfaadefe6c56050fe21b34ad315ba6cd622cc7a` |
| `Contour_Set` | `80a0e523fb64cffb14997c149c4bba3e6e85817a354f28869cdd5df0618d493c` |
| `Flood_Fill_Result` | `235324c526c06aa1ce7447a43beda3228db6da7790fc39d7c8a64da47d1adb4c` |
| `Histogram` | `9a28350b75a23a395566b30797a9a427684e474a92e5e84df7d6b313386818d4` |
| `Hough_Line_Array` | `0c66a2271707ca304bcb276cff3b6a1136bae365c2d87ae80d374c133935064a` |
| `Phase_Correlation_Result` | `ff103c4ac8ba873f10d2bf099c3e1a7d59bdcd4f4f759a7aa946a8eea0c0105e` |

## Core inventory and unresolved references

All destinations use
`https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=` followed
by the exact qualified identity:

| Identity | Occurrences |
| --- | ---: |
| `OpenCV.Core.Mat` | 30 |
| `OpenCV.Core.Min_Max_Result` | 4 |
| `OpenCV.UInt8_Value` | 5 |
| `OpenCV.Float32_Value` | 2 |
| `OpenCV.Float64_Value` | 3 |
| `OpenCV.Point_Coordinate` | 2 |
| `OpenCV.Size_Coordinate` | 1 |

`OpenCV.Size` is additionally source-checked and exercised in synthetic
resolver tests, but does not occur as a type reference in the six authoritative
programs. A synthetic `OpenCV.Core.Depth_Type` tests the verified package
fallback for types not in the inspected symbol subset.

No ambiguous public type reference occurs in the six programs. Standard
`Natural` stays plain; constants, enumeration literals, variables, selectors,
procedure/function names, comments and literals are intentionally not links.
Unsupported scopes and unknown/ambiguous visibility are tested negatively and
left unlinked rather than inferred. These are bounded rendering guarantees,
not a claim to implement complete Ada name resolution.

## Qualification and reproduction

Use the normal documentation environment, not new library dependencies:

```sh
export DOC_PYTHON=/path/to/qualified/markdown/bin/python
sh scripts/generate_docs.sh
"$DOC_PYTHON" -m unittest discover -s scripts -p 'test_gnatdoc_examples.py' -v
"$DOC_PYTHON" -m unittest discover -s scripts -p 'test_gnatdoc_guides.py' -v
"$DOC_PYTHON" -m unittest discover -s scripts -p 'test_validate_docs.py' -v
alr exec -- gprbuild -P docs/example.gpr
obj/docs-example/example
alr exec -- gprbuild -P docs/examples/examples.gpr
```

Run all five guide executables in `obj/docs-examples/`. The existing workflow
also retains warning comparison, coverage, native type-link and navigation
tests, fresh generation comparison and idempotent re-enhancement. Highlighting
covers all seven existing lexical categories, with synthetic literal/attribute
fixtures where a compiled example does not contain one. Shell/text fences are
compared unchanged. Mutation tests independently exercise exact generated-site
reconstruction and the renderer's strict equality verifier.

Local browser command (Playwright 1.64.1 / installed Chrome):

```sh
python3 -m http.server 18741 --bind 127.0.0.1 --directory _site
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright \
DOC_URL=http://127.0.0.1:18741/ CORE_DOC_SITE=/path/to/exact-core-artifact \
DOC_EVIDENCE=/path/to/screenshots node scripts/test_gnatdoc_guides_browser.cjs
```

The matrix covers landing + all five guides, every distinct example type
destination, desktop/mobile, light/dark, JavaScript enabled/disabled, keyboard
focus/activation, local scrolling, and history where supported. Core no-JS
fallback is explicitly native package/declaration navigation: outer symbol
query interpretation is not falsely claimed. Existing presentation/browser
tests are retained. The old optional operation-browser test needed its stale
314-count updated to the independently validated 329 and an explicit iframe
load wait before checking a reloaded declaration.

No public semantic validation is duplicated in the C++ shim. The shim is
unchanged. Proof and coverage-tool campaigns are not needed for documentation
rendering; native source/profile/anchor validation and documentation coverage
remain mandatory.