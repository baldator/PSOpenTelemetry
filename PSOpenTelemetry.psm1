<# 
.SYNOPSIS
PowerShell module for OpenTelemetry logging and tracing using .NET libraries.

.DESCRIPTION
This module provides a simplified PowerShell interface for OpenTelemetry logging and tracing.
It uses standard .NET libraries and the official OpenTelemetry .NET SDKs to provide tracing and logging
capabilities with OTLP export support.

.NOTES
Requires the OpenTelemetry .NET dependencies to be loaded. Use Load-Dependencies.ps1 to load them.
#>

# Ensure required types are available
$requiredTypes = @(
    'System.Diagnostics.ActivitySource',
    'OpenTelemetry.Trace.TracerProviderBuilder',
    'OpenTelemetry.Exporter.OtlpExporter',
    'Microsoft.Extensions.Logging.ILogger'
)

foreach ($type in $requiredTypes) {
    try {
        $loaded = [System.Type]::GetType($type)
        if (-not $loaded) {
            Write-Warning "Required type $type is not loaded. Please run Load-Dependencies.ps1 first."
            break
        }
    }
    catch {
        Write-Warning ("Failed to verify type {0}: {1}" -f $type, $_.Exception.Message)
        break
    }
}

# Global variables to store OpenTelemetry components
$script:GlobalTracerProvider = $null
$script:GlobalLoggerFactory = $null
$script:GlobalActivitySource = $null
$script:GlobalLogger = $null
$script:CurrentActivity = $null

<# 
.SYNOPSIS
Initializes OpenTelemetry configuration for the current PowerShell session.

.DESCRIPTION
Sets up the TracerProvider and LoggerFactory with the specified configuration.
This function must be called before using other OpenTelemetry functions.

.PARAMETER ServiceName
The name of the service for telemetry purposes.

.PARAMETER OtlpEndpoint
The OTLP endpoint URL where telemetry data will be sent.

.PARAMETER Protocol
The protocol to use for OTLP communication. Valid values are 'grpc' and 'http/protobuf'.

.PARAMETER ConsoleOutput
If $true, enables console output for logs in addition to OTLP export.

.EXAMPLE
Initialize-OTel -ServiceName "MyPowerShellScript" -OtlpEndpoint "http://localhost:4317" -Protocol "grpc"

.EXAMPLE
Initialize-OTel -ServiceName "MyApp" -OtlpEndpoint "http://otel-collector:4318" -Protocol "http/protobuf" -ConsoleOutput $true

