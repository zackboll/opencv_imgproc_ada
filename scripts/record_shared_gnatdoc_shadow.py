#!/usr/bin/env python3
"""Summarize independent reports; missing evidence can never become a pass."""
import argparse
from pathlib import Path

from qualify_shared_gnatdoc_shadow import digest, read_json, write_json


def record(workspace):
    reports = {}
    missing = []
    for name in ("qualification", "negative", "browser", "navigation-comparison"):
        path = workspace / (name + ".json")
        if not path.is_file():
            missing.append(name)
        else:
            reports[name] = read_json(path)
    success = (not missing and not reports["qualification"].get("failure")
               and all(reports[n]["status"] == "pass"
                       for n in ("negative", "browser", "navigation-comparison")))
    if "browser" in reports and "qualification" in reports:
        success = success and (reports["browser"].get("tested_shadow_sha256")
                               == reports["qualification"].get("shadow_sha256"))
    blocked = reports.get("navigation-comparison", {}).get("status") == "fail"
    result = {"disposition": "BLOCKED_BY_SHARED_TOOL" if blocked else
              "HOSTED_CI_PENDING" if success else "PARTIAL_SHADOW_COMPATIBILITY",
              "full_shadow_qualification": success, "missing_evidence": missing,
              "non_deployable": True, "production_migration_complete": False,
              "production_https_verified": False,
              "reports": {n: digest((workspace / (n + ".json")).read_bytes()) for n in reports},
              "hosted_exact_head": "consult immutable Actions run; not inferred from local execution"}
    write_json(workspace / "readiness.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    args = parser.parse_args()
    print(record(args.workspace))