#!/usr/bin/env python3
"""Render the approved developer guides; reconstruct expected bytes to validate.

Adapted from opencv_core_ada. Markdown syntax belongs to the pinned
markdown-it-py; token inspection enforces a narrower publishing contract
before any HTML is emitted:

- no raw HTML or images; fenced code only in `ada`, `sh` or `text`;
- every `ada` fence must be exactly one compiled example under
  `docs/examples/`, and every example must appear in a guide, so all Ada code
  in the guides is compiled and executed by the documentation workflow;
- links are local guide headings, other approved guides, `https` pages on
  github.com or zackboll.github.io, or `api:Name` / `api:Name/N` (overload
  N in source order), which resolve to the verified native anchor of that
  declaration discovered by the operation browser, never to a guessed one.

Validation reconstructs every page and the stylesheet and compares bytes; no
manifest can authorize content, destinations or assets.
"""
import html
import re
import sys
from importlib.metadata import version
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
GUIDES = {
    'filtering-and-transforms': (
        'Filtering and image transformations',
        ('Gaussian_Blur', 'Sobel', 'Pyramid_Down', 'Resize', 'Warp_Affine', 'Remap')),
    'color-and-image-representation': (
        'Color conversion and image representation',
        ('Convert_Color', 'Color_Conversion', 'Decode_YUV420', 'Demosaic_Bayer',
         'Apply_Color_Map')),
    'features-and-structural-analysis': (
        'Geometry, features and structural analysis',
        ('Canny_Edges', 'Harris_Corner_Response', 'Find_Hough_Lines',
         'Calculate_Histogram', 'Integral_Sum')),
    'segmentation-contours-and-morphology': (
        'Segmentation, contours and morphology',
        ('Apply_Threshold', 'Apply_Morphology', 'Find_Contours',
         'Connected_Components_With_Stats', 'Flood_Fill')),
    'template-matching-and-registration': (
        'Template matching and image registration',
        ('Template_Matching_Method', 'Match_Template', 'Phase_Correlate',
         'Find_Guil_Template_Matches')),
}
GITHUB = 'https://github.com/zackboll/opencv_imgproc_ada/blob/main/'
EXTERNAL_HOSTS = ('github.com', 'zackboll.github.io')
API_LINK = re.compile(r'api:([A-Za-z][A-Za-z0-9_]*)(?:/([1-9][0-9]*))?')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def slug(text):
    return re.sub(r'[^\w\- ]', '', text.lower()).replace(' ', '-')


def markdown(source, rewrite=None, fences=None, examples=None):
    # Imported here so the guide inventory is available without the renderer.
    from markdown_it import MarkdownIt
    require(version('markdown-it-py') == '3.0.0' and version('mdurl') == '0.1.2',
            'unqualified Markdown dependency version')
    parser = MarkdownIt('commonmark', {'html': True}).enable('table')
    # Every destination must reach the rejecting policy below.
    parser.validateLink = lambda destination: True
    tokens = parser.parse(source)
    headings, level = [], 0
    for i, token in enumerate(tokens):
        require(token.type not in ('html_block', 'html_inline', 'image'),
                'unsupported raw HTML or image')
        if token.type == 'fence':
            lines = source.splitlines()
            end = token.map[1] - 1
            require(end > token.map[0] and re.fullmatch(
                r' {0,3}' + re.escape(token.markup[0]) +
                '{' + str(len(token.markup)) + r',}\s*', lines[end]) is not None,
                'unclosed Markdown fence')
            require(token.info.strip() in ('ada', 'sh', 'text'),
                    'unsupported fenced-code language')
            if token.info.strip() == 'ada' and fences is not None:
                fences.append(token.content)
        if token.type == 'heading_open':
            current = int(token.tag[1:])
            require(current <= level + 1 and (current != 1 or not headings),
                    'invalid heading hierarchy')
            level = current
            text = ''.join(t.content for t in tokens[i + 1].children
                           if t.type in ('text', 'code_inline'))
            identity = slug(text)
            require(identity, 'empty heading identity')
            base, suffix = identity, 0
            while identity in headings:
                suffix += 1
                identity = f'{base}-{suffix}'
            headings.append(identity)
            token.attrSet('id', identity)
        for child in token.children or []:
            require(child.type not in ('html_inline', 'image'), 'unsupported raw HTML or image')
            if child.type == 'link_open' and rewrite:
                child.attrSet('href', rewrite(child.attrGet('href')))
    require(headings and tokens[0].type == 'heading_open' and tokens[0].tag == 'h1',
            'guide must begin with one document title')
    if examples is not None:
        native_fence = parser.renderer.rules['fence']

        def fence_rule(tokens, index, options, env):
            token = tokens[index]
            if token.info.strip() == 'ada':
                return examples.render(token.content, '../') + '\n'
            return native_fence(tokens, index, options, env)

        parser.renderer.rules['fence'] = fence_rule
    rendered = parser.renderer.render(tokens, parser.options, {})
    rendered = rendered.replace(
        '<table>', '<div class="table-scroll" tabindex="0" role="region" '
        'aria-label="Scrollable table"><table>')
    return rendered.replace('</table>', '</table></div>'), headings


def sources(root):
    result = {}
    for name, (title, _) in GUIDES.items():
        path = root / 'docs/guides' / f'{name}.md'
        require(path.is_file() and not path.is_symlink(), f'missing guide source: {name}')
        text = path.read_text(encoding='utf-8')
        require(text.splitlines()[0] == '# ' + title, f'wrong title: {name}')
        result[name] = text
    extra = {p.stem for p in (root / 'docs/guides').glob('*.md')} - set(GUIDES)
    require(not extra, f'unapproved guide sources: {sorted(extra)}')
    return result


