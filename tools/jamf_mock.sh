#!/bin/bash
# jamf_mock.sh — Simulate Jamf Pro script invocation locally.
#
# Jamf always passes 11 positional parameters to scripts:
#   $1 = mount point (typically "/")
#   $2 = computer name
#   $3 = logged-in username
#   $4–$11 = custom parameters from the Jamf policy
#
# Each parameter is individually double-quoted by the Jamf binary, so spaces
# and most special characters are preserved. Empty parameters are passed as
# empty strings (""), not omitted — positional order is always intact.
#
# This wrapper simulates that behavior: it injects realistic $1–$3 values
# and shifts your CLI arguments into the $4–$11 positions, then invokes the
# target script with sudo (since Jamf runs scripts as root).
#
# Usage:
#   ./tools/jamf_mock.sh <script> [param4] [param5] ... [param11]
#
# Example:
#   ./tools/jamf_mock.sh ./src/uninstaller.sh \
#       "jamf=true" \
#       "Privileges" \
#       "/Applications/Privileges.app" \
#       "corp.sap.privileges.pkg" \
#       '$LibAgt/corp.sap.privileges.agent|$LibDmn/corp.sap.privileges.daemon' \
#       "/Applications/Privileges.app" \
#       "" \
#       '$UsrCnt/corp.sap.privileges'
#
#   This invokes:
#     sudo /bin/bash ./src/uninstaller.sh "/" "MyMac" "admin" "jamf=true" "Privileges" ...
#
# Options:
#   --dry-run    Print the command that would be executed, but don't run it
#   --no-sudo    Run without sudo (for testing without root)
#   --shell=zsh  Use /bin/zsh instead of /bin/bash to invoke the script

set -euo pipefail

# ── Simulated Jamf reserved parameters
JAMF_MOUNT_POINT="/"
JAMF_COMPUTER_NAME="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
JAMF_USERNAME="$(stat -f '%Su' /dev/console 2>/dev/null || echo "${USER:-unknown}")"

# ── Parse wrapper flags (before the script path)
use_sudo=true
dry_run=false
shell="/bin/bash"

while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --dry-run)
            dry_run=true
            shift ;;
        --no-sudo)
            use_sudo=false
            shift ;;
        --shell=*)
            shell="${1#--shell=}"
            shift ;;
        *)
            echo "ERROR: Unknown flag: $1" >&2
            echo "Usage: $0 [--dry-run] [--no-sudo] [--shell=path] <script> [param4..param11]" >&2
            exit 1 ;;
    esac
done

# ── Require at least the script path
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 [--dry-run] [--no-sudo] [--shell=path] <script> [param4..param11]" >&2
    echo "" >&2
    echo "Your arguments become \$4–\$11. Jamf's \$1–\$3 are injected automatically:" >&2
    echo "  \$1 = \"$JAMF_MOUNT_POINT\"  (mount point)" >&2
    echo "  \$2 = \"$JAMF_COMPUTER_NAME\"  (computer name)" >&2
    echo "  \$3 = \"$JAMF_USERNAME\"  (current user)" >&2
    exit 1
fi

script_path="$1"
shift

if [[ ! -f "$script_path" ]]; then
    echo "ERROR: Script not found: $script_path" >&2
    exit 1
fi

# ── Build the argument list: $1–$3 (Jamf reserved) + $4–$11 (user params)
# Jamf always passes exactly 11 args. Pad empty strings for missing $4–$11.
params=()
params+=("$JAMF_MOUNT_POINT")       # $1
params+=("$JAMF_COMPUTER_NAME")     # $2
params+=("$JAMF_USERNAME")          # $3

# $4–$11: user's CLI args, padded with empty strings to always have 8
for i in $(seq 1 8); do
    if [[ $i -le $# ]]; then
        params+=("${!i}")
    else
        params+=("")
    fi
done

# ── Build the command
cmd=()
if $use_sudo; then
    cmd+=(sudo)
fi
cmd+=("$shell" "$script_path")
cmd+=("${params[@]}")

# ── Display
echo "── Jamf Mock-Up ──────────────────────────────────────────" >&2
echo "  Script : $script_path" >&2
echo "  Shell  : $shell" >&2
echo "  Sudo   : $use_sudo" >&2
echo "" >&2
echo "  \$1  (mount point)    : ${params[0]}" >&2
echo "  \$2  (computer name)  : ${params[1]}" >&2
echo "  \$3  (username)       : ${params[2]}" >&2
for i in $(seq 3 10); do
    slot=$((i + 1))  # $4–$11
    val="${params[$i]}"
    if [[ -n "$val" ]]; then
        printf '  $%-3s (parameter %-2d)  : %s\n' "$slot" "$slot" "$val" >&2
    else
        printf '  $%-3s (parameter %-2d)  : (empty)\n' "$slot" "$slot" >&2
    fi
done
echo "─────────────────────────────────────────────────────────" >&2
echo "" >&2

if $dry_run; then
    echo "# Dry run — command that would be executed:" >&2
    # Print with proper quoting so it's copy-pasteable
    printf '%q' "${cmd[0]}"
    for arg in "${cmd[@]:1}"; do
        printf ' %q' "$arg"
    done
    echo ""
    exit 0
fi

# ── Execute
exec "${cmd[@]}"
