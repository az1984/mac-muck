# spec/spec_helper.sh
# ShellSpec test helper — sources the uninstaller functions for isolated testing.
#
# Usage: Include "spec_helper.sh" in your spec files.
# ShellSpec will source this automatically if configured in .shellspec.

# Path to the uninstaller script under test
# Use BASH_SOURCE[0] to get the path of this sourced file (not $0 which is the shell)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UNINSTALLER_SCRIPT="${UNINSTALLER_SCRIPT:-${PROJECT_ROOT}/src/uninstaller.sh}"

# We need the functions but NOT the main() or ParseInput() calls.
# Strategy: Extract and source only the function definitions from the uninstaller.
# The uninstaller has functions defined after main() in section #3.

# Provide stub globals so the functions can reference them
export APP_NAME="${APP_NAME:-TestApp}"
export ECHO_PREFIX="${ECHO_PREFIX:-${APP_NAME} Uninstaller.sh - }"
export VERBOSE="${VERBOSE:-false}"
export DEBUG="${DEBUG:-false}"
export LOG_FN_WIDTH="${LOG_FN_WIDTH:-24}"
export LOG_LVL_WIDTH="${LOG_LVL_WIDTH:-10}"

# Extract function definitions from the uninstaller script
# Functions are defined after line 320 (after main() definition)
# We extract everything from "# Functions area" to "# Run" section
FUNCTIONS_START=$(grep -n "# Functions area" "$UNINSTALLER_SCRIPT" | cut -d: -f1)
FUNCTIONS_END=$(grep -n "# Run$" "$UNINSTALLER_SCRIPT" | cut -d: -f1)

if [[ -n "$FUNCTIONS_START" && -n "$FUNCTIONS_END" ]]; then
  # Create a temp file with just the function definitions
  FUNCTIONS_FILE=$(mktemp)
  sed -n "${FUNCTIONS_START},${FUNCTIONS_END}p" "$UNINSTALLER_SCRIPT" | sed '/^# Run$/d' > "$FUNCTIONS_FILE"
  
  # Source the functions file (not a subshell)
  # shellcheck disable=SC1090
  . "$FUNCTIONS_FILE"
  
  # Clean up
  rm -f "$FUNCTIONS_FILE"
fi

# Clear any variables that might interfere
unset FUNCTIONS_START FUNCTIONS_END FUNCTIONS_FILE 2>/dev/null || true