#!/usr/bin/env python3
"""Repeat enhancement only in an API-only staging copy, never assembled guides."""
import os
from pathlib import Path
import shutil
import tempfile

from install_released_gnatdoc import require
from qualify_released_gnatdoc import hashes
from qualify_shared_production import ROOT, execute, source_workspace

with tempfile.TemporaryDirectory(prefix='imgproc-repeat-docs-') as tmp:
    workspace = Path(tmp)
    source = source_workspace(ROOT, workspace / 'source')
    site = workspace / 'site'
    site.mkdir()
    shutil.copytree(ROOT / '_site/api', site / 'api')
    before = hashes(site)
    environment = Path(os.environ.get('GNATDOC_ENHANCER_VENV', ROOT / '.doc-tools/enhancer-0.1.1'))
    execute(environment, source, 'enhance', site)
    execute(environment, source, 'verify', site)
    require(hashes(site) == before, 'repeat enhancement changed API bytes')