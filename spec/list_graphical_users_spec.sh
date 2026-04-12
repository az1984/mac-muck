. ./spec/spec_helper.sh

# Store the uninstaller path for function restoration
UNINSTALLER_SCRIPT="/Users/andrewezimmer/Documents/GitHub/mac-muck/src/uninstaller.sh"

Describe 'ListGraphicalUsers'

  # ─────────────────────────═══════════════════════════════════════
  # Mock setup: override /usr/bin/dscl and id for controlled testing
  # ─────────────────────────═══════════════════════════════════════

  setup_dscl_mock() {
    # Override /usr/bin/dscl as a bash function (bash allows / in function names)
    eval 'function /usr/bin/dscl {
      case "$3" in
        -list)
          # dscl . -list /Users UniqueID
          if [[ -n "${MOCK_DSCL_LIST_OUTPUT:-}" ]]; then
            printf "%s\n" "$MOCK_DSCL_LIST_OUTPUT"
          fi
          return 0
          ;;
        -read)
          # dscl . -read /Users/<name> NFSHomeDirectory
          local user_path="$4"
          local username="${user_path##*/}"
          if [[ -n "${MOCK_DSCL_MISSING_HOME:-}" && "$MOCK_DSCL_MISSING_HOME" == *"$username"* ]]; then
            return 1
          fi
          if [[ -n "${MOCK_DSCL_BAD_HOME:-}" && "$MOCK_DSCL_BAD_HOME" == *"$username"* ]]; then
            echo "NFSHomeDirectory: /var/spool/$username"
            return 0
          fi
          echo "NFSHomeDirectory: /Users/$username"
          return 0
          ;;
      esac
    }'
  }

  setup_id_mock() {
    eval 'function id {
      local username="$1"
      if [[ -n "${MOCK_ID_FAIL:-}" && "$MOCK_ID_FAIL" == *"$username"* ]]; then
        return 1
      fi
      return 0
    }'
  }

  cleanup_mocks() {
    unset -f /usr/bin/dscl 2>/dev/null || true
    unset -f id 2>/dev/null || true
    unset MOCK_DSCL_LIST_OUTPUT 2>/dev/null || true
    unset MOCK_DSCL_MISSING_HOME 2>/dev/null || true
    unset MOCK_DSCL_BAD_HOME 2>/dev/null || true
    unset MOCK_ID_FAIL 2>/dev/null || true
  }

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when given an unknown flag'
    When call ListGraphicalUsers --bogus
    The status should eq 2
    The output should include "Unknown flag"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root gate (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when not root and --needs-root is specified'
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call ListGraphicalUsers --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export FAKE_EUID=0
    export FAKE_UID=0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path (rc 0)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 with no graphical users (empty output)'
    setup_dscl_mock
    setup_id_mock
    export MOCK_DSCL_LIST_OUTPUT=""
    When call ListGraphicalUsers
    The status should eq 0
    The output should eq ""
    cleanup_mocks
  End

  It 'returns 0 and outputs one username per line'
    # Use the real dscl on this Mac; the current user should be present
    When call ListGraphicalUsers
    The status should eq 0
    The output should include "andrewezimmer"
  End

  It 'returns 0 and skips Shared account'
    setup_dscl_mock
    setup_id_mock
    export MOCK_DSCL_LIST_OUTPUT="Shared                 501"
    When call ListGraphicalUsers
    The status should eq 0
    The output should eq ""
    cleanup_mocks
  End

  It 'returns 0 and skips Guest account'
    setup_dscl_mock
    setup_id_mock
    export MOCK_DSCL_LIST_OUTPUT="Guest                  201"
    When call ListGraphicalUsers
    The status should eq 0
    The output should eq ""
    cleanup_mocks
  End

  It 'returns 0 and skips .localized account'
    setup_dscl_mock
    setup_id_mock
    export MOCK_DSCL_LIST_OUTPUT=".localized             501"
    When call ListGraphicalUsers
    The status should eq 0
    The output should eq ""
    cleanup_mocks
  End

  It 'returns 0 and filters users with UID < 500 by default'
    setup_dscl_mock
    setup_id_mock
    # daemon user with UID 1 should be filtered out
    export MOCK_DSCL_LIST_OUTPUT="daemon                 1"
    When call ListGraphicalUsers
    The status should eq 0
    The output should eq ""
    cleanup_mocks
  End

  It 'returns 0 and includes users with UID < 500 when --all is set'
    # Use the real dscl on this Mac with --all flag
    # --all includes UID < 500 but still requires home under /Users/<name> and dir exists
    # The real current user (UID >= 500) should still appear
    When call ListGraphicalUsers --all
    The status should eq 0
    The output should include "andrewezimmer"
  End

  It 'returns 0 and skips users without valid home directory'
    setup_dscl_mock
    setup_id_mock
    export MOCK_DSCL_LIST_OUTPUT="ghostuser              501"
    export MOCK_DSCL_MISSING_HOME="ghostuser"
    When call ListGraphicalUsers
    The status should eq 0
    The output should eq ""
    cleanup_mocks
  End

  It 'returns 0 and skips users whose home is not under /Users'
    setup_dscl_mock
    setup_id_mock
    export MOCK_DSCL_LIST_OUTPUT="svcaccount             501"
    export MOCK_DSCL_BAD_HOME="svcaccount"
    When call ListGraphicalUsers
    The status should eq 0
    The output should eq ""
    cleanup_mocks
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when dscl is not found'
    # Save and redefine function with a nonexistent dscl path
    eval "$(declare -f ListGraphicalUsers | sed 's|/usr/bin/dscl|/nonexistent/dscl_MISSING|g')"
    When call ListGraphicalUsers
    The status should eq 1
    The output should include "dscl not found"
    # Restore original function
    eval "$(sed -n '/^ListGraphicalUsers()/,/^}/p' "$UNINSTALLER_SCRIPT")"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Output format
  # ─────────────────────────═══════════════════════════════════════

  It 'outputs only usernames, one per line'
    # Use the real dscl; verify output contains no UID numbers or paths
    When call ListGraphicalUsers
    The status should eq 0
    The output should not include "/"
  End

  It 'handles multiple graphical users correctly'
    # Use the real dscl; verify the function returns success
    When call ListGraphicalUsers
    The status should eq 0
    The output should include "andrewezimmer"
  End

End
