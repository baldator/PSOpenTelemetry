@{
    RootModule = 'PSOpenTelemetry.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b8f9e1d2-4c6a-4f8e-9b2a-7c3d5e1f8a9b'
    Author = 'Your Name'
    CompanyName = 'Your Company'
    Copyright = '(c) 2025 Your Company. All rights reserved.'
    Description = 'PowerShell module for OpenTelemetry logging and tracing using .NET libraries'
    PowerShellVersion = '5.1'
    DotNetFrameworkVersion = '4.7.2'
    
    # Functions to export
    FunctionsToExport = @(
        'Initialize-OTel',
        'Start-OTelTrace', 
        'Stop-OTelTrace',
        'Write-OTelLog',
        'Get-OTelActivity'
    )
    
    # Aliases to export
    AliasesToExport = @(
        'Start-Trace',
        'Stop-Trace', 
        'Write-OTLog'
    )
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('OpenTelemetry', 'Tracing', 'Logging', 'OTLP', 'Observability')
            LicenseUri = 'https://github.com/yourorg/PSOpenTelemetry/blob/main/LICENSE'
            ProjectUri = 'https://github.com/yourorg/PSOpenTelemetry'
            ReleaseNotes = 'Initial release of PSOpenTelemetry module'
        }
    }
}