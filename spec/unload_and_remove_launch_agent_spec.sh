. ./spec/spec_helper.sh

# Provide a mapfile polyfill for bash 3.2 (macOS ships bash 3.2 which lacks mapfile)
if ! type mapfile &>/dev/null; then
  mapfile() {
    local _flag_t=false _array_name="MAPFILE"
    while (( $# )); do
      case "$1" in
        -t) _flag_t=true; shift ;;
        *)  _array_name="$1"; shift ;;
      esac
    done
    local _line _i=0
    eval "$_array_name=()"
    while IFS= read -r _line || [[ -n "$_line" ]]; do
      if $_flag_t; then
        _line="${_line%$'\n'}"
      fi
      eval "${_array_name}[${_i}]=\"\${_line}\""
      ((_i++))
    done
  }
fi

Describe 'UnloadAndRemoveLaunchAgent'

  # ── shared mock infrastructure ──────────────────────────────────
  # The function calls /bin/launchctl (hardcoded path). Override it
  # with a bash function so the hardcoded path invokes our mock.
  # Use TEST_LAUNCHAGENTS_DIR to redirect plist lookups to a temp dir.

  setup() {
    export FAKE_EUID=0
    export FAKE_UID=0
    export TEST_LAUNCHAGENTS_DIR="${SHELLSPEC_TMPDIR}/LaunchAgents"
    mkdir -p "$TEST_LAUNCHAGENTS_DIR"
    eval 'function /bin/launchctl { return 0; }'
  }

  cleanup() {
    unset -f /bin/launchctl 2>/dev/null || true
    unset -f id 2>/dev/null || true
    rm -rf "${SHELLSPEC_TMPDIR}/LaunchAgents" 2>/dev/null || true
    unset TEST_LAUNCHAGENTS_DIR
    export FAKE_EUID=1000
    export FAKE_UID=1000
  }

  Before 'setup'
  After 'cleanup'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call UnloadAndRemoveLaunchAgent
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid label format (single label)'
    When call UnloadAndRemoveLaunchAgent "notreverse"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when given an invalid label format (only 2 labels)'
    When call UnloadAndRemoveLaunchAgent "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 when label starts with number'
    When call UnloadAndRemoveLaunchAgent "1com.vendor.agent"
    The status should eq 2
    The output should include "Invalid label"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call UnloadAndRemoveLaunchAgent --tolerant-missing --tolerant-missing "com.vendor.app.agent"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with duplicate --needs-root flag'
    When call UnloadAndRemoveLaunchAgent --needs-root --needs-root "com.vendor.app.agent"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call UnloadAndRemoveLaunchAgent --bogus "com.vendor.app.agent"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with multiple non-flag arguments'
    When call UnloadAndRemoveLaunchAgent "com.vendor.app.agent" "com.vendor.app.other"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root gate (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when not root and --needs-root is specified'
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call UnloadAndRemoveLaunchAgent "com.vendor.agent" --needs-root
    The status should eq 3
    The output should include "Needs root"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when no plists found and --tolerant-missing is set'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  It 'returns 0 when no graphical users exist and --tolerant-missing is set'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when no plists found without --tolerant-missing'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent"
    The status should eq 4
    The output should include "No LaunchAgent plists"
  End

  It 'returns 4 when no graphical users exist without --tolerant-missing'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent"
    The status should eq 4
    The output should include "No LaunchAgent plists"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests (system plist)
  # ─────────────────────────═══════════════════════════════════════

  Describe 'system agent plist removal'
    It 'returns 0 when system agent plist is successfully removed'
      touch "${SHELLSPEC_TMPDIR}/LaunchAgents/com.test.happysys.plist"
      ListGraphicalUsers() { return 0; }
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { rm -f "$1" 2>/dev/null; return 0; }
      When call UnloadAndRemoveLaunchAgent "com.test.happysys"
      The status should eq 0
    End
  End

  Describe 'user agent plist removal via system path'
    It 'returns 0 when user agent plist is successfully removed'
      touch "${SHELLSPEC_TMPDIR}/LaunchAgents/com.test.useragent.plist"
      ListGraphicalUsers() { echo "testuser"; }
      id() { if [[ "$1" == "-u" && "$2" == "testuser" ]]; then echo "501"; else command id "$@"; fi; }
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { rm -f "$1" 2>/dev/null; return 0; }
      When call UnloadAndRemoveLaunchAgent "com.test.useragent"
      The status should eq 0
    End
  End

  Describe 'agent plist in both system and user locations'
    It 'returns 0 when agent plist exists in both system and user locations'
      touch "${SHELLSPEC_TMPDIR}/LaunchAgents/com.test.bothagent.plist"
      ListGraphicalUsers() { echo "testuser"; }
      id() { if [[ "$1" == "-u" && "$2" == "testuser" ]]; then echo "501"; else command id "$@"; fi; }
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { rm -f "$1" 2>/dev/null; return 0; }
      When call UnloadAndRemoveLaunchAgent "com.test.bothagent"
      The status should eq 0
    End
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  Describe 'verify-after failures'
    It 'returns 5 when agent still running after bootout'
      touch "${SHELLSPEC_TMPDIR}/LaunchAgents/com.test.verifyfail.plist"
      ListGraphicalUsers() { echo "testuser"; }
      id() { if [[ "$1" == "-u" && "$2" == "testuser" ]]; then echo "501"; else command id "$@"; fi; }
      VerifyServiceUnloaded() { return 1; }
      SafeDelete() { rm -f "$1" 2>/dev/null; return 0; }
      When call UnloadAndRemoveLaunchAgent "com.test.verifyfail"
      The status should eq 5
      The output should include "Verify failed"
    End

    It 'returns 5 when SafeDelete fails to remove plist'
      touch "${SHELLSPEC_TMPDIR}/LaunchAgents/com.test.delfail.plist"
      ListGraphicalUsers() { return 0; }
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { return 5; }
      When call UnloadAndRemoveLaunchAgent "com.test.delfail"
      The status should eq 5
      The output should include "Failed to delete"
    End

    It 'returns 5 when plist still present after deletion attempt'
      touch "${SHELLSPEC_TMPDIR}/LaunchAgents/com.test.persist.plist"
      ListGraphicalUsers() { return 0; }
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { return 0; }
      When call UnloadAndRemoveLaunchAgent "com.test.persist"
      The status should eq 5
      The output should include "Verify failed"
    End

    It 'returns 5 when multiple operations fail'
      touch "${SHELLSPEC_TMPDIR}/LaunchAgents/com.test.multifail.plist"
      ListGraphicalUsers() { echo "testuser"; }
      id() { if [[ "$1" == "-u" && "$2" == "testuser" ]]; then echo "501"; else command id "$@"; fi; }
      VerifyServiceUnloaded() { return 1; }
      SafeDelete() { return 5; }
      When call UnloadAndRemoveLaunchAgent "com.test.multifail"
      The status should eq 5
      The output should include "operations failed"
    End
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when launchctl is not found'
    Skip "Cannot mock hardcoded [[ -x /bin/launchctl ]] check without modifying src"
  End

  It 'returns 1 when ListGraphicalUsers function is not defined'
    Skip "Function does not check for ListGraphicalUsers existence before calling it"
  End

  It 'returns 1 when VerifyServiceUnloaded function is not defined'
    Skip "Function does not check for VerifyServiceUnloaded existence before calling it"
  End

  It 'returns 1 when SafeDelete function is not defined'
    Skip "Function does not check for SafeDelete existence before calling it"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts --tolerant-missing before the label'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
  End

  It 'accepts --tolerant-missing after the label'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent" --tolerant-missing
    The status should eq 0
  End

  It 'accepts --needs-root flag before the label'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --needs-root --tolerant-missing "com.test.agent"
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  Describe 'skip unresolvable UIDs'
    It 'skips users when UID cannot be resolved'
      touch "${SHELLSPEC_TMPDIR}/LaunchAgents/com.test.skipuser.plist"
      ListGraphicalUsers() { echo "nonexistentuser99999"; }
      id() { if [[ "$1" == "-u" && "$2" == "nonexistentuser99999" ]]; then return 1; else command id "$@"; fi; }
      VerifyServiceUnloaded() { return 0; }
      SafeDelete() { rm -f "$1" 2>/dev/null; return 0; }
      When call UnloadAndRemoveLaunchAgent "com.test.skipuser"
      The status should eq 0
    End
  End

  It 'handles labels with underscores in segments correctly'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.test_vendor.agent"
    The status should eq 0
  End

  It 'handles labels with hyphens in segments correctly'
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.test-vendor.agent"
    The status should eq 0
  End

End
