#!/bin/bash
# reset_test_apps.sh — Install (or reinstall) the four MUCK test applications.
#
# Expects a directory containing the installer files:
#   - SuspiciousPackage.dmg       (DMG — mount, copy .app)
#   - santa-*.pkg  OR  santa.pkg  (PKG — installer)
#   - Nextcloud-*.pkg OR Nextcloud.pkg  (PKG — non-VFS installer)
#   - Privileges-*.pkg OR Privileges.pkg (PKG — installer)
#
# Usage:
#   sudo ./tools/reset_test_apps.sh /path/to/installers/
#   sudo ./tools/reset_test_apps.sh ~/Downloads/muck-test-installers/
#
# What it does:
#   1. Runs each test app's uninstall manifest (if the app is present) to clean up
#   2. Installs each app fresh from the provided installers
#   3. Opens each app briefly so it creates its artifacts (containers, agents, etc.)
#   4. Waits for artifacts to settle, then closes the apps
#
# This gives you a clean slate for testing uninstaller manifests.

set -euo pipefail

PREFIX="reset_test_apps.sh"

# ── Require root
if [[ "$(id -u)" -ne 0 ]]; then
    echo "$PREFIX — ERROR: Must run as root (sudo)." >&2
    exit 3
fi

# ── Require installer directory
INSTALLER_DIR="${1:-}"
if [[ -z "$INSTALLER_DIR" || ! -d "$INSTALLER_DIR" ]]; then
    echo "$PREFIX — ERROR: Provide a directory containing installer files." >&2
    echo "Usage: sudo $0 /path/to/installers/" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UNINSTALLER="$SCRIPT_DIR/src/uninstaller.sh"
MANIFESTS_DIR="$SCRIPT_DIR/manifests/examples"

# ── Helper: find a file matching a glob in the installer dir
find_installer() {
    local pattern="$1"
    local match
    # Use compgen for glob expansion (bash 3 safe alternative below)
    for f in "$INSTALLER_DIR"/$pattern; do
        if [[ -f "$f" ]]; then
            echo "$f"
            return 0
        fi
    done
    return 1
}

# ── Helper: install a PKG
install_pkg() {
    local pkg_path="$1"
    local app_name="$2"
    echo "$PREFIX — Installing $app_name from $(basename "$pkg_path")..."
    /usr/sbin/installer -pkg "$pkg_path" -target / -verboseR 2>&1 | \
        sed "s/^/$PREFIX —   /"
    echo "$PREFIX — $app_name installed."
}

# ── Helper: install from DMG (mount, copy .app, unmount)
install_dmg() {
    local dmg_path="$1"
    local app_name="$2"
    local mount_point

    echo "$PREFIX — Mounting $(basename "$dmg_path")..."
    mount_point=$(/usr/bin/hdiutil attach "$dmg_path" -nobrowse -noverify -noautoopen \
        | tail -1 | awk '{print $NF}')

    if [[ -z "$mount_point" || ! -d "$mount_point" ]]; then
        echo "$PREFIX — ERROR: Failed to mount $dmg_path" >&2
        return 1
    fi

    echo "$PREFIX — Mounted at: $mount_point"

    # Find the .app inside
    local app_bundle
    app_bundle=$(find "$mount_point" -maxdepth 2 -name "*.app" -type d | head -1)

    if [[ -z "$app_bundle" ]]; then
        echo "$PREFIX — ERROR: No .app found in $mount_point" >&2
        /usr/bin/hdiutil detach "$mount_point" -quiet
        return 1
    fi

    echo "$PREFIX — Copying $(basename "$app_bundle") to /Applications/..."
    /bin/cp -R "$app_bundle" /Applications/
    /usr/bin/hdiutil detach "$mount_point" -quiet
    echo "$PREFIX — $app_name installed."
}

