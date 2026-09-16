with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Int32_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;
with System;

package body Connected_Component_Tests is

   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Float64_Value;
   use type OpenCV.Image_Processing.Component_Label;
   use type OpenCV.Rect;

   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Raw_Connected_Components
     (Source, Labels, Stats, Centroids : System.Address;
      Connectivity                     : Interfaces.Integer_32;
      Label_Count                      : access Interfaces.Integer_32)
      return C_API.Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_connected_components_with_stats";

   function To_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Input_Mat_Handle,
        System.Address);
   function To_Address is new
     Ada.Unchecked_Conversion
       (OpenCV.Core.Module_Interop.Output_Mat_Handle,
        System.Address);

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

   procedure Clear (Image : in out OpenCV.Core.Mat) is
   begin
      OpenCV.Core.Set_To (Image, (others => 0.0));
   end Clear;

   procedure Set
     (Image       : in out OpenCV.Core.Mat;
      Row, Column : Natural;
      Value       : OpenCV.UInt8_Value := 255) is
   begin
      OpenCV.Core.UInt8_Access.Set (Image, Row, Column, Value);
   end Set;

   function Label_At
     (Labels : OpenCV.Core.Mat; Row, Column : Natural)
      return OpenCV.Image_Processing.Component_Label
   is
      Value : constant Interfaces.Integer_32 :=
        OpenCV.Core.Int32_Access.Get (Labels, Row, Column);
   begin
      AUnit.Assertions.Assert (Value >= 0, "labels must be nonnegative");
      return OpenCV.Image_Processing.Component_Label (Value);
   end Label_At;

   procedure Assert_Close
     (Actual, Expected : OpenCV.Float64_Value; Message : String) is
   begin
      AUnit.Assertions.Assert (abs (Actual - Expected) < 0.000_001, Message);
   end Assert_Close;

   procedure Assert_Component
     (Components             : OpenCV.Image_Processing.Connected_Component_Set;
      Label                  : OpenCV.Image_Processing.Component_Label;
      X, Y                   : OpenCV.Point_Coordinate;
      Width, Height, Area    : Natural;
      Centroid_X, Centroid_Y : OpenCV.Float64_Value;
      Message                : String)
   is
      Item : constant OpenCV.Image_Processing.Component_Statistics :=
        OpenCV.Image_Processing.Get_Component (Components, Label);
   begin
      AUnit.Assertions.Assert
        (Item.Bounds
         = (X      => X,
            Y      => Y,
            Width  => OpenCV.Size_Coordinate (Width),
            Height => OpenCV.Size_Coordinate (Height)),
         Message & " bounds");
      AUnit.Assertions.Assert (Item.Area = Area, Message & " area");
      Assert_Close (Item.Centroid_X, Centroid_X, Message & " centroid x");
      Assert_Close (Item.Centroid_Y, Centroid_Y, Message & " centroid y");
   end Assert_Component;

   procedure Basic_Multiple_Components (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (8, 10, (OpenCV.Core.UInt8, 1));
      Labels     : OpenCV.Core.Mat;
      Components : OpenCV.Image_Processing.Connected_Component_Set;
      A, B, C    : OpenCV.Image_Processing.Component_Label;
   begin
      Clear (Source);
      Set (Source, 1, 1);
      for Row in 1 .. 2 loop
         for Column in 4 .. 6 loop
            Set (Source, Row, Column);
         end loop;
      end loop;
      Set (Source, 4, 7);
      Set (Source, 5, 7);
      Set (Source, 6, 7);
      Set (Source, 6, 8);
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components);
      A := Label_At (Labels, 1, 1);
      B := Label_At (Labels, 1, 4);
      C := Label_At (Labels, 4, 7);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Component_Count (Components) = 3
         and then Labels.Rows = Source.Rows
         and then Labels.Columns = Source.Columns
         and then Labels.Depth = OpenCV.Core.Int32
         and then Labels.Channels = 1,
         "basic result must have three components and Int32 C1 labels");
      AUnit.Assertions.Assert
        (Label_At (Labels, 0, 0) = OpenCV.Image_Processing.Background_Label
         and then A > 0
         and then B > 0
         and then C > 0
         and then A /= B
         and then A /= C
         and then B /= C,
         "background and separate labels must be correct");
      AUnit.Assertions.Assert
        (Label_At (Labels, 2, 6) = B and then Label_At (Labels, 6, 8) = C,
         "component pixels must retain their observed label");
      Assert_Component
        (Components, A, 1, 1, 1, 1, 1, 1.0, 1.0, "single pixel");
      Assert_Component (Components, B, 4, 1, 3, 2, 6, 5.0, 1.5, "rectangle");
      Assert_Component (Components, C, 7, 4, 2, 3, 4, 7.25, 5.25, "L shape");
   end Basic_Multiple_Components;

   procedure Connectivity_And_Nonzero (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Labels        : OpenCV.Core.Mat;
      Components    : OpenCV.Image_Processing.Connected_Component_Set;
      First, Second : OpenCV.Image_Processing.Component_Label;
   begin
      Clear (Source);
      Set (Source, 1, 1, 1);
      Set (Source, 2, 2, 17);
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components, OpenCV.Image_Processing.Four_Connected);
      First := Label_At (Labels, 1, 1);
      Second := Label_At (Labels, 2, 2);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Component_Count (Components) = 2
         and then First /= Second,
         "diagonal pixels must be separate with four-connectivity");
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components, OpenCV.Image_Processing.Eight_Connected);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Component_Count (Components) = 1
         and then Label_At (Labels, 1, 1) = Label_At (Labels, 2, 2),
         "diagonal pixels must join with eight-connectivity");
      Clear (Source);
      Set (Source, 0, 0, 1);
      Set (Source, 0, 1, 17);
      Set (Source, 1, 0, 128);
      Set (Source, 1, 1, 255);
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Component_Count (Components) = 1,
         "all nonzero UInt8 values must be foreground");
   end Connectivity_And_Nonzero;

   procedure Background_Foreground_And_Centroid (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (3, 4, (OpenCV.Core.UInt8, 1));
      Labels     : OpenCV.Core.Mat;
      Components : OpenCV.Image_Processing.Connected_Component_Set;
   begin
      Clear (Source);
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Component_Count (Components) = 0,
         "all background has no foreground statistics");
      for Row in 0 .. 2 loop
         for Column in 0 .. 3 loop
            AUnit.Assertions.Assert
              (Label_At (Labels, Row, Column)
               = OpenCV.Image_Processing.Background_Label,
               "all background labels must be zero");
         end loop;
      end loop;
      OpenCV.Core.Set_To (Source, (others => 255.0));
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components);
      AUnit.Assertions.Assert
        (OpenCV.Image_Processing.Component_Count (Components) = 1,
         "all foreground must be one component");
      Assert_Component
        (Components, 1, 0, 0, 4, 3, 12, 1.5, 1.0, "all foreground");
      Clear (Source);
      Set (Source, 0, 0);
      Set (Source, 0, 3);
      Set (Source, 2, 1);
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components);
      Assert_Component
        (Components,
         Label_At (Labels, 0, 0),
         0,
         0,
         4,
         3,
         3,
         4.0 / 3.0,
         2.0 / 3.0,
         "fractional centroid");
   end Background_Foreground_And_Centroid;

   procedure ROI_Rebinding_And_Preservation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (7, 8, (OpenCV.Core.UInt8, 1));
      Source     : OpenCV.Core.Mat;
      Labels     : OpenCV.Core.Mat :=
        OpenCV.Core.Create (1, 1, (OpenCV.Core.UInt16, 3));
      Components : OpenCV.Image_Processing.Connected_Component_Set;
      Snapshot   : OpenCV.Core.Mat;
   begin
      Clear (Parent);
      Set (Parent, 0, 0);
      Set (Parent, 6, 7);
      Source := Parent.Region ((X => 2, Y => 2, Width => 4, Height => 3));
      Set (Parent, 3, 3);
      Set (Parent, 3, 4);
      Snapshot := Source.Clone;
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components);
      AUnit.Assertions.Assert
        (Labels.Rows = 3
         and then Labels.Columns = 4
         and then Labels.Depth = OpenCV.Core.Int32
         and then Labels.Channels = 1
         and then OpenCV.Image_Processing.Component_Count (Components) = 1,
         "noncontiguous ROI must rebind Labels and exclude parent pixels");
      Assert_Component
        (Components,
         Label_At (Labels, 1, 1),
         1,
         1,
         2,
         1,
         2,
         1.5,
         1.0,
         "ROI-relative statistics");
      for Row in 0 .. 2 loop
         for Column in 0 .. 3 loop
            AUnit.Assertions.Assert
              (OpenCV.Core.UInt8_Access.Get (Source, Row, Column)
               = OpenCV.Core.UInt8_Access.Get (Snapshot, Row, Column),
               "Source ROI must remain unchanged");
         end loop;
      end loop;
   end ROI_Rebinding_And_Preservation;

   procedure Aliases_Invalid_Source_And_Statistics_Access
     (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      Source                        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (4, 4, (OpenCV.Core.UInt8, 1));
      Labels, Shared, First, Second : OpenCV.Core.Mat;
      Components                    :
        OpenCV.Image_Processing.Connected_Component_Set;
      Parent                        : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 6, (OpenCV.Core.UInt8, 1));
      Empty                         : OpenCV.Core.Mat;
      Three_D                       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create
          (OpenCV.Core.Dimension_Array'(1 => 2, 2 => 2, 3 => 2),
           (OpenCV.Core.UInt8, 1));
      UInt16                        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt16, 1));
      Int16                         : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Int16, 1));
      Float32                       : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
      Color                         : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 3));
      procedure Same is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (Source, Source, Components);
      end Same;
      procedure Shallow is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (Source, Shared, Components);
      end Shallow;
      procedure Overlap is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (First, Second, Components);
      end Overlap;
      procedure Empty_Call is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (Empty, Labels, Components);
      end Empty_Call;
      procedure Three_D_Call is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (Three_D, Labels, Components);
      end Three_D_Call;
      procedure UInt16_Call is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (UInt16, Labels, Components);
      end UInt16_Call;
      procedure Int16_Call is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (Int16, Labels, Components);
      end Int16_Call;
      procedure Float_Call is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (Float32, Labels, Components);
      end Float_Call;
      procedure Color_Call is
      begin
         OpenCV.Image_Processing.Connected_Components_With_Stats
           (Color, Labels, Components);
      end Color_Call;
      procedure Background is
      begin
         declare
            Ignore : constant OpenCV.Image_Processing.Component_Statistics :=
              OpenCV.Image_Processing.Get_Component (Components, 0);
         begin
            null;
         end;
      end Background;
      procedure Out_Of_Range is
      begin
         declare
            Ignore : constant OpenCV.Image_Processing.Component_Statistics :=
              OpenCV.Image_Processing.Get_Component (Components, 2);
         begin
            null;
         end;
      end Out_Of_Range;
   begin
      Clear (Source);
      Set (Source, 1, 1);
      Shared := Source;
      Assert_Raises (Same'Access, "same Source/Labels Mat must be rejected");
      Assert_Raises
        (Shallow'Access, "shallow Source/Labels alias must be rejected");
      First := Parent.Region ((X => 0, Y => 0, Width => 4, Height => 4));
      Second := Parent.Region ((X => 2, Y => 2, Width => 4, Height => 4));
      Assert_Raises
        (Overlap'Access, "overlapping Source/Labels ROIs must be rejected");
      Assert_Raises (Empty_Call'Access, "empty source must be rejected");
      Assert_Raises (Three_D_Call'Access, "N-D source must be rejected");
      Assert_Raises (UInt16_Call'Access, "UInt16 source must be rejected");
      Assert_Raises (Int16_Call'Access, "Int16 source must be rejected");
      Assert_Raises (Float_Call'Access, "Float32 source must be rejected");
      Assert_Raises (Color_Call'Access, "UInt8 C3 source must be rejected");
      OpenCV.Image_Processing.Connected_Components_With_Stats
        (Source, Labels, Components);
      Assert_Raises
        (Background'Access, "background statistics must be hidden");
      Assert_Raises
        (Out_Of_Range'Access,
         "out-of-range statistics label must be rejected");
   end Aliases_Invalid_Source_And_Statistics_Access;

   procedure Raw_C_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source                   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.UInt8, 1));
      Labels, Stats, Centroids : OpenCV.Core.Mat;
      Count                    : aliased Interfaces.Integer_32 := 0;
      Status                   : C_API.Status := C_API.Success;
      procedure Input
        (Source_Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle)
      is
         procedure Labels_Output
           (Labels_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
         is
            procedure Stats_Output
              (Stats_Handle : OpenCV.Core.Module_Interop.Output_Mat_Handle)
            is
               procedure Centroids_Output
                 (Centroids_Handle :
                    OpenCV.Core.Module_Interop.Output_Mat_Handle) is
               begin
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       System.Null_Address,
                       To_Address (Stats_Handle),
                       To_Address (Centroids_Handle),
                       8,
                       Count'Access);
                  AUnit.Assertions.Assert
                    (Status = C_API.Error_Invalid_Argument,
                     "null labels must be rejected");
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       To_Address (Source_Handle),
                       To_Address (Stats_Handle),
                       To_Address (Centroids_Handle),
                       8,
                       Count'Access);
                  AUnit.Assertions.Assert
                    (Status = C_API.Error_Invalid_Argument,
                     "source used as an output must be rejected");
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       To_Address (Labels_Handle),
                       System.Null_Address,
                       To_Address (Centroids_Handle),
                       8,
                       Count'Access);
                  AUnit.Assertions.Assert
                    (Status = C_API.Error_Invalid_Argument,
                     "null statistics must be rejected");
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       To_Address (Labels_Handle),
                       To_Address (Stats_Handle),
                       To_Address (Labels_Handle),
                       8,
                       Count'Access);
                  AUnit.Assertions.Assert
                    (Status = C_API.Error_Invalid_Argument,
                     "aliased labels/centroids outputs must be rejected");
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       To_Address (Labels_Handle),
                       To_Address (Stats_Handle),
                       System.Null_Address,
                       8,
                       Count'Access);
                  AUnit.Assertions.Assert
                    (Status = C_API.Error_Invalid_Argument,
                     "null centroids must be rejected");
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       To_Address (Labels_Handle),
                       To_Address (Labels_Handle),
                       To_Address (Centroids_Handle),
                       8,
                       Count'Access);
                  AUnit.Assertions.Assert
                    (Status = C_API.Error_Invalid_Argument,
                     "aliased labels/statistics outputs must be rejected");
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       To_Address (Labels_Handle),
                       To_Address (Stats_Handle),
                       To_Address (Stats_Handle),
                       8,
                       Count'Access);
                  AUnit.Assertions.Assert
                    (Status = C_API.Error_Invalid_Argument,
                     "aliased statistics/centroids outputs must be rejected");
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       To_Address (Labels_Handle),
                       To_Address (Stats_Handle),
                       To_Address (Centroids_Handle),
                       7,
                       Count'Access);
                  AUnit.Assertions.Assert
                    (Status = C_API.Error_Invalid_Argument,
                     "invalid connectivity must be rejected");
                  Status :=
                    Raw_Connected_Components
                      (To_Address (Source_Handle),
                       To_Address (Labels_Handle),
                       To_Address (Stats_Handle),
                       To_Address (Centroids_Handle),
                       8,
                       Count'Access);
               end Centroids_Output;
            begin
               OpenCV.Core.Module_Interop.With_Output_Handle
                 (Centroids, Centroids_Output'Access);
            end Stats_Output;
         begin
            OpenCV.Core.Module_Interop.With_Output_Handle
              (Stats, Stats_Output'Access);
         end Labels_Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle
           (Labels, Labels_Output'Access);
      end Input;
   begin
      Status :=
        Raw_Connected_Components
          (System.Null_Address,
           System.Null_Address,
           System.Null_Address,
           System.Null_Address,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "null source must be rejected");
      Status :=
        Raw_Connected_Components
          (System.Null_Address,
           System.Null_Address,
           System.Null_Address,
           System.Null_Address,
           8,
           null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "null label count must be rejected");
      Set (Source, 0, 0);
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 2,
         "valid raw call after failure must recover");
   end Raw_C_ABI;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Connected components basic statistics",
            Basic_Multiple_Components'Access));
      Result.Add_Test
        (Caller.Create
           ("Connected components connectivity and nonzero",
            Connectivity_And_Nonzero'Access));
      Result.Add_Test
        (Caller.Create
           ("Connected components background foreground centroid",
            Background_Foreground_And_Centroid'Access));
      Result.Add_Test
        (Caller.Create
           ("Connected components ROI rebinding preservation",
            ROI_Rebinding_And_Preservation'Access));
      Result.Add_Test
        (Caller.Create
           ("Connected components aliases validation access",
            Aliases_Invalid_Source_And_Statistics_Access'Access));
      Result.Add_Test
        (Caller.Create ("Connected components raw C ABI", Raw_C_ABI'Access));
      return Result'Access;
   end Suite;

end Connected_Component_Tests;
