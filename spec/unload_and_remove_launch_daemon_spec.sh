. ./spec/spec_helper.sh

Describe 'UnloadAndRemoveLaunchDaemon'

  # ── shared mock infrastructure ──────────────────────────────────
  # Use TEST_LAUNCHDAEMONS_DIR to redirect plist lookups to a temp dir.
  # Mock /bin/launchctl as a no-op, override VerifyServiceUnloaded and SafeDelete per test.

  setup() {
    export FAKE_EUID=0
    export FAKE_UID=0
    export TEST_LAUNCHDAEMONS_DIR="${SHELLSPEC_TMPDIR}/LaunchDaemons"
    mkdir -p "$TEST_LAUNCHDAEMONS_DIR"
    eval 'function /bin/launchctl { return 0; }'
  }

  cleanup() {
    unset -f /bin/launchctl 2>/dev/null || true
    rm -rf "${SHELLSPEC_TMPDIR}/LaunchDaemons" 2>/dev/null || true
    unset TEST_LAUNCHDAEMONS_DIR
    export FAKE_EUID=1000
    export FAKE_UID=1000
  }

  Before 'setup'
  After 'cleanup'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call UnloadAndRemoveLaunchDaemon
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format (single label)'
    When call UnloadAndRemoveLaunchDaemon "notreverse"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when given an invalid label format (only 2 labels)'
    When call UnloadAndRemoveLaunchDaemon "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when label starts with number'
    When call UnloadAndRemoveLaunchDaemon "1com.vendor.daemon"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call UnloadAndRemoveLaunchDaemon --tolerant-missing --tolerant-missing "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with duplicate --needs-root flag'
    When call UnloadAndRemoveLaunchDaemon --needs-root --needs-root "com.vendor.app.daemon"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call UnloadAndRemoveLaunchDaemon --bogus "com.vendor.app.daemon"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with multiple non-flag arguments'
    When call UnloadAndRemoveLaunchDaemon "com.vendor.app.daemon" "com.vendor.app.other"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root check (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when plist exists but not root'
    touch "${SHELLSPEC_TMPDIR}/LaunchDaemons/com.test.rootcheck.plist"
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call UnloadAndRemoveLaunchDaemon "com.test.rootcheck"
    The status should eq 3
    The output should include "Needs root"
  End

  It 'returns 3 when plist not found and not root (non-tolerant)'
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call UnloadAndRemoveLaunchDaemon "com.nonexistent.app.daemon"
    The status should eq 3
    The output should include "Needs root"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when plist not found and --tolerant-missing is set'
    When call UnloadAndRemoveLaunchDaemon "com.nonexistent.app.daemon" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent and root)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when plist not found without --tolerant-missing (as root)'
    When call UnloadAndRemoveLaunchDaemon "com.nonexistent.app.daemon"
    The status should eq 4
    The output should include "not found"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when launchctl is not found'
    touch "${SHELLSPEC_TMPDIR}/LaunchDaemons/com.test.toolcheck.plist"
    export LAUNCHCTL_BIN="/nonexistent/launchctl"
    unset -f /bin/launchctl 2>/dev/null || true
    When call UnloadAndRemoveLaunchDaemon "com.test.toolcheck"
    The status should eq 1
    The output should include "Missing required tool"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests (rc 0)
  # ─────────────────────────═══════════════════════════════════════

  Describe 'daemon plist removal'
    It 'returns 0 when daemon plist is successfully removed'
      touch "${SHELLSPEC_TMPDIR}/LaunchDaemons/com.test.happydaemon.plist"
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { rm -f "$1" 2>/dev/null; return 0; }
      When call UnloadAndRemoveLaunchDaemon "com.test.happydaemon"
      The status should eq 0
    End
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  Describe 'verify-after failures'
    It 'returns 5 when daemon still running after bootout'
      touch "${SHELLSPEC_TMPDIR}/LaunchDaemons/com.test.verifyfail.plist"
      VerifyServiceUnloaded() { return 1; }
      SafeDelete() { rm -f "$1" 2>/dev/null; return 0; }
      When call UnloadAndRemoveLaunchDaemon "com.test.verifyfail"
      The status should eq 5
      The output should include "Verify failed"
    End

    It 'returns 5 when SafeDelete fails to remove plist'
      touch "${SHELLSPEC_TMPDIR}/LaunchDaemons/com.test.delfail.plist"
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { return 5; }
      When call UnloadAndRemoveLaunchDaemon "com.test.delfail"
      The status should eq 5
      The output should include "Failed to delete"
    End

    It 'returns 5 when plist still present after deletion attempt'
      touch "${SHELLSPEC_TMPDIR}/LaunchDaemons/com.test.persist.plist"
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { return 0; }
      When call UnloadAndRemoveLaunchDaemon "com.test.persist"
      The status should eq 5
      The output should include "Verify failed"
    End

    It 'returns 5 when multiple operations fail'
      touch "${SHELLSPEC_TMPDIR}/LaunchDaemons/com.test.multifail.plist"
      VerifyServiceUnloaded() { return 1; }
      SafeDelete() { return 5; }
      When call UnloadAndRemoveLaunchDaemon "com.test.multifail"
      The status should eq 5
      The output should include "operations failed"
    End
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts --tolerant-missing before the label'
    When call UnloadAndRemoveLaunchDaemon --tolerant-missing "com.nonexistent.app.daemon"
    The status should eq 0
  End

  It 'accepts --tolerant-missing after the label'
    When call UnloadAndRemoveLaunchDaemon "com.nonexistent.app.daemon" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts underscores in label components'
    When call UnloadAndRemoveLaunchDaemon "com.vendor.app_daemon" --tolerant-missing
    The status should eq 0
  End

  It 'accepts hyphens in label components'
    When call UnloadAndRemoveLaunchDaemon "com.vendor-app.daemon" --tolerant-missing
    The status should eq 0
  End

End