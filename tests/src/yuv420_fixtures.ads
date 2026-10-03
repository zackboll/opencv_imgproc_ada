with OpenCV.Core;
with OpenCV.Image_Processing;

package YUV420_Fixtures is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   type Samples is array (Natural range <>) of Natural;
   type RGB is record
      R, G, B : Natural;
   end record;
   type Colors is array (Natural range <>) of RGB;
   type Plane_Kind is (Y, U, V);

   function Packed
     (Width, Height : Positive;
      Layout        : IP.YUV420_Layout;
      Luma, U, V    : Samples) return C.Mat;
   function Y_Plane (Width, Height : Positive; Luma : Samples) return C.Mat;
   function UV_Plane
     (Width, Height : Positive;
      Layout        : IP.YUV420_Semiplanar_Layout;
      U, V          : Samples) return C.Mat;
   function Color_Image
     (Width, Height : Positive;
      Pixels        : Colors;
      Order         : IP.YUV_Color_Order;
      Alpha         : Integer := -1) return C.Mat;
   function Read_Plane
     (Image : C.Mat; Layout : IP.YUV420_Planar_Layout; Plane : Plane_Kind)
      return Samples;
   function Byte
     (Image : C.Mat; Row, Column : Natural; Channel : Natural := 0)
      return Natural;
   procedure Set_Byte (Image : in out C.Mat; Row, Column, Value : Natural);
   procedure Equal (Left, Right : C.Mat);
   procedure Preserved (Left, Right : C.Mat);
   function Decode_Reference (Y, U, V : Natural) return RGB;
   function Encode_Reference (Pixel : RGB; Plane : Plane_Kind) return Natural;
end YUV420_Fixtures;
