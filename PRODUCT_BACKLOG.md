# Airlock Product Backlog

**Schema:** 1
**Binding scope:** docs/AIRLOCK_BUILD_BRIEF.md §4
**Method:** fixed-scope Scrum increments with a WIP limit of one story.

Scrum fits because the 45 requirements and MVP boundary are known. Each increment is a
reviewable vertical slice. WIP is one because one engineer should finish and verify one
security slice before pulling another.

## Discovery and architecture decision

- Exact problem: run untrusted AI desktop and CLI tools on the user's existing Windows
  machine without ambient host-file access, while keeping every deliberate grant visible,
  narrow, and testable.
- Success criteria: all 45 source requirements remain traceable; unsupported hosts fail
  before launch; Increment 1 proves one strict Brave session with no broad host mapping,
  no capture devices, and measured RAM, disk, and launch cost.
- Baseline: running the tools directly on Windows is convenient but gives them the user's
  normal filesystem and device access. A conventional VM gives a strong boundary but does
  not meet the requested lightweight operating model without more platform management.
- AI decision: Airlock's control plane does **not** need ML, RAG, fine-tuning, or an AI
  agent. Security decisions must be deterministic rules enforced by Windows Sandbox,
  narrow host scripts, and explicit user action. AI would add latency, cost, attack
  surface, and non-determinism without improving the boundary.
- Data assessment: there is no training dataset. Inputs are policy, package metadata,
  explicit file grants, capability telemetry, and host-only audit events. File contents
  and secret values must not enter logs. Persistent tokens remain an unresolved exposure
  under OQ-07.
- Build-versus-buy: reuse Windows Sandbox for the hypervisor, device redirection, and
  lifecycle. Build only the missing control plane. No custom hypervisor, driver, service,
  message bus, plugin framework, or model-serving stack is justified.
- Cost and latency: no cloud inference cost exists. Numeric RAM, disk, launch, and
  capability-transition budgets remain evidence-gated under OQ-10 and the relevant story.

## Requirement manifest

EXPECTED_REQUIREMENTS: 45

<!-- REQUIREMENTS_START -->
| Requirement ID | Short name |
|---|---|
| R-PLAT-01 | Existing Windows machine |
| R-PLAT-02 | Edition and build preflight |
| R-PLAT-03 | One-action launch |
| R-ISO-01 | No ambient host filesystem access |
| R-ISO-02 | Deliberate data entry only |
| R-ISO-03 | Free access inside the sandbox boundary |
| R-ISO-04 | Nothing outside reachable by default |
| R-ISO-05 | Hypervisor-enforced filesystem boundary |
| R-ISO-06 | Deny-by-default capabilities |
| R-ISO-07 | Host LAN blocked by default |
| R-DATA-01 | Deliberate file input |
| R-DATA-02 | Per-item grants; no broad mount |
| R-DATA-03 | Read-only grant default |
| R-DATA-04 | Separate data export decision |
| R-DATA-05 | Host-side grant and export audit |
| R-DATA-06 | Clipboard treated as a data path |
| R-APP-01 | ChatGPT Windows application |
| R-APP-02 | Claude Code support |
| R-APP-03 | OpenAI Codex support |
| R-APP-04 | Brave support |
| R-APP-05 | Config-driven additional tools |
| R-APP-06 | Tool and sign-in persistence |
| R-APP-07 | Reproducible provisioning |
| R-PERM-01 | Granular user-managed permissions |
| R-PERM-02 | Time-aware permissions |
| R-PERM-03 | Minimise seals microphone |
| R-PERM-04 | Restore re-enables permitted microphone |
| R-PERM-05 | Close ends microphone access |
| R-PERM-06 | Camera and screen-capture treatment |
| R-PERM-07 | Visible capability state |
| R-PERM-08 | Capability transition audit |
| R-PERM-09 | Capability changes fail closed |
| R-PERM-10 | Human-readable declarative policy |
| R-RES-01 | Low RAM |
| R-RES-02 | Low disk |
| R-RES-03 | Measured resource budget |
| R-RES-04 | Measured launch time |
| R-OPS-01 | Plain-language operation |
| R-OPS-02 | Actionable failure messages |
| R-OPS-03 | Truthful current-grant status |
| R-OPS-04 | Verifiable teardown |
| R-SEC-01 | HARD versus SOFT labels |
| R-SEC-02 | Written threat model |
| R-SEC-03 | Defined secret handling |
| R-SEC-04 | Host-controlled audit integrity |
<!-- REQUIREMENTS_END -->

## Delivery and role contract coverage

These contract IDs do not add product scope to the 45 R-IDs. They prove that the delivery,
engineering, AI, product, security, performance, operations, and UI rules governing the
work also map to backlog stories.

<!-- CONTRACT_COVERAGE_START -->
| Contract ID | Backlog story IDs | Coverage intent |
|---|---|---|
| C-DEL-01 | S-00.01.01 | Phase gate and explicit backlog approval |
| C-DEL-02 | S-00.01.01 | Stable hierarchy, zero orphans, open questions, and explicit exclusions |
| C-DEL-03 | S-00.01.01 | Machine board, states, WIP, blocking, and deferred rules |
| C-DEL-04 | S-00.01.01, S-06.01.01 | Ready, Done, evidence, and test re-execution |
| C-DEL-05 | S-00.01.01, S-06.01.01 | Standard-library verifier, CI, pre-push, and seeded lie |
| C-DEL-06 | S-00.01.01 | Sprint goal, demo, retro, change control, and traceability |
| C-AI-01 | S-00.01.01, S-05.02.01 | Problem, data, baseline, AI decision, evaluation honesty, and limits |
| C-PROD-01 | S-01.01.01, S-03.01.01, S-04.01.02, S-05.03.01 | Customer value, workflows, rules, metrics, exceptions, and risk |
| C-ARCH-01 | S-01.01.01, S-01.02.01, S-02.01.02 | Native, minimal, scalable architecture and build-versus-buy decisions |
| C-ENG-01 | S-00.01.01, S-01.02.01, S-02.01.02 | Reuse, standard library, native features, and smallest safe implementation |
| C-SEC-01 | S-01.02.01, S-04.01.01, S-05.01.01, S-05.02.01, S-05.02.02, S-06.02.01 | Threats, validation, authorisation, secrets, and negative controls |
| C-PERF-01 | S-01.02.03, S-03.02.01, S-06.03.01 | RAM, disk, launch, CPU, and transition-latency budgets |
| C-OPS-01 | S-00.01.01, S-03.02.03, S-05.03.01, S-05.03.02, S-06.03.01, S-06.04.01 | CI, observability, diagnostics, rollback, and teardown |
| C-UI-01 | S-03.02.02 | Persistent accessible capability-state UI |
<!-- CONTRACT_COVERAGE_END -->

