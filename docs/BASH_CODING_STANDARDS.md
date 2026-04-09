# Bash Coding Standards

**Team:** WPS – Apple Services
**Applies to:** All Bash scripts authored for macOS fleet management, Jamf deployment, and related tooling.

---

## 1. Naming conventions

### Functions
`UpperCamelCase` with acronyms preserved. Use the `function` keyword with braces — `function FunctionName {` — no parentheses.

The `function` keyword makes the declaration visually unambiguous for scripters at any level. The opening brace goes on the same line as the function name.

```bash
# Correct
function SafeRemovePath {
function ForgetPackage {
function QuitAppByPath {
function UnloadAndRemoveLaunchAgent {

# Wrong
SafeRemovePath() {            # missing function keyword
safe_remove_path() {          # wrong case, missing keyword
function safe_remove_path {   # wrong case
function SafeRemovePath() {   # don't combine keyword + parens (redundant, inconsistent)
```

> **Migration note:** Existing scripts in the codebase use the `FunctionName() {` form. New code should use `function FunctionName {`. Existing scripts will be migrated opportunistically — when a function is modified for other reasons, update its declaration at the same time.

### Global variables
`UPPER_SNAKE_CASE`. Declare with defaulting where appropriate using `${VAR:-default}`.

```bash
APP_NAME="${APP_NAME:-Microsoft 365 Copilot}"
ECHO_PREFIX="${ECHO_PREFIX:-${APP_NAME} Uninstaller.sh - }"
VERBOSE="${VERBOSE:-false}"
DEBUG="${DEBUG:-false}"
```

### Local variables
`lower_snake_case`. Declare at the **top of the function** before any logic, using `local`. Multiple related variables may share a `local` line.

```bash
local tolerant=false
local needs_root=false
local label=""
local tmp_out tmp_err out err line
local remove_success=0 remove_fail=0 remove_missing_strict=0
```

### Tool binary paths
`UPPER_SNAKE_CASE` with `_BIN` suffix. Declared as `local` within each function. Always use the full absolute path.

```bash
local LAUNCHCTL_BIN="/bin/launchctl"
local PKGUTIL_BIN="/usr/sbin/pkgutil"
local RM_BIN="/bin/rm"
local CHFLAGS_BIN="/usr/bin/chflags"
```

### Config arrays
`UPPER_SNAKE_CASE`. Declared in the config section. Names should describe **what they contain**, not what action is taken.

```bash
PATHS_TO_REMOVE=( ... )
PKGS_TO_REMOVE=( ... )
LAUNCH_AGENTS_TO_REMOVE=( ... )
APPS_TO_QUIT=( ... )
```

---

## 2. Script structure

Every script follows a four-section layout, in this order:

```
#1  Config        — globals, target arrays, APP_NAME
#2  main()        — defined (not called); root check, iteration loops, summary
#3  Functions     — all helper functions, declared after main
#4  main "$@"     — single invocation at end of file, after all functions
```

This ordering ensures `main()` is defined before it's called, and all helper functions are defined before `main()` executes.

### Section separators
Use the full-width comment bar for major sections:

```bash
# ──────────────────────────────────────────────────────────────────────────────
# Section Name
# ──────────────────────────────────────────────────────────────────────────────
```

Use `#--------------------------------------------------------------------------------` between individual function definitions.

### Internal section comments within functions
Use `# --- description ---` for logical blocks within a function body:

```bash
# --- arg parsing ---
# --- root required ---
# --- tool presence ---
# --- strict id validation (reverse-DNS with ≥3 labels) ---
# --- presence check ---
# --- attempt removal ---
# --- verify removal ---
```

---

## 3. Function anatomy

Every function follows this structure, in order:

### 3.1 Pathname expansion and IFS safety
First lines inside the function body:

```bash
set -f  # disable pathname expansion
local IFS=$' \t\n'
```

### 3.2 Aligned logging prefixes
Use `LOG_FN_WIDTH` and `LOG_LVL_WIDTH` for column-aligned output:

