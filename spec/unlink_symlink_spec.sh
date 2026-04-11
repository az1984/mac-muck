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
    export EUID=1000
    export UID=1000
    When call UnlinkSymlink "/tmp/testlink" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export EUID=0
    export UID=0
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
    local test_file="/tmp/unlink_test_file_$$"
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
    local test_target="/tmp/unlink_target_$$"
    local test_symlink="/tmp/unlink_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    # Mock unlink to succeed
    unlink() { return 0; }
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    [[ ! -e "$test_symlink" ]]
    rm -f "$test_target"
  End

  It 'returns 0 when successfully unlinks a broken symlink'
    local test_symlink="/tmp/unlink_broken_$$"
    ln -s "/nonexistent/target" "$test_symlink"
    # Mock unlink to succeed
    unlink() { return 0; }
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    [[ ! -e "$test_symlink" ]]
    rm -f "$test_symlink"
  End

  It 'returns 5 when unlink fails'
    local test_target="/tmp/unlink_fail_target_$$"
    local test_symlink="/tmp/unlink_fail_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    # Mock unlink to fail
    unlink() { return 1; }
    When call UnlinkSymlink "$test_symlink"
    The status should eq 5
    rm -f "$test_target" "$test_symlink"
  End

  It 'falls back to rm -f when unlink fails but rm succeeds'
    local test_target="/tmp/unlink_fallback_target_$$"
    local test_symlink="/tmp/unlink_fallback_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    # Mock unlink to fail, rm to succeed
    unlink() { return 1; }
    rm() { return 0; }
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    rm -f "$test_target" "$test_symlink"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when unlink is not found'
    local test_target="/tmp/unlink_tool_target_$$"
    local test_symlink="/tmp/unlink_tool_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call UnlinkSymlink "$test_symlink"
      The status should eq 1
      The output should include "unlink not found"
    )
    rm -f "$test_target" "$test_symlink"
    export PATH="$old_path"
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
    local test_target="/tmp/unlink_immutable_target_$$"
    local test_symlink="/tmp/unlink_immutable_symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    export EUID=0
    export UID=0
    # Mock unlink to succeed
    unlink() { return 0; }
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    rm -f "$test_target" "$test_symlink"
    export EUID=1000
    export UID=1000
  End

  It 'handles symlink paths with spaces correctly'
    local test_target="/tmp/unlink space target_$$"
    local test_symlink="/tmp/unlink space symlink_$$"
    touch "$test_target"
    ln -s "$test_target" "$test_symlink"
    # Mock unlink to succeed
    unlink() { return 0; }
    When call UnlinkSymlink "$test_symlink"
    The status should eq 0
    [[ ! -e "$test_symlink" ]]
    rm -f "$test_target" "$test_symlink"
  End

End