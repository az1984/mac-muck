Describe 'DisableLaunchDaemon'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call DisableLaunchDaemon
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format'
    When call DisableLaunchDaemon "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate flags'
    When call DisableLaunchDaemon --tolerant-missing --tolerant-missing "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call DisableLaunchDaemon --bogus "com.vendor.app.daemon"
    The status should eq 2
    The output should include "unknown flag"
  End

  # --- Root check (rc 3) ---
  # Daemons always require root — no --needs-root flag needed
  # This test should be run as non-root to verify the guard
  It 'returns 3 when not run as root'
    Skip "Requires non-root execution context to test the root guard"
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when daemon is absent in system domain and --tolerant-missing is set'
    # Requires root to even query launchctl for system domain
    Skip "Requires root execution context"
  End
End
