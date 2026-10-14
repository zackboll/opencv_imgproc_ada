# Geometry, features and structural analysis

This guide covers operations that measure image structure rather than
produce a new picture: edges, corners and subpixel refinement, Hough
detection, histograms, integral images, image accumulation and the earth
mover's distance. Geometric warps are in the
[filtering and transforms guide](filtering-and-transforms.md).

## Edges and corners

[Canny_Edges](api:Canny_Edges) writes a UInt8 edge map that is nonzero on
edges and zero elsewhere, using hysteresis thresholds and a Sobel aperture.

The corner response functions
[Corner_Minimum_Eigenvalue](api:Corner_Minimum_Eigenvalue),
[Harris_Corner_Response](api:Harris_Corner_Response),
[Corner_Eigenvalues_And_Vectors](api:Corner_Eigenvalues_And_Vectors) and
[Pre_Corner_Response](api:Pre_Corner_Response) accept UInt8 or Float32 C1
images. Each copies Source into a private snapshot, so a Region is analyzed
as its own image, and returns a fresh Float32 map (six channels for the
eigenvalue and eigenvector form). `Block_Size` 1 and `Wrap` borders are
rejected. Use `OpenCV.Core.Min_Max_Loc` on a response map to locate its
strongest corner.

[Refine_Corners_Subpixel](api:Refine_Corners_Subpixel) iteratively refines
initial points inside a search window. Every point must lie inside the
image, a Float32 image must be finite everywhere, and the image must be at
least `2 * Width + 5` columns by `2 * Height + 5` rows of the window. If the
native covariance degenerates, OpenCV 4.1 can return a NaN point where 4.10
and 5.0 keep the previous estimate.
[Extract_Subpixel_Patch](api:Extract_Subpixel_Patch) samples a patch
centered at a subpixel point inside Source; samples beyond the border come
from a private replicated copy, never from a Region's parent.

## Hough detection

The Hough functions take a binary UInt8 C1 image: zero pixels are
background and every nonzero pixel is a candidate. Each takes a private
snapshot of Source and returns an Ada-owned array; result order is not part
of the contract.

- [Find_Hough_Lines](api:Find_Hough_Lines) returns quantized lines as
  `Rho` (pixels) and `Angle_Radians`: the points satisfying
  `X * cos (Angle_Radians) + Y * sin (Angle_Radians) = Rho`, so a vertical
  line at column c appears near `(c, 0)`.
  [Find_Hough_Lines_With_Votes](api:Find_Hough_Lines_With_Votes) adds the
  accumulator votes. Accepted lines have strictly more votes than
  `Vote_Threshold`.
- [Find_Hough_Line_Segments](api:Find_Hough_Line_Segments) runs the
  probabilistic transform and returns endpoints, which can differ by a pixel
  or two across OpenCV builds.
- [Find_Hough_Circles](api:Find_Hough_Circles) and its vote-bearing variant
  [Find_Hough_Circles_With_Votes](api:Find_Hough_Circles_With_Votes) detect
  circles with the gradient method;
  [Find_Hough_Circle_Centers](api:Find_Hough_Circle_Centers) returns centers
  only.
- [Find_Hough_Lines_From_Points](api:Find_Hough_Lines_From_Points) works on
  an Ada array of finite Float32 points instead of an image.

Vote magnitudes and ordering can differ between OpenCV generations and
optional acceleration backends; use votes for ranking, not as portable
constants.

## Histograms

[Calculate_Histogram](api:Calculate_Histogram) builds a dense
[Histogram](api:Histogram) over up to
[Maximum_Histogram_Dimensions](api:Maximum_Histogram_Dimensions) axes. Each
[Histogram_Dimension](api:Histogram_Dimension) names a channel, a bin count
and a half-open `Lower_Bound .. Upper_Bound` range; the
[nonuniform variants](api:Calculate_Nonuniform_Histogram) take explicit bin
edges. Masked and multi-source overloads exist.
[Histogram_Values](api:Histogram_Values) returns an independent Float32 copy
of the counts, `Bin_Count` rows by one column for one dimension.

[Compare_Histograms](api:Compare_Histograms) supports correlation,
chi-square, intersection, Hellinger distance, alternative chi-square and
Kullback-Leibler divergence. [Back_Project](api:Back_Project) maps each pixel
to its bin value, and [Accumulate_Histogram](api:Accumulate_Histogram) returns
a new histogram with more samples added. These functions publish fresh
results only after success.

[Equalize_Histogram](api:Equalize_Histogram) equalizes a UInt8 C1 image and
supports `Equalize_Histogram (Image, Image)`. [CLAHE](api:CLAHE) applies
contrast-limited adaptive equalization to UInt8 or UInt16 C1 images; its
documentation describes when a Region may sample parent pixels.

