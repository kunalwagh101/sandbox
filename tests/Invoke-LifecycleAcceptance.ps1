[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$lifecycleScript = Join-Path $repoRoot 'scripts\Airlock.Lifecycle.ps1'
$benchmarkScript = Join-Path $repoRoot 'tests\Measure-Increment1.ps1'
. $lifecycleScript

function Assert-Lifecycle {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-ThrowsLifecycle {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ExpectedText
    )

    $caught = $null
    try {
        & $Action
    }
    catch {
        $caught = $_
    }
    Assert-Lifecycle -Condition ($null -ne $caught) -Message "Expected '$ExpectedText', but the action succeeded."
    Assert-Lifecycle `
        -Condition ($caught.Exception.Message.IndexOf($ExpectedText, [StringComparison]::OrdinalIgnoreCase) -ge 0) `
        -Message "Expected '$ExpectedText'; received '$($caught.Exception.Message)'."
}

function New-LifecycleFixture {
    param(
        [ValidateSet('managed-cli', 'legacy-wsb')]
        [string]$LaunchMode = 'managed-cli'
    )

    $testRoot = Join-Path ([IO.Path]::GetTempPath()) (
        'airlock-lifecycle-' + [Guid]::NewGuid().ToString('N')
    )
    $localAppData = Join-Path $testRoot 'LocalAppData'
    $airlockRoot = Join-Path $localAppData 'Airlock'
    $sessionKey = [Guid]::NewGuid().ToString('N')
    $sessionRoot = Join-Path (Join-Path $airlockRoot 'sessions') $sessionKey
    $resultRoot = Join-Path $sessionRoot 'result'
    $statePath = Join-Path (Join-Path $airlockRoot 'state') 'active-session.json'
    New-Item -ItemType Directory -Path $resultRoot -Force | Out-Null
    [IO.File]::WriteAllText(
        (Join-Path $sessionRoot 'Airlock.wsb'),
        '<Configuration />',
        [Text.UTF8Encoding]::new($false)
    )

    $sandboxId = if ($LaunchMode -eq 'managed-cli') {
        [Guid]::NewGuid().ToString('D').ToLowerInvariant()
    }
    else {
        $null
    }
    $state = [ordered]@{
        schemaVersion = 1
        sessionKey = $sessionKey
        launchMode = $LaunchMode
        lifecycleControl = $(if ($LaunchMode -eq 'managed-cli') { 'managed-id' } else { 'legacy-process' })
        launcherPath = $(if ($LaunchMode -eq 'managed-cli') { 'C:\Windows\System32\wsb.exe' } else { 'C:\Windows\System32\WindowsSandbox.exe' })
        sandboxId = $sandboxId
        processId = $(if ($LaunchMode -eq 'legacy-wsb') { 4242 } else { $null })
        processCreationDate = $(if ($LaunchMode -eq 'legacy-wsb') { '20260831010101.000000+000' } else { $null })
        processExecutablePath = $(if ($LaunchMode -eq 'legacy-wsb') { 'C:\Windows\System32\WindowsSandbox.exe' } else { $null })
        launchedAtUtc = '2026-08-31T01:01:01Z'
        configPath = Join-Path $sessionRoot 'Airlock.wsb'
        resultPath = Join-Path $resultRoot 'provision-result.json'
        policySha256 = 'A' * 64
        installerSha256 = 'B' * 64
        security = [ordered]@{ networking = 'Disable' }
    }
    Write-AirlockJsonAtomic -Path $statePath -Value $state

    return [PSCustomObject]@{
        TestRoot = $testRoot
        LocalAppData = $localAppData
        AirlockRoot = $airlockRoot
        SessionKey = $sessionKey
        SessionRoot = $sessionRoot
        StatePath = $statePath
        State = [PSCustomObject]$state
        LauncherPath = [string]$state.launcherPath
    }
}

function Test-WsbIdentityParsing {
    $expectedId = '11111111-2222-3333-4444-555555555555'
    $unrelatedId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
    $raw = [ordered]@{
        sandboxes = @(
            [ordered]@{
                id = $expectedId
                status = 'Running'
                correlationId = $unrelatedId
            }
        )
    } | ConvertTo-Json -Depth 5
    $ids = @(Get-AirlockWsbIds -RawJson $raw -ActiveOnly)
    Assert-Lifecycle -Condition ($ids.Count -eq 1) -Message 'Named-field parsing returned an ambiguous number of IDs.'
    Assert-Lifecycle -Condition ($ids[0] -ceq $expectedId) -Message 'Named-field parsing did not return the exact id field.'
    Assert-Lifecycle -Condition ($ids -notcontains $unrelatedId) -Message 'A GUID in an unrelated field was scraped as session identity.'

    $stopped = [ordered]@{
        sandboxes = @([ordered]@{ id = $expectedId; status = 'Stopped' })
    } | ConvertTo-Json -Depth 5
    Assert-Lifecycle -Condition (@(Get-AirlockWsbIds -RawJson $stopped -ActiveOnly).Count -eq 0) -Message 'Stopped session was reported as active.'

    $wrongCase = [ordered]@{
        sandboxes = @([ordered]@{ Id = $expectedId; status = 'Running'; other = $unrelatedId })
    } | ConvertTo-Json -Depth 5
    Assert-ThrowsLifecycle -ExpectedText "exact 'id' field" -Action {
        Get-AirlockWsbIds -RawJson $wrongCase | Out-Null
    }

    $source = Get-Content -LiteralPath $lifecycleScript -Raw -Encoding UTF8
    $stopFunctionStart = $source.IndexOf('function Stop-AirlockSessionIdentity', [StringComparison]::Ordinal)
    $clearFunctionStart = $source.IndexOf('function Clear-AirlockSessionArtifacts', $stopFunctionStart, [StringComparison]::Ordinal)
    Assert-Lifecycle -Condition ($stopFunctionStart -ge 0 -and $clearFunctionStart -gt $stopFunctionStart) -Message 'Managed stop function boundary is missing.'
    $stopFunction = $source.Substring($stopFunctionStart, $clearFunctionStart - $stopFunctionStart)
    $namedStop = $stopFunction.IndexOf("'stop', '--id'", [StringComparison]::Ordinal)
    $statusProbe = $stopFunction.IndexOf('Test-AirlockSessionActive', [StringComparison]::Ordinal)
    Assert-Lifecycle -Condition ($namedStop -ge 0) -Message 'Managed cleanup does not issue a named stop.'
    Assert-Lifecycle -Condition ($statusProbe -gt $namedStop) -Message 'Provisional raw-status parsing can prevent the managed stop attempt.'
}

function Test-PostStartFailureCleanup {
    $fixture = New-LifecycleFixture
    $previousLocalAppData = $env:LOCALAPPDATA
    $script:postStartStopCalls = 0
    try {
        $env:LOCALAPPDATA = $fixture.LocalAppData
        $unrelated = Join-Path (Join-Path $fixture.AirlockRoot 'sessions') ('unrelated-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $unrelated -Force | Out-Null
        $validated = Assert-AirlockSessionState -State $fixture.State -AirlockRoot $fixture.AirlockRoot

        $caught = $null
        try {
            throw 'simulated post-start state publication failure'
        }
        catch {
            $original = $_.Exception.Message
            Invoke-AirlockFailedLaunchCleanup `
                -ValidatedState $validated `
                -AirlockRoot $fixture.AirlockRoot `
                -LauncherPath $fixture.LauncherPath `
                -StatePath $fixture.StatePath `
                -StopAction {
                    param($State, $Launcher)
                    $script:postStartStopCalls++
                }
            $caught = $original
        }

        Assert-Lifecycle -Condition ($caught -like '*simulated post-start*') -Message 'Original post-start failure was not preserved.'
        Assert-Lifecycle -Condition ($script:postStartStopCalls -eq 1) -Message 'Post-start cleanup did not stop exactly one named guest.'
        Assert-Lifecycle -Condition (-not (Test-Path -LiteralPath $fixture.SessionRoot)) -Message 'Post-start cleanup left owned session staging.'
        Assert-Lifecycle -Condition (-not (Test-Path -LiteralPath $fixture.StatePath)) -Message 'Post-start cleanup left active-session.json.'
        Assert-Lifecycle -Condition (Test-Path -LiteralPath $unrelated -PathType Container) -Message 'Post-start cleanup touched an unrelated session directory.'
    }
    finally {
        $env:LOCALAPPDATA = $previousLocalAppData
        if (Test-Path -LiteralPath $fixture.TestRoot) {
            Remove-Item -LiteralPath $fixture.TestRoot -Recurse -Force
        }
    }
}

function Test-StopAndStateReconciliation {
    $fixture = New-LifecycleFixture
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = $fixture.LocalAppData
        $unrelated = Join-Path (Join-Path $fixture.AirlockRoot 'sessions') ('unrelated-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $unrelated -Force | Out-Null

        $active = Repair-AirlockStaleSessionState `
            -AirlockRoot $fixture.AirlockRoot `
            -LauncherPath $fixture.LauncherPath `
            -StatePath $fixture.StatePath `
            -ActivityProbe { param($State, $Launcher) $false }
        Assert-Lifecycle -Condition ($null -eq $active) -Message 'Externally closed session was not reconciled.'
        Assert-Lifecycle -Condition (-not (Test-Path -LiteralPath $fixture.SessionRoot)) -Message 'Stale owned staging survived reconciliation.'
        Assert-Lifecycle -Condition (-not (Test-Path -LiteralPath $fixture.StatePath)) -Message 'Stale active-session.json survived reconciliation.'
        Assert-Lifecycle -Condition (Test-Path -LiteralPath $unrelated -PathType Container) -Message 'Reconciliation removed an unrelated directory.'
    }
    finally {
        $env:LOCALAPPDATA = $previousLocalAppData
        if (Test-Path -LiteralPath $fixture.TestRoot) {
            Remove-Item -LiteralPath $fixture.TestRoot -Recurse -Force
        }
    }
}

function Test-BenchmarkStopWait {
    $fixture = New-LifecycleFixture
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = $fixture.LocalAppData
        $validated = Assert-AirlockSessionState -State $fixture.State -AirlockRoot $fixture.AirlockRoot
        $script:benchmarkProbeCount = 0
        Wait-AirlockSessionStopped `
            -ValidatedState $validated `
            -LauncherPath $fixture.LauncherPath `
            -TimeoutSeconds 1 `
            -PollMilliseconds 1 `
            -ActivityProbe {
                param($State, $Launcher)
                $script:benchmarkProbeCount++
                return $script:benchmarkProbeCount -lt 3
            }
        Assert-Lifecycle -Condition ($script:benchmarkProbeCount -eq 3) -Message 'Stop wait returned before the session disappeared.'

        Assert-ThrowsLifecycle -ExpectedText 'Timed out' -Action {
            Wait-AirlockSessionStopped `
                -ValidatedState $validated `
                -LauncherPath $fixture.LauncherPath `
                -TimeoutSeconds 0.02 `
                -PollMilliseconds 1 `
                -ActivityProbe { param($State, $Launcher) $true }
        }

        $benchmark = Get-Content -LiteralPath $benchmarkScript -Raw -Encoding UTF8
        Assert-Lifecycle -Condition ($benchmark.Contains('Stop-Airlock.ps1')) -Message 'Benchmark does not use the shared confirmed-stop command.'
        Assert-Lifecycle -Condition ($benchmark.Contains('if ($stopFailed)')) -Message 'Benchmark may continue after teardown failure.'
    }
    finally {
        $env:LOCALAPPDATA = $previousLocalAppData
        if (Test-Path -LiteralPath $fixture.TestRoot) {
            Remove-Item -LiteralPath $fixture.TestRoot -Recurse -Force
        }
    }
}

$tests = @(
    'Test-WsbIdentityParsing',
    'Test-PostStartFailureCleanup',
    'Test-StopAndStateReconciliation',
    'Test-BenchmarkStopWait'
)
foreach ($test in $tests) {
    & $test
    Write-Output "PASS: $test"
}
Write-Output "LIFECYCLE_ACCEPTANCE: PASSED ($($tests.Count) tests)"
