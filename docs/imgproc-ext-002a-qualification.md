# IMGPROC-EXT-002A — isolated AArch64 configuration

Historical record. The production installer and installed-Core contract are
superseded by [IMGPROC-CROSS-UX-001](imgproc-cross-ux-001-qualification.md);
the original measurements below are preserved, not retroactively upgraded.

## Scope and disposition

This is opt-in configuration infrastructure, not a Yocto deployment release.
Native defaults, manifest constraints/development Core pin, public Ada API,
C++ production source and all representation assertions are unchanged.

* **GENERIC_CONFIG_QUALIFIED**: 30 synthetic fail-closed tests pass on host
  and Debian 12 Python 3.11, including
  exact-revision export, prepare, deletion/recreation, and native config preservation.
* **TARGET_PROBE_QUALIFIED**: actual Debian AArch64 GNAT/C++ minimal probes
  compile/link with explicit target GPR configuration. ELF headers establish
  ELF64 little-endian AArch64, not execution or production compatibility.
* **GNAT12_BLOCKED**: Core's production representation gate fails; no complete
  installed GNAT 12 target Core exists for Imgproc production qualification.
* **PRODUCTION_CROSS_BUILD_QUALIFIED is NOT established**.
* **YOCTO_SCARTHGAP_PENDING**: no Scarthgap SDK, target execution, production
  installation, or release qualification is established by Debian probes.

## Exact source identities

PR #64 merged. Freshly fetched parent/main:
`f9fb8cd9da6eb3be2fa44659a634ff9b18974349`. Qualified prerequisite feature
HEAD: `2d2849b978db7258d9763603d599d74817640524`.

Core PR #76 implementation and reproduced GNAT 12 failure:
`746acf20972e57b6099bc1f1861ae22e7ff1499a` (merge
`9380a832aaafd92ca4aacadb253d55dd33b5680c`). Native pinned Core reference:
`f4bd2167ecc0a74162a00c6597772a2a67ea84b0`.

The exact tested Imgproc feature HEAD is recorded in the PR qualification
comment and CI `source-sha.txt`, rather than a self-referential commit SHA in
this file. The workspace also records `source-revision.txt` and
`cross-evidence.json`. Local/remote/PR parity must be verified after pushing.

## Core review and adaptation

Reviewed all three Core scripts, synthetic tests, cross workflow, qualification
document and PR #76 corrective comments. Reused the naming contract, exact
compiler/runtime agreement, explicit GPR configuration, pkg-config sysroot
restriction, physical-path validation, and new-workspace export approach.

Imgproc additionally needs independent Core/Imgproc ELF checks, Imgproc headers,
the installed Core bridge, installed/external GPR project closure, Core Ada and
shim archives, target ALIs, and Core build identity. Core's successful probe
and shim object are insufficient substitutes for that installation.

The shell entry points use a standard-library Python validator to share these
controls without reproducing shell policy in three places. Python 3.11+ and
GNU `find`/`realpath`-compatible Linux filesystem behavior are reference tooling
requirements. Inputs must not change concurrently; this is not a sandbox.

## Contract and reproduction

All tools are external; the wrapper does not install SDKs or use Alire's host
system-dependency discovery in cross mode.

Required environment:

| Variable | Meaning |
| --- | --- |
| `OPENCV_CROSS_TARGET` | matching AArch64 Linux Ada/C++ target triple |
| `OPENCV_CROSS_ADA` | GCC/GNAT cross driver |
| `OPENCV_CROSS_CXX` | GNU C++ cross driver |
| `OPENCV_CROSS_RUNTIME` | compiler's runtime, with adainclude/adalib |
| `OPENCV_CROSS_GPR_CONFIG` | supplied target/runtime/compiler/linker CGPR |
| `OPENCV_CROSS_GPRBUILD`, `OPENCV_CROSS_GPRINSTALL` | explicit GPR tools |
| `OPENCV_CROSS_READELF` | optional, defaults to readelf |
| `ENV_PREFIX` | dedicated target development sysroot, never `/` |
| `OPENCV_CROSS_PKG_CONFIG` | explicit target pkg-config executable/wrapper |
| `PKG_CONFIG_LIBDIR` | nonempty target-only metadata directories |
| `OPENCV_CROSS_CORE_PREFIX` | installed target Core prefix inside sysroot |

`PKG_CONFIG_PATH`, compiler path overrides, Ada include/object paths and external
GPR project search paths must be empty. `PKG_CONFIG_SYSROOT_DIR`, if set, must
match physical ENV_PREFIX. OpenCV metadata may name logical `/usr` paths, but
flags must resolve physically inside the target sysroot. The supported metadata
closure is intentionally limited to Core/Imgproc/libstdc++; broad OpenCV package
flags containing unrelated modules fail closed. Headers/pkg-config version and
shared module SONAMEs must agree. Static archive package-version provenance
still requires independent SDK/package evidence.

The target Core install must include:

* `share/gpr/opencv_core.gpr`, `opencv_core_shim.gpr` and their target-only closure;
* `include/opencv_core_module_bridge.hpp`;
* `lib/opencv_core/libopencv_core_ada.a`,
  `lib/opencv_core_shim/libopencv_core_shim.a`, matching target ALIs;
