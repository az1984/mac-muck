# Unit Testing Spec — macOS Universal Uninstaller

This document is the **authoritative test specification**. Each checkbox is a single ShellSpec test that must exist and pass. The `.clinerules` file refers back to this document — if it's not checked here, it's not done.

**Rules for checking a box:**
- The test EXISTS in the correct spec file
- The test PASSES (not skipped, not warned, not failed)
- The test asserts the CORRECT return code per the function's header comment
- The test asserts MEANINGFUL output (not just status — check the error message too)
- The test does NOT modify production code in `src/uninstaller.sh` to pass
- Mocks simulate real macOS behavior, not just convenient exit codes

**Rules for Skip:**
- A Skip is NOT a checkmark. Leave the box unchecked.
- Only use Skip when the test literally cannot run (missing macOS tool in CI, needs real root)
- If a mock can make it runnable, write the mock and check the box

---

## ForgetPackage — `spec/forget_package_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2, output includes "Bad input"
- [x] Single-label id (e.g., `"notreverse"`) → rc 2, output includes "Invalid"
- [x] Two-label id (e.g., `"com.vendor"`) → rc 2, output includes "Invalid"
- [x] Id starting with number (e.g., `"1com.vendor.app"`) → rc 2, output includes "Invalid"
- [x] Duplicate `--tolerant-missing` flag → rc 2, output includes "duplicate"
- [x] Unknown flag `--bogus` → rc 2, output includes "unknown flag"
- [x] Internal anchors (e.g., `"com.vendor^.app"`) → rc 2, output includes "anchors"
- [x] Trailing space in id → rc 2, output includes "Invalid"
- [x] Leading space in id → rc 2, output includes "Invalid"

### Root check (rc 3)
- [x] FAKE_EUID=1000, valid id → rc 3, output includes "root"

### Tolerant missing (rc 0)
- [x] FAKE_EUID=0, mock pkgutil --pkg-info fails, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] FAKE_EUID=0, mock pkgutil --pkg-info fails, no tolerance flag → rc 4, output includes "not present"

### Happy path (rc 0)
- [x] FAKE_EUID=0, mock pkgutil --pkg-info succeeds then --forget succeeds then --pkg-info fails (gone) → rc 0
- [x] Anchored format `"^com.vendor.app$"` → rc 0 (anchors normalized)
- [x] Leading `^` only → rc 0
- [x] Trailing `$` only → rc 0

### Verify-after failure (rc 5)
- [x] Mock --forget succeeds but --pkg-info still succeeds afterward (receipt persists) → rc 5, output includes "still present"
- [x] Mock --forget fails → rc 5

### Tool presence (rc 1)
- [x] pkgutil binary not found at expected path → rc 1, output includes "Missing required tool"

### Order-agnostic args
- [x] `--tolerant-missing` before id → rc 0 (same as after)
- [x] `--tolerant-missing` after id → rc 0

---

## QuitAppByPath — `spec/quit_app_by_path_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2, output includes "Bad input"
- [x] Unknown flag `--bogus` → rc 2, output includes "unknown flag"
- [x] Duplicate `--tolerant-missing` → rc 2, output includes "duplicate"

### Not present (rc 4)
- [x] Bundle path does not exist on disk, no tolerance → rc 4
- [x] Path exists but is not a `.app` bundle → rc 1 (invalid bundle)

### Tolerant missing (rc 0)
- [x] Bundle path does not exist, `--tolerant-missing` → rc 0
- [x] Process not running (pgrep returns 1), `--tolerant-missing` → rc 0

### Happy path (rc 0)
- [x] PID mode: mock kill -0 succeeds, pkill succeeds, verify pgrep returns 1 → rc 0
- [x] Bundle mode: mock PlistBuddy returns executable name, pkill succeeds → rc 0
- [x] Process name mode: pkill succeeds, pgrep returns 1 → rc 0

### Verify-after failure (rc 5)
- [x] Mock pkill succeeds but pgrep still returns 0 (process alive) → rc 5

### Tool presence (rc 1)
- [x] pgrep not found → rc 1
- [x] pkill not found → rc 1

---

## SafeRemovePath — `spec/safe_remove_path_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2, output includes "Bad input"
- [x] Too many non-flag arguments → rc 2
- [x] Unknown flag → rc 2

### Root check (rc 3)
- [x] FAKE_EUID=1000, `--needs-root` flag → rc 3

### Tolerant missing (rc 0)
- [x] Path does not exist, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Path does not exist, no tolerance → rc 4

