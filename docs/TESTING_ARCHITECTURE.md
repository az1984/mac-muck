# Testing Architecture — The Gauntlet Model

**Last updated:** 2026-04-12

This document describes the philosophy behind how unit tests are structured for each function in `src/uninstaller.sh`, and summarizes the current state of test coverage for the "hard" failure paths (rc 1 and rc 5+).

---

## The Gauntlet

Every function in the uninstaller follows a sequential validation pipeline. A test for a late-stage failure (like rc 5) is only meaningful if it **proves the input survived every earlier gate**. We call this "walking the gauntlet."

The gates, in order:

| Gate | What it checks | Return code on failure |
|------|---------------|----------------------|
| **A — Input validation** | Args present, valid format, no duplicate flags, no unknown flags | rc 2 |
| **B — Root gate** | If `--needs-root`, is EUID == 0? (Some functions always require root) | rc 3 |
| **C — Presence (tolerant)** | Target not found + `--tolerant-missing` → succeed silently | rc 0 |
| **D — Presence (strict)** | Target not found without `--tolerant-missing` | rc 4 |
| **E — Operation succeeds** | Item found, input valid, operation performed, verify-after confirms | rc 0 |
| **F — Operation fails** | Item found, input valid, operation attempted, but something went wrong | rc 1 or rc 5+ |

### Why this matters

A test that claims to check "operation failed (rc 5)" but uses invalid input, doesn't set root, or points at a nonexistent target might get rc 5 from a completely different code path — or worse, might get it from a mock that short-circuits before the real logic runs. The test passes, but it's testing the mock, not the function.

**Rule:** Every E/F test must set up conditions that pass gates A through D, then let the function's own logic reach the operation and verify-after stages.

### rc 1 vs rc 5+

- **rc 5+** = a *specific, predictable* failure. The function knows what went wrong and says so. Example: "pkgutil forget succeeded but receipt is still present" (ForgetPackage rc 5), or "pkill failed for name: myprocess" (QuitAppByPath rc 5). If a function has multiple distinct failure modes at the operation stage, it may use rc 6, 7, etc.

- **rc 1** = the catchall. Something went wrong that doesn't fit a known category. Example: QuitAppByPath sends TERM, pkill reports success, but the process is *still running* after 10 polling attempts. All known methods succeeded, yet the result is wrong — "Somehow, Palpatine returned." rc 1 often surfaces as a verify-after timeout or an unexpected state.

### Orchestrator functions

Some functions (RemovePathForUsers, RemoveLoginItems, SafeRemovePath) are orchestrators — they validate input, then delegate to other functions (SafeRemovePath, UnloadAndRemoveLaunchDaemon, SafeDelete, etc.). Their E/F tests mock the delegate and check that the orchestrator correctly surfaces success or failure. This is acceptable because:

1. The delegate's own gauntlet is tested in its own spec file.
2. The orchestrator's job is routing and error aggregation, not the operation itself.

The full end-to-end path (orchestrator + delegate + real filesystem) is the domain of runtime/integration tests (see `RUNTIME_TESTING.md`).

---

## Function-by-function audit

For each function, we describe how the E (happy path) and F (operation failed) tests work, and whether they properly walk the gauntlet.

---

### ForgetPackage

**Spec:** `spec/forget_package_spec.sh`
**Gates used:** A (input validation, regex, anchors) → B (always requires root) → C/D (pkgutil --pkg-info) → E/F (pkgutil --forget + verify)

**E test — "successfully forgotten" (rc 0):**
Uses a stateful pkgutil mock (`forget_success` mode). Call 1: `--pkg-info` succeeds (receipt exists, passes D). Call 2: `--forget` succeeds. Call 3: `--pkg-info` fails (receipt gone). The function's own verify-after logic produces rc 0.

