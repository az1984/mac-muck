#!/bin/bash
# pkgutil wrapper - behavior controlled by environment variables
#
# This mock wrapper simulates various pkgutil behaviors for testing.
# Place this directory at the front of PATH in test environments.
#
# Available modes (set via MOCK_PKGUTIL_MODE):
#   - normal:           delegate to real /usr/sbin/pkgutil
#   - missing:          simulate command not found (exit 127)
#   - forget_fail:      simulate --forget failure
#   - pkg_info_fail:    simulate --pkg-info failure (receipt not found)
#   - pkg_info_ok:      simulate --pkg-info success (receipt found)
#   - forget_success:   simulate successful forget operation (pkg_info succeeds, forget succeeds)
#   - still_present:    simulate receipt still present after forget

MOCK_PKGUTIL_MODE="${MOCK_PKGUTIL_MODE:-normal}"

case "$MOCK_PKGUTIL_MODE" in
    missing)
        # Simulate command not found
        exit 127 ;;
    
    forget_fail)
        # Simulate --forget failure
        if [[ "$1" == "--pkg-info" ]]; then
            # Package exists initially
            echo "package-id: $2"
            echo "version: 1.0.0"
            echo "location: /Applications"
            exit 0
        else
            echo "pkgutil: forget failed" >&2
            exit 1
        fi ;;
    
    pkg_info_fail)
        # Simulate --pkg-info failure (receipt not found)
        echo "pkgutil: no package info found" >&2
        exit 1 ;;
    
    pkg_info_ok)
        # Simulate --pkg-info success (receipt found)
        if [[ "$1" == "--pkg-info" ]]; then
            # Get package id (may have anchors like ^...$)
            _pkg_id="$2"
            # Strip anchors for display
            _pkg_id="${_pkg_id#^}"
            _pkg_id="${_pkg_id%\$}"
            echo "package-id: $_pkg_id"
            echo "version: 1.0.0"
            echo "location: /Applications"
        fi
        exit 0 ;;
    
    forget_success)
        # Simulate successful forget operation
        # First, pkg-info should succeed (package exists)
        # Then, forget should succeed
        if [[ "$1" == "--pkg-info" ]]; then
            # Get package id (may have anchors like ^...$)
            _pkg_id="$2"
            # Strip anchors for display
            _pkg_id="${_pkg_id#^}"
            _pkg_id="${_pkg_id%\$}"
            echo "package-id: $_pkg_id"
            echo "version: 1.0.0"
            echo "location: /Applications"
            exit 0
        elif [[ "$1" == "--forget" ]]; then
            exit 0
        fi
        exit 0 ;;
    
    still_present)
        # Simulate receipt still present after forget
        if [[ "$1" == "--pkg-info" ]]; then
            # Get package id (may have anchors like ^...$)
            _pkg_id="$2"
            # Strip anchors for display
            _pkg_id="${_pkg_id#^}"
            _pkg_id="${_pkg_id%\$}"
            echo "package-id: $_pkg_id"
            echo "version: 1.0.0"
            echo "location: /Applications"
        fi
        exit 0 ;;
    
    *)
        # Normal behavior - delegate to real pkgutil
        /usr/sbin/pkgutil "$@" ;;
esac