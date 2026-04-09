# Universal Uninstaller - Implementation Plan

## Overview
This document outlines the implementation plan for adding new functions to the macOS universal uninstaller engine. The uninstaller removes applications and their persistence artifacts (LaunchAgents, LaunchDaemons, Finder extensions, QuickLook plugins, PrivilegedHelperTools, package receipts, and scattered files).

## Project Constraints
- **Language**: Bash only (no Python, jq, or Homebrew tools on endpoints)
- **Binaries**: Apple-shipped only (`/bin`, `/usr/bin`, `/usr/sbin`, `/libexec`)
- **Coding Standards**: Follow `docs/BASH_CODING_STANDARDS.md` strictly
- **Testing**: shellcheck + ShellSpec for all functions
- **Architecture**: Four-section layout (Config → main() → Functions → main "$@")

---

## Implementation Tasks

### Task 1: Implement RemoveFinderExtension ✅ IN PROGRESS
**Purpose**: Disable and unregister a Finder Sync extension by bundle identifier using `pluginkit`.

**Interface**:
```bash
RemoveFinderExtension <bundle_id> [--tolerant-missing] [--needs-root]
```

**Dependencies**: `/usr/bin/pluginkit`

**Reference Documents**:
- **Function Spec**: `docs/FUNCTION_SPECS.md` — Section 1 (RemoveFinderExtension)
- **Coding Standards**: `docs/BASH_CODING_STANDARDS.md` — Sections 1-5 (Naming, Script Structure, Function Anatomy, Return Codes, Function Header)
- **Spec File**: `spec/remove_finder_extension_spec.sh` (created)
- **Project Rules**: `.clinerules` — Function anatomy, naming conventions, return codes

