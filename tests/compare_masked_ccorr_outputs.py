"""Gate B requires exact bits, independently of Gate A's oracle ceiling."""
import itertools
import math
import struct
import sys


def load(path):
    cases = {}
    controls = 0
    with open(path, encoding="ascii") as stream:
        for line in stream:
            f = line.split()
            if f[0] == "VERSION":
                version = f[1]
            elif f[0] == "CASE":
                case = {"geometry": tuple(map(int, f[2:])), "scores": []}
                cases[f[1]] = case
            elif f[0] == "SCORE":
                case["scores"].append((int(f[1], 16), int(f[2])))
                actual, oracle = value(int(f[1], 16)), int(f[2])
                reference_bits = int(f[3], 16)
                reference = value(reference_bits)
                rounded = struct.unpack("!f", struct.pack("!f", oracle))[0]
                assert reference == rounded, "incorrect rounded oracle"
                assert int(f[4]) == (reference == oracle), "exactness diagnostic"
                ulp = value(reference_bits + 1) - reference
                bound = max(1e-4, 4 * ulp)
                assert math.isfinite(actual) and f[8] == "finite"
                assert abs(actual - reference) <= bound, "Gate A"
                if case["geometry"][4] == 0:
                    assert oracle == 0 and actual == 0, "all-zero mask"
                if f[9] != "unavailable":
                    control = value(int(f[9], 16))
                    assert math.isfinite(control)
                    assert abs(actual - control) <= 2 * bound, "native control"
                    controls += 1
            elif f[0] == "MAX":
                case["max"] = (int(f[1]), float(f[2]), float(f[3]))
            elif f[0] == "CONTROL":
                case["control"] = tuple(map(float, f[1:]))
            elif f[0] == "ORACLE_MAX":
                print(version, "oracle_max_abs", f[1], "oracle_max_ulp", f[2],
                      "positive_oracle_max_ulp", f[3], "ulp_distance", f[4])
            elif f[0] == "RANK":
                case["rank"] = f[1:]
    print(version, "cases", len(cases), "samples",
          sum(len(c["scores"]) for c in cases.values()), "control_max_abs",
          max(c["control"][0] for c in cases.values()), "control_max_rel",
          max(c["control"][1] for c in cases.values()))
    assert controls == (0 if version == "4.1.0" else
                        sum(len(c["scores"]) for c in cases.values()))
    print(version, "near_tie", cases["near-tie"]["max"])
    for name, c in cases.items():
        if c["geometry"][8] or name in ("multiple-perfect", "near-tie-sub-ulp"):
            print(version, "RANK", name, *c["rank"])
    return version, cases


def value(bits):
    return struct.unpack("!f", struct.pack("!I", bits))[0]


def ordered(bits):
    return 0x80000000 - (bits & 0x7fffffff) if bits >> 31 else 0x80000000 + bits


failed = False
loaded = list(map(load, sys.argv[1:]))
assert [v for v, _ in loaded] == ["4.1.0", "4.10.0", "5.0.0"]
for (av, aa), (bv, bb) in itertools.combinations(loaded, 2):
    assert aa.keys() == bb.keys(), "fixture mismatch"
    absolute = relative = 0.0
    ulps = nonfinite = locations = 0
    for name, a in aa.items():
        b = bb[name]
        g = a["geometry"]
        assert g == b["geometry"]
        assert len(a["scores"]) == len(b["scores"]) == g[5] * g[6]
        if a["max"][0] != b["max"][0]:
            locations += 1
            print("MAXIMUM_DIFFERENCE", name, a["max"], b["max"])
            if g[8]:
                failed = True
        for (ab, ao), (bc, bo) in zip(a["scores"], b["scores"]):
            assert ao == bo, "oracle disagreement"
            x, y = value(ab), value(bc)
            if not math.isfinite(x) or not math.isfinite(y):
                nonfinite += 1
                failed = True
                continue
            delta = abs(x - y)
            absolute = max(absolute, delta)
            relative = max(relative, delta / max(abs(x), abs(y), 1e-30))
            ulps = max(ulps, abs(ordered(ab) - ordered(bc)))
            if ab != bc:
                print("BIT_DIFFERENCE", name, hex(ab), hex(bc), x, y)
                failed = True
    print(av, bv, "max_abs", absolute, "max_rel", relative,
          "max_ulp", ulps, "nonfinite", nonfinite, "max_locations", locations)
if failed:
    sys.exit("VERSION_CONSISTENCY_NOT_ESTABLISHED")