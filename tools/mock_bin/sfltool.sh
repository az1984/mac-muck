#!/bin/bash
# sfltool wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various sfltool behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via MOCK_SFLTOOL_MODE):
#   - normal:      delegate to real /usr/bin/sfltool
#   - missing:     simulate command not found (exit 127)
#   - not_found:   simulate identifier not in BTM (empty output, exit 0)
#   - daemon:      return daemon-type BTM entry
#   - agent:       return agent-type BTM entry
#   - helper:      return helper-type BTM entry
#   - app:         return app-type BTM entry
#   - login_item:  return login item BTM entry
#   - custom:      return custom output (set via MOCK_SFLTOOL_OUTPUT)

MOCK_SFLTOOL_MODE="${MOCK_SFLTOOL_MODE:-normal}"
MOCK_SFLTOOL_OUTPUT="${MOCK_SFLTOOL_OUTPUT:-}"

case "$MOCK_SFLTOOL_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    not_found)
        # Empty output - identifier not in BTM
        exit 0 ;;
    
    custom)
        # Return custom output
        if [[ -n "$MOCK_SFLTOOL_OUTPUT" ]]; then
            echo "$MOCK_SFLTOOL_OUTPUT"
        fi
        exit 0 ;;
    
    daemon)
        # Return daemon-type BTM entry
        cat << 'EOF'
#1:
  Type:            legacy daemon (0x00000001)
  Disposition:     enabled,allowed,visible
  Identifier:      com.test.daemon
  URL:             file:///Library/LaunchDaemons/com.test.daemon.plist
EOF
        exit 0 ;;
    
    agent)
        # Return agent-type BTM entry
        cat << 'EOF'
#1:
  Type:            legacy agent (0x00000002)
  Disposition:     enabled,allowed
  Identifier:      com.test.agent
  URL:             file:///Library/LaunchAgents/com.test.agent.plist
EOF
        exit 0 ;;
    
    helper)
        # Return helper-type BTM entry
        cat << 'EOF'
#1:
  Type:            developer (0x00000004)
  Disposition:     enabled,allowed,visible
  Identifier:      com.test.helper
  URL:             file:///Library/PrivilegedHelperTools/com.test.helper
EOF
        exit 0 ;;
    
    app)
        # Return app-type BTM entry
        cat << 'EOF'
#1:
  Type:            app (0x00000008)
  Disposition:     enabled
  Identifier:      com.test.app
  URL:             file:///Applications/Test.app
EOF
        exit 0 ;;
    
    login_item)
        # Return login item BTM entry
        cat << 'EOF'
#1:
  Type:            login item (0x00000010)
  Disposition:     enabled
  Identifier:      com.test.loginitem
  URL:             file:///Applications/LoginItem.app
EOF
        exit 0 ;;
    
    *)
        # Normal behavior - delegate to real sfltool
        /usr/bin/sfltool "$@" ;;
esac