# Smoke test for ToastPRP.ps1 development on Linux (no Fallout 4 / Windows required)
$ErrorActionPreference = 'Stop'
$scriptPath = '/workspace/ToastPRP.ps1'

Write-Host "=== ToastPRP Smoke Test ===" -ForegroundColor Cyan

# 1. Syntax validation
$parseErrors = $null
$tokens = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    throw "Syntax errors: $($parseErrors | Out-String)"
}
Write-Host "[PASS] Script parses ($($tokens.Count) tokens)" -ForegroundColor Green

# 2. Function inventory from AST
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
$functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
    ForEach-Object { $_.Name }
Write-Host "[PASS] Found $($functions.Count) functions: $($functions -join ', ')" -ForegroundColor Green

# 3. Wait-ForFile logic (isolated, cross-platform)
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "toastprp-smoke-$(Get-Random)"
$script:data = Join-Path $testRoot 'data'
New-Item -ItemType Directory -Path $script:data -Force | Out-Null
$targetFile = Join-Path $script:data 'test-output.txt'

function Wait-ForFile-Smoke {
    param([string]$FileName, [int]$TimeoutSeconds = 5)
    $startTime = Get-Date
    do {
        if (Test-Path $FileName) { return $true }
        if (((Get-Date) - $startTime).TotalSeconds -ge $TimeoutSeconds) { return $false }
        Start-Sleep -Milliseconds 50
    } while ($true)
}

Start-Job -ScriptBlock {
    param($Path)
    Start-Sleep -Milliseconds 200
    Set-Content -Path $Path -Value 'ready'
} -ArgumentList $targetFile | Out-Null

if (-not (Wait-ForFile-Smoke -FileName $targetFile -TimeoutSeconds 5)) {
    throw 'Wait-ForFile smoke test failed'
}
Write-Host "[PASS] Wait-ForFile polling logic" -ForegroundColor Green

# 4. ManageJson structure (no WinForms dialog)
$script:fo4 = $testRoot
$script:jsonFileName = 'ToastPRP.json'
$script:jsonFilePath = Join-Path $script:fo4 $script:jsonFileName
$script:bsarch = Join-Path $script:fo4 'bsarch.exe'
Set-Content -Path $script:bsarch -Value 'mock'

$jsonContent = @{
    'ESP-WIP'    = @()
    'xEdit'      = '/mock/FO4Edit64.exe'
    'Bsarch'     = $false
    'BsarchPath' = $null
}
$jsonContent | ConvertTo-Json -Depth 10 | Set-Content $script:jsonFilePath

$loaded = Get-Content $script:jsonFilePath -Raw | ConvertFrom-Json
if ($loaded.xEdit -ne '/mock/FO4Edit64.exe') {
    throw 'JSON round-trip failed'
}
Write-Host "[PASS] ToastPRP.json read/write round-trip" -ForegroundColor Green

# 5. PSScriptAnalyzer (errors only)
Import-Module PSScriptAnalyzer
$analyzerErrors = Invoke-ScriptAnalyzer -Path $scriptPath -Severity Error
if ($analyzerErrors.Count -gt 0) {
    throw "PSScriptAnalyzer errors: $($analyzerErrors | Out-String)"
}
Write-Host "[PASS] PSScriptAnalyzer (0 errors)" -ForegroundColor Green

Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
Write-Host "`nAll smoke tests passed. Full E2E requires Windows + Fallout 4 + Creation Kit + FO4Edit." -ForegroundColor Green
