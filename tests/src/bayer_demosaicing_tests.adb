with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Bayer_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with System;

package body Bayer_Demosaicing_Tests is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   package F renames Bayer_Fixtures;
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type C.Dimension_Array;
   use type Interfaces.Integer_32;
   use type IP.Bayer_Color_Order;
   use type IP.Bayer_Demosaicing_Method;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bad_Mat
     (Depth : C.Depth_Type; Channels : C.Channel_Count := 1) return C.Mat
   is
      S : C.Mat := C.Create (16, 16, (Depth, Channels));
   begin
      S.Set_Identity;
      return S;
   end Bad_Mat;

   function ND_Mat return C.Mat is
      S : C.Mat := C.Create (C.Dimension_Array'(3, 3, 3), (C.UInt8, 1));
   begin
      S.Set_To ((others => 37.0));
      return S;
   end ND_Mat;

   procedure Preserved (S, Before : C.Mat) is
   begin
      AUnit.Assertions.Assert
        (S.Shape = Before.Shape
         and then S.Depth = Before.Depth
         and then S.Channels = Before.Channels,
         "source metadata preserved");
      if not S.Is_Empty then
         declare
            A      : constant C.Mat := S.Convert_To (C.Float64);
            B      : constant C.Mat := Before.Convert_To (C.Float64);
            Flat_A : constant C.Mat :=
              A.Reshape
                (C.Dimension_Array'(1, OpenCV.Size_Coordinate (A.Total)));
            Flat_B : constant C.Mat :=
              B.Reshape
                (C.Dimension_Array'(1, OpenCV.Size_Coordinate (B.Total)));
            D      : constant C.Mat := C.Abs_Diff (Flat_A, Flat_B);
         begin
            AUnit.Assertions.Assert
              (D.Norm (C.Infinity) = 0.0, "all source values preserved");
         end;
      end if;
   end Preserved;

   procedure Metadata (S, D : C.Mat; Channels : C.Channel_Count) is
   begin
      AUnit.Assertions.Assert
        (D.Rows = S.Rows
         and then D.Columns = S.Columns
         and then D.Depth = S.Depth
         and then D.Channels = Channels,
         "Bayer result size/depth/channels");
   end Metadata;

   procedure Known_Color (D : C.Mat; Order : IP.Bayer_Color_Order) is
      R : constant Natural := (if D.Depth = C.UInt8 then 200 else 50_000);
      G : constant Natural := (if D.Depth = C.UInt8 then 100 else 30_000);
      B : constant Natural := (if D.Depth = C.UInt8 then 50 else 10_000);
   begin
      for Channel in 0 .. Natural (D.Channels) - 1 loop
         declare
            Plane    : constant C.Mat := D.Extract_Channel (Channel);
            Expected : constant Natural :=
              (case Channel is
                 when 0      => (if Order = IP.BGR_Order then B else R),
                 when 1      => G,
                 when 2      => (if Order = IP.BGR_Order then R else B),
                 when others => (if D.Depth = C.UInt8 then 255 else 65_535));
         begin
            --  Center evidence avoids version-dependent VNG borders.
            for Y in 5 .. D.Rows - 6 loop
               for X in 5 .. D.Columns - 6 loop
                  AUnit.Assertions.Assert
                    (F.Pixel (Plane, Y, X) = Expected,
                     "independently known physical CFA components");
               end loop;
            end loop;
         end;
      end loop;
   end Known_Color;

   generic
      Pattern : IP.Bayer_Pattern;
      Depth : C.Depth_Type;
      Method : IP.Bayer_Demosaicing_Method := IP.Bilinear;
   procedure Color (Test : in out Fixture);
   procedure Color (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S      : constant C.Mat := F.Mosaic (Pattern, Depth);
      Before : constant C.Mat := S.Clone;
   begin
      for Order in IP.Bayer_Color_Order loop
         declare
            D : constant C.Mat :=
              IP.Demosaic_Bayer (S, Pattern, Method, Order);
         begin
            Metadata (S, D, 3);
            Known_Color (D, Order);
            F.Equal (S, Before);
         end;
      end loop;
   end Color;

   generic
      Pattern : IP.Bayer_Pattern;
      Depth : C.Depth_Type;
   procedure Gray (Test : in out Fixture);
   procedure Gray (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S        : constant C.Mat := F.Mosaic (Pattern, Depth);
      Before   : constant C.Mat := S.Clone;
      D        : constant C.Mat := IP.Demosaic_Bayer_To_Gray (S, Pattern);
      R        : constant Long_Long_Integer :=
        (if Depth = C.UInt8 then 200 else 50_000);
      G        : constant Long_Long_Integer :=
        (if Depth = C.UInt8 then 100 else 30_000);
      B        : constant Long_Long_Integer :=
        (if Depth = C.UInt8 then 50 else 10_000);
      Expected : constant Natural :=
        Natural ((R * 4899 + G * 9617 + B * 1868 + 8192) / 16_384);
   begin
      Metadata (S, D, 1);
      for Y in 2 .. D.Rows - 3 loop
         for X in 2 .. D.Columns - 3 loop
            AUnit.Assertions.Assert
              (abs (Integer (F.Pixel (D, Y, X)) - Integer (Expected))
               <= (if Depth = C.UInt8 then 1 else 0),
               "native fixed-point luminance (SIMD rounding)");
         end loop;
      end loop;
      F.Equal (S, Before);
   end Gray;

   generic
      Pattern : IP.Bayer_Pattern;
   procedure Alpha (Test : in out Fixture);
   procedure Alpha (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Depth in C.Depth_Type range C.UInt8 .. C.UInt16 loop
         if Depth in C.UInt8 | C.UInt16 then
            declare
               S      : constant C.Mat := F.Mosaic (Pattern, Depth);
               Before : constant C.Mat := S.Clone;
            begin
               for Order in IP.Bayer_Color_Order loop
                  declare
                     D : constant C.Mat :=
                       IP.Demosaic_Bayer_With_Alpha (S, Pattern, Order);
                     A : constant C.Mat := D.Extract_Channel (3);
                  begin
                     Metadata (S, D, 4);
                     Known_Color (D, Order);
                     for Y in 0 .. A.Rows - 1 loop
                        for X in 0 .. A.Columns - 1 loop
                           AUnit.Assertions.Assert
                             (F.Pixel (A, Y, X)
                              = (if Depth = C.UInt8 then 255 else 65_535),
                              "native alpha maximum including borders");
                        end loop;
                     end loop;
                     F.Equal (S, Before);
                  end;
               end loop;
            end;
         end if;
      end loop;
   end Alpha;

   procedure B0 is new Color (IP.RGGB, C.UInt8);
   procedure B1 is new Color (IP.GRBG, C.UInt8);
   procedure B2 is new Color (IP.BGGR, C.UInt8);
   procedure B3 is new Color (IP.GBRG, C.UInt8);
   procedure B4 is new Color (IP.RGGB, C.UInt16);
   procedure B5 is new Color (IP.GRBG, C.UInt16);
   procedure B6 is new Color (IP.BGGR, C.UInt16);
   procedure B7 is new Color (IP.GBRG, C.UInt16);
   procedure G0 is new Gray (IP.RGGB, C.UInt8);
   procedure G1 is new Gray (IP.GRBG, C.UInt8);
   procedure G2 is new Gray (IP.BGGR, C.UInt8);
   procedure G3 is new Gray (IP.GBRG, C.UInt8);
   procedure G4 is new Gray (IP.RGGB, C.UInt16);
   procedure G5 is new Gray (IP.GRBG, C.UInt16);
   procedure G6 is new Gray (IP.BGGR, C.UInt16);
   procedure G7 is new Gray (IP.GBRG, C.UInt16);
   procedure A0 is new Alpha (IP.RGGB);
   procedure A1 is new Alpha (IP.GRBG);
   procedure A2 is new Alpha (IP.BGGR);
   procedure A3 is new Alpha (IP.GBRG);
   procedure E0 is new Color (IP.RGGB, C.UInt8, IP.Edge_Aware);
   procedure E1 is new Color (IP.GRBG, C.UInt8, IP.Edge_Aware);
   procedure E2 is new Color (IP.BGGR, C.UInt16, IP.Edge_Aware);
   procedure E3 is new Color (IP.GBRG, C.UInt16, IP.Edge_Aware);
   procedure V0 is new
     Color (IP.RGGB, C.UInt8, IP.Variable_Number_Of_Gradients);
   procedure V1 is new
     Color (IP.GRBG, C.UInt8, IP.Variable_Number_Of_Gradients);
   procedure V2 is new
     Color (IP.BGGR, C.UInt8, IP.Variable_Number_Of_Gradients);
   procedure V3 is new
     Color (IP.GBRG, C.UInt8, IP.Variable_Number_Of_Gradients);

   procedure Small_VNG (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  4.x fallback treats all VNG codes as the BGGR bilinear phase.
      S : constant C.Mat :=
        F.Mosaic (IP.BGGR, Rows => 7, Columns => 7, Texture => True);
      A : constant C.Mat := IP.Demosaic_Bayer (S, IP.BGGR);
      B : constant C.Mat :=
        IP.Demosaic_Bayer (S, IP.BGGR, IP.Variable_Number_Of_Gradients);
   begin
      F.Equal (A, B);
   end Small_VNG;

   generic
      Method : IP.Bayer_Demosaicing_Method;
   procedure Textured (Test : in out Fixture);
   procedure Textured (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Depth in C.Depth_Type range C.UInt8 .. C.UInt16 loop
         if Depth = C.UInt8
           or else (Depth = C.UInt16 and then Method = IP.Edge_Aware)
         then
            declare
               S         : constant C.Mat :=
                 F.Mosaic
                   (IP.RGGB,
                    Depth,
                    Rows    => 32,
                    Columns => 32,
                    Texture => True);
               Before    : constant C.Mat := S.Clone;
               A         : constant C.Mat := IP.Demosaic_Bayer (S, IP.RGGB);
               B         : constant C.Mat :=
                 IP.Demosaic_Bayer (S, IP.RGGB, Method);
               R         : constant C.Mat :=
                 IP.Demosaic_Bayer (S, IP.RGGB, Method, IP.RGB_Order);
               Different : Boolean := False;
            begin
               Metadata (S, B, 3);
               for Channel in 0 .. 2 loop
                  declare
                     P : constant C.Mat := A.Extract_Channel (Channel);
                     Q : constant C.Mat := B.Extract_Channel (Channel);
                     T : constant C.Mat := R.Extract_Channel (2 - Channel);
                  begin
                     for Y in 8 .. 23 loop
                        for X in 8 .. 23 loop
                           Different :=
                             Different
                             or else F.Pixel (P, Y, X) /= F.Pixel (Q, Y, X);
                           AUnit.Assertions.Assert
                             (F.Pixel (Q, Y, X) = F.Pixel (T, Y, X),
                              "textured native BGR/RGB order");
                        end loop;
                     end loop;
                  end;
               end loop;
               AUnit.Assertions.Assert
                 (Different, "method differs from bilinear in interior");
               F.Equal (S, Before);
            end;
         end if;
      end loop;
   end Textured;
   procedure EA_Texture is new Textured (IP.Edge_Aware);
   procedure VNG_Texture is new Textured (IP.Variable_Number_Of_Gradients);

   generic
      Method : IP.Bayer_Demosaicing_Method;
   procedure Region (Test : in out Fixture);
   procedure Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent   : C.Mat :=
        F.Mosaic (IP.RGGB, Rows => 24, Columns => 26, Texture => True);
      --  RGGB cropped at odd x/y has physical BGGR at logical (0,0).
      R        : constant C.Mat := Parent.Region ((3, 3, 16, 16));
      Snapshot : constant C.Mat := R.Clone;
      Before   : constant C.Mat := Parent.Clone;
      D        : constant C.Mat := IP.Demosaic_Bayer (R, IP.BGGR, Method);
      Expected : constant C.Mat :=
        IP.Demosaic_Bayer (Snapshot, IP.BGGR, Method);
   begin
      F.Equal (D, Expected);
      F.Equal (Parent, Before);
      for Y in 0 .. Parent.Rows - 1 loop
         for X in 0 .. Parent.Columns - 1 loop
            if Y not in 3 .. 18 or else X not in 3 .. 18 then
               F.Set_Pixel (Parent, Y, X, 255);
            end if;
         end loop;
      end loop;
      F.Equal (IP.Demosaic_Bayer (R, IP.BGGR, Method), Expected);
      Parent.Set_To ((others => 0.0));
      F.Equal (D, Expected);
   end Region;
   procedure Bilinear_Region is new Region (IP.Bilinear);
   procedure EA_Region is new Region (IP.Edge_Aware);
   procedure VNG_Region is new Region (IP.Variable_Number_Of_Gradients);

   procedure Gray_Alpha_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent   : C.Mat := F.Mosaic (IP.RGGB, C.UInt16, 24, 26, True);
      R        : constant C.Mat := Parent.Region ((3, 2, 16, 16));
      Snapshot : constant C.Mat := R.Clone;
      Before   : constant C.Mat := Parent.Clone;
      --  Odd column, even row: logical origin is GRBG.
      G        : constant C.Mat := IP.Demosaic_Bayer_To_Gray (R, IP.GRBG);
      A        : constant C.Mat :=
        IP.Demosaic_Bayer_With_Alpha (R, IP.GRBG, IP.RGB_Order);
      GE       : constant C.Mat :=
        IP.Demosaic_Bayer_To_Gray (Snapshot, IP.GRBG);
      AE       : constant C.Mat :=
        IP.Demosaic_Bayer_With_Alpha (Snapshot, IP.GRBG, IP.RGB_Order);
   begin
      F.Equal (G, GE);
      F.Equal (A, AE);
      F.Equal (Parent, Before);
      Parent.Set_To ((others => 0.0));
      F.Equal (G, GE);
      F.Equal (A, AE);
   end Gray_Alpha_Region;

   procedure Independence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S        : constant C.Mat := F.Mosaic (IP.RGGB);
      Before   : constant C.Mat := S.Clone;
      A        : C.Mat := IP.Demosaic_Bayer (S, IP.RGGB);
      B        : constant C.Mat := IP.Demosaic_Bayer (S, IP.RGGB);
      Expected : constant C.Mat := B.Clone;
      G        : C.Mat := IP.Demosaic_Bayer_To_Gray (S, IP.RGGB);
      H        : constant C.Mat := IP.Demosaic_Bayer_To_Gray (S, IP.RGGB);
      GE       : constant C.Mat := H.Clone;
      Alpha    : C.Mat := IP.Demosaic_Bayer_With_Alpha (S, IP.RGGB);
      Other    : constant C.Mat := IP.Demosaic_Bayer_With_Alpha (S, IP.RGGB);
      AE       : constant C.Mat := Other.Clone;
   begin
      A.Set_To ((others => 0.0));
      G.Set_To ((others => 0.0));
      Alpha.Set_To ((others => 0.0));
      F.Equal (S, Before);
      F.Equal (B, Expected);
      F.Equal (H, GE);
      F.Equal (Other, AE);
   end Independence;

   procedure Reject (S : C.Mat; VNG_Only : Boolean := False) is
      Before : constant C.Mat := S.Clone;
      D      : C.Mat;
      procedure Check (Kind : Natural) is
      begin
         begin
            case Kind is
               when 0      =>
                  D := IP.Demosaic_Bayer (S, IP.RGGB);

               when 1      =>
                  D := IP.Demosaic_Bayer_To_Gray (S, IP.RGGB);

               when 2      =>
                  D := IP.Demosaic_Bayer_With_Alpha (S, IP.RGGB);

               when 3      =>
                  D := IP.Demosaic_Bayer (S, IP.RGGB, IP.Edge_Aware);

               when others =>
                  D :=
                    IP.Demosaic_Bayer
                      (S, IP.RGGB, IP.Variable_Number_Of_Gradients);
            end case;
            AUnit.Assertions.Assert (False, "expected OpenCV_Error");
         exception
            when OpenCV.OpenCV_Error =>
               null;
         end;
         AUnit.Assertions.Assert (D.Is_Empty, "no result after rejection");
      end Check;
   begin
      if VNG_Only then
         Check (4);
      else
         for Kind in 0 .. 4 loop
            Check (Kind);
         end loop;
      end if;
      Preserved (S, Before);
   end Reject;

   procedure Invalid_Layout (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : C.Mat;
   begin
      Reject (Empty);
      Reject (ND_Mat);
      Reject (Bad_Mat (C.UInt8, 2));
      Reject (Bad_Mat (C.UInt8, 3));
   end Invalid_Layout;
   procedure Invalid_Depths (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Depth in C.Depth_Type loop
         if Depth not in C.UInt8 | C.UInt16 then
            Reject (Bad_Mat (Depth));
         end if;
      end loop;
   end Invalid_Depths;
   procedure Invalid_Sizes (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Reject (F.Mosaic (IP.RGGB, Rows => 2));
      Reject (F.Mosaic (IP.RGGB, Columns => 2));
      declare
         S : constant C.Mat := F.Mosaic (IP.RGGB, Rows => 3, Columns => 3);
         D : constant C.Mat := IP.Demosaic_Bayer (S, IP.RGGB);
      begin
         Metadata (S, D, 3);
      end;
   end Invalid_Sizes;
   procedure Invalid_VNG (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Reject (F.Mosaic (IP.RGGB, C.UInt16), VNG_Only => True);
   end Invalid_VNG;

   function Address is new
     Ada.Unchecked_Conversion
       (C.Module_Interop.Input_Mat_Handle,
        System.Address);
   function Address is new
     Ada.Unchecked_Conversion
       (C.Module_Interop.Output_Mat_Handle,
        System.Address);
   function Raw_Color
     (S, D : System.Address; Pattern, Method, Order : Interfaces.Integer_32)
      return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_demosaic_bayer";
   function Raw_Gray
     (S, D : System.Address; Pattern : Interfaces.Integer_32)
      return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_demosaic_bayer_gray";
   function Raw_Alpha
     (S, D : System.Address; Pattern, Order : Interfaces.Integer_32)
      return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_demosaic_bayer_alpha";

   generic
      Kind : Natural;
   procedure Raw_Rejection (Test : in out Fixture);
   procedure Raw_Rejection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      D     : C.Mat := C.Create (2, 2, (C.UInt8, 1));
      S     : constant C.Mat := F.Mosaic (IP.RGGB);
      Empty : C.Mat;
      procedure Check
        (Source      : C.Mat;
         Pattern     : Interfaces.Integer_32 := 0;
         Method      : Interfaces.Integer_32 := 0;
         Order       : Interfaces.Integer_32 := 0;
         Expected    : Interfaces.Integer_32 := 4;
         Null_Input  : Boolean := False;
         Null_Output : Boolean := False)
      is
         Status : Interfaces.Integer_32 := -1;
         Before : constant C.Mat := Source.Clone;
         procedure Input (Hs : C.Module_Interop.Input_Mat_Handle) is
            procedure Output (Hd : C.Module_Interop.Output_Mat_Handle) is
               A : constant System.Address :=
                 (if Null_Input then System.Null_Address else Address (Hs));
               B : constant System.Address :=
                 (if Null_Output then System.Null_Address else Address (Hd));
            begin
               case Kind is
                  when 0      =>
                     Status := Raw_Color (A, B, Pattern, Method, Order);

                  when 1      =>
                     Status := Raw_Gray (A, B, Pattern);

                  when others =>
                     Status := Raw_Alpha (A, B, Pattern, Order);
               end case;
            end Output;
         begin
            C.Module_Interop.With_Output_Handle (D, Output'Access);
         end Input;
      begin
         C.Module_Interop.With_Input_Handle (Source, Input'Access);
         AUnit.Assertions.Assert (Status = Expected, "raw invalid status");
         if Expected /= 0 then
            AUnit.Assertions.Assert
              (D.Rows = 2 and then D.Columns = 2 and then D.Channels = 1,
               "raw sentinel metadata retained");
            for Y in 0 .. 1 loop
               for X in 0 .. 1 loop
                  AUnit.Assertions.Assert
                    (F.Pixel (D, Y, X) = 71, "raw sentinel pixels retained");
               end loop;
            end loop;
         end if;
         Preserved (Source, Before);
      end Check;
   begin
      D.Set_To ((others => 71.0));
      Check (S, Pattern => -1);
      Check (S, Pattern => 4);
      Check (S, Null_Input => True);
      Check (S, Null_Output => True);
      Check (Empty);
      Check (ND_Mat);
      Check (Bad_Mat (C.UInt8, 2));
      Check (Bad_Mat (C.Float32));
      if Kind /= 1 then
         Check (S, Order => -1);
         Check (S, Order => 2);
         Check (Bad_Mat (C.Int16));
         Check (Bad_Mat (C.UInt8, 3));
      end if;
      if Kind = 0 then
         Check (S, Method => -1);
         Check (S, Method => 3);
         Check (F.Mosaic (IP.RGGB, C.UInt16), Method => 1);
      end if;
      Check (S, Expected => 0);
      if Kind = 1 then
         F.Equal (D, IP.Demosaic_Bayer_To_Gray (S, IP.RGGB));
      else
         Known_Color (D, IP.BGR_Order);
      end if;
      --  Native-safe raw 1x1/2x2 behavior is not the Ada minimum policy.
      for Size in 1 .. 2 loop
         Check
           (F.Mosaic (IP.RGGB, Rows => Size, Columns => Size), Expected => 0);
      end loop;
   end Raw_Rejection;
   procedure Raw_C is new Raw_Rejection (0);
   procedure Raw_G is new Raw_Rejection (1);
   procedure Raw_A is new Raw_Rejection (2);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Test : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Test));
      end Add;
   begin
      Add ("Bilinear RGGB UInt8 both orders", B0'Access);
      Add ("Bilinear GRBG UInt8 both orders", B1'Access);
      Add ("Bilinear BGGR UInt8 both orders", B2'Access);
      Add ("Bilinear GBRG UInt8 both orders", B3'Access);
      Add ("Bilinear RGGB UInt16 both orders", B4'Access);
      Add ("Bilinear GRBG UInt16 both orders", B5'Access);
      Add ("Bilinear BGGR UInt16 both orders", B6'Access);
      Add ("Bilinear GBRG UInt16 both orders", B7'Access);
      Add ("Gray RGGB UInt8 luminance", G0'Access);
      Add ("Gray GRBG UInt8 luminance", G1'Access);
      Add ("Gray BGGR UInt8 luminance", G2'Access);
      Add ("Gray GBRG UInt8 luminance", G3'Access);
      Add ("Gray RGGB UInt16 luminance", G4'Access);
      Add ("Gray GRBG UInt16 luminance", G5'Access);
      Add ("Gray BGGR UInt16 luminance", G6'Access);
      Add ("Gray GBRG UInt16 luminance", G7'Access);
      Add ("Alpha RGGB both depths and orders", A0'Access);
      Add ("Alpha GRBG both depths and orders", A1'Access);
      Add ("Alpha BGGR both depths and orders", A2'Access);
      Add ("Alpha GBRG both depths and orders", A3'Access);
      Add ("EA RGGB UInt8 both orders", E0'Access);
      Add ("EA GRBG UInt8 both orders", E1'Access);
      Add ("EA BGGR UInt16 both orders", E2'Access);
      Add ("EA GBRG UInt16 both orders", E3'Access);
      Add ("VNG RGGB UInt8 both orders", V0'Access);
      Add ("VNG GRBG UInt8 both orders", V1'Access);
      Add ("VNG BGGR UInt8 both orders", V2'Access);
      Add ("VNG GBRG UInt8 both orders", V3'Access);
      Add ("VNG 7x7 native bilinear fallback", Small_VNG'Access);
      Add ("EA textured interior differs from bilinear", EA_Texture'Access);
      Add ("VNG textured interior uses gradients", VNG_Texture'Access);
      Add ("Bilinear Region isolated snapshot", Bilinear_Region'Access);
      Add ("EA Region isolated snapshot", EA_Region'Access);
      Add ("VNG Region isolated snapshot", VNG_Region'Access);
      Add ("Gray and alpha Region snapshots", Gray_Alpha_Region'Access);
      Add ("Bayer fresh result independence", Independence'Access);
      Add ("Bayer rejects empty ND and channels", Invalid_Layout'Access);
      Add ("Bayer rejects unsupported depths", Invalid_Depths'Access);
      Add ("Bayer minimum dimensions", Invalid_Sizes'Access);
      Add ("VNG rejects UInt16", Invalid_VNG'Access);
      Add ("Bayer color raw rejection recovery", Raw_C'Access);
      Add ("Bayer Gray raw rejection recovery", Raw_G'Access);
      Add ("Bayer alpha raw rejection recovery", Raw_A'Access);
      return Result'Access;
   end Suite;
end Bayer_Demosaicing_Tests;
