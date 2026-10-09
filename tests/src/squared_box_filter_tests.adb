with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Float64_Vec3;
with OpenCV.Core.Float64_Vec3_Access;
with OpenCV.Image_Processing;

package body Squared_Box_Filter_Tests is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   package U renames C.UInt8_Access;
   package D renames C.Float64_Access;
   use AUnit.Assertions;
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type OpenCV.Border_Kind;
   use type OpenCV.Size_Coordinate;
   use type IP.Squared_Box_Mode;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.UInt8_Value;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Lookup
     (Coordinate : Integer; Length : Positive; Border : OpenCV.Border_Kind)
      return Integer
   is
      P : Integer := Coordinate;
   begin
      if P in 0 .. Length - 1 then
         return P;
      elsif Border = OpenCV.Constant_Border then
         return -1;
      elsif Border = OpenCV.Replicate or else Length = 1 then
         return (if P < 0 then 0 else Length - 1);
      end if;
      while P not in 0 .. Length - 1 loop
         if P < 0 then
            P := -P - (if Border = OpenCV.Reflect then 1 else 0);
         else
            P := 2 * Length - P - (if Border = OpenCV.Reflect then 1 else 2);
         end if;
      end loop;
      return P;
   end Lookup;

   procedure Oracle (T : in out Fixture) is
      pragma Unreferenced (T);
      S       : C.Mat := C.Create (3, 4, (C.UInt8, 1));
      type Kernel_Array is array (Positive range <>) of OpenCV.Size;
      Kernels : constant Kernel_Array := ((1, 1), (3, 3), (2, 4), (9, 8));
   begin
      for Y in 0 .. 2 loop
         for X in 0 .. 3 loop
            U.Set (S, Y, X, OpenCV.UInt8_Value (Y * 41 + X * 17));
         end loop;
      end loop;
      for Mode in IP.Squared_Box_Mode loop
         for Border in OpenCV.Border_Kind loop
            if Border /= OpenCV.Wrap then
               for Kernel of Kernels loop
                  declare
                     P : constant C.Mat :=
                       IP.Squared_Box_Filter (S, Kernel, Mode, Border);
                  begin
                     Assert (P.Depth = C.Float64, "Float64 output");
                     for Y in 0 .. 2 loop
                        for X in 0 .. 3 loop
                           declare
                              Sum : OpenCV.Float64_Value := 0.0;
                           begin
                              for J in 0 .. Kernel.Height - 1 loop
                                 for I in 0 .. Kernel.Width - 1 loop
                                    declare
                                       SY : constant Integer :=
                                         Lookup
                                           (Y
                                            + Integer (J)
                                            - Integer (Kernel.Height) / 2,
                                            3,
                                            Border);
                                       SX : constant Integer :=
                                         Lookup
                                           (X
                                            + Integer (I)
                                            - Integer (Kernel.Width) / 2,
                                            4,
                                            Border);
                                    begin
                                       if SY >= 0 and then SX >= 0 then
                                          Sum :=
                                            Sum
                                            + OpenCV.Float64_Value
                                                (U.Get (S, SY, SX))
                                              **2;
                                       end if;
                                    end;
                                 end loop;
                              end loop;
                              if Mode = IP.Mean_Square then
                                 Sum :=
                                   Sum
                                   / OpenCV.Float64_Value
                                       (Kernel.Width * Kernel.Height);
                              end if;
                              Assert
                                (abs (D.Get (P, Y, X) - Sum)
                                 <= 2.0e-15
                                    * OpenCV.Float64_Value'Max (1.0, Sum),
                                 "independent window oracle");
                           end;
                        end loop;
                     end loop;
                  end;
               end loop;
            end if;
         end loop;
      end loop;
   end Oracle;

   procedure Types_And_Singletons (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      for Depth in C.Depth_Type loop
         if Depth in C.UInt8 | C.Float32 then
            for Channels in C.Channel_Count range 1 .. 3 loop
               if Channels /= 2 then
                  for Rows in 1 .. 2 loop
                     for Columns in 1 .. 2 loop
                        declare
                           S : C.Mat :=
                             C.Create (Rows, Columns, (Depth, Channels));
                        begin
                           S.Set_To ((2.0, 2.0, 2.0, 2.0));
                           for Mode in IP.Squared_Box_Mode loop
                              for Border in OpenCV.Border_Kind loop
                                 if Border /= OpenCV.Wrap then
                                    declare
                                       P        : constant C.Mat :=
                                         IP.Squared_Box_Filter
                                           (S, (2, 4), Mode, Border);
                                       Expected : OpenCV.Float64_Value := 4.0;
                                       Area     : Positive := 8;
                                    begin
                                       if Mode = IP.Mean_Square
                                         and then Border
                                                  /= OpenCV.Constant_Border
                                       then
                                          Area :=
                                            (if Columns = 1 then 1 else 2)
                                            * (if Rows = 1 then 1 else 4);
                                       end if;
                                       if Mode = IP.Sum_Of_Squares then
                                          Expected :=
                                            Expected
                                            * OpenCV.Float64_Value (Area);
                                       end if;
                                       if Border = OpenCV.Constant_Border then
                                          Expected :=
                                            4.0
                                            * OpenCV.Float64_Value
                                                (Integer'Min (Rows, 2)
                                                 * Integer'Min (Columns, 1));
                                          if Mode = IP.Mean_Square then
                                             Expected := Expected / 8.0;
                                          end if;
                                       end if;
                                       Assert
                                         (P.Rows = Rows
                                          and then P.Columns = Columns
                                          and then P.Channels = Channels,
                                          "original logical geometry");
                                       if Channels = 1 then
                                          Assert
                                            (D.Get (P, 0, 0) = Expected,
                                             "singleton normalization");
                                       else
                                          declare
                                             V :
                                               constant C
                                                          .Float64_Vec3
                                                          .Vector :=
                                                 C.Float64_Vec3_Access.Get
                                                   (P, 0, 0);
                                          begin
                                             for Value of V loop
                                                Assert
                                                  (Value = Expected,
                                                   "C3 normalization");
                                             end loop;
                                          end;
                                       end if;
                                    end;
                                 end if;
                              end loop;
                           end loop;
                        end;
                     end loop;
                  end loop;
               end if;
            end loop;
         end if;
      end loop;
   end Types_And_Singletons;

   procedure Region_And_Ownership (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent : C.Mat := C.Create (5, 7, (C.UInt8, 1));
   begin
      Parent.Set_To ((99.0, 0.0, 0.0, 0.0));
      declare
         S : C.Mat := Parent.Region ((1, 1, 3, 2));
      begin
         S.Set_To ((2.0, 0.0, 0.0, 0.0));
         declare
            P : C.Mat := IP.Squared_Box_Filter (S, (9, 8));
         begin
            Assert (D.Get (P, 0, 0) = 4.0, "Region-local reflection");
            D.Set (P, 0, 0, 123.0);
            Assert (U.Get (S, 0, 0) = 2, "source unchanged");
            S.Set_To ((7.0, 0.0, 0.0, 0.0));
            Assert (D.Get (P, 1, 1) = 4.0, "independent owning output");
         end;
      end;
      Assert (U.Get (Parent, 0, 0) = 99, "parent guards unchanged");
   end Region_And_Ownership;

   procedure Invalid_And_Recovery (T : in out Fixture) is
      pragma Unreferenced (T);
      S     : C.Mat := C.Create (2, 3, (C.UInt8, 1));
      procedure Reject
        (Image  : C.Mat;
         Kernel : OpenCV.Size;
         Border : OpenCV.Border_Kind := OpenCV.Replicate) is
      begin
         declare
            P : constant C.Mat :=
              IP.Squared_Box_Filter (Image, Kernel, IP.Sum_Of_Squares, Border);
            pragma Unreferenced (P);
         begin
            Assert (False, "must reject invalid input");
         end;
      exception
         when OpenCV.OpenCV_Error =>
            null;
      end Reject;
      Empty : C.Mat;
   begin
      S.Set_To ((255.0, 0.0, 0.0, 0.0));
      Reject (Empty, (1, 1));
      Reject (S, (0, 1));
      Reject (S, (33026, 1));
      Reject (S, (1, 1), OpenCV.Wrap);
      Reject (C.Create (2, 2, (C.UInt8, 2)), (1, 1));
      Reject (C.Create (2, 2, (C.Float64, 1)), (1, 1));
      Reject (C.Create (C.Dimension_Array'(2, 2, 2), (C.UInt8, 1)), (1, 1));
      declare
         P : constant C.Mat :=
           IP.Squared_Box_Filter
             (S, (33025, 1), IP.Sum_Of_Squares, OpenCV.Replicate);
      begin
         Assert
           (D.Get (P, 0, 0) = 2_147_450_625.0,
            "signed Int32 maximum safe area and recovery");
      end;
   end Invalid_And_Recovery;

   procedure Float_Oracle (T : in out Fixture) is
      pragma Unreferenced (T);
      S : C.Mat := C.Create (2, 3, (C.Float32, 1));
   begin
      for Y in 0 .. 1 loop
         for X in 0 .. 2 loop
            C.Float32_Access.Set
              (S, Y, X, OpenCV.Float32_Value (Y * 3 - X * 2) / 4.0);
         end loop;
      end loop;
      declare
         P : constant C.Mat :=
           IP.Squared_Box_Filter
             (S, (3, 1), IP.Sum_Of_Squares, OpenCV.Constant_Border);
      begin
         Assert (D.Get (P, 0, 1) = 1.25, "signed fractional square sum");
         Assert (D.Get (P, 1, 1) = 0.6875, "Float64 accumulation");
      end;
   end Float_Oracle;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Squared box oracle", Oracle'Access));
      Result.Add_Test
        (Caller.Create
           ("Squared box types and singletons", Types_And_Singletons'Access));
      Result.Add_Test
        (Caller.Create
           ("Squared box Region and ownership", Region_And_Ownership'Access));
      Result.Add_Test
        (Caller.Create
           ("Squared box invalid and recovery", Invalid_And_Recovery'Access));
      Result.Add_Test
        (Caller.Create ("Squared box Float32 oracle", Float_Oracle'Access));
      return Result'Access;
   end Suite;
end Squared_Box_Filter_Tests;
