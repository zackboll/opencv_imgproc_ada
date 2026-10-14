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
