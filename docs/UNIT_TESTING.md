# Unit Testing Plan — macOS Universal Uninstaller

This document outlines unit testing strategies for all major functions in the uninstaller script. Each function's possible return codes (rc 0–5) are documented with test scenarios and expected outcomes.

## Return Code Scheme

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | Operation completed successfully (or target absent with `--tolerant-missing`) |
| 1 | Generic Failure | Internal error, missing tool, or unexpected failure |
| 2 | Bad Input | Missing args, unknown flag, invalid format, duplicate flag |
| 3 | Needs Root | Function requires root but EUID != 0 (when `--needs-root` specified) |
| 4 | Not Present (Strict) | Target not found and `--tolerant-missing` NOT specified |
| 5 | Operation Failed | Action attempted but verify-after shows it didn't take |

---

## Function Test Plans

### 1. ForgetPackage

**Purpose:** Remove a macOS package receipt using `pkgutil --forget`.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — present pkg | `com.vendor.pkg` | 0 | Receipt removed, verify shows absent |
| Happy path — tolerant missing | `com.vendor.pkg` `--tolerant-missing` | 0 | Receipt absent, rc 0 due to tolerance |
| Bad input — missing id | (no args) | 2 | No package id provided |
| Bad input — too many args | `pkg1 pkg2` | 2 | Multiple non-flag args |
| Bad input — unknown flag | `com.vendor.pkg` `--invalid` | 2 | Unknown flag rejected |
| Bad input — invalid id format | `badid` | 2 | Reverse-DNS with ≥3 labels required |
| Bad input — duplicate flag | `com.vendor.pkg` `--tolerant-missing` `--tolerant-missing` | 2 | Duplicate flag detected |
| Not present — strict | `com.missing.pkg` | 4 | Receipt not found, no tolerance |
| Operation failed — still present | `com.vendor.pkg` (mocked to persist) | 5 | Forget succeeded but verify shows still present |
| Needs root | `com.vendor.pkg` (non-root) | 3 | EUID != 0 |

#### Mocking Strategy

- Mock `/usr/sbin/pkgutil` to simulate presence/absence
- Mock `pkgutil --forget` to succeed or fail
- Mock `pkgutil --pkg-info` for verify-after step

---

### 2. QuitAppByPath

**Purpose:** Quit an application by bundle path, binary path, process name, or PID.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — bundle quit | `/Applications/App.app` | 0 | App terminated successfully |
| Happy path — not running | `/Applications/NotRunning.app` `--tolerant-missing` | 0 | App not running, rc 0 |
| Happy path — PID kill | `12345` | 0 | Process terminated |
| Happy path — process name | `processname` | 0 | Process killed by name |
| Bad input — missing arg | (no args) | 2 | No target provided |
| Bad input — too many args | `target1 target2` | 3 | Multiple targets |
| Bad input — unknown flag | `target` `--invalid` | 2 | Unknown flag rejected |
| Not present — strict | `/Applications/Missing.app` | 4 | Bundle path absent, no tolerance |
| Operation failed — verify | `target` (mocked to stay running) | 5 | Signal sent but process still running |
| Bundle path invalid | `/not/an/app` | 2 | Not an .app bundle |

#### Mocking Strategy

- Mock `/usr/bin/pkill`, `/usr/bin/pgrep` to simulate success/failure
- Mock `/usr/libexec/PlistBuddy` to return CFBundleExecutable
- Mock `/bin/kill` for PID mode
- Simulate process staying alive for verify-after failure

---

### 3. SafeRemovePath

