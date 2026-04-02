[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RawPath,

    [string[]]$TraceNames = @('time'),
    [string]$OutputCsv,
    [string]$OutputPng,
    [int]$MaxRows = 5000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Resolve-Path -LiteralPath $Path
    [System.IO.Path]::GetFullPath($resolved.Path)
}

function Convert-ToDouble {
    param([string]$Value)

    $number = 0.0
    if ([double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return $number
    }
    return $null
}

$rawResolved = Resolve-NormalizedPath -Path $RawPath
if (-not $OutputCsv) {
    $OutputCsv = [System.IO.Path]::ChangeExtension($rawResolved, '.selected.csv')
}

$reader = [System.IO.StreamReader]::new($rawResolved)
try {
    $variables = New-Object System.Collections.Generic.List[object]
    $valueSectionFound = $false
    $pointCount = 0

    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ($line -match '^No\.\s+Points:\s+(\d+)') {
            $pointCount = [int]$matches[1]
            continue
        }
        if ($line -eq 'Variables:') {
            while (-not $reader.EndOfStream) {
                $variableLine = $reader.ReadLine()
                if ($variableLine -eq 'Values:') {
                    $valueSectionFound = $true
                    break
                }
                $trimmed = $variableLine.Trim()
                if (-not $trimmed) { continue }
                $parts = $trimmed -split '\s+'
                if ($parts.Length -ge 3) {
                    $variables.Add([pscustomobject]@{
                        index = [int]$parts[0]
                        name  = $parts[1]
                        kind  = $parts[2]
                    })
                }
            }
            break
        }
    }

    if (-not $valueSectionFound -or $variables.Count -eq 0) {
        throw 'ASCII LTspice raw format not recognized. Use LTspice -ascii output.'
    }

    $selectedNames = if ($TraceNames.Count -eq 0) { $variables.name } else { $TraceNames }
    $selectedSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $selectedNames) {
        [void]$selectedSet.Add($name)
    }

    $selectedVariables = @($variables | Where-Object { $selectedSet.Contains($_.name) })
    if ($selectedVariables.Count -eq 0) {
        throw 'None of the requested traces were found in the raw file.'
    }

    $timeName = if ($selectedSet.Contains('time')) { 'time' } else { $selectedVariables[0].name }
    $step = 1
    if ($MaxRows -gt 0 -and $pointCount -gt $MaxRows) {
        $step = [int][Math]::Ceiling($pointCount / [double]$MaxRows)
    }

    $selectedIndexMap = @{}
    foreach ($variable in $selectedVariables) {
        $selectedIndexMap[$variable.index] = $variable.name
    }

    $records = New-Object System.Collections.Generic.List[object]
    $currentPoint = -1
    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $parts = $line.Trim() -split '\s+'
        if ($parts.Length -lt 2) { continue }
        if ($parts[0] -notmatch '^\d+$') { continue }

        $currentPoint = [int]$parts[0]
        $keepPoint = (($currentPoint % $step) -eq 0)
        $row = [ordered]@{}
        if ($keepPoint -and $selectedIndexMap.ContainsKey(0)) {
            $row[$selectedIndexMap[0]] = $parts[1]
        }

        for ($variableIndex = 1; $variableIndex -lt $variables.Count; $variableIndex++) {
            if ($reader.EndOfStream) { break }
            $valueLine = $reader.ReadLine()
            if ($keepPoint -and $selectedIndexMap.ContainsKey($variableIndex)) {
                $valueParts = $valueLine.Trim() -split '\s+'
                if ($valueParts.Length -ge 1) {
                    $row[$selectedIndexMap[$variableIndex]] = $valueParts[0]
                }
            }
        }

        if ($keepPoint) {
            $records.Add([pscustomobject]$row)
        }
    }

    $records | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

    $pngStatus = 'not_requested'
    if ($OutputPng) {
        Add-Type -AssemblyName System.Windows.Forms.DataVisualization
        $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        $chart.Width = 1600
        $chart.Height = 900
        [void]$chart.ChartAreas.Add('Main')
        $chart.ChartAreas['Main'].AxisX.Title = $timeName
        $chart.ChartAreas['Main'].AxisY.Title = 'value'

        foreach ($name in $selectedNames) {
            if ($name -eq $timeName) { continue }
            $series = $chart.Series.Add($name)
            $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
            foreach ($row in $records) {
                if ($row.PSObject.Properties.Name -notcontains $timeName) { continue }
                if ($row.PSObject.Properties.Name -notcontains $name) { continue }
                $x = Convert-ToDouble -Value ([string]$row.$timeName)
                $y = Convert-ToDouble -Value ([string]$row.$name)
                if ($null -ne $x -and $null -ne $y) {
                    [void]$series.Points.AddXY($x, $y)
                }
            }
        }

        $chart.SaveImage($OutputPng, 'Png')
        $pngStatus = 'written'
    }

    [pscustomobject]@{
        raw_path     = $rawResolved
        variables    = $variables
        source_rows  = $pointCount
        rows         = $records.Count
        row_step     = $step
        csv_path     = $OutputCsv
        png_path     = $OutputPng
        png_status   = $pngStatus
    }
}
finally {
    $reader.Dispose()
}
