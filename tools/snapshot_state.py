#!/usr/bin/env python3
"""
snapshot_state.py — Capture the state of every artifact a manifest targets.

Workstation-only smoke-test tool. NOT deployed to endpoints.

Run BEFORE and AFTER the uninstaller, then diff the two reports to verify
the uninstaller did its job.

Usage:
  # Before uninstall
  sudo python3 tools/snapshot_state.py \\
      --manifest manifest.json --label BEFORE --output before.txt

  # (run uninstaller)

  # After uninstall
  sudo python3 tools/snapshot_state.py \\
      --manifest manifest.json --label AFTER --output after.txt

  # Compare
  diff before.txt after.txt

The manifest JSON format is the same as build_manifest.py produces.
Requires only Apple-shipped Python 3 (no pip packages).
"""

import argparse
import datetime
import glob as globmod
import json
import os
import pathlib
import pwd
import shutil
import subprocess
import sys

# ──────────────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────────────

_SECTION_WIDTH = 64
_CMD_TIMEOUT = 5
_TREE_MAX_LINES = 200
_SEPARATOR = "=" * _SECTION_WIDTH
_HAS_TREE = shutil.which("tree") is not None


# ──────────────────────────────────────────────────────────────────────────────
# Utilities
# ──────────────────────────────────────────────────────────────────────────────

def run_cmd(cmd, timeout=_CMD_TIMEOUT):
    """Run a command and return (stdout, stderr, returncode). Never raises."""
    try:
        r = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        )
        return r.stdout, r.stderr, r.returncode
    except subprocess.TimeoutExpired:
        return "", f"ERROR: Command timed out after {timeout}s", -1
    except FileNotFoundError:
        return "", f"ERROR: Command not found: {cmd[0]}", 127
    except PermissionError:
        return "", "ERROR: Permission denied", 126
    except Exception as e:
        return "", f"ERROR: {e}", -1


def indent(text, prefix="    "):
    """Indent every non-empty line of text."""
    lines = text.rstrip("\n").split("\n")
    return "\n".join(prefix + line if line.strip() else "" for line in lines)


def section(title):
    """Produce a section header like: ── TITLE ─────────────────"""
    inner = f" {title} "
    pad = _SECTION_WIDTH - 4 - len(inner)
    if pad < 2:
        pad = 2
    return f"\n\u2500\u2500{inner}" + "\u2500" * pad + "\n"


def tree_or_find(path):
    """Return a directory listing via tree (preferred) or find (fallback)."""
    if _HAS_TREE:
        out, err, rc = run_cmd(
            ["tree", "-a", "--dirsfirst", "-C", str(path)], timeout=10
        )
        text = out if rc == 0 else (err or "(tree failed)")
    else:
        out, err, rc = run_cmd(
            ["/usr/bin/find", str(path), "-print"], timeout=10
        )
        if rc == 0:
            lines = sorted(out.strip().split("\n"))
            text = "\n".join(lines)
        else:
            text = err or "(find failed)"

    # Truncate
    lines = text.split("\n")
    if len(lines) > _TREE_MAX_LINES:
        lines = lines[:_TREE_MAX_LINES]
        lines.append(f"... (truncated, showing {_TREE_MAX_LINES} of {len(text.split(chr(10)))} lines)")
        text = "\n".join(lines)

    return text


def get_graphical_users():
    """Return [(username, homedir, uid)] for real graphical users."""
    users = []
    skip_names = {"daemon", "nobody", "root"}

    try:
        out, _, rc = run_cmd(["/usr/bin/dscl", ".", "list", "/Users"])
        if rc != 0:
            raise RuntimeError("dscl failed")
        for name in out.strip().split("\n"):
            name = name.strip()
            if not name or name.startswith("_") or name in skip_names:
                continue
            try:
                pw = pwd.getpwnam(name)
            except KeyError:
                continue
            if pw.pw_uid < 500 or not pw.pw_dir.startswith("/Users/"):
                continue
            users.append((name, pw.pw_dir, pw.pw_uid))
    except Exception:
        # Fallback to current user
        try:
            pw = pwd.getpwuid(os.getuid())
            users = [(pw.pw_name, pw.pw_dir, pw.pw_uid)]
        except Exception:
            pass

    return users


