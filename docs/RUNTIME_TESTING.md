# Runtime Testing Plan — macOS Universal Uninstaller

This document outlines runtime (integration/system) testing strategies for all major functions in the uninstaller script. Unlike unit testing which uses mocks, runtime testing requires putting an actual macOS system in specific states to generate the expected return codes and verify real-world behavior.

## Return Code Scheme

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | Operation completed successfully (or target absent with `--tolerant-missing`) |
| 1 | Generic Failure | Internal error, missing tool, or unexpected failure |
| 2 | Bad Input | Missing args, unknown flag, invalid format, duplicate flag |
| 3 | Needs Root | Function requires root but EUID != 0 (when `--needs-root` specified) |
| 4 | Not Present (Strict) | Target not found and `--tolerant-missing` NOT specified |
| 5 | Operation Failed | Action attempted but verify-after shows it didn't take |

---

## Test Environment Setup

### Prerequisites
- macOS 13+ (Ventura or later) for `sfltool` support
- Root/sudo access for most operations
- Test user account with graphical login
- Clean test VM or isolated test machine recommended

### Test Preparation Script
```bash
#!/bin/bash
# setup_test_environment.sh
# Run this to prepare a test system

# Create test directories
sudo mkdir -p /tmp/test_uninstaller/Library/LaunchAgents
sudo mkdir -p /tmp/test_uninstaller/Library/LaunchDaemons
sudo mkdir -p /tmp/test_uninstaller/Library/PrivilegedHelperTools
sudo mkdir -p /tmp/test_uninstaller/Library/QuickLook
sudo mkdir -p "/tmp/test_uninstaller/Applications/TestApp.app"

# Create test user (if needed)
# sudo dscl . -create /Users/testuser
# sudo dscl . -create /Users/testuser RealName "Test User"
# sudo dscl . -create /Users/testuser UniqueID 502
# sudo dscl . -create /Users/testuser PrimaryGroupID 20
# sudo dscl . -create /Users/testuser NFSHomeDirectory /Users/testuser
# sudo dscl . -create /Users/testuser UserShell /bin/bash
# sudo dscl . -append Groups admin
```

---

## Function Runtime Test Plans

### 1. ForgetPackage

**Purpose:** Remove a macOS package receipt using `pkgutil --forget`.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — present pkg | Install a test package: `pkgutil --pkg-info com.test.pkg` (must exist) | Run `pkgutil --pkg-info com.test.pkg` — should return "No package ID found" |
| Happy path — tolerant missing | Use a non-existent package ID | `pkgutil --pkg-info com.missing.pkg` returns "No package ID found" |
| Not present — strict | Same as above | Same verification |
| Needs root | Run script without sudo | Script exits with rc 3, error message printed |

#### Commands to Verify State
```bash
# Check if package receipt exists
pkgutil --pkg-info <package_id>

# List all receipts
pkgutil --pkgs | grep <pattern>
```

---

### 2. QuitAppByPath

**Purpose:** Quit an application by bundle path, binary path, process name, or PID.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — bundle quit | Launch app: `open /Applications/TestApp.app` | `pgrep -x TestApp` returns PID before, nothing after |
| Happy path — not running | Ensure app is not running | `pgrep -x TestApp` returns nothing |
| Happy path — PID kill | Find a test process: `ps aux | grep testproc` | `kill -0 <pid>` returns 0 before, 1 after |
| Happy path — process name | Start background process: `sleep 1000 &` | `pgrep -f sleep` returns PID before, nothing after |
| Not present — strict | Point to non-existent .app bundle | Bundle path check fails |

#### Commands to Verify State
```bash
# Check if app is running
pgrep -x <process_name>

# Check if PID exists
kill -0 <pid>

# List processes
ps aux | grep <pattern>
```

---

### 3. SafeRemovePath

**Purpose:** Walk a path bottom-up and delete all elements safely.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — directory tree | Create tree: `mkdir -p /tmp/test/a/b/c && touch /tmp/test/a/b/c/file` | `ls -la /tmp/test` returns nothing |
| Happy path — tolerant missing | Use non-existent path | Path does not exist (no error) |
| Happy path — symlink | Create symlink: `ln -s /tmp/target /tmp/link` | `ls -la /tmp/link` returns "No such file" |
| Happy path — single file | Create file: `touch /tmp/testfile` | `ls /tmp/testfile` returns "No such file" |
| Not present — strict | Same as tolerant missing | Same verification |
| Operation failed — verify | Create file with immutable flag: `chflags uchg /tmp/protected` | `ls -lO /tmp/protected` shows "uchg" flag |

