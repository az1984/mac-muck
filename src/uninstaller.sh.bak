#!/usr/bin/env bash
# @name uninstaller.sh
# @version 2.0.0
# @branch main
# @requires SafeRemovePath, ForgetPackage, SafeDelete, UnlinkSymlink, RemoveDir, RemovePathForUsers, QuitAppByPath, ListGraphicalUsers, VerifyServiceUnloaded, DisableLaunchAgent, DisableLaunchDaemon, UnloadAndRemoveLaunchAgent, UnloadAndRemoveLaunchDaemon, /usr/sbin/pkgutil, /bin/launchctl
#
# MUCK — Mac Uninstaller Construction Kit
#
# Universal macOS uninstaller. Feed it a JSON manifest or CLI flags describing
# what to remove and it handles quit, paths, per-user profiles, packages,
# LaunchAgents/Daemons, Finder extensions, QuickLook plugins, Privileged
# Helpers, Login Items, and Containers.
#
# Usage:
#   sudo ./uninstaller.sh manifest.json
#   sudo ./uninstaller.sh --manifest=manifest.json
#   sudo ./uninstaller.sh --app-name="App" --paths="/Applications/App.app" ...
#
# Exit:
#   0 on success (no failures); 1 if any step fails; 3 if not run as root.

# ──────────────────────────────────────────────────────────────────────────────
# Config — defaults for standalone use. Overridden by manifest or CLI flags.
# ──────────────────────────────────────────────────────────────────────────────

APP_NAME="${APP_NAME:-}"

ECHO_PREFIX="${ECHO_PREFIX:-uninstaller.sh - }"
VERBOSE="${VERBOSE:-false}"
DEBUG="${DEBUG:-false}"

PATHS_TO_REMOVE=()
PROFILE_REL_PATHS_TO_REMOVE=()
APPS_TO_QUIT=()
PKGS_TO_REMOVE=()
LAUNCH_AGENTS_TO_REMOVE=()
LAUNCH_DAEMONS_TO_REMOVE=()
FINDER_EXTENSIONS_TO_REMOVE=()
QUICKLOOK_PLUGINS_TO_REMOVE=()
PRIVILEGED_HELPERS_TO_REMOVE=()
LOGIN_ITEMS_TO_REMOVE=()
CONTAINERS_TO_REMOVE=()

# ──────────────────────────────────────────────────────────────────────────────
# Global flags set by ParseInput (do not edit here — parsed at runtime)
# ──────────────────────────────────────────────────────────────────────────────
JAMF_MODE=false

