Describe 'RemovePrivilegedHelper'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call RemovePrivilegedHelper
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when path is not under /Library/PrivilegedHelperTools/'
    When call RemovePrivilegedHelper "/tmp/com.evil.helper"
    The status should eq 2
    The output should include "PrivilegedHelperTools"
  End

  It 'returns 2 when path is not absolute'
    When call RemovePrivilegedHelper "Library/PrivilegedHelperTools/com.vendor.helper"
    The status should eq 2
    The output should include "absolute"
  End

  It 'returns 2 with unknown flag'
    When call RemovePrivilegedHelper --bogus "/Library/PrivilegedHelperTools/com.vendor.helper"
    The status should eq 2
    The output should include "unknown flag"
  End

  # --- Root check (rc 3) ---
  It 'returns 3 when not root'
    # PrivilegedHelperTools always require root to remove
    # This test should be run as non-root
    Skip "Requires non-root execution context"
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
  End
End
