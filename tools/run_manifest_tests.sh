#!/bin/bash
# run_manifest_tests.sh — Run uninstaller against testing manifests and capture logs.
#
# For each manifest in manifests/testing/:
#   1. Reinstalls test apps (via reset_test_apps.sh) so the system is clean
#   2. Runs the uninstaller with the manifest
#   3. Captures stdout, stderr, and exit code
#   4. Compares actual exit code against _expected_rc from the manifest
#
# Usage:
#   sudo ./tools/run_manifest_tests.sh /path/to/installers/
#   sudo ./tools/run_manifest_tests.sh /path/to/installers/ --skip-reset  # skip reinstall
#   sudo ./tools/run_manifest_tests.sh --dry-run                          # preview only
#
# Output:
#   manifests/testing/logs/<name>.stdout.log
#   manifests/testing/logs/<name>.stderr.log
#   manifests/testing/logs/<name>.exitcode
#   manifests/testing/logs/SUMMARY.txt

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UNINSTALLER="$SCRIPT_DIR/src/uninstaller.sh"
RESET_SCRIPT="$SCRIPT_DIR/tools/reset_test_apps.sh"
TESTING_DIR="$SCRIPT_DIR/manifests/testing"
LOG_DIR="$TESTING_DIR/logs"

PREFIX="test-runner"
DRY_RUN=false
SKIP_RESET=false
INSTALLER_DIR=""

# ── Parse flags and positional args
for arg in "$@"; do
    case "$arg" in
        --dry-run)     DRY_RUN=true ;;
        --skip-reset)  SKIP_RESET=true ;;
        --help|-h)
            echo "Usage: sudo $0 /path/to/installers/ [--skip-reset] [--dry-run]"
            echo ""
            echo "  /path/to/installers/  Directory with DMG/PKG files for test apps"
            echo "  --skip-reset          Skip reinstalling apps between tests"
            echo "  --dry-run             Show what would run without executing"
            exit 0 ;;
        -*)
            echo "$PREFIX — ERROR: Unknown flag: $arg" >&2
            exit 1 ;;
        *)
            INSTALLER_DIR="$arg" ;;
    esac
done

# ── Validate inputs
if [[ "$DRY_RUN" == false ]]; then
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "$PREFIX — ERROR: Must run as root (sudo). Use --dry-run to preview." >&2
        exit 3
    fi
    if [[ "$SKIP_RESET" == false ]]; then
        if [[ -z "$INSTALLER_DIR" || ! -d "$INSTALLER_DIR" ]]; then
            echo "$PREFIX — ERROR: Provide installer directory (or use --skip-reset)." >&2
            echo "Usage: sudo $0 /path/to/installers/" >&2
            exit 1
        fi
        if [[ ! -x "$RESET_SCRIPT" ]]; then
            echo "$PREFIX — ERROR: Reset script not found: $RESET_SCRIPT" >&2
            exit 1
        fi
    fi
fi

