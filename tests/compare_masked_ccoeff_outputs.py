"""Cross-version gate B, fixed before measurement.

Per sample: |a - b| <= 1e-4 + 2**-20 * |Sum(M*T*I)| (the dominant term; the
coefficient cancels two large correlations, so error scales with it). ULP
distances are reported, never gated, because a near-zero result has an
enormous ULP distance from exact zero. Also required: no nonfinite scores,
no sign disagreement outside that bound, identical oracle ranking data, and
identical native best-match locations except exact-tie cases. Incomplete or
mismatched cases abort; nothing is silently truncated.
"""
import itertools
import math
import struct
import sys

ABS = 1e-4
SLOPE = 2.0 ** -20


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
            if not fields:
                continue
            if fields[0] == "VERSION":
                version, branch = fields[1], fields[2]
            elif fields[0] == "CASE":
                case = {"geometry": fields[3:5], "scores": [], "rank": None,
                        "control": None}
                cases[fields[1]] = case
            elif fields[0] == "SCORE":
                case["scores"].append(
                    (int(fields[1], 16), float(fields[2]), float(fields[3]),
                     int(fields[4], 16)))
            elif fields[0] == "RANK":
                case["rank"] = fields[1:]
            elif fields[0] == "CONTROL":
                case["control"] = fields[1:]
            elif fields[0] == "FAILURES":
                assert fields[1] == "0", (path, line)
    assert version and branch, path
    for name, item in cases.items():
        rows, cols = map(int, item["geometry"])
        assert len(item["scores"]) == rows * cols, (path, name)
        assert item["rank"] is not None and item["control"] is not None, (path, name)
        assert item["control"][0] == "0", (path, name, item["control"])
    return version, branch, cases


loaded = [load(path) for path in sys.argv[1:]]
assert [item[0] for item in loaded] == ["4.1.0", "4.10.0", "5.0.0"]
assert [item[1] for item in loaded] == ["compatibility", "native", "native"]
failed = False
for (lv, _, left), (rv, _, right) in itertools.combinations(loaded, 2):
    assert left.keys() == right.keys(), (set(left) ^ set(right))
    worst_abs = worst_rel = 0.0
    worst_ulp = signs = nonfinite = location = 0
    for name, a_case in left.items():
        b_case = right[name]
        assert a_case["geometry"] == b_case["geometry"], name
        assert len(a_case["scores"]) == len(b_case["scores"]), name
        # Oracle and ranking facts are version independent.
        assert [s[1:3] for s in a_case["scores"]] == [s[1:3] for s in b_case["scores"]], name
        assert a_case["rank"][0:2] == b_case["rank"][0:2], name
        assert a_case["rank"][4] == b_case["rank"][4], name
        if a_case["rank"][4] == "1" and a_case["rank"][2:4] != b_case["rank"][2:4]:
            location += 1
            failed = True
            print("LOCATION", lv, rv, name, a_case["rank"], b_case["rank"])
        for (a, scale, _, _), (b, _, _, _) in zip(a_case["scores"], b_case["scores"]):
            fa, fb = value(a), value(b)
            if not (math.isfinite(fa) and math.isfinite(fb)):
                nonfinite += 1
                failed = True
                continue
            delta = abs(fa - fb)
            bound = ABS + SLOPE * abs(scale)
            worst_abs = max(worst_abs, delta)
            if max(abs(fa), abs(fb)) > 0:
                worst_rel = max(worst_rel, delta / max(abs(fa), abs(fb)))
            worst_ulp = max(worst_ulp, abs(ordered(a) - ordered(b)))
            if delta > bound:
                failed = True
                print("GATE", lv, rv, name, hex(a), hex(b), delta, bound)
            if fa * fb < 0 and delta > bound:
                signs += 1
    print(lv, rv, "max_abs", worst_abs, "max_rel", worst_rel, "max_ulp",
          worst_ulp, "sign_disagreements", signs, "nonfinite", nonfinite,
          "location_differences", location)
if failed:
    sys.exit(1)
