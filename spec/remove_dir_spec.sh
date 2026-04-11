. ./spec/spec_helper.sh
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
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call RemoveDir "/tmp/testdir" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export FAKE_EUID=0
    export FAKE_UID=0
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
    local test_file="/tmp/remove_dir_test_file_$$"
    touch "$test_file"
    When call RemoveDir "$test_file" --tolerant-missing
    The status should eq 1
    The output should include "Not a directory"
    rm -f "$test_file"
  End

  It 'returns 1 when path is a symlink (not a directory)'
    local test_target="/tmp/remove_dir_target_$$"
    local test_symlink="/tmp/remove_dir_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    When call RemoveDir "$test_symlink" --tolerant-missing
    The status should eq 1
    The output should include "Not a directory"
    rm -f "$test_target" "$test_symlink"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes an empty directory'
    local test_dir="/tmp/remove_dir_test_$$"
    mkdir -p "$test_dir"
    When call RemoveDir "$test_dir"
    The status should eq 0
    [[ ! -d "$test_dir" ]]
    rm -rf "$test_dir"
  End

  It 'returns 5 when rmdir fails (directory not empty)'
    local test_dir="/tmp/remove_dir_test_nonempty_$$"
    mkdir -p "$test_dir"
    touch "$test_dir/file"
    # Mock rmdir to fail
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    When call RemoveDir "$test_dir" --tolerant-missing
    The status should eq 5
    rm -rf "$test_dir"
    export PATH="$old_path"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when rmdir is not found'
    local test_dir="/tmp/remove_dir_test_tool_$$"
    mkdir -p "$test_dir"
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call RemoveDir "$test_dir"
      The status should eq 1
      The output should include "rmdir not found"
    )
    rm -rf "$test_dir"
    export PATH="$old_path"
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

  It 'handles directory paths with spaces correctly'
    local test_dir="/tmp/remove dir with spaces_$$"
    mkdir -p "$test_dir"
    When call RemoveDir "$test_dir"
    The status should eq 0
    [[ ! -d "$test_dir" ]]
    rm -rf "$test_dir"
  End

End