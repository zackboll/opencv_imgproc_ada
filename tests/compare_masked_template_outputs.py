"""Fixed corpus bound: 2^-19 * active * 65025; never fit to observations."""
import itertools
import math
import struct
import sys


def load(path):
    cases = {}
    with open(path, encoding="ascii") as stream:
        for line in stream:
            fields = line.split()
            if fields[0] == "VERSION":
                version = fields[1]
            elif fields[0] == "CASE":
                case = (tuple(map(int, fields[2:])), [], None)
                cases[fields[1]] = case
            elif fields[0] == "SCORE":
                case[1].append(int(fields[1], 16))
            elif fields[0] == "MIN":
                cases[next(reversed(cases))] = (
                    case[0], case[1], tuple(map(int, fields[1:3])))
    return version, cases


def value(bits):
    return struct.unpack("!f", struct.pack("!I", bits))[0]


def ordered(bits):
    return 0x80000000 - (bits & 0x7fffffff) if bits >> 31 else 0x80000000 + bits


failed = False
loaded = list(map(load, sys.argv[1:]))
assert [v for v, _ in loaded] == ["4.1.0", "4.10.0", "5.0.0"]
for (av, aa), (bv, bb) in itertools.combinations(loaded, 2):
    assert aa.keys() == bb.keys(), "fixture set mismatch"
    absolute = relative = 0.0
    ulps = nonfinite = locations = 0
    for name, (geometry, scores, minimum) in aa.items():
        bg, bs, bm = bb[name]
        assert geometry == bg and len(scores) == len(bs), "geometry mismatch"
        assert len(scores) == geometry[10] * geometry[11], "truncated score map"
        active = geometry[9]
        bound = math.ldexp(active * 65025.0, -19)
        # Zero-mask maps deliberately tie; all other corpus minima must agree.
        if minimum != bm:
            locations += 1
            print("MINIMUM_DIFFERENCE", name, minimum, bm)
            failed = True
        if name.startswith("distinctive-"):
            assert minimum == (1, 0), "mask did not restore landmark minimum"
        for index, (abits, bbits) in enumerate(zip(scores, bs)):
            a, b = value(abits), value(bbits)
            if not math.isfinite(a) or not math.isfinite(b):
                nonfinite += 1
                print("NONFINITE", name, index, a, b)
                failed = True
                continue
            delta = abs(a - b)
            absolute = max(absolute, delta)
            relative = max(relative, delta / max(abs(a), abs(b), 1e-30))
            ulps = max(ulps, abs(ordered(abits) - ordered(bbits)))
            if delta > bound:
                print("SCORE_DIFFERENCE", name, index, a, b, bound)
                failed = True
    print(av, bv, "max_abs", absolute, "max_rel", relative,
          "max_ulp", ulps, "nonfinite", nonfinite, "min_locations", locations)
if failed:
    sys.exit("VERSION_CONSISTENCY_NOT_ESTABLISHED")