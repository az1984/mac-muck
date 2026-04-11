#!/bin/bash
# create_launchctl_plist.sh
# Create a mock LaunchAgent or LaunchDaemon plist for testing
#
# Usage: create_launchctl_plist.sh <output_path> <label> <program> [type]
#   type: "agent" or "daemon" (default: agent)
#
# Example:
#   create_launchctl_plist.sh /tmp/test.plist com.test.agent /usr/bin/testagent agent
#   create_launchctl_plist.sh /tmp/test.plist com.test.daemon /usr/bin/testdaemon daemon

set -f
IFS=$' \t\n'

OUTPUT_PATH="$1"
LABEL="$2"
PROGRAM="$3"
TYPE="${4:-agent}"

if [[ -z "$OUTPUT_PATH" || -z "$LABEL" || -z "$PROGRAM" ]]; then
    echo "Usage: create_launchctl_plist.sh <output_path> <label> <program> [type]" >&2
    exit 1
fi

# Determine the domain based on type
if [[ "$TYPE" == "daemon" ]]; then
    DOMAIN="system"
else
    DOMAIN="user"
fi

# Create the plist
cat > "$OUTPUT_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PROGRAM</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

echo "Created $TYPE plist at: $OUTPUT_PATH (label: $LABEL)"