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
  jamf_mock.sh                       # Simulate Jamf script invocation locally

spec/
  spec_helper.sh                     # Test harness
  *_spec.sh                          # ShellSpec tests per function

docs/
  BASH_CODING_STANDARDS.md           # Team coding standards
  FUNCTION_SPECS.md                  # Interface specs + macOS command research

docs/
  CONTRACT.md                        # Behavioral contract between builder and uninstaller

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

## Usage

There are three ways to drive the uninstaller, depending on context. All share
the same engine — only the input method differs. All removal operations default
to tolerant-missing (items not present are skipped, not errors).

### Path A: JSON Manifest (recommended)

Best for: complex apps, version-controlled configs, automated pipelines.

```bash
# 1. Build the manifest — paste paths as you find them, the builder infers the rest
./tools/build_manifest.py \
    --app-name "Privileges" \
    --path "/Applications/Privileges.app" \
    --quit "/Applications/Privileges.app" \
    --launchagent "corp.sap.privileges.agent" \
    --launchdaemon "corp.sap.privileges.daemon" \
    --container "/Users/you/Library/Containers/corp.sap.privileges" \
    --package "corp.sap.privileges.pkg" \
    --output manifests/privileges.json

# 2. Validate it (optional)
./tools/build_manifest.py --validate manifests/privileges.json

# 3. Run it
sudo ./src/uninstaller.sh manifests/privileges.json
```

### Path B: CLI Flags

Best for: one-off runs, scripting, simple apps.

```bash
sudo ./src/uninstaller.sh \
    --app-name="MyApp" \
    --paths="/Applications/MyApp.app" \
    --packages="com.vendor.myapp" \
    --agents="com.vendor.myapp.agent" \
    --quit="/Applications/MyApp.app"
```

Use `--cli-usage` on the builder to generate a ready-to-copy command:

```bash
./tools/build_manifest.py --import-manifest manifests/privileges.json --cli-usage
```

### Path C: Jamf Pro Policy

Best for: fleet-wide deployment via Jamf. Parameters $4–$11 carry the config,
with prefix tokens to pack multiple artifact types into combined slots.

**Step 1: Build the manifest** (if you don't already have one)

```bash
./tools/build_manifest.py \
    --app-name "Privileges" \
    --path "/Applications/Privileges.app" \
    --launchagent "corp.sap.privileges.agent" \
    --launchdaemon "corp.sap.privileges.daemon" \
    --container "corp.sap.privileges" \
    --package "corp.sap.privileges.pkg" \
    --output manifests/privileges.json
```

**Step 2: Generate Jamf parameter values**

```bash
./tools/build_manifest.py --import-manifest manifests/privileges.json --jamf-usage
```

This prints each $4–$11 slot with its value, char count, and overflow warnings.
Copy each value into the corresponding parameter field in your Jamf policy.

**Step 3: Test locally with the Jamf mock wrapper**

Before creating a live policy, test the exact parameter values on a local Mac:

```bash
./tools/jamf_mock.sh ./src/uninstaller.sh \
    "jamf=true" \
    "Privileges" \
    "/Applications/Privileges.app" \
    "corp.sap.privileges.pkg" \
    '$LibAgt/corp.sap.privileges.agent|$LibDmn/corp.sap.privileges.daemon' \
    "/Applications/Privileges.app" \
    "" \
    '$UsrCnt/corp.sap.privileges'
```

`jamf_mock.sh` simulates Jamf's invocation: it injects the reserved $1–$3
parameters (mount point, computer name, username), shifts your arguments into
$4–$11, pads empty slots, and runs the script with `sudo`. Use `--dry-run`
to see the command without executing, or `--no-sudo` for testing without root.

**Step 4: Create the Jamf policy**

Upload `src/uninstaller.sh` as a script in Jamf Pro, label Parameters 4–11 per
the `--jamf-usage` output, and fill in the values. Scope to a test group first.

### Lifecycle Summary

```
Investigate app    Build manifest    Validate & test    Deploy
artifacts       →  (build_manifest)  (local + mock)  →  (Jamf / CLI / manifest)
       ↓               ↓                  ↓
  AppCleaner,     JSON manifest      --cli-usage
  pkgutil,        saved to repo      --jamf-usage
  pluginkit                          jamf_mock.sh
```

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
