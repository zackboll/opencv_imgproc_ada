with Ada.Command_Line;
with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Suites;
with Adaptive_Threshold_Tests;
with Automatic_Threshold_Tests;
with Bilateral_Filter_Tests;
with Box_Blur_Tests;
with Canny_Edge_Tests;
with CLAHE_Tests;
with Connected_Component_Tests;
with Contour_Tests;
with Corner_Analysis_Tests;
with Draw_Contour_Tests;
with Color_Conversion_Tests;
with Filter_2D_Tests;
with Histogram_Analysis_Tests;
with Histogram_Equalization_Tests;
with Hough_Detection_Tests;
with Sep_Filter_2D_Tests;
with Gaussian_Blur_Tests;
with Gaussian_Kernel_Tests;
with Derivative_Kernel_Tests;
with Drawing_Tests;
with Drawing_Annotation_Tests;
with Distance_Transform_Tests;
with Earth_Mover_Tests;
with Integral_Image_Tests;
with Image_Accumulation_Tests;
with Laplacian_Tests;
with Mean_Shift_Tests;
with Median_Blur_Tests;
with Morphology_Tests;
with Pyramid_Construction_Tests;
with Pyramid_Tests;
with Resize_Tests;
with Segmentation_Tests;
with Spatial_Derivative_Tests;
with Template_Matching_Tests;
with Threshold_Tests;
with Warp_Affine_Tests;
with Warp_Perspective_Tests;
with Remap_Tests;
with Polar_Transform_Tests;

procedure Tests is

   use type AUnit.Status;

   Suite : constant AUnit.Test_Suites.Access_Test_Suite :=
     Color_Conversion_Tests.Suite;

   function Stored_Suite return AUnit.Test_Suites.Access_Test_Suite
   is (Suite);

   function Run is new AUnit.Run.Test_Runner_With_Status (Stored_Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Suite.Add_Test (Resize_Tests.Suite);
   Suite.Add_Test (Gaussian_Blur_Tests.Suite);
   Suite.Add_Test (Gaussian_Kernel_Tests.Suite);
   Suite.Add_Test (Derivative_Kernel_Tests.Suite);
   Suite.Add_Test (Pyramid_Tests.Suite);
   Suite.Add_Test (Pyramid_Construction_Tests.Suite);
   Suite.Add_Test (Template_Matching_Tests.Suite);
   Suite.Add_Test (Warp_Affine_Tests.Suite);
   Suite.Add_Test (Warp_Perspective_Tests.Suite);
   Suite.Add_Test (Remap_Tests.Suite);
   Suite.Add_Test (Polar_Transform_Tests.Suite);

   Suite.Add_Test (Median_Blur_Tests.Suite);
   Suite.Add_Test (Box_Blur_Tests.Suite);

   Suite.Add_Test (Bilateral_Filter_Tests.Suite);
   Suite.Add_Test (Filter_2D_Tests.Suite);
   Suite.Add_Test (Sep_Filter_2D_Tests.Suite);
   Suite.Add_Test (Laplacian_Tests.Suite);
   Suite.Add_Test (Morphology_Tests.Suite);
   Suite.Add_Test (Canny_Edge_Tests.Suite);
   Suite.Add_Test (Corner_Analysis_Tests.Suite);
   Suite.Add_Test (Spatial_Derivative_Tests.Suite);
   Suite.Add_Test (Threshold_Tests.Suite);
   Suite.Add_Test (Automatic_Threshold_Tests.Suite);
   Suite.Add_Test (Adaptive_Threshold_Tests.Suite);
   Suite.Add_Test (Histogram_Equalization_Tests.Suite);
   Suite.Add_Test (CLAHE_Tests.Suite);
   Suite.Add_Test (Connected_Component_Tests.Suite);

   Suite.Add_Test (Contour_Tests.Suite);
   Suite.Add_Test (Draw_Contour_Tests.Suite);
   Suite.Add_Test (Drawing_Tests.Suite);
   Suite.Add_Test (Drawing_Annotation_Tests.Suite);
   Suite.Add_Test (Hough_Detection_Tests.Suite);
   Suite.Add_Test (Segmentation_Tests.Suite);
   Suite.Add_Test (Mean_Shift_Tests.Suite);
   Suite.Add_Test (Histogram_Analysis_Tests.Suite);
   Suite.Add_Test (Distance_Transform_Tests.Suite);
   Suite.Add_Test (Earth_Mover_Tests.Suite);
   Suite.Add_Test (Integral_Image_Tests.Suite);
   Suite.Add_Test (Image_Accumulation_Tests.Suite);
   if Run (Reporter) = AUnit.Failure then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
