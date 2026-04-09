# spec/spec_helper.sh
# ShellSpec test helper — sources the uninstaller functions for isolated testing.
#
# Usage: Include "spec_helper.sh" in your spec files.
# ShellSpec will source this automatically if configured in .shellspec.

# Path to the uninstaller script under test
UNINSTALLER_SCRIPT="${UNINSTALLER_SCRIPT:-$(cd "$(dirname "$0")/.." && pwd)/src/uninstaller.sh}"

# We need the functions but NOT the main() call.
# Strategy: source the file with a guard that prevents main from executing.
# The uninstaller ends with `main "$@"` — we override main to a no-op before sourcing.

# Provide stub globals so the functions can reference them
export APP_NAME="TestApp"
export ECHO_PREFIX="TestApp Uninstaller.sh - "
export VERBOSE="${VERBOSE:-false}"
export DEBUG="${DEBUG:-false}"
export LOG_FN_WIDTH=24
export LOG_LVL_WIDTH=10

# Source the uninstaller, intercepting main()
_load_uninstaller_functions() {
  # Save original main if any
  local _orig_main
  if declare -f main >/dev/null 2>&1; then
    _orig_main="$(declare -f main)"
  fi

  # Define a no-op main to prevent execution when sourcing
  function main { :; }

  # Source the script — all functions get defined, main() is a no-op
  # shellcheck disable=SC1090
  . "$UNINSTALLER_SCRIPT"

  # Restore original main or leave the no-op
  if [[ -n "${_orig_main:-}" ]]; then
    eval "$_orig_main"
  fi
}

_load_uninstaller_functions