# ── Helper: open app and wait for artifacts to settle
launch_briefly() {
    local app_path="$1"
    local wait_seconds="${2:-5}"

    if [[ ! -d "$app_path" ]]; then
        echo "$PREFIX — WARNING: $app_path not found, skipping launch."
        return 0
    fi

    echo "$PREFIX — Opening $app_path for $wait_seconds seconds..."
    /usr/bin/open -a "$app_path"
    sleep "$wait_seconds"

    # Quit gracefully
    local app_name
    app_name=$(basename "$app_path" .app)
    /usr/bin/osascript -e "tell application \"$app_name\" to quit" 2>/dev/null || true
    sleep 1
    echo "$PREFIX — Closed $app_name."
}

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  MUCK Test App Reset"
echo "  Installer dir: $INSTALLER_DIR"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ──────────────────────────────────────────────────────────────
# Phase 1: Clean up existing installs
# ──────────────────────────────────────────────────────────────
echo "$PREFIX — Phase 1: Cleaning up existing installs..."
echo ""

for manifest in "$MANIFESTS_DIR"/*.json; do
    name=$(basename "$manifest" .json)
    app_check=$(python3 -c "import json; m=json.load(open('$manifest')); print(m.get('paths',[''])[0])" 2>/dev/null)

    if [[ -n "$app_check" && -d "$app_check" ]]; then
        echo "$PREFIX — Removing existing $name..."
        "$UNINSTALLER" "$manifest" 2>&1 | tail -3 | sed "s/^/$PREFIX —   /"
    else
        echo "$PREFIX — $name not installed, skipping cleanup."
    fi
done

echo ""

# ──────────────────────────────────────────────────────────────
# Phase 2: Install fresh
# ──────────────────────────────────────────────────────────────
echo "$PREFIX — Phase 2: Installing test apps..."
echo ""

# Suspicious Package (DMG)
sp_dmg=$(find_installer "SuspiciousPackage*.dmg" 2>/dev/null || find_installer "Suspicious*Package*.dmg" 2>/dev/null) || true
if [[ -n "$sp_dmg" ]]; then
    install_dmg "$sp_dmg" "Suspicious Package"
else
    echo "$PREFIX — WARNING: No Suspicious Package DMG found. Skipping."
fi

# Santa (PKG)
santa_pkg=$(find_installer "santa*.pkg" 2>/dev/null || find_installer "Santa*.pkg" 2>/dev/null) || true
if [[ -n "$santa_pkg" ]]; then
    install_pkg "$santa_pkg" "Santa"
else
    echo "$PREFIX — WARNING: No Santa PKG found. Skipping."
fi

# Nextcloud (PKG)
nc_pkg=$(find_installer "Nextcloud*.pkg" 2>/dev/null || find_installer "nextcloud*.pkg" 2>/dev/null) || true
if [[ -n "$nc_pkg" ]]; then
    install_pkg "$nc_pkg" "Nextcloud"
else
    echo "$PREFIX — WARNING: No Nextcloud PKG found. Skipping."
fi

# Privileges (PKG)
priv_pkg=$(find_installer "Privileges*.pkg" 2>/dev/null || find_installer "privileges*.pkg" 2>/dev/null) || true
if [[ -n "$priv_pkg" ]]; then
    install_pkg "$priv_pkg" "Privileges"
else
    echo "$PREFIX — WARNING: No Privileges PKG found. Skipping."
fi

echo ""

# ──────────────────────────────────────────────────────────────
# Phase 3: Launch briefly to create artifacts
# ──────────────────────────────────────────────────────────────
echo "$PREFIX — Phase 3: Launching apps to generate artifacts..."
echo ""

launch_briefly "/Applications/Suspicious Package.app" 3
launch_briefly "/Applications/Santa.app" 5
launch_briefly "/Applications/Nextcloud.app" 8
launch_briefly "/Applications/Privileges.app" 5

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Reset complete. All test apps installed and launched."
echo "  Run the uninstaller tests now."
echo "═══════════════════════════════════════════════════════════"
