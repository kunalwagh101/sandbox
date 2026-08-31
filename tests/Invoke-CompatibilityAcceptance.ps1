[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$platformScript = Join-Path $repoRoot 'scripts\Airlock.Platform.ps1'
$startScript = Join-Path $repoRoot 'scripts\Start-Airlock.ps1'
. $platformScript

function Assert-Compatibility {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-ThrowsCompatibility {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ExpectedText
    )
    $caught = $null
    try { & $Action } catch { $caught = $_ }
    Assert-Compatibility -Condition ($null -ne $caught) -Message "Expected failure containing '$ExpectedText', but the action succeeded."
    Assert-Compatibility `
        -Condition ($caught.Exception.Message.IndexOf($ExpectedText, [StringComparison]::OrdinalIgnoreCase) -ge 0) `
        -Message "Expected '$ExpectedText'; received '$($caught.Exception.Message)'."
}

function Test-PlatformContract {
    $win10 = Resolve-AirlockPlatform `
        -Caption 'Microsoft Windows 10 Pro' `
        -Edition 'Professional' `
        -ProductType 1 `
        -Build 19045 `
        -Architecture 'AMD64' `
        -SystemRoot 'C:\Windows' `
        -ManagedCliExists $false `
        -LegacyLauncherExists $true
    Assert-Compatibility -Condition ($win10.Mode -ceq 'legacy-wsb') -Message 'Windows 10 did not select legacy-wsb.'
    Assert-Compatibility -Condition ($win10.LifecycleControl -ceq 'legacy-process') -Message 'Windows 10 lifecycle label is not truthful.'
    Assert-Compatibility -Condition (-not $win10.SandboxIdSupported) -Message 'Windows 10 falsely claims managed Sandbox IDs.'

    $win11 = Resolve-AirlockPlatform `
        -Caption 'Microsoft Windows 11 Pro' `
        -Edition 'Professional' `
        -ProductType 1 `
        -Build 26100 `
        -Architecture 'AMD64' `
        -SystemRoot 'C:\Windows' `
        -ManagedCliExists $true `
        -LegacyLauncherExists $true
    Assert-Compatibility -Condition ($win11.Mode -ceq 'managed-cli') -Message 'Windows 11 24H2 did not select managed-cli.'
    Assert-Compatibility -Condition ($win11.SandboxIdSupported) -Message 'Windows 11 managed mode lost Sandbox-ID support.'

    Assert-ThrowsCompatibility -ExpectedText 'edition' -Action {
        Resolve-AirlockPlatform -Caption 'Microsoft Windows 10 Home' -Edition 'Core' -ProductType 1 -Build 19045 -Architecture 'AMD64' -SystemRoot 'C:\Windows' -ManagedCliExists $false -LegacyLauncherExists $true | Out-Null
    }
    Assert-ThrowsCompatibility -ExpectedText 'build 19044' -Action {
        Resolve-AirlockPlatform -Caption 'Microsoft Windows 10 Pro' -Edition 'Professional' -ProductType 1 -Build 19044 -Architecture 'AMD64' -SystemRoot 'C:\Windows' -ManagedCliExists $false -LegacyLauncherExists $true | Out-Null
    }
    Assert-ThrowsCompatibility -ExpectedText 'below 26100' -Action {
        Resolve-AirlockPlatform -Caption 'Microsoft Windows 11 Pro' -Edition 'Professional' -ProductType 1 -Build 22631 -Architecture 'AMD64' -SystemRoot 'C:\Windows' -ManagedCliExists $false -LegacyLauncherExists $true | Out-Null
    }
    Assert-ThrowsCompatibility -ExpectedText 'architecture' -Action {
        Resolve-AirlockPlatform -Caption 'Microsoft Windows 10 Pro' -Edition 'Professional' -ProductType 1 -Build 19045 -Architecture 'x86' -SystemRoot 'C:\Windows' -ManagedCliExists $false -LegacyLauncherExists $true | Out-Null
    }
    Assert-ThrowsCompatibility -ExpectedText 'launcher is missing' -Action {
        Resolve-AirlockPlatform -Caption 'Microsoft Windows 10 Pro' -Edition 'Professional' -ProductType 1 -Build 19045 -Architecture 'AMD64' -SystemRoot 'C:\Windows' -ManagedCliExists $false -LegacyLauncherExists $false | Out-Null
    }
    Assert-ThrowsCompatibility -ExpectedText 'managed CLI is missing' -Action {
        Resolve-AirlockPlatform -Caption 'Microsoft Windows 11 Pro' -Edition 'Professional' -ProductType 1 -Build 26100 -Architecture 'AMD64' -SystemRoot 'C:\Windows' -ManagedCliExists $false -LegacyLauncherExists $true | Out-Null
    }
}

function Test-LegacyProcessIdentity {
    $source = Get-Content -LiteralPath $startScript -Raw -Encoding UTF8
    Assert-Compatibility -Condition ($source.Contains("Start-Process -FilePath `$preflight.LauncherPath")) -Message 'Legacy launch does not use the selected native launcher.'
    Assert-Compatibility -Condition ($source.Contains("`$profileArgument =")) -Message 'Legacy .wsb path is not prepared as a quoted launch argument.'
    Assert-Compatibility -Condition ($source.Contains("-ArgumentList @(`$profileArgument)")) -Message 'Legacy launch does not pass the quoted generated .wsb profile.'
    Assert-Compatibility -Condition ($source.Contains('Get-NewLegacySandboxProcess')) -Message 'Legacy process identity is not resolved after launch.'
    Assert-Compatibility -Condition ($source.Contains('processCreationDate')) -Message 'Legacy process creation identity is not persisted.'
    Assert-Compatibility -Condition ($source.Contains('processExecutablePath')) -Message 'Legacy executable identity is not persisted.'
    Assert-Compatibility -Condition ($source.Contains("lifecycleControl = [string]`$preflight.LifecycleControl")) -Message 'Legacy lifecycle mode is not persisted.'
    Assert-Compatibility -Condition ($source.Contains('Refusing to stop PID')) -Message 'Legacy stop is not identity-guarded.'
    Assert-Compatibility -Condition ($source.Contains("sandboxId = `$sessionId")) -Message 'Shared state schema lost sandboxId field.'
    Assert-Compatibility -Condition ($source.Contains("`$sessionId = `$null")) -Message 'Legacy mode may invent a Sandbox ID.'
    Assert-Compatibility -Condition ($source.Contains('Airlock stopped the unrecorded legacy Sandbox because session state could not be saved')) -Message 'Legacy state-write cleanup success is not reported distinctly.'
}

Test-PlatformContract
Test-LegacyProcessIdentity
Write-Output 'COMPATIBILITY_ACCEPTANCE: PASSED (2 tests)'
