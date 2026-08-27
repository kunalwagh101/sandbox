from pathlib import Path
import tempfile
import textwrap
import unittest

from scripts.verify_board import (
    BASELINE_CONTRACT_IDS,
    BASELINE_REQUIREMENT_IDS,
    RepositoryVerifier,
    format_result,
)


STORY_ID = "S-00.00.01"
TEST_REF = "tests/test_sample.py::SampleTests.test_exists"
TEST_SELECTOR = "tests.test_sample.SampleTests.test_exists"


def _requirement_rows():
    return "\n        ".join(
        f"| {requirement_id} | Fixture requirement |"
        for requirement_id in sorted(BASELINE_REQUIREMENT_IDS)
    )


def _coverage_rows(omit_last=False):
    requirement_ids = sorted(BASELINE_REQUIREMENT_IDS)
    if omit_last:
        requirement_ids = requirement_ids[:-1]
    return "\n        ".join(
        f"| {requirement_id} | {STORY_ID} |" for requirement_id in requirement_ids
    )


def _contract_rows(omit_last=False):
    contract_ids = sorted(BASELINE_CONTRACT_IDS)
    if omit_last:
        contract_ids = contract_ids[:-1]
    return "\n        ".join(
        f"| {contract_id} | {STORY_ID} |" for contract_id in contract_ids
    )


def _backlog(test_ref=TEST_REF, omit_last_coverage=False, omit_last_contract=False):
    return textwrap.dedent(
        f"""
        # Backlog

        EXPECTED_REQUIREMENTS: 45

        <!-- REQUIREMENTS_START -->
        | Requirement ID | Short name |
        |---|---|
        {_requirement_rows()}
        <!-- REQUIREMENTS_END -->

        <!-- CONTRACT_COVERAGE_START -->
        | Contract ID | Backlog story IDs |
        |---|---|
        {_contract_rows(omit_last_contract)}
        <!-- CONTRACT_COVERAGE_END -->

        ## E-00 — Fixture epic

        - Owner: Test owner
        - Outcome: Deterministic verification
        - Value hypothesis: Contract failures remain reproducible.

        ### F-00.00 — Fixture feature

        - Parent: E-00
        - Capability: Exercise one verifier path.

        #### Story {STORY_ID} — Fixture story

        - User story: As a tester, I want a fixture, so that verification is deterministic.
        - Business value: E-00 — verifies the verifier.
        - Increment: 0
        - Size: S
        - Leading indicator: Deterministic failures.
        - Dependencies: None.
        - Blocking risk: None.
        - Acceptance criteria:
          - AC-{STORY_ID}-01 | Given a fixture, When verification runs, Then its status is exact. | Test: {test_ref}
        - Tasks:
          - T-00.00.01.a: Build one deterministic fixture.

        <!-- COVERAGE_START -->
        | Requirement ID | Backlog story IDs |
        |---|---|
        {_coverage_rows(omit_last_coverage)}
        <!-- COVERAGE_END -->
        """
    ).strip() + "\n"


def _evidence(
    test_ref=TEST_REF,
    *,
    command=f"python -m unittest {TEST_SELECTOR} -v",
    code_ref="scripts/sample.py:1-1",
    commit="abcdef1",
):
    return textwrap.dedent(
        f"""

        EVIDENCE {STORY_ID}
        tests: {test_ref}
        command: {command}
        result: 1 passed (run 2026-08-27)
        code: {code_ref}
        commit: {commit}
        criteria: AC-{STORY_ID}-01={test_ref}
        END EVIDENCE
        """
    )


def _board(status="BACKLOG", evidence="", board_story_id=STORY_ID, note="fixture"):
    board = textwrap.dedent(
        f"""
        # Board

        WIP_LIMIT: 1
        BACKLOG_APPROVED: false

        <!-- BOARD_START -->
        | Story ID | Status | Increment | Blocker or note |
        |---|---|---|---|
        | {board_story_id} | {status} | 0 | {note} |
        <!-- BOARD_END -->
        """
    ).strip() + "\n"
    return board + evidence.lstrip("\n")


class FixtureRepository:
    def __init__(
        self,
        *,
        status="BACKLOG",
        test_ref=TEST_REF,
        evidence=None,
        omit_last_coverage=False,
        omit_last_contract=False,
        board_story_id=STORY_ID,
        test_passes=True,
        code="VALUE = 1\n",
    ):
        self._temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary_directory.name)
        (self.root / "tests").mkdir()
        (self.root / "scripts").mkdir()
        (self.root / "tests" / "__init__.py").write_text("", encoding="utf-8")
        assertion = "self.assertTrue(True)" if test_passes else "self.fail('seeded failure')"
        (self.root / "tests" / "test_sample.py").write_text(
            textwrap.dedent(
                f"""
                import unittest

                class SampleTests(unittest.TestCase):
                    def test_exists(self):
                        {assertion}
                """
            ).strip()
            + "\n",
            encoding="utf-8",
        )
        (self.root / "scripts" / "sample.py").write_text(code, encoding="utf-8")
        (self.root / "PRODUCT_BACKLOG.md").write_text(
            _backlog(test_ref, omit_last_coverage, omit_last_contract), encoding="utf-8"
        )
        board_evidence = evidence
        if board_evidence is None and status == "DONE":
            board_evidence = _evidence(test_ref)
        (self.root / "BOARD.md").write_text(
            _board(status, board_evidence or "", board_story_id), encoding="utf-8"
        )

    def cleanup(self):
        self._temporary_directory.cleanup()


