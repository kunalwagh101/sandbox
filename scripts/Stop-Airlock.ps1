[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 30,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Airlock.Lifecycle.ps1')

if ($env:OS -ne 'Windows_NT') {
    throw 'Airlock lifecycle control requires Windows.'
}
if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    throw 'LOCALAPPDATA is unavailable; Airlock cannot locate host-only session state.'
}

$airlockRoot = Join-Path $env:LOCALAPPDATA 'Airlock'
$statePath = Get-AirlockStatePath -AirlockRoot $airlockRoot
$result = $null
if (-not (Test-Path -LiteralPath $airlockRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    $result = [PSCustomObject]@{
        Status = 'no-active-session'
        LaunchMode = $null
        SessionKey = $null
        Stopped = $false
        Reconciled = $false
    }
}
else {
    $mutex = [Threading.Mutex]::new($false, 'Local\Airlock-Launch')
    $ownsMutex = $false
    try {
        $ownsMutex = $mutex.WaitOne(0)
        if (-not $ownsMutex) {
            throw 'An Airlock launch or stop is already in progress. Wait for it to finish before retrying.'
        }

        $state = Read-AirlockActiveSession -AirlockRoot $airlockRoot -StatePath $statePath
        if ($null -eq $state) {
            $result = [PSCustomObject]@{
                Status = 'no-active-session'
                LaunchMode = $null
                SessionKey = $null
                Stopped = $false
                Reconciled = $false
            }
        }
        elseif ($PSCmdlet.ShouldProcess(
                "Airlock session $($state.SessionKey)",
                'Stop the verified guest and remove only its owned host staging'
            )) {
            $result = Invoke-AirlockStopAndReconcile `
                -AirlockRoot $airlockRoot `
                -StatePath $statePath `
                -TimeoutSeconds $TimeoutSeconds
        }
        else {
            $result = [PSCustomObject]@{
                Status = 'planned'
                LaunchMode = $state.LaunchMode
                SessionKey = $state.SessionKey
                Stopped = $false
                Reconciled = $false
            }
        }
    }
    finally {
        if ($ownsMutex) {
            $mutex.ReleaseMutex()
        }
        $mutex.Dispose()
    }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 5
}
else {
    $result
}
