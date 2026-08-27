[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot '.git'))) {
    throw 'Airlock Git hooks cannot be installed because .git was not found.'
}

& git -C $repositoryRoot config core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) {
    throw 'Git rejected the Airlock hooks-path configuration.'
}

Write-Host 'Airlock pre-push verification is enabled.'
