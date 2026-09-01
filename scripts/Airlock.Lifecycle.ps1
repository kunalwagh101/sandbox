Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'Airlock.Common.ps1')
. (Join-Path $PSScriptRoot 'Airlock.Platform.ps1')

$script:AirlockWsbIdField = 'id'
$script:AirlockWsbContainerField = 'sandboxes'
$script:AirlockWsbStatusField = 'status'

function Get-AirlockTextFingerprint {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Text)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $algorithm.ComputeHash($bytes)
    }
    finally {
        $algorithm.Dispose()
    }
    $hex = ($digest | ForEach-Object { $_.ToString('x2') }) -join ''
    return "length=$($bytes.Length),sha256=$hex"
}

function Invoke-AirlockWsbRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$WsbPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $stderrPath = Join-Path ([IO.Path]::GetTempPath()) (
        'airlock-wsb-' + [Guid]::NewGuid().ToString('N') + '.stderr'
    )
    try {
        $stdout = @(& $WsbPath @Arguments 2> $stderrPath)
        $exitCode = $LASTEXITCODE
        $stdoutText = ($stdout | Out-String).Trim()
        $stderrText = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
            [IO.File]::ReadAllText($stderrPath).Trim()
        }
        else {
            ''
        }

        $diagnostic = "stdout($(Get-AirlockTextFingerprint -Text $stdoutText)); stderr($(Get-AirlockTextFingerprint -Text $stderrText))"
        if ($exitCode -ne 0) {
            throw "wsb.exe $($Arguments[0]) failed with exit code $exitCode; $diagnostic. Run the same command manually to inspect its local output."
        }
        if (-not [string]::IsNullOrWhiteSpace($stdoutText)) {
            try {
                $null = $stdoutText | ConvertFrom-Json
            }
            catch {
                throw "wsb.exe $($Arguments[0]) did not return valid --raw JSON; $diagnostic."
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
            Write-Verbose "wsb.exe $($Arguments[0]) wrote a separate stderr diagnostic: $(Get-AirlockTextFingerprint -Text $stderrText)"
        }
        return $stdoutText
    }
    finally {
        if (Test-Path -LiteralPath $stderrPath) {
            Remove-Item -LiteralPath $stderrPath -Force
        }
    }
}

function ConvertFrom-AirlockWsbRaw {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$RawJson
    )

    if ([string]::IsNullOrWhiteSpace($RawJson)) {
        return @()
    }
    try {
        $parsed = $RawJson | ConvertFrom-Json
    }
    catch {
        throw "Windows Sandbox raw output is not valid JSON: $($_.Exception.Message)"
    }
    if ($null -eq $parsed) {
        return @()
    }

    if ($parsed -is [Array]) {
        $records = @($parsed)
    }
    else {
        $containerProperties = @($parsed.PSObject.Properties | Where-Object {
                $_.Name -ceq $script:AirlockWsbContainerField
            })
        $idProperties = @($parsed.PSObject.Properties | Where-Object {
                $_.Name -ceq $script:AirlockWsbIdField
            })
        if ($containerProperties.Count -eq 1 -and $idProperties.Count -eq 0) {
            $records = @($containerProperties[0].Value)
        }
        elseif ($containerProperties.Count -eq 0 -and $idProperties.Count -eq 1) {
            $records = @($parsed)
        }
        else {
            $fieldNames = @($parsed.PSObject.Properties | ForEach-Object { $_.Name })
            throw "Unsupported Windows Sandbox JSON contract. Expected exact '$($script:AirlockWsbIdField)' records or an exact '$($script:AirlockWsbContainerField)' container; received fields [$($fieldNames -join ', ')]."
        }
    }

    $result = New-Object Collections.Generic.List[object]
    foreach ($record in $records) {
        if ($null -eq $record) {
            throw 'Windows Sandbox JSON contains a null session record.'
        }
        $idProperties = @($record.PSObject.Properties | Where-Object {
                $_.Name -ceq $script:AirlockWsbIdField
            })
        if ($idProperties.Count -ne 1) {
            $fieldNames = @($record.PSObject.Properties | ForEach-Object { $_.Name })
            throw "Windows Sandbox session record has no single exact '$($script:AirlockWsbIdField)' field; received fields [$($fieldNames -join ', ')]."
        }
        $idText = [string]$idProperties[0].Value
        $id = [Guid]::Empty
        if (-not [Guid]::TryParseExact($idText, 'D', [ref]$id)) {
            throw "Windows Sandbox '$($script:AirlockWsbIdField)' is not a canonical GUID."
        }

        $statusProperties = @($record.PSObject.Properties | Where-Object {
                $_.Name -ceq $script:AirlockWsbStatusField
            })
        if ($statusProperties.Count -gt 1) {
            throw "Windows Sandbox session record contains duplicate '$($script:AirlockWsbStatusField)' fields."
        }
        $status = if ($statusProperties.Count -eq 1) {
            [string]$statusProperties[0].Value
        }
        else {
            'unknown'
        }
        $result.Add([PSCustomObject]@{
                Id = $id.ToString('D').ToLowerInvariant()
                Status = $status
            })
    }
    return $result.ToArray()
}

