with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Ada.Unchecked_Conversion;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Module_Interop;
with OpenCV.Core.UInt8_Access;
with OpenCV.Core.UInt8_Vec3;
with OpenCV.Core.UInt8_Vec3_Access;
with OpenCV.Core.Float32_Access;
with OpenCV.Core.Float64_Access;
with OpenCV.Core.UInt16_Access;
with OpenCV.Image_Processing;
with OpenCV.Image_Processing.Internal.C_API;

package body Polar_Transform_Tests is
   package IP renames OpenCV.Image_Processing;
   package C_API renames OpenCV.Image_Processing.Internal.C_API;
   use type C_API.Status;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Core.UInt8_Vec3.Vector;
   use type OpenCV.Core.Depth_Type;
   use type IP.Interpolation_Method;
   function Float32_From_Bits is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_32, OpenCV.Float32_Value);
   function Float64_From_Bits is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, OpenCV.Float64_Value);
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Image return OpenCV.Core.Mat is
      Mat : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 1));
   begin
      OpenCV.Core.Set_To (Mat, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (Mat, 4, 6, 200);
      return Mat;
   end Image;

   procedure Assert_Error (Attempt : not null access procedure) is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, "expected OpenCV_Error");
   end Assert_Error;

   procedure Forward_Mapping (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Image;
      Dest   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 2, (OpenCV.Core.Float32, 1));
   begin
      IP.Warp_Polar
        (Source,
         Dest,
         (4.0, 4.0),
         4.0,
         (8, 16),
         Interpolation => IP.Nearest_Neighbor);
      AUnit.Assertions.Assert
        (Dest.Rows = 16 and then Dest.Columns = 8, "explicit output geometry");
      AUnit.Assertions.Assert
        (Dest.Depth = OpenCV.Core.UInt8, "destination rebind type");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Dest, 0, 4) = 200,
         "forward radial spoke position");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Source, 4, 6) = 200,
         "source remains unchanged");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Dest, 0, 7) = 0, "outlier zero fill");
   end Forward_Mapping;

   procedure Log_And_Inverse (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source                       : constant OpenCV.Core.Mat := Image;
      Linear_Map, Log_Map, Rebuilt : OpenCV.Core.Mat;
   begin
      IP.Warp_Polar
        (Source,
         Linear_Map,
         (4.0, 4.0),
         4.0,
         (16, 32),
         Interpolation => IP.Nearest_Neighbor);
      IP.Warp_Polar
        (Source,
         Log_Map,
         (4.0, 4.0),
         4.0,
         (16, 32),
         Mapping       => IP.Logarithmic_Polar,
         Interpolation => IP.Nearest_Neighbor);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Linear_Map, 0, 8) = 200, "linear rho");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Log_Map, 0, 8) /= 200,
         "log rho differs");
      IP.Warp_Polar
        (Linear_Map,
         Rebuilt,
         (4.0, 4.0),
         4.0,
         (9, 9),
         Direction     => IP.Polar_To_Cartesian,
         Interpolation => IP.Nearest_Neighbor);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Rebuilt, 4, 6) = 200,
         "inverse destination-local center");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Rebuilt, 0, 0) = 0,
         "inverse outlier zero fill");
      IP.Warp_Polar
        (Log_Map,
         Rebuilt,
         (4.0, 4.0),
         4.0,
         (9, 9),
         Mapping       => IP.Logarithmic_Polar,
         Direction     => IP.Polar_To_Cartesian,
         Interpolation => IP.Nearest_Neighbor);
      AUnit.Assertions.Assert (Rebuilt.Rows = 9, "log inverse geometry");
   end Log_And_Inverse;

   procedure Region_And_Interpolation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (14, 14, (OpenCV.Core.UInt8, 1));
      View   : OpenCV.Core.Mat :=
        Parent.Region ((X => 2, Y => 3, Width => 9, Height => 9));
      Dest   : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 0.0));
      OpenCV.Core.UInt8_Access.Set (View, 4, 6, 200);
      for Method in IP.Interpolation_Method loop
         if Method not in IP.Area | IP.Linear_Exact then
            IP.Warp_Polar
              (View, Dest, (4.0, 4.0), 4.0, (8, 16), Interpolation => Method);
            AUnit.Assertions.Assert
              (Dest.Rows = 16, "Region/interpolation works");
         end if;
      end loop;
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Dest, 0, 4) > 0,
         "Region-local center samples feature");
   end Region_And_Interpolation;

   procedure Inverse_Region_Wrap (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Parent : OpenCV.Core.Mat :=
        OpenCV.Core.Create (6, 8, (OpenCV.Core.UInt8, 1));
      View   : OpenCV.Core.Mat :=
        Parent.Region ((X => 0, Y => 1, Width => 8, Height => 4));
      Dest   : OpenCV.Core.Mat;
   begin
      OpenCV.Core.Set_To (Parent, (others => 210.0));
      for X in 0 .. 7 loop
         OpenCV.Core.UInt8_Access.Set (View, 0, X, 40);
         OpenCV.Core.UInt8_Access.Set (View, 3, X, 80);
      end loop;
      IP.Warp_Polar
        (View,
         Dest,
         (-1.0, 0.1),
         4.0,
         (1, 1),
         Direction     => IP.Polar_To_Cartesian,
         Interpolation => IP.Linear);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Dest, 0, 0) in 40 .. 80,
         "inverse wrap uses Region's first/last rows, not parent neighbor");
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Access.Get (Parent, 5, 0) = 210,
         "parent neighboring row remains distinct");
   end Inverse_Region_Wrap;

   procedure Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);
      Source     : OpenCV.Core.Mat := Image;
      Dest       : OpenCV.Core.Mat := Image;
      Bad_Center : constant OpenCV.Float32_Value :=
        Float32_From_Bits (16#7F80_0000#);
      Bad_Radius : constant OpenCV.Float64_Value :=
        Float64_From_Bits (16#7FF0_0000_0000_0000#);
      procedure Try_Center is
      begin
         IP.Warp_Polar (Source, Dest, (Bad_Center, 4.0), 4.0, (8, 16));
      end Try_Center;
      procedure Try_Radius is
      begin
         IP.Warp_Polar (Source, Dest, (4.0, 4.0), Bad_Radius, (8, 16));
      end Try_Radius;
      procedure Try_Area is
      begin
         IP.Warp_Polar
           (Source, Dest, (4.0, 4.0), 4.0, (8, 16), Interpolation => IP.Area);
      end Try_Area;
      procedure Try_Log is
      begin
         IP.Warp_Polar
           (Source,
            Dest,
            (4.0, 4.0),
            1.0,
            (8, 16),
            Mapping => IP.Logarithmic_Polar);
      end Try_Log;
      procedure Try_Zero is
      begin
         IP.Warp_Polar (Source, Dest, (4.0, 4.0), 4.0, (0, 16));
      end Try_Zero;
      procedure Try_Alias is
      begin
         IP.Warp_Polar (Source, Source, (4.0, 4.0), 4.0, (8, 16));
      end Try_Alias;
   begin
      Assert_Error (Try_Area'Access);
      Assert_Error (Try_Center'Access);
      Assert_Error (Try_Radius'Access);
      Assert_Error (Try_Log'Access);
      Assert_Error (Try_Zero'Access);
      Assert_Error (Try_Alias'Access);
      AUnit.Assertions.Assert
        (Dest.Rows = 9 and then Dest.Columns = 9,
         "validation preserves destination");
   end Validation;

   procedure Raw_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Image;
      Dest   : OpenCV.Core.Mat;
      Status : C_API.Status;
      procedure Input (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Output
           (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            for Selector in 0 .. 2 loop
               Status :=
                 C_API.Warp_Polar
                   (Handle,
                    Target,
                    4.0,
                    4.0,
                    4.0,
                    8,
                    16,
                    (if Selector = 0 then 9 else 0),
                    (if Selector = 1 then 9 else 0),
                    (if Selector = 2 then 9 else 1));
               AUnit.Assertions.Assert
                 (Status = C_API.Error_Invalid_Argument,
                  "malformed selector rejected");
            end loop;
            Status :=
              C_API.Warp_Polar
                (Handle, Target, 1.0E+9, 4.0, 4.0, 8, 16, 0, 0, 1);
            AUnit.Assertions.Assert
              (Status = C_API.Error_Invalid_Argument,
               "forward remap coordinate bound");
            Status :=
              C_API.Warp_Polar
                (Handle, Target, 4.0, 4.0, 1.0E-12, 8, 16, 0, 1, 1);
            AUnit.Assertions.Assert
              (Status = C_API.Error_Invalid_Argument,
               "inverse tiny scale bound");
            Status :=
              C_API.Warp_Polar
                (Handle, Target, 4.0, 4.0, 1.000000000000001, 8, 16, 1, 1, 1);
            AUnit.Assertions.Assert
              (Status = C_API.Error_Invalid_Argument,
               "inverse near-unit log radius bound");
            Status :=
              C_API.Warp_Polar
                (Handle,
                 Target,
                 6.0E-8,
                 0.0,
                 1.000000000000012,
                 1,
                 1,
                 1,
                 1,
                 1);
            AUnit.Assertions.Assert
              (Status = C_API.Error_Invalid_Argument,
               "inverse semilog Float32 +1 rounding hazard");
            Status :=
              C_API.Warp_Polar (Handle, Target, 4.0, 4.0, 4.0, 8, 16, 0, 0, 1);
            AUnit.Assertions.Assert
              (Status = C_API.Success, "success after raw failure");
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Dest, Output'Access);
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
   end Raw_Safety;

   procedure Depths_And_Channels (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Dest     : OpenCV.Core.Mat;
      Color    : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt8, 3));
      Unsigned : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.UInt16, 1));
      Single   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.Float32, 1));
      Double   : OpenCV.Core.Mat :=
        OpenCV.Core.Create (9, 9, (OpenCV.Core.Float64, 1));
   begin
      OpenCV.Core.Set_To (Color, (others => 0.0));
      OpenCV.Core.UInt8_Vec3_Access.Set (Color, 4, 6, (10, 20, 30));
      IP.Warp_Polar
        (Color,
         Dest,
         (4.0, 4.0),
         4.0,
         (8, 16),
         Interpolation => IP.Nearest_Neighbor);
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt8_Vec3_Access.Get (Dest, 0, 4) = (10, 20, 30),
         "independent color channels");
      OpenCV.Core.Set_To (Unsigned, (others => 0.0));
      OpenCV.Core.UInt16_Access.Set (Unsigned, 4, 6, 1234);
      IP.Warp_Polar (Unsigned, Dest, (4.0, 4.0), 4.0, (8, 16));
      AUnit.Assertions.Assert
        (OpenCV.Core.UInt16_Access.Get (Dest, 0, 4) = 1234, "UInt16 retained");
      OpenCV.Core.Set_To (Single, (others => 0.0));
      OpenCV.Core.Float32_Access.Set (Single, 4, 6, 2.5);
      IP.Warp_Polar (Single, Dest, (4.0, 4.0), 4.0, (8, 16));
      AUnit.Assertions.Assert
        (OpenCV.Core.Float32_Access.Get (Dest, 0, 4) = 2.5,
         "Float32 retained");
      OpenCV.Core.Set_To (Double, (others => 0.0));
      OpenCV.Core.Float64_Access.Set (Double, 4, 6, 3.5);
      IP.Warp_Polar (Double, Dest, (4.0, 4.0), 4.0, (8, 16));
      AUnit.Assertions.Assert
        (OpenCV.Core.Float64_Access.Get (Dest, 0, 4) = 3.5,
         "Float64 retained");
   end Depths_And_Channels;

   procedure Packed_Inverse_Stride (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (2, 8_192, (OpenCV.Core.UInt8, 4));
      Dest   : OpenCV.Core.Mat;
      Status : C_API.Status;
      procedure Input (Handle : OpenCV.Core.Module_Interop.Input_Mat_Handle) is
         procedure Output
           (Target : OpenCV.Core.Module_Interop.Output_Mat_Handle) is
         begin
            Status :=
              C_API.Warp_Polar (Handle, Target, 0.0, 0.0, 4.0, 2, 2, 0, 1, 1);
         end Output;
      begin
         OpenCV.Core.Module_Interop.With_Output_Handle (Dest, Output'Access);
      end Input;
   begin
      OpenCV.Core.Module_Interop.With_Input_Handle (Source, Input'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "packed C4 stride 8192*4 reaches 0x8000 hazard");
   end Packed_Inverse_Stride;

   procedure Alias_And_Boundaries (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source : constant OpenCV.Core.Mat := Image;
      Alias  : OpenCV.Core.Mat := Source;
      Parent : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (12, 12, (OpenCV.Core.UInt8, 1));
      First  : constant OpenCV.Core.Mat :=
        Parent.Region ((X => 1, Y => 1, Width => 8, Height => 8));
      Second : OpenCV.Core.Mat :=
        Parent.Region ((X => 2, Y => 2, Width => 8, Height => 8));
      Dest   : OpenCV.Core.Mat;
      procedure Shallow is
      begin
         IP.Warp_Polar (Source, Alias, (4.0, 4.0), 4.0, (8, 16));
      end Shallow;
      procedure Overlap is
      begin
         IP.Warp_Polar (First, Second, (4.0, 4.0), 4.0, (8, 16));
      end Overlap;
      procedure Zero_Radius is
      begin
         IP.Warp_Polar (Source, Dest, (4.0, 4.0), 0.0, (8, 16));
      end Zero_Radius;
      procedure Log_Below_One is
      begin
         IP.Warp_Polar
           (Source,
            Dest,
            (4.0, 4.0),
            0.5,
            (8, 16),
            Mapping => IP.Logarithmic_Polar);
      end Log_Below_One;
      procedure Bad_Width is
      begin
         IP.Warp_Polar (Source, Dest, (4.0, 4.0), 4.0, (32_767, 2));
      end Bad_Width;
      procedure Bad_Height is
      begin
         IP.Warp_Polar (Source, Dest, (4.0, 4.0), 4.0, (2, 32_767));
      end Bad_Height;
      procedure Zero_Height is
      begin
         IP.Warp_Polar (Source, Dest, (4.0, 4.0), 4.0, (2, 0));
      end Zero_Height;
   begin
      Assert_Error (Shallow'Access);
      Assert_Error (Overlap'Access);
      Assert_Error (Zero_Radius'Access);
      Assert_Error (Log_Below_One'Access);
      Assert_Error (Bad_Width'Access);
      Assert_Error (Bad_Height'Access);
      Assert_Error (Zero_Height'Access);
      AUnit.Assertions.Assert
        (Alias.Rows = 9 and then Second.Rows = 8,
         "overlapping destination headers remain unchanged");
   end Alias_And_Boundaries;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Polar forward geometry and zero fill", Forward_Mapping'Access));
      Result.Add_Test
        (Caller.Create ("Polar log and inverse", Log_And_Inverse'Access));
      Result.Add_Test
        (Caller.Create
           ("Polar Region and interpolation",
            Region_And_Interpolation'Access));
      Result.Add_Test
        (Caller.Create
           ("Polar inverse Region wrap isolation",
            Inverse_Region_Wrap'Access));
      Result.Add_Test (Caller.Create ("Polar validation", Validation'Access));
      Result.Add_Test
        (Caller.Create ("Polar raw ABI safety", Raw_Safety'Access));
      Result.Add_Test
        (Caller.Create
           ("Polar depth and channels", Depths_And_Channels'Access));
      Result.Add_Test
        (Caller.Create
           ("Polar inverse packed stride", Packed_Inverse_Stride'Access));
      Result.Add_Test
        (Caller.Create
           ("Polar alias and size boundaries", Alias_And_Boundaries'Access));
      return Result'Access;
   end Suite;
end Polar_Transform_Tests;
