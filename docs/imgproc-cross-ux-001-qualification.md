# IMGPROC-CROSS-UX-001 qualification record

## Source reconciliation and scope

Fetched origin before starting. Main was exactly
`a49ca6ee4dfbfd007c44a5cc7a0edbc1533d980f`, tree
`291782ea2f66c4b94bc62ca0aa3506fb21099d53`. PR #77 is merged at that commit;
there were no subsequent Imgproc main changes to reconcile at initial fetch.
The isolated branch is `feature/imgproc-cross-ux-001`; the original checkout and
all unrelated worktrees were preserved. Final local/remote/PR SHA and tree,
hosted run identities and their dispositions are recorded in the PR handoff
rather than introducing a self-referential commit hash in this document.

Core PR #92 is merged (`2267853c089b4fcbc2c7496ae97f862db9dd1234`). Current
Core reference after its #93 release preparation is
`aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d`. Geometry PR #55 was refreshed:
OPEN at `ff4089671cb11837416fe1aa9892018c5fa24fda`, awaiting vendor results.
Its bootstrap, exact consumer-library-directory controls and corrective
findings were reviewed independently. Geometry results are **not Imgproc
qualification**. Neither Core nor Geometry was modified by this task.

Implementation extends the existing production backend, not another preflight
adapter: automatic real-driver GPRconfig; independent installed Core/sysroot
roots; complete fresh/runtime/Core ALI checks; staged nonrecursive installation;
exclusive conflict-aware publication preserving Core; durable Imgproc CGPR;
post-cleanup independent Ada/mixed consumers and relocated copies. See the
[workflow and recovery guide](cross-install-imgproc.md).

No production Ada API, algorithm, representation assertion or production C++
shim source changed. PR #77's macOS SDK propagation and isolated thread test,
and the 1,178 parent AUnit registrations, are preserved.
**No public semantic validation is duplicated in the C++ shim by this task.**

## Measured environments and results

### Native

Linux x86_64; Alire 2.1.1; Alire GNAT 16.1.0 / GPRbuild 26.0.1 distribution
(banner 26.0.0, 2026-04-15); native OpenCV 4.10.0. Ordinary production metadata
remains Imgproc 0.2.1 with Core `~0.4.1`, resolving indexed Core 0.4.1 without a
development pin.

* `alr -n build`: PASS, no new compiler warnings.
* `alr -n -C tests run`: **1,178 tests, 1,178 successes, zero failed assertions
  or unexpected errors**.
* GNATdoc 26.0.0 generation: **zero warnings**, complete links/anchors,
  compiled guide examples, **1,596/1,596 coverage items**.
* Cross/configuration/install synthetic controls: **64 tests, 62 pass, two
  explicitly skipped genuine-SDK controls**. These are not compiler evidence.
* Actual Debian AArch64 source-unit/language-policy controls: **4/4 PASS**.
  Native Debian GNAT 12 controls also pass **4/4**, after installing the real
  frontend in a task-owned disposable container; ShellCheck passes there.
  The direct host GCC-12 attempt was unavailable (`gnat1` absent), not a pass.

No production Ada/SPARK source changed, so a proof campaign is not applicable.
The only GPR consumer change adds external C++ driver/include inputs with the
existing native defaults. No native language mode was changed.

### Real public-toolchain production reference

Disposable Podman reference image
`localhost/geometry-rel004-debian-aarch64:latest` (image `0cbf16aac9eb`), Debian
12/bookworm. Actual Ada/C++ target drivers are `/usr/bin/aarch64-linux-gnu-gcc`
and `/usr/bin/aarch64-linux-gnu-g++`, Debian GCC/GNAT **12.2.0**, runtime
`/usr/lib/gcc-cross/aarch64-linux-gnu/12`, ALI signature `V "GNAT Lib v12"`.
GPRbuild/GPRconfig/GPRinstall are `/opt/gprbuild-26/bin/*`. Target OpenCV is
Debian **4.6.0**, from an explicitly staged Debian development sysroot, not
Scarthgap. Installed Core used by the initial successful qualification is
**0.5.0**, source `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`; its existing
installed artifacts were inspected and linked, never rebuilt or edited as a
workaround.

Initial complete reference run at implementation
`abe09ed724d2c689c55d3d614cbad5184ababf22` passed:

* automatic CGPR generation using actual prefixed drivers, no aliases;
* complete Imgproc production Ada and actual C++ shim compilation;
* installed Core **outside** the sysroot, no invented identity file;
* staged both Imgproc projects, archives, ALIs, source/header closure and license;
* staged Ada/mixed links before publication;
* production workspace removed;
* fresh installed and relocated Ada/mixed links, with all four Ada/shim archives;
* ELF64 little-endian AArch64, target interpreter and native Core/Imgproc
  dependencies, no inappropriate RPATH/RUNPATH, complete target dependency and
  actual symbol-version closure; no original-prefix fallback during relocation;
* original installed Core byte inventory preserved.

