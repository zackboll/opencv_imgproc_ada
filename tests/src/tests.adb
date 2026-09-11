with Ada.Command_Line;
with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Suites;
with Adaptive_Threshold_Tests;
with Automatic_Threshold_Tests;
with Canny_Edge_Tests;
with Color_Conversion_Tests;
with Gaussian_Blur_Tests;
with Laplacian_Tests;
with Morphology_Tests;
with Resize_Tests;
with Spatial_Derivative_Tests;
with Threshold_Tests;

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
   Suite.Add_Test (Laplacian_Tests.Suite);
   Suite.Add_Test (Morphology_Tests.Suite);
   Suite.Add_Test (Canny_Edge_Tests.Suite);
   Suite.Add_Test (Spatial_Derivative_Tests.Suite);
   Suite.Add_Test (Threshold_Tests.Suite);
   Suite.Add_Test (Automatic_Threshold_Tests.Suite);
   Suite.Add_Test (Adaptive_Threshold_Tests.Suite);
   if Run (Reporter) = AUnit.Failure then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
