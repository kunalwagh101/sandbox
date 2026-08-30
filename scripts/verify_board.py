#!/usr/bin/env python3
"""Verify that Airlock delivery claims resolve to repository evidence.

The verifier intentionally uses only the Python standard library. It validates the
backlog/board contract first, then reruns evidence commands for DONE stories.
"""

from __future__ import annotations

import argparse
import collections
import dataclasses
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple


REQUIREMENT_GROUP_COUNTS = {
    "PLAT": 3,
    "ISO": 7,
    "DATA": 6,
    "APP": 7,
    "PERM": 10,
    "RES": 4,
    "OPS": 4,
    "SEC": 4,
}
BASELINE_REQUIREMENT_IDS = frozenset(
    f"R-{group}-{index:02d}"
    for group, count in REQUIREMENT_GROUP_COUNTS.items()
    for index in range(1, count + 1)
)
BASELINE_REQUIREMENT_COUNT = len(BASELINE_REQUIREMENT_IDS)
BASELINE_AUDIT_IDS = frozenset(f"AL-{index:02d}" for index in range(1, 24))
BASELINE_CONTRACT_IDS = frozenset(
    {
        "C-DEL-01",
        "C-DEL-02",
        "C-DEL-03",
        "C-DEL-04",
        "C-DEL-05",
        "C-DEL-06",
        "C-AI-01",
        "C-PROD-01",
        "C-ARCH-01",
        "C-ENG-01",
        "C-SEC-01",
        "C-PERF-01",
        "C-OPS-01",
        "C-UI-01",
    }
)
MAX_WIP_LIMIT = 2
VALID_STATUSES = {
    "BACKLOG",
    "READY",
    "IN_PROGRESS",
    "IN_REVIEW",
    "BLOCKED",
    "DONE",
    "DEFERRED",
}
CODE_SUFFIXES = {".py", ".ps1", ".psm1", ".sh", ".js", ".ts", ".cs"}
STUB_MARKERS = ("TO" + "DO", "FIX" + "ME", "Not" + "Implemented")


@dataclasses.dataclass(frozen=True)
class AcceptanceCriterion:
    criterion_id: str
    statement: str
    test_ref: str


@dataclasses.dataclass(frozen=True)
class Story:
    story_id: str
    title: str
    metadata: Mapping[str, str]
    criteria: Tuple[AcceptanceCriterion, ...]
    tasks: Tuple[str, ...]


@dataclasses.dataclass(frozen=True)
class BoardItem:
    story_id: str
    status: str
    increment: str
    note: str


@dataclasses.dataclass(frozen=True)
class Evidence:
    story_id: str
    tests: Tuple[str, ...]
    command: str
    result: str
    code: Tuple[str, ...]
    commit: str
    criteria: Mapping[str, str]


@dataclasses.dataclass
class VerificationResult:
    errors: List[str]
    status_counts: Mapping[str, int]
    tested_criteria: int
    total_criteria: int
    unfinished: List[Tuple[str, str, str]]
    evidence_outputs: Mapping[str, str]

    @property
    def ok(self) -> bool:
        return not self.errors


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise ValueError(f"required file does not exist: {path.name}") from None


def _marked_section(text: str, start: str, end: str) -> str:
    pattern = re.compile(
        rf"<!--\s*{re.escape(start)}\s*-->(.*?)<!--\s*{re.escape(end)}\s*-->",
        re.DOTALL,
    )
    match = pattern.search(text)
    if not match:
        raise ValueError(f"missing marked section {start} ... {end}")
    return match.group(1)


def _table_rows(section: str) -> List[List[str]]:
    rows: List[List[str]] = []
    for raw_line in section.splitlines():
        line = raw_line.strip()
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = [cell.strip() for cell in line[1:-1].split("|")]
        if not cells or all(re.fullmatch(r":?-+:?", cell or "") for cell in cells):
            continue
        if cells[0] in {"Requirement ID", "Story ID"}:
            continue
        rows.append(cells)
    return rows


def parse_requirements(backlog_text: str) -> Tuple[int, Set[str]]:
    expected_match = re.search(r"^EXPECTED_REQUIREMENTS:\s*(\d+)\s*$", backlog_text, re.MULTILINE)
    if not expected_match:
        raise ValueError("PRODUCT_BACKLOG.md lacks EXPECTED_REQUIREMENTS")
    expected = int(expected_match.group(1))
    rows = _table_rows(_marked_section(backlog_text, "REQUIREMENTS_START", "REQUIREMENTS_END"))
    requirements = [row[0] for row in rows if row and re.fullmatch(r"R-[A-Z]+-\d{2}", row[0])]
    duplicates = sorted(item for item, count in collections.Counter(requirements).items() if count > 1)
    if duplicates:
        raise ValueError(f"duplicate requirement IDs: {', '.join(duplicates)}")
    return expected, set(requirements)


