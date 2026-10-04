with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Int16_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt16_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Resize_Linear_Exact_Tests is
   package IP renames OpenCV.Image_Processing;
   package Raw renames OpenCV.Image_Processing.Internal.C_API;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type Raw.Status;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;
   type Values is array (Positive range <>) of Integer;

   U8_Source    : constant Values := (3, 71, 199, 22, 117, 241);
   --  Independent derivation is in resize_exact_reference_test.cpp.
   U8_Expected  : constant Values :=
     (3, 30, 71, 148, 199, 13, 45, 94, 170, 220, 22, 60, 117, 192, 241);
   U16_Source   : constant Values :=
     (101, 12_003, 60_001, 903, 33_007, 65_003);
   U16_Expected : constant Values :=
     (101,
      4_862,
      12_003,
      40_802,
      60_001,
      502,
      9_303,
      22_505,
      46_503,
      62_502,
      903,
      13_744,
      33_007,
      52_205,
      65_003);
   I16_Source   : constant Values := (-301, -71, 199, -22, 117, 1_241);
   I16_Expected : constant Values :=
     (-301,
      -209,
      -71,
      91,
      199,
      -161,
      -88,
      23,
      441,
      720,
      -22,
      34,
      117,
      791,
      1_241);

   procedure Set (M : in out OpenCV.Core.Mat; R, C, V : Integer) is
   begin
      case M.Depth is
         when OpenCV.Core.UInt8  =>
            OpenCV.Core.UInt8_Access.Set (M, R, C, Interfaces.Unsigned_8 (V));

         when OpenCV.Core.UInt16 =>
            OpenCV.Core.UInt16_Access.Set
              (M, R, C, Interfaces.Unsigned_16 (V));

         when OpenCV.Core.Int16  =>
            OpenCV.Core.Int16_Access.Set (M, R, C, Interfaces.Integer_16 (V));

         when others             =>
            raise Program_Error;
      end case;
   end Set;

   function Get (M : OpenCV.Core.Mat; R, C : Integer) return Integer is
   begin
      case M.Depth is
         when OpenCV.Core.UInt8  =>
            return Integer (OpenCV.Core.UInt8_Access.Get (M, R, C));

         when OpenCV.Core.UInt16 =>
            return Integer (OpenCV.Core.UInt16_Access.Get (M, R, C));

         when OpenCV.Core.Int16  =>
            return Integer (OpenCV.Core.Int16_Access.Get (M, R, C));

         when others             =>
            raise Program_Error;
      end case;
   end Get;

   function Image
     (Depth : OpenCV.Core.Depth_Type; Data : Values) return OpenCV.Core.Mat
   is
      M : OpenCV.Core.Mat := OpenCV.Core.Create (2, 3, (Depth, 1));
   begin
      for R in 0 .. 1 loop
         for C in 0 .. 2 loop
            Set (M, R, C, Data (1 + R * 3 + C));
         end loop;
      end loop;
      return M;
   end Image;

   procedure Check (M : OpenCV.Core.Mat; Expected : Values) is
   begin
      AUnit.Assertions.Assert
        (M.Rows * M.Columns = Expected'Length, "expected geometry");
      for R in 0 .. M.Rows - 1 loop
         for C in 0 .. M.Columns - 1 loop
            AUnit.Assertions.Assert
              (Get (M, R, C) = Expected (1 + R * M.Columns + C),
               "fixed-point expected pixel" & R'Image & C'Image);
         end loop;
      end loop;
   end Check;

   procedure Reject (Attempt : not null access procedure) is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, "requires OpenCV_Error");
   end Reject;

   generic
      Depth : OpenCV.Core.Depth_Type;
      Source_Values, Expected : Values;
   procedure Integer_Reference (T : in out Fixture);

   procedure Integer_Reference (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat := Image (Depth, Source_Values);
      Output : OpenCV.Core.Mat;
   begin
      IP.Resize (Source, Output, (5, 3), IP.Linear_Exact);
      AUnit.Assertions.Assert
        (Output.Depth = Depth and then Output.Channels = 1,
         "exact preserves integer element type");
      Check (Output, Expected);
      Check (Source, Source_Values);
   end Integer_Reference;

   procedure UInt8_Reference is new
     Integer_Reference (OpenCV.Core.UInt8, U8_Source, U8_Expected);
   procedure UInt16_Reference is new
     Integer_Reference (OpenCV.Core.UInt16, U16_Source, U16_Expected);
   procedure Int16_Reference is new
     Integer_Reference (OpenCV.Core.Int16, I16_Source, I16_Expected);

   procedure Distinct_From_Linear (T : in out Fixture) is
      pragma Unreferenced (T);
      Source          : constant OpenCV.Core.Mat :=
        Image (OpenCV.Core.UInt8, U8_Source);
      Exact, Ordinary : OpenCV.Core.Mat;
   begin
      IP.Resize (Source, Exact, (5, 3), IP.Linear_Exact);
      IP.Resize (Source, Ordinary, (5, 3), IP.Linear);
      AUnit.Assertions.Assert
        (Get (Exact, 1, 3) = 170 and then Get (Ordinary, 1, 3) = 169,
         "selector must not map exact to ordinary Linear");
   end Distinct_From_Linear;

   procedure Channels (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      for Count in 1 .. 6 loop
         declare
            Planes : OpenCV.Core.Mat_Array (1 .. Count);
            Output : OpenCV.Core.Mat;
         begin
            for P of Planes loop
               P := Image (OpenCV.Core.UInt8, U8_Source);
            end loop;
            declare
               Source : constant OpenCV.Core.Mat := OpenCV.Core.Merge (Planes);
            begin
               IP.Resize (Source, Output, (5, 3), IP.Linear_Exact);
               AUnit.Assertions.Assert
                 (Output.Channels = OpenCV.Core.Channel_Count (Count),
                  "specialized and generic channels preserved");
               for P of OpenCV.Core.Split (Output) loop
                  Check (P, U8_Expected);
               end loop;
               for P of OpenCV.Core.Split (Source) loop
                  Check (P, U8_Source);
               end loop;
            end;
         end;
      end loop;
   end Channels;

   procedure Area_Redirect (T : in out Fixture) is
      pragma Unreferenced (T);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Exact, Area : OpenCV.Core.Mat;
   begin
      for R in 0 .. 3 loop
         for C in 0 .. 3 loop
            Set (Source, R, C, R * 29 + C * 7 + R * C);
         end loop;
      end loop;
      IP.Resize (Source, Exact, (2, 2), IP.Linear_Exact);
      IP.Resize (Source, Area, (2, 2), IP.Area);
      for R in 0 .. 1 loop
         for C in 0 .. 1 loop
            AUnit.Assertions.Assert
              (Get (Exact, R, C) = Get (Area, R, C), "2x Area equivalence");
         end loop;
      end loop;
   end Area_Redirect;

   procedure C2_Downsample (T : in out Fixture) is
      pragma Unreferenced (T);
      Plane       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Exact, Area : OpenCV.Core.Mat;
   begin
      --  Average 0.5 rounds up on exact C2, not Area's ties-to-even path.
      Plane.Set_To ((others => 0.0));
      Set (Plane, 1, 0, 1);
      Set (Plane, 1, 1, 1);
      declare
         Source : constant OpenCV.Core.Mat :=
           OpenCV.Core.Merge ((1 => Plane, 2 => Plane));
      begin
         IP.Resize (Source, Exact, (1, 1), IP.Linear_Exact);
         IP.Resize (Source, Area, (1, 1), IP.Area);
         for P of OpenCV.Core.Split (Exact) loop
            Check (P, (1 => 1));
         end loop;
         for P of OpenCV.Core.Split (Area) loop
            Check (P, (1 => 0));
         end loop;
      end;
   end C2_Downsample;

   generic
      Depth : OpenCV.Core.Depth_Type;
      Data : Values;
   procedure Same_Size (T : in out Fixture);

   procedure Same_Size (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat := Image (Depth, Data);
      Output : OpenCV.Core.Mat;
   begin
      IP.Resize (Source, Output, (3, 2), IP.Linear_Exact);
      Check (Output, Data);
      Check (Source, Data);
   end Same_Size;

   procedure UInt8_Copy is new Same_Size (OpenCV.Core.UInt8, U8_Source);
   procedure UInt16_Copy is new Same_Size (OpenCV.Core.UInt16, U16_Source);
   procedure Int16_Copy is new Same_Size (OpenCV.Core.Int16, I16_Source);

   procedure Region (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent         : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 7, (OpenCV.Core.UInt8, 1));
      Output, Packed : OpenCV.Core.Mat;
   begin
      Parent.Set_To ((others => 253.0));
      declare
         View : OpenCV.Core.Mat := Parent.Region ((2, 1, 3, 2));
      begin
         for R in 0 .. 1 loop
            for C in 0 .. 2 loop
               Set (View, R, C, U8_Source (1 + R * 3 + C));
            end loop;
         end loop;
         AUnit.Assertions.Assert (not View.Is_Continuous, "strided Region");
         IP.Resize (View, Output, (5, 3), IP.Linear_Exact);
         IP.Resize (View.Clone, Packed, (5, 3), IP.Linear_Exact);
         Check (Output, U8_Expected);
         Check (Packed, U8_Expected);
         Check (View, U8_Source);
         AUnit.Assertions.Assert
           (Get (Parent, 0, 0) = 253, "outside pixels unchanged");
      end;
   end Region;

   generic
      Depth : OpenCV.Core.Depth_Type;
   procedure Float_Rejection (T : in out Fixture);

   procedure Float_Rejection (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : OpenCV.Core.Mat := OpenCV.Core.Create (2, 3, (Depth, 1));
      Output : OpenCV.Core.Mat := Image (OpenCV.Core.UInt8, U8_Source);
      procedure Attempt is
      begin
         IP.Resize (Source, Output, (5, 3), IP.Linear_Exact);
      end Attempt;
   begin
      Source.Set_To ((others => 17.25));
      Reject (Attempt'Access);
      Check (Output, U8_Source);
      IP.Resize (Source, Output, (5, 3), IP.Linear);
      AUnit.Assertions.Assert (Output.Depth = Depth, "ordinary float Linear");
      if Depth = OpenCV.Core.Float32 then
         AUnit.Assertions.Assert
           (OpenCV.Core.Float32_Access.Get (Output, 1, 2) = 17.25,
            "Float32 Linear value");
      else
         AUnit.Assertions.Assert
           (OpenCV.Core.Float64_Access.Get (Output, 1, 2) = 17.25,
            "Float64 Linear value");
      end if;
   end Float_Rejection;

   procedure Float32_Rejection is new Float_Rejection (OpenCV.Core.Float32);
   procedure Float64_Rejection is new Float_Rejection (OpenCV.Core.Float64);

   function Zero_Map return OpenCV.Core.Mat is
      M : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));
   begin
      M.Set_To ((others => 0.0));
      return M;
   end Zero_Map;

   procedure Other_Operations (T : in out Fixture) is
      pragma Unreferenced (T);
      Source      : constant OpenCV.Core.Mat :=
        Image (OpenCV.Core.UInt8, U8_Source);
      Output      : OpenCV.Core.Mat := Source.Clone;
      X, Y        : constant OpenCV.Core.Mat := Zero_Map;
      XY          : constant OpenCV.Core.Mat :=
        OpenCV.Core.Merge ((1 => X, 2 => Y));
      Fixed       : constant IP.Fixed_Remap_Maps :=
        IP.Convert_Remap_To_Fixed (X, Y);
      Affine      : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));
      Perspective : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Float32, 1));
      procedure Separate_Maps is
      begin
         IP.Remap (Source, X, Y, Output, IP.Linear_Exact);
      end Separate_Maps;
      procedure Interleaved is
      begin
         IP.Remap (Source, XY, Output, IP.Linear_Exact);
      end Interleaved;
      procedure Encoded is
      begin
         IP.Remap (Source, Fixed, Output, IP.Linear_Exact);
      end Encoded;
      procedure Warp_Affine is
      begin
         IP.Warp_Affine (Source, Affine, Output, (3, 2), IP.Linear_Exact);
      end Warp_Affine;
      procedure Warp_Perspective is
      begin
         IP.Warp_Perspective
           (Source, Perspective, Output, (3, 2), IP.Linear_Exact);
      end Warp_Perspective;
      procedure Polar is
      begin
         IP.Warp_Polar
           (Source,
            Output,
            (1.0, 1.0),
            1.0,
            (3, 2),
            Interpolation => IP.Linear_Exact);
      end Polar;
   begin
      Reject (Separate_Maps'Access);
      Reject (Interleaved'Access);
      Reject (Encoded'Access);
      Reject (Warp_Affine'Access);
      Reject (Warp_Perspective'Access);
      Reject (Polar'Access);
      Check (Output, U8_Source);
   end Other_Operations;

   procedure Raw_Selectors (T : in out Fixture) is
      pragma Unreferenced (T);
      Source   : constant OpenCV.Core.Mat :=
        Image (OpenCV.Core.UInt8, U8_Source);
      Output   : OpenCV.Core.Mat := Source.Clone;
      Expected : OpenCV.Core.Mat;
      Status   : Raw.Status;
      Selector : Interfaces.Integer_32;
      procedure Input (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Dest (D : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status := Raw.Resize (H, D, 5, 3, Selector);
         end Dest;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Output, Dest'Access);
      end Input;
      procedure Call_Raw is
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      end Call_Raw;
   begin
      Selector := 6;
      Call_Raw;
      AUnit.Assertions.Assert
        (Status = Raw.Error_Invalid_Argument, "selector 6 rejected");
      Check (Output, U8_Source);
      Selector := 5;
      Call_Raw;
      AUnit.Assertions.Assert (Status = Raw.Success, "selector 5 succeeds");
      Check (Output, U8_Expected);
      for Method in IP.Nearest_Neighbor .. IP.Lanczos_4 loop
         Selector :=
           Interfaces.Integer_32 (IP.Interpolation_Method'Pos (Method));
         Call_Raw;
         AUnit.Assertions.Assert (Status = Raw.Success, "legacy raw selector");
         IP.Resize (Source, Expected, (5, 3), Method);
         for R in 0 .. 2 loop
            for C in 0 .. 4 loop
               AUnit.Assertions.Assert
                 (Get (Output, R, C) = Get (Expected, R, C),
                  "legacy selectors retain mapping");
            end loop;
         end loop;
      end loop;
      for Depth in OpenCV.Core.Float32 .. OpenCV.Core.Float64 loop
         declare
            Floating : OpenCV.Core.Mat :=
              OpenCV.Core.Create (2, 3, (Depth, 1));
            procedure Float_Input
              (H : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Dest
                 (D : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status := Raw.Resize (H, D, 5, 3, 5);
               end Dest;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Output, Dest'Access);
            end Float_Input;
         begin
            Floating.Set_To ((others => 17.25));
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Floating, Float_Input'Access);
            AUnit.Assertions.Assert
              (Status = Raw.Success and then Output.Depth = Depth,
               "raw float exact preserves native-safe fallback");
            if Depth = OpenCV.Core.Float32 then
               AUnit.Assertions.Assert
                 (OpenCV.Core.Float32_Access.Get (Output, 1, 2) = 17.25,
                  "raw Float32 fallback value");
            else
               AUnit.Assertions.Assert
                 (OpenCV.Core.Float64_Access.Get (Output, 1, 2) = 17.25,
                  "raw Float64 fallback value");
            end if;
         end;
      end loop;
   end Raw_Selectors;

   procedure Overflow_Atomicity (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat :=
        Image (OpenCV.Core.UInt8, U8_Source);
      Output : OpenCV.Core.Mat := Source.Clone;
      procedure Attempt is
      begin
         IP.Resize (Source, Output, (46_341, 46_341), IP.Linear_Exact);
      end Attempt;
   begin
      Reject (Attempt'Access);
      Check (Output, U8_Source);
      IP.Resize (Source, Output, (5, 3), IP.Linear_Exact);
      Check (Output, U8_Expected);
   end Overflow_Atomicity;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Test : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Test));
      end Add;
   begin
      Add ("Exact UInt8 independent bytes", UInt8_Reference'Access);
      Add ("Exact UInt16 rounded values", UInt16_Reference'Access);
      Add ("Exact Int16 signed rounding across zero", Int16_Reference'Access);
      Add ("Exact differs from ordinary Linear", Distinct_From_Linear'Access);
      Add ("Exact specialized C1..C4 and generic C5/C6", Channels'Access);
      Add ("Exact 2x Area redirect", Area_Redirect'Access);
      Add ("Exact C2 2x avoids nonexact Area", C2_Downsample'Access);
      Add ("Exact UInt8 same-size copy", UInt8_Copy'Access);
      Add ("Exact UInt16 same-size copy", UInt16_Copy'Access);
      Add ("Exact Int16 same-size copy", Int16_Copy'Access);
      Add ("Exact noncontiguous Region isolates parent", Region'Access);
      Add ("Exact Float32 rejected atomically", Float32_Rejection'Access);
      Add ("Exact Float64 rejected atomically", Float64_Rejection'Access);
      Add
        ("Exact rejected by all Remap and warp APIs", Other_Operations'Access);
      Add ("Exact raw selector and legacy mappings", Raw_Selectors'Access);
      Add ("Exact overflow preflight is atomic", Overflow_Atomicity'Access);
      return Result'Access;
   end Suite;
end Resize_Linear_Exact_Tests;
