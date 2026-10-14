#!/usr/bin/env python3
"""Source-backed type cross-references for the pinned GNATdoc 26.0.0 HTML.

Adapted from opencv_core_ada. Only type-mark positions inside native
declaration snippets are candidates: parameter and component types, return
types, array component types and subtype or derived bases. Defaults,
constraints and attributes are never linked.

- An Imgproc type or subtype links to its own native section anchor, which
  is discovered from the generated page, never computed. An unqualified name
  links only when exactly one visible-part declaration of that name precedes
  the referencing declaration and no parameter or discriminant of that
  declaration shadows it.
- A Core type (`OpenCV.X` or `OpenCV.Core.X`) links only when the Core
  specification at `--core` declares that type in the visible part of that
  exact package. The destination is the published Core browser's
  package-level bookmark (`api/index.html?package=...`), the only stable
  destination its navigation supports; no declaration fragment is invented.
  These links open at the top level, outside the documentation frame.
- Standard and other names stay unlinked.

`type-crossrefs.json` records the original snippets and a hash of the page
outside them. A check run recomputes every link from those originals and the
sources and requires byte-identical snippets and unchanged surrounding HTML.
No third-party dependencies.
"""

import argparse
import hashlib
import html
import json
import re
import sys
from collections import Counter
from pathlib import Path

from compare_gnatdoc_warnings import (WarningComparisonError, code_tokens,
                                      declaration_index)

ROOT = Path(__file__).resolve().parent.parent
CORE_SITE = "https://zackboll.github.io/opencv_core_ada/api/index.html"
# Core package identity -> its specification and published bookmark name.
CORE_PACKAGES = {
    "opencv": ("opencv.ads", "OpenCV"),
    "opencv.core": ("opencv-core.ads", "OpenCV.Core"),
}
CORE_DESTINATIONS = {
    identity: f"{CORE_SITE}?package={name}"
    for identity, (_, name) in CORE_PACKAGES.items()
}


class CrossReferenceError(ValueError):
    """The pinned input or an integrity invariant was violated."""


IDENT = r"[A-Za-z][A-Za-z0-9_]*"
NAME = IDENT + r"(?:\." + IDENT + r")*"
SECTION = re.compile(
    r"<h4 id=([^ >]+)>([^<]+)</h4>"
    r"<pre class=ada-code-snippet><code>(.*?)</code></pre>", re.S)
LINK = re.compile(
    r'<a class="type-reference" href="([^"<>]+)" '
    r'data-type="([A-Za-z0-9_.]+)"(?: target="_top")?>([^<>]+)</a>')
TOKEN = re.compile(
    r'--[^\n]*|"(?:[^"\n]|"")*"|' + NAME +
    r"|:=|=>|\.\.|<>|\d[\w.]*|[^\s]", re.I)
MODIFIERS = {"aliased", "in", "out", "not", "null", "access", "constant"}
STANDARD = {
    "integer", "natural", "positive", "boolean", "float", "long_float",
    "long_long_float", "character", "wide_character", "wide_wide_character",
    "string", "wide_string", "wide_wide_string", "duration"}


def require(condition, message):
    if not condition:
        raise CrossReferenceError(message)


def tokens(text):
    return [(m.group().lower(), m.start(), m.end()) for m in TOKEN.finditer(text)
            if not m.group().startswith(('--', '"'))]


def plain(raw):
    """Remove only our exact markup; reject other or malformed snippet tags."""
    stripped = LINK.sub(lambda m: m[3], raw)
    require('<' not in stripped,
            "unexpected/nested/malformed HTML in Ada snippet")
    return stripped


def decoded_offsets(raw):
    """Keep byte-for-byte entity spelling when wrapping decoded token spans."""
    text, starts, ends = [], [], []
    for match in re.finditer(r"&(?:#[0-9]+|#x[0-9a-fA-F]+|[A-Za-z0-9]+);|.", raw, re.S):
        for char in html.unescape(match.group()):
            text.append(char)
            starts.append(match.start())
            ends.append(match.end())
    return ''.join(text), starts, ends


