#!/usr/bin/env python3
"""Operation-level API browser for the single-package Imgproc reference.

Core's browser searches 195 packages; Imgproc publishes one package with 314
declarations, so the useful unit of navigation is the declaration. Only the
native GNATdoc 26.0.0 index changes, and only by:

- one hidden search control group, revealed by the script;
- a static list of every visible-part declaration, grouped in collapsible
  categories, each entry a link to its verified native anchor in the
  documentation frame, so navigation works without JavaScript;
- one deferred repository-owned script (search, selection, bookmarks).

Entries derive from the public specification (names, kinds, profiles and
overload order), the reviewed category manifest `docs/api-categories.json`
(every public declaration name in exactly one category, no unknown names) and
anchors discovered from source-matched native sections. No filename or anchor
is computed. The native index must match the pinned serialization before it
is augmented; repeat enhancement is byte-idempotent.
"""

import argparse
import html
import json
import re
import sys
from collections import Counter
from pathlib import Path

from link_gnatdoc_types import SECTION, Source, plain, require

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "docs/assets/gnatdoc-navigation.js"
CATEGORIES = ROOT / "docs/api-categories.json"
SCRIPT = '<script src="gnatdoc-navigation.js" defer></script>'
CONTROL = (
    '<div id=api-search-controls hidden><label for=api-search>Search operations '
    'and types</label><input id=api-search type=search autocomplete=off '
    'spellcheck=false aria-describedby=api-results><button id=api-clear '
    'type=button>Clear</button><p id=api-results role=status aria-live=polite>'
    '</p></div>')
INDEX_START = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=main><div class=side-navigation><ul class=tab-bar>"
    "<li class=tab><a href=#compilation-units>Compilation Units</a>"
    "<li class=tab><a href=#tagged-types>Tagged Types</a></ul>"
    "<div class=content-column><h2 id=compilation-units>Compilation Units</h2><ul>")
INDEX_END = (
    "</ul><h2 id=tagged-types>Tagged types</h2><ul></ul></div></div>"
    "<div class=document-content><iframe name=document-content></iframe></div>")


def load_categories(path=CATEGORIES):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    require(data.get("version") == 1, "unexpected category manifest version")
    categories = data.get("categories")
    require(isinstance(categories, list) and categories, "empty category manifest")
    owner = {}
    for category in categories:
        require(re.fullmatch(r"[a-z][a-z-]*", category.get("id", "")),
                "invalid category id")
        require(category.get("title") and category.get("declarations"),
                f"incomplete category: {category.get('id')}")
        for name in category["declarations"]:
            require(name not in owner, f"declaration in two categories: {name}")
            owner[name] = category["id"]
    return categories, owner


def entries(api, source_root=ROOT / "src", categories_path=CATEGORIES):
    """Return (package page name, categories with their verified entries)."""
    source = Source(Path(source_root))
    categories, owner = load_categories(categories_path)
    names = {d["name"] for d in source.top}
    require(set(owner) == names,
            "category manifest does not match the public declarations: missing "
            f"{sorted(names - set(owner))}, unknown {sorted(set(owner) - names)}")
    pages = [p for p in sorted(Path(api).glob("*.html")) if p.name != "index.html"]
    require(len(pages) == 1 and re.fullmatch(r"[0-9a-f]{64}\.html", pages[0].name),
            "unsupported native package page set")
    from highlight_gnatdoc_ada import strip_highlighting
    text = pages[0].read_text(encoding="utf-8")
    require(re.findall(r"<h1>([^<]+)</h1>", text) == ["OpenCV.Image_Processing"],
            "noncanonical native package heading")
    anchors = {}
    for section in SECTION.finditer(text):
        declaration = source.match(plain(strip_highlighting(section[3])))
        require(section[2] == declaration["name"], "section heading/source mismatch")
        key = (declaration["start"], declaration["name"])
        require(key not in anchors, "duplicate native section")
        anchors[key] = section[1]
    require(len(anchors) == len(source.top), "native section coverage mismatch")
    totals = Counter(d["name"] for d in source.top)
    seen = Counter()
    grouped = {category["id"]: [] for category in categories}
    titles = {category["id"]: category["title"] for category in categories}
    for declaration in source.top:
        name = declaration["name"]
        seen[name] += 1
        kind = declaration["signature"].split()[0]
        kind = kind if kind in ("function", "procedure", "type", "subtype") else "constant"
        profile = " ".join(declaration["signature"].split()).replace(" : =", " :=")
        grouped[owner[name]].append({
            "name": name, "kind": kind, "profile": profile.rstrip(";"),
            "overload": seen[name] if totals[name] > 1 else 0,
            "overloads": totals[name],
            "href": f"{pages[0].name}#{anchors[(declaration['start'], name)]}",
            "category": titles[owner[name]],
        })
    for category in categories:
        grouped[category["id"]].sort(key=lambda e: (e["name"].lower(), e["overload"]))
    return pages[0].name, [(c["id"], c["title"], grouped[c["id"]]) for c in categories]


