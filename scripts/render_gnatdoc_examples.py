#!/usr/bin/env python3
"""Source-backed, bounded Ada example rendering, independent of Markdown.

This is not an Ada semantic front end. Unsupported visibility disables linking
instead of guessing. Coloring still uses the existing lexical highlighter.
"""
import html
import re
from pathlib import Path

from highlight_gnatdoc_ada import LEXEME, highlight, strip_highlighting
from link_gnatdoc_types import (
    CORE_DESTINATIONS, CORE_PACKAGES, CORE_ROOT, CORE_SITE,
    STANDARD, Source, native_targets, package_page, plain, require, visible_declarations,
)

# Independently inspected in Core's published #type-navigation and in its
# public specifications. No native Core hash is embedded in generated links.
# Contract: Core aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d, docs/documentation.md.
CORE_SYMBOLS = (
    'OpenCV.Core.Mat', 'OpenCV.Core.Min_Max_Result', 'OpenCV.Size',
    'OpenCV.Float32_Value', 'OpenCV.Float64_Value', 'OpenCV.UInt8_Value',
    'OpenCV.Point_Coordinate', 'OpenCV.Size_Coordinate',
)
CORE_EXAMPLE_DESTINATIONS = {CORE_SITE + '?symbol=' + name for name in CORE_SYMBOLS}
VALID_IDENT = re.compile(r'[A-Za-z](?:[A-Za-z0-9]|_(?=[A-Za-z0-9]))*\Z')
BLOCK = re.compile(r'<pre class="ada-example" tabindex="0" role="region" '
                   r'aria-label="Ada example"><code class="language-ada">'
                   r'(.*?)</code></pre>', re.S)
LANDING_MARKER = '<!-- compiled Ada example -->'


def lex(source):
    """Tokenize source, masking literals atomically; reject malformed tokens.

    The shared lexer intentionally tolerates arbitrary native snippets. Example
    identity resolution is stricter: no partial matches inside malformed Ada.
    """
    result, cursor = [], 0
    for match in LEXEME.finditer(source):
        gap = source[cursor:match.start()]
        if gap.strip(' \t\r\n[]') and not (gap.strip() == "'" and match.group() == '('):
            return None
        kind, word = match.lastgroup, match.group()
        if kind == 'identifier' and not VALID_IDENT.fullmatch(word):
            return None
        if kind in ('identifier', 'number') and match.start() and \
                (source[match.start() - 1].isalnum() or source[match.start() - 1] == '_'):
            return None
        # Keep literal placeholders: removing them could join unrelated tokens.
        if kind != 'comment':
            result.append((word.lower() if kind not in ('string', 'character') else '',
                           match.start(), match.end(), kind))
        cursor = match.end()
    if source[cursor:].strip():
        return None
    return result


