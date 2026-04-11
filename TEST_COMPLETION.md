# Test Completion Plan: Eliminating All ShellSpec Skips

## Overview

This document outlines the infrastructure needed to achieve **0 skips** in the ShellSpec test suite. Currently we have 367 examples with 0 failures and 216 skips. The goal is to create mocking wrappers and test infrastructure that allows all tests to execute.

## Skip Categories and Solutions

### 1. Root Execution Context (42 skips)

**Problem:** Tests need to verify root guards but run as non-root.

**Solution:** Create EUID wrapper scripts

```bash
# tools/mock_euid_nonroot.sh
#!/bin/bash
# Wrapper that fakes EUID=1000 (non-root)
export FAKE_EUID=1000
export EUID=1000
export UID=1000
exec "$@"

# tools/mock_euid_root.sh  
#!/bin/bash
# Wrapper that fakes EUID=0 (root)
export FAKE_EUID=0
export EUID=0
export UID=0
exec "$@"
```

**Implementation in spec_helper.sh:**
```bash
# Detect which EUID mode to use
if [[ -n "$TEST_AS_ROOT" ]]; then
    # Source with root EUID
    EUID=0
    UID=0
    export EUID UID
fi
```

**Modified functions:** Update functions to check `FAKE_EUID` first:
```bash
# In each function that checks root
if [[ -n "${FAKE_EUID:-}" ]]; then
    effective_euid=$FAKE_EUID
else
    effective_euid=$EUID
fi
if [[ $effective_euid -ne 0 ]]; then
    # Root check fails
fi
```

---

### 2. Tool Presence Mocking (68 skips)

**Problem:** Tests need to simulate missing or failing tools.

**Solution:** Create tool wrapper directory with controllable behavior

```bash
# tools/mock_bin/launchctl.sh
#!/bin/bash
# launchctl wrapper - behavior controlled by environment
MOCK_LAUNCHCTL_MODE="${MOCK_LAUNCHCTL_MODE:-normal}"

case "$MOCK_LAUNCHCTL_MODE" in
    missing)
        exit 127 ;;  # Command not found
    fail)
        echo "launchctl: operation failed" >&2
        exit 1 ;;
    not_found)
        echo "Could not find service: $*" >&2
        exit 1 ;;
    *)
        # Normal behavior - delegate to real launchctl
        /bin/launchctl "$@" ;;
esac
```

**Wrapper scripts for each tool:**

```bash
# tools/mock_bin/pkill.sh
#!/bin/bash
MOCK_PKILL_MODE="${MOCK_PKILL_MODE:-normal}"
case "$MOCK_PKILL_MODE" in
    missing) exit 127 ;;
    fail) exit 1 ;;
    *) /usr/bin/pkill "$@" ;;
esac

# tools/mock_bin/pgrep.sh
#!/bin/bash
MOCK_PGREP_MODE="${MOCK_PGREP_MODE:-normal}"
case "$MOCK_PGREP_MODE" in
    missing) exit 127 ;;
    running) exit 0 ;;  # Process found
    not_running) exit 1 ;;  # Process not found
    *) /usr/bin/pgrep "$@" ;;
esac

# tools/mock_bin/kill.sh
#!/bin/bash
MOCK_KILL_MODE="${MOCK_KILL_MODE:-normal}"
case "$MOCK_KILL_MODE" in
    missing) exit 127 ;;
    fail) exit 1 ;;
    *) /bin/kill "$@" ;;
esac

# tools/mock_bin/PlistBuddy.sh
#!/bin/bash
MOCK_PLISTB_MODE="${MOCK_PLISTB_MODE:-normal}"
case "$MOCK_PLISTB_MODE" in
    missing) exit 127 ;;
    fail) 
        echo "No such key" >&2
        exit 2 ;;
    *) /usr/libexec/PlistBuddy "$@" ;;
esac

# tools/mock_bin/pkgutil.sh
#!/bin/bash
MOCK_PKGUTIL_MODE="${MOCK_PKGUTIL_MODE:-normal}"
case "$MOCK_PKGUTIL_MODE" in
    missing) exit 127 ;;
    forget_fail)
        echo "pkgutil: forget failed" >&2
        exit 1 ;;
    *) /usr/sbin/pkgutil "$@" ;;
esac
```

**Spec file integration:**
```bash
# At top of spec files
PATH="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin:$PATH"

# Set mock mode before tests
export MOCK_LAUNCHCTL_MODE="not_found"
export MOCK_PKILL_MODE="normal"
```

---

### 3. File System Mocking (24 skips)

**Problem:** Tests need fake .app bundles and file existence states.

**Solution:** Create temporary test directories with mock bundles

```bash
# tools/create_mock_bundle.sh
#!/bin/bash
# Create a mock .app bundle at specified path
BUNDLE_PATH="$1"
EXECUTABLE_NAME="${2:-TestApp}"

mkdir -p "$BUNDLE_PATH/Contents/MacOS"
mkdir -p "$BUNDLE_PATH/Contents/Resources"

# Create Info.plist with CFBundleExecutable
cat > "$BUNDLE_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.test.app</string>
    <key>CFBundleName</key>
    <string>TestApp</string>
</dict>
</plist>
EOF

# Create dummy executable
touch "$BUNDLE_PATH/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$BUNDLE_PATH/Contents/MacOS/$EXECUTABLE_NAME"
```

