#!/bin/bash
# pluginkit wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various pluginkit behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via MOCK_PLUGINKIT_MODE):
#   - normal:      delegate to real /usr/bin/pluginkit
#   - missing:     simulate command not found (exit 127)
#   - fail:        simulate generic failure
#   - success:     simulate successful operation
#   - not_found:   simulate plugin not found
#   - still_registered: simulate plugin still registered after removal

MOCK_PLUGINKIT_MODE="${MOCK_PLUGINKIT_MODE:-normal}"

case "$MOCK_PLUGINKIT_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    fail)
        # Simulate generic failure
        echo "pluginkit: operation failed" >&2
        exit 1 ;;
    
    success)
        # Simulate successful operation
        exit 0 ;;
    
    not_found)
        # Simulate plugin not found
        echo "pluginkit: plugin not found" >&2
        exit 1 ;;
    
    still_registered)
        # Simulate plugin still registered after removal attempt
        echo "pluginkit: plugin still registered" >&2
        exit 1 ;;
    
    *)
        # Normal behavior - delegate to real pluginkit
        /usr/bin/pluginkit "$@" ;;
esac