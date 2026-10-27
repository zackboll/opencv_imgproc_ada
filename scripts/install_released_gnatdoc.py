#!/usr/bin/env python3
"""Imgproc-owned, documentation-only installation of the approved release.

The approved archive digest and immutable Git tree authorize bytes, never an
installation receipt or an output-side presentation manifest. Retained wheels
are independently rechecked before every use. No editable installation, local
enhancer checkout, Alire dependency, or runtime network access is involved.
"""
from __future__ import annotations

import argparse
import hashlib
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
VERSION = "0.1.1"
TAG = "6d3bc1167179ec7cb90c2a6bdf91050b6057f6b4"
COMMIT = "dd100f026e13cdd9e97b283d50130241d71bdb9d"
TREE = "2873e5f7e0c200ec24a6706610d3bc0527303a7d"
WHEEL = "ada_gnatdoc_enhancer-0.1.1-py3-none-any.whl"
WHEEL_HASH = "8b896683a65623a7e7d626701a4cd68c8b89cb65792f9ffd5525bfa8cfa257ab"
PROVENANCE_HASH = "fd29acd9660b4eea07b88dba493091894badc5b442eaeef2c8ad90741c6c0baa"
SDIST_HASH = "5d727b76bb7f667949f04ba2f8bb73183477ae8e3b6d62c061f0e8ebc4750d7f"
SUMS_HASH = "7b508545299c7c84ac5a95ec5a164b4e43cad8620574e02b0c78055c5460179b"
MODULES = """__init__.py __main__.py authored.py browser_metadata.py cli.py
config.py conformance.py coverage.py destinations.py errors.py external_types.py
generic_instances.py guides.py instance_references.py inventory.py metadata.py
native_html.py navigation.py pipeline.py profiles.py qualification.py symbols.py
syntax.py theme.py util.py validation.py warnings.py adapters/__init__.py
adapters/mel.py adapters/opencv.py assets/gnatdoc-guides.css assets/gnatdoc-instance-navigation.js
assets/gnatdoc-navigation.js assets/gnatdoc-symbol-navigation.js
assets/gnatdoc-theme.css""".split()
DIST = "ada_gnatdoc_enhancer-0.1.1.dist-info/"
MEMBERS = {"ada_gnatdoc_enhancer/" + p for p in MODULES} | {
    DIST + p for p in ("METADATA", "WHEEL", "entry_points.txt", "top_level.txt",
                      "RECORD", "licenses/LICENSE")}
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


def tagged_source(directory, members):
    run("git", "init", "--quiet", str(directory))
    run("git", "-c", "http.followRedirects=false", "-C", str(directory),
        "fetch", "--quiet", "--no-tags", REPOSITORY + ".git", f"refs/tags/v{VERSION}")
    identities = run("git", "-C", str(directory), "rev-parse", "FETCH_HEAD",
                     "FETCH_HEAD^{commit}", "FETCH_HEAD^{tree}").decode().split()
    require(identities == [TAG, COMMIT, TREE] and
            run("git", "-C", str(directory), "cat-file", "-t", "FETCH_HEAD") == b"tag\n",
            "annotated tag, source commit or tree mismatch")
    for name in sorted(members):
        if name.startswith("ada_gnatdoc_enhancer/"):
            require(run("git", "-C", str(directory), "show", COMMIT + ":src/" + name)
                    == members[name], "wheel differs from approved tagged source: " + name)


def launcher(environment):
    return (f"#!{environment}/bin/python -IB\n"
            "from ada_gnatdoc_enhancer.cli import main\n"
            "raise SystemExit(main())\n").encode()


def verify(environment):
    """Reconstruct identities from approved archives before importing the tool."""
    require(not environment.is_symlink(), "symlink environment")
    wheel = environment / "approved-archives" / WHEEL
    approved = archive(wheel, WHEEL_HASH, MEMBERS)
    retained = environment / "release-provenance.json"
    require(not retained.is_symlink() and digest(retained.read_bytes()) == PROVENANCE_HASH,
            "release provenance mismatch")
    sums = environment / "SHA256SUMS"
    require(not sums.is_symlink() and digest(sums.read_bytes()) == SUMS_HASH,
            "release checksum inventory mismatch")
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
              "installed_members": {k: digest(v) for k, v in sorted(expected.items())},
              "launcher_sha256": digest(launcher(environment)), "renderers": renderers}
    return record


def install(environment, guides=False):
    require(not environment.exists(), "installation environment must be new")
    with tempfile.TemporaryDirectory(prefix="imgproc009-release-") as tmp:
        directory = Path(tmp)
        wheel = directory / WHEEL
        download(WHEEL, wheel, WHEEL_HASH, 94500)
        members = archive(wheel, WHEEL_HASH, MEMBERS)
        provenance = directory / "release-provenance.json"
        download(provenance.name, provenance, PROVENANCE_HASH, 24655822)
        sums = directory / "SHA256SUMS"
        download(sums.name, sums, SUMS_HASH, 300)
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