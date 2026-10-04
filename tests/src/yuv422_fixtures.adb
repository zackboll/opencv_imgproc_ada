with OpenCV.Core.UInt8_Vec2_Access;

package body YUV422_Fixtures is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;

   function Packed
     (Width, Height : Positive; Layout : IP.YUV422_Layout; Pixels : Pairs)
      return C.Mat
   is
      Result : C.Mat := C.Create (Height, Width, (C.UInt8, 2));
      procedure Put (Row, Column, A, B : Natural) is
      begin
         C.UInt8_Vec2_Access.Set
           (Result,
            Row,
            Column,
            (OpenCV.UInt8_Value (A), OpenCV.UInt8_Value (B)));
      end Put;
   begin
      --  Physical bytes are built directly, independently of native codes,
      --  repository selectors and all production color conversions.
      for Row in 0 .. Height - 1 loop
         for Pair in 0 .. Width / 2 - 1 loop
            declare
               P : constant Pixel_Pair :=
                 Pixels (Pixels'First + Row * (Width / 2) + Pair);
            begin
               case Layout is
                  when IP.UYVY =>
                     Put (Row, 2 * Pair, P.U, P.Y0);
                     Put (Row, 2 * Pair + 1, P.V, P.Y1);

                  when IP.YUY2 =>
                     Put (Row, 2 * Pair, P.Y0, P.U);
                     Put (Row, 2 * Pair + 1, P.Y1, P.V);

                  when IP.YVYU =>
                     Put (Row, 2 * Pair, P.Y0, P.V);
                     Put (Row, 2 * Pair + 1, P.Y1, P.U);
               end case;
            end;
         end loop;
      end loop;
      return Result;
   end Packed;
end YUV422_Fixtures;
