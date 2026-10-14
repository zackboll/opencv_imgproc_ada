with Ada.Text_IO;
with Processing_Check;

procedure Installed_Ada is
begin
   Processing_Check.Run;
   Ada.Text_IO.Put_Line ("installed Ada Imgproc consumer PASS");
end Installed_Ada;
