. ./spec/spec_helper.sh
Describe 'ParseManifestJSON'

  # ─────────────────────────═══════════════════════════════════════
  # Bad input (rc 2)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 2 when no arguments provided'
    When call ParseManifestJSON
    The status should eq 2
    The output should include "Bad input"
  End

  It 'returns 2 when manifest path does not exist'
    When call ParseManifestJSON "/nonexistent/path/manifest.json"
    The status should eq 2
    The output should include "not found"
  End

  It 'returns 2 when given multiple arguments'
    When call ParseManifestJSON "/path/to/manifest.json" "extra-arg"
    The status should eq 2
    The output should include "Bad input"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Tool presence (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 if plutil binary is missing'
    local old_path="$PATH"
    export PATH="/nonexistent:$PATH"
    local test_json="/tmp/test_manifest_$$"
    echo '{"app_name": "Test"}' > "$test_json"
    (
      export PATH="/nonexistent:$PATH"
      When call ParseManifestJSON "$test_json"
      The status should eq 1
      The output should include "plutil not found"
    )
    rm -f "$test_json"
    export PATH="$old_path"
  End

  # ─────────────────────────═══════════════════════════════════════
  # JSON parsing (rc 0)
  # ─────────────────────────═══════════════════════════════════════

  It 'parses app_name from valid JSON manifest'
    local test_json="/tmp/test_manifest_appname_$$"
    cat > "$test_json" << 'EOF'
{
  "app_name": "TestApp"
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    [[ "$APP_NAME" == "TestApp" ]]
    rm -f "$test_json"
  End

  It 'parses paths array from valid JSON manifest'
    local test_json="/tmp/test_manifest_paths_$$"
    cat > "$test_json" << 'EOF'
{
  "paths": ["/path/to/remove1", "/path/to/remove2"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  It 'parses packages array from valid JSON manifest'
    local test_json="/tmp/test_manifest_packages_$$"
    cat > "$test_json" << 'EOF'
{
  "packages": ["com.vendor.pkg1", "com.vendor.pkg2"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  It 'parses launch_agents array from valid JSON manifest'
    local test_json="/tmp/test_manifest_agents_$$"
    cat > "$test_json" << 'EOF'
{
  "launch_agents": ["com.vendor.agent1", "com.vendor.agent2"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  It 'parses launch_daemons array from valid JSON manifest'
    local test_json="/tmp/test_manifest_daemons_$$"
    cat > "$test_json" << 'EOF'
{
  "launch_daemons": ["com.vendor.daemon1", "com.vendor.daemon2"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  It 'parses finder_extensions array from valid JSON manifest'
    local test_json="/tmp/test_manifest_finder_$$"
    cat > "$test_json" << 'EOF'
{
  "finder_extensions": ["com.vendor.ext1", "com.vendor.ext2"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  It 'parses quicklook_plugins array from valid JSON manifest'
    local test_json="/tmp/test_manifest_quicklook_$$"
    cat > "$test_json" << 'EOF'
{
  "quicklook_plugins": ["/Library/QuickLook/plugin1.qlgenerator"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  It 'parses privileged_helpers array from valid JSON manifest'
    local test_json="/tmp/test_manifest_helpers_$$"
    cat > "$test_json" << 'EOF'
{
  "privileged_helpers": ["/Library/PrivilegedHelperTools/com.vendor.helper"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  It 'parses login_items array from valid JSON manifest'
    local test_json="/tmp/test_manifest_login_$$"
    cat > "$test_json" << 'EOF'
{
  "login_items": ["com.vendor.loginitem"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  It 'parses all arrays in a single invocation'
    local test_json="/tmp/test_manifest_all_$$"
    cat > "$test_json" << 'EOF'
{
  "app_name": "TestApp",
  "paths": ["/path/to/remove"],
  "packages": ["com.vendor.pkg"],
  "launch_agents": ["com.vendor.agent"],
  "launch_daemons": ["com.vendor.daemon"],
  "finder_extensions": ["com.vendor.ext"],
  "quicklook_plugins": ["/Library/QuickLook/plugin.qlgenerator"],
  "privileged_helpers": ["/Library/PrivilegedHelperTools/com.vendor.helper"],
  "login_items": ["com.vendor.loginitem"]
}
EOF
    When call ParseManifestJSON "$test_json"
    The status should eq 0
    rm -f "$test_json"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Parse errors (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when given invalid JSON'
    local test_json="/tmp/test_manifest_invalid_$$"
    echo 'this is not json' > "$test_json"
    When call ParseManifestJSON "$test_json"
    The status should eq 1
    The output should include "Invalid JSON"
    rm -f "$test_json"
  End

  It 'returns 1 when given a non-JSON file'
    local test_json="/tmp/test_manifest_nonjson_$$"
    echo 'Just a text file' > "$test_json"
    When call ParseManifestJSON "$test_json"
    The status should eq 1
    rm -f "$test_json"
  End

End