with Ada.Text_IO;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;

procedure Release_Consumer is
   use OpenCV.Core;
   use OpenCV.Image_Processing;
   use type OpenCV.UInt8_Value;
   use type OpenCV.Float32_Value;

   Color                                                  : Mat :=
     Create (6, 8, (Depth => UInt8, Channels => 3));
   Gray, Blurred, Scaled, Scores, Masked_Scores, Survivor : Mat;
begin
   Color.Set_To ((90.0, 90.0, 90.0, 0.0));
   Convert_Color (Color, Gray, BGR_To_Gray);
   pragma Assert (OpenCV.Core.UInt8_Access.Get (Gray, 2, 3) = 90);
   Gaussian_Blur (Gray, Blurred, (Width => 3, Height => 3), 1.0);
   Resize (Blurred, Scaled, (Width => 10, Height => 8));
   pragma Assert (Scaled.Rows = 8 and then Scaled.Columns = 10);
   declare
      Template : Mat := Create (2, 3, (Depth => UInt8, Channels => 1));
      Mask     : Mat := Create (2, 3, (Depth => UInt8, Channels => 1));
   begin
      Template.Set_To ((90.0, 0.0, 0.0, 0.0));
      Mask.Set_To ((255.0, 0.0, 0.0, 0.0));
      Match_Template (Gray, Template, Scores, Squared_Difference);
      Match_Template (Gray, Template, Mask, Masked_Scores);
      pragma Assert (Scores.Rows = 5 and then Scores.Columns = 6);
      pragma
        Assert (Masked_Scores.Rows = 5 and then Masked_Scores.Columns = 6);
      pragma
        Assert
          (abs OpenCV.Core.Float32_Access.Get (Masked_Scores, 1, 2) < 0.01);
      Survivor := Masked_Scores;
   end;
   declare
      Previous : constant Mat := Gray;
   begin
      Color.Set_To ((0.0, 0.0, 0.0, 0.0));
      pragma Assert (OpenCV.Core.UInt8_Access.Get (Gray, 2, 3) = 90);
      Convert_Color (Color, Gray, BGR_To_Gray);
      pragma Assert (OpenCV.Core.UInt8_Access.Get (Previous, 2, 3) = 90);
      pragma Assert (OpenCV.Core.UInt8_Access.Get (Gray, 2, 3) = 0);
   end;
   begin
      Convert_Color (Gray, Blurred, BGR_To_Gray);
      raise Program_Error with "invalid channel count accepted";
   exception
      when OpenCV.OpenCV_Error =>
         null;
   end;
   pragma Assert (OpenCV.Core.UInt8_Access.Get (Blurred, 2, 3) = 90);
   --  Native OpenCV failure must also cross the shim as an Ada exception.
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
   Masked_Scores := Gray;
   pragma Assert (Survivor.Depth = Float32 and then Survivor.Rows = 5);
   pragma Assert (abs OpenCV.Core.Float32_Access.Get (Survivor, 1, 2) < 0.01);
   Ada.Text_IO.Put_Line ("Pin-free indexed Imgproc release consumer PASS");
end Release_Consumer;
