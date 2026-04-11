# ShellSpec Test Fixes Plan

This document outlines the fixes needed to achieve 100% pass rate for the ShellSpec unit tests in the mac-muck project.

## Current Status

- **Total Tests:** 398 examples
- **Failures:** 14
- **Warnings:** 2
- **Skips:** 225

**Progress:** Categories 2 and 4 are complete. Categories 1 and 3 remain.

## Failure Analysis

The failures fall into **4 distinct categories**:

- **Category 1**: Root gate interfering with input validation (14 remaining)
- **Category 2**: Duplicate flag detection order (✅ COMPLETE)
- **Category 3**: Flag position tests requiring root mocking (12 remaining)
- **Category 4**: ParseInput manifest mode (✅ COMPLETE)

---

## Category 1: Root Gate Interfering with Input Validation (14 remaining)

### Affected Functions
- `ForgetPackage` (7 failures)
- `DisableLaunchDaemon` (5 failures)
- `IdentifyLoginItemType` (1 failure)
- `UnloadAndRemoveLaunchDaemon` (5 failures)

**Status:** REMAINING - This is now the highest priority category.

### Root Cause
The functions check for root privileges **before** validating input arguments. When tests run as non-root with invalid input, the function returns rc 3 (needs root) instead of rc 2 (bad input).

### Example Failure
```
ForgetPackage returns 2 when given an invalid package id (single label)
  expected: 2
       got: 3
  Output: "Needs root: run as sudo/root."
```

### Fix Required

The input validation must occur **before** the root check in the following functions:

#### 1. ForgetPackage (src/uninstaller.sh, ~line 3050)

**Current order:**
1. Check argument count
2. Parse flags
3. **Check root** ← Too early
4. Validate package ID format
5. Check for internal anchors/spaces

**Required order:**
1. Check argument count
2. Parse flags
3. **Validate package ID format** ← Move before root check
4. **Check for internal anchors/spaces** ← Move before root check
5. **Check root** ← Move after validation
6. Check for duplicate flags

#### 2. DisableLaunchDaemon (src/uninstaller.sh, ~line 2850)

**Current order:**
1. Check argument count
2. Parse flags
3. **Check root** ← Too early
4. Validate label format

**Required order:**
1. Check argument count
2. Parse flags
3. **Validate label format** ← Move before root check
4. **Check root** ← Move after validation
5. Proceed with daemon operations

#### 3. IdentifyLoginItemType (src/uninstaller.sh, ~line 3200)

**Current order:**
1. Check argument count
2. Parse flags
3. **Check root** ← Too early
4. Validate identifier format

**Required order:**
1. Check argument count
2. Parse flags
3. **Validate identifier format** ← Move before root check
4. **Check root** ← Move after validation
5. Proceed with sfltool queries

#### 4. UnloadAndRemoveLaunchDaemon (src/uninstaller.sh, ~line 3350)

Same pattern as DisableLaunchDaemon - move label validation before root check.

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

## Category 3: Flag Position Tests (12 remaining)

### Affected Functions
- `DisableLaunchAgent` (3 failures)
- `DisableLaunchDaemon` (2 failures)
- `ForgetPackage` (2 failures)
- `QuitAppByPath` (1 failure)
- `RemoveDir` (1 failure)
- `RemoveLoginItems` (1 failure)
- `SafeDelete` (1 failure)
- `SafeRemovePath` (1 failure)
- `UnlinkSymlink` (1 failure)
- `UnloadAndRemoveLaunchDaemon` (2 failures)

**Status:** REMAINING - Requires root mocking in tests.

### Root Cause
These tests verify that flags can appear before or after the main argument. They're failing because the functions require root, and the tests run as non-root.

### Example Failure
```
DisableLaunchAgent accepts flags before the label
  When call DisableLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
  The status should eq 0
  Got: 3 (needs root)
```

### Fix Required

These tests need to be **updated to run as root** or **mocked** to bypass the root check. There are two approaches:

#### Approach A: Run Tests as Root (Simple but Less Safe)

Update the spec files to run these specific tests with `sudo`:

```bash
# In spec file
It 'accepts flags before the label'
  When call DisableLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
  The status should eq 0
End
```

Run with:
```bash
sudo shellspec --shell bash spec/disable_launch_agent_spec.sh
```

#### Approach B: Mock Root Check (Recommended)

Add a mock for the root check in the spec_helper.sh or individual spec files:

```bash
# In spec_helper.sh or at top of spec file
# Mock the EUID check to simulate root
export EUID=0
export UID=0
```

Or mock at the function level using ShellSpec's mock feature:

```bash
# In the spec file
BeforeEach 'BeforeEachDisableLaunchAgent'
  # Set up mock environment
  export EUID=0
  export UID=0
End

It 'accepts flags before the label'
  When call DisableLaunchAgent --tolerant-missing "com.nonexistent.app.agent"
  The status should eq 0
End
```

---

## Category 4: ParseInput Manifest Mode ✅ COMPLETE

### Previously Affected Function
- `ParseInput` (1 failure)

### Fix Applied
Added handling for `--manifest` as a standalone flag that expects the next argument as the path. When `--manifest` is passed without a following path, the function now correctly returns rc 2.

