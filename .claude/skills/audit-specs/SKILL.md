---
name: audit-specs
description: Audit existing ShellSpec tests against the gauntlet model. Use when the user asks to review test quality, check gauntlet compliance, find coverage gaps, or verify that rc1/rc5 tests properly walk gates A through F.
allowed-tools: Read Grep Glob Bash Agent
---

# Audit ShellSpec tests for gauntlet compliance

You are reviewing the unit test suite for a macOS uninstaller project. Your job is to verify that tests for operation-failure paths (rc 1, rc 5+) properly "walk the gauntlet" — proving the input survived all earlier validation gates before reaching the failure point being tested.

## What to audit

Focus on **E/F tests** — tests for rc 0 happy paths (gate E) and rc 1 / rc 5+ operation failures (gate F). Tests for gates A-D (bad input, root check, presence) are straightforward and rarely have gauntlet issues.

## The gauntlet gates

Every function processes input through these gates in order:

| Gate | What | RC | How to verify the test passes it |
|------|------|-----|--------------------------------|
| A | Input validation | 2 | Test uses well-formed args (valid label/path/format) |
| B | Root gate | 3 | Test sets `FAKE_EUID=0` if function requires root |
| C/D | Presence check | 0/4 | Test creates real file/dir OR mock confirms target exists |
| E | Operation + verify | 0 | Mock allows operation to succeed, verify-after confirms |
| F | Operation fails | 1/5+ | Mock causes specific failure AFTER gates A-D pass |

## Audit procedure

For each function, perform these steps:

### 1. Read the source function

Find the function in `src/uninstaller.sh`. Map its code to the gauntlet gates:
- Where does it validate input? (gate A)
- Where does it check root? (gate B)
- Where does it check if the target exists? (gate C/D)
- Where does it perform the operation? (gate E)
- Where does it verify the result? (gate E/F)
- What are the specific rc 5+ paths? What message does each print?
- What are the rc 1 paths? Are they catchalls or type-check failures?

### 2. Read the spec file

For each test that asserts `The status should eq 5` (or eq 1 in an operation-failure context):

**Trace the test through the function's code path:**

1. What arguments does the test pass? → Do they survive gate A?
2. Does the test set FAKE_EUID=0 if needed? → Does it survive gate B?
3. Does the test create a real file/mock that confirms the target exists? → Does it survive gate C/D?
4. What mock state does the test set up? → Does the mock only affect the operation stage, or does it short-circuit an earlier gate?
5. Does the function's own logic (not the mock) produce the return code?

**Red flags to look for:**

- **Mock short-circuits:** A mock that returns rc 5 directly, before the function reaches its own operation logic. The test passes, but it's testing the mock.
- **Missing preconditions:** An rc 5 test that doesn't set FAKE_EUID=0 for a function that requires root. It might get rc 3 instead of rc 5, or it might get rc 5 from an unexpected path.
- **Nonexistent target:** An rc 5 test that doesn't create a file/mock for a function that checks existence. It might get rc 4 instead, or the mock might skip the existence check entirely.
- **Orchestrator delegation without delegate tests:** If FunctionA's rc 5 test mocks FunctionB to return 5, check that FunctionB has its own gauntlet-compliant E/F tests. If FunctionB has no E/F tests, the entire chain is untested.

### 3. Check for missing E/F coverage

A function that modifies state MUST have:
- At least one E test (happy path — operation succeeds and verify confirms)
- At least one F test for each rc 5+ path (operation attempted, specific failure)
- At least one F test for rc 1 if the function has a catchall/verify-after-timeout path

Functions that DON'T need E/F tests:
- Read-only functions (IdentifyLoginItemType, ListGraphicalUsers, VerifyServiceUnloaded) — they don't modify state
- Pure routing functions (ParseInput) — they populate arrays but don't perform destructive operations

### 4. Classify the mock quality

Rate each E/F test's mock strategy:

| Rating | Description | Example |
|--------|-------------|---------|
| **Real filesystem** | No mock for the operation — uses actual filesystem conditions (chmod, non-empty dir) | UnlinkSymlink rc 5: chmod 555 prevents unlink AND rm |
| **Mock lied** | Mock claims success (rc 0) but doesn't act; function's verify-after catches it | RemovePrivilegedHelper: SafeDelete returns 0, file persists |
| **Stateful mock** | Mock changes behavior across calls to simulate a real sequence | ForgetPackage: pkg-info→forget→pkg-info with call counter |
| **Delegate mock** | Orchestrator mocks a delegate function to return failure | RemovePathForUsers: SafeRemovePath returns 5 |
| **Direct mock** | Mock directly returns a failure code at the operation stage | QuitAppByPath: MOCK_PKILL_MODE="fail" |

"Real filesystem" and "Mock lied" are the strongest. "Direct mock" is acceptable when the tool genuinely could refuse (e.g., pkill returning nonzero). "Delegate mock" is acceptable for orchestrators when the delegate has its own tests.

## Output format

Produce a table for each function:

```
### FunctionName
Spec: spec/<name>_spec.sh

| Test description | RC | Gates passed | Mock strategy | Verdict |
|-----------------|-----|-------------|---------------|---------|
| "operation succeeds" | 0 | A,B,C/D,E | real filesystem | PASS |
| "verify-after fails" | 5 | A,B,C/D | mock lied | PASS |
| "delegate fails" | 5 | A,B,C/D | delegate mock | PASS (delegate tested separately) |
| (missing) | 1 | - | - | GAP: no catchall test |
```

Verdicts:
- **PASS** — Test properly walks the gauntlet
- **PASS (note)** — Test is acceptable with a caveat (e.g., orchestrator pattern)
- **WEAK** — Test passes but doesn't strongly prove the gauntlet was walked (e.g., nonexistent target but mock skips existence check)
- **GAP** — Expected test is missing entirely
- **WRONG** — Test asserts incorrect behavior or mock short-circuits

## After the audit

1. Update `docs/TESTING_ARCHITECTURE.md` with any new findings.
2. If gaps are found, list them with the specific tests needed (match the patterns in the existing spec files for that function's sibling — e.g., if UnloadAndRemoveLaunchAgent has good E/F tests, use the same structure for UnloadAndRemoveLaunchDaemon).
3. Do NOT fix the tests during an audit. Report findings only. Fixes are a separate step (use `/write-spec` for that).
