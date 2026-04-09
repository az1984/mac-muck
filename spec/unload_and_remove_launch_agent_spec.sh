Describe 'UnloadAndRemoveLaunchAgent'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call UnloadAndRemoveLaunchAgent
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format'
    When call UnloadAndRemoveLaunchAgent "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with unknown flag'
    When call UnloadAndRemoveLaunchAgent --bogus "com.vendor.app.agent"
    The status should eq 2
    The output should include "unknown flag"
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when no plists found and --tolerant-missing is set'
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  # --- Strict missing (rc 4 when absent) ---
  It 'returns 4 when no plists found without --tolerant-missing'
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent"
    The status should eq 4
  End

  # --- Order-agnostic args ---
  It 'accepts --tolerant-missing before the label'
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  It 'accepts --tolerant-missing after the label'
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent" --tolerant-missing
    The status should eq 0
  End
End
