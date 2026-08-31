Set-StrictMode -Version Latest

function Resolve-AirlockPlatform {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Caption,
        [Parameter(Mandatory = $true)][string]$Edition,
        [Parameter(Mandatory = $true)][int]$ProductType,
        [Parameter(Mandatory = $true)][int]$Build,
        [Parameter(Mandatory = $true)][string]$Architecture,
        [Parameter(Mandatory = $true)][string]$SystemRoot,
        [Parameter(Mandatory = $true)][bool]$ManagedCliExists,
        [Parameter(Mandatory = $true)][bool]$LegacyLauncherExists
    )

    if ($ProductType -ne 1) {
        throw 'Windows Server is not supported. Recovery: use Windows 10/11 Pro, Enterprise, or Education.'
    }
    if ($Edition -notmatch '^(Professional|Enterprise|Education)') {
        throw "Unsupported Windows edition '$Edition'. Recovery: use Pro, Enterprise, or Education; Home is not supported."
    }
    if ($Architecture -notin @('AMD64', 'ARM64')) {
        throw "Unsupported architecture '$Architecture'. Recovery: use AMD64 or ARM64 Windows."
    }

    # Keep this pure and portable: CI exercises Windows decisions from Linux pwsh too.
    $root = $SystemRoot.TrimEnd([char[]]@('\', '/'))
    $managedPath = $root + '\System32\wsb.exe'
    $legacyPath = $root + '\System32\WindowsSandbox.exe'

    if ($Caption -match 'Windows 11') {
        if ($Build -lt 26100) {
            throw "Windows 11 build $Build is below 26100. Recovery: update to Windows 11 24H2 or newer."
        }
        if (-not $ManagedCliExists) {
            throw "Windows Sandbox managed CLI is missing at $managedPath. Recovery: enable/update Windows Sandbox on Windows 11 24H2+."
        }
        return [PSCustomObject]@{
            Mode = 'managed-cli'
            LauncherPath = $managedPath
            LifecycleControl = 'managed-id'
            SandboxIdSupported = $true
        }
    }

    if ($Caption -match 'Windows 10') {
        if ($Build -ne 19045) {
            throw "Windows 10 build $Build is unsupported by this compatibility slice. Recovery: use Windows 10 22H2 build 19045 or Windows 11 24H2+."
        }
        if ($Architecture -eq 'ARM64') {
            throw 'Windows 10 ARM64 is not supported by this compatibility slice. Recovery: use AMD64 Windows 10 22H2 or Windows 11 24H2+.'
        }
        if (-not $LegacyLauncherExists) {
            throw "Windows Sandbox launcher is missing at $legacyPath. Recovery: enable Windows Sandbox, then reboot."
        }
        return [PSCustomObject]@{
            Mode = 'legacy-wsb'
            LauncherPath = $legacyPath
            LifecycleControl = 'legacy-process'
            SandboxIdSupported = $false
        }
    }

    throw "Unsupported Windows version '$Caption'. Recovery: use Windows 10 22H2 build 19045 or Windows 11 24H2+."
}

function Get-AirlockLegacySandboxProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LauncherPath
    )

    $expectedPath = [IO.Path]::GetFullPath($LauncherPath)
    return @(Get-CimInstance -ClassName Win32_Process -Filter "Name='WindowsSandbox.exe'" -ErrorAction SilentlyContinue | Where-Object {
            try {
                -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
                [IO.Path]::GetFullPath([string]$_.ExecutablePath).Equals($expectedPath, [StringComparison]::OrdinalIgnoreCase)
            }
            catch {
                $false
            }
        })
}