def _path_status(p):
    """Describe a single path: [EXISTS], [ABSENT], [SYMLINK]."""
    lines = []
    if os.path.islink(p):
        target = os.readlink(p)
        lines.append(f"[SYMLINK] {p} -> {target}")
        if os.path.isdir(p):
            lines.append(indent(tree_or_find(p)))
    elif os.path.isdir(p):
        lines.append(f"[EXISTS]  {p}")
        lines.append(indent(tree_or_find(p)))
    elif os.path.isfile(p):
        lines.append(f"[EXISTS]  {p}")
        out, _, _ = run_cmd(["/bin/ls", "-la", p])
        if out.strip():
            lines.append(indent(out.strip()))
    elif os.path.exists(p):
        lines.append(f"[EXISTS]  {p}  (special file)")
    else:
        lines.append(f"[ABSENT]  {p}")
    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
# Snap functions — one per manifest key
# ──────────────────────────────────────────────────────────────────────────────

def snap_paths(paths):
    """Snapshot absolute paths (files, dirs, symlinks)."""
    if not paths:
        return "(none specified)\n"
    parts = []
    for p in paths:
        parts.append(_path_status(p))
    return "\n\n".join(parts) + "\n"


def snap_profile_rel_paths(rel_paths, users):
    """Snapshot per-user relative paths, expanding globs."""
    if not rel_paths:
        return "(none specified)\n"
    if not users:
        return "(no graphical users found)\n"

    parts = []
    for username, homedir, uid in users:
        parts.append(f"User: {username} ({homedir})")
        for rel in rel_paths:
            full_pattern = os.path.join(homedir, rel)
            # Expand globs
            if "*" in rel or "?" in rel:
                matches = sorted(globmod.glob(full_pattern))
                if not matches:
                    parts.append(f"  [ABSENT]  ~/{rel}  (glob matched 0 paths)")
                else:
                    parts.append(f"  ~/{rel}  (glob matched {len(matches)} path(s)):")
                    for m in matches:
                        parts.append(indent(_path_status(m), "    "))
            else:
                parts.append(indent(_path_status(full_pattern), "  "))
    return "\n".join(parts) + "\n"


def snap_apps_to_quit(apps):
    """Snapshot app bundle existence and running process state."""
    if not apps:
        return "(none specified)\n"
    parts = []
    for app in apps:
        parts.append(app)
        bundle_exists = os.path.isdir(app)
        parts.append(f"  Bundle:  {'EXISTS' if bundle_exists else 'ABSENT'}")

        # Try to get executable name from Info.plist
        exe_name = None
        if bundle_exists:
            info_plist = os.path.join(app, "Contents", "Info.plist")
            if os.path.isfile(info_plist):
                out, _, rc = run_cmd([
                    "/usr/libexec/PlistBuddy", "-c",
                    "Print :CFBundleExecutable", info_plist
                ])
                if rc == 0 and out.strip():
                    exe_name = out.strip()

        if exe_name is None:
            # Derive from bundle name
            exe_name = os.path.basename(app).replace(".app", "")

        out, _, rc = run_cmd(["/usr/bin/pgrep", "-f", exe_name])
        if rc == 0 and out.strip():
            pids = ", ".join(out.strip().split("\n"))
            parts.append(f"  Process: RUNNING (PIDs: {pids})")
        else:
            parts.append(f"  Process: NOT RUNNING")
    return "\n".join(parts) + "\n"


def snap_packages(packages):
    """Snapshot package receipt state via pkgutil."""
    if not packages:
        return "(none specified)\n"
    parts = []
    for pkg_id in packages:
        parts.append(pkg_id)
        out, err, rc = run_cmd(["/usr/sbin/pkgutil", "--pkg-info", pkg_id])
        if rc == 0:
            parts.append(indent(out.strip()))
        else:
            combined = (err or out or "").strip()
            if "No receipt" in combined or not combined:
                parts.append("    NOT INSTALLED (no receipt)")
            else:
                parts.append(indent(combined))
    return "\n".join(parts) + "\n"