#### Commands to Verify State
```bash
# Check if path exists
ls -la <path>

# Check for immutable flags
ls -lO <path>

# Remove immutable flag (cleanup)
sudo chflags nouchg <path>
```

---

### 4. DisableLaunchAgent

**Purpose:** Disable a LaunchAgent via `launchctl disable` for all graphical users.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — single user | Create plist in ~/Library/LaunchAgents, load it | `launchctl print-disabled gui/<uid>` shows `label => true` |
| Happy path — multiple users | Create plist for each test user | Same verification for each user |
| Happy path — tolerant missing | Use non-existent label | `launchctl print gui/<uid>/<label>` shows "Could not find service" |
| Not present — strict | Same as tolerant missing | Same verification |
| Operation failed — verify | Mock launchctl to always show enabled | `launchctl print-disabled` still shows `label => false` |

#### System Setup Commands
```bash
# Create test LaunchAgent plist
cat > ~/Library/LaunchAgents/com.test.agent.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.test.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sleep</string>
        <string>3600</string>
    </array>
</dict>
</plist>
EOF

# Load the agent
launchctl load ~/Library/LaunchAgents/com.test.agent.plist

# Verify it's loaded
launchctl print gui/<uid>/com.test.agent
```

#### Commands to Verify State
```bash
# Check if agent is disabled
launchctl print-disabled gui/<uid> | grep <label>

# Check if agent is loaded
launchctl print gui/<uid>/<label>
```

---

### 5. DisableLaunchDaemon

**Purpose:** Disable a LaunchDaemon via `launchctl disable` in system domain.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — present | Create plist in /Library/LaunchDaemons, load it | `launchctl print-disabled system` shows `label => true` |
| Happy path — tolerant missing | Use non-existent label | `launchctl print system/<label>` shows "Could not find service" |
| Not present — strict | Same as tolerant missing | Same verification |
| Needs root | Run script without sudo | Script exits with rc 3 |

#### System Setup Commands
```bash
# Create test LaunchDaemon plist
sudo cat > /Library/LaunchDaemons/com.test.daemon.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.test.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sleep</string>
        <string>3600</string>
    </array>
</dict>
</plist>
EOF

# Load the daemon
sudo launchctl load /Library/LaunchDaemons/com.test.daemon.plist

# Verify it's loaded
sudo launchctl print system/com.test.daemon
```

#### Commands to Verify State
```bash
# Check if daemon is disabled
sudo launchctl print-disabled system | grep <label>

# Check if daemon is loaded
sudo launchctl print system/<label>
```

---

### 6. UnloadAndRemoveLaunchAgent

**Purpose:** Disable, unload, and remove a LaunchAgent plist by label.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — system agent | Create plist in /Library/LaunchAgents | Plist file gone, `launchctl print` shows not found |
| Happy path — user agent | Create plist in ~/Library/LaunchAgents | Plist file gone for that user |
| Happy path — tolerant missing | Use non-existent label | Label not found (rc 0 due to tolerance) |
| Not present — strict | Same as tolerant missing | Label not found (rc 4) |
| Operation failed — bootout | Agent running, cannot be unloaded | `launchctl print gui/<uid>/<label>` shows still running |

#### Commands to Verify State
```bash
# Check if plist exists
ls -la /Library/LaunchAgents/<label>.plist
ls -la ~/Library/LaunchAgents/<label>.plist

# Check if agent is unloaded
launchctl print gui/<uid>/<label>
```

---

### 7. UnloadAndRemoveLaunchDaemon

**Purpose:** Disable, unload, and remove a LaunchDaemon plist by label.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — present | Create plist in /Library/LaunchDaemons | Plist file gone, `launchctl print` shows not found |
| Happy path — tolerant missing | Use non-existent label | Label not found (rc 0 due to tolerance) |
| Not present — strict | Same as tolerant missing | Label not found (rc 4) |
| Needs root | Run script without sudo | Script exits with rc 3 |

#### Commands to Verify State
```bash
# Check if plist exists
ls -la /Library/LaunchDaemons/<label>.plist

# Check if daemon is unloaded
sudo launchctl print system/<label>
```

---

### 8. RemoveFinderExtension

**Purpose:** Disable and unregister a Finder Sync extension via `pluginkit`.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — registered | Install app with Finder Sync extension | `pluginkit -m -i <bundle_id>` returns empty |
| Happy path — tolerant missing | Use non-registered bundle ID | `pluginkit -m -i <bundle_id>` returns empty |
| Not present — strict | Same as tolerant missing | `pluginkit -m -i <bundle_id>` returns empty (rc 4) |
| Operation failed — verify | Mock pluginkit to always show registered | `pluginkit -m -i <bundle_id>` still returns info |

