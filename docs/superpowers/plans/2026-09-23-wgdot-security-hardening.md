# WGDot Minimal Security Hardening Implementation Plan

> Execute with `superpowers:executing-plans` and test-first development.

**Goal:** Close three user-to-administrator trust crossings without changing how WGDot installs applications or operates.

**Architecture:** Keep the current single WinGet flow and existing binaries. Bind the two writable JSON handoffs to exact SHA-256 bytes, resolve the existing WinGet alias to a bounded absolute path, and re-resolve DDU from protected install roots after elevation.

**Spec:** `docs/superpowers/specs/2026-09-23-wgdot-security-hardening-design.md`

**Baseline:** `4b97a4d1e7fb62bf5d71b7beba2adb9baa8c53eb`

## Global constraints

- Do not change `wgdot/bootstrap.cmd`, `wgdot/manifest.json`, managed desktop files, software selections, or installer documentation. The v4.6.0 integration permits only the narrow `wgdotw.exe` argument-boundary and version-aware refresh fix in Task 5.
- Do not add an installed executable, service, scheduled task, dependency, package manager, prompt, or installation step.
- Preserve the current one-worker/one-UAC software reconciliation flow.
- Preserve existing WinGet package IDs, sources, arguments, and repair behavior.
- Preserve GPU Safe Mode confirmation and boot-recovery ordering.
- Use `WGDOT_TEST_ROOT` maintenance self-tests plus repository contract tests; CI provides the authoritative Windows compile/run evidence.
- Do not merge or release without explicit approval and real-Windows confirmation.

## Shared interfaces

- Tasks 1 and 3 share `NormalizeSha256`, `Sha256Bytes`, and `ReadVerifiedJson`.
- Task 2 changes `FindWingetExe`/`EnsureWingetAvailable`; every elevated WinGet launch must consume the resolved full path without adding a second install path.
- Task 4 records the invariants implemented by Tasks 1-3.
- Task 5 follows the v4.6.0 merge and changes only the generated windowless frontend plus its existing runtime-swap handoff.

### Task 1: Bind the elevated software plan to exact bytes

**Files:**
- Modify: `wgdot/wgdot-native.cs`
- Modify: `tests/test-wgdot.ps1`

**RED:**

1. Add maintenance self-tests that write a small JSON file, hash it, verify it, then change one byte and require verification to fail. Add malformed-digest coverage.
2. Add repository contract assertions that the parent passes `--plan-sha256`, the worker requires it, and the worker uses `ReadVerifiedJson` rather than `ReadJson`.
3. Run the PowerShell test on Windows/CI and confirm it fails for the missing digest-bound handoff.

**GREEN:**

1. Add narrowly scoped helpers:
   - `NormalizeSha256(string value, string fieldName)`
   - `Sha256Bytes(byte[] value)`
   - constant-time-style digest comparison
   - `ReadVerifiedJson(string path, string expectedSha256)` that reads once and parses the verified bytes
2. After writing the existing software plan, calculate its SHA-256 and add `--plan-sha256` to the existing UAC command.
3. Parse and require that argument in `SoftwareElevatedFromArgs`, pass it to `RunSoftwareElevatedPlan`, and verify before acting.
4. Keep the plan contents and software logic unchanged.

**Verify and commit:**

- Run repository PowerShell tests and native maintenance self-test in CI.
- Commit: `Bind elevated WGDot plans to verified bytes`

### Task 2: Resolve the existing WinGet alias by trusted full path

**Files:**
- Modify: `wgdot/wgdot-native.cs`
- Modify: `tests/test-wgdot.ps1`

**RED:**

1. Add native tests for path containment beneath an explicit WindowsApps root, including rejection of sibling-prefix and `..` escape paths.
2. When WinGet exists, require `FindWingetExe()` to return an absolute existing path within `%LOCALAPPDATA%\Microsoft\WindowsApps` and never the literal `winget.exe`.
3. Add repository contract assertions that the elevated worker resolves one WinGet path and never launches a bare WinGet name.
4. Run the Windows tests and confirm the current bare-name fallback violates the contract.

**GREEN:**

1. Add a small canonical containment helper.
2. Make `FindWingetExe()` check only the current user's explicit WindowsApps alias path and return an absolute canonical path or null.
3. Preserve `EnsureWingetAvailable()` and its current repair behavior, but have it return or expose the verified full path after repair.
4. Resolve WinGet once inside each elevated software/GPU install operation and use that same full path for the existing commands.
5. Do not alter any WinGet arguments, package selection, source selection, or application-install flow.

**Verify and commit:**

- Run repository PowerShell tests and native maintenance self-test in CI.
- Commit: `Resolve elevated WinGet by trusted path`

