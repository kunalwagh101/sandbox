# Contributing to Airlock

Thanks for helping improve Airlock. Because this project enforces a security boundary, changes are reviewed more strictly than ordinary application code.

## Before you start

- Read `README.md`, `docs/ARCHITECTURE.md`, `docs/THREAT_MODEL.md`, `DEFINITION_OF_DONE.md`, and `BOARD.md`.
- Search existing issues and pull requests before opening new work.
- Do not weaken security controls to make a test pass.
- Do not commit installers, credentials, private keys, customer data, machine-specific secrets, or generated Airlock state.

For substantial design changes, open an issue first so the threat model and acceptance criteria can be agreed before implementation.

## Development setup

Airlock is primarily PowerShell with Python verification tooling.

Run the repository checks before submitting a pull request:

```powershell
python -m unittest discover -s tests -v
python scripts/verify_board.py
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-SourceAcceptance.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-CompatibilityAcceptance.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-LifecycleAcceptance.ps1
```

Live Windows Sandbox acceptance is required for changes that affect native launch, mappings, provisioning, lifecycle, Windows version support, or security controls:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-Increment1Acceptance.ps1 -RunLive
```

Do not claim a live boundary is validated when only source tests have run.

## Pull-request requirements

A good pull request should:

1. explain the user/security problem;
2. identify the affected threat boundary;
3. describe the smallest production-safe fix;
4. include or update tests;
5. include documentation and migration/rollback notes when relevant;
6. preserve truthful board/evidence status;
7. list exact commands run and their results;
8. avoid unrelated cleanup that makes security review harder.

## Security-sensitive changes

Changes to any of the following deserve explicit threat review:

- `.wsb` generation and mapped folders;
- network/device/clipboard/vGPU policy;
- installer trust, signatures, hashes, or package pinning;
- path canonicalisation, junctions, symlinks, or reparse points;
- process/Sandbox identity and shutdown;
- host state and cleanup;
- guest-to-host writable data;
- supported Windows versions and launchers.

Fail closed when identity, trust, or policy is ambiguous.

## Commit and code style

- Prefer small, focused commits.
- Use descriptive commit messages.
- Reuse existing helpers before adding parallel implementations.
- Prefer native platform capabilities and standard-library functionality when they satisfy the requirement safely.
- Keep errors actionable and security decisions explicit.

## Licensing of contributions

By submitting a contribution to this repository, you agree that your contribution is submitted under the Apache License 2.0 as described in `LICENSE`, unless you clearly state otherwise before submission.

## Code of conduct

Participation is governed by `CODE_OF_CONDUCT.md`.
