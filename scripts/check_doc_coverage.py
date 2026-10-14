#!/usr/bin/env python3
"""Measure public API documentation coverage by declaration identity.

The expected inventory comes from the visible part of every `src/*.ads`
specification, never from the generated HTML:

- the package description;
- every visible-part declaration, identified by package, kind, name and, for
  subprograms, the complete normalized profile, so each overload is separate;
- every parameter of every subprogram and the return value of every function;
- every enumeration literal; every record component and discriminant.

Documentation is read from the native GNATdoc 26.0.0 section of that exact
declaration. The members GNATdoc lists must be exactly the source members, in
order. Each item needs text of at least two words that is not merely its own
name, so an empty `@param` or a copied identifier does not count.

Every visible-part comment block must also be attached: it must immediately
precede the package or a declaration, with no blank line, or be the first
block inside the package followed by a blank line (the package description
layout GNATformat accepts). Every line of it must render inside that package
description or declaration section. A detached block, or one that does not
render where it belongs, fails.

Undocumented items are compared with a structured baseline as a ratchet: a
new undocumented item always fails, and with --fail-on-removed a baseline
that still lists a documented item fails too. Attachment errors and member
mismatches are never baselined.
"""

import argparse
import collections
import html
import re
import sys
from pathlib import Path

from compare_gnatdoc_warnings import WarningComparisonError, declaration_index
from validate_docs import (
    NATIVE_PAGE,
    PACKAGE_RE,
    SECTION_RE,
    Page,
    _kind,
    _profile,
    code_tokens,
)

ROOT = Path(__file__).resolve().parent.parent
TAG_RE = re.compile(r"@(param|field|enum|exception|formal)\s+(\S+)\s*|@return\s*")
H5_RE = re.compile(r"<h5>([^<]+)</h5><dl>(.*?)</dl>", re.S)
ENTRY_RE = re.compile(r"<dt>(.*?)<dd>(.*?)(?=<dt>|\Z)", re.S)


class CoverageError(Exception):
    """The coverage inventory cannot be established safely."""


def _text(fragment):
    """Visible text; inline markup joins its neighbours, block markup separates."""
    fragment = re.sub(r"</?(?:code|em|strong|a|span)\b[^>]*>", "", fragment)
    return " ".join(html.unescape(re.sub(r"<[^>]+>", " ", fragment)).split())


def _documented(text, name=None):
    words = text.split()
    if len(words) < 2:
        return False
    return name is None or text.rstrip(".").strip() != name


def parameter_names(signature):
    """Parameter names of a normalized subprogram profile, in order."""
    start = signature.find("(")
    head = signature[:start] if start >= 0 else signature
    if start < 0 or " return " in head:
        return []
    depth, part, parts = 0, [], []
    for character in signature[start + 1:]:
        if character == "(":
            depth += 1
        elif character == ")":
            if depth == 0:
                break
            depth -= 1
        elif character == ";" and depth == 0:
            parts.append("".join(part))
            part = []
            continue
        part.append(character)
    parts.append("".join(part))
    names = []
    for item in parts:
        if " : " not in item:
            raise CoverageError(f"unsupported parameter specification: {item}")
        names.extend(n.strip() for n in item.split(" : ", 1)[0].split(","))
    return names


def discriminant_names(signature):
    """Discriminants of `type T (A : X; B : Y) is ...`, in order."""
    match = re.match(r"type \S+ \((.*?)\) is\b", signature)
    if match is None:
        return []
    return [name.strip()
            for item in match[1].split(";")
            for name in item.split(" : ", 1)[0].split(",")]


def specification(path):
    """Return (package, lines, private line, declarations, members by scope)."""
    lines = path.read_text(encoding="utf-8").splitlines()
    code = [code_tokens(line) for line in lines]
    header = next((number for number, text in enumerate(code, start=1)
                   if PACKAGE_RE.match(text)), None)
    if header is None:
        raise CoverageError(f"no package declaration in {path.name}")
    package = PACKAGE_RE.match(code[header - 1])[1]
    private = next((number for number, text in enumerate(code, start=1)
                    if text.strip().lower() == "private"), len(lines) + 1)
    try:
        index = declaration_index(lines)
    except WarningComparisonError as error:
        raise CoverageError(f"{path.name}: {error}") from error
    visible = [d for ds in index.values() for d in ds if d["start"] < private]
    top = sorted((d for d in visible
                  if d["scope"] == f"{package}.{d['name']}"),
                 key=lambda d: d["start"])
    members = collections.defaultdict(list)
    for declaration in sorted(visible, key=lambda d: (d["start"], d["column"])):
        owner = declaration["scope"].rpartition(".")[0]
        if owner != package and owner.startswith(package + "."):
            members[owner].append(declaration)
    return package, lines, header, private, top, members


