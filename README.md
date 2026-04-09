# Universal Uninstaller Framework

**JIRA:** [WPSMOB-5282](https://lilly-jira.atlassian.net/browse/WPSMOB-5282)

## Directory structure

```
.clinerules                          # Cline AI rules — enforces coding standards
.shellspec                           # ShellSpec config
src/
  uninstaller.sh                     # The uninstaller script (working copy)
spec/
  spec_helper.sh                     # Test harness — sources functions without running main()
  disable_launch_agent_spec.sh       # Spec for DisableLaunchAgent
  disable_launch_daemon_spec.sh      # Spec for DisableLaunchDaemon
  forget_package_spec.sh             # Spec for ForgetPackage
  identify_login_item_type_spec.sh   # Spec for IdentifyLoginItemType
  parse_input_spec.sh                # Spec for ParseInput (all three modes + priority)
  remove_finder_extension_spec.sh    # Spec for RemoveFinderExtension
  remove_privileged_helper_spec.sh   # Spec for RemovePrivilegedHelper
  remove_quicklook_plugin_spec.sh    # Spec for RemoveQuickLookPlugin
  unload_and_remove_launch_agent_spec.sh   # Spec for UnloadAndRemoveLaunchAgent
  unload_and_remove_launch_daemon_spec.sh  # Spec for UnloadAndRemoveLaunchDaemon
  verify_service_unloaded_spec.sh    # Spec for VerifyServiceUnloaded
docs/
  BASH_CODING_STANDARDS.md           # Team coding standards — mandatory reading
  FUNCTION_SPECS.md                  # Interface specs + macOS command research for new functions
tools/
  build_manifest.py                  # Dev-side manifest builder (NOT deployed to endpoints)
```

## What's built

Functions already implemented in `src/uninstaller.sh`:
- `ForgetPackage` — remove macOS package receipts
- `ListGraphicalUsers` — discover local graphical users
- `QuitAppByPath` — quit apps by bundle path, binary path, name, or PID
- `RemoveDir` — remove empty directories
- `RemovePathForUsers` — remove user-relative paths across all users
- `SafeDelete` — non-recursive single-node delete
- `SafeRemovePath` — recursive bottom-up path removal
- `UnlinkSymlink` — unlink symlinks only
- `VerifyServiceUnloaded` — check that a launchd service is no longer active
- `DisableLaunchAgent` — disable a LaunchAgent for all graphical users
- `DisableLaunchDaemon` — disable a LaunchDaemon in the system domain
- `UnloadAndRemoveLaunchAgent` — full lifecycle: disable → bootout → verify → delete
- `UnloadAndRemoveLaunchDaemon` — full lifecycle for daemons

## What Cline needs to build

New functions (see `docs/FUNCTION_SPECS.md` for full specs):
- `RemoveFinderExtension` — disable + unregister via `pluginkit`
- `RemoveQuickLookPlugin` — remove `.qlgenerator` + path validation
- `RemovePrivilegedHelper` — remove helper binary with path guard
- `IdentifyLoginItemType` — query `sfltool dumpbtm`, detect persistence type, report TYPE/PATH/DISPOSITION
- `ParseInput` — three-mode input router (manifest → CLI flags → Jamf params → hardcoded)
- `ParseManifestJSON` — plutil-based JSON manifest parser (already designed, needs integration)

Plus: config arrays, main() iteration blocks, summary counters for each.

## Process

1. Read `.clinerules` and `docs/BASH_CODING_STANDARDS.md` first
2. Read `docs/FUNCTION_SPECS.md` for interface contracts and macOS commands
3. Implement functions in `src/uninstaller.sh` section #3
4. Add config arrays in section #1, iteration blocks in section #2
5. Run `shellcheck -s bash src/uninstaller.sh` — must pass with zero warnings
6. Run `shellspec` — all specs must pass
7. Update `@requires` line in the file header

## Running tests

```bash
# Install shellspec (if needed)
brew install shellspec

# Run all specs
shellspec

# Run a single spec
shellspec spec/remove_finder_extension_spec.sh

# Lint
shellcheck -s bash src/uninstaller.sh
```
