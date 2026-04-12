. ./spec/spec_helper.sh

# Mock IdentifyLoginItemType for testing
IdentifyLoginItemType() {
  local mode="${MOCK_IDENTIFY_LOGIN_ITEM_MODE:-not_found}"
  local identifier="$1"
  
  case "$mode" in
    not_found)
      # Return not found (rc 4)
      return 4 ;;
    daemon)
      echo "TYPE=daemon PATH=/Library/LaunchDaemons/com.test.daemon.plist DISPOSITION=enabled"
      return 0 ;;
    agent)
      echo "TYPE=agent PATH=/Library/LaunchAgents/com.test.agent.plist DISPOSITION=enabled"
      return 0 ;;
    helper)
      echo "TYPE=helper PATH=/Library/PrivilegedHelperTools/com.test.helper DISPOSITION=enabled"
      return 0 ;;
    app)
      echo "TYPE=app PATH=/Applications/Test.app DISPOSITION=enabled"
      return 0 ;;
    app_no_path)
      echo "TYPE=app PATH= DISPOSITION=enabled"
      return 0 ;;
    login_item)
      echo "TYPE=login_item PATH=/Applications/LoginItem.app DISPOSITION=enabled"
      return 0 ;;
    login_item_no_path)
      echo "TYPE=login_item PATH= DISPOSITION=enabled"
      return 0 ;;
    unknown)
      echo "TYPE=unknown PATH=/some/path DISPOSITION=enabled"
      return 0 ;;
    unrecognized)
      echo "TYPE=custom_type PATH=/some/path DISPOSITION=enabled"
      return 0 ;;
    needs_root)
      echo "Needs root: sfltool dumpbtm requires root."
      return 3 ;;
    fail)
      return 1 ;;
    *)
      return 4 ;;
  esac
}

