# Contract — Manifest & Uninstaller Behavior

This document defines the agreed behavior between `build_manifest.py` (the
manifest builder) and `src/uninstaller.sh` (the runtime). If it's in here,
both sides must honor it.

---

## 1. Manifest JSON Schema

```json
{
  "app_name":           "string (required)",
  "apps_to_quit":       ["absolute paths to .app bundles"],
  "paths":              ["absolute system-level paths to remove"],
  "profile_rel_paths":  ["paths relative to ~/, removed per-user"],
  "packages":           ["reverse-DNS package receipt IDs to forget"],
  "launch_agents":      ["reverse-DNS LaunchAgent plist labels"],
  "launch_daemons":     ["reverse-DNS LaunchDaemon plist labels"],
  "finder_extensions":  ["reverse-DNS Finder extension bundle IDs"],
  "quicklook_plugins":  ["absolute paths to .qlgenerator bundles"],
  "privileged_helpers": ["absolute paths under /Library/PrivilegedHelperTools/"],
  "login_items":        ["reverse-DNS login item identifiers"],
  "containers":         ["reverse-DNS app container bundle IDs, removed per-user"]
}
```

All array fields are optional. Omit rather than pass empty arrays.

---

## 2. Builder Path Inference

`build_manifest.py` accepts messy real-world input and routes it to the correct
manifest key. An admin can paste whatever path they found on disk.

### `--path` inference

| Input                                          | Routes to            | Value stored                          |
|------------------------------------------------|----------------------|---------------------------------------|
| `--path /Applications/Foo.app`                 | `paths`              | `/Applications/Foo.app` (unchanged)   |
| `--path /Library/Application Support/Vendor`   | `paths`              | `/Library/Application Support/Vendor` |
| `--path /Users/x/Library/Caches/com.foo`       | `profile_rel_paths`  | `Library/Caches/com.foo`              |
| `--path /Users/x/Library/Containers/com.foo`   | `containers`         | `com.foo` (bundle ID extracted)       |

### `--container` inference

| Input                                                  | Routes to    | Value stored  |
|--------------------------------------------------------|--------------|---------------|
| `--container com.foo.bar`                              | `containers` | `com.foo.bar` (pass-through) |
| `--container /Users/x/Library/Containers/com.foo.bar`  | `containers` | `com.foo.bar` (bundle ID extracted) |

### `--ql-plugin` inference

| Input                                                      | Routes to           | Value stored                          |
|------------------------------------------------------------|---------------------|---------------------------------------|
| `--ql-plugin /Library/QuickLook/Foo.qlgenerator`           | `quicklook_plugins` | `/Library/QuickLook/Foo.qlgenerator`  |
| `--ql-plugin /Users/x/Library/QuickLook/Foo.qlgenerator`   | `quicklook_plugins` | `/Library/QuickLook/Foo.qlgenerator` (promoted to system path) |
| `--ql-plugin /Users/x/Library/Application Scripts/com.foo` | `profile_rel_paths` | `Library/Application Scripts/com.foo` (not a .qlgenerator — per-user artifact) |

### Detection rule

Any path matching `/Users/<name>/...` is per-user. The builder:
1. Strips the `/Users/<name>/` prefix to get the relative path
2. Checks if it's a known container stem (`Library/Containers/`, `Library/Group Containers/`) — if so, extracts bundle ID into `containers`
3. Checks if it contains a `.qlgenerator` — if so, promotes to system-level QL path
4. Otherwise, stores the relative path in `profile_rel_paths`

Inference actions are logged to stderr so the admin sees what was routed.

---

## 3. Uninstaller Execution Model

### Per-user iteration

Everything under a user profile must be handled tolerant-missing. If three user
accounts exist but only one ever used the app, the artifact is legitimately
absent for the other two. This is not an error.

Arrays that trigger per-user iteration:
- `profile_rel_paths` — arbitrary paths relative to `~/`
- `containers` — expanded to `~/Library/Containers/<bundle-id>`
- `launch_agents` — per-user agents live under `~/Library/LaunchAgents/`

### System-level removal

These are removed once, as root:
- `paths` — absolute paths, removed directly
- `launch_daemons` — system-wide, under `/Library/LaunchDaemons/`
- `quicklook_plugins` — typically `/Library/QuickLook/`
- `privileged_helpers` — `/Library/PrivilegedHelperTools/`

### Tolerant-missing everywhere

All removal loops — per-user or system — default to tolerant-missing. An item
not being present is the normal case, not an error. The uninstaller logs at
verbose level when skipping absent items and only reports errors for items that
exist but fail to be removed.

---

## 4. CLI Arg Names

| Builder flag     | Manifest key          | Validator         |
|------------------|-----------------------|-------------------|
| `--app-name`     | `app_name`            | non-empty string  |
| `--quit`         | `apps_to_quit`        | absolute path     |
| `--path`         | `paths` (or inferred) | absolute path     |
| `--profile-path` | `profile_rel_paths`   | relative path     |
| `--package`      | `packages`            | reverse-DNS       |
| `--launchagent`  | `launch_agents`       | reverse-DNS       |
| `--launchdaemon` | `launch_daemons`      | reverse-DNS       |
| `--finder-ext`   | `finder_extensions`   | reverse-DNS       |
| `--ql-plugin`    | `quicklook_plugins`   | absolute path     |
| `--helper`       | `privileged_helpers`  | absolute path     |
| `--login-item`   | `login_items`         | reverse-DNS       |
| `--container`    | `containers`          | reverse-DNS       |
