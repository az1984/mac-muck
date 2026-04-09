# Function Specifications — Remaining Uninstaller Features

Reference: WPSMOB-5282

---

## 1. RemoveFinderExtension

### Purpose
Disable and unregister a Finder Sync extension by bundle identifier using `pluginkit`.

### macOS commands

| Action | Command | Notes |
|--------|---------|-------|
| Check if registered | `pluginkit -m -i <bundle_id>` | Returns extension info if present; empty if not. |
| Disable (ignore) | `pluginkit -e ignore -i <bundle_id>` | Tells macOS to stop loading the extension. Non-destructive. |
| Remove registration | `pluginkit -r -i <bundle_id>` | Removes from pluginkit database. The .appex on disk is untouched. |
| Verify removed | `pluginkit -m -i <bundle_id>` | Should return empty after removal. |

### Important behaviors
- `pluginkit` operations are **per-user**. If multiple users have the extension loaded, the disable/remove must be run in each user's context or as the user.
- On macOS 15+ (Sequoia), the Finder Sync Extensions UI was removed from System Settings. `pluginkit` is the only management interface.
- Extensions are embedded inside their containing `.app` bundle (e.g., `Dropbox.app/Contents/PlugIns/garcon.appex`). Removing the registration does NOT remove the file — the app bundle removal handles that separately via `SafeRemovePath`.
- Some apps re-register their extension on launch. The app should be quit (via `QuitAppByPath`) BEFORE calling this function.

### Interface

```
RemoveFinderExtension <bundle_id> [--tolerant-missing] [--needs-root]
```

### Return codes
Standard 0–5 scheme. rc 4 = extension not registered and not tolerant.

### Verification
After `pluginkit -r`, run `pluginkit -m -i <bundle_id>` and confirm empty output.

### Tool requirements
`/usr/bin/pluginkit`

---

## 2. RemoveQuickLookPlugin

### Purpose
Remove a QuickLook generator plugin (`.qlgenerator` bundle) from disk and reload the QL subsystem.

### macOS commands

| Action | Command | Notes |
|--------|---------|-------|
| Remove plugin | `SafeRemovePath` on the `.qlgenerator` path | Standard filesystem removal — it's a directory bundle. |
| Reload QL | `/usr/bin/qlmanage -r` | Forces QuickLook to rescan and drop the removed generator. |
| Verify (list generators) | `/usr/bin/qlmanage -m` | Dumps all registered generators; grep for the plugin name to confirm absence. |

### Plugin locations (search order)
1. `/Library/QuickLook/<n>.qlgenerator` — system-wide, installed by admin/pkg
2. `~/Library/QuickLook/<n>.qlgenerator` — per-user (for each graphical user)
3. Inside app bundles: `<app>.app/Contents/Library/QuickLook/<n>.qlgenerator` — removed when the app bundle is removed via `SafeRemovePath`; no separate action needed.

### Important behaviors
- On macOS 15+ (Sequoia), legacy `.qlgenerator` plugins are deprecated. Apps use QuickLook App Extensions (`.appex`) embedded in the app bundle instead. The function should handle both: standalone `.qlgenerator` → remove + reload; embedded in app bundle → no separate action needed.
- `qlmanage -r` should be called ONCE after all QL plugins are removed, not once per plugin. The `main()` iteration block should call it after the loop, not inside the helper.
- This function takes a **filesystem path** (not a bundle identifier). The path should point to the `.qlgenerator` directory itself.

### Interface

```
RemoveQuickLookPlugin <path_to_qlgenerator> [--tolerant-missing] [--needs-root]
```

### Return codes
Standard 0–5 scheme. rc 4 = plugin not present on disk and not tolerant.

### Verification
After removal, confirm the path no longer exists on disk. The `qlmanage -r` reload is the caller's responsibility (done once in `main()` after all plugins are removed).

### Tool requirements
- `SafeRemovePath` (existing function)
- `/usr/bin/qlmanage` (for reload, called by `main()` not by this function)

---

## 3. IdentifyLoginItemType

### Purpose
Detect what kind of persistence mechanism underlies a login/background item in the macOS BTM (Background Task Management) database. This is a **detector**, not a remover — it tells the caller which removal function to route to.

### The problem this solves
Apple provides no `sfltool remove <item>` command. Login Items are a *symptom* of an underlying persistence mechanism (LaunchAgent, LaunchDaemon, PrivilegedHelperTool, or SMAppService registration). To remove a login item, you must remove its underlying mechanism — but first you need to know *what kind* it is and *where on disk* it lives. This function answers both questions.

### macOS commands

| Action | Command | Notes |
|--------|---------|-------|
| Dump BTM database | `sudo sfltool dumpbtm` | Outputs full BTM database. Requires root. Format varies by macOS version. |
| Reset all items | `sudo sfltool resetbtm` | **Nuclear option** — NOT used by this function. Reference only. |

### Parsing `sfltool dumpbtm` output

