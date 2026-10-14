with Ada.Text_IO;
with Interfaces.C;
with Processing_Check;

procedure Installed_Mixed is
   use type Interfaces.C.int;
   function Native_Check return Interfaces.C.int
   with Import, Convention => C, External_Name => "application_native_check";
begin
   Processing_Check.Run;
   if Native_Check /= 0 then
      raise Program_Error with "native application processing failed";
   end if;
   Ada.Text_IO.Put_Line ("installed mixed Imgproc consumer PASS");
end Installed_Mixed;
