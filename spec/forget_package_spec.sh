# Source the spec helper
. ./spec/spec_helper.sh

Describe 'ForgetPackage'

  # Clean up mock state before each test
  setup() {
    rm -f /tmp/pkgutil_state
  }
  Before 'setup'

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
    When call ForgetPackage "com.vendor"
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
    export FAKE_EUID=1000
    export FAKE_UID=1000
    When call ForgetPackage "com.vendor.app.pkg"
    The status should eq 3
    The output should include "Needs root"
    unset FAKE_EUID FAKE_UID
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tolerant missing (rc 0 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when package not present and --tolerant-missing is set'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="pkg_info_fail"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor.app.pkg" --tolerant-missing
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  # ─────────────────────────═══════════════════════════════════════
  # Strict missing (rc 4 when absent)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 4 when package not present without --tolerant-missing'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="pkg_info_fail"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor.app.pkg"
    The status should eq 4
    The output should include "not present"
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  # ─────────────────────────═══════════════════════════════════════
  # Happy path tests
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 0 when package is successfully forgotten'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="forget_success"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor.app.pkg"
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  It 'accepts anchored format ^com.vendor.app.pkg$'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="forget_success"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "^com.vendor.app.pkg$"
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  It 'normalizes leading ^ anchor'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="forget_success"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "^com.vendor.app.pkg"
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  It 'normalizes trailing $ anchor'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="forget_success"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor.app.pkg$"
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  It 'normalizes both ^ and $ anchors'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="forget_success"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "^com.vendor.app.pkg$"
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  # ─────────────────────────═══════════════════════════════════════
  # Verify-after failure tests (rc 5)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 5 when forget succeeds but receipt still present'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="still_present"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor.app.pkg"
    The status should eq 5
    The output should include "still present"
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  It 'returns 5 when forget fails and receipt still present'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="forget_fail"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor.app.pkg"
    The status should eq 5
    The output should include "failure"
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when pkgutil is not found'
    export FAKE_EUID=0
    export FAKE_UID=0
    export PKGUTIL_BIN="/nonexistent/pkgutil"
    When call ForgetPackage "com.vendor.app.pkg"
    The status should eq 1
    The output should include "Missing required tool"
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  # ─────────────────────────═══════════════════════════════════════
  # Order-agnostic arguments
  # ─────────────────────────═══════════════════════════════════════

  It 'accepts flags before the package id'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="pkg_info_fail"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage --tolerant-missing "com.vendor.app.pkg"
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  It 'accepts flags after the package id'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="pkg_info_fail"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor.app.pkg" --tolerant-missing
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  # ─────────────────────────═══════════════════════════════════════
  # Edge cases
  # ─────────────────────────═══════════════════════════════════════

  It 'handles package ids with underscores correctly'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="pkg_info_fail"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor_name.app_test" --tolerant-missing
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

  It 'handles package ids with hyphens correctly'
    export FAKE_EUID=0
    export FAKE_UID=0
    export MOCK_PKGUTIL_MODE="pkg_info_fail"
    export PKGUTIL_BIN="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin/pkgutil"
    When call ForgetPackage "com.vendor-name.app-test" --tolerant-missing
    The status should eq 0
    unset MOCK_PKGUTIL_MODE
    unset FAKE_EUID FAKE_UID
    unset PKGUTIL_BIN
  End

End