def parse_coverage(backlog_text: str) -> Dict[str, Set[str]]:
    rows = _table_rows(_marked_section(backlog_text, "COVERAGE_START", "COVERAGE_END"))
    coverage: Dict[str, Set[str]] = {}
    for row in rows:
        if len(row) < 2 or not re.fullmatch(r"R-[A-Z]+-\d{2}", row[0]):
            continue
        if row[0] in coverage:
            raise ValueError(f"duplicate coverage row: {row[0]}")
        coverage[row[0]] = set(re.findall(r"S-\d{2}\.\d{2}\.\d{2}", row[1]))
    return coverage


def parse_change_requirements(backlog_text: str) -> Tuple[int, Set[str]]:
    expected_match = re.search(
        r"^EXPECTED_CHANGE_REQUIREMENTS:\s*(\d+)\s*$",
        backlog_text,
        re.MULTILINE,
    )
    if not expected_match:
        raise ValueError("PRODUCT_BACKLOG.md lacks EXPECTED_CHANGE_REQUIREMENTS")
    rows = _table_rows(
        _marked_section(
            backlog_text, "CHANGE_REQUIREMENTS_START", "CHANGE_REQUIREMENTS_END"
        )
    )
    change_ids = [
        row[0]
        for row in rows
        if row and re.fullmatch(r"CR-\d{4}-\d{2}-\d{2}-\d{2}", row[0])
    ]
    duplicates = sorted(
        item for item, count in collections.Counter(change_ids).items() if count > 1
    )
    if duplicates:
        raise ValueError(f"duplicate change requirement IDs: {', '.join(duplicates)}")
    return int(expected_match.group(1)), set(change_ids)


def parse_change_coverage(backlog_text: str) -> Dict[str, Set[str]]:
    rows = _table_rows(
        _marked_section(backlog_text, "CHANGE_COVERAGE_START", "CHANGE_COVERAGE_END")
    )
    coverage: Dict[str, Set[str]] = {}
    for row in rows:
        if len(row) < 2 or not re.fullmatch(
            r"CR-\d{4}-\d{2}-\d{2}-\d{2}", row[0]
        ):
            continue
        if row[0] in coverage:
            raise ValueError(f"duplicate change coverage row: {row[0]}")
        coverage[row[0]] = set(re.findall(r"S-\d{2}\.\d{2}\.\d{2}", row[1]))
    return coverage


def parse_contract_coverage(backlog_text: str) -> Dict[str, Set[str]]:
    rows = _table_rows(
        _marked_section(
            backlog_text, "CONTRACT_COVERAGE_START", "CONTRACT_COVERAGE_END"
        )
    )
    coverage: Dict[str, Set[str]] = {}
    for row in rows:
        if len(row) < 2 or not re.fullmatch(r"C-[A-Z]+-\d{2}", row[0]):
            continue
        if row[0] in coverage:
            raise ValueError(f"duplicate contract coverage row: {row[0]}")
        coverage[row[0]] = set(re.findall(r"S-\d{2}\.\d{2}\.\d{2}", row[1]))
    return coverage


def parse_audit_findings(backlog_text: str) -> Tuple[int, Dict[str, str]]:
    expected_match = re.search(
        r"^EXPECTED_AUDIT_FINDINGS:\s*(\d+)\s*$", backlog_text, re.MULTILINE
    )
    if not expected_match:
        raise ValueError("PRODUCT_BACKLOG.md lacks EXPECTED_AUDIT_FINDINGS")
    rows = _table_rows(_marked_section(backlog_text, "AUDIT_START", "AUDIT_END"))
    findings: Dict[str, str] = {}
    for row in rows:
        if len(row) < 3 or not re.fullmatch(r"AL-\d{2}", row[0]):
            continue
        finding_id = row[0]
        if finding_id in findings:
            raise ValueError(f"duplicate audit finding: {finding_id}")
        story_ids = re.findall(r"S-\d{2}\.\d{2}\.\d{2}", row[2])
        if len(story_ids) != 1:
            raise ValueError(f"{finding_id} must map to exactly one repair story")
        findings[finding_id] = story_ids[0]
    return int(expected_match.group(1)), findings