Each BTM entry contains structured fields. The critical ones:

```
#N:
  UUID:            <uuid>
  Name:            <display name or (null)>
  Developer Name:  <developer or (null)>
  Type:            <type string> (<hex code>)
  Disposition:     <comma-separated flags>
  Identifier:      <reverse-dns identifier>
  URL:             <file:///path/to/artifact>
  Generation:      <int>
```

**Type field values** (observed, may vary by macOS version):

| Type string | Hex | Meaning | Route to |
|-------------|-----|---------|----------|
| `legacy daemon` | `0x10` | LaunchDaemon plist | `UnloadAndRemoveLaunchDaemon` |
| `legacy agent` | `0x8` | LaunchAgent plist | `UnloadAndRemoveLaunchAgent` |
| `login item` | `0x2` | App registered via SMAppService | `SafeRemovePath` (remove the app) |
| `developer` | `0x20` | SMAppService daemon/agent embedded in app | Route by URL path |
| `app` | `0x4` | Application bundle | `SafeRemovePath` |

**Disposition field values** (comma-separated):

| Flag | Meaning |
|------|---------|
| `enabled` | Currently active |
| `disabled` | User or MDM has disabled it |
| `allowed` | Permitted to run |
| `disallowed` | Blocked from running |
| `visible` | Shown in System Settings |
| `notified` | User has been notified |

**URL field**: Contains the `file://` path to the on-disk artifact. Strip the `file://` prefix to get the filesystem path.

### Interface

```
IdentifyLoginItemType <identifier> [--tolerant-missing]
```

Where `<identifier>` is a reverse-DNS label (e.g., `corp.sap.privileges.helper`).

### Output (stdout)
On success (rc 0), emits a machine-parseable line:

```
TYPE=<daemon|agent|helper|app|login_item|unknown> PATH=<filesystem_path> DISPOSITION=<disposition_flags>
```

Examples:
```
TYPE=daemon PATH=/Library/LaunchDaemons/corp.sap.privileges.helper.plist DISPOSITION=enabled,allowed,visible,notified
TYPE=agent PATH=/Library/LaunchAgents/com.vendor.agent.plist DISPOSITION=enabled,allowed,visible
TYPE=unknown PATH= DISPOSITION=enabled,allowed
```

### Return codes
- 0 = found in BTM database (type and path reported on stdout)
- 1 = generic failure (sfltool missing, parse error, unexpected output format)
- 2 = bad input (missing identifier, invalid format)
- 3 = needs root (sfltool dumpbtm requires root)
- 4 = identifier not found in BTM database and NOT tolerant

### How main() uses this

For the `LOGIN_ITEMS_TO_REMOVE=()` config array, the main() block:
1. Calls `IdentifyLoginItemType` for each identifier
2. Parses the `TYPE=` and `PATH=` from stdout
3. Routes to the appropriate removal function based on type:
   - `daemon` → `UnloadAndRemoveLaunchDaemon`
   - `agent` → `UnloadAndRemoveLaunchAgent`
   - `helper` → `RemovePrivilegedHelper`
   - `app` / `login_item` → `SafeRemovePath`
   - `unknown` → warn, skip

This means admins can list identifiers in `LOGIN_ITEMS_TO_REMOVE` without knowing whether each one is an agent, daemon, or helper. The detector figures it out.

### Verification (post-removal)
After all removals, re-run `IdentifyLoginItemType` for each item:
- rc 4 (not found) = fully removed
- rc 0 with `disabled` in disposition = neutralized, BTM entry lingers (acceptable)
- rc 0 with `enabled` = removal didn't fully take effect (warn)

### Tool requirements
- `/usr/bin/sfltool` (available macOS 13+)

### Safety notes
- Read-only query function — does NOT modify the BTM database.
- `sfltool dumpbtm` requires root. The function enforces EUID == 0.
- Output format of `sfltool dumpbtm` is undocumented and may change. Parser must be defensive and return `TYPE=unknown` on unexpected format.
- URL field may be empty for orphaned entries. `PATH=` will be empty in that case.

---

## 4. RemovePrivilegedHelper

### Purpose
Remove a PrivilegedHelperTool binary from `/Library/PrivilegedHelperTools/`.

### macOS behavior
PrivilegedHelperTools are installed by apps that use the `SMJobBless` or `SMAppService` APIs. They consist of:
- A binary in `/Library/PrivilegedHelperTools/<reverse.dns.label>`
- An associated LaunchDaemon plist in `/Library/LaunchDaemons/<reverse.dns.label>.plist`

The LaunchDaemon should be unloaded and removed FIRST (via `UnloadAndRemoveLaunchDaemon`), THEN the helper binary is removed.

### Interface

```
RemovePrivilegedHelper <path> [--tolerant-missing] [--needs-root]
```

Thin wrapper around `SafeDelete` with a guard that the path is under `/Library/PrivilegedHelperTools/` (refuse to operate outside that directory).