### Happy path (rc 0)
- [x] Existing file removed → rc 0
- [x] Existing directory removed → rc 0
- [x] Symlink removed → rc 0

### Verify-after failure (rc 5)
- [x] Delete attempted but path still exists afterward → rc 5

---

## SafeDelete — `spec/safe_delete_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Unknown flag → rc 2

### Root check (rc 3)
- [x] FAKE_EUID=1000, `--needs-root` → rc 3

### Tolerant missing (rc 0)
- [x] File does not exist, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] File does not exist, no tolerance → rc 4

### Happy path (rc 0)
- [x] Regular file deleted → rc 0

### Verify-after failure (rc 5)
- [x] rm succeeds but file still present → rc 5

---

## RemoveDir — `spec/remove_dir_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Unknown flag → rc 2

### Root check (rc 3)
- [x] FAKE_EUID=1000, `--needs-root` → rc 3

### Tolerant missing (rc 0)
- [x] Directory does not exist, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Directory does not exist, no tolerance → rc 4

### Happy path (rc 0)
- [x] Empty directory removed → rc 0

### Not a directory
- [x] Path exists but is a file, not a directory → rc 2 or rc 5 (per function contract)

---

## UnlinkSymlink — `spec/unlink_symlink_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Unknown flag → rc 2

### Root check (rc 3)
- [x] FAKE_EUID=1000, `--needs-root` → rc 3

### Tolerant missing (rc 0)
- [x] Symlink does not exist, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Symlink does not exist, no tolerance → rc 4

### Happy path (rc 0)
- [x] Symlink unlinked → rc 0

### Not a symlink
- [x] Path exists but is not a symlink → rc 2 or rc 5 (per function contract)

---

## ListGraphicalUsers — `spec/list_graphical_users_spec.sh`

### Happy path
- [x] Returns at least one username on a macOS system with graphical users
- [x] Does NOT return `root`
- [x] Does NOT return system accounts (UID < 500)

### Tool presence (rc 1)
- [x] dscl not found → rc 1

---

## RemovePathForUsers — `spec/remove_path_for_users_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Unknown flag → rc 2
- [x] Absolute path (leading `/`) → rc 2 (paths must be relative)

### Tolerant missing (rc 0)
- [x] Relative path does not exist under any user, `--tolerant-missing` → rc 0

### Happy path (rc 0)
- [x] Path removed from all graphical user homes → rc 0

---

## VerifyServiceUnloaded — `spec/verify_service_unloaded_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] More than one argument → rc 2

### Unloaded (rc 0)
- [x] Mock launchctl print returns "Could not find service" in stderr → rc 0
- [x] Mock launchctl print returns "state = not running" in stdout → rc 0

### Still running (rc 1)
- [x] Mock launchctl print returns "state = running" in stdout → rc 1

### Ambiguous (rc 3)
- [x] Mock launchctl print returns neither canonical state → rc 3

---

## DisableLaunchAgent — `spec/disable_launch_agent_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2, output includes "Bad input"
- [x] Invalid label format (not reverse-DNS) → rc 2, output includes "Invalid label"
- [x] Duplicate `--tolerant-missing` → rc 2, output includes "duplicate"
- [x] Unknown flag → rc 2, output includes "unknown flag"
- [x] Multiple non-flag arguments → rc 2, output includes "multiple non-flag"

### Tolerant missing (rc 0)
- [x] Agent not found in any user domain, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Agent not found in any user domain, no tolerance → rc 4

### Happy path (rc 0)
- [x] Mock: agent found, disable succeeds, print-disabled shows "true" → rc 0

### Verify-after failure (rc 5)
- [x] Mock: disable called but print-disabled does NOT show "true" → rc 5

### Order-agnostic args
- [x] Flags before label → same result as flags after label
- [x] Flags after label → rc 0 (with tolerant + absent)

---

## DisableLaunchDaemon — `spec/disable_launch_daemon_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Invalid label → rc 2
- [x] Duplicate flags → rc 2
- [x] Unknown flag → rc 2

### Root check (rc 3)
- [x] FAKE_EUID=1000 → rc 3 (daemons always require root)

### Tolerant missing (rc 0)
- [x] Daemon not found in system domain, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Daemon not found, no tolerance → rc 4

### Happy path (rc 0)
- [x] Mock: daemon found, disable succeeds, verified disabled → rc 0

### Order-agnostic args
- [x] Flags before label → works
- [x] Flags after label → works

---

## UnloadAndRemoveLaunchAgent — `spec/unload_and_remove_launch_agent_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Invalid label → rc 2
- [x] Unknown flag → rc 2