def parse_stories(backlog_text: str) -> Dict[str, Story]:
    epic_ids = set(re.findall(r"^##\s+(E-\d{2})\s+—", backlog_text, re.MULTILINE))
    feature_heading = re.compile(r"^###\s+(F-\d{2}\.\d{2})\s+—", re.MULTILINE)
    feature_matches = list(feature_heading.finditer(backlog_text))
    if not epic_ids or not feature_matches:
        raise ValueError("PRODUCT_BACKLOG.md lacks parseable epic or feature headings")
    feature_parents: Dict[str, str] = {}
    for index, feature_match in enumerate(feature_matches):
        feature_id = feature_match.group(1)
        end = (
            feature_matches[index + 1].start()
            if index + 1 < len(feature_matches)
            else len(backlog_text)
        )
        feature_body = backlog_text[feature_match.end() : end]
        parent_match = re.search(r"^-\s+Parent:\s+(E-\d{2})\s*$", feature_body, re.MULTILINE)
        if not parent_match:
            raise ValueError(f"{feature_id} lacks an epic Parent")
        parent = parent_match.group(1)
        if parent not in epic_ids:
            raise ValueError(f"{feature_id} maps to unknown epic {parent}")
        if feature_id in feature_parents:
            raise ValueError(f"duplicate feature heading: {feature_id}")
        feature_parents[feature_id] = parent

    heading = re.compile(
        r"^#{2,6}\s+(?:Story\s+)?(S-\d{2}\.\d{2}\.\d{2})\s+—\s+(.+?)\s*$",
        re.MULTILINE,
    )
    matches = list(heading.finditer(backlog_text))
    stories: Dict[str, Story] = {}
    required_fields = {
        "User story",
        "Dependencies",
        "Blocking risk",
        "Size",
        "Increment",
        "Leading indicator",
        "Business value",
    }
    for index, match in enumerate(matches):
        story_id, title = match.group(1), match.group(2).strip()
        if story_id in stories:
            raise ValueError(f"duplicate story heading: {story_id}")
        end = matches[index + 1].start() if index + 1 < len(matches) else len(backlog_text)
        body = backlog_text[match.end() : end]
        metadata: Dict[str, str] = {}
        for field, value in re.findall(r"^-\s+([^:\n]+):\s*(.+?)\s*$", body, re.MULTILINE):
            if not field.startswith("AC-"):
                metadata[field.strip()] = value.strip()
        missing = sorted(required_fields - set(metadata))
        if missing:
            raise ValueError(f"{story_id} lacks metadata: {', '.join(missing)}")
        story_parts = story_id[2:].split(".")
        expected_feature = f"F-{story_parts[0]}.{story_parts[1]}"
        active_features = [item for item in feature_matches if item.start() < match.start()]
        active_feature = active_features[-1].group(1) if active_features else ""
        if active_feature != expected_feature:
            raise ValueError(
                f"{story_id} is under {active_feature or 'no feature'}; "
                f"expected {expected_feature}"
            )
        expected_epic = f"E-{story_parts[0]}"
        if feature_parents.get(expected_feature) != expected_epic:
            raise ValueError(f"{story_id} does not trace through {expected_feature} to {expected_epic}")
        user_story = metadata["User story"].lower()
        if not (
            user_story.startswith("as ")
            and ", i want " in user_story
            and ", so that " in user_story
        ):
            raise ValueError(f"{story_id} user story does not use As/I want/so that")
        if not metadata["Business value"].startswith(expected_epic):
            raise ValueError(f"{story_id} business value does not trace to {expected_epic}")

        criteria: List[AcceptanceCriterion] = []
        criterion_pattern = re.compile(
            rf"^\s*-\s+(AC-{re.escape(story_id)}-\d{{2}})\s*(?::|\|)\s*(.+?)\s*$"
        )
        for line in body.splitlines():
            criterion_match = criterion_pattern.match(line)
            if not criterion_match:
                continue
            criterion_id, remainder = criterion_match.groups()
            statement, separator, test_ref = remainder.rpartition("| Test:")
            if not separator:
                statement, test_ref = remainder, "TBD"
            criteria.append(
                AcceptanceCriterion(
                    criterion_id=criterion_id,
                    statement=statement.strip(),
                    test_ref=test_ref.strip(),
                )
            )
        if not criteria:
            raise ValueError(f"{story_id} has no parseable acceptance criteria")
        for criterion in criteria:
            lowered = criterion.statement.lower()
            if not all(word in lowered for word in ("given", "when", "then")):
                raise ValueError(
                    f"{criterion.criterion_id} is not Given/When/Then: {criterion.statement}"
                )
        task_pattern = re.compile(
            rf"^\s*-\s+(T-{re.escape(story_id[2:])}\.[a-z])\s*:",
            re.MULTILINE,
        )
        tasks = tuple(task_pattern.findall(body))
        if not tasks:
            raise ValueError(f"{story_id} has no parseable tasks")
        if len(tasks) != len(set(tasks)):
            raise ValueError(f"{story_id} has duplicate task IDs")
        stories[story_id] = Story(
            story_id=story_id,
            title=title,
            metadata=metadata,
            criteria=tuple(criteria),
            tasks=tasks,
        )
    if not stories:
        raise ValueError("PRODUCT_BACKLOG.md contains no story headings")
    for story in stories.values():
        dependencies = set(re.findall(r"S-\d{2}\.\d{2}\.\d{2}", story.metadata["Dependencies"]))
        if story.story_id in dependencies:
            raise ValueError(f"{story.story_id} depends on itself")
        unknown = sorted(dependencies - set(stories))
        if unknown:
            raise ValueError(
                f"{story.story_id} has unknown story dependencies: {', '.join(unknown)}"
            )
    return stories


def parse_board(board_text: str) -> Dict[str, BoardItem]:
    rows = _table_rows(_marked_section(board_text, "BOARD_START", "BOARD_END"))
    items: Dict[str, BoardItem] = {}
    for row in rows:
        if len(row) != 4 or not re.fullmatch(r"S-\d{2}\.\d{2}\.\d{2}", row[0]):
            continue
        story_id, status, increment, note = row
        if story_id in items:
            raise ValueError(f"duplicate board story: {story_id}")
        items[story_id] = BoardItem(story_id, status, increment, note)
    if not items:
        raise ValueError("BOARD.md contains no machine-readable stories")
    return items


