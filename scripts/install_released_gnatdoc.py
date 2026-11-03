#!/usr/bin/env python3
"""Imgproc-owned, documentation-only installation of the approved release.

The approved archive digest and immutable Git tree authorize bytes, never an
installation receipt or an output-side presentation manifest. Retained wheels
are independently rechecked before every use. No editable installation, local
enhancer checkout, Alire dependency, or runtime network access is involved.
"""
from __future__ import annotations

import argparse
import base64
import csv
from email.parser import BytesParser
import hashlib
import io
import json
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import urllib.parse
import urllib.request
import venv
import zipfile

REPOSITORY = "https://github.com/zackboll/ada-gnatdoc-enhancer"
VERSION = "0.1.5"
TAG = "c6ca2b445b089e7f50abc1779d76dd4ff3f0f1eb"
COMMIT = "0120bee2f2455e4c832d1d5ddae0a4cb03cb9477"
TREE = "01900ddb099c801eeb92fba718f4c528f87d865f"
WHEEL = f"ada_gnatdoc_enhancer-{VERSION}-py3-none-any.whl"
SDIST = f"ada_gnatdoc_enhancer-{VERSION}.tar.gz"
WHEEL_HASH = "d712d330f213fc1909a66c47bc2c7e5e15d5ec687222bea3c4922f5243db4247"
PROVENANCE_HASH = "6c30b7a4ec987ab4f74a44d04586dcd57308dd592ac13f33c9444ef3acf0a8f3"
SDIST_HASH = "2bc2cc4160a182a2a9b1a4907f47198daabf88883888fa09d736913bd2931079"
SUMS_HASH = "93e061866d52e13b6266c6fa0efb3b9c2e3a1bd1b4c818981a11a802ded74756"
# Exact official asset sizes; a download must match before it is hashed.
SIZES = {WHEEL: 117934, SDIST: 3521158, "release-provenance.json": 1157963,
         "SHA256SUMS": 300}
# Derived from the authenticated v0.1.5 wheel and independently equal to every
# file under src/ada_gnatdoc_enhancer in tagged tree 01900ddb (42 files).
MODULES = """__init__.py __main__.py authored.py browser_metadata.py cli.py
config.py conformance.py coverage.py destinations.py errors.py examples.py
external_symbols.py external_types.py generic_instances.py guides.py
instance_references.py inventory.py metadata.py native_html.py navigation.py
pipeline.py profiles.py qualification.py search.py symbols.py syntax.py theme.py
util.py validation.py verified_examples.py warnings.py adapters/__init__.py
adapters/mel.py adapters/opencv.py assets/gnatdoc-examples.css
assets/gnatdoc-guides.css assets/gnatdoc-instance-navigation.js
assets/gnatdoc-navigation.js assets/gnatdoc-search.css assets/gnatdoc-search.js
assets/gnatdoc-symbol-navigation.js assets/gnatdoc-theme.css""".split()
DIST = f"ada_gnatdoc_enhancer-{VERSION}.dist-info/"
MEMBERS = {"ada_gnatdoc_enhancer/" + p for p in MODULES} | {
    DIST + p for p in ("METADATA", "WHEEL", "entry_points.txt", "top_level.txt",
                      "RECORD", "licenses/LICENSE")}
# The only dependency declarations allowed: optional, exact, documentation-only.
OPTIONAL_DEPENDENCIES = ['markdown-it-py==3.0.0; extra == "guides"',
                         'mdurl==0.1.2; extra == "guides"']
RENDERERS = {
    "markdown_it_py-3.0.0-py3-none-any.whl":
        "355216845c60bd96232cd8d8c40e8f9765cc86f46880e43a8fd22dc1a1a8cab1",
    "mdurl-0.1.2-py3-none-any.whl":
        "84008a41e51615a49fc9966191ff91509e3c40b939176e643fd50a5c2196b8f8"}
ROOT = Path(__file__).resolve().parents[1]


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run(*args):
    return subprocess.run(args, check=True, capture_output=True).stdout


def approved_url(url):
    u = urllib.parse.urlsplit(url)
    require(u.scheme == "https" and u.hostname in {
        "github.com", "release-assets.githubusercontent.com"} and
        u.port in (None, 443) and not u.username and not u.password,
        "unapproved release URL or redirect")


class Redirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        approved_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def download(name, path, sha, size):
    url = f"{REPOSITORY}/releases/download/v{VERSION}/{name}"
    approved_url(url)
    with urllib.request.build_opener(Redirect).open(url, timeout=90) as response:
        approved_url(response.url)
        data = response.read(size + 1)
        require(response.status == 200 and len(data) == size and
                response.headers.get("Content-Length") in (None, str(size)),
                "incomplete or oversized release download")
    require(digest(data) == sha, "release archive SHA-256 mismatch")
    path.write_bytes(data)


