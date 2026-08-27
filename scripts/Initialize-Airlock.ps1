[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,

    [string]$PolicyTemplatePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'policy.json'),

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Airlock.Common.ps1')

if ($env:OS -ne 'Windows_NT') {
    throw 'Initialize-Airlock.ps1 must run on Windows.'
}
if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    throw 'LOCALAPPDATA is unavailable; Airlock cannot establish its private host root.'
}

$installer = Get-AirlockCanonicalPath -Path $InstallerPath -MustExist
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw "InstallerPath must name one file: $installer"
}
if ([IO.Path]::GetExtension($installer) -ine '.exe') {
    throw 'The Brave installer must be an .exe file.'
}
if (((Get-Item -LiteralPath $installer -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw 'The installer cannot be a symbolic link or another reparse point.'
}

$template = Read-AirlockJson -Path $PolicyTemplatePath
if ($template.schemaVersion -ne 1 -or $template.profileName -ne 'strict-offline') {
    throw 'The policy template is not the supported strict-offline schema version 1.'
}
$requiredSandbox = [ordered]@{
    networking = 'Disable'
    vGPU = 'Disable'
    audioInput = 'Disable'
    videoInput = 'Disable'
    clipboardRedirection = 'Disable'
    printerRedirection = 'Disable'
    protectedClient = 'Enable'
}
foreach ($setting in $requiredSandbox.Keys) {
    if ([string]$template.sandbox.$setting -cne $requiredSandbox[$setting]) {
        throw "The policy template weakens sandbox.$setting."
    }
}
$templateMemoryMB = 0
if (
    -not [int]::TryParse([string]$template.sandbox.memoryMB, [ref]$templateMemoryMB) -or
    $templateMemoryMB -lt 2048 -or
    $templateMemoryMB -gt 8192
) {
    throw 'The policy template memory must be an integer from 2048 through 8192 MB.'
}
$trustedPublisher = 'Brave Software, Inc.'
if ([string]$template.package.expectedPublisher -cne $trustedPublisher) {
    throw "The policy template must require the trusted publisher '$trustedPublisher'."
}
if ([string]$template.package.product -cne 'Brave Browser') {
    throw 'The policy template product must be Brave Browser.'
}

$signature = Get-AuthenticodeSignature -LiteralPath $installer
if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "The Brave installer signature is not valid: $($signature.StatusMessage)"
}
$subject = [string]$signature.SignerCertificate.Subject
$signerName = $signature.SignerCertificate.GetNameInfo(
    [Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
    $false
)
if ($signerName -cne $trustedPublisher) {
    throw "Installer signer '$signerName' does not match '$trustedPublisher'. Subject: $subject"
}

$sha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToUpperInvariant()
Assert-AirlockSha256 -Value $sha256 -Name 'Installer SHA-256'
$versionInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($installer)
$productName = [string]$versionInfo.ProductName
if ($productName.IndexOf('Brave', [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "The signed installer product is not Brave: '$productName'."
}
$installerVersion = [string]$versionInfo.ProductVersion
if ([string]::IsNullOrWhiteSpace($installerVersion)) {
    $installerVersion = [string]$versionInfo.FileVersion
}
if ([string]::IsNullOrWhiteSpace($installerVersion)) {
    throw 'The signed installer does not expose a product or file version.'
}

$airlockRoot = Join-Path $env:LOCALAPPDATA 'Airlock'
$packageDirectory = Join-Path (Join-Path $airlockRoot 'packages') $sha256
$installerName = [string]$template.package.installerFileName
if ($installerName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') {
    throw "Unsafe installer file name in policy template: $installerName"
}
$packagePath = Join-Path $packageDirectory $installerName
$policyPath = Join-Path $airlockRoot 'policy.lock.json'
$guestScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'guest\provision.ps1'
$guestScript = Get-AirlockCanonicalPath -Path $guestScript -MustExist
if (((Get-Item -LiteralPath $guestScript -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw 'The provisioning script cannot be a symbolic link or another reparse point.'
}
$guestSha256 = (Get-FileHash -LiteralPath $guestScript -Algorithm SHA256).Hash.ToUpperInvariant()
Assert-AirlockSha256 -Value $guestSha256 -Name 'Provisioning script SHA-256'

if ((Test-Path -LiteralPath $policyPath) -and -not $Force) {
    $existing = Read-AirlockJson -Path $policyPath
    if ([string]$existing.package.expectedSha256 -ne $sha256) {
        throw "Airlock is already pinned to another installer. Re-run with -Force to replace the package contract."
    }
}

if ($PSCmdlet.ShouldProcess($airlockRoot, 'Pin the signed Brave installer and strict policy')) {
    New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
    Assert-AirlockNoReparsePoint -Path $packageDirectory -Root $airlockRoot
    if (Test-Path -LiteralPath $policyPath) {
        Assert-AirlockNoReparsePoint -Path $policyPath -Root $airlockRoot
    }
    if (Test-Path -LiteralPath $packagePath) {
        Assert-AirlockNoReparsePoint -Path $packagePath -Root $airlockRoot
        $existingHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($existingHash -cne $sha256) {
            throw 'An existing immutable package path contains different bytes.'
        }
    }
    else {
        $temporaryPackage = Join-Path $packageDirectory ('.package-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        try {
            Copy-Item -LiteralPath $installer -Destination $temporaryPackage
            $copiedHash = (Get-FileHash -LiteralPath $temporaryPackage -Algorithm SHA256).Hash.ToUpperInvariant()
            if ($copiedHash -cne $sha256) {
                throw 'The installer changed while Airlock copied it. No package was pinned.'
            }
            Move-Item -LiteralPath $temporaryPackage -Destination $packagePath
        }
        finally {
            if (Test-Path -LiteralPath $temporaryPackage) {
                Remove-Item -LiteralPath $temporaryPackage -Force
            }
        }
    }

    $template.package.expectedSha256 = $sha256
    $template.package.expectedVersion = $installerVersion
    $template.package.packageRelativePath = 'packages\' + $sha256 + '\' + $installerName
    $template.package.initializedAtUtc = [DateTime]::UtcNow.ToString('o')
    $template.guest.provisionScriptSha256 = $guestSha256
    Write-AirlockJsonAtomic -Path $policyPath -Value $template
}

[PSCustomObject]@{
    PolicyPath = $policyPath
    Product = [string]$template.package.product
    InstallerProduct = $productName
    InstallerVersion = $installerVersion
    InstallerSha256 = $sha256
    Publisher = $subject
    SignerName = $signerName
    Networking = [string]$template.sandbox.networking
}
