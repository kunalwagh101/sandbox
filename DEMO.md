# Airlock Demo

## Repair R2 — cross-version compatibility

Run the deterministic compatibility boundary first:

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-CompatibilityAcceptance.ps1

Expected: `COMPATIBILITY_ACCEPTANCE: PASSED (2 tests)`. This proves Windows 10 build
19045 selects `legacy-wsb`, Windows 11 build 26100+ selects `managed-cli`, unsupported
contracts fail closed, and the legacy path records process identity without inventing a
Sandbox ID.

## Repair R1 — source security boundary

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-SourceAcceptance.ps1

Expected: `SOURCE_ACCEPTANCE: PASSED (4 tests)`. It executes path traversal, mapping,
profile generation, strict-policy weakening, atomic state writing, and initialization
contracts without starting Windows Sandbox.

## Increment 1 — strict offline Brave Sandbox

Run these commands from Windows PowerShell in the repository.

### 1. Prove the host is supported without launching

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Start-Airlock.ps1 -PreflightOnly

Expected on the approved Windows 10 machine:

    Status: passed
    Build: 19045
    PlatformMode: legacy-wsb
    LifecycleControl: legacy-process
    SandboxFeature: Enabled

Expected on Windows 11 24H2+:

    Status: passed
    Build: 26100 or newer
    PlatformMode: managed-cli
    LifecycleControl: managed-id
    SandboxFeature: Enabled

An unsupported host gets the exact failed prerequisite and recovery action. No Sandbox
starts during preflight.

### 2. Pin one official Brave installer

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Initialize-Airlock.ps1 -InstallerPath C:\path\to\BraveBrowserStandaloneSilentSetup.exe

Expected: valid Brave publisher, exact installer version, 64-character SHA-256, and
`Networking: Disable`. A bad signature or wrong publisher fails before execution.

### 3. Launch once

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Start-Airlock.ps1

Expected: exactly one Sandbox window and Brave opening inside it. Brave is offline.
Microphone, camera, clipboard, printer, vGPU, and networking are all disabled.

On Windows 10, output must show `LaunchMode=legacy-wsb`, `LifecycleControl=legacy-process`,
a process ID, and an empty `SandboxId`.

On Windows 11 24H2+, output must show `LaunchMode=managed-cli`,
`LifecycleControl=managed-id`, and a managed Sandbox ID.

### 4. Run negative controls and live acceptance

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-Increment1Acceptance.ps1 -RunLive

Expected: `INCREMENT_1_ACCEPTANCE: PASSED (live=True)`.

The script proves weakened audio policy and a broad user-profile mapping are refused,
then launches the real Sandbox. Windows 10 verifies PID + executable path + process
creation identity before cleanup. Windows 11 verifies the managed Sandbox ID before
cleanup.

### 5. Collect the resource baseline

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Measure-Increment1.ps1 -CollectOnly

Expected: three launches in `%LOCALAPPDATA%\Airlock\evidence\increment-1-benchmark.json`
with launch mode, lifecycle control, failures, cold-launch seconds, RAM delta, disk delta,
median, and worst measurements. Limits are not guessed; OQ-10 must be approved from real
measurements before enforced thresholds are used.

## Increment 0 — prove the delivery gate

    python -m tests.seeded_lie_demo
    python -m unittest discover -s tests -v
    python scripts/verify_board.py

Expected: the seeded lie is rejected, all repository tests pass, and the verifier prints
`VERIFICATION: PASSED` without claiming the compatibility story DONE before live Windows
10 evidence exists.
