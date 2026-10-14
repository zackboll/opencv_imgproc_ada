# Color conversion and image representation

Imgproc works on `OpenCV.Core.Mat`, which `opencv_core` owns. This guide
summarizes the parts of that model Imgproc relies on, then covers color
conversion, packed YUV frames, Bayer demosaicing and color maps. For Mat
lifetime, shallow copies and views in depth, read the Core guide
[Ownership and views](https://zackboll.github.io/opencv_core_ada/guides/ownership-and-views.html).

## Images, channels and depths

A Mat has rows, columns, a depth (`UInt8`, `Int8`, `UInt16`, `Int16`,
`Int32`, `Float16`, `Float32` or `Float64`) and a channel count. The API
documentation writes element types as depth and channel count, so
"UInt8 C3" is three UInt8 channels per pixel. Color images follow OpenCV's
conventions: three-channel images are BGR unless a declaration says RGB,
and four-channel images add alpha last. Coordinates are zero-based; a
`Point` has `X` (column) and `Y` (row), and a `Size` has `Width` (columns)
and `Height` (rows).

Ada assignment of a Mat is shallow: both objects share the same pixels.
`Clone` makes an independent copy. A Region (`Image.Region (Area)`) is a Mat
header that views part of another Mat, so writing through a Region changes
the parent. Operations borrow their Mat arguments only for the duration of a
call; a Mat of mode `in` is not modified.

Each operation documents how it produces its result:

- functions such as [Decode_YUV420](api:Decode_YUV420) and
  [Demosaic_Bayer](api:Demosaic_Bayer) return fresh owning Mats built from
  independent snapshots of their inputs;
- [Convert_Color](api:Convert_Color) and
  [Apply_Color_Map](api:Apply_Color_Map) compute privately and rebind
  Destination only after success, so Destination may be Source itself and a
  failure leaves it unchanged.

## Color conversion

[Convert_Color](api:Convert_Color) takes a nonempty 2-D Source with exactly
the channel count named by the [Color_Conversion](api:Color_Conversion)
literal. Destination keeps Source's geometry and depth; its channel count is
fixed by the conversion. Each of the 86 literals documents its source and
destination layouts and depth restriction:

- layout, gray, XYZ, YCrCb and YUV conversions accept UInt8, UInt16 and
  Float32;
- HSV, HLS, Lab and Luv accept UInt8 and Float32;
- packed BGR565/BGR555 and premultiplied-alpha conversions accept UInt8
  only.

Hue uses OpenCV's encodings: degrees for Float32, half-degrees for standard
UInt8 HSV/HLS, and the full byte range for the `_Full` UInt8 selectors,
whose round trips are not exact. The linear-light Lab and Luv selectors omit
sRGB transfer encoding. Premultiplication by alpha is lossy because of
quantization, especially at low alpha.

## YUV frames

The 4:2:0 operations work on packed frames: a UInt8 C1 Mat with W columns and
`H + H / 2` rows, where W and H are even and at least 2.
[YUV420_Layout](api:YUV420_Layout) selects I420, YV12, NV12 or NV21.
[Decode_YUV420](api:Decode_YUV420) and
[Decode_YUV420_Two_Plane](api:Decode_YUV420_Two_Plane) return BGR or RGB,
optionally with alpha 255; [Encode_YUV420_Planar](api:Encode_YUV420_Planar)
encodes planar layouts and samples chroma from the top-left pixel of each
2 x 2 block without averaging. [Extract_YUV420_Luma](api:Extract_YUV420_Luma)
returns the raw Y bytes. A packed Region must contain a complete standalone
frame. Conversion uses OpenCV's limited-range BT.601 arithmetic; vendor
acceleration can round differently.

[Decode_YUV422](api:Decode_YUV422) handles UYVY, YUY2 and YVYU frames stored
as UInt8 C2 with even width; encoding 4:2:2 is not provided because OpenCV
4.1 lacks it.

## Bayer demosaicing

[Demosaic_Bayer](api:Demosaic_Bayer) converts a single-channel UInt8 or
UInt16 raw image, at least 3 x 3, to BGR or RGB. [Bayer_Pattern](api:Bayer_Pattern)
names the 2 x 2 color-filter arrangement at logical Source (0, 0); cropping
does not adjust it. `Variable_Number_Of_Gradients` requires UInt8 and falls
back to bilinear demosaicing when either dimension is below 8.
[Demosaic_Bayer_To_Gray](api:Demosaic_Bayer_To_Gray) and
[Demosaic_Bayer_With_Alpha](api:Demosaic_Bayer_With_Alpha) give gray and
four-channel results.

## Color maps

[Apply_Color_Map](api:Apply_Color_Map) maps UInt8 C1 or C3 Sources to a
UInt8 C3 BGR image; a C3 Source is first converted to gray, not mapped
channel by channel. [Built_In_Color_Map](api:Built_In_Color_Map) lists the
20 maps present in OpenCV 4.1, 4.10 and 5.0. The
[second overload](api:Apply_Color_Map/2) takes a custom 256-row, one-column
UInt8 C3 lookup table.

## Example

The example converts blue to gray, writes red through a Region and observes
the parent change, applies a color map and decodes a gray I420 frame. It is
`docs/examples/color_and_representation.adb`, compiled and executed by the
documentation workflow.

```ada
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Color_And_Representation is
   use OpenCV.Core;
   use OpenCV.Image_Processing;
   use type OpenCV.UInt8_Value;

   --  "UInt8 C3": depth UInt8 with three channels, stored in BGR order.
   Picture : Mat := Create (4, 6, (Depth => UInt8, Channels => 3));
   Gray    : Mat;
   Colored : Mat;
   Packed  : Mat := Create (6, 4, (Depth => UInt8, Channels => 1));
   Decoded : Mat;
begin
   --  Pure blue in BGR order; the luminance of blue is about 29.
   Picture.Set_To (OpenCV.Make_Scalar (255.0, 0.0, 0.0));
   Convert_Color (Picture, Gray, BGR_To_Gray);
   pragma Assert (Gray.Channels = 1 and then Gray.Depth = UInt8);
   pragma Assert (Gray.Rows = 4 and then Gray.Columns = 6);
   pragma Assert (UInt8_Access.Get (Gray, 0, 0) = 29);

   --  A Region is a view: drawing into it writes the parent's storage.
   declare
      Corner : Mat :=
        Picture.Region ((X => 0, Y => 0, Width => 2, Height => 2));
   begin
      Corner.Set_To (OpenCV.Make_Scalar (0.0, 0.0, 255.0));
   end;
   Convert_Color (Picture, Gray, BGR_To_Gray);
   pragma Assert (UInt8_Access.Get (Gray, 0, 0) = 76);
   pragma Assert (UInt8_Access.Get (Gray, 3, 5) = 29);

   --  A built-in color map turns gray levels into a BGR C3 image.
   Apply_Color_Map (Gray, Colored, Jet_Map);
   pragma Assert (Colored.Channels = 3 and then Colored.Rows = 4);

   --  A packed I420 frame: 4 columns, 4 luma rows plus 2 chroma rows.
   Packed.Set_To (OpenCV.Make_Scalar (128.0));
   Decoded := Decode_YUV420 (Packed, I420, BGR_Output);
   pragma Assert (Decoded.Rows = 4 and then Decoded.Columns = 4);
   pragma Assert (Decoded.Channels = 3);
end Color_And_Representation;
```

## Failure conditions and limits

A Source whose channel count or depth does not match the selected
conversion, an odd YUV dimension, a Bayer Source smaller than 3 x 3, a
wrongly shaped lookup table, or a native failure raises
`OpenCV.OpenCV_Error`. Channel orders for XYZ, YCrCb, YUV, Lab and Luv follow
OpenCV's selector names; the repository's tests pin the gray, layout,
HSV/HLS and alpha behavior. Native rounding is retained and pixel identity
across OpenCV builds and vendor paths is not promised.
