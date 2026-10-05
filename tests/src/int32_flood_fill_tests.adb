with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Int32_Access;
with OpenCV.Core.Int32_Vec3;
with OpenCV.Core.Int32_Vec3_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Int32_Flood_Fill_Tests is
   --  Deliberate nonfinite inputs exercise explicit public validation.
   pragma Suppress (Validity_Check);

   use AUnit.Assertions;
   use type OpenCV.Int32_Value;
   use type OpenCV.UInt8_Value;
   use type OpenCV.Rect;
   use type OpenCV.Core.Int32_Vec3.Vector;
   use type Interfaces.Integer_64;
   use type Interfaces.C.double;
   use type OpenCV.Core.Channel_Count;

   package IP renames OpenCV.Image_Processing;
   package I32 renames OpenCV.Core.Int32_Access;
   package V3 renames OpenCV.Core.Int32_Vec3_Access;
   package U8 renames OpenCV.Core.UInt8_Access;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;
   use type C_API.Rect_I32;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function To_Float is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, Long_Float);

   function Nonfinite (Bits : Interfaces.Unsigned_64) return Long_Float is
      pragma Suppress (Range_Check);
   begin
      return To_Float (Bits);
   end Nonfinite;

   function Gray (Value : Long_Float) return OpenCV.Scalar
   is ((Component_0 => Value, others => 0.0));

   function Image32
     (Rows, Columns : Positive; Channels : OpenCV.Core.Channel_Count := 1)
      return OpenCV.Core.Mat
   is
      Image : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Columns, (OpenCV.Core.Int32, Channels));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      return Image;
   end Image32;

   function Mask8 (Rows, Columns : Positive) return OpenCV.Core.Mat is
      Mask : OpenCV.Core.Mat :=
        OpenCV.Core.Create (Rows, Columns, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Mask, (others => 0.0));
      return Mask;
   end Mask8;

   procedure Basic_C1 (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Image32 (2, 3);
      Fill  : IP.Flood_Fill_Result;
   begin
      I32.Set (Image, 0, 2, 5);
      IP.Flood_Fill (Image, (0, 0), Gray (-23.0), Fill);
      Assert
        (Fill.Pixel_Count = 5 and then Fill.Bounds = (0, 0, 3, 2),
         "Int32 C1 area and bounds");
      Assert
        (I32.Get (Image, 1, 2) = -23 and then I32.Get (Image, 0, 2) = 5,
         "connected component mutated, other pixels preserved");
   end Basic_C1;

   procedure Basic_C3 (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Image32 (1, 3, 3);
      Fill  : IP.Flood_Fill_Result;
   begin
      V3.Set (Image, 0, 0, (-100, 200, 1_000_000_000));
      V3.Set (Image, 0, 1, (-100, 200, 1_000_000_000));
      V3.Set (Image, 0, 2, (-100, 201, 1_000_000_000));
      IP.Flood_Fill (Image, (0, 0), (-7.0, 19.0, 1_000_000_000.0, 0.0), Fill);
      Assert (Fill.Pixel_Count = 2, "each Int32 C3 channel participates");
      Assert
        (V3.Get (Image, 0, 1) = (-7, 19, 1_000_000_000)
         and then V3.Get (Image, 0, 2) = (-100, 201, 1_000_000_000),
         "distinct replacement channels and preserved boundary");
   end Basic_C3;

   procedure Check_Connectivity
     (Connectivity : IP.Pixel_Connectivity; Expected : Natural)
   is
      Image : OpenCV.Core.Mat := Image32 (3, 3);
      Fill  : IP.Flood_Fill_Result;
   begin
      for Index in 0 .. 2 loop
         I32.Set (Image, Index, Index, -4);
      end loop;
      IP.Flood_Fill
        (Image, (0, 0), Gray (8.0), Fill, Connectivity => Connectivity);
      Assert (Fill.Pixel_Count = Expected, "Int32 diagonal connectivity");
   end Check_Connectivity;

   procedure Four_Connected (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Connectivity (IP.Four_Connected, 1);
   end Four_Connected;

   procedure Eight_Connected (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Connectivity (IP.Eight_Connected, 3);
   end Eight_Connected;

   procedure Check_Range (Mode : IP.Flood_Fill_Range_Mode; Count : Natural) is
      Image : OpenCV.Core.Mat := Image32 (1, 5);
      Fill  : IP.Flood_Fill_Result;
   begin
      for Column in 0 .. 4 loop
         I32.Set (Image, 0, Column, OpenCV.Int32_Value (-10 + Column * 2));
      end loop;
      IP.Flood_Fill
        (Image,
         (2, 0),
         Gray (100.0),
         Fill,
         Lower_Difference => Gray (2.9),
         Upper_Difference => Gray (2.1),
         Range_Mode       => Mode);
      Assert (Fill.Pixel_Count = Count, "Int32 native floored range ramp");
   end Check_Range;

   procedure Floating_Range (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Range (IP.Floating_Range, 5);
   end Floating_Range;

   procedure Fixed_Range (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Range (IP.Fixed_Range, 3);
   end Fixed_Range;

   procedure Check_Difference (Lower, Upper : Long_Float; First : Integer) is
      Image : OpenCV.Core.Mat := Image32 (1, 3);
      Fill  : IP.Flood_Fill_Result;
   begin
      I32.Set (Image, 0, 0, -12);
      I32.Set (Image, 0, 1, -10);
      I32.Set (Image, 0, 2, -8);
      IP.Flood_Fill
        (Image, (1, 0), Gray (5.0), Fill, Gray (Lower), Gray (Upper));
      Assert
        (Fill.Pixel_Count = 2
         and then Fill.Bounds = (OpenCV.Point_Coordinate (First), 0, 2, 1),
         "asymmetric Int32 differences use native floor");
   end Check_Difference;

   procedure Lower_Difference (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Difference (2.75, 1.75, 0);
   end Lower_Difference;

   procedure Upper_Difference (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Difference (1.75, 2.75, 1);
   end Upper_Difference;

   procedure Check_Endpoint (Value, Replacement : OpenCV.Int32_Value) is
      Image : OpenCV.Core.Mat := Image32 (1, 3);
      Fill  : IP.Flood_Fill_Result;
   begin
      for Column in 0 .. 2 loop
         I32.Set (Image, 0, Column, Value);
      end loop;
      I32.Set (Image, 0, 2, Value + 1);
      IP.Flood_Fill (Image, (0, 0), Gray (Long_Float (Replacement)), Fill);
      Assert
        (Fill.Pixel_Count = 2
         and then I32.Get (Image, 0, 0) = Replacement
         and then I32.Get (Image, 0, 1) = Replacement
         and then I32.Get (Image, 0, 2) = Value + 1,
         "exact Int32 access checks endpoint samples and replacement");
   end Check_Endpoint;

   procedure Near_First (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Endpoint (OpenCV.Int32_Value'First, OpenCV.Int32_Value'Last);
   end Near_First;

   procedure Near_Last (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Endpoint (OpenCV.Int32_Value'Last - 1, OpenCV.Int32_Value'First);
   end Near_Last;

   procedure Fractional_Value (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Image32 (1, 2);
      Fill  : IP.Flood_Fill_Result;
   begin
      IP.Flood_Fill (Image, (0, 0), Gray (-12.75), Fill);
      Assert
        (Fill.Pixel_Count = 2 and then I32.Get (Image, 0, 1) = -13,
         "native non-tie fractional rounding, not Ada integral restriction");
   end Fractional_Value;

   procedure Region_And_Alias (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : OpenCV.Core.Mat := Image32 (4, 5);
      View   : OpenCV.Core.Mat := OpenCV.Core.Region (Parent, (1, 1, 3, 2));
      Alias  : constant OpenCV.Core.Mat := View;
      Fill   : IP.Flood_Fill_Result;
   begin
      --  Unsafe extrema outside the logical Region must not affect its scan.
      I32.Set (Parent, 0, 0, OpenCV.Int32_Value'First);
      I32.Set (Parent, 3, 4, OpenCV.Int32_Value'Last);
      IP.Flood_Fill (View, (0, 0), Gray (77.0), Fill);
      Assert
        (Fill.Pixel_Count = 6
         and then Fill.Bounds = (0, 0, 3, 2)
         and then I32.Get (Alias, 1, 2) = 77,
         "logical Region bounds and shallow alias mutation");
      for Row in 0 .. 3 loop
         for Column in 0 .. 4 loop
            if Row in 1 .. 2 and then Column in 1 .. 3 then
               Assert (I32.Get (Parent, Row, Column) = 77, "parent mutation");
            elsif Row = 0 and then Column = 0 then
               Assert
                 (I32.Get (Parent, Row, Column) = OpenCV.Int32_Value'First,
                  "outside minimum unchanged");
            elsif Row = 3 and then Column = 4 then
               Assert
                 (I32.Get (Parent, Row, Column) = OpenCV.Int32_Value'Last,
                  "outside maximum unchanged");
            else
               Assert (I32.Get (Parent, Row, Column) = 0, "parent isolation");
            end if;
         end loop;
      end loop;
   end Region_And_Alias;

   procedure Mask_Obstacle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Image32 (3, 4);
      Mask  : OpenCV.Core.Mat := Mask8 (5, 6);
      Fill  : IP.Flood_Fill_Result;
   begin
      for Row in 1 .. 3 loop
         U8.Set (Mask, Row, 3, 99);
      end loop;
      IP.Flood_Fill_With_Mask
        (Image, Mask, (0, 0), Gray (-5.0), Fill, Mask_Fill_Value => 213);
      Assert
        (Fill.Pixel_Count = 6 and then Fill.Bounds = (0, 0, 2, 3),
         "mask obstacle confines Int32 fill");
      Assert
        (I32.Get (Image, 2, 1) = -5
         and then I32.Get (Image, 2, 2) = 0
         and then U8.Get (Mask, 3, 2) = 213
         and then U8.Get (Mask, 3, 3) = 99
         and then U8.Get (Mask, 3, 4) = 0,
         "mask offset, fill value and obstacle preserved");
      for Row in 0 .. 4 loop
         for Column in 0 .. 5 loop
            if Row = 0 or else Row = 4 or else Column = 0 or else Column = 5
            then
               Assert (U8.Get (Mask, Row, Column) = 1, "native mask border");
            end if;
         end loop;
      end loop;
   end Mask_Obstacle;

   procedure Mask_Only (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Image32 (2, 2);
      Mask  : OpenCV.Core.Mat := Mask8 (4, 4);
      Fill  : IP.Flood_Fill_Result;
   begin
      I32.Set (Image, 0, 0, -5);
      IP.Flood_Fill_With_Mask
        (Image,
         Mask,
         (0, 0),
         Gray (Nonfinite (16#7FF0_0000_0000_0000#)),
         Fill,
         Upper_Difference => Gray (5.0),
         Mask_Fill_Value  => 42,
         Mask_Only        => True);
      Assert
        (Fill.Pixel_Count = 4
         and then I32.Get (Image, 0, 0) = -5
         and then I32.Get (Image, 1, 1) = 0
         and then U8.Get (Mask, 2, 2) = 42,
         "mask-only ignores nonfinite value and preserves Int32 samples");
   end Mask_Only;

   procedure Masked_C3 (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : constant OpenCV.Core.Mat := Image32 (4, 5, 3);
      Image  : OpenCV.Core.Mat := OpenCV.Core.Region (Parent, (1, 1, 3, 2));
      Mask   : OpenCV.Core.Mat := Mask8 (4, 5);
      Fill   : IP.Flood_Fill_Result;
   begin
      for Row in 0 .. 1 loop
         for Column in 0 .. 2 loop
            V3.Set (Image, Row, Column, (OpenCV.Int32_Value'First, 0, 17));
         end loop;
      end loop;
      U8.Set (Mask, 1, 3, 7);
      IP.Flood_Fill_With_Mask
        (Image, Mask, (0, 0), (1.0, 2.0, 3.0, 0.0), Fill);
      Assert
        (Fill.Pixel_Count = 5
         and then V3.Get (Image, 1, 2) = (1, 2, 3)
         and then V3.Get (Image, 0, 2) = (OpenCV.Int32_Value'First, 0, 17)
         and then V3.Get (Parent, 0, 0) = (0, 0, 0),
         "C3 strided fill checks spans separately, not across channels");
   end Masked_C3;

   procedure Check_Unsafe
     (Channels          : OpenCV.Core.Channel_Count;
      Masked, Only_Mask : Boolean;
      Mode              : IP.Flood_Fill_Range_Mode := IP.Floating_Range)
   is
      Image  : OpenCV.Core.Mat := Image32 (1, 2, Channels);
      Mask   : OpenCV.Core.Mat := Mask8 (3, 4);
      Fill   : IP.Flood_Fill_Result := (123, (1, 2, 3, 4));
      Raised : Boolean := False;
   begin
      if Channels = 1 then
         I32.Set (Image, 0, 0, OpenCV.Int32_Value'First);
         I32.Set (Image, 0, 1, OpenCV.Int32_Value'Last);
      else
         V3.Set (Image, 0, 0, (3, OpenCV.Int32_Value'First, -2));
         V3.Set (Image, 0, 1, (3, OpenCV.Int32_Value'Last, -2));
      end if;
      begin
         if Masked then
            IP.Flood_Fill_With_Mask
              (Image,
               Mask,
               (0, 0),
               Gray (9.0),
               Fill,
               Range_Mode => Mode,
               Mask_Only  => Only_Mask);
         else
            IP.Flood_Fill
              (Image, (0, 0), Gray (9.0), Fill, Range_Mode => Mode);
         end if;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      Assert (Raised, "unsafe signed sample subtraction rejected");
      --  The public out record is assigned only on success; no result is
      --  promised after an exception. Raw result zeroing is tested below.
      if Channels = 1 then
         Assert
           (I32.Get (Image, 0, 0) = OpenCV.Int32_Value'First
            and then I32.Get (Image, 0, 1) = OpenCV.Int32_Value'Last,
            "C1 rejected image unchanged");
      else
         Assert
           (V3.Get (Image, 0, 0) = (3, OpenCV.Int32_Value'First, -2)
            and then V3.Get (Image, 0, 1) = (3, OpenCV.Int32_Value'Last, -2),
            "C3 rejected image unchanged");
      end if;
      for Row in 0 .. 2 loop
         for Column in 0 .. 3 loop
            Assert (U8.Get (Mask, Row, Column) = 0, "mask/border unchanged");
         end loop;
      end loop;
      OpenCV.Core.Set_To (Image, (others => 0.0));
      IP.Flood_Fill (Image, (0, 0), Gray (9.0), Fill);
      Assert (Fill.Pixel_Count = 2, "recovery after span rejection");
   end Check_Unsafe;

   procedure Unsafe_C1 (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Unsafe (1, False, False);
   end Unsafe_C1;

   procedure Unsafe_C3 (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Unsafe (3, False, False);
   end Unsafe_C3;

   procedure Unsafe_Masked_C1 (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Unsafe (1, True, False);
   end Unsafe_Masked_C1;

   procedure Unsafe_Masked_C3 (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Unsafe (3, True, False, IP.Fixed_Range);
   end Unsafe_Masked_C3;

   procedure Unsafe_Mask_Only (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Check_Unsafe (1, True, True);
   end Unsafe_Mask_Only;

   procedure Span_Boundaries (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat := Image32 (1, 2);
      Fill   : IP.Flood_Fill_Result;
      Raised : Boolean := False;
   begin
      I32.Set (Image, 0, 0, OpenCV.Int32_Value'First);
      I32.Set (Image, 0, 1, -1);
      Assert
        (Interfaces.Integer_64 (I32.Get (Image, 0, 1))
         - Interfaces.Integer_64 (I32.Get (Image, 0, 0))
         = Interfaces.Integer_64 (OpenCV.Int32_Value'Last),
         "boundary expectation derived in widened exact arithmetic");
      IP.Flood_Fill
        (Image,
         (0, 0),
         Gray (7.0),
         Fill,
         Upper_Difference => Gray (Long_Float (OpenCV.Int32_Value'Last)));
      Assert
        (Fill.Pixel_Count = 2 and then I32.Get (Image, 0, 1) = 7,
         "span exactly INT_MAX accepted");
      I32.Set (Image, 0, 0, OpenCV.Int32_Value'First);
      I32.Set (Image, 0, 1, 0);
      Assert
        (Interfaces.Integer_64 (I32.Get (Image, 0, 1))
         - Interfaces.Integer_64 (I32.Get (Image, 0, 0))
         = Interfaces.Integer_64 (OpenCV.Int32_Value'Last) + 1,
         "just beyond boundary derived in widened exact arithmetic");
      begin
         IP.Flood_Fill (Image, (0, 0), Gray (7.0), Fill);
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      Assert
        (Raised
         and then I32.Get (Image, 0, 0) = OpenCV.Int32_Value'First
         and then I32.Get (Image, 0, 1) = 0,
         "span INT_MAX+1 rejected before mutation");
   end Span_Boundaries;

   procedure Scalar_Rejections (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Image32 (1, 2);
      Mask  : OpenCV.Core.Mat := Mask8 (3, 4);
      Fill  : IP.Flood_Fill_Result;

      procedure Reject
        (Value : Long_Float; Which : Natural; Masked : Boolean := False)
      is
         Raised    : Boolean := False;
         New_Value : constant OpenCV.Scalar :=
           (if Which = 0 then Gray (Value) else Gray (1.0));
         Lower     : constant OpenCV.Scalar :=
           (if Which = 1 then Gray (Value) else Gray (0.0));
         Upper     : constant OpenCV.Scalar :=
           (if Which = 2 then Gray (Value) else Gray (0.0));
      begin
         begin
            if Masked then
               IP.Flood_Fill_With_Mask
                 (Image, Mask, (0, 0), New_Value, Fill, Lower, Upper);
            else
               IP.Flood_Fill (Image, (0, 0), New_Value, Fill, Lower, Upper);
            end if;
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         Assert
           (Raised
            and then I32.Get (Image, 0, 0) = 0
            and then I32.Get (Image, 0, 1) = 0
            and then U8.Get (Mask, 0, 0) = 0,
            "invalid Int32 scalar rejected before image/mask mutation");
      end Reject;
   begin
      Reject (Long_Float (OpenCV.Int32_Value'First) - 0.25, 0);
      Reject (Long_Float (OpenCV.Int32_Value'Last) + 0.25, 0, True);
      for Which in 0 .. 2 loop
         Reject (Nonfinite (16#7FF8_0000_0000_0000#), Which);
         Reject (Nonfinite (16#7FF0_0000_0000_0000#), Which, True);
         Reject (Nonfinite (16#FFF0_0000_0000_0000#), Which);
      end loop;
      Reject (-0.1, 1);
      Reject (-0.1, 2);
      Reject (Long_Float (OpenCV.Int32_Value'Last) + 0.25, 1, True);
      Reject (Long_Float (OpenCV.Int32_Value'Last) + 0.25, 2);
      IP.Flood_Fill
        (Image,
         (0, 0),
         Gray (8.0),
         Fill,
         Lower_Difference => Gray (Long_Float (OpenCV.Int32_Value'Last)));
      Assert (Fill.Pixel_Count = 2, "recovery and maximum lower difference");
   end Scalar_Rejections;

   procedure Inactive_Components (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image : OpenCV.Core.Mat := Image32 (1, 2);
      Fill  : IP.Flood_Fill_Result;
      Bad   : constant Long_Float := Nonfinite (16#7FF8_0000_0000_0000#);
   begin
      IP.Flood_Fill
        (Image,
         (0, 0),
         (6.0, Bad, Bad, Bad),
         Fill,
         Lower_Difference => (0.0, -1.0, Bad, Bad),
         Upper_Difference => (0.0, Bad, -1.0, Bad));
      Assert
        (Fill.Pixel_Count = 2 and then I32.Get (Image, 0, 1) = 6,
         "inactive C1 Scalar components ignored");
   end Inactive_Components;

   procedure Raw_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image     : OpenCV.Core.Mat := Image32 (1, 2);
      Mask      : OpenCV.Core.Mat := Mask8 (3, 4);
      Value     : aliased C_API.Scalar4 := (Values => (others => 1.0));
      Low       : aliased C_API.Scalar4 := (Values => (others => 0.0));
      High      : aliased C_API.Scalar4 := (Values => (others => 0.0));
      Count     : aliased Interfaces.Integer_32 := -9;
      Bounds    : aliased C_API.Rect_I32 := (1, 2, 3, 4);
      Status    : C_API.Status;
      Only_Mask : Interfaces.Unsigned_8 := 0;

      procedure On_Image
        (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
         procedure On_Mask
           (Mask_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              C_API.Flood_Fill_Masked
                (Handle,
                 Mask_Handle,
                 0,
                 0,
                 Value'Access,
                 Low'Access,
                 High'Access,
                 4,
                 0,
                 1,
                 Only_Mask,
                 Count'Access,
                 Bounds'Access);
         end On_Mask;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Mask, On_Mask'Access);
      end On_Image;

      procedure Call (Expected : C_API.Status) is
      begin
         Count := -9;
         Bounds := (1, 2, 3, 4);
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Image, On_Image'Access);
         Assert (Status = Expected, "raw Int32 preflight status");
         if Expected /= C_API.Success then
            Assert
              (Count = 0
               and then Bounds = (0, 0, 0, 0)
               and then U8.Get (Mask, 0, 0) = 0
               and then U8.Get (Mask, 1, 1) = 0,
               "raw rejection zeroes outputs before native border writes");
         end if;
      end Call;
   begin
      I32.Set (Image, 0, 0, OpenCV.Int32_Value'First);
      I32.Set (Image, 0, 1, OpenCV.Int32_Value'Last);
      Call (C_API.Error_Invalid_Argument);
      Assert
        (I32.Get (Image, 0, 0) = OpenCV.Int32_Value'First
         and then I32.Get (Image, 0, 1) = OpenCV.Int32_Value'Last,
         "raw span rejection leaves image unchanged");
      OpenCV.Core.Set_To (Image, (others => 0.0));
      Value.Values (0) := 2_147_483_647.25;
      Call (C_API.Error_Invalid_Argument);
      Value.Values (0) := -2_147_483_648.25;
      Call (C_API.Error_Invalid_Argument);
      Value.Values (0) := 1.0;
      Low.Values (0) := 2_147_483_648.0;
      Call (C_API.Error_Invalid_Argument);
      Low.Values (0) := 0.0;
      High.Values (0) := 2_147_483_648.0;
      Call (C_API.Error_Invalid_Argument);
      High.Values (0) := 0.0;
      Value.Values (0) :=
        Interfaces.C.double (Nonfinite (16#7FF8_0000_0000_0000#));
      Call (C_API.Error_Invalid_Argument);
      Only_Mask := 1;
      Call (C_API.Success);
      Assert
        (Count = 2
         and then I32.Get (Image, 0, 0) = 0
         and then I32.Get (Image, 0, 1) = 0
         and then C_API.Last_Error_Message = "",
         "raw mask-only ignores NaN value and recovers");
   end Raw_Safety;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Routine : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create ("Int32 flood fill " & Name, Routine));
      end Add;
   begin
      Add ("C1 basic and negative values", Basic_C1'Access);
      Add ("C3 distinct channels and large positive", Basic_C3'Access);
      Add ("four connectivity", Four_Connected'Access);
      Add ("eight connectivity", Eight_Connected'Access);
      Add ("floating range", Floating_Range'Access);
      Add ("fixed range", Fixed_Range'Access);
      Add ("lower difference", Lower_Difference'Access);
      Add ("upper difference", Upper_Difference'Access);
      Add ("near first samples, last replacement", Near_First'Access);
      Add ("near last samples, first replacement", Near_Last'Access);
      Add ("fractional replacement", Fractional_Value'Access);
      Add ("Region and shallow alias", Region_And_Alias'Access);
      Add ("mask obstacle, border and fill value", Mask_Obstacle'Access);
      Add ("mask only ignores invalid replacement", Mask_Only'Access);
      Add ("masked C3 Region", Masked_C3'Access);
      Add ("unsafe C1 zero range", Unsafe_C1'Access);
      Add ("unsafe C3 zero range", Unsafe_C3'Access);
      Add ("unsafe masked C1", Unsafe_Masked_C1'Access);
      Add ("unsafe masked C3 fixed range", Unsafe_Masked_C3'Access);
      Add ("unsafe mask only", Unsafe_Mask_Only'Access);
      Add ("exact span boundaries", Span_Boundaries'Access);
      Add ("scalar conversion rejections", Scalar_Rejections'Access);
      Add ("inactive components", Inactive_Components'Access);
      Add ("raw ABI safety and recovery", Raw_Safety'Access);
      return Result'Access;
   end Suite;
end Int32_Flood_Fill_Tests;
