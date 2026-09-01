[CmdletBinding()]
param(
    [ValidateRange(0, 3600)][double]$MaxColdLaunchSeconds = 0,
    [ValidateRange(0, 65536)][double]$MaxPeakRamDeltaMB = 0,
    [ValidateRange(0, 102400)][double]$MaxDiskDeltaMB = 0,
    [string]$OutputPath,
    [switch]$CollectOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$startScript = Join-Path $repoRoot 'scripts\Start-Airlock.ps1'
$stopScript = Join-Path $repoRoot 'scripts\Stop-Airlock.ps1'
. (Join-Path $repoRoot 'scripts\Airlock.Common.ps1')

if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'LOCALAPPDATA is unavailable.' }
if (-not $CollectOnly -and ($MaxColdLaunchSeconds -le 0 -or $MaxPeakRamDeltaMB -le 0 -or $MaxDiskDeltaMB -le 0)) {
    throw 'Enforced mode requires all three approved limits. Use -CollectOnly for the first three-run baseline.'
}
$airlockRoot = Join-Path $env:LOCALAPPDATA 'Airlock'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path (Join-Path $airlockRoot 'evidence') 'increment-1-benchmark.json'
}
if (-not (Test-AirlockPathInsideRoot -Path $OutputPath -Root $airlockRoot)) {
    throw 'Benchmark evidence must be written under the private Airlock root.'
}

function Get-FreePhysicalMemoryMB {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    return [double]$os.FreePhysicalMemory / 1024
}

function Get-AirlockDiskMB {
    if (-not (Test-Path -LiteralPath $airlockRoot -PathType Container)) { return 0.0 }
    $sum = Get-ChildItem -LiteralPath $airlockRoot -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    if ($null -eq $sum.Sum) { return 0.0 }
    return [double]$sum.Sum / 1MB
}

function Get-Median {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][double[]]$Values)
    if ($Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) { return $sorted[$middle] }
    return ($sorted[$middle - 1] + $sorted[$middle]) / 2
}

function Stop-MeasuredLaunch {
    param([Parameter(Mandatory = $true)][object]$Launch)
    $stop = & $stopScript -TimeoutSeconds 60 -Confirm:$false
    if ($stop.Status -notin @('stopped', 'reconciled')) {
        throw "Benchmark cleanup returned unexpected status '$($stop.Status)'."
    }
    if (Test-Path -LiteralPath $Launch.StatePath) {
        throw 'Benchmark cleanup left active-session.json after confirmed stop.'
    }
    $sessionRoot = Join-Path (Join-Path $airlockRoot 'sessions') ([string]$Launch.SessionKey)
    if (Test-Path -LiteralPath $sessionRoot) {
        throw "Benchmark cleanup left owned staging for session $($Launch.SessionKey)."
    }
}

$preflight = & $startScript -PreflightOnly
$runs = New-Object Collections.Generic.List[object]

for ($index = 1; $index -le 3; $index++) {
    $launch = $null
    $stopFailed = $false
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $baselineFreeMB = Get-FreePhysicalMemoryMB
    $minimumFreeMB = $baselineFreeMB
    $baselineDiskMB = Get-AirlockDiskMB
    $record = [ordered]@{
        run = $index
        status = 'failed'
        launchMode = [string]$preflight.PlatformMode
        lifecycleControl = [string]$preflight.LifecycleControl
        startedAtUtc = [DateTime]::UtcNow.ToString('o')
        coldLaunchSeconds = $null
        idleRamDeltaMB = $null
        peakRamDeltaMB = $null
        airlockDiskDeltaMB = $null
        browserVersion = $null
        sandboxId = $null
        processId = $null
        errors = @()
        thresholdFailures = @()
        finishedAtUtc = $null
    }
    try {
        $launch = & $startScript
        $record.sandboxId = $launch.SandboxId
        $record.processId = $launch.ProcessId
        $deadline = [DateTime]::UtcNow.AddMinutes(10)
        while (-not (Test-Path -LiteralPath $launch.ResultPath -PathType Leaf)) {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Guest provisioning produced no result within ten minutes.' }
            $sampleFreeMB = Get-FreePhysicalMemoryMB
            if ($sampleFreeMB -lt $minimumFreeMB) { $minimumFreeMB = $sampleFreeMB }
            Start-Sleep -Seconds 1
        }

        if ((Get-Item -LiteralPath $launch.ResultPath).Length -gt 64KB) { throw 'Guest provisioning result exceeds 64 KB.' }
        $guest = Get-Content -LiteralPath $launch.ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($guest.status -ne 'success') { throw "Guest provisioning failed: $($guest.message)" }
        $timer.Stop()
        $sampleFreeMB = Get-FreePhysicalMemoryMB
        if ($sampleFreeMB -lt $minimumFreeMB) { $minimumFreeMB = $sampleFreeMB }
        $record.coldLaunchSeconds = [Math]::Round($timer.Elapsed.TotalSeconds, 3)
        $record.idleRamDeltaMB = [Math]::Round([Math]::Max(0, $baselineFreeMB - $sampleFreeMB), 3)
        $record.peakRamDeltaMB = [Math]::Round([Math]::Max(0, $baselineFreeMB - $minimumFreeMB), 3)
        $record.airlockDiskDeltaMB = [Math]::Round([Math]::Max(0, (Get-AirlockDiskMB) - $baselineDiskMB), 3)
        $record.browserVersion = [string]$guest.browserVersion

        if (-not $CollectOnly) {
            if ($record.coldLaunchSeconds -gt $MaxColdLaunchSeconds) { $record.thresholdFailures += "coldLaunchSeconds=$($record.coldLaunchSeconds) > $MaxColdLaunchSeconds" }
            if ($record.peakRamDeltaMB -gt $MaxPeakRamDeltaMB) { $record.thresholdFailures += "peakRamDeltaMB=$($record.peakRamDeltaMB) > $MaxPeakRamDeltaMB" }
            if ($record.airlockDiskDeltaMB -gt $MaxDiskDeltaMB) { $record.thresholdFailures += "airlockDiskDeltaMB=$($record.airlockDiskDeltaMB) > $MaxDiskDeltaMB" }
        }
        if ($record.thresholdFailures.Count -eq 0) { $record.status = $(if ($CollectOnly) { 'collected' } else { 'passed' }) }
    }
    catch {
        $timer.Stop()
        $record.errors = @($_.Exception.Message)
    }
    finally {
        $record.finishedAtUtc = [DateTime]::UtcNow.ToString('o')
        if ($null -ne $launch) {
            try { Stop-MeasuredLaunch -Launch $launch }
            catch {
                $record.errors += $_.Exception.Message
                $record.status = 'failed'
                $stopFailed = $true
            }
        }
        $runs.Add([PSCustomObject]$record)
    }
    if ($stopFailed) {
        break
    }
}

