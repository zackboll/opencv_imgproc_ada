# Filtering and image transformations

This guide covers smoothing, derivatives, kernels, pyramids and the geometric
transforms of `OpenCV.Image_Processing`: resizing, affine and perspective
warps, polar transforms and remapping. Every statement summarizes the
declaration's own documentation; follow the links for the complete contract.

## Calling conventions

Filters take a `Source` Mat of mode `in` and an `in out` `Destination`.
Two output models exist, and each declaration states which one it uses:

- **Direct native output.** The binding hands Destination's own `cv::Mat`
  to OpenCV. When Destination already has the required size and type,
  OpenCV writes into that storage, so shallow copies of Destination, and the
  parent of a Region passed as Destination, see the result. Otherwise
  Destination is rebound to new storage. [Gaussian_Blur](api:Gaussian_Blur),
  [Median_Blur](api:Median_Blur), [Box_Blur](api:Box_Blur),
  [Filter_2D](api:Filter_2D), [Sobel](api:Sobel), [Laplacian](api:Laplacian),
  [Canny_Edges](api:Canny_Edges), [Resize](api:Resize) and
  [Warp_Affine](api:Warp_Affine) work this way.
- **Private result, published on success.** The result is computed into
  private storage and Destination is rebound to it only after success, so a
  failure leaves Destination unchanged. [Remap](api:Remap),
  [Warp_Polar](api:Warp_Polar), the explicit-size
  [Pyramid_Up](api:Pyramid_Up/2) and
  [Pyramid_Mean_Shift_Filter](api:Pyramid_Mean_Shift_Filter) work this way.

Functions such as [Get_Gaussian_Kernel](api:Get_Gaussian_Kernel),
[Squared_Box_Filter](api:Squared_Box_Filter) and
[Blend_Linear](api:Blend_Linear) return fresh owning Mats.

A Region passed directly to OpenCV is a submatrix, and OpenCV's border
extrapolation may read parent pixels just outside it. Operations that take a
private snapshot say so and then treat the Region as its own image; see
[Squared_Box_Filter](api:Squared_Box_Filter) and
[Blend_Linear](api:Blend_Linear). Pixels outside a Destination Region are
never written.

## Smoothing

[Gaussian_Blur](api:Gaussian_Blur) accepts nonempty 2-D UInt8, UInt16,
Int16, Float32 or Float64 Mats. Kernel dimensions must be positive and odd,
Sigma positive and finite, and `Wrap` borders are rejected. The same Sigma
applies along both axes. [Box_Blur](api:Box_Blur),
[Median_Blur](api:Median_Blur) and [Bilateral_Filter](api:Bilateral_Filter)
cover box averaging, median filtering and edge-preserving smoothing; each
lists its accepted depths and kernel limits.

[Squared_Box_Filter](api:Squared_Box_Filter) returns Float64 local means
(or sums) of squared samples. Float32 inputs keep OpenCV's incremental
arithmetic, so NaN and infinity can persist beyond the ideal window; that is
documented native behavior, not a guarantee of exact per-window sums.

## Derivatives, edges and kernels

[Sobel](api:Sobel) and [Scharr](api:Scharr) compute first or higher
derivatives; choose `Destination_Depth` so that negative and large values
fit (`Float32_Depth` is the Sobel default). In-place use is supported only
with `Same_Depth`. [Laplacian](api:Laplacian) sums second derivatives and
[Spatial_Gradient](api:Spatial_Gradient) returns both first derivatives of
a UInt8 C1 image as fresh Int16 images at once. [Canny_Edges](api:Canny_Edges) produces an UInt8 edge
map that is nonzero at edges and zero elsewhere.

The kernel generators [Get_Gaussian_Kernel](api:Get_Gaussian_Kernel),
[Get_Derivative_Kernels](api:Get_Derivative_Kernels),
[Get_Scharr_Kernels](api:Get_Scharr_Kernels) and
[Get_Gabor_Kernel](api:Get_Gabor_Kernel) return coefficient Mats that can be
passed to [Filter_2D](api:Filter_2D) or [Sep_Filter_2D](api:Sep_Filter_2D).

## Pyramids

[Pyramid_Down](api:Pyramid_Down) blurs and halves each dimension, giving
`(Source.Columns + 1) / 2` columns and likewise for rows;
[Pyramid_Up](api:Pyramid_Up) doubles them. Neither works in place.
[Build_Gaussian_Pyramid](api:Build_Gaussian_Pyramid) and
[Build_Laplacian_Pyramid](api:Build_Laplacian_Pyramid) return every level as
an `OpenCV.Core.Mat_Array`, and
[Reconstruct_Laplacian_Pyramid](api:Reconstruct_Laplacian_Pyramid) inverts
the second. [Maximum_Pyramid_Level_Count](api:Maximum_Pyramid_Level_Count)
tells how many levels a Source allows.

## Geometric transforms

