[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$JobName,

    [string]$ProjectRoot = 'G:\My Drive\BosSys\996_LTSpice\Pwr',
    [string]$CodexRoot = 'G:\My Drive\BosSys\996_LTSpice\Pwr\CODEX'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Resolve-Path -LiteralPath $Path
    return [System.IO.Path]::GetFullPath($resolved.Path)
}

function Test-IsUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\\')
    $normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\\')
    return $normalizedPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

$sourceResolved = Resolve-NormalizedPath -Path $SourcePath
$projectRootResolved = [System.IO.Path]::GetFullPath($ProjectRoot)
$codexRootResolved = [System.IO.Path]::GetFullPath($CodexRoot)

if (-not (Test-IsUnderRoot -Path $sourceResolved -Root $projectRootResolved)) {
    throw "Source must be inside project root: $projectRootResolved"
}

$destinationDir = Join-Path $codexRootResolved "work\$JobName"
New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
$destinationPath = Join-Path $destinationDir ([System.IO.Path]::GetFileName($sourceResolved))
Copy-Item -LiteralPath $sourceResolved -Destination $destinationPath -Force

[pscustomobject]@{
    source_path      = $sourceResolved
    destination_path = $destinationPath
}
