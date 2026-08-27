"""Demonstrate that a DONE story with a missing test is rejected."""

from pathlib import Path
import subprocess
import sys

from tests.test_verify_board import FixtureRepository


def main():
    missing = "tests/test_does_not_exist.py::MissingTests.test_lie"
    fixture = FixtureRepository(status="DONE", test_ref=missing)
    try:
        verifier = Path(__file__).resolve().parents[1] / "scripts" / "verify_board.py"
        process = subprocess.run(
            [sys.executable, str(verifier), "--root", str(fixture.root)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=30,
        )
        print(process.stdout, end="")
        print(f"OBSERVED_EXIT_CODE: {process.returncode}")
        expected_error = "test file does not exist: tests/test_does_not_exist.py"
        if process.returncode == 0 or expected_error not in process.stdout:
            print("SEEDED_LIE_PROOF: FAILED")
            return 1
        print("SEEDED_LIE_PROOF: PASSED")
        return 0
    finally:
        fixture.cleanup()


if __name__ == "__main__":
    raise SystemExit(main())