**Spec file integration:**
```bash
# In spec_helper.sh or individual specs
TEST_TMP_DIR=$(mktemp -d)
MOCK_BUNDLE="$TEST_TMP_DIR/Test.app"

# Setup before tests
create_mock_bundle "$MOCK_BUNDLE" "TestExecutable"

# Cleanup after tests
trap "rm -rf $TEST_TMP_DIR" EXIT
```

**For non-existent file tests:**
```bash
# Just use paths that don't exist
NONEXISTENT_PATH="/tmp/does_not_exist_$(date +%s).app"
# No need to create it - function should handle absence
```

---

### 4. Process State Mocking (18 skips)

**Problem:** Tests need to simulate processes running/not running.

**Solution:** Use pgrep wrapper with controllable output

```bash
# tools/mock_bin/pgrep.sh (enhanced)
#!/bin/bash
MOCK_PGREP_MODE="${MOCK_PGREP_MODE:-normal}"
MOCK_PGREP_PID="${MOCK_PGREP_PID:-}"

case "$MOCK_PGREP_MODE" in
    running)
        # Always return success (process running)
        exit 0 ;;
    not_running)
        # Always return failure (process not running)
        exit 1 ;;
    specific_pid)
        # Return specific PID if matching
        if [[ -n "$MOCK_PGREP_PID" ]]; then
            echo "$MOCK_PGREP_PID"
            exit 0
        fi
        exit 1 ;;
    *)
        /usr/bin/pgrep "$@" ;;
esac
```

**For verify-after tests (process still running):**
```bash
# Mock pgrep to return running for first N calls, then not running
# Use a counter file
COUNTER_FILE="/tmp/pgrep_counter_$$"
touch "$COUNTER_FILE"

# tools/mock_bin/pgrep.sh (counter version)
#!/bin/bash
COUNTER_FILE="/tmp/pgrep_counter_$$"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)

if [[ $COUNT -lt 10 ]]; then
    # First 10 calls: process running
    echo $((COUNT + 1)) > "$COUNTER_FILE"
    exit 0
else
    # After 10 calls: process not running
    rm -f "$COUNTER_FILE"
    exit 1
fi
```

---

### 5. Output Format Mocking (32 skips)

**Problem:** Tests need specific tool output formats.

**Solution:** Create output-controlled wrappers

```bash
# tools/mock_bin/sfltool.sh
#!/bin/bash
MOCK_SFLTOOL_MODE="${MOCK_SFLTOOL_MODE:-normal}"
MOCK_SFLTOOL_OUTPUT="${MOCK_SFLTOOL_OUTPUT:-}"

case "$MOCK_SFLTOOL_MODE" in
    missing)
        exit 127 ;;
    not_found)
        # Empty output - identifier not in BTM
        exit 0 ;;
    custom)
        echo "$MOCK_SFLTOOL_OUTPUT"
        exit 0 ;;
    daemon)
        # Return daemon-type BTM entry
        cat << 'EOF'
#1:
  Type:            legacy daemon (0x00000001)
  Disposition:     enabled,allowed,visible
  Identifier:      com.test.daemon
  URL:             file:///Library/LaunchDaemons/com.test.daemon.plist
EOF
        exit 0 ;;
    agent)
        # Return agent-type BTM entry
        cat << 'EOF'
#1:
  Type:            legacy agent (0x00000002)
  Disposition:     enabled,allowed
  Identifier:      com.test.agent
  URL:             file:///Library/LaunchAgents/com.test.agent.plist
EOF
        exit 0 ;;
    helper)
        # Return helper-type BTM entry
        cat << 'EOF'
#1:
  Type:            developer (0x00000004)
  Disposition:     enabled,allowed,visible
  Identifier:      com.test.helper
  URL:             file:///Library/PrivilegedHelperTools/com.test.helper
EOF
        exit 0 ;;
    app)
        # Return app-type BTM entry
        cat << 'EOF'
#1:
  Type:            app (0x00000008)
  Disposition:     enabled
  Identifier:      com.test.app
  URL:             file:///Applications/Test.app
EOF
        exit 0 ;;
    *)
        /usr/bin/sfltool "$@" ;;
esac
```

**For launchctl print-disabled output:**
```bash
# tools/mock_bin/launchctl.sh (enhanced)
# ... existing cases ...
    print-disabled)
        MOCK_LAUNCHCTL_DISABLED_OUTPUT="${MOCK_LAUNCHCTL_DISABLED_OUTPUT:-}"
        if [[ -n "$MOCK_LAUNCHCTL_DISABLED_OUTPUT" ]]; then
            echo "$MOCK_LAUNCHCTL_DISABLED_OUTPUT"
        fi
        exit 0 ;;
# ...
```

