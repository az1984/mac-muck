#!/bin/bash
# qlmanage wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various qlmanage behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via MOCK_QLMANAGE_MODE):
#   - normal:      delegate to real /usr/bin/qlmanage
#   - missing:     simulate command not found (exit 127)
#   - fail:        simulate generic failure
#   - success:     simulate successful operation

MOCK_QLMANAGE_MODE="${MOCK_QLMANAGE_MODE:-normal}"

case "$MOCK_QLMANAGE_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    fail)
        # Simulate generic failure
        echo "qlmanage: operation failed" >&2
        exit 1 ;;
    
    success)
        # Simulate successful operation
        exit 0 ;;
    
    *)
        # Normal behavior - delegate to real qlmanage
        /usr/bin/qlmanage "$@" ;;
esac