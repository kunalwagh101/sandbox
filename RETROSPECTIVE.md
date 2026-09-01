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

## R2 cross-version review checkpoint — 2026-08-31

### Goal result so far

The approved Windows 10 compatibility change is implemented as one vertical launch slice.
Windows 10 Pro 22H2 build 19045 selects the legacy native `.wsb` launcher; Windows 11
24H2+ preserves the managed `wsb.exe` flow. Both use the same strict offline profile and
package verification path. Windows 10 state reports process identity and intentionally
leaves `sandboxId` empty.

### What changed from the estimate

The change was wider than one preflight condition. The lifecycle choice also affects
concurrency checks, state recording, cleanup after a state-write failure, live acceptance,
and three-run resource measurement. Those paths were updated together rather than leaving
a partial compatibility layer.

CI also exposed two assumptions before review. First, the pure platform resolver used
`Join-Path` with a synthetic `C:\Windows` path, which failed under Linux PowerShell even
though Windows PowerShell passed. It was changed to portable string construction. Second,
legacy `.wsb` launch arguments need explicit quoting because a Windows profile path can
contain spaces. The launch path now quotes the generated profile argument.

### What was cut

Nothing from CR-2026-08-30-01 was cut. Windows 10 live runtime proof is not descoped; it
remains the OQ-15 evidence gate. Existing R1 lifecycle/provenance work remains separate in
S-06.03.01 and S-06.04.01 and was not silently absorbed into R2.

### What the estimate got wrong

The initial mental model treated Windows 10 support as a launcher substitution. The real
blast radius is a lifecycle contract: discovery, launch identity, truthful state, guarded
termination, acceptance, and measurement all depend on the platform's control surface.
The estimate should have started from that lifecycle boundary.

### Re-plan

Once source CI is green, move S-06.05.01 to IN_REVIEW. Do not mark it DONE until the
product owner's Windows 10 build 19045 machine has Windows Sandbox enabled, is rebooted,
and passes `tests\Invoke-Increment1Acceptance.ps1 -RunLive`. Preserve the generated
result and host state as review evidence, then add a resolvable DONE ledger only if every
acceptance criterion and the target-host gate pass.

## R1-L lifecycle review checkpoint — 2026-09-01

### Goal result so far

One shared lifecycle contract now serves launch failure, manual stop, live acceptance,
and the three-run benchmark. Managed Windows 11 sessions use a caller-generated GUID;
Windows 10 sessions retain guarded process identity. Stop waits for disappearance before
state and the exact owned session directory are removed. GitHub Actions run 33473134496
passed the verifier, Python suite, PowerShell 7 behavior, Windows PowerShell 5.1 parsing,
and Windows PowerShell 5.1 behavior.

### What changed from the estimate

Strict parsing alone was insufficient. Airlock needs the managed ID before native launch
so a parser or state-publication failure can still name the guest. Microsoft documents
`wsb start --id`, so the smallest safe design generates the GUID first and verifies that
the runtime exposes the same ID. CI also found that wrapping `List<T>` directly in
`@(...)` fails in both supported PowerShell engines; native `ToArray()` fixed the real
runtime problem without weakening the test.

### What was cut

Nothing from S-06.03.01 was silently cut. Native Windows 10 shutdown and Windows 11 raw
field confirmation are not claimed by source CI; they remain explicit OQ-15 and OQ-14
review gates.

### What the estimate got wrong

The initial estimate treated stop as one native command. Complete teardown is a state
machine: prove identity, request stop, wait for disappearance, remove only owned staging,
then remove matching state. Every consumer must use that entire sequence.

### Re-plan

Keep S-06.03.01 IN_REVIEW. On the product owner's Windows 10 build 19045 machine, enable
Windows Sandbox, reboot, run lifecycle source acceptance, run live acceptance, and run an
explicit start/stop demo. A Windows 11 24H2 host must separately resolve OQ-14. Do not add
DONE evidence until both applicable native contracts are measured.