```bash
local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "FunctionName()  - ")"
local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"
```

### 3.3 Argument parsing (order-agnostic)
Flags and positional args are parsed in a `for` loop with `case`, not by position. This allows `FunctionName --tolerant-missing com.vendor.id` and `FunctionName com.vendor.id --tolerant-missing` to both work.

```bash
local tolerant=false
local needs_root=false
local label=""
if (( $# == 0 || $# > 3 )); then
  echo "${my_echo_prefix}${my_err_prefix}Bad input: expected <label> [--tolerant-missing] [--needs-root]. Got $# args."
  return 2
fi
local arg
for arg in "$@"; do
  case "$arg" in
    --tolerant-missing)
      if [[ $tolerant == true ]]; then
        echo "${my_echo_prefix}${my_err_prefix}Bad input: duplicate --tolerant-missing flag."
        return 2
      fi
      tolerant=true ;;
    --needs-root)
      if [[ $needs_root == true ]]; then
        echo "${my_echo_prefix}${my_err_prefix}Bad input: duplicate --needs-root flag."
        return 2
      fi
      needs_root=true ;;
    -*)
      echo "${my_echo_prefix}${my_err_prefix}Bad input: unknown flag '$arg'."
      return 2 ;;
    *)
      if [[ -n "$label" ]]; then
        echo "${my_echo_prefix}${my_err_prefix}Bad input: multiple non-flag arguments."
        return 2
      fi
      label="$arg" ;;
  esac
done
```

Duplicate flag detection is mandatory. Unknown flags are rejected.

### 3.4 Root gate
Two patterns depending on the function:

**Opt-in** (only when `--needs-root` is passed):
```bash
if $needs_root && [[ $EUID -ne 0 ]]; then
  echo "${my_echo_prefix}${my_err_prefix}Needs root: run as sudo/root."
  return 3
fi
```

**Mandatory** (function always requires root, e.g., LaunchDaemon operations):
```bash
if [[ $EUID -ne 0 ]]; then
  echo "${my_echo_prefix}${my_err_prefix}Needs root: LaunchDaemons require root to manage."
  return 3
fi
```

### 3.5 Tool presence check
Verify every external binary exists and is executable before use:

```bash
local PKGUTIL_BIN="/usr/sbin/pkgutil"
if [[ ! -x "$PKGUTIL_BIN" ]]; then
  echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $PKGUTIL_BIN"
  return 1
fi
```

### 3.6 Input validation
Reverse-DNS identifiers are validated with a strict regex (≥3 dot-separated labels):

```bash
local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
if [[ ! "$label" =~ $id_re ]]; then
  echo "${my_echo_prefix}${my_err_prefix}Invalid label format: $label"
  return 2
fi
```

### 3.7 Action → Verify pattern
Every destructive action is followed by a verification step that confirms the action took effect. Never assume success from an exit code alone.

```bash
# Action
"$PKGUTIL_BIN" --forget "$pkg_id" >/dev/null 2>&1

# Verify
if "$PKGUTIL_BIN" --pkg-info "$pkg_id" >/dev/null 2>&1; then
  echo "${my_echo_prefix}${my_err_prefix}Receipt still present after forget."
  return 5
fi
```

For `launchctl` specifically: **never trust its exit codes**. Capture stdout/stderr to tmpfiles and parse the text:

```bash
local tmp_out tmp_err out err
tmp_out="$(/usr/bin/mktemp -t lcvfy_out.XXXXXX)"
tmp_err="$(/usr/bin/mktemp -t lcvfy_err.XXXXXX)"
"$LAUNCHCTL_BIN" print "$domain_target" 1>"$tmp_out" 2>"$tmp_err" || true
out="$(cat "$tmp_out" 2>/dev/null || true)"
err="$(cat "$tmp_err" 2>/dev/null || true)"
rm -f "$tmp_out" "$tmp_err"
```

