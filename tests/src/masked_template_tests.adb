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

package body Masked_Template_Tests is
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Image_Processing.Template_Matching_Method;
   type Byte_Array is array (Positive range <>) of Interfaces.Unsigned_8;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   procedure Oracle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 6, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Y in 0 .. 4 loop
         for X in 0 .. 5 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Y, X, Interfaces.Unsigned_8 (Y * 11 + X * 7));
         end loop;
      end loop;
      for Y in 0 .. 1 loop
         for X in 0 .. 2 loop
            OpenCV.Core.UInt8_Access.Set
              (Template,
               Y,
               X,
               OpenCV.Core.UInt8_Access.Get (Source, Y + 1, X + 2));
            OpenCV.Core.UInt8_Access.Set
              (Mask, Y, X, (if X = 0 then 0 elsif X = 1 then 1 else 127));
         end loop;
      end loop;
      OpenCV.Image_Processing.Match_Template
        (Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (Destination.Rows = 4
         and then Destination.Columns = 4
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "masked result layout");
      for Y in 0 .. 3 loop
         for X in 0 .. 3 loop
            declare
               Sum : Long_Long_Integer := 0;
            begin
               for V in 0 .. 1 loop
                  for U in 0 .. 2 loop
                     if OpenCV.Core.UInt8_Access.Get (Mask, V, U) /= 0 then
                        declare
                           D : constant Long_Long_Integer :=
                             Long_Long_Integer
                               (OpenCV.Core.UInt8_Access.Get (Template, V, U))
                             - Long_Long_Integer
                                 (OpenCV.Core.UInt8_Access.Get
                                    (Source, Y + V, X + U));
                        begin
                           Sum := Sum + D * D;
                        end;
                     end if;
                  end loop;
               end loop;
               AUnit.Assertions.Assert
                 (abs (OpenCV.Core.Float32_Access.Get (Destination, Y, X)
                       - OpenCV.Float32_Value (Sum))
                  <= 0.125,
                  "widened masked UInt8 oracle");
            end;
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (abs (OpenCV.Core.Float32_Access.Get (Destination, 1, 2)) <= 0.125,
         "perfect match must be near zero");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 4, 5) = 79
         and then OpenCV.Core.UInt8_Access.Get (Mask, 0, 2) = 127,
         "source and nonbinary mask preservation");
   end Oracle;

   procedure Obscured_Landmark (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 8, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Extrema     : OpenCV.Core.Min_Max_Result;
   begin
      --  At x=1 the distinctive 10,200 pair is exact but the last pixel is
      --  obscured. At x=5 a distractor has a much better unmasked score.
      for X in 0 .. 7 loop
         OpenCV.Core.UInt8_Access.Set (Source, 0, X, 70);
      end loop;
      OpenCV.Core.UInt8_Access.Set (Source, 0, 1, 10);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 2, 200);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 3, 255);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 5, 20);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 6, 190);
      OpenCV.Core.UInt8_Access.Set (Source, 0, 7, 0);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 0, 10);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 1, 200);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 2, 0);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 1);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 1, 255);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 2, 0);
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Destination,
         OpenCV.Image_Processing.Squared_Difference);
      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Minimum_Location.X = 5, "unmasked distractor fixture");
      OpenCV.Image_Processing.Match_Template
        (Source, Template, Mask, Destination);
      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Minimum_Location.X = 1
         and then Extrema.Minimum_Location.Y = 0,
         "mask must restore obscured landmark location");
      --  The same exclusion protects against Template corruption.
      OpenCV.Core.UInt8_Access.Set (Template, 0, 2, 127);
      OpenCV.Image_Processing.Match_Template
        (Source, Template, Mask, Destination);
      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Minimum_Location.X = 1, "excluded Template corruption");
   end Obscured_Landmark;

   procedure Regions_And_Ownership (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 9, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      for Y in 0 .. 5 loop
         for X in 0 .. 8 loop
            OpenCV.Core.UInt8_Access.Set
              (Parent, Y, X, Interfaces.Unsigned_8 (Y * 13 + X * 3 + 1));
         end loop;
      end loop;
      declare
         Source   : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 1, Y => 1, Width => 6, Height => 4));
         Template : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 2, Y => 2, Width => 3, Height => 2));
         Mask     : constant OpenCV.Core.Mat :=
           Parent.Region ((X => 3, Y => 2, Width => 3, Height => 2));
         Packed   : OpenCV.Core.Mat;
      begin
         OpenCV.Image_Processing.Match_Template
           (Source, Template, Mask, Destination);
         OpenCV.Image_Processing.Match_Template
           (Source.Clone, Template.Clone, Mask.Clone, Packed);
         for Y in 0 .. Destination.Rows - 1 loop
            for X in 0 .. Destination.Columns - 1 loop
               AUnit.Assertions.Assert
                 (OpenCV.Core.Float32_Access.Get (Destination, Y, X)
                  = OpenCV.Core.Float32_Access.Get (Packed, Y, X),
                  "simultaneous overlapping Regions equal logical clones");
            end loop;
         end loop;
      end;
      OpenCV.Core.UInt8_Access.Set (Parent, 2, 2, 255);
      AUnit.Assertions.Assert
        (abs (OpenCV.Core.Float32_Access.Get (Destination, 1, 1)) <= 0.125,
         "output independent of subsequent parent mutations");
   end Regions_And_Ownership;

   procedure Zero_And_Maximum (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Mask        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.UInt8_Access.Set (Source, 0, 0, 255);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 0, 0);
      OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, 0);
      OpenCV.Image_Processing.Match_Template
        (Source, Template, Mask, Destination);
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 0.0,
         "zero mask gives exact zero");
      for Byte of Byte_Array'(1, 127, 255) loop
         OpenCV.Core.UInt8_Access.Set (Mask, 0, 0, Byte);
         OpenCV.Image_Processing.Match_Template
           (Source, Template, Mask, Destination);
         AUnit.Assertions.Assert
           (OpenCV.Core.Float32_Access.Get (Destination, 0, 0) = 65025.0,
            "all nonzero mask bytes give unscaled maximum difference");
      end loop;
   end Zero_And_Maximum;

   procedure Rejections (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Good        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Bad         : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));

      procedure Check
        (Source, Template, Mask : OpenCV.Core.Mat;
         Method                 :
           OpenCV.Image_Processing.Template_Matching_Method :=
             OpenCV.Image_Processing.Squared_Difference)
      is
         Raised : Boolean := False;
      begin
         begin
            OpenCV.Image_Processing.Match_Template
              (Source, Template, Mask, Destination, Method);
         exception
            when OpenCV.OpenCV_Error =>
               Raised := True;
         end;
         AUnit.Assertions.Assert (Raised, "specific OpenCV_Error required");
         AUnit.Assertions.Assert
           (Destination.Rows = 1
            and then Destination.Columns = 1
            and then Destination.Depth = OpenCV.Core.UInt8
            and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
            "existing destination preserved after rejection");
      end Check;
   begin
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      Check (Bad, Good, Good);
      Check (Good, Bad, Good);
      Check (Good, Good, Bad);
      Bad := OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Check (Bad, Good, Good);
      Check (Good, Bad, Good);
      Check (Good, Good, Bad);
      Bad := OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Check (Bad, Good, Good);
      Check (Good, Bad, Good);
      Check (Good, Good, Bad);
      Bad := OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt8, 1));
      Check (Good, Good, Bad);
      Check (Bad, Good, Good);
      for Method in OpenCV.Image_Processing.Template_Matching_Method loop
         if Method /= OpenCV.Image_Processing.Squared_Difference
           and then Method
                    /= OpenCV.Image_Processing.Normalized_Squared_Difference
           and then Method /= OpenCV.Image_Processing.Cross_Correlation
           and then Method
                    /= OpenCV.Image_Processing.Normalized_Cross_Correlation
         then
            Check (Good, Good, Good, Method);
         end if;
      end loop;
      OpenCV.Image_Processing.Match_Template (Good, Good, Good, Destination);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32, "recovery after rejection");
   end Rejections;

   procedure Raw_Rejection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package API renames OpenCV.Image_Processing.Internal.C_API;
      use type API.Status;
      Empty       : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt8, 1));
      Status      : API.Status := API.Success;
      procedure Input (S : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Output (D : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status := API.Match_Template_Masked (S, S, S, D, 0);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Destination, Output'Access);
      end Input;
   begin
      OpenCV.Core.UInt8_Access.Set (Destination, 0, 0, 73);
      OpenCV.Core.Module_Interop.With_Input_Handle (Empty, Input'Access);
      AUnit.Assertions.Assert
        (Status /= API.Success
         and then OpenCV.Core.UInt8_Access.Get (Destination, 0, 0) = 73,
         "raw malformed Mat rejection preserves Destination");
   end Raw_Rejection;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Masked template oracle", Oracle'Access));
      Result.Add_Test
        (Caller.Create ("Masked obscured landmark", Obscured_Landmark'Access));
      Result.Add_Test
        (Caller.Create
           ("Masked Regions ownership", Regions_And_Ownership'Access));
      Result.Add_Test
        (Caller.Create ("Masked zero and maximum", Zero_And_Maximum'Access));
      Result.Add_Test
        (Caller.Create ("Masked validation atomicity", Rejections'Access));
      Result.Add_Test
        (Caller.Create ("Masked raw ABI rejection", Raw_Rejection'Access));
      return Result'Access;
   end Suite;
end Masked_Template_Tests;
