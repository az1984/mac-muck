. ./spec/spec_helper.sh
Describe 'VerifyServiceUnloaded'

  # Override /bin/launchctl with a shell function so the hardcoded path
  # inside VerifyServiceUnloaded calls our mock instead of the real binary.
  mock_launchctl() {
    case "${MOCK_LAUNCHCTL_MODE:-normal}" in
      not_found)
        echo "Could not find service \"$2\" in domain for port" >&2
        return 113 ;;
      not_running)
        echo "    state = not running"
        return 0 ;;
      running)
        echo "    state = running"
        return 0 ;;
      ambiguous)
        echo "State: unknown"
        return 0 ;;
      list_plists)
        if [[ -n "${MOCK_LAUNCHCTL_OUTPUT:-}" ]]; then
          echo "$MOCK_LAUNCHCTL_OUTPUT"
        fi
        return 0 ;;
      *)
        return 0 ;;
    esac
  }

  setup() {
    eval 'function /bin/launchctl { mock_launchctl "$@"; }'
  }

  cleanup() {
    unset -f /bin/launchctl 2>/dev/null || true
    unset MOCK_LAUNCHCTL_MODE 2>/dev/null || true
    unset MOCK_LAUNCHCTL_OUTPUT 2>/dev/null || true
  }

  Before 'setup'
  After 'cleanup'

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
  End

  It 'returns 0 for a service with state = not running'
    export MOCK_LAUNCHCTL_MODE="not_running"
    When call VerifyServiceUnloaded "com.test.service"
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 for a service that is running'
    export MOCK_LAUNCHCTL_MODE="running"
    When call VerifyServiceUnloaded "com.running.service"
    The status should eq 1
    The output should include "running"
  End

  It 'returns 1 when service shows state = running in output'
    export MOCK_LAUNCHCTL_MODE="running"
    When call VerifyServiceUnloaded "com.running.service"
    The status should eq 1
    The output should include "Still running"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Ambiguous state tests (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when launchctl output is ambiguous'
    export MOCK_LAUNCHCTL_MODE="ambiguous"
    export DEBUG=true
    When call VerifyServiceUnloaded "com.ambiguous.service"
    The status should eq 3
    The output should include "Ambiguous"
  End

  It 'returns 3 when launchctl output contains neither running nor not running'
    export MOCK_LAUNCHCTL_MODE="ambiguous"
    When call VerifyServiceUnloaded "com.unknown.service"
    The status should eq 3
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when launchctl is not found'
    # The function checks [[ ! -x "/bin/launchctl" ]] which always passes on
    # macOS since /bin/launchctl exists. This test validates behavior when
    # the binary is absent. We simulate by temporarily making the function
    # check fail via a shell function that wraps the test call.
    launchctl_missing_test() {
      # Temporarily rename the check by overriding the function to also
      # make [[ ! -x ... ]] fail. We redefine VerifyServiceUnloaded inline
      # with a patched tool-check.
      # Since we cannot modify the source, we skip this on real macOS.
      VerifyServiceUnloaded "com.test.service"
    }
    Skip "Cannot test missing /bin/launchctl on macOS where it always exists"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Domain target format tests
  # ─────────────────────────═══════════════════════════════════════

  It 'handles gui domain for LaunchAgents'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "gui/501/com.test.agent"
    The status should eq 0
  End

  It 'handles system domain for LaunchDaemons'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "system/com.test.daemon"
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles labels with underscores correctly'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "com_test_service"
    The status should eq 0
  End

  It 'handles labels with hyphens correctly'
    export MOCK_LAUNCHCTL_MODE="not_found"
    When call VerifyServiceUnloaded "com-test-service"
    The status should eq 0
  End

  It 'handles empty launchctl output gracefully'
    export MOCK_LAUNCHCTL_OUTPUT=""
    export MOCK_LAUNCHCTL_MODE="list_plists"
    When call VerifyServiceUnloaded "com.empty.service"
    The status should eq 3
  End

End
