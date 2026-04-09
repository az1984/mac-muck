Describe 'DisableLaunchAgent'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call DisableLaunchAgent
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format'
    When call DisableLaunchAgent "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call DisableLaunchAgent --tolerant-missing --tolerant-missing "com.vendor.app.agent"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call DisableLaunchAgent --bogus "com.vendor.app.agent"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with multiple non-flag arguments'
    When call DisableLaunchAgent "com.vendor.app.agent" "com.vendor.app.other"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when agent is absent in all user domains and --tolerant-missing is set'
    When call DisableLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  # --- Order-agnostic args ---
  It 'accepts flags before the label'
    When call DisableLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  It 'accepts flags after the label'
    When call DisableLaunchAgent "com.nonexistent.app.agent" --tolerant-missing
    The status should eq 0
  End
End
