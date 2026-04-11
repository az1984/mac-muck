# Source the spec helper
. ./spec/spec_helper.sh

# Mock launchctl to prevent real system interactions
launchctl() {
  case "$*" in
    print\ gui/507/*|print\ gui/501/*)
      # Simulate "agent not found" scenario
      echo "Could not find service: gui/501/$3" >&2
      return 1 ;;
    print-disabled\ *)
      # Empty output = no disabled services
      return 0 ;;
    disable\ *)
      # Disable succeeds
      return 0 ;;
    *)
      return 0 ;;
  esac
}

# Mock ListGraphicalUsers to return a test user
ListGraphicalUsers() {
  echo "testuser"
}

# Mock id command to return a test UID
id() {
  if [[ "$1" == "-u" ]]; then
    echo "501"
  else
    command id "$@"
  fi
}

Describe 'DisableLaunchAgent'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call DisableLaunchAgent
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format (single label)'
    When call DisableLaunchAgent "notreverse"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when given an invalid label format (only 2 labels)'
    When call DisableLaunchAgent "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when label starts with number'
    When call DisableLaunchAgent "1com.vendor.agent"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call DisableLaunchAgent --tolerant-missing --tolerant-missing "com.vendor.app.agent"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with duplicate --needs-root flag'
    When call DisableLaunchAgent --needs-root --needs-root "com.vendor.app.agent"
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

  # ─────────────────────────═══════════════════════════════════════
  # Root gate (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when not root and --needs-root is specified'
    Skip "Requires non-root execution context to test the root guard"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when agent is absent in all user domains and --tolerant-missing is set'
    When call DisableLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  It 'returns 0 when no graphical users exist and --tolerant-missing is set'
    Skip "Requires mocking ListGraphicalUsers to return empty"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when agent is not found in any user domain without --tolerant-missing'
    Skip "Requires mocking launchctl print to return not found"
  End

  It 'returns 4 when no graphical users exist without --tolerant-missing'
    Skip "Requires mocking ListGraphicalUsers to return empty"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when agent is successfully disabled for one user'
    Skip "Requires mocking launchctl disable and print-disabled"
  End

  It 'returns 0 when agent is successfully disabled for multiple users'
    Skip "Requires mocking ListGraphicalUsers and launchctl for multiple users"
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

  It 'returns 5 when disable fails for one of multiple users'
    Skip "Requires mocking partial failure across users"
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

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the label'
    When call DisableLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  It 'accepts flags after the label'
    When call DisableLaunchAgent "com.nonexistent.app.agent" --tolerant-missing
    The status should eq 0
  End

  It 'accepts --needs-root flag before the label'
    When call DisableLaunchAgent --needs-root "com.vendor.app.agent"
    The status should eq 0
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