#!/usr/bin/env python3
"""Exact synthetic-corpus comparison; no approved tolerances or omissions."""
import itertools
import pathlib
import sys


def load(path):
    lines = pathlib.Path(path).read_text().splitlines()
    if not lines or not lines[0].startswith("VERSION "):
        raise ValueError(f"{path}: missing version")
    version = lines[0].split()[1]
    cases = {}
    index = 1
    while index < len(lines):
        fields = lines[index].split()
        if len(fields) != 10 or fields[0] != "CASE":
            raise ValueError(f"{path}: malformed case: {lines[index]}")
        name = fields[1]
        metadata = tuple(map(int, fields[2:]))
        count = metadata[-1]
        matches = []
        index += 1
        for _ in range(count):
            match = lines[index].split()
            if len(match) != 4 or match[0] != "MATCH":
                raise ValueError(f"{path}: malformed match")
            matches.append((float(match[1]), float(match[2]), int(match[3])))
            index += 1
        if name in cases:
            raise ValueError(f"{path}: duplicate fixture {name}")
        cases[name] = (metadata, tuple(sorted(matches)))
    if not cases or not any(value[1] for value in cases.values()):
        raise ValueError(f"{path}: absent/nonempty corpus")
    if not any(not value[1] for value in cases.values()):
        raise ValueError(f"{path}: no empty-result coverage")
    return version, cases


def main():
    if len(sys.argv) < 3:
        raise ValueError("usage: compare_ballard_outputs.py FILE FILE [FILE]")
    loaded = [load(path) for path in sys.argv[1:]]
    failed = False
    for (va, a), (vb, b) in itertools.combinations(loaded, 2):
        differences = [name for name in sorted(a.keys() | b.keys())
                       if a.get(name) != b.get(name)]
        print(f"{va} vs {vb}: {len(differences)} differences; "
              f"{len(a)} / {len(b)} fixtures")
        for name in differences:
            print(f"  {name}: {va}={a.get(name)!r}; {vb}={b.get(name)!r}")
        failed |= bool(differences)
    return int(failed)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, IndexError, OSError) as error:
        print(error, file=sys.stderr)
        sys.exit(2)