## E-00 — Truthful delivery

- Owner: Product owner and technical lead
- Outcome: No feature is called complete without reproducible evidence.
- Value hypothesis: Automated evidence checks prevent false security claims.

### F-00.01 — Repository truth controls

- Parent: E-00
- Capability: Machine-check scope, board state, evidence, tests, and WIP.

#### Story S-00.01.01 — Verifiable delivery ledger

- User story: As the product owner, I want an independent verifier, so that I can detect incomplete or false delivery claims without trusting chat output.
- Business value: E-00 — independently tests every later security claim.
- Increment: 0
- Size: M
- Leading indicator: Percentage of DONE stories whose evidence is re-run successfully.
- Dependencies: None.
- Blocking risk: None; this is the feature-code gate.
- Acceptance criteria:
  - AC-S-00.01.01-01 | Given the binding brief and backlog, When verification runs, Then it exits non-zero for an unmapped requirement or a story missing from the board. | Test: tests/test_verify_board.py::VerifierContractTests.test_scope_and_board_lies_fail
  - AC-S-00.01.01-02 | Given a DONE story with missing evidence, test, file, line range, commit, or a forbidden stub, When verification runs, Then it exits non-zero and names the lie. | Test: tests/test_verify_board.py::VerifierContractTests.test_done_evidence_lies_fail
  - AC-S-00.01.01-03 | Given a valid DONE story, When verification runs, Then it safely re-runs its named test command and reports board counts, tested-criteria percentage, and every story not DONE. | Test: tests/test_verify_board.py::VerifierContractTests.test_done_tests_are_rerun_and_summary_is_truthful
  - AC-S-00.01.01-04 | Given a push or CI run, When checks start, Then the verifier and its unit tests run before success. | Test: tests/test_project_contract.py::ProjectContractTests.test_ci_and_pre_push_run_required_checks
- Tasks:
  - T-00.01.01.a: Define stable backlog, board, evidence, and traceability formats.
  - T-00.01.01.b: Implement scope, hierarchy, board, and WIP validation.
  - T-00.01.01.c: Implement safe evidence resolution and test re-execution.
  - T-00.01.01.d: Add verifier unit tests and the seeded-lie proof.
  - T-00.01.01.e: Wire CI and the tracked pre-push hook.

## E-01 — Launch a sealed, lightweight workspace

- Owner: Airlock user
- Outcome: Run Brave in a repeatable Windows Sandbox with no ambient host access or capture devices.
- Value hypothesis: A sealed browser is the smallest useful slice that reduces host exposure.

### F-01.01 — Compatible one-action launch

- Parent: E-01
- Capability: Validate the host and start one identifiable session.

#### Story S-01.01.01 — Preflight and launch

- User story: As a non-specialist Windows user, I want one launch command that checks my machine, so that unsupported systems fail safely with a clear fix.
- Business value: E-01 — prevents a false boundary on an unsupported host.
- Increment: 1
- Size: M
- Leading indicator: Supported-host launch success rate.
- Dependencies: OQ-01 and approved backlog.
- Blocking risk: OQ-01 can invalidate the architecture.
- Acceptance criteria:
  - AC-S-01.01.01-01: Given Home edition, build below 26100, disabled virtualisation, or a missing Sandbox feature, When preflight runs, Then launch is refused with the exact failed prerequisite and recovery action. | Test: tests/test_increment1_contract.py::Increment1ContractTests.test_preflight_refuses_unsupported_or_ambiguous_hosts
  - AC-S-01.01.01-02: Given a supported host, When Start-Airlock.ps1 runs, Then exactly one sandbox starts and its session identifier is recorded. | Test: tests/Invoke-Increment1Acceptance.ps1::Test-LiveLaunch
  - AC-S-01.01.01-03: Given an absent or unsafe required path, When launch is requested, Then no sandbox starts and no broad host folder is mapped. | Test: tests/Invoke-SourceAcceptance.ps1::Test-ReparseTraversal
- Tasks:
  - T-01.01.01.a: Implement edition, build, Sandbox-feature, CLI, and virtualisation checks.
  - T-01.01.01.b: Implement canonical Airlock-root and protected-path validation.
  - T-01.01.01.c: Implement one bounded launch and record its session ID.
  - T-01.01.01.d: Add unsupported-host, unsafe-path, and duplicate-launch tests.

### F-01.02 — Deny-by-default sealed profile

- Parent: E-01
- Capability: Generate explicit Windows Sandbox policy and provision Brave.

#### Story S-01.02.01 — Strict sealed profile

- User story: As an Airlock user, I want every capability denied unless required, so that unsafe Microsoft defaults cannot open hidden data paths.
- Business value: E-01 — establishes the hard host boundary and strict microphone guarantee.
- Increment: 1
- Size: M
- Leading indicator: Negative isolation tests passing.
- Dependencies: S-01.01.01, OQ-04, and approved backlog.
- Blocking risk: ProtectedClient compatibility requires a Windows spike.
- Acceptance criteria:
  - AC-S-01.02.01-01: Given strict policy, When XML is generated, Then audio, video, clipboard, printer, and vGPU are disabled explicitly, ProtectedClient is explicit, and memory is bounded. | Test: tests/Invoke-SourceAcceptance.ps1::Test-GeneratedStrictProfile
  - AC-S-01.02.01-02: Given generated mappings, When inspected, Then every host path is under the private Airlock root, every write flag is explicit, and Airlock-relative audit or state paths are refused. | Test: tests/Invoke-SourceAcceptance.ps1::Test-RelativeProtectedPaths
  - AC-S-01.02.01-03: Given a weakened profile, When security tests run, Then each exact security rejection is observed before the hardened profile passes. | Test: tests/Invoke-SourceAcceptance.ps1::Test-GeneratedStrictProfile
- Tasks:
  - T-01.02.01.a: Define and validate the strict policy contract.
  - T-01.02.01.b: Generate deterministic, escaped Sandbox XML.
  - T-01.02.01.c: Enforce the mapped-path allowlist and explicit write flags.
  - T-01.02.01.d: Add profile and deliberate-weakening tests.

#### Story S-01.02.02 — Brave provisioning

