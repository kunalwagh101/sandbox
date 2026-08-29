# Airlock Board

**Schema:** 1
**Single source of truth:** This table, not chat.
**WIP limit:** IN_PROGRESS <= 1 for the current single-engineer workflow.
**Backlog approval:** APPROVED by product owner on 2026-08-27. The product owner
approved the 23-finding repair register on 2026-08-29 after reproducing AL-01 and AL-02.

WIP_LIMIT: 1
BACKLOG_APPROVED: true

## Current sprint

- Increment: R1 — Restore launch and evidence truth
- Sprint goal: Remove the reproduced launch blocker, execute the PowerShell security
  boundary in CI, make session cleanup truthful, and remove unsupported product claims.
- Pull rule: S-06.02.01 is complete. S-06.03.01 stays BACKLOG until its command contract
  satisfies the Definition of Ready; OQ-14 target-host evidence is still outstanding.
- Escalation rule: Increment 1 stories are BLOCKED by AUDIT-2026-08-28 and explicitly
  escalated. R1 is the approved repair work that resolves those blockers.
- Target-host rule: Linux and CI can prove deterministic source behaviour; OQ-01 still
  blocks claims that require a real Windows Sandbox launch.
- Review checkpoint: GitHub Actions run 33249923094 passed the verifier, 21 Python tests,
  portable PowerShell, and Windows PowerShell 5.1 on 2026-08-29. Live launch remains blocked.

## Story board

<!-- BOARD_START -->
| Story ID | Status | Increment | Blocker or note |
|---|---|---:|---|
| S-00.01.01 | DONE | 0 | Repaired distributed evidence below; no Windows feature claim |
| S-01.01.01 | BLOCKED | 1 | External: AUDIT-2026-08-28; OQ-01; escalated=2026-08-29; AL-01,04,05,07,23 |
| S-01.02.01 | BLOCKED | 1 | OQ-04; escalated=AUDIT-2026-08-28; AL-03,09,10,11,13,14,15,19 |
| S-01.02.02 | BLOCKED | 1 | External: installer acceptance; escalated=AUDIT-2026-08-28; AL-12,16 |
| S-01.02.03 | BLOCKED | 1 | OQ-10; escalated=AUDIT-2026-08-28; AL-06,08 |
| S-02.01.01 | BACKLOG | 2 | S-01.02.03; OQ-07; OQ-13 |
| S-02.01.02 | BACKLOG | 2 | S-02.01.01; OQ-05 |
| S-02.01.03 | BACKLOG | 5 | S-02.01.02; OQ-03 |
| S-03.01.01 | BACKLOG | 3 | S-02.01.02; OQ-02; OQ-06; OQ-11 |
| S-03.02.01 | BACKLOG | 3 | S-03.01.01; OQ-06; OQ-11 |
| S-03.02.02 | BACKLOG | 3 | S-03.02.01 |
| S-03.02.03 | BACKLOG | 3 | S-03.02.01 |
| S-04.01.01 | BACKLOG | 4 | S-03.02.03 |
| S-04.01.02 | BACKLOG | 4 | S-04.01.01; OQ-12 |
| S-04.01.03 | BACKLOG | 4 | S-01.02.01 |
| S-05.01.01 | DEFERRED | 5 | reason=offline Increment 1 cannot browse; revisit=after S-02.01.02 and OQ-08 approval |
| S-05.02.01 | BACKLOG | 5 | S-05.01.01 |
| S-05.02.02 | BACKLOG | 5 | S-02.01.01; OQ-07 |
| S-05.03.01 | BACKLOG | 5 | S-04.01.02; S-05.01.01 |
| S-05.03.02 | BACKLOG | 5 | S-05.02.02; S-05.03.01 |
| S-06.01.01 | DONE | R1 | Evidence below; AL-02,18,20,21,22 repaired |
| S-06.02.01 | DONE | R1 | Evidence below; AL-01,03,09,10,11,13,14,15,19 repaired |
| S-06.03.01 | BACKLOG | R1 | S-06.02.01; AL-04,05,06,07,08,23 |
| S-06.04.01 | BACKLOG | R1 | S-06.03.01; AL-12,16,17 |
<!-- BOARD_END -->

## Evidence ledger

