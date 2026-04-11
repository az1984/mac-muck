. ./spec/spec_helper.sh
Describe 'RemoveQuickLookPlugin'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call RemoveQuickLookPlugin
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when unknown flag is provided'
    When call RemoveQuickLookPlugin --bogus "/Library/QuickLook/test.qlgenerator"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 when duplicate --tolerant-missing flag is provided'
    When call RemoveQuickLookPlugin --tolerant-missing "/Library/QuickLook/test.qlgenerator" --tolerant-missing
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 when duplicate --needs-root flag is provided'
    When call RemoveQuickLookPlugin --needs-root "/Library/QuickLook/test.qlgenerator" --needs-root
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 when multiple non-flag arguments are provided'
    When call RemoveQuickLookPlugin "/Library/QuickLook/test1.qlgenerator" "/Library/QuickLook/test2.qlgenerator"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  It 'returns 2 when path is not absolute'
    When call RemoveQuickLookPlugin "Library/QuickLook/test.qlgenerator"
    The status should eq 2
    The output should include "absolute"
  End

  It 'returns 2 when path does not end with .qlgenerator'
    When call RemoveQuickLookPlugin "/Library/QuickLook/test.plist"
    The status should eq 2
    The output should include ".qlgenerator"
  End

  It 'returns 2 when path ends with wrong extension (case sensitive)'
    When call RemoveQuickLookPlugin "/Library/QuickLook/test.QlGenerator"
    The status should eq 2
    The output should include ".qlgenerator"
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when plugin does not exist and --tolerant-missing is set'
    When call RemoveQuickLookPlugin --tolerant-missing "/Library/QuickLook/nonexistent.qlgenerator"
    The status should eq 0
  End

  # --- Strict missing (rc 4 when absent) ---
  It 'returns 4 when plugin does not exist without --tolerant-missing'
    When call RemoveQuickLookPlugin "/Library/QuickLook/nonexistent.qlgenerator"
    The status should eq 4
    The output should include "not present"
  End

  # --- Happy path (rc 0 when present and removed) ---
  It 'returns 0 when plugin is successfully removed'
    local test_plugin="/tmp/test_plugin_$$"
    mkdir -p "$test_plugin"
    # Mock SafeRemovePath to succeed
    SafeRemovePath() { return 0; }
    When call RemoveQuickLookPlugin "$test_plugin"
    The status should eq 0
    rm -rf "$test_plugin"
  End

  # --- Verify-after failure (rc 5) ---
  It 'returns 5 when plugin still exists after removal attempt'
    local test_plugin="/tmp/test_plugin_verify_$$"
    mkdir -p "$test_plugin"
    # Mock SafeRemovePath to succeed but path persists
    SafeRemovePath() { return 0; }
    When call RemoveQuickLookPlugin "$test_plugin"
    The status should eq 5
    rm -rf "$test_plugin"
  End

  # --- SafeRemovePath failure (rc 5) ---
  It 'returns 5 when SafeRemovePath reports failure'
    local test_plugin="/tmp/test_plugin_fail_$$"
    mkdir -p "$test_plugin"
    # Mock SafeRemovePath to fail
    SafeRemovePath() { return 5; }
    When call RemoveQuickLookPlugin "$test_plugin"
    The status should eq 5
    rm -rf "$test_plugin"
  End

End