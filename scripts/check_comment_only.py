#!/usr/bin/env python3
"""Prove that documentation edits changed only Ada comments.

Every Ada source under `src/` is compared with the same file at a Git
revision after removing comments and normalizing whitespace. String and
character literals are kept verbatim, so a changed literal, declaration,
default, pragma or contract is reported, as is an added or removed file.
Used to qualify documentation-only changes; it is not a CI gate because
ordinary feature work legitimately changes declarations.
"""

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def strip_comments(text):
    """Return Ada code tokens with comments removed and literals preserved."""
    tokens = []
    for line in text.splitlines():
        code = []
        index = 0
        while index < len(line):
            if line.startswith("--", index):
                break
            character = line[index]
            if character == '"':
                end = index + 1
                while end < len(line):
                    if line[end] == '"':
                        if line.startswith('""', end):
                            end += 2
                            continue
                        break
                    end += 1
                code.append(line[index:end + 1])
                index = end + 1
                continue
            if (character == "'" and index + 2 < len(line) and line[index + 2] == "'"
                    and not (index and (line[index - 1].isalnum() or line[index - 1] in "_)"))):
                code.append(line[index:index + 3])
                index += 3
                continue
            code.append(character)
            index += 1
        tokens.extend("".join(code).split())
    return tokens


def compare(revision, root=ROOT):
    """Return a list of files whose code differs from `revision`."""
    listed = subprocess.run(
        ["git", "-C", str(root), "ls-tree", "-r", "--name-only", revision, "src"],
        check=True, capture_output=True, text=True,
    ).stdout.split()
    before = {name for name in listed if name.endswith((".ads", ".adb"))}
    after = {path.relative_to(root).as_posix()
             for path in (root / "src").rglob("*") if path.suffix in (".ads", ".adb")}
    differences = [f"added: {name}" for name in sorted(after - before)]
    differences += [f"removed: {name}" for name in sorted(before - after)]
    for name in sorted(before & after):
        old = subprocess.run(
            ["git", "-C", str(root), "show", f"{revision}:{name}"],
            check=True, capture_output=True, text=True,
        ).stdout
        new = (root / name).read_text(encoding="utf-8")
        if strip_comments(old) != strip_comments(new):
            differences.append(f"code changed: {name}")
    return differences


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("revision", help="Git revision to compare against")
    args = parser.parse_args(argv)
    differences = compare(args.revision)
    for difference in differences:
        print(difference)
    if differences:
        return 1
    print(f"Ada sources under src/ differ from {args.revision} only in comments")
    return 0


if __name__ == "__main__":
    sys.exit(main())