**F test — "forget succeeds but receipt still present" (rc 5):**
Mock mode `still_present`. `--pkg-info` always succeeds and `--forget` returns 0, but the verify-after `--pkg-info` still finds the receipt. The function's real verify-after logic sees the receipt persists → rc 5. Gauntlet: valid input ✓, root ✓, pkg exists ✓, operation attempted ✓.

**F test — "forget fails and receipt still present" (rc 5):**
Mock mode `forget_fail`. `--pkg-info` succeeds (exists), `--forget` returns 1 (fails), `--pkg-info` still succeeds (receipt persists) → rc 5. Same gauntlet path, different failure point.

---

### QuitAppByPath

**Spec:** `spec/quit_app_by_path_spec.sh`
**Gates used:** A (arg count, flag parsing) → B (optional --needs-root) → tool presence (pgrep/pkill) → mode classification → C/D (pgrep/kill -0 checks if running) → E/F (pkill/kill -TERM + verify-after polling)

**E test — "successfully terminates process by name" (rc 0):**
`MOCK_PGREP_MODE="running_then_not"` + `MOCK_PKILL_MODE="success"`. First pgrep call: process running (passes D). pkill succeeds. Next pgrep call: process gone. Function's own polling loop confirms termination → rc 0.

**F test — "pkill failed for process name" (rc 5):**
`MOCK_PGREP_MODE="running"` (process found) + `MOCK_PKILL_MODE="fail"`. pgrep confirms process exists (passes D), pkill refuses to cooperate → rc 5 with "pkill failed" message. This is a *specific, known* failure.

**F test — "kill -TERM failed for PID" (rc 5):**
`MOCK_KILL_MODE="check_ok_term_fail"`. kill -0 succeeds (PID exists, passes D), kill -TERM fails → rc 5. Same specificity.

**F test — "process still running after TERM signal" (rc 1):**
`MOCK_PGREP_MODE="running"` + `MOCK_PKILL_MODE="success"`. pgrep confirms running (D), pkill reports success, but pgrep *keeps* reporting running through all 10 poll attempts → rc 1 "Verify failed: still running." This is the "Palpatine returned" scenario — every method reported success, yet the process lives. rc 1, not rc 5, because no specific step failed.

---

### SafeDelete

**Spec:** `spec/safe_delete_spec.sh`
**Gates used:** A → B → C/D (existence check, treats broken symlinks as present) → type dispatch (symlink → UnlinkSymlink, dir → RemoveDir, file → rm) → E/F

**E test — "successfully removes a regular file" (rc 0):**
Creates a real file in /tmp, calls SafeDelete. Real `rm` removes the file. No mocks — exercises the actual delete path.

**F test — "file removal fails" (rc 5):**
Creates a file inside a `chmod a-w` directory. Real rm fails because the parent directory is not writable → rc 5 with "rm failed." Uses **real filesystem permission denial**, not a mock. File exists (passes D), rm is attempted and genuinely fails.

**F test — "directory removal fails" (rc 5):**
Creates a real directory, mocks RemoveDir to return 5. Directory exists (passes D), SafeDelete delegates to RemoveDir, which reports failure → rc 5.

**F test — "UnlinkSymlink delegate fails" (rc 5):**
Creates a real symlink, mocks UnlinkSymlink to return 1. Symlink exists (passes D), SafeDelete delegates, gets failure → rc 5.

---

### SafeRemovePath

**Spec:** `spec/safe_remove_path_spec.sh`
**Gates used:** A → B → C/D → tree walk (find -depth → SafeDelete/RemoveDir/UnlinkSymlink per node) → verify-after (path still exists?)

**E test — "removes a directory tree bottom-up" (rc 0):**
Creates a real multi-level tree (`/tmp/test/subdir1/subdir2` + files). No mocks — exercises the real `find -depth` walk and actual deletion. Verifies the root dir is gone afterward.

**F test — "one or more delete steps fail in directory tree" (rc 5):**
Creates a real tree, mocks SafeDelete to return 5. The tree walk encounters failures → rc 5 with "one or more delete steps failed." Tree exists (passes D), walk is attempted, delegate reports failure.