def archive(path, sha, names=None):
    require(not path.is_symlink() and digest(path.read_bytes()) == sha,
            "approved wheel SHA-256 mismatch")
    with zipfile.ZipFile(path) as z:
        members = z.namelist()
        require(len(members) == len(set(members)), "duplicate wheel member")
        if names is not None:
            require(set(members) == names, "unapproved wheel member inventory")
        result = {}
        for item in z.infolist():
            p = Path(item.filename)
            require(not p.is_absolute() and ".." not in p.parts and
                    not item.is_dir() and stat.S_IFMT(item.external_attr >> 16)
                    in (0, stat.S_IFREG), "unsafe wheel member")
            result[item.filename] = z.read(item)
        return result


def record_hash(data):
    return "sha256=" + base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()


def wheel_record(members):
    """Every wheel member, and only those, has its exact RECORD hash and size."""
    rows = list(csv.reader(io.StringIO(members[DIST + "RECORD"].decode("utf-8"))))
    require(all(len(row) == 3 for row in rows), "malformed wheel RECORD")
    paths = [row[0] for row in rows]
    require(len(paths) == len(set(paths)) and set(paths) == set(members),
            "wheel RECORD inventory differs from wheel members")
    for path, hashed, size in rows:
        if path == DIST + "RECORD":
            require(hashed == "" and size == "", "wheel RECORD self-entry must be unhashed")
        else:
            require(hashed == record_hash(members[path]) and size == str(len(members[path])),
                    "wheel RECORD hash or size mismatch: " + path)
    return len(rows)


def dependencies(members):
    """Distribution identity and no mandatory runtime dependency."""
    metadata = BytesParser().parsebytes(members[DIST + "METADATA"])
    require(metadata["Name"] == "ada-gnatdoc-enhancer" and metadata["Version"] == VERSION,
            "wheel METADATA name/version mismatch")
    require((metadata.get_all("Requires-Dist") or []) == OPTIONAL_DEPENDENCIES and
            (metadata.get_all("Provides-Extra") or []) == ["guides"],
            "unapproved or mandatory runtime dependency")
    require(members[DIST + "entry_points.txt"] ==
            b"[console_scripts]\ngnatdoc-enhancer = ada_gnatdoc_enhancer.cli:main\n" and
            members[DIST + "top_level.txt"] == b"ada_gnatdoc_enhancer\n",
            "unapproved entry point or top-level package")
    return list(OPTIONAL_DEPENDENCIES)


def checksums(data):
    """SHA256SUMS lists exactly the three approved official assets."""
    entries = {}
    for line in data.decode("ascii").splitlines():
        sha, _, name = line.partition("  ")
        require(name and name not in entries, "malformed checksum inventory")
        entries[name] = sha
    require(entries == {WHEEL: WHEEL_HASH, SDIST: SDIST_HASH,
                        "release-provenance.json": PROVENANCE_HASH},
            "release checksum inventory differs from approved assets")


def release_provenance(data, members):
    """Official provenance binds this exact source, archives and package bytes."""
    record = json.loads(data)
    archives = record["archives"]
    audit = record["distribution_content_audit"]
    require(record["release_version"] == VERSION and audit["version"] == VERSION and
            record["expected_source_commit"] == COMMIT and
            record["expected_source_tree"] == TREE, "provenance source identity mismatch")
    require(archives["wheel"]["name"] == WHEEL and archives["wheel"]["sha256"] == WHEEL_HASH and
            archives["wheel"]["bytes"] == SIZES[WHEEL] and
            archives["sdist"]["name"] == SDIST and archives["sdist"]["sha256"] == SDIST_HASH and
            archives["sdist"]["bytes"] == SIZES[SDIST], "provenance archive identity mismatch")
    require(archives["wheel"]["members"] == {
        name: {"bytes": len(content), "sha256": digest(content)}
        for name, content in members.items()}, "provenance wheel member inventory mismatch")
    require(audit["module_asset_sha256"] == {
        name: digest(content) for name, content in members.items()
        if name.startswith("ada_gnatdoc_enhancer/")}, "provenance module/asset digest mismatch")
    require(audit["runtime_dependencies"] == [] and
            audit["optional_guides_dependencies"] == OPTIONAL_DEPENDENCIES and
            audit["wheel_record_hashes_and_sizes_verified"] is True,
            "provenance dependency or RECORD audit mismatch")
    return record


