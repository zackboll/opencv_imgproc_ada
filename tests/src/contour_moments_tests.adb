with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Contour_Moments_Tests is

   package C_API renames OpenCV.Image_Processing.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Float64_Value;
   use type OpenCV.Core.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Rectangle : constant OpenCV.Image_Processing.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 3), (X => 0, Y => 3));

   Translated : constant OpenCV.Image_Processing.Contour :=
     ((X => -7, Y => 5),
      (X => -3, Y => 5),
      (X => -3, Y => 8),
      (X => -7, Y => 8));

   Tolerance : constant OpenCV.Core.Float64_Value := 1.0E-9;

   function Close (Left, Right : OpenCV.Core.Float64_Value) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Close;

   procedure Assert_Close
     (Actual, Expected : OpenCV.Core.Float64_Value; Message : String) is
   begin
      AUnit.Assertions.Assert (Close (Actual, Expected), Message);
   end Assert_Close;

   procedure Assert_Zero
     (Value : OpenCV.Image_Processing.Moments_Result; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Value.M_00 = 0.0
         and then Value.M_10 = 0.0
         and then Value.M_01 = 0.0
         and then Value.M_20 = 0.0
         and then Value.M_11 = 0.0
         and then Value.M_02 = 0.0
         and then Value.M_30 = 0.0
         and then Value.M_21 = 0.0
         and then Value.M_12 = 0.0
         and then Value.M_03 = 0.0
         and then Value.Mu_20 = 0.0
         and then Value.Mu_11 = 0.0
         and then Value.Mu_02 = 0.0
         and then Value.Mu_30 = 0.0
         and then Value.Mu_21 = 0.0
         and then Value.Mu_12 = 0.0
         and then Value.Mu_03 = 0.0
         and then Value.Nu_20 = 0.0
         and then Value.Nu_11 = 0.0
         and then Value.Nu_02 = 0.0
         and then Value.Nu_30 = 0.0
         and then Value.Nu_21 = 0.0
         and then Value.Nu_12 = 0.0
         and then Value.Nu_03 = 0.0,
         Message);
   end Assert_Zero;

   procedure Assert_C_Zero (Value : C_API.C_Moments; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Value.M00 = 0.0
         and then Value.M10 = 0.0
         and then Value.M01 = 0.0
         and then Value.M20 = 0.0
         and then Value.M11 = 0.0
         and then Value.M02 = 0.0
         and then Value.M30 = 0.0
         and then Value.M21 = 0.0
         and then Value.M12 = 0.0
         and then Value.M03 = 0.0
         and then Value.Mu20 = 0.0
         and then Value.Mu11 = 0.0
         and then Value.Mu02 = 0.0
         and then Value.Mu30 = 0.0
         and then Value.Mu21 = 0.0
         and then Value.Mu12 = 0.0
         and then Value.Mu03 = 0.0
         and then Value.Nu20 = 0.0
         and then Value.Nu11 = 0.0
         and then Value.Nu02 = 0.0
         and then Value.Nu30 = 0.0
         and then Value.Nu21 = 0.0
         and then Value.Nu12 = 0.0
         and then Value.Nu03 = 0.0,
         Message);
   end Assert_C_Zero;

   procedure Rectangle_Spatial_Moments (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Moments : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Rectangle);
   begin
      Assert_Close (Moments.M_00, 12.0, "rectangle M_00 must be area 12");
      Assert_Close (Moments.M_10, 24.0, "rectangle M_10 must be 24");
      Assert_Close (Moments.M_01, 18.0, "rectangle M_01 must be 18");
      Assert_Close
        (Moments.M_10 / Moments.M_00, 2.0, "rectangle centroid X must be 2");
      Assert_Close
        (Moments.M_01 / Moments.M_00, 1.5, "rectangle centroid Y must be 1.5");
      Assert_Close (Moments.M_20, 64.0, "rectangle M_20 must be 64");
      Assert_Close (Moments.M_02, 36.0, "rectangle M_02 must be 36");
      Assert_Close (Moments.M_11, 36.0, "rectangle M_11 must be 36");
   end Rectangle_Spatial_Moments;

   procedure Rectangle_Central_Moments (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Moments : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Rectangle);
   begin
      Assert_Close (Moments.Mu_20, 16.0, "rectangle Mu_20 must be 16");
      Assert_Close (Moments.Mu_02, 9.0, "rectangle Mu_02 must be 9");
      Assert_Close (Moments.Mu_11, 0.0, "rectangle Mu_11 must be 0");
      Assert_Close (Moments.Mu_30, 0.0, "rectangle Mu_30 must be ~0");
      Assert_Close (Moments.Mu_21, 0.0, "rectangle Mu_21 must be ~0");
      Assert_Close (Moments.Mu_12, 0.0, "rectangle Mu_12 must be ~0");
      Assert_Close (Moments.Mu_03, 0.0, "rectangle Mu_03 must be ~0");
   end Rectangle_Central_Moments;

   procedure Rectangle_Normalized_Moments (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Moments : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Rectangle);
   begin
      Assert_Close (Moments.Nu_20, 1.0 / 9.0, "rectangle Nu_20 must be 1/9");
      Assert_Close (Moments.Nu_02, 1.0 / 16.0, "rectangle Nu_02 must be 1/16");
      Assert_Close (Moments.Nu_11, 0.0, "rectangle Nu_11 must be 0");
   end Rectangle_Normalized_Moments;

   procedure Matches_Contour_Area (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Moments : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Rectangle);
   begin
      Assert_Close
        (Moments.M_00,
         OpenCV.Image_Processing.Contour_Area (Rectangle),
         "M_00 must match Contour_Area for the rectangle");
   end Matches_Contour_Area;

   procedure Translation_Invariance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Rectangle);
      Shifted  : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Translated);
   begin
      Assert_Close
        (Shifted.M_00, Original.M_00, "translated M_00 must be unchanged");
      Assert_Close (Shifted.M_10, -60.0, "translated M_10 must be -60");
      Assert_Close (Shifted.M_01, 78.0, "translated M_01 must be 78");
      Assert_Close
        (Shifted.Mu_20, Original.Mu_20, "translated Mu_20 must match");
      Assert_Close
        (Shifted.Mu_02, Original.Mu_02, "translated Mu_02 must match");
      Assert_Close
        (Shifted.Mu_11, Original.Mu_11, "translated Mu_11 must match");
      Assert_Close
        (Shifted.Mu_30, Original.Mu_30, "translated Mu_30 must match");
      Assert_Close
        (Shifted.Mu_21, Original.Mu_21, "translated Mu_21 must match");
      Assert_Close
        (Shifted.Mu_12, Original.Mu_12, "translated Mu_12 must match");
      Assert_Close
        (Shifted.Mu_03, Original.Mu_03, "translated Mu_03 must match");
      Assert_Close
        (Shifted.Nu_20, Original.Nu_20, "translated Nu_20 must match");
      Assert_Close
        (Shifted.Nu_02, Original.Nu_02, "translated Nu_02 must match");
      Assert_Close
        (Shifted.Nu_11, Original.Nu_11, "translated Nu_11 must match");
   end Translation_Invariance;

   procedure Degenerate_Contours (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty         : constant OpenCV.Image_Processing.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
      One_Point     : constant OpenCV.Image_Processing.Contour :=
        (0 => OpenCV.Core.Point'(X => 1, Y => 2));
      Two_Points    : constant OpenCV.Image_Processing.Contour :=
        (0 => OpenCV.Core.Point'(X => 0, Y => 0),
         1 => OpenCV.Core.Point'(X => 3, Y => 4));
      Empty_Moments : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Empty);
      One_Moments   : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (One_Point);
      Two_Moments   : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Two_Points);
   begin
      Assert_Zero (Empty_Moments, "empty contour moments must be all zero");
      Assert_Close
        (One_Moments.M_00, 0.0, "one-point contour M_00 must be zero");
      Assert_Close
        (Two_Moments.M_00, 0.0, "two-point contour M_00 must be zero");
   end Degenerate_Contours;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Offset_Rectangle : constant OpenCV.Image_Processing.Contour (7 .. 10) :=
        (7  => (X => 0, Y => 0),
         8  => (X => 4, Y => 0),
         9  => (X => 4, Y => 3),
         10 => (X => 0, Y => 3));
      Ordinary         : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Rectangle);
      Offset           : constant OpenCV.Image_Processing.Moments_Result :=
        OpenCV.Image_Processing.Compute_Moments (Offset_Rectangle);
   begin
      Assert_Close (Offset.M_00, Ordinary.M_00, "offset M_00 must match");
      Assert_Close (Offset.M_10, Ordinary.M_10, "offset M_10 must match");
      Assert_Close (Offset.M_01, Ordinary.M_01, "offset M_01 must match");
      Assert_Close (Offset.M_20, Ordinary.M_20, "offset M_20 must match");
      Assert_Close (Offset.M_11, Ordinary.M_11, "offset M_11 must match");
      Assert_Close (Offset.M_02, Ordinary.M_02, "offset M_02 must match");
      Assert_Close (Offset.Mu_20, Ordinary.Mu_20, "offset Mu_20 must match");
      Assert_Close (Offset.Mu_02, Ordinary.Mu_02, "offset Mu_02 must match");
      Assert_Close (Offset.Nu_20, Ordinary.Nu_20, "offset Nu_20 must match");
      Assert_Close (Offset.Nu_02, Ordinary.Nu_02, "offset Nu_02 must match");
   end Nonzero_Array_Bounds;

   procedure Extracted_Contour_Moments (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
      Set    : OpenCV.Image_Processing.Contour_Set;
   begin
      OpenCV.Core.Set_To (Source, (others => 0.0));
      for Row in 1 .. 4 loop
         for Column in 2 .. 5 loop
            OpenCV.Core.UInt8_Access.Set (Source, Row, Column, 255);
         end loop;
      end loop;
      Set := OpenCV.Image_Processing.Find_Contours (Source);
      declare
         Points  : constant OpenCV.Image_Processing.Contour :=
           OpenCV.Image_Processing.Get_Contour (Set, 0);
         Moments : constant OpenCV.Image_Processing.Moments_Result :=
           OpenCV.Image_Processing.Compute_Moments (Points);
         Area    : constant OpenCV.Core.Float64_Value :=
           OpenCV.Image_Processing.Contour_Area (Points);
      begin
         AUnit.Assertions.Assert
           (Moments.M_00 > 0.0, "extracted contour M_00 must be positive");
         Assert_Close
           (Moments.M_00, Area, "extracted M_00 must match Contour_Area");
         AUnit.Assertions.Assert
           (Moments.M_10 / Moments.M_00 > 1.0
            and then Moments.M_10 / Moments.M_00 < 6.0
            and then Moments.M_01 / Moments.M_00 > 0.0
            and then Moments.M_01 / Moments.M_00 < 5.0,
            "extracted centroid must lie inside the filled rectangle");
      end;
   end Extracted_Contour_Moments;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Value  : aliased C_API.C_Moments;
      Status : C_API.Status;
   begin
      Status := C_API.Contour_Moments (null, -1, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "negative contour point count must be rejected");
      Status := C_API.Contour_Moments (null, 1, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "points")
                  /= 0,
         "null points with positive count must be rejected");
      Status := C_API.Contour_Moments (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output")
                  /= 0,
         "null moments output must be rejected");
      Status := C_API.Contour_Moments (null, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success,
         "zero-count null contour moments must succeed");
      Assert_C_Zero
        (Value, "zero-count null contour moments must return all zeros");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Contour rectangle spatial moments",
            Rectangle_Spatial_Moments'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour rectangle central moments",
            Rectangle_Central_Moments'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour rectangle normalized moments",
            Rectangle_Normalized_Moments'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour moments match Contour_Area",
            Matches_Contour_Area'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour moments translation invariance",
            Translation_Invariance'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour degenerate moments", Degenerate_Contours'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour moments preserve array order",
            Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Extracted contour moments", Extracted_Contour_Moments'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour moments C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Contour_Moments_Tests;