def snap_launch_agents(agents, users):
    """Snapshot LaunchAgent plist existence and launchctl state."""
    if not agents:
        return "(none specified)\n"
    parts = []
    for label in agents:
        parts.append(label)
        plist_name = f"{label}.plist"

        # System-wide plist
        sys_plist = f"/Library/LaunchAgents/{plist_name}"
        exists = os.path.isfile(sys_plist)
        parts.append(f"  System plist: {sys_plist} — {'EXISTS' if exists else 'ABSENT'}")

        # Per-user plists and launchctl state
        for username, homedir, uid in users:
            user_plist = os.path.join(homedir, "Library", "LaunchAgents", plist_name)
            exists = os.path.isfile(user_plist)
            parts.append(f"  User plist ({username}): {'EXISTS' if exists else 'ABSENT'}")

            out, err, rc = run_cmd([
                "/bin/launchctl", "print", f"gui/{uid}/{label}"
            ])
            if rc == 0:
                # Show first few meaningful lines
                lines = out.strip().split("\n")
                summary = "\n".join(lines[:10])
                if len(lines) > 10:
                    summary += f"\n... ({len(lines)} lines total)"
                parts.append(f"  launchctl print gui/{uid}/{label}:")
                parts.append(indent(summary))
            else:
                msg = (err or out or "").strip()
                parts.append(f"  launchctl print gui/{uid}/{label}:")
                parts.append(indent(msg or "(no output)"))

        parts.append("")
    return "\n".join(parts) + "\n"


def snap_launch_daemons(daemons):
    """Snapshot LaunchDaemon plist existence and launchctl state."""
    if not daemons:
        return "(none specified)\n"
    parts = []
    for label in daemons:
        parts.append(label)
        plist_path = f"/Library/LaunchDaemons/{label}.plist"
        exists = os.path.isfile(plist_path)
        parts.append(f"  Plist: {plist_path} — {'EXISTS' if exists else 'ABSENT'}")

        out, err, rc = run_cmd([
            "/bin/launchctl", "print", f"system/{label}"
        ])
        if rc == 0:
            lines = out.strip().split("\n")
            summary = "\n".join(lines[:10])
            if len(lines) > 10:
                summary += f"\n... ({len(lines)} lines total)"
            parts.append(f"  launchctl print system/{label}:")
            parts.append(indent(summary))
        else:
            msg = (err or out or "").strip()
            parts.append(f"  launchctl print system/{label}:")
            parts.append(indent(msg or "(no output)"))

        parts.append("")
    return "\n".join(parts) + "\n"


def snap_finder_extensions(extensions):
    """Snapshot Finder extension registration via pluginkit."""
    if not extensions:
        return "(none specified)\n"
    parts = []
    for bundle_id in extensions:
        parts.append(bundle_id)
        out, err, rc = run_cmd(["/usr/bin/pluginkit", "-m", "-i", bundle_id])
        if out.strip():
            parts.append(indent(out.strip()))
        elif err.strip():
            parts.append(indent(err.strip()))
        else:
            parts.append("    NOT REGISTERED")
    return "\n".join(parts) + "\n"


def snap_quicklook_plugins(plugins):
    """Snapshot QuickLook plugin path existence and qlmanage registration."""
    if not plugins:
        return "(none specified)\n"

    # Get full qlmanage -m output once
    ql_out, _, _ = run_cmd(["/usr/bin/qlmanage", "-m"], timeout=10)

    parts = []
    for plugin_path in plugins:
        parts.append(plugin_path)
        exists = os.path.exists(plugin_path)
        parts.append(f"  On disk: {'EXISTS' if exists else 'ABSENT'}")
        if exists:
            out, _, _ = run_cmd(["/bin/ls", "-la", plugin_path])
            if out.strip():
                parts.append(indent(out.strip()))

        # Grep qlmanage output for this plugin
        plugin_name = pathlib.Path(plugin_path).stem
        matches = [
            line for line in ql_out.split("\n")
            if plugin_name.lower() in line.lower()
        ]
        if matches:
            parts.append(f"  qlmanage -m (matching lines):")
            parts.append(indent("\n".join(matches)))
        else:
            parts.append(f"  qlmanage -m: not found in output")
    return "\n".join(parts) + "\n"


def snap_privileged_helpers(helpers):
    """Snapshot PrivilegedHelperTools existence."""
    if not helpers:
        return "(none specified)\n"
    parts = []
    for helper_path in helpers:
        parts.append(helper_path)
        if os.path.exists(helper_path):
            out, _, _ = run_cmd(["/bin/ls", "-la", helper_path])
            parts.append(indent(out.strip() if out.strip() else "[EXISTS]"))
        else:
            parts.append("    [ABSENT]")
    return "\n".join(parts) + "\n"


