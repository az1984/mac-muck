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
