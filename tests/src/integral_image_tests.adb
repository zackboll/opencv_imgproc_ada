with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Ada.Unchecked_Conversion;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Int32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Integral_Image_Tests is
   package IP renames OpenCV.Image_Processing;
   package C_API renames IP.Internal.C_API;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Float64_Value;
   use type OpenCV.Float32_Value;
   use type C_API.Status;
   use type System.Address;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Address_Of is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Input_Mat_Handle,
        System.Address);
   function Address_Of is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Output_Mat_Handle,
        System.Address);
   function Raw_Sum
     (Source : System.Address;
      Depth  : Interfaces.Integer_32;
      Sum    : System.Address) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_integral_sum";
   function Raw_Pair
     (Source        : System.Address;
      Depth, Square : Interfaces.Integer_32;
      Sum, Squared  : System.Address) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_integral_sum_squares";
   function Raw_Complete
     (Source               : System.Address;
      Depth, Square        : Interfaces.Integer_32;
      Sum, Squared, Tilted : System.Address) return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_integral_complete";

   function Pixel
     (M : OpenCV.Core.Mat; R, C : Natural) return OpenCV.Float64_Value
   is (OpenCV.Core.Float64_Access.Get (M, R, C));

   function Source return OpenCV.Core.Mat is
      M : OpenCV.Core.Mat := OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
   begin
      for R in 0 .. 1 loop
         for C in 0 .. 2 loop
            OpenCV.Core.UInt8_Access.Set
              (M, R, C, Interfaces.Unsigned_8 (R * 3 + C + 1));
         end loop;
      end loop;
      return M;
   end Source;

   procedure Exact_Sum (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S        : constant OpenCV.Core.Mat := Source;
      D        : constant OpenCV.Core.Mat :=
        IP.Integral_Sum (S, IP.Int32_Integral);
      Expected : constant array (0 .. 2, 0 .. 3) of Interfaces.Integer_32 :=
        ((0, 0, 0, 0), (0, 1, 3, 6), (0, 5, 12, 21));
   begin
      AUnit.Assertions.Assert
        (D.Rows = 3
         and then D.Columns = 4
         and then D.Depth = OpenCV.Core.Int32
         and then D.Channels = 1,
         "sum metadata");
      for R in 0 .. 2 loop
         for C in 0 .. 3 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.Int32_Access.Get (D, R, C) = Expected (R, C),
               "summed area cell");
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (S, 1, 2) = 6, "source preserved");
      AUnit.Assertions.Assert
        (OpenCV.Core.Int32_Access.Get (D, 2, 3)
         - OpenCV.Core.Int32_Access.Get (D, 0, 3)
         - OpenCV.Core.Int32_Access.Get (D, 2, 1)
         + OpenCV.Core.Int32_Access.Get (D, 0, 1)
         = 16,
         "rectangle x=[1,3), y=[0,2) equals 2+3+5+6");
   end Exact_Sum;

   procedure Squares_And_Tilt (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant OpenCV.Core.Mat := Source;
      D : constant IP.Integral_Images_Result := IP.Integral_Images (S);
      P : constant IP.Integral_Sum_And_Squares_Result :=
        IP.Integral_Sum_And_Squares (S, IP.Int32_Integral);
   begin
      AUnit.Assertions.Assert
        (D.Sum.Rows = 3
         and then D.Squared_Sum.Columns = 4
         and then D.Tilted_Sum.Rows = 3
         and then D.Tilted_Sum.Columns = 4
         and then D.Tilted_Sum.Depth = D.Sum.Depth,
         "complete metadata");
      AUnit.Assertions.Assert
        (Pixel (D.Sum, 2, 3) = 21.0
         and then Pixel (D.Squared_Sum, 2, 1) = 17.0
         and then Pixel (D.Squared_Sum, 2, 2) = 46.0
         and then Pixel (D.Squared_Sum, 2, 3) = 91.0
         and then Pixel (P.Squared_Sum, 2, 3) = 91.0,
         "square fixture");
      --  tilted(X,Y) sums y<Y with |x-X+1| <= Y-y-1.
      AUnit.Assertions.Assert
        (Pixel (D.Tilted_Sum, 0, 0) = 0.0
         and then Pixel (D.Tilted_Sum, 1, 1) = 1.0
         and then Pixel (D.Tilted_Sum, 2, 2) = 1.0 + 2.0 + 3.0 + 5.0,
         "tilted documented diamond coordinates");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (S, 0, 0) = 1, "source preserved");
   end Squares_And_Tilt;

   procedure Depths_And_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S      : constant OpenCV.Core.Mat := Source;
      F      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      G      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Float32_Access.Set (F, 0, 0, 3.0);
      OpenCV.Core.Float64_Access.Set (G, 0, 0, 4.0);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get
           (IP.Integral_Sum (S, IP.Float32_Integral), 2, 3)
         = 21.0
         and then OpenCV.Core.Float32_Access.Get
                    (IP.Integral_Sum (F, IP.Float32_Integral), 1, 1)
                  = 3.0
         and then Pixel (IP.Integral_Sum (F), 1, 1) = 3.0
         and then Pixel (IP.Integral_Sum (G), 1, 1) = 4.0
         and then OpenCV.Core.Float32_Access.Get
                    (IP.Integral_Sum_And_Squares
                       (S, IP.Float32_Integral, IP.Float32_Squared_Integral)
                       .Squared_Sum,
                     2,
                     3)
                  = 91.0,
         "depth mapping");
      declare
         Pair : constant IP.Integral_Sum_And_Squares_Result :=
           IP.Integral_Sum_And_Squares (S, IP.Float32_Integral);
      begin
         AUnit.Assertions.Assert
           (Pair.Sum.Depth = OpenCV.Core.Float32
            and then Pair.Squared_Sum.Depth = OpenCV.Core.Float64
            and then OpenCV.Core.Float32_Access.Get (Pair.Sum, 2, 3) = 21.0
            and then Pixel (Pair.Squared_Sum, 2, 3) = 91.0,
            "UInt8 Float32 sum with Float64 squares");
      end;
      OpenCV.Core.Set_To (Parent, (others => 100.0));
      OpenCV.Core.UInt8_Access.Set (Parent, 1, 1, 1);
      OpenCV.Core.UInt8_Access.Set (Parent, 1, 2, 2);
      declare
         R : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 1, Y => 1, Width => 2, Height => 1));
         D : constant OpenCV.Core.Mat := IP.Integral_Sum (R);
      begin
         AUnit.Assertions.Assert
           (D.Rows = 2
            and then D.Columns = 3
            and then Pixel (D, 1, 2) = 3.0
            and then OpenCV.Core.UInt8_Access.Get (Parent, 0, 0) = 100,
            "Region excludes parent and preserves it");
      end;
   end Depths_And_Region;

   procedure Channels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      M : OpenCV.Core.Mat := OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
   begin
      OpenCV.Core.Set_To (M, (1.0, 2.0, 3.0, 0.0));
      declare
         D : constant IP.Integral_Images_Result := IP.Integral_Images (M);
      begin
         AUnit.Assertions.Assert
           (D.Sum.Channels = 3
            and then D.Squared_Sum.Channels = 3
            and then D.Tilted_Sum.Channels = 3,
            "C3 metadata");
         for C in 0 .. 2 loop
            declare
               Sum_Channel    : constant OpenCV.Core.Mat :=
                 D.Sum.Extract_Channel (C);
               Square_Channel : constant OpenCV.Core.Mat :=
                 D.Squared_Sum.Extract_Channel (C);
            begin
               AUnit.Assertions.Assert
                 (Pixel (Sum_Channel, 2, 2)
                  = OpenCV.Float64_Value (4 * (C + 1))
                  and then Pixel (Square_Channel, 2, 2)
                           = OpenCV.Float64_Value (4 * (C + 1) * (C + 1)),
                  "independent channel totals");
            end;
         end loop;
      end;
   end Channels;

   procedure Invalid_Public (Test : in out Fixture) is
      pragma Unreferenced (Test);
      F          : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float32, 1));
      G          : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Float64, 1));
      U          : constant OpenCV.Core.Mat := Source;
      E          : OpenCV.Core.Mat;
      N          : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      H          : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 1));
      Rejections : Natural := 0;
   begin
      for Choice in 1 .. 8 loop
         begin
            case Choice is
               when 1      =>
                  E := IP.Integral_Sum (F, IP.Int32_Integral);

               when 2      =>
                  E := IP.Integral_Sum (G, IP.Int32_Integral);

               when 3      =>
                  E := IP.Integral_Sum (G, IP.Float32_Integral);

               when 4      =>
                  declare
                     D : constant IP.Integral_Images_Result :=
                       IP.Integral_Images
                         (G, IP.Float64_Integral, IP.Float32_Squared_Integral);
                  begin
                     E := D.Sum;
                  end;

               when 5      =>
                  declare
                     D : constant IP.Integral_Sum_And_Squares_Result :=
                       IP.Integral_Sum_And_Squares
                         (U, IP.Float64_Integral, IP.Float32_Squared_Integral);
                  begin
                     E := D.Sum;
                  end;

               when 6      =>
                  E := IP.Integral_Sum (E);

               when 7      =>
                  E := IP.Integral_Sum (N);

               when others =>
                  E := IP.Integral_Sum (H);
            end case;
         exception
            when OpenCV.OpenCV_Error =>
               Rejections := Rejections + 1;
         end;
      end loop;
      AUnit.Assertions.Assert
        (Rejections = 8, "Ada rejects invalid contracts");
   end Invalid_Public;

   procedure Raw_Atomic (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S                          : constant OpenCV.Core.Mat := Source;
      E                          : OpenCV.Core.Mat;
      N                          : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      H                          : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.Int16, 1));
      A                          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      B                          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      T                          : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Hs, He, Hn, Hh, Ha, Hb, Ht : System.Address := System.Null_Address;
      procedure Input_S (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Hs := Address_Of (Handle);
      end Input_S;
      procedure Input_E (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         He := Address_Of (Handle);
      end Input_E;
      procedure Input_N (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Hn := Address_Of (Handle);
      end Input_N;
      procedure Input_H (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
      begin
         Hh := Address_Of (Handle);
      end Input_H;
      procedure Output_A
        (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Ha := Address_Of (Handle);
      end Output_A;
      procedure Output_B
        (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Hb := Address_Of (Handle);
      end Output_B;
      procedure Output_T
        (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Ht := Address_Of (Handle);
      end Output_T;
   begin
      OpenCV.Core.Set_To (A, (others => 41.0));
      OpenCV.Core.Set_To (B, (others => 42.0));
      OpenCV.Core.Set_To (T, (others => 43.0));
      OpenCV.Core.Module_Interop.With_Input_Handle (S, Input_S'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle (E, Input_E'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle (N, Input_N'Access);
      OpenCV.Core.Module_Interop.With_Input_Handle (H, Input_H'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle (A, Output_A'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle (B, Output_B'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle (T, Output_T'Access);
      AUnit.Assertions.Assert
        (Raw_Sum (System.Null_Address, 2, Ha) = C_API.Error_Invalid_Argument
         and then Raw_Sum (He, 2, Ha) = C_API.Error_Invalid_Argument
         and then Raw_Sum (Hn, 2, Ha) = C_API.Error_Invalid_Argument
         and then Raw_Sum (Hh, 2, Ha) = C_API.Error_Invalid_Argument
         and then Raw_Sum (Hs, 99, Ha) = C_API.Error_Invalid_Argument
         and then Raw_Pair (Hs, 0, 99, Ha, Hb) = C_API.Error_Invalid_Argument
         and then Raw_Pair (Hs, 2, 0, Ha, Hb) = C_API.Error_Invalid_Argument
         and then Raw_Pair (Hs, 0, 1, Ha, Ha) = C_API.Error_Invalid_Argument
         and then Raw_Complete (Hs, 0, 1, Ha, Hb, Hb)
                  = C_API.Error_Invalid_Argument,
         "raw preflight");
      AUnit.Assertions.Assert
        (Raw_Pair (Hh, 0, 1, Ha, Hb) = C_API.Error_Invalid_Argument
         and then Raw_Pair (Hs, 0, 99, Ha, Hb) = C_API.Error_Invalid_Argument
         and then Raw_Complete (Hs, 2, 0, Ha, Hb, Ht)
                  = C_API.Error_Invalid_Argument,
         "pair and complete failure before publication");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (A, 0, 0) = 41
         and then OpenCV.Core.UInt8_Access.Get (B, 0, 0) = 42
         and then OpenCV.Core.UInt8_Access.Get (T, 0, 0) = 43,
         "all rejected outputs unchanged");
      AUnit.Assertions.Assert
        (Raw_Complete (Hs, 0, 1, Ha, Hb, Ht) = C_API.Success,
         "valid raw call after failures");
   end Raw_Atomic;

   procedure Int32_Overflow (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  8_421_505 * 255 is the first UInt8 total exceeding INT_MAX.
      Width    : constant := 8_421_505;
      S        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, Width, (OpenCV.Core.UInt8, 1));
      A        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Hs, Ha   : System.Address := System.Null_Address;
      procedure Input (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Hs := Address_Of (Handle);
      end Input;
      procedure Output (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
      begin
         Ha := Address_Of (Handle);
      end Output;
      Rejected : Boolean := False;
   begin
      OpenCV.Core.Set_To (S, (others => 255.0));
      OpenCV.Core.Set_To (A, (others => 77.0));
      OpenCV.Core.Module_Interop.With_Input_Handle (S, Input'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle (A, Output'Access);
      AUnit.Assertions.Assert
        (Raw_Sum (Hs, 0, Ha) = C_API.Error_Invalid_Argument
         and then OpenCV.Core.UInt8_Access.Get (A, 0, 0) = 77,
         "actual Int32 total rejected before output allocation");
      begin
         declare
            D : constant OpenCV.Core.Mat :=
              IP.Integral_Sum (S, IP.Int32_Integral);
         begin
            if D.Is_Empty then
               null;
            end if;
         end;
      exception
         when OpenCV.OpenCV_Error =>
            Rejected := True;
      end;
      AUnit.Assertions.Assert (Rejected, "public Int32 overflow rejected");
   end Int32_Overflow;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Integral exact sum", Exact_Sum'Access));
      Result.Add_Test
        (Caller.Create
           ("Integral UInt8 Int32 overflow", Int32_Overflow'Access));
      Result.Add_Test
        (Caller.Create
           ("Integral squares and tilted", Squares_And_Tilt'Access));
      Result.Add_Test
        (Caller.Create
           ("Integral depths and Region", Depths_And_Region'Access));
      Result.Add_Test
        (Caller.Create ("Integral C3 channels", Channels'Access));
      Result.Add_Test
        (Caller.Create ("Integral public validation", Invalid_Public'Access));
      Result.Add_Test
        (Caller.Create ("Integral raw atomicity", Raw_Atomic'Access));
      return Result'Access;
   end Suite;
end Integral_Image_Tests;
