<# 
.SYNOPSIS
Test runner script for PSOpenTelemetry module using Pester 5.

.DESCRIPTION
This script installs Pester (if missing) and runs the unit and integration tests.
It supports running tests with different tags to separate unit and integration tests.

.PARAMETER TestType
The type of tests to run. Valid values are 'Unit', 'Integration', or 'All'.

.PARAMETER IncludeCoverage
If $true, includes code coverage analysis in the test run.

.PARAMETER OutputFile
Optional path to save test results output file.

.EXAMPLE
.\Invoke-Tests.ps1 -TestType Unit

.EXAMPLE
.\Invoke-Tests.ps1 -TestType Integration -IncludeCoverage $true

.EXAMPLE
.\Invoke-Tests.ps1 -TestType All -OutputFile "TestResults.xml"

.NOTES
Requires PowerShell 5.1+ and internet access to download Pester if not installed.
#>
param(
    [Parameter()]
    [ValidateSet('Unit', 'Integration', 'All')]
    [string]$TestType = 'All',
    
    [Parameter()]
    [switch]$IncludeCoverage = $false,
    
    [Parameter()]
    [string]$OutputFile = ''
)

$ErrorActionPreference = 'Stop'

# Script directory and test paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testsDir = Join-Path $scriptDir 'Tests'
$unitTestFile = Join-Path $testsDir 'PSOpenTelemetry.Unit.Tests.ps1'
$integrationTestFile = Join-Path $testsDir 'PSOpenTelemetry.Integration.Tests.ps1'

# Colors for output
$colorInfo = 'Cyan'
$colorSuccess = 'Green'
$colorWarning = 'Yellow'
$colorError = 'Red'

Write-Host "PSOpenTelemetry Test Runner" -ForegroundColor $colorInfo
Write-Host "============================" -ForegroundColor $colorInfo
Write-Host ""

# Check if Pester is installed
Write-Host "Checking Pester installation..." -ForegroundColor $colorInfo
$pesterInstalled = Get-Module -ListAvailable -Name Pester

if (-not $pesterInstalled) {
    Write-Host "Pester not found. Installing Pester..." -ForegroundColor $colorWarning
    
    try {
        # Install Pester from PowerShell Gallery
        Install-Module -Name Pester -Scope CurrentUser -Force -AllowClobber
        Write-Host "Pester installed successfully!" -ForegroundColor $colorSuccess
    }
    catch {
        Write-Host "Failed to install Pester: $($_.Exception.Message)" -ForegroundColor $colorError
        Write-Host "Please install Pester manually with: Install-Module -Name Pester -Scope CurrentUser -Force" -ForegroundColor $colorWarning
        exit 1
    }
}
else {
    Write-Host "Pester is already installed." -ForegroundColor $colorSuccess
}

# Import Pester
Import-Module Pester -Force

# Verify test files exist
Write-Host "Verifying test files..." -ForegroundColor $colorInfo
$testFiles = @()

if ($TestType -eq 'Unit' -or $TestType -eq 'All') {
    if (Test-Path $unitTestFile) {
        $testFiles += $unitTestFile
        Write-Host "✓ Unit tests found" -ForegroundColor $colorSuccess
    }
    else {
        Write-Host "✗ Unit test file not found: $unitTestFile" -ForegroundColor $colorError
    }
}

if ($TestType -eq 'Integration' -or $TestType -eq 'All') {
    if (Test-Path $integrationTestFile) {
        $testFiles += $integrationTestFile
        Write-Host "✓ Integration tests found" -ForegroundColor $colorSuccess
    }
    else {
        Write-Host "✗ Integration test file not found: $integrationTestFile" -ForegroundColor $colorError
    }
}

if (-not $testFiles) {
    Write-Host "No test files found. Exiting." -ForegroundColor $colorError
    exit 1
}

Write-Host ""

# Configure test parameters
$testParams = @{
    Path = $testFiles
    PassThru = $true
    Strict = $true
    Verbose = $true
}

