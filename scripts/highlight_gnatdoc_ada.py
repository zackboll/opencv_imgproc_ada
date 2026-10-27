#!/usr/bin/env python3
"""Deterministic Ada lexical coloring; existing type anchors remain atomic."""

import argparse
import os
import re
from pathlib import Path

from link_gnatdoc_types import LINK, decoded_offsets, plain, process, require


KEYWORDS = set('''abort abs abstract accept access aliased all and array at begin
body case constant declare delay delta digits do else elsif end entry exception
exit for function generic goto if in interface is limited loop mod new not null
of or others out overriding package parallel pragma private procedure protected
raise range record rem renames requeue return reverse select separate some subtype
synchronized tagged task terminate then type until use when while with xor'''.split())
CLASSES = {'keyword', 'number', 'string', 'character', 'attribute', 'comment', 'operator'}
LEXEME = re.compile(
    r'(?P<comment>--[^\n]*)|(?P<string>"(?:[^"\n]|"")*")|'
    r"(?P<character>'[^\n]')|(?P<attribute>'[A-Za-z][A-Za-z0-9_]*)|"
    r'(?P<number>[0-9][0-9_]*\#[0-9A-Fa-f_]+(?:\.[0-9A-Fa-f_]+)?\#'
    r'(?:[Ee][+-]?[0-9][0-9_]*)?|[0-9][0-9_]*(?:\.(?!\.)[0-9][0-9_]*)?'
    r'(?:[Ee][+-]?[0-9][0-9_]*)?)|'
    r'(?P<identifier>[A-Za-z][A-Za-z0-9_]*)|'
    r'(?P<operator>:=|=>|\.\.|\*\*|/=|<=|>=|<>|[&+*/=<>:;,.()|\-])')
SPAN = re.compile(r'<span class="ada-(' + '|'.join(sorted(CLASSES)) + r')">([^<]*)</span>')


def strip_highlighting(raw):
    """Remove only exact flat approved spans; plain() rejects all other tags."""
    return SPAN.sub(lambda match: match[2], raw)


def highlight_text(raw):
    text, starts, ends = decoded_offsets(raw)
    inserts = []
    for match in LEXEME.finditer(text):
        category = match.lastgroup
        if category == 'identifier':
            if match.group().lower() not in KEYWORDS:
                continue
            category = 'keyword'
        start, end = starts[match.start()], ends[match.end() - 1]
        inserts.append((start, end, f'<span class="ada-{category}">{raw[start:end]}</span>'))
    for start, end, markup in reversed(inserts):
        raw = raw[:start] + markup + raw[end:]
    return raw


def highlight(raw):
    """Color only plain intervals, never tags, attributes or anchor contents."""
    original = plain(raw)
    result, cursor = [], 0
    for link in LINK.finditer(raw):
        result.extend((highlight_text(raw[cursor:link.start()]), link[0]))
        cursor = link.end()
    result.append(highlight_text(raw[cursor:]))
    rendered = ''.join(result)
    require(plain(strip_highlighting(rendered)) == original,
            'Ada highlighting text preservation failure')
    require([m[0] for m in LINK.finditer(rendered)] == [m[0] for m in LINK.finditer(raw)],
            'highlighting changed type links')
    return rendered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('api', type=Path)
    parser.add_argument('--core', type=Path,
                        default=Path(os.environ['DOC_CORE_SOURCE'])
                        if os.environ.get('DOC_CORE_SOURCE') else None)
    args = parser.parse_args()
    if args.core is None:
        parser.error('--core or DOC_CORE_SOURCE must identify the resolved indexed dependency')
    from install_gnatdoc_theme import check_theme
    check_theme(args.api)
    process(args.api, Path(__file__).resolve().parent.parent / 'src', args.core,
            highlight=True)


if __name__ == '__main__':
    main()