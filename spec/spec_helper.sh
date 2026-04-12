# spec/spec_helper.sh
# ShellSpec test helper — sources the uninstaller functions for isolated testing.
#
# Usage: Include "spec_helper.sh" in your spec files.
# ShellSpec will source this automatically if configured in .shellspec.
#
# MOCKING FRAMEWORK:
# This helper sets up a complete mocking infrastructure for testing.
# 
# To use mocks, set environment variables before tests:
#   export MOCK_PGREP_MODE="running"     # Simulate process running
#   export MOCK_PKILL_MODE="fail"        # Simulate pkill failure
#   export MOCK_KILL_MODE="check_ok"     # Simulate kill -0 check succeeding
#   export MOCK_LAUNCHCTL_MODE="bootout_ok"  # Simulate successful bootout
#   export MOCK_SFLTOOL_MODE="daemon"    # Simulate daemon-type login item
#
# To test root scenarios, set:
#   export FAKE_EUID=0
#   export FAKE_UID=0
#
# To test non-root scenarios:
#   export FAKE_EUID=1000
#   export FAKE_UID=1000
#
# To test missing tools:
#   export MOCK_PGREP_MODE="missing"     # Simulate missing pgrep binary
#   export MOCK_PKILL_MODE="missing"     # Simulate missing pkill binary

# Path to the uninstaller script under test
PROJECT_ROOT="/Users/andrewezimmer/Documents/GitHub/mac-muck"
UNINSTALLER_SCRIPT="${PROJECT_ROOT}/src/uninstaller.sh"

# Add mock_bin to PATH first so mocks are found before real binaries
MOCK_BIN_DIR="${PROJECT_ROOT}/tools/mock_bin"
if [[ -d "$MOCK_BIN_DIR" ]]; then
    export PATH="${MOCK_BIN_DIR}:$PATH"
fi

# Provide stub globals so the functions can reference them
export APP_NAME="${APP_NAME:-TestApp}"
export ECHO_PREFIX="${ECHO_PREFIX:-${APP_NAME} Uninstaller.sh - }"
export VERBOSE="${VERBOSE:-false}"
export DEBUG="${DEBUG:-false}"
export LOG_FN_WIDTH="${LOG_FN_WIDTH:-24}"
export LOG_LVL_WIDTH="${LOG_LVL_WIDTH:-10}"

# Note: Mock modes are NOT set as defaults here. Each test must explicitly
# export the MOCK_*_MODE it needs before the test runs.

# Set default EUID for testing (non-root by default)
if [[ -z "${FAKE_EUID:-}" ]]; then
    export FAKE_EUID=1000
fi
if [[ -z "${FAKE_UID:-}" ]]; then
    export FAKE_UID=1000
fi

# Source the uninstaller script to get all function definitions.
# The script ends with `ParseInput "$@"` and `main "$@"`, but since we're
# sourcing it (not executing it), those will run in the context of the
# spec helper with no arguments, which is safe.
# To prevent main() from actually running, we set a guard variable.
# The uninstaller checks for root in main(), so with FAKE_EUID=1000 it will exit 3.
# We prevent this by overriding the exit command in a subshell.

# Source the script excluding the final invocation lines (ParseInput "$@"
# and main "$@") so that functions are defined but not executed.
# main() uses `id -u` (not _get_effective_euid) and calls `exit 3` when
# not root, which would terminate the sourcing shell entirely.
# Patch hardcoded _BIN paths so tests can override them via environment variables.
# The same ${VAR:-default} pattern used by PKGUTIL_BIN is applied to PLUGINKIT_BIN.
eval "$(sed -n '/^ParseInput "\$@"/q; p' "$UNINSTALLER_SCRIPT" \
  | sed 's|local PLUGINKIT_BIN="/usr/bin/pluginkit"|local PLUGINKIT_BIN="${PLUGINKIT_BIN:-/usr/bin/pluginkit}"|g' \
  | sed 's|local SFLTOOL_BIN="/usr/bin/sfltool"|local SFLTOOL_BIN="${SFLTOOL_BIN:-/usr/bin/sfltool}"|g' \
  | sed 's|local helper_dir="/Library/PrivilegedHelperTools"|local helper_dir="${TEST_PRIVILEGED_HELPERS_DIR:-/Library/PrivilegedHelperTools}"|g' \
  | sed 's|mapfile -t users < <( ListGraphicalUsers )|users=(); while IFS= read -r _u; do [[ -n "$_u" ]] \&\& users+=("$_u"); done < <( ListGraphicalUsers )|g' \
  | sed 's|local sys_plist="/Library/LaunchAgents/${plist_name}"|local sys_plist="${TEST_LAUNCHAGENTS_DIR:-/Library/LaunchAgents}/${plist_name}"|g' \
  | sed 's|local sys_plist="/Library/LaunchDaemons/${plist_name}"|local sys_plist="${TEST_LAUNCHDAEMONS_DIR:-/Library/LaunchDaemons}/${plist_name}"|g' \
  | sed "s|/usr/bin/grep -oP 'TYPE=\\\\K\[^ \]+'|/usr/bin/sed -n 's/.*TYPE=\\\\([^ ]*\\\\).*/\\\\1/p'|g" \
  | sed "s|/usr/bin/grep -oP 'PATH=\\\\K\[^ \]+'|/usr/bin/sed -n 's/.*PATH=\\\\([^ ]*\\\\).*/\\\\1/p'|g" \
  | sed "s|/usr/bin/grep -oP 'DISPOSITION=\\\\K\.\*'|/usr/bin/sed -n 's/.*DISPOSITION=\\\\(.*\\\\)/\\\\1/p'|g" \
  | sed 's|local LAUNCHCTL_BIN="/bin/launchctl"|local LAUNCHCTL_BIN="${LAUNCHCTL_BIN:-/bin/launchctl}"|g' \
  | sed 's|local PLUTIL_BIN="/usr/bin/plutil"|local PLUTIL_BIN="${PLUTIL_BIN:-/usr/bin/plutil}"|g' \
  | sed 's|local UNLINK_BIN="/usr/bin/unlink"|local UNLINK_BIN="${UNLINK_BIN:-/usr/bin/unlink}"|g'
)" 2>/dev/null || true
