# Changelog

## Unreleased

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
