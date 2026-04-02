[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Resolve-Path -LiteralPath $Path
    return [System.IO.Path]::GetFullPath($resolved.Path)
}

$logResolved = Resolve-NormalizedPath -Path $LogPath
$lines = Get-Content -LiteralPath $logResolved

$measurementMap = [ordered]@{}
$warnings = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]

foreach ($line in $lines) {
    if ($line -match '^\s*([A-Za-z0-9_.\-]+)\s*:\s*([^\s].*?)\s*$') {
        $name = $matches[1]
        $rawValue = $matches[2]
        $numericValue = $null

        if ($rawValue -match '^[+-]?\d+(\.\d+)?([eE][+-]?\d+)?$') {
            $numericValue = [double]$rawValue
        }

        $measurementMap[$name] = [pscustomobject]@{
            raw     = $rawValue
            numeric = $numericValue
        }
        continue
    }

    if ($line -match '(?i)\bwarning\b') {
        $warnings.Add($line)
    }
    if ($line -match '(?i)\berror\b|\bfatal\b') {
        $errors.Add($line)
    }
}

if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($logResolved, '.measurements.json')
}

$result = [pscustomobject]@{
    log_path          = $logResolved
    measurement_count = $measurementMap.Count
    measurements      = $measurementMap
    warnings          = $warnings
    errors            = $errors
    ok                = ($errors.Count -eq 0)
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$result
