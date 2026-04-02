[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$JobName,

    [string]$ProjectRoot = 'G:\My Drive\BosSys\996_LTSpice\Pwr',
    [string]$CodexRoot = 'G:\My Drive\BosSys\996_LTSpice\Pwr\CODEX',
    [string]$LtspiceExe,
    [switch]$Ascii,
    [switch]$NetlistOnly,
    [switch]$ForceCopy
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

    $normalizedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $normalizedPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-LtspiceExe {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath)) {
            throw "LTspice executable not found: $RequestedPath"
        }
        return (Resolve-NormalizedPath -Path $RequestedPath)
    }

    $candidates = @(
        'C:\Program Files\ADI\LTspice\LTspice.exe',
        'C:\Program Files\LTC\LTspiceXVII\XVIIx64.exe',
        'C:\Program Files\LTC\LTspiceXVII\XVIIx86.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-NormalizedPath -Path $candidate)
        }
    }

    throw 'LTspice executable not found. Pass -LtspiceExe explicitly.'
}

function Join-QuotedArguments {
    param([Parameter(Mandatory = $true)][string[]]$Values)

    $quoted = foreach ($value in $Values) {
        if ($value -match '[\s"]') {
            '"' + ($value -replace '"', '\"') + '"'
        } else {
            $value
        }
    }
    return ($quoted -join ' ')
}

$projectRootResolved = [System.IO.Path]::GetFullPath($ProjectRoot)
$codexRootResolved = [System.IO.Path]::GetFullPath($CodexRoot)
$inputResolved = Resolve-NormalizedPath -Path $InputPath

if (-not (Test-IsUnderRoot -Path $inputResolved -Root $projectRootResolved)) {
    throw "Input must be inside project root: $projectRootResolved"
}

$jobWorkDir = Join-Path $codexRootResolved "work\$JobName"
$jobResultDir = Join-Path $codexRootResolved "results\$JobName"
New-Item -ItemType Directory -Path $jobWorkDir -Force | Out-Null
New-Item -ItemType Directory -Path $jobResultDir -Force | Out-Null

if (-not (Test-IsUnderRoot -Path $jobWorkDir -Root $codexRootResolved)) {
    throw 'Work directory escaped CODEX root.'
}
if (-not (Test-IsUnderRoot -Path $jobResultDir -Root $codexRootResolved)) {
    throw 'Result directory escaped CODEX root.'
}

$workingInput = $inputResolved
if ($ForceCopy -or -not (Test-IsUnderRoot -Path $inputResolved -Root $codexRootResolved)) {
    $destinationPath = Join-Path $jobWorkDir ([System.IO.Path]::GetFileName($inputResolved))
    Copy-Item -LiteralPath $inputResolved -Destination $destinationPath -Force
    $workingInput = Resolve-NormalizedPath -Path $destinationPath
}

$ltspiceExeResolved = Get-LtspiceExe -RequestedPath $LtspiceExe
$workingExtension = [System.IO.Path]::GetExtension($workingInput)
$simulationInput = $workingInput

if ((-not $NetlistOnly) -and $workingExtension.Equals('.asc', [System.StringComparison]::OrdinalIgnoreCase)) {
    Push-Location $jobWorkDir
    try {
        $netlistArgs = Join-QuotedArguments -Values @('-netlist', $workingInput)
        $netlistProcess = Start-Process -FilePath $ltspiceExeResolved -ArgumentList $netlistArgs -WorkingDirectory $jobWorkDir -PassThru -Wait
        $netlistExitCode = [int]$netlistProcess.ExitCode
    } finally {
        Pop-Location
    }

    if ($netlistExitCode -ne 0) {
        throw "LTspice netlist generation failed with code $netlistExitCode"
    }

    $generatedNetlist = [System.IO.Path]::ChangeExtension($workingInput, '.net')
    if (-not (Test-Path -LiteralPath $generatedNetlist)) {
        throw "Expected generated netlist not found: $generatedNetlist"
    }
    $simulationInput = Resolve-NormalizedPath -Path $generatedNetlist
}

$arguments = New-Object System.Collections.Generic.List[string]
if ($NetlistOnly) {
    $arguments.Add('-netlist')
} else {
    $arguments.Add('-b')
    if ($Ascii) {
        $arguments.Add('-ascii')
    }
}
$arguments.Add($simulationInput)

Push-Location $jobWorkDir
try {
    $argumentString = Join-QuotedArguments -Values $arguments
    $process = Start-Process -FilePath $ltspiceExeResolved -ArgumentList $argumentString -WorkingDirectory $jobWorkDir -PassThru -Wait
    $exitCode = [int]$process.ExitCode
} finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    throw "LTspice exited with code $exitCode"
}

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($simulationInput)
$artifactSourceDir = [System.IO.Path]::GetDirectoryName($simulationInput)
$possibleOutputs = @(
    "$baseName.log",
    "$baseName.raw",
    "$baseName.net",
    "$baseName.op.raw"
)

$copiedArtifacts = @()
foreach ($name in $possibleOutputs) {
    $candidate = Join-Path $artifactSourceDir $name
    for ($attempt = 0; $attempt -lt 10 -and -not (Test-Path -LiteralPath $candidate); $attempt++) {
        Start-Sleep -Milliseconds 200
    }
    if (Test-Path -LiteralPath $candidate) {
        $destination = Join-Path $jobResultDir $name
        Copy-Item -LiteralPath $candidate -Destination $destination -Force
        $copiedArtifacts += (Resolve-NormalizedPath -Path $destination)
    }
}

$summary = [pscustomobject]@{
    job_name      = $JobName
    source_input  = $inputResolved
    working_input = $workingInput
    simulation_input = $simulationInput
    ltspice_exe   = $ltspiceExeResolved
    mode          = if ($NetlistOnly) { 'netlist' } elseif ($Ascii) { 'batch_ascii' } else { 'batch' }
    artifacts     = $copiedArtifacts
}

$summaryPath = Join-Path $jobResultDir "$baseName.run.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summary
