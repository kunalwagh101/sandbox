[CmdletBinding()]
param(
    [string]$InstallerPath,
    [switch]$RunLive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$startScript = Join-Path $repoRoot 'scripts\Start-Airlock.ps1'
$stopScript = Join-Path $repoRoot 'scripts\Stop-Airlock.ps1'
$initializeScript = Join-Path $repoRoot 'scripts\Initialize-Airlock.ps1'
$profileScript = Join-Path $repoRoot 'scripts\New-AirlockProfile.ps1'
. (Join-Path $repoRoot 'scripts\Airlock.Lifecycle.ps1')
$airlockRoot = Join-Path $env:LOCALAPPDATA 'Airlock'
$policyPath = Join-Path $airlockRoot 'policy.lock.json'

function Assert-Acceptance {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Test-Preflight {
    $result = & $startScript -PreflightOnly
    Assert-Acceptance -Condition ($result.Status -eq 'passed') -Message 'Supported-host preflight did not pass.'
    Assert-Acceptance -Condition ($result.SandboxFeature -eq 'Enabled') -Message 'Preflight accepted a disabled Sandbox feature.'
    if ($result.PlatformMode -eq 'legacy-wsb') {
        Assert-Acceptance -Condition ($result.Build -eq 19045) -Message 'Legacy mode accepted a Windows 10 build other than 19045.'
        Assert-Acceptance -Condition ($result.LifecycleControl -eq 'legacy-process') -Message 'Legacy lifecycle control is mislabeled.'
        Assert-Acceptance -Condition (Test-Path -LiteralPath $result.LegacyLauncherPath -PathType Leaf) -Message 'Legacy launcher is absent.'
    }
    elseif ($result.PlatformMode -eq 'managed-cli') {
        Assert-Acceptance -Condition ($result.Build -ge 26100) -Message 'Managed CLI mode accepted a build below 26100.'
        Assert-Acceptance -Condition ($result.LifecycleControl -eq 'managed-id') -Message 'Managed lifecycle control is mislabeled.'
        Assert-Acceptance -Condition (Test-Path -LiteralPath $result.WsbPath -PathType Leaf) -Message 'Managed wsb.exe CLI is absent.'
    }
    else {
        throw "Unknown platform mode '$($result.PlatformMode)'."
    }
}

function Test-StrictProfile {
    Assert-Acceptance -Condition (Test-Path -LiteralPath $policyPath -PathType Leaf) -Message 'Initialised policy lock is missing.'
    $testRoot = Join-Path (Join-Path $airlockRoot 'sessions') ('acceptance-' + [Guid]::NewGuid().ToString('N'))
    $bootstrap = Join-Path $testRoot 'bootstrap'
    $result = Join-Path $testRoot 'result'
    New-Item -ItemType Directory -Path $bootstrap -Force | Out-Null
    New-Item -ItemType Directory -Path $result -Force | Out-Null
    Copy-Item -LiteralPath $policyPath -Destination (Join-Path $bootstrap 'policy.lock.json')
    $policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Copy-Item -LiteralPath (Join-Path $repoRoot 'guest\provision.ps1') -Destination (Join-Path $bootstrap ([string]$policy.guest.provisionScript))
    $packagePath = Join-Path $airlockRoot ([string]$policy.package.packageRelativePath)
    Copy-Item -LiteralPath $packagePath -Destination (Join-Path $bootstrap ([string]$policy.package.installerFileName))

    $profilePath = Join-Path $testRoot 'acceptance.wsb'
    & $profileScript -PolicyPath (Join-Path $bootstrap 'policy.lock.json') -AirlockRoot $airlockRoot -BootstrapPath $bootstrap -ResultPath $result -OutputPath $profilePath | Out-Null
    [xml]$xml = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
    Assert-Acceptance -Condition ($xml.Configuration.Networking -eq 'Disable') -Message 'Networking is not disabled.'
    Assert-Acceptance -Condition ($xml.Configuration.AudioInput -eq 'Disable') -Message 'Audio input is not disabled.'
    Assert-Acceptance -Condition ($xml.Configuration.VideoInput -eq 'Disable') -Message 'Video input is not disabled.'
    Assert-Acceptance -Condition ($xml.Configuration.ClipboardRedirection -eq 'Disable') -Message 'Clipboard is not disabled.'
    Assert-Acceptance -Condition ($xml.Configuration.PrinterRedirection -eq 'Disable') -Message 'Printer redirection is not disabled.'
    Assert-Acceptance -Condition ($xml.Configuration.vGPU -eq 'Disable') -Message 'vGPU is not disabled.'
    Assert-Acceptance -Condition ($xml.Configuration.ProtectedClient -eq 'Enable') -Message 'ProtectedClient is not enabled.'
    Assert-Acceptance -Condition ($xml.Configuration.MappedFolders.MappedFolder.Count -eq 2) -Message 'Unexpected mapping count.'
    Assert-Acceptance -Condition ($xml.Configuration.MappedFolders.MappedFolder[0].ReadOnly -eq 'true') -Message 'Bootstrap mapping is writable.'
    Assert-Acceptance -Condition ($xml.Configuration.MappedFolders.MappedFolder[1].ReadOnly -eq 'false') -Message 'Result mapping is not explicit.'

    $weakenedPath = Join-Path $testRoot 'weakened.json'
    $policy.sandbox.audioInput = 'Enable'
    [IO.File]::WriteAllText($weakenedPath, ($policy | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    $weakMessage = $null
    try {
        & $profileScript -PolicyPath $weakenedPath -AirlockRoot $airlockRoot -BootstrapPath $bootstrap -ResultPath $result -OutputPath (Join-Path $testRoot 'weak.wsb') | Out-Null
    }
    catch { $weakMessage = $_.Exception.Message }
    Assert-Acceptance `
        -Condition ($null -ne $weakMessage -and $weakMessage -like '*Strict policy requires sandbox.audioInput=Disable*') `
        -Message "Audio weakening failed for the wrong reason: '$weakMessage'."

    $unsafeMessage = $null
    try {
        & $profileScript -PolicyPath (Join-Path $bootstrap 'policy.lock.json') -AirlockRoot $airlockRoot -BootstrapPath $env:USERPROFILE -ResultPath $result -OutputPath (Join-Path $testRoot 'unsafe.wsb') | Out-Null
    }
    catch { $unsafeMessage = $_.Exception.Message }
    Assert-Acceptance `
        -Condition ($null -ne $unsafeMessage -and $unsafeMessage -like '*mapping must be a child of the Airlock root*') `
        -Message "Broad mapping failed for the wrong reason: '$unsafeMessage'."
}

function Assert-LegacyProcessIdentity {
    param(
        [Parameter(Mandatory = $true)][object]$State
    )
    Assert-Acceptance -Condition ($State.lifecycleControl -eq 'legacy-process') -Message 'State does not label legacy lifecycle control.'
    Assert-Acceptance -Condition ([string]::IsNullOrWhiteSpace([string]$State.sandboxId)) -Message 'Legacy state invented a Sandbox ID.'
    Assert-Acceptance -Condition ([int]$State.processId -gt 0) -Message 'Legacy state has no process ID.'
    $process = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$([int]$State.processId)" -ErrorAction SilentlyContinue
    Assert-Acceptance -Condition ($null -ne $process) -Message 'Recorded legacy Sandbox process is not running.'
    Assert-Acceptance `
        -Condition ([string]$process.ExecutablePath -and [IO.Path]::GetFullPath([string]$process.ExecutablePath).Equals([IO.Path]::GetFullPath([string]$State.processExecutablePath), [StringComparison]::OrdinalIgnoreCase)) `
        -Message 'Legacy Sandbox executable path no longer matches state.'
    Assert-Acceptance -Condition ([string]$process.CreationDate -ceq [string]$State.processCreationDate) -Message 'Legacy Sandbox process creation identity no longer matches state.'
    return $process
}

function Test-LiveLaunch {
    $launch = & $startScript
    Assert-Acceptance -Condition ($launch.Status -eq 'started') -Message 'Airlock did not report a started sandbox.'
    $state = $null
    $validatedState = $null
    try {
        if ($launch.LaunchMode -eq 'managed-cli') {
            Assert-Acceptance -Condition (-not [string]::IsNullOrWhiteSpace([string]$launch.SandboxId)) -Message 'Managed launch recorded no Sandbox ID.'
        }
        elseif ($launch.LaunchMode -eq 'legacy-wsb') {
            Assert-Acceptance -Condition ([string]::IsNullOrWhiteSpace([string]$launch.SandboxId)) -Message 'Legacy launch falsely recorded a Sandbox ID.'
            Assert-Acceptance -Condition ([int]$launch.ProcessId -gt 0) -Message 'Legacy launch recorded no process ID.'
        }
        else {
            throw "Unknown launch mode '$($launch.LaunchMode)'."
        }

        $deadline = [DateTime]::UtcNow.AddMinutes(5)
        while ([DateTime]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $launch.ResultPath -PathType Leaf)) {
            Start-Sleep -Seconds 1
        }
        Assert-Acceptance -Condition (Test-Path -LiteralPath $launch.ResultPath -PathType Leaf) -Message 'Guest provisioning produced no result within five minutes.'
        Assert-Acceptance -Condition ((Get-Item -LiteralPath $launch.ResultPath).Length -le 64KB) -Message 'Guest provisioning result exceeds 64 KB.'
        $result = Get-Content -LiteralPath $launch.ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Acceptance -Condition ($result.status -eq 'success') -Message "Guest provisioning failed: $($result.message)"
        Assert-Acceptance -Condition (-not [string]::IsNullOrWhiteSpace([string]$result.browserVersion)) -Message 'Brave exact version is absent.'
        Assert-Acceptance -Condition ([string]$result.installerSha256 -match '^[A-F0-9]{64}$') -Message 'Guest did not report the pinned installer hash.'
        Assert-Acceptance -Condition ($result.networking -eq 'Disable') -Message 'Guest contract did not retain disabled networking.'

        $state = Get-Content -LiteralPath $launch.StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Acceptance -Condition ($state.launchMode -eq $launch.LaunchMode) -Message 'Launch mode differs between result and state.'
        $validatedState = Assert-AirlockSessionState -State $state -AirlockRoot $airlockRoot
        $launcher = Get-AirlockLauncherPathForState -ValidatedState $validatedState
        Assert-Acceptance `
            -Condition (Test-AirlockSessionActive -ValidatedState $validatedState -LauncherPath $launcher) `
            -Message 'Recorded Airlock session is not active after launch.'
        if ($launch.LaunchMode -eq 'managed-cli') {
            Assert-Acceptance -Condition ($validatedState.SandboxId -ceq [string]$launch.SandboxId) -Message 'Managed Sandbox ID differs between launch and validated state.'
        }
        else {
            $null = Assert-LegacyProcessIdentity -State $state
        }
    }
    finally {
        $stop = & $stopScript -TimeoutSeconds 60 -Confirm:$false
        Assert-Acceptance -Condition ($stop.Status -in @('stopped', 'reconciled')) -Message "Acceptance cleanup returned '$($stop.Status)'."
        Assert-Acceptance -Condition (-not (Test-Path -LiteralPath $launch.StatePath)) -Message 'Acceptance cleanup left active-session.json.'
        $ownedSession = Join-Path (Join-Path $airlockRoot 'sessions') ([string]$launch.SessionKey)
        Assert-Acceptance -Condition (-not (Test-Path -LiteralPath $ownedSession)) -Message 'Acceptance cleanup left owned session staging.'
    }
}

if (-not [string]::IsNullOrWhiteSpace($InstallerPath)) {
    & $initializeScript -InstallerPath $InstallerPath -Force | Out-Host
}

Test-Preflight
Test-StrictProfile
if ($RunLive) { Test-LiveLaunch }

Write-Output "INCREMENT_1_ACCEPTANCE: PASSED (live=$RunLive)"