def api_destinations(site, root):
    """(name, overload) -> verified native href, from the operation browser."""
    from enhance_gnatdoc_navigation import entries
    _, groups = entries(site / 'api', root / 'src', root / 'docs/api-categories.json')
    result = {}
    for _, _, items in groups:
        for item in items:
            result[(item['name'], item['overload'] or 1)] = '../api/' + item['href']
    return result


def resolve_link(link, name, headings, api):
    require(not re.search(r'[\x00-\x20\\]', link), f'unsafe link: {link}')
    match = API_LINK.fullmatch(link)
    if match:
        key = (match[1], int(match[2] or 1))
        require(key in api, f'unknown API declaration: {link}')
        return api[key]
    url = urlsplit(link)
    require(not url.query, f'unexpected query: {link}')
    if url.scheme:
        require(url.scheme == 'https' and url.hostname in EXTERNAL_HOSTS and
                not url.username and not url.password and not url.port,
                f'unapproved external link: {link}')
        return link
    require(not url.netloc and '/' not in url.path, f'unapproved local path: {link}')
    if not url.path:
        require(url.fragment in headings[name], f'missing local heading: {link}')
        return '#' + url.fragment
    target = url.path.removesuffix('.md')
    require(url.path.endswith('.md') and target in GUIDES, f'unknown guide: {link}')
    require(not url.fragment or url.fragment in headings[target],
            f'missing guide heading: {link}')
    return target + '.html' + ('#' + url.fragment if url.fragment else '')


def expected(root=ROOT, site=None):
    from render_gnatdoc_examples import ExampleRenderer
    root, site = Path(root).resolve(), Path(site).resolve()
    texts = sources(root)
    headings = {name: markdown(text)[1] for name, text in texts.items()}
    api = api_destinations(site, root)
    renderer = ExampleRenderer(site, root)
    examples = {p.name: p.read_text(encoding='utf-8')
                for p in sorted((root / 'docs/examples').glob('*.adb'))}
    used = set()
    outputs = {'gnatdoc-guides.css': (root / 'docs/assets/gnatdoc-guides.css').read_bytes()}
    for name, (title, entry_names) in GUIDES.items():
        fences = []
        content, _ = markdown(texts[name],
                              lambda link: resolve_link(link, name, headings, api),
                              fences, renderer)
        for fence in fences:
            owners = [file for file, text in examples.items() if text == fence]
            require(len(owners) == 1, f'{name}: Ada code is not a compiled example')
            used.update(owners)
        nav = '\n'.join(
            f'<li><a href="{other}.html"' +
            (' aria-current="page"' if other == name else '') +
            f'>{html.escape(label)}</a></li>' for other, (label, _) in GUIDES.items())
        entries = '\n'.join(
            f'<li><a href="{api[(entry, 1)]}">{entry}</a></li>' for entry in entry_names)
        require('native-api-entry-points' not in headings[name] and
                'main-content' not in headings[name], 'reserved heading identity')
        page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} — OpenCV Imgproc Ada</title>
<link rel="stylesheet" href="../api/gnatdoc-theme.css">
<link rel="stylesheet" href="gnatdoc-guides.css">
</head>
<body>
<a class="skip-link" href="#main-content">Skip to content</a>
<header><nav aria-label="Documentation"><a href="../index.html">Documentation home</a> · <a href="../api/index.html">API browser</a></nav></header>
<div class="guide-layout">
<nav class="guide-nav" aria-label="Developer guides"><ul>
{nav}
</ul></nav>
<main id="main-content">
{content}
<section aria-label="Native API entry points"><h2 id="native-api-entry-points">Native API entry points</h2><ul>
{entries}
</ul></section>
<p class="guide-source"><a href="{GITHUB}docs/guides/{name}.md">Original Markdown source on GitHub</a></p>
</main>
</div>
</body>
</html>
'''
        outputs[name + '.html'] = page.encode('utf-8')
    require(used == set(examples), f'examples missing from guides: {sorted(set(examples) - used)}')
    return outputs


def validate(root=ROOT, site=None):
    outputs = expected(root, site)
    directory = Path(site) / 'guides'
    require(directory.is_dir() and not directory.is_symlink(), 'missing/unsafe guide directory')
    require({p.name for p in directory.iterdir()} == outputs.keys(), 'guide inventory mismatch')
    for name, content in outputs.items():
        require(not (directory / name).is_symlink() and
                (directory / name).read_bytes() == content,
                f'authoritative guide/stylesheet mismatch: {name}')
    return len(outputs) - 1


def generate(root=ROOT, site=None):
    outputs = expected(root, site)
    directory = Path(site) / 'guides'
    require(not directory.is_symlink(), 'unsafe guide output directory')
    directory.mkdir(exist_ok=True)
    require({p.name for p in directory.iterdir()} <= outputs.keys(), 'unapproved guide files')
    for name, content in outputs.items():
        require(not (directory / name).is_symlink(), 'unsafe output file')
        (directory / name).write_bytes(content)
    count = validate(root, site)
    print(f'Guides: {count} pages; exact content, compiled examples, links and '
          'stylesheet verified')


if __name__ == '__main__':
    require(len(sys.argv) == 2, 'usage: render_gnatdoc_guides.py SITE_DIRECTORY')
    generate(ROOT, Path(sys.argv[1]))
