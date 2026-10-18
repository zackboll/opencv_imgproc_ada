#!/usr/bin/env python3
"""Explicitly collect executed reports for review; NOT an authority generator.

Never changes authored.json, authority.json, configuration or dependency trust.
Run manually after qualification; CI retains full generated logs as artifacts.
"""
import argparse
from pathlib import Path
import shutil

from qualify_shared_gnatdoc_shadow import CURRENT_EVIDENCE, ROOT, digest, read_json, require, write_json


def collect(workspace, destination):
    require(workspace.is_dir(), "missing qualification workspace")
    destination.mkdir(parents=True, exist_ok=True)
    require(destination.resolve() == (ROOT / CURRENT_EVIDENCE).resolve(),
            "evidence collection must not rewrite historical GNATDOC-008")
    for source, target in (("qualification.json", "local-qualification.json"),
                           ("negative.json", "adversarial.json"),
                           ("navigation-comparison.json", "navigation-comparison.json"),
                           ("readiness.json", "readiness.json")):
        require((workspace / source).is_file(), f"missing executed evidence: {source}")
        shutil.copyfile(workspace / source, destination / target)
    browser = read_json(workspace / "browser.json")
    write_json(destination / "browser-history-traces.json", browser.get("history_traces", []))
    write_json(destination / "browser-summary.json", {
        "status": browser["status"], "executed": browser["executed"], "failures": browser["failures"],
        "original_assertions_retained": browser["original_assertions_retained"],
        "original_assertion_names_retained": browser["original_assertion_names_retained"],
        "additional_history_assertions": browser["additional_history_assertions"],
        "qualification_sha256": browser["qualification_sha256"],
        "chromium": browser["chromium"], "full_report_sha256": digest((workspace / "browser.json").read_bytes()),
        "full_report": "review-only CI artifact or retained local qualification workspace/browser.json",
        "assertion_names": sorted({c["name"] for c in browser["checks"]}),
        "dimensions": {k: sorted({c[k] for c in browser["checks"] if k in c})
                       for k in ("width", "theme", "javascript")},
        "failed_assertions": [c for c in browser["checks"] if c["status"] != "pass"],
        "production_https_verified": False,
    })
    native = read_json(workspace / "native-identities.json")
    write_json(destination / "native-anchor-inventory.json", {
        name: {k: value[k] for k in ("package", "ids", "declarations", "visible_text_sha256", "native_links")}
        for name, value in native.items()
    })
    commands = read_json_list(workspace / "commands.json")
    write_json(destination / "command-provenance.json", {
        "commands_sha256": digest((workspace / "commands.json").read_bytes()),
        "commands": commands,
        "full_logs": "review-only CI artifact; retained local workspace; each log SHA-256 is recorded",
    })


def read_json_list(path):
    import json
    return json.loads(path.read_text())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--destination", type=Path, default=ROOT / CURRENT_EVIDENCE)
    args = parser.parse_args()
    collect(args.workspace, args.destination)