. ./spec/spec_helper.sh
Describe 'VerifyServiceUnloaded'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call VerifyServiceUnloaded
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given more than one argument'
    When call VerifyServiceUnloaded "system/com.vendor.daemon" "extra"
    The status should eq 2
    The output should include "Bad input"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests (rc 0)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 for a service that does not exist'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "com.nonexistent.service"
    The status should eq 0
    unset MOCK_LAUNCHCTL_MODE
  End

  It 'returns 0 for a service with state = not running'
    export MOCK_LAUNCHCTL_MODE="not_running"
    When call VerifyServiceUnloaded "com.test.service"
    The status should eq 0
    unset MOCK_LAUNCHCTL_MODE
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 for a service that is running'
    export MOCK_LAUNCHCTL_MODE="running"
    When call VerifyServiceUnloaded "com.running.service"
    The status should eq 1
    The output should include "running"
    unset MOCK_LAUNCHCTL_MODE
  End

  It 'returns 1 when service shows state = running in output'
    export MOCK_LAUNCHCTL_MODE="running"
    When call VerifyServiceUnloaded "com.running.service"
    The status should eq 1
    unset MOCK_LAUNCHCTL_MODE
  End

  # ─────────────────────────═══════════════════════════════════════
  # Ambiguous state tests (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when launchctl output is ambiguous'
    export MOCK_LAUNCHCTL_MODE="ambiguous"
    When call VerifyServiceUnloaded "com.ambiguous.service"
    The status should eq 3
    The output should include "ambiguous"
    unset MOCK_LAUNCHCTL_MODE
  End

  It 'returns 3 when launchctl output contains neither running nor not running'
    export MOCK_LAUNCHCTL_MODE="ambiguous"
    When call VerifyServiceUnloaded "com.unknown.service"
    The status should eq 3
    unset MOCK_LAUNCHCTL_MODE
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when launchctl is not found'
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call VerifyServiceUnloaded "com.test.service"
      The status should eq 3
      The output should include "launchctl not found"
    )
    export PATH="$old_path"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Domain target format tests
  # ─────────────────────────═══════════════════════════════════════

  It 'handles gui domain for LaunchAgents'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "gui/501/com.test.agent"
    The status should eq 0
    unset MOCK_LAUNCHCTL_MODE
  End

  It 'handles system domain for LaunchDaemons'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "system/com.test.daemon"
    The status should eq 0
    unset MOCK_LAUNCHCTL_MODE
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles labels with underscores correctly'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "com_test_service"
    The status should eq 0
    unset MOCK_LAUNCHCTL_MODE
  End

  It 'handles labels with hyphens correctly'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "com-test-service"
    The status should eq 0
    unset MOCK_LAUNCHCTL_MODE
  End

  It 'handles empty launchctl output gracefully'
    export MOCK_LAUNCHCTL_OUTPUT=""
    export MOCK_LAUNCHCTL_MODE="list_plists"
    When call VerifyServiceUnloaded "com.empty.service"
    The status should eq 3
    unset MOCK_LAUNCHCTL_MODE
    unset MOCK_LAUNCHCTL_OUTPUT
  End

End