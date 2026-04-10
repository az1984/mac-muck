Describe 'UnloadAndRemoveLaunchDaemon'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call UnloadAndRemoveLaunchDaemon
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format (single label)'
    When call UnloadAndRemoveLaunchDaemon "notreverse"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when given an invalid label format (only 2 labels)'
    When call UnloadAndRemoveLaunchDaemon "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when label starts with number'
    When call UnloadAndRemoveLaunchDaemon "1com.vendor.daemon"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call UnloadAndRemoveLaunchDaemon --tolerant-missing --tolerant-missing "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with duplicate --needs-root flag'
    When call UnloadAndRemoveLaunchDaemon --needs-root --needs-root "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call UnloadAndRemoveLaunchDaemon --bogus "com.vendor.app.daemon"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with multiple non-flag arguments'
    When call UnloadAndRemoveLaunchDaemon "com.vendor.app.daemon" "com.vendor.app.other"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root check (rc 3)
  # ─────────────────────────═══════════════════════════════════════
  # Daemons always require root

  It 'returns 3 when not run as root'
    Skip "Requires non-root execution context to test the root guard"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when plist not found and --tolerant-missing is set'
    Skip "Requires root execution context to check plist"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when plist not found without --tolerant-missing'
    Skip "Requires root execution context to check plist"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when daemon plist is successfully removed'
    Skip "Requires mocking launchctl and SafeDelete"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when daemon still running after bootout'
    Skip "Requires mocking VerifyServiceUnloaded to return still running"
  End

  It 'returns 5 when SafeDelete fails to remove plist'
    Skip "Requires mocking SafeDelete failure"
  End

  It 'returns 5 when plist still present after deletion attempt'
    Skip "Requires mocking plist persistence after delete"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when launchctl is not found'
    Skip "Requires mocking missing launchctl binary"
  End

  It 'returns 1 when VerifyServiceUnloaded function is not defined'
    Skip "Requires mocking missing VerifyServiceUnloaded function"
  End

  It 'returns 1 when SafeDelete function is not defined'
    Skip "Requires mocking missing SafeDelete function"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts --tolerant-missing before the label'
    When call UnloadAndRemoveLaunchDaemon --tolerant-missing "com.nonexistent.app.daemon"
    The status should eq 0
  End

  It 'accepts --tolerant-missing after the label'
    When call UnloadAndRemoveLaunchDaemon "com.nonexistent.app.daemon" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles labels with underscores correctly'
    Skip "Requires mocking launchctl with underscore label"
  End

  It 'handles labels with hyphens correctly'
    Skip "Requires mocking launchctl with hyphen label"
  End

End