**Implementation Steps**:
- [x] Design: Define function anatomy (set -f, IFS, logging prefixes, arg parsing)
- [x] Design: Define validation regex for bundle_id (reverse-DNS ≥3 labels)
- [x] Design: Define verify-after logic (pluginkit -m returns empty)
- [x] Implementation: Write function to `src/uninstaller.sh` (section #3)
- [x] Implementation: Add function header comment block with metadata
- [x] Implementation: Ensure all variables quoted, no nested functions
- [x] Testing: Create `spec/remove_finder_extension_spec.sh`
- [ ] Testing: Happy path test (rc 0) — *Skipped, requires pluginkit mocking*
- [x] Testing: Bad input tests (rc 2 - missing args, unknown flag, invalid format)
- [x] Testing: Tolerant-missing test (rc 0)
- [x] Testing: Strict-missing test (rc 4)
- [ ] Testing: Verify-after failure test (rc 5) — *Skipped, requires pluginkit mocking*
- [x] Verification: Run `shellcheck -s bash` - zero warnings (no new warnings introduced)
- [ ] Verification: Run `shellspec spec/remove_finder_extension_spec.sh` - all pass — *Pending shellspec installation*

---

### Task 2: Implement RemoveQuickLookPlugin
**Purpose**: Remove a QuickLook generator plugin (`.qlgenerator` bundle) from disk.

**Interface**:
```bash
RemoveQuickLookPlugin <path_to_qlgenerator> [--tolerant-missing] [--needs-root]
```

**Dependencies**: `SafeRemovePath`, `/usr/bin/chflags` (optional, root-only)

**Reference Documents**:
- **Function Spec**: `docs/FUNCTION_SPECS.md` — Section 2 (RemoveQuickLookPlugin)
- **Coding Standards**: `docs/BASH_CODING_STANDARDS.md` — Sections 1-5 (Naming, Script Structure, Function Anatomy, Return Codes, Function Header)
- **Spec File**: `spec/remove_quicklook_plugin_spec.sh` (to be created)
- **Project Rules**: `.clinerules` — `qlmanage -r` called in main() AFTER loop, NOT inside function

**Important**: `qlmanage -r` is called ONCE in `main()` after the removal loop, NOT inside this function.

**Implementation Steps**:
- [ ] Design: Define path validation (absolute path, ends in `.qlgenerator`)
- [ ] Design: Define existence check (including broken symlinks)
- [ ] Design: Define verify-after logic (path no longer exists on disk)
- [ ] Implementation: Write function to `src/uninstaller.sh` (section #3)
- [ ] Implementation: Add function header comment block with metadata
- [ ] Implementation: Delegate to `SafeRemovePath` for actual deletion
- [ ] Testing: Create `spec/remove_quicklook_plugin_spec.sh`
- [ ] Testing: Happy path test (rc 0)
- [ ] Testing: Bad input tests (rc 2 - missing args, unknown flag, invalid path format)
- [ ] Testing: Tolerant-missing test (rc 0)
- [ ] Testing: Strict-missing test (rc 4)
- [ ] Testing: Verify-after failure test (rc 5)
- [ ] Verification: Run `shellcheck -s bash` - zero warnings
- [ ] Verification: Run `shellspec spec/remove_quicklook_plugin_spec.sh` - all pass

---

### Task 3: Implement RemovePrivilegedHelper
**Purpose**: Remove a PrivilegedHelperTool binary from `/Library/PrivilegedHelperTools/`.

**Interface**:
```bash
RemovePrivilegedHelper <path> [--tolerant-missing] [--needs-root]
```

**Dependencies**: `SafeDelete`, `/usr/bin/chflags` (optional, root-only)

**Reference Documents**:
- **Function Spec**: `docs/FUNCTION_SPECS.md` — Section 4 (RemovePrivilegedHelper)
- **Coding Standards**: `docs/BASH_CODING_STANDARDS.md` — Sections 1-5 (Naming, Script Structure, Function Anatomy, Return Codes, Function Header)
- **Spec File**: `spec/remove_privileged_helper_spec.sh` (to be created)
- **Project Rules**: `.clinerules` — Path must be under `/Library/PrivilegedHelperTools/`

**Implementation Steps**:
- [ ] Design: Define path validation (absolute, under `/Library/PrivilegedHelperTools/`)
- [ ] Design: Define filename validation (reverse-DNS label)
- [ ] Design: Define verify-after logic (path no longer exists on disk)
- [ ] Implementation: Write function to `src/uninstaller.sh` (section #3)
- [ ] Implementation: Add function header comment block with metadata
- [ ] Implementation: Delegate to `SafeDelete` for actual deletion
- [ ] Testing: Create `spec/remove_privileged_helper_spec.sh`
- [ ] Testing: Happy path test (rc 0)
- [ ] Testing: Bad input tests (rc 2 - missing args, unknown flag, path not under correct dir)
- [ ] Testing: Tolerant-missing test (rc 0)
- [ ] Testing: Strict-missing test (rc 4)
- [ ] Testing: Verify-after failure test (rc 5)
- [ ] Verification: Run `shellcheck -s bash` - zero warnings
- [ ] Verification: Run `shellspec spec/remove_privileged_helper_spec.sh` - all pass

---

### Task 4: Implement IdentifyLoginItemType
**Purpose**: DETECTOR only - Detect what kind of persistence mechanism underlies a login/background item in the BTM database. Returns machine-parseable output for routing.

**Interface**:
```bash
IdentifyLoginItemType <identifier> [--tolerant-missing]
```

**Output Format**:
```
TYPE=<daemon|agent|helper|app|login_item|unknown> PATH=<filesystem_path> DISPOSITION=<flags>
```

**Dependencies**: `/usr/bin/sfltool`

**Reference Documents**:
- **Function Spec**: `docs/FUNCTION_SPECS.md` — Section 3 (IdentifyLoginItemType)
- **Coding Standards**: `docs/BASH_CODING_STANDARDS.md` — Sections 1-5 (Naming, Script Structure, Function Anatomy, Return Codes, Function Header)
- **Spec File**: `spec/identify_login_item_type_spec.sh` (to be created/updated)
- **Project Rules**: `.clinerules` — This is a DETECTOR, not a remover; sfltool output format varies by macOS version; parser MUST be defensive

**Implementation Steps**:
- [ ] Design: Define identifier validation (reverse-DNS ≥3 labels)
- [ ] Design: Define mandatory root gate (sfltool requires root)
- [ ] Design: Define sfltool output parsing (defensive - format varies by macOS version)
- [ ] Design: Define type mapping (legacy daemon→daemon, legacy agent→agent, etc.)
- [ ] Design: Define URL field parsing (strip `file://` prefix)
- [ ] Implementation: Write function to `src/uninstaller.sh` (section #3)
- [ ] Implementation: Add function header comment block with metadata
- [ ] Implementation: Use tmpfile capture pattern for sfltool output
- [ ] Testing: Create `spec/identify_login_item_type_spec.sh`
- [ ] Testing: Happy path - daemon type detected (rc 0)
- [ ] Testing: Happy path - agent type detected (rc 0)
- [ ] Testing: Happy path - app type detected (rc 0)
- [ ] Testing: Bad input tests (rc 2 - missing args, unknown flag, invalid format)
- [ ] Testing: Tolerant-missing test (rc 0, TYPE=unknown)
- [ ] Testing: Strict-missing test (rc 4)
- [ ] Testing: Parse error test (rc 1 - malformed sfltool output)
- [ ] Verification: Run `shellcheck -s bash` - zero warnings
- [ ] Verification: Run `shellspec spec/identify_login_item_type_spec.sh` - all pass

---

### Task 5: Implement ParseInput
**Purpose**: Populate global config arrays from external input sources (manifest, CLI flags, Jamf params, or hardcoded arrays).

**Interface**:
```bash
ParseInput "$@"
```

**Priority Chain** (first source that provides data for an array wins, no merging):
1. `--manifest <path>` (highest priority)
2. CLI `--flags` (any `--paths=`, `--packages=`, etc.)
3. Jamf `$5`–`$11` (when `$4 == "jamf=true"`)
4. Hardcoded arrays (fallback)

**Dependencies**: `ParseManifestJSON`, `/usr/bin/plutil`

**Reference Documents**:
- **Function Spec**: `docs/FUNCTION_SPECS.md` — Section 5 (ParseInput)
- **Coding Standards**: `docs/BASH_CODING_STANDARDS.md` — Sections 1-5 (Naming, Script Structure, Function Anatomy, Return Codes, Function Header)
- **Spec File**: `spec/parse_input_spec.sh` (to be created/updated)
- **Project Rules**: `.clinerules` — Lives in section #3 but CALLED in section #4 before main; three-mode priority chain; pipe delimiter for CLI/Jamf

**Implementation Steps**:
- [ ] Design: Define mode detection logic (manifest → CLI → Jamf → hardcoded)
- [ ] Design: Define CLI flag parsing (pipe-delimited values)
- [ ] Design: Define Jamf param parsing (`$4 == "jamf=true"` exact match)
- [ ] Implementation: Write function to `src/uninstaller.sh` (section #3)
- [ ] Implementation: Add function header comment block with metadata
- [ ] Implementation: Call `ParseManifestJSON` when manifest mode active
- [ ] Testing: Create `spec/parse_input_spec.sh`
- [ ] Testing: Happy path - manifest mode (rc 0)
- [ ] Testing: Happy path - CLI flags mode (rc 0)
- [ ] Testing: Happy path - Jamf mode (rc 0)
- [ ] Testing: Happy path - hardcoded fallback (rc 0)
- [ ] Testing: Bad input - manifest path doesn't exist (rc 2)
- [ ] Testing: Bad input - invalid JSON (rc 1)
- [ ] Testing: Bad input - plutil missing (rc 1)
- [ ] Verification: Run `shellcheck -s bash` - zero warnings
- [ ] Verification: Run `shellspec spec/parse_input_spec.sh` - all pass

---

### Task 6: Implement ParseManifestJSON
**Purpose**: Parse JSON manifest file using `/usr/bin/plutil` and populate global arrays.

**Interface**:
```bash
ParseManifestJSON <manifest_path>
```

**JSON Schema**:
```json
{
  "app_name": "Vendor App",
  "apps_to_quit": ["/Applications/Vendor.app"],
  "paths": ["/Applications/Vendor.app"],
  "profile_rel_paths": ["Library/Caches/com.vendor"],
  "packages": ["com.vendor.app"],
  "launch_agents": ["com.vendor.app.agent"],
  "launch_daemons": ["com.vendor.app.daemon"],
  "finder_extensions": ["com.vendor.app.FinderSync"],
  "quicklook_plugins": ["/Library/QuickLook/Vendor.qlgenerator"],
  "privileged_helpers": ["/Library/PrivilegedHelperTools/com.vendor.helper"],
  "login_items": ["com.vendor.loginitem"]
}
```

**Dependencies**: `/usr/bin/plutil`

**Reference Documents**:
- **Function Spec**: `docs/FUNCTION_SPECS.md` — Section 5 (ParseInput → ParseManifestJSON)
- **Coding Standards**: `docs/BASH_CODING_STANDARDS.md` — Sections 1-5 (Naming, Script Structure, Function Anatomy, Return Codes, Function Header)
- **Spec File**: `spec/parse_manifest_json_spec.sh` (to be created)
- **Project Rules**: `.clinerules` — Uses `/usr/bin/plutil` only, no Python on endpoints

**Implementation Steps**:
- [ ] Design: Define path validation (exists, is file)
- [ ] Design: Define plutil invocation (convert JSON to extractable format)
- [ ] Design: Define array population logic for each field
- [ ] Implementation: Write function to `src/uninstaller.sh` (section #3)
- [ ] Implementation: Add function header comment block with metadata
- [ ] Testing: Create `spec/parse_manifest_json_spec.sh`
- [ ] Testing: Happy path - valid manifest parsed (rc 0)
- [ ] Testing: Bad input - path doesn't exist (rc 2)
- [ ] Testing: Bad input - invalid JSON (rc 1)
- [ ] Testing: Bad input - plutil missing (rc 1)
- [ ] Verification: Run `shellcheck -s bash` - zero warnings
- [ ] Verification: Run `shellspec spec/parse_manifest_json_spec.sh` - all pass

---

### Task 7: Implement RemoveLoginItems
**Purpose**: Wrapper function that removes login items by identifier, automatically detecting and routing to appropriate handlers.

**Interface**:
```bash
RemoveLoginItems <identifier> [--tolerant-missing] [--needs-root]
```

**Routing Logic**:
| TYPE | Action |
|------|--------|
| `daemon` | Call `UnloadAndRemoveLaunchDaemon "$label"` |
| `agent` | Call `UnloadAndRemoveLaunchAgent "$label"` |
| `helper` | Call `RemovePrivilegedHelper "$path"` |
| `app` / `login_item` | Call `QuitAppByPath "$path"` then `SafeRemovePath "$path"` |
| `unknown` | Warn, attempt `SafeRemovePath "$path"` if available, return 5 |

**Dependencies**: `IdentifyLoginItemType`, `UnloadAndRemoveLaunchDaemon`, `UnloadAndRemoveLaunchAgent`, `RemovePrivilegedHelper`, `QuitAppByPath`, `SafeRemovePath`

**Reference Documents**:
- **Function Spec**: `docs/FUNCTION_SPECS.md` — Section 3 (IdentifyLoginItemType → How main() uses this)
- **Coding Standards**: `docs/BASH_CODING_STANDARDS.md` — Sections 1-5 (Naming, Script Structure, Function Anatomy, Return Codes, Function Header)
- **Spec File**: `spec/remove_login_items_spec.sh` (to be created)
- **Project Rules**: `.clinerules` — Wrapper delegates to other functions; does NOT implement removal natively; granularity is key

**Implementation Steps**:
- [ ] Design: Define identifier validation (reverse-DNS ≥3 labels)
- [ ] Design: Define mandatory root gate
- [ ] Design: Define output parsing from `IdentifyLoginItemType`
- [ ] Design: Define routing switch/case structure
- [ ] Design: Define return code aggregation from called functions
- [ ] Implementation: Write function to `src/uninstaller.sh` (section #3)
- [ ] Implementation: Add function header comment block with metadata
- [ ] Testing: Create `spec/remove_login_items_spec.sh`
- [ ] Testing: Happy path - daemon type removed (rc 0)
- [ ] Testing: Happy path - agent type removed (rc 0)
- [ ] Testing: Happy path - app type removed (rc 0)
- [ ] Testing: Happy path - helper type removed (rc 0)
- [ ] Testing: Bad input tests (rc 2 - missing args, unknown flag, invalid format)
- [ ] Testing: Tolerant-missing test (rc 0)
- [ ] Testing: Strict-missing test (rc 4)
- [ ] Testing: Unknown type test (rc 5)
- [ ] Verification: Run `shellcheck -s bash` - zero warnings
- [ ] Verification: Run `shellspec spec/remove_login_items_spec.sh` - all pass

---

### Task 8: Update main() with New Iteration Blocks
**Purpose**: Add removal loops for the new config arrays.

**Implementation Steps**:
- [ ] Design: Define Finder extension loop structure
- [ ] Design: Define QuickLook plugin loop structure (with single `qlmanage -r` after loop)
- [ ] Design: Define Privileged helper loop structure
- [ ] Design: Define Login item loop structure
- [ ] Design: Define new counter variables (finder_success/fail, ql_success/fail, helper_success/fail, login_success/fail)
- [ ] Implementation: Add loops to `src/uninstaller.sh` (section #2, inside main)
- [ ] Implementation: Update summary block with new counters
- [ ] Implementation: Update exit condition to include new failure counters
- [ ] Verification: Run `shellcheck -s bash` - zero warnings

---

### Task 9: Add New Config Arrays
**Purpose**: Add new target arrays to the config section.

**Implementation Steps**:
- [ ] Implementation: Add `FINDER_EXTENSIONS_TO_REMOVE=()` to section #1
- [ ] Implementation: Add `QUICKLOOK_PLUGINS_TO_REMOVE=()` to section #1
- [ ] Implementation: Add `PRIVILEGED_HELPERS_TO_REMOVE=()` to section #1
- [ ] Implementation: Add `LOGIN_ITEMS_TO_REMOVE=()` to section #1
- [ ] Verification: Arrays properly formatted, commented

---

### Task 10: Update Script Invocation
**Purpose**: Call `ParseInput` before `main` in section #4.

**Implementation Steps**:
- [ ] Implementation: Change end of script from:
  ```bash
  main "$@"
  ```
  To:
  ```bash
  ParseInput "$@"
  main "$@"
  ```
- [ ] Verification: Script still executes correctly

---

### Task 11: Create Spec Files for All New Functions
**Purpose**: Ensure all functions have corresponding test files.

**Files to Create**:
- [ ] `spec/remove_finder_extension_spec.sh`
- [ ] `spec/remove_quicklook_plugin_spec.sh`
- [ ] `spec/remove_privileged_helper_spec.sh`
- [ ] `spec/identify_login_item_type_spec.sh` (already exists, may need updates)
- [ ] `spec/parse_input_spec.sh` (already exists, may need updates)
- [ ] `spec/parse_manifest_json_spec.sh`
- [ ] `spec/remove_login_items_spec.sh`

**Per File Checklist**:
- [ ] Follow spec_helper.sh pattern for sourcing uninstaller
- [ ] Define Describe block with function name
- [ ] Implement 7+ test cases per function
- [ ] Verify all tests pass with `shellspec`

---

### Task 12: Run shellcheck on All Scripts
**Purpose**: Ensure all scripts pass shellcheck with zero warnings.

**Implementation Steps**:
- [ ] Run `shellcheck -s bash src/uninstaller.sh`
- [ ] Fix any warnings in new functions
- [ ] Run `shellcheck -s bash spec/*.sh`
- [ ] Fix any warnings in spec files
- [ ] Use inline `# shellcheck disable=SCXXXX` only when necessary with comment

---

### Task 13: Run shellspec Tests
**Purpose**: Ensure all new tests pass.

**Implementation Steps**:
- [ ] Run `shellspec` from project root
- [ ] Fix any failing tests
- [ ] Verify 100% pass rate
- [ ] Document any mocks/stubs used

---

## Execution Strategy

This plan is designed to be executed in **13 separate work sessions**, one per task. Each session should:

1. Read this document to understand the task scope
2. Implement the function(s) or changes
3. Write corresponding tests
4. Run shellcheck and shellspec
5. Confirm all checks pass before moving to next task

### Recommended Order
1. Tasks 1-3: Simple removal functions (independent)
2. Task 4: IdentifyLoginItemType (detector, needed by Task 7)
3. Task 6: ParseManifestJSON (needed by Task 5)
4. Task 5: ParseInput (depends on Task 6)
5. Task 7: RemoveLoginItems (depends on Task 4)
6. Tasks 8-10: Update main() and config (depends on all functions)
7. Task 11: Create remaining spec files
8. Tasks 12-13: Final verification

---

## Reference Documents
- `.clinerules` - Cline coding rules for this project
- `docs/BASH_CODING_STANDARDS.md` - Full Bash coding standards
- `docs/FUNCTION_SPECS.md` - Function interface specifications
- `src/uninstaller.sh` - Main uninstaller script
- `spec/spec_helper.sh` - ShellSpec test helper

---

## Return Code Scheme (Standard Across All Functions)

| Code | Meaning |
|------|---------|
| 0 | Success (action completed, or target absent with `--tolerant-missing`) |
| 1 | Generic failure (missing tool, internal error, unexpected state) |
| 2 | Bad input (wrong arg count, unknown flag, invalid format, duplicate flag) |
| 3 | Needs root (EUID ≠ 0 when root is required) |
| 4 | Target not present and NOT tolerant |
| 5 | Operation failed (action attempted but verify-after shows it didn't take) |

---

## Function Anatomy (Required for All Functions)

```bash
# @name FunctionName
# @version 1.0.0
# @approved true
# @channels stable,beta
# @branch core
# @requires Dependencies, /path/to/tool
#
# FunctionName — One-line summary.
#   Additional context.
#
# Inputs (order-agnostic):
#   $*  <required_arg> [--tolerant-missing] [--needs-root]
#
# Returns:
#   0 = success (description)
#   1–5 per standard scheme
#
# Safety notes:
#   - What this function does NOT do
#   - Validation approach
function FunctionName {
  set -f
  local IFS=$' \t\n'
  
  # Aligned logging prefixes
  local fnw="${LOG_FN_WIDTH:-24}" lvw="${LOG_LVL_WIDTH:-10}"
  local my_echo_prefix="${ECHO_PREFIX:-}$(printf "%-*s" "$fnw" "FunctionName()  - ")"
  local my_vrb_prefix="$(printf "%-*s" "$lvw" "INFO:")"
  local my_err_prefix="$(printf "%-*s" "$lvw" "ERROR:")"
  local my_dbg_prefix="$(printf "%-*s" "$lvw" "DEBUG:")"
  
  # Order-agnostic argument parsing
  local tolerant=false
  local needs_root=false
  local label=""
  if (( $# == 0 || $# > 3 )); then
    echo "${my_echo_prefix}${my_err_prefix}Bad input..."
    return 2
  fi
  local arg
  for arg in "$@"; do
    case "$arg" in
      --tolerant-missing)
        if [[ $tolerant == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: duplicate flag."
          return 2
        fi
        tolerant=true ;;
      --needs-root)
        if [[ $needs_root == true ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: duplicate flag."
          return 2
        fi
        needs_root=true ;;
      -*)
        echo "${my_echo_prefix}${my_err_prefix}Bad input: unknown flag."
        return 2 ;;
      *)
        if [[ -n "$label" ]]; then
          echo "${my_echo_prefix}${my_err_prefix}Bad input: multiple non-flag args."
          return 2
        fi
        label="$arg" ;;
    esac
  done
  
  # Root gate (opt-in or mandatory)
  if $needs_root && [[ $EUID -ne 0 ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Needs root."
    return 3
  fi
  
  # Tool presence check
  local TOOL_BIN="/full/path/to/tool"
  if [[ ! -x "$TOOL_BIN" ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Missing required tool."
    return 1
  fi
  
  # Input validation
  local id_re='^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$'
  if [[ ! "$label" =~ $id_re ]]; then
    echo "${my_echo_prefix}${my_err_prefix}Invalid format."
    return 2
  fi
  
  # Action → Verify pattern
  # ... perform action ...
  # ... verify action took effect ...
  
  # Return appropriate code
}
```

---

## Notes for Implementation

1. **Granularity is key** - Each function does one thing well and delegates to other functions for complex operations.

2. **Never trust exit codes** - For `launchctl` and similar commands, parse stdout/stderr text instead of relying on exit codes.

3. **Use tmpfile capture pattern** - For commands that may have unreliable exit codes, capture to tmpfiles with `mktemp`, cat back, then rm.

4. **All variables quoted** - `"$var"` never `$var`.

5. **No nested functions** - Every function is a top-level peer in section #3.

6. **Full absolute paths** - All external binaries use full paths like `/bin/launchctl`, not just `launchctl`.

7. **Verify-after is mandatory** - Every destructive action must be followed by verification that it took effect.

8. **Tolerant-missing converts rc 4 to rc 0** - This is the standard mechanism for making absence non-fatal in uninstall flows.