def parse_board_settings(board_text: str) -> Tuple[int, bool]:
    wip_match = re.search(r"^WIP_LIMIT:\s*(\d+)\s*$", board_text, re.MULTILINE)
    approval_match = re.search(
        r"^BACKLOG_APPROVED:\s*(true|false)\s*$",
        board_text,
        re.MULTILINE | re.IGNORECASE,
    )
    if not wip_match:
        raise ValueError("BOARD.md lacks WIP_LIMIT")
    if not approval_match:
        raise ValueError("BOARD.md lacks BACKLOG_APPROVED")
    wip_limit = int(wip_match.group(1))
    if not 1 <= wip_limit <= MAX_WIP_LIMIT:
        raise ValueError(f"WIP_LIMIT must be between 1 and {MAX_WIP_LIMIT}")
    return wip_limit, approval_match.group(1).lower() == "true"


def _split_evidence_list(value: str) -> Tuple[str, ...]:
    return tuple(part.strip() for part in value.split(";") if part.strip())


def parse_evidence(board_text: str) -> Dict[str, Evidence]:
    block_pattern = re.compile(
        r"^EVIDENCE\s+(S-\d{2}\.\d{2}\.\d{2})\s*$"
        r"(.*?)"
        r"^END(?:_|\s+)EVIDENCE\s*$",
        re.MULTILINE | re.DOTALL,
    )
    evidence_by_story: Dict[str, Evidence] = {}
    required = {"tests", "command", "result", "code", "commit", "criteria"}
    for match in block_pattern.finditer(board_text):
        story_id, body = match.group(1), match.group(2)
        if story_id in evidence_by_story:
            raise ValueError(f"duplicate evidence block: {story_id}")
        fields = {
            key: value.strip()
            for key, value in re.findall(
                r"^\s*(tests|command|result|code|commit|criteria):\s*(.+?)\s*$",
                body,
                re.MULTILINE,
            )
        }
        missing = sorted(required - set(fields))
        if missing:
            raise ValueError(f"evidence {story_id} lacks fields: {', '.join(missing)}")
        criteria: Dict[str, str] = {}
        for assignment in _split_evidence_list(fields["criteria"]):
            criterion_id, separator, test_ref = assignment.partition("=")
            if not separator or not criterion_id.strip() or not test_ref.strip():
                raise ValueError(f"evidence {story_id} has invalid criteria mapping")
            criterion_id = criterion_id.strip()
            if criterion_id in criteria:
                raise ValueError(
                    f"evidence {story_id} repeats criterion {criterion_id}"
                )
            criteria[criterion_id] = test_ref.strip()
        evidence_by_story[story_id] = Evidence(
            story_id=story_id,
            tests=_split_evidence_list(fields["tests"]),
            command=fields["command"],
            result=fields["result"],
            code=_split_evidence_list(fields["code"]),
            commit=fields["commit"],
            criteria=criteria,
        )
    return evidence_by_story


def _inside_root(root: Path, candidate: Path) -> bool:
    try:
        candidate.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def _split_test_ref(test_ref: str) -> Tuple[str, Optional[str]]:
    path_text, separator, node = test_ref.partition("::")
    return path_text.strip(), node.strip() if separator else None


def _test_ref_resolves(root: Path, test_ref: str) -> Tuple[bool, str]:
    if test_ref == "TBD":
        return False, "test is TBD"
    path_text, node = _split_test_ref(test_ref)
    path = (root / path_text).resolve()
    if not _inside_root(root, path):
        return False, f"test escapes repository: {path_text}"
    if not path.is_file():
        return False, f"test file does not exist: {path_text}"
    if node:
        symbol = node.split(".")[-1]
        source = path.read_text(encoding="utf-8")
        if path.suffix.lower() == ".py":
            found = re.search(
                rf"^\s*def\s+{re.escape(symbol)}\s*\(", source, re.MULTILINE
            )
        elif path.suffix.lower() == ".ps1":
            found = re.search(
                rf"^\s*(?:function\s+{re.escape(symbol)}\b|It\s+['\"]{re.escape(symbol)}['\"])",
                source,
                re.MULTILINE | re.IGNORECASE,
            )
        else:
            found = re.search(rf"\b{re.escape(symbol)}\b", source)
        if not found:
            return False, f"test node does not exist: {test_ref}"
    return True, ""


def _parse_code_ref(root: Path, reference: str) -> Tuple[Optional[Path], Optional[Tuple[int, int]], str]:
    match = re.fullmatch(r"(.+?)(?::(\d+)(?:-(\d+))?)?", reference)
    if not match:
        return None, None, f"invalid code reference: {reference}"
    path_text, start_text, end_text = match.groups()
    path = (root / path_text).resolve()
    if not _inside_root(root, path):
        return None, None, f"code path escapes repository: {path_text}"
    if not path.is_file():
        return None, None, f"code file does not exist: {path_text}"
    if start_text is None:
        return path, None, ""
    start = int(start_text)
    end = int(end_text or start_text)
    line_count = len(path.read_text(encoding="utf-8").splitlines())
    if start < 1 or end < start or end > line_count:
        return None, None, f"code line range does not exist: {reference}"
    return path, (start, end), ""