**F test — "path still exists after removal attempt (verify-after)" (rc 1):**
Creates a real directory tree, mocks SafeDelete and RemoveDir to both return 0 (claim success) but **without actually deleting anything**. The walk "succeeds" but the function's verify-after check sees the path still exists → rc 1 "Verify failed." This is the key rc 1 pattern: no step reported failure, but the outcome is wrong. The filesystem proves the mocks lied.

---

### UnlinkSymlink

**Spec:** `spec/unlink_symlink_spec.sh`
**Gates used:** A → B → C/D (existence, treats broken symlinks as present) �� type check (must be symlink → rc 1 if not) → chflags → unlink → rm -f fallback → E/F

**E test — "successfully unlinks a valid symlink" (rc 0):**
Creates a real symlink to a real target. No mocks. Real `/usr/bin/unlink` removes it. Asserts the symlink no longer exists.

**F test — "unlink fails" (rc 5):**
Creates a symlink inside a `chmod 555` directory. Unlink fails (permission denied), rm -f fallback also fails → rc 5 "unlink failed." Uses **real filesystem permission denial**. Symlink exists (passes D), is a symlink (passes type check), both removal methods genuinely fail.

**Fallback test — "falls back to rm -f when unlink is not found" (rc 0):**
Sets `UNLINK_BIN="/nonexistent/unlink"`. Creates a real symlink. Unlink attempt fails (binary missing), but `rm -f` fallback succeeds → rc 0. Proves the fallback path works. This replaced the original Skip (see WIP_UNIT_TESTING.md Skip 4).

---

### RemoveDir

**Spec:** `spec/remove_dir_spec.sh`
**Gates used:** A → B → C/D → type check (must be directory → rc 1 if not) → chflags → rmdir → E/F

**E test — "successfully removes an empty directory" (rc 0):**
Creates a real empty directory. No mocks. Real `rmdir` removes it.

**F test — "rmdir fails (directory not empty)" (rc 5):**
Creates a real directory with a file inside. Real `rmdir` fails because the directory is not empty → rc 5 "rmdir failed." Uses **real filesystem behavior**. Directory exists (passes D), is a directory (passes type check), rmdir genuinely fails.

---

### RemovePathForUsers

**Spec:** `spec/remove_path_for_users_spec.sh`
**Gates used:** A (rel path validation) → B → dependency checks (ListGraphicalUsers, SafeRemovePath) → path normalization → user discovery → per-user loop (build full path → SafeRemovePath) → E/F

**E test — "successfully removes path for all users" (rc 0):**
Provides explicit username "andrewezimmer", mocks SafeRemovePath to return 0. The function builds the full path, calls SafeRemovePath, gets success → rc 0. This is an orchestrator test — the delegate is mocked.

**F test — "removal fails for one or more users" (rc 5):**
Same setup, mocks SafeRemovePath to return 5. The function builds the path, calls SafeRemovePath, gets failure, increments failure counter → rc 5 "Removal failed." Orchestrator surfaces the delegate's failure.

**F test — "user has no home directory" (rc 5):**
Uses nonexistent user "nonexistent_user_xyz_12345". The function tries to resolve `~nonexistent_user_xyz_12345`, falls back to `/Users/nonexistent_user_xyz_12345`, finds it doesn't exist → rc 5 "No home dir." This tests RemovePathForUsers' **own** logic, not a delegate.

---

### DisableLaunchAgent

**Spec:** `spec/disable_launch_agent_spec.sh`
**Gates used:** A (label format, reverse-DNS regex) → B → tool presence (launchctl) → dependency (ListGraphicalUsers) → label validation → user discovery → per-user: launchctl print (exists?) → launchctl disable → verify (print-disabled) → E/F

