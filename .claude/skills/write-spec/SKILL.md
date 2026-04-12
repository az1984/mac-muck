---
name: write-spec
description: Write or extend a ShellSpec test file for a function in src/uninstaller.sh. Use when the user asks to create tests, add test coverage, convert Skips to real tests, or write E/F gauntlet tests for a function.
allowed-tools: Read Grep Glob Edit Write Bash Agent
---

# Write ShellSpec tests for a function

You are writing ShellSpec unit tests for bash functions in a macOS uninstaller project. Every test must follow the gauntlet model and the project's mandatory rules.

## Step 1 — Gather context

Before writing any test, read ALL of the following:

1. **The function under test** in `src/uninstaller.sh` — find it with `grep -n '^FunctionName()' src/uninstaller.sh`. Read the entire function body AND its header comment (the `# @name` block above it). The header's `Returns:` section is the contract.

2. **The existing spec file** at `spec/<function_name_snake_case>_spec.sh` — understand what's already covered so you don't duplicate.

3. **The test checklist** in `docs/UNIT_TESTING.md` — find the function's section. Each checkbox = one `It` block. If the test you're writing doesn't have a checkbox, add one.

4. **The coding rules** in `.clinerules` — especially the "ShellSpec test writing rules" and "Mock rules" sections.

5. **The gauntlet model** in `docs/TESTING_ARCHITECTURE.md` — understand gates A through F and how rc 1 vs rc 5 work.

6. **The spec helper** at `spec/spec_helper.sh` — understand what's already patched (sed pipeline for _BIN vars, mapfile polyfill, FAKE_EUID, etc.).

7. **Existing mocks** in `tools/mock_bin/` — check if a mock already exists for the tool you need.

## Step 2 — Plan the test using the gauntlet

Every function follows this gate sequence. Map the function's code to these gates:

| Gate | Check | RC on failure | What to look for in the source |
|------|-------|---------------|-------------------------------|
| A | Input validation | 2 | Arg parsing `case`, regex validation, duplicate flag detection |
| B | Root gate | 3 | `_get_effective_euid` check, `--needs-root` or mandatory root |
| C | Presence + tolerant | 0 | `$tolerant` + target missing → early return 0 |
| D | Presence + strict | 4 | Target missing without `--tolerant-missing` → return 4 |
| E | Operation succeeds | 0 | The actual action + verify-after confirms success |
| F | Operation fails | 1 or 5+ | Action attempted, verify-after shows it didn't take |

### For E/F tests specifically:

**The test must prove it passed gates A through D to reach the operation.** This means:

- **Valid input:** Use a well-formed argument (e.g., reverse-DNS label `com.test.example`, valid path, etc.)
- **Root if needed:** Set `export FAKE_EUID=0` / `export FAKE_UID=0` if the function requires root
- **Target exists:** Create a real file/dir/symlink in `/tmp` or `$SHELLSPEC_TMPDIR`, OR set up a mock that confirms presence (e.g., pkgutil --pkg-info succeeds, launchctl print finds the service)
- **Then control only the operation outcome:** Mock the tool/delegate to succeed-but-not-really (for rc 5 verify-after) or to fail outright (for rc 5 operation failure)

### rc 5 vs rc 1:

- **rc 5** = a specific, named failure. The function knows what went wrong. Example: "pkgutil forget succeeded but receipt still present," "pkill failed," "rmdir failed," "SafeDelete failed."
- **rc 1** = the catchall. Everything reported success, but the end result is wrong. Example: verify-after timeout (process still running after all kill methods), path persists after walk reported success. Also used for: missing tool, missing dependency, "not a symlink" type checks.

## Step 3 — Write the test

### File structure rules:
- File starts with `. ./spec/spec_helper.sh`
- `Describe 'FunctionName'` with exact function name
- Group tests under comment headers: `# --- Category (rc N) ---` matching existing style in the file
- Use the separator pattern from existing specs (the `═══` lines)

### Test body rules:
- `When call FunctionName <args>` — never wrap in subshells
- At minimum assert `The status should eq N`
- For E/F tests, also assert output: `The output should include "specific message"`
- Set mock state with `export` BEFORE `When call`
- Clean up with `unset` / `rm -f` AFTER assertions
- Each test must be independent — no state leakage between tests

### Mock strategy (choose the right approach):

**For functions using `_BIN` path variables** (ForgetPackage, RemoveFinderExtension, IdentifyLoginItemType, etc.):
- Set `export TOOL_BIN="/path/to/mock"` to redirect to `tools/mock_bin/<tool>`
- For tool-missing tests: `export TOOL_BIN="/nonexistent/tool"`

**For functions using hardcoded absolute paths** (QuitAppByPath's `/usr/bin/pgrep`, launchctl functions' `/bin/launchctl`):
- Define a bash function that shadows the path: `eval 'function /bin/launchctl { ... }'`
- These work because bash resolves function names (even with `/`) before external commands

**For functions that delegate to other bash functions** (SafeDelete→UnlinkSymlink, RemovePathForUsers→SafeRemovePath):
- Redefine the delegate: `SafeDelete() { return 5; }`
- For verify-after tests, make it "succeed" without acting: `SafeDelete() { return 0; }` (file still exists → rc 5)

**For stateful mocks** (pkgutil needs different responses across calls):
- Use counter files: `MOCK_COUNTER_FILE="/tmp/counter_$$"`
- Track call count, return different results based on count

### The "mock lied" pattern (most important for F tests):

The strongest rc 5 verify-after test is: mock the delegate to return 0 (claim success) but **don't actually perform the action**. Then the function's own verify-after check finds the target still exists → rc 5. This proves the verify-after logic works and isn't just trusting the delegate's return code.

```bash
# Example: RemovePrivilegedHelper verify-after test
touch "$test_helper"                    # target exists (passes gate D)
SafeDelete() { return 0; }             # claims success, doesn't delete
When call RemovePrivilegedHelper "$test_helper"
The status should eq 5                  # verify-after caught the lie
The output should include "still exists after removal"
```

### Real filesystem tests (preferred where possible):

For functions that directly use `rm`, `rmdir`, `unlink` — prefer tests that use real filesystem conditions:
- `chmod a-w` on parent dir to make rm fail
- Non-empty directory to make rmdir fail
- These test the actual tool behavior, not just mock responses

## Step 4 — Verify and update tracking

1. Run the specific spec: `shellspec --shell bash spec/<file>_spec.sh`
2. Run the full suite: `shellspec --shell bash` — expect 0 failures
3. Check the box in `docs/UNIT_TESTING.md` for each new passing test
4. If you added new test categories, add corresponding checkboxes to UNIT_TESTING.md
5. Update `docs/WIP_UNIT_TESTING.md` if this resolves a documented skip or gap
6. Update `docs/TESTING_ARCHITECTURE.md` if you added E/F coverage to a function that was previously missing it

## Bash 3.2 gotchas (macOS)

- No `mapfile` — use the polyfill in spec_helper.sh, or add one to the spec file
- No `grep -P` — use `sed -n` equivalents
- No associative arrays — use parallel indexed arrays or temp files
- `local` must be inside a function body
- ShellSpec's `When call` does not work inside subshells `( ... )`