def _entry(item):
    detail = item["kind"]
    if item["overload"]:
        detail += f", overload {item['overload']} of {item['overloads']}"
    search = " ".join([item["name"], item["kind"], item["category"], item["profile"]]).lower()
    attributes = f' data-op="{item["name"]}"'
    if item["overload"]:
        attributes += f' data-overload="{item["overload"]}"'
    return (f'<li{attributes} data-search="{html.escape(search)}">'
            f'<a href={item["href"]} target=document-content '
            f'title="{html.escape(item["profile"])}">{item["name"]}'
            f'<span class=entry-detail> {detail}</span></a>')


def browser(groups):
    parts = ['<nav id=api-browser aria-labelledby=api-browser-heading>',
             CONTROL, '<h2 id=api-browser-heading>Public API</h2>']
    for identity, title, items in groups:
        parts.append(f'<details class=api-category data-category={identity}>'
                     f'<summary>{html.escape(title)} <span class=api-count>'
                     f'({len(items)})</span></summary><ul>')
        parts.extend(_entry(item) for item in items)
        parts.append('</ul></details>')
    parts.append('</nav>')
    return "".join(parts)


def native_index(api):
    page, groups = entries(api)
    native = (INDEX_START + f"<li><a href={page} target=document-content>"
              "OpenCV.Image_Processing</a>" + INDEX_END)
    return native, groups


def augmented(text, api):
    """The approved navigation index for a native (themed) index text."""
    _, groups = native_index(api)
    marker = "<h2 id=compilation-units>"
    require(text.count(marker) == 1 and text.count("<body class=main>") == 1,
            "unsupported native index structure")
    return (text.replace(marker, browser(groups) + marker, 1)
                .replace("<body class=main>", SCRIPT + "<body class=main>", 1))


def check_navigation(api):
    from install_gnatdoc_theme import themed
    native, groups = native_index(api)
    require((api / "index.html").read_text(encoding="utf-8") ==
            augmented(themed(native), api),
            "unapproved navigation shell, links, controls or scripts")
    require((api / "gnatdoc-navigation.js").read_bytes() == ASSET.read_bytes(),
            "navigation asset differs from repository script")
    return sum(len(items) for _, _, items in groups)


def enhance(api):
    from install_gnatdoc_theme import themed
    api = Path(api).resolve()
    native, _ = native_index(api)
    path = api / "index.html"
    current = path.read_text(encoding="utf-8")
    expected = augmented(themed(native), api)
    if current != expected:
        require(current == themed(native), "unsupported native index structure")
        path.write_text(expected, encoding="utf-8")
        (api / "gnatdoc-navigation.js").write_bytes(ASSET.read_bytes())
    count = check_navigation(api)
    print(f"Navigation: {count} declarations in browsable categories; "
          "native anchors verified")
    return count


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("api", type=Path)
    args = parser.parse_args(argv)
    from link_gnatdoc_types import CrossReferenceError
    try:
        enhance(args.api)
    except (CrossReferenceError, OSError, ValueError) as error:
        print(f"error: navigation: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