### 3.8 Verbose/Debug output
Gate informational messages behind `VERBOSE` and `DEBUG`:

```bash
[[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
  echo "${my_echo_prefix}${my_vrb_prefix}Receipt absent after forget. Success."

[[ ${DEBUG:-false} == true ]] && \
  echo "${my_echo_prefix}${my_dbg_prefix}Canonical root: $root_abs"
```

Errors always print unconditionally.

---

## 4. Return code conventions

All functions use a standardized return code scheme:

| Code | Meaning |
|------|---------|
| 0 | Success (action completed, or target absent with `--tolerant-missing`) |
| 1 | Generic failure (missing tool, internal error, unexpected state) |
| 2 | Bad input (wrong arg count, unknown flag, invalid format, duplicate flag) |
| 3 | Needs root (EUID ≠ 0 when root is required) |
| 4 | Target not present and NOT tolerant (plist missing, service not found, etc.) |
| 5 | Operation failed (action attempted but verify-after shows it didn't take) |

The `--tolerant-missing` flag converts what would be rc 4 into rc 0. This is the standard mechanism for making absence non-fatal in uninstall flows.

---

## 5. Function header comment block

Every function gets a metadata header and documentation block immediately above the `function FunctionName {` line:

```bash
# @name FunctionName
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires DependencyFunction, /path/to/binary
#
# FunctionName — One-line summary of what this function does.
#   Optional additional context lines (indented with 2 spaces).
#
# Inputs (order-agnostic):
#   $*  <required_arg> [--tolerant-missing] [--needs-root]
#       Examples:
#         FunctionName com.vendor.id
#         FunctionName --tolerant-missing com.vendor.id
#
# Returns:
#   0 = success (description)
#   1 = generic failure (description)
#   2 = bad input (description)
#   3 = needs root (description)
#   4 = not present and NOT tolerant (description)
#   5 = operation failed (description)
#
# Safety notes:
#   - What this function does NOT do (e.g., "never deletes files")
#   - Globbing/quoting safety measures
#   - Validation approach
function FunctionName {
  set -f
  local IFS=$' \t\n'
  # ...
```

The `@requires` tag lists both function dependencies and binary paths, comma-separated. Version constraints use `>=` syntax when applicable (e.g., `SafeRemovePath>=1.0.2`).

---

## 6. Script file header

```bash
#!/usr/bin/env bash
# @name Script Name
# @version X.Y.Z
# @branch main
# @requires Function1, Function2, /path/to/tool
#
# Purpose:
#   What this script does.
#
# Usage:
#   sudo "./Script Name.sh"
#
# Globals you can tweak:
#   - ARRAY_NAME:  description
#   - ANOTHER:     description
#
# Exit:
#   0 on success; 1 if any step fails; 3 if not run as root.
```

---

## 7. main() conventions

- **Root check** is the first thing in `main()`.
- **Counter variables** for each action type: `<type>_success` and `<type>_fail`.
- **Iteration blocks** loop over config arrays, call the appropriate helper with `--tolerant-missing`, capture `rc`, and increment counters.
- **Summary block** at the end prints all counters.
- **Exit condition** checks all `_fail` counters. Exit 0 if all are zero, exit 1 otherwise.

```bash
function main {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "${ECHO_PREFIX}ERROR: This script must be run as root (sudo)." >&2
    exit 3
  fi

  local remove_success=0 remove_fail=0
  # ... more counters ...

  # ── Action Type (description)
  local var
  for var in "${ARRAY[@]}"; do
    HelperFunction "$var" "--tolerant-missing"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "${ECHO_PREFIX}Did thing: $var"
      ((remove_success++))
    else
      echo "${ECHO_PREFIX}ERROR: Failed thing: $var (rc=$rc)" >&2
      ((remove_fail++))
    fi
  done

  # Summary
  echo "──────────────────────────────────────────────────────────────────────────────"
  echo "${ECHO_PREFIX}Summary:"
  echo "  Type    : success=$remove_success failure=$remove_fail"

  if [[ $remove_fail -eq 0 ]]; then
    echo "${ECHO_PREFIX}${APP_NAME} uninstall complete."
    exit 0
  else
    echo "${ECHO_PREFIX}${APP_NAME} uninstall completed with failures." >&2
    exit 1
  fi
}
```

---

## 8. Safety rules

1. **All variables are quoted.** No unquoted `$var` anywhere. `"$var"` always.
2. **Globbing is disabled** at function entry with `set -f`.
3. **IFS is explicitly set** at function entry: `local IFS=$' \t\n'`.
4. **No `eval` on untrusted data.** If `eval` is unavoidable, the variable name must be a hardcoded string from within the function, never from user/manifest input.
5. **No nested function definitions.** Every function is a top-level peer in section #3. If you need a helper, make it a standalone function.
6. **Full paths for all external binaries.** Never rely on `$PATH`. Declare as `local *_BIN="/full/path"` and use the variable.
7. **Immutable flags are cleared before deletion** (when running as root):
   ```bash
   if [[ $EUID -eq 0 && -x "$CHFLAGS_BIN" ]]; then
     "$CHFLAGS_BIN" nouchg,noschg -- "$p" 2>/dev/null
   fi
   ```
8. **Broken symlinks are treated as present** in existence checks:
   ```bash
   if [[ ! -e "$p" && ! -L "$p" ]]; then
     # truly absent
   fi
   ```

---

## 9. Logging

### Log levels
- **ERROR** — always printed, unconditionally. Goes to stderr for failures that affect the outcome.
- **INFO** — printed when `VERBOSE=true` or `DEBUG=true`. Confirmations, progress.
- **DEBUG** — printed when `DEBUG=true` only. Internal state, intermediate values.

### Format
All log lines are column-aligned using `LOG_FN_WIDTH` (function name column, default 24) and `LOG_LVL_WIDTH` (level column, default 10):

```
Microsoft 365 Copilot Uninstaller.sh - ForgetPackage()  -          INFO:     Receipt absent after forget. Success.
Microsoft 365 Copilot Uninstaller.sh - SafeRemovePath() -          ERROR:    one or more delete steps failed under: /path
```

The prefix chain is: `ECHO_PREFIX` + `FunctionName() - ` (padded) + `LEVEL:` (padded) + message.

---

## 10. Process requirements

### shellcheck
All scripts must pass `shellcheck` with zero warnings before merge. Run against the target shell (`-s bash`):

```bash
shellcheck -s bash script.sh
```

If a warning must be suppressed, use an inline directive with a comment explaining why:

```bash
# shellcheck disable=SC2086  # intentional word splitting for flag passthrough
```

### shellspec
All scripts must have a corresponding ShellSpec test file. Test files live alongside the script or in a `spec/` directory and use the `.sh` extension convention for ShellSpec DSLs.

Each function should have specs covering at minimum:
- **Happy path** — correct inputs produce expected outcome (rc 0)
- **Bad input** — missing args, unknown flags, invalid format (rc 2)
- **Tolerant-missing** — absent target with `--tolerant-missing` returns 0
- **Strict-missing** — absent target without `--tolerant-missing` returns 4
- **Verify-after** — mock the action tool to succeed but the verify step to fail (rc 5)

```bash
Describe 'ForgetPackage'
  It 'returns 2 when no arguments provided'
    When call ForgetPackage
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 0 when package is absent and tolerant-missing'
    When call ForgetPackage --tolerant-missing com.vendor.nonexistent
    The status should eq 0
  End
End
```

### Version control
Scripts are versioned in the `@version` tag using semver (`MAJOR.MINOR.PATCH`). Bump rules:
- **PATCH** — bug fixes, log message changes, shellcheck fixes
- **MINOR** — new flags, new optional behavior, non-breaking additions
- **MAJOR** — changed return codes, renamed arguments, breaking interface changes
