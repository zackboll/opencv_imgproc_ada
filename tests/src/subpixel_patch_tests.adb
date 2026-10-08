with Ada.Unchecked_Conversion;
with Interfaces;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.Float32_Vec3_Access;
with OpenCV.Image_Processing;

package body Subpixel_Patch_Tests is
   --  Intentional IEEE fixtures follow the existing nonfinite-test pattern.
   pragma Suppress (Validity_Check);
   package C renames OpenCV.Core;
   package U renames C.UInt8_Access;
   package F renames C.Float32_Access;
   package IP renames OpenCV.Image_Processing;
   use AUnit.Assertions;
   use type C.Depth_Type;
   use type OpenCV.UInt8_Value;
   use type OpenCV.Float32_Value;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result            : aliased AUnit.Test_Suites.Test_Suite;
   Adapter_Result    : aliased AUnit.Test_Suites.Test_Suite;
   Historical_Result : aliased AUnit.Test_Suites.Test_Suite;
   function From_Bits is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_32, OpenCV.Float32_Value);

   function Ramp return C.Mat is
      M : C.Mat := C.Create (4, 4, (C.UInt8, 1));
   begin
      for R in 0 .. 3 loop
         for Col in 0 .. 3 loop
            U.Set (M, R, Col, OpenCV.UInt8_Value (R * 40 + Col * 8));
         end loop;
      end loop;
      return M;
   end Ramp;

   procedure Top_Left (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant C.Mat := Ramp;
      P : constant C.Mat := IP.Extract_Subpixel_Patch (S, (3, 3), (0.0, 0.0));
   begin
      for R in 0 .. 2 loop
         for Col in 0 .. 2 loop
            Assert
              (U.Get (P, R, Col)
               = OpenCV.UInt8_Value
                   (Integer'Max (0, R - 1)
                    * 40
                    + Integer'Max (0, Col - 1) * 8),
               "top-left replicated ramp");
         end loop;
      end loop;
   end Top_Left;

   procedure Bottom_Right (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant C.Mat := Ramp;
      P : constant C.Mat := IP.Extract_Subpixel_Patch (S, (1, 1), (3.0, 3.0));
   begin
      Assert (U.Get (P, 0, 0) = 144, "bottom-right exact sample");
   end Bottom_Right;

   procedure Interior (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant C.Mat := Ramp;
      P : C.Mat := IP.Extract_Subpixel_Patch (S, (2, 2), (1.5, 1.5));
   begin
      Assert (P.Rows = 2 and then P.Columns = 2, "even geometry");
      Assert (U.Get (P, 0, 0) = 48, "integer adjusted center");
      U.Set (P, 0, 0, 255);
      Assert (U.Get (S, 1, 1) = 48, "independent owning result");
   end Interior;

   procedure Fractional (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant C.Mat := Ramp;
      P : constant C.Mat :=
        IP.Extract_Subpixel_Patch
          (S, (1, 1), (1.25, 1.25), IP.Promote_To_Float32);
   begin
      Assert (P.Depth = C.Float32, "UInt8 promotion");
      Assert
        (abs (F.Get (P, 0, 0) - 60.0) < 0.001,
         "independent bilinear ramp oracle");
   end Fractional;

   procedure Oversized (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant C.Mat := Ramp;
      P : constant C.Mat := IP.Extract_Subpixel_Patch (S, (7, 9), (1.0, 1.0));
   begin
      Assert (P.Rows = 9 and then P.Columns = 7, "oversized geometry");
      Assert (U.Get (P, 0, 0) = 0, "oversized top-left");
      Assert (U.Get (P, 8, 6) = 144, "oversized bottom-right");
   end Oversized;

   generic
      Width, Height : Positive;
      X, Y : OpenCV.Float32_Value;
   procedure Geometry (T : in out Fixture);

   procedure Geometry (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant C.Mat := Ramp;
      P : constant C.Mat :=
        IP.Extract_Subpixel_Patch
          (S,
           (OpenCV.Size_Coordinate (Width), OpenCV.Size_Coordinate (Height)),
           (X, Y));
   begin
      for R in 0 .. Height - 1 loop
         for Col in 0 .. Width - 1 loop
            declare
               SX       : constant OpenCV.Float32_Value :=
                 OpenCV.Float32_Value'Max
                   (0.0,
                    OpenCV.Float32_Value'Min
                      (3.0,
                       X
                       - OpenCV.Float32_Value (Width - 1) * 0.5
                       + OpenCV.Float32_Value (Col)));
               SY       : constant OpenCV.Float32_Value :=
                 OpenCV.Float32_Value'Max
                   (0.0,
                    OpenCV.Float32_Value'Min
                      (3.0,
                       Y
                       - OpenCV.Float32_Value (Height - 1) * 0.5
                       + OpenCV.Float32_Value (R)));
               Expected : constant OpenCV.UInt8_Value :=
                 OpenCV.UInt8_Value (SY * 40.0 + SX * 8.0);
            begin
               Assert (U.Get (P, R, Col) = Expected, "clamped ramp oracle");
            end;
         end loop;
      end loop;
   end Geometry;

   procedure Odd is new Geometry (3, 3, 1.0, 1.0);
   procedure One_Row is new Geometry (3, 1, 1.0, 1.0);
   procedure One_Column is new Geometry (1, 3, 1.0, 1.0);
   procedure Single is new Geometry (1, 1, 1.0, 1.0);
   procedure Fraction_U8 is new Geometry (1, 1, 1.25, 1.25);
   procedure Top is new Geometry (3, 3, 1.0, 0.0);
   procedure Bottom is new Geometry (3, 3, 1.0, 3.0);
   procedure Left is new Geometry (3, 3, 0.0, 1.0);
   procedure Right is new Geometry (3, 3, 3.0, 1.0);
   procedure Top_Right is new Geometry (3, 3, 3.0, 0.0);
   procedure Bottom_Left is new Geometry (3, 3, 0.0, 3.0);
   procedure Bottom_Corner is new Geometry (3, 3, 3.0, 3.0);
   procedure Wider is new Geometry (7, 3, 1.0, 1.0);
   procedure Taller is new Geometry (3, 7, 1.0, 1.0);
   procedure Fraction_Top is new Geometry (3, 3, 1.25, 0.25);
   procedure Fraction_Bottom is new Geometry (3, 3, 1.25, 2.75);
   procedure Fraction_Left is new Geometry (3, 3, 0.25, 1.25);
   procedure Fraction_Right is new Geometry (3, 3, 2.75, 1.25);

   procedure Invalid (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant C.Mat := Ramp;
   begin
      declare
         P : constant C.Mat :=
           IP.Extract_Subpixel_Patch (S, (1, 1), (4.0, 1.0));
         pragma Unreferenced (P);
      begin
         Assert (False, "outside center accepted");
      end;
   exception
      when OpenCV.OpenCV_Error =>
         null;
   end Invalid;

   generic
      Kind : Positive;
   procedure Invalid_Request (T : in out Fixture);

   procedure Invalid_Request (T : in out Fixture) is
      pragma Unreferenced (T);
      S      : C.Mat := Ramp;
      Size   : OpenCV.Size := (1, 1);
      Center : OpenCV.Float32_Point := (1.0, 1.0);
   begin
      case Kind is
         when 1      =>
            S := C.Create (0, 0, (C.UInt8, 1));

         when 2      =>
            S := C.Create (4, 4, (C.UInt16, 1));

         when 3      =>
            S := C.Create (4, 4, (C.UInt8, 2));

         when 4      =>
            Size.Width := 0;

         when 5      =>
            Size.Height := 0;

         when 6      =>
            Center.X := -0.25;

         when 7      =>
            Center.Y := 4.0;

         when 8      =>
            Center.X := From_Bits (16#7FC0_0000#);

         when 9      =>
            Center.Y := From_Bits (16#7F80_0000#);

         when others =>
            Center.Y := From_Bits (16#FF80_0000#);
      end case;
      declare
         P : constant C.Mat := IP.Extract_Subpixel_Patch (S, Size, Center);
         pragma Unreferenced (P);
      begin
         Assert (False, "invalid request accepted");
      end;
   exception
      when OpenCV.OpenCV_Error =>
         null;
   end Invalid_Request;

   procedure Empty_Source is new Invalid_Request (1);
   procedure Bad_Depth is new Invalid_Request (2);
   procedure Bad_Channels is new Invalid_Request (3);
   procedure Zero_Width is new Invalid_Request (4);
   procedure Zero_Height is new Invalid_Request (5);
   procedure Negative_Center is new Invalid_Request (6);
   procedure Outside_Y is new Invalid_Request (7);
   procedure NaN_Center is new Invalid_Request (8);
   procedure Plus_Inf_Center is new Invalid_Request (9);
   procedure Minus_Inf_Center is new Invalid_Request (10);

   procedure Float_Source (T : in out Fixture) is
      pragma Unreferenced (T);
      S : C.Mat := C.Create (4, 4, (C.Float32, 1));
   begin
      for R in 0 .. 3 loop
         for Col in 0 .. 3 loop
            F.Set (S, R, Col, OpenCV.Float32_Value (R * 40 + Col * 8));
         end loop;
      end loop;
      for D in IP.Subpixel_Patch_Output_Depth loop
         declare
            P : constant C.Mat :=
              IP.Extract_Subpixel_Patch (S, (1, 1), (1.25, 1.25), D);
         begin
            Assert (P.Depth = C.Float32, "Float32 output depth");
            Assert
              (abs (F.Get (P, 0, 0) - 60.0) < 0.001,
               "Float32 bilinear interpolation");
         end;
      end loop;
   end Float_Source;

   procedure Region_Isolation (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent : C.Mat := C.Create (6, 6, (C.UInt8, 1));
   begin
      for R in 0 .. 5 loop
         for Col in 0 .. 5 loop
            U.Set (Parent, R, Col, 250);
         end loop;
      end loop;
      declare
         S : C.Mat := Parent.Region ((1, 1, 4, 4));
      begin
         for R in 0 .. 3 loop
            for Col in 0 .. 3 loop
               U.Set (S, R, Col, 20);
            end loop;
         end loop;
         declare
            P : constant C.Mat :=
              IP.Extract_Subpixel_Patch (S, (7, 7), (0.25, 0.25));
         begin
            for R in 0 .. 6 loop
               for Col in 0 .. 6 loop
                  Assert (U.Get (P, R, Col) = 20, "isolated Region");
               end loop;
            end loop;
         end;
         U.Set (Parent, 0, 0, 200);
         declare
            P : constant C.Mat :=
              IP.Extract_Subpixel_Patch (S, (7, 7), (0.25, 0.25));
         begin
            Assert (U.Get (P, 0, 0) = 20, "parent change excluded");
            Assert (U.Get (Parent, 0, 0) = 200, "parent unchanged");
         end;
      end;
   end Region_Isolation;

   procedure Three_Channels (T : in out Fixture) is
      pragma Unreferenced (T);
      S  : C.Mat := C.Create (4, 4, (C.UInt8, 3));
      FS : C.Mat := C.Create (4, 4, (C.Float32, 3));
   begin
      for R in 0 .. 3 loop
         for Col in 0 .. 3 loop
            C.UInt8_Vec3_Access.Set (S, R, Col, (20, 40, 80));
            C.Float32_Vec3_Access.Set (FS, R, Col, (20.0, 40.0, 80.0));
         end loop;
      end loop;
      for D in IP.Subpixel_Patch_Output_Depth loop
         declare
            P  : constant C.Mat :=
              IP.Extract_Subpixel_Patch (S, (1, 1), (1.25, 1.25), D);
            FP : constant C.Mat :=
              IP.Extract_Subpixel_Patch (FS, (1, 1), (1.25, 1.25), D);
         begin
            if P.Depth = C.UInt8 then
               Assert
                 (C.UInt8_Vec3_Access.Get (P, 0, 0) (2) = 80,
                  "UInt8 C3 preserve");
            else
               Assert
                 (C.Float32_Vec3_Access.Get (P, 0, 0) (2) = 80.0,
                  "UInt8 C3 promote");
            end if;
            Assert
              (C.Float32_Vec3_Access.Get (FP, 0, 0) (1) = 40.0, "Float32 C3");
         end;
      end loop;
   end Three_Channels;

   procedure Nonfinite_Samples (T : in out Fixture) is
      pragma Unreferenced (T);
      S    : C.Mat := C.Create (4, 4, (C.Float32, 1));
      type Bit_Array is array (Positive range <>) of Interfaces.Unsigned_32;
      Bits : constant Bit_Array :=
        (16#7FC0_0000#, 16#7F80_0000#, 16#FF80_0000#);
      use type F.Float32_Classification;
   begin
      for B of Bits loop
         for R in 0 .. 3 loop
            for Col in 0 .. 3 loop
               F.Set (S, R, Col, 12.0);
            end loop;
         end loop;
         F.Set (S, 1, 1, From_Bits (B));
         declare
            P : constant C.Mat :=
              IP.Extract_Subpixel_Patch (S, (1, 1), (1.25, 1.25));
         begin
            Assert
              (F.Classify (P, 0, 0) = F.Classify (S, 1, 1),
               "native sampled IEEE propagation");
         end;
         declare
            P : constant C.Mat :=
              IP.Extract_Subpixel_Patch (S, (1, 1), (2.25, 2.25));
         begin
            Assert (F.Get (P, 0, 0) = 12.0, "nonsampled IEEE excluded");
         end;
      end loop;
   end Nonfinite_Samples;

   function Suite
     (Only_Adapter : Boolean := False; Only_Historical : Boolean := False)
      return AUnit.Test_Suites.Access_Test_Suite is
   begin
      if Only_Adapter or else Only_Historical then
         declare
            S : constant AUnit.Test_Suites.Access_Test_Suite :=
              (if Only_Historical
               then Historical_Result'Access
               else Adapter_Result'Access);
         begin
            S.Add_Test (Caller.Create ("Subpixel top-left", Top_Left'Access));
            S.Add_Test
              (Caller.Create ("Subpixel bottom-right", Bottom_Right'Access));
            if not Only_Historical then
               S.Add_Test (Caller.Create ("Subpixel top", Top'Access));
               S.Add_Test (Caller.Create ("Subpixel bottom", Bottom'Access));
               S.Add_Test (Caller.Create ("Subpixel left", Left'Access));
               S.Add_Test (Caller.Create ("Subpixel right", Right'Access));
               S.Add_Test
                 (Caller.Create ("Subpixel top-right", Top_Right'Access));
               S.Add_Test
                 (Caller.Create ("Subpixel bottom-left", Bottom_Left'Access));
               S.Add_Test
                 (Caller.Create ("Subpixel corner", Bottom_Corner'Access));
               S.Add_Test (Caller.Create ("Subpixel wider", Wider'Access));
               S.Add_Test (Caller.Create ("Subpixel taller", Taller'Access));
               S.Add_Test
                 (Caller.Create
                    ("Subpixel fraction top", Fraction_Top'Access));
               S.Add_Test
                 (Caller.Create
                    ("Subpixel fraction bottom", Fraction_Bottom'Access));
               S.Add_Test
                 (Caller.Create
                    ("Subpixel fraction left", Fraction_Left'Access));
               S.Add_Test
                 (Caller.Create
                    ("Subpixel fraction right", Fraction_Right'Access));
               S.Add_Test
                 (Caller.Create ("Subpixel oversized", Oversized'Access));
               S.Add_Test
                 (Caller.Create ("Subpixel Region", Region_Isolation'Access));
            end if;
            return S;
         end;
      end if;
      Result.Add_Test (Caller.Create ("Subpixel top-left", Top_Left'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel bottom-right", Bottom_Right'Access));
      Result.Add_Test (Caller.Create ("Subpixel interior", Interior'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel fractional", Fractional'Access));
      Result.Add_Test (Caller.Create ("Subpixel oversized", Oversized'Access));
      Result.Add_Test (Caller.Create ("Subpixel invalid", Invalid'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel Float32", Float_Source'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel Region", Region_Isolation'Access));
      Result.Add_Test (Caller.Create ("Subpixel C3", Three_Channels'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel IEEE", Nonfinite_Samples'Access));
      Result.Add_Test (Caller.Create ("Subpixel odd", Odd'Access));
      Result.Add_Test (Caller.Create ("Subpixel row", One_Row'Access));
      Result.Add_Test (Caller.Create ("Subpixel column", One_Column'Access));
      Result.Add_Test (Caller.Create ("Subpixel single", Single'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel UInt8 fraction", Fraction_U8'Access));
      Result.Add_Test (Caller.Create ("Subpixel top", Top'Access));
      Result.Add_Test (Caller.Create ("Subpixel bottom", Bottom'Access));
      Result.Add_Test (Caller.Create ("Subpixel left", Left'Access));
      Result.Add_Test (Caller.Create ("Subpixel right", Right'Access));
      Result.Add_Test (Caller.Create ("Subpixel top-right", Top_Right'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel bottom-left", Bottom_Left'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel corner", Bottom_Corner'Access));
      Result.Add_Test (Caller.Create ("Subpixel wider", Wider'Access));
      Result.Add_Test (Caller.Create ("Subpixel taller", Taller'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel fraction top", Fraction_Top'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel fraction bottom", Fraction_Bottom'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel fraction left", Fraction_Left'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel fraction right", Fraction_Right'Access));
      Result.Add_Test (Caller.Create ("Subpixel empty", Empty_Source'Access));
      Result.Add_Test (Caller.Create ("Subpixel bad depth", Bad_Depth'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel bad channels", Bad_Channels'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel zero width", Zero_Width'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel zero height", Zero_Height'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel negative center", Negative_Center'Access));
      Result.Add_Test (Caller.Create ("Subpixel outside Y", Outside_Y'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel NaN center", NaN_Center'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel +Inf center", Plus_Inf_Center'Access));
      Result.Add_Test
        (Caller.Create ("Subpixel -Inf center", Minus_Inf_Center'Access));
      return Result'Access;
   end Suite;
end Subpixel_Patch_Tests;
