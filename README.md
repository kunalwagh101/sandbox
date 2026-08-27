# Airlock

Airlock launches Brave inside a strict, offline Windows Sandbox without ambient access
to the host user profile, Desktop, Documents, clipboard, microphone, camera, printers,
GPU, or network.

**Delivery status:** Increment 0 is DONE. Increment 1 source is implemented and under
review. It is not DONE until the live acceptance script passes on a supported Windows
machine. Backlog approval was recorded on 2026-08-27.

## What this increment does

- Checks Windows edition, build, CPU architecture, RAM, disk, hardware virtualisation,
  the Sandbox feature, and the 24H2 `wsb.exe` CLI before changing anything.
- Pins a user-supplied Brave standalone installer by valid Authenticode publisher,
  exact SHA-256, and version; Airlock never downloads an executable silently.
- Generates a deny-by-default Sandbox profile from `policy.json`.
- Copies only the pinned installer, pinned guest script, and policy lock into a fresh
  per-session bootstrap directory and maps it read-only.
- Maps one new, empty result directory writable for non-secret provisioning telemetry.
- Refuses concurrent launches and refuses to start beside another active Sandbox.
- Records the Sandbox ID and host-only session state under
  `%LOCALAPPDATA%\Airlock\state`.

Brave is deliberately **offline** in Increment 1. Online browsing needs the later egress
and LAN-isolation story; enabling networking now would silently weaken the boundary.

## Requirements

- Windows 11 Pro, Enterprise, or Education, version 24H2 / build 26100 or newer.
- AMD64 or ARM64, hardware virtualisation and SLAT, at least 4 GB RAM, two CPU cores,
  and 1 GB free disk.
- The optional Windows feature `Containers-DisposableClientVM` enabled.
- An official Brave `BraveBrowserStandaloneSilentSetup.exe` downloaded by you.

Microsoft's [Windows Sandbox installation guide](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-install)
explains how to enable the feature. Brave publishes installers on its
[official release page](https://github.com/brave/brave-browser/releases).

## Build and launch

Open Windows PowerShell in this repository.

1. Check the host without launching anything:

       powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Start-Airlock.ps1 -PreflightOnly

2. Pin the signed Brave standalone installer once:

       powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Initialize-Airlock.ps1 -InstallerPath C:\path\to\BraveBrowserStandaloneSilentSetup.exe

3. Start Airlock on every use:

       powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Start-Airlock.ps1

The command prints the Sandbox ID, host-only state file, and provisioning-result path.
The Brave window should appear inside Windows Sandbox. Close the Sandbox window when
finished; its guest state is disposable in this increment.

If Windows marks scripts from a downloaded archive as remote, inspect them first and
use `Unblock-File` only on the reviewed Airlock `.ps1` files. Do not lower the machine's
global execution policy.

## Verify

Repository checks, runnable on any development host:

    python -m unittest discover -s tests -v
    python scripts/verify_board.py

Live Windows acceptance after initialisation:

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-Increment1Acceptance.ps1 -RunLive

First collect a three-launch resource baseline without inventing limits:

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Measure-Increment1.ps1 -CollectOnly

After the product owner approves limits, rerun with all three explicit thresholds. The
script exits non-zero for any failed run or exceeded limit.

## Delivery method

Airlock uses a fixed-scope Scrum increment with a Kanban execution board and a one-story
WIP limit. Scrum fits because the MVP is a sequence of testable vertical security slices;
the Kanban limit prevents partially verified security work from being hidden in parallel.
`BOARD.md`, not chat, is the state. A story becomes DONE only when the verifier re-runs
resolvable evidence.

See [architecture and threat boundaries](docs/ARCHITECTURE.md), [pasteable demo](DEMO.md),
[open decisions](OPEN_QUESTIONS.md), and [traceability](TRACEABILITY.md).
