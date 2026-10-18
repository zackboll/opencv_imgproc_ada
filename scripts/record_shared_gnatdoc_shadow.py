#!/usr/bin/env python3
"""Summarize independent reports; missing evidence can never become a pass."""
import argparse
from pathlib import Path
import sys

from qualify_shared_gnatdoc_shadow import ENHANCER, TRANSITION_SHA256, digest, hashes, read_json, write_json


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
    qualification = reports.get("qualification", {})
    expected = qualification.get("shadow_sha256")
    complete = (qualification.get("tool", {}).get("revision") == ENHANCER
                and qualification.get("authority_transition_sha256") == TRANSITION_SHA256
                and qualification.get("deterministic") is True
                and qualification.get("byte_idempotent") is True
                and qualification.get("legacy_deterministic") is True
                and qualification.get("legacy_byte_idempotent") is True
                and qualification.get("documentation_tests", {}).get("executed", 0) >= 155
                and len(qualification.get("examples", [])) == 6
                and all(e["build_exit"] == e["run_exit"] == 0 for e in qualification.get("examples", []))
                and all(qualification.get(n) for n in ("legacy_gates", "native_gates", "shadow_gates"))
                and qualification.get("comparison", {}).get("local_type_links") == 326
                and qualification.get("comparison", {}).get("offline_external_type_links") == 549
                and qualification.get("comparison", {}).get("native", {}).get("declarations") == 314
                and reports.get("browser", {}).get("executed", 0) >= 1840
                and reports.get("browser", {}).get("original_assertions_retained", 0) >= 1840
                and reports.get("browser", {}).get("original_assertion_names_retained") is True
                and bool(reports.get("browser", {}).get("history_traces"))
                and reports.get("negative", {}).get("executed") == 36
                and reports.get("navigation-comparison", {}).get("operations") == 314
                and reports.get("navigation-comparison", {}).get("failures") == [])
    qualification_sha = (digest((workspace / "qualification.json").read_bytes())
                         if "qualification" in reports else None)
    for name in ("browser", "negative"):
        evidence = reports.get(name, {})
        complete = complete and (evidence.get("qualification_sha256") == qualification_sha
                                 and evidence.get("tested_shadow_sha256") == expected)
    complete = complete and reports.get("negative", {}).get("restored_shadow_sha256") == expected
    if expected:
        complete = complete and hashes(workspace / "first/_site") == expected
    success = bool(success and complete)
    blocked = reports.get("navigation-comparison", {}).get("status") == "fail"
    result = {"disposition": "BLOCKED_BY_SHARED_TOOL" if blocked else
              "HOSTED_CI_PENDING" if success else "PARTIAL_SHADOW_COMPATIBILITY",
              "full_shadow_qualification": success, "missing_evidence": missing,
               "current_run_complete": bool(complete), "enhancer": ENHANCER,
               "consumer_tested": qualification.get("consumer_tested"),
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
    result = record(args.workspace)
    print(result)
    sys.exit(0 if result["full_shadow_qualification"] else 1)