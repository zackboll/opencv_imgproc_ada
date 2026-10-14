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