def expected_items(declaration, members):
    """Return (heading, expected member names) for one declaration."""
    kind = _kind(declaration["signature"])
    scope = declaration["scope"]
    if kind in ("function", "procedure"):
        items = [("Parameters", parameter_names(declaration["signature"]))]
        if kind == "function":
            items.append(("Return Value", [None]))
        return [(heading, names) for heading, names in items if names]
    if kind == "type":
        names = [m["name"] for m in members.get(scope, [])]
        if " is (" in declaration["signature"] or (
                declaration["signature"].endswith(" is") and names):
            if "record" not in declaration["signature"]:
                return [("Enumeration Literal", names)] if names else []
        discriminants = discriminant_names(declaration["signature"])
        fields = discriminants + [n for n in names if n not in discriminants]
        return [("Record fields", fields)] if fields else []
    return []


def rendered_sections(page_html):
    """Map (name, kind, profile) -> list of (description, {heading: entries})."""
    sections = collections.defaultdict(list)
    for match in SECTION_RE.finditer(page_html):
        name = html.unescape(match[2])
        snippet = " ".join(html.unescape(re.sub(r"<[^>]+>", "", match[3])).split())
        if re.match(rf"{re.escape(name)}\s*:", snippet):
            kind = "object"
        else:
            kind = _kind(snippet)
        profile = _profile(snippet) if kind in ("function", "procedure") else None
        body = match[4]
        first = body.find("<h5>")
        description = _text(body if first < 0 else body[:first])
        groups = {}
        for heading, entries in H5_RE.findall(body):
            if heading == "Return Value":
                groups[heading] = [(None, _text(re.sub(r"^\s*<dd>", "", entries)))]
            else:
                groups[heading] = [(_text(dt), _text(dd))
                                   for dt, dd in ENTRY_RE.findall(entries)]
        sections[(name, kind, profile)].append(
            {"description": description, "groups": groups, "text": _text(body)})
    return sections


def _rendered_units(lines):
    """Split a comment block into the text runs GNATdoc renders contiguously.

    The description precedes the first tag; each `@param`, `@return`,
    `@exception`, `@enum` or `@field` item renders as its name followed by
    its text. List markers and code-span backticks do not render as text,
    except inside an indented code block (five or more spaces after `--`),
    which renders verbatim.
    """
    units, current = [], []
    for line in lines:
        raw = line.strip()[2:]
        body = raw.strip()
        if raw.startswith("     "):
            current.append(body)
            continue
        if body.startswith("@"):
            units.append(current)
            current = []
            body = TAG_RE.sub(lambda m: (m[2] or "") + " ", body, count=1)
        body = re.sub(r"^(?:[-*]|\d+\.)\s+", "", body)
        current.append(body.replace("`", ""))
    units.append(current)
    return [" ".join(" ".join(unit).split()) for unit in units if "".join(unit).strip()]


MEMBER_KINDS = {"Parameters": "parameter", "Return Value": "return",
                "Enumeration Literal": "literal", "Record fields": "component"}


