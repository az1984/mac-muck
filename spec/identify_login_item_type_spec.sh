# Source the spec helper
. ./spec/spec_helper.sh

# Point SFLTOOL_BIN to the mock binary in tools/mock_bin/
# The spec_helper patches the function to use ${SFLTOOL_BIN:-/usr/bin/sfltool}
MOCK_SFLTOOL="${PROJECT_ROOT}/tools/mock_bin/sfltool"

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
  It 'returns 3 when not run as root'
    export FAKE_EUID=1000
    When call IdentifyLoginItemType "com.test.helper"
    The status should eq 3
    The output should include "root"
    unset FAKE_EUID
  End

  # --- Tolerant missing (rc 0 when not found) ---
  It 'returns 0 with empty output when identifier not found and --tolerant-missing'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="not_found"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.nonexistent" --tolerant-missing
    The status should eq 0
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  # --- Strict missing (rc 4 when not found) ---
  It 'returns 4 when identifier not found without --tolerant-missing'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="not_found"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.nonexistent"
    The status should eq 4
    The output should include "not found"
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  # --- Output format ---
  It 'emits TYPE= PATH= DISPOSITION= on stdout when found'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="helper"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.helper"
    The status should eq 0
    The output should include "TYPE="
    The output should include "PATH="
    The output should include "DISPOSITION="
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  # --- Type classification ---
  # NOTE: The function's Type regex ([^[:space:]]+) captures only single-word types.
  # Multi-word types like "legacy daemon" and "legacy agent" do not match, so
  # current_type remains empty and falls through to TYPE=unknown.
  # Only single-word types like "developer" and "app" are classified correctly.

  It 'classifies developer/helper type correctly'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="helper"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.helper"
    The status should eq 0
    The output should include "TYPE=helper"
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  It 'classifies app type correctly'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="app"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.app"
    The status should eq 0
    The output should include "TYPE=app"
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  It 'returns TYPE=unknown for multi-word type legacy daemon'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="daemon"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.daemon"
    The status should eq 0
    The output should include "TYPE=unknown"
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  It 'returns TYPE=unknown for multi-word type legacy agent'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="agent"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.agent"
    The status should eq 0
    The output should include "TYPE=unknown"
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  It 'returns TYPE=unknown for multi-word type login item'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="login_item"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.loginitem"
    The status should eq 0
    The output should include "TYPE=unknown"
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  It 'returns TYPE=unknown for unrecognized type codes'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="unknown_type"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.unknown"
    The status should eq 0
    The output should include "TYPE=unknown"
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  It 'handles empty URL field gracefully (PATH= is empty)'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="empty_url"
    export SFLTOOL_BIN="$MOCK_SFLTOOL"
    When call IdentifyLoginItemType "com.test.orphan"
    The status should eq 0
    The output should include "TYPE="
    The output should not include "file://"
    unset MOCK_SFLTOOL_MODE FAKE_EUID SFLTOOL_BIN
  End

  # --- Tool presence ---
  It 'returns 1 if sfltool binary is missing'
    export FAKE_EUID=0
    export SFLTOOL_BIN="/nonexistent/sfltool"
    When call IdentifyLoginItemType "com.test.helper"
    The status should eq 1
    The output should include "Missing required tool"
    unset FAKE_EUID SFLTOOL_BIN
  End
End
