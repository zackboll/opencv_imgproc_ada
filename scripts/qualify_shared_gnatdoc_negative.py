#!/usr/bin/env python3
"""Consumer adversarial checks on the independently built full shadow site.

Each mutation is observed before rejection; bytes are restored in finally.
This suite does not run in, replace, or relax the legacy documentation suite.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile

from qualify_shared_gnatdoc_shadow import (
    BASE, CORE, CONFIG, EVIDENCE, ENHANCER, Session, check_files, compare,
    dependency, digest, hashes, provenance, read_json, require, safe, write_json,
)


def run(workspace, enhancer):
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.pipeline import verify
    from ada_gnatdoc_enhancer.qualification import bind_pristine
    root = safe(workspace / "first")
    site = root / "_site"
    pristine = workspace / "pristine-first"
    config = lambda: load(root, "qualification.toml")
    baseline = hashes(site)
    verify(config(), site)
    results = []

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
        anchors = re.findall(r'href=["\']?([^\s>"\']+\.html#[a-f0-9]{64})', index.read_text())
        require(len(set(anchors)) > 1, "need two real declaration links")
        # Swap two destinations while preserving all real anchor identities.
        first, second = list(dict.fromkeys(anchors))[:2]
        mutation("swapped operation overload target", index,
                 index.read_bytes().replace(first.encode(), second.encode(), 1))
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
        second_output = workspace / "second/_site/api/index.html"
        mutation("nondeterministic regeneration", second_output, second_output.read_bytes() + b"\n",
                 lambda: require(hashes(site) == hashes(workspace / "second/_site"), "output copies differ"))
        # Recheck original authority after all tampering and restoration.
        require(hashes(site) == baseline, "negative tests did not restore output")
        verify(config(), site)
        bind_pristine(pristine, site)
    finally:
        write_json(workspace / "negative.json", {"tests": results, "executed": len(results),
                    "status": "pass" if len(results) == 22 and all(r["rejected"] for r in results) else "fail"})
    require(len(results) == 22, "incomplete adversarial suite")
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