EVIDENCE S-00.01.01
tests: tests/test_verify_board.py::VerifierContractTests.test_scope_and_board_lies_fail; tests/test_verify_board.py::VerifierContractTests.test_done_evidence_lies_fail; tests/test_verify_board.py::VerifierContractTests.test_done_tests_are_rerun_and_summary_is_truthful; tests/test_project_contract.py::ProjectContractTests.test_ci_and_pre_push_run_required_checks
command: python -m unittest tests.test_verify_board.VerifierContractTests.test_scope_and_board_lies_fail tests.test_verify_board.VerifierContractTests.test_done_evidence_lies_fail tests.test_verify_board.VerifierContractTests.test_done_tests_are_rerun_and_summary_is_truthful tests.test_project_contract.ProjectContractTests.test_ci_and_pre_push_run_required_checks -v
result: 4 passed (run 2026-08-29)
code: scripts/verify_board.py
commit: 9f1429d68d7e0997e7ec6403fd73dcaa05fdde2f
criteria: AC-S-00.01.01-01=tests/test_verify_board.py::VerifierContractTests.test_scope_and_board_lies_fail; AC-S-00.01.01-02=tests/test_verify_board.py::VerifierContractTests.test_done_evidence_lies_fail; AC-S-00.01.01-03=tests/test_verify_board.py::VerifierContractTests.test_done_tests_are_rerun_and_summary_is_truthful; AC-S-00.01.01-04=tests/test_project_contract.py::ProjectContractTests.test_ci_and_pre_push_run_required_checks
END EVIDENCE

EVIDENCE S-06.01.01
tests: tests/test_verify_board.py::VerifierContractTests.test_commit_must_resolve_in_git_repository; tests/test_verify_board.py::VerifierContractTests.test_implemented_backlog_story_fails; tests/test_verify_board.py::VerifierContractTests.test_summary_does_not_overclaim_coverage; tests/test_verify_board.py::VerifierContractTests.test_escalated_blocker_requires_explicit_repair
command: python -m unittest tests.test_verify_board.VerifierContractTests.test_commit_must_resolve_in_git_repository tests.test_verify_board.VerifierContractTests.test_implemented_backlog_story_fails tests.test_verify_board.VerifierContractTests.test_summary_does_not_overclaim_coverage tests.test_verify_board.VerifierContractTests.test_escalated_blocker_requires_explicit_repair -v
result: 4 passed (run 2026-08-29)
code: scripts/verify_board.py
commit: 9f1429d68d7e0997e7ec6403fd73dcaa05fdde2f
criteria: AC-S-06.01.01-01=tests/test_verify_board.py::VerifierContractTests.test_commit_must_resolve_in_git_repository; AC-S-06.01.01-02=tests/test_verify_board.py::VerifierContractTests.test_implemented_backlog_story_fails; AC-S-06.01.01-03=tests/test_verify_board.py::VerifierContractTests.test_summary_does_not_overclaim_coverage; AC-S-06.01.01-04=tests/test_verify_board.py::VerifierContractTests.test_escalated_blocker_requires_explicit_repair
END EVIDENCE

EVIDENCE S-06.02.01
tests: tests/Invoke-SourceAcceptance.ps1::Test-ReparseTraversal; tests/Invoke-SourceAcceptance.ps1::Test-GeneratedStrictProfile; tests/Invoke-SourceAcceptance.ps1::Test-RelativeProtectedPaths; tests/Invoke-SourceAcceptance.ps1::Test-StateWriteContract
command: powershell -NoProfile -File tests/Invoke-SourceAcceptance.ps1
result: 4 passed on pwsh and Windows PowerShell 5.1; CI run 33249923094 (run 2026-08-29)
code: scripts/Airlock.Common.ps1; scripts/New-AirlockProfile.ps1; scripts/Initialize-Airlock.ps1
commit: 4605ab01e3cc19692f3dd878f1f5810761783f27
criteria: AC-S-06.02.01-01=tests/Invoke-SourceAcceptance.ps1::Test-ReparseTraversal; AC-S-06.02.01-02=tests/Invoke-SourceAcceptance.ps1::Test-GeneratedStrictProfile; AC-S-06.02.01-03=tests/Invoke-SourceAcceptance.ps1::Test-RelativeProtectedPaths; AC-S-06.02.01-04=tests/Invoke-SourceAcceptance.ps1::Test-StateWriteContract
END EVIDENCE

## Deferred register

- S-05.01.01 / online browsing: reason=Increment 1 intentionally disables networking,
  so Brave can prove isolation but cannot browse; revisit=after the CLI toolchain exists,
  OQ-08 is accepted, and LAN-isolation tests are available. Product-owner approved this
  explicit deferral through AL-17 on 2026-08-29.
