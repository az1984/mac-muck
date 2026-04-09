Describe 'UnloadAndRemoveLaunchDaemon'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call UnloadAndRemoveLaunchDaemon
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format'
    When call UnloadAndRemoveLaunchDaemon "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with unknown flag'
    When call UnloadAndRemoveLaunchDaemon --bogus "com.vendor.app.daemon"
    The status should eq 2
    The output should include "unknown flag"
  End

  # --- Root check (rc 3) ---
  It 'returns 3 when not run as root'
    Skip "Requires non-root execution context to test the root guard"
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when plist not found and --tolerant-missing is set'
    # Note: requires root since daemons enforce root before checking plist
    Skip "Requires root execution context"
  End

  # --- Strict missing (rc 4 when absent) ---
  It 'returns 4 when plist not found without --tolerant-missing'
    Skip "Requires root execution context"
  End
End
