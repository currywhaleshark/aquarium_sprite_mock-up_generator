param(
    [string]$Filter = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$logDir = Join-Path $repoRoot "tmp\godot-logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Find-Godot {
    $candidates = @("godot", "godot4", "godot4.6")
    foreach ($candidate in $candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command -ne $null) {
            return $command.Source
        }
    }
    throw "Godot executable not found in PATH. Tried: $($candidates -join ', ')"
}

function Get-TestScenes {
    param([string]$NameFilter)

    $scenesDir = Join-Path $repoRoot "scenes"
    if (-not (Test-Path -LiteralPath $scenesDir)) {
        throw "Scenes directory not found: $scenesDir"
    }

    $allTests = Get-ChildItem -LiteralPath $scenesDir -Filter "*Test.tscn" |
        Sort-Object Name

    if ([string]::IsNullOrWhiteSpace($NameFilter)) {
        return $allTests
    }

    $matches = $allTests | Where-Object {
        $_.Name -like "*$NameFilter*" -or
        $_.BaseName -like "*$NameFilter*" -or
        $_.FullName -like "*$NameFilter*"
    }

    if (-not $matches -or $matches.Count -eq 0) {
        throw "No Godot test scene matched filter: $NameFilter"
    }

    return $matches
}

$godot = Find-Godot
$tests = @(Get-TestScenes -NameFilter $Filter)
if ($tests.Count -eq 0) {
    throw "No Godot test scenes found."
}

$failed = @()
foreach ($test in $tests) {
    $scenePath = "scenes/$($test.Name)"
    $logPath = Join-Path $logDir "$($test.BaseName).log"
    Write-Host "RUN $scenePath"

    & $godot --headless --disable-crash-handler --path $repoRoot --log-file $logPath $scenePath
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $failed += "$scenePath exited with $exitCode; log: $logPath"
        Write-Host "FAIL $scenePath"
    } else {
        Write-Host "PASS $scenePath"
    }
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Godot CLI test failures:"
    foreach ($failure in $failed) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "Godot CLI tests passed: $($tests.Count)"