**E test — "agent is successfully disabled for one user" (rc 0):**
Mock: agent exists (`MOCK_LAUNCHCTL_AGENT_EXISTS="true"`), disable verified (`MOCK_LAUNCHCTL_DISABLE_VERIFIED="true"`). ListGraphicalUsers returns "testuser". The function finds the agent (passes D), disables it, verify-after confirms → rc 0.

**F test — "disable succeeds but verify shows still enabled" (rc 5):**
Same setup but `MOCK_LAUNCHCTL_DISABLE_VERIFIED="false"`. Agent exists (passes D), launchctl disable returns 0, but print-disabled shows the label is NOT in the disabled set → rc 5 "Verify failed." The operation appeared to succeed, but verification caught that it didn't take.

**F test — "disable fails for one of multiple users" (rc 5):**
Custom multi-user launchctl mock: user 501's verify succeeds, user 507's verify fails (label not in disabled list). Tests partial failure across multiple users → rc 5.

---

### DisableLaunchDaemon

**Spec:** `spec/disable_launch_daemon_spec.sh`
**Gates used:** A → B (always requires root) → tool presence → label validation → launchctl print (exists?) → launchctl disable → verify → E/F

**E test — "daemon is successfully disabled" (rc 0):**
Daemon exists, disable verified. Same pattern as DisableLaunchAgent but for system domain.

**F test — "disable succeeds but verify shows still enabled" (rc 5):**
Daemon exists, disable "succeeds," but print-disabled shows empty → rc 5 "Verify failed."

**F test — "print-disabled has stderr during verification" (rc 5):**
Daemon exists, print-disabled returns stderr → rc 5. Tests that the function treats stderr during verification as a failure signal.

---

### UnloadAndRemoveLaunchAgent

**Spec:** `spec/unload_and_remove_launch_agent_spec.sh`
**Gates used:** A → B → tool presence (launchctl) → dependency checks (ListGraphicalUsers, VerifyServiceUnloaded, SafeDelete) → label validation → user discovery → per-location: plist exists? → disable → bootout → VerifyServiceUnloaded → SafeDelete → verify plist gone → E/F

**E test — "system agent plist is successfully removed" (rc 0):**
Creates a real plist file in the test LaunchAgents dir. Mocks VerifyServiceUnloaded to return 0 and SafeDelete to actually `rm -f` the file. The function finds the plist (passes D), disables, boots out, verifies unloaded, deletes plist → rc 0.

**F test — "agent still running after bootout" (rc 5):**
Creates real plist. VerifyServiceUnloaded returns 1 (still running). Plist exists (passes D), disable+bootout attempted, but service verification fails → rc 5 "Verify failed."

**F test — "SafeDelete fails to remove plist" (rc 5):**
Creates real plist. SafeDelete returns 5. Plist exists, service verified unloaded, but deletion reports failure → rc 5.

**F test — "plist still present after deletion attempt" (rc 5):**
Creates real plist. SafeDelete returns 0 **but doesn't actually remove the file**. The function's own verify-after sees the plist persists → rc 5 "Verify failed." This is the "mock lied, filesystem caught it" pattern.

---

### UnloadAndRemoveLaunchDaemon

**Spec:** `spec/unload_and_remove_launch_daemon_spec.sh`
**Gates used:** A → B (always requires root) → tool presence → label validation → plist exists? → disable → bootout → VerifyServiceUnloaded → SafeDelete → verify → E/F

**COVERAGE GAP: No E or F tests exist.** The spec only covers gates A (bad input), B (needs root), and C (tolerant missing). There are no tests that create a real plist file, run the function, and verify the operation succeeded or failed. This is the only function in the suite with a complete absence of E/F coverage. See the "Gaps" section below.

---

### RemoveFinderExtension

**Spec:** `spec/remove_finder_extension_spec.sh`
**Gates used:** A (bundle ID format, reverse-DNS) → B → tool presence (pluginkit) → pluginkit -m (registered?) → pluginkit -e (disable) → pluginkit -r (remove) → verify (pluginkit -m again) → E/F

