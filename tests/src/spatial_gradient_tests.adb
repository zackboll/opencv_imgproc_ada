with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Int16_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Spatial_Gradient_Tests is
   package C renames OpenCV.Core;
   package U renames C.UInt8_Access;
   package I renames C.Int16_Access;
   package IP renames OpenCV.Image_Processing;
   package Raw renames IP.Internal.C_API;
   package Bridge renames C.Module_Interop;
   use AUnit.Assertions;
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type OpenCV.Int16_Value;
   use type OpenCV.UInt8_Value;
   use type OpenCV.Border_Kind;
   use type Raw.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result         : aliased AUnit.Test_Suites.Test_Suite;
   Adapter_Result : aliased AUnit.Test_Suites.Test_Suite;

   type Pattern is
     (Horizontal,
      Vertical,
      Diagonal,
      Positive_Edge,
      Negative_Edge,
      Flat,
      Noise);

   function Image (Rows, Columns : Positive; Kind : Pattern) return C.Mat is
      M     : C.Mat := C.Create (Rows, Columns, (C.UInt8, 1));
      Value : Natural;
   begin
      for R in 0 .. Rows - 1 loop
         for Col in 0 .. Columns - 1 loop
            case Kind is
               when Horizontal                    =>
                  Value := Col * 10;

               when Vertical                      =>
                  Value := R * 10;

               when Diagonal                      =>
                  Value := (R + Col) * 10;

               when Positive_Edge | Negative_Edge =>
                  if (Columns = 1 and then R >= 2)
                    or else (Columns > 1 and then Col >= 2)
                  then
                     Value := 255;
                  else
                     Value := 0;
                  end if;
                  if Kind = Negative_Edge then
                     Value := 255 - Value;
                  end if;

               when Flat                          =>
                  Value := 71;

               when Noise                         =>
                  Value := (R * 79 + Col * 53 + 17) mod 256;
            end case;
            U.Set (M, R, Col, OpenCV.UInt8_Value (Value));
         end loop;
      end loop;
      return M;
   end Image;

   --  Independent test oracle: convolution by the documented Sobel kernels
   --  on the original logical image, never on a duplicated temporary.
   function Index
     (Position : Integer; Length : Positive; Border : OpenCV.Border_Kind)
      return Natural is
   begin
      if Length = 1 then
         return 0;
      elsif Position < 0 then
         return (if Border = OpenCV.Replicate then 0 else 1);
      elsif Position >= Length then
         return (if Border = OpenCV.Replicate then Length - 1 else Length - 2);
      else
         return Position;
      end if;
   end Index;

   procedure Check
     (Source : C.Mat;
      G      : IP.Spatial_Gradient_Result;
      Border : OpenCV.Border_Kind)
   is
      Smooth       : constant array (-1 .. 1) of Integer := (1, 2, 1);
      X, Y, Sample : Integer;
   begin
      Assert
        (G.X_Derivative.Rows = Source.Rows
         and then G.Y_Derivative.Rows = Source.Rows
         and then G.X_Derivative.Columns = Source.Columns
         and then G.Y_Derivative.Columns = Source.Columns
         and then G.X_Derivative.Depth = C.Int16
         and then G.Y_Derivative.Depth = C.Int16
         and then G.X_Derivative.Channels = 1
         and then G.Y_Derivative.Channels = 1,
         "both results have source geometry and Int16 C1 type");
      for R in 0 .. Source.Rows - 1 loop
         for Col in 0 .. Source.Columns - 1 loop
            X := 0;
            Y := 0;
            for DR in -1 .. 1 loop
               for DC in -1 .. 1 loop
                  Sample :=
                    Integer
                      (U.Get
                         (Source,
                          Index (R + DR, Source.Rows, Border),
                          Index (Col + DC, Source.Columns, Border)));
                  X := X + Sample * DC * Smooth (DR);
                  Y := Y + Sample * DR * Smooth (DC);
               end loop;
            end loop;
            Assert
              (I.Get (G.X_Derivative, R, Col) = OpenCV.Int16_Value (X),
               "exact X convolution including logical borders");
            Assert
              (I.Get (G.Y_Derivative, R, Col) = OpenCV.Int16_Value (Y),
               "exact Y convolution including logical borders");
            if Source.Columns = 1 then
               Assert
                 (I.Get (G.X_Derivative, R, Col) = 0,
                  "every adapter X pixel is exactly zero");
            end if;
         end loop;
      end loop;
   end Check;

   generic
      Rows, Columns : Positive;
      Kind : Pattern;
      Border : OpenCV.Border_Kind;
   procedure Exact (T : in out Fixture);
   procedure Exact (T : in out Fixture) is
      pragma Unreferenced (T);
      S : constant C.Mat := Image (Rows, Columns, Kind);
      G : constant IP.Spatial_Gradient_Result :=
        IP.Spatial_Gradient (S, Border);
   begin
      Check (S, G, Border);
      if Rows = 1 and then Columns = 1 then
         Assert
           (I.Get (G.X_Derivative, 0, 0) = 0
            and then I.Get (G.Y_Derivative, 0, 0) = 0,
            "1x1 has exactly zero derivatives for either supported border");
      end if;
      if Kind in Positive_Edge | Negative_Edge then
         if Columns = 1 then
            Assert
              (I.Get (G.Y_Derivative, 1, 0)
               = (if Kind = Positive_Edge then 1020 else -1020),
               "attainable one-column Y arithmetic endpoint");
         else
            Assert
              (I.Get (G.X_Derivative, 1, 1)
               = (if Kind = Positive_Edge then 1020 else -1020),
               "attainable direct X arithmetic endpoint");
         end if;
      end if;
   end Exact;
   procedure H is new Exact (5, 7, Horizontal, OpenCV.Reflect_101);
   procedure V is new Exact (5, 7, Vertical, OpenCV.Reflect_101);
   procedure D is new Exact (5, 7, Diagonal, OpenCV.Reflect_101);
   procedure Pos is new Exact (3, 3, Positive_Edge, OpenCV.Replicate);
   procedure Neg is new Exact (3, 3, Negative_Edge, OpenCV.Replicate);
   procedure F is new Exact (5, 7, Flat, OpenCV.Reflect_101);
   procedure BR is new Exact (7, 19, Noise, OpenCV.Reflect_101);
   procedure BP is new Exact (7, 19, Noise, OpenCV.Replicate);
   procedure R12 is new Exact (1, 2, Noise, OpenCV.Reflect_101);
   procedure P12 is new Exact (1, 2, Noise, OpenCV.Replicate);
   procedure R1N is new Exact (1, 19, Noise, OpenCV.Reflect_101);
   procedure P1N is new Exact (1, 19, Noise, OpenCV.Replicate);
   procedure R22 is new Exact (2, 2, Noise, OpenCV.Reflect_101);
   procedure P22 is new Exact (2, 2, Noise, OpenCV.Replicate);
   procedure R2N is new Exact (2, 19, Noise, OpenCV.Reflect_101);
   procedure P2N is new Exact (2, 19, Noise, OpenCV.Replicate);
   procedure RN2 is new Exact (7, 2, Noise, OpenCV.Reflect_101);
   procedure PN2 is new Exact (7, 2, Noise, OpenCV.Replicate);
   procedure R11 is new Exact (1, 1, Flat, OpenCV.Reflect_101);
   procedure P11 is new Exact (1, 1, Flat, OpenCV.Replicate);
   procedure R21 is new Exact (2, 1, Vertical, OpenCV.Reflect_101);
   procedure P21 is new Exact (2, 1, Vertical, OpenCV.Replicate);
   procedure RN1 is new Exact (7, 1, Vertical, OpenCV.Reflect_101);
   procedure PN1 is new Exact (7, 1, Vertical, OpenCV.Replicate);
   procedure APos is new Exact (3, 1, Positive_Edge, OpenCV.Reflect_101);
   procedure ANeg is new Exact (3, 1, Negative_Edge, OpenCV.Replicate);

   generic
      Width : Positive;
      Border : OpenCV.Border_Kind;
   procedure Region (T : in out Fixture);
   procedure Region (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent  : C.Mat := C.Create (7, Width + 2, (C.UInt8, 1));
      Logical : constant C.Mat :=
        Parent.Region ((1, 1, OpenCV.Size_Coordinate (Width), 5));
      Before  : C.Mat;
   begin
      for R in 0 .. 6 loop
         U.Set (Parent, R, 0, OpenCV.UInt8_Value (200 + R));
         U.Set (Parent, R, Width + 1, OpenCV.UInt8_Value (250 + R mod 6));
         for Col in 1 .. Width loop
            U.Set (Parent, R, Col, OpenCV.UInt8_Value ((R + 1) * 10));
         end loop;
      end loop;
      Before := Parent.Clone;
      Assert (not Logical.Is_Continuous, "Region retains parent row stride");
      Check (Logical, IP.Spatial_Gradient (Logical, Border), Border);
      for R in 0 .. 6 loop
         for Col in 0 .. Width + 1 loop
            Assert
              (U.Get (Parent, R, Col) = U.Get (Before, R, Col),
               "all parent pixels unchanged");
         end loop;
      end loop;
      --  Change surrounding pixels and recheck the same logical oracle.
      for R in 0 .. 6 loop
         U.Set (Parent, R, 0, 0);
         U.Set (Parent, R, Width + 1, 255);
      end loop;
      Check (Logical, IP.Spatial_Gradient (Logical, Border), Border);
   end Region;
   procedure RR is new Region (3, OpenCV.Reflect_101);
   procedure RP is new Region (3, OpenCV.Replicate);
   procedure AR is new Region (1, OpenCV.Reflect_101);
   procedure AP is new Region (1, OpenCV.Replicate);

   generic
      Width : Positive;
      Border : OpenCV.Border_Kind;
   procedure Equivalent (T : in out Fixture);
   procedure Equivalent (T : in out Fixture) is
      pragma Unreferenced (T);
      S    : constant C.Mat := Image (7, Width, Noise);
      G    : constant IP.Spatial_Gradient_Result :=
        IP.Spatial_Gradient (S, Border);
      X, Y : C.Mat;
   begin
      IP.Sobel (S, X, 1, 0, IP.Int16_Depth, IP.Kernel_3, 1.0, 0.0, Border);
      IP.Sobel (S, Y, 0, 1, IP.Int16_Depth, IP.Kernel_3, 1.0, 0.0, Border);
      for R in 0 .. S.Rows - 1 loop
         for Col in 0 .. S.Columns - 1 loop
            Assert
              (I.Get (X, R, Col) = I.Get (G.X_Derivative, R, Col)
               and then I.Get (Y, R, Col) = I.Get (G.Y_Derivative, R, Col),
               "exact equivalence to independent native Sobel calls");
         end loop;
      end loop;
      Check (S, G, Border);
   end Equivalent;
   procedure ER is new Equivalent (19, OpenCV.Reflect_101);
   procedure EP is new Equivalent (19, OpenCV.Replicate);
   procedure EAR is new Equivalent (1, OpenCV.Reflect_101);
   procedure EAP is new Equivalent (1, OpenCV.Replicate);

   generic
      Width : Positive;
   procedure Ownership (T : in out Fixture);
   procedure Ownership (T : in out Fixture) is
      pragma Unreferenced (T);
      G                  : IP.Spatial_Gradient_Result;
      Before_X, Before_Y : OpenCV.Int16_Value;
   begin
      declare
         S      : constant C.Mat := Image (5, Width, Noise);
         Before : constant C.Mat := S.Clone;
      begin
         G := IP.Spatial_Gradient (S);
         Check (S, G, OpenCV.Reflect_101);
         Before_Y := I.Get (G.Y_Derivative, 0, 0);
         I.Set (G.X_Derivative, 0, 0, 1234);
         Assert
           (I.Get (G.Y_Derivative, 0, 0) = Before_Y,
            "modifying X cannot affect Y");
         Before_X := I.Get (G.X_Derivative, 0, 0);
         I.Set (G.Y_Derivative, 0, 0, -1234);
         Assert
           (I.Get (G.X_Derivative, 0, 0) = Before_X,
            "modifying Y cannot affect X");
         for R in 0 .. S.Rows - 1 loop
            for Col in 0 .. S.Columns - 1 loop
               Assert
                 (U.Get (S, R, Col) = U.Get (Before, R, Col),
                  "source unchanged by computation and result mutation");
            end loop;
         end loop;
      end;
      Assert
        (I.Get (G.X_Derivative, 0, 0) = 1234
         and then I.Get (G.Y_Derivative, 0, 0) = -1234,
         "both results survive source finalization");
   end Ownership;
   procedure OD is new Ownership (7);
   procedure OA is new Ownership (1);

   type Invalid_Kind is
     (Empty, Float, Color, Wide, ND, Constant_B, Reflect_B, Wrap_B);
   generic
      Kind : Invalid_Kind;
   procedure Invalid (T : in out Fixture);
   procedure Invalid (T : in out Fixture) is
      pragma Unreferenced (T);
      S      : C.Mat;
      G      : IP.Spatial_Gradient_Result;
      Border : OpenCV.Border_Kind := OpenCV.Reflect_101;
      Raised : Boolean := False;
   begin
      case Kind is
         when Empty  =>
            null;

         when Float  =>
            S := C.Create (3, 3, (C.Float32, 1));

         when Color  =>
            S := C.Create (3, 3, (C.UInt8, 3));

         when Wide   =>
            S := C.Create (3, 3, (C.UInt16, 1));

         when ND     =>
            S := C.Create (C.Dimension_Array'(2, 3, 4), (C.UInt8, 1));

         when others =>
            S := Image (3, 3, Flat);
            Border :=
              (case Kind is
                 when Constant_B => OpenCV.Constant_Border,
                 when Reflect_B  => OpenCV.Reflect,
                 when others     => OpenCV.Wrap);
      end case;
      begin
         G := IP.Spatial_Gradient (S, Border);
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      Assert (Raised, "invalid public input raises specifically OpenCV_Error");
      Assert
        (G.X_Derivative.Is_Empty and then G.Y_Derivative.Is_Empty,
         "invalid public input publishes neither result");
   end Invalid;
   procedure IE is new Invalid (Empty);
   procedure IF32 is new Invalid (Float);
   procedure IC is new Invalid (Color);
   procedure IW is new Invalid (Wide);
   procedure IND is new Invalid (ND);
   procedure IB0 is new Invalid (Constant_B);
   procedure IB2 is new Invalid (Reflect_B);
   procedure IBW is new Invalid (Wrap_B);

   --  Test-only conversion permits exact source/output object identity;
   --  ordinary public operations cannot expose these private handles.
   function As_Output is new
     Ada.Unchecked_Conversion
       (Bridge.Input_Mat_Handle,
        Bridge.Output_Mat_Handle);
   type Raw_Kind is
     (Bad_Border,
      Bad_Type,
      Bad_ND,
      Same_Outputs,
      Source_X,
      Source_Y,
      Recovery,
      One_Column,
      Shared_Storage);
   generic
      Kind : Raw_Kind;
   procedure Raw_Test (T : in out Fixture);
   procedure Raw_Test (T : in out Fixture) is
      pragma Unreferenced (T);
      S      : C.Mat := Image (5, (if Kind = One_Column then 1 else 3), Noise);
      X      : C.Mat := C.Create (2, 2, (C.Int16, 1));
      Y      : C.Mat := C.Create (2, 2, (C.Int16, 1));
      Status : Raw.Status;
      procedure Input (H : Bridge.Input_Mat_Handle) is
         procedure X_Out (HX : Bridge.Output_Mat_Handle) is
            procedure Y_Out (HY : Bridge.Output_Mat_Handle) is
            begin
               Status :=
                 Raw.Spatial_Gradient
                   (H,
                    (if Kind in Bad_Border | Recovery then 99 else 3),
                    (if Kind = Source_X then As_Output (H) else HX),
                    (if Kind = Source_Y
                     then As_Output (H)
                     elsif Kind = Same_Outputs
                     then HX
                     else HY));
               if Kind = Recovery then
                  Assert
                    (Status = Raw.Error_Invalid_Argument,
                     "initial invalid call rejected");
                  Assert
                    (I.Get (X, 0, 0) = 77 and then I.Get (Y, 0, 0) = 88,
                     "failure preserves both existing outputs");
                  Status := Raw.Spatial_Gradient (H, 3, HX, HY);
               end if;
            end Y_Out;
         begin
            Bridge.With_Output_Handle (Y, Y_Out'Access);
         end X_Out;
      begin
         Bridge.With_Output_Handle (X, X_Out'Access);
      end Input;
   begin
      C.Set_To (X, (others => 77.0));
      C.Set_To (Y, (others => 88.0));
      if Kind = Bad_Type then
         S := C.Create (5, 1, (C.Float32, 1));
      elsif Kind = Bad_ND then
         S := C.Create (C.Dimension_Array'(2, 3, 4), (C.UInt8, 1));
      elsif Kind = Shared_Storage then
         Y := X;
      end if;
      Bridge.With_Input_Handle (S, Input'Access);
      if Kind in Recovery | One_Column | Shared_Storage then
         Assert (Status = Raw.Success, "valid raw call succeeds");
         Check (S, (X, Y), OpenCV.Reflect_101);
         I.Set (X, 0, 0, 1234);
         Assert
           (I.Get (Y, 0, 0) /= 1234, "raw output allocations independent");
      else
         Assert
           (Status = Raw.Error_Invalid_Argument,
            "raw unsafe arguments rejected");
         Assert
           (X.Rows = 2
            and then Y.Rows = 2
            and then X.Columns = 2
            and then Y.Columns = 2,
            "failure preserves both output geometries");
         for R in 0 .. 1 loop
            for Col in 0 .. 1 loop
               Assert
                 (I.Get (X, R, Col) = 77 and then I.Get (Y, R, Col) = 88,
                  "failure preserves every existing X/Y pixel");
            end loop;
         end loop;
         if Kind in Source_X | Source_Y | Same_Outputs then
            declare
               Before : constant C.Mat := Image (5, 3, Noise);
            begin
               for R in 0 .. 4 loop
                  for Col in 0 .. 2 loop
                     Assert
                       (U.Get (S, R, Col) = U.Get (Before, R, Col),
                        "raw identity rejection preserves source");
                  end loop;
               end loop;
            end;
         end if;
      end if;
   end Raw_Test;
   procedure RB is new Raw_Test (Bad_Border);
   procedure RT is new Raw_Test (Bad_Type);
   procedure RND is new Raw_Test (Bad_ND);
   procedure RXY is new Raw_Test (Same_Outputs);
   procedure RSX is new Raw_Test (Source_X);
   procedure RSY is new Raw_Test (Source_Y);
   procedure REC is new Raw_Test (Recovery);
   procedure RA is new Raw_Test (One_Column);
   procedure RSS is new Raw_Test (Shared_Storage);

   function Suite
     (Only_Adapter : Boolean := False)
      return AUnit.Test_Suites.Access_Test_Suite
   is
      procedure Add
        (Name : String; Run : Caller.Test_Method; Adapter : Boolean := False)
      is
      begin
         if not Only_Adapter or else Adapter then
            if Only_Adapter then
               Adapter_Result.Add_Test
                 (Caller.Create ("Spatial gradient " & Name, Run));
            else
               Result.Add_Test
                 (Caller.Create ("Spatial gradient " & Name, Run));
            end if;
         end if;
      end Add;
   begin
      Add ("horizontal ramp", H'Access);
      Add ("vertical ramp", V'Access);
      Add ("diagonal pattern", D'Access);
      Add ("+1020 X", Pos'Access);
      Add ("-1020 X", Neg'Access);
      Add ("flat", F'Access);
      Add ("Reflect_101 borders SIMD", BR'Access);
      Add ("Replicate borders SIMD", BP'Access);
      Add ("1x2 Reflect_101", R12'Access);
      Add ("1x2 Replicate", P12'Access);
      Add ("1xN Reflect_101", R1N'Access);
      Add ("1xN Replicate", P1N'Access);
      Add ("2x2 Reflect_101", R22'Access);
      Add ("2x2 Replicate", P22'Access);
      Add ("2xN Reflect_101", R2N'Access);
      Add ("2xN Replicate", P2N'Access);
      Add ("Nx2 Reflect_101", RN2'Access);
      Add ("Nx2 Replicate", PN2'Access);
      Add ("Region Reflect_101", RR'Access);
      Add ("Region Replicate", RP'Access);
      Add ("adapter 1x1 Reflect_101", R11'Access, True);
      Add ("adapter 1x1 Replicate", P11'Access, True);
      Add ("adapter 2x1 Reflect_101", R21'Access, True);
      Add ("adapter 2x1 Replicate", P21'Access, True);
      Add ("adapter Nx1 Reflect_101", RN1'Access, True);
      Add ("adapter Nx1 Replicate", PN1'Access, True);
      Add ("adapter +1020 Y", APos'Access, True);
      Add ("adapter -1020 Y", ANeg'Access, True);
      Add ("adapter Region Reflect_101", AR'Access, True);
      Add ("adapter Region Replicate", AP'Access, True);
      Add ("Sobel equivalent Reflect_101", ER'Access);
      Add ("Sobel equivalent Replicate", EP'Access);
      Add ("adapter Sobel equivalent Reflect_101", EAR'Access, True);
      Add ("adapter Sobel equivalent Replicate", EAP'Access, True);
      Add ("ownership", OD'Access);
      Add ("adapter ownership", OA'Access, True);
      Add ("reject empty", IE'Access);
      Add ("reject Float32", IF32'Access);
      Add ("reject UInt8 C3", IC'Access);
      Add ("reject UInt16", IW'Access);
      Add ("reject N-D", IND'Access);
      Add ("reject Constant", IB0'Access);
      Add ("reject Reflect", IB2'Access);
      Add ("reject Wrap", IBW'Access);
      Add ("raw border atomicity", RB'Access);
      Add ("raw type atomicity", RT'Access);
      Add ("raw N-D atomicity", RND'Access);
      Add ("raw same X/Y", RXY'Access);
      Add ("raw source X", RSX'Access);
      Add ("raw source Y", RSY'Access);
      Add ("raw recovery", REC'Access);
      Add ("adapter raw request", RA'Access, True);
      Add ("raw previously shared storage", RSS'Access);
      return (if Only_Adapter then Adapter_Result'Access else Result'Access);
   end Suite;
end Spatial_Gradient_Tests;
