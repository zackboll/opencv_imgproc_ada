#!/usr/bin/env python3
"""Additive R1 review handoff. Observed URLs are not publication approval."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess

from install_released_gnatdoc import digest, require
from qualify_released_gnatdoc import hashes, write

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True,
                          capture_output=True, text=True).stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--proposal", type=Path, required=True)
    args = parser.parse_args()
    destination = ROOT / "docs/evidence/gnatdoc009/r1"
    require(not (destination / "checkpoint.json").exists(), "R1 evidence already recorded")
    destination.mkdir(parents=True, exist_ok=True)
    proposal = json.loads((args.proposal / "core-destination-proposal.json").read_text())
    require(len(proposal["occurrences"]) == 586 and len(proposal["types"]) == 14 and
            not proposal["unresolved"] and proposal["approval"] is False,
            "incomplete or self-approved Core proposal")
    shutil.copyfile(args.proposal / "core-destination-proposal.json", destination / "core-destination-proposal.json")
    shutil.copyfile(args.proposal / "candidate.toml", destination / "candidate-proposal.toml")
    for name in ("candidate-reconciliation.json", "commands.json", "installed-identity.json"):
        shutil.copyfile(args.work / "candidate-verified" / name, destination / name)
    names = ("installed-recheck.json", "core-artifact-identity.json", "core-run.json",
             "core-deployment.json", "core-deployment-statuses.json", "initial-ci.json",
             "acquisition-start.json", "documentation-start.json", "shadow-start.json",
             "cross-platform-start.json", "acquisition-success.json",
             "starting-acquisition-artifacts.json", "core-build.log", "core-native.log",
             "legacy-generation.log", "core-mutation-tests-final.log", "release-controls.log",
             "compiled-examples.log", "shared-coverage.log", "warnings.log", "proposal.log",
             "candidate.log", "core-candidate-browser.json", "core-candidate-browser-full.json",
             "core-candidate-browser-observed.json", "core-candidate-browser-history.json",
             "core-candidate-browser-final.json")
    for name in names:
        shutil.copyfile(args.work / name, destination / name)
    browser = json.loads((args.work / "core-candidate-browser-final.json").read_text())
    candidate_config = (args.work / "candidate-verified/source/candidate.toml").read_bytes()
    require(candidate_config == (args.proposal / "candidate.toml").read_bytes(),
            "source-refreshed proposal differs from exercised candidate URLs")
    require(browser["status"] == "observation-pass-policy-not-approved" and not browser["failures"],
            "browser observation campaign did not complete")
    changes = browser["navigationDifferences"]
    require(changes and all(x["sharedTarget"] is None and x["outerUrlUnchanged"] for x in changes),
            "missing real-browser external target evidence")
    initial = "dc2cdb81754ca097fc586a85f2f75c4223704a00"
    unchanged = ["src", "cpp", "alire.toml", "scripts/install_released_gnatdoc.py",
                 "scripts/generate_docs.sh", "scripts/render_gnatdoc_examples.py",
                 "scripts/render_gnatdoc_guides.py", ".github/workflows/documentation.yml",
                 ".github/workflows/documentation-shared-shadow.yml",
                 "docs/evidence/gnatdoc008", "docs/evidence/gnatdoc008c"]
    require(not git("diff", "--name-only", initial, "--", *unchanged),
            "production, library, installer or historical authority changed")
    # Prior GNATDOC-009 reports remain exact; additions below r1 do not rewrite
    # the earlier evidence inventory or its recorded digests.
    old = json.loads((ROOT / "docs/evidence/gnatdoc009/evidence-sha256.json").read_text())
    require(all(digest((ROOT / "docs/evidence/gnatdoc009" / name).read_bytes()) == sha
                for name, sha in old.items()), "prior evidence rewritten")
    count = {identity: len(indices) for identity, indices in proposal["by_type"].items()}
    write(destination / "policy-review.json", {
        "disposition": "CORE_POLICY_REVIEW_REQUIRED", "production_enabled": False,
        "proposal_sha256": digest((destination / "core-destination-proposal.json").read_bytes()),
        "occurrences": 586, "counts_by_type": count, "unresolved_types": [],
        "source_native_hosted_identity_qualified": True,
        "material_navigation_changes": [
            "Every package-overview bookmark becomes a specific direct native declaration fragment",
            "All 586 external links lose legacy target=_top; Core loads inside Imgproc iframe",
            "Outer Imgproc bookmark continues naming Imgproc after cross-origin iframe navigation"],
        "browser_status": browser["status"], "policy_approved": False,
        "required_decision": "Independent review must explicitly approve changed external navigation semantics, or request a separately reviewed upstream capability preserving target=_top. No HTML rewriting or installed-tool patch is authorized.",
        "future_requalification": "Fail closed on changed indexed source, native type profile, artifact/deployment identity, hosted bytes, URL, occurrence ledger, or link-target behavior",
        "unversioned_hosting_is_immutable": False})
    write(destination / "checkpoint.json", {
        "disposition": "CORE_POLICY_REVIEW_REQUIRED", "ready": False,
        "starting_head": initial, "starting_tree": "c6723f998960431c1c4f0a9e631a528d56e825fa",
        "observed_main": git("rev-parse", "origin/main"),
        "observed_main_tree": git("rev-parse", "origin/main^{tree}"),
        "checkpoint_head": git("rev-parse", "HEAD"), "checkpoint_tree": git("rev-parse", "HEAD^{tree}"),
        "final_head_record": "PR checkpoint comment records final immutable head/tree and exact-head hosted status",
        "prior_evidence_preserved": True, "production_changed": False,
        "browser_assertion_records": len(browser["assertions"]),
        "browser_navigation_difference_records": len(changes),
        "not_performed": ["independent approval of material external-navigation policy changes",
            "complete authored/shared production site qualification and promotion",
            "complete shared production browser/security matrix", "qualified Imgproc Pages artifact equality",
            "post-merge publication and live acceptance"],
        "downloaded_starting_acquisition_artifact": {
            "id": 12321453034, "sha256": digest((args.work / "starting-acquisition.zip").read_bytes()),
            "scope": "Starting-head release installation receipts only, not a production candidate"}})
    write(destination / "sha256.json", {k: v for k, v in hashes(destination).items() if k != "sha256.json"})


if __name__ == "__main__":
    main()