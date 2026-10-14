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
