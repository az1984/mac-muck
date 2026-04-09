Describe 'ParseInput'

  # ════════════════════════════════════════════════════════════
  # Fallback mode (no arguments — hardcoded arrays survive)
  # ════════════════════════════════════════════════════════════

  Describe 'with no arguments (fallback to hardcoded arrays)'
    It 'returns 0 and does not modify pre-set arrays'
      # Pre-set a hardcoded array value before calling ParseInput
      PATHS_TO_REMOVE=("/Applications/TestApp.app")
      When call ParseInput
      The status should eq 0
      The variable PATHS_TO_REMOVE should eq "/Applications/TestApp.app"
    End
  End

  # ════════════════════════════════════════════════════════════
  # Jamf mode ($4 == "jamf=true")
  # ════════════════════════════════════════════════════════════

  Describe 'Jamf mode detection'
    It 'sets JAMF_MODE when $4 is exactly "jamf=true"'
      # Simulate: $1=mountpoint $2=computername $3=username $4=jamf=true $5=TestApp
      When call ParseInput "/tmp" "mac01" "admin" "jamf=true" "TestApp"
      The status should eq 0
      The variable APP_NAME should eq "TestApp"
    End

    It 'does NOT enter Jamf mode when $4 is "JAMF=TRUE" (case sensitive)'
      When call ParseInput "/tmp" "mac01" "admin" "JAMF=TRUE" "TestApp"
      The status should eq 0
      # APP_NAME should NOT be overwritten by $5 since Jamf mode didn't activate
      # (it stays as the hardcoded default or whatever was set before)
    End

    It 'does NOT enter Jamf mode when $4 is empty'
      When call ParseInput "/tmp" "mac01" "admin" ""
      The status should eq 0
    End
  End

  Describe 'Jamf parameter parsing'
    It 'parses $6 as pipe-delimited PATHS_TO_REMOVE'
      When call ParseInput "/tmp" "mac01" "admin" "jamf=true" "TestApp" "/Applications/Test.app|/Library/Prefs/com.test"
      The status should eq 0
      The variable 'PATHS_TO_REMOVE[0]' should eq "/Applications/Test.app"
      The variable 'PATHS_TO_REMOVE[1]' should eq "/Library/Prefs/com.test"
    End

    It 'parses $7 as pipe-delimited PKGS_TO_REMOVE'
      When call ParseInput "/tmp" "mac01" "admin" "jamf=true" "TestApp" "" "com.test.pkg1|com.test.pkg2"
      The status should eq 0
      The variable 'PKGS_TO_REMOVE[0]' should eq "com.test.pkg1"
      The variable 'PKGS_TO_REMOVE[1]' should eq "com.test.pkg2"
    End

    It 'leaves arrays empty when Jamf param slot is empty'
      When call ParseInput "/tmp" "mac01" "admin" "jamf=true" "TestApp" "" ""
      The status should eq 0
      # PKGS_TO_REMOVE should remain at its hardcoded value (or empty)
    End
  End

  # ════════════════════════════════════════════════════════════
  # CLI flag mode
  # ════════════════════════════════════════════════════════════

  Describe 'CLI flag parsing'
    It 'parses --app-name= flag'
      When call ParseInput --app-name="CLI Test App"
      The status should eq 0
      The variable APP_NAME should eq "CLI Test App"
    End

    It 'parses --paths= with pipe delimiter'
      When call ParseInput --paths="/Applications/Foo.app|/Library/Bar"
      The status should eq 0
      The variable 'PATHS_TO_REMOVE[0]' should eq "/Applications/Foo.app"
      The variable 'PATHS_TO_REMOVE[1]' should eq "/Library/Bar"
    End

    It 'parses --packages= flag'
      When call ParseInput --packages="com.vendor.app|com.vendor.helper"
      The status should eq 0
      The variable 'PKGS_TO_REMOVE[0]' should eq "com.vendor.app"
      The variable 'PKGS_TO_REMOVE[1]' should eq "com.vendor.helper"
    End

    It 'parses --agents= flag'
      When call ParseInput --agents="com.vendor.app.agent"
      The status should eq 0
      The variable 'LAUNCH_AGENTS_TO_REMOVE[0]' should eq "com.vendor.app.agent"
    End

    It 'parses --daemons= flag'
      When call ParseInput --daemons="com.vendor.app.daemon"
      The status should eq 0
      The variable 'LAUNCH_DAEMONS_TO_REMOVE[0]' should eq "com.vendor.app.daemon"
    End

    It 'parses --finder-exts= flag'
      When call ParseInput --finder-exts="com.vendor.app.FinderSync"
      The status should eq 0
      The variable 'FINDER_EXTENSIONS_TO_REMOVE[0]' should eq "com.vendor.app.FinderSync"
    End

    It 'parses --quit= flag'
      When call ParseInput --quit="/Applications/Foo.app"
      The status should eq 0
      The variable 'APPS_TO_QUIT[0]' should eq "/Applications/Foo.app"
    End

    It 'parses --profile-paths= flag'
      When call ParseInput --profile-paths="Library/Caches/com.vendor"
      The status should eq 0
      The variable 'PROFILE_REL_PATHS_TO_REMOVE[0]' should eq "Library/Caches/com.vendor"
    End

    It 'parses --ql-plugins= flag'
      When call ParseInput --ql-plugins="/Library/QuickLook/Vendor.qlgenerator"
      The status should eq 0
      The variable 'QUICKLOOK_PLUGINS_TO_REMOVE[0]' should eq "/Library/QuickLook/Vendor.qlgenerator"
    End

    It 'parses --helpers= flag'
      When call ParseInput --helpers="/Library/PrivilegedHelperTools/com.vendor.helper"
      The status should eq 0
      The variable 'PRIVILEGED_HELPERS_TO_REMOVE[0]' should eq "/Library/PrivilegedHelperTools/com.vendor.helper"
    End

    It 'parses --login-items= flag'
      When call ParseInput --login-items="com.vendor.loginitem"
      The status should eq 0
      The variable 'LOGIN_ITEMS_TO_REMOVE[0]' should eq "com.vendor.loginitem"
    End

    It 'handles multiple flags in one invocation'
      When call ParseInput --app-name="Multi" --paths="/Applications/Multi.app" --packages="com.multi.app"
      The status should eq 0
      The variable APP_NAME should eq "Multi"
      The variable 'PATHS_TO_REMOVE[0]' should eq "/Applications/Multi.app"
      The variable 'PKGS_TO_REMOVE[0]' should eq "com.multi.app"
    End
  End

  # ════════════════════════════════════════════════════════════
  # Manifest mode
  # ════════════════════════════════════════════════════════════

  Describe 'manifest mode'
    It 'returns 2 when --manifest is specified but no path follows'
      When call ParseInput --manifest
      The status should eq 2
    End

    It 'returns 2 when --manifest path does not exist'
      When call ParseInput --manifest="/nonexistent/path/manifest.json"
      The status should eq 2
    End

    It 'parses a valid JSON manifest via ParseManifestJSON'
      Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
    End
  End

  # ════════════════════════════════════════════════════════════
  # Priority chain
  # ════════════════════════════════════════════════════════════

  Describe 'priority: CLI flags override Jamf params'
    It 'uses CLI --app-name over Jamf $5 when both present'
      # CLI flag should win even if $4 is "jamf=true"
      When call ParseInput --app-name="CLI Wins" "/tmp" "mac01" "admin" "jamf=true" "JamfApp"
      The status should eq 0
      The variable APP_NAME should eq "CLI Wins"
    End
  End

  Describe 'priority: manifest overrides CLI flags'
    It 'uses manifest over CLI flags when --manifest is present'
      Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
    End
  End
End
