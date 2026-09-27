with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt16_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt8_Vec4;
with OpenCV.Core.UInt8_Vec4_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Draw_Contour_Tests is
   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.UInt8_Value;
   use type OpenCV.UInt16_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Core.UInt8_Vec4.Vector;
   use type IP.Contour_Index;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;
   White  : constant OpenCV.Scalar := (Component_0 => 255.0, others => 0.0);

   function Pixel
     (Image : OpenCV.Core.Mat; Y, X : Natural) return OpenCV.UInt8_Value
   is (OpenCV.Core.UInt8_Access.Get (Image, Y, X));

   procedure Clear (Image : in out OpenCV.Core.Mat) is
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
   end Clear;

   procedure Rectangle
     (Image                    : in out OpenCV.Core.Mat;
      Left, Top, Right, Bottom : Natural;
      Value                    : OpenCV.UInt8_Value := 255) is
   begin
      for Y in Top .. Bottom loop
         for X in Left .. Right loop
            OpenCV.Core.UInt8_Access.Set (Image, Y, X, Value);
         end loop;
      end loop;
   end Rectangle;

   function Tree return IP.Contour_Set is
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (45, 45, (OpenCV.Core.UInt8, 1));
   begin
      Clear (Source);
      Rectangle (Source, 2, 2, 42, 42);
      Rectangle (Source, 10, 10, 34, 34, 0);
      Rectangle (Source, 18, 18, 26, 26);
      return IP.Find_Contours (Source, Retrieval => IP.Full_Tree);
   end Tree;

   function Root_Of (Set : IP.Contour_Set) return IP.Contour_Index is
   begin
      for I in 0 .. IP.Contour_Count (Set) - 1 loop
         if not IP.Get_Hierarchy (Set, IP.Contour_Index (I)).Parent.Present
         then
            return IP.Contour_Index (I);
         end if;
      end loop;
      raise Program_Error with "tree has no root";
   end Root_Of;

   procedure Assert_Raises
     (Attempt : not null access procedure; Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, Message);
   end Assert_Raises;

   procedure Fill_Depths (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Set        : constant IP.Contour_Set := Tree;
      Root       : constant IP.Contour_Index := Root_Of (Set);
      Child      : constant IP.Optional_Contour_Index :=
        IP.Get_Hierarchy (Set, Root).First_Child;
      Grandchild : IP.Optional_Contour_Index;
      Image      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (45, 45, (OpenCV.Core.UInt8, 1));
   begin
      AUnit.Assertions.Assert
        (IP.Contour_Count (Set) = 3 and then Child.Present,
         "three-level tree must contain a child");
      Grandchild := IP.Get_Hierarchy (Set, Child.Index).First_Child;
      AUnit.Assertions.Assert
        (Grandchild.Present
         and then IP.Get_Hierarchy (Set, Grandchild.Index).Parent.Index
                  = Child.Index,
         "island must be a grandchild");
      for Level in 0 .. 2 loop
         Clear (Image);
         IP.Fill_Contours
           (Image, Set, Root, White, Descendant_Levels => Level);
         AUnit.Assertions.Assert
           (Pixel (Image, 5, 5) = 255
            and then Pixel (Image, 13, 13) = (if Level = 0 then 255 else 0)
            and then Pixel (Image, 22, 22) = (if Level = 1 then 0 else 255),
            "outer/hole/island parity at each requested depth");
      end loop;
      Clear (Image);
      IP.Fill_Contours
        (Image, Set, Root, White, Descendant_Levels => Natural'Last);
      AUnit.Assertions.Assert
        (Pixel (Image, 13, 13) = 0 and then Pixel (Image, 22, 22) = 255,
         "excessive depth must include every descendant");
      Clear (Image);
      IP.Fill_Contours (Image, Set, White);
      AUnit.Assertions.Assert
        (Pixel (Image, 5, 5) = 255
         and then Pixel (Image, 13, 13) = 0
         and then Pixel (Image, 22, 22) = 255,
         "all-contours fill must preserve hole and island");
   end Fill_Depths;

   procedure Outline_Selection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Set    : constant IP.Contour_Set := Tree;
      Root   : constant IP.Contour_Index := Root_Of (Set);
      Child  : constant IP.Contour_Index :=
        IP.Get_Hierarchy (Set, Root).First_Child.Index;
      Island : constant IP.Contour_Index :=
        IP.Get_Hierarchy (Set, Child).First_Child.Index;
      Image  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (45, 45, (OpenCV.Core.UInt8, 1));
      function Marked (Index : IP.Contour_Index) return Boolean is
         Shape : constant IP.Contour := IP.Get_Contour (Set, Index);
      begin
         for Point of Shape loop
            if Pixel (Image, Natural (Point.Y), Natural (Point.X)) /= 0 then
               return True;
            end if;
         end loop;
         return False;
      end Marked;
   begin
      Clear (Image);
      IP.Draw_Contours (Image, Set, Root, White);
      AUnit.Assertions.Assert
        (Marked (Root)
         and then not Marked (Child)
         and then not Marked (Island),
         "root outline only");
      Clear (Image);
      IP.Draw_Contours (Image, Set, Root, White, Descendant_Levels => 1);
      AUnit.Assertions.Assert
        (Marked (Root) and then Marked (Child) and then not Marked (Island),
         "one level of outline descendants");
      Clear (Image);
      IP.Draw_Contours (Image, Set, Root, White, Descendant_Levels => 2);
      AUnit.Assertions.Assert (Marked (Island), "grandchild outline");
      Clear (Image);
      IP.Draw_Contours (Image, Set, White);
      AUnit.Assertions.Assert
        (Marked (Root) and then Marked (Child) and then Marked (Island),
         "all outlines");
   end Outline_Selection;

   procedure Offset_Alias_Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 6, (OpenCV.Core.UInt8, 1));
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (20, 20, (OpenCV.Core.UInt8, 1));
      Alias  : constant OpenCV.Core.Mat := Parent;
      View   : OpenCV.Core.Mat :=
        OpenCV.Core.Region
          (Alias, (X => 5, Y => 4, Width => 12, Height => 12));
      Set    : IP.Contour_Set;
   begin
      Clear (Source);
      Clear (Parent);
      Rectangle (Source, 1, 1, 3, 3);
      Set := IP.Find_Contours (Source);
      IP.Fill_Contours (View, Set, White, Offset => (X => 2, Y => 3));
      AUnit.Assertions.Assert
        (Pixel (Parent, 8, 8) = 255
         and then Pixel (Parent, 8, 6) = 0
         and then Pixel (Parent, 0, 0) = 0
         and then Pixel (Alias, 8, 8) = 255,
         "offset in local Region coordinates must mutate shared parent");
   end Offset_Alias_Region;

   procedure Empty_And_Errors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty        : IP.Contour_Set;
      Set          : constant IP.Contour_Set := Tree;
      Negative_Set : IP.Contour_Set;
      Source       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 6, (OpenCV.Core.UInt8, 1));
      Image        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (45, 45, (OpenCV.Core.UInt8, 1));
      Other        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (45, 45, (OpenCV.Core.UInt16, 1));
      procedure Bad_Root is
      begin
         IP.Fill_Contours (Image, Empty, 0, White);
      end Bad_Root;
      procedure Out_Of_Range_Root is
      begin
         IP.Draw_Contours
           (Image, Set, IP.Contour_Index (IP.Contour_Count (Set)), White);
      end Out_Of_Range_Root;
      procedure Positive_Overflow is
      begin
         IP.Draw_Contours
           (Image,
            Set,
            White,
            Offset => (X => OpenCV.Point_Coordinate'Last, Y => 0));
      end Positive_Overflow;
      procedure Negative_Overflow is
      begin
         IP.Fill_Contours
           (Image,
            Negative_Set,
            White,
            Offset => (X => OpenCV.Point_Coordinate'First, Y => 0));
      end Negative_Overflow;
      procedure Bad_AA is
      begin
         IP.Draw_Contours
           (Other, Set, White, Line_Style => IP.Anti_Aliased_Line);
      end Bad_AA;
      procedure Bad_Image is
         Uninitialized : OpenCV.Core.Mat;
      begin
         IP.Fill_Contours (Uninitialized, Empty, White);
      end Bad_Image;
   begin
      Clear (Image);
      Clear (Source);
      Rectangle (Source, 1, 1, 3, 3);
      Negative_Set := IP.Find_Contours (Source, Offset => (X => -2, Y => 0));
      IP.Fill_Contours (Image, Empty, White);
      IP.Draw_Contours (Image, Empty, White);
      Assert_Raises (Bad_Root'Access, "empty root must be rejected");
      Assert_Raises
        (Out_Of_Range_Root'Access, "nonempty out-of-range root rejected");
      Assert_Raises (Positive_Overflow'Access, "positive offset overflow");
      Assert_Raises (Negative_Overflow'Access, "negative offset overflow");
      Assert_Raises (Bad_AA'Access, "non-UInt8 AA must be rejected");
      Assert_Raises
        (Bad_Image'Access, "empty collection still validates image");
      AUnit.Assertions.Assert
        (Pixel (Image, 5, 5) = 0 and then Pixel (Image, 22, 22) = 0,
         "structural failures must not write pixels");
   end Empty_And_Errors;

   procedure Depth_Color_AA (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Set    : constant IP.Contour_Set := Tree;
      Image  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (45, 45, (OpenCV.Core.UInt16, 1));
      Color  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (45, 45, (OpenCV.Core.UInt8, 3));
      Color4 : OpenCV.Core.Mat :=
        OpenCV.Core.Create (45, 45, (OpenCV.Core.UInt8, 4));
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
      IP.Fill_Contours (Image, Set, (Component_0 => 1234.0, others => 0.0));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt16_Access.Get (Image, 5, 5) = 1234, "UInt16 fill");
      OpenCV.Core.Set_To (Color, (others => 0.0));
      IP.Fill_Contours
        (Color,
         Set,
         (Component_0 => 7.0,
          Component_1 => 19.0,
          Component_2 => 31.0,
          others      => 0.0));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Color, 5, 5) = (7, 19, 31),
         "C3 channel order");
      OpenCV.Core.Set_To (Color4, (others => 0.0));
      IP.Fill_Contours
        (Color4,
         Set,
         (Component_0 => 7.0,
          Component_1 => 19.0,
          Component_2 => 31.0,
          Component_3 => 43.0));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec4_Access.Get (Color4, 5, 5) = (7, 19, 31, 43),
         "C4 channel order including alpha component");
      Clear (Color);
      IP.Draw_Contours (Color, Set, White, Line_Style => IP.Anti_Aliased_Line);
   end Depth_Color_AA;

   procedure Raw_Guards (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
      Points : aliased C_API.Point_I32_Array :=
        (0 => (X => 1, Y => 1),
         1 => (X => 5, Y => 1),
         2 => (X => 5, Y => 5),
         3 => (X => 1, Y => 5));
      Spans  : aliased C_API.Contour_Span_Array :=
        (0 => (First_Point => 0, Point_Count => 4),
         1 => (First_Point => 0, Point_Count => 4));
      Status : C_API.Status;
      procedure Call (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status :=
           C_API.Draw_Contours
             (Handle,
              Points (0)'Access,
              4,
              Spans (0)'Access,
              1,
              255.0,
              0.0,
              0.0,
              0.0,
              1,
              1,
              C_API.Drawing_Line_8,
              0,
              0);
      end Call;

      procedure Check
        (P        : access constant C_API.Point_I32;
         PC       : Interfaces.Integer_32;
         S        : access constant C_API.Contour_Span;
         SC       : Interfaces.Integer_32;
         Fill     : Interfaces.Unsigned_8 := 1;
         Line     : Interfaces.Integer_32 := C_API.Drawing_Line_8;
         DX       : Interfaces.Integer_32 := 0;
         Expected : C_API.Status := C_API.Error_Invalid_Argument)
      is
         Actual : C_API.Status;
         procedure Invoke
           (Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Actual :=
              C_API.Draw_Contours
                (Handle,
                 P,
                 PC,
                 S,
                 SC,
                 255.0,
                 0.0,
                 0.0,
                 0.0,
                 Fill,
                 1,
                 Line,
                 DX,
                 0);
         end Invoke;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Image, Invoke'Access);
         AUnit.Assertions.Assert (Actual = Expected, "raw guard status");
         if Expected /= C_API.Success then
            AUnit.Assertions.Assert
              (Pixel (Image, 1, 1) = 0, "raw guard must precede write");
         end if;
      end Check;
   begin
      Clear (Image);
      Check (null, 1, Spans (0)'Access, 1);
      Check (Points (0)'Access, 4, null, 1);
      Check (null, -1, null, 0);
      Check (null, 0, null, -1);
      Spans (0).First_Point := -1;
      Check (null, 0, Spans (0)'Access, 1);
      Spans (0).First_Point := 0;
      Spans (0).Point_Count := 0;
      Check (null, 0, Spans (0)'Access, 1);
      Spans (0).Point_Count := Interfaces.Integer_32'Last;
      Check (null, 0, Spans (0)'Access, 1);
      Spans (0).First_Point := Interfaces.Integer_32'Last;
      Check (null, 0, Spans (0)'Access, 1);
      Spans (0).First_Point := 0;
      Spans (0).Point_Count := 4;
      Check (Points (0)'Access, 4, Spans (0)'Access, 1, Fill => 2);
      Check (Points (0)'Access, 4, Spans (0)'Access, 1, Line => 3);
      Points (0).X := Interfaces.Integer_32'Last;
      Check (Points (0)'Access, 4, Spans (0)'Access, 1, DX => 1);
      Points (0).X := 1;
      --  The sum is checked before any huge point buffer is accessed.
      Spans (0).Point_Count := Interfaces.Integer_32'Last;
      Spans (1).Point_Count := 1;
      Check
        (Points (0)'Access, Interfaces.Integer_32'Last, Spans (0)'Access, 2);
      Spans (0).Point_Count := 4;
      Check (null, 0, null, 0, Expected => C_API.Success);
      OpenCV.Core.Module_Interop.With_Output_Handle (Image, Call'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Pixel (Image, 3, 3) = 255,
         "valid call after failures succeeds");
   end Raw_Guards;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("fill nested contour depths and all", Fill_Depths'Access));
      Result.Add_Test
        (Caller.Create
           ("outline selected levels and all", Outline_Selection'Access));
      Result.Add_Test
        (Caller.Create
           ("offset alias and Region", Offset_Alias_Region'Access));
      Result.Add_Test
        (Caller.Create
           ("empty set and atomic failures", Empty_And_Errors'Access));
      Result.Add_Test
        (Caller.Create
           ("depth color and antialiasing", Depth_Color_AA'Access));
      Result.Add_Test
        (Caller.Create ("raw contour ABI guards", Raw_Guards'Access));
      return Result'Access;
   end Suite;
end Draw_Contour_Tests;