### Task 3: Protect GPU Safe Mode resume state and DDU execution

**Files:**
- Modify: `wgdot/wgdot-native.cs`
- Modify: `tests/test-wgdot.ps1`

**RED:**

1. Add contract assertions that RunOnce includes `--state-sha256`, dispatch passes resume arguments, verified JSON is used, and the resume method does not execute `GetString(state, "dduPath")`.
2. Add native path tests accepting a child beneath a supplied Program Files root and rejecting sibling-prefix/escape paths.
3. Reuse the verified-JSON test to prove a changed GPU state byte is rejected.
4. Run Windows tests and confirm the current stored-path resume behavior fails the contract.

**GREEN:**

1. Hash the final GPU state and include `--state-sha256` in the existing HKLM RunOnce command.
2. Replace dispatch with `GpuSafeResumeFromArgs(string[] args)`, require the digest, and preserve it through the existing UAC handoff.
3. Read and verify the state once after elevation.
4. Add `FindTrustedDduExe()` using the current registered/conventional candidates but accept only existing canonical paths beneath Program Files or Program Files (x86).
5. Keep `dduPath` only as non-authoritative diagnostic state; never execute it.
6. Preserve the existing BCD cleanup-before-DDU ordering and failure behavior.

**Verify and commit:**

- Run repository PowerShell tests and native maintenance self-test in CI.
- Commit: `Protect WGDot Safe Mode resume state`

### Task 4: Record the minimal invariants and validate the branch

**Files:**
- Modify: `AGENTS.md`
- Verify: `wgdot/wgdot-native.cs`
- Verify: `tests/test-wgdot.ps1`

**Work:**

1. Record only these new invariants:
   - elevated JSON handoffs are bound to exact bytes and parsed from the verified read;
   - elevated WinGet execution uses a validated absolute WindowsApps path, not inherited PATH;
   - GPU resume re-resolves DDU beneath Program Files and never executes the stored path.
2. Run local platform-independent checks:
   - `python tests/test-desktop-bindings.py`
   - `python -m json.tool wgdot/manifest.json`
   - `git diff --check`
3. Run or require the full existing `Validate WGDot` Windows matrix, including Windows PowerShell 5.1, PowerShell 7, YASB schema, bootstrap compilation, runtime refresh, and maintenance self-test.
4. Inspect the complete branch diff and confirm there are no changes to bootstrap, manifest, desktop configuration, application selection, or installation documentation.
5. Commit: `Document WGDot privileged trust invariants`

### Task 5: Preserve `wgdotw.exe` argument boundaries after v4.6.0

**Files:**
- Modify: `wgdot/wgdot-native.cs`
- Modify: `tests/test-wgdot.ps1`
- Modify: `AGENTS.md`

**RED:**

1. Assert that the generated frontend quotes each argument and no longer uses a raw space join.
2. Assert that the frontend has an explicit version and the runtime-swap helper ensures it before recording the refreshed revision.
3. Demonstrate that the current source fails both contracts.

**GREEN:**

1. Implement Windows-compatible argument quoting inside the existing generated `wgdotw.exe` source while retaining `UseShellExecute = false`, `CreateNoWindow = true`, sibling-only `wgdot.exe` resolution, wait behavior, and exit-code forwarding.
2. Add an explicit frontend file version and rebuild only when the installed frontend is absent or older.
3. Have the existing post-exit runtime-swap helper call the internal `ensure-hidden-launcher` command before `mark-runtime`, so existing installations receive the fix without a new executable or installation step.
4. Exercise spaces, embedded quotes, empty values, and trailing backslashes in the quoting contract.

## Final review focus

- Confirm no second or alternate application-install path was introduced.
- Confirm WinGet arguments and user-visible software flow are unchanged except for the executable path passed to `ProcessStartInfo`.
- Confirm every verified JSON file is read once and parsed from those same bytes.
- Confirm digest arguments survive both elevation paths.
- Confirm path containment rejects sibling-prefix and traversal cases.
- Confirm DDU cannot be launched from the state file's stored path.
- Confirm desktop callbacks are untouched and `wgdotw.exe` changes are limited to exact argument forwarding and version-aware refresh.

## Real-Windows handoff before merge/release

Use the existing exact-revision bootstrap command, approve the new `wgdot.exe` and (only for this wrapper-version change) `wgdotw.exe` hashes in ThreatLocker, run current Work desktop callbacks including one Yazi outbound drag from a path containing spaces, and run one ordinary software reconciliation. Expected result: the same selection flow, one UAC prompt, and the same applications/actions as before. Safe Mode/DDU testing remains optional and must not be inferred from CI.
