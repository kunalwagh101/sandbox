[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ContractPath,

    [Parameter(Mandatory = $true)]
    [string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-ProvisionResult {
    param([Parameter(Mandatory = $true)][object]$Value)

    $parent = Split-Path -Parent $ResultPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Result directory is unavailable: $parent"
    }
    $temporary = Join-Path $parent ('.result-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $json = $Value | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText($temporary, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $ResultPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}

$startedAt = [DateTime]::UtcNow
try {
    $bootstrapRoot = [IO.Path]::GetFullPath((Split-Path -Parent $ContractPath)).TrimEnd('\')
    if ($bootstrapRoot -cne 'C:\AirlockBootstrap') {
        throw 'The provisioning contract is outside the read-only bootstrap mapping.'
    }
    $resultRoot = [IO.Path]::GetFullPath((Split-Path -Parent $ResultPath)).TrimEnd('\')
    if ($resultRoot -cne 'C:\AirlockResult') {
        throw 'Provisioning output is outside the dedicated result mapping.'
    }

    $policy = Get-Content -LiteralPath $ContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($policy.schemaVersion -ne 1 -or $policy.profileName -ne 'strict-offline') {
        throw 'Unsupported provisioning contract.'
    }
    if (
        [string]$policy.package.product -cne 'Brave Browser' -or
        [string]$policy.package.expectedPublisher -cne 'Brave Software, Inc.' -or
        [string]$policy.package.installerFileName -cne 'BraveBrowserStandaloneSilentSetup.exe' -or
        [string]$policy.guest.provisionScript -cne 'provision.ps1' -or
        [string]$policy.guest.resultFileName -cne 'provision-result.json'
    ) {
        throw 'Provisioning contract changed a trusted Brave identity or fixed file name.'
    }
    foreach ($setting in @('networking', 'vGPU', 'audioInput', 'videoInput', 'clipboardRedirection', 'printerRedirection')) {
        if ([string]$policy.sandbox.$setting -cne 'Disable') {
            throw "Provisioning refuses weakened setting sandbox.$setting."
        }
    }
    if ([string]$policy.sandbox.protectedClient -cne 'Enable') {
        throw 'Provisioning requires ProtectedClient=Enable.'
    }

    $installerName = [string]$policy.package.installerFileName
    if ($installerName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') {
        throw 'Unsafe installer file name in provisioning contract.'
    }
    $expectedHash = [string]$policy.package.expectedSha256
    if ($expectedHash -cnotmatch '^[A-F0-9]{64}$') {
        throw 'Invalid installer hash in provisioning contract.'
    }
    $installerPath = Join-Path $bootstrapRoot $installerName
    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
        throw "Pinned Brave installer is missing: $installerName"
    }
    $actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualHash -cne $expectedHash) {
        throw "Pinned Brave installer hash mismatch. Expected $expectedHash; received $actualHash."
    }
    $expectedProvisionHash = [string]$policy.guest.provisionScriptSha256
    if ($expectedProvisionHash -cnotmatch '^[A-F0-9]{64}$') {
        throw 'Invalid provisioning script hash in provisioning contract.'
    }
    $actualProvisionHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualProvisionHash -cne $expectedProvisionHash) {
        throw 'The executing provisioning script does not match its pinned hash.'
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "Pinned Brave installer signature is not valid: $($signature.StatusMessage)"
    }
    $publisher = [string]$signature.SignerCertificate.Subject
    $signerName = $signature.SignerCertificate.GetNameInfo(
        [Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
        $false
    )
    if ($signerName -cne 'Brave Software, Inc.') {
        throw "Pinned Brave installer signer does not match policy: '$signerName'. Subject: $publisher"
    }

    $browserRoots = @(
        $env:ProgramFiles
        ${env:ProgramFiles(x86)}
        $env:LOCALAPPDATA
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $browserCandidates = @($browserRoots | ForEach-Object {
            Join-Path $_ 'BraveSoftware\Brave-Browser\Application\brave.exe'
        })
    $browserPath = $browserCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    $installed = $false
    $installerExitCode = $null
    if ([string]::IsNullOrWhiteSpace([string]$browserPath)) {
        $installerProcess = Start-Process -FilePath $installerPath -Wait -PassThru
        $installerExitCode = $installerProcess.ExitCode
        if ($installerExitCode -ne 0) {
            throw "Brave installer failed with exit code $installerExitCode."
        }
        $installed = $true
        $browserPath = $browserCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
    if ([string]::IsNullOrWhiteSpace([string]$browserPath)) {
        throw 'Brave installation completed but brave.exe was not found in a supported location.'
    }

    $browserVersion = [string][Diagnostics.FileVersionInfo]::GetVersionInfo($browserPath).ProductVersion
    if ([string]::IsNullOrWhiteSpace($browserVersion)) {
        $browserVersion = [string][Diagnostics.FileVersionInfo]::GetVersionInfo($browserPath).FileVersion
    }
    if ([string]::IsNullOrWhiteSpace($browserVersion)) {
        throw 'Brave launched binary does not expose an exact version.'
    }
    $browserProduct = [string][Diagnostics.FileVersionInfo]::GetVersionInfo($browserPath).ProductName
    if ($browserProduct.IndexOf('Brave', [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Installed browser binary is not Brave: '$browserProduct'."
    }
    $browserSignature = Get-AuthenticodeSignature -LiteralPath $browserPath
    if ($browserSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "Installed Brave binary signature is not valid: $($browserSignature.StatusMessage)"
    }
    $browserSignerName = $browserSignature.SignerCertificate.GetNameInfo(
        [Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
        $false
    )
    if ($browserSignerName -cne 'Brave Software, Inc.') {
        throw "Installed Brave binary signer changed to '$browserSignerName'."
    }

    $dataRoot = 'C:\AirlockData\Brave'
    New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
    $browserArguments = @(
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-background-mode',
        '--user-data-dir=' + $dataRoot
    )
    $browserProcess = Start-Process -FilePath $browserPath -ArgumentList $browserArguments -PassThru
    Start-Sleep -Seconds 1
    $browserProcess.Refresh()
    if ($browserProcess.HasExited) {
        throw "Brave exited during readiness check with code $($browserProcess.ExitCode)."
    }

    Write-ProvisionResult -Value ([ordered]@{
            schemaVersion = 1
            status = 'success'
            product = 'Brave Browser'
            browserVersion = $browserVersion
            browserProduct = $browserProduct
            browserSignerName = $browserSignerName
            browserPath = $browserPath
            installerVersion = [string]$policy.package.expectedVersion
            installerSha256 = $actualHash
            installerPublisher = $publisher
            installerSignerName = $signerName
            installedThisSession = $installed
            installerExitCode = $installerExitCode
            browserProcessId = $browserProcess.Id
            networking = [string]$policy.sandbox.networking
            startedAtUtc = $startedAt.ToString('o')
            readyAtUtc = [DateTime]::UtcNow.ToString('o')
        })
}
catch {
    try {
        Write-ProvisionResult -Value ([ordered]@{
                schemaVersion = 1
                status = 'failed'
                errorType = $_.Exception.GetType().FullName
                message = $_.Exception.Message
                startedAtUtc = $startedAt.ToString('o')
                failedAtUtc = [DateTime]::UtcNow.ToString('o')
            })
    }
    catch {
        Write-Error "Provisioning failed and the result could not be recorded: $($_.Exception.Message)"
    }
    exit 1
}
