# spec/spec_helper.sh
# ShellSpec test helper — sources the uninstaller functions for isolated testing.
#
# Usage: Include "spec_helper.sh" in your spec files.
# ShellSpec will source this automatically if configured in .shellspec.

# Path to the uninstaller script under test
# Use absolute path since shellspec may change working directory
PROJECT_ROOT="/Users/andrewezimmer/Documents/GitHub/mac-muck"
UNINSTALLER_SCRIPT="${PROJECT_ROOT}/src/uninstaller.sh"

# Provide stub globals so the functions can reference them
export APP_NAME="${APP_NAME:-TestApp}"
export ECHO_PREFIX="${ECHO_PREFIX:-${APP_NAME} Uninstaller.sh - }"
export VERBOSE="${VERBOSE:-false}"
export DEBUG="${DEBUG:-false}"
export LOG_FN_WIDTH="${LOG_FN_WIDTH:-24}"
export LOG_LVL_WIDTH="${LOG_LVL_WIDTH:-10}"

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