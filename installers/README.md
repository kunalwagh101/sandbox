# Brave installer input

Airlock does not commit or silently download third-party executable files. Download the
current **Brave Browser standalone silent installer** from Brave's official release page,
then pin that exact signed file once:

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File scripts\Initialize-Airlock.ps1 -InstallerPath C:\path\to\BraveBrowserStandaloneSilentSetup.exe

Initialisation verifies the Windows Authenticode signature and expected Brave publisher,
copies the file to `%LOCALAPPDATA%\Airlock\packages\<sha256>`, and creates
`%LOCALAPPDATA%\Airlock\policy.lock.json` with its exact SHA-256 and version. Launch checks
the hash again before and after staging. The guest repeats both hash and signature checks
before execution.

The installer is never mapped from this repository or from Downloads. Only the freshly
copied, hash-verified per-session bootstrap directory is mapped, and it is read-only.
