with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Colormap_Tests is
   package IP renames OpenCV.Image_Processing;
   package Raw renames OpenCV.Image_Processing.Internal.C_API;
   package U8 renames OpenCV.Core.UInt8_Access;
   package C3 renames OpenCV.Core.UInt8_Vec3_Access;
   subtype Triple is OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   use type Triple;
   use type Raw.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result      : aliased AUnit.Test_Suites.Test_Suite;
   type Bytes is array (Natural range <>) of Interfaces.Unsigned_8;
   Ramp_Values : constant Bytes := (0, 1, 64, 127, 200, 255);
   Pin_Values  : constant Bytes := (0, 64, 127, 255);

   function Ramp (Values : Bytes := Ramp_Values) return OpenCV.Core.Mat is
      M : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, Values'Length, (OpenCV.Core.UInt8, 1));
   begin
      for I in Values'Range loop
         U8.Set (M, 0, I - Values'First, Values (I));
      end loop;
      return M;
   end Ramp;

   function Lookup_Value (I : Interfaces.Unsigned_8) return Triple
   is ((I, 255 - I, I xor 16#55#));

   function Table return OpenCV.Core.Mat is
      M : OpenCV.Core.Mat :=
        OpenCV.Core.Create (256, 1, (OpenCV.Core.UInt8, 3));
   begin
      for I in 0 .. 255 loop
         C3.Set (M, I, 0, Lookup_Value (Interfaces.Unsigned_8 (I)));
      end loop;
      return M;
   end Table;

   procedure Equal (Left, Right : OpenCV.Core.Mat; Context : String) is
   begin
      AUnit.Assertions.Assert
        (Left.Rows = Right.Rows
         and then Left.Columns = Right.Columns
         and then Left.Depth = Right.Depth
         and then Left.Channels = Right.Channels,
         Context & " metadata");
      for R in 0 .. Left.Rows - 1 loop
         for C in 0 .. Left.Columns - 1 loop
            if Left.Channels = 1 then
               AUnit.Assertions.Assert
                 (U8.Get (Left, R, C) = U8.Get (Right, R, C),
                  Context & " source byte");
            else
               AUnit.Assertions.Assert
                 (C3.Get (Left, R, C) = C3.Get (Right, R, C),
                  Context & " BGR triple");
            end if;
         end loop;
      end loop;
   end Equal;

   procedure Metadata (M, Source : OpenCV.Core.Mat; Context : String) is
   begin
      AUnit.Assertions.Assert
        (M.Depth = OpenCV.Core.UInt8
         and then M.Channels = 3
         and then M.Rows = Source.Rows
         and then M.Columns = Source.Columns,
         Context & " UInt8 C3 geometry");
   end Metadata;

   procedure Reject (Action : not null access procedure) is
   begin
      Action.all;
      AUnit.Assertions.Assert (False, "expected OpenCV_Error");
   exception
      when OpenCV.OpenCV_Error =>
         null;
   end Reject;

   procedure All_Selectors (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat := Ramp;
      Before : constant OpenCV.Core.Mat := Source.Clone;
      Output : OpenCV.Core.Mat;
   begin
      for Map in IP.Built_In_Color_Map loop
         IP.Apply_Color_Map (Source, Output, Map);
         Metadata (Output, Source, Map'Image);
         Equal (Source, Before, Map'Image & " unchanged");
      end loop;
   end All_Selectors;

   type Triples is array (Natural range <>) of Triple;
   generic
      Map : IP.Built_In_Color_Map;
      Expected : Triples;
   procedure Pinned (T : in out Fixture);

   procedure Pinned (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat := Ramp (Pin_Values);
      Output : OpenCV.Core.Mat;
   begin
      IP.Apply_Color_Map (Source, Output, Map);
      for I in Expected'Range loop
         AUnit.Assertions.Assert
           (C3.Get (Output, 0, I) = Expected (I), Map'Image & I'Image);
      end loop;
   end Pinned;

   --  Independently derived from pinned colormap.cpp definitions; see review.
   procedure Autumn is new
     Pinned
       (IP.Autumn_Map,
        ((0, 0, 255), (0, 64, 255), (0, 127, 255), (0, 255, 255)));
   procedure Jet is new
     Pinned
       (IP.Jet_Map,
        ((128, 0, 0), (255, 128, 0), (130, 255, 126), (0, 0, 128)));
   procedure Viridis is new
     Pinned
       (IP.Viridis_Map,
        ((84, 1, 68), (139, 82, 59), (141, 144, 33), (37, 231, 253)));

   procedure Twilight (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat := Ramp ((0, 255));
      Output : OpenCV.Core.Mat;
   begin
      IP.Apply_Color_Map (Source, Output, IP.Twilight_Map);
      AUnit.Assertions.Assert
        (C3.Get (Output, 0, 0) = (226, 217, 226), "Twilight first endpoint");
      AUnit.Assertions.Assert
        (C3.Get (Output, 0, 1) = (226, 217, 226), "Twilight last endpoint");
   end Twilight;

   procedure Custom_Bytes (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat := Ramp;
      LUT    : constant OpenCV.Core.Mat := Table;
      Before : constant OpenCV.Core.Mat := LUT.Clone;
      Output : OpenCV.Core.Mat;
   begin
      IP.Apply_Color_Map (Source, Output, LUT);
      Metadata (Output, Source, "custom");
      for I in Ramp_Values'Range loop
         AUnit.Assertions.Assert
           (C3.Get (Output, 0, I) = Lookup_Value (Ramp_Values (I)),
            "custom" & I'Image);
      end loop;
      Equal (Source, Ramp, "source unchanged");
      Equal (LUT, Before, "table unchanged");
   end Custom_Bytes;

   procedure BGR_Luminance (T : in out Fixture) is
      pragma Unreferenced (T);
      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 4, (OpenCV.Core.UInt8, 3));
      Output, Built_In : OpenCV.Core.Mat;
      LUT              : constant OpenCV.Core.Mat := Table;
      --  Round(0.114 B + 0.587 G + 0.299 R): 29,150,76,22.
      Gray             : constant Bytes := (29, 150, 76, 22);
      Pixels           : constant Triples :=
        ((255, 0, 0), (0, 255, 0), (0, 0, 255), (10, 20, 30));
   begin
      for I in Pixels'Range loop
         C3.Set (Source, 0, I, Pixels (I));
      end loop;
      IP.Apply_Color_Map (Source, Output, LUT);
      IP.Apply_Color_Map (Source, Built_In, IP.Autumn_Map);
      for I in Gray'Range loop
         AUnit.Assertions.Assert
           (C3.Get (Output, 0, I) = Lookup_Value (Gray (I)),
            "BGR luminance" & I'Image);
         AUnit.Assertions.Assert
           (C3.Get (Built_In, 0, I) = (0, Gray (I), 255),
            "built-in BGR luminance" & I'Image);
         AUnit.Assertions.Assert
           (C3.Get (Source, 0, I) = Pixels (I), "C3 source unchanged");
      end loop;
   end BGR_Luminance;

   generic
      Kind : Natural;
      Is_Table : Boolean;
   procedure Invalid_Input (T : in out Fixture);

   procedure Invalid_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Bad      : OpenCV.Core.Mat;
      Source   : constant OpenCV.Core.Mat := Ramp;
      LUT      : constant OpenCV.Core.Mat := Table;
      Output   : OpenCV.Core.Mat := Ramp;
      Before   : constant OpenCV.Core.Mat := Output.Clone;
      procedure Built_In is
      begin
         IP.Apply_Color_Map (Bad, Output, IP.Jet_Map);
      end Built_In;
      procedure Custom is
      begin
         if Is_Table then
            IP.Apply_Color_Map (Source, Output, Bad);
         else
            IP.Apply_Color_Map (Bad, Output, LUT);
         end if;
      end Custom;
      Rows     : constant Positive := (if Is_Table then 256 else 2);
      Channels : constant OpenCV.Core.Channel_Count :=
        (if Is_Table then 3 else 1);
   begin
      case Kind is
         when 0      =>
            null;

         when 1      =>
            Bad :=
              OpenCV.Core.Create
                (Shape        => (2, 2, 2),
                 Element_Type => (OpenCV.Core.UInt8, Channels));

         when 2      =>
            Bad :=
              OpenCV.Core.Create (Rows, 1, (OpenCV.Core.UInt16, Channels));

         when 3      =>
            Bad := OpenCV.Core.Create (Rows, 1, (OpenCV.Core.Int16, Channels));

         when 4      =>
            Bad :=
              OpenCV.Core.Create (Rows, 1, (OpenCV.Core.Float32, Channels));

         when 5      =>
            Bad :=
              OpenCV.Core.Create (Rows, 1, (OpenCV.Core.Float64, Channels));

         when 6      =>
            Bad := OpenCV.Core.Create (Rows, 1, (OpenCV.Core.UInt8, 2));

         when 7      =>
            Bad := OpenCV.Core.Create (Rows, 1, (OpenCV.Core.UInt8, 4));

         when 8      =>
            Bad := OpenCV.Core.Create (255, 1, (OpenCV.Core.UInt8, 3));

         when 9      =>
            Bad := OpenCV.Core.Create (257, 1, (OpenCV.Core.UInt8, 3));

         when 10     =>
            Bad := OpenCV.Core.Create (1, 256, (OpenCV.Core.UInt8, 3));

         when 11     =>
            Bad := OpenCV.Core.Create (256, 1, (OpenCV.Core.UInt8, 1));

         when others =>
            raise Program_Error;
      end case;
      if not Is_Table then
         Reject (Built_In'Access);
         Equal (Output, Before, "built-in rejection atomic");
      end if;
      Reject (Custom'Access);
      Equal (Output, Before, "custom rejection atomic");
   end Invalid_Input;

   procedure Empty_Source is new Invalid_Input (0, False);
   procedure ND_Source is new Invalid_Input (1, False);
   procedure U16_Source is new Invalid_Input (2, False);
   procedure I16_Source is new Invalid_Input (3, False);
   procedure F32_Source is new Invalid_Input (4, False);
   procedure F64_Source is new Invalid_Input (5, False);
   procedure C2_Source is new Invalid_Input (6, False);
   procedure C4_Source is new Invalid_Input (7, False);
   procedure ND_Table is new Invalid_Input (1, True);
   procedure U16_Table is new Invalid_Input (2, True);
   procedure F32_Table is new Invalid_Input (4, True);
   procedure C2_Table is new Invalid_Input (6, True);
   procedure C4_Table is new Invalid_Input (7, True);
   procedure Short_Table is new Invalid_Input (8, True);
   procedure Long_Table is new Invalid_Input (9, True);
   procedure Horizontal_Table is new Invalid_Input (10, True);
   procedure C1_Table is new Invalid_Input (11, True);

   generic
      Custom : Boolean;
   procedure Source_Region (T : in out Fixture);

   procedure Source_Region (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent            : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 8, (OpenCV.Core.UInt8, 3));
      LUT               : constant OpenCV.Core.Mat := Table;
      Output, Reference : OpenCV.Core.Mat;
   begin
      Parent.Set_To ((255.0, 0.0, 255.0, 0.0));
      declare
         View : OpenCV.Core.Mat := Parent.Region ((2, 1, 3, 2));
      begin
         View.Set_To ((10.0, 20.0, 30.0, 0.0));
         if Custom then
            IP.Apply_Color_Map (View, Output, LUT);
            IP.Apply_Color_Map (View.Clone, Reference, LUT);
         else
            IP.Apply_Color_Map (View, Output, IP.Jet_Map);
            IP.Apply_Color_Map (View.Clone, Reference, IP.Jet_Map);
         end if;
         Equal (Output, Reference, "logical Source Region");
         AUnit.Assertions.Assert
           (C3.Get (Parent, 0, 0) = (255, 0, 255), "outside parent unchanged");
      end;
   end Source_Region;
   procedure Built_In_Region is new Source_Region (False);
   procedure Custom_Region is new Source_Region (True);

   procedure Table_Region (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent            : OpenCV.Core.Mat :=
        OpenCV.Core.Create (258, 4, (OpenCV.Core.UInt8, 3));
      Source            : constant OpenCV.Core.Mat := Ramp;
      Output, Reference : OpenCV.Core.Mat;
   begin
      Parent.Set_To ((others => 233.0));
      declare
         View : OpenCV.Core.Mat := Parent.Region ((1, 1, 1, 256));
      begin
         for I in 0 .. 255 loop
            C3.Set (View, I, 0, Lookup_Value (Interfaces.Unsigned_8 (I)));
         end loop;
         AUnit.Assertions.Assert
           (not View.Is_Continuous, "strided LUT fixture");
         IP.Apply_Color_Map (Source, Output, View);
         IP.Apply_Color_Map (Source, Reference, View.Clone);
         Equal (Output, Reference, "logical table Region");
         for I in Ramp_Values'Range loop
            AUnit.Assertions.Assert
              (C3.Get (Output, 0, I) = Lookup_Value (Ramp_Values (I)),
               "Region entry");
         end loop;
      end;
   end Table_Region;

   generic
      Kind : Natural;
   procedure Aliasing (T : in out Fixture);

   procedure Aliasing (T : in out Fixture) is
      pragma Unreferenced (T);
      Source    : OpenCV.Core.Mat := Ramp;
      LUT       : OpenCV.Core.Mat := Table;
      Reference : OpenCV.Core.Mat;
   begin
      case Kind is
         when 0      =>
            IP.Apply_Color_Map (Source, Reference, IP.Jet_Map);
            IP.Apply_Color_Map (Source, Source, IP.Jet_Map);
            Equal (Source, Reference, "built-in same handle");

         when 1      =>
            IP.Apply_Color_Map (Source, Reference, LUT);
            IP.Apply_Color_Map (Source, Source, LUT);
            Equal (Source, Reference, "custom Source same handle");

         when 2      =>
            IP.Apply_Color_Map (Source, Reference, LUT);
            IP.Apply_Color_Map (Source, LUT, LUT);
            Equal (LUT, Reference, "custom table same handle");

         when 3      =>
            declare
               Shared : constant OpenCV.Core.Mat := LUT.Region ((0, 64, 1, 3));
            begin
               IP.Apply_Color_Map (Shared.Clone, Reference, LUT.Clone);
               IP.Apply_Color_Map (Shared, LUT, LUT);
               Equal (LUT, Reference, "Source/table shared storage");
            end;

         when others =>
            raise Program_Error;
      end case;
   end Aliasing;
   procedure Built_In_Alias is new Aliasing (0);
   procedure Source_Alias is new Aliasing (1);
   procedure Table_Alias is new Aliasing (2);
   procedure Shared_Inputs is new Aliasing (3);

   procedure Fresh_Storage (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat := Ramp;
      LUT    : constant OpenCV.Core.Mat := Table;
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 8, (OpenCV.Core.UInt8, 3));
   begin
      Parent.Set_To ((others => 73.0));
      declare
         Output : OpenCV.Core.Mat := Parent.Region ((1, 1, 6, 1));
      begin
         IP.Apply_Color_Map (Source, Output, LUT);
         Output.Set_To ((others => 0.0));
         AUnit.Assertions.Assert
           (C3.Get (Parent, 1, 1) = (73, 73, 73),
            "Destination Region rebinds");
         Equal (Source, Ramp, "fresh Source");
         Equal (LUT, Table, "fresh table");
      end;
   end Fresh_Storage;

   function Raw_Call
     (Source   : OpenCV.Core.Mat;
      Output   : in out OpenCV.Core.Mat;
      LUT      : OpenCV.Core.Mat;
      Custom   : Boolean;
      Selector : Interfaces.Integer_32 := 0) return Raw.Status
   is
      Status : Raw.Status := Raw.Success;
      procedure Input (S : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Lookup (L : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            procedure Dest (D : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
            begin
               Status :=
                 (if Custom
                  then Raw.Apply_Custom_Colormap (S, D, L)
                  else Raw.Apply_Colormap (S, D, Selector));
            end Dest;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Output, Dest'Access);
         end Lookup;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (LUT, Lookup'Access);
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      return Status;
   end Raw_Call;

   generic
      Custom : Boolean;
   procedure Raw_Recovery (T : in out Fixture);

   procedure Raw_Recovery (T : in out Fixture) is
      pragma Unreferenced (T);
      Source : constant OpenCV.Core.Mat := Ramp;
      LUT    : constant OpenCV.Core.Mat := Table;
      Output : OpenCV.Core.Mat := Ramp;
      Before : constant OpenCV.Core.Mat := Output.Clone;
      Status : Raw.Status;
      procedure Bad (S, L : OpenCV.Core.Mat) is
      begin
         Status := Raw_Call (S, Output, L, Custom);
         AUnit.Assertions.Assert (Status /= Raw.Success, "raw rejects");
         Equal (Output, Before, "raw rejection atomic");
      end Bad;
   begin
      if not Custom then
         for Selector in Interfaces.Integer_32 range -1 .. 21 loop
            if Selector not in 0 .. 19 then
               Status := Raw_Call (Source, Output, LUT, False, Selector);
               AUnit.Assertions.Assert
                 (Status = Raw.Error_Invalid_Argument,
                  "private selector rejects");
               Equal (Output, Before, "selector rejection atomic");
            end if;
         end loop;
      else
         Bad (Source, OpenCV.Core.Create (1, 256, (OpenCV.Core.UInt8, 3)));
         Bad (Source, OpenCV.Core.Create (255, 1, (OpenCV.Core.UInt8, 3)));
         Bad (Source, OpenCV.Core.Create (256, 1, (OpenCV.Core.UInt8, 1)));
         Bad (Source, OpenCV.Core.Create (256, 1, (OpenCV.Core.UInt8, 2)));
         Bad (Source, OpenCV.Core.Create (256, 1, (OpenCV.Core.Float32, 3)));
         Bad
           (Source,
            OpenCV.Core.Create
              (Shape => (2, 2, 2), Element_Type => (OpenCV.Core.UInt8, 3)));
      end if;
      Bad (OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1)), LUT);
      Bad (OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 4)), LUT);
      Bad
        (OpenCV.Core.Create
           (Shape => (2, 2, 2), Element_Type => (OpenCV.Core.UInt8, 1)),
         LUT);
      declare
         Empty : OpenCV.Core.Mat;
      begin
         Bad (Empty, LUT);
      end;
      Status := Raw_Call (Source, Output, LUT, Custom);
      AUnit.Assertions.Assert (Status = Raw.Success, "raw valid recovery");
      Metadata (Output, Source, "raw recovery");
      for I in Ramp_Values'Range loop
         AUnit.Assertions.Assert
           (C3.Get (Output, 0, I)
            = (if Custom
               then Lookup_Value (Ramp_Values (I))
               else (0, Ramp_Values (I), 255)),
            "raw recovery exact bytes");
      end loop;
   end Raw_Recovery;
   procedure Raw_Built_In is new Raw_Recovery (False);
   procedure Raw_Custom is new Raw_Recovery (True);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Test : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create ("Colormap " & Name, Test));
      end Add;
   begin
      Add ("all 20 selectors", All_Selectors'Access);
      Add ("Autumn pinned BGR", Autumn'Access);
      Add ("Jet pinned BGR", Jet'Access);
      Add ("Viridis pinned BGR", Viridis'Access);
      Add ("Twilight pinned endpoints", Twilight'Access);
      Add ("custom independent bytes", Custom_Bytes'Access);
      Add ("C3 BGR luminance not per-channel", BGR_Luminance'Access);
      Add ("empty Source", Empty_Source'Access);
      Add ("ND Source", ND_Source'Access);
      Add ("UInt16 Source", U16_Source'Access);
      Add ("Int16 Source", I16_Source'Access);
      Add ("Float32 Source", F32_Source'Access);
      Add ("Float64 Source", F64_Source'Access);
      Add ("C2 Source", C2_Source'Access);
      Add ("C4 Source", C4_Source'Access);
      Add ("ND table", ND_Table'Access);
      Add ("UInt16 table", U16_Table'Access);
      Add ("Float32 table", F32_Table'Access);
      Add ("C2 table", C2_Table'Access);
      Add ("C4 table", C4_Table'Access);
      Add ("255-entry table", Short_Table'Access);
      Add ("257-entry table", Long_Table'Access);
      Add ("horizontal table", Horizontal_Table'Access);
      Add ("C1 table portability policy", C1_Table'Access);
      Add ("built-in Source Region", Built_In_Region'Access);
      Add ("custom Source Region", Custom_Region'Access);
      Add ("noncontiguous table Region", Table_Region'Access);
      Add ("built-in same handle", Built_In_Alias'Access);
      Add ("custom Source same handle", Source_Alias'Access);
      Add ("custom table same handle", Table_Alias'Access);
      Add ("shared Source and table storage", Shared_Inputs'Access);
      Add ("fresh result and Destination Region", Fresh_Storage'Access);
      Add ("raw selectors and recovery", Raw_Built_In'Access);
      Add ("raw custom rejection and recovery", Raw_Custom'Access);
      return Result'Access;
   end Suite;
end Colormap_Tests;