### Tolerant missing (rc 0)
- [x] No plists found, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] No plists found, no tolerance → rc 4

### Happy path (rc 0)
- [x] Mock: plist exists, disable + bootout succeed, VerifyServiceUnloaded returns 0, SafeDelete succeeds, file gone → rc 0

### Verify-after failure (rc 5)
- [x] VerifyServiceUnloaded returns 1 (still running) → rc 5
- [x] SafeDelete succeeds but plist still on disk → rc 5

### Order-agnostic args
- [x] `--tolerant-missing` before label → works
- [x] `--tolerant-missing` after label → works

---

## UnloadAndRemoveLaunchDaemon — `spec/unload_and_remove_launch_daemon_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Invalid label → rc 2
- [x] Unknown flag → rc 2

### Root check (rc 3)
- [x] FAKE_EUID=1000 → rc 3

### Tolerant missing (rc 0)
- [x] Plist not found, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Plist not found, no tolerance → rc 4

### Happy path (rc 0)
- [x] Mock: plist exists, disable + bootout succeed, verified unloaded, SafeDelete succeeds → rc 0

### Verify-after failure (rc 5)
- [x] Still running after bootout → rc 5
- [x] Plist still on disk after delete → rc 5

---

## RemoveFinderExtension — `spec/remove_finder_extension_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2, output includes "Bad input"
- [x] Unknown flag → rc 2, output includes "unknown flag"
- [x] Duplicate `--tolerant-missing` → rc 2, output includes "duplicate"
- [x] Duplicate `--needs-root` → rc 2, output includes "duplicate"
- [x] Multiple non-flag arguments → rc 2
- [x] Invalid bundle ID (2 labels) → rc 2, output includes "Invalid bundle ID"
- [x] Invalid bundle ID (1 label) → rc 2
- [x] Bundle ID starts with number → rc 2

### Root check (rc 3)
- [x] FAKE_EUID=1000, `--needs-root` → rc 3

### Tolerant missing (rc 0)
- [x] Mock pluginkit -m returns empty, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Mock pluginkit -m returns empty, no tolerance → rc 4, output includes "not registered"

### Happy path (rc 0)
- [x] Mock: pluginkit -m returns info, -e ignore succeeds, -r succeeds, verify -m returns empty → rc 0

### Verify-after failure (rc 5)
- [x] Mock: removal attempted but pluginkit -m still returns info → rc 5, output includes "still registered"

### Tool presence (rc 1)
- [x] pluginkit not found → rc 1

---

## RemoveQuickLookPlugin — `spec/remove_quicklook_plugin_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Unknown flag → rc 2
- [x] Path not absolute → rc 2, output includes "absolute"
- [x] Path does not end in `.qlgenerator` → rc 2, output includes "Invalid"
- [x] Path outside recognized QuickLook directories → rc 2

### Tolerant missing (rc 0)
- [x] Path does not exist, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Path does not exist, no tolerance → rc 4

### Happy path (rc 0)
- [x] Mock: path exists, SafeRemovePath succeeds, verify path gone → rc 0

### Verify-after failure (rc 5)
- [x] SafeRemovePath called but path still exists → rc 5

---

## RemovePrivilegedHelper — `spec/remove_privileged_helper_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Unknown flag → rc 2
- [x] Path not absolute → rc 2, output includes "absolute"
- [x] Path not under `/Library/PrivilegedHelperTools/` → rc 2, output includes "PrivilegedHelperTools"

### Root check (rc 3)
- [x] FAKE_EUID=1000 → rc 3 (helpers always require root)

### Tolerant missing (rc 0)
- [x] Helper not present, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Helper not present, no tolerance → rc 4

### Happy path (rc 0)
- [x] Mock: file exists, SafeDelete succeeds, verify file gone → rc 0

### Verify-after failure (rc 5)
- [x] SafeDelete called but file still present → rc 5

---

## IdentifyLoginItemType — `spec/identify_login_item_type_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2, output includes "Bad input"
- [x] Invalid identifier format → rc 2, output includes "Invalid"
- [x] Unknown flag → rc 2, output includes "unknown flag"
- [x] Multiple non-flag arguments → rc 2

### Root check (rc 3)
- [x] FAKE_EUID=1000 → rc 3

### Tolerant missing (rc 0)
- [x] Mock sfltool output has no matching identifier, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Mock sfltool output has no matching identifier, no tolerance → rc 4

