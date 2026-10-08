with AUnit.Test_Suites;

package Subpixel_Patch_Tests is
   function Suite
     (Only_Adapter : Boolean := False; Only_Historical : Boolean := False)
      return AUnit.Test_Suites.Access_Test_Suite;
end Subpixel_Patch_Tests;
