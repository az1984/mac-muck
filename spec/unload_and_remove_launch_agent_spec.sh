. ./spec/spec_helper.sh
Describe 'UnloadAndRemoveLaunchAgent'

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
    export EUID=1000
    export UID=1000
    When call UnloadAndRemoveLaunchAgent "com.vendor.agent" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export EUID=0
    export UID=0
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when no plists found and --tolerant-missing is set'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  It 'returns 0 when no graphical users exist and --tolerant-missing is set'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when no plists found without --tolerant-missing'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent"
    The status should eq 4
    The output should include "No LaunchAgent plists"
    export EUID=1000
    export UID=1000
  End

  It 'returns 4 when no graphical users exist without --tolerant-missing'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent"
    The status should eq 4
    export EUID=1000
    export UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when system agent plist is successfully removed'
    export EUID=0
    export UID=0
    local test_plist="/tmp/test_agent_$$"
    mkdir -p /Library/LaunchAgents
    touch "$test_plist"
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to succeed
    VerifyServiceUnloaded() { return 0; }
    # Mock SafeDelete to succeed
    SafeDelete() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 0
    rm -f "$test_plist"
    export EUID=1000
    export UID=1000
  End

  It 'returns 0 when user agent plist is successfully removed'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a test user
    ListGraphicalUsers() { echo "testuser"; }
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to succeed
    VerifyServiceUnloaded() { return 0; }
    # Mock SafeDelete to succeed
    SafeDelete() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  It 'returns 0 when agent plist exists in both system and user locations'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a test user
    ListGraphicalUsers() { echo "testuser"; }
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to succeed
    VerifyServiceUnloaded() { return 0; }
    # Mock SafeDelete to succeed
    SafeDelete() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when agent still running after bootout'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a test user
    ListGraphicalUsers() { echo "testuser"; }
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to fail (still running)
    VerifyServiceUnloaded() { return 1; }
    # Mock SafeDelete to succeed
    SafeDelete() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 5
    export EUID=1000
    export UID=1000
  End

  It 'returns 5 when SafeDelete fails to remove plist'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a test user
    ListGraphicalUsers() { echo "testuser"; }
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to succeed
    VerifyServiceUnloaded() { return 0; }
    # Mock SafeDelete to fail
    SafeDelete() { return 5; }
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 5
    export EUID=1000
    export UID=1000
  End

  It 'returns 5 when plist still present after deletion attempt'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a test user
    ListGraphicalUsers() { echo "testuser"; }
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to succeed
    VerifyServiceUnloaded() { return 0; }
    # Mock SafeDelete to succeed but file persists
    SafeDelete() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 5
    export EUID=1000
    export UID=1000
  End

  It 'returns 5 when multiple operations fail'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a test user
    ListGraphicalUsers() { echo "testuser"; }
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to fail
    VerifyServiceUnloaded() { return 1; }
    # Mock SafeDelete to fail
    SafeDelete() { return 5; }
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 5
    export EUID=1000
    export UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when launchctl is not found'
    export EUID=0
    export UID=0
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call UnloadAndRemoveLaunchAgent "com.test.agent"
      The status should eq 1
      The output should include "launchctl not found"
    )
    export PATH="$old_path"
    export EUID=1000
    export UID=1000
  End

  It 'returns 1 when ListGraphicalUsers function is not defined'
    export EUID=0
    export UID=0
    # Temporarily remove ListGraphicalUsers
    local orig_ListGraphicalUsers="$ListGraphicalUsers"
    unset ListGraphicalUsers
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 1
    export EUID=1000
    export UID=1000
  End

  It 'returns 1 when VerifyServiceUnloaded function is not defined'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a test user
    ListGraphicalUsers() { echo "testuser"; }
    # Temporarily remove VerifyServiceUnloaded
    local orig_VerifyServiceUnloaded="$VerifyServiceUnloaded"
    unset VerifyServiceUnloaded
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 1
    export EUID=1000
    export UID=1000
  End

  It 'returns 1 when SafeDelete function is not defined'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a test user
    ListGraphicalUsers() { echo "testuser"; }
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to succeed
    VerifyServiceUnloaded() { return 0; }
    # Temporarily remove SafeDelete
    local orig_SafeDelete="$SafeDelete"
    unset SafeDelete
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 1
    export EUID=1000
    export UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts --tolerant-missing before the label'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  It 'accepts --tolerant-missing after the label'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.nonexistent.app.agent" --tolerant-missing
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  It 'accepts --needs-root flag before the label'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --needs-root "com.test.agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'skips users when UID cannot be resolved'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return a user without UID
    ListGraphicalUsers() { echo "nouser"; }
    # Mock launchctl to succeed
    launchctl() { return 0; }
    # Mock VerifyServiceUnloaded to succeed
    VerifyServiceUnloaded() { return 0; }
    # Mock SafeDelete to succeed
    SafeDelete() { return 0; }
    When call UnloadAndRemoveLaunchAgent "com.test.agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  It 'handles labels with underscores correctly'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com_test_agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

  It 'handles labels with hyphens correctly'
    export EUID=0
    export UID=0
    # Mock ListGraphicalUsers to return empty
    ListGraphicalUsers() { return 0; }
    When call UnloadAndRemoveLaunchAgent --tolerant-missing "com-test-agent"
    The status should eq 0
    export EUID=1000
    export UID=1000
  End

End