with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.UInt8_Vec4;
with OpenCV.Core.UInt8_Vec4_Access;
with OpenCV.Image_Processing;
with System;
with YUV420_Fixtures;
with YUV422_Fixtures;

package body YUV422_Conversion_Tests is
   package C renames OpenCV.Core;
   package IP renames OpenCV.Image_Processing;
   package F renames YUV422_Fixtures;
   package Bytes renames YUV420_Fixtures;
   use type C.Depth_Type;
   use type C.Channel_Count;
   use type Interfaces.Integer_32;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Frame
     (Layout : IP.YUV422_Layout;
      Pixel  : F.Pixel_Pair := (100, 180, 90, 200);
      Width  : Positive := 4;
      Height : Positive := 3) return C.Mat
   is (F.Packed
         (Width,
          Height,
          Layout,
          F.Pairs'(0 .. Width * Height / 2 - 1 => Pixel)));

   procedure Metadata
     (Image : C.Mat; Rows, Columns : Positive; Channels : C.Channel_Count) is
   begin
      AUnit.Assertions.Assert
        (Image.Rows = Rows
         and then Image.Columns = Columns
         and then Image.Depth = C.UInt8
         and then Image.Channels = Channels
         and then Image.Is_Continuous,
         "fresh packed result metadata");
   end Metadata;

   procedure Check_Pixel
     (Image       : C.Mat;
      Row, Column : Natural;
      Output      : IP.YUV422_Color_Output;
      Expected    : Bytes.RGB)
   is
      Is_RGB : constant Boolean := Output in IP.RGB_Output | IP.RGBA_Output;
   begin
      AUnit.Assertions.Assert
        (Bytes.Byte (Image, Row, Column, 0)
         = (if Is_RGB then Expected.R else Expected.B)
         and then Bytes.Byte (Image, Row, Column, 1) = Expected.G
         and then Bytes.Byte (Image, Row, Column, 2)
                  = (if Is_RGB then Expected.B else Expected.R),
         "independent pinned fixed-point pixel and channel order");
      if Image.Channels = 4 then
         AUnit.Assertions.Assert
           (Bytes.Byte (Image, Row, Column, 3) = 255, "opaque alpha");
      end if;
   end Check_Pixel;

   generic
      Layout : IP.YUV422_Layout;
      Kind : Natural;
   procedure Decode (Test : in out Fixture);
   procedure Decode (Test : in out Fixture) is
      pragma Unreferenced (Test);
      P      : constant F.Pixel_Pair :=
        (case Kind is
           when 0      => (16, 16, 128, 128),
           when 1      => (235, 235, 128, 128),
           when 2      => (100, 180, 90, 200),
           when others => (0, 255, 0, 255));
      E0     : constant Bytes.RGB :=
        (case Kind is
           when 0      => (0, 0, 0),
           when 1      => (255, 255, 255),
           when 2      => (213, 54, 21),
           when others => (203, 0, 0));
      E1     : constant Bytes.RGB :=
        (case Kind is
           when 0      => (0, 0, 0),
           when 1      => (255, 255, 255),
           when 2      => (255, 147, 114),
           when others => (255, 225, 20));
      Source : constant C.Mat := Frame (Layout, P);
      Before : constant C.Mat := Source.Clone;
   begin
      for Output in IP.YUV422_Color_Output loop
         declare
            D : constant C.Mat := IP.Decode_YUV422 (Source, Layout, Output);
         begin
            Metadata
              (D,
               3,
               4,
               (if Output in IP.BGR_Output | IP.RGB_Output then 3 else 4));
            for Row in 0 .. 2 loop
               for Column in 0 .. 3 loop
                  Check_Pixel
                    (D,
                     Row,
                     Column,
                     Output,
                     (if Column mod 2 = 0 then E0 else E1));
               end loop;
            end loop;
            Bytes.Equal (Source, Before);
         end;
      end loop;
   end Decode;
   procedure D00 is new Decode (IP.UYVY, 0);
   procedure D01 is new Decode (IP.UYVY, 1);
   procedure D02 is new Decode (IP.UYVY, 2);
   procedure D03 is new Decode (IP.UYVY, 3);
   procedure D10 is new Decode (IP.YUY2, 0);
   procedure D11 is new Decode (IP.YUY2, 1);
   procedure D12 is new Decode (IP.YUY2, 2);
   procedure D13 is new Decode (IP.YUY2, 3);
   procedure D20 is new Decode (IP.YVYU, 0);
   procedure D21 is new Decode (IP.YVYU, 1);
   procedure D22 is new Decode (IP.YVYU, 2);
   procedure D23 is new Decode (IP.YVYU, 3);

   generic
      Layout : IP.YUV422_Layout;
   procedure Luma (Test : in out Fixture);
   procedure Luma (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Pixels  : constant F.Pairs :=
        ((0, 16, 90, 200),
         (235, 255, 22, 70),
         (32, 180, 33, 240),
         (91, 152, 0, 255),
         (11, 47, 128, 128),
         (87, 201, 255, 0));
      Changed : F.Pairs := Pixels;
      Source  : constant C.Mat := F.Packed (4, 3, Layout, Pixels);
      Before  : constant C.Mat := Source.Clone;
      D       : constant C.Mat := IP.Extract_YUV422_Luma (Source, Layout);
   begin
      Metadata (D, 3, 4, 1);
      for I in Pixels'Range loop
         declare
            Column : constant Natural := (if I mod 2 = 0 then 0 else 2);
         begin
            AUnit.Assertions.Assert
              (Bytes.Byte (D, I / 2, Column) = Pixels (I).Y0
               and then Bytes.Byte (D, I / 2, Column + 1) = Pixels (I).Y1,
               "all raw Y bytes including outside-studio values");
         end;
         Changed (I).U := 255 - Pixels (I).U;
         Changed (I).V := 255 - Pixels (I).V;
      end loop;
      Bytes.Equal
        (D, IP.Extract_YUV422_Luma (F.Packed (4, 3, Layout, Changed), Layout));
      Bytes.Equal (Source, Before);
   end Luma;
   procedure L0 is new Luma (IP.UYVY);
   procedure L1 is new Luma (IP.YUY2);
   procedure L2 is new Luma (IP.YVYU);

   generic
      Layout : IP.YUV422_Layout;
   procedure Minimum (Test : in out Fixture);
   procedure Minimum (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant C.Mat := Frame (Layout, (32, 180, 90, 200), 2, 1);
      L      : constant C.Mat := IP.Extract_YUV422_Luma (Source, Layout);
   begin
      Metadata (L, 1, 2, 1);
      AUnit.Assertions.Assert
        (Bytes.Byte (L, 0, 0) = 32 and then Bytes.Byte (L, 0, 1) = 180,
         "minimum raw Y");
      for Output in IP.YUV422_Color_Output loop
         declare
            D : constant C.Mat := IP.Decode_YUV422 (Source, Layout, Output);
         begin
            Metadata
              (D,
               1,
               2,
               (if Output in IP.BGR_Output | IP.RGB_Output then 3 else 4));
            Check_Pixel (D, 0, 0, Output, (134, 0, 0));
            Check_Pixel (D, 0, 1, Output, (255, 147, 114));
         end;
      end loop;
   end Minimum;
   procedure M0 is new Minimum (IP.UYVY);
   procedure M1 is new Minimum (IP.YUY2);
   procedure M2 is new Minimum (IP.YVYU);

   generic
      Layout : IP.YUV422_Layout;
   procedure Region (Test : in out Fixture);
   procedure Region (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : C.Mat := C.Create (7, 11, (C.UInt8, 2));
   begin
      Parent.Set_To ((3.0, 251.0, 0.0, 0.0));
      declare
         View   : C.Mat := Parent.Region ((3, 2, 4, 3));
         Source : constant C.Mat := Frame (Layout);
      begin
         --  Even at an odd parent column, the logical C2 phase supplied by
         --  this caller is complete and correct for the declared layout.
         Source.Copy_To (View);
         declare
            Before : constant C.Mat := Parent.Clone;
            Packed : constant C.Mat := View.Clone;
         begin
            AUnit.Assertions.Assert (not View.Is_Continuous, "strided ROI");
            for Output in IP.YUV422_Color_Output loop
               Bytes.Equal
                 (IP.Decode_YUV422 (View, Layout, Output),
                  IP.Decode_YUV422 (Packed, Layout, Output));
            end loop;
            Bytes.Equal
              (IP.Extract_YUV422_Luma (View, Layout),
               IP.Extract_YUV422_Luma (Packed, Layout));
            Bytes.Equal (Parent, Before);
         end;
      end;
   end Region;
   procedure R0 is new Region (IP.UYVY);
   procedure R1 is new Region (IP.YUY2);
   procedure R2 is new Region (IP.YVYU);

   generic
      Luma_Only : Boolean;
   procedure Ownership (Test : in out Fixture);
   procedure Ownership (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant C.Mat := Frame (IP.YVYU);
      Before : constant C.Mat := Source.Clone;
      function Convert return C.Mat
      is (if Luma_Only
          then IP.Extract_YUV422_Luma (Source, IP.YVYU)
          else IP.Decode_YUV422 (Source, IP.YVYU, IP.RGBA_Output));
      A      : C.Mat := Convert;
      B      : constant C.Mat := Convert;
      Saved  : constant C.Mat := B.Clone;
   begin
      A.Set_To ((others => 17.0));
      Bytes.Equal (B, Saved);
      Bytes.Equal (Source, Before);
   end Ownership;
   procedure O0 is new Ownership (False);
   procedure O1 is new Ownership (True);

   function Bad
     (Width    : Positive := 4;
      Depth    : C.Depth_Type := C.UInt8;
      Channels : C.Channel_Count := 2;
      ND       : Boolean := False) return C.Mat
   is
      D : C.Mat :=
        (if ND
         then C.Create (C.Dimension_Array'(2, 2, 2), (Depth, Channels))
         else C.Create (3, Width, (Depth, Channels)));
   begin
      D.Set_To ((others => 37.0));
      return D;
   end Bad;

   procedure Reject (Source : C.Mat; Luma_Only : Boolean) is
      Raised : Boolean := False;
   begin
      begin
         declare
            D : constant C.Mat :=
              (if Luma_Only
               then IP.Extract_YUV422_Luma (Source, IP.UYVY)
               else IP.Decode_YUV422 (Source, IP.UYVY));
            pragma Unreferenced (D);
         begin
            null;
         end;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, "specific public OpenCV_Error");
   end Reject;

   generic
      Luma_Only : Boolean;
   procedure Public_Rejection (Test : in out Fixture);
   procedure Public_Rejection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : C.Mat;
   begin
      Reject (Empty, Luma_Only);
      Reject (Bad (ND => True), Luma_Only);
      Reject (Bad (Depth => C.UInt16), Luma_Only);
      Reject (Bad (Depth => C.Float32), Luma_Only);
      Reject (Bad (Channels => 1), Luma_Only);
      Reject (Bad (Channels => 3), Luma_Only);
   end Public_Rejection;
   procedure J0 is new Public_Rejection (False);
   procedure J1 is new Public_Rejection (True);

   generic
      Width : Positive;
   procedure Odd_Width (Test : in out Fixture);
   procedure Odd_Width (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant C.Mat := Bad (Width);
   begin
      Reject (Source, False);
      Reject (Source, True);
   end Odd_Width;
   procedure W1 is new Odd_Width (1);
   procedure W3 is new Odd_Width (3);
   procedure W5 is new Odd_Width (5);

   function Address is new
     Ada.Unchecked_Conversion
       (C.Module_Interop.Input_Mat_Handle,
        System.Address);
   function Address is new
     Ada.Unchecked_Conversion
       (C.Module_Interop.Output_Mat_Handle,
        System.Address);
   function Raw_Decode
     (S, D : System.Address; Layout, Output : Interfaces.Integer_32)
      return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_decode_yuv422";
   function Raw_Luma
     (S, D : System.Address; Layout : Interfaces.Integer_32)
      return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_imgproc_extract_yuv422_luma";

   procedure Raw_Call
     (Source      : C.Mat;
      Destination : in out C.Mat;
      Layout      : Interfaces.Integer_32;
      Output      : Interfaces.Integer_32 := 0;
      Luma_Only   : Boolean := False;
      Expected    : Interfaces.Integer_32 := 4;
      Nulls       : Natural := 0;
      Same_Handle : Boolean := False)
   is
      Status : Interfaces.Integer_32 := -1;
      procedure Input (S : C.Module_Interop.Input_Mat_Handle) is
         procedure Publish (D : C.Module_Interop.Output_Mat_Handle) is
            SA : constant System.Address :=
              (if Nulls = 1
               then System.Null_Address
               elsif Same_Handle
               then Address (D)
               else Address (S));
            DA : constant System.Address :=
              (if Nulls = 2 then System.Null_Address else Address (D));
         begin
            Status :=
              (if Luma_Only
               then Raw_Luma (SA, DA, Layout)
               else Raw_Decode (SA, DA, Layout, Output));
         end Publish;
      begin
         C.Module_Interop.With_Output_Handle (Destination, Publish'Access);
      end Input;
   begin
      C.Module_Interop.With_Input_Handle (Source, Input'Access);
      AUnit.Assertions.Assert (Status = Expected, "raw YUV422 status");
   end Raw_Call;

   generic
      Luma_Only : Boolean;
   procedure Raw_Atomic (Test : in out Fixture);
   procedure Raw_Atomic (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant C.Mat := Frame (IP.UYVY);
      Empty  : C.Mat;
      D      : C.Mat := Bad (Channels => 1);
      Shared : constant C.Mat := D;
      procedure Check
        (S      : C.Mat;
         Layout : Interfaces.Integer_32 := 0;
         Output : Interfaces.Integer_32 := 0;
         Nulls  : Natural := 0)
      is
         Before : constant C.Mat := D.Clone;
         Saved  : constant C.Mat := S.Clone;
      begin
         Raw_Call (S, D, Layout, Output, Luma_Only, Nulls => Nulls);
         Bytes.Equal (D, Before);
         Bytes.Preserved (S, Saved);
         Bytes.Set_Byte (D, 0, 0, 71);
         AUnit.Assertions.Assert
           (Bytes.Byte (Shared, 0, 0) = 71, "failure storage identity");
         Bytes.Set_Byte (D, 0, 0, 37);
      end Check;
   begin
      Check (Source, -1);
      Check (Source, 3);
      if not Luma_Only then
         Check (Source, Output => -1);
         Check (Source, Output => 4);
         Check (Bad (1));
         Check (Bad (3));
         Check (Bad (5));
      end if;
      Check (Empty);
      Check (Bad (ND => True));
      Check (Bad (Depth => C.UInt16));
      Check (Bad (Depth => C.Float32));
      Check (Bad (Channels => 1));
      Check (Bad (Channels => 3));
      Check (Source, Nulls => 1);
      Check (Source, Nulls => 2);
      Raw_Call (Source, D, 0, Luma_Only => Luma_Only, Expected => 0);
      Bytes.Equal
        (D,
         (if Luma_Only
          then IP.Extract_YUV422_Luma (Source, IP.UYVY)
          else IP.Decode_YUV422 (Source, IP.UYVY)));
      AUnit.Assertions.Assert
        (Bytes.Byte (Shared, 0, 0) = 37, "successful publication rebinds");
      if Luma_Only then
         declare
            Odd : constant C.Mat := Bad (3);
         begin
            Raw_Call (Odd, D, 0, Luma_Only => True, Expected => 0);
            Bytes.Equal (D, Odd.Extract_Channel (1));
         end;
      end if;
   end Raw_Atomic;
   procedure A0 is new Raw_Atomic (False);
   procedure A1 is new Raw_Atomic (True);

   procedure Aliasing (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Layout in IP.YUV422_Layout loop
         declare
            S : constant C.Mat := Frame (Layout);
         begin
            for Output in IP.YUV422_Color_Output loop
               declare
                  D      : C.Mat := S.Clone;
                  Shared : constant C.Mat := D;
               begin
                  Raw_Call
                    (S,
                     D,
                     Interfaces.Integer_32 (IP.YUV422_Layout'Pos (Layout)),
                     Interfaces.Integer_32
                       (IP.YUV422_Color_Output'Pos (Output)),
                     Expected    => 0,
                     Same_Handle => True);
                  Bytes.Equal (D, IP.Decode_YUV422 (S, Layout, Output));
                  Bytes.Equal (Shared, S);
               end;
            end loop;
            declare
               D : C.Mat := S.Clone;
            begin
               Raw_Call
                 (S,
                  D,
                  Interfaces.Integer_32 (IP.YUV422_Layout'Pos (Layout)),
                  Luma_Only   => True,
                  Expected    => 0,
                  Same_Handle => True);
               Bytes.Equal (D, IP.Extract_YUV422_Luma (S, Layout));
            end;
         end;
      end loop;
   end Aliasing;

   procedure Wide_Frame (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Width  : constant Positive := 322;
      Height : constant Positive := 240;
   begin
      --  Cross CPU SIMD/tail and signed scheduling threshold with a small
      --  real frame, using direct typed access to keep assertions inexpensive.
      for Layout in IP.YUV422_Layout loop
         declare
            S : constant C.Mat :=
              Frame (Layout, Width => Width, Height => Height);
         begin
            for Output in IP.YUV422_Color_Output loop
               declare
                  D   : constant C.Mat := IP.Decode_YUV422 (S, Layout, Output);
                  RGB : constant Boolean :=
                    Output in IP.RGB_Output | IP.RGBA_Output;
               begin
                  for Row in 0 .. Height - 1 loop
                     for Column in 0 .. Width - 1 loop
                        declare
                           E : constant Bytes.RGB :=
                             (if Column mod 2 = 0
                              then (213, 54, 21)
                              else (255, 147, 114));
                           B : constant OpenCV.UInt8_Value :=
                             OpenCV.UInt8_Value (if RGB then E.R else E.B);
                           R : constant OpenCV.UInt8_Value :=
                             OpenCV.UInt8_Value (if RGB then E.B else E.R);
                        begin
                           if D.Channels = 3 then
                              declare
                                 P : constant C.UInt8_Vec3.Vector :=
                                   C.UInt8_Vec3_Access.Get (D, Row, Column);
                                 use type C.UInt8_Vec3.Vector;
                              begin
                                 AUnit.Assertions.Assert
                                   (P = (B, OpenCV.UInt8_Value (E.G), R),
                                    "SIMD/tail pair and parallel rows C3");
                              end;
                           else
                              declare
                                 P : constant C.UInt8_Vec4.Vector :=
                                   C.UInt8_Vec4_Access.Get (D, Row, Column);
                                 use type C.UInt8_Vec4.Vector;
                              begin
                                 AUnit.Assertions.Assert
                                   (P = (B, OpenCV.UInt8_Value (E.G), R, 255),
                                    "SIMD/tail pair and parallel rows C4");
                              end;
                           end if;
                        end;
                     end loop;
                  end loop;
               end;
            end loop;
         end;
      end loop;
   end Wide_Frame;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      procedure Add (Name : String; Test : Caller.Test_Method) is
      begin
         Result.Add_Test (Caller.Create (Name, Test));
      end Add;
   begin
      Add ("UYVY black all outputs", D00'Access);
      Add ("UYVY white all outputs", D01'Access);
      Add ("UYVY independent asymmetric pair all outputs", D02'Access);
      Add ("UYVY out-of-studio saturation all outputs", D03'Access);
      Add ("YUY2 black all outputs", D10'Access);
      Add ("YUY2 white all outputs", D11'Access);
      Add ("YUY2 independent asymmetric pair all outputs", D12'Access);
      Add ("YUY2 out-of-studio saturation all outputs", D13'Access);
      Add ("YVYU black all outputs", D20'Access);
      Add ("YVYU white all outputs", D21'Access);
      Add ("YVYU independent asymmetric pair all outputs", D22'Access);
      Add ("YVYU out-of-studio saturation all outputs", D23'Access);
      Add ("UYVY exact patterned chroma-independent luma", L0'Access);
      Add ("YUY2 exact patterned chroma-independent luma", L1'Access);
      Add ("YVYU exact patterned chroma-independent luma", L2'Access);
      Add ("UYVY minimum 2x1 all outputs and luma", M0'Access);
      Add ("YUY2 minimum 2x1 all outputs and luma", M1'Access);
      Add ("YVYU minimum 2x1 all outputs and luma", M2'Access);
      Add ("UYVY strided standalone Region and luma", R0'Access);
      Add ("YUY2 strided standalone Region and luma", R1'Access);
      Add ("YVYU strided standalone Region and luma", R2'Access);
      Add ("YUV422 fresh C4 ownership", O0'Access);
      Add ("YUV422 fresh luma ownership", O1'Access);
      Add ("YUV422 decode public type rejection", J0'Access);
      Add ("YUV422 luma public type rejection", J1'Access);
      Add ("YUV422 W=1 public rejection", W1'Access);
      Add ("YUV422 W=3 public rejection", W3'Access);
      Add ("YUV422 W=5 public rejection", W5'Access);
      Add ("YUV422 raw decode atomicity and recovery", A0'Access);
      Add ("YUV422 raw luma atomicity and recovery", A1'Access);
      Add ("YUV422 raw same-handle publication", Aliasing'Access);
      Add ("YUV422 SIMD tail and parallel pair semantics", Wide_Frame'Access);
      return Result'Access;
   end Suite;
end YUV422_Conversion_Tests;
