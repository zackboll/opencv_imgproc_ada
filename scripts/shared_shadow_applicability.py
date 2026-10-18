#!/usr/bin/env python3
"""Scope GNATDOC-008C to integration changes, never rebase its frozen authority.

Every PR gets an auditable decision. Applicable changes are overlaid onto the
immutable last GNATDOC-008C consumer, not onto feature production sources. The
unmodified historical qualifier must still pass every source/hash check.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HISTORICAL = "3722ac594c266741eb2735c99bb0cd21d165274d"
AUTHORITY_BASE = "9ce22ae5ab70008e1147475a9e6d7baef82f1df0"


def integration_path(name):
    path = PurePosixPath(name)
    return (name == ".github/workflows/documentation-shared-shadow.yml"
            or name.startswith("docs/evidence/")
            or name.startswith("docs/shared-gnatdoc-shadow")
            or name == "docs/shared-shadow-applicability.md"
            or (path.parent == PurePosixPath("scripts") and
                ("shared_gnatdoc" in path.name or "shared_shadow" in path.name)))


def git(root, *args):
    return subprocess.run(["git", *args], cwd=root, check=True,
                          capture_output=True).stdout


def revision(root, value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("expected full immutable Git SHA")
    actual = git(root, "rev-parse", "--verify", value + "^{commit}").decode().strip()
    if actual != value:
        raise ValueError("revision identity mismatch")
    return actual


def assess(root, base, head):
    base, head = revision(root, base), revision(root, head)
    if git(root, "rev-parse", "HEAD").decode().strip() != head:
        raise ValueError("checkout is not the exact PR head")
    # --no-renames lists both deleted and added paths, so renaming an
    # integration script to an ordinary path cannot evade applicability.
    changed = sorted(filter(None, git(root, "diff", "--no-renames", "--name-only",
                                     "-z", base + "..." + head).decode().split("\0")))
    matched = [name for name in changed if integration_path(name)]
    return {"schema_version": 1, "pr_base": base, "pr_head": head,
            "historical_consumer": HISTORICAL, "authority_base": AUTHORITY_BASE,
            "changed_paths": changed, "integration_paths": matched,
            "applicable": bool(matched),
            "disposition": "FULL_HISTORICAL_QUALIFICATION_REQUIRED" if matched else
                           "NOT_APPLICABLE_API_FEATURE",
            "reason": "Shadow integration or evidence changed" if matched else
                      "No shadow integration/evidence changes; current API is qualified "
                      "by the separate Ada API Documentation workflow",
            "historical_qualification_passed": False, "non_deployable": True}


def prepare(root, head, destination):
    """Prepare a source-bound historical run; cannot authorize any new hashes."""
    revision(root, head)
    revision(root, HISTORICAL)
    if destination.exists():
        raise ValueError("historical checkout must be new")
    git(root, "clone", "--no-hardlinks", "--no-checkout", str(root), str(destination))
    git(destination, "checkout", "--detach", HISTORICAL)
    current = set(git(root, "ls-tree", "-r", "--name-only", head).decode().splitlines())
    historical = set(git(root, "ls-tree", "-r", "--name-only", HISTORICAL).decode().splitlines())
    overlay = {}
    for name in sorted(filter(integration_path, current | historical)):
        target = destination / name
        if name not in current:
            target.unlink()
            overlay[name] = None
            continue
        mode = git(root, "ls-tree", head, "--", name).decode().split()[0]
        if mode not in ("100644", "100755"):
            raise ValueError(f"non-regular integration file: {name}")
        data = git(root, "show", head + ":" + name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        target.chmod(0o755 if mode == "100755" else 0o644)
        overlay[name] = hashlib.sha256(data).hexdigest()
    git(destination, "add", "--all")
    git(destination, "-c", "user.name=Historical shadow qualification",
        "-c", "user.email=qualification@invalid", "commit", "--allow-empty",
        "-m", "Isolated historical consumer with integration from " + head)
    tested = git(destination, "rev-parse", "HEAD").decode().strip()
    return {"pr_head": head, "historical_consumer": HISTORICAL,
            "authority_base": AUTHORITY_BASE, "isolated_test_head": tested,
            "integration_sha256": overlay,
            "scope": "Historical consumer only; NOT current feature API qualification"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--summary", type=Path)
    parser.add_argument("--prepare", type=Path)
    args = parser.parse_args(argv)
    report = assess(ROOT, args.base, args.head)
    if args.prepare:
        if not report["applicable"]:
            raise ValueError("cannot prepare non-applicable historical qualification")
        report["prepared"] = prepare(ROOT, args.head, args.prepare)
    args.report.write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
    if args.github_output:
        with args.github_output.open("a") as output:
            output.write(f"applicable={str(report['applicable']).lower()}\n")
            if args.prepare:
                output.write("tested_head=" + report["prepared"]["isolated_test_head"] + "\n")
    if args.summary:
        with args.summary.open("a") as output:
            output.write("## Historical GNATDOC-008C applicability\n\n"
                         f"**{report['disposition']}**\n\n{report['reason']}\n\n"
                         f"PR head: `{args.head}`\n\n"
                         f"Historical consumer: `{HISTORICAL}`\n\n"
                         "Not a production migration or current-API qualification.\n\n"
                         "Integration paths:\n" +
                         "\n".join(f"- `{name}`" for name in report["integration_paths"]) + "\n")
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()