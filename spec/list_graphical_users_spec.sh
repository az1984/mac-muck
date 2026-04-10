Describe 'ListGraphicalUsers'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when given an unknown flag'
    When call ListGraphicalUsers --bogus
    The status should eq 2
    The output should include "Unknown flag"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root gate (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when not root and --needs-root is specified'
    # This test should be run as non-root
    Skip "Requires non-root execution context to test the root guard"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path (rc 0)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 with no graphical users (empty output)'
    # Mock dscl to return no users
    Skip "Requires mocking dscl output"
  End

  It 'returns 0 and outputs one username per line'
    # Mock dscl to return test users
    Skip "Requires mocking dscl output"
  End

  It 'returns 0 and skips Shared account'
    # Mock dscl to include Shared
    Skip "Requires mocking dscl output"
  End

  It 'returns 0 and skips Guest account'
    # Mock dscl to include Guest
    Skip "Requires mocking dscl output"
  End

  It 'returns 0 and skips .localized account'
    # Mock dscl to include .localized
    Skip "Requires mocking dscl output"
  End

  It 'returns 0 and filters users with UID < 500 by default'
    # Mock dscl to include low-UID users
    Skip "Requires mocking dscl output"
  End

  It 'returns 0 and includes users with UID < 500 when --all is set'
    # Mock dscl to include low-UID users
    Skip "Requires mocking dscl output"
  End

  It 'returns 0 and skips users without valid home directory'
    # Mock dscl to include user with missing home
    Skip "Requires mocking dscl output"
  End

  It 'returns 0 and skips users whose home is not under /Users'
    # Mock dscl to include user with unusual home
    Skip "Requires mocking dscl output"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when dscl is not found'
    Skip "Requires mocking missing dscl binary"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Output format
  # ─────────────────────────═══════════════════════════════════════

  It 'outputs only usernames, one per line'
    # Verify no extra output or formatting
    Skip "Requires mocking dscl output"
  End

  It 'handles multiple graphical users correctly'
    # Mock dscl to return multiple users
    Skip "Requires mocking dscl output"
  End

End