def visible_declarations(path):
    """Return (package identity, visible-part declarations) of one spec."""
    lines = path.read_text(encoding="utf-8").splitlines()
    code = "\n".join(code_tokens(line) for line in lines)
    package = re.search(r"\bpackage\s+(" + NAME + r")\s+is\b", code, re.I)
    require(package is not None, f"no library package in {path.name}")
    require(not re.search(r"\buse\s+(?!type\b|all\b)" + NAME, code, re.I),
            f"use clauses are not supported: {path.name}")
    require(not re.search(r"\brenames\b", code, re.I),
            f"renamings are not supported: {path.name}")
    private = next((number for number, line in enumerate(lines, start=1)
                    if code_tokens(line).strip().lower() == "private"),
                   len(lines) + 1)
    try:
        index = declaration_index(lines)
    except WarningComparisonError as error:
        raise CrossReferenceError(f"{path.name}: {error}") from error
    declarations = [d for values in index.values() for d in values
                    if d["start"] < private]
    return package[1].lower(), lines, declarations


def core_types(core_root):
    """Visible-part type and subtype names of each linked Core package."""
    result = {}
    for identity, (filename, _) in CORE_PACKAGES.items():
        path = core_root / "src" / filename
        require(path.is_file(), f"missing Core specification: {path}")
        package, _, declarations = visible_declarations(path)
        require(package == identity, f"unexpected Core package in {filename}")
        result[identity] = {
            d["name"].lower() for d in declarations
            if d["scope"].lower() == f"{identity}.{d['name'].lower()}"
            and d["signature"].split()[0] in ("type", "subtype")}
    return result


class Source:
    """The single public Imgproc specification and its visible declarations."""

    def __init__(self, source_root):
        specs = sorted(source_root.glob("*.ads"))
        require(len(specs) == 1, "type links support exactly one public package")
        self.package, self.lines, self.declarations = visible_declarations(specs[0])
        self.top = [d for d in self.declarations
                    if d["scope"].lower() == f"{self.package}.{d['name'].lower()}"]
        # Declarations that are directly visible in the package: top-level
        # declarations and enumeration literals. Record components are not.
        enumerations = {d["scope"].lower() for d in self.top
                        if d["signature"].split()[0] == "type"
                        and " is (" in d["signature"]}
        self.by_name = {}
        for declaration in self.declarations:
            owner = declaration["scope"].lower().rpartition(".")[0]
            if owner == self.package or owner in enumerations:
                self.by_name.setdefault(declaration["name"].lower(), []).append(declaration)

    def match(self, raw):
        """The one visible-part declaration whose source text is this snippet."""
        profile = [t[0] for t in tokens(html.unescape(raw))]
        require(profile, "empty Ada declaration")
        # GNATdoc 26.0.0 elides the middle of a long enumeration as `…,`.
        elided = profile.count("…")
        require(elided <= 1, "unsupported snippet elision")
        if elided:
            cut = profile.index("…")
            require(profile[0] == "type" and profile[cut + 1:cut + 2] == [","],
                    "unsupported snippet elision")
            prefix, suffix = profile[:cut], profile[cut + 2:]
        matches = []
        for declaration in self.top:
            source = [t[0] for t in tokens(
                "\n".join(self.lines[declaration["start"] - 1:declaration["end"]]))]
            if elided:
                if (len(source) > len(prefix) + len(suffix) and
                        source[:len(prefix)] == prefix and
                        source[len(source) - len(suffix):] == suffix):
                    matches.append(declaration)
                continue
            remainder = source[len(profile):]
            complete = not remainder or (
                profile[0] in {"function", "procedure"} and remainder[0] in {";", "with"})
            if source[:len(profile)] == profile and complete:
                matches.append(declaration)
        require(len(matches) == 1, f"source profile not unique: {raw[:100]}")
        return matches[0]


