# ShellSpec Test Fixes Plan

This document outlines the fixes needed to achieve 100% pass rate for the ShellSpec unit tests in the mac-muck project.

## Current Status

- **Total Tests:** 390 examples
- **Failures:** 14
- **Warnings:** 6
- **Skips:** 213

**Progress:** Categories 2 and 4 are complete. Remaining issues are in flag position tests and input validation edge cases.

## Failure Analysis

The failures fall into **3 distinct categories**:

- **Category 1**: Root gate interfering with input validation (✅ COMPLETE - functions already have correct order)
- **Category 2**: Duplicate flag detection order (✅ COMPLETE)
- **Category 3**: Flag position tests and launchctl interactions (14 failures + 6 warnings remaining)
- **Category 4**: ParseInput manifest mode (✅ COMPLETE - but warnings remain)

---

## Category 1: Root Gate Interfering with Input Validation ✅ COMPLETE

### Previously Affected Functions
- `ForgetPackage`
- `DisableLaunchDaemon`
- `IdentifyLoginItemType`
- `UnloadAndRemoveLaunchDaemon`

### Status
**COMPLETE** - All four functions already have input validation before root check:
- `ForgetPackage` - validation at lines 405-427, root gate at line 430
- `DisableLaunchDaemon` - validation at lines 1827-1832, root gate at line 1835
- `IdentifyLoginItemType` - validation at lines 2811-2816, root gate at line 2819
- `UnloadAndRemoveLaunchDaemon` - validation at lines 2228-2233, root gate at line 2257

---

## Category 2: Duplicate Flag Detection Order ✅ COMPLETE

### Previously Affected Functions
- `ForgetPackage` (1 failure)
- `RemoveLoginItems` (2 failures)
- `RemovePathForUsers` (1 failure)
- `SafeDelete` (2 failures)
- `SafeRemovePath` (1 failure)
- `UnlinkSymlink` (1 failure)

### Fix Applied
The duplicate flag detection was moved to occur before the unknown flag catch-all. The `-*` case was moved to the **end** of the case statement, after all known flags are checked explicitly.

### Status
**COMPLETE** - All 8 tests now passing.

---

## Category 3: Flag Position Tests and Launchctl Interactions (14 failures + 6 warnings)

### Current Failures

| # | Spec File | Test Description | Issue |
|---|-----------|------------------|-------|
| 2 | disable_launch_agent_spec.sh:70 | returns 0 when agent is absent and --tolerant-missing | Returns 5 (verify failure) instead of 0 |
| 13 | disable_launch_agent_spec.sh:135 | accepts flags before the label | Returns 5 instead of 0 |
| 14 | disable_launch_agent_spec.sh:140 | accepts flags after the label | Returns 5 instead of 0 |
| 15 | disable_launch_agent_spec.sh:145 | accepts --needs-root flag before the label | Returns 5 instead of 0 |
| 26 | disable_launch_daemon_spec.sh:113 | accepts flags before the label | Needs investigation |
| 27 | disable_launch_daemon_spec.sh:118 | accepts flags after the label | Needs investigation |
| 44 | forget_package_spec.sh:134 | accepts flags before the package id | Needs investigation |
| 45 | forget_package_spec.sh:139 | accepts flags after the package id | Needs investigation |
| 89 | quit_app_by_path_spec.sh:44 | returns 4 when bundle path does not exist | Needs investigation |
| 90 | quit_app_by_path_spec.sh:55 | returns 1 when path is not a valid .app bundle | Needs investigation |
| 117 | remove_login_items_spec.sh:20 | returns 2 when given an unknown flag | Needs investigation |
| 118 | remove_login_items_spec.sh:32 | returns 2 when identifier format is invalid | Needs investigation |
| 141 | remove_login_items_spec.sh:176 | accepts flags after the identifier | Needs investigation |
| 218 | unload_and_remove_launch_agent_spec.sh:160 | accepts --needs-root flag before the label | Needs investigation |

### Current Warnings

| # | Spec File | Test Description | Issue |
|---|-----------|------------------|-------|
| 30 | forget_package_spec.sh:46 | returns 2 with internal anchors | Warning instead of failure |
| 31 | forget_package_spec.sh:51 | returns 2 when package id has trailing space | Warning instead of failure |
| 32 | forget_package_spec.sh:56 | returns 2 when package id has leading space | Warning instead of failure |
| 71 | parse_input_spec.sh:152 | manifest mode returns 2 when --manifest but no path | Warning instead of failure |
| 72 | parse_input_spec.sh:157 | manifest mode returns 2 when --manifest path does not exist | Warning instead of failure |
| 205 | unload_and_remove_launch_agent_spec.sh:81 | returns 4 when no plists found without --tolerant-missing | Warning instead of failure |

