with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;

package body Processing_Check is
   procedure Run is
      use OpenCV.Core;
      use OpenCV.Image_Processing;
      use type OpenCV.UInt8_Value;
      Image                           : Mat :=
        Create (6, 8, (Depth => UInt8, Channels => 3));
      Gray, Blurred, Scaled, Survivor : Mat;
   begin
      for Row in 0 .. 5 loop
         for Column in 0 .. 7 loop
            OpenCV.Core.UInt8_Vec3_Access.Set
              (Image, Row, Column, [90, 90, 90]);
         end loop;
      end loop;
      Convert_Color (Image, Gray, BGR_To_Gray);
      if Gray.Channels /= 1
        or else OpenCV.Core.UInt8_Access.Get (Gray, 2, 3) /= 90
      then
         raise Program_Error with "color conversion failed";
      end if;
      declare
         Previous : constant Mat := Gray;
         View     : constant Mat :=
           Image.Region ((X => 1, Y => 1, Width => 4, Height => 3));
      begin
         Convert_Color (View, Gray, BGR_To_Gray);
         if Gray.Rows /= 3 or else Gray.Columns /= 4 or else Previous.Rows /= 6
         then
            raise Program_Error with "Region/replacement failed";
         end if;
         OpenCV.Core.UInt8_Vec3_Access.Set (Image, 2, 3, [0, 90, 90]);
         if OpenCV.Core.UInt8_Access.Get (Gray, 1, 2) /= 90 then
            raise Program_Error with "output must own independent storage";
         end if;
         Gaussian_Blur (Gray, Blurred, (Width => 3, Height => 3), 1.0);
         Resize (Blurred, Scaled, (Width => 8, Height => 6));
         Survivor := Scaled.Region ((X => 2, Y => 1, Width => 3, Height => 2));
      end;
      Image := Create (1, 1, (Depth => UInt8, Channels => 1));
      Scaled := Image;
      if Survivor.Rows /= 2
        or else OpenCV.Core.UInt8_Access.Get (Survivor, 1, 1) /= 90
      then
         raise Program_Error with "output Region lifetime failed";
      end if;
      begin
         Convert_Color (Image, Gray, BGR_To_Gray);
         raise Program_Error with "invalid channel count accepted";
      exception
         when OpenCV.OpenCV_Error =>
            null;
      end;
      if Gray.Rows /= 3 or else OpenCV.Core.UInt8_Access.Get (Gray, 1, 2) /= 90
      then
         raise Program_Error with "failure changed destination";
      end if;
      begin
         declare
            Invalid : constant Mat :=
              Image.Region ((X => 1, Y => 0, Width => 1, Height => 1));
         begin
            raise Program_Error
              with "invalid Region accepted" & Invalid.Rows'Image;
         end;
      exception
         when OpenCV.OpenCV_Error =>
            null;
      end;
      --  Native failure translation, independently of Imgproc validation.
      begin
         declare
            Empty   : Mat;
            Table   : constant Mat :=
              Create (1, 256, (Depth => UInt8, Channels => 1));
            Invalid : constant Mat := Empty.Apply_LUT (Table);
         begin
            raise Program_Error
              with "native failure accepted" & Invalid.Rows'Image;
         end;
      exception
         when OpenCV.OpenCV_Error =>
            null;
      end;
      for Iteration in 1 .. 100 loop
         declare
            Temporary : Mat := Survivor.Clone;
         begin
            Resize (Temporary, Blurred, (Width => 4, Height => 4));
            Temporary := Image;
            if Temporary.Rows /= 1 then
               raise Program_Error with "cleanup failed" & Iteration'Image;
            end if;
         end;
      end loop;
   end Run;
end Processing_Check;
