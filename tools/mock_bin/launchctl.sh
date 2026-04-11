#!/bin/bash
# launchctl wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various launchctl behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via environment variables before running):
#   MOCK_LAUNCHCTL_MODE:
#     - normal:      delegate to real /bin/launchctl
#     - missing:     simulate command not found (exit 127)
#     - fail:        simulate generic failure
#     - not_found:   simulate service not found
#     - bootout_ok:  simulate successful bootout
#     - bootout_fail: simulate bootout failure
#     - list_plists: simulate listing plists with custom output
#     - print_disabled: simulate print-disabled output
#     - print_disabled_empty: simulate empty print-disabled output
#     - running:     simulate service is running
#     - not_running: simulate service is not running
#     - ambiguous:   simulate ambiguous output for testing verify-after
#
# Additional controls:
#   MOCK_LAUNCHCTL_OUTPUT: custom output for list_plists mode
#   MOCK_LAUNCHCTL_DISABLED_OUTPUT: custom output for print-disabled mode
#   MOCK_LAUNCHCTL_STATE: "running" or "not_running" for state queries

MOCK_LAUNCHCTL_MODE="${MOCK_LAUNCHCTL_MODE:-normal}"

case "$MOCK_LAUNCHCTL_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    fail)
        # Simulate generic failure
        echo "launchctl: operation failed" >&2
        exit 1 ;;
    
    not_found)
        # Simulate service not found
        echo "Could not find service: $*" >&2
        exit 1 ;;
    
    bootout_fail)
        # Simulate bootout failure
        echo "launchctl: failed to bootout service" >&2
        exit 1 ;;
    
    list_plists)
        # Return custom plist listing
        if [[ -n "$MOCK_LAUNCHCTL_OUTPUT" ]]; then
            echo "$MOCK_LAUNCHCTL_OUTPUT"
        fi
        exit 0 ;;
    
    print_disabled)
        # Return print-disabled output
        if [[ -n "$MOCK_LAUNCHCTL_DISABLED_OUTPUT" ]]; then
            echo "$MOCK_LAUNCHCTL_DISABLED_OUTPUT"
        fi
        exit 0 ;;
    
    print_disabled_empty)
        # Return empty print-disabled output (no disabled services)
        exit 0 ;;
    
    running)
        # Simulate service is running
        echo "Process ID: 12345"
        echo "Process Name: test-service"
        exit 0 ;;
    
    not_running)
        # Simulate service is not running
        echo "Could not find service: $*" >&2
        exit 1 ;;
    
    ambiguous)
        # Return ambiguous output for testing verify-after edge cases
        echo "State: unknown"
        exit 0 ;;
    
    *)
        # Normal behavior - delegate to real launchctl
        /bin/launchctl "$@" ;;
esac