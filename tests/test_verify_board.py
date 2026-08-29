from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

from scripts.verify_board import (
    BoardItem,
    BASELINE_CONTRACT_IDS,
    BASELINE_AUDIT_IDS,
    BASELINE_REQUIREMENT_IDS,
    RepositoryVerifier,
    _board_flow_errors,
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


def _audit_rows(omit_last=False):
    finding_ids = sorted(BASELINE_AUDIT_IDS)
    if omit_last:
        finding_ids = finding_ids[:-1]
    return "\n        ".join(
        f"| {finding_id} | Fixture | {STORY_ID} | fixture repair |"
        for finding_id in finding_ids
    )


def _backlog(
    test_ref=TEST_REF,
    omit_last_coverage=False,
    omit_last_contract=False,
    omit_last_audit=False,
):
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

        EXPECTED_AUDIT_FINDINGS: 23

        <!-- AUDIT_START -->
        | Finding ID | Severity | Repair story | Repair intent |
        |---|---|---|---|
        {_audit_rows(omit_last_audit)}
        <!-- AUDIT_END -->

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
        omit_last_audit=False,
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
            _backlog(
                test_ref,
                omit_last_coverage,
                omit_last_contract,
                omit_last_audit,
            ),
            encoding="utf-8",
        )
        board_evidence = evidence
        if board_evidence is None and status == "DONE":
            board_evidence = _evidence(test_ref)
        (self.root / "BOARD.md").write_text(
            _board(status, board_evidence or "", board_story_id), encoding="utf-8"
        )
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(
            ["git", "config", "user.name", "Airlock Test"], cwd=self.root, check=True
        )
        subprocess.run(
            ["git", "config", "user.email", "airlock-test@example.invalid"],
            cwd=self.root,
            check=True,
        )
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "fixture"], cwd=self.root, check=True
        )
        self.commit = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=self.root,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        ).stdout.strip()
        board_path = self.root / "BOARD.md"
        board_path.write_text(
            board_path.read_text(encoding="utf-8").replace(
                "commit: abcdef1", f"commit: {self.commit}"
            ),
            encoding="utf-8",
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
                FixtureRepository(omit_last_audit=True),
                "orphan audit findings:",
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
            (
                FixtureRepository(
                    status="DONE", code="VALUE = 1\n# TODO outside cited range\n"
                ),
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
        self.assertIn("AC TESTS RESOLVED: 1/1 (100.0%)", output)
        self.assertNotIn("AC TEST COVERAGE", output)
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

    def test_commit_must_resolve_in_git_repository(self):
        fixture = FixtureRepository(status="DONE")
        self.addCleanup(fixture.cleanup)
        (fixture.root / ".git").rename(fixture.root / ".git-disabled")
        result = RepositoryVerifier(fixture.root, run_evidence_tests=False).verify()
        self.assertFalse(result.ok)
        self.assertIn(
            "commit unverifiable: no Git repository", "\n".join(result.errors)
        )

    def test_implemented_backlog_story_fails(self):
        fixture = FixtureRepository(status="BACKLOG")
        self.addCleanup(fixture.cleanup)
        result = RepositoryVerifier(fixture.root, run_evidence_tests=False).verify()
        self.assertFalse(result.ok)
        self.assertIn(
            f"{STORY_ID} remains BACKLOG with implemented acceptance tests",
            "\n".join(result.errors),
        )

    def test_summary_does_not_overclaim_coverage(self):
        fixture = FixtureRepository(status="DONE")
        self.addCleanup(fixture.cleanup)
        result = RepositoryVerifier(fixture.root, run_evidence_tests=False).verify()
        output = format_result(result)
        self.assertIn("AC TESTS RESOLVED", output)
        self.assertNotIn("AC TEST COVERAGE", output)

    def test_escalated_blocker_requires_explicit_repair(self):
        blocked = BoardItem(
            STORY_ID,
            "BLOCKED",
            "0",
            "External: target host; escalated=AUDIT-TEST",
        )
        repair = BoardItem(
            "S-00.00.02", "IN_PROGRESS", "0", f"repair-for={STORY_ID}"
        )
        self.assertEqual([], _board_flow_errors({"blocked": blocked, "repair": repair}, 1))

        missing_escalation = BoardItem(
            STORY_ID, "BLOCKED", "0", "External: target host"
        )
        errors = _board_flow_errors(
            {"blocked": missing_escalation, "repair": repair}, 1
        )
        self.assertIn("blocked stories lack explicit escalation", "\n".join(errors))

        ordinary_work = BoardItem(
            "S-00.00.02", "IN_PROGRESS", "0", "new feature"
        )
        errors = _board_flow_errors(
            {"blocked": blocked, "ordinary": ordinary_work}, 1
        )
        self.assertIn("not an explicit repair", "\n".join(errors))

    def test_done_stub_scan_covers_whole_powershell_file(self):
        fixture = FixtureRepository(status="DONE")
        self.addCleanup(fixture.cleanup)
        powershell_path = fixture.root / "scripts" / "sample.ps1"
        powershell_path.write_text(
            "function Invoke-Placeholder { }\nVALUE = 1\n", encoding="utf-8"
        )
        board_path = fixture.root / "BOARD.md"
        board_path.write_text(
            board_path.read_text(encoding="utf-8").replace(
                "scripts/sample.py:1-1", "scripts/sample.ps1:2-2"
            ),
            encoding="utf-8",
        )
        result = RepositoryVerifier(fixture.root, run_evidence_tests=False).verify()
        self.assertFalse(result.ok)
        self.assertIn("empty PowerShell function", "\n".join(result.errors))


if __name__ == "__main__":
    unittest.main()
