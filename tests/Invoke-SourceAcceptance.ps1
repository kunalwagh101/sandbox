[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$commonScript = Join-Path $repoRoot 'scripts\Airlock.Common.ps1'
$profileScript = Join-Path $repoRoot 'scripts\New-AirlockProfile.ps1'
. $commonScript

function Assert-SourceAcceptance {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-ThrowsMessage {
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
    Assert-SourceAcceptance `
        -Condition ($null -ne $caught) `
        -Message "Expected failure containing '$ExpectedText', but the action succeeded."
    Assert-SourceAcceptance `
        -Condition ($caught.Exception.Message.IndexOf(
                $ExpectedText,
                [StringComparison]::OrdinalIgnoreCase
            ) -ge 0) `
        -Message "Expected failure containing '$ExpectedText'; received '$($caught.Exception.Message)'."
}

function New-SourceFixture {
    param([switch]$StateAncestor)

    $testRoot = Join-Path ([IO.Path]::GetTempPath()) (
        'airlock-source-' + [Guid]::NewGuid().ToString('N')
    )
    $profileRoot = if ($StateAncestor) {
        Join-Path (Join-Path $testRoot 'state') 'profile'
    }
    else {
        Join-Path $testRoot 'profile'
    }
    $localAppData = Join-Path $profileRoot 'LocalAppData'
    $airlockRoot = Join-Path $localAppData 'Airlock'
    $sessionRoot = Join-Path (Join-Path $airlockRoot 'sessions') 'fixture-session'
    $bootstrap = Join-Path $sessionRoot 'bootstrap'
    $result = Join-Path $sessionRoot 'result'
    New-Item -ItemType Directory -Path $bootstrap -Force | Out-Null
    New-Item -ItemType Directory -Path $result -Force | Out-Null

    $policy = Get-Content -LiteralPath (Join-Path $repoRoot 'policy.json') -Raw -Encoding UTF8 |
        ConvertFrom-Json
    $policy.package.expectedSha256 = 'A' * 64
    $policy.package.expectedVersion = '1.2.3.4'
    $policy.package.packageRelativePath = 'packages\fixture\BraveBrowserStandaloneSilentSetup.exe'
    $policy.package.initializedAtUtc = '2026-08-29T00:00:00Z'
    $policy.guest.provisionScriptSha256 = 'B' * 64
    $policyPath = Join-Path $bootstrap 'policy.lock.json'
    [IO.File]::WriteAllText(
        $policyPath,
        ($policy | ConvertTo-Json -Depth 12),
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        (Join-Path $bootstrap 'BraveBrowserStandaloneSilentSetup.exe'),
        'fixture installer',
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        (Join-Path $bootstrap 'provision.ps1'),
        'Write-Output fixture',
        [Text.UTF8Encoding]::new($false)
    )

    return [PSCustomObject]@{
        TestRoot = $testRoot
        LocalAppData = $localAppData
        AirlockRoot = $airlockRoot
        SessionRoot = $sessionRoot
        Bootstrap = $bootstrap
        Result = $result
        PolicyPath = $policyPath
        Policy = $policy
    }
}

function Test-ReparseTraversal {
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) (
        'airlock-reparse-' + [Guid]::NewGuid().ToString('N')
    )
    try {
        $child = Join-Path $testRoot 'child'
        $file = Join-Path $child 'policy.lock.json'
        New-Item -ItemType Directory -Path $child -Force | Out-Null
        [IO.File]::WriteAllText($file, '{}', [Text.UTF8Encoding]::new($false))

        Assert-AirlockNoReparsePoint -Path $child -Root $testRoot
        Assert-AirlockNoReparsePoint -Path $file -Root $testRoot

        $originalFile = Get-Item -LiteralPath $file -Force
        Assert-ThrowsMessage -ExpectedText 'Parent' -Action {
            $null = $originalFile.Parent
        }
    }
    finally {
        if (Test-Path -LiteralPath $testRoot) {
            Remove-Item -LiteralPath $testRoot -Recurse -Force
        }
    }
}

function Test-GeneratedStrictProfile {
    $fixture = New-SourceFixture
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = $fixture.LocalAppData
        $outputPath = Join-Path $fixture.SessionRoot 'strict.wsb'
        & $profileScript `
            -PolicyPath $fixture.PolicyPath `
            -AirlockRoot $fixture.AirlockRoot `
            -BootstrapPath $fixture.Bootstrap `
            -ResultPath $fixture.Result `
            -OutputPath $outputPath | Out-Null

        [xml]$xml = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8
        $expectedSettings = [ordered]@{
            Networking = 'Disable'
            vGPU = 'Disable'
            AudioInput = 'Disable'
            VideoInput = 'Disable'
            ClipboardRedirection = 'Disable'
            PrinterRedirection = 'Disable'
            ProtectedClient = 'Enable'
            MemoryInMB = '4096'
        }
        foreach ($setting in $expectedSettings.Keys) {
            Assert-SourceAcceptance `
                -Condition ([string]$xml.Configuration.$setting -ceq $expectedSettings[$setting]) `
                -Message "Generated profile has unexpected $setting."
        }
        $mappings = @($xml.Configuration.MappedFolders.MappedFolder)
        Assert-SourceAcceptance -Condition ($mappings.Count -eq 2) -Message 'Expected exactly two mappings.'
        Assert-SourceAcceptance -Condition ([string]$mappings[0].HostFolder -ceq $fixture.Bootstrap) -Message 'Bootstrap host mapping changed.'
        Assert-SourceAcceptance -Condition ([string]$mappings[0].ReadOnly -ceq 'true') -Message 'Bootstrap mapping is writable.'
        Assert-SourceAcceptance -Condition ([string]$mappings[1].HostFolder -ceq $fixture.Result) -Message 'Result host mapping changed.'
        Assert-SourceAcceptance -Condition ([string]$mappings[1].ReadOnly -ceq 'false') -Message 'Result mapping is not explicit.'

        $strictJson = $fixture.Policy | ConvertTo-Json -Depth 12
        $weakenings = [ordered]@{
            networking = 'Enable'
            vGPU = 'Enable'
            audioInput = 'Enable'
            videoInput = 'Enable'
            clipboardRedirection = 'Enable'
            printerRedirection = 'Enable'
            protectedClient = 'Disable'
        }
        foreach ($setting in $weakenings.Keys) {
            $weakened = $strictJson | ConvertFrom-Json
            $weakened.sandbox.$setting = $weakenings[$setting]
            [IO.File]::WriteAllText(
                $fixture.PolicyPath,
                ($weakened | ConvertTo-Json -Depth 12),
                [Text.UTF8Encoding]::new($false)
            )
            Assert-ThrowsMessage `
                -ExpectedText "Strict policy requires sandbox.$setting" `
                -Action {
                    & $profileScript `
                        -PolicyPath $fixture.PolicyPath `
                        -AirlockRoot $fixture.AirlockRoot `
                        -BootstrapPath $fixture.Bootstrap `
                        -ResultPath $fixture.Result `
                        -OutputPath (Join-Path $fixture.SessionRoot "weak-$setting.wsb") | Out-Null
                }
        }

        $weakenedMemory = $strictJson | ConvertFrom-Json
        $weakenedMemory.sandbox.memoryMB = 4097
        [IO.File]::WriteAllText(
            $fixture.PolicyPath,
            ($weakenedMemory | ConvertTo-Json -Depth 12),
            [Text.UTF8Encoding]::new($false)
        )
        Assert-ThrowsMessage -ExpectedText 'binding 4096 MB ceiling' -Action {
            & $profileScript `
                -PolicyPath $fixture.PolicyPath `
                -AirlockRoot $fixture.AirlockRoot `
                -BootstrapPath $fixture.Bootstrap `
                -ResultPath $fixture.Result `
                -OutputPath (Join-Path $fixture.SessionRoot 'weak-memory.wsb') | Out-Null
        }
    }
    finally {
        $env:LOCALAPPDATA = $previousLocalAppData
        if (Test-Path -LiteralPath $fixture.TestRoot) {
            Remove-Item -LiteralPath $fixture.TestRoot -Recurse -Force
        }
    }
}

function Test-RelativeProtectedPaths {
    $fixture = New-SourceFixture -StateAncestor
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = $fixture.LocalAppData
        $resolved = Assert-AirlockMappedPath `
            -Path $fixture.Bootstrap `
            -Root $fixture.AirlockRoot `
            -Purpose bootstrap
        Assert-SourceAcceptance -Condition ($resolved -ceq $fixture.Bootstrap) -Message 'A valid mapping under a state-named user ancestor was rejected.'

        $protected = Join-Path (Join-Path $fixture.AirlockRoot 'sessions') 'state'
        New-Item -ItemType Directory -Path $protected -Force | Out-Null
        Assert-ThrowsMessage -ExpectedText 'Airlock-relative audit and state paths' -Action {
            Assert-AirlockMappedPath `
                -Path $protected `
                -Root $fixture.AirlockRoot `
                -Purpose result | Out-Null
        }

        $wrongRoot = Join-Path $fixture.TestRoot 'OtherRoot'
        $wrongChild = Join-Path $wrongRoot 'child'
        New-Item -ItemType Directory -Path $wrongChild -Force | Out-Null
        Assert-ThrowsMessage -ExpectedText 'private LOCALAPPDATA Airlock directory' -Action {
            Assert-AirlockMappedPath -Path $wrongChild -Root $wrongRoot -Purpose bootstrap | Out-Null
        }
    }
    finally {
        $env:LOCALAPPDATA = $previousLocalAppData
        if (Test-Path -LiteralPath $fixture.TestRoot) {
            Remove-Item -LiteralPath $fixture.TestRoot -Recurse -Force
        }
    }
}

function Test-StateWriteContract {
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) (
        'airlock-state-' + [Guid]::NewGuid().ToString('N')
    )
    try {
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
        $statePath = Join-Path $testRoot 'state.json'
        Write-AirlockJsonAtomic -Path $statePath -Value ([ordered]@{ generation = 1 })
        Write-AirlockJsonAtomic -Path $statePath -Value ([ordered]@{ generation = 2 })
        $state = Read-AirlockJson -Path $statePath
        Assert-SourceAcceptance -Condition ($state.generation -eq 2) -Message 'Atomic replacement did not publish the complete second state.'
        Assert-SourceAcceptance `
            -Condition (@(Get-ChildItem -LiteralPath $testRoot -Filter '.airlock-*.tmp' -Force).Count -eq 0) `
            -Message 'Atomic state write left a temporary file.'

        $planned = New-AirlockInitializationResult `
            -Applied $false `
            -PolicyPath $statePath `
            -InstallerVersion '1.2.3.4' `
            -InstallerSha256 ('A' * 64) `
            -Networking 'Disable'
        Assert-SourceAcceptance -Condition ($planned.Status -ceq 'planned') -Message 'WhatIf result does not say planned.'
        Assert-SourceAcceptance -Condition (-not $planned.PolicyWritten) -Message 'WhatIf result falsely reports a written policy.'

        $applied = New-AirlockInitializationResult `
            -Applied $true `
            -PolicyPath $statePath `
            -InstallerVersion '1.2.3.4' `
            -InstallerSha256 ('A' * 64) `
            -Networking 'Disable'
        Assert-SourceAcceptance -Condition ($applied.Status -ceq 'initialized') -Message 'Applied result does not say initialized.'
        Assert-SourceAcceptance -Condition $applied.PolicyWritten -Message 'Applied result does not report its write.'
    }
    finally {
        if (Test-Path -LiteralPath $testRoot) {
            Remove-Item -LiteralPath $testRoot -Recurse -Force
        }
    }
}

$tests = @(
    'Test-ReparseTraversal',
    'Test-GeneratedStrictProfile',
    'Test-RelativeProtectedPaths',
    'Test-StateWriteContract'
)
foreach ($test in $tests) {
    & $test
    Write-Output "PASS: $test"
}
Write-Output "SOURCE_ACCEPTANCE: PASSED ($($tests.Count) tests)"
