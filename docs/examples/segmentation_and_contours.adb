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
