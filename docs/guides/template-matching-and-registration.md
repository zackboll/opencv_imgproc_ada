# Template matching and image registration

This guide covers locating a known pattern in an image with
[Match_Template](api:Match_Template) and generalized Hough detection, and
measuring the translation between two images with
[Phase_Correlate](api:Phase_Correlate).

## The six matching methods

[Template_Matching_Method](api:Template_Matching_Method) names OpenCV's six
`TM_*` methods. Scores are Float32 values with native rounding, one per
placement of the template; the score map has `Source.Rows - Template.Rows + 1`
rows and `Source.Columns - Template.Columns + 1` columns, and each score's
location is the template's top-left corner.

| Method | OpenCV | Best match |
| --- | --- | --- |
| `Squared_Difference` | `TM_SQDIFF` | minimum |
| `Normalized_Squared_Difference` | `TM_SQDIFF_NORMED` | minimum |
| `Cross_Correlation` | `TM_CCORR` | maximum |
| `Normalized_Cross_Correlation` | `TM_CCORR_NORMED` | maximum |
| `Correlation_Coefficient` | `TM_CCOEFF` | maximum |
| `Normalized_Correlation_Coefficient` | `TM_CCOEFF_NORMED` | maximum |

Locate the best score with `OpenCV.Core.Min_Max_Loc`: use
`Minimum_Location` for the squared-difference methods and
`Maximum_Location` for the others. Near-equal scores are ties; they are not
reliable unique matches.

The [unmasked overload](api:Match_Template/1) writes Destination as a direct
native output, reusing matching storage; only a Destination that is the same
Mat as an input, or starts at the same data, is rejected.

## Masked matching

The [masked overload](api:Match_Template/2) compares only the template
pixels whose `Mask` byte is nonzero; every nonzero byte includes its pixel
with weight one. Source, Template and Mask are nonempty 2-D UInt8 C1 Mats,
and Mask has Template's dimensions. It supports exactly five methods:
`Squared_Difference` (the default), `Normalized_Squared_Difference`,
`Cross_Correlation`, `Normalized_Cross_Correlation` and
`Correlation_Coefficient`. **`Normalized_Correlation_Coefficient` is not
supported** and raises `OpenCV.OpenCV_Error`.

The masked overload snapshots its inputs, so Regions contribute only their
logical pixels, and it rebinds Destination to fresh Float32 storage only on
success. Scores stay in original UInt8 intensity units; the binding passes
unscaled Float32 copies and an exact 0/1 mask, avoiding OpenCV 4.1's scaling
of UInt8 masks.

Zero-energy policies make undefined scores deterministic:

- `Squared_Difference` with an all-zero mask yields zero scores, and
  `Cross_Correlation` supports black templates and all-zero masks with zero
  correlation.
- `Normalized_Cross_Correlation` requires at least one pixel where both mask
  and template are nonzero; a scene window whose included samples are all
  zero scores exactly +0.0.
- `Normalized_Squared_Difference` requires positive masked template energy
  and rejects an all-zero mask; a scene window whose included samples are
  all zero scores `Float32'Last`, a finite worst-match sentinel.
- `Correlation_Coefficient` is the unnormalized masked covariance; it is not
  limited to [-1, 1], can be negative, and rejects an all-zero mask.

Depending on the method and OpenCV version, the binding either calls
OpenCV's masked method or composes the same result from native operations:
masked cross-correlation always correlates a zeroed copy of the template
without a mask, and OpenCV 4.1 compositions replace masked methods it lacks.
Each method's documentation names its path. Compare scores across versions
with tolerances, not for bit identity.

## Generalized Hough detection

[Find_Ballard_Template_Matches](api:Find_Ballard_Template_Matches) finds
translated copies of a template's edge shape: votes must strictly exceed the
threshold, and centers are reported in Scene pixels.
[Find_Guil_Template_Matches](api:Find_Guil_Template_Matches) also searches
rotation and scale ranges given by [Guil_Search_Parameters](api:Guil_Search_Parameters).
The Guil planner rejects searches whose native accumulator would be too
large; with the default 72 angle bins and 30 scale bins that already
limits the Scene to 62,137 pixels, so narrow the ranges or coarsen the
steps for larger images.

## Phase correlation

[Phase_Correlate](api:Phase_Correlate) estimates the subpixel translation of
`Source_2` relative to `Source_1`: right and down are positive, so apply the
negative shift to `Source_2` to align it with `Source_1`. Both sources are
Float32 or Float64 C1 with identical size. The
[windowed overload](api:Phase_Correlate/2) multiplies both by a window such
as [Create_Hanning_Window](api:Create_Hanning_Window), which reduces edge
effects. `Response` is the normalized peak energy; it is not a probability
and is not guaranteed to lie in [0, 1]. OpenCV 4.1 computes it slightly
differently from 4.10 and 5.0.

