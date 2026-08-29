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

### Security

- Proposed splitting immutable installers/provisioning inputs from writable profiles and
  workspace. This remains OQ-13 until approved.
- Increment 1 uses a new per-session read-only bootstrap, checks installer signature/hash
  on both host and guest, rejects reparse/broad/audit mappings, and disables network,
  microphone, camera, clipboard, printer, and vGPU explicitly.

### Migration and rollback

- No Windows runtime, database, or user data changed in Increment 0.
- Roll back the repository contract by reverting the Increment 0 commits. Disable the
  local tracked hook, if installed, with `git config --unset core.hooksPath`.
- Source development changed no Windows host. On a target host, initialisation writes only
  under `%LOCALAPPDATA%\Airlock`; launch creates disposable guest state and per-session
  staging. Stop a live guest with `wsb stop --id <sandbox-id>` before any manual cleanup.
