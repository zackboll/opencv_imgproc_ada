# AArch64 GNAT Pro / Scarthgap Imgproc build and installation

Use `scripts/cross_install_imgproc.sh` from a **clean Git checkout**, or select
an unpacked, Git-free release/Alire source directory with `--source-root`.
Python 3.11+, Linux/GNU filesystem tools, pkg-config, readelf, GPRbuild,
GPRconfig and GPRinstall are required. No Alire installation is needed by the
cross installer or installed consumers. Tools and SDK inputs must remain stable
during a run; this is not a concurrent-mutation sandbox.

## Intended profile and independent roots

The intended vendor profile is **AdaCore GNAT Pro 25.0w, GCC 12.3.1**, target
`aarch64-linux-gnu`, explicit `rts-native`, Yocto **Scarthgap** development
sysroot, OpenCV **4.9.0**, and an authentic installed target Core. It is not
Debian GNAT 12.2.0, nor historical GNAT Pro 25.2/GCC 13.3.1.
See [qualification and outstanding gates](imgproc-cross-ux-001-qualification.md)
before interpreting this as vendor qualification.

```sh
sh scripts/cross_install_imgproc.sh \
  --target aarch64-linux-gnu \
  --toolchain-bin /usr/local/gnat/aarch64-linux-gnu/bin \
  --runtime /usr/local/gnat/aarch64-linux-gnu/lib/gcc/aarch64-linux-gnu/12.3.1/rts-native \
  --sysroot /usr/local/yocto/scarthgap/aarch64 \
  --core-prefix /usr/local/lib/aarch64-linux-gnu/ada \
  --prefix /usr/local/lib/aarch64-linux-gnu/ada \
  --profile release
```

These paths are examples, not constants. Core and Imgproc prefixes may be
**identical or disjoint**, but not nested. Core may be outside the sysroot;
it is never copied into the sysroot. Keep a native installation separate, for
example `/usr/local/lib/x86_64-linux-gnu/ada`. Neither library objects, generated
projects nor Alire state are written to the source checkout.

`--sysroot` sets the existing `ENV_PREFIX` contract. `--target`, `--runtime`,
`--core-prefix`, and `--prefix` also accept the existing environment defaults
`OPENCV_CROSS_TARGET`, `OPENCV_CROSS_RUNTIME`, `OPENCV_CROSS_CORE_PREFIX`, and
`OPENCV_CROSS_INSTALL_PREFIX`. `--runtime` is never guessed. Profiles are
`release` (installer default), `development`, and `validation`. Production Ada
retains its default/Ada 2012 policy, warnings-as-errors and representation gates;
the workflow does not globally enable Ada 2022.

## Required installed Core and minimum dependency

The prefix must contain externally-built projects `share/gpr/opencv_core.gpr`
and `opencv_core_shim.gpr`, their complete import/source closure,
`include/opencv_core_module_bridge.hpp`,
`lib/opencv_core/libopencv_core_ada.a`,
`lib/opencv_core_shim/libopencv_core_shim.a`, and the production ALIs.
All archive members must be ELF64 little-endian AArch64. A freshly compiled Ada
probe must have the **complete** ALI version signature of both the selected
runtime and installed Core. GCC major-version equality is not an ALI identity.
When the compiler answers literal `adalib`, the matching toolchain's GNATLS is
used and both complete Source and Object search sections are checked.

No user-authored identity file is required. Old `cross-identity.json` metadata,
if present, is checked as supplementary evidence. Different CGPR hashes do not
make equivalent tool/runtime selections incompatible. Real Ada compile/bind/link,
C++/OpenCV and installed Core/Imgproc consumer links remain mandatory.

