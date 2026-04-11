. ./spec/spec_helper.sh
Describe 'RemoveFinderExtension'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call RemoveFinderExtension
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when unknown flag is provided'
    When call RemoveFinderExtension --bogus "com.vendor.extension"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 when duplicate --tolerant-missing flag is provided'
    When call RemoveFinderExtension --tolerant-missing "com.vendor.extension" --tolerant-missing
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 when duplicate --needs-root flag is provided'
    When call RemoveFinderExtension --needs-root "com.vendor.extension" --needs-root
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 when multiple non-flag arguments are provided'
    When call RemoveFinderExtension "com.vendor.extension" "com.another.extension"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  It 'returns 2 when bundle ID format is invalid (only 2 labels)'
    When call RemoveFinderExtension "com.vendor"
    The status should eq 2
    The output should include "Invalid bundle ID format"
  End

  It 'returns 2 when bundle ID format is invalid (single label)'
    When call RemoveFinderExtension "vendor"
    The status should eq 2
    The output should include "Invalid bundle ID format"
  End

  It 'returns 2 when bundle ID starts with number'
    When call RemoveFinderExtension "1com.vendor.extension"
    The status should eq 2
    The output should include "Invalid bundle ID format"
  End

  # --- Root check (rc 3) ---
  It 'returns 3 when not root and --needs-root is specified'
    export EUID=1000
    export UID=1000
    When call RemoveFinderExtension "com.vendor.extension" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export EUID=0
    export UID=0
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when extension is not registered and --tolerant-missing is set'
    export EUID=0
    export UID=0
    export MOCK_PLUGINKIT_MODE="not_found"
    When call RemoveFinderExtension --tolerant-missing "com.nonexistent.extension"
    The status should eq 0
    unset MOCK_PLUGINKIT_MODE
    export EUID=1000
    export UID=1000
  End

  # --- Strict missing (rc 4 when absent) ---
  It 'returns 4 when extension is not registered without --tolerant-missing'
    export EUID=0
    export UID=0
    export MOCK_PLUGINKIT_MODE="not_found"
    When call RemoveFinderExtension "com.nonexistent.extension"
    The status should eq 4
    The output should include "not registered"
    unset MOCK_PLUGINKIT_MODE
    export EUID=1000
    export UID=1000
  End

  # --- Happy path (rc 0 when present and removed) ---
  It 'returns 0 when extension is successfully removed'
    export EUID=0
    export UID=0
    export MOCK_PLUGINKIT_MODE="success"
    When call RemoveFinderExtension "com.vendor.extension"
    The status should eq 0
    unset MOCK_PLUGINKIT_MODE
    export EUID=1000
    export UID=1000
  End

  # --- Verify-after failure (rc 5) ---
  It 'returns 5 when extension is still registered after removal attempt'
    export EUID=0
    export UID=0
    export MOCK_PLUGINKIT_MODE="still_registered"
    When call RemoveFinderExtension "com.vendor.extension"
    The status should eq 5
    The output should include "still registered"
    unset MOCK_PLUGINKIT_MODE
    export EUID=1000
    export UID=1000
  End

  # --- Tool presence check (rc 1) ---
  It 'returns 1 when pluginkit is not found'
    export EUID=0
    export UID=0
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call RemoveFinderExtension "com.vendor.extension"
      The status should eq 1
      The output should include "pluginkit not found"
    )
    export PATH="$old_path"
    export EUID=1000
    export UID=1000
  End

End