### Root Cause

The DisableLaunchAgent failures show the pattern:
```
Expected: 0
Got: 5
Output: "Verify failed: print-disabled had stderr for gui/507."
```

This indicates the tests are running with a real GUI user (uid 507) and launchctl is interacting with the actual system. The tests need proper mocking of launchctl commands.

### Fix Required

These tests need **proper mocking** of launchctl to prevent actual system interactions:

```bash
# In spec file, mock launchctl to return expected values
Before 'BeforeDisableLaunchAgentTests'
  # Mock launchctl to simulate agent not found
  launchctl() {
    case "$*" in
      print\ gui/507/*)
        echo "Could not find service" >&2
        return 1 ;;
      print-disabled\ *)
        echo ""  # Empty output = no disabled services
        return 0 ;;
    esac
  }
End
```

---

## Category 4: ParseInput Manifest Mode ✅ COMPLETE

### Previously Affected Function
- `ParseInput` (1 failure)

### Fix Applied
Added handling for `--manifest` as a standalone flag that expects the next argument as the path. When `--manifest` is passed without a following path, the function now correctly returns rc 2.

### Remaining Warnings
Two tests show warnings instead of failures for manifest mode edge cases. These need investigation to ensure proper error handling.

### Status
**COMPLETE** - Main issue fixed, warnings need attention.

---

## Summary of Remaining Code Changes

### Files to Modify

1. **spec/spec_helper.sh** - Add better launchctl mocking infrastructure
2. **Individual spec files** - Update tests to use proper mocks:
   - `spec/disable_launch_agent_spec.sh`
   - `spec/disable_launch_daemon_spec.sh`
   - `spec/forget_package_spec.sh`
   - `spec/quit_app_by_path_spec.sh`
   - `spec/remove_login_items_spec.sh`
   - `spec/unload_and_remove_launch_agent_spec.sh`

### Priority Order

1. **HIGH** - Fix launchctl mocking in DisableLaunchAgent tests (4 failures)
2. **MEDIUM** - Fix remaining flag position tests (10 failures)
3. **LOW** - Address warnings (6 warnings)

### Testing After Fixes

Run the full test suite:
```bash
cd /Users/andrewezimmer/Documents/GitHub/mac-muck
shellspec --shell bash
```

Expected result: 390 examples, 0 failures, 0 warnings, 213 skips

---

## Appendix: Current Test Failure List

| # | Spec File | Line | Test Description | Status |
|---|-----------|------|------------------|--------|
| 2 | disable_launch_agent_spec.sh | 70 | returns 0 when agent is absent and --tolerant-missing | FAILED |
| 13 | disable_launch_agent_spec.sh | 135 | accepts flags before the label | FAILED |
| 14 | disable_launch_agent_spec.sh | 140 | accepts flags after the label | FAILED |
| 15 | disable_launch_agent_spec.sh | 145 | accepts --needs-root flag before the label | FAILED |
| 26 | disable_launch_daemon_spec.sh | 113 | accepts flags before the label | FAILED |
| 27 | disable_launch_daemon_spec.sh | 118 | accepts flags after the label | FAILED |
| 30 | forget_package_spec.sh | 46 | returns 2 with internal anchors | WARNED |
| 31 | forget_package_spec.sh | 51 | returns 2 when package id has trailing space | WARNED |
| 32 | forget_package_spec.sh | 56 | returns 2 when package id has leading space | WARNED |
| 44 | forget_package_spec.sh | 134 | accepts flags before the package id | FAILED |
| 45 | forget_package_spec.sh | 139 | accepts flags after the package id | FAILED |
| 71 | parse_input_spec.sh | 152 | manifest mode returns 2 when --manifest but no path | WARNED |
| 72 | parse_input_spec.sh | 157 | manifest mode returns 2 when --manifest path does not exist | WARNED |
| 89 | quit_app_by_path_spec.sh | 44 | returns 4 when bundle path does not exist | FAILED |
| 90 | quit_app_by_path_spec.sh | 55 | returns 1 when path is not a valid .app bundle | FAILED |
| 117 | remove_login_items_spec.sh | 20 | returns 2 when given an unknown flag | FAILED |
| 118 | remove_login_items_spec.sh | 32 | returns 2 when identifier format is invalid | FAILED |
| 141 | remove_login_items_spec.sh | 176 | accepts flags after the identifier | FAILED |
| 205 | unload_and_remove_launch_agent_spec.sh | 81 | returns 4 when no plists found without --tolerant-missing | WARNED |
| 218 | unload_and_remove_launch_agent_spec.sh | 160 | accepts --needs-root flag before the label | FAILED |