Describe 'RemoveLoginItems'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call RemoveLoginItems
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given too many arguments'
    When call RemoveLoginItems "com.vendor.one" "com.vendor.two"
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an unknown flag'
    When call RemoveLoginItems "com.vendor.helper" --bogus
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 when given duplicate flags'
    When call RemoveLoginItems "com.vendor.helper" --tolerant-missing --tolerant-missing
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 4 when identifier has 2 labels but is not found'
    # Note: RemoveLoginItems uses ≥2 labels validation (more permissive than other functions)
    # "com.vendor" passes validation but then fails at IdentifyLoginItemType (rc 4)
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="not_found"
    When call RemoveLoginItems "com.vendor"
    The status should eq 4
    The output should include "not found"
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 2 when identifier format is invalid (single label)'
    When call RemoveLoginItems "vendor"
    The status should eq 2
    The output should include "Invalid identifier"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root gate (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when IdentifyLoginItemType returns rc 3 (needs root)'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="needs_root"
    When call RemoveLoginItems "com.test.helper"
    The status should eq 1
    The output should include "IdentifyLoginItemType failed with rc 3"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Missing identifier tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when identifier not found without --tolerant-missing'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="not_found"
    When call RemoveLoginItems "com.nonexistent"
    The status should eq 4
    The output should include "not found"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 0 when identifier not found with --tolerant-missing'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="not_found"
    When call RemoveLoginItems "com.nonexistent" --tolerant-missing
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - daemon
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to UnloadAndRemoveLaunchDaemon when TYPE=daemon'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="daemon"
    # Mock UnloadAndRemoveLaunchDaemon to succeed
    UnloadAndRemoveLaunchDaemon() { return 0; }
    When call RemoveLoginItems "com.test.daemon"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 5 when UnloadAndRemoveLaunchDaemon fails for daemon type'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="daemon"
    # Mock UnloadAndRemoveLaunchDaemon to fail
    UnloadAndRemoveLaunchDaemon() { return 5; }
    When call RemoveLoginItems "com.test.daemon"
    The status should eq 5
    The output should include "Removal failed"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - agent
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to UnloadAndRemoveLaunchAgent when TYPE=agent'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="agent"
    # Mock UnloadAndRemoveLaunchAgent to succeed
    UnloadAndRemoveLaunchAgent() { return 0; }
    When call RemoveLoginItems "com.test.agent"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 5 when UnloadAndRemoveLaunchAgent fails for agent type'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="agent"
    # Mock UnloadAndRemoveLaunchAgent to fail
    UnloadAndRemoveLaunchAgent() { return 5; }
    When call RemoveLoginItems "com.test.agent"
    The status should eq 5
    The output should include "Removal failed"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - helper
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to RemovePrivilegedHelper when TYPE=helper'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="helper"
    # Mock RemovePrivilegedHelper to succeed
    RemovePrivilegedHelper() { return 0; }
    When call RemoveLoginItems "com.test.helper"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 5 when RemovePrivilegedHelper fails for helper type'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="helper"
    # Mock RemovePrivilegedHelper to fail
    RemovePrivilegedHelper() { return 5; }
    When call RemoveLoginItems "com.test.helper"
    The status should eq 5
    The output should include "Removal failed"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - app
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to SafeRemovePath when TYPE=app with path'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="app"
    # Mock SafeRemovePath to succeed
    SafeRemovePath() { return 0; }
    When call RemoveLoginItems "com.test.app"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 5 when TYPE=app has no path available'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="app_no_path"
    When call RemoveLoginItems "com.test.app"
    The status should eq 5
    The output should include "No path available"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 5 when SafeRemovePath fails for app type'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="app"
    # Mock SafeRemovePath to fail
    SafeRemovePath() { return 5; }
    When call RemoveLoginItems "com.test.app"
    The status should eq 5
    The output should include "Removal failed"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - login_item
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to SafeRemovePath when TYPE=login_item with path'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="login_item"
    # Mock SafeRemovePath to succeed
    SafeRemovePath() { return 0; }
    When call RemoveLoginItems "com.test.loginitem"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 5 when TYPE=login_item has no path available'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="login_item_no_path"
    When call RemoveLoginItems "com.test.loginitem"
    The status should eq 5
    The output should include "No path available"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - unknown
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when TYPE=unknown'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="unknown"
    When call RemoveLoginItems "com.test.unknown"
    The status should eq 5
    The output should include "Unknown login item type"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 5 when TYPE is unrecognized'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="unrecognized"
    When call RemoveLoginItems "com.test.custom"
    The status should eq 5
    The output should include "Unrecognized type"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when IdentifyLoginItemType function is not defined'
    export FAKE_EUID=0
    export FAKE_UID=0
    # Save and remove IdentifyLoginItemType
    eval "$(declare -f IdentifyLoginItemType | sed '1s/IdentifyLoginItemType/_saved_IdentifyLoginItemType/')"
    unset -f IdentifyLoginItemType
    When call RemoveLoginItems "com.test.item"
    The status should eq 1
    The output should include "Missing required function"
    # Restore mock
    eval "$(declare -f _saved_IdentifyLoginItemType | sed '1s/_saved_IdentifyLoginItemType/IdentifyLoginItemType/')"
    unset -f _saved_IdentifyLoginItemType
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 1 when IdentifyLoginItemType fails'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="fail"
    When call RemoveLoginItems "com.test.item"
    The status should eq 1
    The output should include "IdentifyLoginItemType failed"
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Output parsing tests
  # ─────────────────────────═══════════════════════════════════════

  It 'parses TYPE= from IdentifyLoginItemType output'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="daemon"
    UnloadAndRemoveLaunchDaemon() { return 0; }
    When call RemoveLoginItems "com.test.daemon"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'parses PATH= from IdentifyLoginItemType output'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="app"
    SafeRemovePath() { return 0; }
    When call RemoveLoginItems "com.test.app"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'parses DISPOSITION= from IdentifyLoginItemType output'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="agent"
    UnloadAndRemoveLaunchAgent() { return 0; }
    When call RemoveLoginItems "com.test.agent"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'returns 1 when TYPE cannot be parsed from output'
    export FAKE_EUID=0
    export FAKE_UID=0
    # Custom mock that returns malformed output
    IdentifyLoginItemType() {
      echo "MALFORMED OUTPUT WITHOUT TYPE"
      return 0
    }
    When call RemoveLoginItems "com.test.item"
    The status should eq 1
    The output should include "Failed to parse TYPE"
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags after the identifier'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="not_found"
    When call RemoveLoginItems "com.test.item" --tolerant-missing
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles identifiers with underscores correctly'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="not_found"
    When call RemoveLoginItems --tolerant-missing "com.test_item"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

  It 'handles identifiers with hyphens correctly'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_IDENTIFY_LOGIN_ITEM_MODE="not_found"
    When call RemoveLoginItems --tolerant-missing "com.test-item"
    The status should eq 0
    unset MOCK_IDENTIFY_LOGIN_ITEM_MODE
    export FAKE_EUID=1000
    export FAKE_UID=1000
  End

End