**E test — "extension is successfully removed" (rc 0):**
Stateful pluginkit mock (`success` mode). First -m call: registered (passes D). -e and -r succeed. Second -m call: not registered → rc 0.

**F test — "extension is still registered after removal attempt" (rc 5):**
Mock mode `still_registered`. -m always returns registered. -e and -r "succeed," but verify-after -m still finds it → rc 5 "still registered."

---

### RemovePrivilegedHelper

**Spec:** `spec/remove_privileged_helper_spec.sh`
**Gates used:** A (absolute path, under /Library/PrivilegedHelperTools/, reverse-DNS filename) → B → C/D → SafeDelete → verify file gone → E/F

**E test — "helper is successfully removed" (rc 0):**
Creates a real file in a temp PrivilegedHelperTools dir. Mocks SafeDelete to actually `rm -f` the file. File exists (passes D), SafeDelete removes it, verify-after confirms → rc 0.

**F test — "helper still exists after removal attempt" (rc 5):**
Creates real file. SafeDelete returns 0 **but doesn't remove**. Verify-after sees file persists → rc 5 "still exists after removal." The "mock lied" pattern.

**F test — "SafeDelete reports failure" (rc 5):**
Creates real file. SafeDelete returns 5 → rc 5 "SafeDelete failed."

---

### RemoveQuickLookPlugin

**Spec:** `spec/remove_quicklook_plugin_spec.sh`
**Gates used:** A (absolute path, .qlgenerator extension) → B → C/D → SafeRemovePath → verify path gone → E/F

**E test — "plugin is successfully removed" (rc 0):**
Creates a real .qlgenerator directory. Mocks SafeRemovePath to actually `rm -rf` it. Exists (passes D), removed, verified → rc 0.

**F test — "plugin still exists after removal attempt" (rc 5):**
Creates real dir. SafeRemovePath returns 0 but doesn't remove. Verify-after catches persistence → rc 5.

**F test — "SafeRemovePath reports failure" (rc 5):**
Creates real dir. SafeRemovePath returns 5 → rc 5.

---

### IdentifyLoginItemType

**Spec:** `spec/identify_login_item_type_spec.sh`
**Gates used:** A (identifier format) → B (always requires root) → tool presence (sfltool) → sfltool dumpbtm → parse output → classify type

**No E/F tests needed.** This is a read-only function — it identifies what type a login item is, but does not modify state. There is no operation to fail and no verify-after. The rc 0 tests verify correct classification of each type (helper, app, daemon, agent, login_item, unknown).

---

### RemoveLoginItems

**Spec:** `spec/remove_login_items_spec.sh`
**Gates used:** A (identifier format) → B → dependency (IdentifyLoginItemType) → call IdentifyLoginItemType → parse TYPE/PATH → route to correct removal function → E/F

**E tests — type routing (rc 0):**
For each type (daemon, agent, helper, app, login_item): mocks IdentifyLoginItemType to return the type, mocks the corresponding removal function to succeed. Tests that the orchestrator correctly routes and surfaces success.

**F tests — delegate failures (rc 5):**
For each type: mocks IdentifyLoginItemType to return the type, mocks the removal function to return 5. Tests that the orchestrator surfaces "Removal failed."

**F test — "TYPE=app has no path available" (rc 5):**
IdentifyLoginItemType returns TYPE=app with empty PATH. RemoveLoginItems' **own** logic detects "No path available" → rc 5. Not a delegate failure — tests the orchestrator's handling of incomplete data.

**F test — "TYPE=unknown" (rc 5):**
IdentifyLoginItemType returns an unrecognized type. RemoveLoginItems doesn't know which delegate to call → rc 5 "Unknown login item type."

**rc 1 tests:**
- IdentifyLoginItemType function missing → rc 1 "Missing required function"
- IdentifyLoginItemType returns rc 1 (generic failure) → rc 1
- IdentifyLoginItemType returns malformed output → rc 1 "Failed to parse TYPE"

---

