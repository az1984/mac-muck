. ./spec/spec_helper.sh
Describe 'RemovePrivilegedHelper'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call RemovePrivilegedHelper
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when unknown flag is provided'
    When call RemovePrivilegedHelper --bogus "/Library/PrivilegedHelperTools/com.vendor.helper"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 when duplicate --tolerant-missing flag is provided'
    When call RemovePrivilegedHelper --tolerant-missing "/Library/PrivilegedHelperTools/com.vendor.helper" --tolerant-missing
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 when duplicate --needs-root flag is provided'
    When call RemovePrivilegedHelper --needs-root "/Library/PrivilegedHelperTools/com.vendor.helper" --needs-root
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 when multiple non-flag arguments are provided'
    When call RemovePrivilegedHelper "/Library/PrivilegedHelperTools/com.vendor.helper" "/Library/PrivilegedHelperTools/com.another.helper"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  It 'returns 2 when path is not absolute'
    When call RemovePrivilegedHelper "Library/PrivilegedHelperTools/com.vendor.helper"
    The status should eq 2
    The output should include "absolute"
  End

  It 'returns 2 when path is not under /Library/PrivilegedHelperTools/'
    When call RemovePrivilegedHelper "/tmp/com.vendor.helper"
    The status should eq 2
    The output should include "PrivilegedHelperTools"
  End

  It 'returns 2 when path is under wrong directory with similar name'
    When call RemovePrivilegedHelper "/Library/PrivilegedHelperToolsExtra/com.vendor.helper"
    The status should eq 2
    The output should include "PrivilegedHelperTools"
  End

  It 'returns 2 when filename is not valid reverse-DNS format (only 2 labels)'
    When call RemovePrivilegedHelper "/Library/PrivilegedHelperTools/com.vendor"
    The status should eq 2
    The output should include "Invalid filename"
  End

  It 'returns 2 when filename is not valid reverse-DNS format (single label)'
    When call RemovePrivilegedHelper "/Library/PrivilegedHelperTools/vendor"
    The status should eq 2
    The output should include "Invalid filename"
  End

  # --- Root check (rc 3) ---
  It 'returns 3 when not root and --needs-root is specified'
    export EUID=1000
    export UID=1000
    When call RemovePrivilegedHelper "/Library/PrivilegedHelperTools/com.vendor.helper" --needs-root
    The status should eq 3
    The output should include "Must be run as root"
    export EUID=0
    export UID=0
  End

  # --- Tolerant missing (rc 0 when absent) ---
  It 'returns 0 when helper does not exist and --tolerant-missing is set'
    When call RemovePrivilegedHelper --tolerant-missing "/Library/PrivilegedHelperTools/com.nonexistent.helper"
    The status should eq 0
  End

  # --- Strict missing (rc 4 when absent) ---
  It 'returns 4 when helper does not exist without --tolerant-missing'
    When call RemovePrivilegedHelper "/Library/PrivilegedHelperTools/com.nonexistent.helper"
    The status should eq 4
    The output should include "not present"
  End

  # --- Happy path (rc 0 when present and removed) ---
  It 'returns 0 when helper is successfully removed'
    local test_helper="/tmp/test_helper_$$"
    mkdir -p "/Library/PrivilegedHelperTools"
    touch "$test_helper"
    # Mock SafeDelete to succeed
    SafeDelete() { return 0; }
    When call RemovePrivilegedHelper "$test_helper"
    The status should eq 0
    rm -f "$test_helper"
  End

  # --- Verify-after failure (rc 5) ---
  It 'returns 5 when helper still exists after removal attempt'
    local test_helper="/tmp/test_helper_verify_$$"
    mkdir -p "/Library/PrivilegedHelperTools"
    touch "$test_helper"
    # Mock SafeDelete to succeed but path persists
    SafeDelete() { return 0; }
    When call RemovePrivilegedHelper "$test_helper"
    The status should eq 5
    rm -f "$test_helper"
  End

  # --- SafeDelete failure (rc 5) ---
  It 'returns 5 when SafeDelete reports failure'
    local test_helper="/tmp/test_helper_fail_$$"
    mkdir -p "/Library/PrivilegedHelperTools"
    touch "$test_helper"
    # Mock SafeDelete to fail
    SafeDelete() { return 5; }
    When call RemovePrivilegedHelper "$test_helper"
    The status should eq 5
    rm -f "$test_helper"
  End

End