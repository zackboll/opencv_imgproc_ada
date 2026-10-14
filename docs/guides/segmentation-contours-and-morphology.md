# Segmentation, contours and morphology

This guide covers turning images into regions and shapes: thresholding,
morphology, distance transforms, flood fill, watershed, GrabCut, contours,
connected components, and drawing results back into images.

## Thresholding

[Apply_Threshold](api:Apply_Threshold) applies a fixed threshold to every
channel of a UInt8, UInt16, Int16, Float32 or Float64 image using a
[Threshold_Mode](api:Threshold_Mode); `Binary` writes `Maximum_Value` above
the threshold and zero elsewhere.
[Apply_Automatic_Threshold](api:Apply_Automatic_Threshold) chooses the
threshold with Otsu (UInt8 or UInt16 C1; OpenCV 4.1 rejects UInt16) or
Triangle (UInt8 C1) and reports it.
[Apply_Adaptive_Threshold](api:Apply_Adaptive_Threshold) compares each UInt8
C1 pixel with its local mean or Gaussian-weighted mean minus a finite Bias,
over an odd block size. All three write Destination as a direct native
output: matching storage is reused, so shallow copies see the result.

## Morphology

[Erode](api:Erode), [Dilate](api:Dilate) and
[Apply_Morphology](api:Apply_Morphology) (opening, closing, gradient,
top-hat, black-hat) take either a shape and size or an explicit kernel Mat
from [Get_Structuring_Element](api:Get_Structuring_Element); overloads add an
explicit anchor. With `Constant_Border`, pixels outside the image take
`Border_Value`, which by default is OpenCV's neutral morphology value, so
borders do not erode or dilate the image.
[Explicit_Morphology_Border](api:Explicit_Morphology_Border) builds another
value. [Hit_Or_Miss](api:Hit_Or_Miss) matches an Int8 kernel of foreground
(+1), background (-1) and don't-care (0) cells against a UInt8 C1 image
whose pixels are exactly 0 or 255.

## Distances, flood fill and region growing

[Distance_Transform](api:Distance_Transform) returns the Float32 distance
from every pixel to the nearest zero pixel of a UInt8 C1 image; L1 and
chessboard distances are exact, the 3 x 3 and 5 x 5 Euclidean masks are
OpenCV's approximations and `Euclidean_Precise` is exact up to Float32
rounding. [Distance_Transform_With_Labels](api:Distance_Transform_With_Labels)
also labels the nearest zero component or pixel.

[Flood_Fill](api:Flood_Fill) and [Flood_Fill_With_Mask](api:Flood_Fill_With_Mask)
modify their image (and mask) **in place**, starting at a seed and growing
through neighbours within the given differences;
[Flood_Fill_Range_Mode](api:Flood_Fill_Range_Mode) compares with the seed or
with the already-filled neighbour.

[Watershed](api:Watershed) updates an Int32 C1 marker image in place: zero
means unknown, positive values seed regions, and on return boundaries are
-1. [Initialize_GrabCut](api:Initialize_GrabCut) and
[Refine_GrabCut](api:Refine_GrabCut) segment a UInt8 C3 image into
foreground and background labels held in a private
[GrabCut_State](api:GrabCut_State); refinement works on private clones and
commits them only after success. Exact boundary labels can differ between
OpenCV 4.1 and later releases.

## Contours and connected components

[Find_Contours](api:Find_Contours) treats zero as background and nonzero as
foreground and returns an Ada-owned [Contour_Set](api:Contour_Set);
[Contour_Retrieval_Mode](api:Contour_Retrieval_Mode) selects outer contours
only or the hierarchy to build, and
[Contour_Approximation_Mode](api:Contour_Approximation_Mode) whether every
boundary point is kept. Read it with [Contour_Count](api:Contour_Count),
[Get_Contour](api:Get_Contour) and [Get_Hierarchy](api:Get_Hierarchy), whose
links are [Optional_Contour_Index](api:Optional_Contour_Index) values.

[Connected_Components_With_Stats](api:Connected_Components_With_Stats)
writes an Int32 label image and returns per-component area, bounds and
centroid. Label zero is [Background_Label](api:Background_Label); foreground
labels run from 1 to [Component_Count](api:Component_Count) but have **no
spatial-order guarantee**, so identify components by their statistics.

## Drawing results