### Type classification (rc 0 with correct TYPE= output)
- [x] Mock BTM entry with "legacy daemon" type → output includes "TYPE=daemon"
- [x] Mock BTM entry with "legacy agent" type → output includes "TYPE=agent"
- [x] Mock BTM entry with "login item" type → output includes "TYPE=login_item"
- [x] Mock BTM entry with "app" type → output includes "TYPE=app"
- [x] Mock BTM entry with unrecognized type → output includes "TYPE=unknown"

### Output format
- [x] Output contains `PATH=` with the filesystem path from URL field
- [x] Output contains `DISPOSITION=` with the disposition flags
- [x] Empty URL field → `PATH=` is empty (not crash)

### Tool presence (rc 1)
- [x] sfltool not found → rc 1

---

## RemoveLoginItems — `spec/remove_login_items_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] Unknown flag → rc 2
- [x] Invalid identifier format → rc 2

### Tolerant missing (rc 0)
- [x] Identifier not in BTM, `--tolerant-missing` → rc 0

### Strict missing (rc 4)
- [x] Identifier not in BTM, no tolerance → rc 4

### Auto-routing (rc 0)
- [x] TYPE=daemon → calls UnloadAndRemoveLaunchDaemon, rc 0
- [x] TYPE=agent → calls UnloadAndRemoveLaunchAgent, rc 0
- [x] TYPE=helper → calls RemovePrivilegedHelper, rc 0
- [x] TYPE=app → calls SafeRemovePath, rc 0

### Routing failures (rc 5)
- [x] TYPE=unknown → rc 5, output includes warning about unknown type
- [x] TYPE=app but PATH is empty → rc 5
- [x] Underlying removal function fails → rc 5

### Order-agnostic args
- [x] Flags before identifier → works
- [x] Flags after identifier → works

---

## ParseInput — `spec/parse_input_spec.sh`

### Fallback mode (no arguments)
- [x] No arguments → rc 0, hardcoded arrays survive unchanged

### Jamf mode detection
- [x] `$4 == "jamf=true"` → enters Jamf mode, parses $5-$11
- [x] `$4 == "JAMF=TRUE"` → does NOT enter Jamf mode (case sensitive)
- [x] `$4 == ""` → does NOT enter Jamf mode

### Jamf parameter parsing
- [x] `$5` sets APP_NAME
- [x] `$6` pipe-delimited → PATHS_TO_REMOVE array
- [x] `$7` pipe-delimited → PKGS_TO_REMOVE array
- [x] Empty Jamf slot → array not modified

### CLI flag parsing
- [x] `--app-name="Test"` → sets APP_NAME
- [x] `--paths="a|b"` → PATHS_TO_REMOVE = ["a", "b"]
- [x] `--packages="x|y"` → PKGS_TO_REMOVE = ["x", "y"]
- [x] `--agents="a.b.c"` → LAUNCH_AGENTS_TO_REMOVE = ["a.b.c"]
- [x] `--daemons="a.b.c"` → LAUNCH_DAEMONS_TO_REMOVE = ["a.b.c"]
- [x] `--finder-exts="a.b.c"` → FINDER_EXTENSIONS_TO_REMOVE = ["a.b.c"]
- [x] `--quit="/path"` → APPS_TO_QUIT = ["/path"]
- [x] `--profile-paths="rel/path"` → PROFILE_REL_PATHS_TO_REMOVE
- [x] `--ql-plugins="/path.qlgenerator"` → QUICKLOOK_PLUGINS_TO_REMOVE
- [x] `--helpers="/Library/PrivilegedHelperTools/x"` → PRIVILEGED_HELPERS_TO_REMOVE
- [x] `--login-items="a.b.c"` → LOGIN_ITEMS_TO_REMOVE
- [x] Multiple flags in one invocation → all arrays set

### Manifest mode
- [x] `--manifest` with no path → rc 2
- [x] `--manifest=/nonexistent` → rc 2
- [x] `--manifest=/valid.json` → rc 0, arrays populated via ParseManifestJSON

### Priority chain
- [x] CLI flags override Jamf params when both present
- [x] Manifest overrides CLI flags when both present

---

## ParseManifestJSON — `spec/parse_manifest_json_spec.sh`

### Bad input (rc 2)
- [x] No arguments → rc 2
- [x] File does not exist → rc 2

### Happy path (rc 0)
- [x] Valid JSON with all keys → rc 0, arrays populated
- [x] Valid JSON with empty arrays → rc 0, arrays remain empty

### Parse failure (rc 1)
- [x] Invalid JSON → rc 1
- [x] plutil not found → rc 1