.OUTPUTS
None
#>
function Initialize-OTel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        
        [Parameter(Mandatory = $true)]
        [string]$OtlpEndpoint,
        
        [Parameter()]
        [ValidateSet('grpc', 'http/protobuf')]
        [string]$Protocol = 'grpc',
        
        [Parameter()]
        [switch]$ConsoleOutput = $false
    )
    
    try {
        # Clean up existing configuration if any
        if ($script:GlobalTracerProvider) {
            $script:GlobalTracerProvider.Dispose()
            $script:GlobalTracerProvider = $null
        }
        
        if ($script:GlobalLoggerFactory) {
            $script:GlobalLoggerFactory.Dispose()
            $script:GlobalLoggerFactory = $null
        }
        
        # Create ActivitySource for tracing
        $script:GlobalActivitySource = New-Object System.Diagnostics.ActivitySource $ServiceName
        
        # Build TracerProvider
        $tracerProviderBuilder = [OpenTelemetry.Trace.TracerProviderBuilderExtensions]::NewTracerProviderBuilder([OpenTelemetry.TelemetryConfiguration]::CreateDefault())
        
        # Add OTLP exporter
        $otlpExporterOptions = New-Object OpenTelemetry.Exporter.OtlpExporterOptions
        $otlpExporterOptions.Endpoint = [System.Uri]::new($OtlpEndpoint)
        
        if ($Protocol -eq 'http/protobuf') {
            $otlpExporterOptions.Protocol = [OpenTelemetry.Exporter.OtlpExportProtocol]::HttpProtobuf
        } else {
            $otlpExporterOptions.Protocol = [OpenTelemetry.Exporter.OtlpExportProtocol]::Grpc
        }
        
        $tracerProviderBuilder = [OpenTelemetry.Trace.TracerProviderBuilderExtensions]::AddOtlpExporter($tracerProviderBuilder, $otlpExporterOptions)
        
        # Add ActivitySource
        $tracerProviderBuilder = [OpenTelemetry.Trace.TracerProviderBuilderExtensions]::AddSource($tracerProviderBuilder, $ServiceName)
        
        # Build and store TracerProvider
        $script:GlobalTracerProvider = $tracerProviderBuilder.Build()
        
        # Build LoggerFactory
        $loggerFactoryBuilder = [Microsoft.Extensions.Logging.LoggingFactoryExtensions]::CreateLoggingBuilder([Microsoft.Extensions.Logging.LoggingBuilder]::new([Microsoft.Extensions.Logging.LoggerFactory]::new()))
        
        # Add console logging if requested
        if ($ConsoleOutput) {
            $loggerFactoryBuilder = [Microsoft.Extensions.Logging.ConsoleLoggerExtensions]::AddConsole($loggerFactoryBuilder)
        }
        
        # Add OpenTelemetry logging
        $loggerFactoryBuilder = [OpenTelemetry.Extensions.Logging.OpenTelemetryLoggingExtensions]::AddOpenTelemetry($loggerFactoryBuilder)
        
        # Configure OpenTelemetry logging
        $openTelemetryLoggerOptions = New-Object OpenTelemetry.Extensions.Logging.OpenTelemetryLoggerOptions
        $openTelemetryLoggerOptions.IncludeFormattedMessage = $true
        $openTelemetryLoggerOptions.IncludeScopes = $true
        $openTelemetryLoggerOptions.ParseStateValues = $true
        $openTelemetryLoggerOptions.IncludeActivityId = $true
        $openTelemetryLoggerOptions.ActivityIdFormat = [OpenTelemetry.Extensions.Logging.ActivityIdFormat]::Hierarchical
        
        # Apply configuration
        [OpenTelemetry.Extensions.Logging.OpenTelemetryLoggingExtensions]::AddOpenTelemetry($loggerFactoryBuilder, $openTelemetryLoggerOptions)
        
        # Build and store LoggerFactory
        $script:GlobalLoggerFactory = $loggerFactoryBuilder.Build()
        
        # Create a logger for the service
        $script:GlobalLogger = $script:GlobalLoggerFactory.CreateLogger($ServiceName)
        
        Write-Host "OpenTelemetry initialized successfully!" -ForegroundColor Green
        Write-Host "  Service Name: $ServiceName" -ForegroundColor Cyan
        Write-Host "  OTLP Endpoint: $OtlpEndpoint" -ForegroundColor Cyan
        Write-Host "  Protocol: $Protocol" -ForegroundColor Cyan
        if ($ConsoleOutput) {
            Write-Host "  Console Output: Enabled" -ForegroundColor Cyan
        } else {
            Write-Host "  Console Output: Disabled" -ForegroundColor Cyan
        }
        
    }
    catch {
        Write-Error "Failed to initialize OpenTelemetry: $($_.Exception.Message)"
        throw
    }
}

<# 
.SYNOPSIS
Starts a new OpenTelemetry trace (Activity/Span).

.DESCRIPTION
Creates and starts a new Activity (span) for tracing purposes. This function returns
an Activity object that should be passed to Stop-OTelTrace when the operation is complete.

.PARAMETER Name
The name of the operation being traced.

.PARAMETER Kind
The kind of activity. Valid values are 'Internal', 'Server', 'Client', 'Producer', 'Consumer'.

.PARAMETER ParentActivity
Optional parent activity to create a hierarchy of spans.

.EXAMPLE
$activity = Start-OTelTrace -Name "DatabaseQuery" -Kind "Client"

.EXAMPLE
$activity = Start-OTelTrace -Name "ProcessData" -Kind "Internal" -ParentActivity $parentActivity

.OUTPUTS
System.Diagnostics.Activity
#>
function Start-OTelTrace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter()]
        [ValidateSet('Internal', 'Server', 'Client', 'Producer', 'Consumer')]
        [string]$Kind = 'Internal',
        
        [Parameter()]
        [System.Diagnostics.Activity]$ParentActivity = $null
    )
    
    if (-not $script:GlobalActivitySource) {
        Write-Warning "OpenTelemetry not initialized. Please call Initialize-OTel first."
        return $null
    }
    
    try {
        # Set parent activity if provided
        if ($ParentActivity) {
            [System.Diagnostics.Activity]::Current = $ParentActivity
        }
        
        # Create activity kind enum
        $activityKind = [System.Diagnostics.ActivityKind]::$Kind
        
        # Start the activity
        $activity = $script:GlobalActivitySource.StartActivity($Name, $activityKind)
        
        if ($activity) {
            $activity.Start()
            $script:CurrentActivity = $activity
            Write-Verbose "Started trace: $($activity.DisplayName)"
        }
        
        return $activity
    }
    catch {
        Write-Error "Failed to start trace: $($_.Exception.Message)"
        return $null
    }
}

