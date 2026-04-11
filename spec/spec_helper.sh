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
# Use absolute path since shellspec may change working directory
PROJECT_ROOT="/Users/andrewezimmer/Documents/GitHub/mac-muck"
UNINSTALLER_SCRIPT="${PROJECT_ROOT}/src/uninstaller.sh"

# Add mock_bin to PATH if it exists (for tool mocking)
# This must come BEFORE any other PATH modifications
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

# Set default mock modes - can be overridden per-test
# Only set defaults if not already set by the test
if [[ -z "${MOCK_PGREP_MODE:-}" ]]; then export MOCK_PGREP_MODE="normal"; fi
if [[ -z "${MOCK_PKILL_MODE:-}" ]]; then export MOCK_PKILL_MODE="normal"; fi
if [[ -z "${MOCK_KILL_MODE:-}" ]]; then export MOCK_KILL_MODE="normal"; fi
if [[ -z "${MOCK_PLISTB_MODE:-}" ]]; then export MOCK_PLISTB_MODE="normal"; fi
if [[ -z "${MOCK_LAUNCHCTL_MODE:-}" ]]; then export MOCK_LAUNCHCTL_MODE="normal"; fi
if [[ -z "${MOCK_SFLTOOL_MODE:-}" ]]; then export MOCK_SFLTOOL_MODE="normal"; fi
if [[ -z "${MOCK_PLUGINKIT_MODE:-}" ]]; then export MOCK_PLUGINKIT_MODE="normal"; fi
if [[ -z "${MOCK_QLMANAGE_MODE:-}" ]]; then export MOCK_QLMANAGE_MODE="normal"; fi
if [[ -z "${MOCK_PKGUTIL_MODE:-}" ]]; then export MOCK_PKGUTIL_MODE="normal"; fi

# Set default EUID for testing (non-root by default)
# Use FAKE_EUID/FAKE_UID instead of EUID/UID since they are readonly
# Only set defaults if not already set by the test
if [[ -z "${FAKE_EUID:-}" ]]; then
    export FAKE_EUID=1000
fi
if [[ -z "${FAKE_UID:-}" ]]; then
    export FAKE_UID=1000
fi

# Extract only the function definitions from the uninstaller script
# The script structure is:
#   Section 1: Config
#   Section 2: main() definition (but not called yet)
#   Section 3: Functions area
#   Section 4: ParseInput "$@" then main "$@" (we skip this)

# Find the start of the Functions area and the Run section
FUNCTIONS_START=$(grep -n "# Functions area" "$UNINSTALLER_SCRIPT" | cut -d: -f1)
RUN_SECTION=$(grep -n "^# Run$" "$UNINSTALLER_SCRIPT" | cut -d: -f1)

if [ -n "$FUNCTIONS_START" ] && [ -n "$RUN_SECTION" ]; then
  # Create a temp file with just the function definitions
  FUNCTIONS_FILE=$(mktemp)
  # Extract from Functions area to just before Run section
  sed -n "${FUNCTIONS_START},$((RUN_SECTION - 1))p" "$UNINSTALLER_SCRIPT" > "$FUNCTIONS_FILE"
  
  # Source the functions file
  . "$FUNCTIONS_FILE"
  
  # Clean up
  rm -f "$FUNCTIONS_FILE"
fi