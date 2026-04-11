# Source the spec helper
. ./spec/spec_helper.sh

# Global test mode flags - set these before each test that needs special behavior
# Default: normal success mode
TEST_KILL_FAIL=false
TEST_PGREP_RUNNING=true
TEST_PKILL_FAIL=false

# Mock /usr/bin/pkill to prevent real process termination
pkill() {
  if $TEST_PKILL_FAIL; then
    return 1
  fi
  return 0
}

# Mock /usr/bin/pgrep to prevent real process queries
pgrep() {
  if $TEST_PGREP_RUNNING; then
    return 0
  fi
  return 1
}

# Mock /usr/libexec/PlistBuddy for bundle mode tests
PlistBuddy() {
  case "$*" in
    -c\ 'Print\ :CFBundleExecutable'*)
      echo "TestAppExecutable"
      return 0 ;;
    *)
      return 0 ;;
  esac
}

# Mock /bin/kill for PID mode tests
kill() {
  if $TEST_KILL_FAIL; then
    return 1
  fi
  case "$*" in
    -0\ *)
      # Simulate process exists
      return 0 ;;
    -TERM\ *)
      # Simulate kill success
      return 0 ;;
    *)
      return 0 ;;
  esac
}

Describe 'QuitAppByPath'

  # ─────────────────────────────────────────────────────────══════════════════════
  # Bad input (rc 2)
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 2 when no arguments provided'
    When call QuitAppByPath
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given too many arguments'
    When call QuitAppByPath "target1" "target2"
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an unknown flag'
    When call QuitAppByPath "/Applications/Test.app" --bogus
    The status should eq 2
    The output should include "Unknown flag"
  End

  It 'returns 2 when given duplicate --tolerant-missing flag'
    When call QuitAppByPath "/Applications/Test.app" --tolerant-missing --tolerant-missing
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 when given duplicate --needs-root flag'
    When call QuitAppByPath "/Applications/Test.app" --needs-root --needs-root
    The status should eq 2
    The output should include "duplicate"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Root gate (rc 3)
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 3 when not root and --needs-root is specified'
    Skip "Requires non-root execution context to test the root guard"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Bundle mode tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 4 when bundle path does not exist without --tolerant-missing'
    Skip "Requires mocking file system for bundle existence check"
  End

  It 'returns 0 when bundle path does not exist with --tolerant-missing'
    Skip "Requires mocking file system for bundle existence check"
  End

  It 'returns 1 when path is not a valid .app bundle'
    Skip "Requires mocking file system for bundle type check"
  End

  It 'derives process name from CFBundleExecutable in Info.plist'
    Skip "Requires mock PlistBuddy and test .app bundle"
  End

  It 'falls back to bundle name when CFBundleExecutable is missing'
    Skip "Requires mock PlistBuddy and test .app bundle"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # PID mode tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 0 when PID process is not running'
    TEST_PGREP_RUNNING=false
    When call QuitAppByPath "12345"
    The status should eq 0
    TEST_PGREP_RUNNING=true
  End

  It 'returns 0 when successfully terminates process by PID'
    When call QuitAppByPath "12345"
    The status should eq 0
  End

  It 'returns 5 when kill fails for PID'
    Skip "Requires mocking kill to fail in subshell"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Process name mode tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 0 when process by name is not running'
    TEST_PGREP_RUNNING=false
    When call QuitAppByPath "testprocess"
    The status should eq 0
    TEST_PGREP_RUNNING=true
  End

  It 'returns 0 when successfully terminates process by name'
    When call QuitAppByPath "testprocess"
    The status should eq 0
  End

  It 'returns 5 when pkill fails for process name'
    Skip "Requires mocking pkill to fail in subshell"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Binary path mode tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 0 when binary path process is not running'
    TEST_PGREP_RUNNING=false
    When call QuitAppByPath "/usr/local/bin/testbinary"
    The status should eq 0
    TEST_PGREP_RUNNING=true
  End

  It 'returns 0 when successfully terminates process by binary path'
    When call QuitAppByPath "/usr/local/bin/testbinary"
    The status should eq 0
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Verify-after tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 1 when process still running after TERM signal'
    Skip "Requires mocking pgrep to always return running in subshell"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 1 when pkill is not found'
    Skip "Requires mocking missing pkill binary"
  End

  It 'returns 1 when pgrep is not found'
    Skip "Requires mocking missing pgrep binary"
  End

  It 'returns 1 when PlistBuddy is not found'
    Skip "Requires mocking missing PlistBuddy binary"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Order-agnostic arguments
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'accepts flags before the target'
    When call QuitAppByPath --tolerant-missing "/Applications/Test.app"
    The status should eq 0
  End

  It 'accepts flags after the target'
    When call QuitAppByPath "/Applications/Test.app" --tolerant-missing
    The status should eq 0
  End

End