class ExampleRenderer:
    """Resolve public types from specs + observed native declaration sections."""

    def __init__(self, site, root, core=CORE_ROOT):
        self.source = Source(Path(root) / 'src')
        page = package_page(Path(site) / 'api', self.source)
        _, targets = native_targets(page.read_text(encoding='utf-8'), self.source)
        self.destinations = {
            identity: ('api/' + page.name + '#' + anchor)
            for identity, anchor in targets.items()
        }
        self.names = {self.source.package: self.source.by_name}
        canonical = {name.lower(): name for name in CORE_SYMBOLS}
        for owner, (filename, _) in CORE_PACKAGES.items():
            package, _, declarations = visible_declarations(Path(core) / 'src' / filename)
            require(package == owner, 'unexpected example Core source identity')
            top = [d for d in declarations
                   if d['scope'].lower() == owner + '.' + d['name'].lower()]
            enumerations = {d['scope'].lower() for d in top
                            if d['signature'].startswith('type ') and ' is (' in d['signature']}
            names = self.names[owner] = {}
            for declaration in declarations:
                if declaration['scope'].lower().rpartition('.')[0] in {owner} | enumerations:
                    names.setdefault(declaration['name'].lower(), []).append(declaration)
            for declaration in top:
                if declaration['signature'].split()[0] not in ('type', 'subtype'):
                    continue
                identity = declaration['scope'].lower()
                self.destinations[identity] = (
                    CORE_SITE + '?symbol=' + canonical[identity] if identity in canonical
                    else CORE_DESTINATIONS[owner])
        require(all(name.lower() in self.destinations for name in CORE_SYMBOLS),
                'stale example Core symbol identity')

    def references(self, source):
        """Return source offsets and identities, never arbitrary word matches.

        Supported: one procedure, its initial with/use context, object type
        marks, use [all] type, local subtype bases, and explicit conversions /
        qualifications. Simple nested declare blocks and loops are allowed.
        All local defining names conservatively shadow throughout the example.
        Nested subprograms/packages, renames, generics, tasks and records disable
        links for the entire example. Unknown use packages suppress unqualified
        links. No visibility is inferred from aliases or prefixed notation.
        """
        ts = lex(source)
        if not ts:
            return []
        ws = [t[0] for t in ts]
        if ws.count('procedure') != 1 or any(w in ws for w in (
                'function', 'package', 'renames', 'generic', 'task', 'protected', 'record')):
            return []
        if any(w == 'type' and (i == 0 or ws[i - 1] not in ('use', 'all'))
               for i, w in enumerate(ws)):
            return []
        uses, imports, shadows, candidates = [], set(), set(), set()
        package_names = set()
        unknown_use = False
        first_body = min((i for i, w in enumerate(ws) if w in ('begin', 'declare')),
                         default=len(ws))

        def name_at(i):
            if i >= len(ts) or ts[i][3] != 'identifier':
                return None
            start = i
            while i + 2 < len(ws) and ws[i + 1] == '.' and ts[i + 2][3] == 'identifier':
                i += 2
            return ''.join(ws[start:i + 1]), start, i

        for i, word in enumerate(ws):
            if word in ('with', 'use'):
                j = i + 1
                if word == 'use' and ws[j:j + 1] == ['all']:
                    j += 1
                if ws[j:j + 1] == ['type']:
                    item = name_at(j + 1)
                    if item:
                        candidates.add((item[1], item[2]))
                    continue
                # Local use scopes are not modeled by this bounded resolver.
                if i >= first_body:
                    return []
                while (item := name_at(j)) is not None:
                    name, _, end = item
                    if word == 'with':
                        imports.add(name)
                        package_names.add(name.rsplit('.', 1)[-1])
                        imports.update(name.rsplit('.', n)[0] for n in range(1, name.count('.') + 1))
                    else:
                        uses.append((i, name))
                        unknown_use |= name not in self.names or name not in imports
                    j = end + 1
                    if ws[j:j + 1] != [',']:
                        break
                    j += 1
            if word in ('procedure', 'subtype', 'for') and i + 1 < len(ws):
                shadows.add(ws[i + 1])
            if word == ':' and i:
                # Defining-name list, not a selector or arbitrary expression.
                j = i - 1
                defining = []
                while j >= 0 and ts[j][3] == 'identifier':
                    defining.append(ws[j])
                    if j < 2 or ws[j - 1] != ',':
                        break
                    j -= 2
                shadows.update(defining)
                if defining and (j == 0 or ws[j - 1] in (';', 'is', 'declare', '(')):
                    k = i + 1
                    while k < len(ws) and ws[k] in ('constant', 'aliased', 'in', 'out', 'not', 'null', 'access'):
                        k += 1
                    item = name_at(k)
                    if item:
                        candidates.add((item[1], item[2]))
            if word == 'subtype' and ws[i + 2:i + 3] == ['is']:
                item = name_at(i + 3)
                if item:
                    candidates.add((item[1], item[2]))
            # A resolved type followed by '(' or "'(" is a conversion or
            # qualification. Function names cannot resolve as public types.
            if ts[i][3] == 'identifier' and (i == 0 or ws[i - 1] not in ('.', "'")):
                item = name_at(i)
                if item and (ws[item[2] + 1:item[2] + 2] == ['('] or
                             source[ts[item[2]][2]:].lstrip().startswith("'(")):
                    candidates.add((item[1], item[2]))

        result = []
        for start, end in sorted(candidates):
            name = ''.join(ws[start:end + 1])
            if ws[end + 1:end + 2] in (['.'], ['..']):
                continue
            if name.split('.')[0] in shadows:
                continue
            if '.' in name:
                owner, _, _ = name.rpartition('.')
                identities = [name] if owner in imports else []
            else:
                if unknown_use or name in package_names or name in STANDARD:
                    continue
                identities = []
                for position, owner in uses:
                    if position < start:
                        identities.extend(d['scope'].lower()
                                          for d in self.names[owner].get(name, []))
                identities = list(dict.fromkeys(identities))
            if len(identities) != 1 or identities[0] not in self.destinations:
                continue
            identity = identities[0]
            owner, _, simple = identity.rpartition('.')
            declarations = self.names.get(owner, {}).get(simple, [])
            if len(declarations) != 1 or declarations[0]['signature'].split()[0] not in ('type', 'subtype'):
                continue
            result.append((ts[start][1], ts[end][2], identity))
        return result

    def render(self, source, prefix=''):
        pieces, cursor = [], 0
        for start, end, identity in self.references(source):
            destination = self.destinations[identity]
            if not destination.startswith('https://'):
                destination = prefix + destination
            target = ' target="_top"' if destination.startswith('https://') else ''
            pieces.extend((html.escape(source[cursor:start], quote=False),
                           f'<a class="type-reference" href="{destination}" '
                           f'data-type="{identity}"{target}>' +
                           html.escape(source[start:end], quote=False) + '</a>'))
            cursor = end
        pieces.append(html.escape(source[cursor:], quote=False))
        rendered = highlight(''.join(pieces))
        require(html.unescape(plain(strip_highlighting(rendered))) == source,
                'example source round-trip failure')
        return ('<pre class="ada-example" tabindex="0" role="region" '
                'aria-label="Ada example"><code class="language-ada">' +
                rendered + '</code></pre>')

    def verify(self, source, rendered, prefix=''):
        """No generated markup, manifest or matching text can authorize links."""
        require(rendered == self.render(source, prefix),
                'example source/type identity/destination/markup mismatch')


def landing(root, renderer):
    template = (Path(root) / 'docs/index.html').read_text(encoding='utf-8')
    require(template.count(LANDING_MARKER) == 1, 'missing/duplicated landing example marker')
    source = (Path(root) / 'docs/example.adb').read_text(encoding='utf-8')
    return template.replace(LANDING_MARKER, renderer.render(source)).encode('utf-8')


def validate_landing(root, site, core=CORE_ROOT):
    renderer = ExampleRenderer(site, root, core)
    require((Path(site) / 'index.html').read_bytes() == landing(root, renderer),
            'authoritative landing/example markup mismatch')


if __name__ == '__main__':
    import sys
    root = Path(__file__).resolve().parent.parent
    require(len(sys.argv) == 2, 'usage: render_gnatdoc_examples.py SITE')
    site = Path(sys.argv[1])
    (site / 'index.html').write_bytes(landing(root, ExampleRenderer(site, root)))