- User story: As an Airlock user, I want Brave inside the sealed session, so that the first increment is useful for web-based AI tools.
- Business value: E-01 — makes the sealed boundary usable without widening it.
- Increment: 1
- Size: M
- Leading indicator: Cold launches reaching a usable Brave window.
- Dependencies: S-01.02.01 and a signed installer contract.
- Blocking risk: Installer provenance and Sandbox compatibility need Windows evidence.
- Acceptance criteria:
  - AC-S-01.02.02-01: Given a pinned installer matching policy hash, When provisioning runs, Then Brave installs or is reused and telemetry records the exact version. | Test: tests/Invoke-Increment1Acceptance.ps1::Test-LiveLaunch
  - AC-S-01.02.02-02: Given a missing or mismatched installer, When provisioning runs, Then execution stops with an actionable error. | Test: tests/test_increment1_contract.py::Increment1ContractTests.test_guest_rechecks_package_and_records_exact_version
  - AC-S-01.02.02-03: Given successful provisioning, When Brave starts, Then strict policy and host mappings remain unchanged. | Test: tests/test_increment1_contract.py::Increment1ContractTests.test_no_bootstrap_source_is_mapped_directly
- Tasks:
  - T-01.02.02.a: Define checksum-validated Brave package policy.
  - T-01.02.02.b: Implement signed-package and pinned-hash validation.
  - T-01.02.02.c: Implement idempotent Brave install and version telemetry.
  - T-01.02.02.d: Add missing, mismatched, repeat-launch, and boundary tests.

#### Story S-01.02.03 — Enforced footprint budget

- User story: As a user on a normal Windows machine, I want RAM, disk, and launch cost measured, so that lightweight is a tested limit.
- Business value: E-01 — keeps protection practical for daily use.
- Increment: 1
- Size: M
- Leading indicator: Measured RAM, disk, and launch time against approved limits.
- Dependencies: S-01.02.02 and OQ-10.
- Blocking risk: No honest threshold exists before target-host baselining.
- Acceptance criteria:
  - AC-S-01.02.03-01: Given approved limits, When benchmarks run, Then idle RAM delta, peak RAM, Airlock disk delta, and cold-launch time are recorded with units and timestamps. | Test: tests/test_increment1_contract.py::Increment1ContractTests.test_resource_benchmark_has_three_runs_and_enforced_limits
  - AC-S-01.02.03-02: Given any value above its limit, When verification runs, Then the story fails and names the metric. | Test: tests/test_increment1_contract.py::Increment1ContractTests.test_resource_benchmark_has_three_runs_and_enforced_limits
  - AC-S-01.02.03-03: Given three clean launches, When results publish, Then median and worst-case values include failed runs. | Test: tests/test_increment1_contract.py::Increment1ContractTests.test_resource_benchmark_has_three_runs_and_enforced_limits
- Tasks:
  - T-01.02.03.a: Define the measurement protocol after OQ-10.
  - T-01.02.03.b: Collect native RAM, disk, and cold-launch measurements.
  - T-01.02.03.c: Evaluate approved thresholds and three-run aggregates.
  - T-01.02.03.d: Add threshold and report-integrity tests.

## E-02 — Persist tools without widening host access

- Owner: Airlock user
- Outcome: Keep approved tools and sign-in state through a narrow, reproducible path.
- Value hypothesis: Fast repeat use gives VM-like convenience at Sandbox weight.

### F-02.01 — Brokered persistence and toolchain

- Parent: E-02
- Capability: Persist mutable app data while keeping executable inputs immutable.

#### Story S-02.01.01 — Segmented vault persistence

- User story: As an Airlock user, I want approved app state to survive teardown, so that I do not reinstall and sign in each session.
- Business value: E-02 — provides usability through one narrow host opening.
- Increment: 2
- Size: L
- Leading indicator: Restored profiles with zero writes to immutable installer inputs.
- Dependencies: S-01.02.03, OQ-07, and OQ-13.
- Blocking risk: One writable vault permits installer tampering across sessions.
- Acceptance criteria:
  - AC-S-02.01.01-01: Given the approved segmented design, When the guest runs, Then installers and provisioning inputs are read-only and only named profile and workspace paths are writable.
  - AC-S-02.01.01-02: Given saved app state, When the sandbox relaunches, Then approved settings return without broad host mapping.
  - AC-S-02.01.01-03: Given guest code alters a pinned installer, When the write is attempted, Then it fails and the next launch verifies the original hash.
- Tasks:
  - T-02.01.01.a: Define approved immutable and writable path segments.
  - T-02.01.01.b: Map installer and provisioning inputs read-only.
  - T-02.01.01.c: Redirect named app profiles without broad mappings.
  - T-02.01.01.d: Add relaunch-persistence tests.
  - T-02.01.01.e: Add installer-tamper and hash-regression tests.

#### Story S-02.01.02 — Declarative CLI toolchain

- User story: As an Airlock user, I want Claude Code, Codex, Git, and Node installed from a versioned manifest, so that tools are reproducible config entries.
- Business value: E-02 — supports future tools without a plugin framework.
- Increment: 2
- Size: L
- Leading indicator: Manifest-to-installed-version match and warm-launch time.
- Dependencies: S-02.01.01 and OQ-05.
- Blocking risk: Floating or network-only installers destroy determinism.
- Acceptance criteria:
  - AC-S-02.01.02-01: Given valid policy, When provisioning runs, Then each enabled tool reaches its pinned version and telemetry records it.
  - AC-S-02.01.02-02: Given a new supported package entry, When config changes without script changes, Then the existing package contract installs it.
  - AC-S-02.01.02-03: Given a correct toolchain, When a warm session starts, Then provisioning is idempotent and stays within the approved time limit.
- Tasks:
  - T-02.01.02.a: Define the minimal package contract and pinned tool manifest.
  - T-02.01.02.b: Implement one manifest-driven package installer.
  - T-02.01.02.c: Record and compare installed tool versions.
  - T-02.01.02.d: Add idempotency and config-only extension tests.
  - T-02.01.02.e: Add warm-launch budget tests.

#### Story S-02.01.03 — ChatGPT Windows feasibility gate

- User story: As an Airlock user, I want the real ChatGPT Windows app tested, so that a browser fallback is not misrepresented as the desktop app.
- Business value: E-02 — resolves a named requirement honestly.
- Increment: 5
- Size: M
- Leading indicator: Reproducible package 9PLM9XGG6VKS install and launch.
- Dependencies: S-02.01.02 and OQ-03.
- Blocking risk: Store infrastructure is absent in a fresh Sandbox.
- Acceptance criteria:
  - AC-S-02.01.03-01: Given the target host, When the official-package spike runs, Then bootstrap steps, package identity, result, and logs are retained.
  - AC-S-02.01.03-02: Given unsupported install or sign-in, When the spike fails, Then R-APP-01 remains not DONE and any Brave PWA is labelled as a fallback requiring approval.