$successfulRuns = @($runs | Where-Object { $null -ne $_.coldLaunchSeconds })
$coldValues = [double[]]@($successfulRuns | ForEach-Object { $_.coldLaunchSeconds })
$idleRamValues = [double[]]@($successfulRuns | ForEach-Object { $_.idleRamDeltaMB })
$ramValues = [double[]]@($successfulRuns | ForEach-Object { $_.peakRamDeltaMB })
$diskValues = [double[]]@($successfulRuns | ForEach-Object { $_.airlockDiskDeltaMB })
$failedRuns = @($runs | Where-Object { $_.status -notin @('passed', 'collected') })
$report = [ordered]@{
    schemaVersion = 1
    measuredAtUtc = [DateTime]::UtcNow.ToString('o')
    mode = $(if ($CollectOnly) { 'collect-only' } else { 'enforced' })
    platformMode = [string]$preflight.PlatformMode
    lifecycleControl = [string]$preflight.LifecycleControl
    methodology = 'Three clean disposable Sandbox launches; host free-RAM sampling; private Airlock-root disk delta.'
    thresholds = [ordered]@{
        maxColdLaunchSeconds = $(if ($CollectOnly) { $null } else { $MaxColdLaunchSeconds })
        maxPeakRamDeltaMB = $(if ($CollectOnly) { $null } else { $MaxPeakRamDeltaMB })
        maxDiskDeltaMB = $(if ($CollectOnly) { $null } else { $MaxDiskDeltaMB })
    }
    runCount = $runs.Count
    failedRunCount = $failedRuns.Count
    aggregate = [ordered]@{
        measuredRunCount = $successfulRuns.Count
        medianColdLaunchSeconds = Get-Median -Values $coldValues
        worstColdLaunchSeconds = $(if ($coldValues.Count) { ($coldValues | Measure-Object -Maximum).Maximum } else { $null })
        medianIdleRamDeltaMB = Get-Median -Values $idleRamValues
        worstIdleRamDeltaMB = $(if ($idleRamValues.Count) { ($idleRamValues | Measure-Object -Maximum).Maximum } else { $null })
        medianPeakRamDeltaMB = Get-Median -Values $ramValues
        worstPeakRamDeltaMB = $(if ($ramValues.Count) { ($ramValues | Measure-Object -Maximum).Maximum } else { $null })
        medianDiskDeltaMB = Get-Median -Values $diskValues
        worstDiskDeltaMB = $(if ($diskValues.Count) { ($diskValues | Measure-Object -Maximum).Maximum } else { $null })
        overallStatus = $(if ($failedRuns.Count -eq 0 -and $runs.Count -eq 3) { if ($CollectOnly) { 'collected' } else { 'passed' } } else { 'failed' })
    }
    runs = @($runs)
}

Write-AirlockJsonAtomic -Path $OutputPath -Value $report
$report | ConvertTo-Json -Depth 12
if ($report.aggregate.overallStatus -eq 'failed') { exit 1 }
