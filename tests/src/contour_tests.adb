with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Contour_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Point;
   use type OpenCV.Core.Point_Coordinate;

   package C_API renames OpenCV.Image_Processing.Internal.C_API;

   use type C_API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   procedure Assert_Raises_OpenCV_Error
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
   end Assert_Raises_OpenCV_Error;

   procedure Fill_Rectangle
     (Image                    : in out OpenCV.Core.Mat;
      Left, Top, Right, Bottom : Natural;
      Value                    : OpenCV.Core.UInt8_Value := 255) is
   begin
      for Row in Top .. Bottom loop
         for Column in Left .. Right loop
            OpenCV.Core.UInt8_Access.Set (Image, Row, Column, Value);
         end loop;
      end loop;
   end Fill_Rectangle;

   procedure Clear (Image : in out OpenCV.Core.Mat) is
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
   end Clear;

   function Contains
     (Contour : OpenCV.Image_Processing.Contour; Point : OpenCV.Core.Point)
      return Boolean is
   begin
      for Item of Contour loop
         if Item = Point then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   procedure External_Rectangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
      Set    : OpenCV.Image_Processing.Contour_Set;
   begin
      Clear (Source);
      Fill_Rectangle (Source, 2, 1, 5, 4);
      Set := OpenCV.Image_Processing.Find_Contours (Source);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Contour_Count (Set) = 1,
         "external rectangle must have exactly one contour");
      declare
         Shape : constant OpenCV.Image_Processing.Contour :=
           OpenCV.Image_Processing.Get_Contour (Set, 0);
      begin
         AUnit.Assertions.Assert
           (Shape'Length = 4, "simple rectangle must contain four points");
         AUnit.Assertions.Assert
           (Contains (Shape, (X => 2, Y => 1)),
            "simple rectangle must contain its upper-left corner");
         AUnit.Assertions.Assert
           (Contains (Shape, (X => 5, Y => 1)),
            "simple rectangle must contain its upper-right corner");
         AUnit.Assertions.Assert
           (Contains (Shape, (X => 5, Y => 4)),
            "simple rectangle must contain its lower-right corner");
         AUnit.Assertions.Assert
           (Contains (Shape, (X => 2, Y => 4)),
            "simple rectangle must contain its lower-left corner");
      end;
   end External_Rectangle;

   procedure Approximation_Modes (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source            : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
      Every, Simple_Set : OpenCV.Image_Processing.Contour_Set;
   begin
      Clear (Source);
      Fill_Rectangle (Source, 2, 1, 5, 4);
      Every :=
        OpenCV.Image_Processing.Find_Contours
          (Source, Approximation => OpenCV.Image_Processing.Every_Point);
      Simple_Set := OpenCV.Image_Processing.Find_Contours (Source);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Get_Contour (Every, 0)'Length = 12,
         "every-point mode must retain all rectangle boundary points");
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Get_Contour (Simple_Set, 0)'Length = 4,
         "simple mode must compress rectangle boundary points");
   end Approximation_Modes;

   procedure Preserves_Source_And_Empty (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 5, (OpenCV.Core.UInt8, 1));
      Empty  : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
   begin
      Clear (Source);
      Clear (Empty);
      Fill_Rectangle (Source, 1, 1, 3, 3);
      declare
         Ignored : constant OpenCV.Image_Processing.Contour_Set :=
           OpenCV.Image_Processing.Find_Contours (Source);
         pragma Unreferenced (Ignored);
      begin
         null;
      end;
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 1, 1) = 255,
         "find contours must not modify Source");
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Contour_Count
           (OpenCV.Image_Processing.Find_Contours (Empty))
         = 0,
         "an all-zero image must return an empty contour set");
   end Preserves_Source_And_Empty;

   procedure Hierarchy_Modes_And_Offset (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (11, 11, (OpenCV.Core.UInt8, 1));
      Tree, Flat, Two  : OpenCV.Image_Processing.Contour_Set;
      Has_Relationship : Boolean := False;
   begin
      Clear (Source);
      Fill_Rectangle (Source, 1, 1, 9, 9);
      Fill_Rectangle (Source, 3, 3, 7, 7, 0);
      Tree :=
        OpenCV.Image_Processing.Find_Contours
          (Source, Retrieval => OpenCV.Image_Processing.Full_Tree);
      Flat :=
        OpenCV.Image_Processing.Find_Contours
          (Source, Retrieval => OpenCV.Image_Processing.Flat_List);
      Two :=
        OpenCV.Image_Processing.Find_Contours
          (Source, Retrieval => OpenCV.Image_Processing.Two_Level);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Contour_Count (Tree) = 2
         and then OpenCV.Image_Processing.Contour_Count (Flat) = 2
         and then OpenCV.Image_Processing.Contour_Count (Two) = 2,
         "nested image must return outer and hole contours in each mode");
      for Index in 0 .. 1 loop
         declare
            Tree_Entry :
              constant OpenCV.Image_Processing.Contour_Hierarchy_Entry :=
                OpenCV.Image_Processing.Get_Hierarchy
                  (Tree, OpenCV.Image_Processing.Contour_Index (Index));
            Flat_Entry :
              constant OpenCV.Image_Processing.Contour_Hierarchy_Entry :=
                OpenCV.Image_Processing.Get_Hierarchy
                  (Flat, OpenCV.Image_Processing.Contour_Index (Index));
         begin
            Has_Relationship :=
              Has_Relationship
              or else Tree_Entry.First_Child.Present
              or else Tree_Entry.Parent.Present;
            AUnit.Assertions.Assert
              (not Flat_Entry.First_Child.Present
               and then not Flat_Entry.Parent.Present,
               "flat list must not expose parent-child relationships");
         end;
      end loop;
      AUnit.Assertions.Assert
        (Has_Relationship,
         "full tree must expose a parent-child relationship");
      declare
         Offset_Set     : constant OpenCV.Image_Processing.Contour_Set :=
           OpenCV.Image_Processing.Find_Contours
             (Source, Offset => (X => -2, Y => 3));
         Offset_Contour : constant OpenCV.Image_Processing.Contour :=
           OpenCV.Image_Processing.Get_Contour (Offset_Set, 0);
      begin
         AUnit.Assertions.Assert
           (Contains (Offset_Contour, (X => -1, Y => 4)),
            "offset must shift contour coordinates exactly");
      end;
   end Hierarchy_Modes_And_Offset;

   procedure Teh_Chin_Selectors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 8, (OpenCV.Core.UInt8, 1));
   begin
      Clear (Source);
      Fill_Rectangle (Source, 2, 1, 5, 4);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Contour_Count
           (OpenCV.Image_Processing.Find_Contours
              (Source, Approximation => OpenCV.Image_Processing.Teh_Chin_L1))
         = 1
         and then OpenCV.Image_Processing.Contour_Count
                    (OpenCV.Image_Processing.Find_Contours
                       (Source,
                        Approximation =>
                          OpenCV.Image_Processing.Teh_Chin_KCOS))
                  = 1,
         "both Teh-Chin selectors must be accepted");
   end Teh_Chin_Selectors;

   procedure Validation_And_Index_Errors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty                   : OpenCV.Core.Mat;
      Three_Dimensional_Shape : constant OpenCV.Core.Dimension_Array :=
        (1 => 2, 2 => 2, 3 => 2);
      Three_Dimensional       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (Three_Dimensional_Shape, (OpenCV.Core.UInt8, 1));
      UInt16                  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Multi                   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 2));
      Valid                   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Set                     : OpenCV.Image_Processing.Contour_Set;
      procedure Check_Empty is
      begin
         Set := OpenCV.Image_Processing.Find_Contours (Empty);
      end Check_Empty;
      procedure Check_Depth is
      begin
         Set := OpenCV.Image_Processing.Find_Contours (UInt16);
      end Check_Depth;
      procedure Check_Dimensions is
      begin
         Set := OpenCV.Image_Processing.Find_Contours (Three_Dimensional);
      end Check_Dimensions;
      procedure Check_Channels is
      begin
         Set := OpenCV.Image_Processing.Find_Contours (Multi);
      end Check_Channels;
      procedure Check_Contour is
         Ignored : constant OpenCV.Image_Processing.Contour :=
           OpenCV.Image_Processing.Get_Contour (Set, 1);
         pragma Unreferenced (Ignored);
      begin
         null;
      end Check_Contour;
      procedure Check_Hierarchy is
         Ignored : constant OpenCV.Image_Processing.Contour_Hierarchy_Entry :=
           OpenCV.Image_Processing.Get_Hierarchy (Set, 1);
         pragma Unreferenced (Ignored);
      begin
         null;
      end Check_Hierarchy;
   begin
      Clear (Valid);
      Assert_Raises_OpenCV_Error
        (Check_Empty'Access, "empty source must be rejected");
      Assert_Raises_OpenCV_Error
        (Check_Depth'Access, "non-UInt8 source must be rejected");
      Assert_Raises_OpenCV_Error
        (Check_Dimensions'Access, "non-2D source must be rejected");
      Assert_Raises_OpenCV_Error
        (Check_Channels'Access, "multi-channel source must be rejected");
      Fill_Rectangle (Valid, 1, 1, 1, 1);
      Set := OpenCV.Image_Processing.Find_Contours (Valid);
      Assert_Raises_OpenCV_Error
        (Check_Contour'Access, "invalid contour index must be rejected");
      Assert_Raises_OpenCV_Error
        (Check_Hierarchy'Access, "invalid hierarchy index must be rejected");
   end Validation_And_Index_Errors;

   procedure C_ABI_Rejects_Malformed_Selectors (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
      Handle : aliased C_API.Contours_Handle := C_API.Null_Contours_Handle;
      Status : C_API.Status := C_API.Success;
      Count  : aliased Interfaces.Integer_32 := 0;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           C_API.Find_Contours
             (Source_Handle,
              99,
              C_API.Contour_Approximation_Simple,
              0,
              0,
              Handle'Access);
      end Input;
      procedure Invalid_Approximation
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           C_API.Find_Contours
             (Source_Handle,
              C_API.Contour_Retrieval_External,
              99,
              0,
              0,
              Handle'Access);
      end Invalid_Approximation;
      procedure Valid_Result
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
      begin
         Status :=
           C_API.Find_Contours
             (Source_Handle,
              C_API.Contour_Retrieval_External,
              C_API.Contour_Approximation_Simple,
              0,
              0,
              Handle'Access);
      end Valid_Result;
   begin
      Clear (Source);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "retrieval")
                  /= 0,
         "malformed retrieval selector must be rejected with a diagnostic");
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Invalid_Approximation'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "approximation")
                  /= 0,
         "malformed approximation selector must be rejected"
         & " with a diagnostic");
      Fill_Rectangle (Source, 1, 1, 1, 1);
      OpenCV.Core.Module_Interop.With_Input_Handle
        (Source, Valid_Result'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "valid raw contour request must succeed");
      Status := C_API.Contour_Point_Count (Handle, -1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "index")
                  /= 0,
         "negative raw contour index must be rejected with a diagnostic");
      Status := C_API.Contour_Point_Count (Handle, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "index")
                  /= 0,
         "out-of-range raw contour index must be rejected with a diagnostic");
      C_API.Contours_Destroy (Handle);
   exception
      when others =>
         C_API.Contours_Destroy (Handle);
         raise;
   end C_ABI_Rejects_Malformed_Selectors;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("External rectangle contours", External_Rectangle'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour approximation modes", Approximation_Modes'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour source preservation and empty",
            Preserves_Source_And_Empty'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour hierarchy modes and offset",
            Hierarchy_Modes_And_Offset'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour Teh-Chin selectors", Teh_Chin_Selectors'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour validation and index errors",
            Validation_And_Index_Errors'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour C ABI malformed selectors",
            C_ABI_Rejects_Malformed_Selectors'Access));
      return Result'Access;
   end Suite;

end Contour_Tests;
