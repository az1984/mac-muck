. ./spec/spec_helper.sh
Describe 'IdentifyLoginItemType'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call IdentifyLoginItemType
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid identifier format'
    When call IdentifyLoginItemType "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid"
  End

  It 'returns 2 with unknown flag'
    When call IdentifyLoginItemType --bogus "com.vendor.app.helper"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with multiple non-flag arguments'
    When call IdentifyLoginItemType "com.vendor.one" "com.vendor.two"
    The status should eq 2
    The output should include "multiple non-flag"
  End

  # --- Root check (rc 3) ---
  # sfltool dumpbtm always requires root
  It 'returns 3 when not run as root'
    Skip "Requires non-root execution context to test the root guard"
  End

  # --- Tolerant missing (rc 0 when not found) ---
  It 'returns 0 with empty output when identifier not found and --tolerant-missing'
    Skip "Requires root execution context with sfltool"
  End

  # --- Strict missing (rc 4 when not found) ---
  It 'returns 4 when identifier not found without --tolerant-missing'
    Skip "Requires root execution context with sfltool"
  End

  # --- Output format ---
  It 'emits TYPE= PATH= DISPOSITION= on stdout when found'
    Skip "Requires root + a known BTM entry to test against"
  End

  # --- Type classification ---
  # These tests require mock sfltool output. Strategy:
  # Create a function that injects canned sfltool dumpbtm output.

  It 'classifies legacy daemon type correctly'
    Skip "Requires sfltool output mock"
  End

  It 'classifies legacy agent type correctly'
    Skip "Requires sfltool output mock"
  End

  It 'classifies login item type correctly'
    Skip "Requires sfltool output mock"
  End

  It 'returns TYPE=unknown for unrecognized type codes'
    Skip "Requires sfltool output mock"
  End

  It 'handles empty URL field gracefully (PATH= is empty)'
    Skip "Requires sfltool output mock"
  End

  # --- Tool presence ---
  It 'returns 1 if sfltool binary is missing'
    Skip "Requires mock of sfltool binary path"
  End
End
