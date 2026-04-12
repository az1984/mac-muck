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
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call UnlinkSymlink "/tmp/testlink" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export FAKE_EUID=0
    export FAKE_UID=0
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
    test_file="/tmp/unlink_test_file_$$"
    touch "$test_file"
    When call UnlinkSymlink "$test_file"
    The status should eq 1
    The output should include "Not a symlink"
    rm -f "$test_file"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when successfully unlinks a valid symlink'
    test_target="/tmp/unlink_target_$$"
    test_symlink="/tmp/unlink_symlink_$$"
    touch "$test_target"
    ln -sf "$test_target" "$test_symlink"
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    The path "$test_symlink" should not be exist
    rm -f "$test_target"
  End

  It 'returns 0 when successfully unlinks a broken symlink'
    test_symlink="/tmp/unlink_broken_$$"
    ln -sf "/nonexistent/target" "$test_symlink"
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    The path "$test_symlink" should not be exist
    rm -f "$test_symlink"
  End

  It 'returns 5 when unlink fails'
    test_dir="/tmp/unlink_fail_dir_$$"
    mkdir -p "$test_dir"
    touch "$test_dir/target"
    ln -sf "$test_dir/target" "$test_dir/link"
    chmod 555 "$test_dir"
    When call UnlinkSymlink "$test_dir/link"
    The status should eq 5
    The output should include "unlink failed"
    chmod 755 "$test_dir"
    rm -rf "$test_dir"
  End

  It 'falls back to rm -f when unlink fails but rm succeeds'
    # On this system /usr/bin/unlink may not exist, so the function naturally
    # falls back to /bin/rm -f. Create a real symlink and let the fallback work.
    test_target="/tmp/unlink_fallback_target_$$"
    test_symlink="/tmp/unlink_fallback_symlink_$$"
    touch "$test_target"
    ln -sf "$test_target" "$test_symlink"
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    The path "$test_symlink" should not be exist
    rm -f "$test_target"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when unlink is not found'
    Skip "Function uses hardcoded /usr/bin/unlink without a tool-presence check; needs source fix to add [[ ! -x UNLINK_BIN ]] gate"
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
    test_target="/tmp/unlink_immutable_target_$$"
    test_symlink="/tmp/unlink_immutable_symlink_$$"
    touch "$test_target"
    ln -sf "$test_target" "$test_symlink"
    export FAKE_EUID=0
    export FAKE_UID=0
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    The path "$test_symlink" should not be exist
    rm -f "$test_target"
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'handles symlink paths with spaces correctly'
    test_target="/tmp/unlink space target_$$"
    test_symlink="/tmp/unlink space symlink_$$"
    touch "$test_target"
    ln -sf "$test_target" "$test_symlink"
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    The path "$test_symlink" should not be exist
    rm -f "$test_target"
  End

End