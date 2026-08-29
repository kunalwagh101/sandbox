[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PolicyPath,

    [Parameter(Mandatory = $true)]
    [string]$AirlockRoot,

    [Parameter(Mandatory = $true)]
    [string]$BootstrapPath,

    [Parameter(Mandatory = $true)]
    [string]$ResultPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Airlock.Common.ps1')

$root = Get-AirlockCanonicalPath -Path $AirlockRoot -MustExist
$bootstrap = Assert-AirlockMappedPath -Path $BootstrapPath -Root $root -Purpose bootstrap
$result = Assert-AirlockMappedPath -Path $ResultPath -Root $root -Purpose result
$output = Get-AirlockCanonicalPath -Path $OutputPath
if (-not (Test-AirlockPathInsideRoot -Path $output -Root $root)) {
    throw "The generated profile must stay under the Airlock root: $output"
}
if ($bootstrap.Equals($result, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Bootstrap and result mappings must be separate directories.'
}
$sessionRoot = Split-Path -Parent $bootstrap
if (-not $sessionRoot.Equals((Split-Path -Parent $result), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Bootstrap and result mappings must belong to the same fresh session.'
}
$sessionsRoot = Get-AirlockCanonicalPath -Path (Join-Path $root 'sessions')
if (-not (Split-Path -Parent $sessionRoot).Equals(
        $sessionsRoot,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'Mappings must be direct children of one directory under Airlock\sessions.'
}
if ((Split-Path -Leaf $bootstrap) -cne 'bootstrap' -or (Split-Path -Leaf $result) -cne 'result') {
    throw 'Session mappings must use the fixed bootstrap and result directory names.'
}
if (-not (Split-Path -Parent $output).Equals($sessionRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The generated profile must be stored beside, not inside, the mapped directories.'
}
if ((Get-ChildItem -LiteralPath $result -Force | Measure-Object).Count -ne 0) {
    throw 'The writable result mapping must be empty before launch.'
}

$policy = Read-AirlockJson -Path $PolicyPath
if ($policy.schemaVersion -ne 1 -or $policy.profileName -ne 'strict-offline') {
    throw 'Only strict-offline policy schema version 1 can generate a profile.'
}

$required = [ordered]@{
    networking = 'Disable'
    vGPU = 'Disable'
    audioInput = 'Disable'
    videoInput = 'Disable'
    clipboardRedirection = 'Disable'
    printerRedirection = 'Disable'
    protectedClient = 'Enable'
}
foreach ($name in $required.Keys) {
    $actual = [string]$policy.sandbox.$name
    if ($actual -cne $required[$name]) {
        throw "Strict policy requires sandbox.$name=$($required[$name]); received '$actual'."
    }
}

$memoryMB = 0
if (-not [int]::TryParse([string]$policy.sandbox.memoryMB, [ref]$memoryMB)) {
    throw 'sandbox.memoryMB must be an integer.'
}
if ($memoryMB -lt 2048 -or $memoryMB -gt 4096) {
    throw 'sandbox.memoryMB must remain between 2048 and the binding 4096 MB ceiling.'
}

$installerName = [string]$policy.package.installerFileName
$provisionName = [string]$policy.guest.provisionScript
$resultName = [string]$policy.guest.resultFileName
foreach ($fileName in @($installerName, $provisionName, $resultName)) {
    if ($fileName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') {
        throw "Unsafe policy file name: $fileName"
    }
}
if (
    $installerName -cne 'BraveBrowserStandaloneSilentSetup.exe' -or
    $provisionName -cne 'provision.ps1' -or
    $resultName -cne 'provision-result.json' -or
    [string]$policy.package.product -cne 'Brave Browser' -or
    [string]$policy.package.expectedPublisher -cne 'Brave Software, Inc.'
) {
    throw 'Strict policy contains an unsupported product, publisher, or bootstrap file name.'
}
Assert-AirlockSha256 -Value ([string]$policy.package.expectedSha256) -Name 'Installer SHA-256'
Assert-AirlockSha256 -Value ([string]$policy.guest.provisionScriptSha256) -Name 'Provisioning script SHA-256'
$expectedBootstrapNames = @($installerName, $provisionName, 'policy.lock.json') | Sort-Object
$actualBootstrapItems = @(Get-ChildItem -LiteralPath $bootstrap -Force)
if (@($actualBootstrapItems | Where-Object { $_.PSIsContainer }).Count -ne 0) {
    throw 'The bootstrap mapping cannot contain directories.'
}
$actualBootstrapNames = @($actualBootstrapItems | ForEach-Object { $_.Name } | Sort-Object)
if (($actualBootstrapNames -join '|') -cne ($expectedBootstrapNames -join '|')) {
    throw 'The bootstrap mapping must contain exactly the installer, policy lock, and provisioner.'
}

$command = 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ' +
    '-File C:\AirlockBootstrap\' + $provisionName + ' ' +
    '-ContractPath C:\AirlockBootstrap\policy.lock.json ' +
    '-ResultPath C:\AirlockResult\' + $resultName

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.IndentChars = '  '
$settings.NewLineChars = "`r`n"
$settings.Encoding = [Text.UTF8Encoding]::new($false)
$settings.OmitXmlDeclaration = $true

$parent = Split-Path -Parent $output
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
$temporary = Join-Path $parent ('.profile-' + [Guid]::NewGuid().ToString('N') + '.tmp')
$writer = $null
try {
    $writer = [Xml.XmlWriter]::Create($temporary, $settings)
    $writer.WriteStartElement('Configuration')
    $elements = @(
        [PSCustomObject]@{ Name = 'vGPU'; Value = [string]$policy.sandbox.vGPU }
        [PSCustomObject]@{ Name = 'Networking'; Value = [string]$policy.sandbox.networking }
    )
    foreach ($element in $elements) {
        $writer.WriteElementString($element.Name, $element.Value)
    }

    $writer.WriteStartElement('MappedFolders')
    $mappings = @(
        [PSCustomObject]@{ Host = $bootstrap; Guest = 'C:\AirlockBootstrap'; ReadOnly = 'true' }
        [PSCustomObject]@{ Host = $result; Guest = 'C:\AirlockResult'; ReadOnly = 'false' }
    )
    foreach ($mapping in $mappings) {
        $writer.WriteStartElement('MappedFolder')
        $writer.WriteElementString('HostFolder', $mapping.Host)
        $writer.WriteElementString('SandboxFolder', $mapping.Guest)
        $writer.WriteElementString('ReadOnly', $mapping.ReadOnly)
        $writer.WriteEndElement()
    }
    $writer.WriteEndElement()

    $writer.WriteStartElement('LogonCommand')
    $writer.WriteElementString('Command', $command)
    $writer.WriteEndElement()
    $writer.WriteElementString('AudioInput', [string]$policy.sandbox.audioInput)
    $writer.WriteElementString('VideoInput', [string]$policy.sandbox.videoInput)
    $writer.WriteElementString('ProtectedClient', [string]$policy.sandbox.protectedClient)
    $writer.WriteElementString('PrinterRedirection', [string]$policy.sandbox.printerRedirection)
    $writer.WriteElementString('ClipboardRedirection', [string]$policy.sandbox.clipboardRedirection)
    $writer.WriteElementString('MemoryInMB', [string]$memoryMB)
    $writer.WriteEndElement()
    $writer.Flush()
    $writer.Close()
    $writer = $null
    Move-AirlockFileAtomic -TemporaryPath $temporary -DestinationPath $output
}
finally {
    if ($null -ne $writer) {
        $writer.Dispose()
    }
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Force
    }
}

return $output