#### System Setup Commands
```bash
# Check if extension is registered
pluginkit -m -i <bundle_id>

# List all registered Finder extensions
pluginkit -m -i -s finder-sync
```

**Note:** To test with a real Finder Sync extension, you need to:
1. Build an app with a Finder Sync extension
2. Install it on the test system
3. Enable it in System Settings > Extensions > Finder Extensions

---

### 9. RemoveQuickLookPlugin

**Purpose:** Remove a QuickLook generator plugin from disk.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — present | Create test plugin: `mkdir /Library/QuickLook/test.qlgenerator` | `ls /Library/QuickLook/test.qlgenerator` returns "No such file" |
| Happy path — tolerant missing | Use non-existent plugin path | Path does not exist (rc 0 due to tolerance) |
| Not present — strict | Same as tolerant missing | Path does not exist (rc 4) |
| Bad input — not .qlgenerator | Use path ending in .app or other | Validation fails before removal |

#### System Setup Commands
```bash
# Create test QuickLook plugin directory
sudo mkdir -p /Library/QuickLook/test.qlgenerator
sudo touch /Library/QuickLook/test.qlgenerator/placeholder

# Verify plugin exists
ls -la /Library/QuickLook/test.qlgenerator

# List all registered generators
qlmanage -m | grep -i test
```

---

### 10. RemovePrivilegedHelper

**Purpose:** Remove a PrivilegedHelperTool binary from `/Library/PrivilegedHelperTools/`.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — present | Create test helper: `touch /Library/PrivilegedHelperTools/com.test.helper` | `ls /Library/PrivilegedHelperTools/com.test.helper` returns "No such file" |
| Happy path — tolerant missing | Use non-existent helper path | Path does not exist (rc 0 due to tolerance) |
| Not present — strict | Same as tolerant missing | Path does not exist (rc 4) |
| Bad input — not under dir | Use path outside /Library/PrivilegedHelperTools/ | Validation fails before removal |

#### System Setup Commands
```bash
# Create test helper binary (placeholder)
sudo touch /Library/PrivilegedHelperTools/com.test.helper
sudo chmod 755 /Library/PrivilegedHelperTools/com.test.helper

# Verify helper exists
ls -la /Library/PrivilegedHelperTools/com.test.helper
```

---

### 11. IdentifyLoginItemType

**Purpose:** Detect the persistence mechanism underlying a login/background item.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — daemon | Create LaunchDaemon, add to BTM | Output: `TYPE=daemon PATH=/Library/LaunchDaemons/...` |
| Happy path — agent | Create LaunchAgent, add to BTM | Output: `TYPE=agent PATH=/Library/LaunchAgents/...` |
| Happy path — login_item | Register app as login item | Output: `TYPE=login_item PATH=file:///Applications/...` |
| Happy path — app | Register app in BTM | Output: `TYPE=app PATH=file:///Applications/...` |
| Not present — strict | Use non-existent identifier | Output: "Identifier not found in BTM database" (rc 4) |
| Needs root | Run script without sudo | Script exits with rc 3 |

#### System Setup Commands
```bash
# Dump BTM database to see current entries
sudo sfltool dumpbtm

# Note: There is no public API to add entries to BTM
# Test entries are created by:
# - Installing apps with login items
# - Using SMAppService API
# - Legacy login item registration
```

**Important:** The BTM database is populated by macOS itself when:
- Apps register via SMAppService
- Apps register as login items via System Preferences
- Legacy login item APIs are used

To test different types, you need to install apps that use each mechanism.

---

### 12. RemoveLoginItems

**Purpose:** Remove login/background items by auto-routing to correct removal function.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — daemon route | Create LaunchDaemon in BTM | Daemon plist removed, BTM entry gone |
| Happy path — agent route | Create LaunchAgent in BTM | Agent plist removed, BTM entry gone |
| Happy path — helper route | Create helper in BTM | Helper binary removed |
| Happy path — app route | Register app in BTM | App bundle removed |
| Not present — strict | Use non-existent identifier | Identifier not found (rc 4) |

#### Verification Commands
```bash
# Before removal
sudo sfltool dumpbtm | grep -A 10 <identifier>

# After removal
sudo sfltool dumpbtm | grep <identifier>
# Should return nothing
```

---

### 13. ParseInput

**Purpose:** Route input source and populate config arrays.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — manifest mode | Create valid JSON manifest file | Arrays populated from manifest |
| Happy path — CLI flags | Run with --flags | Arrays populated from flags |
| Happy path — Jamf mode | Run with $4="jamf=true" | Arrays populated from params |
| Happy path — fallback | Run with no input | Hardcoded arrays preserved |
| Bad input — manifest missing | Use non-existent manifest path | Script exits with rc 2 |

