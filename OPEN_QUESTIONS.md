# Airlock Open Questions

An answer is not implied by a recommendation. A question remains OPEN until the product
owner supplies evidence or approves a spike result. A story cannot enter READY if an OPEN
question can change its shape.

## OQ-01 — Target Windows edition and build

- Status: ANSWERED FOR IMPLEMENTATION — BLOCKS LIVE ACCEPTANCE ONLY
- Ambiguity: Exact edition, build, Sandbox feature state, and hardware virtualisation state.
- Options: Home, Pro, Enterprise, or Education; before or after build 26100.
- Recommended default: Build the fail-safe preflight now; collect machine facts before
  claiming Windows acceptance.
- Evidence received: Windows 10 Pro 22H2, build 19045; hardware checks passed, the
  Sandbox feature is disabled, `wsb.exe` is absent, and the product owner approved
  CR-2026-08-30-01 on 2026-08-30.
- Blast radius: Total. Windows 10 requires the legacy `.wsb` launcher because the
  managed runtime CLI begins with Windows 11 24H2.
- Blocks: Windows runtime evidence and DONE status for Increment 1. It does not block
  source implementation after the product owner's explicit build instruction.
- Answer: Support exactly two contracts: Windows 10 Pro 22H2 build 19045 through
  `WindowsSandbox.exe`, and Windows 11 Pro/Enterprise/Education build 26100+ through
  `wsb.exe`. The strict `.wsb` security policy is shared. Live acceptance remains pending
  until the product owner enables Windows Sandbox and reboots.
- Evidence command: `scripts\Start-Airlock.ps1 -PreflightOnly`, followed by
  `tests\Invoke-Increment1Acceptance.ps1 -RunLive` on the target Windows host.

## OQ-02 — Default microphone mode

- Status: OPEN
- Ambiguity: Strict or voice mode as the default profile.
- Options: Strict, where AudioInput is disabled; voice, where runtime gating is SOFT.
- Recommended default: Strict.
- Evidence needed: Product-owner choice after reading the HARD/SOFT difference.
- Blast radius: Medium. Voice by default can create false confidence.
- Blocks: S-03.01.01.
- Answer: Pending.

## OQ-03 — ChatGPT Windows compatibility

- Status: OPEN — SPIKE REQUIRED
- Ambiguity: Whether package 9PLM9XGG6VKS and its Store dependencies work in Sandbox.
- Options: Works directly; needs Store bootstrap; unsupported; approved Brave PWA fallback.
- Recommended default: Run a reversible spike. Never count a PWA as R-APP-01 silently.
- Evidence needed: Target-host install, launch, sign-in, and relaunch logs.
- Blast radius: High. R-APP-01 is a named requirement.
- Blocks: S-02.01.03.
- Answer: Pending.

## OQ-04 — ProtectedClient compatibility

- Status: OPEN — SPIKE REQUIRED
- Ambiguity: Whether ProtectedClient=Enable interferes with runtime wsb share.
- Options: Compatible; incompatible; compatible with restrictions.
- Recommended default: Measure it. If incompatible, keep the broker and document reduced RDP hardening.
- Evidence needed: Runtime read/write share probes with ProtectedClient on and off.
- Blast radius: Medium. It can break the only controlled data path.
- Blocks: S-01.02.01.
- Answer: Pending.

## OQ-05 — Acceptable warm-launch time

- Status: OPEN
- Ambiguity: Maximum usable time-to-ready for repeat launches.
- Options: 30, 60, 90 seconds, or another measured threshold.
- Recommended default: Use 90 seconds only as a candidate, then decide from three measurements.
- Evidence needed: Cold and warm distributions on the target machine.
- Blast radius: High. A slow safety control will be bypassed.
- Blocks: S-02.01.02 DONE status.
- Answer: Pending.

## OQ-06 — Seal on minimise or all focus loss

- Status: OPEN
- Ambiguity: The user named minimise, but alt-tab may express the same intent.
- Options: Minimise only; minimise plus focus loss; selectable policy.
- Recommended default: Selectable, defaulting to minimise plus focus loss.
- Evidence needed: Product-owner choice and usability test.
- Blast radius: Low to medium. Loose permits background capture; strict interrupts work.
- Blocks: S-03.01.01 and S-03.02.01.
- Answer: Pending.

## OQ-07 — Token and API-key persistence

- Status: OPEN
- Ambiguity: Persist, protect, or destroy credentials on teardown.
- Options: Persistent; protected persistent; ephemeral; selectable.
- Recommended default: Selectable, with ephemeral safest. Do not promise DPAPI before testing disposable guest identities.
- Evidence needed: Product-owner choice and target-host persistence/teardown tests.
- Blast radius: Medium. Bearer tokens can remain in the host vault.
- Blocks: S-02.01.01 and S-05.02.02.
- Answer: Pending.

## OQ-08 — Residual LAN risk

- Status: OPEN
- Ambiguity: Whether SOFT in-guest firewall mitigation is acceptable with networking on.
- Options: Accept with disclosure; disable networking; add a stronger host boundary.
- Recommended default: Default-deny outbound, explicit app allows, private-range denies, negative probes, and clear residual-risk text.
- Evidence needed: Target-host LAN probes and product-owner risk acceptance.
- Blast radius: Medium to high. Guest code may attack reachable private services.
- Blocks: S-05.01.01 DONE status.
- Answer: Pending.

## OQ-09 — WSL2 Track B

