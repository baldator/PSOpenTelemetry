# PSOpenTelemetry

A PowerShell module for OpenTelemetry logging and tracing using .NET libraries.

## Overview

PSOpenTelemetry provides a simplified PowerShell interface for OpenTelemetry logging and tracing. It uses standard .NET libraries and the official OpenTelemetry .NET SDKs to provide tracing and logging capabilities with OTLP export support.

**Key Features:**
- Tracing using `System.Diagnostics.ActivitySource`
- Logging using `Microsoft.Extensions.Logging` bridged to OpenTelemetry
- OTLP export support (gRPC and HTTP/Protobuf)
- Console output for local development
- Simple PowerShell-friendly API

## Requirements

- PowerShell 5.1+
- .NET Framework 4.7.2+ or .NET Core/5+
- Internet access (for downloading NuGet packages)

## Installation

### Step 1: Load Dependencies

First, load the required .NET dependencies:

```powershell
# Download and load required NuGet packages
.\Load-Dependencies.ps1

# Or use the simple version
.\Load-Dependencies-Simple.ps1
```

### Step 2: Import the Module

```powershell
Import-Module .\PSOpenTelemetry.psm1
```

## Usage

### Basic Example

```powershell
# Load dependencies and import module
.\Load-Dependencies.ps1
Import-Module .\PSOpenTelemetry.psm1

# Initialize OpenTelemetry
Initialize-OTel -ServiceName "MyPowerShellScript" -OtlpEndpoint "http://localhost:4317" -Protocol "grpc" -ConsoleOutput $true

# Start a trace
$activity = Start-OTelTrace -Name "MainOperation" -Kind "Internal"

# Add some attributes
$activity.SetTag("operation.type", "demo")
$activity.SetTag("script.version", "1.0.0")

# Write logs
Write-OTelLog -Message "Operation started" -Level "Information"
Write-OTelLog -Message "Processing data..." -Level "Debug"

# Start a child trace
$childActivity = Start-OTelTrace -Name "ChildOperation" -Kind "Client" -ParentActivity $activity
Write-OTelLog -Message "Making API call" -Level "Information"
Stop-OTelTrace -Activity $childActivity

# Stop the main trace
Stop-OTelTrace -Activity $activity
```

### Configuration Options

#### Initialize-OTel Parameters

- **ServiceName** (Required): The name of your service
- **OtlpEndpoint** (Required): OTLP endpoint URL (e.g., "http://localhost:4317")
- **Protocol**: Communication protocol ("grpc" or "http/protobuf", default: "grpc")
- **ConsoleOutput**: Enable console logging ($true/$false, default: $false)

#### Start-OTelTrace Parameters

- **Name** (Required): Name of the operation
- **Kind**: Activity kind ("Internal", "Server", "Client", "Producer", "Consumer", default: "Internal")
- **ParentActivity**: Parent activity for hierarchy

#### Write-OTelLog Parameters

- **Message** (Required): Log message
- **Level**: Log level ("Trace", "Debug", "Information", "Warning", "Error", "Critical", default: "Information")
- **Exception**: Exception object to include
- **Activity**: Activity to associate with the log

## Functions

### Core Functions

- `Initialize-OTel` - Initialize OpenTelemetry configuration
- `Start-OTelTrace` - Start a new trace (Activity/Span)
- `Stop-OTelTrace` - Stop and dispose a trace
- `Write-OTelLog` - Write a log message
- `Get-OTelActivity` - Get current activity

### Aliases

- `Start-Trace` → `Start-OTelTrace`
- `Stop-Trace` → `Stop-OTelTrace`
- `Write-OTLog` → `Write-OTelLog`

## Example Scripts

See `Usage.ps1` for a comprehensive example demonstrating:
- Loading dependencies
- Initializing OpenTelemetry
- Creating traces and logs
- Using aliases
- Error handling

## Troubleshooting

### Common Issues

1. **"Required type is not loaded"**: Run `.\Load-Dependencies.ps1` first
2. **Module not found**: Ensure you're in the correct directory and the .psm1 file exists
3. **OTLP connection errors**: Verify your OTLP endpoint is correct and accessible

### Dependencies

The module requires these NuGet packages:
- `System.Diagnostics.DiagnosticSource` (v8.0.0)
- `OpenTelemetry` (v1.9.0)
- `OpenTelemetry.Exporter.OpenTelemetryProtocol` (v1.9.0)
- `Microsoft.Extensions.Logging` (v8.0.0)
- `Microsoft.Extensions.Logging.Abstractions` (v8.0.0)
- `Microsoft.Extensions.Logging.Console` (v8.0.0)

## Architecture

PSOpenTelemetry uses the following .NET components:

- **Tracing**: `System.Diagnostics.ActivitySource` for creating spans
- **Logging**: `Microsoft.Extensions.Logging.ILogger` for structured logging
- **Export**: `OpenTelemetry.Exporter.OpenTelemetryProtocol` for OTLP export
- **Configuration**: OpenTelemetry .NET SDK for setup and configuration

## Contributing

Contributions are welcome! Please ensure:
- Code follows PowerShell best practices
- Functions include proper help documentation
- Changes maintain backward compatibility

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the example scripts
3. Ensure all dependencies are loaded correctly