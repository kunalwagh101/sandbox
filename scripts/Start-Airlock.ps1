[CmdletBinding()]
param(
    [string]$PolicyPath,
    [switch]$PreflightOnly,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Airlock.Common.ps1')
. (Join-Path $PSScriptRoot 'Airlock.Platform.ps1')
. (Join-Path $PSScriptRoot 'Airlock.Lifecycle.ps1')

function Invoke-AirlockPreflight {
    if ($env:OS -ne 'Windows_NT') {
        throw 'Airlock requires Windows 10/11 Pro, Enterprise, or Education. This host is not Windows.'
    }

    $failures = New-Object Collections.Generic.List[string]
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $processors = @(Get-CimInstance -ClassName Win32_Processor)
    $currentVersion = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $edition = [string]$currentVersion.EditionID
    $build = 0
    if (-not [int]::TryParse([string]$currentVersion.CurrentBuildNumber, [ref]$build)) {
        $failures.Add('Windows build could not be read. Recovery: run winver and use Windows 10 22H2 build 19045 or Windows 11 24H2+.')
    }

    $architecture = if ([string]::IsNullOrWhiteSpace($env:PROCESSOR_ARCHITEW6432)) {
        [string]$env:PROCESSOR_ARCHITECTURE
    }
    else {
        [string]$env:PROCESSOR_ARCHITEW6432
    }

    $systemRoot = [string]$env:SystemRoot
    $managedPath = Join-Path $systemRoot 'System32\wsb.exe'
    $legacyPath = Join-Path $systemRoot 'System32\WindowsSandbox.exe'
    $platform = $null
    if ($build -gt 0) {
        try {
            $platform = Resolve-AirlockPlatform `
                -Caption ([string]$os.Caption) `
                -Edition $edition `
                -ProductType ([int]$os.ProductType) `
                -Build $build `
                -Architecture $architecture `
                -SystemRoot $systemRoot `
                -ManagedCliExists (Test-Path -LiteralPath $managedPath -PathType Leaf) `
                -LegacyLauncherExists (Test-Path -LiteralPath $legacyPath -PathType Leaf)
        }
        catch {
            $failures.Add($_.Exception.Message)
        }
    }

    $memoryBytes = [UInt64]$computer.TotalPhysicalMemory
    if ($memoryBytes -lt 4GB) {
        $failures.Add("Only $([Math]::Round($memoryBytes / 1GB, 1)) GB RAM is visible. Recovery: provide at least 4 GB; Microsoft recommends 8 GB.")
    }
    $logicalProcessors = [int]$computer.NumberOfLogicalProcessors
    if ($logicalProcessors -lt 2) {
        $failures.Add("Only $logicalProcessors logical processor is visible. Recovery: provide at least two CPU cores.")
    }

    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $failures.Add('LOCALAPPDATA is unavailable. Recovery: sign in with a normal local Windows user profile.')
        $airlockDriveId = [string]$env:SystemDrive
    }
    else {
        $airlockDriveId = [IO.Path]::GetPathRoot($env:LOCALAPPDATA).TrimEnd([char[]]@('\', '/'))
    }
    $airlockDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$airlockDriveId'"
    $freeBytes = if ($null -eq $airlockDrive) { 0 } else { [UInt64]$airlockDrive.FreeSpace }
    if ($null -eq $airlockDrive -or [int]$airlockDrive.DriveType -ne 3) {
        $failures.Add("Airlock storage '$airlockDriveId' is not a ready fixed local drive. Recovery: use a local Windows user profile.")
    }
    if ($freeBytes -lt 1GB) {
        $failures.Add("Only $([Math]::Round($freeBytes / 1GB, 1)) GB is free on $airlockDriveId. Recovery: free at least 1 GB before launch.")
    }

    $firmwareVirtualisation = @($processors | Where-Object {
            $_.VirtualizationFirmwareEnabled -eq $true -and
            $_.SecondLevelAddressTranslationExtensions -eq $true
        }).Count -gt 0
    $hypervisorPresent = $computer.HypervisorPresent -eq $true
    if (-not ($firmwareVirtualisation -or $hypervisorPresent)) {
        $failures.Add('Hardware virtualisation or SLAT is unavailable. Recovery: enable AMD-V/Intel VT-x and SLAT in firmware, then reboot.')
    }

    $featureState = 'Unavailable'
    try {
        $feature = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='Containers-DisposableClientVM'"
        if ($null -eq $feature) {
            $featureState = 'Absent'
        }
        else {
            $featureState = switch ([int]$feature.InstallState) {
                1 { 'Enabled' }
                2 { 'Disabled' }
                3 { 'Absent' }
                default { 'Unknown' }
            }
        }
        if ($featureState -ne 'Enabled') {
            $failures.Add("Windows Sandbox feature state is '$featureState'. Recovery (administrator PowerShell): Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All, then reboot.")
        }
    }
    catch {
        $failures.Add("Windows Sandbox feature state could not be read through Win32_OptionalFeature. Recovery: open administrator PowerShell and run Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM. Detail: $($_.Exception.Message)")
    }

    if ($failures.Count -gt 0) {
        throw "Airlock preflight failed:`n - $($failures -join "`n - ")"
    }

    return [PSCustomObject]@{
        Status = 'passed'
        Edition = $edition
        WindowsCaption = [string]$os.Caption
        WindowsVersion = [string]$currentVersion.DisplayVersion
        Build = $build
        Architecture = $architecture
        PlatformMode = [string]$platform.Mode
        LifecycleControl = [string]$platform.LifecycleControl
        LauncherPath = [string]$platform.LauncherPath
        WsbPath = $(if ($platform.Mode -eq 'managed-cli') { [string]$platform.LauncherPath } else { $null })
        LegacyLauncherPath = $(if ($platform.Mode -eq 'legacy-wsb') { [string]$platform.LauncherPath } else { $null })
        MemoryGB = [Math]::Round($memoryBytes / 1GB, 2)
        LogicalProcessors = $logicalProcessors
        FreeSystemDriveGB = [Math]::Round($freeBytes / 1GB, 2)
        HypervisorPresent = $hypervisorPresent
        FirmwareVirtualisation = $firmwareVirtualisation
        SandboxFeature = $featureState
    }
}

$preflight = Invoke-AirlockPreflight
if ($PreflightOnly) {
    if ($AsJson) { $preflight | ConvertTo-Json -Depth 5 } else { $preflight }
    return
}

if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    throw 'LOCALAPPDATA is unavailable; Airlock cannot establish its private host root.'
}
$airlockRoot = Join-Path $env:LOCALAPPDATA 'Airlock'
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $airlockRoot 'policy.lock.json'
}
$policyFile = Get-AirlockCanonicalPath -Path $PolicyPath -MustExist
if (-not (Test-AirlockPathInsideRoot -Path $policyFile -Root $airlockRoot)) {
    throw "The active policy must be under the private Airlock root: $policyFile"
}
Assert-AirlockNoReparsePoint -Path $policyFile -Root $airlockRoot

$policy = Read-AirlockJson -Path $policyFile
if ($policy.schemaVersion -ne 1 -or $policy.profileName -ne 'strict-offline') {
    throw 'Run Initialize-Airlock.ps1 to create a supported strict-offline policy lock.'
}
$installerName = [string]$policy.package.installerFileName
$provisionName = [string]$policy.guest.provisionScript
$resultName = [string]$policy.guest.resultFileName
if (
    [string]$policy.package.product -cne 'Brave Browser' -or
    [string]$policy.package.expectedPublisher -cne 'Brave Software, Inc.' -or
    $installerName -cne 'BraveBrowserStandaloneSilentSetup.exe' -or
    $provisionName -cne 'provision.ps1' -or
    $resultName -cne 'provision-result.json'
) {
    throw 'The policy lock changed a trusted Brave identity or fixed bootstrap file name.'
}
$packageHash = [string]$policy.package.expectedSha256
$provisionHash = [string]$policy.guest.provisionScriptSha256
Assert-AirlockSha256 -Value $packageHash -Name 'Installer SHA-256'
Assert-AirlockSha256 -Value $provisionHash -Name 'Provisioning script SHA-256'

$relativePackage = [string]$policy.package.packageRelativePath
if ([string]::IsNullOrWhiteSpace($relativePackage) -or [IO.Path]::IsPathRooted($relativePackage)) {
    throw 'The policy packageRelativePath must be a non-empty relative path.'
}
$packagePath = Get-AirlockCanonicalPath -Path (Join-Path $airlockRoot $relativePackage) -MustExist
if (-not (Test-AirlockPathInsideRoot -Path $packagePath -Root $airlockRoot)) {
    throw 'The pinned package path escapes the Airlock root.'
}
Assert-AirlockNoReparsePoint -Path $packagePath -Root $airlockRoot
$expectedPackagePath = Get-AirlockCanonicalPath -Path (
    Join-Path (Join-Path (Join-Path $airlockRoot 'packages') $packageHash) $installerName
)
if (-not $packagePath.Equals($expectedPackagePath, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The policy package path does not match its immutable SHA-256 location.'
}
$actualPackageHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($actualPackageHash -cne $packageHash) {
    throw 'Pinned Brave package hash mismatch. Re-run Initialize-Airlock.ps1 with a valid signed installer.'
}
$packageSignature = Get-AuthenticodeSignature -LiteralPath $packagePath
if ($packageSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "Pinned Brave package signature is no longer valid: $($packageSignature.StatusMessage)"
}
$packageSignerName = $packageSignature.SignerCertificate.GetNameInfo(
    [Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
    $false
)
if ($packageSignerName -cne 'Brave Software, Inc.') {
    throw "Pinned Brave package signer changed to '$packageSignerName'."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$provisionSource = Get-AirlockCanonicalPath -Path (Join-Path $repoRoot 'guest\provision.ps1') -MustExist
if (((Get-Item -LiteralPath $provisionSource -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw 'The provisioning source cannot be a symbolic link or another reparse point.'
}
$actualProvisionHash = (Get-FileHash -LiteralPath $provisionSource -Algorithm SHA256).Hash.ToUpperInvariant()
if ($actualProvisionHash -cne $provisionHash) {
    throw 'The provisioning script changed after initialisation. Review it, then re-run Initialize-Airlock.ps1.'
}

$mutex = [Threading.Mutex]::new($false, 'Local\Airlock-Launch')
$ownsMutex = $false
$sessionRoot = $null
$statePath = Get-AirlockStatePath -AirlockRoot $airlockRoot
$state = $null
$validatedState = $null
$launchAttempted = $false
$legacyBeforeIds = @()
try {
    $ownsMutex = $mutex.WaitOne(0)
    if (-not $ownsMutex) {
        throw 'Another Airlock launch is already in progress. Wait for it to finish before retrying.'
    }

    $recordedSession = Repair-AirlockStaleSessionState -AirlockRoot $airlockRoot
    if ($null -ne $recordedSession) {
        throw "Airlock session $($recordedSession.SessionKey) is already active. Run scripts\Stop-Airlock.ps1 and wait for confirmed teardown before retrying."
    }

    if ($preflight.PlatformMode -eq 'managed-cli') {
        $existingJson = Invoke-AirlockWsbRaw -WsbPath $preflight.LauncherPath -Arguments @('list', '--raw')
        $existingIds = @(Get-AirlockWsbIds -RawJson $existingJson -ActiveOnly)
        if ($existingIds.Count -gt 0) {
            throw "Airlock refuses to start while another Windows Sandbox is active: $($existingIds -join ', '). Stop it explicitly, then retry."
        }
    }
    else {
        $existingLegacy = @(Get-AirlockLegacySandboxProcesses -LauncherPath $preflight.LauncherPath)
        if ($existingLegacy.Count -gt 0) {
            throw "Airlock refuses to start while WindowsSandbox.exe is already active: $(@($existingLegacy | ForEach-Object { $_.ProcessId }) -join ', '). Close it, then retry."
        }
        $legacyBeforeIds = [int[]]@($existingLegacy | ForEach-Object { [int]$_.ProcessId })
    }

    $sessionKey = [Guid]::NewGuid().ToString('N')
    $sessionRoot = Join-Path (Join-Path $airlockRoot 'sessions') $sessionKey
    $bootstrapPath = Join-Path $sessionRoot 'bootstrap'
    $resultPath = Join-Path $sessionRoot 'result'
    New-Item -ItemType Directory -Path $bootstrapPath -Force | Out-Null
    New-Item -ItemType Directory -Path $resultPath -Force | Out-Null
    Assert-AirlockNoReparsePoint -Path $sessionRoot -Root $airlockRoot

    $stagedInstaller = Join-Path $bootstrapPath $installerName
    $stagedProvision = Join-Path $bootstrapPath $provisionName
    $stagedPolicy = Join-Path $bootstrapPath 'policy.lock.json'
    Copy-Item -LiteralPath $packagePath -Destination $stagedInstaller
    Copy-Item -LiteralPath $provisionSource -Destination $stagedProvision
    Copy-Item -LiteralPath $policyFile -Destination $stagedPolicy

    $stagedPackageHash = (Get-FileHash -LiteralPath $stagedInstaller -Algorithm SHA256).Hash.ToUpperInvariant()
    $stagedProvisionHash = (Get-FileHash -LiteralPath $stagedProvision -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($stagedPackageHash -cne $packageHash -or $stagedProvisionHash -cne $provisionHash) {
        throw 'A verified bootstrap file changed during per-session staging. No sandbox was started.'
    }

    $profilePath = Join-Path $sessionRoot 'Airlock.wsb'
    $profileScript = Join-Path $PSScriptRoot 'New-AirlockProfile.ps1'
    $generatedProfile = & $profileScript `
        -PolicyPath $stagedPolicy `
        -AirlockRoot $airlockRoot `
        -BootstrapPath $bootstrapPath `
        -ResultPath $resultPath `
        -OutputPath $profilePath
    if ((Get-AirlockCanonicalPath -Path $generatedProfile -MustExist) -cne (Get-AirlockCanonicalPath -Path $profilePath -MustExist)) {
        throw 'Profile generator returned an unexpected output path.'
    }
    $profileXml = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($profileXml)) {
        throw 'The generated Windows Sandbox configuration is empty.'
    }

    $launchStartedAt = [DateTime]::UtcNow
    $sessionId = $(if ($preflight.PlatformMode -eq 'managed-cli') {
            [Guid]::NewGuid().ToString('D').ToLowerInvariant()
        }
        else {
            $null
        })
    $legacyProcess = $null
    $state = [ordered]@{
        schemaVersion = 1
        sessionKey = $sessionKey
        launchMode = [string]$preflight.PlatformMode
        lifecycleControl = [string]$preflight.LifecycleControl
        launcherPath = [string]$preflight.LauncherPath
        sandboxId = $sessionId
        processId = $null
        processCreationDate = $null
        processExecutablePath = $null
        launchedAtUtc = $launchStartedAt.ToString('o')
        configPath = $profilePath
        resultPath = Join-Path $resultPath $resultName
        policySha256 = (Get-FileHash -LiteralPath $stagedPolicy -Algorithm SHA256).Hash.ToUpperInvariant()
        installerSha256 = $packageHash
        security = [ordered]@{
            networking = 'Disable'
            audioInput = 'Disable'
            videoInput = 'Disable'
            clipboardRedirection = 'Disable'
            printerRedirection = 'Disable'
            vGPU = 'Disable'
            protectedClient = 'Enable'
            bootstrapMapping = 'read-only'
            resultMapping = 'dedicated writable folder; empty at launch'
        }
    }
    if ($preflight.PlatformMode -eq 'managed-cli') {
        $validatedState = Assert-AirlockSessionState -State ([PSCustomObject]$state) -AirlockRoot $airlockRoot
        $launchAttempted = $true
        $startJson = Invoke-AirlockWsbRaw -WsbPath $preflight.LauncherPath -Arguments @(
            'start', '--id', $sessionId, '--config', $profileXml, '--raw'
        )
        $sessionId = Get-AirlockSessionIdAfterStart `
            -WsbPath $preflight.LauncherPath `
            -ExpectedId $sessionId `
            -StartJson $startJson
    }
    else {
        $profileArgument = '"' + $profilePath + '"'
        $launchAttempted = $true
        Start-Process -FilePath $preflight.LauncherPath -ArgumentList @($profileArgument) -PassThru | Out-Null
        $legacyProcess = Get-NewLegacySandboxProcess -LauncherPath $preflight.LauncherPath -BeforeProcessIds $legacyBeforeIds
        $state.processId = [int]$legacyProcess.ProcessId
        $state.processCreationDate = [string]$legacyProcess.CreationDate
        $state.processExecutablePath = [string]$legacyProcess.ExecutablePath
        $validatedState = Assert-AirlockSessionState -State ([PSCustomObject]$state) -AirlockRoot $airlockRoot
    }

    Write-AirlockJsonAtomic -Path $statePath -Value $state

    $result = [PSCustomObject]@{
        Status = 'started'
        LaunchMode = [string]$preflight.PlatformMode
        LifecycleControl = [string]$preflight.LifecycleControl
        SandboxId = $sessionId
        ProcessId = $(if ($null -ne $legacyProcess) { [int]$legacyProcess.ProcessId } else { $null })
        SessionKey = $sessionKey
        ResultPath = $state.resultPath
        StatePath = $statePath
        Networking = 'disabled'
        Message = 'Brave is provisioning inside a strict offline Windows Sandbox.'
    }
    if ($AsJson) { $result | ConvertTo-Json -Depth 5 } else { $result }
}
catch {
    $launchError = $_.Exception.Message
    $cleanupErrors = New-Object Collections.Generic.List[string]
    $cleanupPerformed = $false

    if ($launchAttempted) {
        if ($preflight.PlatformMode -eq 'legacy-wsb' -and $null -eq $validatedState) {
            try {
                $legacyProcess = Get-NewLegacySandboxProcess `
                    -LauncherPath $preflight.LauncherPath `
                    -BeforeProcessIds $legacyBeforeIds
                $state.processId = [int]$legacyProcess.ProcessId
                $state.processCreationDate = [string]$legacyProcess.CreationDate
                $state.processExecutablePath = [string]$legacyProcess.ExecutablePath
                $validatedState = Assert-AirlockSessionState `
                    -State ([PSCustomObject]$state) `
                    -AirlockRoot $airlockRoot
            }
            catch {
                $cleanupErrors.Add("Legacy session identity could not be recovered: $($_.Exception.Message)")
            }
        }

        if ($null -ne $validatedState) {
            try {
                Invoke-AirlockFailedLaunchCleanup `
                    -ValidatedState $validatedState `
                    -AirlockRoot $airlockRoot `
                    -LauncherPath $preflight.LauncherPath `
                    -StatePath $statePath
                $cleanupPerformed = $true
            }
            catch {
                $cleanupErrors.Add($_.Exception.Message)
            }
        }
        else {
            $cleanupErrors.Add('No verified session identity was available for guarded cleanup.')
        }
    }
    elseif ($null -ne $sessionRoot -and (Test-Path -LiteralPath $sessionRoot -PathType Container)) {
        try {
            Assert-AirlockNoReparsePoint -Path $sessionRoot -Root $airlockRoot
            Remove-Item -LiteralPath $sessionRoot -Recurse -Force
            $cleanupPerformed = $true
        }
        catch {
            $cleanupErrors.Add("Pre-launch staging cleanup failed: $($_.Exception.Message)")
        }
    }

    if ($cleanupErrors.Count -gt 0) {
        throw "CRITICAL: Airlock launch failed and cleanup could not be proven. Original failure: $launchError Cleanup: $($cleanupErrors -join ' | ')"
    }
    if ($cleanupPerformed) {
        throw "Airlock launch failed; its session was stopped or confirmed absent and owned staging was removed. Original failure: $launchError"
    }
    throw
}
finally {
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