<# 
.SYNOPSIS
Stops and disposes an OpenTelemetry trace (Activity/Span).

.DESCRIPTION
Stops the specified activity and disposes of it. If no activity is specified,
it will stop the current activity.

.PARAMETER Activity
The activity to stop. If not specified, stops the current activity.

.EXAMPLE
Stop-OTelTrace -Activity $activity

.EXAMPLE
Stop-OTelTrace

.OUTPUTS
None
#>
function Stop-OTelTrace {
    param(
        [Parameter()]
        [System.Diagnostics.Activity]$Activity = $null
    )
    
    try {
        $activityToStop = if ($Activity) { $Activity } else { $script:CurrentActivity }
        
        if ($activityToStop) {
            $activityToStop.Stop()
            $activityToStop.Dispose()
            Write-Verbose "Stopped trace: $($activityToStop.DisplayName)"
            
            # Clear current activity if we stopped it
            if ($Activity -eq $null) {
                $script:CurrentActivity = $null
            }
        }
        else {
            Write-Warning "No activity to stop"
        }
    }
    catch {
        Write-Error "Failed to stop trace: $($_.Exception.Message)"
    }
}

<# 
.SYNOPSIS
Writes a log message through OpenTelemetry.

.DESCRIPTION
Writes a log message using the configured OpenTelemetry logger. The log will be
sent to both the console (if configured) and the OTLP endpoint.

.PARAMETER Message
The log message to write.

.PARAMETER Level
The log level. Valid values are 'Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical'.

.PARAMETER Exception
Optional exception object to include in the log.

.PARAMETER Activity
Optional activity to associate with the log message.

.EXAMPLE
Write-OTelLog -Message "Operation completed successfully" -Level "Information"

.EXAMPLE
Write-OTelLog -Message "An error occurred" -Level "Error" -Exception $Error[0]

.OUTPUTS
None
#>
function Write-OTelLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Information',
        
        [Parameter()]
        [System.Exception]$Exception = $null,
        
        [Parameter()]
        [System.Diagnostics.Activity]$Activity = $null
    )
    
    if (-not $script:GlobalLogger) {
        Write-Warning "OpenTelemetry not initialized. Please call Initialize-OTel first."
        return
    }
    
    try {
        # Set current activity if provided
        if ($Activity) {
            [System.Diagnostics.Activity]::Current = $Activity
        }
        
        # Create log level enum
        $logLevel = [Microsoft.Extensions.Logging.LogLevel]::$Level
        
        # Write the log
        if ($Exception) {
            $script:GlobalLogger.Log($logLevel, $Exception, $Message)
        } else {
            $script:GlobalLogger.Log($logLevel, $Message)
        }
        
        Write-Verbose "Logged message: $Message (Level: $Level)"
    }
    catch {
        Write-Error "Failed to write log: $($_.Exception.Message)"
    }
}

<# 
.SYNOPSIS
Gets the current OpenTelemetry activity.

.DESCRIPTION
Returns the currently active activity, which can be used for correlation
or to pass as a parent to new activities.

.EXAMPLE
$currentActivity = Get-OTelActivity

.OUTPUTS
System.Diagnostics.Activity
#>
function Get-OTelActivity {
    return [System.Diagnostics.Activity]::Current
}

# Create aliases for convenience
Set-Alias -Name 'Start-Trace' -Value 'Start-OTelTrace'
Set-Alias -Name 'Stop-Trace' -Value 'Stop-OTelTrace'
Set-Alias -Name 'Write-OTLog' -Value 'Write-OTelLog'

Export-ModuleMember -Function Initialize-OTel, Start-OTelTrace, Stop-OTelTrace, Write-OTelLog, Get-OTelActivity
Export-ModuleMember -Alias Start-Trace, Stop-Trace, Write-OTLog