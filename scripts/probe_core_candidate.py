#!/usr/bin/env python3
"""Exercise an unapproved Core mapping without promoting a production site.

The full per-token ledger must match both identity and decoded snippet offset;
a matching total cannot conceal a dropped, duplicated or reassigned link.
"""
from __future__ import annotations

import argparse
from collections import Counter
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
import subprocess

from install_released_gnatdoc import checked_tool, digest, require
from link_gnatdoc_types import SECTION, Source, package_page
from qualify_released_gnatdoc import Operations, expected_operations, hashes, write

ROOT = Path(__file__).resolve().parents[1]


class SnippetLinks(HTMLParser):
    def __init__(self, raw):
        super().__init__(convert_charrefs=True)
        self.text_offset = 0
        self.current = None
        self.links = []
        self.text = ""
        self.feed(raw)
        require(self.current is None, "unclosed snippet link")

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "a":
            require(self.current is None, "nested type link")
            self.current = {"start": self.text_offset, "identity": attributes.get("data-type"),
                            "href": attributes.get("href"), "target": attributes.get("target"),
                            "label": ""}

    def handle_data(self, text):
        self.text_offset += len(text)
        self.text += text
        if self.current is not None:
            self.current["label"] += text

    def handle_endtag(self, tag):
        if tag == "a":
            require(self.current is not None, "unexpected closing link")
            self.current["end"] = self.text_offset
            self.links.append(self.current)
            self.current = None


def reconcile(native, candidate, ledger):
    source = Source(ROOT / "src")
    original = package_page(native / "api", source)
    path = candidate / "api" / original.name
    before = list(SECTION.finditer(original.read_text()))
    after = list(SECTION.finditer(path.read_text()))
    require(len(before) == len(after) == 329, "native section inventory mismatch")
    actual, local = {}, []
    for a, b in zip(before, after):
        parsed = SnippetLinks(b[3])
        require((a[1], a[2], html.unescape(a[3])) == (b[1], b[2], parsed.text),
                "native declaration anchors, order, headings or snippets changed")
        for link in parsed.links:
            key = b[1] + ":" + str(link["start"])
            record = {"native_anchor": b[1], **link}
            if link["href"].startswith("https:"):
                require(key not in actual, "duplicate Core occurrence")
                actual[key] = record
            else:
                local.append(record)
    expected = {item["occurrence_id"]: item for item in ledger["occurrences"]}
    require(len(expected) == len(actual) == 586 and actual.keys() == expected.keys(),
            "Core occurrence identities differ")
    for key, item in expected.items():
        observed = actual[key]
        require(observed["identity"] == item["core_identity"] and
                observed["href"] == item["proposed_url"] and
                observed["start"] == item["type_mark_start"] and
                observed["end"] == item["type_mark_end"] and
                observed["label"] == item["type_mark"], "Core occurrence reassigned: " + key)
    require(len(local) == 350, "shared local occurrence count differs")
    old = {(x["declaration_anchor"], x["offset"], x["identity"], x["url"].split("#")[-1])
           for x in ledger["legacy_local_occurrences"]}
    current = {(x["native_anchor"], x["start"], x["identity"], x["href"].split("#")[-1])
               for x in local}
    require(old <= current, "legacy local type occurrence lost or reassigned")
    additions = [x for x in local if (x["native_anchor"], x["start"], x["identity"],
                                      x["href"].split("#")[-1]) not in old]
    require(len(additions) == 2, "unexpected local link additions")
    declarations = {s[1]: source.match(s[3]) for s in before}
    expected_additions = {"Background_Label": "Component_Label",
                          "Default_Morphology_Border": "Morphology_Border_Value"}
    targets = {d["name"]: (anchor, d) for anchor, d in declarations.items()
               if d["signature"].split()[0] in {"type", "subtype"}}
    for addition in additions:
        owner = declarations[addition["native_anchor"]]
        require(owner["name"] in expected_additions, "unapproved new local owner")
        target_name = expected_additions[owner["name"]]
        anchor, target = targets[target_name]
        require(addition["label"] == target_name and
                addition["identity"] == source.package + "." + target_name.lower() and
                addition["href"] == original.name + "#" + anchor and
                target["start"] < owner["start"], "new local link is not source-owned type mark")
        # Source assertions independent of enhancement output: these are public
        # constant declarations whose sole type mark is the target public type.
        full = "\n".join(source.lines[owner["start"] - 1:owner["end"]])
        require(re.match(r"\s*" + owner["name"] + r"\s*:\s*constant\s+" + target_name + r"\b",
                         full), "additional local reference not a defining constant type mark")
        addition["source_declaration"] = owner
        addition["target_declaration"] = target
        addition["classification"] = "source-proven public constant type-mark improvement; proposal for review"
    return {"core_occurrences": len(actual), "core_distinct_types": len(ledger["types"]),
            "exact_identity_offset_label_url_parity": True,
            "external_target_attributes": dict(Counter(str(x["target"]) for x in actual.values())),
            "legacy_external_target": "_top",
            "local_occurrences": len(local), "preserved_local_occurrences": len(old),
            "local_additions": additions,
            "filename_fragment_equivalence": "All 348 old local destinations resolve to the same native page and anchor"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("proposal", "native", "venv", "workspace"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    workspace = args.workspace.absolute()
    require(not workspace.exists(), "candidate workspace must be new")
    workspace.mkdir()
    ledger = json.loads((args.proposal / "core-destination-proposal.json").read_text())
    require(ledger["approval"] is False and not ledger["unresolved"], "unexpected Core policy state")
    source = workspace / "source"
    (source / "qualification-public").mkdir(parents=True)
    shutil.copyfile(ROOT / "src/opencv-image_processing.ads", source / "qualification-public/opencv-image_processing.ads")
    shutil.copyfile(ROOT / "docs/api-categories.json", source / "categories.json")
    shutil.copyfile(args.proposal / "candidate.toml", source / "candidate.toml")
    logs = []

    def execute(command, site):
        tool, installed = checked_tool(args.venv.absolute())
        write(workspace / "installed-identity.json", installed)
        command_line = [str(tool), command, "--config", "candidate.toml", "--source-root", str(source),
                        "--site", str(site)]
        result = subprocess.run(command_line, capture_output=True, text=True)
        logs.append({"command": command_line, "returncode": result.returncode,
                     "stdout": result.stdout, "stderr": result.stderr})
        write(workspace / "commands.json", logs)
        require(result.returncode == 0, "released command rejected candidate: " + result.stderr)

    first, second = workspace / "first", workspace / "second"
    execute("inventory", args.native.absolute())
    for candidate in (first, second):
        shutil.copytree(args.native, candidate)
        execute("enhance", candidate)
        execute("verify", candidate)
    report = reconcile(args.native, first, ledger)
    expected, _ = expected_operations(args.native / "api")
    require(Operations((first / "api/index.html").read_text()).links == expected,
            "operation category/order/overload/destination differs")
    before = hashes(first)
    require(before == hashes(second), "fresh enhancements differ")
    execute("enhance", first)
    require(before == hashes(first), "enhancement is not byte-idempotent")
    report.update({"fresh_equal": True, "byte_idempotent": True, "operations": len(expected),
                   "site_sha256": before, "production_enabled": False,
                   "disposition": "CORE_POLICY_REVIEW_REQUIRED"})
    write(workspace / "candidate-reconciliation.json", report)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()