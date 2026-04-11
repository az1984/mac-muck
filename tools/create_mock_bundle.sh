#!/bin/bash
# create_mock_bundle.sh
# Create a mock .app bundle at the specified path for testing
#
# Usage: create_mock_bundle.sh <bundle_path> [executable_name]
#
# This script creates a minimal .app bundle structure with:
# - Contents/MacOS/ directory with an executable
# - Contents/Resources/ directory
# - Contents/Info.plist with CFBundleExecutable, CFBundleIdentifier, CFBundleName
#
# Example:
#   create_mock_bundle.sh /tmp/Test.app "TestExecutable"
#
# The created bundle can be used to test:
# - QuitAppByPath bundle mode
# - SafeRemovePath with bundles
# - RemoveQuickLookPlugin with .qlgenerator bundles

set -f
IFS=$' \t\n'

BUNDLE_PATH="$1"
EXECUTABLE_NAME="${2:-TestApp}"

if [[ -z "$BUNDLE_PATH" ]]; then
    echo "Usage: create_mock_bundle.sh <bundle_path> [executable_name]" >&2
    exit 1
fi

# Create directory structure
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
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
EOF

# Create dummy executable
touch "$BUNDLE_PATH/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$BUNDLE_PATH/Contents/MacOS/$EXECUTABLE_NAME"

echo "Created mock bundle at: $BUNDLE_PATH"