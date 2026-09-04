with OpenCV.Core;

package OpenCV.Image_Processing is

   type Color_Conversion is (BGR_To_Gray);

   procedure Convert_Color
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Conversion  : Color_Conversion);
   --  BGR_To_Gray converts a non-empty, two-dimensional, three-channel BGR
   --  Source whose depth is UInt8, UInt16, or Float32. Destination is replaced
   --  with a Mat having Source's rows, columns, and depth, and exactly one
   --  channel. Source remains valid and is not modified. Empty Sources and
   --  unsupported Source dimensions, channel counts, or depths raise
   --  OpenCV.OpenCV_Error before the imgproc shim is called. Failures reported
   --  by OpenCV also raise OpenCV.OpenCV_Error.

end OpenCV.Image_Processing;
