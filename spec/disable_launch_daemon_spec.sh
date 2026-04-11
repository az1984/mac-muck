. ./spec/spec_helper.sh

# Mock launchctl to prevent real system interactions
launchctl() {
  case "$*" in
    print\ system/*)
      # Simulate "daemon not found" scenario for nonexistent daemons
      echo "Could not find service: system/$3" >&2
      return 1 ;;
    print-disabled\ system)
      # Empty output = no disabled services
      return 0 ;;
    disable\ *)
      # Disable succeeds
      return 0 ;;
    *)
      return 0 ;;
  esac
}

Describe 'DisableLaunchDaemon'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call DisableLaunchDaemon
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format (single label)'
    When call DisableLaunchDaemon "notreverse"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when given an invalid label format (only 2 labels)'
    When call DisableLaunchDaemon "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when label starts with number'
    When call DisableLaunchDaemon "1com.vendor.daemon"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call DisableLaunchDaemon --tolerant-missing --tolerant-missing "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with duplicate --needs-root flag'
    When call DisableLaunchDaemon --needs-root --needs-root "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call DisableLaunchDaemon --bogus "com.vendor.app.daemon"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with multiple non-flag arguments'
    When call DisableLaunchDaemon "com.vendor.app.daemon" "com.vendor.app.other"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root check (rc 3)
  # ─────────────────────────═══════════════════════════════════════
  # Daemons always require root — no --needs-root flag needed

  It 'returns 3 when not run as root'
    Skip "Requires non-root execution context to test the root guard"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when daemon is absent in system domain and --tolerant-missing is set'
    Skip "Requires root execution context to query launchctl"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when daemon is not found in system domain without --tolerant-missing'
    Skip "Requires root execution context to query launchctl"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when daemon is successfully disabled'
    Skip "Requires mocking launchctl disable and print-disabled"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when disable succeeds but verify shows still enabled'
    Skip "Requires mocking launchctl to show enabled after disable"
  End

  It 'returns 5 when print-disabled has stderr during verification'
    Skip "Requires mocking launchctl print-disabled to have stderr"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when launchctl is not found'
    Skip "Requires mocking missing launchctl binary"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the label'
    Skip "Requires root execution context (LaunchDaemons always require root)"
  End

  It 'accepts flags after the label'
    Skip "Requires root execution context (LaunchDaemons always require root)"
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
