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
    terminated = False
    corruption = False
    with open(path, encoding="ascii") as stream:
        for line in stream:
            fields = line.split()
            if not fields:
                continue
            assert not terminated, (path, "data after termination")
            if fields[0] == "VERSION":
                assert version is None and len(fields) == 3, path
                version, branch = fields[1], fields[2]
            elif fields[0] == "CASE":
                assert fields[1] not in cases and fields[2] == branch, path
                case = {"geometry": fields[3:5], "scores": [], "rank": None,
                        "control": None, "bounds": []}
                cases[fields[1]] = case
            elif fields[0] == "SCORE":
                assert case is not None and len(fields) == 9, (path, line)
                scale = int(fields[8])
                assert float(fields[2]) == scale, (path, line)
                case["scores"].append(
                    (int(fields[1], 16), scale, float(fields[3]),
                     int(fields[4], 16)))
            elif fields[0] == "BOUND":
                assert len(case["scores"]) == len(case["bounds"]) + 1, path
                case["bounds"].append(float(fields[1]))
            elif fields[0] == "RANK":
                assert case["rank"] is None and len(fields) == 17, path
                case["rank"] = fields[1:]
            elif fields[0] == "CONTROL":
                assert case["control"] is None, path
                case["control"] = fields[1:]
            elif fields[0] == "CORRUPTION":
                assert not corruption and int(fields[1]) > 0, path
                assert float(fields[3]) <= float(fields[4]), path
                corruption = True
            elif fields[0] == "FAILURES":
                assert fields[1] == "0", (path, line)
                terminated = True
            else:
                raise AssertionError((path, "unknown record", line))
    assert version and branch and terminated and corruption, path
    for name, item in cases.items():
        rows, cols = map(int, item["geometry"])
        assert len(item["scores"]) == rows * cols, (path, name)
        assert item["rank"] is not None and item["control"] is not None, (path, name)
        assert item["control"][0] == "0", (path, name, item["control"])
        scores = item["scores"]
        bounds = item["bounds"]
        assert len(bounds) == len(scores), (path, name, "missing bounds")
        assert all(math.isclose(b, ABS + SLOPE * s[1],
                                rel_tol=0.0, abs_tol=math.ulp(b))
                   for b, s in zip(bounds, scores)), (path, name, "bounds")
        assert all(s[0] == s[3] for s in scores), (path, name, "Gate C")
        assert all(math.isfinite(value(s[0])) and
                   abs(value(s[0]) - s[2]) <= b
                   for s, b in zip(scores, bounds)), (path, name, "Gate A")
        oracle = [s[2] for s in scores]
        native = [value(s[0]) for s in scores]
        best = oracle.index(max(oracle))
        native_best = native.index(max(native))
        alternatives = [i for i in range(len(scores)) if i != best]
        other = max(alternatives, key=lambda i: oracle[i] + bounds[i]) \
            if alternatives else best
        second = max(oracle[i] for i in alternatives) \
            if alternatives else oracle[best]
        separation = oracle[best] - bounds[best] - \
            (oracle[other] + bounds[other]) if alternatives else 0.0
        ties = oracle.count(oracle[best])
        classification = "single" if not alternatives else "tie" \
            if ties > 1 else "robust" if separation > 0 else "ambiguous"
        rank = item["rank"]
        expected_ints = [best % cols, best // cols, native_best % cols,
                         native_best // cols, ties, native.count(max(native))]
        assert list(map(int, rank[:6])) == expected_ints, (path, name, rank)
        # Only serialization/reconstruction rounding uses isclose; the
        # numerical gates above and robust separation remain strict.
        facts = [oracle[best], second, oracle[best] - second, bounds[best]]
        assert all(math.isclose(float(a), b, rel_tol=1e-12, abs_tol=1e-9)
                   for a, b in zip(rank[6:10], facts)), (path, name)
        assert int(rank[10]) == other, (path, name, "alternative")
        assert all(math.isclose(float(a), b, rel_tol=1e-12, abs_tol=1e-9)
                   for a, b in zip(rank[11:14],
                                   [oracle[other], bounds[other], separation])), \
            (path, name, "separation")
        assert rank[14] == classification, (path, name, "classification")
        required = name in {"landmark-full", "landmark-sparse", "dft-large"}
        assert int(rank[15]) == int(required), (path, name, "required")
        if required:
            assert classification == "robust" and ties == 1 and \
                expected_ints[5] == 1 and best == native_best, (path, name)
        if name in {"exact-ties", "near-tie"}:
            assert classification == "tie", (path, name)
        if name == "ambiguous-near-tie":
            assert classification == "ambiguous" and ties == 1, (path, name)
        print(version, name, "class", classification, "margin", rank[8],
              "winner_bound", rank[9], "separation", rank[13])
    original = {
        "landmark-full", "landmark-sparse", "nonbinary-mask", "scene-offset",
        "template-offset", "positive-scale", "inverted", "high-values",
        "corrupt-template", "corrupt-scene", "black-template", "black-scene",
        "constant-template", "constant-scene", "one-pixel", "one-by-one",
        "template-equals-source", "one-row", "one-column", "odd-even",
        "exact-ties", "near-tie", "dft-large", "region-source"}
    assert set(cases) == original | {"ambiguous-near-tie"}, path
    assert sum(len(cases[n]["scores"]) for n in original) == 49238, \
        (path, "original corpus completeness")
    samples = [s for c in cases.values() for s in c["scores"]]
    worst_abs = max(abs(value(s[0]) - s[2]) for s in samples)
    worst_rel = max(abs(value(s[0]) - s[2]) /
                    max(abs(value(s[0])), abs(s[2]))
                    if max(abs(value(s[0])), abs(s[2])) else 0.0
                    for s in samples)
    oracle_ulp = max(abs(ordered(s[0]) - ordered(
        struct.unpack("!I", struct.pack("!f", s[2]))[0])) for s in samples)
    print(version, "ORACLE max_abs", worst_abs, "max_rel", worst_rel,
          "max_ulp", oracle_ulp, "samples", len(samples), "nonfinite", 0)
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
        assert a_case["bounds"] == b_case["bounds"], name
        assert a_case["rank"][0:2] == b_case["rank"][0:2], name
        assert a_case["rank"][4] == b_case["rank"][4], name
        assert a_case["rank"][6:] == b_case["rank"][6:], name
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
            if fa * fb < 0:
                signs += 1
                if delta > bound:
                    failed = True
    print(lv, rv, "max_abs", worst_abs, "max_rel", worst_rel, "max_ulp",
          worst_ulp, "sign_disagreements", signs, "nonfinite", nonfinite,
          "location_differences", location)
if failed:
    sys.exit(1)
