# MUCK — Mac Uninstaller Construction Kit

A universal macOS app uninstaller driven by JSON manifests. Build a manifest
describing what an app installed, hand it to the uninstaller, and everything
gets cleaned up: app bundles, LaunchAgents/Daemons, package receipts, per-user
caches, containers, QuickLook plugins, Privileged Helpers, Login Items, and
Finder extensions.

## Quick Start

```bash
# 1. Build a manifest (workstation tool — not deployed to endpoints)
./tools/build_manifest.py \
    --app-name "Suspicious Package" \
    --path "/Applications/Suspicious Package.app" \
    --ql-plugin "/Users/you/Library/Application Scripts/com.mothersruin.SuspiciousPackageApp.QLPreview" \
    --container "/Users/you/Library/Containers/com.mothersruin.SuspiciousPackageApp.QLPreview" \
    --package "com.mothersruin.SuspiciousPackage.pkg" \
    --output suspicious_package.json

# 2. Run the uninstaller
sudo ./src/uninstaller.sh suspicious_package.json
```

## What It Handles

| Artifact type       | Manifest key          | How it's removed                              |
|---------------------|-----------------------|-----------------------------------------------|
| App bundles         | `paths`               | Direct removal (SafeDelete)                   |
| Per-user files      | `profile_rel_paths`   | Iterated across all user homes                |
| Package receipts    | `packages`            | `pkgutil --forget`                            |
| LaunchAgents        | `launch_agents`       | Disable, unload, remove plist (per-user + system) |
| LaunchDaemons       | `launch_daemons`      | Disable, unload, remove plist (system-wide)   |
| Finder extensions   | `finder_extensions`   | `pluginkit` unregister                        |
| QuickLook plugins   | `quicklook_plugins`   | Remove `.qlgenerator` or note `.appex` removal |
| Privileged Helpers  | `privileged_helpers`  | Remove from `/Library/PrivilegedHelperTools/`  |
| Login Items         | `login_items`         | Detect type via BTM, route to correct handler |
| Containers          | `containers`          | Remove from `~/Library/Containers/` per-user  |
| Quit before removal | `apps_to_quit`        | Graceful quit before anything is touched      |

## Project Structure

```
src/
  uninstaller.sh                     # The universal uninstaller (deployed to endpoints)

tools/
  build_manifest.py                  # Manifest builder (workstation-only)

spec/
  spec_helper.sh                     # Test harness
  *_spec.sh                          # ShellSpec tests per function

docs/
  BASH_CODING_STANDARDS.md           # Team coding standards
  FUNCTION_SPECS.md                  # Interface specs + macOS command research

CONTRACT.md                          # Behavioral contract between builder and uninstaller
ROADMAP.md                           # Planned features
```

## Manifest Builder

`build_manifest.py` is designed to be forgiving. Admins can paste paths exactly
as they find them on disk — the builder infers where each item belongs:

- `/Users/jane/Library/Containers/com.foo.app` via `--container` or `--path`
  is recognized as a container, and the bundle ID `com.foo.app` is extracted.
- `/Users/jane/Library/Caches/com.foo.app` via `--path` is detected as per-user
  and routed to `profile_rel_paths`.
- QuickLook extensions are verified against `pluginkit` to confirm they're real
  QL plugins before being added to `quicklook_plugins`.

See `CONTRACT.md` for the full inference rules and routing tables.

### Builder Flags

| Flag             | Description                                    |
|------------------|------------------------------------------------|
| `--app-name`     | Display name (required)                        |
| `--path`         | Absolute path to remove (auto-infers per-user) |
| `--profile-path` | Explicitly per-user relative path              |
| `--quit`         | App to quit before removal                     |
| `--package`      | Package receipt ID to forget                   |
| `--launchagent`  | LaunchAgent plist label                        |
| `--launchdaemon` | LaunchDaemon plist label                       |
| `--finder-ext`   | Finder extension bundle ID                     |
| `--ql-plugin`    | QuickLook plugin (path or bundle ID)           |
| `--helper`       | Privileged Helper path                         |
| `--login-item`   | Login item identifier                          |
| `--container`    | App container bundle ID (path also accepted)   |
| `--output`       | Output file (default: stdout)                  |
| `--validate`     | Validate an existing manifest                  |

All flags are repeatable.

## Running the Uninstaller

```bash
# With a manifest (recommended)
sudo ./src/uninstaller.sh manifest.json
sudo ./src/uninstaller.sh --manifest=manifest.json

# With CLI flags (for Jamf, scripted use)
sudo ./src/uninstaller.sh \
    --app-name="MyApp" \
    --paths="/Applications/MyApp.app" \
    --packages="com.vendor.myapp"

# Jamf mode (positional parameters from Jamf policy)
# $4=jamf=true $5=app_name $6=paths $7=packages
```

All removal operations default to tolerant-missing — items that don't exist are
skipped without error. This is by design: an uninstaller run across multiple
user profiles will find artifacts in some but not others.

## Functions

Functions implemented in `src/uninstaller.sh`:

- `SafeDelete` — non-recursive single-node delete
- `SafeRemovePath` — recursive bottom-up path removal
- `RemoveDir` — remove empty directories
- `UnlinkSymlink` — unlink symlinks only
- `RemovePathForUsers` — remove user-relative paths across all users
- `ForgetPackage` — remove macOS package receipts
- `QuitAppByPath` — quit apps by bundle path, binary path, name, or PID
- `ListGraphicalUsers` — discover local graphical users
- `DisableLaunchAgent` / `DisableLaunchDaemon` — disable services
- `UnloadAndRemoveLaunchAgent` / `UnloadAndRemoveLaunchDaemon` — full lifecycle
- `VerifyServiceUnloaded` — confirm a launchd service is inactive
- `RemoveFinderExtension` — disable + unregister via `pluginkit`
- `RemoveQuickLookPlugin` — remove `.qlgenerator` bundles
- `RemovePrivilegedHelper` — remove helper binaries with path guard
- `IdentifyLoginItemType` — query BTM, detect persistence type
- `RemoveLoginItems` — identify and remove login items by type
- `ParseInput` — three-mode input router (manifest / CLI flags / Jamf)
- `ParseManifestJSON` — `plutil`-based JSON manifest parser

## Testing

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

## Requirements

- macOS 10.15+ (bash 3.2 compatible)
- Root privileges (`sudo`)
- No external dependencies — uses only built-in macOS tools (`plutil`,
  `pkgutil`, `launchctl`, `pluginkit`, `qlmanage`)
