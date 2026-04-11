. ./spec/spec_helper.sh
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
    export EUID=1000
    export UID=1000
    When call SafeRemovePath "/tmp/testpath" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export EUID=0
    export UID=0
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
    local test_target="/tmp/safe_rm_target_$$"
    local test_symlink="/tmp/safe_rm_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    When call SafeRemovePath "$test_symlink"
    The status should eq 0
    [[ ! -e "$test_symlink" ]]
    rm -f "$test_target"
  End

  It 'returns 5 when symlink removal fails'
    local test_target="/tmp/safe_rm_fail_target_$$"
    local test_symlink="/tmp/safe_rm_fail_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    # Mock UnlinkSymlink to fail
    UnlinkSymlink() { return 5; }
    When call SafeRemovePath "$test_symlink"
    The status should eq 5
    rm -f "$test_target" "$test_symlink"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Directory removal tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes an empty directory'
    local test_dir="/tmp/safe_rm_dir_$$"
    mkdir -p "$test_dir"
    When call SafeRemovePath "$test_dir"
    The status should eq 0
    [[ ! -d "$test_dir" ]]
    rm -rf "$test_dir"
  End

  It 'returns 0 when successfully removes a directory tree (bottom-up)'
    local test_dir="/tmp/safe_rm_tree_$$"
    mkdir -p "$test_dir/subdir1/subdir2"
    touch "$test_dir/file1" "$test_dir/subdir1/file2"
    When call SafeRemovePath "$test_dir"
    The status should eq 0
    [[ ! -d "$test_dir" ]]
    rm -rf "$test_dir"
  End

  It 'returns 5 when directory removal fails'
    local test_dir="/tmp/safe_rm_dir_fail_$$"
    mkdir -p "$test_dir"
    # Mock RemoveDir to fail
    RemoveDir() { return 5; }
    When call SafeRemovePath "$test_dir"
    The status should eq 5
    rm -rf "$test_dir"
  End

  # ─────────────────────────═══════════════════════════════════════
  # File removal tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes a single file'
    local test_file="/tmp/safe_rm_file_$$"
    touch "$test_file"
    When call SafeRemovePath "$test_file"
    The status should eq 0
    [[ ! -f "$test_file" ]]
    rm -f "$test_file"
  End

  It 'returns 5 when file removal fails'
    local test_file="/tmp/safe_rm_file_fail_$$"
    touch "$test_file"
    # Mock SafeDelete to fail
    SafeDelete() { return 5; }
    When call SafeRemovePath "$test_file"
    The status should eq 5
    rm -f "$test_file"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when path still exists after removal attempt'
    local test_file="/tmp/safe_rm_verify_$$"
    touch "$test_file"
    # Mock SafeDelete to succeed but file persists
    SafeDelete() { return 0; }
    When call SafeRemovePath "$test_file"
    The status should eq 5
    rm -f "$test_file"
  End

  It 'returns 5 when one or more delete steps fail in directory tree'
    local test_dir="/tmp/safe_rm_tree_fail_$$"
    mkdir -p "$test_dir/subdir1"
    touch "$test_dir/file1" "$test_dir/subdir1/file2"
    # Mock SafeDelete to fail
    SafeDelete() { return 5; }
    When call SafeRemovePath "$test_dir"
    The status should eq 5
    rm -rf "$test_dir"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when find is not found'
    local test_dir="/tmp/safe_rm_find_test_$$"
    mkdir -p "$test_dir"
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call SafeRemovePath "$test_dir"
      The status should eq 1
      The output should include "find not found"
    )
    rm -rf "$test_dir"
    export PATH="$old_path"
  End

  It 'returns 1 when realpath is not found'
    local test_file="/tmp/safe_rm_realpath_test_$$"
    touch "$test_file"
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call SafeRemovePath "$test_file"
      The status should eq 1
      The output should include "realpath not found"
    )
    rm -f "$test_file"
    export PATH="$old_path"
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
    local test_symlink="/tmp/safe_rm_broken_$$"
    ln -s "/nonexistent/target" "$test_symlink"
    When call SafeRemovePath "$test_symlink"
    The status should eq 0
    rm -f "$test_symlink"
  End

  It 'handles paths with spaces correctly'
    local test_dir="/tmp/safe rm with spaces_$$"
    mkdir -p "$test_dir"
    When call SafeRemovePath "$test_dir"
    The status should eq 0
    [[ ! -d "$test_dir" ]]
    rm -rf "$test_dir"
  End

  It 'handles paths with special characters correctly'
    local test_dir="/tmp/safe_rm_test_@#\$%^_$$"
    mkdir -p "$test_dir"
    When call SafeRemovePath "$test_dir"
    The status should eq 0
    [[ ! -d "$test_dir" ]]
    rm -rf "$test_dir"
  End

End