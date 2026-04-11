#!/bin/bash
# kill wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various kill behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via MOCK_KILL_MODE):
#   - normal:      delegate to real /bin/kill
#   - missing:     simulate command not found (exit 127)
#   - fail:        simulate generic failure (exit 1)
#   - success:     always succeed (simulate signal sent)
#   - check_fail:  simulate kill -0 check failing (process not running)
#   - check_ok:    simulate kill -0 check succeeding (process running)

MOCK_KILL_MODE="${MOCK_KILL_MODE:-normal}"

# Parse arguments to detect kill -0 (check mode)
is_check_mode=false
for arg in "$@"; do
    if [[ "$arg" == "-0" ]]; then
        is_check_mode=true
        break
    fi
done

case "$MOCK_KILL_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    fail)
        # Simulate generic failure
        echo "kill: operation failed" >&2
        exit 1 ;;
    
    success)
        # Simulate successful signal
        exit 0 ;;
    
    check_fail)
        # Simulate kill -0 failing (process not running)
        exit 1 ;;
    
    check_ok)
        # Simulate kill -0 succeeding (process running)
        exit 0 ;;
    
    *)
        # Normal behavior - delegate to real kill
        /bin/kill "$@" ;;
esac