## Integral images, accumulation and distances

[Integral_Sum](api:Integral_Sum) returns a `(Rows + 1) x (Columns + 1)` Mat
with a zero first row and column, so the sum of any rectangle needs four
reads. [Integral_Sum_And_Squares](api:Integral_Sum_And_Squares) and
[Integral_Images](api:Integral_Images) add squared and tilted sums.

[Accumulate_Image](api:Accumulate_Image),
[Accumulate_Image_Square](api:Accumulate_Image_Square),
[Accumulate_Image_Product](api:Accumulate_Image_Product) and
[Update_Running_Average](api:Update_Running_Average) never modify `Base`:
each returns a fresh result computed from a private clone. Optional masks
select pixels with any nonzero byte.

[Earth_Mover_Distance](api:Earth_Mover_Distance) compares two weighted
signatures with a built-in ground metric. Its variants return the transport
flow, take an explicit cost matrix, or
([Earth_Mover_Distance_With_Lower_Bound](api:Earth_Mover_Distance_With_Lower_Bound))
stop early when a lower bound already exceeds a threshold. Both signatures
always need the same column count.

## Example

The example finds the outline, corners, straight sides, gray-level
histogram and pixel sum of a bright square. It is
`docs/examples/features_and_analysis.adb`, compiled and executed by the
documentation workflow.

```ada
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Features_And_Analysis is
   use OpenCV.Core;
   use OpenCV.Image_Processing;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.UInt8_Value;

   Image : Mat := Create (64, 64, (Depth => UInt8, Channels => 1));
   Edges : Mat;
begin
   --  A bright filled square on a dark background.
   Image.Set_To (OpenCV.Make_Scalar (0.0));
   Fill_Rectangle
     (Image,
      Bounds => (X => 16, Y => 16, Width => 32, Height => 32),
      Color  => OpenCV.Make_Scalar (255.0));

   --  Canny marks the outline: nonzero on the border, zero inside.
   Canny_Edges
     (Image, Edges, Lower_Threshold => 50.0, Upper_Threshold => 150.0);
   pragma Assert (Edges.Depth = UInt8 and then Edges.Channels = 1);
   pragma Assert (UInt8_Access.Get (Edges, 32, 32) = 0);

   --  The strongest Harris corner response lies at a corner of the square.
   declare
      Response : constant Mat := Harris_Corner_Response (Image);
      Peak     : constant Min_Max_Result := Min_Max_Loc (Response);
   begin
      pragma Assert (Response.Depth = Float32);
      pragma Assert (Peak.Maximum > 0.0);
      pragma
        Assert
          (abs (Peak.Maximum_Location.X - 16) <= 2
             or else abs (Peak.Maximum_Location.X - 47) <= 2);
   end;

   --  The standard Hough transform finds the square's straight sides.
   declare
      Lines : constant Hough_Line_Array :=
        Find_Hough_Lines
          (Edges,
           Distance_Resolution      => 1.0,
           Angle_Resolution_Radians => Hough_Degree,
           Vote_Threshold           => 20);
   begin
      pragma Assert (Lines'Length >= 4);
   end;

   --  A 2-bin histogram over 0 .. 256 counts dark and bright pixels.
   declare
      Counts : constant Histogram :=
        Calculate_Histogram
          (Image,
           [1 =>
              (Channel     => 0,
               Bin_Count   => 2,
               Lower_Bound => 0.0,
               Upper_Bound => 256.0)]);
      Values : constant Mat := Histogram_Values (Counts);
   begin
      pragma Assert (Float32_Access.Get (Values, 0, 0) = 3072.0);
      pragma Assert (Float32_Access.Get (Values, 1, 0) = 1024.0);
   end;

   --  An integral image sums any rectangle in four lookups.
   declare
      Sums  : constant Mat := Integral_Sum (Image);
      Total : constant OpenCV.Float64_Value :=
        Float64_Access.Get (Sums, 64, 64);
   begin
      pragma Assert (Sums.Rows = 65 and then Sums.Columns = 65);
      pragma Assert (Total = 255.0 * 1024.0);
   end;
end Features_And_Analysis;
```

## Failure conditions and limits

Non-binary or wrongly typed Hough sources, nonfinite or nonpositive
resolutions, invalid angle ranges, corner windows that do not fit, histogram
bounds that are not increasing and native arithmetic limits raise
`OpenCV.OpenCV_Error`. Corner responses, Hough votes and floating histogram
comparisons keep native floating-point rounding; compare them with
tolerances. Hough results are accumulator bins, quantized by the requested
resolutions.
