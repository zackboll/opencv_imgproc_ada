with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Linear_Blend_Tests is
   --  Intentional IEEE nonfinite samples test the explicit weight policy.
   pragma Suppress (Validity_Check);
   package C renames OpenCV.Core;
   package F renames C.Float32_Access;
   package U renames C.UInt8_Access;
   package IP renames OpenCV.Image_Processing;
   package Raw renames IP.Internal.C_API;
   use AUnit.Assertions;
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type OpenCV.Float32_Value;
   use type OpenCV.UInt8_Value;
   use type Raw.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function From_Bits is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_32, OpenCV.Float32_Value);

   function Image
     (Depth    : C.Depth_Type := C.Float32;
      Channels : C.Channel_Count := 1;
      Value    : Long_Float := 1.0;
      Rows     : Positive := 3;
      Columns  : Positive := 67) return C.Mat
   is
      M     : C.Mat := C.Create (Rows, Columns, (Depth, Channels));
      Plane : C.Mat := C.Create (Rows, Columns, (Depth, 1));
   begin
      C.Set_To (Plane, (others => Value));
      --  OpenCV 5 represents at most 128 channels; Core's public subtype
      --  remains 1..512. Exercise the actual Core Mat, not an invented type.
      for Channel in 0 .. Natural (M.Channels) - 1 loop
         M.Insert_Channel (Plane, Channel);
      end loop;
      return M;
   end Image;

   procedure Check
     (M : C.Mat; Expected : Long_Float; Tolerance : Long_Float := 0.0001) is
   begin
      for Channel in 0 .. Natural (M.Channels) - 1 loop
         declare
            Plane : constant C.Mat := M.Extract_Channel (Channel);
         begin
            for R in 0 .. M.Rows - 1 loop
               for Col in 0 .. M.Columns - 1 loop
                  if M.Depth = C.UInt8 then
                     Assert
                       (U.Get (Plane, R, Col) = OpenCV.UInt8_Value (Expected),
                        "exact UInt8 channel/pixel");
                  else
                     Assert
                       (abs (Long_Float (F.Get (Plane, R, Col)) - Expected)
                        <= Tolerance,
                        "Float32 channel/pixel tolerance");
                  end if;
               end loop;
            end loop;
         end;
      end loop;
   end Check;

   generic
      Depth : C.Depth_Type;
      Channels : C.Channel_Count;
   procedure Equal_Weights (T : in out Fixture);
   procedure Equal_Weights (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant C.Mat := Image (Depth, Channels, 20.0);
      B : constant C.Mat := Image (Depth, Channels, 100.0);
      W : constant C.Mat := Image;
      D : C.Mat := IP.Blend_Linear (A, B, W, W);
   begin
      Assert
        (D.Depth = Depth
         and then D.Channels = A.Channels
         and then D.Rows = A.Rows
         and then D.Columns = A.Columns,
         "native output metadata");
      Assert
        (A.Channels = Channels
         or else (Channels = 512 and then A.Channels = 128),
         "exact-version native channel representation");
      Check (D, (if Depth = C.UInt8 then 60.0 else 120.0 / 2.00001));
      --  This also proves (1,1) is normalized, not the raw weighted sum.
      Check (A, 20.0);
      Check (B, 100.0);
      Check (W, 1.0);
      declare
         Plane : constant C.Mat := Image (Depth, Value => 7.0);
      begin
         for Channel in 0 .. Natural (D.Channels) - 1 loop
            D.Insert_Channel (Plane, Channel);
         end loop;
      end;
      Check (D, 7.0);
      Check (A, 20.0);
      Check (B, 100.0);
      Check (W, 1.0);
   end Equal_Weights;
   procedure U1 is new Equal_Weights (C.UInt8, 1);
   procedure U2 is new Equal_Weights (C.UInt8, 2);
   procedure U3 is new Equal_Weights (C.UInt8, 3);
   procedure U4 is new Equal_Weights (C.UInt8, 4);
   procedure U5 is new Equal_Weights (C.UInt8, 5);
   procedure U512 is new Equal_Weights (C.UInt8, 512);
   procedure F1 is new Equal_Weights (C.Float32, 1);
   procedure F2 is new Equal_Weights (C.Float32, 2);
   procedure F3 is new Equal_Weights (C.Float32, 3);
   procedure F4 is new Equal_Weights (C.Float32, 4);
   procedure F5 is new Equal_Weights (C.Float32, 5);
   procedure F512 is new Equal_Weights (C.Float32, 512);

   procedure Spatial (T : in out Fixture) is
      pragma Unreferenced (T);
      A      : constant C.Mat := Image (C.Float32, 3, 20.0);
      B      : constant C.Mat := Image (C.Float32, 3, 100.0);
      W1, W2 : C.Mat := Image;
      D      : C.Mat;
   begin
      for R in 0 .. W1.Rows - 1 loop
         for Col in 0 .. W1.Columns - 1 loop
            F.Set (W1, R, Col, OpenCV.Float32_Value (Col mod 3) / 2.0);
            F.Set (W2, R, Col, 0.25);
         end loop;
      end loop;
      D := IP.Blend_Linear (A, B, W1, W2);
      for Channel in 0 .. 2 loop
         declare
            Plane : constant C.Mat := D.Extract_Channel (Channel);
         begin
            for R in 0 .. D.Rows - 1 loop
               for Col in 0 .. D.Columns - 1 loop
                  declare
                     Weight   : constant Long_Float :=
                       Long_Float (Col mod 3) / 2.0;
                     Expected : constant Long_Float :=
                       (20.0 * Weight + 25.0) / (Weight + 0.25001);
                  begin
                     Assert
                       (abs (Long_Float (F.Get (Plane, R, Col)) - Expected)
                        < 0.0001,
                        "spatial/unequal weight shared by channels");
                     Assert
                       (F.Get (W1, R, Col) = OpenCV.Float32_Value (Weight)
                        and then F.Get (W2, R, Col) = 0.25,
                        "both weight maps preserved");
                  end;
               end loop;
            end loop;
         end;
      end loop;
   end Spatial;

   generic
      Depth : C.Depth_Type;
   procedure Zero (T : in out Fixture);
   procedure Zero (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant C.Mat := Image (Depth, 3, 255.0);
      W : constant C.Mat := Image (Value => 0.0);
      D : constant C.Mat := IP.Blend_Linear (A, A, W, W);
   begin
      Check (D, 0.0, 0.0);
   end Zero;
   procedure Zero_U8 is new Zero (C.UInt8);
   procedure Zero_F32 is new Zero (C.Float32);

   procedure Epsilon (T : in out Fixture) is
      pragma Unreferenced (T);
      A  : constant C.Mat := Image (Value => 100.0);
      W1 : constant C.Mat := Image;
      W0 : constant C.Mat := Image (Value => 0.0);
      D  : constant C.Mat := IP.Blend_Linear (A, A, W1, W0);
   begin
      Check (D, 100.0 / 1.00001, 0.00003);
      Assert (F.Get (D, 0, 0) < 100.0, "(1,0) is not identity");
   end Epsilon;

   procedure Regions (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent : constant C.Mat :=
        Image (Value => 100.0, Rows => 5, Columns => 72);
      WP     : constant C.Mat :=
        Image (Value => 2.0, Rows => 5, Columns => 72);
      A      : C.Mat := Parent.Region ((1, 1, 67, 3));
      B      : constant C.Mat := Parent.Region ((2, 1, 67, 3));
      W      : C.Mat := WP.Region ((1, 1, 67, 3));
      D      : C.Mat;
   begin
      C.Set_To (W, (others => 1.0));
      C.Set_To (A, (others => 20.0));
      Assert
        (not A.Is_Continuous and then not W.Is_Continuous,
         "original strides retained");
      D := IP.Blend_Linear (A, B, W, W);
      Assert (D.Rows = 3 and then D.Columns = 67, "logical Region size");
      for R in 0 .. 2 loop
         for Col in 0 .. 66 loop
            Assert
              (abs (F.Get (D, R, Col) - (if Col = 66 then 60.0 else 20.0))
               < 0.001,
               "overlapping sources use logical pixels only");
         end loop;
      end loop;
      Assert
        (F.Get (Parent, 0, 0) = 100.0
         and then F.Get (Parent, 1, 1) = 20.0
         and then F.Get (WP, 0, 0) = 2.0
         and then F.Get (WP, 1, 1) = 1.0,
         "parent/Region preservation; outside invalid weights not scanned");
      C.Set_To (D, (others => 0.0));
      Assert (F.Get (Parent, 1, 1) = 20.0, "Region result independent");
   end Regions;

   procedure Shared (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant C.Mat := Image (Value => 0.5);
      D : constant C.Mat := IP.Blend_Linear (A, A, A, A);
   begin
      Check (D, 0.5 / 1.00001);
      Check (A, 0.5);
   end Shared;

   procedure IEEE_Sources (T : in out Fixture) is
      pragma Unreferenced (T);
      A : C.Mat := Image;
      W : constant C.Mat := Image;
      D : C.Mat;
   begin
      F.Set (A, 0, 0, From_Bits (16#7FC0_0000#));
      F.Set (A, 0, 1, From_Bits (16#7F80_0000#));
      F.Set (A, 0, 2, From_Bits (16#FF80_0000#));
      F.Set (A, 0, 3, OpenCV.Float32_Value'Last);
      D := IP.Blend_Linear (A, A, W, W);
      Assert (F.Get (D, 0, 0) /= F.Get (D, 0, 0), "NaN preserved natively");
      Assert
        (F.Get (D, 0, 1) > OpenCV.Float32_Value'Last,
         "positive infinity accepted");
      Assert
        (F.Get (D, 0, 2) < OpenCV.Float32_Value'First,
         "negative infinity accepted");
      Assert
        (F.Get (D, 0, 3) > OpenCV.Float32_Value'Last,
         "native intermediate overflow not prohibited");
   end IEEE_Sources;

   type Bad_Kind is
     (Empty_Source,
      Empty_Weight,
      ND_Source,
      ND_Weight,
      Source_Size,
      Source_Depth,
      Source_Channels,
      Unsupported_Depth,
      Weight_Depth,
      Weight_Channels,
      Weight_Size,
      NaN_Weight,
      Plus_Inf,
      Minus_Inf,
      Below_Zero,
      Above_One);
   generic
      Kind : Bad_Kind;
      Second_Weight : Boolean := False;
      Floating_Source : Boolean := False;
   procedure Invalid (T : in out Fixture);
   procedure Invalid (T : in out Fixture) is
      pragma Unreferenced (T);
      A, B   : C.Mat := Image (C.UInt8, Value => 20.0);
      W1, W2 : C.Mat := Image;
      Bad, D : C.Mat;
      Value  : OpenCV.Float32_Value := 0.0;
   begin
      if Floating_Source then
         A := Image (C.Float32, Value => 20.0);
         B := Image (C.Float32, Value => 100.0);
      end if;
      case Kind is
         when Empty_Source                                               =>
            A := Bad;

         when Empty_Weight                                               =>
            null;

         when ND_Source                                                  =>
            A := C.Create (C.Dimension_Array'(2, 3, 4), (C.UInt8, 1));

         when ND_Weight                                                  =>
            Bad := C.Create (C.Dimension_Array'(2, 3, 4), (C.Float32, 1));

         when Source_Size                                                =>
            B := Image (C.UInt8, Columns => 66);

         when Source_Depth                                               =>
            B := Image (C.Float32);

         when Source_Channels                                            =>
            B := Image (C.UInt8, 3);

         when Unsupported_Depth                                          =>
            A := Image (C.UInt16);
            B := Image (C.UInt16);

         when Weight_Depth                                               =>
            Bad := Image (C.UInt8);

         when Weight_Channels                                            =>
            Bad := Image (C.Float32, 3);

         when Weight_Size                                                =>
            Bad := Image (Rows => 2);

         when NaN_Weight | Plus_Inf | Minus_Inf | Below_Zero | Above_One =>
            case Kind is
               when NaN_Weight =>
                  Value := From_Bits (16#7FC0_0000#);

               when Plus_Inf   =>
                  Value := From_Bits (16#7F80_0000#);

               when Minus_Inf  =>
                  Value := From_Bits (16#FF80_0000#);

               when Below_Zero =>
                  Value := -0.01;

               when others     =>
                  Value := 1.01;
            end case;
            Bad := Image;
            --  Last logical sample catches scans that inspect just a prefix.
            F.Set (Bad, Bad.Rows - 1, Bad.Columns - 1, Value);
      end case;
      if Kind
         in Empty_Weight
          | ND_Weight
          | Weight_Depth
          | Weight_Channels
          | Weight_Size
          | NaN_Weight
          | Plus_Inf
          | Minus_Inf
          | Below_Zero
          | Above_One
      then
         if Second_Weight then
            W2 := Bad;
         else
            W1 := Bad;
         end if;
      end if;
      begin
         D := IP.Blend_Linear (A, B, W1, W2);
         Assert (False, "expected specific OpenCV_Error");
      exception
         when OpenCV.OpenCV_Error =>
            null;
      end;
      A := Image (C.UInt8, Value => 20.0);
      B := Image (C.UInt8, Value => 100.0);
      W1 := Image;
      W2 := Image;
      D := IP.Blend_Linear (A, B, W1, W2);
      Check (D, 60.0);
   end Invalid;
   procedure Bad_Empty_S is new Invalid (Empty_Source);
   procedure Bad_Empty_W is new Invalid (Empty_Weight);
   procedure Bad_ND_S is new Invalid (ND_Source);
   procedure Bad_ND_W is new Invalid (ND_Weight);
   procedure Bad_Size is new Invalid (Source_Size);
   procedure Bad_Depth is new Invalid (Source_Depth);
   procedure Bad_Channels is new Invalid (Source_Channels);
   procedure Bad_Unsupported is new Invalid (Unsupported_Depth);
   procedure Bad_W_Depth is new Invalid (Weight_Depth);
   procedure Bad_W_Channels is new Invalid (Weight_Channels);
   procedure Bad_W_Size is new Invalid (Weight_Size);
   procedure Bad_NaN is new Invalid (NaN_Weight);
   procedure Bad_Pinf is new Invalid (Plus_Inf);
   procedure Bad_Ninf is new Invalid (Minus_Inf);
   procedure Bad_Low is new Invalid (Below_Zero);
   procedure Bad_High is new Invalid (Above_One);
   procedure Bad_NaN_2 is new Invalid (NaN_Weight, True);
   procedure Bad_Pinf_2 is new Invalid (Plus_Inf, True);
   procedure Bad_Ninf_2 is new Invalid (Minus_Inf, True);
   procedure Bad_Low_2 is new Invalid (Below_Zero, True);
   procedure Bad_High_2 is new Invalid (Above_One, True);
   procedure Float_NaN is new Invalid (NaN_Weight, False, True);
   procedure Float_Pinf is new Invalid (Plus_Inf, False, True);
   procedure Float_Ninf is new Invalid (Minus_Inf, True, True);
   procedure Float_Low is new Invalid (Below_Zero, True, True);
   procedure Float_High is new Invalid (Above_One, False, True);

   procedure Channel_Values (T : in out Fixture) is
      pragma Unreferenced (T);
      A  : C.Mat := Image (C.UInt8, 4, 0.0);
      B  : C.Mat := Image (C.UInt8, 4, 0.0);
      W1 : constant C.Mat := Image (Value => 0.25);
      W2 : constant C.Mat := Image (Value => 0.75);
      D  : C.Mat;
   begin
      for Channel in 0 .. 3 loop
         declare
            P : constant C.Mat :=
              Image (C.UInt8, Value => Long_Float (Channel * 20));
            Q : constant C.Mat :=
              Image (C.UInt8, Value => Long_Float (80 + Channel * 20));
         begin
            A.Insert_Channel (P, Channel);
            B.Insert_Channel (Q, Channel);
         end;
      end loop;
      D := IP.Blend_Linear (A, B, W1, W2);
      for Channel in 0 .. 3 loop
         Check (D.Extract_Channel (Channel), Long_Float (60 + Channel * 20));
      end loop;
   end Channel_Values;

   procedure Lifetime (T : in out Fixture) is
      pragma Unreferenced (T);
      D : C.Mat;
   begin
      declare
         A : constant C.Mat := Image (C.UInt8, Value => 20.0);
         B : constant C.Mat := Image (C.UInt8, Value => 100.0);
         W : constant C.Mat := Image;
      begin
         D := IP.Blend_Linear (A, B, W, W);
      end;
      Check (D, 60.0);
   end Lifetime;

   procedure Raw_Atomic (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant C.Mat := Image (C.UInt8, Value => 20.0);
      W : C.Mat := Image;
      D : C.Mat := Image (C.UInt8, Value => 77.0);
      procedure Source (S : C.Module_Interop.Input_Mat_Handle) is
         procedure Weight (H : C.Module_Interop.Input_Mat_Handle) is
            procedure Output (O : C.Module_Interop.Output_Mat_Handle) is
            begin
               for Kind in NaN_Weight .. Above_One loop
                  case Kind is
                     when NaN_Weight =>
                        F.Set (W, 0, 0, From_Bits (16#7FC0_0000#));

                     when Plus_Inf   =>
                        F.Set (W, 0, 0, From_Bits (16#7F80_0000#));

                     when Minus_Inf  =>
                        F.Set (W, 0, 0, From_Bits (16#FF80_0000#));

                     when Below_Zero =>
                        F.Set (W, 0, 0, -1.0);

                     when others     =>
                        F.Set (W, 0, 0, 2.0);
                  end case;
                  Assert
                    (Raw.Blend_Linear (S, S, H, H, O)
                     = Raw.Error_Invalid_Argument,
                     "unsafe UInt8 raw weights rejected before conversion");
                  Check (D, 77.0);
                  Check (A, 20.0);
               end loop;
               F.Set (W, 0, 0, 1.0);
               Assert
                 (Raw.Blend_Linear (S, S, H, H, O) = Raw.Success,
                  "raw recovery publishes after complete success");
            end Output;
         begin
            C.Module_Interop.With_Output_Handle (D, Output'Access);
         end Weight;
      begin
         C.Module_Interop.With_Input_Handle (W, Weight'Access);
      end Source;
   begin
      C.Module_Interop.With_Input_Handle (A, Source'Access);
      Check (D, 20.0);
   end Raw_Atomic;

   procedure Raw_Float (T : in out Fixture) is
      pragma Unreferenced (T);
      A : constant C.Mat := Image (Value => 20.0);
      W : C.Mat := Image (Value => 2.0);
      D : C.Mat := Image (Value => 77.0);
      procedure Source (S : C.Module_Interop.Input_Mat_Handle) is
         procedure Weight (H : C.Module_Interop.Input_Mat_Handle) is
            procedure Output (O : C.Module_Interop.Output_Mat_Handle) is
            begin
               Assert
                 (Raw.Blend_Linear (S, S, H, H, O) = Raw.Success,
                  "Float32 raw [0,1] policy is not duplicated");
               Check (D, 80.0 / 4.00001);
               F.Set (W, 0, 0, From_Bits (16#7FC0_0000#));
               Assert
                 (Raw.Blend_Linear (S, S, H, H, O) = Raw.Success,
                  "Float32 raw NaN arithmetic is native");
               Assert
                 (F.Get (D, 0, 0) /= F.Get (D, 0, 0), "native NaN output");
            end Output;
         begin
            C.Module_Interop.With_Output_Handle (D, Output'Access);
         end Weight;
      begin
         C.Module_Interop.With_Input_Handle (W, Weight'Access);
      end Source;
   begin
      C.Module_Interop.With_Input_Handle (A, Source'Access);
      Check (A, 20.0);
   end Raw_Float;

   procedure Raw_Layouts (T : in out Fixture) is
      pragma Unreferenced (T);
      A      : constant C.Mat := Image (C.UInt8, Value => 20.0);
      W      : constant C.Mat := Image;
      D      : C.Mat := Image (C.UInt8, Value => 77.0);
      Bad    : C.Mat;
      Status : Raw.Status := Raw.Success;
      procedure Request (S1, S2, W1, W2 : C.Mat) is
         procedure First (H1 : C.Module_Interop.Input_Mat_Handle) is
            procedure Second (H2 : C.Module_Interop.Input_Mat_Handle) is
               procedure Weight1 (H3 : C.Module_Interop.Input_Mat_Handle) is
                  procedure Weight2 (H4 : C.Module_Interop.Input_Mat_Handle) is
                     procedure Output (H5 : C.Module_Interop.Output_Mat_Handle)
                     is
                     begin
                        Status := Raw.Blend_Linear (H1, H2, H3, H4, H5);
                     end Output;
                  begin
                     C.Module_Interop.With_Output_Handle (D, Output'Access);
                  end Weight2;
               begin
                  C.Module_Interop.With_Input_Handle (W2, Weight2'Access);
               end Weight1;
            begin
               C.Module_Interop.With_Input_Handle (W1, Weight1'Access);
            end Second;
         begin
            C.Module_Interop.With_Input_Handle (S2, Second'Access);
         end First;
      begin
         C.Module_Interop.With_Input_Handle (S1, First'Access);
         Check (D, 77.0);
      end Request;
   begin
      Bad := C.Create (C.Dimension_Array'(3, 67, 2), (C.UInt8, 1));
      Request (Bad, A, W, W);
      Assert
        (Status = Raw.Error_Invalid_Argument,
         "n-D source cannot publish uninitialized native result");
      Bad := C.Create (C.Dimension_Array'(3, 67, 2), (C.Float32, 1));
      Request (A, A, Bad, W);
      Assert
        (Status = Raw.Error_Invalid_Argument,
         "n-D UInt8 weights cannot bypass safety scan");
      Request (A, A, A, W);
      Assert
        (Status = Raw.Error_Invalid_Argument,
         "wrong weight layout cannot be scanned as float");
      Bad := Image (C.UInt8, Columns => 66);
      Request (A, Bad, W, W);
      Assert
        (Status = Raw.Error_OpenCV,
         "raw geometry policy belongs to native assertions");
      Bad := Image (C.Float32);
      Request (A, Bad, W, W);
      Assert
        (Status = Raw.Error_OpenCV,
         "raw source type policy belongs to native assertions");
   end Raw_Layouts;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Run : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create ("Linear blend " & Name, Run));
      end Add;
   begin
      Add ("UInt8 C1", U1'Access);
      Add ("UInt8 C2", U2'Access);
      Add ("UInt8 C3", U3'Access);
      Add ("UInt8 C4", U4'Access);
      Add ("UInt8 C5 scalar", U5'Access);
      Add ("UInt8 native maximum C512/C128", U512'Access);
      Add ("Float32 C1", F1'Access);
      Add ("Float32 C2", F2'Access);
      Add ("Float32 C3", F3'Access);
      Add ("Float32 C4", F4'Access);
      Add ("Float32 C5 scalar", F5'Access);
      Add ("Float32 native maximum C512/C128", F512'Access);
      Add ("Spatial unequal maps", Spatial'Access);
      Add ("Both zero UInt8", Zero_U8'Access);
      Add ("Both zero Float32", Zero_F32'Access);
      Add ("Native epsilon bias", Epsilon'Access);
      Add ("Strided overlapping Regions", Regions'Access);
      Add ("All inputs share storage", Shared'Access);
      Add ("IEEE source samples", IEEE_Sources'Access);
      Add ("Empty source", Bad_Empty_S'Access);
      Add ("Empty weight", Bad_Empty_W'Access);
      Add ("ND source", Bad_ND_S'Access);
      Add ("ND weight", Bad_ND_W'Access);
      Add ("Source geometry", Bad_Size'Access);
      Add ("Source depth", Bad_Depth'Access);
      Add ("Source channels", Bad_Channels'Access);
      Add ("Unsupported depth", Bad_Unsupported'Access);
      Add ("Weight depth", Bad_W_Depth'Access);
      Add ("Weight channels", Bad_W_Channels'Access);
      Add ("Weight geometry", Bad_W_Size'Access);
      Add ("Weight1 NaN", Bad_NaN'Access);
      Add ("Weight1 +Inf", Bad_Pinf'Access);
      Add ("Weight1 -Inf", Bad_Ninf'Access);
      Add ("Weight1 below zero", Bad_Low'Access);
      Add ("Weight1 above one", Bad_High'Access);
      Add ("Weight2 NaN", Bad_NaN_2'Access);
      Add ("Weight2 +Inf", Bad_Pinf_2'Access);
      Add ("Weight2 -Inf", Bad_Ninf_2'Access);
      Add ("Weight2 below zero", Bad_Low_2'Access);
      Add ("Weight2 above one", Bad_High_2'Access);
      Add ("Raw UInt8 safety/atomicity", Raw_Atomic'Access);
      Add ("Float32 weight NaN", Float_NaN'Access);
      Add ("Float32 weight +Inf", Float_Pinf'Access);
      Add ("Float32 weight -Inf", Float_Ninf'Access);
      Add ("Float32 weight below zero", Float_Low'Access);
      Add ("Float32 weight above one", Float_High'Access);
      Add ("Distinct channel values", Channel_Values'Access);
      Add ("Result outlives inputs", Lifetime'Access);
      Add ("Raw Float32 native weights", Raw_Float'Access);
      Add ("Raw layouts and native error atomicity", Raw_Layouts'Access);
      return Result'Access;
   end Suite;
end Linear_Blend_Tests;