**Purpose:** Walk a path bottom-up and delete all elements safely.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — directory tree | `/path/to/dir` (exists) | 0 | All nodes removed bottom-up |
| Happy path — tolerant missing | `/nonexistent` `--tolerant-missing` | 0 | Path absent, rc 0 due to tolerance |
| Happy path — symlink | `/path/to/symlink` | 0 | Symlink unlinked |
| Happy path — single file | `/path/to/file` | 0 | File removed |
| Bad input — missing arg | (no args) | 2 | No path provided |
| Bad input — too many args | `path1 path2` | 2 | Multiple paths |
| Bad input — unknown flag | `path` `--invalid` | 2 | Unknown flag rejected |
| Not present — strict | `/nonexistent` | 4 | Path absent, no tolerance |
| Operation failed — verify | `path` (mocked to persist) | 5 | Delete attempted but verify shows present |

#### Mocking Strategy

- Mock `/usr/bin/find` to return node list
- Mock `SafeDelete`, `RemoveDir`, `UnlinkSymlink` to succeed/fail
- Simulate file persisting after delete for verify-after failure

---

### 4. DisableLaunchAgent

**Purpose:** Disable a LaunchAgent via `launchctl disable` for all graphical users.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — single user | `com.vendor.agent` | 0 | Disabled, verified disabled |
| Happy path — multiple users | `com.vendor.agent` (2 users) | 0 | Disabled for all users |
| Happy path — tolerant missing | `com.missing.agent` `--tolerant-missing` | 0 | Not found, rc 0 due to tolerance |
| Bad input — missing label | (no args) | 2 | No label provided |
| Bad input — too many args | `label1 label2` | 2 | Multiple labels |
| Bad input — unknown flag | `label` `--invalid` | 2 | Unknown flag rejected |
| Bad input — invalid label | `badlabel` | 2 | Reverse-DNS with ≥3 labels required |
| Bad input — duplicate flag | `label` `--tolerant-missing` `--tolerant-missing` | 2 | Duplicate flag detected |
| Not present — strict | `com.missing.agent` | 4 | Not found in any user domain |
| Operation failed — verify | `label` (mocked to stay enabled) | 5 | Disable attempted but verify shows enabled |
| No graphical users | (no users) | 4 | No users to disable for |

#### Mocking Strategy

- Mock `ListGraphicalUsers` to return test users
- Mock `/bin/launchctl print` to simulate found/not found
- Mock `/bin/launchctl disable` to succeed
- Mock `/bin/launchctl print-disabled` for verify-after

---

### 5. DisableLaunchDaemon

**Purpose:** Disable a LaunchDaemon via `launchctl disable` in system domain.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — present | `com.vendor.daemon` | 0 | Disabled, verified disabled |
| Happy path — tolerant missing | `com.missing.daemon` `--tolerant-missing` | 0 | Not found, rc 0 due to tolerance |
| Bad input — missing label | (no args) | 2 | No label provided |
| Bad input — too many args | `label1 label2` | 2 | Multiple labels |
| Bad input — unknown flag | `label` `--invalid` | 2 | Unknown flag rejected |
| Bad input — invalid label | `badlabel` | 2 | Reverse-DNS with ≥3 labels required |
| Bad input — duplicate flag | `label` `--tolerant-missing` `--tolerant-missing` | 2 | Duplicate flag detected |
| Not present — strict | `com.missing.daemon` | 4 | Not found in system domain |
| Operation failed — verify | `label` (mocked to stay enabled) | 5 | Disable attempted but verify shows enabled |
| Needs root | `label` (non-root) | 3 | Daemons always require root |

#### Mocking Strategy

- Mock `/bin/launchctl print` to simulate found/not found
- Mock `/bin/launchctl disable` to succeed
- Mock `/bin/launchctl print-disabled` for verify-after

---

### 6. UnloadAndRemoveLaunchAgent

