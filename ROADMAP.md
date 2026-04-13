# Roadmap

## build_manifest.py — CLI-args output mode with shorthand path tokens

When `build_manifest.py` emits CLI arguments (for Jamf script parameters, where
the 255-char limit bites), use shorthand tokens instead of full literal paths.
The uninstaller expands them at runtime.

### Token table

| Token       | Expands to                          | Notes                    |
|-------------|-------------------------------------|--------------------------|
| `$PER_USER` | `/Users/<each user>`                | Triggers per-user loop   |
| `$LibAgt`   | `/Library/LaunchAgents`             |                          |
| `$UsrAgt`   | `~/Library/LaunchAgents`            | Per-user                 |
| `$SysDmn`   | `/System/Library/LaunchDaemons`     | Read-only on modern macOS|
| `$LibDmn`   | `/Library/LaunchDaemons`            |                          |
| `$LibQL`    | `/Library/QuickLook`                |                          |
| `$LibHelp`  | `/Library/PrivilegedHelperTools`    |                          |

### How it works

- **JSON mode** (default): full literal paths in the right arrays. No tokens.
- **CLI-args mode** (`--cli-args`, future flag): paths compressed with tokens.
  The uninstaller's `ParseInput` expands tokens before populating arrays.
- Saves characters where Jamf's 255-char parameter limit is the bottleneck.

### Open questions

- Exact token set — do we need `$SysAgt` (`/System/Library/LaunchAgents`)?
  Rarely touched but exists.
- Group Containers: `$GrpCtr` for `~/Library/Group Containers/`?
- Should token expansion live in `ParseInput` or a dedicated `ExpandTokens`
  function called early?

---

## System Extensions support

macOS System Extensions (Endpoint Security, Network Extensions, Driver
Extensions) replaced kexts starting in 10.15. They live inside the parent
`.app` bundle and are registered with the OS separately.

### Manifest key

```json
"system_extensions": ["com.google.santa.daemon"]
```

### Silent vs. interactive mode

The uninstaller needs a `--silent` / `--interactive` flag (default: `--silent`).

**Interactive mode** (`--interactive`):
- Calls `systemextensionsctl uninstall <team-id> <bundle-id>`
- This triggers a macOS UI prompt asking the user to approve the removal
- Logs success/failure per extension

**Silent mode** (`--silent`, default):
- Does NOT attempt `systemextensionsctl uninstall` (no UI popups allowed)
- Deletes the parent `.app` bundle as normal
- Emits a CLI banner at the end of the run if any artifacts require a reboot
  to fully deactivate:

```
════════════════════════════════════════════════════════════════
  REBOOT REQUIRED
  The following items will not fully deactivate until restart:
    • System Extension: com.google.santa.daemon
════════════════════════════════════════════════════════════════
```

This same banner mechanism should cover any artifact type that needs a reboot
to stick — system extensions, network filters, kernel extensions (legacy), etc.

### MDM note

MDM profiles (`SystemExtensions` payload) can manage/remove system extensions
silently without user consent. If the endpoint is MDM-managed, removing the
profile is the cleanest path. The uninstaller can't do this — it's a
server-side action.

### Open questions

- How to discover the `team-id` at runtime? `codesign -dv` on the `.app` or
  the `.systemextension` bundle gives the team identifier.
- Should we also model Network Extensions and Driver Extensions separately,
  or group all three under `system_extensions`?
- The reboot banner should be a general-purpose mechanism — not just for
  system extensions. Track a `NEEDS_REBOOT` flag that any removal step can set.

---

## Glob / wildcard support in paths

Some artifacts leave behind timestamped files (crash logs, caches) that can't
be enumerated in advance. Examples:

- `/Library/Logs/DiagnosticReports/com.google.santa.daemon-*.ips`
- `Library/Caches/com.vendor.app.*`

### Approach

Allow glob patterns in `paths` and `profile_rel_paths`. The uninstaller expands
them at runtime with `compgen -G` or a `find`-based fallback. Each expanded
path goes through the same `SafeRemovePath` pipeline.

Builder would accept globs as-is and pass them through (no inference needed —
a glob is clearly intentional).