- Tasks:
  - T-02.01.03.a: Prepare a reversible Store/App Installer spike.
  - T-02.01.03.b: Run and record official-package install and launch.
  - T-02.01.03.c: Run and record sign-in and relaunch behaviour.
  - T-02.01.03.d: Publish the result without counting a fallback as R-APP-01.

## E-03 — Make runtime capabilities visible and fail closed

- Owner: Airlock user
- Outcome: Voice-mode capture follows explicit temporal policy without false confirmation.
- Value hypothesis: A visible state machine reduces accidental capture while preserving optional voice.

### F-03.01 — Declarative capability policy

- Parent: E-03
- Capability: Validate readable rules and expose current grants.

#### Story S-03.01.01 — Policy and truthful status

- User story: As an Airlock user, I want readable capability policy and current status, so that I control and inspect every grant.
- Business value: E-03 — turns hidden behaviour into an inspectable contract.
- Increment: 3
- Size: M
- Leading indicator: Rejected invalid policies and status matching confirmed telemetry.
- Dependencies: S-02.01.02, OQ-02, OQ-06, and OQ-11.
- Blocking risk: Screen-capture meaning and focus-loss policy are unresolved.
- Acceptance criteria:
  - AC-S-03.01.01-01: Given unknown or unsafe policy values, When policy loads, Then launch is refused with the JSON path and allowed values.
  - AC-S-03.01.01-02: Given valid policy, When status is requested, Then desired, last-confirmed, and stale state are distinct for every capability.
  - AC-S-03.01.01-03: Given strict mode, When policy loads, Then LIVE audio transitions are impossible because audio is absent.
- Tasks:
  - T-03.01.01.a: Define a versioned capability-policy schema.
  - T-03.01.01.b: Implement fail-fast schema and unsafe-value validation.
  - T-03.01.01.c: Implement desired, confirmed, and stale status projection.
  - T-03.01.01.d: Add strict-mode, status, and malformed-policy tests.

### F-03.02 — Focus-aware capability warden

- Parent: E-03
- Capability: Coordinate host window state, guest actions, visible status, and audit.

#### Story S-03.02.01 — Focus-aware state machine

- User story: As a voice-mode user, I want capture sealed when minimised and restored only under policy, so that background listening is reduced.
- Business value: E-03 — delivers the user's core temporal-permission request while labelling it SOFT.
- Increment: 3
- Size: L
- Leading indicator: Minimise-to-confirmed-SEALED latency and false-LIVE count.
- Dependencies: S-03.01.01, OQ-06, and OQ-11.
- Blocking risk: Guest mute is SOFT and hostile code can re-enable or spoof it.
- Acceptance criteria:
  - AC-S-03.02.01-01: Given voice mode is LIVE, When an approved sealing trigger occurs, Then the warden requests SEALED and never confirms it before correlated guest response.
  - AC-S-03.02.01-02: Given restored focus, permitted policy, and a healthy agent, When LIVE is requested, Then LIVE appears only after correlated confirmation.
  - AC-S-03.02.01-03: Given missing confirmation, When timeout expires, Then the warden visibly escalates and performs the configured fail-closed action.
  - AC-S-03.02.01-04: Given latency above the approved limit, When verification runs, Then it fails and retains the measurement.
- Tasks:
  - T-03.02.01.a: Implement native Sandbox-window and trigger detection.
  - T-03.02.01.b: Implement the desired-state transition table and request IDs.
  - T-03.02.01.c: Apply one guest capability request and validate correlation.
  - T-03.02.01.d: Implement timeout escalation and configured fail-closed action.
  - T-03.02.01.e: Add state, stale-response, failure, and latency tests.

#### Story S-03.02.02 — Accessible visible indicator

- User story: As an Airlock user, I want persistent capability status, so that I never guess whether voice is live, sealed, stale, or failed.
- Business value: E-03 — makes security state understandable at a glance.
- Increment: 3
- Size: M
- Leading indicator: State-to-indicator match across transitions.
- Dependencies: S-03.02.01.
- Blocking risk: Colour-only or temporary notifications fail accessibility and persistence.
- Acceptance criteria:
  - AC-S-03.02.02-01: Given each state, When it changes, Then a persistent host indicator shows distinct icon, text, and accessible name without colour alone.
  - AC-S-03.02.02-02: Given stale telemetry or escalation, When display updates, Then it cannot present LIVE or SEALED as confirmed.
- Tasks:
  - T-03.02.02.a: Define complete state-to-text and icon mappings.
  - T-03.02.02.b: Implement the smallest persistent native tray indicator.
  - T-03.02.02.c: Add accessible names and non-colour state cues.
  - T-03.02.02.d: Add state mapping and accessibility tests.

#### Story S-03.02.03 — Telemetry and host-only audit

- User story: As the product owner, I want correlated telemetry and sandbox-inaccessible audit, so that capability transitions can be investigated.
- Business value: E-03 — provides evidence without treating guest telemetry as HARD.
- Increment: 3
- Size: M
- Leading indicator: Audited transitions with matching request IDs and latency.
- Dependencies: S-03.02.01.
- Blocking risk: Malicious guests can forge SOFT telemetry; a nonce only prevents stale replies.
- Acceptance criteria:
  - AC-S-03.02.03-01: Given a request, When guest state is written, Then it contains schema, session, nonce, desired state, applied state, timestamp, and error.
  - AC-S-03.02.03-02: Given stale, malformed, mismatched, or absent telemetry, When validated, Then confirmation fails closed.
  - AC-S-03.02.03-03: Given any transition outcome, When it finishes, Then host-only audit records trigger, result, and latency.
- Tasks:
  - T-03.02.03.a: Define versioned telemetry and audit schemas.
  - T-03.02.03.b: Implement atomic guest telemetry writes.
  - T-03.02.03.c: Validate schema, session, nonce, timestamp, and applied state.
  - T-03.02.03.d: Append host-only transition audit events.
  - T-03.02.03.e: Add integrity tests and forgery-limit documentation.

## E-04 — Broker every host data movement

- Owner: Airlock user
- Outcome: Move selected data without ambient mounts or clipboard bypass.
- Value hypothesis: Per-item grants preserve the mental model that only deliberate data enters.

### F-04.01 — Runtime file broker

- Parent: E-04
- Capability: Read-only grants by default and separate exports.

#### Story S-04.01.01 — Read-only data-in grant

