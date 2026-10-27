#!/usr/bin/env python3
"""Consumer-owned R2 semantic oracle, independent of enhancer output receipts.

Native input is freshly generated outside the publication tree. The toolkit
qualifies only the staged API. This module additionally reconstructs the
consumer-owned authored pages and checks the COMPLETE publication inventory.
"""
import argparse
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
import subprocess
import tomllib

from check_doc_coverage import check_site
from install_released_gnatdoc import checked_tool, digest, require
from link_gnatdoc_types import Source, package_page
from probe_core_candidate import reconcile
from qualify_released_gnatdoc import Operations, expected_operations, hashes, write
from render_gnatdoc_examples import ExampleRenderer, landing
from render_gnatdoc_guides import expected as authored_guides
from validate_docs import Page, LEAKS

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    'api/gnatdoc-navigation.js': 'b3fb428b507844d6be76fb40156058d39a5b5f57004bde04e33b0411f68504cd',
    'api/gnatdoc-theme.css': 'cf06637732a8b047a7191bfb991a5c3da7cd31a52076876880d5f8a3f63929bc',
}
INDEX_SHA = '6ccce736335a87da898e8258aad4c341775a65b0690522a010783302e834dc04'


class SnippetMarkup(HTMLParser):
    """Only lexical spans and mechanically source-checked type links are legal."""
    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        require(len(attrs) == len(attributes), 'duplicate snippet attribute')
        if tag == 'span':
            from highlight_gnatdoc_ada import CLASSES
            require(set(attrs) == {'class'} and attrs['class'] in {'ada-' + x for x in CLASSES},
                    'unapproved snippet span')
        elif tag == 'a':
            external = attrs.get('href', '').startswith('https:')
            require(set(attrs) == {'class', 'href', 'data-type'} | ({'target'} if external else set()) and
                    attrs['class'] == 'type-reference' and
                    (not external or attrs['target'] == '_top'), 'unapproved type-link markup or target')
        else:
            raise ValueError('unapproved snippet tag: ' + tag)

    def handle_endtag(self, tag):
        require(tag in {'span', 'a'}, 'unapproved snippet end tag')


def indexed_core(root, core):
    from core_source_authority import checked_resolution
    return checked_resolution(root, core)


def source_workspace(root, destination):
    destination.mkdir()
    (destination / 'qualification-public').mkdir()
    shutil.copyfile(root / 'src/opencv-image_processing.ads',
                    destination / 'qualification-public/opencv-image_processing.ads')
    shutil.copyfile(root / 'docs/api-categories.json', destination / 'categories.json')
    shutil.copyfile(root / 'docs/gnatdoc-enhancer.toml', destination / 'candidate.toml')
    return destination


def execute(environment, source, command, site):
    tool, _ = checked_tool(environment)
    subprocess.run([str(tool), command, '--config', 'candidate.toml',
                    '--source-root', str(source), '--site', str(site)],
                   check=True, timeout=180)


