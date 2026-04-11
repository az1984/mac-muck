# Source the spec helper
. ./spec/spec_helper.sh

# Default mock modes for QuitAppByPath tests
# These can be overridden per-test as needed
export MOCK_PGREP_MODE="${MOCK_PGREP_MODE:-running}"
export MOCK_PKILL_MODE="${MOCK_PKILL_MODE:-success}"
export MOCK_KILL_MODE="${MOCK_KILL_MODE:-success}"
export MOCK_PLISTB_MODE="${MOCK_PLISTB_MODE:-normal}"

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
    export EUID=1000
    export UID=1000
    When call QuitAppByPath "testprocess" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export EUID=0
    export UID=0
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Bundle mode tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 4 when bundle path does not exist without --tolerant-missing'
    local test_bundle="/tmp/nonexistent_test_bundle_$$"
    export MOCK_PGREP_MODE="not_running"
    When call QuitAppByPath "$test_bundle"
    The status should eq 4
    The output should include "Absent bundle"
    unset MOCK_PGREP_MODE
  End

  It 'returns 0 when bundle path does not exist with --tolerant-missing'
    local test_bundle="/tmp/nonexistent_test_bundle_$$"
    export MOCK_PGREP_MODE="not_running"
    When call QuitAppByPath "$test_bundle" --tolerant-missing
    The status should eq 0
    unset MOCK_PGREP_MODE
  End

  It 'returns 1 when path is not a valid .app bundle'
    local not_a_bundle="/tmp/not_a_bundle_$$"
    mkdir -p "$not_a_bundle"
    export MOCK_PGREP_MODE="not_running"
    When call QuitAppByPath "$not_a_bundle" --tolerant-missing
    The status should eq 1
    The output should include "Not an .app bundle"
    rm -rf "$not_a_bundle"
    unset MOCK_PGREP_MODE
  End

  It 'derives process name from CFBundleExecutable in Info.plist'
    local test_bundle="/tmp/test_bundle_$$"
    /Users/andrewezimmer/Documents/GitHub/mac-muck/tools/create_mock_bundle.sh "$test_bundle" "MyExecutable"
    export MOCK_PGREP_MODE="not_running"
    export MOCK_PKILL_MODE="success"
    When call QuitAppByPath "$test_bundle"
    The status should eq 0
    rm -rf "$test_bundle"
    unset MOCK_PGREP_MODE
    unset MOCK_PKILL_MODE
  End

  It 'falls back to bundle name when CFBundleExecutable is missing'
    local test_bundle="/tmp/test_bundle_nocf_$$"
    mkdir -p "$test_bundle/Contents/MacOS"
    mkdir -p "$test_bundle/Contents/Resources"
    # Create Info.plist without CFBundleExecutable
    cat > "$test_bundle/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.test.app</string>
    <key>CFBundleName</key>
    <string>FallbackApp</string>
</dict>
</plist>
EOF
    touch "$test_bundle/Contents/MacOS/dummy"
    chmod +x "$test_bundle/Contents/MacOS/dummy"
    export MOCK_PGREP_MODE="not_running"
    export MOCK_PKILL_MODE="success"
    When call QuitAppByPath "$test_bundle"
    The status should eq 0
    rm -rf "$test_bundle"
    unset MOCK_PGREP_MODE
    unset MOCK_PKILL_MODE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # PID mode tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 0 when PID process is not running'
    export MOCK_KILL_MODE="check_fail"
    When call QuitAppByPath "12345"
    The status should eq 0
    unset MOCK_KILL_MODE
  End

  It 'returns 0 when successfully terminates process by PID'
    export MOCK_KILL_MODE="success"
    When call QuitAppByPath "12345"
    The status should eq 0
    unset MOCK_KILL_MODE
  End

  It 'returns 5 when kill fails for PID'
    export MOCK_KILL_MODE="check_ok"
    export MOCK_KILL_MODE="fail"
    When call QuitAppByPath "12345"
    The status should eq 5
    The output should include "kill -TERM failed"
    unset MOCK_KILL_MODE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Process name mode tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 0 when process by name is not running'
    export MOCK_PGREP_MODE="not_running"
    When call QuitAppByPath "testprocess"
    The status should eq 0
    unset MOCK_PGREP_MODE
  End

  It 'returns 0 when successfully terminates process by name'
    export MOCK_PGREP_MODE="running"
    export MOCK_PKILL_MODE="success"
    When call QuitAppByPath "testprocess"
    The status should eq 0
    unset MOCK_PGREP_MODE
    unset MOCK_PKILL_MODE
  End

  It 'returns 5 when pkill fails for process name'
    export MOCK_PGREP_MODE="running"
    export MOCK_PKILL_MODE="fail"
    When call QuitAppByPath "testprocess"
    The status should eq 5
    The output should include "pkill failed"
    unset MOCK_PGREP_MODE
    unset MOCK_PKILL_MODE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Binary path mode tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 0 when binary path process is not running'
    export MOCK_PGREP_MODE="not_running"
    When call QuitAppByPath "/usr/local/bin/testbinary"
    The status should eq 0
    unset MOCK_PGREP_MODE
  End

  It 'returns 0 when successfully terminates process by binary path'
    export MOCK_PGREP_MODE="running"
    export MOCK_PKILL_MODE="success"
    When call QuitAppByPath "/usr/local/bin/testbinary"
    The status should eq 0
    unset MOCK_PGREP_MODE
    unset MOCK_PKILL_MODE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Verify-after tests
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 1 when process still running after TERM signal'
    # Use counter mode to simulate process still running after multiple checks
    export MOCK_PGREP_MODE="counter"
    export MOCK_PKILL_MODE="success"
    local counter_file="/tmp/pgrep_counter_$$"
    export MOCK_PGREP_COUNTER_FILE="$counter_file"
    echo "0" > "$counter_file"
    When call QuitAppByPath "testprocess"
    The status should eq 1
    The output should include "Verify failed: still running"
    rm -f "$counter_file"
    unset MOCK_PGREP_MODE
    unset MOCK_PKILL_MODE
    unset MOCK_PGREP_COUNTER_FILE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 1 when pkill is not found'
    # Temporarily rename pkill in PATH to simulate missing
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    # Use a subshell to isolate the PATH change
    (
      export PATH="/nonexistent:$PATH"
      When call QuitAppByPath "testprocess"
      The status should eq 1
      The output should include "Missing required tool"
    )
    export PATH="$old_path"
  End

  It 'returns 1 when pgrep is not found'
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call QuitAppByPath "testprocess"
      The status should eq 1
      The output should include "Missing required tool"
    )
    export PATH="$old_path"
  End

  It 'returns 1 when PlistBuddy is not found'
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    local test_bundle="/tmp/test_bundle_pbskip_$$"
    /Users/andrewezimmer/Documents/GitHub/mac-muck/tools/create_mock_bundle.sh "$test_bundle" "TestExec"
    (
      export PATH="/nonexistent:$PATH"
      When call QuitAppByPath "$test_bundle"
      The status should eq 1
      The output should include "Missing required tool"
    )
    rm -rf "$test_bundle"
    export PATH="$old_path"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Order-agnostic arguments
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'accepts flags before the target'
    export MOCK_PGREP_MODE="not_running"
    When call QuitAppByPath --tolerant-missing "/Applications/Test.app"
    The status should eq 0
    unset MOCK_PGREP_MODE
  End

  It 'accepts flags after the target'
    export MOCK_PGREP_MODE="not_running"
    When call QuitAppByPath "/Applications/Test.app" --tolerant-missing
    The status should eq 0
    unset MOCK_PGREP_MODE
  End

End