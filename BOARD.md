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
- Pull rule: S-06.01.01 is the only active story. Later repair stories stay BACKLOG until
  its verifier evidence is complete.
- Escalation rule: Increment 1 stories are BLOCKED by AUDIT-2026-08-28 and explicitly
  escalated. R1 is the approved repair work that resolves those blockers.
- Target-host rule: Linux and CI can prove deterministic source behaviour; OQ-01 still
  blocks claims that require a real Windows Sandbox launch.
- Review checkpoint: The product owner's Windows run reproduced AL-01 and AL-02 on
  2026-08-29. Prior claims that all repository tests passed are withdrawn.

## Story board

<!-- BOARD_START -->
| Story ID | Status | Increment | Blocker or note |
|---|---|---:|---|
| S-00.01.01 | IN_REVIEW | 0 | Prior DONE withdrawn after AL-02; repair-for=S-06.01.01 |
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
| S-06.01.01 | IN_PROGRESS | R1 | repair-for=S-00.01.01; approved=2026-08-29; AL-02,18,20,21,22 |
| S-06.02.01 | BACKLOG | R1 | S-06.01.01; AL-01,03,09,10,11,13,14,15,19 |
| S-06.03.01 | BACKLOG | R1 | S-06.02.01; AL-04,05,06,07,08,23 |
| S-06.04.01 | BACKLOG | R1 | S-06.03.01; AL-12,16,17 |
<!-- BOARD_END -->

## Evidence ledger

The previous S-00.01.01 evidence named a commit absent from the distributed GitHub
history. It is withdrawn. New evidence will be recorded only after S-06.01.01 passes.

## Deferred register

- S-05.01.01 / online browsing: reason=Increment 1 intentionally disables networking,
  so Brave can prove isolation but cannot browse; revisit=after the CLI toolchain exists,
  OQ-08 is accepted, and LAN-isolation tests are available. Product-owner approved this
  explicit deferral through AL-17 on 2026-08-29.