function Get-AirlockWsbIds {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$RawJson,
        [switch]$ActiveOnly
    )

    $ids = New-Object Collections.Generic.List[string]
    foreach ($record in @(ConvertFrom-AirlockWsbRaw -RawJson $RawJson)) {
        $status = ([string]$record.Status).ToLowerInvariant()
        if ($ActiveOnly -and $status -in @('stopped', 'closed', 'terminated')) {
            continue
        }
        if (-not $ids.Contains([string]$record.Id)) {
            $ids.Add([string]$record.Id)
        }
    }
    return $ids.ToArray()
}

function Get-AirlockSessionIdAfterStart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$WsbPath,
        [Parameter(Mandatory = $true)][string]$ExpectedId,
        [AllowEmptyString()][string]$StartJson
    )

    $expected = [Guid]::Empty
    if (-not [Guid]::TryParseExact($ExpectedId, 'D', [ref]$expected)) {
        throw 'The requested Windows Sandbox ID is not a canonical GUID.'
    }
    $expectedText = $expected.ToString('D').ToLowerInvariant()

    if (-not [string]::IsNullOrWhiteSpace($StartJson)) {
        $startIds = @(Get-AirlockWsbIds -RawJson $StartJson)
        if ($startIds.Count -gt 0 -and ($startIds.Count -ne 1 -or $startIds[0] -cne $expectedText)) {
            throw "wsb.exe start returned an ID other than the requested Airlock ID $expectedText."
        }
    }

    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        $listJson = Invoke-AirlockWsbRaw -WsbPath $WsbPath -Arguments @('list', '--raw')
        $activeIds = @(Get-AirlockWsbIds -RawJson $listJson -ActiveOnly)
        if ($activeIds -contains $expectedText) {
            return $expectedText
        }
        if ($activeIds.Count -gt 0) {
            throw "A Windows Sandbox other than requested Airlock ID $expectedText appeared after launch: $($activeIds -join ', ')."
        }
        Start-Sleep -Milliseconds 250
    }
    throw "Windows Sandbox did not expose requested Airlock ID $expectedText within ten seconds."
}

function Get-NewLegacySandboxProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][int[]]$BeforeProcessIds
    )

    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        $candidates = @(Get-AirlockLegacySandboxProcesses -LauncherPath $LauncherPath | Where-Object {
                [int]$_.ProcessId -notin $BeforeProcessIds
            })
        if ($candidates.Count -eq 1) {
            return $candidates[0]
        }
        if ($candidates.Count -gt 1) {
            throw "More than one new WindowsSandbox.exe process appeared: $(@($candidates | ForEach-Object { $_.ProcessId }) -join ', ')."
        }
        Start-Sleep -Milliseconds 250
    }
    throw 'Windows Sandbox launcher returned without one new verifiable WindowsSandbox.exe process.'
}

function Get-AirlockStateProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$AllowEmpty
    )

    $properties = @($State.PSObject.Properties | Where-Object { $_.Name -ceq $Name })
    if ($properties.Count -ne 1) {
        throw "Airlock session state must contain one exact '$Name' field."
    }
    $value = $properties[0].Value
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace([string]$value)) {
        throw "Airlock session state field '$Name' is empty."
    }
    return $value
}

