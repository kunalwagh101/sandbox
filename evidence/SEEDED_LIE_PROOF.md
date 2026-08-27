# Seeded Lie Proof

Run date: 2026-08-27

Command:

    python -m tests.seeded_lie_demo

Observed output:

    VERIFICATION: FAILED
    ERROR: S-00.00.01 test file does not exist: tests/test_does_not_exist.py
    ERROR: S-00.00.01 evidence command omits named tests: tests.test_does_not_exist.MissingTests.test_lie
    BOARD: BACKLOG=0 | BLOCKED=0 | DEFERRED=0 | DONE=1 | IN_PROGRESS=0 | IN_REVIEW=0 | READY=0
    AC TEST COVERAGE: 0/1 (0.0%)
    NOT BUILT: 0
    OBSERVED_EXIT_CODE: 1
    SEEDED_LIE_PROOF: PASSED

The outer demo exits zero only because the inner verifier failed with the expected
non-zero exit and named the planted missing-test lie.