def tagged_source(directory, members):
    run("git", "init", "--quiet", str(directory))
    run("git", "-c", "http.followRedirects=false", "-C", str(directory),
        "fetch", "--quiet", "--no-tags", REPOSITORY + ".git", f"refs/tags/v{VERSION}")
    identities = run("git", "-C", str(directory), "rev-parse", "FETCH_HEAD",
                     "FETCH_HEAD^{commit}", "FETCH_HEAD^{tree}").decode().split()
    require(identities == [TAG, COMMIT, TREE] and
            run("git", "-C", str(directory), "cat-file", "-t", "FETCH_HEAD") == b"tag\n",
            "annotated tag, source commit or tree mismatch")
    tagged = run("git", "-C", str(directory), "ls-tree", "-r", "--name-only", COMMIT,
                 "src/ada_gnatdoc_enhancer").decode().splitlines()
    packaged = {name for name in members if name.startswith("ada_gnatdoc_enhancer/")}
    require({name.removeprefix("src/") for name in tagged} == packaged,
            "wheel package inventory differs from tagged source inventory")
    for name in sorted(packaged):
        require(run("git", "-C", str(directory), "show", COMMIT + ":src/" + name)
                == members[name], "wheel differs from approved tagged source: " + name)


def launcher(environment):
    return (f"#!{environment}/bin/python -IB\n"
            "from ada_gnatdoc_enhancer.cli import main\n"
            "raise SystemExit(main())\n").encode()


def installed_record(site, expected):
    """Classify EVERY installed RECORD row; nothing unapproved may be recorded."""
    rows = list(csv.reader(io.StringIO((site / DIST / "RECORD").read_text(encoding="utf-8"))))
    require(all(len(row) == 3 for row in rows) and len({r[0] for r in rows}) == len(rows),
            "malformed installed RECORD")
    owned = {k: v for k, v in expected.items()
             if k.split("/")[0] in {"ada_gnatdoc_enhancer", DIST.rstrip("/")}}
    seen = set()
    for path, hashed, size in rows:
        if path in owned:
            require([hashed, size] == [record_hash(owned[path]), str(len(owned[path]))],
                    "installed RECORD differs from approved member: " + path)
            seen.add(path)
        elif path == DIST + "RECORD":
            require(hashed == size == "", "installed RECORD self-entry must be unhashed")
        elif path in {DIST + "INSTALLER", DIST + "REQUESTED", DIST + "direct_url.json"}:
            content = (site / path).read_bytes()
            require([hashed, size] == [record_hash(content), str(len(content))],
                    "installed metadata differs from RECORD: " + path)
        elif "/__pycache__/" in path:
            module = path.split("/__pycache__/")
            require(hashed == size == "" and path.endswith(".pyc") and
                    f"{module[0]}/{module[1].split('.')[0]}.py" in owned,
                    "unapproved installed bytecode RECORD entry: " + path)
        else:
            require(path == "../../../bin/gnatdoc-enhancer", "unapproved installed file: " + path)
    require(seen == set(owned) - {DIST + "RECORD"}, "installed RECORD omits approved members")


