[CmdletBinding()]
param(
    [string]$PolicyPath,

    [switch]$PreflightOnly,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Airlock.Common.ps1')

function Invoke-AirlockPreflight {
    if ($env:OS -ne 'Windows_NT') {
        throw 'Airlock requires Windows 11 Pro, Enterprise, or Education. This host is not Windows.'
    }

    $failures = New-Object Collections.Generic.List[string]
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $processors = @(Get-CimInstance -ClassName Win32_Processor)
    $currentVersion = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $edition = [string]$currentVersion.EditionID
    $build = 0
    if (-not [int]::TryParse([string]$currentVersion.CurrentBuildNumber, [ref]$build)) {
        $failures.Add('Windows build could not be read. Recovery: run winver and install Windows 11 24H2 or newer.')
    }

    $supportedEdition = $edition -match '^(Professional|Enterprise|Education)'
    if (-not $supportedEdition -or [int]$os.ProductType -ne 1 -or [string]$os.Caption -notmatch 'Windows 11') {
        $failures.Add("Unsupported Windows edition '$edition'. Recovery: use Windows 11 Pro, Enterprise, or Education; Home and Server are not supported.")
    }
    if ($build -lt 26100) {
        $failures.Add("Windows build $build is below 26100. Recovery: install Windows 11 24H2 or newer so wsb.exe is available.")
    }

    $architecture = if ([string]::IsNullOrWhiteSpace($env:PROCESSOR_ARCHITEW6432)) {
        [string]$env:PROCESSOR_ARCHITECTURE
    }
    else {
        [string]$env:PROCESSOR_ARCHITEW6432
    }
    if ($architecture -notin @('AMD64', 'ARM64')) {
        $failures.Add("Unsupported architecture '$architecture'. Recovery: use an AMD64 or ARM64 Windows host.")
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
        $featureState = switch ([int]$feature.InstallState) {
            1 { 'Enabled' }
            2 { 'Disabled' }
            3 { 'Absent' }
            default { 'Unknown' }
        }
        if ($featureState -ne 'Enabled') {
            $failures.Add("Windows Sandbox feature state is '$featureState'. Recovery (administrator PowerShell): Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All, then reboot.")
        }
    }
    catch {
        $failures.Add("Windows Sandbox feature state could not be read through Win32_OptionalFeature. Recovery: open administrator PowerShell and run Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM. Detail: $($_.Exception.Message)")
    }

    $wsbPath = Join-Path $env:SystemRoot 'System32\wsb.exe'
    if (-not (Test-Path -LiteralPath $wsbPath -PathType Leaf)) {
        $failures.Add("Windows Sandbox CLI is missing at $wsbPath. Recovery: update to Windows 11 24H2+ and enable Windows Sandbox.")
    }

    if ($failures.Count -gt 0) {
        throw "Airlock preflight failed:`n - $($failures -join "`n - ")"
    }

    return [PSCustomObject]@{
        Status = 'passed'
        Edition = $edition
        WindowsVersion = [string]$currentVersion.DisplayVersion
        Build = $build
        Architecture = $architecture
        MemoryGB = [Math]::Round($memoryBytes / 1GB, 2)
        LogicalProcessors = $logicalProcessors
        FreeSystemDriveGB = [Math]::Round($freeBytes / 1GB, 2)
        HypervisorPresent = $hypervisorPresent
        FirmwareVirtualisation = $firmwareVirtualisation
        SandboxFeature = $featureState
        WsbPath = $wsbPath
    }
}

function Invoke-WsbRaw {
    param(
        [Parameter(Mandatory = $true)][string]$WsbPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = @(& $WsbPath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    if ($exitCode -ne 0) {
        throw "wsb.exe $($Arguments[0]) failed with exit code $exitCode. $text"
    }
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        try {
            $null = $text | ConvertFrom-Json
        }
        catch {
            throw "wsb.exe $($Arguments[0]) did not return valid --raw JSON: $text"
        }
    }
    return $text
}

function Get-WsbIds {
    param(
        [AllowEmptyString()][string]$RawJson,
        [switch]$ActiveOnly
    )

    if ([string]::IsNullOrWhiteSpace($RawJson)) {
        return @()
    }
    $guidPattern = '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
    $parsed = $RawJson | ConvertFrom-Json
    if ($null -eq $parsed) {
        return @()
    }
    $containerProperty = $parsed.PSObject.Properties | Where-Object {
        $_.Name -in @('sandboxes', 'Sandboxes', 'sessions', 'Sessions', 'value', 'Value')
    } | Select-Object -First 1
    if ($null -ne $containerProperty) {
        $candidates = @($containerProperty.Value)
    }
    elseif ($parsed -is [Collections.IEnumerable] -and $parsed -isnot [string]) {
        $candidates = @($parsed)
    }
    else {
        $candidates = @($parsed)
    }

    $ids = New-Object Collections.Generic.List[string]
    foreach ($candidate in $candidates) {
        $candidateJson = $candidate | ConvertTo-Json -Depth 8 -Compress
        $candidateIds = @([regex]::Matches($candidateJson, $guidPattern) | ForEach-Object {
                $_.Value.ToLowerInvariant()
            } | Select-Object -Unique)
        if ($candidateIds.Count -eq 0) {
            continue
        }
        $statusProperty = $candidate.PSObject.Properties | Where-Object {
            $_.Name -in @('status', 'Status', 'state', 'State')
        } | Select-Object -First 1
        $status = if ($null -eq $statusProperty) { 'unknown' } else { [string]$statusProperty.Value }
        if ($ActiveOnly -and $status -match '^(?i:stopped|closed|terminated)$') {
            continue
        }
        foreach ($id in $candidateIds) {
            if (-not $ids.Contains($id)) {
                $ids.Add($id)
            }
        }
    }

    if ($ids.Count -eq 0 -and -not $ActiveOnly) {
        return @([regex]::Matches($RawJson, $guidPattern) | ForEach-Object {
                $_.Value.ToLowerInvariant()
            } | Select-Object -Unique)
    }
    return @($ids)
}

function Get-AirlockSessionIdAfterStart {
    param(
        [Parameter(Mandatory = $true)][string]$WsbPath,
        [AllowEmptyString()][string]$StartJson
    )

    $ids = @(Get-WsbIds -RawJson $StartJson)
    if ($ids.Count -eq 1) {
        return $ids[0]
    }
    if ($ids.Count -gt 1) {
        throw 'wsb.exe start returned more than one sandbox identifier.'
    }

    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 250
        $listJson = Invoke-WsbRaw -WsbPath $WsbPath -Arguments @('list', '--raw')
        $ids = @(Get-WsbIds -RawJson $listJson -ActiveOnly)
        if ($ids.Count -eq 1) {
            return $ids[0]
        }
        if ($ids.Count -gt 1) {
            throw 'More than one Windows Sandbox appeared after Airlock launch.'
        }
    }
    throw 'Windows Sandbox started without a resolvable session identifier. Run wsb list --raw before retrying.'
}

$preflight = Invoke-AirlockPreflight
if ($PreflightOnly) {
    if ($AsJson) {
        $preflight | ConvertTo-Json -Depth 5
    }
    else {
        $preflight
    }
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
    throw "Pinned Brave package hash mismatch. Re-run Initialize-Airlock.ps1 with a valid signed installer."
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
try {
    $ownsMutex = $mutex.WaitOne(0)
    if (-not $ownsMutex) {
        throw 'Another Airlock launch is already in progress. Wait for it to finish before retrying.'
    }

    $existingJson = Invoke-WsbRaw -WsbPath $preflight.WsbPath -Arguments @('list', '--raw')
    $existingIds = @(Get-WsbIds -RawJson $existingJson -ActiveOnly)
    if ($existingIds.Count -gt 0) {
        throw "Airlock refuses to start while another Windows Sandbox is active: $($existingIds -join ', '). Stop it explicitly, then retry."
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
    $startJson = Invoke-WsbRaw -WsbPath $preflight.WsbPath -Arguments @(
        'start', '--config', $profileXml, '--raw'
    )
    $sessionId = Get-AirlockSessionIdAfterStart -WsbPath $preflight.WsbPath -StartJson $startJson

    $statePath = Join-Path (Join-Path $airlockRoot 'state') 'active-session.json'
    $state = [ordered]@{
        schemaVersion = 1
        sessionKey = $sessionKey
        sandboxId = $sessionId
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
    try {
        Write-AirlockJsonAtomic -Path $statePath -Value $state
    }
    catch {
        $stateError = $_.Exception.Message
        $stopOutput = @(& $preflight.WsbPath stop --id $sessionId --raw 2>&1)
        if ($LASTEXITCODE -eq 0) {
            throw "Airlock stopped the unrecorded Sandbox because session state could not be saved: $stateError"
        }
        throw "CRITICAL: Airlock could not record or stop Sandbox $sessionId. Run 'wsb stop --id $sessionId' now. State error: $stateError. Stop output: $(($stopOutput | Out-String).Trim())"
    }

    $result = [PSCustomObject]@{
        Status = 'started'
        SandboxId = $sessionId
        SessionKey = $sessionKey
        ResultPath = $state.resultPath
        StatePath = $statePath
        Networking = 'disabled'
        Message = 'Brave is provisioning inside a strict offline Windows Sandbox.'
    }
    if ($AsJson) {
        $result | ConvertTo-Json -Depth 5
    }
    else {
        $result
    }
}
finally {
    if ($ownsMutex) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}