def _stub_error(path: Path, line_range: Optional[Tuple[int, int]]) -> Optional[str]:
    if path.suffix.lower() not in CODE_SUFFIXES:
        return None
    lines = path.read_text(encoding="utf-8").splitlines()
    for offset, line in enumerate(lines, start=1):
        if any(marker in line for marker in STUB_MARKERS):
            return f"stub marker in {path.name}:{offset}"
        if re.fullmatch(r"\s*pass\s*(?:#.*)?", line):
            return f"bare pass stub in {path.name}:{offset}"
    if path.suffix.lower() in {".ps1", ".psm1"}:
        source = "\n".join(lines)
        empty_function = re.search(
            r"(?ims)^\s*function\s+[A-Za-z_][\w-]*\s*(?:\([^)]*\))?\s*\{\s*\}",
            source,
        )
        if empty_function:
            line = source[: empty_function.start()].count("\n") + 1
            return f"empty PowerShell function in {path.name}:{line}"
        placeholder_throw = re.search(
            r"(?im)^\s*throw\s+['\"][^'\"]*(?:not\s+(?:yet\s+)?implemented|placeholder)",
            source,
        )
        if placeholder_throw:
            line = source[: placeholder_throw.start()].count("\n") + 1
            return f"PowerShell placeholder throw in {path.name}:{line}"
    return None


