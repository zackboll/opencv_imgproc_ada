#!/usr/bin/env python3
"""R1 Core occurrence census and source/native/hosted proposal, never approval.

The unchanged legacy resolver is the occurrence oracle. Native snippets are
matched to visible declarations in exact indexed sources; an output manifest
cannot add a type, occurrence, host, page, fragment or approval. Network access
is explicit and redirects are forbidden. Production is never modified here.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import html
import json
from pathlib import Path
import re
import stat
import subprocess
import urllib.request
import zipfile

from highlight_gnatdoc_ada import strip_highlighting
from install_released_gnatdoc import digest, require
from link_gnatdoc_types import (CORE_PACKAGES, SECTION, Source, core_types,
                                decoded_offsets, native_targets, package_page,
                                plain, render, resolve, type_positions,
                                visible_declarations)
from qualify_released_gnatdoc import hashes, write

ROOT = Path(__file__).resolve().parents[1]
CORE = "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f"
HOSTED = "aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d"
ARTIFACT = 12238050173
ARTIFACT_SHA = "fd328d27efc3196b5861d11c73561c2d22451e2a0fcf2b6477d7c6e0f853cc37"
BASE_URL = "https://zackboll.github.io/opencv_core_ada/"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Core hosting redirect rejected: " + newurl)


def fetch(relative):
    require(re.fullmatch(r"(?:(?:api|guides)/)?[A-Za-z0-9_-]+\.(?:html|css|js|json)", relative) is not None,
            "unexpected hosted artifact path")
    url = BASE_URL + relative
    with urllib.request.build_opener(NoRedirect).open(url, timeout=90) as response:
        require(response.status == 200 and response.url == url, "Core hosting identity changed")
        data = response.read(8_000_001)
        require(len(data) <= 8_000_000, "oversized Core hosted file")
        length = response.headers.get("Content-Length")
        require(length is None or len(data) == int(length), "incomplete Core hosted file")
        return data


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True,
                          capture_output=True).stdout


def public_model(spec):
    package, lines, declarations = visible_declarations(spec)
    source = Source.__new__(Source)
    source.package, source.lines, source.declarations = package, lines, declarations
    source.top = [d for d in declarations if d["scope"].lower() ==
                  package + "." + d["name"].lower()]
    return source


def source_native_types(core, native, wanted):
    """Find genuine type sections, matching full source profiles, not names only."""
    models = {owner: public_model(core / "src" / filename)
              for owner, (filename, _) in CORE_PACKAGES.items()}
    pages = {}
    for path in sorted((native / "api").glob("*.html")):
        headings = re.findall(r"<h1>([^<]+)</h1>", path.read_text())
        if headings and headings[0].lower() in models:
            owner = headings[0].lower()
            require(owner not in pages and len(headings) == 1, "ambiguous Core package")
            pages[owner] = path
    require(set(pages) == set(models), "missing Core owner package")
    result = {}
    for owner, model in models.items():
        text = pages[owner].read_text()
        for section in SECTION.finditer(text):
            identity = owner + "." + section[2].lower()
            if identity not in wanted:
                continue
            declaration = model.match(section[3])
            require(declaration["scope"].lower() == identity and
                    declaration["signature"].split()[0] in {"type", "subtype"},
                    "Core target is not an exact visible type/subtype")
            require(identity not in result, "ambiguous Core declaration")
            filename = CORE_PACKAGES[owner][0]
            path = core / "src" / filename
            content = "\n".join(model.lines[declaration["start"] - 1:declaration["end"]])
            result[identity] = {
                "identity": declaration["scope"], "owner": owner,
                "kind": declaration["signature"].split()[0], "source_file": "src/" + filename,
                "source_file_sha256": digest(path.read_bytes()), "declaration": declaration,
                "source_declaration_text": content, "source_declaration_sha256": digest(content.encode()),
                "native_page": "api/" + pages[owner].name,
                "native_page_sha256": digest(pages[owner].read_bytes()),
                "native_anchor": section[1], "native_anchor_sha256": digest(section[1].encode()),
                "native_snippet": html.unescape(section[3]),
                "native_snippet_sha256": digest(html.unescape(section[3]).encode())}
    require(set(result) == set(wanted), "Core source/native target census incomplete")
    return result


def census(native, legacy, core):
    source = Source(ROOT / "src")
    path = package_page(native / "api", source)
    sections, targets = native_targets(path.read_text(), source)
    require(len(sections) == len(source.top) == 329, "current Imgproc native inventory mismatch")
    text = (legacy / "api" / path.name).read_text()
    actual = {s[1]: s for s in SECTION.finditer(text)}
    require(set(actual) == {s[1] for s in sections}, "legacy/native anchors differ")
    types = core_types(core)
    ledger, local = [], []
    source_hash = digest((ROOT / "src/opencv-image_processing.ads").read_bytes())
    for section in sections:
        declaration = source.match(section[3])
        raw = section[3]
        counts, families = Counter(), Counter()
        recomputed = render(raw, declaration, source, targets, types, counts, families)
        observed = strip_highlighting(actual[section[1]][3])
        require(observed == recomputed and plain(observed) == raw,
                "original production resolver does not reconstruct exact snippet")
        decoded, _, _ = decoded_offsets(raw)
        occurrence = 0
        for mark, start, end in type_positions(decoded):
            identity, url, status = resolve(mark, declaration, source, targets, types)
            if status == "linked":
                local.append({"declaration_anchor": section[1], "identity": identity,
                              "url": url, "offset": start})
            if status != "external":
                continue
            occurrence += 1
            owner = identity.rpartition(".")[0]
            full = "\n".join(source.lines[declaration["start"] - 1:declaration["end"]])
            ledger.append({
                "occurrence_id": section[1] + ":" + str(start),
                "imgproc_declaration": declaration, "imgproc_source_file": "src/opencv-image_processing.ads",
                "imgproc_source_file_sha256": source_hash,
                "imgproc_source_declaration_sha256": digest(full.encode()),
                "native_page": "api/" + path.name, "native_anchor": section[1],
                "native_snippet_sha256": digest(raw.encode()), "native_snippet": html.unescape(raw),
                "type_mark": decoded[start:end], "type_mark_start": start, "type_mark_end": end,
                "core_identity": identity, "core_package_owner": owner,
                "original_url": url,
                "original_semantics": "package browser query; target=_top; package overview, not declaration",
                "ordinal_in_declaration": occurrence})
    require(len(ledger) == 586 and len(local) == 348, "legacy occurrence reconciliation differs")
    require(len({x["occurrence_id"] for x in ledger}) == len(ledger), "duplicate occurrence identity")
    return ledger, local


def artifact_members(archive):
    require(digest(archive.read_bytes()) == ARTIFACT_SHA, "Core artifact ZIP hash differs")
    with zipfile.ZipFile(archive) as z:
        require(len(z.namelist()) == len(set(z.namelist())), "duplicate artifact members")
        members = {}
        for item in z.infolist():
            path = Path(item.filename)
            require(not path.is_absolute() and ".." not in path.parts and
                    stat.S_IFMT(item.external_attr >> 16) in (0, stat.S_IFREG, stat.S_IFDIR),
                    "unsafe artifact member")
            if not item.is_dir():
                members[item.filename] = z.read(item)
        return members


def propose(args):
    output = args.output.absolute()
    require(not output.exists(), "R1 proposal output must be new; do not overwrite evidence")
    output.mkdir(parents=True)
    require(git(args.core, "rev-parse", "HEAD").decode().strip() == CORE,
            "not indexed Core 0.5.0 source")
    require(not git(args.core, "diff", "--name-only", "HEAD", "--", "src"), "Core source modified")
    indexed = Path(subprocess.run(["alr", "exec", "--", "printenv", "OPENCV_CORE_ALIRE_PREFIX"],
                                 cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip())
    lock = __import__("tomllib").loads((ROOT / "alire/alire.lock").read_text())
    solved = [s for s in lock["solution"]["state"] if s["crate"] == "opencv_core"]
    require(len(solved) == 1 and not solved[0]["pinned"] and
            solved[0]["release"]["version"] == "0.5.0" and
            solved[0]["release"]["origin"]["commit"] == CORE, "indexed solution mismatch")
    source_map = {p.relative_to(args.core).as_posix(): digest(p.read_bytes())
                  for p in sorted((args.core / "src").rglob("*")) if p.is_file()}
    require(source_map == {name: digest((indexed / name).read_bytes()) for name in source_map},
            "indexed Core source differs from exact release acquisition")
    ledger, local = census(args.native, args.legacy, indexed)
    wanted = Counter(x["core_identity"] for x in ledger)
    proof = source_native_types(args.core, args.core_native, wanted)
    hosted_source = output / "hosted-source"
    (hosted_source / "src").mkdir(parents=True)
    for filename, _ in CORE_PACKAGES.values():
        data = git(args.core, "show", HOSTED + ":src/" + filename)
        (hosted_source / "src" / filename).write_bytes(data)
    for identity, item in proof.items():
        spec = hosted_source / item["source_file"]
        model = public_model(spec)
        found = [d for d in model.top if d["scope"].lower() == identity]
        require(len(found) == 1 and found[0]["signature"] == item["declaration"]["signature"],
                "hosted source owner/type/profile differs from indexed Core: " + identity)
        declaration = found[0]
        content = "\n".join(model.lines[declaration["start"] - 1:declaration["end"]])
        require(content == item["source_declaration_text"], "hosted source declaration text differs")
        item.update({"hosted_source_file_sha256": digest(spec.read_bytes()),
                     "hosted_source_declaration": declaration,
                     "hosted_source_declaration_sha256": digest(content.encode())})
    artifact = json.loads((args.work / "core-artifact-identity.json").read_text())
    deployment = json.loads((args.work / "core-deployment.json").read_text())
    statuses = json.loads((args.work / "core-deployment-statuses.json").read_text())
    run = json.loads((args.work / "core-run.json").read_text())
    require(artifact["id"] == ARTIFACT and artifact["digest"] == "sha256:" + ARTIFACT_SHA and
            artifact["workflow_run"]["head_sha"] == HOSTED and not artifact["expired"] and
            deployment["sha"] == HOSTED and statuses[0]["state"] == "success" and
            run["head_sha"] == HOSTED and run["conclusion"] == "success",
            "hosted Core acquisition identity mismatch")
    members = artifact_members(args.work / "core-artifact.zip")
    hosted = output / "hosted"
    hosted.mkdir()
    # Verify the complete actual hosted artifact, including JS/CSS and all pages.
    web = {}
    for name, data in sorted(members.items()):
        observed = fetch(name)
        require(observed == data, "live Core differs from immutable artifact: " + name)
        web[name] = digest(observed)
        target = hosted / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(observed)
    unresolved = []
    for identity, item in proof.items():
        page = item["native_page"]
        require(page in members, "genuine native Core page not hosted")
        text = members[page].decode()
        matches = [s for s in SECTION.finditer(text) if s[1] == item["native_anchor"]]
        if len(matches) != 1:
            unresolved.append({"identity": identity, "reason": "native fragment missing or duplicated"})
            continue
        match = matches[0]
        observed = html.unescape(plain(strip_highlighting(match[3])))
        if match[2] != item["identity"].rpartition(".")[2] or observed != item["native_snippet"]:
            unresolved.append({"identity": identity, "reason": "hosted native type identity/profile changed"})
            continue
        require(text.count("id=" + item["native_anchor"] + ">") == 1, "duplicate hosted anchor")
        item.update({"hosted_revision": HOSTED, "hosted_page_sha256": digest(members[page]),
                     "hosted_snippet_sha256": digest(observed.encode()),
                     "url": BASE_URL + page + "#" + item["native_anchor"],
                     "occurrences": wanted[identity],
                     "classification": "proposed package-overview to exact declaration navigation",
                     "approval": "REVIEW_REQUIRED"})
    for item in ledger:
        item["proposed_url"] = proof[item["core_identity"]].get("url")
        item["core_proof_identity"] = item["core_identity"]
        item["destination_change_classification"] = "intentional declaration-specific navigation; approval required"
    by_type, by_declaration = defaultdict(list), defaultdict(list)
    for i, item in enumerate(ledger):
        by_type[item["core_identity"]].append(i)
        by_declaration[item["native_anchor"]].append(i)
    record = {"schema_version": 1, "disposition": "CORE_POLICY_REVIEW_REQUIRED",
        "approval": False, "production_enabled": False, "indexed_core_version": "0.5.0",
        "indexed_core_revision": CORE, "indexed_core_tree": git(args.core, "rev-parse", "HEAD^{tree}").decode().strip(),
        "core_source_sha256": source_map, "core_native_sha256": hashes(args.core_native),
        "core_native_log": (args.work / "core-native.log").read_text(),
        "hosted_revision": HOSTED, "artifact": artifact, "deployment": deployment,
        "deployment_status": statuses[0], "hosted_file_sha256": web,
        "compatibility_boundary": "Only these exact referenced public declarations match Core 0.5.0; unversioned Pages is mutable, not immutable",
        "future_acceptance": "Fail closed on any source, native, artifact, deployment, URL, hosted-byte or occurrence change; explicit new independent policy review required",
        "types": proof, "occurrence_count": len(ledger), "occurrences": ledger,
        "by_type": by_type, "by_declaration_anchor": by_declaration,
        "legacy_local_occurrences": local, "unresolved": unresolved}
    write(output / "core-destination-proposal.json", record)
    require(not unresolved, "CORE_HOSTING_BLOCKED: unresolved exact type destinations")
    config = '''schema_version = 1
project = "opencv_imgproc_ada"
[gnatdoc]
version = "26.0.0"
[sources]
directories = ["qualification-public"]
packages = ["OpenCV.Image_Processing"]
comment_style = "leading"
[navigation]
mode = "operations"
categories = "categories.json"
[presentation]
theme = true
syntax_highlighting = true
type_links = true
[security]
external_hosts = ["zackboll.github.io"]
[external_types]
'''
    config += "".join(json.dumps(identity) + " = " + json.dumps(proof[identity]["url"]) + "\n"
                      for identity in sorted(proof))
    (output / "candidate.toml").write_text(config)
    print(json.dumps({"occurrences": len(ledger), "distinct_types": len(wanted),
                      "unresolved": len(unresolved), "policy_approved": False}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("work", "core", "core-native", "native", "legacy", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    propose(parser.parse_args())


if __name__ == "__main__":
    main()