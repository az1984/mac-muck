#!/bin/bash
# pkill wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various pkill behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via MOCK_PKILL_MODE):
#   - normal:      delegate to real /usr/bin/pkill
#   - missing:     simulate command not found (exit 127)
#   - fail:        simulate generic failure (exit 1)
#   - success:     always succeed (simulate process terminated)
#   - no_process:  simulate no matching process (exit 1)

MOCK_PKILL_MODE="${MOCK_PKILL_MODE:-normal}"

case "$MOCK_PKILL_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    fail)
        # Simulate generic failure
        echo "pkill: operation failed" >&2
        exit 1 ;;
    
    success)
        # Simulate successful termination
        exit 0 ;;
    
    no_process)
        # Simulate no matching process found
        exit 1 ;;
    
    *)
        # Normal behavior - delegate to real pkill
        /usr/bin/pkill "$@" ;;
esac