function Assert-AirlockSessionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$AirlockRoot
    )

    $root = Assert-AirlockPrivateRoot -Root $AirlockRoot
    if ([int](Get-AirlockStateProperty -State $State -Name 'schemaVersion') -ne 1) {
        throw 'Airlock session state has an unsupported schema version.'
    }
    $sessionKey = [string](Get-AirlockStateProperty -State $State -Name 'sessionKey')
    if ($sessionKey -cnotmatch '^[a-f0-9]{32}$') {
        throw 'Airlock sessionKey must be 32 lowercase hexadecimal characters.'
    }
    $launchMode = [string](Get-AirlockStateProperty -State $State -Name 'launchMode')
    if ($launchMode -notin @('managed-cli', 'legacy-wsb')) {
        throw "Unsupported Airlock launchMode '$launchMode'."
    }

    $sessionRoot = Get-AirlockCanonicalPath -Path (
        Join-Path (Join-Path $root 'sessions') $sessionKey
    )
    if (-not (Test-AirlockPathInsideRoot -Path $sessionRoot -Root $root)) {
        throw 'Airlock session directory escaped the private root.'
    }
    $configPath = Get-AirlockCanonicalPath -Path (
        [string](Get-AirlockStateProperty -State $State -Name 'configPath')
    )
    $expectedConfig = Get-AirlockCanonicalPath -Path (Join-Path $sessionRoot 'Airlock.wsb')
    if (-not $configPath.Equals($expectedConfig, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Airlock state configPath does not identify its owned session profile.'
    }
    $resultPath = Get-AirlockCanonicalPath -Path (
        [string](Get-AirlockStateProperty -State $State -Name 'resultPath')
    )
    $expectedResultRoot = Get-AirlockCanonicalPath -Path (Join-Path $sessionRoot 'result')
    if (-not (Test-AirlockPathInsideRoot -Path $resultPath -Root $expectedResultRoot)) {
        throw 'Airlock state resultPath does not identify its owned result directory.'
    }

    $sandboxId = [string](Get-AirlockStateProperty -State $State -Name 'sandboxId' -AllowEmpty)
    $processIdValue = Get-AirlockStateProperty -State $State -Name 'processId' -AllowEmpty
    $processCreationDate = [string](Get-AirlockStateProperty -State $State -Name 'processCreationDate' -AllowEmpty)
    $processExecutablePath = [string](Get-AirlockStateProperty -State $State -Name 'processExecutablePath' -AllowEmpty)
    if ($launchMode -eq 'managed-cli') {
        $parsedId = [Guid]::Empty
        if (-not [Guid]::TryParseExact($sandboxId, 'D', [ref]$parsedId)) {
            throw 'Managed Airlock state contains no canonical sandboxId.'
        }
        if ($null -ne $processIdValue -and -not [string]::IsNullOrWhiteSpace([string]$processIdValue)) {
            throw 'Managed Airlock state must not contain a legacy processId.'
        }
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($sandboxId)) {
            throw 'Legacy Airlock state must not claim a managed sandboxId.'
        }
        $processId = 0
        if (-not [int]::TryParse([string]$processIdValue, [ref]$processId) -or $processId -le 0) {
            throw 'Legacy Airlock state contains no valid processId.'
        }
        if ([string]::IsNullOrWhiteSpace($processCreationDate) -or [string]::IsNullOrWhiteSpace($processExecutablePath)) {
            throw 'Legacy Airlock state is missing its guarded process identity.'
        }
    }

    return [PSCustomObject]@{
        State = $State
        SessionKey = $sessionKey
        SessionRoot = $sessionRoot
        LaunchMode = $launchMode
        SandboxId = $sandboxId.ToLowerInvariant()
        ProcessId = $(if ($launchMode -eq 'legacy-wsb') { [int]$processIdValue } else { $null })
        ProcessCreationDate = $processCreationDate
        ProcessExecutablePath = $processExecutablePath
    }
}

function Get-AirlockStatePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AirlockRoot
    )
    return Join-Path (Join-Path $AirlockRoot 'state') 'active-session.json'
}

