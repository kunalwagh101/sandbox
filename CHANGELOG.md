# Changelog

## Unreleased

### Repair register

- Added the approved AUDIT-2026-08-28 register with AL-01 through AL-23 mapped to four
  WIP-limited R1 repair stories.
- Withdrew Increment 0 DONE evidence after the product owner's Windows clone reproduced
  the missing-commit failure on 2026-08-29.
- Reopened S-06.01.01 after a later Windows run proved that a temporary fixture could
  borrow an enclosing Git worktree and report the wrong failure.
- Marked the affected Increment 1 stories BLOCKED with explicit escalation and recorded
  online browsing as DEFERRED rather than silently narrowing R-APP-04.
- Corrected the nonce limitation text: correlation is planned in S-06.04.01 and does not
  exist in the current implementation.
- Added approved change CR-2026-08-30-01 and story S-06.05.01 for Windows 10 Pro 22H2
  build 19045 compatibility while preserving Windows 11 24H2+ support.
- Pulled only S-06.03.01 into the WIP-limited R1-L lifecycle slice and moved it to
  IN_REVIEW after the portable source boundary passed GitHub Actions run 33472443734.

### Fixed

- Require evidence commits to resolve from the verifier's exact repository root; an
  enclosing parent worktree can no longer make a temporary fixture look Git-backed.
- Fixed `Assert-AirlockNoReparsePoint` so `FileInfo` traversal uses `.Directory`; the
  exact failure reproduced by the product owner is now an executed regression test.
- Restricted the configurable root to `%LOCALAPPDATA%\Airlock` and evaluate protected
  `audit`/`state` names relative to that root, avoiding false failures for user ancestors.
- Restored the binding 4096 MB ceiling and added executed deliberate-weakening checks for
  every strict Sandbox setting plus the memory boundary.
- Replaced forced file moves in host JSON/profile writes with same-directory atomic move
  or replace operations, using a real transient backup path for Windows PowerShell 5.1.
- Made initialiser `-WhatIf` results say `planned` and `PolicyWritten=false`.
- Added portable PowerShell source acceptance to Ubuntu CI, Windows PowerShell 5.1 CI,
  and the pre-push gate; CI now checks out full history so evidence commits resolve.
- Closed the executed PowerShell boundary after GitHub Actions run 33249923094 passed on
  both PowerShell 7 and Windows PowerShell 5.1.
- Re-closed the verifier and PowerShell boundary only after the exact-root repair passed
  GitHub Actions run 33254551558, including Windows repository tests.
- Split host/version failure messages so Windows 10 is not falsely reported as an
  unsupported `Professional` edition.
- Added version-aware launch selection: Windows 10 build 19045 uses the legacy native
  `.wsb` launcher; Windows 11 build 26100+ retains the managed `wsb.exe` lifecycle.
- Windows 10 state now records PID, executable path, and process creation identity and
  intentionally leaves `sandboxId` empty rather than claiming feature equivalence.
- Resource measurement and live acceptance now clean up each launch using the correct
  lifecycle contract.
- Removed arbitrary GUID scraping from managed-session discovery. Airlock accepts only
  an exact lowercase `id` in the provisional `sandboxes` JSON contract and fails closed
  on any other shape.
- Windows 11 now generates the managed ID before `wsb start --id`, so post-start failure
  cleanup can issue a named stop even when `list --raw` has an unknown schema.
- Native stdout and stderr are captured separately; errors report bounded hashes and
  byte counts rather than leaking host paths or mixing diagnostics with JSON.
- All post-start failure paths now stop the recorded identity, wait for confirmed
  shutdown, preserve the original launch error, and remove only matching state/staging.
- Stale state from an externally closed guest is reconciled before a new launch, while
  identity mismatch and stop timeout retain recovery state and fail closed.
- The three-run benchmark now waits for confirmed teardown and stops the sequence after
  any teardown failure.
- Replaced Windows PowerShell-incompatible generic-list array coercion with `.ToArray()`;
  the exact behavior passes both Windows PowerShell 5.1 and PowerShell 7 in CI.

### Added

- Binding Airlock build brief.
- Complete 45-requirement backlog and explicit MVP exclusions.
- Open-question register including writable-installer tampering risk.
- Machine-readable board, Ready/Done contract, traceability, and Increment 0 demo.
- Standard-library verifier, unit tests, seeded-lie proof, CI, and tracked pre-push gate
  under S-00.01.01.
- Increment 1 strict-offline policy, signed Brave package pinning, Windows preflight,
  deterministic Sandbox XML generation, single-session launch, guest provisioning, and
  machine-readable session/result records.
- Static negative-control tests, target-Windows acceptance script, three-run resource
  collector with collect-only and enforced modes, and Windows PowerShell parser CI.
- Architecture, threat-boundary, launch, rollback, and pasteable demo documentation.
- `scripts/Airlock.Platform.ps1` for deterministic Windows 10/11 platform selection.
- `tests/Invoke-CompatibilityAcceptance.ps1`, wired into CI and pre-push, to prove both
  platform contracts and legacy process-identity rules without starting a real Sandbox.
- `scripts/Airlock.Lifecycle.ps1` as the shared identity, stop, wait, stale-state, and
  exact-owned-cleanup contract for launch, manual stop, acceptance, and benchmarking.
- `scripts/Stop-Airlock.ps1`, with mutex protection, `-WhatIf`, bounded timeout, and
  optional JSON output for both managed-ID and guarded legacy-process modes.
- `tests/Invoke-LifecycleAcceptance.ps1`, wired into CI and pre-push, with four named
  lifecycle acceptance tests. GitHub Actions run 33472443734 passed on PowerShell 7,
  Windows PowerShell 5.1, Linux Python, and Windows Python.

### Security

- Proposed splitting immutable installers/provisioning inputs from writable profiles and
  workspace. This remains OQ-13 until approved.
- Increment 1 uses a new per-session read-only bootstrap, checks installer signature/hash
  on both host and guest, rejects reparse/broad/audit mappings, and disables network,
  microphone, camera, clipboard, printer, and vGPU explicitly.
- Windows 10 compatibility does not alter the generated strict `.wsb` profile. Only the
  native lifecycle control changes.
- Legacy termination is allowed only after recorded PID, executable path, and process
  creation identity still match, reducing PID-reuse risk.
- Managed cleanup issues `wsb stop --id <generated-id>` before querying provisional raw
  status, so an undocumented list schema cannot prevent the stop attempt. Confirmation
  still fails closed until the target contract is known.
- Session artifact removal canonicalises state paths, rejects reparse points, verifies
  the exact session key, and never removes an unrelated session directory.

### Migration and rollback

- No database or guest-state migration is required.
- Host `active-session.json` remains schema version 1 and gains `launchMode`,
  `lifecycleControl`, optional `launcherPath`, and legacy process-identity fields.
  Windows 11 now stores the caller-generated `sandboxId`; older schema-1 state remains
  readable because `launcherPath` is not required by validation.
- Roll back S-06.05.01 by reverting its source commits. Existing policy locks and pinned
  packages remain valid because the strict `.wsb` policy and installer contract did not
  change.
- Before rollback, run `scripts\Stop-Airlock.ps1` and require confirmed shutdown and
  reconciliation. Do not manually delete state for a possibly active guest. On Windows
  10, never kill a PID unless executable path and process creation identity match
  recorded Airlock state.