# ── Prepare log directory
mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log "$LOG_DIR"/*.exitcode "$LOG_DIR"/SUMMARY.txt

# ── Collect manifests (sorted by filename for deterministic order)
manifests=()
for f in "$TESTING_DIR"/*.json; do
    [[ -f "$f" ]] && manifests+=("$f")
done

if [[ ${#manifests[@]} -eq 0 ]]; then
    echo "$PREFIX — No manifests found in $TESTING_DIR" >&2
    exit 1
fi

# ── Extract metadata from a manifest
get_meta() {
    local manifest="$1" key="$2"
    python3 -c "
import json, sys
try:
    m = json.load(open('$manifest'))
    print(m.get('$key', ''))
except: print('')
" 2>/dev/null
}

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  MUCK Manifest Test Runner"
echo "  Manifests  : ${#manifests[@]}"
echo "  Installers : ${INSTALLER_DIR:-(skip-reset)}"
echo "  Log dir    : $LOG_DIR"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# ── Run each manifest
declare -a results_name=()
declare -a results_actual=()
declare -a results_expected=()
declare -a results_pass=()
declare -a results_func=()

pass_count=0
fail_count=0

for manifest in "${manifests[@]}"; do
    name=$(basename "$manifest" .json)
    desc=$(get_meta "$manifest" "_test_description")
    expected_rc=$(get_meta "$manifest" "_expected_rc")
    func=$(get_meta "$manifest" "_function_under_test")

    echo "── [$name] ──────────────────────────────────────"
    echo "   Function: $func"
    echo "   Purpose : $desc"
    echo "   Expected: exit $expected_rc"

    if $DRY_RUN; then
        echo "   [DRY RUN]"
        echo ""
        results_name+=("$name")
        results_actual+=("--")
        results_expected+=("$expected_rc")
        results_pass+=("--")
        results_func+=("$func")
        continue
    fi

    # ── Phase 1: Reinstall test apps (unless --skip-reset)
    if [[ "$SKIP_RESET" == false ]]; then
        echo "   Resetting test apps..."
        "$RESET_SCRIPT" "$INSTALLER_DIR" \
            >"$LOG_DIR/${name}.reset.log" 2>&1
        reset_rc=$?
        if [[ $reset_rc -ne 0 ]]; then
            echo "   WARNING: Reset exited $reset_rc (see ${name}.reset.log)"
        fi
    fi

    # ── Phase 2: Run the uninstaller
    echo "   Running uninstaller..."
    "$UNINSTALLER" "$manifest" \
        >"$LOG_DIR/${name}.stdout.log" \
        2>"$LOG_DIR/${name}.stderr.log"
    actual_rc=$?
    echo "$actual_rc" > "$LOG_DIR/${name}.exitcode"

    # ── Phase 3: Compare against expected
    if [[ -n "$expected_rc" && "$actual_rc" == "$expected_rc" ]]; then
        verdict="PASS"
        ((pass_count++))
    elif [[ -z "$expected_rc" ]]; then
        verdict="SKIP"  # no expectation set
    else
        verdict="FAIL"
        ((fail_count++))
    fi

    if [[ "$verdict" == "PASS" ]]; then
        echo "   Result  : PASS (exit $actual_rc = expected $expected_rc)"
    elif [[ "$verdict" == "FAIL" ]]; then
        echo "   Result  : FAIL (exit $actual_rc != expected $expected_rc)"
    else
        echo "   Result  : exit $actual_rc (no expected_rc set)"
    fi
    echo ""

    results_name+=("$name")
    results_actual+=("$actual_rc")
    results_expected+=("$expected_rc")
    results_pass+=("$verdict")
    results_func+=("$func")
done

# ── Summary table
echo "═══════════════════════════════════════════════════════════════════"
echo "  Summary — $pass_count passed, $fail_count failed, ${#manifests[@]} total"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

summary_file="$LOG_DIR/SUMMARY.txt"
{
    printf "%-6s  %-42s  %-8s  %-5s  %-5s  %s\n" \
        "STATUS" "MANIFEST" "FUNCTION" "GOT" "WANT" "DESCRIPTION"
    printf "%-6s  %-42s  %-8s  %-5s  %-5s  %s\n" \
        "------" "--------" "--------" "---" "----" "-----------"
    for i in "${!results_name[@]}"; do
        printf "%-6s  %-42s  %-8s  %5s  %5s  %s\n" \
            "${results_pass[$i]}" \
            "${results_name[$i]}" \
            "${results_func[$i]}" \
            "${results_actual[$i]}" \
            "${results_expected[$i]}" \
            "$(get_meta "${manifests[$i]}" "_test_description" | cut -c1-60)"
    done
} | tee "$summary_file"

echo ""
echo "Logs: $LOG_DIR/"

# ── Exit
if [[ $fail_count -gt 0 ]]; then
    echo ""
    echo "FAILED: $fail_count test(s) did not match expected exit code."
    exit 1
elif [[ $pass_count -eq ${#manifests[@]} ]]; then
    echo ""
    echo "ALL TESTS PASSED."
    exit 0
else
    exit 0
fi
