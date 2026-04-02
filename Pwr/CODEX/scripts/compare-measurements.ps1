[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaselineJson,

    [Parameter(Mandatory = $true)]
    [string]$CandidateJson,

    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Resolve-Path -LiteralPath $Path
    return [System.IO.Path]::GetFullPath($resolved.Path)
}

function Get-NumericMeasurementMap {
    param($JsonObject)

    $map = @{}
    foreach ($property in $JsonObject.measurements.PSObject.Properties) {
        $value = $property.Value.numeric
        if ($null -ne $value) {
            $map[$property.Name] = [double]$value
        }
    }
    return $map
}

$baselineResolved = Resolve-NormalizedPath -Path $BaselineJson
$candidateResolved = Resolve-NormalizedPath -Path $CandidateJson

$baseline = Get-Content -LiteralPath $baselineResolved -Raw | ConvertFrom-Json
$candidate = Get-Content -LiteralPath $candidateResolved -Raw | ConvertFrom-Json

if (-not $OutputDir) {
    $OutputDir = Join-Path ([System.IO.Path]::GetDirectoryName($candidateResolved)) 'comparison'
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$baselineMap = Get-NumericMeasurementMap -JsonObject $baseline
$candidateMap = Get-NumericMeasurementMap -JsonObject $candidate
$allNames = ($baselineMap.Keys + $candidateMap.Keys | Sort-Object -Unique)

$rows = foreach ($name in $allNames) {
    $baseValue = if ($baselineMap.ContainsKey($name)) { $baselineMap[$name] } else { $null }
    $candidateValue = if ($candidateMap.ContainsKey($name)) { $candidateMap[$name] } else { $null }
    $delta = if ($null -ne $baseValue -and $null -ne $candidateValue) { $candidateValue - $baseValue } else { $null }
    $deltaPercent = if ($null -ne $baseValue -and $baseValue -ne 0 -and $null -ne $candidateValue) { (($candidateValue - $baseValue) / $baseValue) * 100.0 } else { $null }

    [pscustomobject]@{
        name          = $name
        baseline      = $baseValue
        candidate     = $candidateValue
        delta         = $delta
        delta_percent = $deltaPercent
    }
}

$jsonPath = Join-Path $OutputDir 'comparison.json'
$csvPath = Join-Path $OutputDir 'comparison.csv'

$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
$rows