def type_positions(text):
    """Recognize type marks, not arbitrary identifiers or expressions."""
    ts = tokens(text)
    ws = [t[0] for t in ts]
    require(bool(ws), "missing declaration")
    depth = 0
    for word in ws:
        depth += (word == '(') - (word == ')')
        require(depth >= 0, "unbalanced Ada profile")
    require(depth == 0, "unbalanced Ada profile")
    if ws[0] not in {'function', 'procedure', 'type', 'subtype'}:
        return []
    positions = set()
    for i, word in enumerate(ws):
        candidate = word in {':', 'return'}
        if ws[0] in {'type', 'subtype'}:
            candidate |= word == 'of' and 'array' in ws[:i]
            candidate |= word == 'is' and ws[0] == 'subtype'
            candidate |= word == 'new' and i > 1 and ws[i - 1] == 'is'
        if not candidate:
            continue
        j = i + 1
        while j < len(ws) and ws[j] in MODIFIERS:
            j += 1
        if j < len(ws) and re.fullmatch(NAME, ws[j]) and ws[j] not in {
                'procedure', 'function', 'array', 'record', 'range', 'digits',
                'delta', 'constant'}:
            positions.add(j)
    return [ts[i] for i in sorted(positions)]


def native_targets(text, source):
    """Discover type anchors from source-matched native sections."""
    from highlight_gnatdoc_ada import strip_highlighting
    targets = {}
    sections = list(SECTION.finditer(text))
    require(len(sections) == text.count('<pre class=ada-code-snippet>'),
            "unexpected snippet structure")
    for section in sections:
        raw = plain(strip_highlighting(section[3]))
        declaration = source.match(raw)
        header = re.match(r"\s*(type|subtype)\s+(" + IDENT + r")\b",
                          html.unescape(raw), re.I)
        if not header:
            continue
        require(header[2].lower() == section[2].lower() ==
                declaration["name"].lower(), "type heading/profile mismatch")
        identity = f"{source.package}.{header[2].lower()}"
        require(identity not in targets, f"conflicting type identity: {identity}")
        targets[identity] = section[1]
    return sections, targets


def resolve(name, declaration, source, targets, core):
    """Return (identity, destination, status) for one type mark."""
    if '.' in name:
        owner, _, simple = name.rpartition('.')
        if owner == source.package:
            identity = name
            return ((identity, '#' + targets[identity], 'linked')
                    if identity in targets else (None, None, 'unsupported'))
        if owner in CORE_DESTINATIONS and simple in core[owner]:
            return name, CORE_DESTINATIONS[owner], 'external'
        return None, None, 'unsupported'
    full = "\n".join(source.lines[declaration["start"] - 1:declaration["end"]])
    shadows = set()
    for match in re.finditer(r'\b(' + IDENT + r'(?:\s*,\s*' + IDENT + r')*)\s*:(?!=)', full):
        shadows.update(n.strip().lower() for n in match[1].split(','))
    if name in shadows:
        return None, None, 'unsupported'
    earlier = [d for d in source.by_name.get(name, [])
               if d["start"] < declaration["start"]]
    if not earlier:
        return None, None, 'unsupported'
    identity = f"{source.package}.{name}"
    if len(earlier) == 1 and identity in targets and \
            earlier[0]["scope"].lower() == identity:
        return identity, '#' + targets[identity], 'linked'
    return None, None, 'ambiguous'


def render(raw, declaration, source, targets, core, counts, families):
    text, starts, ends = decoded_offsets(raw)
    inserts = []
    for name, start, end in type_positions(text):
        identity, destination, status = resolve(name, declaration, source, targets, core)
        counts[status] += 1
        if not identity:
            continue
        label = raw[starts[start]:ends[end - 1]]
        external = ' target="_top"' if status == 'external' else ''
        inserts.append((starts[start], ends[end - 1],
                        f'<a class="type-reference" href="{destination}" '
                        f'data-type="{identity}"{external}>{label}</a>'))
        families[identity] += 1
    result = raw
    for start, end, markup in reversed(inserts):
        result = result[:start] + markup + result[end:]
    require(plain(result) == raw, "Ada text preservation failure")
    return result


