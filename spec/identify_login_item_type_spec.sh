# Mock sfltool for testing
# The mock is controlled by MOCK_SFLTOOL_MODE environment variable
sfltool() {
  local mode="${MOCK_SFLTOOL_MODE:-normal}"
  
  case "$mode" in
    missing)
      # Simulate command not found
      exit 127 ;;
    
    not_found)
      # Empty output - identifier not in BTM
      exit 0 ;;
    
    daemon)
      cat << 'EOF'
#1:
  Type:            legacy daemon (0x00000001)
  Disposition:     enabled,allowed,visible
  Identifier:      com.test.daemon
  URL:             file:///Library/LaunchDaemons/com.test.daemon.plist
EOF
      exit 0 ;;
    
    agent)
      cat << 'EOF'
#1:
  Type:            legacy agent (0x00000002)
  Disposition:     enabled,allowed
  Identifier:      com.test.agent
  URL:             file:///Library/LaunchAgents/com.test.agent.plist
EOF
      exit 0 ;;
    
    helper)
      cat << 'EOF'
#1:
  Type:            developer (0x00000004)
  Disposition:     enabled,allowed,visible
  Identifier:      com.test.helper
  URL:             file:///Library/PrivilegedHelperTools/com.test.helper
EOF
      exit 0 ;;
    
    app)
      cat << 'EOF'
#1:
  Type:            app (0x00000008)
  Disposition:     enabled
  Identifier:      com.test.app
  URL:             file:///Applications/Test.app
EOF
      exit 0 ;;
    
    login_item)
      cat << 'EOF'
#1:
  Type:            login item (0x00000010)
  Disposition:     enabled
  Identifier:      com.test.loginitem
  URL:             file:///Applications/LoginItem.app
EOF
      exit 0 ;;
    
    unknown_type)
      cat << 'EOF'
#1:
  Type:            unknown_type_xyz (0x0000FFFF)
  Disposition:     enabled
  Identifier:      com.test.unknown
  URL:             file:///Some/Path
EOF
      exit 0 ;;
    
    empty_url)
      cat << 'EOF'
#1:
  Type:            legacy daemon (0x00000001)
  Disposition:     enabled,allowed
  Identifier:      com.test.orphan
  URL:             
EOF
      exit 0 ;;
    
    *)
      # Default: not found
      exit 0 ;;
  esac
}

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
  # sfltool dumpbtm always requires root - test with FAKE_EUID
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
    When call IdentifyLoginItemType "com.test.nonexistent" --tolerant-missing
    The status should eq 0
    unset MOCK_SFLTOOL_MODE FAKE_EUID
  End

  # --- Strict missing (rc 4 when not found) ---
  It 'returns 4 when identifier not found without --tolerant-missing'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="not_found"
    When call IdentifyLoginItemType "com.test.nonexistent"
    The status should eq 4
    The output should include "not found"
    unset MOCK_SFLTOOL_MODE FAKE_EUID
  End

  # --- Output format ---
  It 'emits TYPE= PATH= DISPOSITION= on stdout when found'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="daemon"
    When call IdentifyLoginItemType "com.test.daemon"
    The status should eq 0
    The output should include "TYPE="
    The output should include "PATH="
    The output should include "DISPOSITION="
    unset MOCK_SFLTOOL_MODE FAKE_EUID
  End

  # --- Type classification ---
  It 'classifies legacy daemon type correctly'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="daemon"
    When call IdentifyLoginItemType "com.test.daemon"
    The status should eq 0
    The output should include "TYPE=daemon"
    unset MOCK_SFLTOOL_MODE FAKE_EUID
  End

  It 'classifies legacy agent type correctly'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="agent"
    When call IdentifyLoginItemType "com.test.agent"
    The status should eq 0
    The output should include "TYPE=agent"
    unset MOCK_SFLTOOL_MODE FAKE_EUID
  End

  It 'classifies login item type correctly'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="login_item"
    When call IdentifyLoginItemType "com.test.loginitem"
    The status should eq 0
    The output should include "TYPE=login_item"
    unset MOCK_SFLTOOL_MODE FAKE_EUID
  End

  It 'returns TYPE=unknown for unrecognized type codes'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="unknown_type"
    When call IdentifyLoginItemType "com.test.unknown"
    The status should eq 0
    The output should include "TYPE=unknown"
    unset MOCK_SFLTOOL_MODE FAKE_EUID
  End

  It 'handles empty URL field gracefully (PATH= is empty)'
    export FAKE_EUID=0
    export MOCK_SFLTOOL_MODE="empty_url"
    When call IdentifyLoginItemType "com.test.orphan"
    The status should eq 0
    The output should include "TYPE="
    The output should not include "file://"
    unset MOCK_SFLTOOL_MODE FAKE_EUID
  End

  # --- Tool presence ---
  It 'returns 1 if sfltool binary is missing'
    export FAKE_EUID=0
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    (
      export PATH="/nonexistent:$PATH"
      When call IdentifyLoginItemType "com.test.helper"
      The status should eq 1
      The output should include "Missing required tool"
    )
    export PATH="$old_path"
    unset FAKE_EUID
  End
End
