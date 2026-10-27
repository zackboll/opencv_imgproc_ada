"""R2 immutable Core artifact authorization and archive safety controls."""
import io
from pathlib import Path
import shutil
import tempfile
import unittest
import zipfile
from unittest.mock import patch

import qualify_current_core as core
from core_source_authority import ROOT, authority
from qualify_production_core_links import source_native_types


class CoreArchive(unittest.TestCase):
    def test_digest_cannot_be_authorized_by_archive(self):
        with self.assertRaisesRegex(ValueError, 'digest differs'):
            core.review_members(b'forged')

    def test_complete_member_inventory_required(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            archive.writestr('index.html', 'untrusted')
        with patch.object(core, 'REVIEW_SHA', core.digest(data.getvalue())):
            with self.assertRaisesRegex(ValueError, 'inventory changed'):
                core.review_members(data.getvalue())

    def test_changed_deployment_never_inherits_approval(self):
        with patch.object(core, 'api', return_value=[{'id': 1, 'sha': core.SOURCE}]):
            with self.assertRaisesRegex(ValueError, 'renewed comparison required'):
                core.provenance()


class ReferencedDeclarationMutations(unittest.TestCase):
    def test_wrong_owner_private_ambiguous_and_modified_complete_declaration(self):
        approved = authority()
        wanted = approved['types']
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'src').mkdir()
            native = root / 'native'
            (native / 'api').mkdir(parents=True)
            # Use independently source-proven profiles to create the deliberately
            # small parser mutation fixture. Final qualification uses authentic
            # GNATdoc, never this fixture as native authority.
            from link_gnatdoc_types import CORE_ROOT
            for name in ('opencv.ads', 'opencv-core.ads'):
                shutil.copyfile(CORE_ROOT / 'src' / name, root / 'src' / name)
            import html
            for owner in ('opencv', 'opencv.core'):
                members = [p for p in wanted.values() if p['owner'] == owner]
                page = native / members[0]['native_page']
                page.write_text('<h1>' + members[0]['identity'].rpartition('.')[0] + '</h1>' + ''.join(
                    '<h4 id=' + p['native_anchor'] + '>' + p['identity'].rpartition('.')[2] +
                    '</h4><pre class=ada-code-snippet><code>' +
                    html.escape(p['native_snippet'], quote=False) + '</code></pre>' for p in members))
            source_native_types(root, native, wanted)
            mat = wanted['opencv.core.mat']
            page = native / mat['native_page']
            original = page.read_text()
            for before, after in (
                ('<h1>OpenCV.Core</h1>', '<h1>OpenCV</h1>'),
                ('>Mat</h4>', '>Scalar</h4>'),
                (html.escape(mat['native_snippet'], quote=False), 'type Mat is new Natural;'),
                ('</h1>', '</h1><h4 id=' + mat['native_anchor'] + '>Mat</h4>' +
                 '<pre class=ada-code-snippet><code>' + html.escape(mat['native_snippet'], quote=False) + '</code></pre>')):
                with self.subTest(mutation=before):
                    page.write_text(original.replace(before, after, 1))
                    with self.assertRaises(ValueError):
                        source_native_types(root, native, wanted)
                    page.write_text(original)
            specification = root / mat['source_file']
            text = specification.read_text()
            for replacement in ('type Mat is new Natural;', 'type Mat is private;\n   type Mat is private;'):
                with self.subTest(replacement=replacement):
                    specification.write_text(text.replace(mat['source_declaration_text'], replacement, 1))
                    with self.assertRaises(ValueError):
                        source_native_types(root, native, wanted)
                    specification.write_text(text)

    def test_wrong_source_same_deployment_rejected(self):
        with patch.object(core, 'api', return_value=[{'id': core.DEPLOYMENT, 'sha': '0' * 40}]):
            with self.assertRaisesRegex(ValueError, 'renewed comparison required'):
                core.provenance()


if __name__ == '__main__':
    unittest.main()