#### Test Commands
```bash
# Create test manifest
cat > /tmp/test_manifest.json << 'EOF'
{
  "app_name": "Test App",
  "paths": ["/tmp/test1", "/tmp/test2"],
  "packages": ["com.test.app"]
}
EOF

# Run with manifest
./uninstaller.sh --manifest=/tmp/test_manifest.json

# Run with CLI flags
./uninstaller.sh --app-name="Test" --paths="/tmp/test1"

# Run in Jamf mode (simulate)
./uninstaller.sh "mountpoint" "hostname" "username" "jamf=true" "AppName" "paths" "pkgs"
```

---

### 14. ParseManifestJSON

**Purpose:** Parse a JSON manifest file using plutil.

#### System States to Create

| Test Case | How to Set Up System | Verification |
|-----------|---------------------|--------------|
| Happy path — valid JSON | Create valid JSON manifest | Arrays populated |
| Happy path — empty arrays | Create manifest with empty arrays | Arrays remain empty |
| Bad input — file not found | Use non-existent path | Script exits with rc 2 |
| Operation failed — invalid JSON | Create malformed JSON | Script exits with rc 1 |

#### Test Commands
```bash
# Create valid manifest
cat > /tmp/valid.json << 'EOF'
{
  "app_name": "Test",
  "paths": ["/tmp/test"]
}
EOF

# Create invalid JSON
cat > /tmp/invalid.json << 'EOF'
{
  "app_name": "Test"
  missing_comma: true
}
EOF

# Test plutil parsing
plutil -convert json -o - /tmp/valid.json
plutil -convert json -o - /tmp/invalid.json
```

---

## Full Integration Test Scenarios

### Scenario 1: Complete Uninstall of Test Application

**Setup:**
```bash
# Create a test application structure
sudo mkdir -p "/Applications/TestApp.app/Contents/MacOS"
sudo touch "/Applications/TestApp.app/Contents/MacOS/testapp"
sudo chmod 755 "/Applications/TestApp.app/Contents/MacOS/testapp"

# Create LaunchAgent
sudo mkdir -p /Library/LaunchAgents
sudo cat > /Library/LaunchAgents/com.test.app.agent.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.test.app.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/TestApp.app/Contents/MacOS/testapp</string>
    </array>
</dict>
</plist>
EOF

# Create package receipt (simulate)
# Note: Cannot easily create real receipts without installing a package

# Create QuickLook plugin
sudo mkdir -p /Library/QuickLook/TestApp.qlgenerator
sudo touch /Library/QuickLook/TestApp.qlgenerator/placeholder
```

**Execute:**
```bash
# Run uninstaller with test app configuration
./uninstaller.sh --app-name="TestApp" \
  --paths="/Applications/TestApp.app" \
  --agents="com.test.app.agent" \
  --ql-plugins="/Library/QuickLook/TestApp.qlgenerator"
```

**Verify:**
```bash
# Check all artifacts removed
ls -la "/Applications/TestApp.app"           # Should not exist
ls -la /Library/LaunchAgents/com.test.app.agent.plist  # Should not exist
ls -la /Library/QuickLook/TestApp.qlgenerator          # Should not exist
```

---

## Cleanup Script

```bash
#!/bin/bash
# cleanup_test_environment.sh
# Run this to clean up test artifacts

# Remove test directories
sudo rm -rf /tmp/test_uninstaller
sudo rm -rf /tmp/test*

# Remove test LaunchAgents
sudo rm -f /Library/LaunchAgents/com.test.*.plist
rm -f ~/Library/LaunchAgents/com.test.*.plist

# Remove test LaunchDaemons
sudo rm -f /Library/LaunchDaemons/com.test.*.plist

# Remove test QuickLook plugins
sudo rm -rf /Library/QuickLook/TestApp.qlgenerator
sudo rm -rf /Library/QuickLook/test.qlgenerator

# Remove test helpers
sudo rm -f /Library/PrivilegedHelperTools/com.test.*

# Remove test apps
sudo rm -rf "/Applications/TestApp.app"

# Reset BTM database (nuclear option - use with caution)
# sudo sfltool resetbtm
```

---

## Test Reporting

For each runtime test, record:

| Field | Description |
|-------|-------------|
| Test Case | Name of the test scenario |
| macOS Version | e.g., "macOS 15.3 (Sequoia)" |
| Setup Steps | How the test environment was prepared |
| Command Executed | The exact uninstaller command run |
| Return Code | Actual rc returned |
| Expected rc | What rc was expected |
| Verification | Commands run to verify outcome |
| Actual Outcome | What actually happened |
| Pass/Fail | Whether test passed |
| Notes | Any additional observations |