class VerifierContractTests(unittest.TestCase):
    def test_scope_and_board_lies_fail(self):
        cases = (
            (FixtureRepository(omit_last_coverage=True), "orphan requirements:"),
            (
                FixtureRepository(omit_last_contract=True),
                "orphan delivery contracts:",
            ),
            (
                FixtureRepository(board_story_id="S-00.00.02"),
                f"stories missing from board: {STORY_ID}",
            ),
        )
        for fixture, expected in cases:
            with self.subTest(expected=expected):
                self.addCleanup(fixture.cleanup)
                result = RepositoryVerifier(
                    fixture.root, run_evidence_tests=False
                ).verify()
                self.assertFalse(result.ok)
                self.assertIn(expected, "\n".join(result.errors))

    def test_done_evidence_lies_fail(self):
        missing_test = "tests/test_does_not_exist.py::MissingTests.test_lie"
        cases = (
            (FixtureRepository(status="DONE", evidence=" "), "DONE story lacks evidence"),
            (
                FixtureRepository(status="DONE", test_ref=missing_test),
                "test file does not exist: tests/test_does_not_exist.py",
            ),
            (
                FixtureRepository(
                    status="DONE", evidence=_evidence(code_ref="scripts/sample.py:2-3")
                ),
                "code line range does not exist",
            ),
            (
                FixtureRepository(status="DONE", evidence=_evidence(commit="not-a-sha")),
                "invalid commit value",
            ),
            (
                FixtureRepository(status="DONE", code="pass\n"),
                "bare pass stub",
            ),
            (
                FixtureRepository(status="DONE", code="VALUE = None  # TODO\n"),
                "stub marker",
            ),
            (
                FixtureRepository(status="DONE", code="VALUE = None  # FIXME\n"),
                "stub marker",
            ),
            (
                FixtureRepository(status="DONE", code="raise NotImplementedError\n"),
                "stub marker",
            ),
        )
        for fixture, expected in cases:
            with self.subTest(expected=expected):
                self.addCleanup(fixture.cleanup)
                result = RepositoryVerifier(
                    fixture.root, run_evidence_tests=False
                ).verify()
                self.assertFalse(result.ok)
                self.assertIn(expected, "\n".join(result.errors))

    def test_done_tests_are_rerun_and_summary_is_truthful(self):
        passing = FixtureRepository(status="DONE")
        failing = FixtureRepository(status="DONE", test_passes=False)
        self.addCleanup(passing.cleanup)
        self.addCleanup(failing.cleanup)

        result = RepositoryVerifier(passing.root, run_evidence_tests=True).verify()
        self.assertTrue(result.ok, result.errors)
        self.assertIn("OK", result.evidence_outputs[STORY_ID])
        output = format_result(result)
        self.assertIn("DONE=1", output)
        self.assertIn("AC TEST COVERAGE: 1/1 (100.0%)", output)
        self.assertIn("NOT BUILT: 0", output)

        failed_result = RepositoryVerifier(failing.root, run_evidence_tests=True).verify()
        self.assertFalse(failed_result.ok)
        self.assertIn("evidence command failed", "\n".join(failed_result.errors))

    def test_requirement_substitution_fails(self):
        fixture = FixtureRepository()
        self.addCleanup(fixture.cleanup)
        backlog_path = fixture.root / "PRODUCT_BACKLOG.md"
        backlog = backlog_path.read_text(encoding="utf-8")
        backlog_path.write_text(
            backlog.replace("R-APP-01", "R-FAKE-01"), encoding="utf-8"
        )
        result = RepositoryVerifier(fixture.root, run_evidence_tests=False).verify()
        self.assertFalse(result.ok)
        self.assertIn("binding requirements missing: R-APP-01", "\n".join(result.errors))

    def test_unsafe_or_incomplete_evidence_command_fails(self):
        command = "python -c print('not a test')"
        fixture = FixtureRepository(status="DONE", evidence=_evidence(command=command))
        self.addCleanup(fixture.cleanup)
        result = RepositoryVerifier(fixture.root, run_evidence_tests=False).verify()
        self.assertFalse(result.ok)
        self.assertIn("must run unittest", "\n".join(result.errors))


if __name__ == "__main__":
    unittest.main()
