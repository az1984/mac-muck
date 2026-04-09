Describe 'RemoveFinderExtension'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call RemoveFinderExtension
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid bundle id format'
    When call RemoveFinderExtension "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid"
  End

  It 'returns 2 when given a two-label identifier'
    When call RemoveFinderExtension "com.vendor"
    The status should eq 2
    The output should include "Invalid"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call RemoveFinderExtension --tolerant-missing --tolerant-missing "com.vendor.ext.finder"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call RemoveFinderExtension --bogus "com.vendor.ext.finder"
    The status should eq 2
    The output should include "unknown flag"
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when extension is absent and --tolerant-missing is set'
    # pluginkit -m -i should return empty for a nonexistent extension
    When call RemoveFinderExtension --tolerant-missing "com.nonexistent.ext.finder"
    The status should eq 0
  End

  # --- Strict missing (rc 4 when absent) ---
  It 'returns 4 when extension is absent without --tolerant-missing'
    When call RemoveFinderExtension "com.nonexistent.ext.finder"
    The status should eq 4
  End

  # --- Tool presence ---
  It 'returns 1 if pluginkit binary is missing'
    # This test requires mocking the tool path check
    # Placeholder — implement with mock/stub in test environment
    Skip "Requires mock of pluginkit binary path"
  End
End