function Read-AirlockActiveSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AirlockRoot,
        [string]$StatePath
    )

    if ([string]::IsNullOrWhiteSpace($StatePath)) {
        $StatePath = Get-AirlockStatePath -AirlockRoot $AirlockRoot
    }
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
        return $null
    }
    Assert-AirlockNoReparsePoint -Path $StatePath -Root $AirlockRoot
    $state = Read-AirlockJson -Path $StatePath
    return Assert-AirlockSessionState -State $state -AirlockRoot $AirlockRoot
}

function Get-AirlockLauncherPathForState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$ValidatedState
    )

    if ([string]::IsNullOrWhiteSpace($env:SystemRoot)) {
        throw 'SystemRoot is unavailable; Airlock cannot resolve the native Sandbox launcher.'
    }
    $relative = if ($ValidatedState.LaunchMode -eq 'managed-cli') {
        'System32\wsb.exe'
    }
    else {
        'System32\WindowsSandbox.exe'
    }
    $launcher = Get-AirlockCanonicalPath -Path (Join-Path $env:SystemRoot $relative)
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
        throw "The recorded Airlock session cannot be controlled because its native launcher is missing: $launcher"
    }
    if ($ValidatedState.LaunchMode -eq 'legacy-wsb' -and
        -not $launcher.Equals(
            (Get-AirlockCanonicalPath -Path $ValidatedState.ProcessExecutablePath),
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'The recorded legacy process path does not match the native Windows Sandbox launcher.'
    }
    return $launcher
}

function Test-AirlockSessionActive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$ValidatedState,
        [Parameter(Mandatory = $true)][string]$LauncherPath
    )

    if ($ValidatedState.LaunchMode -eq 'managed-cli') {
        $raw = Invoke-AirlockWsbRaw -WsbPath $LauncherPath -Arguments @('list', '--raw')
        $ids = @(Get-AirlockWsbIds -RawJson $raw -ActiveOnly)
        return $ids -contains [string]$ValidatedState.SandboxId
    }

    $process = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$([int]$ValidatedState.ProcessId)" -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return $false
    }
    if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath) -or
        -not [IO.Path]::GetFullPath([string]$process.ExecutablePath).Equals(
            [IO.Path]::GetFullPath($LauncherPath),
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        [string]$process.CreationDate -cne [string]$ValidatedState.ProcessCreationDate) {
        throw "Refusing lifecycle action for PID $($ValidatedState.ProcessId) because its process identity no longer matches Airlock state."
    }
    return $true
}

function Wait-AirlockSessionStopped {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$ValidatedState,
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [ValidateRange(0.01, 300)][double]$TimeoutSeconds = 30,
        [ValidateRange(1, 5000)][int]$PollMilliseconds = 250,
        [scriptblock]$ActivityProbe
    )

    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $active = if ($null -ne $ActivityProbe) {
            [bool](& $ActivityProbe $ValidatedState $LauncherPath)
        }
        else {
            Test-AirlockSessionActive -ValidatedState $ValidatedState -LauncherPath $LauncherPath
        }
        if (-not $active) {
            return
        }
        Start-Sleep -Milliseconds $PollMilliseconds
    }
    throw "Timed out after $TimeoutSeconds seconds waiting for Airlock $($ValidatedState.LaunchMode) session to stop. No new session may start until this identity is reconciled."
}