- User story: As an Airlock user, I want to grant one path read-only, so that tools can use it without standing host access.
- Business value: E-04 — creates the one deliberate data-in path.
- Increment: 4
- Size: M
- Leading indicator: Canonical narrow grants and denied writes.
- Dependencies: S-03.02.03.
- Blocking risk: Traversal, reparse points, and broad ancestors can widen scope.
- Acceptance criteria:
  - AC-S-04.01.01-01: Given one safe canonical path, When a default grant is approved, Then wsb share mounts only it read-only into the active session.
  - AC-S-04.01.01-02: Given a drive root, user root, audit path, reparse escape, missing path, or inactive session, When requested, Then no mount occurs.
  - AC-S-04.01.01-03: Given any grant outcome, When complete, Then host audit records path, mode, session, user action, and outcome without file contents.
- Tasks:
  - T-04.01.01.a: Implement canonical-path and existence validation.
  - T-04.01.01.b: Reject protected roots, broad ancestors, and reparse escapes.
  - T-04.01.01.c: Share one validated path read-only into the active session.
  - T-04.01.01.d: Append a content-free host grant audit event.
  - T-04.01.01.e: Add write-denial and adversarial-path tests.

#### Story S-04.01.02 — Separate write and export approval

- User story: As an Airlock user, I want write and export to require a louder action, so that data-in never silently grants data-out.
- Business value: E-04 — prevents read access becoming an unreviewed host-write channel.
- Increment: 4
- Size: L
- Leading indicator: Exported items with individual approval and audit.
- Dependencies: S-04.01.01 and OQ-12.
- Blocking risk: A writable share cannot prove each exported file was approved.
- Acceptance criteria:
  - AC-S-04.01.02-01: Given data-in access, When no write flag exists, Then guest writes fail and no export destination is exposed.
  - AC-S-04.01.02-02: Given requested write or export, When the user confirms resolved source, destination, mode, and session, Then only approved scope is exposed or copied.
  - AC-S-04.01.02-03: Given any export decision, When processing ends, Then separate host audit records item, destination, decision, and integrity hash.
- Tasks:
  - T-04.01.02.a: Resolve OQ-12 and define the export transaction.
  - T-04.01.02.b: Stage and copy only the confirmed source to destination.
  - T-04.01.02.c: Handle cancellation, collision, and partial-copy failure.
  - T-04.01.02.d: Audit the decision and resulting integrity hash.
  - T-04.01.02.e: Add scope, cancellation, collision, and audit tests.

#### Story S-04.01.03 — Clipboard boundary proof

- User story: As an Airlock user, I want clipboard blocked in both directions, so that it cannot bypass the broker.
- Business value: E-04 — closes an overlooked bidirectional path.
- Increment: 4
- Size: S
- Leading indicator: Both negative clipboard probes pass.
- Dependencies: S-01.02.01.
- Blocking risk: Actual RDP behaviour needs Windows evidence.
- Acceptance criteria:
  - AC-S-04.01.03-01: Given distinct host and guest clipboard markers, When paste is attempted either way, Then neither marker crosses.
  - AC-S-04.01.03-02: Given clipboard enabled in a weakened profile, When the same probe runs, Then it fails before hardened policy passes.
- Tasks:
  - T-04.01.03.a: Implement host-to-guest and guest-to-host clipboard probes.
  - T-04.01.03.b: Add weakened-profile and hardened-profile evidence.

## E-05 — Harden network, secrets, and lifecycle

- Owner: Airlock user
- Outcome: Restrict residual paths, document exact guarantees, and remove Airlock cleanly.
- Value hypothesis: Honest limits and teardown prevent partial control being mistaken for total security.

### F-05.01 — Guest egress policy

- Parent: E-05
- Capability: Default-deny outbound, allow named apps, and mitigate private-network reachability.

#### Story S-05.01.01 — Egress and LAN mitigation

- User story: As an Airlock user, I want only approved tools online and private networks blocked, so that guest code has less attack and exfiltration reach.
- Business value: E-05 — reduces exposure while stating firewall control is SOFT.
- Increment: 5
- Size: L
- Leading indicator: Blocked unapproved-app and RFC1918 probes with approved connectivity retained.
- Dependencies: S-02.01.02 and OQ-08.
- Blocking risk: Guest firewall is IP-based and bypassable by hostile privileged code.
- Acceptance criteria:
  - AC-S-05.01.01-01: Given approved apps, When firewall policy applies, Then outbound defaults deny and only resolved approved executables receive allows.
  - AC-S-05.01.01-02: Given host-local, RFC1918, link-local, and router probes, When run inside, Then they fail while required public service remains reachable.
  - AC-S-05.01.01-03: Given an unapproved executable, When it connects outbound, Then it fails without claiming domain-level filtering.
- Tasks:
  - T-05.01.01.a: Define blocked host-local, private, and link-local ranges.
  - T-05.01.01.b: Apply default-deny outbound firewall policy.
  - T-05.01.01.c: Resolve and allow only approved application executables.
  - T-05.01.01.d: Add approved, unapproved, and private-range probes.
  - T-05.01.01.e: Add weakened-policy evidence and residual-risk text.

### F-05.02 — Honest posture and secrets

- Parent: E-05
- Capability: Label trust boundaries and define token lifecycle.

#### Story S-05.02.01 — HARD/SOFT threat documentation

- User story: As an Airlock user, I want every control labelled by enforcement strength, so that I can act without false confidence.
- Business value: E-05 — prevents the highest-consequence communication failure.
- Increment: 5
- Size: M
- Leading indicator: Security claims linked to mechanism, test, and limitation.
- Dependencies: S-05.01.01.
- Blocking risk: Runtime mic and firewall must never be described as hypervisor-enforced.
- Acceptance criteria:
  - AC-S-05.02.01-01: Given a user-facing security claim, When docs lint runs, Then it links HARD or SOFT mechanism, evidence test, and limitation.
  - AC-S-05.02.01-02: Given the threat model, When checked, Then defended threats, exclusions, boundaries, and residual risks from §8 appear.
  - AC-S-05.02.01-03: Given strict and voice modes, When compared, Then only strict says audio is absent and voice says gating is SOFT.
- Tasks:
  - T-05.02.01.a: Write the HARD/SOFT control catalogue.
  - T-05.02.01.b: Write defended threats, exclusions, and residual risks.
  - T-05.02.01.c: Implement claim-to-mechanism documentation checks.
  - T-05.02.01.d: Add strict-versus-voice wording tests.

#### Story S-05.02.02 — Secret lifecycle policy

