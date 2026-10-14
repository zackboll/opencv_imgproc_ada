with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Color_And_Representation is
   use OpenCV.Core;
   use OpenCV.Image_Processing;
   use type OpenCV.UInt8_Value;

   --  "UInt8 C3": depth UInt8 with three channels, stored in BGR order.
   Picture : Mat := Create (4, 6, (Depth => UInt8, Channels => 3));
   Gray    : Mat;
   Colored : Mat;
   Packed  : Mat := Create (6, 4, (Depth => UInt8, Channels => 1));
   Decoded : Mat;
begin
   --  Pure blue in BGR order; the luminance of blue is about 29.
   Picture.Set_To (OpenCV.Make_Scalar (255.0, 0.0, 0.0));
   Convert_Color (Picture, Gray, BGR_To_Gray);
   pragma Assert (Gray.Channels = 1 and then Gray.Depth = UInt8);
   pragma Assert (Gray.Rows = 4 and then Gray.Columns = 6);
   pragma Assert (UInt8_Access.Get (Gray, 0, 0) = 29);

   --  A Region is a view: drawing into it writes the parent's storage.
   declare
      Corner : Mat :=
        Picture.Region ((X => 0, Y => 0, Width => 2, Height => 2));
   begin
      Corner.Set_To (OpenCV.Make_Scalar (0.0, 0.0, 255.0));
   end;
   Convert_Color (Picture, Gray, BGR_To_Gray);
   pragma Assert (UInt8_Access.Get (Gray, 0, 0) = 76);
   pragma Assert (UInt8_Access.Get (Gray, 3, 5) = 29);

   --  A built-in color map turns gray levels into a BGR C3 image.
   Apply_Color_Map (Gray, Colored, Jet_Map);
   pragma Assert (Colored.Channels = 3 and then Colored.Rows = 4);

   --  A packed I420 frame: 4 columns, 4 luma rows plus 2 chroma rows.
   Packed.Set_To (OpenCV.Make_Scalar (128.0));
   Decoded := Decode_YUV420 (Packed, I420, BGR_Output);
   pragma Assert (Decoded.Rows = 4 and then Decoded.Columns = 4);
   pragma Assert (Decoded.Channels = 3);
end Color_And_Representation;