* `share/opencv_core/cross-identity.json`, emitted/attested by its qualified
  build, with these fields:

```json
{
  "source_sha": "<actual 40-character Core source SHA>",
  "target": "aarch64-linux-gnu",
  "runtime": "/absolute/target/compiler/runtime",
  "ada_version": "12.2.0",
  "opencv_version": "4.6.0",
  "gpr_config_sha256": "<SHA256 of the supplied CGPR>",
  "library_kind": "static-pic"
}
```

This new Imgproc-specific integration attestation is **not** currently produced
by Core PR #76. It must only be supplied after a real Core build; it is not
permission to invent archives or certify GNAT 12 by hand. Installation layout
qualification against a real successful target Core remains pending. Text GPR
validation is complemented by actual compiler/linker probe traces; arbitrary
dynamic GPR expressions are not a supported untrusted configuration language.

```sh
sh scripts/configure_cross_opencv.sh --check
sh scripts/cross_build_imgproc.sh --prepare /absolute/new-prepare-workspace
sh scripts/cross_build_imgproc.sh --build /absolute/new-build-workspace
python3 -m unittest discover -s tests -p test_cross_configuration.py -v
```

Both workspace operations require a new absolute destination and clean source
Git HEAD. The wrapper rejects existing/dangling destinations and canonical
overlap in either direction with source/sysroot before mutation. It archives
that exact HEAD; source-tree config/objects/libraries/Alire state are not copied.
Target CGPR, config, probe objects, production objects, logs, libraries and
installation stay inside the disposable workspace. Delete only that workspace
to recreate. `--prepare` also executes probes; `--build` creates its own new
workspace and runs probes before production compilation/install. Production
errors retain original diagnostics and never disable ABI assertions.

`OPENCV_IMGPROC_CROSS=True` changes the existing configure entry point to
read-only target preflight, never native generation. Default `False` preserves
native behavior; unknown values are rejected. Use the isolated wrapper for
cross generation/build, not an Alire native checkout.

## Executed reference evidence

A new Podman container was derived from the existing Core PR #76 Debian 12
reference image without modifying that container. Reference snapshot image:
`b3eb5bdf4fc3f04256b1d5be1d7dfe0692346555b764c4ed7327d3af0c3e1770`.
Reference compiler packages `gnat-12-aarch64-linux-gnu` and
`g++-12-aarch64-linux-gnu`: `12.2.0-14cross1`.
`libopencv-core-dev:arm64`/`libopencv-core406:arm64`: `4.6.0+dfsg-12`.
Target Imgproc development/runtime packages `4.6.0+dfsg-12` were installed in
the new reference container, not the original Core container. No complete
target Core Ada installation was fabricated to proceed past its failed gate.
This is public Debian package provenance, not a Yocto sysroot.

Actual target: `aarch64-linux-gnu`; runtime:
`/usr/lib/gcc-cross/aarch64-linux-gnu/12/adalib`. GPRbuild 26.0.1 selected
`/usr/bin/aarch64-linux-gnu-gcc`, explicit `--RTS`, and the Core reference
`/reference/r2-head/tools/g++` cross-linker alias. The minimal Imgproc fixture's
Ada executable and C++ object both pass ELF64/little-endian/AArch64 checks.
The probe used the documented Debian reference sysroot
`/reference/r2-head/sysroot`; it does not establish complete target OpenCV/Core
installation resolution. No target executable was run.

Core production reproduction returned status 4. Original diagnostic:

```text
opencv-internal-c_api.ads:565:26: error: C Vec3 size mismatch
```

The unchanged assertion is
`Compile_Time_Error (Float64_Vec3'Size /= 192, "C Vec3 size mismatch")`.
Further representation errors and GNAT 12 warnings remain in the original
log. The affected production path stops here: no fabricated target Core install,
Imgproc production PASS, cross-GPRinstall, or consumer/runtime claim. This is a
Core blocker; Imgproc production GNAT 12 compatibility remains unverified.

## Native and hosted protection

Host GNAT 16.1 native build passes; all 1129 Imgproc AUnit tests pass.
Debian 12 GNAT 16.1/OpenCV 4.6 independent Core/Imgproc installation and
installed/relocated Ada and mixed C++ consumer qualification pass. Existing
Linux/macOS/Windows, Debian installed-consumer, GNATdoc and coverage workflows
are retained. Hosted results must be read from the submitted PR; local native
Linux tests do not certify macOS/Windows execution.

Dedicated cross CI records exact feature SHA, runs synthetic negative/positive
controls, shell syntax/static checks and uploads evidence. It explicitly reports
target compilation/execution NOT RUN; no fabricated SDK/runtime PASS. A
reproducible Yocto SDK environment is not made a mandatory hosted dependency.

GNATformat was run on the minimal Ada fixture. No SPARK implementation changed,
so no GNATprove campaign is required for this configuration-only task. No
production C++ shim source changed; no public semantic validation is duplicated
in the C++ shim by this task. Release gates remaining: compatible Core target
production build, alignment/representation safety, real installed Core integration,
Imgproc production build/install/consumers, complete target search resolution,
actual target execution and Yocto Scarthgap SDK qualification.