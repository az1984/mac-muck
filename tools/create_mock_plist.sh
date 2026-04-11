#!/bin/bash
# create_mock_plist.sh
# Create a mock plist file with specified keys for testing
#
# Usage: create_mock_plist.sh <output_path> <key1> <value1> [key2] [value2] ...
#
# This script creates a minimal plist file with the specified key-value pairs.
#
# Example:
#   create_mock_plist.sh /tmp/test.plist \
#     "CFBundleExecutable" "TestApp" \
#     "CFBundleIdentifier" "com.test.app"
#
# For LaunchAgent/LaunchDaemon plists, use:
#   create_launchctl_plist.sh <output_path> <label> <program>

set -f
IFS=$' \t\n'

OUTPUT_PATH="$1"
shift

if [[ -z "$OUTPUT_PATH" ]]; then
    echo "Usage: create_mock_plist.sh <output_path> <key1> <value1> [key2] [value2] ..." >&2
    exit 1
fi

# Start the plist
cat > "$OUTPUT_PATH" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
EOF

# Add key-value pairs
while [[ $# -gt 0 ]]; do
    key="$1"
    value="$2"
    if [[ -n "$key" && -n "$value" ]]; then
        echo "    <key>$key</key>" >> "$OUTPUT_PATH"
        echo "    <string>$value</string>" >> "$OUTPUT_PATH"
    fi
    shift 2
done

# Close the plist
cat >> "$OUTPUT_PATH" << 'EOF'
</dict>
</plist>
EOF

echo "Created plist at: $OUTPUT_PATH"