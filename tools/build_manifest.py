#!/usr/bin/env python3
"""
build_manifest.py — Build a JSON uninstall manifest for the universal uninstaller.

Workstation-only tool. NOT deployed to endpoints.

Usage examples:
  # Minimal — just an app name and a path
  ./build_manifest.py --app-name "Microsoft 365 Copilot" \
      --path "/Applications/Microsoft 365 Copilot.app"

  # Full featured
  ./build_manifest.py --app-name "Vendor App" \
      --path "/Applications/Vendor App.app" \
      --path "/Library/Application Support/Vendor" \
      --profile-path "Library/Caches/com.vendor.app" \
      --profile-path "Library/Preferences/com.vendor.app.plist" \
      --quit "/Applications/Vendor App.app" \
      --package "com.vendor.app" \
      --package "com.vendor.app.helper" \
      --launchagent "com.vendor.app.agent" \
      --launchdaemon "com.vendor.app.daemon" \
      --finder-ext "com.vendor.app.FinderSync" \
      --ql-plugin "/Library/QuickLook/Vendor.qlgenerator" \
      --helper "/Library/PrivilegedHelperTools/com.vendor.helper" \
      --login-item "com.vendor.loginitem" \
      --container "com.vendor.app" \
      --output vendor_app_uninstall.json

  # Output to stdout (for piping or copy-paste)
  ./build_manifest.py --app-name "SomeApp" --path "/Applications/SomeApp.app"

  # Suspicious Package — uses QuickLook plugin + container
  ./build_manifest.py --app-name "Suspicious Package" \
      --path "/Applications/Suspicious Package.app" \
      --ql-plugin "/Library/QuickLook/SuspiciousPackage.qlgenerator" \
      --container "com.mothersruin.SuspiciousPackage" \
      --package "com.mothersruin.SuspiciousPackage.pkg"

  # Validate an existing manifest
  ./build_manifest.py --validate existing_manifest.json

Flags are repeatable: use --path twice for two paths, etc.

Output is deterministic (sorted keys, consistent indent) so manifests
diff cleanly in version control.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import OrderedDict


# ──────────────────────────────────────────────────────────────────────────────
# Validation helpers
# ──────────────────────────────────────────────────────────────────────────────

# Reverse-DNS: ≥3 labels, starts with letter, only [A-Za-z0-9_-.]
_RDNS_RE = re.compile(r'^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_-]*){2,}$')

# Characters forbidden in identifiers (matches the bash validator)
_BAD_CHARS_RE = re.compile(r'[\s/\\*?\[\]{}|;:<>&`\'"]')


def validate_absolute_path(path: str, field_name: str) -> tuple[list[str], list[str]]:
    """Validate an absolute filesystem path. Returns (errors, warnings)."""
    errors = []
    warnings = []
    if not path.startswith("/"):
        errors.append(f"{field_name}: '{path}' is not an absolute path (must start with /)")
    if "\0" in path:
        errors.append(f"{field_name}: '{path}' contains null bytes")
    return errors, warnings


def validate_relative_path(path: str, field_name: str) -> tuple[list[str], list[str]]:
    """Validate a user-relative path (no leading slash). Returns (errors, warnings)."""
    errors = []
    warnings = []
    if path.startswith("/"):
        errors.append(f"{field_name}: '{path}' should NOT start with / (it's relative to ~/)")
    if "\0" in path:
        errors.append(f"{field_name}: '{path}' contains null bytes")
    if ".." in path.split("/"):
        warnings.append(f"{field_name}: '{path}' contains '..' traversal — suspicious")
    return errors, warnings


def validate_rdns_id(identifier: str, field_name: str) -> tuple[list[str], list[str]]:
    """Validate a reverse-DNS identifier. Returns (errors, warnings)."""
    errors = []
    warnings = []
    # Strip optional anchors (^ and $) for validation, same as the bash functions
    clean = identifier.lstrip("^").rstrip("$")
    if not _RDNS_RE.match(clean):
        errors.append(
            f"{field_name}: '{identifier}' is not valid reverse-DNS format "
            f"(need ≥3 dot-separated labels, e.g., com.vendor.app)"
        )
    if _BAD_CHARS_RE.search(clean):
        errors.append(f"{field_name}: '{identifier}' contains forbidden characters")
    return errors, warnings


def validate_ql_plugin_entry(entry: str, field_name: str) -> tuple[list[str], list[str]]:
    """Validate a quicklook_plugins entry — either an absolute path or a bundle ID."""
    if entry.startswith("/"):
        return validate_absolute_path(entry, field_name)
    else:
        return validate_rdns_id(entry, field_name)


def validate_manifest(manifest: dict) -> tuple[list[str], list[str]]:
    """
    Validate a complete manifest dict.
    Returns (errors, warnings) — errors are fatal, warnings are advisory.
    """
    errors = []
    warnings = []

    # ── Required field
    if "app_name" not in manifest or not manifest["app_name"].strip():
        errors.append("'app_name' is required and cannot be empty")

    # ── Known keys
    known_keys = {
        "app_name", "paths", "profile_rel_paths", "apps_to_quit",
        "packages", "launch_agents", "launch_daemons", "finder_extensions",
        "quicklook_plugins", "privileged_helpers", "login_items", "containers",
    }
    for key in manifest:
        if key not in known_keys:
            warnings.append(f"Unknown key '{key}' — will be ignored by the uninstaller")

    # ── Array fields: type check + per-item validation
    array_validators = {
        "paths":              ("absolute path",  validate_absolute_path),
        "apps_to_quit":       ("absolute path",  validate_absolute_path),
        "profile_rel_paths":  ("relative path",  validate_relative_path),
        "packages":           ("package id",     validate_rdns_id),
        "launch_agents":      ("agent label",    validate_rdns_id),
        "launch_daemons":     ("daemon label",   validate_rdns_id),
        "finder_extensions":  ("extension id",   validate_rdns_id),
        "quicklook_plugins":  ("ql plugin",      validate_ql_plugin_entry),
        "privileged_helpers": ("helper path",    validate_absolute_path),
        "login_items":        ("login item id",  validate_rdns_id),
        "containers":         ("container id",   validate_rdns_id),
    }

    for key, (desc, validator) in array_validators.items():
        value = manifest.get(key, [])
        if not isinstance(value, list):
            errors.append(f"'{key}' must be an array, got {type(value).__name__}")
            continue
        for i, item in enumerate(value):
            if not isinstance(item, str):
                errors.append(f"'{key}[{i}]' must be a string, got {type(item).__name__}")
                continue
            if not item.strip():
                errors.append(f"'{key}[{i}]' is empty")
                continue
            item_errors, item_warnings = validator(item, f"{key}[{i}]")
            errors.extend(item_errors)
            warnings.extend(item_warnings)

    # ── Cross-field checks
    paths = manifest.get("paths", [])
    quit_apps = manifest.get("apps_to_quit", [])
    for app in quit_apps:
        if app not in paths:
            warnings.append(
                f"'{app}' is in apps_to_quit but not in paths — "
                f"the app will be quit but its bundle won't be removed"
            )

    return errors, warnings


# ──────────────────────────────────────────────────────────────────────────────
# Path inference
# ──────────────────────────────────────────────────────────────────────────────

# Matches /Users/<username>/ — captures the relative remainder
_PER_USER_RE = re.compile(r'^/Users/[^/]+/(.+)$')

# Known per-user container directory stems (relative to ~/)
_CONTAINER_STEMS = ("Library/Containers/", "Library/Group Containers/")


def _extract_container_id(rel_path: str) -> str | None:
    """If rel_path is under a Containers dir, return the bundle ID (last component)."""
    for stem in _CONTAINER_STEMS:
        if rel_path.startswith(stem):
            remainder = rel_path[len(stem):]
            # bundle ID is the first (and usually only) component after the stem
            bundle_id = remainder.split("/")[0]
            if bundle_id:
                return bundle_id
    return None


def _extract_ql_plugin_path(rel_path: str) -> str | None:
    """If rel_path contains a .qlgenerator bundle, return the system-level QL path."""
    for component in rel_path.split("/"):
        if component.endswith(".qlgenerator"):
            return f"/Library/QuickLook/{component}"
    return None


def _probe_ql_extension(candidate: str) -> str | None:
    """
    Given a path or bundle-ID-like string, check if it corresponds to a
    registered QuickLook preview extension via pluginkit.

    Returns the bundle ID if confirmed as a QL extension, None otherwise.
    """
    import subprocess

    # Extract a bundle-ID-like string: last path component, no trailing slash
    probe_id = os.path.basename(candidate.rstrip("/"))

    # Must look like a reverse-DNS identifier (at least two dots)
    if probe_id.count(".") < 2:
        return None

    try:
        result = subprocess.run(
            ["pluginkit", "-m", "-p", "com.apple.quicklook.preview", "-i", probe_id],
            capture_output=True, text=True, timeout=5,
        )
        # pluginkit prints the bundle ID line if it matches, empty if not
        if probe_id in result.stdout:
            return probe_id
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return None


def classify_paths(args: argparse.Namespace) -> None:
    """
    Inspect path-bearing args and auto-route them to the right manifest arrays.

    For --path: /Users/<name>/... entries are stripped to relative paths and
    moved to profile_rel_paths.

    For --container: full paths are accepted — the bundle ID is extracted from
    the last component of the Containers directory. Per-user prefix is stripped.

    For --ql-plugin: full paths are accepted — if under /Users/<name>/, the
    .qlgenerator basename is extracted and a system-level path is inferred.
    Per-user QL paths also get added to profile_rel_paths for per-user cleanup.
    """

    # ── --path: split per-user vs system paths
    if args.path:
        keep_paths = []
        for p in args.path:
            m = _PER_USER_RE.match(p)
            if m:
                rel = m.group(1)
                # Check if it's actually a container
                cid = _extract_container_id(rel)
                if cid:
                    if args.container is None:
                        args.container = []
                    args.container.append(cid)
                    print(f"  ↳ container detected: '{p}' → containers: '{cid}'", file=sys.stderr)
                else:
                    if args.profile_path is None:
                        args.profile_path = []
                    args.profile_path.append(rel)
                    print(f"  ↳ per-user path detected: '{p}' → profile_rel_paths: '{rel}'", file=sys.stderr)
            else:
                keep_paths.append(p)
        args.path = keep_paths or None

    # ── --container: accept full paths or bare bundle IDs
    if args.container:
        normalized = []
        for c in args.container:
            m = _PER_USER_RE.match(c)
            if m:
                rel = m.group(1)
                cid = _extract_container_id(rel)
                if cid:
                    print(f"  ↳ container path detected: '{c}' → containers: '{cid}'", file=sys.stderr)
                    normalized.append(cid)
                else:
                    # Under /Users/ but not a known container stem — use basename
                    basename = os.path.basename(c)
                    print(f"  ↳ container path detected: '{c}' → containers: '{basename}'", file=sys.stderr)
                    normalized.append(basename)
            elif c.startswith("/"):
                # Absolute path but not under /Users/ — extract basename
                basename = os.path.basename(c)
                print(f"  ↳ container path detected: '{c}' → containers: '{basename}'", file=sys.stderr)
                normalized.append(basename)
            else:
                # Already a bare bundle ID
                normalized.append(c)
        args.container = normalized

    # ── --ql-plugin: accept .qlgenerator paths, full user paths, or bundle IDs
    #    Uses pluginkit to verify non-obvious candidates are real QL extensions.
    if args.ql_plugin:
        normalized = []
        for q in args.ql_plugin:
            m = _PER_USER_RE.match(q)
            if m:
                rel = m.group(1)
                ql_path = _extract_ql_plugin_path(rel)
                if ql_path:
                    # Legacy .qlgenerator under a user dir — promote to system path
                    print(f"  ↳ per-user QL plugin: '{q}' → quicklook_plugins: '{ql_path}'", file=sys.stderr)
                    normalized.append(ql_path)
                else:
                    # Not a .qlgenerator — probe pluginkit to see if it's a QL extension
                    confirmed_id = _probe_ql_extension(q)
                    if confirmed_id:
                        print(f"  ↳ QL extension confirmed via pluginkit: '{q}' → quicklook_plugins (id: '{confirmed_id}')", file=sys.stderr)
                        normalized.append(confirmed_id)
                    else:
                        # Genuinely not a QL plugin — route as per-user artifact
                        if args.profile_path is None:
                            args.profile_path = []
                        args.profile_path.append(rel)
                        print(f"  ↳ not a QL extension (pluginkit says no): '{q}' → profile_rel_paths: '{rel}'", file=sys.stderr)
            elif q.endswith(".qlgenerator") or q.startswith("/"):
                # System-level .qlgenerator path or other absolute path — keep as-is
                normalized.append(q)
            else:
                # Bare string — could be a bundle ID, verify with pluginkit
                confirmed_id = _probe_ql_extension(q)
                if confirmed_id:
                    print(f"  ↳ QL extension confirmed via pluginkit: '{q}'", file=sys.stderr)
                    normalized.append(confirmed_id)
                else:
                    print(f"  WARNING: '{q}' not recognized as a QL extension by pluginkit", file=sys.stderr)
                    normalized.append(q)  # pass through anyway, let validator catch it
        args.ql_plugin = normalized or None


# ──────────────────────────────────────────────────────────────────────────────
# Manifest building
# ──────────────────────────────────────────────────────────────────────────────

def build_manifest(args: argparse.Namespace) -> dict:
    """Construct a manifest dict from parsed CLI arguments."""
    manifest = OrderedDict()
    manifest["app_name"] = args.app_name

    # Only include arrays that have entries — keeps output clean
    if args.quit:
        manifest["apps_to_quit"] = args.quit
    if args.path:
        manifest["paths"] = args.path
    if args.profile_path:
        manifest["profile_rel_paths"] = args.profile_path
    if args.package:
        manifest["packages"] = args.package
    if args.launchagent:
        manifest["launch_agents"] = args.launchagent
    if args.launchdaemon:
        manifest["launch_daemons"] = args.launchdaemon
    if args.finder_ext:
        manifest["finder_extensions"] = args.finder_ext
    if args.ql_plugin:
        manifest["quicklook_plugins"] = args.ql_plugin
    if args.helper:
        manifest["privileged_helpers"] = args.helper
    if args.login_item:
        manifest["login_items"] = args.login_item
    if args.container:
        manifest["containers"] = args.container

    return manifest


# ──────────────────────────────────────────────────────────────────────────────
# Validate-only mode
# ──────────────────────────────────────────────────────────────────────────────

def run_validate(filepath: str) -> int:
    """Validate an existing JSON manifest file. Returns exit code."""
    if not os.path.isfile(filepath):
        print(f"ERROR: File not found: {filepath}", file=sys.stderr)
        return 1

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            manifest = json.load(f)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {filepath}: {e}", file=sys.stderr)
        return 1

    if not isinstance(manifest, dict):
        print(f"ERROR: Top-level value must be an object, got {type(manifest).__name__}", file=sys.stderr)
        return 1

    errors, warnings = validate_manifest(manifest)

    if warnings:
        print(f"\n⚠  Warnings ({len(warnings)}):", file=sys.stderr)
        for w in warnings:
            print(f"   {w}", file=sys.stderr)

    if errors:
        print(f"\n✖  Errors ({len(errors)}):", file=sys.stderr)
        for e in errors:
            print(f"   {e}", file=sys.stderr)
        print(f"\n{filepath}: INVALID", file=sys.stderr)
        return 1

    print(f"\n✔  {filepath}: VALID", file=sys.stderr)
    if not warnings:
        print("   No warnings.", file=sys.stderr)
    return 0


# ──────────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Build a JSON uninstall manifest for the universal uninstaller.",
        epilog=(
            "Examples:\n"
            '  %(prog)s --app-name "Vendor App" --path "/Applications/Vendor App.app" --package "com.vendor.app" --launchdaemon "com.vendor.daemon"\n'
            '  %(prog)s --validate existing_manifest.json\n'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    # ── Validate mode (mutually exclusive with build mode)
    parser.add_argument(
        "--validate",
        metavar="FILE",
        help="Validate an existing JSON manifest instead of building one",
    )

    # ── Build mode arguments
    parser.add_argument(
        "--app-name",
        help='Short display name (e.g., "Microsoft 365 Copilot")',
    )
    parser.add_argument(
        "--path",
        action="append",
        metavar="ABSPATH",
        help="Absolute path to remove (repeatable)",
    )
    parser.add_argument(
        "--profile-path",
        action="append",
        metavar="RELPATH",
        help="User-relative path to remove from all profiles (repeatable, no leading /)",
    )
    parser.add_argument(
        "--quit",
        action="append",
        metavar="APPPATH",
        help="App bundle path to quit before removal (repeatable)",
    )
    parser.add_argument(
        "--package",
        action="append",
        metavar="PKGID",
        help="Package receipt id to forget (repeatable)",
    )
    parser.add_argument(
        "--launchagent",
        action="append",
        metavar="LABEL",
        help="LaunchAgent plist label to unload+remove (repeatable)",
    )
    parser.add_argument(
        "--launchdaemon",
        action="append",
        metavar="LABEL",
        help="LaunchDaemon plist label to unload+remove (repeatable)",
    )
    parser.add_argument(
        "--finder-ext",
        action="append",
        metavar="BUNDLEID",
        help="Finder extension bundle id to remove (repeatable)",
    )
    parser.add_argument(
        "--ql-plugin",
        action="append",
        metavar="ABSPATH",
        help="QuickLook plugin path to remove, e.g. /Library/QuickLook/Foo.qlgenerator (repeatable)",
    )
    parser.add_argument(
        "--helper",
        action="append",
        metavar="ABSPATH",
        help="Privileged helper tool path to remove, e.g. /Library/PrivilegedHelperTools/com.vendor.helper (repeatable)",
    )
    parser.add_argument(
        "--login-item",
        action="append",
        metavar="IDENTIFIER",
        help="Login item identifier to detect and remove (repeatable)",
    )
    parser.add_argument(
        "--container",
        action="append",
        metavar="BUNDLEID",
        help="App container bundle id — removed from all user profiles (repeatable)",
    )
    parser.add_argument(
        "--output", "-o",
        metavar="FILE",
        help="Write manifest to FILE (default: stdout)",
    )

    args = parser.parse_args()

    # ── Validate mode
    if args.validate:
        sys.exit(run_validate(args.validate))

    # ── Build mode: require --app-name
    if not args.app_name:
        parser.error("--app-name is required when building a manifest (or use --validate FILE)")

    classify_paths(args)
    manifest = build_manifest(args)

    # ── Validate before output
    errors, warnings = validate_manifest(manifest)

    if warnings:
        print(f"\n⚠  Warnings ({len(warnings)}):", file=sys.stderr)
        for w in warnings:
            print(f"   {w}", file=sys.stderr)
        print("", file=sys.stderr)

    if errors:
        print(f"\n✖  Errors ({len(errors)}):", file=sys.stderr)
        for e in errors:
            print(f"   {e}", file=sys.stderr)
        print("\nManifest NOT written due to errors.", file=sys.stderr)
        sys.exit(1)

    # ── Serialize
    json_str = json.dumps(manifest, indent=2, ensure_ascii=False)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(json_str + "\n")
        print(f"✔  Manifest written to: {args.output}", file=sys.stderr)
    else:
        print(json_str)


if __name__ == "__main__":
    main()
