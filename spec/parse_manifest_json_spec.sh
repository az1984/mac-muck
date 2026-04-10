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
    Skip "Requires mocking /usr/bin/plutil"
  End

  # ─────────────────────────═══════════════════════════════════════
  # JSON parsing (rc 0)
  # ─────────────────────────═══════════════════════════════════════

  It 'parses app_name from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses paths array from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses packages array from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses launch_agents array from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses launch_daemons array from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses finder_extensions array from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses quicklook_plugins array from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses privileged_helpers array from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses login_items array from valid JSON manifest'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'parses all arrays in a single invocation'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  # ─────────────────────────═══════════════════════════════════════
  # Parse errors (rc 1)
  # ─────────────────────────═══════════════════════════════════════

  It 'returns 1 when given invalid JSON'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

  It 'returns 1 when given a non-JSON file'
    Skip "Requires macOS with /usr/bin/plutil and a test manifest file"
  End

End