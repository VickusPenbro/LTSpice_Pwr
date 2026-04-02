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
    [System.IO.Path]::GetFullPath($resolved.Path)
}

function Test-IsUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    $normalizedPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

$projectRootResolved = [System.IO.Path]::GetFullPath($ProjectRoot)
$codexRootResolved = [System.IO.Path]::GetFullPath($CodexRoot)
$sourceResolved = Resolve-NormalizedPath -Path $SourcePath

if (-not (Test-IsUnderRoot -Path $sourceResolved -Root $projectRootResolved)) {
    throw "Source must be inside project root: $projectRootResolved"
}

$jobDir = Join-Path $codexRootResolved "work\$JobName"
New-Item -ItemType Directory -Path $jobDir -Force | Out-Null
if (-not (Test-IsUnderRoot -Path $jobDir -Root $codexRootResolved)) {
    throw 'Job directory escaped CODEX root.'
}

$copied = New-Object System.Collections.Generic.List[string]
$sourceCopy = Join-Path $jobDir ([System.IO.Path]::GetFileName($sourceResolved))
Copy-Item -LiteralPath $sourceResolved -Destination $sourceCopy -Force
$copied.Add($sourceCopy)

$lines = Get-Content -LiteralPath $sourceResolved
$symbolNames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
$includeFiles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

foreach ($line in $lines) {
    if ($line -match '^SYMBOL\s+(\S+)') {
        [void]$symbolNames.Add($matches[1])
    }
    if ($line -match '^TEXT .*?!\.(?:include|inc)\s+(.+)$') {
        $includeRef = $matches[1].Trim()
        $includeRef = $includeRef.Trim('"')
        [void]$includeFiles.Add($includeRef)
    }
}

$modelFiles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($symbolName in $symbolNames) {
    $projectSymbolPath = Join-Path $projectRootResolved ($symbolName + '.asy')
    if (Test-Path -LiteralPath $projectSymbolPath) {
        $symbolDest = Join-Path $jobDir ([System.IO.Path]::GetFileName($projectSymbolPath))
        Copy-Item -LiteralPath $projectSymbolPath -Destination $symbolDest -Force
        $copied.Add($symbolDest)

        foreach ($asyLine in Get-Content -LiteralPath $projectSymbolPath) {
            if ($asyLine -match '^SYMATTR\s+ModelFile\s+(.+)$') {
                [void]$modelFiles.Add($matches[1].Trim())
            }
        }
    }
}

foreach ($modelFile in $modelFiles) {
    $projectModelPath = Join-Path $projectRootResolved $modelFile
    if (Test-Path -LiteralPath $projectModelPath) {
        $modelDest = Join-Path $jobDir ([System.IO.Path]::GetFileName($projectModelPath))
        Copy-Item -LiteralPath $projectModelPath -Destination $modelDest -Force
        $copied.Add($modelDest)
    }
}

foreach ($includeFile in $includeFiles) {
    $candidatePaths = @(
        (Join-Path ([System.IO.Path]::GetDirectoryName($sourceResolved)) $includeFile),
        (Join-Path $projectRootResolved $includeFile)
    )

    foreach ($candidate in $candidatePaths) {
        if (Test-Path -LiteralPath $candidate) {
            $includeDest = Join-Path $jobDir ([System.IO.Path]::GetFileName($candidate))
            Copy-Item -LiteralPath $candidate -Destination $includeDest -Force
            $copied.Add($includeDest)
            break
        }
    }
}

$manifest = [pscustomobject]@{
    source = $sourceResolved
    job_dir = $jobDir
    symbols_detected = @($symbolNames | Sort-Object)
    model_files = @($modelFiles | Sort-Object)
    include_files = @($includeFiles | Sort-Object)
    copied_files = @($copied | Sort-Object -Unique)
}

$manifestPath = Join-Path $jobDir 'job-manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$manifest
