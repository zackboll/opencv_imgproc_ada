#!/usr/bin/env python3
"""Independent source-order navigation audit using the unchanged consumer oracle.

This intentionally rejects mislabeled/reordered genuine anchors: existence of
an anchor does not prove that an overload link denotes the advertised overload.
"""
import argparse
from html.parser import HTMLParser
from pathlib import Path
import sys

from qualify_shared_gnatdoc_shadow import require, write_json


class Links(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.links = []
        self.current = None
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and attrs.get("target") == "document-content" and "#" in attrs.get("href", ""):
            self.current = [attrs["href"], ""]

    def handle_data(self, text):
        if self.current is not None:
            self.current[1] += text

    def handle_endtag(self, tag):
        if tag == "a" and self.current is not None:
            self.links.append(self.current)
            self.current = None


def run(workspace):
    legacy = workspace / "legacy"
    sys.path.insert(0, str(legacy / "scripts"))
    from enhance_gnatdoc_navigation import entries
    _, groups = entries(legacy / "_site/api", legacy / "src", legacy / "docs/api-categories.json")
    expected = [entry for _, _, group in groups for entry in group]
    actual = Links((workspace / "first/_site/api/index.html").read_text()).links
    failures = []
    require(len(actual) == len(expected) == 314, "operation navigation inventory differs")
    labels = {href: label for href, label in actual}
    require(len(labels) == 314, "duplicate navigation destination")
    for entry in expected:
        label = entry["name"] + (f" ({entry['overload']})" if entry["overload"] else "")
        observed = labels.get(entry["href"])
        if observed != label:
            failures.append({"name": entry["name"], "source_order_overload": entry["overload"],
                             "source_profile": entry["profile"], "href": entry["href"],
                             "expected_shared_label": label, "observed_shared_label": observed,
                             "classification": "Incorrect output"})
    report = {"status": "fail" if failures else "pass", "operations": len(actual),
              "failures": failures, "oracle": "unchanged source-backed consumer entries()",
              "upstream_cause": "navigation.operation_entries uses len(resolved)+1 across a category, not per-name source-order overload numbering"}
    write_json(workspace / "navigation-comparison.json", report)
    require(not failures, f"{len(failures)} source-order overload labels are incorrect")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    args = parser.parse_args()
    try:
        run(args.workspace)
    except ValueError as exc:
        print(f"independent navigation comparison failed: {exc}", file=sys.stderr)
        sys.exit(1)