with Interfaces.C.Strings;

package body OpenCV.Image_Processing.Internal.C_API is

   use type Interfaces.C.Strings.chars_ptr;

   function Last_Error_Message return String is
      Message : constant Interfaces.C.Strings.chars_ptr :=
        Last_Error_Message_Pointer;
   begin
      if Message = Interfaces.C.Strings.Null_Ptr then
         return "";
      end if;

      return Interfaces.C.Strings.Value (Message);
   end Last_Error_Message;

end OpenCV.Image_Processing.Internal.C_API;