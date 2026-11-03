#!/usr/bin/env python3
"""Example visibility, text fidelity and adversarial publication mutations."""
import html
import re
import shutil
import tempfile
import unittest
from pathlib import Path

from highlight_gnatdoc_ada import strip_highlighting
from link_gnatdoc_types import CORE_ROOT, CORE_SITE, LINK, plain
from render_gnatdoc_examples import BLOCK, ExampleRenderer, lex
from validate_docs import DocumentationError, ROOT, validate


@unittest.skipUnless((ROOT / '_site/api/presentation.json').is_file(),
                     'requires generated site')
class Examples(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.renderer = ExampleRenderer(ROOT / '_site', ROOT)

    def program(self, body, context='use OpenCV.Core; use OpenCV.Image_Processing;'):
        return ('with OpenCV.Core; with OpenCV.Image_Processing;\n'
                'procedure Demo is\n' + context + '\n' + body + '\nend Demo;\n')

    def identities(self, source):
        return [(source[a:b], identity) for a, b, identity in self.renderer.references(source)]

    def test_all_six_examples_round_trip_and_have_links(self):
        paths = [ROOT / 'docs/example.adb', *sorted((ROOT / 'docs/examples').glob('*.adb'))]
        self.assertEqual(len(paths), 6)
        for path in paths:
            with self.subTest(path=path.name):
                source = path.read_text(encoding='utf-8')
                rendered = self.renderer.render(source)
                content = BLOCK.fullmatch(rendered)[1]
                self.assertEqual(html.unescape(plain(strip_highlighting(content))), source)
                self.assertTrue(LINK.search(content))

    def test_type_contexts_case_and_qualified_size(self):
        text = self.program('A : mAt; B : OpenCV.Size; C : Component_Statistics;\n'
                            'subtype Local is OpenCV.Size_Coordinate;\n'
                            'begin A := Mat (A); C := Component_Statistics\'(C);')
        self.assertEqual([label for label, _ in self.identities(text)],
                         ['mAt', 'OpenCV.Size', 'Component_Statistics',
                          'OpenCV.Size_Coordinate', 'Mat', 'Component_Statistics'])

    def test_comments_strings_characters_variables_calls_and_selectors_are_plain(self):
        source = self.program('A : Mat; Text : String := "Mat ""Component_Statistics""";\n'
                               "C : Character := 'M';\n"
                               '-- Mat Component_Statistics\n'
                               'begin A.Mat; A.Component_Statistics (A);\n'
                               'Mat_Name := 1; Gaussian_Blur (A, A);')
        self.assertEqual(self.identities(source), [('Mat', 'opencv.core.mat')])

    def test_local_shadowing_is_conservative_even_outside_nested_scope(self):
        for declaration in ('Mat : Integer;', 'subtype Mat is Integer;',
                            'procedure Mat is begin null; end Mat;',
                            'package Mat renames OpenCV.Core;',
                            'for Mat in 1 .. 2 loop null; end loop;'):
            with self.subTest(declaration=declaration):
                source = self.program('A : Mat; begin declare ' + declaration +
                                      ' begin null; end;')
                self.assertNotIn('Mat', [label for label, _ in self.identities(source)])

    def test_missing_use_unknown_use_and_alias_context_remain_plain(self):
        for context in ('', 'use Other;', 'use OpenCV.Core; use Other;',
                        'package C renames OpenCV.Core; use C;'):
            self.assertEqual(self.identities(self.program('A : Mat; begin null;', context)), [])

    def test_verified_core_package_fallback_and_private_names(self):
        source = self.program('A : OpenCV.Core.Depth_Type; B : OpenCV.Core.Absent;\n'
                              'begin null;')
        rendered = self.renderer.render(source)
        links = list(LINK.finditer(BLOCK.fullmatch(rendered)[1]))
        self.assertEqual([(m[1], m[2]) for m in links],
                         [(CORE_SITE + '?package=OpenCV.Core', 'opencv.core.depth_type')])

    def test_stale_imgproc_and_core_source_identities_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copytree(ROOT / 'src', root / 'src')
            spec = root / 'src/opencv-image_processing.ads'
            original = spec.read_text(encoding='utf-8')
            spec.write_text(original.replace('type Component_Statistics is',
                                              'type Renamed_Statistics is', 1), encoding='utf-8')
            with self.assertRaises(ValueError):
                ExampleRenderer(ROOT / '_site', root)
            spec.write_text(original, encoding='utf-8')
            core = root / 'core'
            (core / 'src').mkdir(parents=True)
            for filename in ('opencv.ads', 'opencv-core.ads'):
                shutil.copy(CORE_ROOT / 'src' / filename, core / 'src' / filename)
            spec = core / 'src/opencv.ads'
            spec.write_text(spec.read_text(encoding='utf-8').replace('UInt8_Value', 'Other_Value'),
                            encoding='utf-8')
            with self.assertRaises(ValueError):
                ExampleRenderer(ROOT / '_site', root, core)

    def test_non_ada_fences_are_byte_unchanged(self):
        from render_gnatdoc_guides import markdown
        source = '# Demo\n\n```sh\necho "Mat <Ada> &"\n```\n\n```text\nMat\n```\n'
        self.assertEqual(markdown(source)[0], markdown(source, examples=self.renderer)[0])

    def test_homographs_and_non_type_declarations_are_not_types(self):
        self.assertEqual(self.identities('with Other.Mat; ' + self.program(
            'A : Mat; begin null;')), [])
        renderer = self.renderer
        old = renderer.names['opencv.image_processing'].get('mat')
        try:
            renderer.names['opencv.image_processing']['mat'] = [
                {'scope': 'OpenCV.Image_Processing.Mat', 'signature': 'function Mat return Integer'}]
            self.assertEqual(self.identities(self.program('A : Mat; begin null;')), [])
        finally:
            if old is None:
                del renderer.names['opencv.image_processing']['mat']
            else:
                renderer.names['opencv.image_processing']['mat'] = old

    def test_malformed_tokens_disable_links_but_not_safe_coloring(self):
        for malformed in ('Mat__', '_Mat', '1Mat', '"Mat', "'", 'Mat!'):
            text = self.program('A : Mat; B : ' + malformed + '; begin null;')
            self.assertIsNone(lex(text))
            rendered = self.renderer.render(text)
            self.assertNotIn('type-reference', rendered)

    def test_all_highlighting_categories_entities_and_whitespace(self):
        source = self.program('A : Mat;\n\t-- <Mat> & "Mat"\n'
                              'S : String := "<Mat> & ""Ada"""; C : Character := \'A\';\n'
                              "begin X := A'Length + 16#FF#; X := X / 2;", '')
        rendered = self.renderer.render(source)
        for category in ('keyword', 'comment', 'string', 'character', 'number', 'attribute', 'operator'):
            self.assertIn('class="ada-' + category + '"', rendered)
        content = BLOCK.fullmatch(rendered)[1]
        self.assertEqual(html.unescape(plain(strip_highlighting(content))), source)
        self.assertIn('&lt;Mat&gt; &amp;', content)


@unittest.skipUnless((ROOT / '_site/guides').is_dir(), 'requires generated site')
class ExampleMutations(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.site = Path(self.tmp.name) / 'site'
        shutil.copytree(ROOT / '_site', self.site)

    def reject(self, relative, transform):
        path = self.site / relative
        original = path.read_text(encoding='utf-8')
        changed = transform(original)
        self.assertNotEqual(original, changed, 'mutation did not apply')
        path.write_text(changed, encoding='utf-8')
        with self.assertRaises(DocumentationError):
            validate(self.site, ROOT)
        path.write_text(original, encoding='utf-8')

    def test_every_example_missing_modified_or_duplicated_is_rejected(self):
        for relative in ['index.html', *['guides/' + p.name for p in
                                         sorted((self.site / 'guides').glob('*.html'))]]:
            for transform in (lambda s: BLOCK.sub('', s),
                              lambda s: BLOCK.sub(lambda m: m[0] + m[0], s),
                              lambda s: s.replace('ada-number">1', 'ada-number">9', 1)):
                with self.subTest(relative=relative, transform=transform):
                    self.reject(relative, transform)

    def test_wrong_existing_type_and_unrelated_operation_anchors_are_rejected(self):
        native = next(p for p in (self.site / 'api').glob('*.html') if p.name != 'index.html')
        text = native.read_text(encoding='utf-8')
        for name in ('Histogram', 'Gaussian_Blur'):
            anchor = re.search(r'<h4 id=([^ >]+)>' + name + '</h4>', text)[1]
            self.reject('guides/segmentation-contours-and-morphology.html',
                        lambda s: re.sub(r'(<a class="type-reference" href="../api/[^#]+#)[^"]+',
                                         lambda m: m[1] + anchor, s, count=1))

    def test_changed_core_identity_and_unsafe_urls_are_rejected(self):
        for url in ('https://example.com/', 'javascript:alert(1)',
                    'https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=OpenCV.Size',
                    'https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=OpenCV.Core.Clone'):
            self.reject('index.html', lambda s: s.replace(
                'https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=OpenCV.Core.Mat', url, 1))
        self.reject('index.html', lambda s: s.replace('data-type="opencv.core.mat"',
                                                    'data-type="opencv.size"', 1))

    def test_links_inside_comments_and_strings_are_rejected(self):
        relative = 'guides/color-and-image-representation.html'
        text = (self.site / relative).read_text(encoding='utf-8')
        link = LINK.search(BLOCK.search(text)[1])[0]
        # Mutation changes markup only, not the Ada text.
        self.reject(relative, lambda s: s.replace('Region is a view',
                    link.replace(LINK.fullmatch(link)[3], 'Region') + ' is a view', 1))
        # The authoritative examples contain no string literals outside comments;
        # add a synthetic authored string fixture and reconstruct it independently.
        renderer = ExampleRenderer(self.site, ROOT)
        source = 'with OpenCV.Core; procedure Demo is S : String := "Mat"; begin null; end Demo;'
        rendered = renderer.render(source)
        self.assertNotIn('type-reference', rendered)
        changed = rendered.replace('"Mat"', '"' + link.replace(LINK.fullmatch(link)[3], 'Mat') + '"')
        self.assertNotEqual(changed, renderer.render(source))
        with self.assertRaises(ValueError):
            renderer.verify(source, changed)

    def test_dropped_duplicated_tokens_nested_and_unsafe_markup_are_rejected(self):
        for old, new in (
                ('ada-keyword">with</span>', 'ada-keyword">With</span>'),
                ('ada-keyword">with</span>', 'ada-keyword"></span>'),
                ('ada-keyword">with</span>', 'ada-keyword">with with</span>'),
                ('ada-keyword">with</span>', 'ada-keyword"><b>with</span></b>'),
                ('<span class="ada-keyword">', '<span onclick="alert(1)" class="ada-keyword">'),
                ('<span class="ada-keyword">', '<script>alert(1)</script><span class="ada-keyword">')):
            self.reject('index.html', lambda s: s.replace(old, new, 1))


if __name__ == '__main__':
    unittest.main()