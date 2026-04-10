Describe 'RemoveDir'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call RemoveDir
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given too many arguments'
    When call RemoveDir "/path/to/dir" "extra-arg"
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an unknown flag'
    When call RemoveDir "/path/to/dir" --bogus
    The status should eq 2
    The output should include "Unknown flag"
  End

  It 'returns 2 when given duplicate flags'
    When call RemoveDir "/path/to/dir" --tolerant-missing --tolerant-missing
    The status should eq 2
    The output should include "duplicate"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root gate (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when not root and --needs-root is specified'
    Skip "Requires non-root execution context to test the root guard"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Missing path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when directory does not exist without --tolerant-missing'
    When call RemoveDir "/nonexistent/directory"
    The status should eq 4
    The output should include "Absent"
  End

  It 'returns 0 when directory does not exist with --tolerant-missing'
    When call RemoveDir "/nonexistent/directory" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type check tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when path is not a directory'
    Skip "Requires creating test file that is not a directory"
  End

  It 'returns 1 when path is a symlink (not a directory)'
    Skip "Requires creating test symlink"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes an empty directory'
    Skip "Requires creating test empty directory"
  End

  It 'returns 5 when rmdir fails (directory not empty)'
    Skip "Requires creating test non-empty directory"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when rmdir is not found'
    Skip "Requires mocking missing rmdir binary"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the path'
    When call RemoveDir --tolerant-missing "/nonexistent/directory"
    The status should eq 0
  End

  It 'accepts flags after the path'
    When call RemoveDir "/nonexistent/directory" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'clears immutable flags before removal when root'
    Skip "Requires mocking chflags and test directory with flags"
  End

  It 'handles directory paths with spaces correctly'
    Skip "Requires creating test directory with spaces in name"
  End

End