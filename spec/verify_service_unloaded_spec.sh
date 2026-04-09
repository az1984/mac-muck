Describe 'VerifyServiceUnloaded'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call VerifyServiceUnloaded
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given more than one argument'
    When call VerifyServiceUnloaded "system/com.vendor.daemon" "extra"
    The status should eq 2
    The output should include "Bad input"
  End

  # --- Functional tests (require macOS with launchctl) ---
  It 'returns 0 for a service that does not exist'
    # launchctl print should return "Could not find service" for a nonexistent label
    Skip "Requires macOS with launchctl (not available in CI)"
  End

  It 'returns 1 for a service that is running'
    Skip "Requires macOS with a known running service to test against"
  End
End
