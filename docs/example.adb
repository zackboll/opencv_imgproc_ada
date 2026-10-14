with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Example is
   use OpenCV.Core;
   use type OpenCV.UInt8_Value;
   Image   : Mat := Create (4, 6, (Depth => UInt8, Channels => 1));
   Blurred : Mat;
begin
   Image.Set_To (OpenCV.Make_Scalar (128.0));
   OpenCV.Image_Processing.Gaussian_Blur
     (Source      => Image,
      Destination => Blurred,
      Kernel_Size => (Width => 3, Height => 3),
      Sigma       => 1.0);
   pragma Assert (Blurred.Rows = 4 and then Blurred.Columns = 6);
   pragma Assert (UInt8_Access.Get (Blurred, 0, 0) = 128);
end Example;
