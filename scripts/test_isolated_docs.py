"""Opt-in real generator regression: no sibling Core checkout or symlink."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.environ.get('DOC_ISOLATED_TEST') == '1', 'requires full isolated generation campaign')
class IsolatedGeneration(unittest.TestCase):
    def test_indexed_dependency_without_sibling_core(self):
        with tempfile.TemporaryDirectory(prefix='imgproc-isolated-docs-') as tmp:
            parent = Path(tmp)
            root = parent / 'imgproc'
            subprocess.run(['git', 'clone', '--quiet', '--no-hardlinks', str(ROOT), str(root)],
                           check=True, timeout=120)
            # Include uncommitted integration only for local development. CI
            # checks clean exact-head source; no source identity is substituted.
            for directory in ('scripts', 'docs', '.github'):
                shutil.copytree(ROOT / directory, root / directory, dirs_exist_ok=True)
            self.assertFalse((parent / 'core').exists())
            environment = os.environ.copy()
            environment.pop('DOC_CORE_SOURCE', None)
            subprocess.run(['sh', str(root / 'scripts/generate_docs.sh')], cwd=root,
                           env=environment, check=True, timeout=900)
            self.assertFalse((parent / 'core').exists())
            self.assertEqual((root / '_site/index.html').read_bytes(), (ROOT / '_site/index.html').read_bytes())
            self.assertEqual({p.relative_to(root / '_site').as_posix(): p.read_bytes()
                              for p in (root / '_site').rglob('*') if p.is_file()},
                             {p.relative_to(ROOT / '_site').as_posix(): p.read_bytes()
                              for p in (ROOT / '_site').rglob('*') if p.is_file()})


if __name__ == '__main__':
    unittest.main()