function Stop-AirlockSessionIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$ValidatedState,
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [ValidateRange(1, 300)][int]$TimeoutSeconds = 30
    )

    if (-not (Test-AirlockSessionActive -ValidatedState $ValidatedState -LauncherPath $LauncherPath)) {
        return
    }
    if ($ValidatedState.LaunchMode -eq 'managed-cli') {
        try {
            $null = Invoke-AirlockWsbRaw -WsbPath $LauncherPath -Arguments @(
                'stop', '--id', [string]$ValidatedState.SandboxId, '--raw'
            )
        }
        catch {
            if (Test-AirlockSessionActive -ValidatedState $ValidatedState -LauncherPath $LauncherPath) {
                throw
            }
        }
    }
    else {
        try {
            Stop-Process -Id ([int]$ValidatedState.ProcessId) -Force -ErrorAction Stop
        }
        catch {
            if (Test-AirlockSessionActive -ValidatedState $ValidatedState -LauncherPath $LauncherPath) {
                throw
            }
        }
    }
    Wait-AirlockSessionStopped `
        -ValidatedState $ValidatedState `
        -LauncherPath $LauncherPath `
        -TimeoutSeconds $TimeoutSeconds
}

function Clear-AirlockSessionArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$ValidatedState,
        [Parameter(Mandatory = $true)][string]$AirlockRoot,
        [string]$StatePath
    )

    if ([string]::IsNullOrWhiteSpace($StatePath)) {
        $StatePath = Get-AirlockStatePath -AirlockRoot $AirlockRoot
    }
    if (Test-Path -LiteralPath $ValidatedState.SessionRoot -PathType Container) {
        Assert-AirlockNoReparsePoint -Path $ValidatedState.SessionRoot -Root $AirlockRoot
        Remove-Item -LiteralPath $ValidatedState.SessionRoot -Recurse -Force
    }

    if (Test-Path -LiteralPath $StatePath -PathType Leaf) {
        Assert-AirlockNoReparsePoint -Path $StatePath -Root $AirlockRoot
        $current = Assert-AirlockSessionState `
            -State (Read-AirlockJson -Path $StatePath) `
            -AirlockRoot $AirlockRoot
        if ($current.SessionKey -cne $ValidatedState.SessionKey) {
            throw "Refusing to remove active-session.json because it belongs to session $($current.SessionKey), not $($ValidatedState.SessionKey)."
        }
        Remove-Item -LiteralPath $StatePath -Force
    }
}

function Repair-AirlockStaleSessionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AirlockRoot,
        [string]$LauncherPath,
        [string]$StatePath,
        [scriptblock]$ActivityProbe
    )

    $state = Read-AirlockActiveSession -AirlockRoot $AirlockRoot -StatePath $StatePath
    if ($null -eq $state) {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($LauncherPath)) {
        $LauncherPath = Get-AirlockLauncherPathForState -ValidatedState $state
    }
    $active = if ($null -ne $ActivityProbe) {
        [bool](& $ActivityProbe $state $LauncherPath)
    }
    else {
        Test-AirlockSessionActive -ValidatedState $state -LauncherPath $LauncherPath
    }
    if ($active) {
        return $state
    }
    Clear-AirlockSessionArtifacts -ValidatedState $state -AirlockRoot $AirlockRoot -StatePath $StatePath
    return $null
}

function Invoke-AirlockFailedLaunchCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$ValidatedState,
        [Parameter(Mandatory = $true)][string]$AirlockRoot,
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [string]$StatePath,
        [ValidateRange(1, 300)][int]$TimeoutSeconds = 30,
        [scriptblock]$StopAction
    )

    if ($null -ne $StopAction) {
        & $StopAction $ValidatedState $LauncherPath
    }
    else {
        Stop-AirlockSessionIdentity `
            -ValidatedState $ValidatedState `
            -LauncherPath $LauncherPath `
            -TimeoutSeconds $TimeoutSeconds
    }
    Clear-AirlockSessionArtifacts `
        -ValidatedState $ValidatedState `
        -AirlockRoot $AirlockRoot `
        -StatePath $StatePath
}

function Invoke-AirlockStopAndReconcile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AirlockRoot,
        [string]$StatePath,
        [ValidateRange(1, 300)][int]$TimeoutSeconds = 30
    )

    $state = Read-AirlockActiveSession -AirlockRoot $AirlockRoot -StatePath $StatePath
    if ($null -eq $state) {
        return [PSCustomObject]@{
            Status = 'no-active-session'
            LaunchMode = $null
            SessionKey = $null
            Stopped = $false
            Reconciled = $false
        }
    }
    $launcher = Get-AirlockLauncherPathForState -ValidatedState $state
    $wasActive = Test-AirlockSessionActive -ValidatedState $state -LauncherPath $launcher
    if ($wasActive) {
        Stop-AirlockSessionIdentity `
            -ValidatedState $state `
            -LauncherPath $launcher `
            -TimeoutSeconds $TimeoutSeconds
    }
    Clear-AirlockSessionArtifacts `
        -ValidatedState $state `
        -AirlockRoot $AirlockRoot `
        -StatePath $StatePath

    return [PSCustomObject]@{
        Status = $(if ($wasActive) { 'stopped' } else { 'reconciled' })
        LaunchMode = $state.LaunchMode
        SessionKey = $state.SessionKey
        Stopped = $wasActive
        Reconciled = $true
    }
}
