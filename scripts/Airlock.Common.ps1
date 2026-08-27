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
        $current = $current.Parent
    }

    throw "Could not prove that the path remains under the Airlock root: $canonicalPath"
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
    $canonicalRoot = Get-AirlockCanonicalPath -Path $Root -MustExist
    if (-not (Test-AirlockPathInsideRoot -Path $canonicalPath -Root $canonicalRoot)) {
        throw "The $Purpose mapping must be a child of the Airlock root: $canonicalPath"
    }

    $separators = [char[]]@('\', '/')
    $driveRoot = [IO.Path]::GetPathRoot($canonicalPath).TrimEnd($separators)
    if ($canonicalPath.TrimEnd($separators).Equals(
            $driveRoot,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "A drive root can never be mapped into Airlock: $canonicalPath"
    }

    $protected = @(
        $env:USERPROFILE,
        $env:LOCALAPPDATA,
        $env:APPDATA,
        $(if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'Desktop' }),
        $(if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'Documents' })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($protectedPath in $protected) {
        $canonicalProtected = Get-AirlockCanonicalPath -Path $protectedPath
        if ($canonicalPath.Equals(
                $canonicalProtected,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Protected host path can never be mapped into Airlock: $canonicalPath"
        }
    }

    if ($canonicalPath -match '(?i)[\\/](audit|state)([\\/]|$)') {
        throw "Audit and state paths can never be mapped into Airlock: $canonicalPath"
    }

    Assert-AirlockNoReparsePoint -Path $canonicalPath -Root $canonicalRoot
    return $canonicalPath
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
        Move-Item -LiteralPath $temporary -Destination $canonical -Force
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