---

### 6. Subshell-Local State (8 skips)

**Problem:** ShellSpec runs tests in subshells, preventing global variable changes.

**Solution:** Use environment variables instead of global variables

```bash
# Instead of:
TEST_KILL_FAIL=false  # Global - doesn't work in subshell

# Use:
export MOCK_KILL_MODE="fail"  # Environment - works in subshell

# tools/mock_bin/kill.sh reads from environment
#!/bin/bash
MOCK_KILL_MODE="${MOCK_KILL_MODE:-normal}"
case "$MOCK_KILL_MODE" in
    fail) exit 1 ;;
    *) /bin/kill "$@" ;;
esac
```

**Per-test setup in spec files:**
```bash
It 'returns 5 when kill fails for PID'
    export MOCK_KILL_MODE="fail"
    When call QuitAppByPath "12345"
    The status should eq 5
    unset MOCK_KILL_MODE
End
```

---

## Complete Spec File Example

```bash
# spec/quit_app_by_path_spec.sh

. ./spec/spec_helper.sh

# Add mock bin to PATH
export PATH="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin:$PATH"

# Default mock modes
export MOCK_PGREP_MODE="running"
export MOCK_PKILL_MODE="normal"
export MOCK_KILL_MODE="normal"

Describe 'QuitAppByPath'

  # Bad input tests
  It 'returns 2 when no arguments provided'
    When call QuitAppByPath
    The status should eq 2
    The output should include "Bad input"
  End

  # PID not running test
  It 'returns 0 when PID process is not running'
    export MOCK_PGREP_MODE="not_running"
    When call QuitAppByPath "12345"
    The status should eq 0
    unset MOCK_PGREP_MODE
  End

  # Kill failure test
  It 'returns 5 when kill fails for PID'
    export MOCK_KILL_MODE="fail"
    When call QuitAppByPath "12345"
    The status should eq 5
    unset MOCK_KILL_MODE
  End

  # Pkill failure test
  It 'returns 5 when pkill fails for process name'
    export MOCK_PKILL_MODE="fail"
    When call QuitAppByPath "testprocess"
    The status should eq 5
    unset MOCK_PKILL_MODE
  End

  # Bundle mode with mock bundle
  It 'derives process name from CFBundleExecutable'
    TEST_TMP_DIR=$(mktemp -d)
    export PATH="/Users/andrewezimmer/Documents/GitHub/mac-muck/tools/mock_bin:$PATH"
    /Users/andrewezimmer/Documents/GitHub/mac-muck/tools/create_mock_bundle.sh "$TEST_TMP_DIR/Test.app" "MyExecutable"
    
    When call QuitAppByPath "$TEST_TMP_DIR/Test.app"
    The status should eq 0
    
    rm -rf "$TEST_TMP_DIR"
  End

End
```

---

## Implementation Checklist

### Phase 1: EUID Wrappers
- [ ] Create `tools/mock_euid_nonroot.sh`
- [ ] Create `tools/mock_euid_root.sh`
- [ ] Modify functions to check `FAKE_EUID` first
- [ ] Update spec_helper.sh to support EUID modes

### Phase 2: Tool Wrappers
- [ ] Create `tools/mock_bin/` directory
- [ ] Create launchctl wrapper with all modes
- [ ] Create pkill/pgrep wrappers
- [ ] Create kill wrapper
- [ ] Create PlistBuddy wrapper
- [ ] Create pkgutil wrapper
- [ ] Create sfltool wrapper
- [ ] Create pluginkit wrapper
- [ ] Create qlmanage wrapper

### Phase 3: File System Tools
- [ ] Create `tools/create_mock_bundle.sh`
- [ ] Create `tools/create_mock_plist.sh`
- [ ] Create `tools/setup_test_dirs.sh`

### Phase 4: Update Spec Files
- [ ] Update all spec files to use mock PATH
- [ ] Add environment variable setup per test
- [ ] Replace Skip blocks with actual tests
- [ ] Add cleanup traps

### Phase 5: Verification
- [ ] Run full test suite
- [ ] Verify 0 failures
- [ ] Verify 0 skips (or document remaining intentional skips)

---

## Expected Results

After implementing all infrastructure:
- **367 examples, 0 failures, 0 skips**
- All tests execute with controlled mock behavior
- Tests can verify success, failure, and edge cases
- Root and non-root scenarios both testable
- Tool absence and failure scenarios testable

---

## Notes

1. **Environment variables over globals:** Always use `export VAR=value` for per-test configuration since ShellSpec runs tests in subshells.

2. **Cleanup is critical:** Every test that creates files must clean up. Use `trap` in spec files or ensure cleanup in each test.

3. **Mock mode isolation:** Each test should set its own mock modes and unset them afterward to prevent cross-test contamination.

4. **Real tool fallback:** Mock wrappers should delegate to real tools when in "normal" mode, ensuring mocks don't break actual functionality.

5. **Document mock modes:** Each wrapper script should have clear documentation of available modes and their effects.