# ──────────────────────────────────────────────────────────────────────────────
# main (define first)
#   • Root check lives here
#   • Iterations live here; helpers own tolerance logic
#   • Only aggregates exit codes + branches on specific ints (no globals)
# ──────────────────────────────────────────────────────────────────────────────
main() {
	if [[ $( _get_effective_euid ) -ne 0 ]]; then
		echo "${ECHO_PREFIX}ERROR: This script must be run as root (sudo)." >&2
		exit 3
	fi

	local remove_success=0 remove_fail=0 remove_missing_strict=0
	local forget_success=0 forget_fail=0 forget_missing_strict=0
  local quit_success=0 quit_fail=0
  local userrm_success=0 userrm_fail=0
  local agent_success=0 agent_fail=0
  local daemon_success=0 daemon_fail=0

  # ── Quit apps (by bundle path; tolerant missing)
  local app rc
  for app in "${APPS_TO_QUIT[@]}"; do
    QuitAppByPath "$app" "--tolerant-missing"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "${ECHO_PREFIX}Quit (or not running): $app"
      ((quit_success++))
    else
      echo "${ECHO_PREFIX}ERROR: Failed to quit: $app (rc=$rc)" >&2
      ((quit_fail++))
    fi
  done

	# ── Remove paths
	# The exit code for missing files while in strict mode is 255  ← change if your helper differs
	local path
	for path in "${PATHS_TO_REMOVE[@]}"; do
		SafeRemovePath "$path" "--tolerant-missing"
		rc=$?
		# If you want strict mode, remove "--tolerant-missing" above

		if [[ $rc -eq 0 ]]; then
			echo "${ECHO_PREFIX}Removed: $path"
			((remove_success++))
		elif [[ $rc -eq 255 ]]; then
			echo "${ECHO_PREFIX}Item missing; strict mode active for path: $path" >&2
			((remove_missing_strict++))
			((remove_fail++))
		else
			echo "${ECHO_PREFIX}ERROR: Failed to remove: $path (rc=$rc)" >&2
			((remove_fail++))
		fi
	done

  # ── Remove user-relative paths across graphical users (tolerant missing)
  # Uses RemovePathForUsers; refuses /Users/Shared internally.
  local rel
  for rel in "${PROFILE_REL_PATHS_TO_REMOVE[@]}"; do
    RemovePathForUsers "$rel" "--tolerant-missing"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "${ECHO_PREFIX}Removed from user profiles: ~/$rel"
      ((userrm_success++))
    else
      echo "${ECHO_PREFIX}ERROR: Failed removing from user profiles: ~/$rel (rc=$rc)" >&2
      ((userrm_fail++))
    fi
  done

	# ── Forget pkg receipts
	# The exit code for missing receipts while in strict mode is 255  ← change if your helper differs
	local pkg_id
	for pkg_id in "${PKGS_TO_REMOVE[@]}"; do
		ForgetPackage "--tolerant-missing" "$pkg_id"
		rc=$?
		# If you want strict mode, remove "--tolerant-missing" above

		if [[ $rc -eq 0 ]]; then
			echo "${ECHO_PREFIX}Forgot package: $pkg_id"
			((forget_success++))
		elif [[ $rc -eq 255 ]]; then
			echo "${ECHO_PREFIX}Item missing; strict mode active for receipt: $pkg_id" >&2
			((forget_missing_strict++))
			((forget_fail++))
		else
			echo "${ECHO_PREFIX}ERROR: Failed to forget package: $pkg_id (rc=$rc)" >&2
			((forget_fail++))
		fi
	done

  # ── Unload and remove LaunchAgents (by plist label; tolerant missing)
  local agent_label
  for agent_label in "${LAUNCH_AGENTS_TO_REMOVE[@]}"; do
    UnloadAndRemoveLaunchAgent "$agent_label" "--tolerant-missing"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "${ECHO_PREFIX}Removed LaunchAgent: $agent_label"
      ((agent_success++))
    else
      echo "${ECHO_PREFIX}ERROR: Failed to remove LaunchAgent: $agent_label (rc=$rc)" >&2
      ((agent_fail++))
    fi
  done

  # ── Unload and remove LaunchDaemons (by plist label; tolerant missing)
  local daemon_label
  for daemon_label in "${LAUNCH_DAEMONS_TO_REMOVE[@]}"; do
    UnloadAndRemoveLaunchDaemon "$daemon_label" "--tolerant-missing"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "${ECHO_PREFIX}Removed LaunchDaemon: $daemon_label"
      ((daemon_success++))
    else
      echo "${ECHO_PREFIX}ERROR: Failed to remove LaunchDaemon: $daemon_label (rc=$rc)" >&2
      ((daemon_fail++))
    fi
  done

  # ── Remove Finder Sync Extensions (by bundle identifier; tolerant missing)
  local finder_ext
  for finder_ext in "${FINDER_EXTENSIONS_TO_REMOVE[@]}"; do
    RemoveFinderExtension "$finder_ext" "--tolerant-missing"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "${ECHO_PREFIX}Removed Finder extension: $finder_ext"
      ((agent_success++))
    else
      echo "${ECHO_PREFIX}ERROR: Failed to remove Finder extension: $finder_ext (rc=$rc)" >&2
      ((agent_fail++))
    fi
  done

  # ── Remove QuickLook Plugins (path to .qlgenerator OR appex bundle ID; tolerant missing)
  local ql_plugin
  for ql_plugin in "${QUICKLOOK_PLUGINS_TO_REMOVE[@]}"; do
    if [[ "$ql_plugin" == /* ]]; then
      # Legacy .qlgenerator — remove from disk
      RemoveQuickLookPlugin "$ql_plugin" "--tolerant-missing"
      rc=$?
      if [[ $rc -eq 0 ]]; then
        echo "${ECHO_PREFIX}Removed QuickLook plugin: $ql_plugin"
        ((remove_success++))
      else
        echo "${ECHO_PREFIX}ERROR: Failed to remove QuickLook plugin: $ql_plugin (rc=$rc)" >&2
        ((remove_fail++))
      fi
    else
      # Modern appex bundle ID — the extension lives inside the parent .app
      # bundle (already removed via paths). Just note it for the QL reload.
      echo "${ECHO_PREFIX}QuickLook extension (appex): $ql_plugin — removed with parent app bundle"
      ((remove_success++))
    fi
  done

  # ── Reload QuickLook subsystem (once, after all plugin removals)
  local QL_RELOAD_BIN="/usr/bin/qlmanage"
  if [[ -x "$QL_RELOAD_BIN" ]]; then
    "$QL_RELOAD_BIN" -r >/dev/null 2>&1
    echo "${ECHO_PREFIX}QuickLook subsystem reloaded"
  else
    echo "${ECHO_PREFIX}WARNING: qlmanage not found; skipping QuickLook reload" >&2
  fi

  # ── Remove Privileged Helper Tools (by path; tolerant missing)
  local helper_path
  for helper_path in "${PRIVILEGED_HELPERS_TO_REMOVE[@]}"; do
    RemovePrivilegedHelper "$helper_path" "--tolerant-missing"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "${ECHO_PREFIX}Removed Privileged Helper: $helper_path"
      ((remove_success++))
    else
      echo "${ECHO_PREFIX}ERROR: Failed to remove Privileged Helper: $helper_path (rc=$rc)" >&2
      ((remove_fail++))
    fi
  done

  # ── Remove Login Items (by identifier; tolerant missing)
  local login_item
  for login_item in "${LOGIN_ITEMS_TO_REMOVE[@]}"; do
    RemoveLoginItems "$login_item" "--tolerant-missing"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "${ECHO_PREFIX}Removed login item: $login_item"
      ((remove_success++))
    else
      echo "${ECHO_PREFIX}ERROR: Failed to remove login item: $login_item (rc=$rc)" >&2
      ((remove_fail++))
    fi
  done

	# Summary
	echo "──────────────────────────────────────────────────────────────────────────────"
	echo "${ECHO_PREFIX}Summary:"
  echo "  Quit    : success=$quit_success failure=$quit_fail"
	echo "  Paths   : success=$remove_success failure=$remove_fail (missing-strict=$remove_missing_strict)"
  echo "  Profiles: success=$userrm_success failure=$userrm_fail"
	echo "  Packages: success=$forget_success failure=$forget_fail (missing-strict=$forget_missing_strict)"
	echo "  Agents  : success=$agent_success failure=$agent_fail (includes LaunchAgents, LaunchDaemons, Finder extensions)"
	echo "  Daemons : success=$daemon_success failure=$daemon_fail"
	echo "  Paths   : success=$remove_success failure=$remove_fail (includes QuickLook plugins, Privileged Helpers, Login Items)"

	if [[ $quit_fail -eq 0 && $remove_fail -eq 0 && $userrm_fail -eq 0 && $forget_fail -eq 0 && $agent_fail -eq 0 && $daemon_fail -eq 0 ]]; then
		echo "${ECHO_PREFIX}${APP_NAME} uninstall complete."
		exit 0
	else
		echo "${ECHO_PREFIX}${APP_NAME} uninstall completed with failures." >&2
		exit 1
	fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Functions area (declare after main; helpers own tolerance logic)
# ──────────────────────────────────────────────────────────────────────────────

# Support for testing: use FAKE_EUID/FAKE_UID when available (set by spec_helper.sh)
# This allows testing root/non-root behavior without actual root access
_get_effective_euid() {
  if [[ -n "${FAKE_EUID:-}" ]]; then
    echo "$FAKE_EUID"
  else
    echo "$EUID"
  fi
}

_get_effective_uid() {
  if [[ -n "${FAKE_UID:-}" ]]; then
    echo "$FAKE_UID"
  else
    echo "$UID"
  fi
}

# @name ForgetPackage
# @version 1.1.1
# @approved true
# @channels stable,beta
# @branch core
# @requires /usr/sbin/pkgutil
#
# ForgetPackage — remove a macOS package receipt by id using pkgutil.
#
# Inputs (order-agnostic):
#   $*  <pkg_id_or_^pkg_id$> [--tolerant-missing]
#       Examples:
#         ForgetPackage com.vendor.pkg
#         ForgetPackage '^com.vendor.pkg$'
#         ForgetPackage --tolerant-missing com.vendor.pkg
#         ForgetPackage '^com.vendor.pkg$' --tolerant-missing
#
# Returns:
#   0 = success (removed, or missing but tolerated)
#   1 = generic failure (e.g., pkgutil missing, internal error)
#   2 = bad input (too many args, unknown flag, missing id, invalid id format/anchors)
#   3 = needs root (EUID != 0)
#   4 = package id not present and NOT tolerant
#   5 = operation failed (pkgutil --forget failed / still present)
#
# Safety notes:
#   - This function **never** deletes files or directories; it only forgets receipts.
#   - Globbing is disabled and all variables are quoted to prevent accidental expansions.
#   - The id is strictly validated to reverse-DNS format with ≥3 labels and only [A-Za-z0-9_-.].
#   - Optional leading '^' and trailing '$' are allowed for input clarity and are normalized away
#     before invoking 'pkgutil' (which needs the literal id).
ForgetPackage() {
  set -f  # disable pathname expansion
  local IFS=$' \t\n'

  # aligned logging
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "ForgetPackage()  - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # --- arg parsing ---
  local tolerant=false
  local raw_arg=""
  local arg
  for arg in "$@"; do
    case "$arg" in
      --tolerant-missing)
        if [[ $tolerant == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: duplicate --tolerant-missing flag."
          return 2
        fi
        tolerant=true ;;
      -*)
        echo "${my_echo_prefix}${my_err_prefix}Bad input: unknown flag '$arg'."
        return 2 ;;
      *)
        if [[ -n "$raw_arg" ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: multiple non-flag arguments."
          return 2
        fi
        raw_arg="$arg" ;;
    esac
  done

  # Validate required argument after parsing (so duplicate flags are caught first)
  if [[ -z "$raw_arg" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: package id is required."
    return 2
  fi

  # --- normalize anchors for validation ---
  local has_leading_caret=false has_trailing_dollar=false
  [[ "${raw_arg:0:1}" == "^" ]] && has_leading_caret=true
  [[ "${raw_arg: -1}" == '$' ]] && has_trailing_dollar=true

  local pkg_id="$raw_arg"
  $has_leading_caret  && pkg_id="${pkg_id#^}"
  $has_trailing_dollar && pkg_id="${pkg_id%\$}"

  # forbid internal anchors
  if [[ "$pkg_id" == *'^'* || "$pkg_id" == *'$'* ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: anchors '^' and '$' are only allowed at string boundaries."
    return 2
  fi

  # pretty view for logs
  local validation_view
  if $has_leading_caret && $has_trailing_dollar; then
    validation_view="$raw_arg"
  else
    validation_view="^${pkg_id}\$"
  fi

  # --- strict id validation (reverse-DNS with ≥3 labels) ---
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
  if [[ ! "$pkg_id" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid package id format: ${validation_view}"
    return 2
  fi
  if [[ "$pkg_id" =~ [[:space:]/\\\*\?\[\]\{\}\|\;\:\<\>\&\`\'\"] ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid characters in package id: ${validation_view}"
    return 2
  fi

  # --- root required ---
  if [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: run as sudo/root."
    return 3
  fi

  # --- tool presence ---
  # Allow PKGUTIL_BIN to be overridden via environment variable for testing
  local PKGUTIL_BIN="${PKGUTIL_BIN:-/usr/sbin/pkgutil}"
  if [[ ! -x "$PKGUTIL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $PKGUTIL_BIN"
    return 1
  fi

  # --- presence check ---
  if "$PKGUTIL_BIN" --pkg-info "$pkg_id" >/dev/null 2>&1; then
    [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Receipt present for ${validation_view}. Proceeding to forget."
  else
    if [[ $tolerant == true ]]; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Package id ${validation_view} not present; tolerant mode → success."
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Package id ${validation_view} not present."
      return 4
    fi
  fi

  # --- attempt removal ---
  if "$PKGUTIL_BIN" --forget "$pkg_id" >/dev/null 2>&1; then
    [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
      echo "${my_echo_prefix}${my_vrb_prefix}pkgutil forget succeeded for ${validation_view}. Verifying..."
  else
    echo "${my_echo_prefix}${my_err_prefix}pkgutil forget reported failure for ${validation_view}. Verifying state..."
  fi

  # --- verify removal ---
  if "$PKGUTIL_BIN" --pkg-info "$pkg_id" >/dev/null 2>&1; then
    echo "${my_echo_prefix}${my_err_prefix}Receipt still present after forget for ${validation_view}."
    return 5
  else
    [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
      echo "${my_echo_prefix}${my_vrb_prefix}Receipt absent after forget for ${validation_view}. Success."
    return 0
  fi
}
#--------------------------------------------------------------------------------

# @name ListGraphicalUsers
# @version 1.1.1
# @approved true
# @channels stable,beta
# @branch core
# @requires /usr/bin/dscl,/usr/bin/id
#
# ListGraphicalUsers — Emit newline-separated local *graphical* users.
#   Criteria (default):
#     • UID >= 500
#     • Home verified via dscl and under /Users/<name>
#     • Skips Shared, Guest, .localized
#
# Inputs:
#   $1  optional flag "--all"         — include any user with home under /Users (ignores UID>=500)
#   $2  optional flag "--needs-root"  — require root if supplied
#
# Output:
#   stdout: one username per line
#
# Returns:
#   0 = success (even if list is empty)
#   1 = generic failure
#   2 = bad input (unknown flag)
#   3 = needs root (when --needs-root is supplied but EUID != 0)

ListGraphicalUsers() {
  # -------- locals / prefixes --------
  local priorPrefix="${ECHO_PREFIX:-}"
  local functionTag="ListGraphicalUsers() - "
  local my_echo_prefix="${priorPrefix}${functionTag}"

  local my_vrb_prefix="INFO:     "
  local my_err_prefix="ERROR:    "
  local my_dbg_prefix="DEBUG:    "

  # -------- args / flags --------
  local include_all=false needs_root=false
  while (( $# )); do
    case "$1" in
      --all)        include_all=true ;;
      --needs-root) needs_root=true ;;
      *) echo "${my_echo_prefix}${my_err_prefix} Unknown flag: $1"; return 2 ;;
    esac
    shift
  done

  # -------- root gate (opt-in) --------
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix} Must be run as root (EUID $( _get_effective_euid )) due to --needs-root"
    return 3
  fi

  # -------- tool checks --------
  local DSCL="/usr/bin/dscl"
  [[ -x "$DSCL" ]] || { echo "${my_echo_prefix}${my_err_prefix} dscl not found"; return 1; }

  # -------- discovery loop via dscl --------
  # Format: `dscl . -list /Users UniqueID` → "<name> <uid>"
  while IFS= read -r line; do
    # -- parse name + uid
    local u uid
    u="${line%% *}"
    uid="${line##* }"

    # -- skip non-graphical / known pseudo-accounts
    case "$u" in Shared|Guest|".localized") continue ;; esac

    # -- read home from dscl; fallback to /Users/<name>
    local home
    home="$("$DSCL" . -read "/Users/$u" NFSHomeDirectory 2>/dev/null | awk '/NFSHomeDirectory:/{print $2}')"
    [[ -z "$home" ]] && home="/Users/$u"

    # -- sanity: must be under /Users and map to /Users/<name>
    [[ "$home" == /Users/* ]] || continue
    [[ "$home" == "/Users/$u" ]] || continue

    # -- UID filter unless --all
    if ! $include_all; then
      [[ "$uid" =~ ^[0-9]+$ ]] || continue
      (( uid >= 500 )) || continue
    fi

    # -- verify user exists and home dir is present
    id "$u" >/dev/null 2>&1 || continue
    [[ -d "$home" ]] || continue

    # -- emit
    echo "$u"
  done < <("$DSCL" . -list /Users UniqueID 2>/dev/null)

  # -------- done --------
  return 0
}
#--------------------------------------------------------------------------------

# @name QuitAppByPath
# @version 1.1.0
# @approved true
# @channels stable,beta
# @branch core
# @requires /usr/bin/pkill,/usr/bin/pgrep,/usr/libexec/PlistBuddy,/usr/bin/realpath,/bin/kill
#
# QuitAppByPath — Quit by *bundle path*, *binary path*, *process name*, or *PID*:
#   - .app bundle path  → derive CFBundleExecutable, pkill -TERM -x <name>
#   - binary path       → pkill -TERM -f <full path>, fallback verify by -f
#   - bare name         → pkill -TERM -x <name>, verify by -x
#   - PID (digits only) → kill -TERM <pid>, verify with kill -0
#   - Not running == success.
#
# Inputs:
#   $1  target (REQUIRED) — .app path | binary path | process name | PID
#   $2  optional flag "--tolerant-missing" — missing bundle path is treated as success
#   $3  optional flag "--needs-root"       — require root if supplied
#
# Returns:
#   0 = success (not running OR terminated)
#   1 = generic failure (bad type/derive failed/verify-after failed)
#   2 = bad input (missing arg, >3 args, unknown flag)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = missing bundle without --tolerant-missing
#   5 = signal/kill failed

QuitAppByPath() {
  # -------- locals / prefixes --------
  local priorPrefix="${ECHO_PREFIX:-}"
  local functionTag="QuitAppByPath() - "
  local my_echo_prefix="${priorPrefix}${functionTag}"

  local my_vrb_prefix="INFO:     "
  local my_err_prefix="ERROR:    "
  local my_dbg_prefix="DEBUG:    "

  local PKILL="${PKILL_BIN:-/usr/bin/pkill}"
  local PGREP="${PGREP_BIN:-/usr/bin/pgrep}"
  local PLISTB="/usr/libexec/PlistBuddy"
  local KILL="/bin/kill"

  if [[ ! -x "$PGREP" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $PGREP"
    return 1
  fi
  if [[ ! -x "$PKILL" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $PKILL"
    return 1
  fi

  # -------- args / flags (parse first to catch duplicates before count validation) --------
  local target=""
  local tolerant=false needs_root=false
  local arg_count=0
  while (( $# )); do
    case "$1" in
      --tolerant-missing)
        if [[ $tolerant == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix} Bad input: duplicate --tolerant-missing flag."
          return 2
        fi
        tolerant=true ;;
      --needs-root)
        if [[ $needs_root == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix} Bad input: duplicate --needs-root flag."
          return 2
        fi
        needs_root=true ;;
      -*) echo "${my_echo_prefix}${my_err_prefix} Unknown flag: $1"; return 2 ;;
      *)
        # Count non-flag arguments
        ((arg_count++))
        if [[ -z "$target" ]]; then
          target="$1"
        fi
        ;;
    esac
    shift
  done

  # Validate required argument after parsing (so duplicate flags are caught first)
  if [[ -z "$target" ]]; then
    echo "${my_echo_prefix}${my_err_prefix} Bad input: expected target argument"
    return 2
  fi
  if (( arg_count > 1 )); then
    echo "${my_echo_prefix}${my_err_prefix} Bad input: expected 1..3 args (target + optional flags)"
    return 2
  fi

  # -------- root gate (opt-in) --------
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix} Must be run as root (EUID $( _get_effective_euid )) due to --needs-root"
    return 3
  fi

  # -------- classify target --------
  local mode="" name="" verify_kind="" # verify_kind: x|f|pid
  if [[ "$target" =~ ^[0-9]+$ ]]; then
    mode="pid"; verify_kind="pid"
  elif [[ -d "$target" && "${target##*.}" == "app" ]]; then
    mode="bundle"; verify_kind="x"
  elif [[ "$target" == */* ]]; then
    # any path containing a slash but not an .app directory → treat as binary path
    mode="binpath"; verify_kind="f"
  else
    mode="name"; name="$target"; verify_kind="x"
  fi
  [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix} Mode: $mode  Target: $target"

  # -------- PID mode --------
  if [[ "$mode" == "pid" ]]; then
    local pid="$target"
    if ! "$KILL" -0 "$pid" 2>/dev/null; then
      [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix} Not running (pid): $pid"
      return 0
    fi
    if "$KILL" -TERM "$pid" 2>/dev/null; then
      # verify-after (brief poll)
      local i
      for i in {1..10}; do
        sleep 0.2
        if ! "$KILL" -0 "$pid" 2>/dev/null; then
          [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]] && \
            echo "${my_echo_prefix}${my_vrb_prefix} Quit ok (pid): $pid"
          return 0
        fi
      done
      echo "${my_echo_prefix}${my_err_prefix} Verify failed: still running (pid): $pid"
      return 1
    else
      echo "${my_echo_prefix}${my_err_prefix} kill -TERM failed (pid): $pid"
      return 5
    fi
  fi

  # -------- bundle mode: derive name --------
  if [[ "$mode" == "bundle" ]]; then
    if [[ ! -e "$target" ]]; then
      if $tolerant; then
        [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]] && \
          echo "${my_echo_prefix}${my_vrb_prefix} Absent bundle (tolerant-missing): $target"
        return 0
      else
        echo "${my_echo_prefix}${my_err_prefix} Absent bundle (not tolerant-missing): $target"
        return 4
      fi
    fi
    if [[ ! -d "$target" || "${target##*.}" != "app" ]]; then
      echo "${my_echo_prefix}${my_err_prefix} Not an .app bundle: $target"
      return 1
    fi
    local plist="$target/Contents/Info.plist"
    if [[ -f "$plist" ]]; then
      name="$("$PLISTB" -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null || true)"
    fi
    [[ -z "$name" ]] && name="$(basename "$target" .app)"
    if [[ -z "$name" ]]; then
      echo "${my_echo_prefix}${my_err_prefix} Could not determine process name for bundle: $target"
      return 1
    fi
    [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix} Derived name: $name"
  fi

  # -------- binpath mode: choose pattern --------
  # For binary paths, prefer matching the *full command line* with -f, which is safer.
  local binpath=""
  if [[ "$mode" == "binpath" ]]; then
    binpath="$target"
    name="$(basename -- "$binpath")"
    [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix} Binary path basename: $name"
  fi

  # -------- if not running, success --------
  if [[ "$verify_kind" == "x" ]]; then
    if ! "$PGREP" -x "$name" >/dev/null 2>&1; then
      [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix} Not running (name): $name"
      return 0
    fi
  elif [[ "$verify_kind" == "f" ]]; then
    if ! "$PGREP" -f -- "$binpath" >/dev/null 2>&1; then
      [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix} Not running (cmdline contains): $binpath"
      return 0
    fi
  fi

  # -------- send TERM --------
  local term_ok=false
  case "$verify_kind" in
    x)
      if "$PKILL" -TERM -x -- "$name" 2>/dev/null; then term_ok=true; fi
      ;;
    f)
      if "$PKILL" -TERM -f -- "$binpath" 2>/dev/null; then term_ok=true; fi
      ;;
  esac

  if ! $term_ok; then
    case "$verify_kind" in
      x) echo "${my_echo_prefix}${my_err_prefix} pkill failed for name: $name" ;;
      f) echo "${my_echo_prefix}${my_err_prefix} pkill failed for pattern: $binpath" ;;
    esac
    return 5
  fi

  # -------- verify-after (brief poll) --------
  local i
  for i in {1..10}; do
    sleep 0.2
    case "$verify_kind" in
      x) "$PGREP" -x "$name" >/dev/null 2>&1 || { [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_vrb_prefix} Quit ok (name): $name"; return 0; } ;;
      f) "$PGREP" -f -- "$binpath" >/dev/null 2>&1 || { [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_vrb_prefix} Quit ok (pattern): $binpath"; return 0; } ;;
    esac
  done

  echo "${my_echo_prefix}${my_err_prefix} Verify failed: still running"
  [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix} mode=$mode verify=$verify_kind name='$name' binpath='$binpath'"
  return 1
}
#--------------------------------------------------------------------------------

# @name RemoveDir
# @version 1.0.2
# @approved true
# @channels stable,beta
# @branch core
# @requires /bin/rmdir
#
# RemoveDir — Remove an empty directory (no recursion).
#
# Inputs:
#   $1  dir_path (REQUIRED)
#   $2  optional flag "--tolerant-missing"
#   $3  optional flag "--needs-root"
#
# Returns:
#   0 = success (removed OR did not exist with --tolerant-missing)
#   1 = error not handled otherwise (e.g., not a directory)
#   2 = bad input (missing path, >3 args, or unknown flag)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = missing without --tolerant-missing
#   5 = rmdir failed

