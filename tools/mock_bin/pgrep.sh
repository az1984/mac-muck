#!/bin/bash
# pgrep wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various pgrep behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via MOCK_PGREP_MODE):
#   - normal:       delegate to real /usr/bin/pgrep
#   - missing:      simulate command not found (exit 127)
#   - running:      always return success (process found, exit 0)
#   - not_running:  always return failure (process not found, exit 1)
#   - specific_pid: return a specific PID (set via MOCK_PGREP_PID)
#   - counter:      use counter file for verify-after testing

MOCK_PGREP_MODE="${MOCK_PGREP_MODE:-normal}"
MOCK_PGREP_PID="${MOCK_PGREP_PID:-}"
MOCK_PGREP_COUNTER_FILE="${MOCK_PGREP_COUNTER_FILE:-}"

case "$MOCK_PGREP_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    running)
        # Always return success (process running)
        exit 0 ;;
    
    not_running)
        # Always return failure (process not running)
        exit 1 ;;
    
    specific_pid)
        # Return specific PID if set
        if [[ -n "$MOCK_PGREP_PID" ]]; then
            echo "$MOCK_PGREP_PID"
            exit 0
        fi
        exit 1 ;;
    
    running_then_not)
        # Returns running on first call, not running on second and subsequent
        # Uses MOCK_PGREP_COUNTER_FILE to track calls
        if [[ -n "$MOCK_PGREP_COUNTER_FILE" ]]; then
            if [[ ! -f "$MOCK_PGREP_COUNTER_FILE" ]]; then
                echo "0" > "$MOCK_PGREP_COUNTER_FILE"
            fi
            count=$(cat "$MOCK_PGREP_COUNTER_FILE" 2>/dev/null || echo "0")
            ((count++))
            echo "$count" > "$MOCK_PGREP_COUNTER_FILE"
            # First call: running; second+: not running
            if [[ $count -le 1 ]]; then
                exit 0
            else
                exit 1
            fi
        fi
        # No counter file: just return running first time (fallback)
        exit 0 ;;

    counter)
        # Use counter file for verify-after testing
        # Returns running for first N calls, then not running
        if [[ -n "$MOCK_PGREP_COUNTER_FILE" ]]; then
            # Create counter file if it doesn't exist
            if [[ ! -f "$MOCK_PGREP_COUNTER_FILE" ]]; then
                echo "0" > "$MOCK_PGREP_COUNTER_FILE"
            fi
            
            # Read current count
            count=$(cat "$MOCK_PGREP_COUNTER_FILE" 2>/dev/null || echo "0")
            
            # Increment counter
            ((count++))
            echo "$count" > "$MOCK_PGREP_COUNTER_FILE"
            
            # Return running for first 10 calls, then not running
            if [[ $count -lt 10 ]]; then
                exit 0
            else
                rm -f "$MOCK_PGREP_COUNTER_FILE"
                exit 1
            fi
        fi
        exit 1 ;;
    
    *)
        # Normal behavior - delegate to real pgrep
        /usr/bin/pgrep "$@" ;;
esac