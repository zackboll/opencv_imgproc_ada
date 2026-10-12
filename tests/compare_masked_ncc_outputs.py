"""Predeclared ceiling: 1e-4 absolute on finite normalized scores.

The ceiling was chosen before inspecting cross-version differences and is not
widened from observations. Relative and ULP extremes are always reported.
"""
import itertools
import math
import struct
import sys

CEILING = 1e-4


def load(path):
    cases = {}
    version = None
    case = None
    with open(path, encoding="ascii") as stream:
        for line in stream:
            fields = line.split()
            if fields[0] == "VERSION":
                version = fields[1]
            elif fields[0] == "CASE":
                geometry = tuple(fields[2:])
                case = [geometry, [], None]
                cases[fields[1]] = case
            elif fields[0] == "SCORE":
                case[1].append(int(fields[1], 16))
            elif fields[0] == "MAX":
                case[2] = (
                    int(fields[1]), int(fields[2]), int(fields[3]),
                    float.fromhex(fields[4]), float.fromhex(fields[5]))
    return version, cases


def value(bits):
    return struct.unpack("!f", struct.pack("!I", bits))[0]


def ordered(bits):
    return 0x80000000 - (bits & 0x7fffffff) if bits >> 31 else 0x80000000 + bits


failed = False
loaded = list(map(load, sys.argv[1:]))
assert [item[0] for item in loaded] == ["4.1.0", "4.10.0", "5.0.0"]
for (left_version, left), (right_version, right) in itertools.combinations(loaded, 2):
    assert left.keys() == right.keys(), "fixture set mismatch"
    absolute = relative = 0.0
    ulps = nonfinite = locations = rankings = 0
    for name, (geometry, scores, maximum) in left.items():
        other_geometry, other_scores, other_maximum = right[name]
        assert geometry == other_geometry, "geometry mismatch"
        assert len(scores) == len(other_scores), "score count mismatch"
        rows, cols = int(geometry[-2]), int(geometry[-1])
        assert len(scores) == rows * cols, "truncated score map"
        if maximum[:3] != other_maximum[:3]:
            locations += 1
            print("MAXIMUM_DIFFERENCE", name, maximum, other_maximum)
            if not name.startswith("near-tie") and not name.startswith("one-pixel-tie"):
                failed = True
        left_margin = maximum[3] - maximum[4]
        right_margin = other_maximum[3] - other_maximum[4]
        if name == "near-tie":
            print("NEAR_TIE", left_version, maximum, "margin", left_margin)
            print("NEAR_TIE", right_version, other_maximum, "margin", right_margin)
            if maximum[0:2] != other_maximum[0:2]:
                rankings += 1
                print("NEAR_TIE_RANK_CHANGE", name)
        elif left_margin > 1e-3 and maximum[0:2] != other_maximum[0:2]:
            rankings += 1
            print("HIGH_MARGIN_RANK_CHANGE", name, left_margin)
            failed = True
        for index, (left_bits, right_bits) in enumerate(zip(scores, other_scores)):
            left_value, right_value = value(left_bits), value(right_bits)
            if math.isinf(left_value) or math.isinf(right_value):
                nonfinite += 1
                print("UNEXPECTED_INFINITY", name, index, hex(left_bits), hex(right_bits))
                failed = True
                continue
            if not math.isfinite(left_value) or not math.isfinite(right_value):
                nonfinite += 1
                print("NONFINITE", name, index, left_value, right_value)
                failed = True
                continue
            delta = abs(left_value - right_value)
            absolute = max(absolute, delta)
            scale = max(abs(left_value), abs(right_value), 1e-30)
            relative = max(relative, delta / scale)
            ulps = max(ulps, abs(ordered(left_bits) - ordered(right_bits)))
            if delta > CEILING:
                print("SCORE_DIFFERENCE", name, index, left_value, right_value)
                failed = True
    print(left_version, right_version, "max_abs", absolute, "max_rel", relative,
          "max_ulp", ulps, "nonfinite", nonfinite, "max_locations", locations,
          "rank_changes", rankings)
if failed:
    sys.exit("VERSION_CONSISTENCY_NOT_ESTABLISHED")
