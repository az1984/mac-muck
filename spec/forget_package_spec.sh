# Source the spec helper
. ./spec/spec_helper.sh

Describe 'ForgetPackage'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call ForgetPackage
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when given an invalid package id (single label)'
    When call ForgetPackage "notreverse"
    The status should eq 2
    The output should include "Invalid"
  End

  It 'returns 2 when given an invalid package id (only 2 labels)'
    When call ForgetPackage "not-reverse-dns"
    The status should eq 2
    The output should include "Invalid"
  End

  It 'returns 2 when package id starts with number'
    When call ForgetPackage "1com.vendor.app"
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
    The output should include "anchors"
  End

  It 'returns 2 when package id has trailing space'
    When call ForgetPackage "com.vendor.app "
    The status should eq 2
    The output should include "Invalid package id"
  End

  It 'returns 2 when package id has leading space'
    When call ForgetPackage " com.vendor.app"
    The status should eq 2
    The output should include "Invalid package id"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Root check (rc 3)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 3 when not run as root'
    Skip "Requires non-root execution context"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when package not present and --tolerant-missing is set'
    Skip "Requires root execution context (pkgutil needs root)"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when package not present without --tolerant-missing'
    Skip "Requires root execution context (pkgutil needs root)"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when package is successfully forgotten'
    Skip "Requires root and mocking pkgutil --forget"
  End

  It 'accepts anchored format ^com.vendor.app.pkg$'
    # Should normalize anchors and validate the inner id
    Skip "Requires root execution context"
  End

  It 'normalizes leading ^ anchor'
    Skip "Requires root execution context"
  End

  It 'normalizes trailing $ anchor'
    Skip "Requires root execution context"
  End

  It 'normalizes both ^ and $ anchors'
    Skip "Requires root execution context"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when forget succeeds but receipt still present'
    Skip "Requires mocking pkgutil to persist receipt"
  End

  It 'returns 5 when forget fails and receipt still present'
    Skip "Requires mocking pkgutil --forget failure"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when pkgutil is not found'
    Skip "Requires mocking missing pkgutil binary"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the package id'
    Skip "Requires root execution context (pkgutil needs root)"
  End

  It 'accepts flags after the package id'
    Skip "Requires root execution context (pkgutil needs root)"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles package ids with underscores correctly'
    Skip "Requires root execution context"
  End

  It 'handles package ids with hyphens correctly'
    Skip "Requires root execution context"
  End

End