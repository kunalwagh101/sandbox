# Airlock Board

**Schema:** 1
**Single source of truth:** This table, not chat.
**WIP limit:** IN_PROGRESS <= 1 for the current single-engineer workflow.
**Backlog approval:** APPROVED by product owner on 2026-08-27.

WIP_LIMIT: 1
BACKLOG_APPROVED: true

## Current sprint

- Increment: 1 — Sealed box
- Sprint goal: Launch a strict Windows Sandbox with Brave, no ambient host mapping, no
  capture devices, and measurable resource evidence.
- Pull rule: S-01.01.01 is in review; do not pull its dependent story before live Windows
  acceptance resolves the upstream dependency.
- Target-host rule: OQ-01 blocks Windows acceptance evidence, not source implementation.
- Review checkpoint: 16 repository tests pass; PowerShell parsing and Sandbox behavior
  still require the target Windows runner.

## Story board

<!-- BOARD_START -->
| Story ID | Status | Increment | Blocker or note |
|---|---|---:|---|
| S-00.01.01 | DONE | 0 | Evidence below; no Windows feature claim |
| S-01.01.01 | IN_REVIEW | 1 | External: target Windows acceptance; OQ-01 |
| S-01.02.01 | BACKLOG | 1 | Source prepared; pull after S-01.01.01; OQ-04 |
| S-01.02.02 | BACKLOG | 1 | Source prepared; pull after S-01.02.01; installer evidence |
| S-01.02.03 | BACKLOG | 1 | Collector prepared; pull after S-01.02.02; OQ-10 |
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
| S-05.01.01 | BACKLOG | 5 | S-02.01.02; OQ-08 |
| S-05.02.01 | BACKLOG | 5 | S-05.01.01 |
| S-05.02.02 | BACKLOG | 5 | S-02.01.01; OQ-07 |
| S-05.03.01 | BACKLOG | 5 | S-04.01.02; S-05.01.01 |
| S-05.03.02 | BACKLOG | 5 | S-05.02.02; S-05.03.01 |
<!-- BOARD_END -->

## Evidence ledger

EVIDENCE S-00.01.01
tests: tests/test_verify_board.py::VerifierContractTests.test_scope_and_board_lies_fail; tests/test_verify_board.py::VerifierContractTests.test_done_evidence_lies_fail; tests/test_verify_board.py::VerifierContractTests.test_done_tests_are_rerun_and_summary_is_truthful; tests/test_project_contract.py::ProjectContractTests.test_ci_and_pre_push_run_required_checks
command: python -m unittest tests.test_verify_board.VerifierContractTests.test_scope_and_board_lies_fail tests.test_verify_board.VerifierContractTests.test_done_evidence_lies_fail tests.test_verify_board.VerifierContractTests.test_done_tests_are_rerun_and_summary_is_truthful tests.test_project_contract.ProjectContractTests.test_ci_and_pre_push_run_required_checks -v
result: 4 passed (run 2026-08-27)
code: scripts/verify_board.py:1-880
commit: 9b6cadbd3363242e1786545970d5f762c05a631b
criteria: AC-S-00.01.01-01=tests/test_verify_board.py::VerifierContractTests.test_scope_and_board_lies_fail; AC-S-00.01.01-02=tests/test_verify_board.py::VerifierContractTests.test_done_evidence_lies_fail; AC-S-00.01.01-03=tests/test_verify_board.py::VerifierContractTests.test_done_tests_are_rerun_and_summary_is_truthful; AC-S-00.01.01-04=tests/test_project_contract.py::ProjectContractTests.test_ci_and_pre_push_run_required_checks
END EVIDENCE

## Deferred register

No requirement is deferred. The explicit MVP exclusions remain in PRODUCT_BACKLOG.md.