- User story: As an Airlock user, I want to choose token persistence, so that convenience does not silently become long-lived exposure.
- Business value: E-05 — makes credential persistence explicit.
- Increment: 5
- Size: M
- Leading indicator: Secrets with selected mode and verified teardown result.
- Dependencies: S-02.01.01 and OQ-07.
- Blocking risk: DPAPI and Store-token behaviour need target-host proof.
- Acceptance criteria:
  - AC-S-05.02.02-01: Given persistent, protected, or ephemeral mode, When provisioning starts, Then only selected storage is used and values never enter logs.
  - AC-S-05.02.02-02: Given ephemeral mode, When teardown completes, Then token material is absent from persistent Airlock paths by a content-safe probe.
  - AC-S-05.02.02-03: Given persistent mode, When status is requested, Then locations and residual exposure appear without values.
- Tasks:
  - T-05.02.02.a: Resolve OQ-07 and define approved secret modes.
  - T-05.02.02.b: Route each mode to only its selected storage.
  - T-05.02.02.c: Redact secret values from status, telemetry, and logs.
  - T-05.02.02.d: Implement ephemeral teardown and residue reporting.
  - T-05.02.02.e: Add redaction, persistence, and teardown tests.

### F-05.03 — Non-specialist operations

- Parent: E-05
- Capability: Explain, inspect, and remove Airlock without source knowledge.

#### Story S-05.03.01 — Operations and diagnostics

- User story: As a non-specialist, I want short commands and actionable errors, so that I can operate Airlock safely.
- Business value: E-05 — makes the boundary usable rather than theoretical.
- Increment: 5
- Size: M
- Leading indicator: Workflows completed without source edits.
- Dependencies: S-04.01.02 and S-05.01.01.
- Blocking risk: Diagnostics must not leak tokens or unrelated host paths.
- Acceptance criteria:
  - AC-S-05.03.01-01: Given a supported host, When documented install, launch, status, grant, and stop steps run, Then none requires source editing.
  - AC-S-05.03.01-02: Given each seeded failure, When it occurs, Then the message names failure, unchanged state, and next safe action without a bare stack trace.
  - AC-S-05.03.01-03: Given status, When displayed, Then session, grants, confirmation age, policy version, and control labels appear without secrets.
- Tasks:
  - T-05.03.01.a: Write install, launch, status, grant, stop, and recovery steps.
  - T-05.03.01.b: Implement actionable, state-preserving diagnostics.
  - T-05.03.01.c: Redact tokens and unrelated host paths from diagnostics.
  - T-05.03.01.d: Add workflow smoke and diagnostic-redaction tests.

#### Story S-05.03.02 — Verifiable teardown

- User story: As an Airlock user, I want one teardown action and residue report, so that I know what stopped and what persists.
- Business value: E-05 — closes access and exposes deliberate persistence.
- Increment: 5
- Size: M
- Leading indicator: Stopped sessions with revoked grants and accurate residue inventory.
- Dependencies: S-05.02.02 and S-05.03.01.
- Blocking risk: Intentional vault data must not be deleted or called residue-free silently.
- Acceptance criteria:
  - AC-S-05.03.02-01: Given a running sandbox, When teardown runs, Then wsb stop completes, warden exits, runtime grants end, and final audit writes.
  - AC-S-05.03.02-02: Given teardown, When residue verification runs, Then remaining paths are reported as intentional vault data or unexpected residue.
  - AC-S-05.03.02-03: Given explicit purge confirmation, When removal runs, Then only canonical Airlock-owned paths are targeted and result is audited.
- Tasks:
  - T-05.03.02.a: Stop the named session within a bounded timeout.
  - T-05.03.02.b: Stop the warden, close runtime grants, and append final audit.
  - T-05.03.02.c: Inventory intentional persistent data and unexpected residue.
  - T-05.03.02.d: Implement confirmed purge of canonical Airlock-owned paths only.
  - T-05.03.02.e: Add stop, residue, purge, and adversarial-path tests.

## E-06 — Repair launch and evidence truth

- Owner: Product owner and technical lead
- Outcome: The distributed repository launches when supported and every security claim is
  backed by executed behaviour rather than source-text presence.
- Value hypothesis: Repairing the evidence system and launch lifecycle before adding
  features prevents a broken security boundary from becoming trusted or widely used.

### F-06.01 — Distributed repository truth

- Parent: E-06
- Capability: Keep evidence, board state, and distributed Git history mutually resolvable.

#### Story S-06.01.01 — Restore the delivery lie detector

- User story: As the product owner, I want the cloned repository to reject false progress and verify its own evidence, so that CI and my machine report the same truth.
- Business value: E-06 — restores the gate required before any sandbox claim can advance.
- Increment: R1
- Size: M
- Leading indicator: Fresh GitHub clones producing the same verifier result as the authoring repository.
- Dependencies: None.
- Blocking risk: Evidence cannot close against a commit that exists only in an undistributed local history.
- Acceptance criteria:
  - AC-S-06.01.01-01 | Given evidence in a Git repository or exported tree, When its commit cannot be independently resolved, Then verification fails and names whether Git or the commit is missing. | Test: tests/test_verify_board.py::VerifierContractTests.test_commit_must_resolve_in_git_repository
  - AC-S-06.01.01-02 | Given a story remains BACKLOG while its declared implementation paths exist, When verification runs, Then it fails and names the unpulled implemented story. | Test: tests/test_verify_board.py::VerifierContractTests.test_implemented_backlog_story_fails
  - AC-S-06.01.01-03 | Given acceptance-test references merely resolve by name, When the summary prints, Then it labels that value as resolved tests rather than behavioural coverage. | Test: tests/test_verify_board.py::VerifierContractTests.test_summary_does_not_overclaim_coverage
  - AC-S-06.01.01-04 | Given escalated blocked work and an approved repair story, When board rules run, Then the repair is allowed only when the escalation and repair target are explicit. | Test: tests/test_verify_board.py::VerifierContractTests.test_escalated_blocker_requires_explicit_repair
- Tasks:
  - T-06.01.01.a: Parse and validate the complete AL-01 through AL-23 repair register.
  - T-06.01.01.b: Fail closed when Git evidence cannot be checked.
  - T-06.01.01.c: Detect implemented stories hidden in BACKLOG and enforce explicit repair escalation.
  - T-06.01.01.d: Rename the acceptance-test summary to what it actually measures.

### F-06.02 — Executed PowerShell boundary

- Parent: E-06
- Capability: Execute deterministic path, policy, and state controls on every CI run.

#### Story S-06.02.01 — Execute security behaviour before launch