def snap_login_items(items, btm_cache):
    """Snapshot login item presence in BTM database."""
    if not items:
        return "(none specified)\n"
    parts = []
    for identifier in items:
        parts.append(identifier)
        if btm_cache is None:
            parts.append("    (sfltool dumpbtm not available — requires root)")
            continue

        # Search for the identifier in the BTM dump
        matching = []
        for line in btm_cache.split("\n"):
            if identifier.lower() in line.lower():
                matching.append(line)

        if matching:
            parts.append(f"  Found in BTM ({len(matching)} matching line(s)):")
            parts.append(indent("\n".join(matching[:20])))
            if len(matching) > 20:
                parts.append(f"    ... ({len(matching)} lines total)")
        else:
            parts.append("    NOT FOUND in BTM output")
    return "\n".join(parts) + "\n"


# ──────────────────────────────────────────────────────────────────────────────
# Report builder
# ──────────────────────────────────────────────────────────────────────────────

def build_report(manifest, label, manifest_path):
    """Assemble the complete snapshot report."""
    app_name = manifest.get("app_name", "(unknown)")
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    title = f"SNAPSHOT: {app_name}"
    if label:
        title += f" \u2014 {label}"

    lines = [
        _SEPARATOR,
        title,
        f"Date: {now}",
        f"Manifest: {manifest_path}",
        _SEPARATOR,
    ]

    users = get_graphical_users()

    # Cache sfltool output once (requires root)
    btm_cache = None
    login_items = manifest.get("login_items", [])
    if login_items:
        out, err, rc = run_cmd(["/usr/bin/sfltool", "dumpbtm"], timeout=15)
        if rc == 0:
            btm_cache = out
        # If it fails (no root), btm_cache stays None — handled gracefully

    # Each section in manifest order
    sections = [
        ("PATHS",                manifest.get("paths", []),              lambda v: snap_paths(v)),
        ("PROFILE RELATIVE PATHS (per user)", manifest.get("profile_rel_paths", []), lambda v: snap_profile_rel_paths(v, users)),
        ("APPS TO QUIT",         manifest.get("apps_to_quit", []),       lambda v: snap_apps_to_quit(v)),
        ("PACKAGE RECEIPTS",     manifest.get("packages", []),           lambda v: snap_packages(v)),
        ("LAUNCH AGENTS",        manifest.get("launch_agents", []),      lambda v: snap_launch_agents(v, users)),
        ("LAUNCH DAEMONS",       manifest.get("launch_daemons", []),     lambda v: snap_launch_daemons(v)),
        ("FINDER EXTENSIONS",    manifest.get("finder_extensions", []),  lambda v: snap_finder_extensions(v)),
        ("QUICKLOOK PLUGINS",    manifest.get("quicklook_plugins", []),  lambda v: snap_quicklook_plugins(v)),
        ("PRIVILEGED HELPERS",   manifest.get("privileged_helpers", []), lambda v: snap_privileged_helpers(v)),
        ("LOGIN ITEMS",          manifest.get("login_items", []),        lambda v: snap_login_items(v, btm_cache)),
    ]

    for title_text, value, fn in sections:
        lines.append(section(title_text))
        lines.append(fn(value))

    lines.append(_SEPARATOR)
    lines.append("END SNAPSHOT")
    lines.append(_SEPARATOR)

    return "\n".join(lines) + "\n"


# ──────────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Snapshot the state of all artifacts targeted by an uninstall manifest."
    )
    parser.add_argument(
        "--manifest", required=True,
        help="Path to the manifest JSON file (same format as build_manifest.py output)"
    )
    parser.add_argument(
        "--output",
        help="Write report to this file (default: stdout)"
    )
    parser.add_argument(
        "--label",
        help="Label for the report header (e.g., BEFORE, AFTER)"
    )
    args = parser.parse_args()

    # Load manifest
    manifest_path = os.path.abspath(args.manifest)
    if not os.path.isfile(manifest_path):
        print(f"Error: manifest not found: {manifest_path}", file=sys.stderr)
        sys.exit(2)

    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        print(f"Error: failed to read manifest: {e}", file=sys.stderr)
        sys.exit(2)

    if not isinstance(manifest, dict):
        print("Error: manifest must be a JSON object", file=sys.stderr)
        sys.exit(2)

    if "app_name" not in manifest:
        print("Error: manifest missing required 'app_name' key", file=sys.stderr)
        sys.exit(2)

    # Build report
    report = build_report(manifest, args.label, manifest_path)

    # Output
    if args.output:
        out_path = os.path.abspath(args.output)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(report)
        print(f"Report written to: {out_path}", file=sys.stderr)
    else:
        print(report)

    sys.exit(0)


if __name__ == "__main__":
    main()
