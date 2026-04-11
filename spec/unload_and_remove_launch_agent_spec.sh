. ./spec/spec_helper.sh
Describe 'UnloadAndRemoveLaunchAgent'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call UnloadAndRemoveLaunchAgent
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format (single label)'
    When call UnloadAndRemoveLaunchAgent "notreverse"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when given an invalid label format (only 2 labels)'
    When call UnloadAndRemoveLaunchAgent "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when label starts with number'
    When call UnloadAndRemoveLaunchAgent "1com.vendor.agent"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call UnloadAndRemoveLaunchAgent --tolerant-missing --tolerant-missing "com.vendor.app.agent"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with duplicate --needs-root flag'
    When call UnloadAndRemoveLaunchAgent --needs-root --needs-root "com.vendor.app.agent"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call UnloadAndRemoveLaunchAgent --bogus "com.vendor.app.agent"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with multiple non-flag arguments'
    When call UnloadAndRemoveLaunchAgent "com.vendor.app.agent" "com.vendor.app.other"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root gate (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when not root and --needs-root is specified'
    Skip "Requires non-root execution context to test the root guard"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when no plists found and --tolerant-missing is set'
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  It 'returns 0 when no graphical users exist and --tolerant-missing is set'
    Skip "Requires mocking ListGraphicalUsers to return empty"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when no plists found without --tolerant-missing'
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent"
    The status should eq 4
    The output should include "No LaunchAgent plists"
  End

  It 'returns 4 when no graphical users exist without --tolerant-missing'
    Skip "Requires mocking ListGraphicalUsers to return empty"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when system agent plist is successfully removed'
    Skip "Requires mocking launchctl and SafeDelete"
  End

  It 'returns 0 when user agent plist is successfully removed'
    Skip "Requires mocking ListGraphicalUsers, launchctl and SafeDelete"
  End

  It 'returns 0 when agent plist exists in both system and user locations'
    Skip "Requires mocking multiple plist locations"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when agent still running after bootout'
    Skip "Requires mocking VerifyServiceUnloaded to return still running"
  End

  It 'returns 5 when SafeDelete fails to remove plist'
    Skip "Requires mocking SafeDelete failure"
  End

  It 'returns 5 when plist still present after deletion attempt'
    Skip "Requires mocking plist persistence after delete"
  End

  It 'returns 5 when multiple operations fail'
    Skip "Requires mocking multiple operation failures"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when launchctl is not found'
    Skip "Requires mocking missing launchctl binary"
  End

  It 'returns 1 when ListGraphicalUsers function is not defined'
    Skip "Requires mocking missing ListGraphicalUsers function"
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
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  It 'accepts --tolerant-missing after the label'
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent" --tolerant-missing
    The status should eq 0
  End

  It 'accepts --needs-root flag before the label'
    Skip "Requires root execution context when --needs-root is specified"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'skips users when UID cannot be resolved'
    Skip "Requires mocking user without resolvable UID"
  End

  It 'handles labels with underscores correctly'
    Skip "Requires mocking launchctl with underscore label"
  End

  It 'handles labels with hyphens correctly'
    Skip "Requires mocking launchctl with hyphen label"
  End

End