# Add coverage if requested
if ($IncludeCoverage) {
    Write-Host "Code coverage enabled." -ForegroundColor $colorInfo
    $modulePath = Join-Path $scriptDir 'PSOpenTelemetry.psm1'
    if (Test-Path $modulePath) {
        $testParams.CodeCoverage = $modulePath
        Write-Host "✓ Code coverage will include: $modulePath" -ForegroundColor $colorSuccess
    }
    else {
        Write-Host "✗ Module file not found for coverage: $modulePath" -ForegroundColor $colorWarning
    }
    Write-Host ""
}

# Run tests
Write-Host "Running tests..." -ForegroundColor $colorInfo
Write-Host "================" -ForegroundColor $colorInfo

try {
    $testResults = Invoke-Pester @testParams
    
    # Display results
    Write-Host ""
    Write-Host "Test Results Summary:" -ForegroundColor $colorInfo
    Write-Host "=====================" -ForegroundColor $colorInfo
    
    $totalTests = $testResults.TotalCount
    $passedTests = $testResults.PassedCount
    $failedTests = $testResults.FailedCount
    $skippedTests = $testResults.SkippedCount
    
    Write-Host "Total Tests: $totalTests" -ForegroundColor $colorInfo
    Write-Host "Passed: $passedTests" -ForegroundColor $colorSuccess
    Write-Host "Failed: $failedTests" -ForegroundColor $colorError
    Write-Host "Skipped: $skippedTests" -ForegroundColor $colorWarning
    
    if ($IncludeCoverage -and $testResults.CodeCoverage) {
        Write-Host ""
        Write-Host "Code Coverage:" -ForegroundColor $colorInfo
        Write-Host "==============" -ForegroundColor $colorInfo
        Write-Host "Coverage: $($testResults.CodeCoverage.CoveragePercent.ToString('F2'))%" -ForegroundColor $colorInfo
        Write-Host "Commands Executed: $($testResults.CodeCoverage.NumberOfCommandsExecuted)" -ForegroundColor $colorInfo
        Write-Host "Commands Missed: $($testResults.CodeCoverage.NumberOfCommandsMissed)" -ForegroundColor $colorInfo
    }
    
    # Save results if requested
    if ($OutputFile) {
        Write-Host ""
        Write-Host "Saving test results to: $OutputFile" -ForegroundColor $colorInfo
        
        # Create output directory if it doesn't exist
        $outputDir = Split-Path $OutputFile -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        # Export results in NUnit format (commonly used for CI/CD)
        $testResults | Export-NUnitReport -Path $OutputFile
        Write-Host "✓ Test results saved successfully!" -ForegroundColor $colorSuccess
    }
    
    # Determine exit code
    if ($failedTests -gt 0) {
        Write-Host ""
        Write-Host "Some tests failed. Exiting with error code 1." -ForegroundColor $colorError
        exit 1
    }
    else {
        Write-Host ""
        Write-Host "All tests passed! Exiting with success code 0." -ForegroundColor $colorSuccess
        exit 0
    }
}
catch {
    Write-Host ""
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor $colorError
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor $colorError
    exit 1
}

<# 
.SYNOPSIS
Helper function to run specific test types.

.DESCRIPTION
This function provides a convenient way to run specific test types with common configurations.

.EXAMPLE
Run-UnitTests

.EXAMPLE
Run-IntegrationTests -IncludeCoverage

.EXAMPLE
Run-AllTests -OutputFile "Results.xml"
#>

function Run-UnitTests {
    param(
        [switch]$IncludeCoverage = $false,
        [string]$OutputFile = ''
    )
    
    $PSBoundParameters.TestType = 'Unit'
    . $MyInvocation.MyCommand.Path @PSBoundParameters
}

function Run-IntegrationTests {
    param(
        [switch]$IncludeCoverage = $false,
        [string]$OutputFile = ''
    )
    
    $PSBoundParameters.TestType = 'Integration'
    . $MyInvocation.MyCommand.Path @PSBoundParameters
}

function Run-AllTests {
    param(
        [switch]$IncludeCoverage = $false,
        [string]$OutputFile = ''
    )
    
    $PSBoundParameters.TestType = 'All'
    . $MyInvocation.MyCommand.Path @PSBoundParameters
}