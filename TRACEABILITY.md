# Airlock Traceability

This ledger connects each story to requirements, expected implementation, evidence, and
current state. Planned paths are not claims that files already exist.

| Story | Requirements | Planned implementation | Planned evidence | State |
|---|---|---|---|---|
| S-00.01.01 | Delivery contract §2.5 | scripts/verify_board.py; CI; pre-push | BOARD.md evidence; tests/test_verify_board.py; evidence/SEEDED_LIE_PROOF.md | DONE — repaired distributed evidence |
| S-01.01.01 | R-PLAT-01..03; R-OPS-02 | scripts/Airlock.Common.ps1; scripts/Start-Airlock.ps1 | executed source acceptance; tests/Invoke-Increment1Acceptance.ps1 | BLOCKED — repair and Windows evidence pending |
| S-01.02.01 | R-ISO-01,03..06; R-PERM-01; R-DATA-06; R-SEC-01 | scripts/New-AirlockProfile.ps1; policy.json | executed PowerShell weakening and mapping tests; Windows profile probes | BLOCKED — repair in progress |
| S-01.02.02 | R-APP-04; R-APP-07 | scripts/Initialize-Airlock.ps1; guest/provision.ps1 | signature/hash source contracts; live Brave acceptance | BLOCKED — installer acceptance and repair dependency |
| S-01.02.03 | R-RES-01..04 | tests/Measure-Increment1.ps1; DEMO.md | three-run target-host threshold report | BLOCKED — OQ-10 and lifecycle repair dependency |
| S-02.01.01 | R-APP-06; R-SEC-03 | segmented mappings and profiles | persistence and immutable-input tests | BACKLOG |
| S-02.01.02 | R-APP-02,03,05,07; R-RES-04 | policy manifest; guest/provision.ps1 | version, idempotency, and launch tests | BACKLOG |
| S-02.01.03 | R-APP-01 | reversible Store spike | target-host install/sign-in evidence | BACKLOG |
| S-03.01.01 | R-PERM-01,02,07,10; R-OPS-03 | policy.json validation and status | schema and stale-state tests | BACKLOG |
| S-03.02.01 | R-PERM-03..06,09 | scripts/Airlock-Warden.ps1; guest/agent.ps1 | transition, timeout, and latency tests | BACKLOG |
| S-03.02.02 | R-PERM-07 | native host indicator | state and accessibility tests | BACKLOG |
| S-03.02.03 | R-PERM-08,09; R-SEC-04 | telemetry and host audit | correlation and integrity tests | BACKLOG |
| S-04.01.01 | R-ISO-02; R-DATA-01..03,05; R-OPS-03 | scripts/Grant-AirlockFolder.ps1 | path and read-only tests | BACKLOG |
| S-04.01.02 | R-DATA-03..05 | approved export transaction | cancellation, scope, and audit tests | BACKLOG |
| S-04.01.03 | R-DATA-06 | clipboard probes | weakened and hardened profile tests | BACKLOG |
| S-05.01.01 | R-ISO-07 | guest firewall policy | app, LAN, and negative probes | DEFERRED — online browsing intentionally outside offline Increment 1 |
| S-05.02.01 | R-SEC-01,02 | control catalogue and threat model | documentation lint | BACKLOG |
| S-05.02.02 | R-SEC-03 | secret modes | redaction and teardown tests | BACKLOG |
| S-05.03.01 | R-OPS-01..03 | README and safe diagnostics | workflow smoke tests | BACKLOG |
| S-05.03.02 | R-PERM-05; R-OPS-04; R-SEC-03 | stop, residue report, purge | teardown and path-safety tests | BACKLOG |
| S-06.01.01 | Delivery repair AL-02,18,20,21,22 | scripts/verify_board.py; BOARD.md | exact-root Git test; CI run 33254551558 | DONE |
| S-06.02.01 | Security repair AL-01,03,09,10,11,13,14,15,19 | common/profile/initialiser controls; PowerShell CI | tests/Invoke-SourceAcceptance.ps1; CI run 33254551558 | DONE |
| S-06.03.01 | Lifecycle repair AL-04..08,23 | Airlock.Lifecycle.ps1; Start-Airlock.ps1; Stop-Airlock.ps1; benchmark teardown | tests/Invoke-LifecycleAcceptance.ps1; source CI run 33473134496; target-host acceptance | IN_REVIEW — source gates passed; OQ-14/OQ-15 target evidence pending |
| S-06.04.01 | Product-truth repair AL-12,16,17 | provisioning correlation; docs; deferred register | provenance acceptance; project contract test | BACKLOG |
| S-06.05.01 | CR-2026-08-30-01; R-PLAT-01..03; R-OPS-02 | scripts/Airlock.Platform.ps1; scripts/Start-Airlock.ps1; shared strict `.wsb` profile; version-aware acceptance and benchmark cleanup | source CI run 33367645830; tests/Invoke-CompatibilityAcceptance.ps1; tests/test_increment1_contract.py; tests/test_project_contract.py; tests/Invoke-Increment1Acceptance.ps1 -RunLive on Windows 10 build 19045 | IN_REVIEW — source gates passed; OQ-15 target-host live evidence blocks DONE |
