. ./spec/spec_helper.sh

Describe 'DisableLaunchDaemon'

  # ── shared mock infrastructure ──────────────────────────────────
  # The function uses ${LAUNCHCTL_BIN:-/bin/launchctl} (patched by spec_helper).
  # We override /bin/launchctl with a bash function so the hardcoded path invokes our mock.
  # MOCK_LAUNCHCTL_DAEMON_EXISTS controls whether the daemon is "found"
  # MOCK_LAUNCHCTL_DISABLE_VERIFIED controls whether print-disabled shows "true"
  # MOCK_LAUNCHCTL_PRINT_DISABLED_STDERR controls whether print-disabled has stderr

  setup() {
    export FAKE_EUID=0
    export FAKE_UID=0
    # Default: daemon not found, disable verified
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="false"
    export MOCK_LAUNCHCTL_DISABLE_VERIFIED="true"
    export MOCK_LAUNCHCTL_PRINT_DISABLED_STDERR="false"

    eval 'function /bin/launchctl {
      local subcmd="$1"
      shift
      case "$subcmd" in
        print)
          # $1 is system/<label>
          if [[ "${MOCK_LAUNCHCTL_DAEMON_EXISTS}" == "true" ]]; then
            echo "service = system/${1}"
            return 0
          else
            echo "Could not find service: ${1}" >&2
            return 113
          fi
          ;;
        disable)
          return 0
          ;;
        print-disabled)
          if [[ "${MOCK_LAUNCHCTL_PRINT_DISABLED_STDERR}" == "true" ]]; then
            echo "Error getting disabled status" >&2
            return 1
          fi
          if [[ "${MOCK_LAUNCHCTL_DISABLE_VERIFIED}" == "true" ]]; then
            echo "disabled services = {"
            echo "	\"${MOCK_LAUNCHCTL_LABEL:-com.vendor.app.daemon}\" => true"
            echo "}"
          else
            echo "disabled services = {"
            echo "}"
          fi
          return 0
          ;;
        *)
          return 0
          ;;
      esac
    }'
  }

  cleanup() {
    unset -f /bin/launchctl 2>/dev/null || true
    unset MOCK_LAUNCHCTL_DAEMON_EXISTS 2>/dev/null || true
    unset MOCK_LAUNCHCTL_DISABLE_VERIFIED 2>/dev/null || true
    unset MOCK_LAUNCHCTL_PRINT_DISABLED_STDERR 2>/dev/null || true
    unset MOCK_LAUNCHCTL_LABEL 2>/dev/null || true
    export FAKE_EUID=1000
    export FAKE_UID=1000
  }

  Before 'setup'
  After 'cleanup'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call DisableLaunchDaemon
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format (single label)'
    When call DisableLaunchDaemon "notreverse"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when given an invalid label format (only 2 labels)'
    When call DisableLaunchDaemon "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when label starts with number'
    When call DisableLaunchDaemon "1com.vendor.daemon"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call DisableLaunchDaemon --tolerant-missing --tolerant-missing "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with duplicate --needs-root flag'
    When call DisableLaunchDaemon --needs-root --needs-root "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call DisableLaunchDaemon --bogus "com.vendor.app.daemon"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with multiple non-flag arguments'
    When call DisableLaunchDaemon "com.vendor.app.daemon" "com.vendor.app.other"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root check (rc 3)
  # ─────────────────────────═══════════════════════════════════════
  # Daemons always require root — no --needs-root flag needed

  It 'returns 3 when not run as root'
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call DisableLaunchDaemon "com.vendor.app.daemon"
    The status should eq 3
    The output should include "Needs root"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when daemon is absent in system domain and --tolerant-missing is set'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="false"
    When call DisableLaunchDaemon --tolerant-missing "com.nonexistent.app.daemon"
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when daemon is not found in system domain without --tolerant-missing'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="false"
    When call DisableLaunchDaemon "com.nonexistent.app.daemon"
    The status should eq 4
    The output should include "not found"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when daemon is successfully disabled'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="true"
    export MOCK_LAUNCHCTL_DISABLE_VERIFIED="true"
    export MOCK_LAUNCHCTL_LABEL="com.vendor.app.daemon"
    When call DisableLaunchDaemon "com.vendor.app.daemon"
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when disable succeeds but verify shows still enabled'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="true"
    export MOCK_LAUNCHCTL_DISABLE_VERIFIED="false"
    export MOCK_LAUNCHCTL_LABEL="com.vendor.app.daemon"
    When call DisableLaunchDaemon "com.vendor.app.daemon"
    The status should eq 5
    The output should include "Verify failed"
  End

  It 'returns 5 when print-disabled has stderr during verification'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="true"
    export MOCK_LAUNCHCTL_PRINT_DISABLED_STDERR="true"
    export MOCK_LAUNCHCTL_LABEL="com.vendor.app.daemon"
    When call DisableLaunchDaemon "com.vendor.app.daemon"
    The status should eq 5
    The output should include "Verify failed"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when launchctl is not found'
    export LAUNCHCTL_BIN="/nonexistent/launchctl"
    unset -f /bin/launchctl 2>/dev/null || true
    When call DisableLaunchDaemon "com.vendor.app.daemon"
    The status should eq 1
    The output should include "Missing required tool"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the label'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="false"
    When call DisableLaunchDaemon --tolerant-missing "com.nonexistent.app.daemon"
    The status should eq 0
  End

  It 'accepts flags after the label'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="false"
    When call DisableLaunchDaemon "com.nonexistent.app.daemon" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles labels with underscores correctly'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="true"
    export MOCK_LAUNCHCTL_DISABLE_VERIFIED="true"
    export MOCK_LAUNCHCTL_LABEL="com.test_vendor.app.daemon"
    When call DisableLaunchDaemon "com.test_vendor.app.daemon"
    The status should eq 0
  End

  It 'handles labels with hyphens correctly'
    export MOCK_LAUNCHCTL_DAEMON_EXISTS="true"
    export MOCK_LAUNCHCTL_DISABLE_VERIFIED="true"
    export MOCK_LAUNCHCTL_LABEL="com.test-vendor.app.daemon"
    When call DisableLaunchDaemon "com.test-vendor.app.daemon"
    The status should eq 0
  End

End