def api_semantics(native, candidate, root=ROOT):
    ledger = json.loads((root / 'docs/evidence/gnatdoc009/r1/core-destination-proposal.json').read_text())
    policy = tomllib.loads((root / 'docs/gnatdoc-enhancer.toml').read_text())
    require(policy['presentation'] == {'theme': True, 'syntax_highlighting': True,
            'type_links': True, 'external_type_target': '_top'}, 'unreviewed presentation policy')
    require(policy['external_types'] == {k: v['url'] for k, v in ledger['types'].items()},
            'Core destination differs from reviewed source/native proposal')
    authority_path = root / 'docs/evidence/gnatdoc009/r3/referenced-types.json'
    require(digest(authority_path.read_bytes()) ==
            '47209d10c4b5de1f31ca3f85f00b838d41381c614acfc7930456b1cd66391603',
            'reviewed current Core declaration authority changed')
    authority = json.loads(authority_path.read_text())
    proposal = json.loads((root / 'docs/evidence/gnatdoc009/r3/policy-proposal.json').read_text())
    from core_source_authority import authority as source_authority
    indexed = source_authority(root)
    for identity, proof in authority.items():
        require(all(proof[k] == indexed['types'][identity][k] for k in indexed['types'][identity]),
                'hosted type not bound to exact indexed 0.5.2 declaration')
    require(proposal['deployment'] == 7348179998 and proposal['run'] == 40433988181 and
            proposal['source'] == '33a2a4f3b83606a5c779b8a93abeb6c91fa49a21' and
            proposal['tree'] == '454fb0fa3a128e638a1d7d85f345c7904f296877' and
            proposal['review_artifact'] == 12702919800 and
            proposal['pages_artifact'] == 12703258126 and
            proposal['indexed_version'] == indexed['version'] and
            proposal['indexed_origin'] == indexed['origin'] and
            proposal['policy_approved'] is False and
            policy['external_types'] == {k: v['url'] for k, v in authority.items()},
            'Core policy not bound to reviewed immutable deployment proposal')
    require(digest((root / 'src/opencv-image_processing.ads').read_bytes()) ==
            ledger['occurrences'][0]['imgproc_source_file_sha256'], 'current source differs from occurrence authority')
    report = reconcile(native, candidate, ledger)
    require(report['external_target_attributes'] == {'_top': 586}, 'external navigation must escape the iframe')
    expected, inventory = expected_operations(native / 'api')
    require(Operations((candidate / 'api/index.html').read_text()).links == expected,
            'source-order overload/category/operation destination changed')
    require(digest((candidate / 'api/index.html').read_bytes()) == INDEX_SHA,
            'unqualified navigation markup or controls')
    source = Source(root / 'src')
    original = package_page(native / 'api', source)
    transformed = (candidate / 'api' / original.name).read_text()
    from link_gnatdoc_types import SECTION
    from probe_core_candidate import SnippetLinks
    occurrence_inventory = []
    for section in SECTION.finditer(transformed):
        parser = SnippetMarkup()
        parser.feed(section[3])
        parser.close()
        occurrence_inventory.extend({'declaration_anchor': section[1], **link}
                                    for link in SnippetLinks(section[3]).links)
    report['api_occurrences'] = occurrence_inventory
    # Outside snippets only the exact reviewed native-document head changes.
    # This rejects invisible injected attributes, changed bookmarks and hidden
    # active markup even if the visible-text and receipt checks still match.
    scrub = lambda text: SECTION.sub(lambda m: m[0].replace(m[3], '__SOURCE_SNIPPET__', 1), text)
    native_shell = scrub(original.read_text())
    enhanced_shell = scrub(transformed)
    native_head = '<html class=main>\n<link rel=stylesheet href=gnatdoc.css>'
    enhanced_head = ('<html class=main lang="en">\n<head><meta charset="utf-8">'
                     '<title>OpenCV.Image_Processing — opencv_imgproc_ada</title>'
                     '<link rel=stylesheet href=gnatdoc.css><meta name="viewport" '
                     'content="width=device-width, initial-scale=1">'
                     '<link rel="stylesheet" href="gnatdoc-theme.css"></head>')
    require(native_shell.count(native_head) == 1 and
            native_shell.replace(native_head, enhanced_head, 1) == enhanced_shell,
            'native page shell, links or documentation markup changed')
    title = '<title>OpenCV.Image_Processing — opencv_imgproc_ada</title>'
    require(transformed.count(title) == 1, 'missing or unexpected native package title')
    plain = lambda text: html.unescape(re.sub(r'<[^>]*>', '', text))
    require(plain(original.read_text()) == plain(transformed.replace(title, '', 1)),
            'native visible declaration/documentation text changed')
    native_files = hashes(native)
    require(native_files['api/gnatdoc.css'] == digest((candidate / 'api/gnatdoc.css').read_bytes()),
            'native GNATdoc stylesheet changed')
    manifest = json.loads((candidate / 'api/presentation.json').read_text())
    require(manifest['enhancer_version'] == '0.1.1' and manifest['gnatdoc_version'] == '26.0.0',
            'wrong presentation version')
    require(manifest['original_api_html'] == {
        p.relative_to(native).as_posix(): p.read_text() for p in (native / 'api').glob('*.html')},
        'output manifest cannot substitute pristine native authority')
    require(manifest['source_sha256'] == {'qualification-public/opencv-image_processing.ads':
            digest((root / 'src/opencv-image_processing.ads').read_bytes())}, 'source manifest substitution')
    require(manifest['counts'] == {'declaration_snippets': 329,
            'linked_external_types': 586, 'linked_local_types': 350,
            'linked_types': 936, 'public_packages': 1, 'unrendered_renderer_exceptions': 0},
            'tampered presentation counts')
    expected_output = {p: digest((candidate / p).read_bytes()) for p in (
        'api/' + original.name, 'api/index.html', *ASSETS)}
    require(manifest['output_sha256'] == expected_output and
            manifest['native_css_sha256'] == native_files['api/gnatdoc.css'] and
            set(manifest) == {'schema_version', 'enhancer_version', 'gnatdoc_version',
                             'project', 'original_api_html', 'native_css_sha256',
                             'source_sha256', 'output_sha256', 'counts'} and
            manifest['schema_version'] == 1 and manifest['project'] == 'opencv_imgproc_ada',
            'tampered presentation receipt')
    for name, sha in ASSETS.items():
        require(digest((candidate / name).read_bytes()) == sha, 'unqualified static asset: ' + name)
    report.update(operations=len(inventory), public_packages=1,
                  native_visible_text_preserved=True, native_css_preserved=True)
    return report


