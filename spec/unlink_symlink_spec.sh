. ./spec/spec_helper.sh
Describe 'UnlinkSymlink'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call UnlinkSymlink
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given too many arguments'
    When call UnlinkSymlink "/path/to/symlink" "extra-arg"
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an unknown flag'
    When call UnlinkSymlink "/path/to/symlink" --bogus
    The status should eq 2
    The output should include "Unknown flag"
  End

  It 'returns 2 when given duplicate flags'
    When call UnlinkSymlink "/path/to/symlink" --tolerant-missing --tolerant-missing
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

  It 'returns 4 when symlink does not exist without --tolerant-missing'
    When call UnlinkSymlink "/nonexistent/symlink"
    The status should eq 4
    The output should include "Absent"
  End

  It 'returns 0 when symlink does not exist with --tolerant-missing'
    When call UnlinkSymlink "/nonexistent/symlink" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type check tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when path is not a symlink'
    Skip "Requires creating test file that is not a symlink"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully unlinks a valid symlink'
    Skip "Requires creating test symlink and mocking unlink"
  End

  It 'returns 0 when successfully unlinks a broken symlink'
    Skip "Requires creating broken symlink and mocking unlink"
  End

  It 'returns 5 when unlink fails'
    Skip "Requires mocking unlink failure"
  End

  It 'falls back to rm -f when unlink fails but rm succeeds'
    Skip "Requires mocking unlink failure and rm success"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when unlink is not found'
    Skip "Requires mocking missing unlink binary"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the path'
    When call UnlinkSymlink --tolerant-missing "/nonexistent/symlink"
    The status should eq 0
  End

  It 'accepts flags after the path'
    When call UnlinkSymlink "/nonexistent/symlink" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'clears immutable flags on symlink before unlink when root'
    Skip "Requires mocking chflags -h and test symlink with flags"
  End

  It 'handles symlink paths with spaces correctly'
    Skip "Requires creating test symlink with spaces in name"
  End

End