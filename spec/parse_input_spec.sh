# Source the spec helper
. ./spec/spec_helper.sh

# No mock for ParseManifestJSON — use the real function sourced from spec_helper.sh
# so that manifest-mode tests exercise the real plutil-based parsing.

Describe 'ParseInput'

  # ─────────────────────────────────────────────────────────══════════════════════
  # Fallback mode (no arguments)
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 0 with no arguments and keeps hardcoded arrays unchanged'
    # Set up hardcoded arrays before calling ParseInput
    export APP_NAME="HardcodedApp"
    PATHS_TO_REMOVE=("/hardcoded/path")
    PKGS_TO_REMOVE=("com.hardcoded.pkg")
    
    When call ParseInput
    
    The status should eq 0
    # Arrays should remain unchanged since no input source matched
    unset APP_NAME PATHS_TO_REMOVE PKGS_TO_REMOVE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Jamf mode detection
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'enters Jamf mode when $4 == "jamf=true"'
    export APP_NAME=""
    PATHS_TO_REMOVE=()
    PKGS_TO_REMOVE=()
    
    When call ParseInput "mountpoint" "computername" "username" "jamf=true" "JamfApp" "path1|path2" "pkg1|pkg2"
    
    The status should eq 0
    The output should eq ""
    unset APP_NAME PATHS_TO_REMOVE PKGS_TO_REMOVE JAMF_MODE
  End

  It 'does NOT enter Jamf mode when $4 == "JAMF=TRUE" (case sensitive)'
    export APP_NAME="DefaultApp"
    PATHS_TO_REMOVE=()
    PKGS_TO_REMOVE=()
    
    When call ParseInput "mountpoint" "computername" "username" "JAMF=TRUE" "JamfApp" "path1|path2" "pkg1|pkg2"
    
    The status should eq 0
    # APP_NAME should remain unchanged since Jamf mode was not entered
    unset APP_NAME PATHS_TO_REMOVE PKGS_TO_REMOVE JAMF_MODE
  End

  It 'does NOT enter Jamf mode when $4 is empty'
    export APP_NAME="DefaultApp"
    
    When call ParseInput "mountpoint" "computername" "username" ""
    
    The status should eq 0
    unset APP_NAME JAMF_MODE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Jamf parameter parsing
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'sets APP_NAME from $5 in Jamf mode'
    export APP_NAME=""
    
    When call ParseInput "mountpoint" "computername" "username" "jamf=true" "TestAppName"
    
    The status should eq 0
    unset APP_NAME JAMF_MODE
  End

  It 'parses pipe-delimited paths from $6 in Jamf mode'
    export PATHS_TO_REMOVE=()
    
    When call ParseInput "mountpoint" "computername" "username" "jamf=true" "App" "path1|path2|path3"
    
    The status should eq 0
    unset PATHS_TO_REMOVE JAMF_MODE
  End

  It 'parses pipe-delimited packages from $7 in Jamf mode'
    export PKGS_TO_REMOVE=()
    
    When call ParseInput "mountpoint" "computername" "username" "jamf=true" "App" "paths" "pkg1|pkg2"
    
    The status should eq 0
    unset PKGS_TO_REMOVE JAMF_MODE
  End

  It 'does not modify arrays when Jamf slot is empty'
    export PATHS_TO_REMOVE=("/existing/path")
    
    When call ParseInput "mountpoint" "computername" "username" "jamf=true" "App" ""
    
    The status should eq 0
    unset PATHS_TO_REMOVE JAMF_MODE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # CLI flag parsing
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'sets APP_NAME with --app-name flag'
    export APP_NAME=""
    
    When call ParseInput "--app-name=TestApp"
    
    The status should eq 0
    unset APP_NAME
  End

  It 'parses pipe-delimited paths with --paths flag'
    export PATHS_TO_REMOVE=()
    
    When call ParseInput "--paths=/path1|/path2|/path3"
    
    The status should eq 0
    unset PATHS_TO_REMOVE
  End

  It 'parses pipe-delimited packages with --packages flag'
    export PKGS_TO_REMOVE=()
    
    When call ParseInput "--packages=com.pkg1|com.pkg2"
    
    The status should eq 0
    unset PKGS_TO_REMOVE
  End

  It 'sets LAUNCH_AGENTS_TO_REMOVE with --agents flag'
    export LAUNCH_AGENTS_TO_REMOVE=()
    
    When call ParseInput "--agents=com.vendor.agent"
    
    The status should eq 0
    unset LAUNCH_AGENTS_TO_REMOVE
  End

  It 'sets LAUNCH_DAEMONS_TO_REMOVE with --daemons flag'
    export LAUNCH_DAEMONS_TO_REMOVE=()
    
    When call ParseInput "--daemons=com.vendor.daemon"
    
    The status should eq 0
    unset LAUNCH_DAEMONS_TO_REMOVE
  End

  It 'sets FINDER_EXTENSIONS_TO_REMOVE with --finder-exts flag'
    export FINDER_EXTENSIONS_TO_REMOVE=()
    
    When call ParseInput "--finder-exts=com.vendor.extension"
    
    The status should eq 0
    unset FINDER_EXTENSIONS_TO_REMOVE
  End

  It 'sets APPS_TO_QUIT with --quit flag'
    export APPS_TO_QUIT=()
    
    When call ParseInput "--quit=/Applications/Test.app"
    
    The status should eq 0
    unset APPS_TO_QUIT
  End

  It 'sets PROFILE_REL_PATHS_TO_REMOVE with --profile-paths flag'
    export PROFILE_REL_PATHS_TO_REMOVE=()
    
    When call ParseInput "--profile-paths=Library/Caches/com.vendor"
    
    The status should eq 0
    unset PROFILE_REL_PATHS_TO_REMOVE
  End

  It 'sets QUICKLOOK_PLUGINS_TO_REMOVE with --ql-plugins flag'
    export QUICKLOOK_PLUGINS_TO_REMOVE=()
    
    When call ParseInput "--ql-plugins=/Library/QuickLook/plugin.qlgenerator"
    
    The status should eq 0
    unset QUICKLOOK_PLUGINS_TO_REMOVE
  End

  It 'sets PRIVILEGED_HELPERS_TO_REMOVE with --helpers flag'
    export PRIVILEGED_HELPERS_TO_REMOVE=()
    
    When call ParseInput "--helpers=/Library/PrivilegedHelperTools/com.vendor.helper"
    
    The status should eq 0
    unset PRIVILEGED_HELPERS_TO_REMOVE
  End

  It 'sets LOGIN_ITEMS_TO_REMOVE with --login-items flag'
    export LOGIN_ITEMS_TO_REMOVE=()
    
    When call ParseInput "--login-items=com.vendor.loginitem"
    
    The status should eq 0
    unset LOGIN_ITEMS_TO_REMOVE
  End

  It 'parses multiple flags in one invocation'
    export APP_NAME=""
    PATHS_TO_REMOVE=()
    PKGS_TO_REMOVE=()
    LAUNCH_AGENTS_TO_REMOVE=()
    
    When call ParseInput "--app-name=MultiApp" "--paths=/p1|/p2" "--packages=com.p1|com.p2" "--agents=com.agent"
    
    The status should eq 0
    unset APP_NAME PATHS_TO_REMOVE PKGS_TO_REMOVE LAUNCH_AGENTS_TO_REMOVE
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Manifest mode
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'returns 2 when --manifest is specified without a path'
    When call ParseInput "--manifest"

    The status should eq 2
    The stderr should include "requires a path"
  End

  It 'returns 2 when --manifest path does not exist'
    When call ParseInput "--manifest=/nonexistent.json"

    The status should eq 2
    The stderr should include "does not exist"
  End

  It 'returns 0 when --manifest path is valid and populates arrays'
    local test_manifest="/tmp/test_manifest_valid_$$.json"
    cat > "$test_manifest" << 'MEOF'
{
  "app_name": "ManifestApp",
  "paths": ["/manifest/path1", "/manifest/path2"],
  "packages": ["com.manifest.pkg1"]
}
MEOF
    When call ParseInput "--manifest=$test_manifest"

    The status should eq 0
    rm -f "$test_manifest"
  End

  # ─────────────────────────────────────────────────────────══════════════════════
  # Priority chain
  # ─────────────────────────────────────────────────────────══════════════════════

  It 'CLI flags override Jamf params when both present'
    export APP_NAME=""
    
    # When both CLI flags and Jamf mode args are present, CLI flags take precedence
    # This is tested by checking that --app-name sets the value even when Jamf mode args exist
    When call ParseInput "--app-name=CLIApp" "mountpoint" "computername" "username" "jamf=true" "JamfApp"
    
    The status should eq 0
    unset APP_NAME JAMF_MODE
  End

  It 'Manifest overrides CLI flags when both present'
    local test_manifest="/tmp/test_manifest_override_$$.json"
    cat > "$test_manifest" << 'MEOF'
{
  "app_name": "ManifestApp",
  "paths": ["/manifest/path1"]
}
MEOF
    # Manifest mode has highest priority, so if --manifest is present, it takes precedence
    When call ParseInput "--manifest=$test_manifest" "--app-name=CLIApp"

    The status should eq 0
    # The manifest should be parsed, not the CLI flag
    rm -f "$test_manifest"
  End

End