- User story: As an Airlock user, I want the PowerShell boundary executed against safe fixtures, so that a launch-blocking or weakened-control defect is caught before Windows Sandbox starts.
- Business value: E-06 — proves the generated boundary instead of trusting strings in source files.
- Increment: R1
- Size: M
- Leading indicator: Security mutations rejected by executed cross-platform PowerShell tests.
- Dependencies: S-06.01.01.
- Blocking risk: Windows-only Authenticode and Sandbox runtime behaviour still require OQ-01 target-host evidence.
- Acceptance criteria:
  - AC-S-06.02.01-01 | Given real files and directories below an Airlock fixture root, When reparse traversal executes, Then both valid types reach the root and a deliberately weakened traversal test fails. | Test: tests/Invoke-SourceAcceptance.ps1::Test-ReparseTraversal
  - AC-S-06.02.01-02 | Given fixture mappings and the strict policy, When the profile generator executes, Then parsed XML contains only bounded mappings and every deliberate capability weakening is rejected. | Test: tests/Invoke-SourceAcceptance.ps1::Test-GeneratedStrictProfile
  - AC-S-06.02.01-03 | Given a protected relative path and a user-profile path containing state or audit as an ancestor, When mapping validation executes, Then only Airlock-relative state and audit segments are rejected. | Test: tests/Invoke-SourceAcceptance.ps1::Test-RelativeProtectedPaths
  - AC-S-06.02.01-04 | Given existing policy state or a WhatIf initialisation, When writes are evaluated, Then replacement is atomic and WhatIf never reports a write that did not occur. | Test: tests/Invoke-SourceAcceptance.ps1::Test-StateWriteContract
- Tasks:
  - T-06.02.01.a: Fix FileInfo traversal and root-relative protected-path checks.
  - T-06.02.01.b: Execute the real profile generator and parse its emitted XML.
  - T-06.02.01.c: Add deliberate weakening tests with exact expected failures.
  - T-06.02.01.d: Run source acceptance under PowerShell in CI and pre-push.

### F-06.03 — Safe session lifecycle

- Parent: E-06
- Capability: Identify, stop, reconcile, and clean one session without orphaned guests or stale state.

#### Story S-06.03.01 — Stop and clean every launched session

- User story: As an Airlock user, I want failed and completed sessions stopped and cleaned automatically, so that no invisible sandbox or installer copy survives by accident.
- Business value: E-06 — restores availability, disk discipline, and truthful current-session state.
- Increment: R1
- Size: L
- Leading indicator: Simulated post-start failures leaving zero active IDs, stale state files, or session directories.
- Dependencies: S-06.02.01.
- Blocking risk: The 24H2 wsb.exe JSON field names and Windows PowerShell 5.1 stderr behaviour need target-host confirmation.
- Acceptance criteria:
  - AC-S-06.03.01-01 | Given documented wsb JSON, When session identity is parsed, Then only the named ID field is accepted and ambiguous GUID scraping is impossible. | Test: tests/Invoke-LifecycleAcceptance.ps1::Test-WsbIdentityParsing
  - AC-S-06.03.01-02 | Given any failure after start, When launch handling exits, Then the named guest is stopped and the failure remains actionable. | Test: tests/Invoke-LifecycleAcceptance.ps1::Test-PostStartFailureCleanup
  - AC-S-06.03.01-03 | Given a stopped or externally closed guest, When state reconciliation runs, Then active-session.json and its staging directory are removed without touching other paths. | Test: tests/Invoke-LifecycleAcceptance.ps1::Test-StopAndStateReconciliation
  - AC-S-06.03.01-04 | Given repeated benchmark launches, When one guest is stopped, Then the collector waits until its ID disappears before the next run and fails on timeout. | Test: tests/Invoke-LifecycleAcceptance.ps1::Test-BenchmarkStopWait
- Tasks:
  - T-06.03.01.a: Replace GUID scraping with named-field parsing and raw-output diagnostics.
  - T-06.03.01.b: Centralise post-start cleanup for every failure branch.
  - T-06.03.01.c: Add Stop-Airlock with bounded polling, state reconciliation, and owned-directory cleanup.
  - T-06.03.01.d: Make acceptance and benchmark teardown wait for confirmed stop.

### F-06.04 — Honest provenance and scope

- Parent: E-06
- Capability: Bind results to their launch and distinguish measured facts from contract inputs.

#### Story S-06.04.01 — Remove unsupported product claims

- User story: As an Airlock user, I want every result and scope statement to describe what was actually measured, so that I do not mistake an offline browser or echoed value for proven security evidence.
- Business value: E-06 — prevents false confidence at the product boundary.
- Increment: R1
- Size: M
- Leading indicator: Result records with verified session correlation and no contract-echo evidence fields.
- Dependencies: S-06.03.01.
- Blocking risk: Online browsing remains deferred until OQ-08 has an accepted LAN-risk design.
- Acceptance criteria:
  - AC-S-06.04.01-01 | Given a pinned installer and policy version, When host and guest validate it, Then the actual installer version is checked against policy and recorded as measured. | Test: tests/Invoke-ProvenanceAcceptance.ps1::Test-MeasuredInstallerVersion
  - AC-S-06.04.01-02 | Given a unique session and nonce, When provisioning writes a result, Then the host accepts only the matching correlation values. | Test: tests/Invoke-ProvenanceAcceptance.ps1::Test-SessionCorrelation
  - AC-S-06.04.01-03 | Given Increment 1 has networking disabled, When scope and board state are inspected, Then online browsing is explicitly DEFERRED with a reason and revisit trigger. | Test: tests/test_project_contract.py::ProjectContractTests.test_offline_browsing_is_explicitly_deferred
- Tasks:
  - T-06.04.01.a: Measure and compare installer version on both sides of the boundary.
  - T-06.04.01.b: Add cryptographically random nonce and session correlation to contract and result.
  - T-06.04.01.c: Validate correlation before accepting provisioning success.
  - T-06.04.01.d: Correct README, architecture, open-question, board, and demo claims.

## Approved audit repair register

The product owner reproduced AL-01 and AL-02 and approved this complete register on
2026-08-29. Every finding maps to exactly one repair story; no finding is silently dropped.

EXPECTED_AUDIT_FINDINGS: 23

