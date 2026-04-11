. ./spec/spec_helper.sh
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
    The output should include "Unknown flag"
  End

  It 'returns 2 when given duplicate flags'
    When call RemoveLoginItems "com.vendor.helper" --tolerant-missing --tolerant-missing
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 when identifier format is invalid (only 2 labels)'
    When call RemoveLoginItems "com.vendor"
    The status should eq 2
    The output should include "Invalid identifier"
  End

  It 'returns 2 when identifier format is invalid (single label)'
    When call RemoveLoginItems "vendor"
    The status should eq 2
    The output should include "Invalid identifier"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root gate (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when IdentifyLoginItemType requires root'
    Skip "Requires non-root execution context to test the root guard"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Missing identifier tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when identifier not found without --tolerant-missing'
    Skip "Requires mocking IdentifyLoginItemType to return not found"
  End

  It 'returns 0 when identifier not found with --tolerant-missing'
    Skip "Requires mocking IdentifyLoginItemType to return not found"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - daemon
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to UnloadAndRemoveLaunchDaemon when TYPE=daemon'
    Skip "Requires mocking IdentifyLoginItemType to return daemon type"
  End

  It 'returns 5 when UnloadAndRemoveLaunchDaemon fails for daemon type'
    Skip "Requires mocking daemon removal failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - agent
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to UnloadAndRemoveLaunchAgent when TYPE=agent'
    Skip "Requires mocking IdentifyLoginItemType to return agent type"
  End

  It 'returns 5 when UnloadAndRemoveLaunchAgent fails for agent type'
    Skip "Requires mocking agent removal failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - helper
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to RemovePrivilegedHelper when TYPE=helper'
    Skip "Requires mocking IdentifyLoginItemType to return helper type"
  End

  It 'returns 5 when RemovePrivilegedHelper fails for helper type'
    Skip "Requires mocking helper removal failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - app
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to SafeRemovePath when TYPE=app with path'
    Skip "Requires mocking IdentifyLoginItemType to return app type with path"
  End

  It 'returns 5 when TYPE=app has no path available'
    Skip "Requires mocking IdentifyLoginItemType to return app type with empty path"
  End

  It 'returns 5 when SafeRemovePath fails for app type'
    Skip "Requires mocking app removal failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - login_item
  # ─────────────────────────═══════════════════════════════════════

  It 'routes to SafeRemovePath when TYPE=login_item with path'
    Skip "Requires mocking IdentifyLoginItemType to return login_item type with path"
  End

  It 'returns 5 when TYPE=login_item has no path available'
    Skip "Requires mocking IdentifyLoginItemType to return login_item type with empty path"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Type routing tests - unknown
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when TYPE=unknown'
    Skip "Requires mocking IdentifyLoginItemType to return unknown type"
  End

  It 'returns 5 when TYPE is unrecognized'
    Skip "Requires mocking IdentifyLoginItemType to return unrecognized type"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when IdentifyLoginItemType function is not defined'
    Skip "Requires mocking missing IdentifyLoginItemType function"
  End

  It 'returns 1 when IdentifyLoginItemType fails'
    Skip "Requires mocking IdentifyLoginItemType failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Output parsing tests
  # ─────────────────────────═══════════════════════════════════════

  It 'parses TYPE= from IdentifyLoginItemType output'
    Skip "Requires mocking IdentifyLoginItemType output"
  End

  It 'parses PATH= from IdentifyLoginItemType output'
    Skip "Requires mocking IdentifyLoginItemType output"
  End

  It 'parses DISPOSITION= from IdentifyLoginItemType output'
    Skip "Requires mocking IdentifyLoginItemType output"
  End

  It 'returns 1 when TYPE cannot be parsed from output'
    Skip "Requires mocking malformed IdentifyLoginItemType output"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags after the identifier'
    When call RemoveLoginItems "com.vendor.helper" --tolerant-missing
    The status should eq 0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles identifiers with underscores correctly'
    Skip "Requires mocking IdentifyLoginItemType with underscore identifier"
  End

  It 'handles identifiers with hyphens correctly'
    Skip "Requires mocking IdentifyLoginItemType with hyphen identifier"
  End

End