#!/usr/bin/env python3
"""Export independently source-matched native operations for browser assertions."""
import argparse
from pathlib import Path
from qualify_released_gnatdoc import expected_operations, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
write(args.output, expected_operations(root / 'obj/docs/native/api')[0])