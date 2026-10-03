with Ada.Numerics;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Kernel_Generator_Tests is
   use OpenCV.Image_Processing;
   use AUnit.Assertions;
   use type OpenCV.Float64_Value;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.UInt8_Value;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   package API renames OpenCV.Image_Processing.Internal.C_API;
   use type API.Status;
   package F64 renames OpenCV.Core.Float64_Access;
   package U8 renames OpenCV.Core.UInt8_Access;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function From_Bits is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, OpenCV.Float64_Value);

   function Gabor
     (Depth : Gabor_Kernel_Depth := Float64_Kernel;
      Phase : OpenCV.Float64_Value := 0.4;
      Angle : OpenCV.Float64_Value := 0.7) return OpenCV.Core.Mat is
   begin
      return Get_Gabor_Kernel ((5, 3), 1.3, Angle, 3.2, 0.8, Phase, Depth);
   end Gabor;

   generic
      Depth : Gabor_Kernel_Depth;
   procedure Gabor_Metadata (Test : in out Fixture);
   procedure Gabor_Metadata (Test : in out Fixture) is
      pragma Unreferenced (Test);
      K     : constant OpenCV.Core.Mat := Gabor (Depth);
      Small : constant OpenCV.Core.Mat :=
        Get_Gabor_Kernel ((3, 3), 1.0, 0.0, 2.0, 1.0, Depth => Depth);
   begin
      Assert
        (K.Rows = 3 and then K.Columns = 5 and then K.Channels = 1,
         "exact rectangular C1 metadata");
      Assert
        (K.Depth
         = (if Depth = Float32_Kernel
            then OpenCV.Core.Float32
            else OpenCV.Core.Float64),
         "coefficient depth");
      Assert (Small.Rows = 3 and then Small.Columns = 3, "3x3 geometry");
   end Gabor_Metadata;
   procedure Metadata_32 is new Gabor_Metadata (Float32_Kernel);
   procedure Metadata_64 is new Gabor_Metadata (Float64_Kernel);

   procedure Formula_And_Order (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use Ada.Numerics.Long_Elementary_Functions;
      K   : constant OpenCV.Core.Mat := Gabor;
      K32 : constant OpenCV.Core.Mat := Gabor (Float32_Kernel);
   begin
      for Row in 0 .. 2 loop
         for Col in 0 .. 4 loop
            declare
               X        : constant Long_Float := Long_Float (2 - Col);
               Y        : constant Long_Float := Long_Float (1 - Row);
               XR       : constant Long_Float := X * Cos (0.7) + Y * Sin (0.7);
               YR       : constant Long_Float :=
                 -X * Sin (0.7) + Y * Cos (0.7);
               Expected : constant OpenCV.Float64_Value :=
                 OpenCV.Float64_Value
                   (Exp (-0.5 * ((XR / 1.3)**2 + (YR / (1.3 / 0.8))**2))
                    * Cos (2.0 * Ada.Numerics.Pi * XR / 3.2 + 0.4));
            begin
               Assert
                 (abs (F64.Get (K, Row, Col) - Expected) < 1.0E-12,
                  "native reversed coordinates and formula");
               Assert
                 (abs (OpenCV.Float64_Value
                         (OpenCV.Core.Float32_Access.Get (K32, Row, Col))
                       - Expected)
                  < 1.0E-7,
                  "Float32 rounding tolerance");
            end;
         end loop;
      end loop;
   end Formula_And_Order;

   procedure Phase_And_Orientation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Default_K  : constant OpenCV.Core.Mat :=
        Get_Gabor_Kernel ((5, 3), 1.3, 0.7, 3.2, 0.8);
      Explicit_K : constant OpenCV.Core.Mat :=
        Gabor (Phase => Ada.Numerics.Pi / 2.0);
      Changed    : constant OpenCV.Core.Mat := Gabor;
      Rotated    : constant OpenCV.Core.Mat := Gabor (Angle => 0.0);
   begin
      Assert
        (abs (F64.Get (Default_K, 0, 0) - F64.Get (Explicit_K, 0, 0))
         < 1.0E-12,
         "default phase");
      Assert
        (abs (F64.Get (Changed, 0, 0) - F64.Get (Default_K, 0, 0)) > 0.01,
         "phase changes values");
      Assert
        (abs (F64.Get (Changed, 0, 0) - F64.Get (Rotated, 0, 0)) > 0.01,
         "orientation changes values");
   end Phase_And_Orientation;

   generic
      Depth : Gabor_Kernel_Depth;
   procedure Filter_Integration (Test : in out Fixture);
   procedure Filter_Integration (Test : in out Fixture) is
      pragma Unreferenced (Test);
      K           : OpenCV.Core.Mat := Gabor (Depth);
      Other       : constant OpenCV.Core.Mat := Gabor (Depth);
      Before      : constant OpenCV.Core.Mat := K.Clone;
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.Float64, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for R in 0 .. 8 loop
         for C in 0 .. 8 loop
            F64.Set (Source, R, C, OpenCV.Float64_Value ((R + C) mod 3));
         end loop;
      end loop;
      Filter_2D (Source, Destination, K);
      Assert
        (Destination.Rows = 9
         and then abs (F64.Get (Destination, 4, 4)) > 0.01,
         "direct Gabor filtering is nontrivial");
      for R in 0 .. 8 loop
         for C in 0 .. 8 loop
            Assert
              (F64.Get (Source, R, C) = OpenCV.Float64_Value ((R + C) mod 3),
               "source unchanged");
         end loop;
      end loop;
      if Depth = Float64_Kernel then
         Assert
           (F64.Get (K, 0, 0) = F64.Get (Before, 0, 0), "kernel unchanged");
         F64.Set (K, 0, 0, 42.0);
         Assert (F64.Get (Other, 0, 0) /= 42.0, "independent storage");
      else
         Assert
           (OpenCV.Core.Float32_Access.Get (K, 0, 0)
            = OpenCV.Core.Float32_Access.Get (Before, 0, 0),
            "Float32 kernel unchanged");
         OpenCV.Core.Float32_Access.Set (K, 0, 0, 42.0);
         Assert
           (OpenCV.Core.Float32_Access.Get (Other, 0, 0) /= 42.0,
            "Float32 independent storage");
      end if;
   end Filter_Integration;
   procedure Filter_32 is new Filter_Integration (Float32_Kernel);
   procedure Filter_64 is new Filter_Integration (Float64_Kernel);

   generic
      Case_Number : Positive;
   procedure Reject_Gabor (Test : in out Fixture);
   procedure Reject_Gabor (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);
      Size                : OpenCV.Size := (3, 3);
      Sigma, Wave, Aspect : OpenCV.Float64_Value := 1.0;
      Angle, Phase        : OpenCV.Float64_Value := 0.0;
      Bad                 : constant OpenCV.Float64_Value :=
        From_Bits (16#7FF0_0000_0000_0000#);
      Raised              : Boolean := False;
   begin
      case Case_Number is
         when 1      =>
            Size.Width := 4;

         when 2      =>
            Size.Height := 4;

         when 3      =>
            Size.Width := 0;

         when 4      =>
            Size.Height := 0;

         when 5      =>
            Sigma := Bad;

         when 6      =>
            Sigma := -1.0;

         when 7      =>
            Angle := Bad;

         when 8      =>
            Wave := 0.0;

         when 9      =>
            Wave := Bad;

         when 10     =>
            Aspect := 0.0;

         when 11     =>
            Aspect := Bad;

         when 12     =>
            Phase := Bad;

         when others =>
            Sigma := From_Bits (16#7FF8_0000_0000_0000#);
      end case;
      begin
         declare
            K : constant OpenCV.Core.Mat :=
              Get_Gabor_Kernel (Size, Sigma, Angle, Wave, Aspect, Phase);
         begin
            Assert (K.Is_Empty, "invalid call must not return");
         end;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      Assert (Raised, "specific public error");
      declare
         K : constant OpenCV.Core.Mat := Gabor;
      begin
         Assert (K.Rows = 3, "recovery after rejection");
      end;
   end Reject_Gabor;
   procedure Reject_1 is new Reject_Gabor (1);
   procedure Reject_2 is new Reject_Gabor (2);
   procedure Reject_3 is new Reject_Gabor (3);
   procedure Reject_4 is new Reject_Gabor (4);
   procedure Reject_5 is new Reject_Gabor (5);
   procedure Reject_6 is new Reject_Gabor (6);
   procedure Reject_7 is new Reject_Gabor (7);
   procedure Reject_8 is new Reject_Gabor (8);
   procedure Reject_9 is new Reject_Gabor (9);
   procedure Reject_10 is new Reject_Gabor (10);
   procedure Reject_11 is new Reject_Gabor (11);
   procedure Reject_12 is new Reject_Gabor (12);
   procedure Reject_13 is new Reject_Gabor (13);

   generic
      Shape : Morphology_Shape;
   procedure Masks_And_Morphology (Test : in out Fixture);
   procedure Masks_And_Morphology (Test : in out Fixture) is
      pragma Unreferenced (Test);
      K      : OpenCV.Core.Mat := Get_Structuring_Element ((5, 5), Shape);
      Other  : constant OpenCV.Core.Mat :=
        Get_Structuring_Element ((5, 5), Shape);
      One    : constant OpenCV.Core.Mat :=
        Get_Structuring_Element ((1, 1), Shape);
      Even   : constant OpenCV.Core.Mat :=
        Get_Structuring_Element ((4, 2), Shape);
      Rect   : constant OpenCV.Core.Mat := Get_Structuring_Element ((5, 3));
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 1));
      A, B   : OpenCV.Core.Mat;
      procedure Equal is
      begin
         for R in 0 .. 8 loop
            for C in 0 .. 8 loop
               Assert
                 (U8.Get (A, R, C) = U8.Get (B, R, C),
                  "custom mask matches shape overload");
               Assert
                 (U8.Get (Source, R, C)
                  = OpenCV.UInt8_Value ((R * 17 + C * 31) mod 256),
                  "borrowed source unchanged");
            end loop;
         end loop;
      end Equal;
   begin
      Assert
        (K.Depth = OpenCV.Core.UInt8
         and then K.Channels = 1
         and then K.Rows = 5
         and then K.Columns = 5,
         "mask metadata");
      Assert (Even.Rows = 2 and then Even.Columns = 4, "even exact size");
      Assert (U8.Get (One, 0, 0) = 1, "1x1 collapses to Rectangle");
      for R in 0 .. 2 loop
         for C in 0 .. 4 loop
            Assert (U8.Get (Rect, R, C) = 1, "3x5 Rectangle mask");
         end loop;
      end loop;
      for R in 0 .. 4 loop
         for C in 0 .. 4 loop
            Assert (U8.Get (K, R, C) in 0 .. 1, "native binary values");
            if Shape = Rectangle then
               Assert (U8.Get (K, R, C) = 1, "Rectangle included");
            elsif Shape = Cross then
               Assert
                 (U8.Get (K, R, C) = (if R = 2 or else C = 2 then 1 else 0),
                  "centered Cross");
            else
               Assert
                 (U8.Get (K, R, C) = U8.Get (K, 4 - R, C)
                  and then U8.Get (K, R, C) = U8.Get (K, R, 4 - C),
                  "Ellipse symmetry");
            end if;
         end loop;
      end loop;
      for R in 0 .. 8 loop
         for C in 0 .. 8 loop
            U8.Set
              (Source, R, C, OpenCV.UInt8_Value ((R * 17 + C * 31) mod 256));
         end loop;
      end loop;
      Erode (Source, A, K);
      Erode (Source, B, (5, 5), Shape);
      Equal;
      Dilate (Source, A, K);
      Dilate (Source, B, (5, 5), Shape);
      Equal;
      Apply_Morphology (Source, A, Opening, K);
      Apply_Morphology (Source, B, Opening, (5, 5), Shape);
      Equal;
      Assert (U8.Get (K, 2, 2) = 1, "mask unchanged by morphology");
      U8.Set (K, 2, 2, 0);
      Assert (U8.Get (Other, 2, 2) = 1, "independent masks");
   end Masks_And_Morphology;
   procedure Rectangle_Test is new Masks_And_Morphology (Rectangle);
   procedure Cross_Test is new Masks_And_Morphology (Cross);
   procedure Ellipse_Test is new Masks_And_Morphology (Ellipse);

   procedure Explicit_Cross (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Anchor : constant OpenCV.Point := (0, 1);
      K      : constant OpenCV.Core.Mat :=
        Get_Structuring_Element ((5, 5), Cross, Anchor);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 1));
      A, B   : OpenCV.Core.Mat;
   begin
      for R in 0 .. 4 loop
         for C in 0 .. 4 loop
            Assert
              (U8.Get (K, R, C) = (if R = 1 or else C = 0 then 1 else 0),
               "off-center Cross");
         end loop;
      end loop;
      for R in 0 .. 8 loop
         for C in 0 .. 8 loop
            U8.Set (Source, R, C, OpenCV.UInt8_Value (R * 9 + C));
         end loop;
      end loop;
      Dilate (Source, A, K, Anchor);
      Dilate (Source, B, (5, 5), Cross, Anchor);
      for R in 0 .. 8 loop
         for C in 0 .. 8 loop
            Assert
              (U8.Get (A, R, C) = U8.Get (B, R, C),
               "same explicit generating and application anchor");
         end loop;
      end loop;
   end Explicit_Cross;

   procedure Reject_Masks (Test : in out Fixture) is
      pragma Unreferenced (Test);
      procedure Check (Size : OpenCV.Size; Anchor : OpenCV.Point) is
         Raised : Boolean := False;
      begin
         begin
            declare
               K : constant OpenCV.Core.Mat :=
                 Get_Structuring_Element (Size, Cross, Anchor);
            begin
               Assert (K.Is_Empty, "invalid call must not return");
            end;
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         Assert (Raised, "invalid size or anchor raises OpenCV_Error");
      end Check;
   begin
      Check ((0, 3), (0, 0));
      Check ((3, 0), (0, 0));
      Check ((3, 3), (-1, 0));
      Check ((3, 3), (0, -1));
      Check ((3, 3), (3, 0));
      Check ((3, 3), (0, 3));
   end Reject_Masks;

   procedure Raw_Atomicity (Test : in out Fixture) is
      pragma Unreferenced (Test);
      K      : OpenCV.Core.Mat := Gabor;
      Status : API.Status := API.Success;
      procedure Output (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
      begin
         Status :=
           API.Get_Gabor_Kernel (Handle, 3, 3, 1.0, 0.0, 2.0, 1.0, 0.0, 99);
         Assert (Status = API.Error_Invalid_Argument, "raw invalid depth");
         Status :=
           API.Get_Gabor_Kernel
             (Handle,
              Interfaces.Integer_32'Last,
              Interfaces.Integer_32'Last,
              1.0,
              0.0,
              2.0,
              1.0,
              0.0,
              API.Gaussian_Kernel_Float64);
         Assert
           (Status = API.Error_Invalid_Argument,
            "allocation overflow before allocation");
         for Shape in 3 .. 4 loop
            Status :=
              API.Get_Structuring_Element
                (Handle, 3, 3, Interfaces.Integer_32 (Shape), 1, 1);
            Assert
              (Status = API.Error_Invalid_Argument,
               "unknown and Diamond selectors rejected");
         end loop;
         Status :=
           API.Get_Structuring_Element
             (Handle, 3, 92_682, API.Morphology_Ellipse, 1, 0);
         Assert
           (Status = API.Error_Invalid_Argument,
            "ellipse r*r overflow rejected before allocation");
         Status :=
           API.Get_Gabor_Kernel
             (Handle,
              0,
              3,
              1.0,
              0.0,
              2.0,
              1.0,
              0.0,
              API.Gaussian_Kernel_Float64);
         Assert
           (Status = API.Error_Invalid_Argument,
            "raw automatic Gabor extent rejected");
         Status :=
           API.Get_Structuring_Element
             (Handle, 3, 0, API.Morphology_Rectangle, 0, 0);
         Assert
           (Status = API.Error_Invalid_Argument,
            "raw zero height rejected before division");
         Status :=
           API.Get_Structuring_Element
             (Handle, 3, 3, API.Morphology_Cross, 3, 0);
         Assert (Status = API.Error_OpenCV, "normalizeAnchor assertion");
      end Output;
      Saved  : constant OpenCV.Float64_Value := F64.Get (K, 0, 0);
      procedure Recover (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
      begin
         Status :=
           API.Get_Structuring_Element
             (Handle, 3, 3, API.Morphology_Rectangle, 1, 1);
      end Recover;
   begin
      OpenCV.Core.Module_Interop.With_Output_Handle (K, Output'Access);
      Assert
        (K.Rows = 3 and then K.Columns = 5 and then F64.Get (K, 0, 0) = Saved,
         "failure atomicity");
      OpenCV.Core.Module_Interop.With_Output_Handle (K, Recover'Access);
      Assert
        (Status = API.Success and then U8.Get (K, 0, 0) = 1, "raw recovery");
   end Raw_Atomicity;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Gabor Float32", Metadata_32'Access));
      Result.Add_Test (Caller.Create ("Gabor Float64", Metadata_64'Access));
      Result.Add_Test
        (Caller.Create ("Gabor formula/order", Formula_And_Order'Access));
      Result.Add_Test
        (Caller.Create
           ("Gabor phase/orientation", Phase_And_Orientation'Access));
      Result.Add_Test (Caller.Create ("Gabor Filter32", Filter_32'Access));
      Result.Add_Test (Caller.Create ("Gabor Filter64", Filter_64'Access));
      Result.Add_Test (Caller.Create ("Gabor even width", Reject_1'Access));
      Result.Add_Test (Caller.Create ("Gabor even height", Reject_2'Access));
      Result.Add_Test (Caller.Create ("Gabor zero width", Reject_3'Access));
      Result.Add_Test (Caller.Create ("Gabor zero height", Reject_4'Access));
      Result.Add_Test (Caller.Create ("Gabor sigma Inf", Reject_5'Access));
      Result.Add_Test
        (Caller.Create ("Gabor sigma negative", Reject_6'Access));
      Result.Add_Test (Caller.Create ("Gabor angle Inf", Reject_7'Access));
      Result.Add_Test
        (Caller.Create ("Gabor wavelength zero", Reject_8'Access));
      Result.Add_Test
        (Caller.Create ("Gabor wavelength Inf", Reject_9'Access));
      Result.Add_Test (Caller.Create ("Gabor aspect zero", Reject_10'Access));
      Result.Add_Test (Caller.Create ("Gabor aspect Inf", Reject_11'Access));
      Result.Add_Test (Caller.Create ("Gabor phase Inf", Reject_12'Access));
      Result.Add_Test (Caller.Create ("Gabor sigma NaN", Reject_13'Access));
      Result.Add_Test
        (Caller.Create ("Rectangle mask/morphology", Rectangle_Test'Access));
      Result.Add_Test
        (Caller.Create ("Cross mask/morphology", Cross_Test'Access));
      Result.Add_Test
        (Caller.Create ("Ellipse mask/morphology", Ellipse_Test'Access));
      Result.Add_Test
        (Caller.Create ("Explicit Cross integration", Explicit_Cross'Access));
      Result.Add_Test (Caller.Create ("Invalid masks", Reject_Masks'Access));
      Result.Add_Test
        (Caller.Create ("Raw safety/atomicity", Raw_Atomicity'Access));
      return Result'Access;
   end Suite;
end Kernel_Generator_Tests;