### Return codes
Standard 0–5 scheme. rc 4 = helper not present and not tolerant.

### Verification
Confirm the file no longer exists on disk after deletion.

### Tool requirements
- `SafeDelete` (existing function)

---

## 5. ParseInput

### Purpose
Populate the global config arrays from external input sources, implementing the layered priority chain.

### Input priority chain

Sources are checked in this order. **First source that provides data for a given array wins.** No merging.

| Priority | Source | Activation | Suitable for |
|----------|--------|------------|--------------|
| 1 | `--manifest <path>` | CLI flag present | Complex apps, automated pipelines |
| 2 | CLI `--flags` | Any `--paths=`, `--packages=`, etc. present | Jamf "Files and Processes", manual CLI |
| 3 | Jamf `$5`–`$11` | `$4 == "jamf=true"` (exact match) | Jamf script parameters |
| 4 | Hardcoded arrays | Always (fallback) | Current per-app template behavior |

### Jamf mode detection

```bash
if [[ "${4:-}" == "jamf=true" ]]; then
  JAMF_MODE=true
fi
```

When `JAMF_MODE=true`, `$5`–`$11` are parsed as pipe-delimited values:

| Param | Array |
|-------|-------|
| `$5` | `APP_NAME` |
| `$6` | `PATHS_TO_REMOVE` |
| `$7` | `PKGS_TO_REMOVE` |
| `$8` | `LAUNCH_AGENTS_TO_REMOVE` |
| `$9` | `LAUNCH_DAEMONS_TO_REMOVE` |
| `${10}` | `FINDER_EXTENSIONS_TO_REMOVE` |
| `${11}` | `APPS_TO_QUIT` |

Pipe `|` is the delimiter (paths can't contain pipes).

### CLI flag mode

```bash
./uninstaller.sh --app-name="Vendor App" \
    --paths="/Applications/Vendor.app|/Library/Prefs/com.vendor" \
    --packages="com.vendor.app" \
    --agents="com.vendor.app.agent" \
    --daemons="com.vendor.app.daemon" \
    --finder-exts="com.vendor.app.FinderSync" \
    --quit="/Applications/Vendor.app" \
    --profile-paths="Library/Caches/com.vendor" \
    --ql-plugins="/Library/QuickLook/Vendor.qlgenerator" \
    --helpers="/Library/PrivilegedHelperTools/com.vendor.helper" \
    --login-items="com.vendor.loginitem"
```

Each value is pipe-delimited. Parsing: `IFS='|' read -ra ARRAY <<< "$value"`.

### Manifest mode

`--manifest <path>` calls `ParseManifestJSON()` which uses `/usr/bin/plutil`. No Python on endpoints.

JSON schema:
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

### Interface

```
ParseInput "$@"
```

Called once, BEFORE `main()`, at the end of the script:

```bash
# section #4
ParseInput "$@"
main "$@"
```

### Return codes
- 0 = success (arrays populated from whichever source)
- 1 = generic failure (manifest parse error, plutil missing)
- 2 = bad input (--manifest specified but path missing or not a file)

### Dependencies
- `ParseManifestJSON` (for manifest mode — already built, uses `/usr/bin/plutil`)

---

## Summary: What Cline needs to build

### New functions (in section #3)

| Function | Type | Complexity |
|----------|------|------------|
| `RemoveFinderExtension` | Action | Medium — pluginkit interactions, per-user, verify-after |
| `RemoveQuickLookPlugin` | Action | Low — delegates to SafeRemovePath, path validation |
| `RemovePrivilegedHelper` | Action | Low — delegates to SafeDelete, path guard |
| `IdentifyLoginItemType` | Detector | Medium — sfltool dumpbtm parsing, type classification, machine-parseable output |
| `ParseInput` | Input router | Medium — three-mode arg parsing, Jamf detection |
| `ParseManifestJSON` | Input parser | Medium — plutil-based JSON extraction (already built) |

### New config arrays (in section #1)

```bash
FINDER_EXTENSIONS_TO_REMOVE=(
  # "com.vendor.app.FinderSync"
)

QUICKLOOK_PLUGINS_TO_REMOVE=(
  # "/Library/QuickLook/SuspiciousPackage.qlgenerator"
)

PRIVILEGED_HELPERS_TO_REMOVE=(
  # "/Library/PrivilegedHelperTools/com.vendor.helper"
)

LOGIN_ITEMS_TO_REMOVE=(
  # "com.vendor.loginitem"  ← IdentifyLoginItemType auto-routes to correct removal
)
```

### New main() blocks (in section #2)

- Finder extension removal loop
- QuickLook plugin removal loop + single `qlmanage -r` after loop
- PrivilegedHelper removal loop
- Login item auto-routing loop (detect type → route to removal function)

### Script invocation change (section #4)

```bash
# Before:
main "$@"

# After:
ParseInput "$@"
main "$@"
```
