# Portable built-in and custom colormaps: exact-source review

## Evidence and limits

Reviewed exact OpenCV tags, not moving branches:

| Tag | Commit |
| --- | --- |
| [4.1.0](https://github.com/opencv/opencv/tree/4.1.0) | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| [4.10.0](https://github.com/opencv/opencv/tree/4.10.0) | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| [5.0.0](https://github.com/opencv/opencv/tree/5.0.0) | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

Inspected in each tag: `modules/imgproc/include/opencv2/imgproc.hpp`,
`modules/imgproc/src/colormap.cpp`, `color.cpp`, `color_rgb.dispatch.cpp`,
`color_rgb.simd.hpp`, `color.simd_helpers.hpp`. Also inspected 4.1
`modules/core/src/lut.cpp`, `modules/core/include/opencv2/core/private.hpp`,
and `modules/core/src/alloc.cpp`. Existing
[color safety findings](extended-color-source-review.md) inform the HAL review;
the Gray dispatch and relevant Carotene/RVV registrations were rechecked.

The production shim passes strict syntax checks with each exact tag's Core
and Imgproc headers (using a generated module-list header for configuration).
This is **source compatibility**, not three-version runtime validation.
Local runtime tests execute installed **OpenCV 4.10.0** only. Optional IPP,
OpenVX, ARM Carotene, FastCV and RVV runtimes are not claimed tested.

## Portable selectors and native definitions

The public `Built_In_Color_Map` enum has exactly twenty values. Its exhaustive
Ada case maps to repository-owned private selectors; a separate C++ table maps
those selectors to native constants:

| Private selector | Public literal | Native suffix |
| --- | --- | --- |
| 0 | Autumn_Map | AUTUMN |
| 1 | Bone_Map | BONE |
| 2 | Jet_Map | JET |
| 3 | Winter_Map | WINTER |
| 4 | Rainbow_Map | RAINBOW |
| 5 | Ocean_Map | OCEAN |
| 6 | Summer_Map | SUMMER |
| 7 | Spring_Map | SPRING |
| 8 | Cool_Map | COOL |
| 9 | HSV_Map | HSV |
| 10 | Pink_Map | PINK |
| 11 | Hot_Map | HOT |
| 12 | Parula_Map | PARULA |
| 13 | Magma_Map | MAGMA |
| 14 | Inferno_Map | INFERNO |
| 15 | Plasma_Map | PLASMA |
| 16 | Viridis_Map | VIRIDIS |
| 17 | Cividis_Map | CIVIDIS |
| 18 | Twilight_Map | TWILIGHT |
| 19 | Twilight_Shifted_Map | TWILIGHT_SHIFTED |

Native 4.1 has range 0..19; 4.10/5 add Turbo=20 and DeepGreen=21.
Neither newer constant is referenced in production source. Private negatives
and selectors >=20 reject even on newer native libraries.

Diffing `colormap.cpp` across the tags found **no changes to the twenty
portable LUT definitions or their construction**. 4.1->4.10 adds the two maps
and replaces execution; 4.10->5 changes the dimension assertion from `==2` to
`<=2`. The binding requires genuine 2-D nonempty inputs in all versions.
This does not promise arbitrary backend interpolation bit patterns identical.

## Source, table and result contracts

Both overloads require nonempty 2-D UInt8 C1/C3 Source. A C1 byte directly
indexes the table. C3 means **BGR -> Gray first**, not independent B/G/R
channel mappings. The native `COLOR_BGR2GRAY` conversion is used unchanged.
Result is fresh owning UInt8 C3 **BGR**, with the logical Source geometry.
No depth scaling, alpha, Ada LUT generation or interpolation is added.

The native custom overload checks `Size(1,256)` (width 1, height 256): the
portable Ada table is exactly **256 rows x 1 column UInt8 C3**, each row a
BGR triple. Table `(I,0)` is the entry for grayscale byte I, 0..255.
Horizontal 1x256 and other lengths/depths/channels/ND layouts reject publicly.

Custom C1 is *natively valid*, but not portable in output type:

- **4.1:** `ColorMap::operator()` feeds a C3 grayscale-expanded source to
  Core `LUT`; `LUT` creates output with the **source channel count**, hence C3
  even with a C1 LUT.
- **4.10/5:** the dedicated loop allocates with **LUT type**, hence C1 with
  a C1 LUT.

The portable public API therefore deliberately accepts only C3 tables. The
raw custom entry also excludes C1 as an **ABI compatibility condition** for
stable C3 output, not because native C1 is unsafe. It does not expand C1 to C3.

## Native pipelines

4.1 `colormap.cpp:676..690`:

```text
C3: clone -> BGR2GRAY -> clone -> GRAY2BGR -> LUT(C3 table)
C1: clone -> GRAY2BGR -> LUT(C3 table)
```

`linear_colormap` merges planes in B,G,R order and converts to CV_8U at scale
255, so all built-in tables are C3 BGR. Custom C3 shares the same operator.
The binding calls native `applyColorMap`; it does not emulate this pipeline.

4.10/5 `colormap.cpp:728..788`: C3 converts BGR2GRAY; C1 is used directly;
table must be continuous; destination is created with LUT type. Dedicated
parallel row loops index one C1 byte and copy one `Vec3b` for our C3 LUTs.

## Native arithmetic and allocation

4.1 Core LUT's iterator path contains `int len = (int)it.size` (lines 347,
406), then `LUT8u_` evaluates signed `len*cn` (lines 23,28). The internal
source is C3. Before *both* calls, division-based uint64 arithmetic establishes

