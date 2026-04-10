Describe 'RemovePathForUsers'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call RemovePathForUsers
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an unknown flag'
    When call RemovePathForUsers "Library/Caches/test" --bogus
    The status should eq 2
    The output should include "Unknown flag"
  End

  It 'returns 2 when given duplicate flags'
    When call RemovePathForUsers "Library/Caches/test" --tolerant-missing --tolerant-missing
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
  # Path validation tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when relative path is empty (leading slash stripped)'
    When call RemovePathForUsers "/"
    The status should eq 2
    The output should include "empty"
  End

  It 'strips leading slash from relative path'
    # Path "/Library/Caches/test" should become "Library/Caches/test"
    Skip "Requires verifying path normalization"
  End

  # ─────────────────────────═══════════════════════════════════════
  # User discovery tests
  # ─────────────────────────═══════════════════════════════════════

  It 'discovers users via ListGraphicalUsers when none provided'
    Skip "Requires mocking ListGraphicalUsers"
  End

  It 'uses explicitly provided usernames instead of discovery'
    Skip "Requires mocking ListGraphicalUsers and verifying explicit users used"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Shared user protection tests
  # ─────────────────────────═══════════════════════════════════════

  It 'skips user named Shared with warning'
    Skip "Requires verifying Shared user is skipped"
  End

  It 'skips path that resolves to /Users/Shared exactly'
    Skip "Requires verifying /Users/Shared is refused"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Home directory resolution tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when user has no home directory'
    Skip "Requires mocking user without home directory"
  End

  It 'falls back to /Users/<username> when eval ~user fails'
    Skip "Requires mocking eval failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Removal tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes path for all users'
    Skip "Requires mocking SafeRemovePath and multiple users"
  End

  It 'returns 5 when removal fails for one or more users'
    Skip "Requires mocking SafeRemovePath failure"
  End

  It 'returns 0 when path is absent for all users with --tolerant-missing'
    Skip "Requires mocking SafeRemovePath with tolerant-missing"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when ListGraphicalUsers function is not defined'
    Skip "Requires mocking missing ListGraphicalUsers function"
  End

  It 'returns 1 when SafeRemovePath function is not defined'
    Skip "Requires mocking missing SafeRemovePath function"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags after the relative path'
    When call RemovePathForUsers "Library/Caches/test" --tolerant-missing
    The status should eq 0
  End

  It 'accepts explicit usernames after the relative path'
    Skip "Requires mocking ListGraphicalUsers and verifying explicit users used"
  End

  It 'accepts flags and usernames in any order'
    Skip "Requires mocking ListGraphicalUsers and verifying mixed args"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles relative paths with spaces correctly'
    Skip "Requires creating test path with spaces"
  End

  It 'handles relative paths with wildcards correctly'
    Skip "Requires creating test path with wildcards"
  End

End