Imgproc **0.3.0** selects **Core `~0.5.0`** through ordinary Alire resolution,
without production pins. Core 0.5.0 contains the layout/language/warning fixes
needed for complete GNAT 12 production builds (merged Core PRs #77–81). Core
0.5.2's convenience installer is not required. The external installed-Core
workflow still consumes an independently built, compiler/runtime-compatible
Core prefix, not an Alire source override. The existing Debian full-cross
reference uses Core 0.5.2 source and is not lower-bound evidence; separate
actual-0.5.0 controls and pin-free consumers are tracked in the
[0.3.0 release qualification](imgproc-rel-005-qualification.md).
The Arch availability exclusion remains unchanged.

## Automatic configuration and advanced inputs

An explicit `OPENCV_CROSS_GPR_CONFIG` is validated. Otherwise a compatible Core
configuration may be reused; Core need not have saved one. Generation uses the
actual selected driver directories and C++ executable basename:

```sh
gprconfig --batch --target="$target" \
  --config="Ada,,$runtime,$ada_compiler_directory,GNAT" \
  --config="C++,,,$cxx_compiler_directory,$cxx_executable_basename" -o "$config_file"
```

The installer supplies a scoped knowledge-base discovery entry for that exact
C++ basename: older GPRconfig databases recognize only unprefixed `g++`. It
does not create compiler aliases or edit generated CGPR output. Both target
spellings `aarch64-linux-gnu` and canonical `aarch64-linux` are accepted.
Missing C++, wrong drivers/runtime, and host selections are rejected, including
through actual verbose compiler/binder/archiver/link traces.

Advanced executable overrides (all remain validated):

* `OPENCV_CROSS_ADA`, `OPENCV_CROSS_CXX`;
* `OPENCV_CROSS_GPRBUILD`, `OPENCV_CROSS_GPRINSTALL`, `OPENCV_CROSS_GPRCONFIG`;
* `OPENCV_CROSS_PKG_CONFIG`, `OPENCV_CROSS_READELF`;
* `OPENCV_CROSS_GPR_CONFIG` for an explicit saved configuration.

Set `PKG_CONFIG_LIBDIR` for a nonstandard target layout; every entry and target
OpenCV header/library must stay physically inside `ENV_PREFIX`. Defaults search
existing sysroot `usr/lib/pkgconfig`, `usr/lib/TARGET/pkgconfig`,
`usr/lib64/pkgconfig`, `usr/share/pkgconfig`, and `lib/pkgconfig`. Host
`PKG_CONFIG_PATH`, compiler/Ada/project search injections and `LD_LIBRARY_PATH`
are rejected. No Yocto environment script is sourced; `CC`/`CXX` strings and
BitBake are not used. Vendor origin must be established from your SDK records,
not guessed from a path or banner.

Optional CPU/ABI flags are JSON arrays, e.g.:

```sh
export OPENCV_CROSS_ADA_FLAGS='["-mcpu=cortex-a53", "-mabi=lp64"]'
export OPENCV_CROSS_CXX_FLAGS='["-mcpu=cortex-a53", "-mabi=lp64"]'
```

Only `-march=`, `-mcpu=`, `-mtune=`, and `-mabi=lp64` are accepted. They are
passed to real compilation/linking and retained in evidence; unsupported flags
fail, rather than being silently ignored. Link compatibility checks compare
the linked output's actual GLIBC, GLIBCXX, CXXABI and GCC version requirements
against the selected target definitions, not compiler-version equality.

## Staging, publication, durable files and recovery

`cross_build_imgproc.sh` / `cross_configuration.py` remain the single production
backend. The installer bootstraps it, stages **only Imgproc** with nonrecursive
GPRinstall, verifies the installed import closure and archives, and links both
staged consumers before publication. No Core project, metadata or saved CGPR is
reinstalled or overwritten. Existing Core bytes are inventoried and compared.

The installed closure includes:

```text
share/gpr/opencv_imgproc.gpr
share/gpr/opencv_imgproc_shim.gpr
lib/opencv_imgproc/libopencv_imgproc_ada.a
lib/opencv_imgproc_shim/libopencv_imgproc_shim.a
share/gprconfig/opencv_imgproc-aarch64-linux-gnu.cgpr
share/doc/opencv_imgproc/LICENSE
```

GPRinstall supplies required ALIs, sources/headers and generated project closure.
Imports are generated correctly, never patched after installation. The durable
CGPR selects external SDK/tool paths and outlives the disposable build workspace.
After successful publication that workspace is removed, then fresh installed-only
consumers are built outside it. Logs, source identity, tool banners, runtime/Core
inventories and output identities are retained in the printed evidence directory.
Git builds record exact HEAD; explicitly selected Git-free trees record a
deterministic `staged-sha256:` identity after excluding native/generated state.

The entire publication is conflict-checked before any file is copied. Files
are created exclusively: an existing Imgproc installation is not upgraded in
place. On failure the original failing tool status and diagnostic locations are
reported, and work/evidence are retained. No external prefix is ever deleted as
rollback. An interrupted publication can leave new files: inspect the retained
staging inventory, preserve Core, remove **only demonstrably newly created
Imgproc files**, or select a fresh separate prefix. Never `rm -rf` a shared
Core/Imgproc prefix. Only writing the requested prefix needs permissions; no
automatic sudo is used.

## Independent installed and relocated consumers

For automatic full qualification, choose a fresh nonexistent Imgproc prefix:

```sh
qualification=$(mktemp -d /tmp/imgproc-cross-qualification.XXXXXXXX) &&
sh tests/cross/qualify_imgproc_cross_install.sh \
  --target aarch64-linux-gnu \
  --toolchain-bin /usr/local/gnat/aarch64-linux-gnu/bin \
  --runtime /usr/local/gnat/aarch64-linux-gnu/lib/gcc/aarch64-linux-gnu/12.3.1/rts-native \
  --sysroot /usr/local/yocto/scarthgap/aarch64 \
  --core-prefix /usr/local/lib/aarch64-linux-gnu/ada \
  --prefix "$qualification/imgproc" --profile release
```

Unset `OPENCV_CROSS_GPR_CONFIG` first: qualification **forces generation**, not
reuse. Both independent Ada and mixed Ada/C++ consumers call actual Imgproc
operations through Core-owned Mats. Qualification checks all four installed
archives in each link, compiler/binder/archiver paths, actual linker inputs,
ELF/interpreter, dependency and symbol-version closure, complete ALI signatures,
absence of source/build fallback and RPATH/RUNPATH. It repeats using copied,
relocated Core/Imgproc prefixes and forbids original-prefix fallback. Original
Core is never moved. Only the exact four validated `PREFIX/lib/PROJECT`
directories get the consumer-specific `-L` allowance, including under
`/usr/local/lib`; production/probe validation is not weakened.

Actual linker inputs may use the selected Ada runtime's exact resolved
`adalib/libgnat.a`, `libgnarl.a`, `libgnat.so` and `libgnarl.so`; this does not
authorize other libraries in that directory or identically named libraries in
an unselected runtime. ELF architecture validation and hashing still apply.
The Debian reference CI runs a separate real static-Ada-runtime link control;
its binder `-static` choice is local to that control, not production policy.

glibc 2.34 and later can supply empty link-time compatibility archives. Only
`libdl.a`, `libpthread.a`, `libutil.a`, `libanl.a`, and `librt.a` are eligible:
the supplied and canonical names must be approved, the canonical target must
be an existing regular file physically within the validated target sysroot,
and its complete contents must be exactly the eight bytes `!<arch>\n`.
These archives are optional. Accepted paths, sizes and SHA256 hashes are
recorded separately as `empty_compatibility_archives`, not architecture-checked
ELF objects. Traced inputs also have an adjacent
`.empty-compatibility-archives.json` evidence file. They are excluded from
initial ELF dependency roots and can **never** provide a recursive `DT_NEEDED`
dependency. Nonempty compatibility archives still undergo ordinary archive-member
architecture checks. Required GNAT, OpenCV, Core and Imgproc libraries are not
exempt. The SDK archives and installed Core are never repaired or rewritten.
See the [glibc 2.34 announcement](https://sourceware.org/pipermail/libc-announce/2021/000032.html).

Manual ordinary GPRbuild example, from a fresh directory containing copied
`tests/installed_consumers` sources (no Alire):

```sh
export GPR_PROJECT_PATH="$CORE_PREFIX/share/gpr:$IMGPROC_PREFIX/share/gpr"
gprbuild --config="$IMGPROC_PREFIX/share/gprconfig/opencv_imgproc-aarch64-linux-gnu.cgpr" \
  -P ada_consumer.gpr -p -v -R \
  -cargs:Ada "--sysroot=$ENV_PREFIX" \
  -largs "--sysroot=$ENV_PREFIX" -Wl,-t \
  "-Wl,-rpath-link,$ENV_PREFIX/usr/lib" "-Wl,-rpath-link,$ENV_PREFIX/lib"
```

For `mixed_consumer.gpr`, also pass
`-XCONSUMER_CXX=/absolute/selected/aarch64-linux-gnu-g++`,
`-XCONSUMER_OPENCV_INCLUDE=-I$ENV_PREFIX/usr/include/opencv4`, and
`-cargs:C++ --sysroot=...` before `-largs`. Add target multiarch/loader library
directories to `-rpath-link` as required; the qualification driver derives them
from the sysroot's loader configuration. For relocation, copy both prefixes,
set `CORE_PREFIX`/`IMGPROC_PREFIX` and `GPR_PROJECT_PATH` to those copies, and use
the copied Imgproc CGPR; never move the user's production Core. `-R` prevents
GPRbuild runtime-path injection. `-rpath-link` is link-time resolution only, not
a deployed runtime loader path.

Cross-link PASS is **not execution**. Deploy the actual DT_NEEDED closure and
qualify on hardware or an explicitly recorded emulator separately. Until then:
`TARGET_RUNTIME_PENDING`.