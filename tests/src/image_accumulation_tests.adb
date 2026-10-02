with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Ada.Unchecked_Conversion;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Image_Accumulation_Tests is
   package IP renames OpenCV.Image_Processing;
   package Core renames OpenCV.Core;
   package C_API renames IP.Internal.C_API;
   use type Core.Depth_Type;
   use type Core.Channel_Count;
   use type OpenCV.Float64_Value;
   use type Interfaces.Unsigned_8;
   use type C_API.Status;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Image
     (Depth    : Core.Depth_Type;
      Channels : Core.Channel_Count := 1;
      Value    : Long_Float := 2.0;
      Rows     : Natural := 2;
      Columns  : Natural := 3) return Core.Mat
   is
      M : Core.Mat := Core.Create (Rows, Columns, (Depth, Channels));
   begin
      Core.Set_To (M, (others => Value));
      return M;
   end Image;

   function Pixel
     (M : Core.Mat; R, C : Natural := 0; Channel : Natural := 0)
      return OpenCV.Float64_Value
   is
      Single : constant Core.Mat := M.Extract_Channel (Channel);
   begin
      if M.Depth = Core.Float32 then
         return OpenCV.Float64_Value (Core.Float32_Access.Get (Single, R, C));
      else
         return Core.Float64_Access.Get (Single, R, C);
      end if;
   end Pixel;

   function Apply
     (Mode       : Natural;
      S, T, B, M : Core.Mat;
      Masked     : Boolean;
      Weight     : OpenCV.Float64_Value) return Core.Mat
   is
      pragma Suppress (Validity_Check);
   begin
      case Mode is
         when 0      =>
            if Masked then
               return IP.Accumulate_Image (S, B, M);
            end if;
            return IP.Accumulate_Image (S, B);

         when 1      =>
            if Masked then
               return IP.Accumulate_Image_Square (S, B, M);
            end if;
            return IP.Accumulate_Image_Square (S, B);

         when 2      =>
            if Masked then
               return IP.Accumulate_Image_Product (S, T, B, M);
            end if;
            return IP.Accumulate_Image_Product (S, T, B);

         when others =>
            if Masked then
               return IP.Update_Running_Average (S, B, M, Weight);
            end if;
            return IP.Update_Running_Average (S, B, Weight);
      end case;
   end Apply;

   generic
      Mode : Natural;
      Source_Depth, Base_Depth : Core.Depth_Type;
      Channels : Core.Channel_Count := 1;
      Masked : Boolean := False;
      Weight : OpenCV.Float64_Value := 0.25;
   procedure Success (Test : in out Fixture);
   procedure Success (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S                  : constant Core.Mat := Image (Source_Depth, Channels);
      T                  : constant Core.Mat :=
        Image (Source_Depth, Channels, 3.0);
      B                  : constant Core.Mat :=
        Image (Base_Depth, Channels, 10.0);
      M                  : Core.Mat := Image (Core.UInt8, Value => 0.0);
      D, Again           : Core.Mat;
      Expected, Repeated : OpenCV.Float64_Value;
   begin
      Core.UInt8_Access.Set (M, 0, 1, 7);
      D := Apply (Mode, S, T, B, M, Masked, Weight);
      Again := Apply (Mode, S, T, D, M, Masked, Weight);
      case Mode is
         when 0      =>
            Expected := 12.0;
            Repeated := 14.0;

         when 1      =>
            Expected := 14.0;
            Repeated := 18.0;

         when 2      =>
            Expected := 16.0;
            Repeated := 22.0;

         when others =>
            Expected := 10.0 * (1.0 - Weight) + 2.0 * Weight;
            Repeated := Expected * (1.0 - Weight) + 2.0 * Weight;
      end case;
      AUnit.Assertions.Assert
        (D.Depth = Base_Depth
         and then D.Channels = Channels
         and then D.Rows = 2
         and then D.Columns = 3,
         "result preserves accumulator type and geometry");
      for Ch in 0 .. Natural (Channels) - 1 loop
         AUnit.Assertions.Assert
           (Pixel (D, 0, 1, Ch) = Expected
            and then Pixel (Again, 0, 1, Ch) = Repeated
            and then Pixel (D, 0, 0, Ch) = (if Masked then 10.0 else Expected),
            "known result, repeated update and nonzero per-pixel mask");
      end loop;
      Core.Set_To (D, (others => 99.0));
      AUnit.Assertions.Assert
        (Pixel (B) = 10.0 and then Core.UInt8_Access.Get (M, 0, 1) = 7,
         "base and mask remain unchanged; output has independent storage");
   end Success;

   procedure U8_F32 is new Success (0, Core.UInt8, Core.Float32);
   procedure U8_F64 is new Success (0, Core.UInt8, Core.Float64);
   procedure U16_F32 is new Success (0, Core.UInt16, Core.Float32);
   procedure U16_F64 is new Success (0, Core.UInt16, Core.Float64);
   procedure F32_F32 is new Success (0, Core.Float32, Core.Float32);
   procedure F32_F64 is new Success (0, Core.Float32, Core.Float64);
   procedure F64_F64 is new Success (0, Core.Float64, Core.Float64);
   procedure Plain_C4 is new Success (0, Core.UInt8, Core.Float64, 4, True);
   procedure Square_U8 is new Success (1, Core.UInt8, Core.Float32);
   procedure Square_F32 is new Success (1, Core.Float32, Core.Float64);
   procedure Square_C3 is new Success (1, Core.Float32, Core.Float32, 3, True);
   procedure Product_U8 is new Success (2, Core.UInt8, Core.Float64);
   procedure Product_C3 is new
     Success (2, Core.Float32, Core.Float32, 3, True);
   procedure Average_Zero is new
     Success (3, Core.UInt8, Core.Float32, Weight => 0.0);
   procedure Average_One is new
     Success (3, Core.Float32, Core.Float64, Weight => 1.0);
   procedure Average_Quarter is new Success (3, Core.UInt8, Core.Float64);
   procedure Average_C3 is new
     Success (3, Core.Float32, Core.Float32, 3, True);

   generic
      Mode : Natural;
      Source_Depth : Core.Depth_Type := Core.UInt8;
      Base_Depth : Core.Depth_Type := Core.Float32;
      Channels : Core.Channel_Count := 1;
      Fault : Natural := 0;
      Weight : OpenCV.Float64_Value := 0.25;
   procedure Reject (Test : in out Fixture);
   procedure Reject (Test : in out Fixture) is
      --  Deliberately pass IEEE NaN/Inf to the public finite-weight validator.
      pragma Suppress (Validity_Check);
      pragma Unreferenced (Test);
      S        : Core.Mat := Image (Source_Depth, Channels);
      B        : Core.Mat := Image (Base_Depth, Channels, 10.0);
      T        : Core.Mat := S;
      M        : Core.Mat := Image (Core.UInt8);
      Rejected : Boolean := False;
      Empty    : Core.Mat;
   begin
      case Fault is
         when 1      =>
            T := Image (Core.Float32, Channels);

         when 2      =>
            T := Image (Source_Depth, Channels, Rows => 1);

         when 3      =>
            M := Image (Core.UInt8, 3);

         when 4      =>
            M := Image (Core.Float32);

         when 5      =>
            M := Image (Core.UInt8, Rows => 1);

         when 6      =>
            M := Empty;

         when 7      =>
            S := Empty;

         when 8      =>
            B := Image (Base_Depth, Channels, Rows => 1);

         when 9      =>
            S :=
              Core.Create
                (Shape => (2, 2, 2), Element_Type => (Source_Depth, Channels));

         when 10     =>
            T := Image (Source_Depth, 3);

         when 11     =>
            B := Image (Base_Depth, 3);

         when others =>
            null;
      end case;
      begin
         declare
            D : constant Core.Mat :=
              Apply (Mode, S, T, B, M, Fault in 3 .. 6, Weight);
         begin
            AUnit.Assertions.Assert (D.Is_Empty, "expected rejection");
         end;
      exception
         when OpenCV.OpenCV_Error =>
            Rejected := True;
      end;
      AUnit.Assertions.Assert (Rejected, "specific public OpenCV_Error");
      if Fault /= 8 and then Fault /= 11 then
         if Base_Depth in Core.Float32 | Core.Float64 then
            AUnit.Assertions.Assert
              (Pixel (B) = 10.0, "rejected base unchanged");
         end if;
      end if;
      declare
         Good : constant Core.Mat :=
           IP.Accumulate_Image (Image (Core.UInt8), Image (Core.Float32));
      begin
         AUnit.Assertions.Assert
           (Pixel (Good) = 4.0, "recovery after rejection");
      end;
   end Reject;

   function Float_From_Bits is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, OpenCV.Float64_Value);
   procedure Narrowing is new Reject (0, Core.Float64);
   procedure Bad_Base is new Reject (0, Base_Depth => Core.UInt8);
   procedure Square_U16 is new Reject (1, Core.UInt16);
   procedure Square_F64 is new Reject (1, Core.Float64, Core.Float64);
   procedure Square_C2 is new Reject (1, Channels => 2);
   procedure Product_Type is new Reject (2, Fault => 1);
   procedure Product_Size is new Reject (2, Fault => 2);
   procedure Product_Channels is new Reject (2, Fault => 10);
   procedure Product_U16 is new Reject (2, Core.UInt16);
   procedure Average_F64 is new Reject (3, Core.Float64, Core.Float64);
   procedure Average_C4 is new Reject (3, Channels => 4);
   procedure Mask_Channels is new Reject (0, Fault => 3);
   procedure Mask_Depth is new Reject (1, Fault => 4);
   procedure Mask_Size is new Reject (2, Fault => 5);
   procedure Mask_Empty is new Reject (3, Fault => 6);
   procedure Empty_Source is new Reject (0, Fault => 7);
   procedure Base_Size is new Reject (0, Fault => 8);
   procedure Source_3D is new Reject (0, Fault => 9);
   procedure Base_Channels is new Reject (0, Fault => 11);
   procedure Weight_Low is new Reject (3, Weight => -0.1);
   procedure Weight_High is new Reject (3, Weight => 1.1);
   procedure Weight_NaN is new
     Reject (3, Weight => Float_From_Bits (16#7FF8_0000_0000_0000#));
   procedure Weight_Infinity is new
     Reject (3, Weight => Float_From_Bits (16#7FF0_0000_0000_0000#));

   procedure Aliases_And_Regions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : constant Core.Mat :=
        Image (Core.Float32, Value => 100.0, Rows => 4, Columns => 5);
      S           : Core.Mat := Parent.Region ((1, 1, 3, 2));
      B           : constant Core.Mat := S;
      Mask_Parent : constant Core.Mat :=
        Image (Core.UInt8, Value => 0.0, Rows => 4, Columns => 5);
      M           : Core.Mat := Mask_Parent.Region ((1, 1, 3, 2));
      D           : Core.Mat;
   begin
      Core.Set_To (S, (others => 2.0));
      Core.UInt8_Access.Set (M, 0, 1, 255);
      for Mode in 0 .. 3 loop
         D := Apply (Mode, S, S, B, M, True, 0.25);
         AUnit.Assertions.Assert
           (Pixel (D) = 2.0
            and then Pixel (D, 0, 1)
                     = (case Mode is
                          when 0      => 4.0,
                          when 1 | 2  => 6.0,
                          when others => 2.0),
            "aliased sources/base Regions and product self-source");
         Core.Set_To (D, (others => 50.0));
         AUnit.Assertions.Assert
           (Pixel (Parent) = 100.0 and then Pixel (S) = 2.0,
            "fresh result isolates Region parent");
      end loop;
      D := IP.Accumulate_Image (S, S);
      AUnit.Assertions.Assert (Pixel (D) = 4.0, "same Mat source/base");
      declare
         U         : constant Core.Mat := Image (Core.UInt8);
         A         : constant Core.Mat := Image (Core.Float64, Value => 0.0);
         V         : constant Core.Mat := IP.Accumulate_Image (U, A, U);
         Z         : constant Core.Mat := Image (Core.UInt8, Value => 0.0);
         Unchanged : constant Core.Mat := IP.Accumulate_Image (U, A, Z);
      begin
         AUnit.Assertions.Assert
           (Pixel (V) = 2.0
            and then Pixel (Unchanged) = 0.0
            and then Core.UInt8_Access.Get (U, 0, 0) = 2,
            "source/mask shared storage and all-zero mask");
      end;
   end Aliases_And_Regions;

   procedure Shifted_Overlap (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent  : Core.Mat :=
        Image (Core.Float64, Value => 0.0, Rows => 2, Columns => 5);
      S, B, D : Core.Mat;
   begin
      for R in 0 .. 1 loop
         for C in 0 .. 4 loop
            Core.Float64_Access.Set
              (Parent, R, C, OpenCV.Float64_Value (C + 1));
         end loop;
      end loop;
      S := Parent.Region ((0, 0, 3, 2));
      B := Parent.Region ((1, 0, 3, 2));
      D := IP.Accumulate_Image (S, B);
      for C in 0 .. 2 loop
         AUnit.Assertions.Assert
           (Pixel (D, 0, C) = OpenCV.Float64_Value (2 * C + 3)
            and then Pixel (Parent, 0, C) = OpenCV.Float64_Value (C + 1),
            "shifted shared storage reads original logical pixels");
      end loop;
      Core.Set_To (D, (others => 0.0));
      AUnit.Assertions.Assert (Pixel (B) = 2.0, "overlap parent isolated");
   end Shifted_Overlap;

   procedure Floating_Overflow (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use type Core.Float64_Access.Float64_Classification;
      S : Core.Mat := Image (Core.Float64, Value => 0.0);
      D : Core.Mat;
   begin
      Core.Float64_Access.Set (S, 0, 0, OpenCV.Float64_Value'Last);
      D := IP.Accumulate_Image (S, S);
      AUnit.Assertions.Assert
        (Core.Float64_Access.Classify (D, 0, 0)
         = Core.Float64_Access.Positive_Infinity
         and then Pixel (S) = OpenCV.Float64_Value'Last,
         "native floating overflow is not saturated or rejected");
   end Floating_Overflow;

   function Address_Of is new
     Ada.Unchecked_Conversion
       (Core.Module_Interop.Input_Mat_Handle,
        System.Address);
   function Address_Of is new
     Ada.Unchecked_Conversion
       (Core.Module_Interop.Output_Mat_Handle,
        System.Address);
   function Raw
     (S, T, B, M : System.Address;
      Mode       : Interfaces.Integer_32;
      Weight     : Interfaces.C.double;
      D          : System.Address) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_accumulate_image";

   procedure Raw_Atomic (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S   : constant Core.Mat := Image (Core.UInt8);
      T   : constant Core.Mat := Image (Core.Float32);
      B   : constant Core.Mat := Image (Core.Float64, Value => 10.0);
      Bad : constant Core.Mat := Image (Core.UInt8, 3, Rows => 1);
      D   : Core.Mat := Image (Core.Float64, Value => 77.0);
      procedure First (Hs : Core.Module_Interop.Input_Mat_Handle) is
         procedure Second (Ht : Core.Module_Interop.Input_Mat_Handle) is
            procedure Base (Hb : Core.Module_Interop.Input_Mat_Handle) is
               procedure Mask (Hm : Core.Module_Interop.Input_Mat_Handle) is
                  procedure Output (Hd : Core.Module_Interop.Output_Mat_Handle)
                  is
                     S1 : constant System.Address := Address_Of (Hs);
                     S2 : constant System.Address := Address_Of (Ht);
                     A  : constant System.Address := Address_Of (Hb);
                     M  : constant System.Address := Address_Of (Hm);
                     O  : constant System.Address := Address_Of (Hd);
                     N  : constant System.Address := System.Null_Address;
                  begin
                     AUnit.Assertions.Assert
                       (Raw (S1, N, A, N, 99, 0.0, O)
                        = C_API.Error_Invalid_Argument
                        and then Raw (S1, N, A, N, 2, 0.0, O)
                                 = C_API.Error_Invalid_Argument
                        and then Raw (N, N, A, N, 0, 0.0, O)
                                 = C_API.Error_Invalid_Argument
                        and then Raw (S1, N, A, N, 0, 0.0, N)
                                 = C_API.Error_Invalid_Argument,
                        "raw selectors and missing handles");
                     AUnit.Assertions.Assert
                       (Raw (S1, N, A, M, 0, 0.0, O) = C_API.Error_OpenCV
                        and then Raw (S1, S2, A, N, 2, 0.0, O)
                                 = C_API.Error_OpenCV
                        and then Raw (S1, M, A, N, 2, 0.0, O)
                                 = C_API.Error_OpenCV
                        and then Raw (S1, N, A, S2, 0, 0.0, O)
                                 = C_API.Error_OpenCV
                        and then Raw (S1, N, S1, N, 0, 0.0, O)
                                 = C_API.Error_OpenCV,
                        "raw semantics rejected by native assertions");
                     AUnit.Assertions.Assert
                       (Pixel (D) = 77.0, "raw rejected output unchanged");
                     AUnit.Assertions.Assert
                       (Raw (S1, N, A, N, 0, 0.0, O) = C_API.Success,
                        "raw valid recovery");
                  end Output;
               begin
                  Core.Module_Interop.With_Output_Handle (D, Output'Access);
               end Mask;
            begin
               Core.Module_Interop.With_Input_Handle (Bad, Mask'Access);
            end Base;
         begin
            Core.Module_Interop.With_Input_Handle (B, Base'Access);
         end Second;
      begin
         Core.Module_Interop.With_Input_Handle (T, Second'Access);
      end First;
   begin
      Core.Module_Interop.With_Input_Handle (S, First'Access);
      AUnit.Assertions.Assert
        (Pixel (D) = 12.0 and then Pixel (B) = 10.0,
         "raw publishes independent successful result");
   end Raw_Atomic;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Run : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create ("Image accumulation " & Name, Run));
      end Add;
   begin
      Add ("UInt8 Float32", U8_F32'Access);
      Add ("UInt8 Float64", U8_F64'Access);
      Add ("UInt16 Float32", U16_F32'Access);
      Add ("UInt16 Float64", U16_F64'Access);
      Add ("Float32 Float32", F32_F32'Access);
      Add ("Float32 Float64", F32_F64'Access);
      Add ("Float64 Float64", F64_F64'Access);
      Add ("plain masked C4", Plain_C4'Access);
      Add ("square UInt8", Square_U8'Access);
      Add ("square Float64 base", Square_F32'Access);
      Add ("square masked C3", Square_C3'Access);
      Add ("product UInt8", Product_U8'Access);
      Add ("product masked C3", Product_C3'Access);
      Add ("weight zero", Average_Zero'Access);
      Add ("weight one", Average_One'Access);
      Add ("weight quarter repeated", Average_Quarter'Access);
      Add ("weighted masked C3", Average_C3'Access);
      Add ("reject Float64 narrowing", Narrowing'Access);
      Add ("reject integer base", Bad_Base'Access);
      Add ("reject square UInt16", Square_U16'Access);
      Add ("reject square Float64", Square_F64'Access);
      Add ("reject square C2", Square_C2'Access);
      Add ("reject product type", Product_Type'Access);
      Add ("reject product size", Product_Size'Access);
      Add ("reject product channels", Product_Channels'Access);
      Add ("reject product UInt16", Product_U16'Access);
      Add ("reject weighted Float64", Average_F64'Access);
      Add ("reject weighted C4", Average_C4'Access);
      Add ("reject mask channels", Mask_Channels'Access);
      Add ("reject mask depth", Mask_Depth'Access);
      Add ("reject mask size", Mask_Size'Access);
      Add ("reject empty mask", Mask_Empty'Access);
      Add ("reject empty source", Empty_Source'Access);
      Add ("reject base size", Base_Size'Access);
      Add ("reject 3-D source", Source_3D'Access);
      Add ("reject base channels", Base_Channels'Access);
      Add ("reject negative weight", Weight_Low'Access);
      Add ("reject weight above one", Weight_High'Access);
      Add ("reject NaN weight", Weight_NaN'Access);
      Add ("reject infinite weight", Weight_Infinity'Access);
      Add ("aliases Regions and zero mask", Aliases_And_Regions'Access);
      Add ("shifted overlapping Regions", Shifted_Overlap'Access);
      Add ("native floating overflow", Floating_Overflow'Access);
      Add ("raw ABI atomicity and recovery", Raw_Atomic'Access);
      return Result'Access;
   end Suite;
end Image_Accumulation_Tests;