def verify(environment):
    """Reconstruct identities from approved archives before importing the tool."""
    require(not environment.is_symlink(), "symlink environment")
    wheel = environment / "approved-archives" / WHEEL
    approved = archive(wheel, WHEEL_HASH, MEMBERS)
    record_entries = wheel_record(approved)
    optional = dependencies(approved)
    retained = environment / "release-provenance.json"
    require(not retained.is_symlink() and digest(retained.read_bytes()) == PROVENANCE_HASH,
            "release provenance mismatch")
    release_provenance(retained.read_bytes(), approved)
    sums = environment / "SHA256SUMS"
    require(not sums.is_symlink() and digest(sums.read_bytes()) == SUMS_HASH,
            "release checksum inventory mismatch")
    checksums(sums.read_bytes())
    site = Path(run(str(environment / "bin/python"), "-I", "-B", "-c",
                    "import sysconfig;print(sysconfig.get_path('purelib'))").decode().strip())
    require(site.resolve().is_relative_to(environment.resolve()), "site-packages escapes environment")
    renderers = {}
    for name, sha in RENDERERS.items():
        path = wheel.parent / name
        if path.exists():
            renderers[name] = sha
            for member, data in archive(path, sha).items():
                require(member not in approved, "conflicting wheel members")
                approved[member] = data
    require(len(renderers) in (0, 2), "incomplete guide renderer")
    tops = {name.split("/")[0] for name in approved}
    actual = {}
    for top in sorted(tops):
        base = site / top
        require(base.is_dir() and not base.is_symlink(), "missing or symlink installed package")
        for path in sorted(base.rglob("*")):
            require(not path.is_symlink(), "symlink installed member")
            if path.is_file() and "__pycache__" not in path.parts:
                relative = path.relative_to(site).as_posix()
                if top.endswith(".dist-info") and path.name in {
                        "RECORD", "INSTALLER", "REQUESTED", "direct_url.json"}:
                    continue
                actual[relative] = path.read_bytes()
        for cache in base.rglob("__pycache__"):
            shutil.rmtree(cache)
    expected = {k: v for k, v in approved.items() if not k.endswith(".dist-info/RECORD")}
    require(actual == expected, "installed modules, assets or metadata differ from approved wheels")
    installed_record(site, expected)
    origin = json.loads((site / DIST / "direct_url.json").read_text())
    require(not origin.get("dir_info") and not origin.get("vcs_info") and
            origin == {"url": wheel.as_uri(),
                       "archive_info": {"hash": "sha256=" + WHEEL_HASH,
                                        "hashes": {"sha256": WHEEL_HASH}}},
            "non-editable wheel provenance mismatch")
    tool = environment / "bin/gnatdoc-enhancer"
    require(not tool.is_symlink() and tool.read_bytes() == launcher(environment),
            "installed launcher differs")
    versions = json.loads(run(str(environment / "bin/python"), "-I", "-B", "-c",
        "import importlib.metadata as m,ada_gnatdoc_enhancer as a,json;"
        "print(json.dumps([m.version('ada-gnatdoc-enhancer'),a.__version__]))"))
    require(versions == [VERSION, VERSION] and
            run(str(tool), "--version") == (VERSION + "\n").encode(),
            "installed CLI/module/distribution version mismatch")
    run(str(environment / "bin/python"), "-I", "-m", "pip", "check")
    record = {"repository": REPOSITORY, "tag": "v" + VERSION, "tag_object": TAG,
              "source_commit": COMMIT, "source_tree": TREE, "version": VERSION,
              "wheel_sha256": WHEEL_HASH, "sdist_sha256_not_installed": SDIST_HASH,
              "release_provenance_sha256": PROVENANCE_HASH,
              "sha256sums_sha256": SUMS_HASH,
              "wheel_record_entries_verified": record_entries,
              "mandatory_runtime_dependencies": [], "optional_dependencies": optional,
              "installed_members": {k: digest(v) for k, v in sorted(expected.items())},
              "launcher_sha256": digest(launcher(environment)), "renderers": renderers}
    return record


def install(environment, guides=False):
    require(not environment.exists(), "installation environment must be new")
    with tempfile.TemporaryDirectory(prefix="imgproc012-release-") as tmp:
        directory = Path(tmp)
        wheel = directory / WHEEL
        download(WHEEL, wheel, WHEEL_HASH, SIZES[WHEEL])
        members = archive(wheel, WHEEL_HASH, MEMBERS)
        wheel_record(members)
        dependencies(members)
        provenance = directory / "release-provenance.json"
        download(provenance.name, provenance, PROVENANCE_HASH, SIZES[provenance.name])
        release_provenance(provenance.read_bytes(), members)
        sums = directory / "SHA256SUMS"
        download(sums.name, sums, SUMS_HASH, SIZES[sums.name])
        checksums(sums.read_bytes())
        tagged_source(directory / "git", members)
        if guides:
            run("python3", "-m", "pip", "download", "--no-deps", "--require-hashes",
                "--only-binary=:all:", "--dest", str(directory), "-r",
                str(ROOT / "docs/released-gnatdoc-requirements.txt"))
            for name, sha in RENDERERS.items():
                archive(directory / name, sha)
        venv.EnvBuilder(with_pip=True).create(environment)
        destination = environment / "approved-archives"
        destination.mkdir()
        names = [WHEEL] + (list(RENDERERS) if guides else [])
        for name in names:
            shutil.copyfile(directory / name, destination / name)
        shutil.copyfile(provenance, environment / provenance.name)
        shutil.copyfile(sums, environment / sums.name)
        run(str(environment / "bin/python"), "-I", "-m", "pip", "install", "--no-index",
            "--no-deps", *(str(destination / name) for name in names))
    (environment / "bin/gnatdoc-enhancer").write_bytes(launcher(environment))
    record = verify(environment)
    (environment / "installation-provenance.json").write_text(
        json.dumps(record, sort_keys=True, indent=2) + "\n")
    return record


def checked_tool(environment):
    record = verify(environment)
    require(json.loads((environment / "installation-provenance.json").read_text()) == record,
            "installation receipt differs from independently reconstructed identity")
    return environment / "bin/gnatdoc-enhancer", record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--venv", required=True, type=Path)
    parser.add_argument("--with-guides", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    environment = args.venv.absolute()
    record = checked_tool(environment)[1] if args.verify else install(environment, args.with_guides)
    print(json.dumps(record, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()