### Status
**COMPLETE** - Test now passing.

---

## Summary of Remaining Code Changes

### Files to Modify

1. **src/uninstaller.sh** - Fix input validation order in:
   - `ForgetPackage` function
   - `DisableLaunchDaemon` function
   - `IdentifyLoginItemType` function
   - `UnloadAndRemoveLaunchDaemon` function

2. **spec/spec_helper.sh** - Add root simulation for non-root tests (Category 3)

3. **Individual spec files** - Update tests to use mocked root environment (Category 3)

### Priority Order

1. **HIGH** - Fix input validation order (Category 1) - 14 remaining
2. **MEDIUM** - Add root mocking (Category 3) - 12 remaining

Categories 2 and 4 are complete.

### Testing After Fixes

Run the full test suite:
```bash
cd /Users/andrewezimmer/Documents/GitHub/mac-muck
shellspec --shell bash
```

Expected result: 398 examples, 0 failures, 225 skips (the skips are intentional for tests requiring actual macOS APIs)

---

## Appendix: Test Failure List

| # | Spec File | Line | Test Description | Category |
|---|-----------|------|------------------|----------|
| 2 | disable_launch_agent_spec.sh | 70 | returns 0 when agent is absent and --tolerant-missing | 3 |
| 13 | disable_launch_agent_spec.sh | 135 | accepts flags before the label | 3 |
| 14 | disable_launch_agent_spec.sh | 140 | accepts flags after the label | 3 |
| 15 | disable_launch_agent_spec.sh | 145 | accepts --needs-root flag before the label | 3 |
| 19 | disable_launch_daemon_spec.sh | 14 | returns 2 when given an invalid label format (single label) | 1 |
| 20 | disable_launch_daemon_spec.sh | 20 | returns 2 when given an invalid label format (only 2 labels) | 1 |
| 21 | disable_launch_daemon_spec.sh | 26 | returns 2 when label starts with number | 1 |
| 29 | disable_launch_daemon_spec.sh | 113 | accepts flags before the label | 3 |
| 30 | disable_launch_daemon_spec.sh | 118 | accepts flags after the label | 3 |
| 33 | forget_package_spec.sh | 16 | returns 2 when given an invalid package id (single label) | 1 |
| 34 | forget_package_spec.sh | 22 | returns 2 when given an invalid package id (only 2 labels) | 1 |
| 35 | forget_package_spec.sh | 28 | returns 2 when package id starts with number | 1 |
| 37 | forget_package_spec.sh | 46 | returns 2 with internal anchors | 1 |
| 38 | forget_package_spec.sh | 51 | returns 2 when package id has trailing space | 1 |
| 39 | forget_package_spec.sh | 56 | returns 2 when package id has leading space | 1 |
| 51 | forget_package_spec.sh | 134 | accepts flags before the package id | 3 |
| 52 | forget_package_spec.sh | 139 | accepts flags after the package id | 3 |
| 55 | identify_login_item_type_spec.sh | 11 | returns 2 when given an invalid identifier format | 1 |
| 96 | quit_app_by_path_spec.sh | 14 | returns 2 when given too many arguments | 3 |
| 99 | quit_app_by_path_spec.sh | 44 | returns 4 when bundle path does not exist | 3 |
| 100 | quit_app_by_path_spec.sh | 55 | returns 1 when path is not a valid .app bundle | 3 |
| 115 | quit_app_by_path_spec.sh | 141 | accepts flags before the target | 3 |
| 116 | remove_dir_spec.sh | 14 | returns 2 when given too many arguments | 3 |
| 124 | remove_dir_spec.sh | 91 | accepts flags before the path | 3 |
| 156 | remove_login_items_spec.sh | 176 | accepts flags after the identifier | 3 |
| 184 | safe_delete_spec.sh | 14 | returns 2 when given too many arguments | 3 |
| 195 | safe_delete_spec.sh | 107 | accepts flags before the path | 3 |
| 198 | safe_remove_path_spec.sh | 14 | returns 2 when given too many arguments | 3 |
| 212 | safe_remove_path_spec.sh | 123 | accepts flags before the path | 3 |
| 216 | unlink_symlink_spec.sh | 14 | returns 2 when given too many arguments | 3 |
| 225 | unlink_symlink_spec.sh | 95 | accepts flags before the path | 3 |
| 243 | unload_and_remove_launch_agent_spec.sh | 160 | accepts --needs-root flag before the label | 3 |
| 247 | unload_and_remove_launch_daemon_spec.sh | 14 | returns 2 when given an invalid label format (single label) | 1 |
| 248 | unload_and_remove_launch_daemon_spec.sh | 20 | returns 2 when given an invalid label format (only 2 labels) | 1 |
| 249 | unload_and_remove_launch_daemon_spec.sh | 26 | returns 2 when label starts with number | 1 |
| 260 | unload_and_remove_launch_daemon_spec.sh | 125 | accepts --tolerant-missing before the label | 3 |
| 261 | unload_and_remove_launch_daemon_spec.sh | 130 | accepts --tolerant-missing after the label | 3 |