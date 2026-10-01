with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Corner_Analysis_Tests is
   pragma Suppress (Validity_Check);
   use type OpenCV.Float32_Value;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type OpenCV.Float64_Value;
   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_32, OpenCV.Float32_Value);
   function Bits_To_Double is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, OpenCV.Float64_Value);

   function Scene (Float_Source : Boolean := False) return OpenCV.Core.Mat is
      Depth : constant OpenCV.Core.Depth_Type :=
        (if Float_Source then OpenCV.Core.Float32 else OpenCV.Core.UInt8);
      Image : OpenCV.Core.Mat := OpenCV.Core.Create (32, 32, (Depth, 1));
   begin
      for Y in 0 .. 31 loop
         for X in 0 .. 31 loop
            if Float_Source then
               OpenCV.Core.Float32_Access.Set
                 (Image,
                  Y,
                  X,
                  (if Y >= 16 and then X >= 16 then 255.0 else 0.0));
            else
               OpenCV.Core.UInt8_Access.Set
                 (Image, Y, X, (if Y >= 16 and then X >= 16 then 255 else 0));
            end if;
         end loop;
      end loop;
      return Image;
   end Scene;

   procedure Check_Map
     (Map : OpenCV.Core.Mat; Channels : OpenCV.Core.Channel_Count) is
   begin
      AUnit.Assertions.Assert
        (Map.Rows = 32
         and then Map.Columns = 32
         and then Map.Depth = OpenCV.Core.Float32
         and then Map.Channels = Channels,
         "response map geometry and Float32 channels");
   end Check_Map;

   procedure Must_Reject (Action : not null access procedure) is
      Raised : Boolean := False;
   begin
      begin
         Action.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert
        (Raised, "invalid corner request must raise OpenCV_Error");
   end Must_Reject;

   procedure Minimum_Corner (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
      M : constant OpenCV.Core.Mat := IP.Corner_Minimum_Eigenvalue (S);
   begin
      Check_Map (M, 1);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (M, 16, 16)
         > OpenCV.Core.Float32_Access.Get (M, 3, 3),
         "strong corner vs flat");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (S, 16, 16) = 255,
         "minimum response preserves source");
   end Minimum_Corner;

   procedure Float_Minimum (T : in out Fixture) is
      pragma Unreferenced (T);
      M : constant OpenCV.Core.Mat :=
        IP.Corner_Minimum_Eigenvalue (Scene (True));
   begin
      Check_Map (M, 1);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (M, 16, 16) > 0.0,
         "Float32 minimum corner");
   end Float_Minimum;

   procedure Harris (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
      A : constant OpenCV.Core.Mat := IP.Harris_Corner_Response (S);
      B : constant OpenCV.Core.Mat := IP.Harris_Corner_Response (S, K => 0.12);
   begin
      Check_Map (A, 1);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (A, 16, 16)
         /= OpenCV.Core.Float32_Access.Get (B, 16, 16),
         "Harris k affects score");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (S, 16, 16) = 255,
         "Harris preserves source");
   end Harris;

   procedure Eigen (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
      M : constant OpenCV.Core.Mat := IP.Corner_Eigenvalues_And_Vectors (S);
   begin
      Check_Map (M, 6);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (S, 16, 16) = 255,
         "eigen preserves source");
   end Eigen;

   procedure Pre_Corner (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
      M : constant OpenCV.Core.Mat := IP.Pre_Corner_Response (S);
   begin
      Check_Map (M, 1);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (M, 3, 3) = 0.0,
         "flat pre-corner score is zero");
   end Pre_Corner;

   procedure Borders_And_Apertures (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
   begin
      for Border in
        OpenCV.Border_Kind range OpenCV.Constant_Border .. OpenCV.Reflect_101
      loop
         Check_Map
           (IP.Corner_Minimum_Eigenvalue
              (S, Aperture => IP.Aperture_5, Border => Border),
            1);
         Check_Map
           (IP.Pre_Corner_Response
              (S, Aperture => IP.Aperture_7, Border => Border),
            1);
      end loop;
   end Borders_And_Apertures;

   procedure Region_Local (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (40, 40, (OpenCV.Core.UInt8, 1));
      R        : OpenCV.Core.Mat;
      Snapshot : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 240.0));
      R := Parent.Region ((X => 4, Y => 4, Width => 32, Height => 32));
      OpenCV.Core.Set_To (R, (others => 0.0));
      Snapshot := R.Clone;
      AUnit.Assertions.Assert
        (OpenCV.Core.Norm
           (OpenCV.Core.Abs_Diff
              (IP.Corner_Minimum_Eigenvalue (R),
               IP.Corner_Minimum_Eigenvalue (Snapshot)),
            OpenCV.Core.Infinity)
         = 0.0,
         "Region borders exclude parent pixels");
      AUnit.Assertions.Assert
        (OpenCV.Core.Norm
           (IP.Corner_Minimum_Eigenvalue (R), OpenCV.Core.Infinity)
         = 0.0,
         "constant Region remains flat despite bright parent");
   end Region_Local;

   procedure Other_Regions (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (40, 40, (OpenCV.Core.UInt8, 1));
      R      : OpenCV.Core.Mat;
      Clone  : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 255.0));
      R := Parent.Region ((X => 4, Y => 4, Width => 32, Height => 32));
      OpenCV.Core.Set_To (R, (others => 0.0));
      Clone := R.Clone;
      AUnit.Assertions.Assert
        (OpenCV.Core.Norm
           (OpenCV.Core.Abs_Diff
              (IP.Harris_Corner_Response (R),
               IP.Harris_Corner_Response (Clone)),
            OpenCV.Core.Infinity)
         = 0.0,
         "Harris Region equals independent clone");
      AUnit.Assertions.Assert
        (OpenCV.Core.Norm
           (OpenCV.Core.Abs_Diff
              (IP.Corner_Eigenvalues_And_Vectors (R),
               IP.Corner_Eigenvalues_And_Vectors (Clone)),
            OpenCV.Core.Infinity)
         = 0.0,
         "eigen Region equals independent clone");
      AUnit.Assertions.Assert
        (OpenCV.Core.Norm
           (OpenCV.Core.Abs_Diff
              (IP.Pre_Corner_Response (R), IP.Pre_Corner_Response (Clone)),
            OpenCV.Core.Infinity)
         = 0.0,
         "pre-corner Region equals independent clone");
   end Other_Regions;

   procedure Eigen_Values (T : in out Fixture) is
      pragma Unreferenced (T);
      M : constant OpenCV.Core.Mat :=
        IP.Corner_Eigenvalues_And_Vectors (Scene);
      --  Core's Vec4 access is not applicable to the six-channel layout;
      --  verify a finite response with the norm of the returned C6 Mat.
   begin
      AUnit.Assertions.Assert
        (OpenCV.Core.Norm (M, OpenCV.Core.Infinity) > 0.0,
         "eigenvalues are nontrivial on the synthetic corner");
   end Eigen_Values;

   procedure Pre_Corner_Nontrivial (T : in out Fixture) is
      pragma Unreferenced (T);
      M : constant OpenCV.Core.Mat := IP.Pre_Corner_Response (Scene (True));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Core.Norm (M, OpenCV.Core.Infinity) > 0.0,
         "pre-corner response is nontrivial near the corner");
   end Pre_Corner_Nontrivial;

   procedure Map_Rejections (T : in out Fixture) is
      pragma Unreferenced (T);
      Bad   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (32, 32, (OpenCV.Core.UInt16, 1));
      Multi : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (32, 32, (OpenCV.Core.UInt8, 3));
      S     : constant OpenCV.Core.Mat := Scene;
      E     : OpenCV.Core.Mat;
      pragma Unreferenced (E);
      procedure Depth is
      begin
         E := IP.Corner_Minimum_Eigenvalue (Bad);
      end Depth;
      procedure Channels is
      begin
         E := IP.Harris_Corner_Response (Multi);
      end Channels;
      procedure Block is
      begin
         E := IP.Corner_Eigenvalues_And_Vectors (S, Block_Size => 1);
      end Block;
      procedure Border is
      begin
         E := IP.Pre_Corner_Response (S, Border => OpenCV.Wrap);
      end Border;
      procedure Nonfinite is
      begin
         E :=
           IP.Harris_Corner_Response
             (S, K => Bits_To_Double (16#7FF0_0000_0000_0000#));
      end Nonfinite;
   begin
      Must_Reject (Depth'Access);
      Must_Reject (Channels'Access);
      Must_Reject (Block'Access);
      Must_Reject (Border'Access);
      Must_Reject (Nonfinite'Access);
   end Map_Rejections;

   procedure Raw_Invalid (T : in out Fixture) is
      pragma Unreferenced (T);
      S      : constant OpenCV.Core.Mat := Scene;
      D      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Status : C_API.Status;
      procedure Input (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Output (O : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status := C_API.Corner_Response (H, O, 99, 3, 3, 0.04, 3);
            AUnit.Assertions.Assert
              (Status = C_API.Error_Invalid_Argument, "raw mode rejected");
            Status := C_API.Corner_Response (H, O, 1, 3, 3, 0.04, 99);
            AUnit.Assertions.Assert
              (Status = C_API.Error_Invalid_Argument, "raw border rejected");
            Status := C_API.Corner_Response (H, O, 1, 3, 99, 0.04, 3);
            AUnit.Assertions.Assert
              (Status = C_API.Error_Invalid_Argument, "raw aperture rejected");
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (D, Output'Access);
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (S, Input'Access);
      AUnit.Assertions.Assert
        (D.Rows = 2 and then D.Columns = 2,
         "malformed ABI leaves output unchanged");
   end Raw_Invalid;

   procedure Subpixel (T : in out Fixture) is
      pragma Unreferenced (T);
      S       : constant OpenCV.Core.Mat := Scene;
      Initial : constant IP.Corner_Point_Array (7 .. 8) :=
        (7 => (X => 15.2, Y => 15.3), 8 => (X => 0.0, Y => 0.0));
      R       : constant IP.Corner_Point_Array :=
        IP.Refine_Corners_Subpixel (S, Initial, (Width => 3, Height => 3));
   begin
      AUnit.Assertions.Assert
        (R'First = 7 and then R'Last = 8, "arbitrary bounds preserved");
      AUnit.Assertions.Assert
        (abs (R (7).X - 15.5) < abs (Initial (7).X - 15.5)
         and then abs (R (7).Y - 15.5) < abs (Initial (7).Y - 15.5),
         "subpixel converges toward synthetic corner");
      AUnit.Assertions.Assert
        (Initial (7).X = 15.2
         and then OpenCV.Core.UInt8_Access.Get (S, 16, 16) = 255,
         "inputs preserved");
   end Subpixel;

   procedure Empty_And_Zero_Zone (T : in out Fixture) is
      pragma Unreferenced (T);
      S     : constant OpenCV.Core.Mat := Scene (True);
      Empty : constant IP.Corner_Point_Array (5 .. 4) :=
        (others => (0.0, 0.0));
      P     : constant IP.Corner_Point_Array (3 .. 3) := (3 => (15.1, 15.2));
      R     : constant IP.Corner_Point_Array :=
        IP.Refine_Corners_Subpixel
          (S,
           P,
           (3, 3),
           (Enabled => True, Half_Size => (0, 0)),
           (Maximum_Iterations => 50, Epsilon => 0.001));
   begin
      AUnit.Assertions.Assert
        (IP.Refine_Corners_Subpixel (S, Empty, (3, 3))'Length = 0,
         "empty array succeeds");
      AUnit.Assertions.Assert
        (R'First = 3 and then R (3).X >= 0.0, "Float32 source and zero zone");
   end Empty_And_Zero_Zone;

   procedure Point_Rejections (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
      R : IP.Corner_Point_Array (0 .. 0);
      P : IP.Corner_Point_Array (0 .. 0) := (0 => (0.0, 0.0));
      procedure Try is
      begin
         R := IP.Refine_Corners_Subpixel (S, P, (3, 3));
      end Try;
   begin
      for X of
        IP.Corner_Point_Array'
          ((-1.0, 0.0),
           (32.0, 0.0),
           (Bits_To_Float (16#7FC0_0000#), 0.0),
           (Bits_To_Float (16#7F80_0000#), 0.0))
      loop
         P (0) := X;
         Must_Reject (Try'Access);
      end loop;
      P (0) := (0.0, -1.0);
      Must_Reject (Try'Access);
      P (0) := (0.0, 32.0);
      Must_Reject (Try'Access);
      P (0) := (15.0, 15.0);
      Try;
      AUnit.Assertions.Assert (R (0).X >= 0.0, "recovery after rejection");
   end Point_Rejections;

   procedure Window_Rejections (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
      P : constant IP.Corner_Point_Array (0 .. 0) := (0 => (15.0, 15.0));
      R : IP.Corner_Point_Array (0 .. 0);
      pragma Unreferenced (R);
      procedure Zero is
      begin
         R := IP.Refine_Corners_Subpixel (S, P, (0, 3));
      end Zero;
      procedure Huge is
      begin
         R :=
           IP.Refine_Corners_Subpixel (S, P, (OpenCV.Size_Coordinate'Last, 3));
      end Huge;
      procedure Zone is
      begin
         R :=
           IP.Refine_Corners_Subpixel
             (S, P, (3, 3), (Enabled => True, Half_Size => (3, 0)));
      end Zone;
      procedure Epsilon is
      begin
         R :=
           IP.Refine_Corners_Subpixel
             (S,
              P,
              (3, 3),
              Termination => (Maximum_Iterations => 5, Epsilon => -1.0));
      end Epsilon;
   begin
      Must_Reject (Zero'Access);
      Must_Reject (Huge'Access);
      Must_Reject (Zone'Access);
      Must_Reject (Epsilon'Access);
   end Window_Rejections;

   procedure Subpixel_Region (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (40, 40, (OpenCV.Core.UInt8, 1));
      R      : OpenCV.Core.Mat;
      Copy   : OpenCV.Core.Mat;
      P      : constant IP.Corner_Point_Array (5 .. 5) := (5 => (0.0, 0.0));
   begin
      OpenCV.Core.Set_To (Parent, (others => 255.0));
      R := Parent.Region ((X => 4, Y => 4, Width => 32, Height => 32));
      OpenCV.Core.Set_To (R, (others => 0.0));
      Copy := R.Clone;
      AUnit.Assertions.Assert
        (IP.Refine_Corners_Subpixel (R, P, (3, 3)) (5).X
         = IP.Refine_Corners_Subpixel (Copy, P, (3, 3)) (5).X,
         "subpixel Region boundary excludes bright parent");
   end Subpixel_Region;

   procedure Subpixel_Raw (T : in out Fixture) is
      pragma Unreferenced (T);
      S         : constant OpenCV.Core.Mat := Scene;
      Points    : aliased C_API.Corner_Point := (15.0, 15.0);
      Out_Point : aliased C_API.Corner_Point := (90.0, 90.0);
      Status    : C_API.Status;
      procedure Input (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           C_API.Corner_Subpixel
             (H,
              Points'Access,
              1,
              Out_Point'Access,
              2_147_483_647,
              3,
              -1,
              -1,
              30,
              0.01);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "raw oversized window rejected");
         Status :=
           C_API.Corner_Subpixel
             (H, Points'Access, 1, Out_Point'Access, 3, 3, -1, -1, 30, 0.01);
         AUnit.Assertions.Assert
           (Status = C_API.Success, "raw recovery succeeds");
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (S, Input'Access);
      AUnit.Assertions.Assert
        (Out_Point.X < 90.0, "result only copied after successful call");
   end Subpixel_Raw;

   procedure Empty_Still_Validates (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
      P : constant IP.Corner_Point_Array (1 .. 0) := (others => (0.0, 0.0));
      R : IP.Corner_Point_Array (1 .. 0);
      pragma Unreferenced (R);
      procedure Attempt is
      begin
         R := IP.Refine_Corners_Subpixel (S, P, (0, 0));
      end Attempt;
   begin
      Must_Reject (Attempt'Access);
   end Empty_Still_Validates;

   procedure Check_Nonfinite_Subpixel_Source (Bits : Interfaces.Unsigned_32) is
      S     : OpenCV.Core.Mat := Scene (True);
      P     : constant IP.Corner_Point_Array (7 .. 7) :=
        (7 => (X => 15.2, Y => 15.3));
      Empty : constant IP.Corner_Point_Array (3 .. 2) :=
        (others => (0.0, 0.0));
      Value : constant OpenCV.Float32_Value := Bits_To_Float (Bits);
      procedure Attempt is
         R : constant IP.Corner_Point_Array :=
           IP.Refine_Corners_Subpixel (S, P, (3, 3));
         pragma Unreferenced (R);
      begin
         null;
      end Attempt;
      procedure Attempt_Empty is
         R : constant IP.Corner_Point_Array :=
           IP.Refine_Corners_Subpixel (S, Empty, (3, 3));
         pragma Unreferenced (R);
      begin
         null;
      end Attempt_Empty;
   begin
      OpenCV.Core.Float32_Access.Set (S, 16, 16, Value);
      Must_Reject (Attempt'Access);
      Must_Reject (Attempt_Empty'Access);
      AUnit.Assertions.Assert
        (P (7).X = 15.2 and then P (7).Y = 15.3,
         "nonfinite rejection preserves caller points");
      AUnit.Assertions.Assert
        (not (OpenCV.Core.Float32_Access.Get (S, 16, 16)
              = OpenCV.Core.Float32_Access.Get (S, 16, 16))
         or else OpenCV.Core.Float32_Access.Get (S, 16, 16)
                 > OpenCV.Float32_Value'Last,
         "nonfinite rejection preserves source sample");
      OpenCV.Core.Float32_Access.Set (S, 16, 16, 255.0);
      AUnit.Assertions.Assert
        (IP.Refine_Corners_Subpixel (S, P, (3, 3)) (7).X >= 0.0,
         "valid refinement succeeds after nonfinite rejection");
   end Check_Nonfinite_Subpixel_Source;

   procedure NaN_Subpixel_Source (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Check_Nonfinite_Subpixel_Source (16#7FC0_0000#);
   end NaN_Subpixel_Source;

   procedure Infinity_Subpixel_Source (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Check_Nonfinite_Subpixel_Source (16#7F80_0000#);
   end Infinity_Subpixel_Source;

   procedure Float_Subpixel_Region_Finiteness (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (40, 40, (OpenCV.Core.Float32, 1));
      R      : OpenCV.Core.Mat;
      P      : constant IP.Corner_Point_Array (5 .. 5) :=
        (5 => (X => 15.2, Y => 15.3));
      procedure Attempt is
         Result : constant IP.Corner_Point_Array :=
           IP.Refine_Corners_Subpixel (R, P, (3, 3));
         pragma Unreferenced (Result);
      begin
         null;
      end Attempt;
   begin
      OpenCV.Core.Set_To (Parent, (others => 0.0));
      R := Parent.Region ((X => 4, Y => 4, Width => 32, Height => 32));
      for Y in 0 .. 31 loop
         for X in 0 .. 31 loop
            OpenCV.Core.Float32_Access.Set
              (R, Y, X, (if Y >= 16 and then X >= 16 then 255.0 else 0.0));
         end loop;
      end loop;
      OpenCV.Core.Float32_Access.Set
        (Parent, 0, 0, Bits_To_Float (16#7FC0_0000#));
      OpenCV.Core.Float32_Access.Set
        (Parent, 39, 39, Bits_To_Float (16#7F80_0000#));
      AUnit.Assertions.Assert
        (IP.Refine_Corners_Subpixel (R, P, (3, 3)) (5).X >= 0.0,
         "finite Region ignores nonfinite parent pixels");
      OpenCV.Core.Float32_Access.Set
        (R, 16, 16, Bits_To_Float (16#7FC0_0000#));
      Must_Reject (Attempt'Access);
   end Float_Subpixel_Region_Finiteness;

   procedure Corner_Recover (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant OpenCV.Core.Mat := Scene;
      M : OpenCV.Core.Mat;
      procedure Attempt is
      begin
         M := IP.Corner_Minimum_Eigenvalue (S, Border => OpenCV.Wrap);
      end Attempt;
   begin
      Must_Reject (Attempt'Access);
      M := IP.Corner_Minimum_Eigenvalue (S);
      Check_Map (M, 1);
   end Corner_Recover;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Minimum corner on UInt8", Minimum_Corner'Access));
      Result.Add_Test
        (Caller.Create ("Minimum corner on Float32", Float_Minimum'Access));
      Result.Add_Test (Caller.Create ("Harris k and source", Harris'Access));
      Result.Add_Test (Caller.Create ("Eigen C6 geometry", Eigen'Access));
      Result.Add_Test
        (Caller.Create ("Pre-corner flat response", Pre_Corner'Access));
      Result.Add_Test
        (Caller.Create
           ("Corner borders and apertures", Borders_And_Apertures'Access));
      Result.Add_Test
        (Caller.Create ("Corner Region is isolated", Region_Local'Access));
      Result.Add_Test
        (Caller.Create
           ("Other corner maps isolate Regions", Other_Regions'Access));
      Result.Add_Test
        (Caller.Create ("Eigen response nontrivial", Eigen_Values'Access));
      Result.Add_Test
        (Caller.Create
           ("Pre-corner response nontrivial", Pre_Corner_Nontrivial'Access));
      Result.Add_Test
        (Caller.Create
           ("Corner public invalid arguments", Map_Rejections'Access));
      Result.Add_Test
        (Caller.Create ("Corner raw selectors", Raw_Invalid'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel converges and preserves inputs", Subpixel'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel empty and zero zone", Empty_And_Zero_Zone'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel rejects invalid points", Point_Rejections'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel rejects windows and criteria",
            Window_Rejections'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel Region isolates parent", Subpixel_Region'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel raw arithmetic and recovery", Subpixel_Raw'Access));
      Result.Add_Test
        (Caller.Create
           ("Empty subpixel still validates", Empty_Still_Validates'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel rejects NaN Float32 source",
            NaN_Subpixel_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel rejects infinity Float32 source",
            Infinity_Subpixel_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Subpixel Float32 Region finite scan is local",
            Float_Subpixel_Region_Finiteness'Access));
      Result.Add_Test
        (Caller.Create
           ("Corner map recovers after rejection", Corner_Recover'Access));
      return Result'Access;
   end Suite;
end Corner_Analysis_Tests;