## Example

The example finds a bright square with unmasked and masked matching, then
measures a 3-column, 2-row translation with phase correlation. It is
`docs/examples/matching_and_registration.adb`, compiled and executed by the
documentation workflow.

```ada
with OpenCV.Core;
with OpenCV.Image_Processing;

procedure Matching_And_Registration is
   use OpenCV.Core;
   use OpenCV.Image_Processing;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;

   Scene    : Mat := Create (64, 64, (Depth => UInt8, Channels => 1));
   Template : Mat;
   Mask     : Mat := Create (12, 12, (Depth => UInt8, Channels => 1));
   Scores   : Mat;
begin
   --  A scene with one bright 8 x 8 square at column 40, row 12, and a
   --  12 x 12 template cut around it with a 2-pixel dark margin.
   Scene.Set_To (OpenCV.Make_Scalar (20.0));
   Fill_Rectangle
     (Scene,
      Bounds => (X => 40, Y => 12, Width => 8, Height => 8),
      Color  => OpenCV.Make_Scalar (230.0));
   Template :=
     Scene.Region ((X => 38, Y => 10, Width => 12, Height => 12)).Clone;

   --  Squared difference: lower is better, so take the minimum location.
   Match_Template (Scene, Template, Scores, Squared_Difference);
   pragma Assert (Scores.Rows = 64 - 12 + 1 and then Scores.Columns = 53);
   declare
      Best : constant Min_Max_Result := Min_Max_Loc (Scores);
   begin
      pragma Assert (Best.Minimum_Location.X = 38);
      pragma Assert (Best.Minimum_Location.Y = 10);
   end;

   --  Normalized cross-correlation: higher is better, so take the maximum.
   Match_Template (Scene, Template, Scores, Normalized_Cross_Correlation);
   declare
      Best : constant Min_Max_Result := Min_Max_Loc (Scores);
   begin
      pragma Assert (Best.Maximum_Location.X = 38);
      pragma Assert (Best.Maximum_Location.Y = 10);
   end;

   --  The masked overload only compares template pixels whose mask byte is
   --  nonzero; here the margin is excluded and only the square counts.
   Mask.Set_To (OpenCV.Make_Scalar (0.0));
   Fill_Rectangle
     (Mask,
      Bounds => (X => 2, Y => 2, Width => 8, Height => 8),
      Color  => OpenCV.Make_Scalar (255.0));
   Match_Template (Scene, Template, Mask, Scores, Squared_Difference);
   declare
      Best : constant Min_Max_Result := Min_Max_Loc (Scores);
   begin
      pragma Assert (Best.Minimum = 0.0);
      pragma Assert (Best.Minimum_Location.X = 38);
   end;

   --  Phase correlation measures the shift of Source_2 relative to
   --  Source_1 (right and down are positive), here 3 columns and 2 rows.
   declare
      First  : Mat := Create (64, 64, (Depth => Float32, Channels => 1));
      Second : Mat := Create (64, 64, (Depth => Float32, Channels => 1));
      Window : constant Mat :=
        Create_Hanning_Window
          ((Width => 64, Height => 64), Float32_Hanning_Window);
   begin
      First.Set_To (OpenCV.Make_Scalar (0.0));
      Second.Set_To (OpenCV.Make_Scalar (0.0));
      Fill_Circle
        (First,
         Center => (X => 30, Y => 30),
         Radius => 8,
         Color  => OpenCV.Make_Scalar (1.0));
      Fill_Circle
        (Second,
         Center => (X => 33, Y => 32),
         Radius => 8,
         Color  => OpenCV.Make_Scalar (1.0));
      declare
         Shift : constant Phase_Correlation_Result :=
           Phase_Correlate (First, Second, Window);
      begin
         pragma Assert (abs (Shift.X_Shift - 3.0) < 0.5);
         pragma Assert (abs (Shift.Y_Shift - 2.0) < 0.5);
      end;
   end;
end Matching_And_Registration;
```

## Failure conditions and limits

Wrong depths or channel counts, a template larger than the source, a mask
whose size differs from the template, the unsupported masked method,
undefined normalized scores, mismatched phase-correlation sources and native
size limits raise `OpenCV.OpenCV_Error`. Template scores, phase shifts and
`Response` keep native floating-point rounding: compare with tolerances,
and treat near-ties as ambiguous.
