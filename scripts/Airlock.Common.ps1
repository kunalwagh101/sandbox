Set-StrictMode -Version Latest

function Get-AirlockCanonicalPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$MustExist
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "A required path is empty."
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (-not [IO.Path]::IsPathRooted($expanded)) {
        throw "Path must be absolute: $Path"
    }

    $separators = [char[]]@(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $canonical = [IO.Path]::GetFullPath($expanded).TrimEnd($separators)
    if ($canonical -match '^[A-Za-z]:$') {
        $canonical += [IO.Path]::DirectorySeparatorChar
    }

    if ($MustExist -and -not (Test-Path -LiteralPath $canonical)) {
        throw "Required path does not exist: $canonical"
    }

    return $canonical
}

function Test-AirlockPathInsideRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Root,

        [switch]$AllowRoot
    )

    $canonicalPath = Get-AirlockCanonicalPath -Path $Path
    $canonicalRoot = Get-AirlockCanonicalPath -Path $Root
    if ($AllowRoot -and $canonicalPath.Equals(
            $canonicalRoot,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        return $true
    }

    $separators = [char[]]@('\', '/')
    $prefix = $canonicalRoot.TrimEnd($separators) + [IO.Path]::DirectorySeparatorChar
    return $canonicalPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-AirlockNoReparsePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $canonicalPath = Get-AirlockCanonicalPath -Path $Path -MustExist
    $canonicalRoot = Get-AirlockCanonicalPath -Path $Root -MustExist
    if (-not (Test-AirlockPathInsideRoot -Path $canonicalPath -Root $canonicalRoot -AllowRoot)) {
        throw "Path escapes the Airlock root: $canonicalPath"
    }

    $current = Get-Item -LiteralPath $canonicalPath -Force
    while ($null -ne $current) {
        if (($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse points are not allowed in an Airlock path: $($current.FullName)"
        }
        $separators = [char[]]@('\', '/')
        if ($current.FullName.TrimEnd($separators).Equals(
                $canonicalRoot.TrimEnd($separators),
                [StringComparison]::OrdinalIgnoreCase
            )) {
            return
        }
        if ($current -is [IO.DirectoryInfo]) {
            $current = $current.Parent
        }
        elseif ($current -is [IO.FileInfo]) {
            $current = $current.Directory
        }
        else {
            throw "Unsupported filesystem item type during reparse validation: $($current.GetType().FullName)"
        }
    }

    throw "Could not prove that the path remains under the Airlock root: $canonicalPath"
}

function Assert-AirlockPrivateRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'LOCALAPPDATA is unavailable; the private Airlock root cannot be proven.'
    }
    $canonicalRoot = Get-AirlockCanonicalPath -Path $Root -MustExist
    if (-not (Test-Path -LiteralPath $canonicalRoot -PathType Container)) {
        throw "The Airlock root must be a directory: $canonicalRoot"
    }
    $expectedRoot = Get-AirlockCanonicalPath -Path (Join-Path $env:LOCALAPPDATA 'Airlock')
    if (-not $canonicalRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The Airlock root must be the private LOCALAPPDATA Airlock directory: $expectedRoot"
    }
    $rootItem = Get-Item -LiteralPath $canonicalRoot -Force
    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "The Airlock root cannot be a reparse point: $canonicalRoot"
    }
    return $canonicalRoot
}

function Assert-AirlockMappedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [ValidateSet('bootstrap', 'result')]
        [string]$Purpose
    )

    $canonicalPath = Get-AirlockCanonicalPath -Path $Path -MustExist
    $canonicalRoot = Assert-AirlockPrivateRoot -Root $Root
    if (-not (Test-AirlockPathInsideRoot -Path $canonicalPath -Root $canonicalRoot)) {
        throw "The $Purpose mapping must be a child of the Airlock root: $canonicalPath"
    }

    $separators = [char[]]@('\', '/')
    $prefix = $canonicalRoot.TrimEnd($separators) + [IO.Path]::DirectorySeparatorChar
    $relative = $canonicalPath.Substring($prefix.Length)
    $relativeSegments = @($relative -split '[\\/]' | Where-Object { $_ -ne '' })
    if (@($relativeSegments | Where-Object { $_ -in @('audit', 'state') }).Count -gt 0) {
        throw "Airlock-relative audit and state paths can never be mapped: $relative"
    }

    Assert-AirlockNoReparsePoint -Path $canonicalPath -Root $canonicalRoot
    return $canonicalPath
}

function Move-AirlockFileAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemporaryPath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $temporary = Get-AirlockCanonicalPath -Path $TemporaryPath -MustExist
    $destination = Get-AirlockCanonicalPath -Path $DestinationPath
    $temporaryParent = Split-Path -Parent $temporary
    $destinationParent = Split-Path -Parent $destination
    if (-not $temporaryParent.Equals(
            $destinationParent,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Atomic replacement requires temporary and destination files in one directory.'
    }
    if (Test-Path -LiteralPath $destination) {
        # Windows PowerShell 5.1 cannot reliably bind a null backup path to
        # File.Replace.  A same-directory backup preserves the atomic replace
        # contract and is removed only after Replace returns.
        $backup = Join-Path $destinationParent (
            '.airlock-' + [Guid]::NewGuid().ToString('N') + '.bak'
        )
        try {
            [IO.File]::Replace($temporary, $destination, $backup)
        }
        finally {
            if (Test-Path -LiteralPath $backup) {
                Remove-Item -LiteralPath $backup -Force
            }
        }
    }
    else {
        [IO.File]::Move($temporary, $destination)
    }
}

function New-AirlockInitializationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][bool]$Applied,
        [Parameter(Mandatory = $true)][string]$PolicyPath,
        [Parameter(Mandatory = $true)][string]$InstallerVersion,
        [Parameter(Mandatory = $true)][string]$InstallerSha256,
        [Parameter(Mandatory = $true)][string]$Networking
    )

    return [PSCustomObject]@{
        Status = if ($Applied) { 'initialized' } else { 'planned' }
        PolicyPath = $PolicyPath
        PolicyWritten = $Applied
        InstallerVersion = $InstallerVersion
        InstallerSha256 = $InstallerSha256
        Networking = $Networking
    }
}

function Read-AirlockJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $canonical = Get-AirlockCanonicalPath -Path $Path -MustExist
    try {
        return Get-Content -LiteralPath $canonical -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in ${canonical}: $($_.Exception.Message)"
    }
}

function Write-AirlockJsonAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $canonical = Get-AirlockCanonicalPath -Path $Path
    $parent = Split-Path -Parent $canonical
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $temporary = Join-Path $parent ('.airlock-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $json = $Value | ConvertTo-Json -Depth 12
        [IO.File]::WriteAllText($temporary, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        Move-AirlockFileAtomic -TemporaryPath $temporary -DestinationPath $canonical
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}

function Assert-AirlockSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [string]$Name = 'SHA-256'
    )

    if ($Value -cnotmatch '^[A-F0-9]{64}$') {
        throw "$Name must be 64 uppercase hexadecimal characters."
    }
}