**Purpose:** Disable, unload, and remove a LaunchAgent plist by label.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — system agent | `com.vendor.agent` (in /Library/LaunchAgents) | 0 | Disabled, bootout, plist removed |
| Happy path — user agent | `com.vendor.agent` (in ~/Library/LaunchAgents) | 0 | Disabled, bootout, plist removed |
| Happy path — tolerant missing | `com.missing.agent` `--tolerant-missing` | 0 | Not found, rc 0 due to tolerance |
| Bad input — missing label | (no args) | 2 | No label provided |
| Bad input — too many args | `label1 label2` | 2 | Multiple labels |
| Bad input — unknown flag | `label` `--invalid` | 2 | Unknown flag rejected |
| Bad input — invalid label | `badlabel` | 2 | Reverse-DNS with ≥3 labels required |
| Not present — strict | `com.missing.agent` | 4 | No plist found |
| Operation failed — bootout | `label` (mocked bootout failure) | 5 | Bootout failed, verify shows running |
| Operation failed — delete | `label` (mocked SafeDelete failure) | 5 | Plist delete failed |

#### Mocking Strategy

- Mock `ListGraphicalUsers` to return test users
- Mock `/bin/launchctl disable`, `bootout` to succeed/fail
- Mock `SafeDelete` to succeed/fail
- Mock `VerifyServiceUnloaded` to simulate verification

---

### 7. UnloadAndRemoveLaunchDaemon

**Purpose:** Disable, unload, and remove a LaunchDaemon plist by label.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — present | `com.vendor.daemon` | 0 | Disabled, bootout, plist removed |
| Happy path — tolerant missing | `com.missing.daemon` `--tolerant-missing` | 0 | Not found, rc 0 due to tolerance |
| Bad input — missing label | (no args) | 2 | No label provided |
| Bad input — too many args | `label1 label2` | 2 | Multiple labels |
| Bad input — unknown flag | `label` `--invalid` | 2 | Unknown flag rejected |
| Bad input — invalid label | `badlabel` | 2 | Reverse-DNS with ≥3 labels required |
| Not present — strict | `com.missing.daemon` | 4 | No plist found |
| Operation failed — bootout | `label` (mocked bootout failure) | 5 | Bootout failed, verify shows running |
| Operation failed — delete | `label` (mocked SafeDelete failure) | 5 | Plist delete failed |
| Needs root | `label` (non-root) | 3 | Daemons always require root |

#### Mocking Strategy

- Mock `/bin/launchctl disable`, `bootout` to succeed/fail
- Mock `SafeDelete` to succeed/fail
- Mock `VerifyServiceUnloaded` to simulate verification

---

### 8. RemoveFinderExtension

**Purpose:** Disable and unregister a Finder Sync extension via `pluginkit`.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — registered | `com.vendor.finder` | 0 | Disabled, removed, verify shows absent |
| Happy path — tolerant missing | `com.missing.finder` `--tolerant-missing` | 0 | Not registered, rc 0 due to tolerance |
| Bad input — missing bundle_id | (no args) | 2 | No bundle_id provided |
| Bad input — too many args | `id1 id2` | 2 | Multiple bundle_ids |
| Bad input — unknown flag | `id` `--invalid` | 2 | Unknown flag rejected |
| Bad input — invalid format | `badid` | 2 | Reverse-DNS with ≥3 labels required |
| Bad input — duplicate flag | `id` `--tolerant-missing` `--tolerant-missing` | 2 | Duplicate flag detected |
| Not present — strict | `com.missing.finder` | 4 | Not registered, no tolerance |
| Operation failed — verify | `id` (mocked to persist) | 5 | Remove attempted but verify shows registered |

#### Mocking Strategy

- Mock `/usr/bin/pluginkit -m -i` to simulate registered/not registered
- Mock `/usr/bin/pluginkit -e ignore` to succeed
- Mock `/usr/bin/pluginkit -r` to succeed
- Mock verify step to show persistence for rc 5

---

### 9. RemoveQuickLookPlugin

