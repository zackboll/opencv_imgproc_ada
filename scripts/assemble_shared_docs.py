#!/usr/bin/env python3
"""Production assembly: isolated released API enhancement, original authored renderer."""
import argparse
from pathlib import Path
import shutil
import tempfile

from install_released_gnatdoc import checked_tool, install, require
from qualify_released_gnatdoc import expected_operations, write
from qualify_shared_production import (
    ROOT, api_semantics, execute, final_semantics, indexed_core, source_workspace,
)
from render_gnatdoc_examples import ExampleRenderer, landing
from render_gnatdoc_guides import generate


def assemble(native, site, core, environment):
    indexed_core(ROOT, core)
    require(not site.exists(), 'final publication destination must be new')
    operations, declarations = expected_operations(native / 'api')
    require(len(operations) == len(declarations) == 329,
            'pristine native/source declaration inventory differs')
    write(ROOT / 'obj/docs/native-source-operations.json', declarations)
    if not environment.exists():
        install(environment, guides=True)
    _, identity = checked_tool(environment)
    write(ROOT / 'obj/docs/installed-enhancer.json', identity)
    # No authored pages enter this stage. Toolkit verify must not be described
    # as accepting the separate consumer-owned final assembly.
    with tempfile.TemporaryDirectory(prefix='imgproc-production-docs-') as tmp:
        workspace = Path(tmp)
        source = source_workspace(ROOT, workspace / 'source')
        staged = workspace / 'api-only'
        shutil.copytree(native, staged)
        execute(environment, source, 'inventory', staged)
        execute(environment, source, 'enhance', staged)
        execute(environment, source, 'verify', staged)
        api_semantics(native, staged)
        shutil.copytree(staged, site)
    (site / 'index.html').write_bytes(landing(ROOT, ExampleRenderer(site, ROOT, core)))
    generate(ROOT, site)
    write(ROOT / 'obj/docs/shared-qualification.json', final_semantics(site, native, core))
    checked_tool(environment)
    print('Shared API and independent complete-site qualification passed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('native', 'site', 'core', 'venv'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    assemble(args.native.resolve(), args.site.resolve(), args.core.resolve(), args.venv.absolute())