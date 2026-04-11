#!/bin/bash
# mock_euid_root.sh
# Wrapper that fakes EUID=0 (root) for testing
#
# Usage: mock_euid_root.sh <command> [args...]
#
# This script sets FAKE_EUID, EUID, and UID environment variables to 0
# before executing the specified command. This allows testing of functions
# that require root privileges without actually running as root.
#
# Example:
#   mock_euid_root.sh bash -c 'echo $EUID'  # outputs: 0

export FAKE_EUID=0
export EUID=0
export UID=0

exec "$@"