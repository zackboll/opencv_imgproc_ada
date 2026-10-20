with AUnit.Test_Suites;

package Connected_Component_Tests is
   function Suite
     (Only_Parallel : Boolean := False)
      return AUnit.Test_Suites.Access_Test_Suite;
end Connected_Component_Tests;
