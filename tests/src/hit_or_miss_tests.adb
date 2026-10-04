with AUnit.Assertions;
with Ada.Unchecked_Conversion;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with System;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Int8_Access;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Hit_Or_Miss_Tests is
   package C renames OpenCV.Core;
   package API renames OpenCV.Image_Processing.Internal.C_API;
   use OpenCV.Image_Processing;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_32;
   use type OpenCV.Border_Kind;
   use type OpenCV.Point_Coordinate;
   use type C.Channel_Count;
   use type C.Depth_Type;
   use type API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Binary (Rows, Cols : Positive; Data : String) return C.Mat is
      Image : C.Mat := C.Create (Rows, Cols, (C.UInt8, 1));
   begin
      for R in 0 .. Rows - 1 loop
         for X in 0 .. Cols - 1 loop
            C.UInt8_Access.Set
              (Image,
               R,
               X,
               (if Data (R * Cols + X + 1) = '1' then 255 else 0));
         end loop;
      end loop;
      return Image;
   end Binary;

   function Ternary (Rows, Cols : Positive; Data : String) return C.Mat is
      Kernel : C.Mat := C.Create (Rows, Cols, (C.Int8, 1));
   begin
      for R in 0 .. Rows - 1 loop
         for X in 0 .. Cols - 1 loop
            C.Int8_Access.Set
              (Kernel,
               R,
               X,
               (case Data (R * Cols + X + 1) is
                  when '+'    => 1,
                  when '-'    => -1,
                  when others => 0));
         end loop;
      end loop;
      return Kernel;
   end Ternary;

   procedure Equal (A, B : C.Mat; Label : String) is
   begin
      AUnit.Assertions.Assert
        (A.Rows = B.Rows
         and then A.Columns = B.Columns
         and then A.Depth = C.UInt8
         and then A.Channels = 1,
         Label);
      for R in 0 .. Integer (A.Rows) - 1 loop
         for X in 0 .. Integer (A.Columns) - 1 loop
            AUnit.Assertions.Assert
              (C.UInt8_Access.Get (A, R, X) = C.UInt8_Access.Get (B, R, X),
               Label & R'Image & X'Image);
         end loop;
      end loop;
   end Equal;

   procedure Expect (A : C.Mat; Data : String) is
      B : constant C.Mat := Binary (A.Rows, A.Columns, Data);
   begin
      Equal (A, B, "independent expected binary mask");
   end Expect;

   procedure Reject (Attempt : not null access procedure) is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, "expected OpenCV_Error");
   end Reject;

   procedure Tutorial (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S      : constant C.Mat :=
        Binary
          (8,
           8,
           "00000000"
           & "01110001"
           & "01110000"
           & "01110100"
           & "00100000"
           & "00100110"
           & "01010010"
           & "01110000");
      K      : constant C.Mat := Ternary (3, 3, "0+0+-+0+0");
      Before : constant C.Mat := S.Clone;
      D      : C.Mat := C.Create (1, 2, (C.Float32, 3));
   begin
      Hit_Or_Miss (S, D, K);
      --  Zero-based (row=6,column=2) has a background center and four hits.
      Expect
        (D,
         "00000000"
         & "00000000"
         & "00000000"
         & "00000000"
         & "00000000"
         & "00000000"
         & "00100000"
         & "00000000");
      Equal (S, Before, "distinct source preserved");
   end Tutorial;

   generic
      Miss : Boolean;
   procedure Singleton (Test : in out Fixture);
   procedure Singleton (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat := Binary (2, 4, "10100110");
      K : constant C.Mat := Ternary (1, 1, (if Miss then "-" else "+"));
      D : C.Mat;
   begin
      Hit_Or_Miss (S, D, K, Iterations => Morphology_Iterations'Last);
      Expect (D, (if Miss then "01011001" else "10100110"));
   end Singleton;
   procedure Hits is new Singleton (False);
   procedure Misses is new Singleton (True);

   procedure Dont_Care (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S    : C.Mat :=
        Binary
          (8,
           8,
           "00000000"
           & "01110001"
           & "01110000"
           & "01110100"
           & "00100000"
           & "00100110"
           & "01010010"
           & "01110000");
      K    : constant C.Mat := Ternary (3, 3, "0+0+-+0+0");
      A, B : C.Mat;
   begin
      Hit_Or_Miss (S, A, K);
      --  Change two don't-care corners under the tutorial's sole match.
      C.UInt8_Access.Set (S, 5, 1, 255);
      C.UInt8_Access.Set (S, 5, 3, 255);
      Hit_Or_Miss (S, B, K);
      Equal (A, B, "don't-care changes leave complete match mask unchanged");
   end Dont_Care;

   procedure Anchors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S    : constant C.Mat := Binary (1, 5, "01000");
      K    : constant C.Mat := Ternary (1, 3, "+-0");
      A, B : C.Mat;
   begin
      Hit_Or_Miss (S, A, K, Border => OpenCV.Replicate);
      Hit_Or_Miss (S, B, K, Anchor => (0, 0), Border => OpenCV.Replicate);
      Expect (A, "00100");
      Expect (B, "01000");
   end Anchors;

   procedure Even_Nonsquare (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S    : constant C.Mat := Binary (1, 5, "01000");
      K    : constant C.Mat := Ternary (1, 2, "+-");
      A, B : C.Mat;
   begin
      Hit_Or_Miss (S, A, K, Border => OpenCV.Replicate);
      Hit_Or_Miss (S, B, K, Anchor => (1, 0), Border => OpenCV.Replicate);
      Equal (A, B, "even width center is width/2");
      Expect (A, "00100");
   end Even_Nonsquare;

   generic
      Miss : Boolean;
   procedure Full_Iterations (Test : in out Fixture);
   procedure Full_Iterations (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat :=
        Binary (1, 7, (if Miss then "1000001" else "0111110"));
      K : constant C.Mat := Ternary (1, 3, (if Miss then "---" else "+++"));
      D : C.Mat;
   begin
      Hit_Or_Miss (S, D, K, Iterations => 2);
      Expect (D, "0001000");
   end Full_Iterations;
   procedure Hit_Iterations is new Full_Iterations (False);
   procedure Miss_Iterations is new Full_Iterations (True);

   procedure Mixed_Iterations (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat := Binary (1, 5, "01010");
      K : constant C.Mat := Ternary (1, 2, "+-");
      D : C.Mat;
   begin
      Hit_Or_Miss (S, D, K, Iterations => 2, Border => OpenCV.Replicate);
      --  Sparse hit leg samples x-2; sparse miss leg samples x.
      --  Repeating the whole transform twice would yield a different mask.
      Expect (D, "00000");
      Hit_Or_Miss (S, D, K, Iterations => 3, Border => OpenCV.Replicate);
      Expect (D, "00001");
   end Mixed_Iterations;

   procedure Source_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      P    : C.Mat := Binary (4, 7, "1111111111111111111111111111");
      S    : C.Mat := P.Region ((2, 1, 3, 2));
      K    : constant C.Mat := Ternary (1, 3, "+++");
      A, B : C.Mat;
   begin
      C.Set_To (S, (others => 0.0));
      C.UInt8_Access.Set (S, 0, 0, 255);
      AUnit.Assertions.Assert (not S.Is_Continuous, "source is strided");
      for Border in OpenCV.Border_Kind loop
         if Border /= OpenCV.Wrap then
            Hit_Or_Miss (S, A, K, Border => Border);
            Hit_Or_Miss (S.Clone, B, K, Border => Border);
            Equal (A, B, "source Region is isolated");
         end if;
      end loop;
      --  Nonbinary parent pixels outside the view are not Source pixels.
      C.UInt8_Access.Set (P, 0, 0, 127);
      Hit_Or_Miss (S, A, K);
      Hit_Or_Miss (S.Clone, B, K);
      Equal (A, B, "binary scan ignores parent outside Source Region");
   end Source_Region;

   procedure Kernel_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      P    : C.Mat := C.Create (5, 6, (C.Int8, 1));
      K    : C.Mat := P.Region ((2, 1, 3, 3));
      S    : constant C.Mat := Binary (3, 5, "000000100000000");
      A, B : C.Mat;
   begin
      --  Invalid values outside the logical kernel must not be inspected.
      C.Set_To (P, (127.0, others => 0.0));
      C.Set_To (K, (others => 0.0));
      C.Int8_Access.Set (K, 1, 0, 1);
      C.Int8_Access.Set (K, 1, 1, -1);
      AUnit.Assertions.Assert (not K.Is_Continuous, "kernel is strided");
      Hit_Or_Miss (S, A, K);
      Hit_Or_Miss (S, B, K.Clone);
      Equal (A, B, "strided kernel Region alone participates");
   end Kernel_Region;

   procedure In_Place (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : C.Mat := Binary (1, 5, "01000");
      K : constant C.Mat := Ternary (1, 3, "+-0");
   begin
      Hit_Or_Miss (S, S, K, Border => OpenCV.Replicate);
      Expect (S, "00100");
   end In_Place;

   procedure In_Place_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      P     : constant C.Mat := Binary (3, 7, "111111111111111111111");
      S     : C.Mat := P.Region ((1, 1, 5, 1));
      Input : constant C.Mat := Binary (1, 5, "01000");
      K     : constant C.Mat := Ternary (1, 3, "+-0");
   begin
      Input.Copy_To (S);
      Hit_Or_Miss (S, S, K, Border => OpenCV.Replicate);
      Expect (S, "00100");
      Expect (P, "1111111" & "1001001" & "1111111");
   end In_Place_Region;

   procedure Borders (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat := Binary (1, 3, "100");
      K : constant C.Mat := Ternary (1, 3, "+-0");
      D : C.Mat;
   begin
      Hit_Or_Miss (S, D, K, Border => OpenCV.Constant_Border);
      Expect (D, "010");
      Hit_Or_Miss (S, D, K, Border => OpenCV.Replicate);
      Expect (D, "010");
      Hit_Or_Miss (S, D, K, Border => OpenCV.Reflect);
      Expect (D, "010");
      Hit_Or_Miss (S, D, K, Border => OpenCV.Reflect_101);
      Expect (D, "010");
      --  A missing required hit is neutral under default constant erosion.
      declare
         Edge : constant C.Mat := Binary (1, 3, "000");
      begin
         Hit_Or_Miss (Edge, D, K);
         Expect (D, "100");
         Hit_Or_Miss (Edge, D, K, Border => OpenCV.Replicate);
         Expect (D, "000");
      end;
   end Borders;

   generic
      Value : OpenCV.UInt8_Value;
   procedure Nonbinary (Test : in out Fixture);
   procedure Nonbinary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : C.Mat := Binary (2, 3, "101010");
      K : constant C.Mat := Ternary (1, 1, "+");
      D : C.Mat := Binary (1, 2, "10");
      procedure Call is
      begin
         Hit_Or_Miss (S, D, K);
      end Call;
   begin
      C.UInt8_Access.Set (S, 1, 1, Value);
      Reject (Call'Access);
      AUnit.Assertions.Assert
        (C.UInt8_Access.Get (S, 1, 1) = Value, "source not normalized");
      Expect (D, "10");
   end Nonbinary;
   procedure Byte_1 is new Nonbinary (1);
   procedure Byte_127 is new Nonbinary (127);
   procedure Byte_254 is new Nonbinary (254);

   procedure Invalid_Ternary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S       : constant C.Mat := Binary (1, 3, "010");
      K       : C.Mat := Ternary (1, 2, "+0");
      D       : C.Mat := Binary (1, 2, "10");
      type Values is array (Positive range <>) of OpenCV.Int8_Value;
      Invalid : constant Values := (2, -2, 127, -128);
      procedure Call is
      begin
         Hit_Or_Miss (S, D, K);
      end Call;
   begin
      for V of Invalid loop
         C.Int8_Access.Set (K, 0, 1, V);
         Reject (Call'Access);
         Expect (D, "10");
      end loop;
   end Invalid_Ternary;

   procedure Zero_Kernel (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat := Binary (1, 3, "010");
      K : constant C.Mat := Ternary (2, 3, "000000");
      D : C.Mat;
      procedure Call is
      begin
         Hit_Or_Miss (S, D, K);
      end Call;
   begin
      Reject (Call'Access);
   end Zero_Kernel;

   generic
      Kernel_Test : Boolean;
   procedure Layouts (Test : in out Fixture);
   procedure Layouts (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S   : constant C.Mat := Binary (1, 3, "010");
      K   : constant C.Mat := Ternary (1, 1, "+");
      D   : C.Mat;
      Bad : C.Mat;
      procedure Call is
      begin
         if Kernel_Test then
            Hit_Or_Miss (S, D, Bad);
         else
            Hit_Or_Miss (Bad, D, K);
         end if;
      end Call;
   begin
      Reject (Call'Access);
      Bad :=
        C.Create
          (C.Dimension_Array'(2, 2, 2),
           ((if Kernel_Test then C.Int8 else C.UInt8), 1));
      Reject (Call'Access);
      for Depth in C.Depth_Type loop
         if Depth /= (if Kernel_Test then C.Int8 else C.UInt8) then
            Bad := C.Create (2, 2, (Depth, 1));
            Reject (Call'Access);
         end if;
      end loop;
      Bad := C.Create (2, 2, ((if Kernel_Test then C.Int8 else C.UInt8), 2));
      Reject (Call'Access);
   end Layouts;
   procedure Source_Layouts is new Layouts (False);
   procedure Kernel_Layouts is new Layouts (True);

   procedure Invalid_Geometry (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat := Binary (1, 3, "010");
      K : constant C.Mat := Ternary (1, 3, "+++");
      D : C.Mat;
      A : OpenCV.Point := (-1, 0);
      procedure Anchor_Call is
      begin
         Hit_Or_Miss (S, D, K, A);
      end Anchor_Call;
      procedure Wrap_Call is
      begin
         Hit_Or_Miss (S, D, K, Border => OpenCV.Wrap);
      end Wrap_Call;
      procedure Overflow_Call is
      begin
         Hit_Or_Miss (S, D, K, Iterations => 1_073_741_825);
      end Overflow_Call;
   begin
      Reject (Anchor_Call'Access);
      A := (3, 0);
      Reject (Anchor_Call'Access);
      A := (0, 1);
      Reject (Anchor_Call'Access);
      Reject (Wrap_Call'Access);
      Reject (Overflow_Call'Access);
   end Invalid_Geometry;

   procedure Kernel_Overlap (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S : constant C.Mat := Binary (1, 3, "010");
      K : C.Mat := Ternary (1, 3, "+-0");
      procedure Call is
      begin
         Hit_Or_Miss (S, K, K);
      end Call;
   begin
      Reject (Call'Access);
   end Kernel_Overlap;

   function Input_Handle is new
     Ada.Unchecked_Conversion
       (System.Address,
        C.Module_Interop.Input_Mat_Handle);
   function Output_Handle is new
     Ada.Unchecked_Conversion
       (System.Address,
        C.Module_Interop.Output_Mat_Handle);

   function Raw
     (S        : C.Mat;
      D        : in out C.Mat;
      K        : C.Mat;
      Selector : Interfaces.Integer_32 := 1;
      X        : Interfaces.Integer_32 := 0;
      N        : Interfaces.Integer_32 := 1;
      Border   : Interfaces.Integer_32 := API.Border_Constant;
      Nulls    : Natural := 0) return API.Status
   is
      Status : API.Status;
      procedure Input (SH : C.Module_Interop.Input_Mat_Handle) is
         procedure Mask (KH : C.Module_Interop.Input_Mat_Handle) is
            procedure Output (DH : C.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 API.Hit_Or_Miss
                   ((if Nulls = 1
                     then Input_Handle (System.Null_Address)
                     else SH),
                    (if Nulls = 2
                     then Output_Handle (System.Null_Address)
                     else DH),
                    (if Nulls = 3
                     then Input_Handle (System.Null_Address)
                     else KH),
                    Selector,
                    X,
                    0,
                    N,
                    Border);
            end Output;
         begin
            C.Module_Interop.With_Output_Handle (D, Output'Access);
         end Mask;
      begin
         C.Module_Interop.With_Input_Handle (K, Mask'Access);
      end Input;
   begin
      C.Module_Interop.With_Input_Handle (S, Input'Access);
      return Status;
   end Raw;

   procedure Raw_Atomicity (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S     : constant C.Mat := Binary (1, 3, "010");
      K     : constant C.Mat := Ternary (1, 3, "+++");
      D     : C.Mat := Binary (2, 2, "1001");
      Alias : constant C.Mat := D;
      Bad   : C.Mat;
      procedure Check (Status : API.Status) is
      begin
         AUnit.Assertions.Assert
           (Status = API.Error_Invalid_Argument, "raw safety rejection");
         AUnit.Assertions.Assert
           (D.Rows = 2
            and then D.Columns = 2
            and then D.Depth = C.UInt8
            and then D.Channels = 1,
            "preflight preserves metadata");
         Expect (D, "1001");
         --  Shallow alias observes writes iff the same storage was retained.
         C.UInt8_Access.Set (D, 0, 1, 255);
         AUnit.Assertions.Assert
           (C.UInt8_Access.Get (Alias, 0, 1) = 255,
            "storage identity retained");
         C.UInt8_Access.Set (D, 0, 1, 0);
      end Check;
   begin
      Check (Raw (S, D, K, Nulls => 1));
      Check (Raw (S, D, K, Nulls => 2));
      Check (Raw (S, D, K, Nulls => 3));
      Check (Raw (Bad, D, K));
      Check (Raw (S, D, Bad));
      Bad := C.Create (C.Dimension_Array'(2, 2, 2), (C.UInt8, 1));
      Check (Raw (Bad, D, K));
      Bad := C.Create (2, 2, (C.UInt8, 2));
      Check (Raw (Bad, D, K));
      Bad := C.Create (2, 2, (C.Int16, 1));
      Check (Raw (Bad, D, K));
      for Depth in C.Depth_Type loop
         if Depth /= C.Int8 then
            Bad := C.Create (2, 2, (Depth, 1));
            Check (Raw (S, D, Bad));
         end if;
      end loop;
      Bad := C.Create (C.Dimension_Array'(2, 2, 2), (C.Int8, 1));
      Check (Raw (S, D, Bad));
      Bad := C.Create (2, 2, (C.Int8, 2));
      Check (Raw (S, D, Bad));
      Check (Raw (S, D, K, Selector => 2));
      Check (Raw (S, D, K, X => -1));
      Check (Raw (S, D, K, X => 3));
      Check (Raw (S, D, K, N => 0));
      Check (Raw (S, D, K, N => -1));
      Check (Raw (S, D, K, Border => API.Border_Wrap));
      Check (Raw (S, D, K, Border => 99));
      Check (Raw (S, D, K, N => 1_073_741_825));
      declare
         Overlap : C.Mat := K.Clone;
      begin
         AUnit.Assertions.Assert
           (Raw (S, Overlap, Overlap) = API.Error_Invalid_Argument
            and then Overlap.Depth = C.Int8
            and then Overlap.Columns = 3
            and then C.Int8_Access.Get (Overlap, 0, 0) = 1,
            "raw kernel/destination overlap rejects before publication");
      end;
      AUnit.Assertions.Assert
        (Raw (S, D, Ternary (1, 1, "+")) = API.Success, "raw recovery");
      Equal (S, D, "valid recovery result");
   end Raw_Atomicity;

   procedure Raw_Semantics (Test : in out Fixture) is
      pragma Unreferenced (Test);
      S     : C.Mat := Binary (1, 3, "010");
      K     : C.Mat := Ternary (1, 1, "0");
      D     : C.Mat;
      Facts : aliased API.Hit_Or_Miss_Facts;
      procedure Inspect is
         Status : API.Status;
         procedure Input (SH : C.Module_Interop.Input_Mat_Handle) is
            procedure Mask (KH : C.Module_Interop.Input_Mat_Handle) is
            begin
               Status := API.Hit_Or_Miss_Inspect (SH, KH, Facts'Access);
            end Mask;
         begin
            C.Module_Interop.With_Input_Handle (K, Mask'Access);
         end Input;
      begin
         C.Module_Interop.With_Input_Handle (S, Input'Access);
         AUnit.Assertions.Assert (Status = API.Success, "facts inspection");
      end Inspect;
   begin
      AUnit.Assertions.Assert
        (Raw (S, D, K) = API.Success, "raw all-zero native copy allowed");
      Equal (S, D, "native zero-kernel copy");
      C.Int8_Access.Set (K, 0, 0, 2);
      AUnit.Assertions.Assert
        (Raw (S, D, K) = API.Success, "raw malformed safe ternary allowed");
      Expect (D, "111");
      C.Int8_Access.Set (K, 0, 0, 1);
      C.UInt8_Access.Set (S, 0, 1, 127);
      AUnit.Assertions.Assert
        (Raw (S, D, K) = API.Success
         and then C.UInt8_Access.Get (D, 0, 1) = 127
         and then C.UInt8_Access.Get (S, 0, 1) = 127,
         "raw nonbinary native singleton, without mutation/normalization");
      Inspect;
      AUnit.Assertions.Assert
        (Facts.Source_Binary = 0 and then Facts.All_Hits = 1,
         "nonbinary source is a fact; singleton hit is a full erosion mask");
      K := Ternary (1, 3, "+-+");
      Inspect;
      AUnit.Assertions.Assert
        (Facts.Kernel_Ternary = 1
         and then Facts.Has_Constraint = 1
         and then Facts.All_Hits = 0
         and then Facts.All_Misses = 0,
         "full-area mixed +/-1 is sparse in both native erosion legs");
   end Raw_Semantics;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Test : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create ("Hit-or-Miss " & Name, Test));
      end Add;
   begin
      Add ("tutorial independent match", Tutorial'Access);
      Add ("singleton hit", Hits'Access);
      Add ("singleton miss", Misses'Access);
      Add ("don't-care positions", Dont_Care'Access);
      Add ("off-center anchor shift", Anchors'Access);
      Add ("even nonsquare center", Even_Nonsquare'Access);
      Add ("full hit iterations", Hit_Iterations'Access);
      Add ("full miss iterations", Miss_Iterations'Access);
      Add ("mixed sparse leg iterations", Mixed_Iterations'Access);
      Add ("isolated source Region", Source_Region'Access);
      Add ("logical kernel Region", Kernel_Region'Access);
      Add ("direct in-place", In_Place'Access);
      Add ("parent-backed in-place", In_Place_Region'Access);
      Add ("edge border selectors", Borders'Access);
      Add ("reject source byte 1", Byte_1'Access);
      Add ("reject source byte 127", Byte_127'Access);
      Add ("reject source byte 254", Byte_254'Access);
      Add ("reject nonternary values", Invalid_Ternary'Access);
      Add ("reject all-don't-care", Zero_Kernel'Access);
      Add ("reject source layouts", Source_Layouts'Access);
      Add ("reject kernel layouts", Kernel_Layouts'Access);
      Add ("reject geometry and Wrap", Invalid_Geometry'Access);
      Add ("reject kernel overlap", Kernel_Overlap'Access);
      Add ("raw safety atomicity recovery", Raw_Atomicity'Access);
      Add ("raw native semantic boundary", Raw_Semantics'Access);
      return Result'Access;
   end Suite;
end Hit_Or_Miss_Tests;
