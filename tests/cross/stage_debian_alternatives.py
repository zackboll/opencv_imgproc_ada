"""Reproduce shared-library alternatives from downloaded Debian metadata.

dpkg-deb extraction does not run postinst, so BLAS/LAPACK SONAME links are
otherwise absent. Never execute package maintainer scripts. Only literal,
contained shared-library alternatives are staged, with an evidence record.
"""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def alternatives(text):
    text = text.replace("\\\n", " ")
    return re.findall(r"^\s*update-alternatives\s+--install\s+"
                      r"(/(?:usr/)?lib/\S+\.so\.\S+)\s+\S+\s+"
                      r"(/(?:usr/)?lib/\S+)\s+(\d+)", text, re.M)


def stage(sysroot, packages, evidence):
    sysroot = sysroot.resolve(strict=True)
    choices = {}
    for package in sorted(packages.glob("*.deb")):
        with tempfile.TemporaryDirectory(prefix="imgproc-package-control-") as temp:
            subprocess.run(["dpkg-deb", "-e", str(package), temp], check=True)
            postinst = Path(temp) / "postinst"
            for link, target, priority in alternatives(postinst.read_text() if postinst.exists() else ""):
                if link not in choices or int(priority) > choices[link][1]:
                    choices[link] = (target, int(priority), package.name)
    records = []
    for link, (target, priority, owner) in sorted(choices.items()):
        destination, source = sysroot / link.lstrip("/"), sysroot / target.lstrip("/")
        for path in [source, destination.parent]:
            if not path.resolve(strict=True).is_relative_to(sysroot):
                raise ValueError(f"alternative escapes sysroot: {path}")
        if destination.exists() or destination.is_symlink():
            raise ValueError(f"alternative already exists: {destination}")
        destination.symlink_to(os.path.relpath(source, destination.parent))
        records.append(f"{link} -> {target} priority={priority} package={owner}")
    evidence.write_text("\n".join(records) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: stage_debian_alternatives.py SYSROOT PACKAGES EVIDENCE")
    stage(*map(Path, sys.argv[1:]))