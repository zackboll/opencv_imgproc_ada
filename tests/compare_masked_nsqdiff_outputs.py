"""Cross-version gates fixed before measurement: abs <= 1e-4 and <= 8 ULPs.

Zero-Scene scores must be exactly 0x7F7FFFFF. Bit identity is reported, not
required, because the 4.1 fallback and the later native call differ.
"""
import itertools
import struct
import sys

ABS = 1e-4
ULP = 8


def value(bits):
    return struct.unpack("!f", struct.pack("!I", bits))[0]


def ordered(bits):
    return 0x80000000 - (bits & 0x7FFFFFFF) if bits >> 31 else bits + 0x80000000


def load(path):
    cases = {}
    version = branch = None
    case = None
    with open(path, encoding="ascii") as stream:
        for line in stream:
            fields = line.split()
            if fields[0] == "VERSION":
                version, branch = fields[1], fields[2]
            elif fields[0] == "CASE":
                case = [fields[2:], []]
                cases[fields[1]] = case
            elif fields[0] == "SCORE":
                bits = int(fields[1], 16)
                scene = int(fields[2])
                if scene == 0:
                    assert bits == 0x7F7FFFFF, path
                case[1].append(bits)
            elif fields[0] == "MIN":
                case.append(tuple(fields[1:]))
    return version, branch, cases


loaded = list(map(load, sys.argv[1:]))
assert [item[0] for item in loaded] == ["4.1.0", "4.10.0", "5.0.0"]
assert [item[1] for item in loaded] == ["compatibility", "native", "native"]
failed = False
for (lv, _, left), (rv, _, right) in itertools.combinations(loaded, 2):
    assert left.keys() == right.keys()
    worst_abs = worst_ulp = 0
    for name, (geometry, scores, minimum) in left.items():
        other_geometry, other_scores, other_minimum = right[name]
        assert geometry[1:] == other_geometry[1:]
        rows = int(geometry[-2])
        cols = int(geometry[-1])
        assert len(scores) == rows * cols, (name, len(scores), rows, cols)
        assert len(scores) == len(other_scores), (name, len(scores), len(other_scores))
        for a, b in zip(scores, other_scores):
            if a == b:
                continue
            distance = abs(ordered(a) - ordered(b))
            delta = abs(value(a) - value(b))
            worst_abs = max(worst_abs, delta)
            worst_ulp = max(worst_ulp, distance)
            if delta > ABS or distance > ULP:
                failed = True
                print("GATE", lv, rv, name, hex(a), hex(b), delta, distance)
        if minimum[:3] != other_minimum[:3]:
            failed = True
            print("MIN", name, minimum, other_minimum)
    print(lv, rv, "max_abs", worst_abs, "max_ulp", worst_ulp)
if failed:
    sys.exit(1)
