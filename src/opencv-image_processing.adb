with Ada.Exceptions;
with Interfaces;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing.Internal.C_API;

package body OpenCV.Image_Processing is

   function To_C_Conversion
     (Conversion : Color_Conversion) return Interfaces.Integer_32
   is
   begin
      case Conversion is
         when BGR_To_Gray =>
            return Internal.C_API.BGR_To_Gray;
      end case;
   end To_C_Conversion;

   procedure Validate_BGR_To_Gray (Source : OpenCV.Core.Mat) is
      use type OpenCV.Core.Channel_Count;
   begin
      if Source.Is_Empty then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "BGR_To_Gray requires a non-empty source Mat");
      end if;

      if Source.Dimension_Count /= 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "BGR_To_Gray requires a two-dimensional source Mat");
      end if;

      if Source.Channels /= 3 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "BGR_To_Gray requires a source Mat with exactly 3 channels");
      end if;

      case Source.Depth is
         when OpenCV.Core.UInt8 | OpenCV.Core.UInt16 | OpenCV.Core.Float32 =>
            null;
         when others =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "BGR_To_Gray requires a UInt8, UInt16, or Float32 source Mat");
      end case;
   end Validate_BGR_To_Gray;

   procedure Validate_Conversion
     (Source : OpenCV.Core.Mat; Conversion : Color_Conversion)
   is
   begin
      case Conversion is
         when BGR_To_Gray =>
            Validate_BGR_To_Gray (Source);
      end case;
   end Validate_Conversion;

   procedure Raise_On_Error
     (Status : Internal.C_API.Status; Operation : String)
   is
      use type Internal.C_API.Status;

      Diagnostic : constant String := Internal.C_API.Last_Error_Message;
   begin
      if Status = Internal.C_API.Success then
         return;
      end if;

      if Diagnostic'Length = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Operation & " failed");
      else
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " failed: " & Diagnostic);
      end if;
   end Raise_On_Error;

   procedure Convert_Color
     (Source      : OpenCV.Core.Mat;
      Destination : in out OpenCV.Core.Mat;
      Conversion  : Color_Conversion)
   is
      use Internal.C_API;

      Status : Internal.C_API.Status := Success;

      procedure Convert_Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Convert_Output
           (Destination_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
         begin
            Status :=
              Cvt_Color
                (Source_Handle,
                 Destination_Handle,
                 To_C_Conversion (Conversion));
         end Convert_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Convert_Output'Access);
      end Convert_Input;
   begin
      Validate_Conversion (Source, Conversion);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Convert_Input'Access);
      Raise_On_Error (Status, "color conversion");
   end Convert_Color;

end OpenCV.Image_Processing;