The drawing procedures, from [Draw_Line](api:Draw_Line) to
[Draw_Contours](api:Draw_Contours) and [Fill_Contours](api:Fill_Contours),
modify their image in place; through a Region they draw into the parent's
storage, with Region-relative coordinates. Images may be UInt8, UInt16,
Int16, Float32 or Float64 with 1 to 4 channels; coordinates outside the image
are clipped, and anti-aliasing requires UInt8. [Draw_Text](api:Draw_Text)
and [Measure_Text](api:Measure_Text) use the Hershey fonts.

## Example

The example thresholds an image with two blobs and a speck of noise, removes
the speck with an opening, then counts components and contours and flood
fills one blob. It is `docs/examples/segmentation_and_contours.adb`,
compiled and executed by the documentation workflow.

```ada
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Segmentation_And_Contours is
   use OpenCV.Core;
   use OpenCV.Image_Processing;
   use type OpenCV.Size_Coordinate;
   use type OpenCV.UInt8_Value;

   Image  : Mat := Create (60, 80, (Depth => UInt8, Channels => 1));
   Binary : Mat;
   Opened : Mat;
   Labels : Mat;
   Blobs  : Connected_Component_Set;
begin
   --  Two solid blobs, a one-pixel speck of noise, and a gray background.
   Image.Set_To (OpenCV.Make_Scalar (40.0));
   Fill_Rectangle
     (Image,
      Bounds => (X => 5, Y => 5, Width => 20, Height => 10),
      Color  => OpenCV.Make_Scalar (220.0));
   Fill_Circle
     (Image,
      Center => (X => 55, Y => 35),
      Radius => 10,
      Color  => OpenCV.Make_Scalar (220.0));
   UInt8_Access.Set (Image, 50, 10, 220);

   --  Fixed threshold: 255 above 128, 0 elsewhere.
   Apply_Threshold (Image, Binary, Threshold_Value => 128.0);
   pragma Assert (UInt8_Access.Get (Binary, 10, 10) = 255);
   pragma Assert (UInt8_Access.Get (Binary, 0, 0) = 0);

   --  A 3 x 3 opening removes the speck and keeps both blobs.
   Apply_Morphology
     (Binary, Opened, Opening, Kernel_Size => (Width => 3, Height => 3));
   pragma Assert (UInt8_Access.Get (Opened, 50, 10) = 0);
   pragma Assert (UInt8_Access.Get (Opened, 10, 10) = 255);

   --  Connected components: label 0 is the background. Foreground labels
   --  have no spatial order, so find the rectangle by its statistics.
   Connected_Components_With_Stats (Opened, Labels, Blobs);
   pragma Assert (Component_Count (Blobs) = 2);
   declare
      Rectangles : Natural := 0;
   begin
      for Label in 1 .. Component_Label (Component_Count (Blobs)) loop
         declare
            Blob : constant Component_Statistics :=
              Get_Component (Blobs, Label);
         begin
            if Blob.Area = 200 and then Blob.Bounds.Width = 20 then
               Rectangles := Rectangles + 1;
            end if;
         end;
      end loop;
      pragma Assert (Rectangles = 1);
   end;

   --  Outer contours of the same binary image.
   declare
      Outlines : constant Contour_Set := Find_Contours (Opened);
   begin
      pragma Assert (Contour_Count (Outlines) = 2);
   end;

   --  Flood fill grows from a seed through equal neighbours, in place.
   declare
      Filled : Flood_Fill_Result;
   begin
      Flood_Fill
        (Opened,
         Seed      => (X => 10, Y => 10),
         New_Value => OpenCV.Make_Scalar (100.0),
         Result    => Filled);
      pragma Assert (Filled.Pixel_Count = 200);
      pragma Assert (UInt8_Access.Get (Opened, 14, 24) = 100);
   end;
end Segmentation_And_Contours;
```

## Failure conditions and limits

Unsupported depths or channel counts, even adaptive block sizes, nonfinite
thresholds or Bias, seeds outside the image, negative watershed markers,
GrabCut regions without enough pixels inside and outside, and native
arithmetic limits raise `OpenCV.OpenCV_Error`. Out-of-range subtype values,
such as a zero `Morphology_Iterations`, raise `Constraint_Error`.
In-place mutation is part of the contract only where a declaration states it:
the flood fills, watershed markers and drawing procedures.
