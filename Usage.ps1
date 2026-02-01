<# 
.SYNOPSIS
Example script demonstrating how to use the PSOpenTelemetry module.

.DESCRIPTION
This script shows how to:
1. Load the required dependencies
2. Import the PSOpenTelemetry module
3. Initialize OpenTelemetry configuration
4. Start and stop traces
5. Write log messages
6. Use the module in a realistic scenario

.NOTES
This is a demonstration script. In a real scenario, you would:
- Use actual OTLP endpoints
- Handle errors more gracefully
- Add more comprehensive logging and tracing
#>

# Clear any existing OpenTelemetry configuration
Write-Host "=== PSOpenTelemetry Usage Example ===" -ForegroundColor Yellow
Write-Host ""

# Step 1: Load dependencies (only needed once per session)
Write-Host "Step 1: Loading OpenTelemetry dependencies..." -ForegroundColor Cyan
try {
    . .\Load-Dependencies.ps1
    Write-Host "Dependencies loaded successfully!" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to load dependencies: $($_.Exception.Message)"
    Write-Host "Please ensure you have internet access and try again." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Import the module
Write-Host "Step 2: Importing PSOpenTelemetry module..." -ForegroundColor Cyan
try {
    Import-Module .\PSOpenTelemetry.psm1 -Force
    Write-Host "Module imported successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import module: $($_.Exception.Message)"
    exit 1
}

Write-Host ""

# Step 3: Initialize OpenTelemetry
Write-Host "Step 3: Initializing OpenTelemetry..." -ForegroundColor Cyan
$serviceName = "ExamplePowerShellScript"
$otlpEndpoint = "http://localhost:4317"  # Change this to your OTLP endpoint

try {
    Initialize-OTel -ServiceName $serviceName -OtlpEndpoint $otlpEndpoint -Protocol "grpc" -ConsoleOutput $true
    Write-Host "OpenTelemetry initialized!" -ForegroundColor Green
}
catch {
    Write-Warning "OpenTelemetry initialization failed (this is expected if no OTLP endpoint is available): $($_.Exception.Message)"
    Write-Host "Continuing with console-only logging..." -ForegroundColor Yellow
    
    # Initialize with console output only for demonstration
    Initialize-OTel -ServiceName $serviceName -OtlpEndpoint "http://localhost:4317" -Protocol "grpc" -ConsoleOutput $true
}

Write-Host ""

# Step 4: Demonstrate tracing and logging
Write-Host "Step 4: Demonstrating tracing and logging..." -ForegroundColor Cyan

# Start a main trace
Write-Host "Starting main operation trace..." -ForegroundColor Green
$mainTrace = Start-OTelTrace -Name "MainOperation" -Kind "Internal"

if ($mainTrace) {
    # Add some attributes to the trace
    $mainTrace.SetTag("operation.type", "demo")
    $mainTrace.SetTag("script.version", "1.0.0")
    $mainTrace.SetTag("environment", "development")
    
    # Write some logs
    Write-OTelLog -Message "Main operation started" -Level "Information"
    
    # Simulate some work
    Write-Host "Simulating some work..." -ForegroundColor Gray
    Start-Sleep -Milliseconds 500
    
    # Start a child trace
    Write-Host "Starting child operation trace..." -ForegroundColor Green
    $childTrace = Start-OTelTrace -Name "ChildOperation" -Kind "Client" -ParentActivity $mainTrace
    
    if ($childTrace) {
        # Add attributes to child trace
        $childTrace.SetTag("child.operation", "network_call")
        $childTrace.SetTag("target.service", "api.example.com")
        
        Write-OTelLog -Message "Making API call to external service" -Level "Information"
        
        # Simulate API call
        Start-Sleep -Milliseconds 300
        
        # Simulate successful response
        Write-OTelLog -Message "API call completed successfully" -Level "Information"
        
        # Stop child trace
        Stop-OTelTrace -Activity $childTrace
        Write-Host "Child operation completed" -ForegroundColor Green
    }
    
    # Write more logs
    Write-OTelLog -Message "Processing data..." -Level "Debug"
    Start-Sleep -Milliseconds 200
    
    Write-OTelLog -Message "Data processing completed" -Level "Information"
    
    # Simulate a warning
    Write-OTelLog -Message "Low memory warning detected" -Level "Warning"
    
    # Simulate an error (but handle it gracefully)
    try {
        # This would normally be actual error-prone code
        throw [System.Exception]::new("Simulated error for demonstration")
    }
    catch {
        Write-OTelLog -Message "An error occurred during processing" -Level "Error" -Exception $_
        Write-OTelLog -Message "Error handled gracefully" -Level "Information"
    }
    
    # Get current activity for demonstration
    $currentActivity = Get-OTelActivity
    if ($currentActivity) {
        Write-Host "Current activity: $($currentActivity.DisplayName)" -ForegroundColor Cyan
    }
    
    # Stop main trace
    Stop-OTelTrace -Activity $mainTrace
    Write-Host "Main operation completed" -ForegroundColor Green
}
else {
    Write-Warning "Failed to start main trace"
}

Write-Host ""

# Step 5: Demonstrate aliases
Write-Host "Step 5: Demonstrating aliases..." -ForegroundColor Cyan
$aliasTrace = Start-Trace -Name "AliasDemo" -Kind "Internal"
Write-OTLog -Message "Using aliases for convenience" -Level "Information"
Stop-Trace -Activity $aliasTrace
Write-Host "Alias demo completed" -ForegroundColor Green

Write-Host ""

# Step 6: Cleanup demonstration
Write-Host "Step 6: Cleanup..." -ForegroundColor Cyan
Write-OTelLog -Message "Script execution completed successfully" -Level "Information"

# Show available functions
Write-Host "Available PSOpenTelemetry functions:" -ForegroundColor Yellow
Get-Command -Module PSOpenTelemetry | Select-Object -ExpandProperty Name | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }

Write-Host ""
Write-Host "Available aliases:" -ForegroundColor Yellow
Get-Alias | Where-Object { $_.Definition -like "*OTel*" } | ForEach-Object { Write-Host "  - $($_.Name) -> $($_.Definition)" -ForegroundColor Cyan }

Write-Host ""
Write-Host "=== Example completed! ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "To use PSOpenTelemetry in your own scripts:" -ForegroundColor Green
Write-Host "1. Run: . .\Load-Dependencies.ps1" -ForegroundColor White
Write-Host "2. Run: Import-Module .\PSOpenTelemetry.psm1" -ForegroundColor White
Write-Host "3. Call: Initialize-OTel -ServiceName 'YourService' -OtlpEndpoint 'your-endpoint'" -ForegroundColor White
Write-Host "4. Use: Start-OTelTrace, Write-OTelLog, Stop-OTelTrace as needed" -ForegroundColor White