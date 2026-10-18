#!/usr/bin/env python3
"""Consumer adversarial checks on the independently built full shadow site.

Each mutation is observed before rejection; bytes are restored in finally.
This suite does not run in, replace, or relax the legacy documentation suite.
"""
from __future__ import annotations

import argparse
import json
import importlib.metadata
from pathlib import Path
import sys
import tempfile

from qualify_shared_gnatdoc_shadow import (
    EVIDENCE, ENHANCER, OLD_ENHANCER, TRANSITION, Session, check_files,
    dependency, digest, hashes, provenance, read_json, require, safe, trusted_inputs, write_json,
)


def run(workspace, enhancer):
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.pipeline import enhance, verify
    from ada_gnatdoc_enhancer.qualification import bind_pristine
    root = safe(workspace / "first")
    site = root / "_site"
    pristine = workspace / "pristine-first"
    config = lambda: load(root, "qualification.toml")
    baseline = hashes(site)
    verify(config(), site)
    results = []
    restored_and_verified = False

    def reject(label, assertion, *, observed):
        require(observed, f"mutation did not occur: {label}")
        try:
            assertion()
        except (ValueError, OSError, KeyError) as exc:
            results.append({"name": label, "mutation_observed": True,
                            "rejected": True, "reason": str(exc)})
        else:
            raise ValueError(f"tamper accepted: {label}")

    def mutation(label, path, changed, assertion=None):
        original = path.read_bytes()
        require(changed != original, f"no-op mutation: {label}")
        try:
            path.write_bytes(changed)
            reject(label, assertion or (lambda: verify(config(), site)),
                   observed=path.read_bytes() == changed and path.read_bytes() != original)
        finally:
            path.write_bytes(original)

    def changed_json(label, path, transform, assertion=None):
        data = read_json(path)
        transform(data)
        mutation(label, path, (json.dumps(data, sort_keys=True, indent=2) + "\n").encode(), assertion)

    try:
        # Actual detached/branch state mutations, in a disposable checkout only.
        with tempfile.TemporaryDirectory(prefix="gnatdoc008-negative-") as temp:
            temp = Path(temp)
            session = Session(temp)
            checkout = temp / "enhancer"
            session.export(enhancer, ENHANCER, checkout)
            session.run(["git", "remote", "set-url", "origin",
                         "https://github.com/zackboll/ada-gnatdoc-enhancer.git"], checkout)
            session.run(["git", "checkout", "--detach", ENHANCER + "^"], checkout)
            reject("incorrect shared enhancer SHA", lambda: provenance(session, checkout),
                   observed=session.run(["git", "rev-parse", "HEAD"], checkout) != ENHANCER)
            session.run(["git", "checkout", "-b", "unpinned", ENHANCER], checkout)
            reject("unpinned enhancer checkout", lambda: provenance(session, checkout),
                   observed=session.run(["git", "symbolic-ref", "--short", "HEAD"], checkout) == "unpinned")
            for label, revision in (("previous enhancer pin rejected", OLD_ENHANCER),
                                    ("feature HEAD rejected instead of merge", ENHANCER + "^2")):
                session.run(["git", "checkout", "--detach", revision], checkout)
                reject(label, lambda: provenance(session, checkout),
                       observed=session.run(["git", "rev-parse", "HEAD"], checkout) != ENHANCER)
        provenance_logs = workspace / "negative-provenance"
        provenance_logs.mkdir()
        negative_session = Session(provenance_logs)
        asset = enhancer / "src/ada_gnatdoc_enhancer/assets/gnatdoc-navigation.js"
        mutation("modified pinned enhancer JavaScript", asset, asset.read_bytes() + b"\n/* altered */\n",
                 lambda: provenance(negative_session, enhancer))
        dist = importlib.metadata.distribution("ada-gnatdoc-enhancer")
        installed = Path(dist.locate_file("ada_gnatdoc_enhancer/assets/gnatdoc-navigation.js"))
        mutation("installed asset differs from pinned checkout", installed,
                 installed.read_bytes() + b"\n/* installed alteration */\n",
                 lambda: provenance(negative_session, enhancer))
        transition = root / TRANSITION
        mutation("modified authority transition", transition, transition.read_bytes() + b"\n",
                 lambda: trusted_inputs(root))
        original_transition = transition.read_bytes()
        try:
            transition.unlink()
            reject("missing authority transition", lambda: trusted_inputs(root),
                   observed=not transition.exists())
        finally:
            transition.write_bytes(original_transition)
        changed_json("altered historical authority hash in transition", transition,
                     lambda d: d["historical_records_sha256"].update({"authority.json": "0" * 64}),
                     lambda: trusted_inputs(root))
        historical = root / EVIDENCE / "authority.json"
        mutation("altered historical authority bytes", historical, historical.read_bytes() + b"\n",
                 lambda: trusted_inputs(root))
        authoritative_core = root / EVIDENCE / "core-types.json"
        mutation("unapproved authoritative Core manifest", authoritative_core,
                 authoritative_core.read_bytes() + b"\n", lambda: trusted_inputs(root))
        lock = workspace / "source/alire/alire.lock"
        original = lock.read_bytes()
        mutation("incorrect Core 0.4.1 origin", lock,
                 original.replace(b"git+https://github.com/zackboll/opencv_core_ada.git", b"git+https://example.invalid/impostor.git"),
                 lambda: dependency(lock))
        mutation("Core 0.5.0 substitution", lock,
                 original.replace(b'version = "0.4.1"', b'version = "0.5.0"'), lambda: dependency(lock))
        spec = read_json(root / EVIDENCE / "consumer-input.json")
        source = root / "src/opencv-image_processing.ads"
        mutation("changed real public specification", source, source.read_bytes() + b"\n-- changed\n",
                 lambda: check_files(root, spec["source_sha256"]))
        staged = root / "qualification-public/src/opencv-image_processing.ads"
        mutation("changed staged specification", staged, staged.read_bytes() + b"\n-- changed\n")
        page = next(p for p in pristine.glob("api/*.html") if p.name != "index.html")
        mutation("altered pristine GNATdoc bytes", page, page.read_bytes() + b"\n",
                 lambda: require(hashes(pristine) == spec["pristine_sha256"], "pristine identity changed"))
        manifest = root / EVIDENCE / "core-types.json"
        data = read_json(manifest)
        mat = data["types"]["opencv.core.mat"]
        wrong = next(t for t in data["types"].values()
                     if t["page"] == mat["page"] and t["anchor"] != mat["anchor"])
        require(wrong["anchor"] in (root / "qualification-dependencies/core-0.4.1/native/api" / mat["page"]).read_text(),
                "wrong-but-existing target does not exist")
        changed_json("wrong-but-existing external anchor", manifest,
                     lambda d: d["types"]["opencv.core.mat"].update(anchor=wrong["anchor"]))
        index = site / "api/index.html"
        from ada_gnatdoc_enhancer.qualification import identities
        declarations = next(v for v in identities(pristine).values() if v["package"])["declarations"]
        by_name = {}
        for anchor, name in declarations:
            by_name.setdefault(name, []).append(anchor)
        overloaded = next(values for values in by_name.values() if len(values) > 1)
        first, second = overloaded[:2]
        require(first in index.read_text() and second in index.read_text(), "overload links missing")
        # Use two genuine targets of the SAME overloaded operation, not unrelated names.
        mutation("swapped operation overload target", index,
                 index.read_bytes().replace(first.encode(), second.encode(), 1))
        mutation("forged declaration fragment", index,
                 index.read_bytes().replace(first.encode(), b"f" * 64, 1))
        original_index = index.read_bytes()
        metadata = site / "api/presentation.json"
        original_metadata = metadata.read_bytes()
        try:
            changed_index = original_index.replace(first.encode(), second.encode(), 1)
            index.write_bytes(changed_index)
            changed_metadata = original_metadata.replace(digest(original_index).encode(),
                                                         digest(changed_index).encode())
            require(changed_metadata != original_metadata, "output hash not present in metadata")
            metadata.write_bytes(changed_metadata)
            reject("forged navigation with matching output-side metadata", lambda: verify(config(), site),
                   observed=index.read_bytes() == changed_index and metadata.read_bytes() == changed_metadata)
        finally:
            index.write_bytes(original_index)
            metadata.write_bytes(original_metadata)
        guide = site / "guides/filtering-and-transforms.html"
        original = guide.read_bytes()
        try:
            guide.unlink()
            reject("missing guide", lambda: verify(config(), site), observed=not guide.exists())
        finally:
            guide.write_bytes(original)
        css = root / "docs/assets/gnatdoc-guides.css"
        mutation("modified guide stylesheet", css, css.read_bytes() + b"\n/* changed */\n")
        markdown = root / "docs/guides/filtering-and-transforms.md"
        mutation("modified Ada example fence", markdown,
                 markdown.read_bytes().replace(b"```ada\n", b"```ada\n-- altered fence\n", 1))
        example = root / "docs/examples/filtering_and_transforms.adb"
        mutation("changed compiled example source", example, example.read_bytes() + b"\n-- changed\n")
        categories = root / "docs/api-categories.json"
        changed_json("missing source-owned category", categories, lambda d: d["categories"].pop())
        extra = site / "unapproved.html"
        try:
            extra.write_text("<!doctype html><h1>Unapproved</h1>")
            reject("unapproved output HTML", lambda: verify(config(), site), observed=extra.is_file())
        finally:
            extra.unlink()
        extra_binary = site / "unapproved.bin"
        try:
            extra_binary.write_bytes(b"not an approved publication")
            reject("extra non-HTML published file", lambda: verify(config(), site),
                   observed=extra_binary.read_bytes() == b"not an approved publication")
        finally:
            extra_binary.unlink()
        output = next(p for p in site.glob("api/*.html") if p.name != "index.html")
        mutation("unapproved production URLs", output,
                 output.read_bytes().replace(b"https://core.invalid/", b"https://zackboll.github.io/opencv_core_ada/", 1))
        for label, path, assertion in (
            ("symlinked source path", staged, lambda: verify(config(), site)),
            ("symlinked output path", output, lambda: verify(config(), site)),
        ):
            original = path.read_bytes()
            backing = workspace / "symlink-backing"
            try:
                backing.write_bytes(original)
                path.unlink()
                path.symlink_to(backing)
                reject(label, assertion, observed=path.is_symlink())
            finally:
                path.unlink()
                path.write_bytes(original)
                backing.unlink()
        presentation = site / "api/presentation.json"
        changed_json("output-manifest tampering", presentation,
                     lambda d: d.update(unreviewed_authority=True))
        toml = root / "qualification.toml"
        mutation("unknown config key", toml, b"unknown_key = true\n" + toml.read_bytes(),
                 lambda: load(root, "qualification.toml"))
        mutation("duplicate config key", toml, b"schema_version = 1\n" + toml.read_bytes(),
                 lambda: load(root, "qualification.toml"))
        mutation("partial failed enhancement", output, output.read_bytes()[:100])
        # A real failed enhancement must not publish a partial caller-owned tree.
        original = categories.read_bytes()
        try:
            data = read_json(categories)
            data["categories"][0]["declarations"].append("No_Such_Real_Operation")
            changed = (json.dumps(data, indent=2) + "\n").encode()
            categories.write_bytes(changed)
            before_failure = hashes(site)
            reject("failed enhancement is atomic", lambda: enhance(config(), site),
                   observed=categories.read_bytes() == changed and changed != original)
            require(hashes(site) == before_failure, "failed enhancement partially published output")
        finally:
            categories.write_bytes(original)
        second_output = workspace / "second/_site/api/index.html"
        mutation("nondeterministic regeneration", second_output, second_output.read_bytes() + b"\n",
                 lambda: require(hashes(site) == hashes(workspace / "second/_site"), "output copies differ"))
        # Recheck original authority after all tampering and restoration.
        require(hashes(site) == baseline, "negative tests did not restore output")
        verify(config(), site)
        bind_pristine(pristine, site)
        trusted_inputs(root)
        restored_and_verified = True
    finally:
        write_json(workspace / "negative.json", {"tests": results, "executed": len(results),
                    "qualification_sha256": digest((workspace / "qualification.json").read_bytes()),
                    "tested_shadow_sha256": baseline, "restored_shadow_sha256": hashes(site),
                    "restored_and_verified": restored_and_verified,
                    "status": "pass" if restored_and_verified and len(results) == 36
                    and all(r["rejected"] for r in results) else "fail"})
    require(len(results) == 36, "incomplete adversarial suite")
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--enhancer", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = run(args.workspace, args.enhancer)
    except (ValueError, OSError, KeyError) as exc:
        print(f"negative qualification failed: {exc}", file=sys.stderr)
        return 1
    print(f"Rejected {len(result)} observed consumer mutations")
    return 0


if __name__ == "__main__":
    sys.exit(main())