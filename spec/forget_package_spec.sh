Describe 'ForgetPackage'

  # --- Bad input (rc 2) ---
  It 'returns 2 when no arguments provided'
    When call ForgetPackage
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid package id'
    When call ForgetPackage "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid"
  End

  It 'returns 2 with duplicate --tolerant-missing flag'
    When call ForgetPackage --tolerant-missing --tolerant-missing "com.vendor.app.pkg"
    The status should eq 2
    The output should include "duplicate"
  End

  It 'returns 2 with unknown flag'
    When call ForgetPackage --bogus "com.vendor.app.pkg"
    The status should eq 2
    The output should include "unknown flag"
  End

  It 'returns 2 with internal anchors'
    When call ForgetPackage "com.vendor^.app.pkg"
    The status should eq 2
  End

  # --- Root check (rc 3) ---
  It 'returns 3 when not run as root'
    Skip "Requires non-root execution context"
  End

  # --- Tolerant missing ---
  It 'returns 0 when package not present and --tolerant-missing is set'
    Skip "Requires root execution context (pkgutil needs root)"
  End

  # --- Order-agnostic ---
  It 'accepts anchored format ^com.vendor.app.pkg$'
    # Should normalize anchors and validate the inner id
    Skip "Requires root execution context"
  End
End