def final_semantics(site, native, core, root=ROOT):
    indexed_core(root, core)
    result = api_semantics(native, site, root)
    outputs = {'index.html': landing(root, ExampleRenderer(site, root, core))}
    outputs.update({'guides/' + name: content for name, content in authored_guides(root, site).items()})
    for name, data in outputs.items():
        require((site / name).read_bytes() == data, 'authoritative authored page/asset mismatch: ' + name)
    allowed = set(hashes(native)) | set(ASSETS) | {'api/presentation.json'} | set(outputs)
    require(set(hashes(site)) == allowed, 'complete publication file inventory differs')
    pages = {p.resolve(): Page(p) for p in site.rglob('*.html')}
    approved_external = set(tomllib.loads((root / 'docs/gnatdoc-enhancer.toml').read_text())['external_types'].values())
    from validate_docs import LANDING_DESTINATIONS
    from render_gnatdoc_examples import CORE_EXAMPLE_DESTINATIONS
    from urllib.parse import urlsplit, unquote
    approved_external |= set(LANDING_DESTINATIONS) | CORE_EXAMPLE_DESTINATIONS | {
        'https://github.com/zackboll/opencv_imgproc_ada/blob/main/README.md',
        'https://github.com/zackboll/opencv_imgproc_ada/releases',
        'https://github.com/zackboll/opencv_imgproc_ada/issues'}
    for path, page in pages.items():
        relative = path.relative_to(site.resolve()).as_posix()
        require(not page.active or (relative == 'api/index.html' and
                page.active == ['<script src=gnatdoc-navigation.js>']), 'unexpected active content: ' + relative)
        require(len(page.ids) == len(set(page.ids)), 'duplicate IDs: ' + relative)
        require(not LEAKS.search(' '.join(page.text)), 'private or machine-local content leaked')
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                approved = link in approved_external or (
                    relative.startswith('guides/') and url.scheme == 'https' and
                    url.netloc in {'github.com', 'zackboll.github.io'} and
                    not url.username and not url.password and not url.port and not url.query)
                require(approved, 'unapproved external URL: ' + link)
            else:
                require(not url.path.startswith('/') and not url.query, 'unsafe local URL')
                target = (path.parent / unquote(url.path)).resolve() if url.path else path
                require(target.is_relative_to(site.resolve()) and target.is_file(), 'broken local URL: ' + link)
                require(not url.fragment or (target in pages and unquote(url.fragment) in pages[target].ids),
                        'wrong local fragment: ' + link)
    items, missing, errors = check_site(site, root)
    require(len(items) == 1596 and not missing and not errors, 'source documentation coverage changed')
    renderer = ExampleRenderer(site, root, core)
    references = [identity for path in [root / 'docs/example.adb', *sorted((root / 'docs/examples').glob('*.adb'))]
                  for _, _, identity in renderer.references(path.read_text())]
    require(len(references) == 55 and sum(x.startswith('opencv.image_processing.') for x in references) == 8,
            'authored example source-qualified occurrence inventory changed')
    result.update(documented_elements=len(items), authored_examples=6,
                  authored_example_links=55, authored_local_links=8, authored_core_links=47,
                  full_site_sha256=hashes(site))
    result['authored_occurrences'] = [
        {'source': path.relative_to(root).as_posix(), 'source_sha256': digest(path.read_bytes()),
         'references': [{'start': start, 'end': end, 'identity': identity,
                         'label': path.read_text()[start:end], 'url': renderer.destinations[identity]}
                        for start, end, identity in renderer.references(path.read_text())]}
        for path in [root / 'docs/example.adb', *sorted((root / 'docs/examples').glob('*.adb'))]]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path, required=True)
    parser.add_argument('--site', type=Path, required=True)
    parser.add_argument('--core', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    write(args.report, final_semantics(args.site.resolve(), args.native.resolve(), args.core.resolve()))


if __name__ == '__main__':
    main()