# IMGPROC-EXT-001: independent installed consumers

## Scope and source identities

Initial fetched `origin/main` commits (isolated sibling worktrees):

* Imgproc: `9dad3245321953e6fb887e0a65bbdccf890eb59c`.
* Core: `f4bd2167ecc0a74162a00c6597772a2a67ea84b0`.

The dedicated workflow pins that Core commit. Each qualification records both
tested commit SHAs, the Imgproc working diff/status, and the container image ID
in `source-revisions.log`. The final tested Imgproc SHA is reported in the PR
and handoff; it cannot be embedded in its own commit. Existing worktrees and
branches were preserved.

This extends the two-container design of
[Core PR #75](https://github.com/zackboll/opencv_core_ada/pull/75): prepare with
Alire, install using GPRinstall, then directly build independent consumers in a
second container with no binding checkout mounted and Alire removed. Evidence
is staged separately with readable permissions, without publishing compiler
toolchains, binding sources, archives or executables.

## Installation defects corrected

1. The original Imgproc shim GPR searched only `<Core project directory>/cpp`.
   Core installs its bridge as `<prefix>/include/opencv_core_module_bridge.hpp`,
   while the installed project is under `<prefix>/share/gpr`. A fresh build
   against installed Core failed with `opencv_core_module_bridge.hpp: No such
   file or directory`. Add the Core-project-relative `../../include` search
   directory while retaining the original checkout path for existing CI.
2. GPRinstall serialized top-level `Common_Cxx_Switches` into the externally
   built installed shim project, embedding the original Core prefix. Move this
   build-only variable into `Compiler`; GPRinstall now omits the compiler-only
   settings. Installed projects contain prefix-relative source/library paths
   and only system OpenCV link settings. No post-install rewrite or weakened
   relocation check is used.

No production Ada/C++ source, public API, C ABI, manifest or library version
changes. No public semantic validation is duplicated in the C++ shim.

## Reproduce

Place Imgproc and the exact Core commit in sibling `imgproc` and `core`
directories. From their parent directory:

```sh
docker build -t imgproc-debian12-qualification imgproc/containers/debian12-consumers
IMGPROC_CONSUMER_EVIDENCE=/absolute/private/evidence \
IMGPROC_CONSUMER_ARTIFACTS=/absolute/publishable/artifacts \
  sh imgproc/scripts/qualify_debian12_consumers.sh
```

Both evidence destinations must initially be empty and artifacts must be outside
private evidence. For Podman set `CONTAINER_ENGINE=podman`; an alternate image
can be selected with `IMGPROC_CONSUMER_IMAGE`. `IMGPROC_CORE_SOURCE` overrides
the sibling Core directory. The container recipe selects GNAT 16.1.0 and the
Alire gprbuild 26.0.1 package. Debian package versions/image IDs are recorded
because `debian:12` and Debian package repositories may receive updates.

Preparation builds Core with Alire, recursively GPRinstalls Core, and compares
the installed bridge byte-for-byte with its source. The full hand-written
Imgproc AUnit suite runs through its existing test crate. A fresh Imgproc build
uses only Core's installed project closure via `GPR_PROJECT_PATH`, not its
development Alire pin. Imgproc and its shim are separately GPRinstalled without
recursively reinstalling the externally built Core dependency.

The consumer container mounts only the installed prefix/consumer payload, logs,
and selected GNAT/GPR toolchains. It has no Core/Imgproc checkout, no Alire
executable, no consumer Alire manifest, no inherited include/library search
paths, and no custom `LD_LIBRARY_PATH`. It builds both GPR projects directly.
The mixed application compiles its own C++ with Debian `/usr/bin/g++`, calls
OpenCV Core/Imgproc itself, and contains exceptions at its C boundary. No Mat
pointers or binding handles are exchanged with application C++.

`prefix-a` is then moved to `relocated-longer-prefix-b`. The old prefix must be
absent. Both applications are rebuilt from fresh object directories and rerun.
Installed project metadata, resolution/build traces, ELF and ldd evidence are
checked for checkout/original-prefix requirements. Consumer link traces must
include installed Core and Imgproc archives. `readelf` records ELF headers,
dynamic sections and symbol tables; `ldd -r` verifies both consumers and system
OpenCV libraries have no missing dependencies or unresolved symbols.

## Qualified environment and results

Local qualification uses the checked-in container recipe with Podman:

* Debian 12, amd64/x86_64.
* Alire 2.1.1 in builder only; GNAT 16.1.0.
* Alire gprbuild package 26.0.1; GPRbuild/GPRinstall banners 26.0.0,
  2026-04-15; GPRinstall engine 2.
* Debian OpenCV 4.6.0+dfsg-12; native SONAMEs
  `libopencv_core.so.406` and `libopencv_imgproc.so.406`.
* Application C++: Debian GCC 12.2.0; libstdc++6 12.2.0-14+deb12u1;
  libc6 2.36-9+deb12u14; binutils 2.40-2.
* Ada runtime: GNAT 16.1.0 `adalib/libgnat.a`, as recorded in link traces.

Independent Core and Imgproc install, pure Ada/mixed consumers, fresh relocated
builds/runs, and ELF/ldd checks passed locally. Full AUnit: **1,129 successful
tests, zero failed assertions, zero unexpected errors**.

Both applications exercise color conversion, Gaussian blur and resize; Core
typed access; a non-contiguous Region source; independent output storage;
destination replacement retaining shallow aliases; output Region survival
after reassignment; specific `OpenCV_Error` behavior and destination retention
after invalid color conversion; invalid Region and native LUT exception
translation; repeated scopes and controlled reassignment/cleanup. Cleanup is
behaviorally exercised, not a leak proof.

The dedicated `debian12-consumers.yml` workflow uploads logs, generated installed
GPRs, GPRinstall manifests, file inventories/checksums and ELF/runtime evidence.
Existing Linux/macOS/Windows workflow jobs are unchanged. Hosted results remain
subject to the actual PR checks; local Podman results are not Docker CI claims.

## Dependency/release disposition and exclusions

The production manifest retains the development-only `../core` path pin and
`opencv_core = "~0.1.0"`. The qualified Core checkout declares `0.5.0-dev`;
the path-pinned development build is not evidence that the existing version
constraint resolves an independently published compatible dependency.

Before an eventual unpinned Alire release, remove the development pin and select
a dependency constraint matching a published, ABI-compatible Core version that
actually supplies the required Mat/module bridge/shared types. Validate clean
index resolution, all supported toolchains and installation against that
release. No constraint change, pin removal, Alire index submission or clean
unpinned resolution claim is made here.

Only Debian 12/OpenCV 4.6/GNAT 16.1 default static-PIC installs and rebuilding
consumers after relocation are qualified. Shared-library install modes,
moving already-linked executables, GNAT 12, Yocto, cross-compilation and other
compiler/runtime ABIs are out of scope. GNATprove/coverage were not run because
production Ada/SPARK code is unchanged. No Core dependency/ABI blocker remained
in this qualified configuration; safety checks were not bypassed.