- Status: OPEN — NON-BLOCKING MVP
- Ambiguity: Whether a CLI-only WSL2 profile should follow the Windows Sandbox MVP.
- Options: No; after MVP; separate project.
- Recommended default: Revisit after MVP review.
- Evidence needed: CLI workflow demand and maintenance cost.
- Blast radius: Low. It is additive and out of current scope.
- Blocks: Nothing.
- Answer: Pending.

## OQ-10 — Resource budgets

- Status: OPEN
- Ambiguity: Low RAM and disk have no pass/fail numbers.
- Options: Universal limits; percentage-of-host limits; explicit memory ceiling plus measured deltas.
- Recommended default: Set MemoryInMB and separate host RAM, Airlock disk, and launch budgets after a baseline.
- Evidence needed: Target RAM, free disk, and three baseline launches.
- Blast radius: High. R-RES-03 cannot be DONE without thresholds.
- Blocks: S-01.02.03.
- Answer: Pending.
- Evidence command: `tests\Measure-Increment1.ps1 -CollectOnly`; approved values then
  become the three mandatory threshold parameters in enforced mode.

## OQ-11 — Meaning of screen capture

- Status: OPEN
- Ambiguity: R-PERM-06 derives focus-conditional screen capture, but Windows Sandbox has no equivalent runtime toggle.
- Options: Guest camera; guest desktop capture; host-screen visibility; another intended surface.
- Recommended default: Clarify the protected asset. Do not pretend VideoInput controls screen capture.
- Evidence needed: Product-owner definition and Windows mechanism spike.
- Blast radius: Medium. A control can protect the wrong surface.
- Blocks: S-03.01.01 and part of S-03.02.01.
- Answer: Pending.

## OQ-12 — Per-item export audit

- Status: OPEN — DESIGN DECISION
- Ambiguity: A writable share audits the grant, not every file exported through it.
- Options: Grant-level audit; guest staging plus host-confirmed per-item copy; narrow-folder watcher.
- Recommended default: Guest staging plus explicit host copy and integrity hash.
- Evidence needed: Product-owner confirmation and threat review.
- Blast radius: High. R-DATA-04/05 would otherwise be overclaimed.
- Blocks: S-04.01.02.
- Answer: Pending.

## OQ-13 — Writable installer tampering

- Status: OPEN — SECURITY ARCHITECTURE DECISION
- Ambiguity: Brief §6.3 maps the vault, including installers, writable. Guest code could alter an installer executed next session.
- Options: One writable vault; split immutable inputs read-only; copy hash-verified installers to ephemeral guest storage.
- Recommended default: Read-only installer/provisioning mappings, pinned hashes before execution, and only named profiles/workspace writable.
- Evidence needed: Product-owner approval of this §6 design change plus write-denial and hash-mismatch tests.
- Blast radius: Critical. A compromised session can become durable code execution.
- Blocks: S-02.01.01.
- Answer: Pending.
- Increment 1 handling: only a freshly copied, hash-verified bootstrap is mapped read-only.
  The persistent-vault decision remains open for S-02.01.01.

## OQ-14 — wsb.exe raw contract and Windows PowerShell 5.1

- Status: OPEN — BLOCKS TARGET-HOST LIFECYCLE ACCEPTANCE
- Ambiguity: The exact named ID field returned by the installed 24H2 `wsb.exe --raw`
  commands, and whether that build writes warnings to stderr under Windows PowerShell 5.1.
- Options: A stable documented field; a version-specific field contract; or an unsupported
  CLI shape that must fail closed with raw redacted diagnostics.
- Recommended default: Accept only an explicitly named field confirmed on the target host,
  record the CLI file version, capture stdout and stderr separately, and never scrape GUIDs.
- Evidence needed: Redacted outputs from `wsb list --raw` and one test `wsb start --raw`,
  `wsb.exe` file version, and Windows PowerShell 5.1 stderr behaviour.
- Blast radius: High. A wrong ID can orphan a live sandbox or stop the wrong session.
- Blocks: Target-host DONE evidence for S-06.03.01 and S-01.01.01.
- Answer: Source repair approved on 2026-08-29; target-host contract evidence pending.

## OQ-15 — Windows 10 legacy process identity

- Status: ANSWERED FOR IMPLEMENTATION — TARGET-HOST VALIDATION PENDING
- Ambiguity: Windows 10 has no managed Sandbox ID, list, or stop CLI. The older native
  launcher exposes only a host process after starting a `.wsb` configuration.
- Options: Refuse Windows 10; track the exact launcher process; or falsely treat a PID as
  a managed Sandbox ID.
- Recommended default: Track the exact `WindowsSandbox.exe` PID, process start time, and
  executable path; refuse an existing instance; label lifecycle control `legacy-process`;
  never populate `sandboxId` in this mode.
- Evidence needed: Run compatibility acceptance after enabling Sandbox on build 19045,
  observe one process identity, successful provisioning, and clean manual/guarded close.
- Blast radius: Medium. The hypervisor and strict mappings are unchanged, but automated
  session reconciliation is weaker than the Windows 11 managed CLI.
- Blocks: DONE for S-06.05.01, not implementation; the command shape is fixed by the
  approved Microsoft native `.wsb` launcher contract.
- Answer: Product owner accepted Windows 10 compatibility on 2026-08-30 with truthful
  lifecycle labelling rather than feature equivalence.

## Known limitation — telemetry is SOFT

The current Increment 1 result is isolated by a per-session directory but does not yet
carry a nonce. S-06.04.01 must add and verify session plus nonce correlation before the
project may claim stale-result rejection. Even after that repair, guest telemetry remains
SOFT because the guest controls its own report. Strict mode and `wsb stop` remain the only
HARD microphone guarantees.
