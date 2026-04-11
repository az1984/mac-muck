. ./spec/spec_helper.sh
Describe 'QuitAppByPath'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

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

  It 'returns 2 when given duplicate flags'
    When call QuitAppByPath "/Applications/Test.app" --tolerant-missing --tolerant-missing
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
  # Bundle mode tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when bundle path does not exist without --tolerant-missing'
    When call QuitAppByPath "/Applications/NonExistent.app"
    The status should eq 4
    The output should include "Absent bundle"
  End

  It 'returns 0 when bundle path does not exist with --tolerant-missing'
    When call QuitAppByPath "/Applications/NonExistent.app" --tolerant-missing
    The status should eq 0
  End

  It 'returns 1 when path is not a valid .app bundle'
    When call QuitAppByPath "/tmp/not-an-app"
    The status should eq 1
    The output should include "Not an .app bundle"
  End

  It 'derives process name from CFBundleExecutable in Info.plist'
    Skip "Requires mock PlistBuddy and test .app bundle"
  End

  It 'falls back to bundle name when CFBundleExecutable is missing'
    Skip "Requires mock PlistBuddy and test .app bundle"
  End

  # ─────────────────────────═══════════════════════════════════════
  # PID mode tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when PID process is not running'
    Skip "Requires testing with non-existent PID"
  End

  It 'returns 0 when successfully terminates process by PID'
    Skip "Requires process creation and termination test"
  End

  It 'returns 5 when kill fails for PID'
    Skip "Requires mocking kill failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Process name mode tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when process by name is not running'
    Skip "Requires testing with non-existent process name"
  End

  It 'returns 0 when successfully terminates process by name'
    Skip "Requires process creation and termination test"
  End

  It 'returns 5 when pkill fails for process name'
    Skip "Requires mocking pkill failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Binary path mode tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when binary path process is not running'
    Skip "Requires testing with non-existent binary path"
  End

  It 'returns 0 when successfully terminates process by binary path'
    Skip "Requires process creation and termination test"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when process still running after TERM signal'
    Skip "Requires mocking process that ignores SIGTERM"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when pkill is not found'
    Skip "Requires mocking missing pkill binary"
  End

  It 'returns 1 when pgrep is not found'
    Skip "Requires mocking missing pgrep binary"
  End

  It 'returns 1 when PlistBuddy is not found'
    Skip "Requires mocking missing PlistBuddy binary"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the target'
    When call QuitAppByPath --tolerant-missing "/Applications/Test.app"
    The status should eq 0
  End

  It 'accepts flags after the target'
    When call QuitAppByPath "/Applications/Test.app" --tolerant-missing
    The status should eq 0
  End

End