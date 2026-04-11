. ./spec/spec_helper.sh
Describe 'SafeDelete'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call SafeDelete
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given too many arguments'
    When call SafeDelete "/path/to/delete" "extra-arg"
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an unknown flag'
    When call SafeDelete "/path/to/delete" --bogus
    The status should eq 2
    The output should include "Unknown flag"
  End

  It 'returns 2 when given duplicate flags'
    When call SafeDelete "/path/to/delete" --tolerant-missing --tolerant-missing
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

  It 'returns 4 when path does not exist without --tolerant-missing'
    When call SafeDelete "/nonexistent/path"
    The status should eq 4
    The output should include "Absent"
  End

  It 'returns 0 when path does not exist with --tolerant-missing'
    When call SafeDelete "/nonexistent/path" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Symlink deletion tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully unlinks a symlink'
    Skip "Requires creating test symlink and mocking UnlinkSymlink"
  End

  It 'returns 5 when symlink is not a symlink (type check fails)'
    Skip "Requires creating test file that is not a symlink"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Directory deletion tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes an empty directory'
    Skip "Requires creating test directory and mocking RemoveDir"
  End

  It 'returns 5 when directory removal fails'
    Skip "Requires mocking RemoveDir failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # File deletion tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes a regular file'
    Skip "Requires creating test file and mocking rm"
  End

  It 'returns 5 when file removal fails'
    Skip "Requires mocking rm failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when UnlinkSymlink function is not defined'
    Skip "Requires mocking missing UnlinkSymlink function"
  End

  It 'returns 1 when RemoveDir function is not defined'
    Skip "Requires mocking missing RemoveDir function"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the path'
    When call SafeDelete --tolerant-missing "/nonexistent/path"
    The status should eq 0
  End

  It 'accepts flags after the path'
    When call SafeDelete "/nonexistent/path" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles broken symlinks correctly'
    Skip "Requires creating broken symlink test case"
  End

  It 'clears immutable flags before deletion when root'
    Skip "Requires mocking chflags and test file with flags"
  End

End