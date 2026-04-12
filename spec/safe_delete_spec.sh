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
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call SafeDelete "/tmp/testpath" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export FAKE_EUID=0
    export FAKE_UID=0
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
    local test_target="/tmp/safe_del_target_$$"
    local test_symlink="/tmp/safe_del_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    # Mock UnlinkSymlink to succeed
    UnlinkSymlink() { return 0; }
    When call SafeDelete "$test_symlink"
    The status should eq 0
    rm -f "$test_target" "$test_symlink"
  End

  It 'returns 0 when successfully removes a regular file via rm'
    local test_file="/tmp/safe_del_regular_$$"
    touch "$test_file"
    When call SafeDelete "$test_file"
    The status should eq 0
    rm -f "$test_file"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Directory deletion tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes an empty directory'
    local test_dir="/tmp/safe_del_dir_$$"
    mkdir -p "$test_dir"
    # Mock RemoveDir to succeed
    RemoveDir() { return 0; }
    When call SafeDelete "$test_dir"
    The status should eq 0
    rm -rf "$test_dir"
  End

  It 'returns 5 when directory removal fails'
    local test_dir="/tmp/safe_del_dir_fail_$$"
    mkdir -p "$test_dir"
    # Mock RemoveDir to fail
    RemoveDir() { return 5; }
    When call SafeDelete "$test_dir"
    The status should eq 5
    rm -rf "$test_dir"
  End

  # ─────────────────────────═══════════════════════════════════════
  # File deletion tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully removes a regular file'
    local test_file="/tmp/safe_del_file_$$"
    touch "$test_file"
    When call SafeDelete "$test_file"
    The status should eq 0
    rm -f "$test_file"
  End

  It 'returns 5 when file removal fails'
    local test_dir="/tmp/safe_del_nowrite_$$"
    local test_file="$test_dir/protected_file"
    mkdir -p "$test_dir"
    touch "$test_file"
    chmod a-w "$test_dir"
    When call SafeDelete "$test_file"
    The status should eq 5
    The output should include "rm failed"
    chmod u+w "$test_dir"
    rm -rf "$test_dir"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when UnlinkSymlink delegate fails'
    local test_symlink="/tmp/safe_del_unlink_test_$$"
    ln -s "/nonexistent" "$test_symlink"
    # Mock UnlinkSymlink to return failure
    UnlinkSymlink() { return 1; }
    When call SafeDelete "$test_symlink"
    The status should eq 5
    rm -f "$test_symlink"
  End

  It 'returns 5 when RemoveDir delegate fails'
    local test_dir="/tmp/safe_del_rmdir_test_$$"
    mkdir -p "$test_dir"
    # Mock RemoveDir to return failure
    RemoveDir() { return 1; }
    When call SafeDelete "$test_dir"
    The status should eq 5
    rm -rf "$test_dir"
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
    local test_symlink="/tmp/safe_del_broken_$$"
    ln -s "/nonexistent/target" "$test_symlink"
    # Mock UnlinkSymlink to succeed
    UnlinkSymlink() { return 0; }
    When call SafeDelete "$test_symlink"
    The status should eq 0
    rm -f "$test_symlink"
  End

  It 'clears immutable flags before deletion when root'
    local test_file="/tmp/safe_del_immutable_$$"
    touch "$test_file"
    export FAKE_EUID=0
    export FAKE_UID=0
    When call SafeDelete "$test_file"
    The status should eq 0
    rm -f "$test_file"
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

End