```text
Rows * Columns * 3 <= INT_MAX
```

No product is evaluated in signed int. The guard bounds even a continuous
whole-image iterator plane, not merely a row. It also bounds `Columns*3`
packed strides, `width*height` in every reviewed `CvtColorLoop` scheduler,
color channel pointer advances, and output byte count. It introduces no
arbitrary dimension cap.

New loop scheduling uses `p=max(1,4096/cols)` and `(rows+p-1)/p`.
For cols>=1, p<=4096; the legacy bound implies rows<=INT_MAX/3, so
rows+p-1<=INT_MAX/3+4095<INT_MAX. No second tighter restriction is needed.

On supported 32/64-bit hosts, output bytes<=INT_MAX fit SIZE_MAX and
PTRDIFF_MAX. 4.1 fallback `fastMalloc` adds `sizeof(void*)+64`: even INT_MAX
plus that overhead fits 32-bit SIZE_MAX. Snapshot preflight additionally
checks total allocation against `SIZE_MAX-64-sizeof(void*)`, including raw
unsupported types that will later be rejected by native semantic checks.

## Logical-row snapshots and address spans

The shim does manual row copies into independent packed Mats, not
`clone/copyTo` on the caller's view (which may encounter IPP int step casts).
Before copying, widened division-based arithmetic checks

```text
(Rows-1) * original Step + logical row bytes
    <= min(SIZE_MAX, PTRDIFF_MAX)
```

and `Step >= logical row bytes`. Source logical row bytes are Columns for
C1, Columns*3 for C3. Table logical row bytes are 3 for 256 rows. Parent step
is not narrowed or arbitrarily restricted to INT_MAX. A wider-parent 256x1
table Region is repacked to continuous CV_8UC3, satisfying native continuity.
Only logical Region pixels participate, including C3 luminance conversion.

Once packed, source byte step is Columns or Columns*3; internal Gray has
Columns step, internal BGR/result Columns*3. Parent stride cannot reach
native color/LUT backends. Original source/table row spans remain the only
parent-stride restrictions.

## Backend reachability

4.1 Core LUT:

- **HAL LUT:** `lut.cpp` has no `CALL_HAL` LUT dispatch. Do not infer one
  from later Core versions or from color HAL dispatch.
- **IPP LUT:** C3 table/source can select `IppLUTParallelBody_LUTCN` and
  `ippiLUTPalette_8u_C3R` *if enabled*. It casts source/destination steps to
  int at line 256. Packed internal steps are Columns*3, bounded above.
  However exact 4.1 `core/private.hpp` defines `IPP_DISABLE_PERF_LUT=1`, so
  the LUT IPP implementation/call are compiled out in the unmodified tag.
- **OpenVX LUT:** `openvx_LUT` requires source, destination and LUT all
  CV_8UC1; the internal C3 source/C3 table makes this path unreachable.
- **OpenCL LUT:** gated by `_dst.isUMat()`. This binding uses local Mat
  results, so OpenCL is unreachable. Native color OpenCL also needs UMat.

4.10/5 lookup is the dedicated Mat CPU loop, not Core LUT, so LUT HAL/IPP/
OpenVX/OpenCL are not involved. C3 still reaches native BGR2GRAY dispatch.

