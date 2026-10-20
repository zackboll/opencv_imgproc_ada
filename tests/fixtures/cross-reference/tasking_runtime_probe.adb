with Ada.Text_IO;

procedure Static_Runtime_Probe is
   task Worker;

   task body Worker is
   begin
      Ada.Text_IO.Put_Line ("Static tasking runtime link control");
   end Worker;
begin
   null;
end Static_Runtime_Probe;
