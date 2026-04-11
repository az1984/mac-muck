#!/bin/bash
# PlistBuddy wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various PlistBuddy behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via MOCK_PLISTB_MODE):
#   - normal:      delegate to real /usr/libexec/PlistBuddy
#   - missing:     simulate command not found (exit 127)
#   - fail:        simulate generic failure (exit 2)
#   - no_such_key: simulate "No such key" error
#   - custom_value: return a custom value (set via MOCK_PLISTB_VALUE)
#   - cf_bundle_exec: return a CFBundleExecutable value

MOCK_PLISTB_MODE="${MOCK_PLISTB_MODE:-normal}"
MOCK_PLISTB_VALUE="${MOCK_PLISTB_VALUE:-}"

case "$MOCK_PLISTB_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    fail)
        # Simulate generic failure
        echo "PlistBuddy: Error: Unable to open file" >&2
        exit 2 ;;
    
    no_such_key)
        # Simulate "No such key" error
        echo "Print: No such key" >&2
        exit 2 ;;
    
    custom_value)
        # Return custom value
        if [[ -n "$MOCK_PLISTB_VALUE" ]]; then
            echo "$MOCK_PLISTB_VALUE"
        fi
        exit 0 ;;
    
    cf_bundle_exec)
        # Return CFBundleExecutable value
        if [[ -n "$MOCK_PLISTB_VALUE" ]]; then
            echo "$MOCK_PLISTB_VALUE"
        else
            echo "TestAppExecutable"
        fi
        exit 0 ;;
    
    *)
        # Normal behavior - delegate to real PlistBuddy
        /usr/libexec/PlistBuddy "$@" ;;
esac