def check_site(site, root=ROOT):
    """Return ({identity: item kind}, missing identities, errors)."""
    site = Path(site).resolve()
    api = site / "api"
    pages = {}
    for path in api.glob("*.html"):
        if NATIVE_PAGE.fullmatch(path.name):
            headings = Page(path).headings
            if len(headings) == 1:
                pages[headings[0]] = path.read_text(encoding="utf-8")
    items, missing, errors = {}, [], []

    def record(identity, kind, documented):
        if identity in items:
            errors.append(f"duplicate documentation item: {identity}")
        items[identity] = kind
        if not documented:
            missing.append(identity)

    for spec in sorted((Path(root) / "src").glob("*.ads")):
        package, lines, header, private, top, members = specification(spec)
        if package not in pages:
            errors.append(f"{package}: package page missing")
            continue
        page = pages[package]
        start = page.find("<h2>Description</h2>")
        first = page.find("<h4 ", start)
        if start < 0:
            errors.append(f"{package}: package description heading missing")
            continue
        description = _text(page[start + len("<h2>Description</h2>"):
                                  first if first >= 0 else len(page)])
        record(f"{package}: package: description", "package", _documented(description))
        sections = rendered_sections(page)
        by_start = {}
        for declaration in top:
            kind = _kind(declaration["signature"])
            profile = (_profile(declaration["signature"])
                       if kind in ("function", "procedure") else None)
            key = (declaration["name"], kind, profile)
            found = sections.get(key, [])
            label = f"{package}: {profile or kind + ' ' + declaration['name']}"
            if len(found) != 1:
                errors.append(f"{label}: expected one native section, found {len(found)}")
                continue
            section = found[0]
            by_start[declaration["start"]] = section
            record(f"{label}: description", kind, _documented(section["description"]))
            expected = expected_items(declaration, members)
            headings = {heading for heading, _ in expected}
            for heading in section["groups"]:
                if heading not in headings and heading != "Raised exceptions":
                    errors.append(f"{label}: unexpected rendered group {heading}")
            for heading, names in expected:
                entries = section["groups"].get(heading)
                if entries is None or [n for n, _ in entries] != names:
                    errors.append(
                        f"{label}: {heading} differ from source: "
                        f"expected {names}, rendered "
                        f"{None if entries is None else [n for n, _ in entries]}")
                    continue
                item = MEMBER_KINDS[heading]
                for name, text in entries:
                    identity = f"{label}: {item}" + (f" {name}" if name else "")
                    record(identity, item, _documented(text, name))
            for name, text in section["groups"].get("Raised exceptions", []):
                if not _documented(text, name):
                    errors.append(f"{label}: exception {name} lacks text")
        errors.extend(_attachment_errors(package, lines, header, private, top,
                                         by_start, description))
    return items, missing, errors


def _attachment_errors(package, lines, header, private, top, by_start, description):
    errors = []
    starts = {d["start"] for d in top}
    block = []
    for number, line in enumerate(lines[:private - 1], start=1):
        if line.strip().startswith("--"):
            block.append(number)
            continue
        if not block:
            continue
        first, last = block[0], block[-1]
        units = _rendered_units(lines[first - 1:last])
        target = last + 1
        # GNATdoc also takes the package description from the first block
        # inside the package when a blank line separates it from the next
        # declaration; GNATformat requires that layout.
        opening = (first > header
                   and all(not text.strip() for text in lines[header:first - 1])
                   and not lines[last].strip())
        if target == header or opening:
            text = description
        elif target in starts:
            section = by_start.get(target)
            text = None if section is None else section["text"]
        else:
            errors.append(f"{package}: detached comment at lines {first}-{last}")
            block = []
            continue
        if text is not None and not all(unit in text for unit in units):
            errors.append(
                f"{package}: comment at lines {first}-{last} does not render "
                f"in the declaration it precedes (line {target})")
        block = []
    return errors


def parse_baseline(text):
    entries = []
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        if ": " not in line:
            raise CoverageError(f"baseline:{number}: malformed entry: {line}")
        entries.append(line)
    return entries


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("baseline", type=Path)
    parser.add_argument("site", type=Path)
    parser.add_argument("--write-baseline", action="store_true",
                        help="Record the current undocumented items")
    parser.add_argument("--fail-on-removed", action="store_true",
                        help="Fail when the baseline lists documented items")
    parser.add_argument("--report", action="store_true",
                        help="Print coverage by item kind")
    parser.add_argument("--root", type=Path, default=ROOT,
                        help="Repository whose src/*.ads define the inventory")
    args = parser.parse_args(argv)
    try:
        items, missing, errors = check_site(args.site, args.root)
        if errors:
            raise CoverageError("\n".join(errors))
        if args.write_baseline:
            args.baseline.write_text(
                "".join(entry + "\n" for entry in missing), encoding="utf-8")
            print(f"Wrote {len(missing)} undocumented item identities")
            return 0
        baseline = parse_baseline(args.baseline.read_text(encoding="utf-8"))
    except (CoverageError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    added = sorted((collections.Counter(missing) - collections.Counter(baseline)).elements())
    removed = sorted((collections.Counter(baseline) - collections.Counter(missing)).elements())
    kinds = collections.Counter(items.values())
    gaps = collections.Counter(items[identity] for identity in missing)
    documented = len(items) - len(missing)
    print(f"Documentation coverage: {documented}/{len(items)} items "
          f"({100.0 * documented / len(items):.1f}%); "
          f"{len(added)} newly undocumented, {len(removed)} newly documented")
    if args.report:
        for kind in sorted(kinds):
            print(f"  {kind}: {kinds[kind] - gaps[kind]}/{kinds[kind]}")
    for identity in added:
        print("undocumented: " + identity)
    for identity in removed:
        print("documented: " + identity)
    if added:
        return 1
    if removed and args.fail_on_removed:
        print("error: items were documented; regenerate the baseline with "
              "--write-baseline so they cannot silently regress", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