def outside_hash(text):
    return hashlib.sha256(SECTION.sub(lambda m: m[0].replace(m[3], '', 1), text)
                          .encode('utf-8')).hexdigest()


def package_page(api, source):
    pages = []
    for path in sorted(api.glob('*.html')):
        if path.name == 'index.html':
            continue
        headings = re.findall(r"<h1>([^<]+)</h1>", path.read_text(encoding="utf-8"))
        require(len(headings) == 1, f"unexpected package heading: {path.name}")
        pages.append((headings[0].lower(), path))
    require([name for name, _ in pages] == [source.package],
            "public source/page coverage mismatch")
    return pages[0][1]


def process(api, source_root=ROOT / "src", core_root=ROOT.parent / "core",
            check=False, highlight=False, minimum_internal=0, minimum_external=0,
            quiet=False):
    """Link, verify, or (with highlight) color the package page snippets."""
    from highlight_gnatdoc_ada import highlight as color, strip_highlighting
    api = Path(api).resolve()
    require(api.name == 'api', "cross-references must operate in a generated api directory")
    source = Source(Path(source_root))
    core = core_types(Path(core_root))
    path = package_page(api, source)
    text = path.read_text(encoding="utf-8")
    sections, targets = native_targets(text, source)
    manifest_path = api / 'type-crossrefs.json'
    existing = manifest_path.exists()
    require(existing or not check, "missing cross-reference integrity manifest")
    if existing:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        require(manifest.get('version') == 1, "unexpected cross-reference manifest version")
        require(manifest.get('file') == path.name, "manifest package page mismatch")
        require(manifest.get('outside') == outside_hash(text), "non-snippet HTML changed")
        require(len(manifest.get('snippets', [])) == len(sections), "snippet count changed")
        colored = manifest.get('highlighting', 0)
        require(colored in (0, 1), "unexpected highlighting contract version")
    else:
        require('type-reference' not in text, "linked HTML lacks integrity manifest")
        manifest = {'version': 1, 'file': path.name, 'outside': outside_hash(text),
                    'snippets': [section[3] for section in sections]}
        colored = 0
    require(not highlight or existing, "highlighting requires qualified type links")
    counts, families = Counter(), Counter()
    replacements = []
    for raw, section in zip(manifest['snippets'], sections):
        current = strip_highlighting(section[3]) if colored else section[3]
        require(existing is False or plain(current) == raw,
                f"original Ada declaration text changed: {section[2]}")
        declaration = source.match(raw)
        expected = render(raw, declaration, source, targets, core, counts, families)
        if existing:
            require(section[3] == (color(expected) if colored else expected),
                    f"type identity/destination/markup mismatch: {section[2]}")
        if colored or highlight:
            expected = color(expected)
        replacements.append((section.start(3), section.end(3), expected))
    require(counts['linked'] >= minimum_internal and counts['external'] >= minimum_external,
            f"insufficient safe coverage: {counts['linked']} internal and "
            f"{counts['external']} Core links")
    result = text
    for start, end, replacement in reversed(replacements):
        result = result[:start] + replacement + result[end:]
    require(outside_hash(result) == manifest['outside'], "HTML outside snippets changed")
    # Every integrity check completes before any site write.
    if not check and (not existing or (highlight and not colored)):
        if highlight:
            manifest['highlighting'] = 1
        path.write_text(result, encoding="utf-8")
        manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n',
                                 encoding="utf-8")
    if not quiet:
        print(f"Type cross-references: {len(sections)} snippets; "
              f"{counts['linked']} Imgproc and {counts['external']} Core package links; "
              f"{counts['ambiguous']} ambiguous and {counts['unsupported']} unsupported "
              f"names left unlinked" + ("; highlighting verified" if colored or highlight else ""))
    return counts, families


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('api', type=Path)
    parser.add_argument('--sources', type=Path, default=ROOT / 'src')
    parser.add_argument('--core', type=Path, default=ROOT.parent / 'core')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args(argv)
    try:
        process(args.api, args.sources, args.core, args.check)
    except (CrossReferenceError, KeyError, OSError) as error:
        print(f'error: type cross-references: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
