from pathlib import Path
import unittest

from scripts.verify_board import (
    BASELINE_REQUIREMENT_IDS,
    RepositoryVerifier,
    parse_change_requirements,
    parse_change_coverage,
    parse_requirements,
)


ROOT = Path(__file__).resolve().parents[1]


class ProjectContractTests(unittest.TestCase):
    def test_exactly_45_requirements_are_declared(self):
        backlog = (ROOT / "PRODUCT_BACKLOG.md").read_text(encoding="utf-8")
        expected, requirements = parse_requirements(backlog)
        self.assertEqual(45, expected)
        self.assertEqual(45, len(requirements))
        self.assertEqual(BASELINE_REQUIREMENT_IDS, requirements)

    def test_current_repository_passes_without_running_evidence(self):
        result = RepositoryVerifier(ROOT, run_evidence_tests=False).verify()
        self.assertTrue(result.ok, "\n".join(result.errors))

    def test_approved_change_is_traceable(self):
        backlog = (ROOT / "PRODUCT_BACKLOG.md").read_text(encoding="utf-8")
        expected, changes = parse_change_requirements(backlog)
        coverage = parse_change_coverage(backlog)
        self.assertEqual(1, expected)
        self.assertEqual({"CR-2026-08-30-01"}, changes)
        self.assertEqual({"S-06.05.01"}, coverage["CR-2026-08-30-01"])

    def test_ci_and_pre_push_run_required_checks(self):
        hook = (ROOT / ".githooks" / "pre-push").read_text(encoding="utf-8")
        self.assertIn("scripts/verify_board.py", hook)
        self.assertIn("unittest", hook)
        self.assertNotIn("--no-", hook)
        self.assertIn("Invoke-SourceAcceptance.ps1", hook)
        self.assertIn("Invoke-CompatibilityAcceptance.ps1", hook)

        workflow = (
            ROOT / ".github" / "workflows" / "verify-board.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("python scripts/verify_board.py", workflow)
        self.assertIn("python -m unittest discover -s tests -v", workflow)
        self.assertEqual(2, workflow.count("fetch-depth: 0"))
        self.assertIn("runs-on: windows-latest", workflow)
        self.assertIn("Language.Parser]::ParseFile", workflow)
        self.assertGreaterEqual(workflow.count("Invoke-SourceAcceptance.ps1"), 2)
        self.assertGreaterEqual(workflow.count("Invoke-CompatibilityAcceptance.ps1"), 2)


if __name__ == "__main__":
    unittest.main()