**Purpose:** Remove a QuickLook generator plugin from disk.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — present | `/Library/QuickLook/plugin.qlgenerator` | 0 | Plugin removed, verify shows absent |
| Happy path — tolerant missing | `/nonexistent.qlgenerator` `--tolerant-missing` | 0 | Not present, rc 0 due to tolerance |
| Bad input — missing path | (no args) | 2 | No path provided |
| Bad input — too many args | `path1 path2` | 2 | Multiple paths |
| Bad input — unknown flag | `path` `--invalid` | 2 | Unknown flag rejected |
| Bad input — not absolute | `relative/path.qlgenerator` | 2 | Must be absolute path |
| Bad input — not .qlgenerator | `/path/to/plugin.app` | 2 | Must end with .qlgenerator |
| Not present — strict | `/nonexistent.qlgenerator` | 4 | Not present, no tolerance |
| Operation failed — verify | `path` (mocked to persist) | 5 | Remove attempted but verify shows present |

#### Mocking Strategy

- Mock `SafeRemovePath` to succeed/fail
- Mock file existence checks for verify-after

---

### 10. RemovePrivilegedHelper

**Purpose:** Remove a PrivilegedHelperTool binary from `/Library/PrivilegedHelperTools/`.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — present | `/Library/PrivilegedHelperTools/com.vendor.helper` | 0 | Helper removed, verify shows absent |
| Happy path — tolerant missing | `/Library/PrivilegedHelperTools/com.missing.helper` `--tolerant-missing` | 0 | Not present, rc 0 due to tolerance |
| Bad input — missing path | (no args) | 2 | No path provided |
| Bad input — too many args | `path1 path2` | 2 | Multiple paths |
| Bad input — unknown flag | `path` `--invalid` | 2 | Unknown flag rejected |
| Bad input — not absolute | `relative/helper` | 2 | Must be absolute path |
| Bad input — not under dir | `/Library/Other/helper` | 2 | Must be under /Library/PrivilegedHelperTools/ |
| Bad input — invalid filename | `/Library/PrivilegedHelperTools/badname` | 2 | Filename must be reverse-DNS ≥3 labels |
| Not present — strict | `/Library/PrivilegedHelperTools/com.missing.helper` | 4 | Not present, no tolerance |
| Operation failed — verify | `path` (mocked to persist) | 5 | Remove attempted but verify shows present |

#### Mocking Strategy

- Mock `SafeDelete` to succeed/fail
- Mock file existence checks for verify-after

---

### 11. IdentifyLoginItemType

**Purpose:** Detect the persistence mechanism underlying a login/background item.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — daemon | `com.vendor.daemon` (in BTM as legacy daemon) | 0 | Outputs `TYPE=daemon PATH=...` |
| Happy path — agent | `com.vendor.agent` (in BTM as legacy agent) | 0 | Outputs `TYPE=agent PATH=...` |
| Happy path — login_item | `com.vendor.login` (in BTM as login item) | 0 | Outputs `TYPE=login_item PATH=...` |
| Happy path — app | `com.vendor.app` (in BTM as app) | 0 | Outputs `TYPE=app PATH=...` |
| Happy path — tolerant missing | `com.missing.item` `--tolerant-missing` | 0 | Not found, rc 0 due to tolerance |
| Bad input — missing identifier | (no args) | 2 | No identifier provided |
| Bad input — too many args | `id1 id2` | 2 | Multiple identifiers |
| Bad input — unknown flag | `id` `--invalid` | 2 | Unknown flag rejected |
| Bad input — invalid format | `badid` | 2 | Reverse-DNS with ≥2 labels required |
| Bad input — duplicate flag | `id` `--tolerant-missing` `--tolerant-missing` | 2 | Duplicate flag detected |
| Not present — strict | `com.missing.item` | 4 | Not in BTM, no tolerance |
| Operation failed — parse error | `id` (malformed BTM output) | 1 | Parser cannot interpret output |
| Needs root | `id` (non-root) | 3 | sfltool dumpbtm requires root |

#### Mocking Strategy

- Mock `/usr/bin/sfltool dumpbtm` to return various BTM entries
- Simulate malformed output for parse error
- Simulate empty URL for orphaned entries

---

### 12. RemoveLoginItems