<!-- AUDIT_START -->
| Finding ID | Severity | Repair story | Repair intent |
|---|---|---|---|
| AL-01 | Blocker | S-06.02.01 | Fix FileInfo traversal and execute it |
| AL-02 | Critical | S-06.01.01 | Make distributed commit evidence resolve |
| AL-03 | Critical | S-06.02.01 | Replace source-string security checks with execution |
| AL-04 | High | S-06.03.01 | Stop the guest after every post-start failure |
| AL-05 | High | S-06.03.01 | Parse named wsb identity fields only |
| AL-06 | High | S-06.03.01 | Remove per-session staging after stop |
| AL-07 | High | S-06.03.01 | Reconcile stale active-session state |
| AL-08 | High | S-06.03.01 | Wait for confirmed stop between benchmarks |
| AL-09 | Medium | S-06.02.01 | Remove unreachable absolute denylist logic |
| AL-10 | Medium | S-06.02.01 | Assert exact negative-control failures |
| AL-11 | Medium | S-06.02.01 | Evaluate protected names relative to Airlock root |
| AL-12 | Medium | S-06.04.01 | Record measured installer version |
| AL-13 | Medium | S-06.02.01 | Restore the binding 4096 MB ceiling |
| AL-14 | Medium | S-06.02.01 | Use real atomic replace for existing state |
| AL-15 | Medium | S-06.02.01 | Make WhatIf output truthful |
| AL-16 | Medium | S-06.04.01 | Implement the documented nonce correlation |
| AL-17 | Process | S-06.04.01 | Record offline browsing as DEFERRED |
| AL-18 | Process | S-06.01.01 | Reject implementation hidden in BACKLOG |
| AL-19 | Process | S-06.02.01 | Execute portable PowerShell in CI |
| AL-20 | Note | S-06.01.01 | Fail when commit verification lacks Git |
| AL-21 | Note | S-06.01.01 | Extend stub checks to PowerShell and whole files |
| AL-22 | Note | S-06.01.01 | Rename test-resolution summary honestly |
| AL-23 | Note | S-06.03.01 | Avoid Windows PowerShell native-stderr ambiguity |
<!-- AUDIT_END -->

## Requirements → Backlog coverage

The verifier compares the fixed 45-ID source manifest above with this table.

<!-- COVERAGE_START -->
| Requirement ID | Covered by story | Coverage intent |
|---|---|---|
| R-PLAT-01 | S-01.01.01 | Existing Windows host |
| R-PLAT-02 | S-01.01.01 | Exact prerequisite checks |
| R-PLAT-03 | S-01.01.01 | One-action launch |
| R-ISO-01 | S-01.02.01 | No ambient host filesystem access |
| R-ISO-02 | S-04.01.01 | Deliberate brokered data-in |
| R-ISO-03 | S-01.02.01 | Free access inside guest boundary |
| R-ISO-04 | S-01.02.01 | Nothing outside reachable by default |
| R-ISO-05 | S-01.02.01 | Hypervisor filesystem boundary |
| R-ISO-06 | S-01.02.01 | Explicit deny-by-default profile |
| R-ISO-07 | S-05.01.01 | LAN and egress mitigation |
| R-DATA-01 | S-04.01.01 | Deliberate file grant |
| R-DATA-02 | S-04.01.01 | Per-item canonical scope |
| R-DATA-03 | S-04.01.01, S-04.01.02 | Read-only default and loud write action |
| R-DATA-04 | S-04.01.02 | Separate export decision |
| R-DATA-05 | S-04.01.01, S-04.01.02 | Host-only grant and export audit |
| R-DATA-06 | S-01.02.01, S-04.01.03 | Clipboard disabled and proven |
| R-APP-01 | S-02.01.03 | Real ChatGPT app feasibility |
| R-APP-02 | S-02.01.02 | Claude Code toolchain |
| R-APP-03 | S-02.01.02 | OpenAI Codex toolchain |
| R-APP-04 | S-01.02.02, S-05.01.01 | Offline Brave first; browsing only after egress controls |
| R-APP-05 | S-02.01.02 | Config-driven package additions |
| R-APP-06 | S-02.01.01 | Persistent app state |
| R-APP-07 | S-01.02.02, S-02.01.02 | Pinned reproducible provisioning |
| R-PERM-01 | S-01.02.01, S-03.01.01 | Granular deny-by-default policy |
| R-PERM-02 | S-03.01.01, S-03.02.01 | Temporal policy |
| R-PERM-03 | S-03.02.01 | Seal on minimise |
| R-PERM-04 | S-03.02.01 | Restore after confirmation |
| R-PERM-05 | S-03.02.01, S-05.03.02 | Close ends access |
| R-PERM-06 | S-03.01.01, S-03.02.01 | Camera and screen decision |
| R-PERM-07 | S-03.01.01, S-03.02.02 | At-a-glance status |
| R-PERM-08 | S-03.02.03 | Transition audit |
| R-PERM-09 | S-03.02.01, S-03.02.03 | Fail closed |
| R-PERM-10 | S-03.01.01 | Declarative policy |
| R-RES-01 | S-01.02.01, S-01.02.03 | Bounded measured RAM |
| R-RES-02 | S-01.02.03 | Measured disk |
| R-RES-03 | S-01.02.03 | Enforced budget |
| R-RES-04 | S-01.02.03, S-02.01.02 | Time-to-usable |
| R-OPS-01 | S-05.03.01 | Plain-language operations |
| R-OPS-02 | S-01.01.01, S-05.03.01 | Actionable failures |
| R-OPS-03 | S-03.01.01, S-04.01.01, S-05.03.01 | Truthful status |
| R-OPS-04 | S-05.03.02 | Teardown |
| R-SEC-01 | S-01.02.01, S-05.02.01 | HARD/SOFT labels |
| R-SEC-02 | S-05.02.01 | Threat model |
| R-SEC-03 | S-02.01.01, S-05.02.02, S-05.03.02 | Secret lifecycle |
| R-SEC-04 | S-03.02.03 | Host-only audit |
<!-- COVERAGE_END -->

**Coverage total: 45 / 45. Orphan requirements: 0.**

## Explicit OUT_OF_SCOPE for the MVP

- Domain-level egress filtering: it needs an in-guest proxy; per-application firewall
  allowlisting is the smaller MVP control.
- Multiple concurrent sandboxes or multi-profile orchestration: the first user needs one
  bounded session, and concurrency would widen lifecycle and grant risks.
- GPU compute or local-model inference: the requested tools are remote-service clients and
  strict mode disables vGPU to reduce attack surface and RAM use.
- macOS, Linux-host, or Windows Home support: the selected HARD boundary and runtime CLI
  are Windows Sandbox capabilities unavailable on those hosts.
- WSL2 Track B implementation: it is a separate CLI-only architecture and remains OQ-09
  for post-MVP review.
- Automated malware analysis or behaviour monitoring: Airlock contains tools; it does not
  classify their intent or claim to detect malware.
- A general GUI beyond the required native indicator: command-driven operation and one
  accessible state indicator meet the MVP without a second application layer.
- Multi-user or cross-machine sharing: identity, remote access, and shared-secret policy
  are separate product problems with no current requirement.