[Resize](api:Resize) takes the output size explicitly; `Width` counts
columns and `Height` rows. `Linear_Exact` is a fixed-point bilinear mode for
UInt8, UInt16 and Int16 only; Float32 and Float64 requests are rejected rather
than silently falling back to `Linear`.

[Warp_Affine](api:Warp_Affine) takes a 2 x 3 single-channel Float32 or
Float64 transform Mat and [Warp_Perspective](api:Warp_Perspective) a 3 x 3
one; coefficients must be finite. By default the matrix maps Source
coordinates to Destination coordinates (`Source_To_Destination`); pass
`Destination_To_Source` when the matrix is already the inverse map.
Uncovered Destination pixels take `Border_Value` with the default
`Constant_Border`. The warps reject `Area`, `Lanczos_4` and `Linear_Exact`
interpolation, and Destination must not share storage with Source or the
transform.

[Remap](api:Remap) samples Source at per-pixel coordinates given either as
two Float32 maps, one interleaved map, or the fixed-point representation
produced by [Convert_Remap_To_Fixed](api:Convert_Remap_To_Fixed).
Nearest-only fixed maps round coordinates to integers.
[Warp_Polar](api:Warp_Polar) maps between Cartesian and linear or
logarithmic polar coordinates.

## Example

The example builds an image with a vertical edge, smooths it, takes an X
derivative, halves it and translates it with an affine matrix. It is
`docs/examples/filtering_and_transforms.adb`, compiled with assertions and
warnings as errors and executed by the documentation workflow.

```ada
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Filtering_And_Transforms is
   use OpenCV.Core;
   use OpenCV.Image_Processing;
   use type OpenCV.Float32_Value;
   use type OpenCV.UInt8_Value;

   Image     : Mat := Create (40, 60, (Depth => UInt8, Channels => 1));
   Smoothed  : Mat;
   Gradient  : Mat;
   Half      : Mat;
   Transform : Mat := Create (2, 3, (Depth => Float64, Channels => 1));
   Moved     : Mat;
begin
   --  A dark image whose right half (columns 30 .. 59) is bright.
   Image.Set_To (OpenCV.Make_Scalar (0.0));
   Fill_Rectangle
     (Image,
      Bounds => (X => 30, Y => 0, Width => 30, Height => 40),
      Color  => OpenCV.Make_Scalar (200.0));

   --  Smoothing keeps the geometry and type; flat areas are unchanged.
   Gaussian_Blur
     (Image, Smoothed, Kernel_Size => (Width => 5, Height => 5), Sigma => 1.0);
   pragma Assert (Smoothed.Rows = 40 and then Smoothed.Columns = 60);
   pragma Assert (UInt8_Access.Get (Smoothed, 20, 5) = 0);
   pragma Assert (UInt8_Access.Get (Smoothed, 20, 55) = 200);

   --  A Float32 X derivative responds only at the vertical edge.
   Sobel
     (Image,
      Gradient,
      X_Order           => 1,
      Y_Order           => 0,
      Destination_Depth => Float32_Depth);
   pragma Assert (Float32_Access.Get (Gradient, 20, 30) > 0.0);
   pragma Assert (Float32_Access.Get (Gradient, 20, 10) = 0.0);

   --  Area interpolation halves the image.
   Resize
     (Image,
      Half,
      Output_Size   => (Width => 30, Height => 20),
      Interpolation => Area);
   pragma Assert (Half.Rows = 20 and then Half.Columns = 30);

   --  A 2 x 3 Float64 affine matrix translating by 5 columns and 3 rows.
   Transform.Set_To (OpenCV.Make_Scalar (0.0));
   Float64_Access.Set (Transform, 0, 0, 1.0);
   Float64_Access.Set (Transform, 0, 2, 5.0);
   Float64_Access.Set (Transform, 1, 1, 1.0);
   Float64_Access.Set (Transform, 1, 2, 3.0);
   Warp_Affine
     (Image, Transform, Moved, Output_Size => (Width => 60, Height => 40));
   --  The edge moves from column 30 to 35; uncovered rows use the zero
   --  Constant_Border.
   pragma Assert (UInt8_Access.Get (Moved, 10, 35) = 200);
   pragma Assert (UInt8_Access.Get (Moved, 10, 34) = 0);
   pragma Assert (UInt8_Access.Get (Moved, 1, 50) = 0);
end Filtering_And_Transforms;
```

## Failure conditions and limits

Contract violations raise `OpenCV.OpenCV_Error` before OpenCV runs: empty or
non-2-D sources, unsupported depths or channel counts, even or nonpositive
kernel sizes where odd ones are required, nonfinite parameters, `Wrap`
borders where unsupported and `Linear_Exact` on floating images. Values
outside an Ada subtype range, such as a zero `Morphology_Iterations`, raise
`Constraint_Error`.

Results keep OpenCV's native rounding. Bit-for-bit identity across OpenCV
4.1, 4.10 and 5.0, platforms or optional acceleration backends is not
promised unless a declaration says so; where a version difference is known,
the declaration documents it.