### VerifyServiceUnloaded

**Spec:** `spec/verify_service_unloaded_spec.sh`
**Gates used:** A (arg count) → tool presence (launchctl) → launchctl print → parse state

**This function IS the verify-after tool** used by UnloadAndRemoveLaunchAgent/Daemon. It doesn't modify state — it checks whether a launchd service is still active.

**rc 0:** Service not found (launchctl print returns 113) or state = "not running." Both mean the service is properly unloaded.

**rc 1:** Service state = "running" → "Still running." The unload didn't work.

**rc 3:** Tool missing or ambiguous output (state is neither "running" nor "not running"). The function can't determine the answer.

---

### ListGraphicalUsers

**Spec:** `spec/list_graphical_users_spec.sh`
**Gates used:** A (flag parsing) → B → tool presence (dscl) → dscl enumeration → filter

**No E/F tests in the gauntlet sense.** This is a read-only enumeration function. It emits usernames; there's no operation to fail. Tests verify correct filtering (skip Shared, Guest, .localized, UID < 500, no home dir, home not under /Users) and correct output format.

**rc 1 test:** Rewrites the function with sed to replace `/usr/bin/dscl` with a nonexistent path → rc 1 "dscl not found." This is a creative approach to testing a hardcoded path without a `_BIN` override.

---

### ParseInput

**Spec:** `spec/parse_input_spec.sh`
**No gauntlet structure.** ParseInput is a routing function that populates configuration arrays from one of three sources (manifest JSON, CLI flags, Jamf parameters). Tests verify each mode correctly populates arrays, and that priority ordering works (manifest > CLI > Jamf > fallback).

**rc 2 tests:** `--manifest` without a path, `--manifest` pointing to nonexistent file.

---

### ParseManifestJSON

**Spec:** `spec/parse_manifest_json_spec.sh`
**Gates used:** A (arg count, file exists) → tool presence (plutil) → plutil parse → populate arrays

**rc 1 tests:**
- `PLUTIL_BIN="/nonexistent/plutil"` → rc 1 "Missing required tool." Valid file exists (passes A), but tool is missing.
- Invalid JSON content → rc 1 "Failed to parse manifest JSON." File exists and plutil is present, but the content is garbage. The function's real plutil call genuinely fails.

---

## Gaps identified

### UnloadAndRemoveLaunchDaemon — Missing E/F tests

The spec file has zero tests for the happy path or any operation-failure scenario. It only covers:
- rc 2 (bad input, 8 tests)
- rc 3 (needs root, 1 test)
- rc 0 (tolerant missing, 1 test)
- Edge cases (underscores/hyphens, 2 tests)

**Needed:** Tests matching the UnloadAndRemoveLaunchAgent pattern:
1. E: Create plist, mock VerifyServiceUnloaded + SafeDelete to succeed and actually remove → rc 0
2. F: Create plist, VerifyServiceUnloaded returns 1 (still running) → rc 5
3. F: Create plist, SafeDelete returns 5 → rc 5
4. F: Create plist, SafeDelete returns 0 but doesn't remove → rc 5 (verify-after catches persistence)

### Minor: Section header mislabeling

`safe_delete_spec.sh` line 135 has a "Tool presence (rc 1)" section header, but the tests underneath check rc 5 (delegate failures). The header should say "Delegate failure (rc 5)."

---

## File locations

| What | Where |
|------|-------|
| Production code | `src/uninstaller.sh` |
| Test helper | `spec/spec_helper.sh` |
| Spec files | `spec/<snake_case>_spec.sh` (20 files) |
| Mock binaries | `tools/mock_bin/` |
| Unit test checklist | `docs/UNIT_TESTING.md` |
| Runtime test plan | `docs/RUNTIME_TESTING.md` |
| Session notes | `docs/WIP_UNIT_TESTING.md` |
| Coding rules | `.clinerules` |
| This document | `docs/TESTING_ARCHITECTURE.md` |
