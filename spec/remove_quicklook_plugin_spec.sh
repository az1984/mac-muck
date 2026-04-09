Describe 'RemoveQuickLookPlugin'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call RemoveQuickLookPlugin
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when path does not end in .qlgenerator'
    When call RemoveQuickLookPlugin "/Library/QuickLook/NotAPlugin.txt"
    The status should eq 2
    The output should include "Invalid"
  End

  It 'returns 2 when path is not absolute'
    When call RemoveQuickLookPlugin "relative/path/Plugin.qlgenerator"
    The status should eq 2
    The output should include "absolute"
  End

  It 'returns 2 with unknown flag'
    When call RemoveQuickLookPlugin --bogus "/Library/QuickLook/Test.qlgenerator"
    The status should eq 2
    The output should include "unknown flag"
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when plugin path does not exist and --tolerant-missing is set'
    When call RemoveQuickLookPlugin --tolerant-missing "/Library/QuickLook/NonExistent.qlgenerator"
    The status should eq 0
  End

  # --- Strict missing (rc 4 when absent) ---
  It 'returns 4 when plugin path does not exist without --tolerant-missing'
    When call RemoveQuickLookPlugin "/Library/QuickLook/NonExistent.qlgenerator"
    The status should eq 4
  End

  # --- Path guard ---
  It 'returns 2 when path is outside allowed QuickLook directories'
    When call RemoveQuickLookPlugin "/tmp/Evil.qlgenerator"
    The status should eq 2
    The output should include "not in a recognized QuickLook directory"
  End
End
