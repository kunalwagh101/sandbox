# Increment 0 Retrospective

## Goal result

The repository can now reject orphan requirements, board drift, unproved DONE claims,
missing files and tests, invalid code references, unresolved commits, stub markers, WIP
violations, and failing evidence commands.

## What changed from the estimate

The source brief says "all 40 R-IDs" in its final action list, but the enumerated inventory
contains 45. The authoritative manifest uses all 45; OQ-10 remains reserved for the real
resource-budget decision.

The first temporary-fixture rewrite retained indentation after multiline insertion. The
fixtures failed before reaching their seeded lies. Their row indentation and board
assembly were made deterministic, after which every intended failure path was reached.

## What was cut

Nothing from Increment 0. Windows feature code was intentionally not started because the
source brief requires backlog approval after the governance gate.

## Re-plan

Increment 1 remains one vertical slice: preflight, strict policy rendering, one-action
launch, Brave provisioning, and measured isolation/resource tests. Windows runtime
acceptance requires a supported target host.

## Increment 1 review checkpoint — 2026-08-27

### Goal result so far

The full strict-offline source path exists: signed installer initialisation, fail-closed
preflight, bounded staging, deterministic policy rendering, one-session launch, Brave
provisioning, live acceptance, and three-run measurement. Sixteen repository tests pass.
No Windows runtime claim has been made.

### What changed from the estimate

Microsoft's 24H2 CLI takes formatted XML in `wsb start --config`, not the `.wsb` path.
Source review caught and corrected that integration detail. The original single mapped
input also could not return exact guest version evidence, so the design adds one empty,
per-session result folder. It is explicitly writable, never reused as executable input,
and its data remains untrusted.

### What was cut

Nothing was silently cut. Networking remains disabled by design until the egress/LAN
story. Windows execution, ProtectedClient compatibility, and approved performance limits
remain visible review gates rather than fabricated evidence.

### Re-plan

Run the acceptance and collect-only benchmark on the target Windows host. If acceptance
passes, resolve S-01.01.01 evidence, pull dependent stories in order, approve OQ-10 from
the baseline, and run enforced resource thresholds before any Increment 1 DONE claim.