Private local evidence root:
`/home/zboll/work/imgproc-cross-ux-001`. Initial full run log:
`debian-attempt8.log`, durable evidence directory
`opencv-imgproc-evidence-rivmumjr` (includes `installation.json`, source identity,
production/probe/install logs, three consumer evidence sets, `dispositions.txt`).
The installed target CGPR is beneath the task's separate `imgproc` prefix.
Subsequent final-head reruns and shared-prefix/Git-free controls are recorded
in the PR handoff. At `e7464b4d480e7804dc7cc06447ca5f4fcb12d8d2`, the hardened
full run (`debian-attempt12.log`, `opencv-imgproc-evidence-qecf9xi2`) passes
with actual CPU/ABI flags `-mcpu=cortex-a53 -mabi=lp64`, strict actual linker
input checks and target-first runtime search. A second real build/install
from a Git-free export (`shared-archive.log`, `opencv-imgproc-evidence-z1lxmdj0`)
passes against a task-owned **shared** Core/Imgproc prefix, preserving all
existing bytes. Its source identity is
`staged-sha256:5794d6cf7a98e915123f912b615a993be268a19257334ce8121b42c5a3ee3984`.
Genuine Debian sysroot integration controls pass **41/41**, separately from
synthetic results. An earlier implementation run alone is not final-head
qualification. All failed-attempt diagnostics were retained, including the
GPRconfig database discovery gap and the overly broad staged-prefix rejection;
neither was bypassed by editing installed projects.

Fresh hosted sysroot construction also exposed a real missing-input issue:
`dpkg-deb -x` does not run BLAS/LAPACK postinst alternatives, so the SONAME links
were missing. The Debian test builder now derives contained literal library
alternatives from downloaded package metadata without executing maintainer
scripts; production dependency validation remains strict. This is test-fixture
construction, not a whitelist or a change to user SDKs.

At `360e47175ad9287f3e71c3dd58144e63094b07d8`, local full qualification
passed again (`debian-final.log`, `opencv-imgproc-evidence-dx4x_y9o`), including
the effective-runtime-switch and cwd-isolation corrections. Shared-prefix
Git-free build/install passed (`shared-final.log`,
`opencv-imgproc-evidence-fqrjz39z`), followed by installed and relocated links
(`shared-relocation-complete-evidence`). Hosted full cross install
`39367727598`, target-dependency `39367727580`, GNAT 12 `39367727597`, and
Debian native installed/relocated consumers `39367727531` passed at that head.
Later final-head artifacts/results are in the PR handoff. Final hardening also
retains GNATLS output from either stdout or stderr, inventories compiler-selected
linker/archiver binaries, and stages the shim's required local header closure.

## Hosted and vendor gates

The existing Homebrew/MacPorts standalone SDK, cross-platform Windows/MSYS2,
Debian installed consumers, GNAT 12, target dependency and documentation jobs
are retained. Added full Debian production cross-install CI builds its own
Core prerequisite and sysroot, then calls this same installer/qualification
backend. Hosted logs/artifacts at the **final PR head** are the authority;
earlier-head or local results do not qualify those platforms.

The intended AdaCore `/usr/local/gnat/...` toolchain, selected `rts-native`,
Scarthgap sysroot and OpenCV 4.9.0 are **not present locally**. No proprietary
compiler was substituted. Debian 12.2.0 and synthetic tests do not establish
GNAT Pro 25.0w/GCC 12.3.1 qualification. Historical Pro 25.2/GCC 13.3.1 evidence
is also not this profile.

**VENDOR_QUALIFICATION_REQUIRED** until the final source SHA's one-command
driver completes real full production compilation, installation, installed
Ada/mixed links and relocated Ada/mixed links with the intended inputs. The
[pasteable driver command](cross-install-imgproc.md#independent-installed-and-relocated-consumers)
uses a fresh temporary Imgproc prefix and never writes the production shared
prefix. Returned logs must be inspected before clearing that gate.

**TARGET_RUNTIME_PENDING** independently: no target or emulator execution is
claimed. Build/link qualification does not establish calling-convention behavior
on hardware or deployment correctness.

## Dependency/release disposition

Core 0.5.0 contains the first complete GNAT 12 production fixes; Core 0.5.2 is
not required merely for its installer or saved configuration. Native indexed
Core 0.4.1 remains qualified separately. This installed-Core workflow does not
pretend ordinary Alire `~0.4.1` resolution supplies newer fixes. A subsequent
release must decide whether to broaden the production dependency for an Alire
cross-profile promise and qualify that decision. No release version, tag or
index submission is changed here. Preserve the Arch exclusion.

Alire-index publication remains pending independent source review, merge and
qualification of the resulting release candidate. The source PR is to remain
non-draft, open/unmerged, with auto-merge disabled. Pending/failed hosted checks
and the vendor gate must remain visible; do not label the task
`READY_FOR_INDEPENDENT_REVIEW` while those required gates are outstanding.