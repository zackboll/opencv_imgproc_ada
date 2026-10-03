with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.Module_Interop;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Phase_Correlation_Tests is
   use OpenCV.Image_Processing;
   use type OpenCV.Float64_Value;
   use type OpenCV.Size_Coordinate;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   package ABI renames OpenCV.Image_Processing.Internal.C_API;
   use type ABI.Status;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      AUnit.Assertions.Assert (Condition, Message);
   end Check;

   procedure Put
     (Image : in out OpenCV.Core.Mat;
      R, C  : Natural;
      Value : OpenCV.Float64_Value) is
   begin
      if Image.Depth = OpenCV.Core.Float64 then
         OpenCV.Core.Float64_Access.Set (Image, R, C, Value);
      else
         OpenCV.Core.Float32_Access.Set
           (Image, R, C, OpenCV.Float32_Value (Value));
      end if;
   end Put;

   function Get
     (Image : OpenCV.Core.Mat; R, C : Natural) return OpenCV.Float64_Value is
   begin
      if Image.Depth = OpenCV.Core.Float64 then
         return OpenCV.Core.Float64_Access.Get (Image, R, C);
      else
         return
           OpenCV.Float64_Value (OpenCV.Core.Float32_Access.Get (Image, R, C));
      end if;
   end Get;

   function Texture
     (Depth : OpenCV.Core.Depth_Type; DX : Integer := 0; DY : Integer := 0)
      return OpenCV.Core.Mat
   is
      Image : OpenCV.Core.Mat := OpenCV.Core.Create (32, 32, (Depth, 1));
   begin
      Image.Set_To ((others => 0.0));
      for R in 7 .. 23 loop
         for C in 7 .. 23 loop
            Put
              (Image,
               Natural (R + DY),
               Natural (C + DX),
               OpenCV.Float64_Value ((R * 17 + C * 31 + R * C * 7) mod 101));
         end loop;
      end loop;
      return Image;
   end Texture;

   procedure Same (A, B : OpenCV.Core.Mat) is
   begin
      for R in 0 .. A.Rows - 1 loop
         for C in 0 .. A.Columns - 1 loop
            Check (Get (A, R, C) = Get (B, R, C), "input changed");
         end loop;
      end loop;
   end Same;

   generic
      Depth : OpenCV.Core.Depth_Type;
      DX, DY : Integer;
      Windowed : Boolean := False;
   procedure Translation (Test : in out Fixture);
   procedure Translation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      A        : constant OpenCV.Core.Mat := Texture (Depth);
      B        : constant OpenCV.Core.Mat := Texture (Depth, DX, DY);
      W        : constant OpenCV.Core.Mat :=
        Create_Hanning_Window
          ((32, 32),
           (if Depth = OpenCV.Core.Float32
            then Float32_Hanning_Window
            else Float64_Hanning_Window));
      Before_A : constant OpenCV.Core.Mat := A.Clone;
      Before_B : constant OpenCV.Core.Mat := B.Clone;
      Before_W : constant OpenCV.Core.Mat := W.Clone;
      Shift    : constant Phase_Correlation_Result :=
        (if Windowed
         then Phase_Correlate (A, B, W)
         else Phase_Correlate (A, B));
   begin
      Check
        (abs (Shift.X_Shift - OpenCV.Float64_Value (DX)) < 0.6
         and then abs (Shift.Y_Shift - OpenCV.Float64_Value (DY)) < 0.6,
         "native Source_2 displacement sign/shift");
      Check
        (Shift.Response > 0.2 and then Shift.Response < 1.2,
         "clean texture response must be meaningful and finite");
      Same (A, Before_A);
      Same (B, Before_B);
      Same (W, Before_W);
      if Depth = OpenCV.Core.Float32 and then not Windowed then
         declare
            Other : constant Phase_Correlation_Result :=
              Phase_Correlate
                (Texture (OpenCV.Core.Float64),
                 Texture (OpenCV.Core.Float64, DX, DY));
         begin
            Check
              (abs (Other.X_Shift - Shift.X_Shift) < 0.1
               and then abs (Other.Y_Shift - Shift.Y_Shift) < 0.1,
               "Float32/Float64 agreement");
         end;
      end if;
   end Translation;
   procedure Identical_32 is new Translation (OpenCV.Core.Float32, 0, 0);
   procedure Identical_64 is new Translation (OpenCV.Core.Float64, 0, 0);
   procedure Right is new Translation (OpenCV.Core.Float64, 3, 0);
   procedure Left is new Translation (OpenCV.Core.Float64, -3, 0);
   procedure Down is new Translation (OpenCV.Core.Float64, 0, 4);
   procedure Combined is new Translation (OpenCV.Core.Float64, 3, -2);
   procedure Shift_32 is new Translation (OpenCV.Core.Float32, 3, -2);
   procedure Window_32 is new Translation (OpenCV.Core.Float32, 3, -2, True);
   procedure Window_64 is new Translation (OpenCV.Core.Float64, 3, -2, True);

   generic
      Depth : Hanning_Window_Depth;
      Width, Height : OpenCV.Size_Coordinate;
   procedure Hanning (Test : in out Fixture);
   procedure Hanning (Test : in out Fixture) is
      pragma Unreferenced (Test);
      W     : OpenCV.Core.Mat :=
        Create_Hanning_Window ((Width, Height), Depth);
      Other : constant OpenCV.Core.Mat :=
        Create_Hanning_Window ((Width, Height), Depth);
   begin
      Check
        (W.Rows = Natural (Height)
         and then W.Columns = Natural (Width)
         and then W.Channels = 1
         and then W.Depth
                  = (if Depth = Float32_Hanning_Window
                     then OpenCV.Core.Float32
                     else OpenCV.Core.Float64),
         "Hanning metadata");
      for R in 0 .. W.Rows - 1 loop
         for C in 0 .. W.Columns - 1 loop
            Check
              (abs (Get (W, R, C) - Get (W, R, W.Columns - 1 - C)) < 1.0E-6,
               "horizontal symmetry");
            Check
              (abs (Get (W, R, C) - Get (W, W.Rows - 1 - R, C)) < 1.0E-6,
               "vertical symmetry");
            if R = 0
              or else C = 0
              or else R = W.Rows - 1
              or else C = W.Columns - 1
            then
               Check (abs Get (W, R, C) < 1.0E-6, "zero edge");
            end if;
         end loop;
      end loop;
      Check
        (abs (Get (W, W.Rows / 2, W.Columns / 2) - 1.0) < 1.0E-6,
         "odd center");
      if Width = 5 then
         Check
           (abs (Get (W, 1, 1) - 0.5) < 1.0E-6,
            "5x5 sqrt product is 0.5, not unsquared product 0.25");
      end if;
      Check
        (abs (Get (W, 1, 1)
              **2
              - Get (W, 1, W.Columns / 2)**2 * Get (W, W.Rows / 2, 1)**2)
         < 1.0E-6,
         "sqrt separable product");
      Put (W, W.Rows / 2, W.Columns / 2, 9.0);
      Check
        (abs (Get (Other, Other.Rows / 2, Other.Columns / 2) - 1.0) < 1.0E-6,
         "fresh independent storage");
   end Hanning;
   procedure Hann_32 is new Hanning (Float32_Hanning_Window, 5, 5);
   procedure Hann_64 is new Hanning (Float64_Hanning_Window, 5, 5);
   procedure Hann_Rect is new Hanning (Float64_Hanning_Window, 7, 5);

   generic
      Case_Number : Positive;
   procedure Rejection (Test : in out Fixture);
   procedure Rejection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      A      : OpenCV.Core.Mat := Texture (OpenCV.Core.Float64);
      B      : OpenCV.Core.Mat := A.Clone;
      W      : OpenCV.Core.Mat := Create_Hanning_Window ((32, 32));
      Shift  : Phase_Correlation_Result;
      Raised : Boolean := False;
   begin
      case Case_Number is
         when 1      =>
            B := OpenCV.Core.Create (31, 32, (OpenCV.Core.Float64, 1));

         when 10     =>
            A :=
              OpenCV.Core.Create
                (OpenCV.Core.Dimension_Array'(2, 4, 8),
                 (OpenCV.Core.Float64, 1));

         when 2      =>
            B := Texture (OpenCV.Core.Float32);

         when 3      =>
            A := OpenCV.Core.Create (32, 32, (OpenCV.Core.Float64, 3));

         when 4      =>
            A := OpenCV.Core.Create (32, 32, (OpenCV.Core.UInt8, 1));

         when 5      =>
            W := Create_Hanning_Window ((31, 32));

         when 6      =>
            W := Create_Hanning_Window ((32, 32), Float32_Hanning_Window);

         when 7      =>
            A := OpenCV.Core.Create (0, 0, (OpenCV.Core.Float64, 1));

         when others =>
            null;
      end case;
      begin
         if Case_Number = 8 then
            W := Create_Hanning_Window ((1, 5));
         elsif Case_Number = 9 then
            W := Create_Hanning_Window ((5, 1));
         else
            Shift := Phase_Correlate (A, B, W);
         end if;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      Check (Raised, "specific OpenCV_Error required");
      A := Texture (OpenCV.Core.Float64);
      Shift := Phase_Correlate (A, A);
      Check (abs Shift.X_Shift < 0.1, "recovery");
   end Rejection;
   procedure Bad_Geometry is new Rejection (1);
   procedure Bad_Depth is new Rejection (2);
   procedure Bad_Channels is new Rejection (3);
   procedure Bad_Integer is new Rejection (4);
   procedure Bad_Window_Size is new Rejection (5);
   procedure Bad_Window_Type is new Rejection (6);
   procedure Bad_Empty is new Rejection (7);
   procedure Bad_Width is new Rejection (8);
   procedure Bad_Height is new Rejection (9);
   procedure Bad_Dimensions is new Rejection (10);

   procedure Aliases (Test : in out Fixture) is
      pragma Unreferenced (Test);
      A      : constant OpenCV.Core.Mat := Texture (OpenCV.Core.Float64);
      Header : constant OpenCV.Core.Mat := A;
      Before : constant OpenCV.Core.Mat := A.Clone;
      Shift  : Phase_Correlation_Result;
   begin
      Shift := Phase_Correlate (A, Header, A);
      Check (abs Shift.X_Shift < 0.1, "window/source alias");
      Shift := Phase_Correlate (Header, A, A);
      Check (abs Shift.Y_Shift < 0.1, "window/second source alias");
      Same (A, Before);
   end Aliases;

   procedure Regions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent           : OpenCV.Core.Mat :=
        OpenCV.Core.Create (40, 42, (OpenCV.Core.Float64, 1));
      A                : OpenCV.Core.Mat := Parent.Region ((3, 4, 31, 29));
      B                : constant OpenCV.Core.Mat :=
        Parent.Region ((5, 5, 31, 29));
      W                : constant OpenCV.Core.Mat :=
        Parent.Region ((4, 4, 31, 29));
      Actual, Expected : Phase_Correlation_Result;
      Before           : OpenCV.Core.Mat;
   begin
      Parent.Set_To ((others => 1.0E6));
      for R in 0 .. A.Rows - 1 loop
         for C in 0 .. A.Columns - 1 loop
            Put (A, R, C, OpenCV.Float64_Value ((R * 31 + C * 17) mod 97));
         end loop;
      end loop;
      Before := Parent.Clone;
      Expected := Phase_Correlate (A.Clone, B.Clone, W.Clone);
      Actual := Phase_Correlate (A, B, W);
      Check
        (abs (Actual.X_Shift - Expected.X_Shift) < 1.0E-9
         and then abs (Actual.Y_Shift - Expected.Y_Shift) < 1.0E-9
         and then abs (Actual.Response - Expected.Response) < 1.0E-9,
         "overlapping source/window Regions equal packed clones");
      Same (Parent, Before);
      Put (Parent, 39, 41, -1.0E9);
      Actual := Phase_Correlate (A, B, W);
      Check
        (abs (Actual.Response - Expected.Response) < 1.0E-9,
         "parent outside logical Regions has no effect");
   end Regions;

   procedure Raw_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      A            : constant OpenCV.Core.Mat := Texture (OpenCV.Core.Float64);
      Before_A     : constant OpenCV.Core.Mat := A.Clone;
      Empty        : OpenCV.Core.Mat;
      Output       : OpenCV.Core.Mat := A.Clone;
      X, Y, Energy : aliased Interfaces.C.double := 91.0;
      Status       : ABI.Status;
      procedure Native_Rejection (Second, Window : OpenCV.Core.Mat) is
         Before : constant OpenCV.Core.Mat := Second.Clone;
         procedure First (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
            procedure Other (B : OpenCV.Core.Module_Interop.Input_Mat_Handle)
            is
               procedure Selection
                 (W : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
               begin
                  X := 91.0;
                  Y := 91.0;
                  Energy := 91.0;
                  Status :=
                    ABI.Phase_Correlate
                      (H, B, W, X'Access, Y'Access, Energy'Access);
                  Check
                    (Status = ABI.Error_OpenCV,
                     "native assertion translated to OpenCV status");
                  Check
                    (X = 91.0 and then Y = 91.0 and then Energy = 91.0,
                     "native failure atomicity");
               end Selection;
            begin
               OpenCV.Core.Module_Interop.With_Input_Handle
                 (Window, Selection'Access);
            end Other;
         begin
            OpenCV.Core.Module_Interop.With_Input_Handle
              (Second, Other'Access);
         end First;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle (A, First'Access);
         Same (Second, Before);
      end Native_Rejection;
      procedure Input (H : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Null_Input (N : OpenCV.Core.Module_Interop.Input_Mat_Handle)
         is
         begin
            Status :=
              ABI.Phase_Correlate (N, H, N, X'Access, Y'Access, Energy'Access);
            Check (Status = ABI.Error_Invalid_Argument, "null first");
            Status :=
              ABI.Phase_Correlate (H, N, N, X'Access, Y'Access, Energy'Access);
            Check (Status = ABI.Error_Invalid_Argument, "null second");
            Status :=
              ABI.Phase_Correlate (H, H, N, null, Y'Access, Energy'Access);
            Check (Status = ABI.Error_Invalid_Argument, "null scalar");
            Check
              (X = 91.0 and then Y = 91.0 and then Energy = 91.0,
               "failed scalars unchanged");
            Status :=
              ABI.Phase_Correlate (H, H, N, X'Access, Y'Access, Energy'Access);
            Check (Status = ABI.Success, "raw phase recovery");
         end Null_Input;
      begin
         OpenCV.Core.Module_Interop.With_Input_Handle
           (Empty, Null_Input'Access);
      end Input;
      procedure Destination (H : OpenCV.Core.Module_Interop.Output_Mat_Handle)
      is
      begin
         Status := ABI.Create_Hanning_Window (5, 5, 99, H);
         Check (Status = ABI.Error_Invalid_Argument, "bad selector");
         Status := ABI.Create_Hanning_Window (1, 5, 1, H);
         Check (Status = ABI.Error_OpenCV, "native invalid dimension");
         Status := ABI.Create_Hanning_Window (5, -1, 1, H);
         Check (Status = ABI.Error_OpenCV, "native negative dimension");
         Status :=
           ABI.Create_Hanning_Window
             (Interfaces.Integer_32'Last, Interfaces.Integer_32'Last, 1, H);
         Check (Status = ABI.Error_Invalid_Argument, "allocation preflight");
      end Destination;
      procedure Recovery (H : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
      begin
         Status := ABI.Create_Hanning_Window (5, 5, 1, H);
         Check (Status = ABI.Success, "raw Hanning recovery");
      end Recovery;
   begin
      Native_Rejection (Texture (OpenCV.Core.Float32), Empty);
      Native_Rejection
        (OpenCV.Core.Create (31, 32, (OpenCV.Core.Float64, 1)), Empty);
      Native_Rejection
        (A, Create_Hanning_Window ((32, 32), Float32_Hanning_Window));
      Native_Rejection (A, Create_Hanning_Window ((31, 32)));
      OpenCV.Core.Module_Interop.With_Input_Handle (A, Input'Access);
      OpenCV.Core.Module_Interop.With_Output_Handle
        (Output, Destination'Access);
      Same (Output, A);
      Same (A, Before_A);
      OpenCV.Core.Module_Interop.With_Output_Handle (Output, Recovery'Access);
      Check
        (Output.Rows = 5 and then Output.Columns = 5,
         "raw recovered geometry");
   end Raw_ABI;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Run : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Run));
      end Add;
   begin
      Add ("Phase identical Float32", Identical_32'Access);
      Add ("Phase identical Float64", Identical_64'Access);
      Add ("Phase sign: Source_2 right is positive X", Right'Access);
      Add ("Phase negative X", Left'Access);
      Add ("Phase positive Y", Down'Access);
      Add ("Phase combined shift Float64", Combined'Access);
      Add ("Phase combined shift Float32", Shift_32'Access);
      Add ("Phase optimal windowed Float32 preservation", Window_32'Access);
      Add ("Phase optimal windowed Float64 preservation", Window_64'Access);
      Add ("Hanning Float32 invariants", Hann_32'Access);
      Add ("Hanning Float64 invariants", Hann_64'Access);
      Add ("Hanning non-square invariants", Hann_Rect'Access);
      Add ("Phase rejects geometry", Bad_Geometry'Access);
      Add ("Phase rejects depth", Bad_Depth'Access);
      Add ("Phase rejects C3", Bad_Channels'Access);
      Add ("Phase rejects UInt8", Bad_Integer'Access);
      Add ("Phase rejects window geometry", Bad_Window_Size'Access);
      Add ("Phase rejects window type", Bad_Window_Type'Access);
      Add ("Phase rejects empty", Bad_Empty'Access);
      Add ("Phase rejects 3-D layout", Bad_Dimensions'Access);
      Add ("Hanning rejects width one", Bad_Width'Access);
      Add ("Hanning rejects height one", Bad_Height'Access);
      Add ("Phase shared headers and window aliases", Aliases'Access);
      Add ("Phase overlapping logical Regions", Regions'Access);
      Add ("Phase/Hanning raw ABI atomicity", Raw_ABI'Access);
      return Result'Access;
   end Suite;
end Phase_Correlation_Tests;
