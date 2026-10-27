#!/usr/bin/env python3
"""Explicit review-only oracle: legacy presentation of the same pristine input.

Never runs on shared-enhanced API files. Not a second production generator.
The caller must pass the independently verified indexed Core path explicitly.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

from install_released_gnatdoc import require

ROOT = Path(__file__).resolve().parents[1]


def render(native, output, core):
    require(not output.exists(), 'legacy oracle destination must be new')
    require((core / 'src/opencv.ads').is_file(), 'explicit indexed Core source required')
    shutil.copytree(native, output)
    for script, args in (
        ('install_gnatdoc_theme.py', [output / 'api']),
        ('link_gnatdoc_types.py', [output / 'api', '--core', core]),
        ('highlight_gnatdoc_ada.py', [output / 'api', '--core', core]),
        ('enhance_gnatdoc_navigation.py', [output / 'api']),
        ('render_gnatdoc_examples.py', [output]),
        ('render_gnatdoc_guides.py', [output]),
        ('validate_docs.py', [output]),
    ):
        subprocess.run([sys.executable, str(ROOT / 'scripts' / script), *map(str, args)],
                       cwd=ROOT, check=True, timeout=180)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('native', 'output', 'core'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    render(args.native.absolute(), args.output.absolute(), args.core.absolute())