def _commit_resolves(root: Path, commit: str) -> Tuple[bool, str]:
    if not re.fullmatch(r"[0-9a-fA-F]{7,40}", commit):
        return False, f"invalid commit value: {commit}"
    try:
        repository = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, f"commit unverifiable because Git could not run: {exc}"
    if repository.returncode != 0:
        return False, "commit unverifiable: no Git repository"
    repository_root = Path(repository.stdout.strip()).resolve()
    try:
        exact_root = os.path.samefile(repository_root, root)
    except OSError:
        exact_root = os.path.normcase(str(repository_root)) == os.path.normcase(
            str(root.resolve())
        )
    if not exact_root:
        return False, "commit unverifiable: no Git repository"
    try:
        process = subprocess.run(
            ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, f"commit unverifiable because Git could not run: {exc}"
    if process.returncode != 0:
        return False, f"commit does not resolve: {commit}"
    return True, ""


def _board_flow_errors(
    board: Mapping[str, BoardItem], wip_limit: int
) -> List[str]:
    errors: List[str] = []
    in_progress = [item for item in board.values() if item.status == "IN_PROGRESS"]
    if len(in_progress) > wip_limit:
        errors.append(
            f"WIP limit exceeded: {len(in_progress)} stories IN_PROGRESS; limit {wip_limit}"
        )
    blocked = [item for item in board.values() if item.status == "BLOCKED"]
    if blocked and in_progress:
        un_escalated = sorted(
            item.story_id for item in blocked if "escalated=" not in item.note.lower()
        )
        non_repair = sorted(
            item.story_id for item in in_progress if "repair-for=" not in item.note.lower()
        )
        if un_escalated:
            errors.append(
                "blocked stories lack explicit escalation: " + ", ".join(un_escalated)
            )
        if non_repair:
            errors.append(
                "work pulled beside blockers is not an explicit repair: "
                + ", ".join(non_repair)
            )
    return errors


def _unittest_selector(test_ref: str) -> Optional[str]:
    path_text, node = _split_test_ref(test_ref)
    if not node or not path_text.endswith(".py"):
        return None
    module = path_text[:-3].replace("/", ".").replace("\\", ".")
    return f"{module}.{node}"


def _safe_evidence_command(
    root: Path, command: str, test_refs: Sequence[str]
) -> Tuple[Optional[List[str]], str]:
    try:
        arguments = shlex.split(command, posix=True)
    except ValueError as exc:
        return None, f"invalid evidence command: {exc}"
    if len(arguments) < 2:
        return None, "evidence command is incomplete"
    executable = Path(arguments[0]).name.lower()
    if executable in {"python", "python3", "python.exe", "py", "py.exe"}:
        module_index = 1
        if executable in {"py", "py.exe"} and arguments[1:2] == ["-3"]:
            module_index += 1
        if arguments[module_index : module_index + 2] != ["-m", "unittest"]:
            return None, "Python evidence command must run unittest"
        selectors = {
            argument
            for argument in arguments[module_index + 2 :]
            if not argument.startswith("-")
        }
        expected = {_unittest_selector(test_ref) for test_ref in test_refs}
        if None in expected:
            return None, "Python evidence tests must be .py file::node references"
        missing = sorted(expected - selectors)
        if missing:
            return None, f"evidence command omits named tests: {', '.join(missing)}"
        return [sys.executable, *arguments[module_index:]], ""

    if executable in {"pwsh", "pwsh.exe", "powershell", "powershell.exe"}:
        lowered = [argument.lower() for argument in arguments]
        if "-noprofile" not in lowered or "-file" not in lowered:
            return None, "PowerShell evidence command requires -NoProfile and -File"
        file_index = lowered.index("-file") + 1
        if file_index >= len(arguments):
            return None, "PowerShell evidence command lacks a script path"
        script_text = arguments[file_index]
        script_path = (root / script_text).resolve()
        tests_root = (root / "tests").resolve()
        if not _inside_root(tests_root, script_path) or script_path.suffix.lower() != ".ps1":
            return None, "PowerShell evidence script must be a .ps1 file under tests"
        referenced_paths = {_split_test_ref(test_ref)[0] for test_ref in test_refs}
        if referenced_paths != {script_text}:
            return None, "PowerShell evidence command does not match named test files"
        if executable.startswith("powershell"):
            engine_candidates = ("powershell", "powershell.exe", "pwsh", "pwsh.exe")
        else:
            engine_candidates = ("pwsh", "pwsh.exe", "powershell", "powershell.exe")
        engine = next(
            (resolved for name in engine_candidates if (resolved := shutil.which(name))),
            engine_candidates[0],
        )
        return [engine, *arguments[1:]], ""

    return None, "evidence command must use Python unittest or a PowerShell test script"


class RepositoryVerifier:
    def __init__(self, root: Path, run_evidence_tests: bool = True) -> None:
        self.root = root.resolve()
        self.run_evidence_tests = run_evidence_tests

    def verify(self) -> VerificationResult:
        errors: List[str] = []
        outputs: Dict[str, str] = {}
        try:
            backlog_text = _read(self.root / "PRODUCT_BACKLOG.md")
            board_text = _read(self.root / "BOARD.md")
            expected, requirements = parse_requirements(backlog_text)
            coverage = parse_coverage(backlog_text)
            expected_changes, change_requirements = parse_change_requirements(backlog_text)
            change_coverage = parse_change_coverage(backlog_text)
            contract_coverage = parse_contract_coverage(backlog_text)
            expected_audit, audit_findings = parse_audit_findings(backlog_text)
            stories = parse_stories(backlog_text)
            board = parse_board(board_text)
            wip_limit, backlog_approved = parse_board_settings(board_text)
            evidence = parse_evidence(board_text)
        except ValueError as exc:
            return VerificationResult(
                errors=[str(exc)],
                status_counts={},
                tested_criteria=0,
                total_criteria=0,
                unfinished=[],
                evidence_outputs={},
            )

        if expected != BASELINE_REQUIREMENT_COUNT:
            errors.append(
                f"EXPECTED_REQUIREMENTS is {expected}; binding source contains "
                f"{BASELINE_REQUIREMENT_COUNT}"
            )
        if len(requirements) != expected:
            errors.append(
                f"requirement manifest count is {len(requirements)}; expected {expected}"
            )
        missing_manifest = sorted(BASELINE_REQUIREMENT_IDS - requirements)
        unexpected_manifest = sorted(requirements - BASELINE_REQUIREMENT_IDS)
        if missing_manifest:
            errors.append(f"binding requirements missing: {', '.join(missing_manifest)}")
        if unexpected_manifest:
            errors.append(
                f"unexpected requirement substitutions: {', '.join(unexpected_manifest)}"
            )

        missing_coverage = sorted(requirements - set(coverage))
        extra_coverage = sorted(set(coverage) - requirements)
        if missing_coverage:
            errors.append(f"orphan requirements: {', '.join(missing_coverage)}")
        if extra_coverage:
            errors.append(f"coverage contains undeclared requirements: {', '.join(extra_coverage)}")
        for requirement_id, story_ids in sorted(coverage.items()):
            if not story_ids:
                errors.append(f"{requirement_id} maps to no story")
            missing_stories = sorted(story_ids - set(stories))
            if missing_stories:
                errors.append(
                    f"{requirement_id} maps to unknown stories: {', '.join(missing_stories)}"
                )

        if len(change_requirements) != expected_changes:
            errors.append(
                "change requirement manifest count is "
                f"{len(change_requirements)}; expected {expected_changes}"
            )
        missing_change_coverage = sorted(change_requirements - set(change_coverage))
        extra_change_coverage = sorted(set(change_coverage) - change_requirements)
        if missing_change_coverage:
            errors.append(
                "orphan change requirements: " + ", ".join(missing_change_coverage)
            )
        if extra_change_coverage:
            errors.append(
                "change coverage contains undeclared requirements: "
                + ", ".join(extra_change_coverage)
            )
        for change_id, story_ids in sorted(change_coverage.items()):
            if not story_ids:
                errors.append(f"{change_id} maps to no story")
            missing_stories = sorted(story_ids - set(stories))
            if missing_stories:
                errors.append(
                    f"{change_id} maps to unknown stories: {', '.join(missing_stories)}"
                )

        missing_contracts = sorted(BASELINE_CONTRACT_IDS - set(contract_coverage))
        extra_contracts = sorted(set(contract_coverage) - BASELINE_CONTRACT_IDS)
        if missing_contracts:
            errors.append(f"orphan delivery contracts: {', '.join(missing_contracts)}")
        if extra_contracts:
            errors.append(f"unexpected delivery contracts: {', '.join(extra_contracts)}")
        for contract_id, story_ids in sorted(contract_coverage.items()):
            if not story_ids:
                errors.append(f"{contract_id} maps to no story")
            missing_stories = sorted(story_ids - set(stories))
            if missing_stories:
                errors.append(
                    f"{contract_id} maps to unknown stories: {', '.join(missing_stories)}"
                )

        if expected_audit != len(BASELINE_AUDIT_IDS):
            errors.append(
                f"EXPECTED_AUDIT_FINDINGS is {expected_audit}; approved register contains "
                f"{len(BASELINE_AUDIT_IDS)}"
            )
        missing_audit = sorted(BASELINE_AUDIT_IDS - set(audit_findings))
        unexpected_audit = sorted(set(audit_findings) - BASELINE_AUDIT_IDS)
        if missing_audit:
            errors.append(f"orphan audit findings: {', '.join(missing_audit)}")
        if unexpected_audit:
            errors.append(f"unexpected audit findings: {', '.join(unexpected_audit)}")
        for finding_id, story_id in sorted(audit_findings.items()):
            if story_id not in stories:
                errors.append(f"{finding_id} maps to unknown repair story: {story_id}")

        missing_board = sorted(set(stories) - set(board))
        extra_board = sorted(set(board) - set(stories))
        if missing_board:
            errors.append(f"stories missing from board: {', '.join(missing_board)}")
        if extra_board:
            errors.append(f"board contains unknown stories: {', '.join(extra_board)}")

        for item in board.values():
            if item.status not in VALID_STATUSES:
                errors.append(f"{item.story_id} has invalid status {item.status}")
                continue
            story = stories.get(item.story_id)
            if story and item.increment != story.metadata["Increment"]:
                errors.append(
                    f"{item.story_id} board increment {item.increment} does not match "
                    f"backlog increment {story.metadata['Increment']}"
                )
            if item.status == "BLOCKED" and not (
                re.search(r"OQ-\d{2}", item.note)
                or item.note.lower().startswith("external:")
            ):
                errors.append(
                    f"{item.story_id} is BLOCKED without an OQ or named external dependency"
                )
            if item.status == "DEFERRED" and not (
                "reason=" in item.note.lower() and "revisit=" in item.note.lower()
            ):
                errors.append(
                    f"{item.story_id} is DEFERRED without reason= and revisit="
                )
            if item.status == "READY" and re.search(r"OQ-\d{2}", item.note):
                errors.append(f"{item.story_id} is READY with an open-question blocker")
            if (
                item.story_id[2:4] != "00"
                and not backlog_approved
                and item.status in {"READY", "IN_PROGRESS", "IN_REVIEW", "DONE"}
            ):
                errors.append(
                    f"{item.story_id} advanced before BACKLOG_APPROVED became true"
                )
        errors.extend(_board_flow_errors(board, wip_limit))
        for story_id, story in stories.items():
            if story_id not in board or board[story_id].status not in {
                "READY",
                "IN_PROGRESS",
                "IN_REVIEW",
                "DONE",
            }:
                continue
            upstream = set(
                re.findall(r"S-\d{2}\.\d{2}\.\d{2}", story.metadata["Dependencies"])
            )
            incomplete = sorted(
                dependency
                for dependency in upstream
                if dependency not in board or board[dependency].status != "DONE"
            )
            if incomplete:
                errors.append(
                    f"{story_id} advanced with incomplete dependencies: {', '.join(incomplete)}"
                )

        all_criterion_ids: List[str] = []
        tested_criteria = 0
        for story in stories.values():
            for criterion in story.criteria:
                all_criterion_ids.append(criterion.criterion_id)
                resolves, _ = _test_ref_resolves(self.root, criterion.test_ref)
                if resolves:
                    tested_criteria += 1
        for story_id, item in board.items():
            if item.status != "BACKLOG" or story_id not in stories:
                continue
            implemented_tests = sorted(
                criterion.test_ref
                for criterion in stories[story_id].criteria
                if _test_ref_resolves(self.root, criterion.test_ref)[0]
            )
            if implemented_tests:
                errors.append(
                    f"{story_id} remains BACKLOG with implemented acceptance tests: "
                    + ", ".join(implemented_tests)
                )
        duplicate_criteria = sorted(
            criterion_id
            for criterion_id, count in collections.Counter(all_criterion_ids).items()
            if count > 1
        )
        if duplicate_criteria:
            errors.append(f"duplicate acceptance criteria: {', '.join(duplicate_criteria)}")

        done_ids = {item.story_id for item in board.values() if item.status == "DONE"}
        extra_evidence = sorted(set(evidence) - done_ids)
        if extra_evidence:
            errors.append(f"evidence exists for non-DONE stories: {', '.join(extra_evidence)}")

        for story_id in sorted(done_ids):
            story = stories[story_id]
            item_evidence = evidence.get(story_id)
            if item_evidence is None:
                errors.append(f"DONE story lacks evidence: {story_id}")
                continue

            criterion_ids = {criterion.criterion_id for criterion in story.criteria}
            mapped_ids = set(item_evidence.criteria)
            missing_criteria = sorted(criterion_ids - mapped_ids)
            extra_criteria = sorted(mapped_ids - criterion_ids)
            if missing_criteria:
                errors.append(
                    f"{story_id} evidence omits acceptance criteria: "
                    f"{', '.join(missing_criteria)}"
                )
            if extra_criteria:
                errors.append(
                    f"{story_id} evidence names unknown criteria: {', '.join(extra_criteria)}"
                )
            backlog_tests = {
                criterion.criterion_id: criterion.test_ref for criterion in story.criteria
            }
            for criterion_id, test_ref in item_evidence.criteria.items():
                if test_ref not in item_evidence.tests:
                    errors.append(
                        f"{story_id} {criterion_id} maps to a test absent from tests: {test_ref}"
                    )
                planned = backlog_tests.get(criterion_id)
                if planned and planned != "TBD" and planned != test_ref:
                    errors.append(
                        f"{story_id} {criterion_id} evidence test differs from backlog: "
                        f"{test_ref}"
                    )
            if len(item_evidence.tests) != len(set(item_evidence.tests)):
                errors.append(f"{story_id} evidence repeats a test reference")
            if len(item_evidence.code) != len(set(item_evidence.code)):
                errors.append(f"{story_id} evidence repeats a code reference")

            for test_ref in item_evidence.tests:
                resolves, reason = _test_ref_resolves(self.root, test_ref)
                if not resolves:
                    errors.append(f"{story_id} {reason}")

            for code_ref in item_evidence.code:
                code_path, line_range, reason = _parse_code_ref(self.root, code_ref)
                if reason:
                    errors.append(f"{story_id} {reason}")
                    continue
                assert code_path is not None
                stub = _stub_error(code_path, line_range)
                if stub:
                    errors.append(f"{story_id} {stub}")

            commit_ok, commit_reason = _commit_resolves(self.root, item_evidence.commit)
            if not commit_ok:
                errors.append(f"{story_id} {commit_reason}")
            if not re.search(r"\brun\s+\d{4}-\d{2}-\d{2}\b", item_evidence.result):
                errors.append(f"{story_id} evidence result lacks a dated run statement")

            command, command_reason = _safe_evidence_command(
                self.root, item_evidence.command, item_evidence.tests
            )
            if command is None:
                errors.append(f"{story_id} {command_reason}")
            elif self.run_evidence_tests:
                try:
                    process = subprocess.run(
                        command,
                        cwd=self.root,
                        text=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        timeout=120,
                        check=False,
                        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
                    )
                except (OSError, subprocess.TimeoutExpired) as exc:
                    errors.append(f"{story_id} evidence command could not complete: {exc}")
                else:
                    outputs[story_id] = process.stdout.strip()
                    if process.returncode != 0:
                        tail = "\n".join(process.stdout.splitlines()[-12:])
                        errors.append(
                            f"{story_id} evidence command failed with {process.returncode}:\n{tail}"
                        )

        counts = collections.Counter(item.status for item in board.values())
        unfinished = [
            (
                story_id,
                board[story_id].status if story_id in board else "MISSING",
                story.title,
            )
            for story_id, story in sorted(stories.items())
            if story_id not in board or board[story_id].status != "DONE"
        ]
        return VerificationResult(
            errors=errors,
            status_counts={status: counts.get(status, 0) for status in sorted(VALID_STATUSES)},
            tested_criteria=tested_criteria,
            total_criteria=len(all_criterion_ids),
            unfinished=unfinished,
            evidence_outputs=outputs,
        )


def format_result(result: VerificationResult) -> str:
    lines: List[str] = []
    if result.errors:
        lines.append("VERIFICATION: FAILED")
        lines.extend(f"ERROR: {error}" for error in result.errors)
    else:
        lines.append("VERIFICATION: PASSED")
    if result.status_counts:
        counts = " | ".join(
            f"{status}={count}" for status, count in result.status_counts.items()
        )
        lines.append(f"BOARD: {counts}")
    percentage = (
        100.0 * result.tested_criteria / result.total_criteria
        if result.total_criteria
        else 0.0
    )
    lines.append(
        "AC TESTS RESOLVED: "
        f"{result.tested_criteria}/{result.total_criteria} ({percentage:.1f}%)"
    )
    lines.append(f"NOT BUILT: {len(result.unfinished)}")
    lines.extend(
        f"- {story_id} [{status}] {title}"
        for story_id, status, title in result.unfinished
    )
    return "\n".join(lines)


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (defaults to the parent of scripts)",
    )
    args = parser.parse_args(argv)
    result = RepositoryVerifier(args.root).verify()
    print(format_result(result))
    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
