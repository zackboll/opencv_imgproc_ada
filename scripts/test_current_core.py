"""R2 immutable Core artifact authorization and archive safety controls."""
import io
import unittest
import zipfile
from unittest.mock import patch

import qualify_current_core as core


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

    def test_wrong_source_same_deployment_rejected(self):
        with patch.object(core, 'api', return_value=[{'id': core.DEPLOYMENT, 'sha': '0' * 40}]):
            with self.assertRaisesRegex(ValueError, 'renewed comparison required'):
                core.provenance()


if __name__ == '__main__':
    unittest.main()