Color conversion in all tags: BGR2GRAY/GRAY2BGR enter pointer-only HAL then
CPU dispatch. The reviewed BGR2GRAY IPP branches require Float32, so our
UInt8 BGR input bypasses them. 4.1 GRAY2BGR UInt8 C3 has an optional IPP
branch gated by `IPP_DISABLE_CVTCOLOR_GRAY2BGR_8UC3`; its narrowed strides
are packed and bounded. Carotene Gray registrations take ptrdiff-sized
strides and UInt8 layouts; packed spans/products satisfy those requirements.
5 RVV Gray loops use size_t steps, with the existing reviewed scheduling
products dominated by the portable bound. Exact FastCV files contain no
BGR2GRAY/GRAY2BGR override. No optional-vendor runtime execution is asserted.

## Ownership, aliases, errors and validation boundary

Core owns Mat handles; Imgproc borrows through the module bridge. Source
and (for custom calls) table are **fully snapshotted before native execution**.
A local result is moved to Destination only after complete success. Existing
Destination—including a Region—remains unchanged on failure and rebinds to
fresh storage on success. Destination=Source and Destination=Lookup_Table
work; Source/table shared storage also works. No borrowed handle is owned,
destroyed or retained by this crate.

Ada owns public depth/channel/source/table geometry policy. The shim lets
OpenCV reject unsupported types and table dimensions normally. Retained
duplicated conditions are:

1. Nonempty/2-D snapshot input: manual 2-D row addressing requires rows/cols;
   empty newer native input also risks division by zero in packet scheduling.
2. Custom C1 exclusion: stable cross-version **C3 output ABI compatibility**,
   explicitly not a claim of native memory unsafety.

Other new guards protect handles, stable private selector bounds, readable
spans, allocator arithmetic and legacy signed products. Each safety-looking
guard has an `ABI safety:` explanation. No duplicated friendly semantic
source-type or table-size checks, and no native-result restatement checks.

## Independent values and verification

Pinned BGR expectations at Source 0,64,127,255:

| Map | 0 | 64 | 127 | 255 |
| --- | --- | --- | --- | --- |
| Autumn | 0,0,255 | 0,64,255 | 0,127,255 | 0,255,255 |
| Jet | 128,0,0 | 255,128,0 | 130,255,126 | 0,0,128 |
| Viridis | 84,1,68 | 139,82,59 | 141,144,33 | 37,231,253 |

Autumn follows r=1,g=x,b=0. Jet follows its pinned piecewise ramps, sampled
at I/255 then scaled/rounded to bytes. Viridis uses pinned 256 float entries
(e.g. I=64 RGB=.229739,.322361,.545706), scaled by 255 and rounded.
Twilight pins both endpoints: RGB first .8857501584,.8500092494,.8879736506;
last .8857115512,.8500218612,.8857253899; both yield BGR 226,217,226.
Expectations do not call native applyColorMap a second time.

Custom table is B=I,G=255-I,R=I xor 0x55, checked at 0,1,64,127,200,255.
Independent unequal BGR inputs give grayscale 29,150,76,22, checked against
table formulas and Autumn—not another Apply_Color_Map result.

Baseline: 871 registered/executed/passed. Final: **905/905/905**, zero failed
assertions/unexpected errors; 34 focused registrations. One table-driven test
executes all twenty selectors and labels metadata/source assertions by map.
Regions are compared to packed clones; aliasing, independent storage,
public rejections, raw failures/sentinel preservation and recovery are tested.
Huge arithmetic boundaries use an allocation-free strict C++ helper, also
executed under ASan/UBSan, rather than allocating enormous Mats.

Project-owned Ada passes -gnatwa -gnatwc -gnatwu -gnatwn -gnatwe -gnatyM79
-Werror. Local forced baseline initially exposed generated -gnatVa validity
checks intercepting deliberate NaN/Infinity tests. Rebuilding with -gnatVn
allows existing explicit API checks to run; this does not disable warnings or
ordinary Ada range checks. Strict switches are scoped to owned sources, not
AUnit's third-party style. A separate detached clean Core checkout is used
for authoritative local verification; dependency metadata is unchanged.
The normal `alr -n build` and `alr -n -C tests run` commands also succeeded
locally (905 passed); the separate clean-Core strict run is the authoritative
result, avoiding reliance on the sibling Core's unrelated working changes.
One pre-existing impossible `String'Length > Integer_32'Last` comparison in
the modified library body was replaced with checked conversion and the same
OpenCV_Error translation, so -gnatwc passes without suppressing warnings.