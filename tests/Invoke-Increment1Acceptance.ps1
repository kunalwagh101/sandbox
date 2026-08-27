[CmdletBinding()]
param(
    [string]$InstallerPath,

    [switch]$RunLive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$startScript = Join-Path $repoRoot 'scripts\Start-Airlock.ps1'
$initializeScript = Join-Path $repoRoot 'scripts\Initialize-Airlock.ps1'
$profileScript = Join-Path $repoRoot 'scripts\New-AirlockProfile.ps1'
$airlockRoot = Join-Path $env:LOCALAPPDATA 'Airlock'
$policyPath = Join-Path $airlockRoot 'policy.lock.json'

function Assert-Acceptance {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Test-Preflight {
    $result = & $startScript -PreflightOnly
    Assert-Acceptance -Condition ($result.Status -eq 'passed') -Message 'Supported-host preflight did not pass.'
    Assert-Acceptance -Condition ($result.Build -ge 26100) -Message 'Preflight accepted a build below 26100.'
    Assert-Acceptance -Condition ($result.SandboxFeature -eq 'Enabled') -Message 'Preflight accepted a disabled Sandbox feature.'
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
    $weakFailed = $false
    try {
        & $profileScript -PolicyPath $weakenedPath -AirlockRoot $airlockRoot -BootstrapPath $bootstrap -ResultPath $result -OutputPath (Join-Path $testRoot 'weak.wsb') | Out-Null
    }
    catch {
        $weakFailed = $true
    }
    Assert-Acceptance -Condition $weakFailed -Message 'Profile generator accepted AudioInput=Enable.'

    $unsafeFailed = $false
    try {
        & $profileScript -PolicyPath (Join-Path $bootstrap 'policy.lock.json') -AirlockRoot $airlockRoot -BootstrapPath $env:USERPROFILE -ResultPath $result -OutputPath (Join-Path $testRoot 'unsafe.wsb') | Out-Null
    }
    catch {
        $unsafeFailed = $true
    }
    Assert-Acceptance -Condition $unsafeFailed -Message 'Profile generator accepted the user profile as a mapping.'
}

function Test-LiveLaunch {
    $launch = & $startScript
    Assert-Acceptance -Condition ($launch.Status -eq 'started') -Message 'Airlock did not report a started sandbox.'
    Assert-Acceptance -Condition (-not [string]::IsNullOrWhiteSpace([string]$launch.SandboxId)) -Message 'No Sandbox ID was recorded.'
    $result = $null
    try {
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

        $raw = (& (Join-Path $env:SystemRoot 'System32\wsb.exe') list --raw 2>&1 | Out-String)
        $runningStatuses = [regex]::Matches($raw, '(?i)"(?:status|state)"\s*:\s*"running"')
        Assert-Acceptance -Condition ($runningStatuses.Count -eq 1) -Message 'Exactly one running Windows Sandbox was not observed.'
        Assert-Acceptance -Condition ($raw.IndexOf([string]$launch.SandboxId, [StringComparison]::OrdinalIgnoreCase) -ge 0) -Message 'Recorded Sandbox ID is absent from the runtime list.'
    }
    finally {
        $stopOutput = @(& (Join-Path $env:SystemRoot 'System32\wsb.exe') stop --id $launch.SandboxId --raw 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Acceptance cleanup could not stop Sandbox $($launch.SandboxId): $(($stopOutput | Out-String).Trim())"
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($InstallerPath)) {
    & $initializeScript -InstallerPath $InstallerPath -Force | Out-Host
}

Test-Preflight
Test-StrictProfile
if ($RunLive) {
    Test-LiveLaunch
}

Write-Output "INCREMENT_1_ACCEPTANCE: PASSED (live=$RunLive)"
