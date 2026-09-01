# Airlock

Airlock launches Brave inside a strict, offline Windows Sandbox without ambient access
to the host user profile, Desktop, Documents, clipboard, microphone, camera, printers,
GPU, or network.

**Delivery status:** Increment 0 is DONE. Increment 1 remains evidence-gated. The
fail-safe lifecycle repair `S-06.03.01` is IN_REVIEW after its portable source boundary
passed GitHub Actions run 33473134496 on PowerShell 7 and Windows PowerShell 5.1. The
Windows 10 compatibility repair `S-06.05.01` is also IN_REVIEW. Neither can be called
DONE until the target-host runs named in OQ-14 and OQ-15 pass.

## Supported host modes

Airlock now uses one command and two native Windows Sandbox control paths:

| Host | Launch mode | Lifecycle evidence |
|---|---|---|
| Windows 10 Pro 22H2, build 19045, AMD64 | `legacy-wsb` | Exact `WindowsSandbox.exe` PID, executable path, and process creation identity. No Sandbox ID is claimed. |
| Windows 11 Pro/Enterprise/Education, build 26100+ | `managed-cli` | Existing `wsb.exe start/list/stop --raw` path and managed Sandbox ID. |

The generated `.wsb` security profile is shared. The Windows 10 path does **not** weaken
network, device, clipboard, mapping, ProtectedClient, or memory policy. The lifecycle
control is simply weaker because the older Windows Sandbox runtime does not expose the
new managed CLI. Airlock reports that difference explicitly instead of pretending the
platforms are equivalent.

Microsoft documents Windows Sandbox and `.wsb` configuration for Windows 10 and Windows
11. The newer Store-based Sandbox and command-line lifecycle begin with Windows 11 24H2.

## What this increment does

- Checks Windows edition/version/build, CPU architecture, RAM, disk, hardware
  virtualisation, the Sandbox feature, and the correct native launcher before changing
  anything.
- Selects `WindowsSandbox.exe` on the approved Windows 10 build and `wsb.exe` on Windows
  11 24H2+.
- Pins a user-supplied Brave standalone installer by valid Authenticode publisher, exact
  SHA-256, and version; Airlock never downloads an executable silently.
- Generates a deny-by-default Sandbox profile from `policy.json`.
- Copies only the pinned installer, pinned guest script, and policy lock into a fresh
  per-session bootstrap directory and maps it read-only.
- Maps one new, empty result directory writable for non-secret provisioning telemetry.
- Refuses concurrent launches. Windows 10 refuses an already-running verified
  `WindowsSandbox.exe`; Windows 11 refuses an existing managed Sandbox session.
- Generates the Windows 11 managed ID before launch, stops that exact ID after any
  post-start failure, and never discovers identity by scraping arbitrary GUIDs.
- Records host-only session state under `%LOCALAPPDATA%\Airlock\state`, reconciles an
  externally closed session, and deletes only that session's owned staging directory.
- Provides one guarded stop command for both host modes and waits for confirmed shutdown
  before cleanup or another benchmark launch.

Brave is deliberately **offline** in this increment. Online browsing needs the later
egress and LAN-isolation story; enabling networking now would silently weaken the
boundary.

## Requirements

For both modes:

- Pro, Enterprise, or Education edition. Home and Server are not supported.
- Hardware virtualisation and SLAT, at least 4 GB RAM, two CPU cores, and 1 GB free disk.
- The optional Windows feature `Containers-DisposableClientVM` enabled.
- An official Brave `BraveBrowserStandaloneSilentSetup.exe` downloaded by you.

Supported OS contracts:

- Windows 10 Pro 22H2 build **19045**, AMD64.
- Windows 11 Pro/Enterprise/Education build **26100 or newer**, AMD64 or ARM64.

### Enable Windows Sandbox

Open **Administrator PowerShell** and run:

    Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All

Then reboot if Windows asks you to.

## Build and launch

Open Windows PowerShell in this repository.

1. Check the host without launching anything:

       powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Start-Airlock.ps1 -PreflightOnly

   A passing Windows 10 machine should report `PlatformMode = legacy-wsb` and
   `LifecycleControl = legacy-process`. A passing Windows 11 24H2+ machine should report
   `PlatformMode = managed-cli` and `LifecycleControl = managed-id`.

2. Pin the signed Brave standalone installer once:

       powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Initialize-Airlock.ps1 -InstallerPath C:\path\to\BraveBrowserStandaloneSilentSetup.exe

3. Start Airlock on every use:

       powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Start-Airlock.ps1

4. Stop the verified session and remove its owned staging:

       powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Stop-Airlock.ps1

The command prints the launch mode, host-only state file, and provisioning-result path.
Windows 11 additionally prints the managed Sandbox ID. Windows 10 prints the guarded
process ID instead and intentionally leaves `SandboxId` empty.

The stop command returns `Status=stopped` only after the recorded identity is no longer
active and its exact session directory and state record have been removed. An identity
mismatch or timeout fails closed and keeps the state needed for recovery.

If Windows marks scripts from a downloaded archive as remote, inspect them first and use
`Unblock-File` only on reviewed Airlock `.ps1` files. Do not lower the machine's global
execution policy.

## Verify

Repository checks:

    python -m unittest discover -s tests -v
    python scripts/verify_board.py

Portable PowerShell boundaries:

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-SourceAcceptance.ps1
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-CompatibilityAcceptance.ps1
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-LifecycleAcceptance.ps1

Live target-host acceptance after initialisation:

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-Increment1Acceptance.ps1 -RunLive

The live acceptance script understands both launch modes. On Windows 10 it verifies that
no managed Sandbox ID is invented and that PID + executable path + process creation
identity still point to the launched native Sandbox process before guarded shutdown. On
both modes it requires confirmed stop and removal of the matching state and staging.

Collect a three-launch resource baseline without inventing limits:

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Measure-Increment1.ps1 -CollectOnly

After the product owner approves limits, rerun with all three explicit thresholds. The
script exits non-zero for any failed run or exceeded limit.

## Migration and rollback

There is no database or guest-state migration. The host state file keeps schema version 1
and gains version-aware lifecycle fields: `launchMode`, `lifecycleControl`, optional
`launcherPath`, and Windows 10 process identity fields. The Windows 11 `sandboxId` is now
generated and validated before launch; old schema-1 state remains readable because
`launcherPath` is not required during state validation.

Rollback is code-only. Before reverting, run `scripts\Stop-Airlock.ps1` and require a
successful result. Existing package and policy locks remain valid because the strict
`.wsb` profile and pinned package contract did not change. Do not delete
`active-session.json` manually while the recorded guest may still be active, and never
kill a legacy PID that has not been identity-checked.

## Delivery method

Airlock uses a **Scrum + Kanban hybrid**. Scrum gives each security change a fixed,
reviewable vertical increment. Kanban supplies the repository board and WIP limit so one
security slice is finished or escalated before another is pulled. `BOARD.md`, not chat,
is state. A story becomes DONE only when the verifier re-runs resolvable evidence and all
required target-host evidence exists.

See [architecture and threat boundaries](docs/ARCHITECTURE.md), [pasteable demo](DEMO.md),
[open decisions](OPEN_QUESTIONS.md), and [traceability](TRACEABILITY.md).
