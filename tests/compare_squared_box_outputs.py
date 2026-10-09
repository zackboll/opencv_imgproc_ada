#!/usr/bin/env python3
"""Predeclared cross-version policy; compare every production output sample.

A: exact numerical equality. B: <=2 ULP (reciprocal then product rounding).
C: <=4 ULP; small allowance for binary64 evaluation, not a relative epsilon
that masks lost tiny residuals. D: identical finite/NaN/signed-Inf classes;
finite values follow C. NaN payload/sign and signed zero are not contracts.
These budgets are agreement limits, not ideal-window accuracy guarantees.
"""
import itertools
import math
import struct
import sys


def load(path):
    with open(path, encoding="ascii") as stream:
        header = next(stream).split()
        if header[0] != "squared-box-v1":
            raise ValueError("invalid corpus format")
        cases = []
        for line in stream:
            fields = line.split()
            metadata = fields[:16]
            values = [struct.unpack(">d", bytes.fromhex(x))[0] for x in fields[16:]]
            if len(values) != int(fields[12]) * int(fields[13]) * int(fields[15]):
                raise ValueError("incomplete output")
            cases.append((metadata, values))
        return header[1], cases


def classify(x):
    if math.isnan(x):
        return "nan"
    if math.isinf(x):
        return "+inf" if x > 0 else "-inf"
    return "finite"


def ordered(x):
    bits = struct.unpack(">Q", struct.pack(">d", x))[0]
    return (~bits & ((1 << 64) - 1)) if bits >> 63 else bits | (1 << 63)


def main():
    if len(sys.argv) < 3:
        raise ValueError("provide at least two version-labeled corpus files")
    datasets = [load(path) for path in sys.argv[1:]]
    versions = {version for version, _ in datasets}
    if not {"4.1.0", "4.10.0", "5.0.0"}.issubset(versions):
        raise ValueError("mandatory exact versions 4.1.0/4.10.0/5.0.0 missing")
    failures = 0
    for (va, a), (vb, b) in itertools.combinations(datasets, 2):
        if len(a) != len(b) or not a:
            raise ValueError("different or empty corpus")
        maxima = {c: [0.0, 0.0, 0] for c in "ABCD"}
        samples = 0
        for (ma, xa), (mb, xb) in zip(a, b):
            if ma != mb:
                raise ValueError("fixture metadata differs")
            category = ma[1]
            for index, (x, y) in enumerate(zip(xa, xb)):
                samples += 1
                cx, cy = classify(x), classify(y)
                mismatch = cx != cy
                if cx == cy == "finite":
                    absolute = abs(x-y)
                    relative = absolute / max(abs(x), abs(y)) if x or y else 0
                    ulp = 0 if x == y else abs(ordered(x)-ordered(y))
                    maxima[category] = [max(maxima[category][0], absolute),
                                        max(maxima[category][1], relative),
                                        max(maxima[category][2], ulp)]
                    mismatch = x != y if category == "A" else ulp > (
                        2 if category == "B" else 4)
                if mismatch:
                    if failures < 20:
                        print(f"BLOCKER {va}/{vb} case={ma[0]} class={category} "
                              f"sample={index} {x!r} != {y!r}")
                    failures += 1
        print(f"{va} vs {vb}: {len(a)} cases, {samples} values")
        for category, (absolute, relative, ulp) in maxima.items():
            print(f"  {category}: max_abs={absolute:.17g} "
                  f"max_rel={relative:.17g} max_ULP={ulp}")
    print(f"{failures} unapproved inconsistencies")
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())