with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Template_Matching_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;

   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.Point_Coordinate;
   use type OpenCV.Core.UInt8_Vec3.Vector;

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

   function Nearly_Equal
     (Left, Right : OpenCV.Core.Float32_Value;
      Tolerance   : OpenCV.Core.Float32_Value) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Nearly_Equal;

   SQDiff_Zero_Tolerance : constant OpenCV.Core.Float32_Value := 1.0E-2;

   procedure Fill_Unique_UInt8_Scene
     (Source : in out OpenCV.Core.Mat; Match_Row, Match_Column : Natural) is
   begin
      for Row in 0 .. Source.Rows - 1 loop
         for Column in 0 .. Source.Columns - 1 loop
            OpenCV.Core.UInt8_Access.Set
              (Source, Row, Column, Interfaces.Unsigned_8 (Row + Column + 1));
         end loop;
      end loop;

      OpenCV.Core.UInt8_Access.Set (Source, Match_Row, Match_Column, 10);
      OpenCV.Core.UInt8_Access.Set (Source, Match_Row, Match_Column + 1, 20);
      OpenCV.Core.UInt8_Access.Set (Source, Match_Row + 1, Match_Column, 30);
      OpenCV.Core.UInt8_Access.Set
        (Source, Match_Row + 1, Match_Column + 1, 40);
   end Fill_Unique_UInt8_Scene;

   function Unique_UInt8_Template return OpenCV.Core.Mat is
      Template : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.UInt8_Access.Set (Template, 0, 0, 10);
      OpenCV.Core.UInt8_Access.Set (Template, 0, 1, 20);
      OpenCV.Core.UInt8_Access.Set (Template, 1, 0, 30);
      OpenCV.Core.UInt8_Access.Set (Template, 1, 1, 40);
      return Template;
   end Unique_UInt8_Template;

   procedure UInt8_Squared_Difference_Exact_Match (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 6, (OpenCV.Core.UInt8, 1));
      Template    : constant OpenCV.Core.Mat := Unique_UInt8_Template;
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.UInt16, 2));
      Extrema     : OpenCV.Core.Min_Max_Result;
   begin
      Fill_Unique_UInt8_Scene (Source, 1, 2);
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Destination,
         OpenCV.Image_Processing.Squared_Difference);

      AUnit.Assertions.Assert
        (Destination.Rows = 4
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "Match_Template SQDIFF must rebind Destination to 5x4 Float32 C1");

      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Minimum >= 0.0
         and then Nearly_Equal
                    (OpenCV.Core.Float32_Value (Extrema.Minimum),
                     0.0,
                     SQDiff_Zero_Tolerance)
         and then Extrema.Minimum_Location.X = 2
         and then Extrema.Minimum_Location.Y = 1,
         "SQDIFF exact match must be near zero at the known top-left");

      AUnit.Assertions.Assert
        (Source.Rows = 5
         and then Source.Columns = 6
         and then OpenCV.Core.UInt8_Access.Get (Source, 1, 2) = 10
         and then OpenCV.Core.UInt8_Access.Get (Template, 0, 0) = 10,
         "Match_Template must not modify Source or Template");
   end UInt8_Squared_Difference_Exact_Match;

   procedure Float32_Cross_Correlation_Score (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 2, (OpenCV.Core.Float32, 1));
      Destination : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Float32_Access.Set (Source, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 1, 2.0);
      OpenCV.Core.Float32_Access.Set (Source, 0, 2, 3.0);
      OpenCV.Core.Float32_Access.Set (Source, 1, 0, 4.0);
      OpenCV.Core.Float32_Access.Set (Source, 1, 1, 5.0);
      OpenCV.Core.Float32_Access.Set (Source, 1, 2, 6.0);
      OpenCV.Core.Float32_Access.Set (Template, 0, 0, 1.0);
      OpenCV.Core.Float32_Access.Set (Template, 0, 1, 2.0);

      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Destination,
         OpenCV.Image_Processing.Cross_Correlation);

      AUnit.Assertions.Assert
        (Destination.Rows = 2
         and then Destination.Columns = 2
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "Float32 CCORR must produce a 2x2 Float32 C1 score map");
      AUnit.Assertions.Assert
        (Nearly_Equal
           (OpenCV.Core.Float32_Access.Get (Destination, 0, 0), 5.0, 1.0E-5)
         and then Nearly_Equal
                    (OpenCV.Core.Float32_Access.Get (Destination, 0, 1),
                     8.0,
                     1.0E-5)
         and then Nearly_Equal
                    (OpenCV.Core.Float32_Access.Get (Destination, 1, 0),
                     14.0,
                     1.0E-5)
         and then Nearly_Equal
                    (OpenCV.Core.Float32_Access.Get (Destination, 1, 1),
                     17.0,
                     1.0E-5),
         "Float32 CCORR scores must equal the integer-valued dot products");
   end Float32_Cross_Correlation_Score;

   procedure All_Six_Methods_Find_The_Known_Match (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 6, (OpenCV.Core.UInt8, 1));
      Template : constant OpenCV.Core.Mat := Unique_UInt8_Template;

      procedure Check
        (Method      : OpenCV.Image_Processing.Template_Matching_Method;
         Use_Minimum : Boolean)
      is
         Destination : OpenCV.Core.Mat;
         Extrema     : OpenCV.Core.Min_Max_Result;
      begin
         OpenCV.Image_Processing.Match_Template
           (Source, Template, Destination, Method);
         Extrema := OpenCV.Core.Min_Max_Loc (Destination);

         if Use_Minimum then
            AUnit.Assertions.Assert
              (Extrema.Minimum_Location.X = 2
               and then Extrema.Minimum_Location.Y = 1,
               "SQDIFF methods must minimize at the known match");
         else
            AUnit.Assertions.Assert
              (Extrema.Maximum_Location.X = 2
               and then Extrema.Maximum_Location.Y = 1,
               "correlation methods must maximize at the known match");
         end if;
      end Check;
   begin
      Fill_Unique_UInt8_Scene (Source, 1, 2);
      Check (OpenCV.Image_Processing.Squared_Difference, True);
      Check (OpenCV.Image_Processing.Normalized_Squared_Difference, True);
      Check (OpenCV.Image_Processing.Cross_Correlation, False);
      Check (OpenCV.Image_Processing.Normalized_Cross_Correlation, False);
      Check (OpenCV.Image_Processing.Correlation_Coefficient, False);
      Check
        (OpenCV.Image_Processing.Normalized_Correlation_Coefficient, False);
   end All_Six_Methods_Find_The_Known_Match;

   procedure UInt8_C3_Normalized_Cross_Correlation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.UInt8, 3));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Destination : OpenCV.Core.Mat;
      Extrema     : OpenCV.Core.Min_Max_Result;
   begin
      OpenCV.Core.Set_To (Source, (Component_0 => 8.0, others => 8.0));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 2, (10, 20, 30));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 1, 3, (40, 50, 60));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 2, 2, (70, 80, 90));
      OpenCV.Core.UInt8_Vec3_Access.Set (Source, 2, 3, (100, 110, 120));
      OpenCV.Core.UInt8_Vec3_Access.Set (Template, 0, 0, (10, 20, 30));
      OpenCV.Core.UInt8_Vec3_Access.Set (Template, 0, 1, (40, 50, 60));
      OpenCV.Core.UInt8_Vec3_Access.Set (Template, 1, 0, (70, 80, 90));
      OpenCV.Core.UInt8_Vec3_Access.Set (Template, 1, 1, (100, 110, 120));

      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Destination,
         OpenCV.Image_Processing.Normalized_Cross_Correlation);

      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1
         and then Destination.Rows = 3
         and then Destination.Columns = 4
         and then Extrema.Maximum_Location.X = 2
         and then Extrema.Maximum_Location.Y = 1
         and then OpenCV.Core.UInt8_Vec3_Access.Get (Source, 1, 2)
                  = (10, 20, 30),
         "C3 Match_Template must keep Float32 C1 at the color match");

   end UInt8_C3_Normalized_Cross_Correlation;

   procedure Same_Mat_Source_And_Template (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Image       : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat;
      Score       : OpenCV.Core.Float32_Value;
   begin
      Fill_Unique_UInt8_Scene (Image, 0, 0);
      OpenCV.Image_Processing.Match_Template
        (Image,
         Image,
         Destination,
         OpenCV.Image_Processing.Squared_Difference);

      AUnit.Assertions.Assert
        (Destination.Rows = 1
         and then Destination.Columns = 1
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "identical Source and Template must yield a 1x1 Float32 C1 score");

      Score := OpenCV.Core.Float32_Access.Get (Destination, 0, 0);
      AUnit.Assertions.Assert
        (Score >= 0.0
         and then Nearly_Equal (Score, 0.0, SQDiff_Zero_Tolerance),
         "identical Source and Template SQDIFF must be nonnegative "
         & "and near zero");
   end Same_Mat_Source_And_Template;

   procedure Template_Region_Of_Source (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 6, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat;
      Destination : OpenCV.Core.Mat;
      Extrema     : OpenCV.Core.Min_Max_Result;
   begin
      Fill_Unique_UInt8_Scene (Source, 1, 2);
      Template :=
        OpenCV.Core.Region (Source, (X => 2, Y => 1, Width => 2, Height => 2));
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Destination,
         OpenCV.Image_Processing.Squared_Difference);

      Extrema := OpenCV.Core.Min_Max_Loc (Destination);
      AUnit.Assertions.Assert
        (Extrema.Minimum >= 0.0
         and then Nearly_Equal
                    (OpenCV.Core.Float32_Value (Extrema.Minimum),
                     0.0,
                     SQDiff_Zero_Tolerance)
         and then Extrema.Minimum_Location.X = 2
         and then Extrema.Minimum_Location.Y = 1,
         "a Template Region of Source must still find the shared patch");
   end Template_Region_Of_Source;

   procedure Destination_Alias_Is_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Template : constant OpenCV.Core.Mat := Unique_UInt8_Template;
      Shared   : OpenCV.Core.Mat;

      procedure Alias_Source is
      begin
         OpenCV.Image_Processing.Match_Template
           (Source,
            Template,
            Source,
            OpenCV.Image_Processing.Squared_Difference);
      end Alias_Source;

      procedure Alias_Template is
         Local : OpenCV.Core.Mat := Unique_UInt8_Template;
      begin
         OpenCV.Image_Processing.Match_Template
           (Source, Local, Local, OpenCV.Image_Processing.Squared_Difference);
      end Alias_Template;

      procedure Shared_Source_Data is
      begin
         OpenCV.Image_Processing.Match_Template
           (Source,
            Template,
            Shared,
            OpenCV.Image_Processing.Squared_Difference);
      end Shared_Source_Data;
   begin
      Fill_Unique_UInt8_Scene (Source, 1, 1);
      Shared := Source;
      Assert_Raises_OpenCV_Error
        (Alias_Source'Access,
         "Match_Template must reject Destination aliased with Source");
      Assert_Raises_OpenCV_Error
        (Alias_Template'Access,
         "Match_Template must reject Destination aliased with Template");
      Assert_Raises_OpenCV_Error
        (Shared_Source_Data'Access,
         "Match_Template must reject Destination sharing Source storage");
   end Destination_Alias_Is_Rejected;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty_Mat      : OpenCV.Core.Mat;
      Three_D        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      UInt16_Source  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt16, 1));
      Int16_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.Int16, 1));
      Five_Channel   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 5));
      Valid_Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.UInt8, 1));
      Valid_Template : OpenCV.Core.Mat := Unique_UInt8_Template;
      Float32_Templ  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      C3_Template    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Wide_Template  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 6, (OpenCV.Core.UInt8, 1));
      Tall_Template  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 2, (OpenCV.Core.UInt8, 1));
      Destination    : OpenCV.Core.Mat;

      procedure Empty_Source is
      begin
         OpenCV.Image_Processing.Match_Template
           (Empty_Mat,
            Valid_Template,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Empty_Source;

      procedure Empty_Template is
      begin
         OpenCV.Image_Processing.Match_Template
           (Valid_Source,
            Empty_Mat,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Empty_Template;

      procedure Three_D_Source is
      begin
         OpenCV.Image_Processing.Match_Template
           (Three_D,
            Valid_Template,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Three_D_Source;

      procedure Three_D_Template is
      begin
         OpenCV.Image_Processing.Match_Template
           (Valid_Source,
            Three_D,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Three_D_Template;

      procedure UInt16_Depth is
      begin
         OpenCV.Image_Processing.Match_Template
           (UInt16_Source,
            UInt16_Source,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end UInt16_Depth;

      procedure Int16_Depth is
      begin
         OpenCV.Image_Processing.Match_Template
           (Int16_Source,
            Int16_Source,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Int16_Depth;

      procedure Five_Channel_Source is
      begin
         OpenCV.Image_Processing.Match_Template
           (Five_Channel,
            Five_Channel,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Five_Channel_Source;

      procedure Depth_Mismatch is
      begin
         OpenCV.Image_Processing.Match_Template
           (Valid_Source,
            Float32_Templ,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Depth_Mismatch;

      procedure Channel_Mismatch is
      begin
         OpenCV.Image_Processing.Match_Template
           (Valid_Source,
            C3_Template,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Channel_Mismatch;

      procedure Template_Wider is
      begin
         OpenCV.Image_Processing.Match_Template
           (Valid_Source,
            Wide_Template,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Template_Wider;

      procedure Template_Taller is
      begin
         OpenCV.Image_Processing.Match_Template
           (Valid_Source,
            Tall_Template,
            Destination,
            OpenCV.Image_Processing.Squared_Difference);
      end Template_Taller;
   begin
      OpenCV.Core.Set_To (Valid_Source, (others => 7.0));
      Assert_Raises_OpenCV_Error
        (Empty_Source'Access, "Match_Template must reject an empty Source");
      Assert_Raises_OpenCV_Error
        (Empty_Template'Access,
         "Match_Template must reject an empty Template");
      Assert_Raises_OpenCV_Error
        (Three_D_Source'Access, "Match_Template must reject a 3-D Source");
      Assert_Raises_OpenCV_Error
        (Three_D_Template'Access, "Match_Template must reject a 3-D Template");
      Assert_Raises_OpenCV_Error
        (UInt16_Depth'Access, "Match_Template must reject UInt16");
      Assert_Raises_OpenCV_Error
        (Int16_Depth'Access, "Match_Template must reject Int16");
      Assert_Raises_OpenCV_Error
        (Five_Channel_Source'Access,
         "Match_Template must reject more than 4 channels");
      Assert_Raises_OpenCV_Error
        (Depth_Mismatch'Access,
         "Match_Template must reject a Source/Template depth mismatch");
      Assert_Raises_OpenCV_Error
        (Channel_Mismatch'Access,
         "Match_Template must reject a Source/Template channel mismatch");
      Assert_Raises_OpenCV_Error
        (Template_Wider'Access,
         "Match_Template must reject a Template wider than Source");
      Assert_Raises_OpenCV_Error
        (Template_Taller'Access,
         "Match_Template must reject a Template taller than Source");
   end Rejects_Invalid_Public_Inputs;

   procedure Result_Geometry_Rebinds_Destination (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 7, (OpenCV.Core.UInt8, 1));
      Template    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 3, (OpenCV.Core.UInt8, 1));
      Destination : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.Float64, 3));
      Same_Size   : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Source, (others => 3.0));
      OpenCV.Core.Set_To (Template, (others => 3.0));
      OpenCV.Image_Processing.Match_Template
        (Source,
         Template,
         Destination,
         OpenCV.Image_Processing.Squared_Difference);

      AUnit.Assertions.Assert
        (Destination.Rows = 4
         and then Destination.Columns = 5
         and then Destination.Depth = OpenCV.Core.Float32
         and then Destination.Channels = 1,
         "5x7 Source and 2x3 Template must rebind to 5x4 Float32 C1");

      OpenCV.Image_Processing.Match_Template
        (Source,
         Source,
         Same_Size,
         OpenCV.Image_Processing.Squared_Difference);
      AUnit.Assertions.Assert
        (Same_Size.Rows = 1
         and then Same_Size.Columns = 1
         and then Same_Size.Depth = OpenCV.Core.Float32
         and then Same_Size.Channels = 1,
         "equal Source and Template geometry must rebind Destination to 1x1");
   end Result_Geometry_Rebinds_Destination;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      UInt8_Source   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.UInt8, 1));
      UInt8_Template : OpenCV.Core.Mat := Unique_UInt8_Template;
      Empty_Mat      : OpenCV.Core.Mat;
      Three_D        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      Int16_Source   : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 5, (OpenCV.Core.Int16, 1));
      Float32_Templ  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      C3_Template    : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      Wide_Template  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 6, (OpenCV.Core.UInt8, 1));
      Tall_Template  : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 2, (OpenCV.Core.UInt8, 1));

      procedure Check
        (Source     : OpenCV.Core.Mat;
         Template   : OpenCV.Core.Mat;
         Method     : Interfaces.Integer_32;
         Diagnostic : String)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Template_Input
              (Template_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Match_Template
                      (Source_Handle,
                       Template_Handle,
                       Destination_Handle,
                       Method);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Template_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Template, Template_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Match_Template C ABI must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Diagnostic)
            /= 0,
            "malformed Match_Template C ABI input must identify "
            & Diagnostic);
      end Check;

      procedure Check_Aliased_Source is
         Status : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Template_Input
              (Template_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Match_Template
                      (Source_Handle,
                       Template_Handle,
                       Destination_Handle,
                       C_API.Template_Squared_Difference);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (UInt8_Source, Output'Access);
            end Template_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (UInt8_Template, Template_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "aliased Destination/Source C ABI must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "share storage")
            /= 0,
            "aliased Destination/Source C ABI must identify shared storage");
      end Check_Aliased_Source;

      procedure Check_Aliased_Template is
         Status : C_API.Status := C_API.Success;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Template_Input
              (Template_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Match_Template
                      (Source_Handle,
                       Template_Handle,
                       Destination_Handle,
                       C_API.Template_Squared_Difference);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (UInt8_Template, Output'Access);
            end Template_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (UInt8_Template, Template_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "aliased Destination/Template C ABI must return invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "share storage")
            /= 0,
            "aliased Destination/Template C ABI must identify shared storage");
      end Check_Aliased_Template;

      procedure Check_Success
        (Source   : OpenCV.Core.Mat;
         Template : OpenCV.Core.Mat;
         Method   : Interfaces.Integer_32)
      is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Template_Input
              (Template_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Output
                 (Destination_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    C_API.Match_Template
                      (Source_Handle,
                       Template_Handle,
                       Destination_Handle,
                       Method);
               end Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Destination, Output'Access);
            end Template_Input;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Template, Template_Input'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "valid Match_Template C ABI call must succeed");
      end Check_Success;

      procedure Check_Shared_Inputs is
         Destination : OpenCV.Core.Mat;
         Status      : C_API.Status := C_API.Error_Unknown;
         procedure Source_Input
           (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
            procedure Output
              (Destination_Handle :
                 OpenCV.Core.Module_Interop.Output_Mat_Handle) is
            begin
               Status :=
                 C_API.Match_Template
                   (Source_Handle,
                    Source_Handle,
                    Destination_Handle,
                    C_API.Template_Squared_Difference);
            end Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Destination, Output'Access);
         end Source_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (UInt8_Source, Source_Input'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success,
            "shared Source/Template C ABI handles must succeed");
         AUnit.Assertions.Assert
           (Destination.Rows = 1 and then Destination.Columns = 1,
            "shared Source/Template C ABI call must produce a 1x1 result");
      end Check_Shared_Inputs;
   begin
      OpenCV.Core.Set_To (UInt8_Source, (others => 9.0));
      Check
        (UInt8_Source, UInt8_Template, Interfaces.Integer_32'(-1), "method");
      Check (UInt8_Source, UInt8_Template, 6, "method");
      Check (UInt8_Source, UInt8_Template, 99, "method");
      Check (Empty_Mat, UInt8_Template, 0, "source");
      Check (UInt8_Source, Empty_Mat, 0, "template");
      Check (Three_D, UInt8_Template, 0, "two-dimensional");
      Check (UInt8_Source, Three_D, 0, "two-dimensional");
      Check (Int16_Source, Int16_Source, 0, "CV_8U");
      Check (UInt8_Source, Float32_Templ, 0, "types must match");
      Check (UInt8_Source, C3_Template, 0, "types must match");
      Check (UInt8_Source, Wide_Template, 0, "larger than source");
      Check (UInt8_Source, Tall_Template, 0, "larger than source");
      Check_Aliased_Source;
      Check_Aliased_Template;
      Check_Success
        (UInt8_Source, UInt8_Template, C_API.Template_Squared_Difference);
      Check_Success
        (UInt8_Source,
         UInt8_Template,
         C_API.Template_Normalized_Correlation_Coefficient);
      Check_Shared_Inputs;
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Match_Template UInt8 SQDIFF exact match rebinds Destination",
            UInt8_Squared_Difference_Exact_Match'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template Float32 CCORR scores match the dot product",
            Float32_Cross_Correlation_Score'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template six methods find the known best match",
            All_Six_Methods_Find_The_Known_Match'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template preserves UInt8 C3 and returns Float32 C1",
            UInt8_C3_Normalized_Cross_Correlation'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template allows identical Source and Template",
            Same_Mat_Source_And_Template'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template accepts a Template Region of Source",
            Template_Region_Of_Source'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template rejects Destination aliased with inputs",
            Destination_Alias_Is_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template result geometry rebinds Destination",
            Result_Geometry_Rebinds_Destination'Access));
      Result.Add_Test
        (Caller.Create
           ("Match_Template C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Template_Matching_Tests;
