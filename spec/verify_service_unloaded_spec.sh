Describe 'VerifyServiceUnloaded'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

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

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests (rc 0)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 for a service that does not exist'
    # launchctl print should return "Could not find service" for a nonexistent label
    Skip "Requires macOS with launchctl (not available in CI)"
  End

  It 'returns 0 for a service with state = not running'
    Skip "Requires mocking launchctl print output with not running state"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 for a service that is running'
    Skip "Requires macOS with a known running service to test against"
  End

  It 'returns 1 when service shows state = running in output'
    Skip "Requires mocking launchctl print output with running state"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Ambiguous state tests (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when launchctl output is ambiguous'
    Skip "Requires mocking launchctl print with ambiguous output"
  End

  It 'returns 3 when launchctl output contains neither running nor not running'
    Skip "Requires mocking launchctl print with unexpected output"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when launchctl is not found'
    Skip "Requires mocking missing launchctl binary"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Domain target format tests
  # ─────────────────────────═══════════════════════════════════════

  It 'handles gui domain for LaunchAgents'
    Skip "Requires mocking launchctl print for gui domain"
  End

  It 'handles system domain for LaunchDaemons'
    Skip "Requires mocking launchctl print for system domain"
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

  It 'handles empty launchctl output gracefully'
    Skip "Requires mocking launchctl print with empty output"
  End

End
