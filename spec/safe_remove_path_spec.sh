Describe 'SafeRemovePath'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call SafeRemovePath
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given too many arguments'
    When call SafeRemovePath "/path/to/remove" "extra-arg"
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an unknown flag'
    When call SafeRemovePath "/path/to/remove" --bogus
    The status should eq 2
    The output should include "Unknown flag"
  End

  It 'returns 2 when given duplicate flags'
    When call SafeRemovePath "/path/to/remove" --tolerant-missing --tolerant-missing
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
    When call SafeRemovePath "/nonexistent/path"
    The status should eq 4
    The output should include "Absent"
  End

  It 'returns 0 when path does not exist with --tolerant-missing'
    When call SafeRemovePath "/nonexistent/path" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Symlink removal tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes a symlink'
    Skip "Requires creating test symlink and mocking UnlinkSymlink"
  End

  It 'returns 5 when symlink removal fails'
    Skip "Requires mocking UnlinkSymlink failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Directory removal tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes an empty directory'
    Skip "Requires creating test directory and mocking RemoveDir"
  End

  It 'returns 0 when successfully removes a directory tree (bottom-up)'
    Skip "Requires creating nested test directories"
  End

  It 'returns 5 when directory removal fails'
    Skip "Requires mocking RemoveDir failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # File removal tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes a single file'
    Skip "Requires creating test file and mocking SafeDelete"
  End

  It 'returns 5 when file removal fails'
    Skip "Requires mocking SafeDelete failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when path still exists after removal attempt'
    Skip "Requires mocking removal to succeed but path persists"
  End

  It 'returns 5 when one or more delete steps fail in directory tree'
    Skip "Requires mocking partial failure in tree removal"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when find is not found'
    Skip "Requires mocking missing find binary"
  End

  It 'returns 1 when realpath is not found'
    Skip "Requires mocking missing realpath binary"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the path'
    When call SafeRemovePath --tolerant-missing "/nonexistent/path"
    The status should eq 0
  End

  It 'accepts flags after the path'
    When call SafeRemovePath "/nonexistent/path" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles broken symlinks correctly'
    Skip "Requires creating broken symlink test case"
  End

  It 'handles paths with spaces correctly'
    Skip "Requires creating test path with spaces"
  End

  It 'handles paths with special characters correctly'
    Skip "Requires creating test path with special characters"
  End

End