RemoveDir() {
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local priorPrefix="${ECHO_PREFIX:-}"
  local functionTag="RemoveDir()    - "
  local my_echo_prefix="${priorPrefix}$(printf "%-*s" "$fnw" "$functionTag")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  local RMDIR_BIN="/bin/rmdir"
  local CHFLAGS_BIN="/usr/bin/chflags"

  # --- args / flags (parse first to catch duplicates before count validation) ---
  local d=""
  local tolerant=false needs_root=false
  local arg_count=0
  while (($#)); do
    case "$1" in
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
      -*) echo "${my_echo_prefix}${my_err_prefix}Unknown flag: $1"; return 2 ;;
      *)
        # Count non-flag arguments
        ((arg_count++))
        if [[ -z "$d" ]]; then
          d="$1"
        fi
        ;;
    esac; shift
  done

  # Validate required argument after parsing (so duplicate flags are caught first)
  if [[ -z "$d" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected path argument"
    return 2
  fi
  if (( arg_count > 1 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected 1..3 args (path + optional flags)"
    return 2
  fi

  # --- root gate (opt-in) ---
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Must be run as root (EUID $( _get_effective_euid )) due to --needs-root"
    return 3
  fi

  # --- existence check (treat broken symlink as present but not a dir) ---
  if [[ ! -e "$d" && ! -L "$d" ]]; then
    if $tolerant; then
      if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
        echo "${my_echo_prefix}${my_vrb_prefix}Absent dir (tolerant-missing): $d"
      fi
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Absent dir (not tolerant-missing): $d"
      return 4
    fi
  fi

  # --- type check ---
  if [[ ! -d "$d" || -L "$d" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Not a directory: $d"
    return 1
  fi

  # --- clear immutable flags on the directory (root only) ---
  if [[ $( _get_effective_euid ) -eq 0 && -x "$CHFLAGS_BIN" ]]; then
    "$CHFLAGS_BIN" nouchg,noschg -- "$d" 2>/dev/null
  fi

  # --- remove ---
  if "$RMDIR_BIN" -- "$d" 2>/dev/null; then
    if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
      echo "${my_echo_prefix}${my_vrb_prefix}rmdir ok: $d"
    fi
    [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}rmdir ok"
    return 0
  else
    echo "${my_echo_prefix}${my_err_prefix}rmdir failed (not empty or in use): $d"
    return 5
  fi
}
#--------------------------------------------------------------------------------

# @name RemovePathForUsers
# @version 1.1.1
# @approved true
# @channels stable,beta
# @branch core
# @requires SafeRemovePath>=1.0.2,ListGraphicalUsers>=1.1.0
#
# RemovePathForUsers — For each user, remove a *user-relative* path safely.
#   - Builds <home>/<relative_path> and calls SafeRemovePath on it.
#   - Auto-discovers users with ListGraphicalUsers if none provided.
#   - REFUSES to delete /Users/Shared (warns and skips; does not fail run).
#
# Inputs:
#   $1  user_relative_path (REQUIRED) — e.g., Library/Caches/MyApp
#   $2+ usernames and/or flags:
#         --tolerant-missing  — pass through to SafeRemovePath
#         --needs-root        — require root & pass through
#   Non-flag args after $1 are treated as explicit usernames.
#
# Returns:
#   0 = success (all requested removals succeeded or were absent with tolerant)
#   1 = generic failure (e.g., path looks empty; bad username home)
#   2 = bad input (missing path or unknown flag)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   5 = one or more per-user removals failed

RemovePathForUsers() {
  # -------- locals / prefixes --------
  local priorPrefix="${ECHO_PREFIX:-}"
  local functionTag="RemovePathForUsers() - "
  local my_echo_prefix="${priorPrefix}${functionTag}"

  local my_vrb_prefix="INFO:     "
  local my_err_prefix="ERROR:    "
  local my_dbg_prefix="DEBUG:    "

  # -------- args / flags (parse first to catch duplicates before validation) --------
  local rel=""
  local tolerant=false needs_root=false
  local users=()
  local arg_count=0
  while (( $# )); do
    case "$1" in
      --tolerant-missing)
        if [[ $tolerant == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix} Bad input: duplicate --tolerant-missing flag."
          return 2
        fi
        tolerant=true ;;
      --needs-root)
        if [[ $needs_root == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix} Bad input: duplicate --needs-root flag."
          return 2
        fi
        needs_root=true ;;
      --*) echo "${my_echo_prefix}${my_err_prefix} Unknown flag: $1"; return 2 ;;
      *)
        # Count non-flag arguments
        ((arg_count++))
        if [[ -z "$rel" ]]; then
          rel="$1"
        else
          users+=("$1")
        fi
        ;;
    esac
    shift
  done

  # Validate required argument after parsing (so duplicate flags are caught first)
  if [[ -z "$rel" ]]; then
    echo "${my_echo_prefix}${my_err_prefix} Bad input: expected at least 1 arg (relative path)"
    return 2
  fi

  # -------- root gate (opt-in) --------
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix} Must be run as root (EUID $( _get_effective_euid )) due to --needs-root"
    return 3
  fi

  # -------- normalize / validate relative path --------
  rel="${rel#/}"    # strip leading slash if provided
  if [[ -z "$rel" ]]; then
    echo "${my_echo_prefix}${my_err_prefix} Bad input: relative path cannot be empty"
    return 2
  fi

  # -------- dependency presence --------
  if ! type -t ListGraphicalUsers >/dev/null 2>&1; then
    echo "${my_echo_prefix}${my_err_prefix}Missing dependency: ListGraphicalUsers"
    return 1
  fi
  if ! type -t SafeRemovePath >/dev/null 2>&1; then
    echo "${my_echo_prefix}${my_err_prefix}Missing dependency: SafeRemovePath"
    return 1
  fi

  # -------- user discovery (if none provided) --------
  if (( ${#users[@]} == 0 )); then
    while IFS= read -r _u; do users+=("$_u"); done < <( ListGraphicalUsers )
  fi

  # -------- per-user removal loop --------
  local failures=0 u home full rc
  for u in "${users[@]}"; do
    # -- refuse the Shared pseudo-user
    if [[ "$u" == "Shared" ]]; then
      echo "${my_echo_prefix}${my_vrb_prefix} Skip: refusing to delete /Users/Shared (user 'Shared')"
      continue
    fi

    # -- resolve user's home (~user → path; fallback /Users/<name>)
    home="$(eval "echo ~$u" 2>/dev/null || true)"
    [[ -z "$home" || ! -d "$home" ]] && home="/Users/$u"
    if [[ ! -d "$home" ]]; then
      echo "${my_echo_prefix}${my_err_prefix} No home dir for user '$u'"
      failures=$((failures+1))
      continue
    fi

    # -- build absolute target; safety guards
    full="$home/$rel"
    if [[ "$full" == "/Users/Shared" ]]; then
      echo "${my_echo_prefix}${my_vrb_prefix} Skip: refusing to delete /Users/Shared (exact match)"
      continue
    fi

    # -- call SafeRemovePath (flags passed through)
    [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]] && \
      echo "${my_echo_prefix}${my_vrb_prefix} Removing for user '$u': $full"

    SafeRemovePath "$full" $($tolerant && echo "--tolerant-missing") $($needs_root && echo "--needs-root")
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "${my_echo_prefix}${my_err_prefix} Removal failed for user '$u' (rc=$rc): $full"
      failures=$((failures+1))
      continue
    fi
  done

  # -------- summarize outcome --------
  (( failures > 0 )) && return 5 || return 0
}
#--------------------------------------------------------------------------------

# @name SafeDelete
# @version 1.0.3
# @approved true
# @channels stable,beta
# @branch core
# @requires UnlinkSymlink, RemoveDir, /bin/rm
#
# SafeDelete — Non-recursive delete of a single path (rm replacement).
#   If symlink → UnlinkSymlink
#   If directory → RemoveDir (must be empty)
#   Else → rm -f (single node)
#
# Inputs:
#   $1  target_path (REQUIRED) — single path to delete (non-recursive)
#   $2  optional flag "--tolerant-missing" — missing target is treated as success
#   $3  optional flag "--needs-root"       — enforce root if supplied
#
# Returns:
#   0 = success (deleted OR did not exist with --tolerant-missing)
#   1 = error not handled otherwise
#   2 = bad input (missing path, >3 args, or unknown flag)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = missing without --tolerant-missing
#   5 = delete step failed (unlink/rmdir/rm)

SafeDelete() {
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local priorPrefix="${ECHO_PREFIX:-}"
  local functionTag="SafeDelete()  - "
  local my_echo_prefix="${priorPrefix}$(printf "%-*s" "$fnw" "$functionTag")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  local RM_BIN="/bin/rm"
  local CHFLAGS_BIN="/usr/bin/chflags"

  # --- args / flags (parse first to catch duplicates before count validation) ---
  local p=""
  local tolerant=false needs_root=false
  local arg_count=0
  while (($#)); do
    case "$1" in
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
      -*) echo "${my_echo_prefix}${my_err_prefix}Unknown flag: $1"; return 2 ;;
      *)
        # Count non-flag arguments
        ((arg_count++))
        if [[ -z "$p" ]]; then
          p="$1"
        fi
        ;;
    esac
    shift
  done

  # Validate argument count after parsing (so duplicate flags are caught first)
  if [[ -z "$p" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected path argument"
    return 2
  fi
  if (( arg_count > 1 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected 1..3 args (path + optional flags)"
    return 2
  fi

  # --- root gate (opt-in) ---
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Must be run as root (EUID $( _get_effective_euid )) due to --needs-root"
    return 3
  fi

  # --- existence check (treat broken symlink as present) ---
  if [[ ! -e "$p" && ! -L "$p" ]]; then
    if $tolerant; then
      if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
        echo "${my_echo_prefix}${my_vrb_prefix}Absent (tolerant-missing): $p"
      fi
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Absent (not tolerant-missing): $p"
      return 4
    fi
  fi

  # --- delegate or delete ---
  if [[ -L "$p" ]]; then
    UnlinkSymlink "$p" $($tolerant && echo "--tolerant-missing") $($needs_root && echo "--needs-root")
    local rc=$?
    [[ $rc -ne 0 ]] && return 5
    return 0
  elif [[ -d "$p" ]]; then
    RemoveDir "$p" $($tolerant && echo "--tolerant-missing") $($needs_root && echo "--needs-root")
    local rc=$?
    [[ $rc -ne 0 ]] && return 5
    return 0
  else
    # Regular file: clear immutable flags when root, then rm -f
    if [[ $( _get_effective_euid ) -eq 0 && -x "$CHFLAGS_BIN" ]]; then
      "$CHFLAGS_BIN" nouchg,noschg -- "$p" 2>/dev/null
    fi
    if "$RM_BIN" -f -- "$p" 2>/dev/null; then
      if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
        echo "${my_echo_prefix}${my_vrb_prefix}rm ok: $p"
      fi
      [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}rm -f ok"
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}rm failed: $p"
      return 5
    fi
  fi
}

#--------------------------------------------------------------------------------

# @name SafeRemovePath
# @version 1.1.0
# @approved true
# @channels stable,beta
# @branch core
# @requires SafeDelete, UnlinkSymlink, RemoveDir, /usr/bin/realpath, /usr/bin/find
#
# SafeRemovePath — Walk a path bottom-up with `find -depth` and delete elements:
#   - symlink  -> UnlinkSymlink
#   - dir      -> RemoveDir (must be empty at that moment)
#   - other    -> SafeDelete (non-recursive)
#
# Inputs:
#   $1  root_path (REQUIRED)
#   $2  optional flag "--tolerant-missing"
#   $3  optional flag "--needs-root"
#
# Returns:
#   0 = success
#   1 = verify failed (root still present) / unexpected
#   2 = bad input (missing/extra args, unknown flag)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = missing without --tolerant-missing
#   5 = one or more delete steps failed

SafeRemovePath() {
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local priorPrefix="${ECHO_PREFIX:-}"
  local functionTag="SafeRemovePath() - "
  local my_echo_prefix="${priorPrefix}$(printf "%-*s" "$fnw" "$functionTag")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  local FIND_BIN="/usr/bin/find"
  local REALPATH_BIN="/usr/bin/realpath"

  # --- args / flags (parse first to catch duplicates before count validation) ---
  local root=""
  local tolerant=false needs_root=false
  local arg_count=0
  while (($#)); do
    case "$1" in
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
      -*) echo "${my_echo_prefix}${my_err_prefix}Unknown flag: $1"; return 2 ;;
      *)
        # Count non-flag arguments
        ((arg_count++))
        if [[ -z "$root" ]]; then
          root="$1"
        fi
        ;;
    esac
    shift
  done

  # Validate argument count after parsing (so duplicate flags are caught first)
  if [[ -z "$root" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected path argument"
    return 2
  fi
  if (( arg_count > 1 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected 1..3 args (path + optional flags)"
    return 2
  fi

  # --- root gate (opt-in) ---
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Must be run as root (EUID $( _get_effective_euid )) due to --needs-root"
    return 3
  fi

  # --- missing root? (tolerate if requested) ---
  if [[ ! -e "$root" && ! -L "$root" ]]; then
    local msg_path
    [[ "$root" == /* ]] && msg_path="$root" || msg_path="$(pwd -P)/$root"
    if $tolerant; then
      if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
        echo "${my_echo_prefix}${my_vrb_prefix}Absent (tolerant-missing): $msg_path"
      fi
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Absent (not tolerant-missing): $msg_path"
      return 4
    fi
  fi

  # --- fast paths (no traversal needed) ---
  if [[ -L "$root" ]]; then
    UnlinkSymlink "$root" $($tolerant && echo "--tolerant-missing") $($needs_root && echo "--needs-root")
    return $(( $? == 0 ? 0 : 5 ))
  fi
  if [[ ! -d "$root" ]]; then
    SafeDelete "$root" $($tolerant && echo "--tolerant-missing") $($needs_root && echo "--needs-root")
    return $?
  fi

  # --- canonical path (for logs only) ---
  local root_abs=""
  if [[ -x "$REALPATH_BIN" ]]; then
    root_abs="$("$REALPATH_BIN" "$root" 2>/dev/null || echo "")"
  fi
  [[ -z "$root_abs" ]] && { [[ "$root" == /* ]] && root_abs="$root" || root_abs="$(pwd -P)/$root"; }
  [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Canonical root: $root_abs"

  # --- collect nodes bottom-up into an array (bash 3+/zsh friendly) ---
  local -a nodes=()
  if builtin type -t mapfile >/dev/null 2>&1; then
    mapfile -d '' -t nodes < <("$FIND_BIN" "$root" -depth -print0 2>/dev/null)
  else
    local p
    while IFS= read -r -d '' p; do
      nodes+=("$p")
    done < <("$FIND_BIN" "$root" -depth -print0 2>/dev/null)
  fi

  # --- walk the array and delete per-node ---
  local failures=0 p
  for p in "${nodes[@]}"; do
    if [[ -L "$p" ]]; then
      UnlinkSymlink "$p" $($tolerant && echo "--tolerant-missing") $($needs_root && echo "--needs-root") || ((failures++))
    elif [[ -d "$p" ]]; then
      RemoveDir "$p"      $($tolerant && echo "--tolerant-missing") $($needs_root && echo "--needs-root") || ((failures++))
    else
      SafeDelete "$p"     $($tolerant && echo "--tolerant-missing") $($needs_root && echo "--needs-root") || ((failures++))
    fi
  done

  [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}bottom-up failures=${failures}"
  if [[ $failures -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}one or more delete steps failed under: $root_abs"
    return 5
  fi

  # --- verify root removed ---
  if [[ -e "$root" || -L "$root" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Verify failed: still present after delete: $root_abs"
    return 1
  fi

  if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
    echo "${my_echo_prefix}${my_vrb_prefix}Removed: $root_abs"
  fi
  return 0
}
#--------------------------------------------------------------------------------

# @name UnlinkSymlink
# @version 1.0.4
# @approved true
# @channels stable,beta
# @branch core
# @requires /usr/bin/unlink
#
# UnlinkSymlink — Unlink a symlink only.
#
# Inputs:
#   $1  symlink_path (REQUIRED)
#   $2  optional flag "--tolerant-missing"
#   $3  optional flag "--needs-root"
#
# Returns:
#   0 = success (unlinked OR did not exist with --tolerant-missing)
#   1 = error not handled otherwise (e.g., not a symlink)
#   2 = bad input (missing path, >3 args, or unknown flag)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = missing without --tolerant-missing
#   5 = unlink failed

UnlinkSymlink() {
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local priorPrefix="${ECHO_PREFIX:-}"
  local functionTag="UnlinkSymlink() - "
  local my_echo_prefix="${priorPrefix}$(printf "%-*s" "$fnw" "$functionTag")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  local UNLINK_BIN="/usr/bin/unlink"
  local CHFLAGS_BIN="/usr/bin/chflags"
  local RM_BIN="/bin/rm"

  # --- args / flags (parse first to catch duplicates before count validation) ---
  local p=""
  local tolerant=false needs_root=false
  local arg_count=0
  while (($#)); do
    case "$1" in
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
      -*) echo "${my_echo_prefix}${my_err_prefix}Unknown flag: $1"; return 2 ;;
      *)
        # Count non-flag arguments
        ((arg_count++))
        if [[ -z "$p" ]]; then
          p="$1"
        fi
        ;;
    esac
    shift
  done

  # Validate argument count after parsing (so duplicate flags are caught first)
  if [[ -z "$p" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected path argument"
    return 2
  fi
  if (( arg_count > 1 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected 1..3 args (path + optional flags)"
    return 2
  fi

  # --- root gate (opt-in) ---
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Must be run as root (EUID $( _get_effective_euid )) due to --needs-root"
    return 3
  fi

  # --- existence check (treat broken symlink as present) ---
  if [[ ! -e "$p" && ! -L "$p" ]]; then
    if $tolerant; then
      if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
        echo "${my_echo_prefix}${my_vrb_prefix}Absent (tolerant-missing): $p"
      fi
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Absent (not tolerant-missing): $p"
      return 4
    fi
  fi

  # --- type check ---
  if [[ ! -L "$p" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Not a symlink: $p"
    return 1
  fi

  # --- clear immutable flags on the link (root only; do not follow target) ---
  if [[ $( _get_effective_euid ) -eq 0 && -x "$CHFLAGS_BIN" ]]; then
    "$CHFLAGS_BIN" -h nouchg,noschg -- "$p" 2>/dev/null
  fi

  # --- unlink; fallback to rm -f (no recursion, no dereference) ---
  if "$UNLINK_BIN" "$p" 2>/dev/null; then
    if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
      echo "${my_echo_prefix}${my_vrb_prefix}unlinked symlink: $p"
    fi
    [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}unlink ok"
    return 0
  fi

  if "$RM_BIN" -f -- "$p" 2>/dev/null; then
    if [[ ! -L "$p" && ! -e "$p" ]]; then
      if [[ "${VERBOSE:-false}" == true || "${DEBUG:-false}" == true ]]; then
        echo "${my_echo_prefix}${my_vrb_prefix}rm -f removed symlink: $p"
      fi
      [[ "${DEBUG:-false}" == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}rm -f ok"
      return 0
    fi
  fi

  echo "${my_echo_prefix}${my_err_prefix}unlink failed: $p"
  return 5
}

#--------------------------------------------------------------------------------

# @name VerifyServiceUnloaded
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires /bin/launchctl
#
# VerifyServiceUnloaded — Check that a launchd service is no longer active.
#   Uses `launchctl print <domain_target>` and parses stdout/stderr to determine
#   whether the service has been successfully unloaded.
#
# Inputs:
#   $1  domain_target (REQUIRED) — fully qualified target, e.g.,
#       "gui/501/com.vendor.agent" or "system/com.vendor.daemon"
#
# Returns:
#   0 = verified unloaded ("Could not find service" or "state = not running")
#   1 = still running (bootout did not take effect)
#   2 = bad input (missing arg or too many args)
#   3 = ambiguous (could not determine state from launchctl output)
#
# Safety notes:
#   - Read-only query; does NOT modify launchctl state.
#   - launchctl exit codes are NOT trusted; stdout/stderr text is parsed instead.
#   - Uses tmpfile capture pattern (from is_launchagent_running.sh / is_launchdaemon_running.sh).

VerifyServiceUnloaded() {
  set -f
  local IFS=$' \t\n'

  # aligned logging
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "VerifySvcUnloaded() - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # --- arg check ---
  local domain_target=""
  if (( $# != 1 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected exactly 1 arg (domain_target). Got $# args."
    return 2
  fi
  domain_target="$1"

  # --- tool presence ---
  local LAUNCHCTL_BIN="/bin/launchctl"
  if [[ ! -x "$LAUNCHCTL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $LAUNCHCTL_BIN"
    return 3
  fi

  # --- query launchctl print (do NOT trust exit code) ---
  local tmp_out tmp_err out err
  tmp_out="$(/usr/bin/mktemp -t lcvfy_out.XXXXXX)"
  tmp_err="$(/usr/bin/mktemp -t lcvfy_err.XXXXXX)"
  "$LAUNCHCTL_BIN" print "$domain_target" 1>"$tmp_out" 2>"$tmp_err" || true
  out="$(cat "$tmp_out" 2>/dev/null || true)"
  err="$(cat "$tmp_err" 2>/dev/null || true)"
  rm -f "$tmp_out" "$tmp_err"

  # "Could not find service" in stderr = fully unloaded (ideal outcome)
  if [[ -n "$err" ]] && { printf '%s' "$err" | /usr/bin/grep -Fq "Could not find service"; }; then
    [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Verified unloaded (not found): $domain_target"
    return 0
  fi

  # "state = not running" in stdout = acceptable (disabled, not active)
  if printf '%s\n' "$out" | /usr/bin/grep -Eq '^[[:space:]]*state[[:space:]]*=[[:space:]]*not[[:space:]]+running[[:space:]]*$'; then
    [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Verified not running: $domain_target"
    return 0
  fi

  # "state = running" in stdout = failure — still alive after bootout
  if printf '%s\n' "$out" | /usr/bin/grep -Eq '^[[:space:]]*state[[:space:]]*=[[:space:]]*running[[:space:]]*$'; then
    echo "${my_echo_prefix}${my_err_prefix}Still running after bootout: $domain_target"
    return 1
  fi

  # Neither canonical state found — ambiguous
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Ambiguous state for $domain_target; could not determine loaded/running status."
  return 3
}
#--------------------------------------------------------------------------------

# @name DisableLaunchAgent
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires ListGraphicalUsers, /bin/launchctl
#
# DisableLaunchAgent — Disable a LaunchAgent via launchctl for all graphical users.
#   For each user, calls `launchctl disable gui/<uid>/<label>`.
#   Does NOT unload or delete the plist — use UnloadAndRemoveLaunchAgent for that.
#
# Inputs (order-agnostic):
#   $*  <label> [--tolerant-missing] [--needs-root]
#       The label is the job identifier (e.g., "com.vendor.agent"), NOT a file path.
#
# Returns:
#   0 = success (disabled for all users, or not present with --tolerant-missing)
#   1 = generic failure (launchctl missing, internal error)
#   2 = bad input (too many args, unknown flag, missing label, invalid format)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = agent not present in any user domain and NOT tolerant
#   5 = operation failed (disable reported failure or verify-after shows still enabled)
#
# Safety notes:
#   - This function only manipulates launchctl state; it does NOT delete files.
#   - The label is validated to reverse-DNS format with ≥3 labels.
#   - Verification uses `launchctl print-disabled gui/<uid>` and checks for
#     `<label> => true` in the output (pattern from is_launchagent_disabled.sh).
#   - launchctl exit codes are NOT trusted; stdout/stderr text is parsed instead.

DisableLaunchAgent() {
  set -f
  local IFS=$' \t\n'

  # aligned logging
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "DisableLaunchAgent() - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # --- arg parsing (order-agnostic) ---
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

  if [[ -z "$label" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: label is required."
    return 2
  fi

  # --- root gate (opt-in) ---
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: run as sudo/root."
    return 3
  fi

  # --- tool presence ---
  local LAUNCHCTL_BIN="/bin/launchctl"
  if [[ ! -x "$LAUNCHCTL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $LAUNCHCTL_BIN"
    return 1
  fi

  # --- strict label validation (reverse-DNS with ≥3 labels) ---
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
  if [[ ! "$label" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid label format: $label"
    return 2
  fi

  # --- dependency presence ---
  if ! type -t ListGraphicalUsers >/dev/null 2>&1; then
    echo "${my_echo_prefix}${my_err_prefix}Missing dependency: ListGraphicalUsers"
    return 1
  fi

  # --- discover graphical users ---
  local -a users=()
  while IFS= read -r _u; do users+=("$_u"); done < <( ListGraphicalUsers )
  if (( ${#users[@]} == 0 )); then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}No graphical users found; tolerant mode → success."
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}No graphical users found."
      return 4
    fi
  fi

  # --- disable for each user ---
  local u uid
  local found_any=false
  local failures=0
  local tmp_out tmp_err out err line

  for u in "${users[@]}"; do
    uid="$(id -u "$u" 2>/dev/null || true)"
    if [[ -z "$uid" || ! "$uid" =~ ^[0-9]+$ ]]; then
      [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Could not resolve UID for '$u'; skipping."
      continue
    fi

    # -- check if the agent exists in this user's domain via launchctl print --
    tmp_out="$(/usr/bin/mktemp -t lcprint_out.XXXXXX)"
    tmp_err="$(/usr/bin/mktemp -t lcprint_err.XXXXXX)"
    "$LAUNCHCTL_BIN" print "gui/${uid}/${label}" 1>"$tmp_out" 2>"$tmp_err" || true
    err="$(cat "$tmp_err" 2>/dev/null || true)"
    rm -f "$tmp_out" "$tmp_err"

    # Detect explicit "not found" from stderr
    if [[ -n "$err" ]] && { printf '%s' "$err" | /usr/bin/grep -Fq "Could not find service"; }; then
      [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Agent ${label} not found in gui/${uid}; skipping user '$u'."
      continue
    fi

    found_any=true
    [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Agent ${label} found in gui/${uid}. Disabling."

    # -- disable --
    "$LAUNCHCTL_BIN" disable "gui/${uid}/${label}" 2>/dev/null || true
    [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}launchctl disable gui/${uid}/${label} attempted."

    # -- verify: check print-disabled output for label => true --
    tmp_out="$(/usr/bin/mktemp -t lcdis_out.XXXXXX)"
    tmp_err="$(/usr/bin/mktemp -t lcdis_err.XXXXXX)"
    "$LAUNCHCTL_BIN" print-disabled "gui/${uid}" 1>"$tmp_out" 2>"$tmp_err" || true
    out="$(cat "$tmp_out" 2>/dev/null || true)"
    err="$(cat "$tmp_err" 2>/dev/null || true)"
    rm -f "$tmp_out" "$tmp_err"

    if [[ -n "$err" ]]; then
      echo "${my_echo_prefix}${my_err_prefix}Verify failed: print-disabled had stderr for gui/${uid}."
      ((failures++))
      continue
    fi

    # Parse the disabled-override mapping (pattern from is_launchagent_disabled.sh)
    line="$(
      printf '%s\n' "$out" | /usr/bin/awk -v J="$label" '
        BEGIN{IGNORECASE=1}
        $0 ~ "^[[:space:]]*\"?" J "\"?[[:space:]]*(=>|=)[[:space:]]*(true|false)" {
          print tolower($0); exit
        }
      '
    )"

    if printf '%s\n' "$line" | /usr/bin/grep -q "true"; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Verified disabled: ${label} in gui/${uid} for user '$u'."
    else
      echo "${my_echo_prefix}${my_err_prefix}Verify failed: ${label} not showing disabled in gui/${uid} after disable."
      ((failures++))
    fi
  done

  # --- nothing found ---
  if [[ $found_any == false ]]; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Agent ${label} not found in any user domain; tolerant mode → success."
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Agent ${label} not found in any user domain."
      return 4
    fi
  fi

  # --- summarize ---
  if (( failures > 0 )); then
    echo "${my_echo_prefix}${my_err_prefix}One or more disable operations failed for ${label}."
    return 5
  fi

  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Agent ${label} disabled for all applicable users. Success."
  return 0
}
#--------------------------------------------------------------------------------

# @name DisableLaunchDaemon
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires /bin/launchctl
#
# DisableLaunchDaemon — Disable a LaunchDaemon via launchctl in the system domain.
#   Calls `launchctl disable system/<label>`.
#   Does NOT unload or delete the plist — use UnloadAndRemoveLaunchDaemon for that.
#
# Inputs (order-agnostic):
#   $*  <label> [--tolerant-missing] [--needs-root]
#       The label is the job identifier (e.g., "com.vendor.daemon"), NOT a file path.
#
# Returns:
#   0 = success (disabled, or not present with --tolerant-missing)
#   1 = generic failure (launchctl missing, internal error)
#   2 = bad input (too many args, unknown flag, missing label, invalid format)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = daemon not present in system domain and NOT tolerant
#   5 = operation failed (disable failed or verify-after shows still enabled)
#
# Safety notes:
#   - This function only manipulates launchctl state; it does NOT delete files.
#   - The label is validated to reverse-DNS format with ≥3 labels.
#   - Verification uses `launchctl print-disabled system` and checks for
#     `<label> => true` (pattern from is_launchdaemon_disabled.sh).
#   - Daemons require root to manage; this function enforces EUID == 0.

DisableLaunchDaemon() {
  set -f
  local IFS=$' \t\n'

  # aligned logging
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "DisableLaunchDaemon() - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # --- arg parsing (order-agnostic) ---
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

  if [[ -z "$label" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: label is required."
    return 2
  fi

  # --- strict label validation (reverse-DNS with ≥3 labels) ---
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
  if [[ ! "$label" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid label format: $label"
    return 2
  fi

  # --- root check (daemons always require root) ---
  if [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: LaunchDaemons require root to disable."
    return 3
  fi

  # --- tool presence ---
  local LAUNCHCTL_BIN="/bin/launchctl"
  if [[ ! -x "$LAUNCHCTL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $LAUNCHCTL_BIN"
    return 1
  fi

  # --- pre-check: is the daemon known to launchctl? ---
  local tmp_out tmp_err out err line
  tmp_out="$(/usr/bin/mktemp -t lcprint_out.XXXXXX)"
  tmp_err="$(/usr/bin/mktemp -t lcprint_err.XXXXXX)"
  "$LAUNCHCTL_BIN" print "system/${label}" 1>"$tmp_out" 2>"$tmp_err" || true
  err="$(cat "$tmp_err" 2>/dev/null || true)"
  rm -f "$tmp_out" "$tmp_err"

  if [[ -n "$err" ]] && { printf '%s' "$err" | /usr/bin/grep -Fq "Could not find service"; }; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Daemon ${label} not found in system domain; tolerant mode → success."
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Daemon ${label} not found in system domain."
      return 4
    fi
  fi
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Daemon ${label} found in system domain. Disabling."

  # --- disable ---
  "$LAUNCHCTL_BIN" disable "system/${label}" 2>/dev/null || true
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}launchctl disable system/${label} attempted."

  # --- verify: check print-disabled for label => true ---
  tmp_out="$(/usr/bin/mktemp -t lcdis_out.XXXXXX)"
  tmp_err="$(/usr/bin/mktemp -t lcdis_err.XXXXXX)"
  "$LAUNCHCTL_BIN" print-disabled system 1>"$tmp_out" 2>"$tmp_err" || true
  out="$(cat "$tmp_out" 2>/dev/null || true)"
  err="$(cat "$tmp_err" 2>/dev/null || true)"
  rm -f "$tmp_out" "$tmp_err"

  if [[ -n "$err" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Verify failed: print-disabled had stderr for system domain."
    return 5
  fi

  line="$(
    printf '%s\n' "$out" | /usr/bin/awk -v J="$label" '
      BEGIN{IGNORECASE=1}
      $0 ~ "^[[:space:]]*\"?" J "\"?[[:space:]]*(=>|=)[[:space:]]*(true|false)" {
        print tolower($0); exit
      }
    '
  )"

  if printf '%s\n' "$line" | /usr/bin/grep -q "true"; then
    [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
      echo "${my_echo_prefix}${my_vrb_prefix}Verified disabled: ${label} in system domain."
    return 0
  else
    echo "${my_echo_prefix}${my_err_prefix}Verify failed: ${label} not showing disabled in system domain after disable."
    return 5
  fi
}
#--------------------------------------------------------------------------------

# @name UnloadAndRemoveLaunchAgent
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires ListGraphicalUsers, VerifyServiceUnloaded, SafeDelete, /bin/launchctl
#
# UnloadAndRemoveLaunchAgent — Disable, unload, and remove a LaunchAgent plist by label.
#   Searches /Library/LaunchAgents and each graphical user's ~/Library/LaunchAgents.
#   Lifecycle per location where the plist is found:
#     1. Disable via `launchctl disable gui/<uid>/<label>` for each user
#     2. Bootout via `launchctl bootout gui/<uid>/<label>` (non-fatal if not loaded)
#     3. Verify unloaded via VerifyServiceUnloaded (expect not-found or not-running)
#     4. Delete the plist file via SafeDelete
#     5. Verify deleted: plist file no longer on disk
#   For system-wide plists (/Library/LaunchAgents), bootout is attempted for every
#   graphical user since system-wide agents are loaded per-user at login.
#
# Inputs (order-agnostic):
#   $*  <label> [--tolerant-missing] [--needs-root]
#
# Returns:
#   0 = success (unloaded+removed, or missing but tolerated)
#   1 = generic failure (launchctl missing, internal error)
#   2 = bad input (too many args, unknown flag, missing label, invalid format)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = agent not present and NOT tolerant
#   5 = operation failed (unload or delete failed)
#
# Safety notes:
#   - Only removes plist files whose filename matches <label>.plist exactly.
#   - Uses SafeDelete for file removal (non-recursive, single node).
#   - The label is validated to reverse-DNS format with ≥3 labels.
#   - Bootout failures are non-fatal if the service is not currently loaded;
#     the disable and plist removal still proceed.

UnloadAndRemoveLaunchAgent() {
  set -f
  local IFS=$' \t\n'

  # aligned logging
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "UnloadRmAgent()  - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # --- arg parsing (order-agnostic) ---
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

  if [[ -z "$label" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: label is required."
    return 2
  fi

  # --- root gate (opt-in) ---
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: run as sudo/root."
    return 3
  fi

  # --- tool presence ---
  local LAUNCHCTL_BIN="/bin/launchctl"
  if [[ ! -x "$LAUNCHCTL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $LAUNCHCTL_BIN"
    return 1
  fi

  # --- strict label validation (reverse-DNS with ≥3 labels) ---
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
  if [[ ! "$label" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid label format: $label"
    return 2
  fi

  # --- dependency presence ---
  if ! type -t ListGraphicalUsers >/dev/null 2>&1; then
    echo "${my_echo_prefix}${my_err_prefix}Missing dependency: ListGraphicalUsers"
    return 1
  fi
  if ! type -t VerifyServiceUnloaded >/dev/null 2>&1; then
    echo "${my_echo_prefix}${my_err_prefix}Missing dependency: VerifyServiceUnloaded"
    return 1
  fi
  if ! type -t SafeDelete >/dev/null 2>&1; then
    echo "${my_echo_prefix}${my_err_prefix}Missing dependency: SafeDelete"
    return 1
  fi

  local plist_name="${label}.plist"
  local found_any=false
  local failures=0
  local rc

  # --- discover graphical users ---
  local -a users=()
  while IFS= read -r _u; do users+=("$_u"); done < <( ListGraphicalUsers )

  # --- system-wide LaunchAgent: /Library/LaunchAgents ---
  local sys_plist="/Library/LaunchAgents/${plist_name}"
  if [[ -f "$sys_plist" ]]; then
    found_any=true
    [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Found system agent plist: $sys_plist"

    # disable + bootout + verify for each user (system-wide agents load per-user at login)
    local u uid
    for u in "${users[@]}"; do
      uid="$(id -u "$u" 2>/dev/null || true)"
      if [[ -z "$uid" || ! "$uid" =~ ^[0-9]+$ ]]; then
        [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Could not resolve UID for '$u'; skipping."
        continue
      fi

      # disable
      "$LAUNCHCTL_BIN" disable "gui/${uid}/${label}" 2>/dev/null || true

      # bootout (non-fatal)
      "$LAUNCHCTL_BIN" bootout "gui/${uid}/${label}" 2>/dev/null || true
      [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}bootout gui/${uid}/${label} attempted."

      # verify unloaded
      VerifyServiceUnloaded "gui/${uid}/${label}"
      rc=$?
      if [[ $rc -eq 1 ]]; then
        echo "${my_echo_prefix}${my_err_prefix}Verify failed: agent still running for user '$u' (gui/${uid})."
        ((failures++))
      fi
      # rc 0 = good, rc 3 = ambiguous (proceed), rc 2 = bad input (shouldn't happen)
    done

    # delete plist
    SafeDelete "$sys_plist"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "${my_echo_prefix}${my_err_prefix}Failed to delete system agent plist: $sys_plist (rc=$rc)"
      ((failures++))
    else
      # verify deletion
      if [[ -f "$sys_plist" ]]; then
        echo "${my_echo_prefix}${my_err_prefix}Verify failed: system agent plist still present after delete: $sys_plist"
        ((failures++))
      else
        [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
          echo "${my_echo_prefix}${my_vrb_prefix}Deleted system agent plist: $sys_plist"
      fi
    fi
  fi

  # --- per-user LaunchAgents: ~/Library/LaunchAgents ---
  local home user_plist
  for u in "${users[@]}"; do
    home="$(eval "echo ~$u" 2>/dev/null || true)"
    [[ -z "$home" || ! -d "$home" ]] && home="/Users/$u"
    user_plist="${home}/Library/LaunchAgents/${plist_name}"

    if [[ -f "$user_plist" ]]; then
      found_any=true
      [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Found user agent plist for '$u': $user_plist"

      uid="$(id -u "$u" 2>/dev/null || true)"
      if [[ -n "$uid" && "$uid" =~ ^[0-9]+$ ]]; then
        # disable
        "$LAUNCHCTL_BIN" disable "gui/${uid}/${label}" 2>/dev/null || true

        # bootout (non-fatal)
        "$LAUNCHCTL_BIN" bootout "gui/${uid}/${label}" 2>/dev/null || true
        [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}bootout gui/${uid}/${label} attempted."

        # verify unloaded
        VerifyServiceUnloaded "gui/${uid}/${label}"
        rc=$?
        if [[ $rc -eq 1 ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Verify failed: agent still running for user '$u' (gui/${uid})."
          ((failures++))
        fi
      else
        [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Could not resolve UID for '$u'; skipping bootout."
      fi

      # delete plist
      SafeDelete "$user_plist"
      rc=$?
      if [[ $rc -ne 0 ]]; then
        echo "${my_echo_prefix}${my_err_prefix}Failed to delete user agent plist for '$u': $user_plist (rc=$rc)"
        ((failures++))
      else
        if [[ -f "$user_plist" ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Verify failed: user agent plist still present after delete: $user_plist"
          ((failures++))
        else
          [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
            echo "${my_echo_prefix}${my_vrb_prefix}Deleted user agent plist for '$u': $user_plist"
        fi
      fi
    fi
  done

  # --- nothing found ---
  if [[ $found_any == false ]]; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}No LaunchAgent plists found for ${label}; tolerant mode → success."
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}No LaunchAgent plists found for ${label}."
      return 4
    fi
  fi

  # --- summarize ---
  if (( failures > 0 )); then
    echo "${my_echo_prefix}${my_err_prefix}One or more operations failed for LaunchAgent ${label}."
    return 5
  fi

  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}LaunchAgent ${label} fully removed. Success."
  return 0
}
#--------------------------------------------------------------------------------

# @name UnloadAndRemoveLaunchDaemon
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires VerifyServiceUnloaded, SafeDelete, /bin/launchctl
#
# UnloadAndRemoveLaunchDaemon — Disable, unload, and remove a LaunchDaemon plist by label.
#   Searches /Library/LaunchDaemons only (daemons are system-wide, not per-user).
#   Lifecycle:
#     1. Disable via `launchctl disable system/<label>`
#     2. Bootout via `launchctl bootout system/<label>` (non-fatal if not loaded)
#     3. Verify unloaded via VerifyServiceUnloaded (expect not-found or not-running)
#     4. Delete the plist file via SafeDelete
#     5. Verify deleted: plist file no longer on disk
#
# Inputs (order-agnostic):
#   $*  <label> [--tolerant-missing] [--needs-root]
#
# Returns:
#   0 = success (unloaded+removed, or missing but tolerated)
#   1 = generic failure (launchctl missing, internal error)
#   2 = bad input (too many args, unknown flag, missing label, invalid format)
#   3 = needs root (when --needs-root is supplied but EUID != 0)
#   4 = daemon not present and NOT tolerant
#   5 = operation failed (unload or delete failed)
#
# Safety notes:
#   - Only removes plist files whose filename matches <label>.plist exactly.
#   - Uses SafeDelete for file removal (non-recursive, single node).
#   - The label is validated to reverse-DNS format with ≥3 labels.
#   - Bootout failures are non-fatal if the service is not currently loaded.
#   - Daemons run as root; this function requires EUID == 0.

UnloadAndRemoveLaunchDaemon() {
  set -f
  local IFS=$' \t\n'

  # aligned logging
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "UnloadRmDaemon() - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # --- arg parsing (order-agnostic) ---
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

  if [[ -z "$label" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: label is required."
    return 2
  fi

  # --- strict label validation (reverse-DNS with ≥3 labels) ---
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
  if [[ ! "$label" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid label format: $label"
    return 2
  fi

  # --- locate the plist ---
  local plist_name="${label}.plist"
  local sys_plist="/Library/LaunchDaemons/${plist_name}"

  # Check if plist exists first - if not found and tolerant, return success without root
  if [[ ! -f "$sys_plist" ]]; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}LaunchDaemon plist not found: $sys_plist; tolerant mode → success."
      return 0
    else
      # Only check root if we need to proceed with removal (plist exists or not tolerant)
      if [[ $( _get_effective_euid ) -ne 0 ]]; then
        echo "${my_echo_prefix}${my_err_prefix}Needs root: LaunchDaemons require root to unload and remove."
        return 3
      fi
      echo "${my_echo_prefix}${my_err_prefix}LaunchDaemon plist not found: $sys_plist."
      return 4
    fi
  fi

  # --- root check (daemons always require root) ---
  if [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: LaunchDaemons require root to unload and remove."
    return 3
  fi

  # --- tool presence ---
  local LAUNCHCTL_BIN="/bin/launchctl"
  if [[ ! -x "$LAUNCHCTL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $LAUNCHCTL_BIN"
    return 1
  fi
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Found daemon plist: $sys_plist"

  local failures=0
  local rc

  # --- step 1: disable ---
  "$LAUNCHCTL_BIN" disable "system/${label}" 2>/dev/null || true
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}launchctl disable system/${label} attempted."

  # --- step 2: bootout (non-fatal if not loaded) ---
  "$LAUNCHCTL_BIN" bootout "system/${label}" 2>/dev/null || true
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}launchctl bootout system/${label} attempted."

  # --- step 3: verify unloaded ---
  VerifyServiceUnloaded "system/${label}"
  rc=$?
  if [[ $rc -eq 1 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Verify failed: daemon ${label} still running in system domain after bootout."
    ((failures++))
  fi
  # rc 0 = good, rc 3 = ambiguous (proceed to deletion), rc 2 = bad input (shouldn't happen)

  # --- step 4: delete plist ---
  SafeDelete "$sys_plist"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Failed to delete daemon plist: $sys_plist (rc=$rc)"
    ((failures++))
  fi

  # --- step 5: verify deleted ---
  if [[ -f "$sys_plist" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Verify failed: daemon plist still present after delete: $sys_plist"
    ((failures++))
  else
    [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
      echo "${my_echo_prefix}${my_vrb_prefix}Deleted daemon plist: $sys_plist"
  fi

  # --- summarize ---
  if (( failures > 0 )); then
    echo "${my_echo_prefix}${my_err_prefix}One or more operations failed for LaunchDaemon ${label}."
    return 5
  fi

  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}LaunchDaemon ${label} fully removed. Success."
  return 0
}


# @name RemoveFinderExtension
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires /usr/bin/pluginkit
#
# RemoveFinderExtension — Disable and unregister a Finder Sync extension.
#   Uses pluginkit to disable (ignore) then remove registration.
#   The .appex on disk is NOT removed by this function; app bundle removal
#   handles that separately via SafeRemovePath.
#
# Inputs (order-agnostic):
#   $*  <bundle_id> [--tolerant-missing] [--needs-root]
#
# Returns:
#   0 = success (extension removed, or absent with --tolerant-missing)
#   1 = generic failure (pluginkit missing, internal error)
#   2 = bad input (missing arg, unknown flag, invalid bundle_id format)
#   3 = needs root (--needs-root specified but EUID != 0)
#   4 = extension not registered and NOT tolerant
#   5 = operation failed (verify-after shows still registered)
#
# Safety notes:
#   - This function only removes the registration from pluginkit database.
#   - Does NOT remove the .appex file from disk (that's handled by app removal).
#   - Bundle ID is validated to reverse-DNS format with ≥3 labels.
function RemoveFinderExtension {
  set -f
  local IFS=$' \t\n'

  # Aligned logging prefixes
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "RemoveFinderExtension()  - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # Order-agnostic argument parsing with duplicate detection
  local tolerant=false needs_root=false bundle_id=""
  if (( $# == 0 || $# > 3 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected <bundle_id> [--tolerant-missing] [--needs-root]. Got $# args."
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
        if [[ -n "$bundle_id" ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: multiple non-flag arguments."
          return 2
        fi
        bundle_id="$arg" ;;
    esac
  done

  # Root gate (opt-in)
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: run as sudo/root."
    return 3
  fi

  # Tool presence check
  local PLUGINKIT_BIN="/usr/bin/pluginkit"
  if [[ ! -x "$PLUGINKIT_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $PLUGINKIT_BIN"
    return 1
  fi

  # Strict bundle ID validation (reverse-DNS with ≥3 labels)
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
  if [[ ! "$bundle_id" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid bundle ID format: $bundle_id"
    return 2
  fi

  # Presence check (pluginkit -m -i returns info if registered, empty if not)
  local check_output
  check_output=$("$PLUGINKIT_BIN" -m -i "$bundle_id" 2>/dev/null || true)
  if [[ -z "$check_output" ]]; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Extension not registered (tolerant-missing): $bundle_id"
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Extension not registered: $bundle_id"
      return 4
    fi
  fi
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Extension registered. Proceeding to disable and remove."

  # Step 1: Disable (ignore) the extension
  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Disabling extension: $bundle_id"
  "$PLUGINKIT_BIN" -e ignore -i "$bundle_id" 2>/dev/null || true

  # Step 2: Remove registration
  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Removing registration: $bundle_id"
  "$PLUGINKIT_BIN" -r -i "$bundle_id" 2>/dev/null || true

  # Step 3: Verify-after (pluginkit -m -i should return empty)
  local verify_output
  verify_output=$("$PLUGINKIT_BIN" -m -i "$bundle_id" 2>/dev/null || true)
  if [[ -n "$verify_output" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Extension still registered after removal: $bundle_id"
    return 5
  fi

  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Extension successfully removed: $bundle_id"
  return 0
}
#--------------------------------------------------------------------------------

# @name RemoveQuickLookPlugin
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires SafeRemovePath, /usr/bin/qlmanage
#
# RemoveQuickLookPlugin — Remove a QuickLook generator plugin (.qlgenerator bundle) from disk.
#   Takes a filesystem path pointing to the .qlgenerator directory itself.
#   Uses SafeRemovePath for removal. The qlmanage -r reload is called by main()
#   AFTER all plugins are removed, not inside this function.
#
# Inputs (order-agnostic):
#   $*  <path_to_qlgenerator> [--tolerant-missing] [--needs-root]
#
# Returns:
#   0 = success (plugin removed, or absent with --tolerant-missing)
#   1 = generic failure (SafeRemovePath missing, internal error)
#   2 = bad input (missing arg, unknown flag, invalid path format, not .qlgenerator)
#   3 = needs root (--needs-root specified but EUID != 0)
#   4 = plugin not present on disk and NOT tolerant
#   5 = operation failed (SafeRemovePath reported failure, or verify-after shows file still exists)
#
# Safety notes:
#   - This function only removes the .qlgenerator directory from disk.
#   - Does NOT call qlmanage -r; that is called once in main() after all removals.
#   - Path must be absolute and end with .qlgenerator (case-sensitive).
#   - SafeRemovePath handles bottom-up removal of directory bundles.
function RemoveQuickLookPlugin {
  set -f
  local IFS=$' \t\n'

  # Aligned logging prefixes
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "RemoveQuickLookPlugin() - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # Order-agnostic argument parsing with duplicate detection
  local tolerant=false needs_root=false ql_path=""
  if (( $# == 0 || $# > 3 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected <path> [--tolerant-missing] [--needs-root]. Got $# args."
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
        if [[ -n "$ql_path" ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: multiple non-flag arguments."
          return 2
        fi
        ql_path="$arg" ;;
    esac
  done

  # Root gate (opt-in)
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: run as sudo/root."
    return 3
  fi

  # Tool presence check
  local SAFEREMOVE_BIN="SafeRemovePath"
  if ! type -t "$SAFEREMOVE_BIN" &>/dev/null; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required function: $SAFEREMOVE_BIN"
    return 1
  fi

  # Validate path is absolute
  if [[ ! "$ql_path" =~ ^/ ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid path: must be absolute. Got: $ql_path"
    return 2
  fi

  # Validate path ends with .qlgenerator (case-sensitive)
  if [[ ! "$ql_path" =~ \.qlgenerator$ ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid path: must end with .qlgenerator. Got: $ql_path"
    return 2
  fi

  # Presence check (path must exist on disk)
  if [[ ! -e "$ql_path" ]]; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Plugin not present on disk (tolerant-missing): $ql_path"
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Plugin not present on disk: $ql_path"
      return 4
    fi
  fi
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Plugin present. Proceeding to remove."

  # Step 1: Remove the plugin using SafeRemovePath
  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Removing plugin: $ql_path"
  local remove_rc=0
  "$SAFEREMOVE_BIN" "$ql_path" || remove_rc=$?
  if (( remove_rc != 0 )); then
    echo "${my_echo_prefix}${my_err_prefix}SafeRemovePath failed with rc $remove_rc for: $ql_path"
    return 5
  fi

  # Step 2: Verify-after (path should no longer exist)
  if [[ -e "$ql_path" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Plugin still exists after removal attempt: $ql_path"
    return 5
  fi

  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Plugin successfully removed: $ql_path"
  return 0
}
#--------------------------------------------------------------------------------

# @name RemovePrivilegedHelper
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires SafeDelete
#
# RemovePrivilegedHelper — Remove a PrivilegedHelperTool binary from /Library/PrivilegedHelperTools/.
#   Thin wrapper around SafeDelete with guards:
#   - Path must be under /Library/PrivilegedHelperTools/ (refuses to operate elsewhere)
#   - Filename must be valid reverse-DNS format (≥3 labels)
#   - The associated LaunchDaemon plist should be unloaded first via UnloadAndRemoveLaunchDaemon.
#
# Inputs (order-agnostic):
#   $*  <path> [--tolerant-missing] [--needs-root]
#
# Returns:
#   0 = success (helper removed, or absent with --tolerant-missing)
#   1 = generic failure (SafeDelete missing, internal error)
#   2 = bad input (missing arg, unknown flag, invalid path format, not under PrivilegedHelperTools, invalid filename)
#   3 = needs root (--needs-root specified but EUID != 0)
#   4 = helper not present and NOT tolerant
#   5 = operation failed (SafeDelete reported failure, or verify-after shows file still exists)
#
# Safety notes:
#   - This function only removes the helper binary from disk.
#   - Does NOT remove the associated LaunchDaemon plist; that should be done first via UnloadAndRemoveLaunchDaemon.
#   - Path must be absolute and under /Library/PrivilegedHelperTools/ (exact match, not similar names).
#   - Filename is validated to reverse-DNS format with ≥3 labels.
#   - SafeDelete handles non-recursive deletion of the single file.
function RemovePrivilegedHelper {
  set -f
  local IFS=$' \t\n'

  # Aligned logging prefixes
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "RemovePrivilegedHelper - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # Order-agnostic argument parsing with duplicate detection
  local tolerant=false needs_root=false helper_path=""
  if (( $# == 0 || $# > 3 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected <path> [--tolerant-missing] [--needs-root]. Got $# args."
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
        if [[ -n "$helper_path" ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: multiple non-flag arguments."
          return 2
        fi
        helper_path="$arg" ;;
    esac
  done

  # Root gate (opt-in)
  if $needs_root && [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: run as sudo/root."
    return 3
  fi

  # Tool presence check
  local SAFEDELETE_BIN="SafeDelete"
  if ! type -t "$SAFEDELETE_BIN" &>/dev/null; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required function: $SAFEDELETE_BIN"
    return 1
  fi

  # Validate path is absolute
  if [[ ! "$helper_path" =~ ^/ ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid path: must be absolute. Got: $helper_path"
    return 2
  fi

  # Validate path is under /Library/PrivilegedHelperTools/ (exact directory match)
  local helper_dir="/Library/PrivilegedHelperTools"
  if [[ ! "$helper_path" =~ ^${helper_dir}/ ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid path: must be under ${helper_dir}/. Got: $helper_path"
    return 2
  fi

  # Extract filename and validate reverse-DNS format (≥3 labels)
  local filename="${helper_path##*/}"
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
  if [[ ! "$filename" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid filename format (must be reverse-DNS with ≥3 labels): $filename"
    return 2
  fi

  # Presence check (path must exist on disk)
  if [[ ! -e "$helper_path" ]]; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Helper not present on disk (tolerant-missing): $helper_path"
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Helper not present on disk: $helper_path"
      return 4
    fi
  fi
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Helper present. Proceeding to remove."

  # Step 1: Remove the helper using SafeDelete
  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Removing helper: $helper_path"
  local remove_rc=0
  "$SAFEDELETE_BIN" "$helper_path" || remove_rc=$?
  if (( remove_rc != 0 )); then
    echo "${my_echo_prefix}${my_err_prefix}SafeDelete failed with rc $remove_rc for: $helper_path"
    return 5
  fi

  # Step 2: Verify-after (path should no longer exist)
  if [[ -e "$helper_path" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Helper still exists after removal attempt: $helper_path"
    return 5
  fi

  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Helper successfully removed: $helper_path"
  return 0
}
#--------------------------------------------------------------------------------

# @name IdentifyLoginItemType
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires /usr/bin/sfltool
#
# IdentifyLoginItemType — Detect the persistence mechanism underlying a login/background item.
#   This is a DETECTOR, not a remover. It queries sfltool dumpbtm to identify what type
#   of artifact (LaunchDaemon, LaunchAgent, PrivilegedHelperTool, or App) is registered
#   in the macOS Background Task Management database.
#
#   The caller uses this to route to the correct removal function based on TYPE.
#
# Inputs (order-agnostic):
#   $*  <identifier> [--tolerant-missing]
#
#   Where <identifier> is a reverse-DNS label (e.g., "corp.sap.privileges.helper").
#
# Returns:
#   0 = found in BTM database (outputs: TYPE=<type> PATH=<path> DISPOSITION=<flags>)
#   1 = generic failure (sfltool missing, parse error, unexpected output format)
#   2 = bad input (missing identifier, invalid format, unknown flag, duplicate flag)
#   3 = needs root (sfltool dumpbtm requires root)
#   4 = identifier not found in BTM database and NOT tolerant
#
# Output (stdout on rc 0):
#   TYPE=<daemon|agent|helper|app|login_item|unknown> PATH=<filesystem_path> DISPOSITION=<disposition_flags>
#
#   Examples:
#     TYPE=daemon PATH=/Library/LaunchDaemons/corp.sap.privileges.helper.plist DISPOSITION=enabled,allowed,visible,notified
#     TYPE=agent PATH=/Library/LaunchAgents/com.vendor.agent.plist DISPOSITION=enabled,allowed,visible
#     TYPE=unknown PATH= DISPOSITION=enabled,allowed
#
# Safety notes:
#   - Read-only query function — does NOT modify the BTM database.
#   - sfltool dumpbtm requires root. The function enforces EUID == 0.
#   - Output format of sfltool dumpbtm is undocumented and may change. Parser is defensive.
#   - URL field may be empty for orphaned entries. PATH= will be empty in that case.
#   - This function does NOT perform any removal. The caller routes based on TYPE.
function IdentifyLoginItemType {
  set -f
  local IFS=$' \t\n'

  # Aligned logging prefixes
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "IdentifyLoginItemType - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # Order-agnostic argument parsing with duplicate detection (parse first to catch duplicates before count validation)
  local tolerant=false identifier=""
  local arg_count=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --tolerant-missing)
        if [[ $tolerant == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: duplicate --tolerant-missing flag."
          return 2
        fi
        tolerant=true ;;
      -*)
        echo "${my_echo_prefix}${my_err_prefix}Bad input: unknown flag '$arg'."
        return 2 ;;
      *)
        # Count non-flag arguments
        ((arg_count++))
        if [[ -n "$identifier" ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: multiple non-flag arguments."
          return 2
        fi
        identifier="$arg" ;;
    esac
  done

  # Validate required argument after parsing (so duplicate flags are caught first)
  if [[ -z "$identifier" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: missing identifier argument."
    return 2
  fi
  if (( arg_count > 1 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected <identifier> [--tolerant-missing]."
    return 2
  fi

  # Validate identifier format (reverse-DNS with ≥2 labels for flexibility)
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*)+$'
  if [[ ! "$identifier" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid identifier format: $identifier"
    return 2
  fi

  # Root gate (mandatory - sfltool dumpbtm requires root)
  if [[ $( _get_effective_euid ) -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root: sfltool dumpbtm requires root."
    return 3
  fi

  # Tool presence check
  local SFLTOOL_BIN="/usr/bin/sfltool"
  if [[ ! -x "$SFLTOOL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $SFLTOOL_BIN"
    return 1
  fi

  # Dump BTM database and capture output to temp file
  local btm_dump
  btm_dump=$(mktemp /tmp/btm_dump.XXXXXX) || {
    echo "${my_echo_prefix}${my_err_prefix}Failed to create temp file for BTM dump."
    return 1
  }

  "$SFLTOOL_BIN" dumpbtm > "$btm_dump" 2>&1 || true

  # Parse the dump to find the matching identifier
  local found=0
  local current_type=""
  local current_disposition=""
  local current_url=""
  local in_entry=0
  local entry_identifier=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Detect start of a new entry (#N: pattern)
    if [[ "$line" =~ ^#[0-9]+: ]]; then
      # If we were processing an entry and haven't matched, reset for new entry
      if [[ $in_entry -eq 1 && -n "$entry_identifier" ]]; then
        # Check if previous entry matched
        if [[ "$entry_identifier" == "$identifier" ]]; then
          found=1
          break
        fi
      fi
      # Start new entry
      in_entry=1
      current_type=""
      current_disposition=""
      current_url=""
      entry_identifier=""
      continue
    fi

    # Parse fields within an entry
    if [[ $in_entry -eq 1 ]]; then
      # Type field: "  Type:            <type string> (<hex code>)"
      if [[ "$line" =~ ^[[:space:]]*Type:[[:space:]]*([^[:space:]]+)[[:space:]]*\( ]]; then
        current_type="${BASH_REMATCH[1]}"
      fi

      # Disposition field: "  Disposition:     <comma-separated flags>"
      if [[ "$line" =~ ^[[:space:]]*Disposition:[[:space:]]*(.+)$ ]]; then
        current_disposition="${BASH_REMATCH[1]}"
        # Trim trailing whitespace
        current_disposition="${current_disposition%"${current_disposition##*[![:space:]]}"}"
      fi

      # URL field: "  URL:             <file:///path/to/artifact>"
      if [[ "$line" =~ ^[[:space:]]*URL:[[:space:]]*file://(.+)$ ]]; then
        current_url="${BASH_REMATCH[1]}"
      fi

      # Identifier field: "  Identifier:      <reverse-dns identifier>"
      if [[ "$line" =~ ^[[:space:]]*Identifier:[[:space:]]*(.+)$ ]]; then
        entry_identifier="${BASH_REMATCH[1]}"
        # Trim trailing whitespace
        entry_identifier="${entry_identifier%"${entry_identifier##*[![:space:]]}"}"
      fi
    fi
  done < "$btm_dump"

  # Check the last entry if we haven't found yet
  if [[ $found -eq 0 && $in_entry -eq 1 && -n "$entry_identifier" ]]; then
    if [[ "$entry_identifier" == "$identifier" ]]; then
      found=1
    fi
  fi

  # Clean up temp file
  rm -f "$btm_dump"

  # Handle not found
  if [[ $found -eq 0 ]]; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Identifier not found in BTM database (tolerant-missing): $identifier"
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Identifier not found in BTM database: $identifier"
      return 4
    fi
  fi

  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Found BTM entry for: $identifier"

  # Classify type based on Type field and hex code
  local type_output="unknown"
  local path_output=""

  case "$current_type" in
    "legacy daemon")
      type_output="daemon"
      # Construct LaunchDaemon plist path
      path_output="/Library/LaunchDaemons/${identifier}.plist"
      ;;
    "legacy agent")
      type_output="agent"
      # Could be in /Library/LaunchAgents or ~/Library/LaunchAgents
      # Default to system location; caller can probe both
      path_output="/Library/LaunchAgents/${identifier}.plist"
      ;;
    "login item")
      type_output="login_item"
      # URL should contain the app path
      if [[ -n "$current_url" ]]; then
        path_output="$current_url"
      fi
      ;;
    "developer")
      type_output="helper"
      # SMAppService daemon/agent - URL may point to helper or plist
      if [[ -n "$current_url" ]]; then
        path_output="$current_url"
      fi
      ;;
    "app")
      type_output="app"
      # URL should contain the app bundle path
      if [[ -n "$current_url" ]]; then
        path_output="$current_url"
      fi
      ;;
    *)
      # Unrecognized type - output unknown
      type_output="unknown"
      # Try to extract path from URL if available
      if [[ -n "$current_url" ]]; then
        path_output="$current_url"
      fi
      ;;
  esac

  # Output the machine-parseable result
  echo "TYPE=${type_output} PATH=${path_output} DISPOSITION=${current_disposition}"

  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Identified login item: TYPE=${type_output} PATH=${path_output}"

  return 0
}
#--------------------------------------------------------------------------------

# @name ExpandTokenizedSlot
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
#
# ExpandTokenizedSlot — Parse a pipe-delimited tokenized slot and route entries
#   to the correct global arrays based on prefix tokens.
#
#   Each entry in the slot is either:
#     - Prefixed with a token (e.g., "$LibAgt/com.vendor.agent") — token is
#       stripped and the value is appended to the corresponding global array.
#     - Bare (no recognized prefix) — appended to the default array.
#
# Inputs:
#   $1  raw slot string (pipe-delimited, tokenized)
#   $2  default array name (for entries with no recognized prefix)
#
# Token reference:
#   $LibAgt/ → LAUNCH_AGENTS_TO_REMOVE    $UsrAgt/ → LAUNCH_AGENTS_TO_REMOVE
#   $LibDmn/ → LAUNCH_DAEMONS_TO_REMOVE   $SysDmn/ → LAUNCH_DAEMONS_TO_REMOVE
#   $FndExt/ → FINDER_EXTENSIONS_TO_REMOVE
#   $QLPlg/  → QUICKLOOK_PLUGINS_TO_REMOVE (bundle ID)
#   $QLPlg:  → QUICKLOOK_PLUGINS_TO_REMOVE (path)
#   $UsrCnt/ → CONTAINERS_TO_REMOVE
#   $Login/  → LOGIN_ITEMS_TO_REMOVE
#   $HlpBin: → PRIVILEGED_HELPERS_TO_REMOVE
#   $UsrRel: → PROFILE_REL_PATHS_TO_REMOVE
#
# Returns:
#   0 = success
#   2 = bad input (missing arguments)
#
# Side effects:
#   Appends to global config arrays based on token routing.
function ExpandTokenizedSlot {
  local raw_slot="${1:-}"       # pipe-delimited tokenized string
  local default_array="${2:-}"  # array name for bare (unprefixed) entries

  if [[ -z "$raw_slot" ]]; then
    return 0  # empty slot is fine — nothing to parse
  fi

  local -a entries=()
  IFS='|' read -ra entries <<< "$raw_slot"

  local entry value
  for entry in "${entries[@]}"; do
    case "$entry" in
      '$LibAgt/'*)
        value="${entry#\$LibAgt/}"
        LAUNCH_AGENTS_TO_REMOVE+=("$value") ;;
      '$UsrAgt/'*)
        value="${entry#\$UsrAgt/}"
        LAUNCH_AGENTS_TO_REMOVE+=("$value") ;;
      '$LibDmn/'*)
        value="${entry#\$LibDmn/}"
        LAUNCH_DAEMONS_TO_REMOVE+=("$value") ;;
      '$SysDmn/'*)
        value="${entry#\$SysDmn/}"
        LAUNCH_DAEMONS_TO_REMOVE+=("$value") ;;
      '$FndExt/'*)
        value="${entry#\$FndExt/}"
        FINDER_EXTENSIONS_TO_REMOVE+=("$value") ;;
      '$QLPlg/'*)
        value="${entry#\$QLPlg/}"
        QUICKLOOK_PLUGINS_TO_REMOVE+=("$value") ;;
      '$QLPlg:'*)
        value="${entry#\$QLPlg:}"
        QUICKLOOK_PLUGINS_TO_REMOVE+=("$value") ;;
      '$UsrCnt/'*)
        value="${entry#\$UsrCnt/}"
        CONTAINERS_TO_REMOVE+=("$value") ;;
      '$Login/'*)
        value="${entry#\$Login/}"
        LOGIN_ITEMS_TO_REMOVE+=("$value") ;;
      '$HlpBin:'*)
        value="${entry#\$HlpBin:}"
        PRIVILEGED_HELPERS_TO_REMOVE+=("$value") ;;
      '$UsrRel:'*)
        value="${entry#\$UsrRel:}"
        PROFILE_REL_PATHS_TO_REMOVE+=("$value") ;;
      *)
        # No recognized prefix — route to default array
        if [[ -n "$default_array" ]]; then
          eval "${default_array}+=(\"\$entry\")"
        fi
        [[ ${DEBUG:-false} == true ]] && echo "DEBUG: ExpandTokenizedSlot — bare entry '$entry' → $default_array" ;;
    esac
    [[ ${DEBUG:-false} == true ]] && echo "DEBUG: ExpandTokenizedSlot — '${entry}'"
  done

  return 0
}
#--------------------------------------------------------------------------------

# @name ParseInput
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires ParseManifestJSON
#
# ParseInput — Route input source and populate config arrays.
#   Priority chain (first source that provides data wins, no merging):
#     1. --manifest <path> → calls ParseManifestJSON (highest priority)
#     2. CLI flags (--app-name=, --paths=, --packages=, etc.)
#     3. Jamf mode ($4 == "jamf=true") → parses $5, $6, $7, etc.
#     4. Fallback to hardcoded arrays (no modification)
#
#   This function is called ONCE, BEFORE main(), at script invocation time.
#
# Inputs:
#   $@  All script arguments (flags and positional params)
#
#   CLI flag format:
#     --app-name="Name"
#     --paths="/path1|/path2"
#     --packages="com.pkg1|com.pkg2"
#     --agents="com.agent1"
#     --daemons="com.daemon1"
#     --finder-exts="com.extension1"
#     --quit="/path/to/app"
#     --profile-paths="Library/Caches/com.vendor"
#     --ql-plugins="/Library/QuickLook/plugin.qlgenerator"
#     --helpers="/Library/PrivilegedHelperTools/helper"
#     --login-items="com.loginitem1"
#
#   Jamf mode ($4 == "jamf=true"):
#     $1 = mountpoint (Jamf-provided, unused)
#     $2 = computername (Jamf-provided, unused)
#     $3 = username (Jamf-provided, unused)
#     $4 = "jamf=true" (triggers Jamf mode)
#     $5 = app_name (plain string)
#     $6 = paths (pipe-delimited absolute paths)
#     $7 = packages (pipe-delimited reverse-DNS)
#     $8 = launch items (prefix-tokenized: $LibAgt/, $LibDmn/, etc.)
#     $9 = apps to quit (pipe-delimited absolute paths)
#     ${10} = extras A (prefix-tokenized: $FndExt/, $QLPlg/, $QLPlg:)
#     ${11} = extras B (prefix-tokenized: $UsrCnt/, $Login/, $HlpBin:, $UsrRel:)
#
# Returns:
#   0 = success (arrays populated from whichever source)
#   1 = generic failure (manifest parse error, plutil missing)
#   2 = bad input (--manifest specified but path missing or not a file)
#
# Side effects:
#   Populates global config arrays (APP_NAME, PATHS_TO_REMOVE, PKGS_TO_REMOVE, etc.)
#   Sets JAMF_MODE=true when Jamf mode is detected
function ParseInput {
  set -f
  local IFS=$' \t\n'

  # --- Check for --manifest mode first (highest priority) ---
  local manifest_path=""
  local arg
  local i=1
  while (( i <= $# )); do
    arg="${!i}"
    case "$arg" in
      --manifest=*)
        manifest_path="${arg#--manifest=}"
        break ;;
      --manifest)
        # --manifest without = requires next arg to be the path
        if (( i < $# )); then
          ((i++))
          manifest_path="${!i}"
        else
          # --manifest specified but no path follows
          echo "ERROR: ParseInput --manifest requires a path argument" >&2
          return 2
        fi
        break ;;
    esac
    ((i++))
  done

  # --- Auto-detect: bare .json file as positional arg ---
  if [[ -z "$manifest_path" ]]; then
    for arg in "$@"; do
      if [[ "$arg" == *.json && -f "$arg" ]]; then
        manifest_path="$arg"
        break
      fi
    done
  fi

  if [[ -n "$manifest_path" ]]; then
    # Manifest specified — validate path exists
    if [[ ! -f "$manifest_path" ]]; then
      echo "ERROR: ParseInput --manifest path does not exist: $manifest_path" >&2
      return 2
    fi
    # Call ParseManifestJSON to populate arrays
    ParseManifestJSON "$manifest_path"
    return $?
  fi

  # --- Check for CLI flag mode (any --flag= present) ---
  local has_cli_flag=false
  for arg in "$@"; do
    if [[ "$arg" == --* ]]; then
      has_cli_flag=true
      break
    fi
  done

  if $has_cli_flag; then
    # CLI flag mode — parse all flags
    local app_name="" paths_str="" packages_str="" agents_str="" daemons_str=""
    local finder_exts_str="" quit_str="" profile_paths_str="" ql_plugins_str=""
    local helpers_str="" login_items_str=""

    for arg in "$@"; do
      case "$arg" in
        --app-name=*)
          app_name="${arg#--app-name=}" ;;
        --paths=*)
          paths_str="${arg#--paths=}" ;;
        --packages=*)
          packages_str="${arg#--packages=}" ;;
        --agents=*)
          agents_str="${arg#--agents=}" ;;
        --daemons=*)
          daemons_str="${arg#--daemons=}" ;;
        --finder-exts=*)
          finder_exts_str="${arg#--finder-exts=}" ;;
        --quit=*)
          quit_str="${arg#--quit=}" ;;
        --profile-paths=*)
          profile_paths_str="${arg#--profile-paths=}" ;;
        --ql-plugins=*)
          ql_plugins_str="${arg#--ql-plugins=}" ;;
        --helpers=*)
          helpers_str="${arg#--helpers=}" ;;
        --login-items=*)
          login_items_str="${arg#--login-items=}" ;;
      esac
    done

    # Populate arrays from CLI flags (only if non-empty)
    if [[ -n "$app_name" ]]; then
      APP_NAME="$app_name"
    fi
    if [[ -n "$paths_str" ]]; then
      IFS='|' read -ra PATHS_TO_REMOVE <<< "$paths_str"
    fi
    if [[ -n "$packages_str" ]]; then
      IFS='|' read -ra PKGS_TO_REMOVE <<< "$packages_str"
    fi
    if [[ -n "$agents_str" ]]; then
      IFS='|' read -ra LAUNCH_AGENTS_TO_REMOVE <<< "$agents_str"
    fi
    if [[ -n "$daemons_str" ]]; then
      IFS='|' read -ra LAUNCH_DAEMONS_TO_REMOVE <<< "$daemons_str"
    fi
    if [[ -n "$finder_exts_str" ]]; then
      IFS='|' read -ra FINDER_EXTENSIONS_TO_REMOVE <<< "$finder_exts_str"
    fi
    if [[ -n "$quit_str" ]]; then
      IFS='|' read -ra APPS_TO_QUIT <<< "$quit_str"
    fi
    if [[ -n "$profile_paths_str" ]]; then
      IFS='|' read -ra PROFILE_REL_PATHS_TO_REMOVE <<< "$profile_paths_str"
    fi
    if [[ -n "$ql_plugins_str" ]]; then
      IFS='|' read -ra QUICKLOOK_PLUGINS_TO_REMOVE <<< "$ql_plugins_str"
    fi
    if [[ -n "$helpers_str" ]]; then
      IFS='|' read -ra PRIVILEGED_HELPERS_TO_REMOVE <<< "$helpers_str"
    fi
    if [[ -n "$login_items_str" ]]; then
      IFS='|' read -ra LOGIN_ITEMS_TO_REMOVE <<< "$login_items_str"
    fi

    # Update ECHO_PREFIX if APP_NAME changed
    ECHO_PREFIX="uninstaller.sh - ${APP_NAME:+${APP_NAME} - }"

    return 0
  fi

  # --- Check for Jamf mode ($4 == "jamf=true") ---
  if [[ "${4:-}" == "jamf=true" ]]; then
    JAMF_MODE=true

    local jamf_app_name="${5:-}"   # $5 = app_name
    local jamf_paths="${6:-}"      # $6 = paths (pipe-delimited)
    local jamf_packages="${7:-}"   # $7 = packages (pipe-delimited)
    local jamf_launch="${8:-}"     # $8 = launch items (tokenized)
    local jamf_quit="${9:-}"       # $9 = apps to quit (pipe-delimited)
    local jamf_extras_a="${10:-}"  # ${10} = extras A (tokenized)
    local jamf_extras_b="${11:-}"  # ${11} = extras B (tokenized)

    # Simple slots — pipe-split into arrays
    if [[ -n "$jamf_app_name" ]]; then
      APP_NAME="$jamf_app_name"
    fi
    if [[ -n "$jamf_paths" ]]; then
      IFS='|' read -ra PATHS_TO_REMOVE <<< "$jamf_paths"
    fi
    if [[ -n "$jamf_packages" ]]; then
      IFS='|' read -ra PKGS_TO_REMOVE <<< "$jamf_packages"
    fi
    if [[ -n "$jamf_quit" ]]; then
      IFS='|' read -ra APPS_TO_QUIT <<< "$jamf_quit"
    fi

    # Tokenized slots — route via ExpandTokenizedSlot
    # $8: launch items — bare entries default to LAUNCH_AGENTS_TO_REMOVE
    ExpandTokenizedSlot "$jamf_launch" "LAUNCH_AGENTS_TO_REMOVE"
    # ${10}: extras A — bare entries default to FINDER_EXTENSIONS_TO_REMOVE
    ExpandTokenizedSlot "$jamf_extras_a" "FINDER_EXTENSIONS_TO_REMOVE"
    # ${11}: extras B — bare entries default to PROFILE_REL_PATHS_TO_REMOVE
    ExpandTokenizedSlot "$jamf_extras_b" "PROFILE_REL_PATHS_TO_REMOVE"

    # Update ECHO_PREFIX if APP_NAME changed
    ECHO_PREFIX="uninstaller.sh - ${APP_NAME:+${APP_NAME} - }"

    [[ ${DEBUG:-false} == true ]] && echo "DEBUG: ParseInput — Jamf mode detected, APP_NAME=$APP_NAME"
    return 0
  fi

  # --- No input source matched — error out ---
  echo "ERROR: No input provided. Usage:" >&2
  echo "  ./uninstaller.sh manifest.json" >&2
  echo "  ./uninstaller.sh --manifest=manifest.json" >&2
  echo "  ./uninstaller.sh --app-name=\"App\" --paths=\"/path\" ..." >&2
  echo "  (Jamf mode: \$4=jamf=true \$5=app_name \$6=paths ...)" >&2
  return 2
}
#--------------------------------------------------------------------------------

# @name RemoveLoginItems
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires IdentifyLoginItemType, UnloadAndRemoveLaunchDaemon, UnloadAndRemoveLaunchAgent, RemovePrivilegedHelper, SafeRemovePath
#
# RemoveLoginItems — Remove login/background items by auto-routing to the correct removal function.
#   This is a wrapper function that:
#   1. Calls IdentifyLoginItemType to detect the persistence mechanism type
#   2. Routes to the appropriate removal function based on TYPE
#
#   Routing table:
#     - daemon   → UnloadAndRemoveLaunchDaemon (constructs plist path)
#     - agent    → UnloadAndRemoveLaunchAgent (constructs plist path)
#     - helper   → RemovePrivilegedHelper (constructs helper binary path)
#     - app      → SafeRemovePath (uses URL path from BTM)
#     - login_item → SafeRemovePath (uses URL path from BTM)
#     - unknown  → warns and skips
#
# Inputs (order-agnostic):
#   $*  <identifier> [--tolerant-missing]
#
#   Where <identifier> is a reverse-DNS label (e.g., "corp.sap.privileges.helper").
#
# Returns:
#   0 = success (item removed, or absent with --tolerant-missing)
#   1 = generic failure (IdentifyLoginItemType failed, internal error)
#   2 = bad input (missing identifier, invalid format, unknown flag)
#   3 = needs root (IdentifyLoginItemType requires root)
#   4 = identifier not found in BTM database and NOT tolerant
#   5 = removal operation failed (type-specific removal failed)
#
# Safety notes:
#   - This function does NOT directly remove anything; it delegates to type-specific functions.
#   - For daemon/agent types, constructs the plist path from the identifier.
#   - For helper type, constructs the helper binary path under /Library/PrivilegedHelperTools/.
#   - For app/login_item types, uses the URL path from BTM output (may be empty for orphaned entries).
#   - Unknown types are logged as warnings and skipped (rc 5).
function RemoveLoginItems {
  set -f
  local IFS=$' \t\n'

  # Aligned logging prefixes
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "RemoveLoginItems()   - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # Order-agnostic argument parsing with duplicate detection (parse first to catch duplicates before count validation)
  local tolerant=false identifier=""
  local arg_count=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --tolerant-missing)
        if [[ $tolerant == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: duplicate --tolerant-missing flag."
          return 2
        fi
        tolerant=true ;;
      -*)
        echo "${my_echo_prefix}${my_err_prefix}Bad input: unknown flag '$arg'."
        return 2 ;;
      *)
        # Count non-flag arguments
        ((arg_count++))
        if [[ -n "$identifier" ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: multiple non-flag arguments."
          return 2
        fi
        identifier="$arg" ;;
    esac
  done

  # Validate required argument after parsing (so duplicate flags are caught first)
  if [[ -z "$identifier" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: missing identifier argument."
    return 2
  fi
  if (( arg_count > 1 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected <identifier> [--tolerant-missing]."
    return 2
  fi

  # Tool presence check
  local IDENTIFY_BIN="IdentifyLoginItemType"
  if ! type -t "$IDENTIFY_BIN" &>/dev/null; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required function: $IDENTIFY_BIN"
    return 1
  fi

  # Validate identifier format (reverse-DNS with ≥2 labels)
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*)+$'
  if [[ ! "$identifier" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid identifier format: $identifier"
    return 2
  fi

  # Step 1: Identify the login item type
  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Identifying login item: $identifier"
  local identify_output
  identify_output=$("$IDENTIFY_BIN" "$identifier" $($tolerant && echo "--tolerant-missing") 2>&1)
  local identify_rc=$?

  # Handle not found
  if [[ $identify_rc -eq 4 ]]; then
    if $tolerant; then
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Login item not found (tolerant-missing): $identifier"
      return 0
    else
      echo "${my_echo_prefix}${my_err_prefix}Login item not found: $identifier"
      return 4
    fi
  fi

  # Handle other errors from IdentifyLoginItemType
  if [[ $identify_rc -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}IdentifyLoginItemType failed with rc $identify_rc for: $identifier"
    return 1
  fi

  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Identify output: $identify_output"

  # Step 2: Parse TYPE= PATH= DISPOSITION= from output
  local type_output="" path_output="" disposition_output=""
  type_output=$(echo "$identify_output" | /usr/bin/grep -oP 'TYPE=\K[^ ]+' || echo "")
  path_output=$(echo "$identify_output" | /usr/bin/grep -oP 'PATH=\K[^ ]+' || echo "")
  disposition_output=$(echo "$identify_output" | /usr/bin/grep -oP 'DISPOSITION=\K.*' || echo "")

  if [[ -z "$type_output" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Failed to parse TYPE from IdentifyLoginItemType output: $identify_output"
    return 1
  fi

  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Parsed: TYPE=$type_output PATH=$path_output DISPOSITION=$disposition_output"

  # Step 3: Route to appropriate removal function based on type
  local removal_rc=0

  case "$type_output" in
    daemon)
      # Construct LaunchDaemon plist path
      local daemon_plist="/Library/LaunchDaemons/${identifier}.plist"
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Routing to UnloadAndRemoveLaunchDaemon: $daemon_plist"
      UnloadAndRemoveLaunchDaemon "$identifier" $($tolerant && echo "--tolerant-missing")
      removal_rc=$?
      ;;
    agent)
      # Construct LaunchAgent plist path
      local agent_plist="/Library/LaunchAgents/${identifier}.plist"
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Routing to UnloadAndRemoveLaunchAgent: $agent_plist"
      UnloadAndRemoveLaunchAgent "$identifier" $($tolerant && echo "--tolerant-missing")
      removal_rc=$?
      ;;
    helper)
      # Construct PrivilegedHelperTool binary path
      local helper_bin="/Library/PrivilegedHelperTools/${identifier}"
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Routing to RemovePrivilegedHelper: $helper_bin"
      RemovePrivilegedHelper "$helper_bin" $($tolerant && echo "--tolerant-missing")
      removal_rc=$?
      ;;
    app|login_item)
      # Use URL path from BTM output (may be empty for orphaned entries)
      if [[ -z "$path_output" ]]; then
        echo "${my_echo_prefix}${my_err_prefix}No path available for app/login_item type: $identifier"
        return 5
      fi
      [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
        echo "${my_echo_prefix}${my_vrb_prefix}Routing to SafeRemovePath: $path_output"
      SafeRemovePath "$path_output" $($tolerant && echo "--tolerant-missing")
      removal_rc=$?
      ;;
    unknown)
      echo "${my_echo_prefix}${my_err_prefix}Unknown login item type for: $identifier (DISPOSITION=$disposition_output)"
      return 5
      ;;
    *)
      echo "${my_echo_prefix}${my_err_prefix}Unrecognized type '$type_output' for: $identifier"
      return 5
      ;;
  esac

  # Step 4: Check removal result
  if [[ $removal_rc -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Removal failed for login item: $identifier (rc=$removal_rc)"
    return 5
  fi

  [[ ${VERBOSE:-false} == true || ${DEBUG:-false} == true ]] && \
    echo "${my_echo_prefix}${my_vrb_prefix}Login item successfully removed: $identifier"
  return 0
}
#--------------------------------------------------------------------------------

# @name ParseManifestJSON
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires /usr/bin/plutil
#
# ParseManifestJSON — Parse a JSON manifest file using plutil (no Python/jq).
#   Reads a JSON file and populates config arrays from its contents.
#
# JSON schema:
# {
#   "app_name": "Vendor App",
#   "apps_to_quit": ["/Applications/Vendor.app"],
#   "paths": ["/Applications/Vendor.app"],
#   "profile_rel_paths": ["Library/Caches/com.vendor"],
#   "packages": ["com.vendor.app"],
#   "launch_agents": ["com.vendor.app.agent"],
#   "launch_daemons": ["com.vendor.app.daemon"],
#   "finder_extensions": ["com.vendor.app.FinderSync"],
#   "quicklook_plugins": ["/Library/QuickLook/Vendor.qlgenerator"],
#   "privileged_helpers": ["/Library/PrivilegedHelperTools/com.vendor.helper"],
#   "login_items": ["com.vendor.loginitem"]
# }
#
# Inputs:
#   $1  path to JSON manifest file (REQUIRED)
#
# Returns:
#   0 = success (arrays populated)
#   1 = generic failure (plutil missing, parse error, file not readable)
#   2 = bad input (missing path, path not a file)
#
# Safety notes:
#   - Uses /usr/bin/plutil -convert json to parse JSON without Python/jq
#   - Arrays are completely replaced (not merged with existing values)
function ParseManifestJSON {
  set -f
  local IFS=$' \t\n'

  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "ParseManifestJSON - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"

  # --- Validate input ---
  if [[ $# -ne 1 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Bad input: expected exactly 1 argument (manifest path). Got $# args."
    return 2
  fi

  local manifest_path="$1"

  if [[ ! -f "$manifest_path" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Manifest file not found: $manifest_path"
    return 2
  fi

  # --- Tool presence ---
  local PLUTIL_BIN="/usr/bin/plutil"
  if [[ ! -x "$PLUTIL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool: $PLUTIL_BIN"
    return 1
  fi

  # --- Convert JSON to XML for plutil parsing ---
  local tmp_xml
  tmp_xml=$(mktemp /tmp/manifest_xml.XXXXXX) || {
    echo "${my_echo_prefix}${my_err_prefix}Failed to create temp file."
    return 1
  }

  # Convert JSON to XML format that plutil can read
  "$PLUTIL_BIN" -convert xml1 -o "$tmp_xml" "$manifest_path" 2>/dev/null
  local convert_rc=$?

  if [[ $convert_rc -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Failed to parse manifest JSON: $manifest_path"
    rm -f "$tmp_xml"
    return 1
  fi

  # --- Extract values using plutil ---
  local extract_value
  extract_value() {
    local key="$1"
    "$PLUTIL_BIN" -extract "$key" raw -o - "$tmp_xml" 2>/dev/null || echo ""
  }

  # Extract simple string values
  local json_app_name
  json_app_name=$(extract_value "app_name")
  if [[ -n "$json_app_name" ]]; then
    APP_NAME="$json_app_name"
  fi

  # --- Extract arrays ---
  # For arrays, we need to iterate through indices
  local -a tmp_array

  # apps_to_quit
  tmp_array=()
  local i=0
  while true; do
    local val
    val=$(extract_value "apps_to_quit.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    APPS_TO_QUIT=("${tmp_array[@]}")
  fi

  # paths
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "paths.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    PATHS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # profile_rel_paths
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "profile_rel_paths.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    PROFILE_REL_PATHS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # packages
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "packages.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    PKGS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # launch_agents
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "launch_agents.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    LAUNCH_AGENTS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # launch_daemons
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "launch_daemons.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    LAUNCH_DAEMONS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # finder_extensions
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "finder_extensions.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    FINDER_EXTENSIONS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # quicklook_plugins
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "quicklook_plugins.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    QUICKLOOK_PLUGINS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # privileged_helpers
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "privileged_helpers.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    PRIVILEGED_HELPERS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # login_items
  tmp_array=()
  i=0
  while true; do
    local val
    val=$(extract_value "login_items.$i")
    if [[ -z "$val" ]]; then
      break
    fi
    tmp_array+=("$val")
    ((i++))
  done
  if (( ${#tmp_array[@]} > 0 )); then
    LOGIN_ITEMS_TO_REMOVE=("${tmp_array[@]}")
  fi

  # Clean up
  rm -f "$tmp_xml"

  # Update ECHO_PREFIX if APP_NAME changed
  ECHO_PREFIX="uninstaller.sh - ${APP_NAME:+${APP_NAME} - }"

  [[ ${DEBUG:-false} == true ]] && echo "${my_echo_prefix}${my_dbg_prefix}Manifest parsed successfully: $manifest_path"
  return 0
}
#--------------------------------------------------------------------------------

# ──────────────────────────────────────────────────────────────────────────────
# Run
# ──────────────────────────────────────────────────────────────────────────────
ParseInput "$@" || exit $?
main "$@"
