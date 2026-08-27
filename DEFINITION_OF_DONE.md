# Airlock Definition of Ready and Done

## Definition of Ready

A story may move to READY only when all are true:

- Its user story, business value, size, indicator, dependencies, risks, tasks, and machine-testable Given/When/Then criteria exist.
- Upstream stories are DONE.
- Data, path, policy, and command contracts are known.
- No OPEN question can change the story's shape.
- The product owner has approved the backlog and the story belongs to the active increment.
- Required Windows-only acceptance evidence has a named target-host test.
- Pulling the story keeps IN_PROGRESS within the board limit.

## Definition of Done

A story may move to DONE only when all are true:

- Production code is complete inside the slice. There is no unfinished marker, NotImplemented-style exception, or bare placeholder body in the cited code range.
- Every acceptance criterion maps to at least one real test node in its evidence block.
- Error handling, validation, authorisation, path safety, data integrity, concurrency, observability, accessibility, and rollback are covered where the story touches them.
- Negative security tests are shown failing against a deliberately weakened control before passing against the real control.
- The exact evidence command ran in this session and passed.
- Docs and CHANGELOG are updated. Migration and rollback are stated when persistent state changes.
- The evidence names resolvable tests, command, result, code lines, and an existing Git commit.
- BOARD.md is updated and scripts/verify_board.py exits zero.
- Windows-only claims use target-host evidence. Linux-side parser tests cannot prove Windows Sandbox behaviour.

Code that exists but lacks this evidence is IN_REVIEW, not DONE.

## Evidence block schema

Each DONE story has one block in BOARD.md using this exact format:

    EVIDENCE S-01.02.01
    tests: tests/test_profile.ps1::rejects_audio_enabled; tests/test_profile.ps1::emits_strict_profile
    command: pwsh -NoProfile -File tests/test_profile.ps1
    result: 2 passed (run 2026-08-26)
    code: scripts/New-AirlockProfile.ps1:20-180
    commit: 0123456789abcdef
    criteria: AC-S-01.02.01-01=tests/test_profile.ps1::emits_strict_profile; AC-S-01.02.01-02=tests/test_profile.ps1::rejects_broad_mapping
    END EVIDENCE

Rules:

- tests is a semicolon-separated list of repository-relative file::node references.
- command is executed without a shell. Python commands must use `-m unittest` and name
  every listed test directly. PowerShell commands must use `-NoProfile -File` with one
  test script under `tests/`.
- result is retained evidence, but the verifier trusts the re-run rather than the text.
- code is one or more semicolon-separated file:start-end references.
- commit must resolve in the current Git repository.
- criteria maps each acceptance-criterion ID to a named test reference.
- no DONE criterion may remain `TBD`, and every mapped test must appear in tests.