**Purpose:** Remove login/background items by auto-routing to correct removal function.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — daemon route | `com.vendor.daemon` (TYPE=daemon) | 0 | Routes to UnloadAndRemoveLaunchDaemon |
| Happy path — agent route | `com.vendor.agent` (TYPE=agent) | 0 | Routes to UnloadAndRemoveLaunchAgent |
| Happy path — helper route | `com.vendor.helper` (TYPE=helper) | 0 | Routes to RemovePrivilegedHelper |
| Happy path — app route | `com.vendor.app` (TYPE=app, has URL) | 0 | Routes to SafeRemovePath |
| Happy path — tolerant missing | `com.missing.item` `--tolerant-missing` | 0 | Not found, rc 0 due to tolerance |
| Bad input — missing identifier | (no args) | 2 | No identifier provided |
| Bad input — too many args | `id1 id2` | 2 | Multiple identifiers |
| Bad input — unknown flag | `id` `--invalid` | 2 | Unknown flag rejected |
| Bad input — invalid format | `badid` | 2 | Reverse-DNS with ≥2 labels required |
| Not present — strict | `com.missing.item` | 4 | Not in BTM, no tolerance |
| Operation failed — unknown type | `id` (TYPE=unknown) | 5 | Unknown type, cannot route |
| Operation failed — no path | `id` (TYPE=app, empty URL) | 5 | Cannot remove without path |
| Operation failed — route failure | `id` (route to failing remover) | 5 | Underlying remover failed |

#### Mocking Strategy

- Mock `IdentifyLoginItemType` to return various TYPE outputs
- Mock underlying removal functions to succeed/fail
- Simulate empty URL path for app/login_item types

---

### 13. ParseInput

**Purpose:** Route input source and populate config arrays.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — manifest mode | `--manifest=/path/to/manifest.json` | 0 | Arrays populated from manifest |
| Happy path — CLI flags | `--app-name=Test --paths=/path1` | 0 | Arrays populated from flags |
| Happy path — Jamf mode | `mnt host user jamf=true AppName|path|pkg` | 0 | Arrays populated from Jamf params |
| Happy path — fallback | (no flags, no Jamf) | 0 | Hardcoded arrays preserved |
| Bad input — manifest missing | `--manifest=/nonexistent.json` | 2 | Manifest file does not exist |
| Bad input — manifest not file | `--manifest=/a/directory` | 2 | Path is directory, not file |

#### Mocking Strategy

- Mock `ParseManifestJSON` to succeed/fail
- Test each input source priority order
- Verify no merging across sources

---

### 14. ParseManifestJSON

**Purpose:** Parse a JSON manifest file using plutil.

#### Test Scenarios

| Test Case | Input | Expected rc | Notes |
|-----------|-------|-------------|-------|
| Happy path — valid JSON | `/path/to/valid.json` | 0 | Arrays populated |
| Happy path — empty arrays | `/path/to/empty.json` | 0 | Arrays remain empty |
| Bad input — missing arg | (no args) | 2 | No manifest path provided |
| Bad input — too many args | `path1 path2` | 2 | Multiple paths |
| Bad input — file not found | `/nonexistent.json` | 2 | File does not exist |
| Operation failed — invalid JSON | `/path/to/invalid.json` | 1 | plutil parse fails |
| Operation failed — plutil missing | (mocked) | 1 | /usr/bin/plutil not found |

#### Mocking Strategy

- Mock `/usr/bin/plutil` to succeed/fail
- Create test JSON files with various structures
- Simulate plutil parse errors

---

## Test File Naming Convention

Spec files should follow the naming convention:
```
spec/<function_name_snake_case>_spec.sh
```

Examples:
- `spec/forget_package_spec.sh`
- `spec/remove_finder_extension_spec.sh`
- `spec/identify_login_item_type_spec.sh`

---

## Running Tests

```bash
# Run all tests
shellspec

# Run specific test file
shellspec spec/remove_finder_extension_spec.sh

# Run with verbose output
shellspec --format documentation