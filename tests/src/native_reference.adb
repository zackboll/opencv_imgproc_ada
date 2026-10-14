with AUnit.Assertions;
with OpenCV.Core.Module_Interop;

package body Native_Reference is
   use type Interfaces.Integer_32;

   function Version return Natural is
      Value : constant Interfaces.Integer_32 := Native_Version;
   begin
      AUnit.Assertions.Assert
        (Value > 0, "native header/runtime versions agree");
      return Natural (Value);
   end Version;

   function Bayer_Matches
     (Source, Output : OpenCV.Core.Mat;
      Pattern        : OpenCV.Image_Processing.Bayer_Pattern;
      Method         : OpenCV.Image_Processing.Bayer_Demosaicing_Method;
      Order          : OpenCV.Image_Processing.Bayer_Color_Order)
      return Boolean
   is
      function Check
        (Source, Output         : OpenCV.Core.Module_Interop.Input_Mat_Handle;
         Pattern, Method, Order : Interfaces.Integer_32)
         return Interfaces.Integer_32
      with
        Import,
        Convention    => C,
        External_Name => "imgproc_test_bayer_reference";
      Result : Interfaces.Integer_32 := -1;
      procedure Input (S : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Expected (D : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
         begin
            Result :=
              Check
                (S,
                 D,
                 OpenCV.Image_Processing.Bayer_Pattern'Pos (Pattern),
                 OpenCV.Image_Processing.Bayer_Demosaicing_Method'Pos (Method),
                 OpenCV.Image_Processing.Bayer_Color_Order'Pos (Order));
         end Expected;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Output, Expected'Access);
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      AUnit.Assertions.Assert (Result >= 0, "native Bayer oracle completed");
      return Result = 1;
   end Bayer_Matches;
end Native_Reference;
