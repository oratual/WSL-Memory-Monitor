# Test Runner - Executes all unit tests

$ErrorActionPreference = "Stop"

Write-Host @"

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       WSL MEMORY MONITOR - UNIT TEST RUNNER              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

$testFiles = Get-ChildItem "$PSScriptRoot/Unit" -Filter "*.ps1"
$totalTests = 0
$passedTests = 0
$failedTests = 0

Write-Host "Found $($testFiles.Count) test files`n" -ForegroundColor Yellow

foreach ($testFile in $testFiles) {
    Write-Host "Running $($testFile.Name)..." -ForegroundColor Cyan

    try {
        & $testFile.FullName
        $passedTests++
    } catch {
        Write-Host "  ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failedTests++
    }

    $totalTests++
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " TEST SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Total Test Files: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Green" })
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

if ($failedTests -eq 0) {
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some tests failed" -ForegroundColor Red
    exit 1
}
