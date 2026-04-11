#!/bin/bash
# mock_euid_nonroot.sh
# Wrapper that fakes EUID=1000 (non-root) for testing
#
# Usage: mock_euid_nonroot.sh <command> [args...]
#
# This script sets FAKE_EUID, EUID, and UID environment variables to 1000
# before executing the specified command. This allows testing of functions
# that have root guards without actually running as root.
#
# Example:
#   mock_euid_nonroot.sh bash -c 'echo $EUID'  # outputs: 1000

export FAKE_EUID=1000
export EUID=1000
export UID=1000

exec "$@"