# Airlock Demo

## Increment 1 — strict offline Brave Sandbox

Run these commands from Windows PowerShell in the repository.

### 1. Prove the host is supported without launching

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Start-Airlock.ps1 -PreflightOnly

Expected: `Status: passed`, Windows build 26100 or newer, Sandbox feature `Enabled`, and
the resolved `wsb.exe` path. An unsupported host receives the failed prerequisite and a
recovery command; no Sandbox starts.

### 2. Pin one official Brave installer

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Initialize-Airlock.ps1 -InstallerPath C:\path\to\BraveBrowserStandaloneSilentSetup.exe

Expected: a valid Brave publisher, exact installer version, 64-character SHA-256, and
`Networking: Disable`. A bad signature or wrong publisher stops here.

### 3. Launch once

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Start-Airlock.ps1

Expected: exactly one Sandbox window, a recorded Sandbox ID, and Brave opening inside it.
Brave is offline. Microphone, camera, clipboard, printer, vGPU, and networking are all
explicitly disabled.

### 4. Run negative controls and live acceptance

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Invoke-Increment1Acceptance.ps1 -RunLive

Expected: `INCREMENT_1_ACCEPTANCE: PASSED (live=True)`. The script first proves a weakened
audio policy and a user-profile mapping are refused, then launches, checks the result,
matches the live Sandbox ID, and stops the test guest.

### 5. Collect the first resource baseline

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Measure-Increment1.ps1 -CollectOnly

Expected: three runs in `%LOCALAPPDATA%\Airlock\evidence\increment-1-benchmark.json`, with
timestamps, failures, cold-launch seconds, peak host RAM delta, Airlock disk delta, median,
and worst measurements. Limits are not guessed; approve OQ-10 from this evidence and rerun
with all three threshold parameters.

## Increment 0 — prove the delivery gate

    python -m tests.seeded_lie_demo
    python -m unittest discover -s tests -v
    python scripts/verify_board.py

Expected: the seeded lie is rejected, all repository tests pass, and the real verifier
prints `VERIFICATION: PASSED` without claiming Increment 1 DONE.
