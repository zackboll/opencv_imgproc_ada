# Resize Linear_Exact local validation

Starting main: `2bb7b78b4b8525f05150023daa81426ee3bd926e` (PR #37).
Branch: `feature/resize-linear-exact`.

## Results

| Check | Result |
| --- | --- |
| Detached unchanged-main baseline | 855 registered/executed/passed, 0 failures/errors |
| Final full AUnit | 871 registered/executed/passed, 0 failures/errors |
| Added registrations | 16 |
| Modified library Ada, strict warnings | PASS |
| All project-owned test Ada bodies, strict warnings | PASS |
| Modified Ada GNATformat, width 79 | PASS |
| Direct modified-Ada 79-column check | PASS |
| Strict C++17 production shim | PASS |
| Layout helper strict C++17 and ASan/UBSan | PASS |
| Independent fixture derivation strict C++17 | PASS |
| Exact 4.1.0 / 4.10.0 / 5.0.0 public-header syntax | PASS / PASS / PASS |
| git diff --check | PASS |
| Actual runtime | Linux x86_64, OpenCV 4.10.0 |

Strict Ada switches included `-gnatwa -gnatwc -gnatwu -gnatwn -gnatwe
-gnatyM79 -Werror`. Strict C++ used `-std=c++17 -Wall -Wextra -Wpedantic
-Werror`. No warning suppression was introduced. GNATformat 26.0.0 and
Alire-managed GNAT 16.1.0 / GPRbuild 26.0.1 were used.

The normal `alr -n build` succeeded on initial inspection. Final validation
used the tests crate's Alire environment with explicit GPR project paths to
a clean detached Core worktree at `4ebb727124bed45e9f1e76a6ede0664a26ca817a`.
The sibling Core had unrelated work, so it was not used for final linking.
Production dependency metadata was not changed. Configuration used the
existing `scripts/configure_opencv.sh` mechanism.

The development profile's `-gnatVa` classifies deliberately constructed
IEEE NaN/Infinity values in existing negative tests as invalid Ada data.
For the full suite, the established `-gnatVn` override was applied
consistently to Core/Imgproc/tests; it is a validity-check setting, **not** a
warning suppression. The unchanged baseline was verified under the same
setting. Strict warning checks remain enabled, including `-gnatwc`.

The shared `/tmp` tmpfs filled during validation. Compiler scratch and new
validation outputs were redirected via TMPDIR to the main filesystem;
unrelated temporary data was not removed. An attempted Clang helper check
could not run because `clang++` is not installed locally; GCC strict and
sanitizer checks passed. Remote macOS CI supplies the Clang check.

## Behavioral evidence

All 16 registrations pass: independent UInt8/UInt16/Int16 expected values;
exact versus ordinary Linear distinction; C1..C6; 2x Area redirect and C2
exception; same-size copy for all three integer depths; non-contiguous
Region versus clone; Float32/Float64 public rejection preserving Destination
and ordinary floating Linear success; rejection by all three Remap overloads,
affine/perspective/polar warps; raw selector 5 success, 6 rejection, old 0..4
mapping and subsequent recovery, raw floating fallback; allocation-free
overflow rejection preserving Destination and recovery.

No SPARK unit was materially changed; GNATprove was not run. No GNATcov
campaign was required for this focused operation. C++ helper sanitizer
execution does not claim sanitizer coverage of the installed OpenCV binary.
Exact-tag syntax checking does not claim runtime execution of 4.1.0/5.0.0.

The validation-boundary review found **no public semantic validation
duplicated in the C++ shim**. All retained native layout checks name concrete
signed arithmetic, allocation, or row-address failure modes.

PR and normal/manual CI evidence is recorded in the PR and final task report,
not predicted by this local validation record.