<# 
.SYNOPSIS
Unit tests for PSOpenTelemetry module using Pester 5.

.DESCRIPTION
These tests verify the logic of PowerShell wrapper functions without relying on the full OTel pipeline.
They use mocking to isolate the functions being tested.

.NOTES
Requires Pester 5+ for testing framework.
#>

BeforeAll {
    # Import the module for testing
    $modulePath = Join-Path $PSScriptRoot '..\PSOpenTelemetry.psm1'
    Import-Module $modulePath -Force -ErrorAction Stop
    
    # Mock the dependency loading to avoid actual NuGet downloads
    Mock Write-Warning { } -ParameterFilter { $Message -like "*Required type*" }
    Mock Write-Warning { } -ParameterFilter { $Message -like "*Failed to verify type*" }
}

Describe 'Initialize-OTel Unit Tests' {
    Context 'Parameter Validation' {
        It 'Should require ServiceName parameter' {
            { Initialize-OTel -OtlpEndpoint 'http://localhost:4317' } | Should -Throw
        }
        
        It 'Should require OtlpEndpoint parameter' {
            { Initialize-OTel -ServiceName 'TestService' } | Should -Throw
        }
        
        It 'Should accept valid Protocol values' {
            { Initialize-OTel -ServiceName 'TestService' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' } | Should -Not -Throw
            { Initialize-OTel -ServiceName 'TestService' -OtlpEndpoint 'http://localhost:4317' -Protocol 'http/protobuf' } | Should -Not -Throw
        }
        
        It 'Should reject invalid Protocol values' {
            { Initialize-OTel -ServiceName 'TestService' -OtlpEndpoint 'http://localhost:4317' -Protocol 'invalid' } | Should -Throw
        }
        
        It 'Should accept valid Log Level values' {
            { Initialize-OTel -ServiceName 'TestService' -OtlpEndpoint 'http://localhost:4317' -ConsoleOutput:$true } | Should -Not -Throw
            { Initialize-OTel -ServiceName 'TestService' -OtlpEndpoint 'http://localhost:4317' -ConsoleOutput:$false } | Should -Not -Throw
        }
    }
    
    Context 'Global Variable Management' {
        BeforeEach {
            # Reset global variables before each test
            $script:GlobalTracerProvider = $null
            $script:GlobalLoggerFactory = $null
            $script:GlobalActivitySource = $null
            $script:GlobalLogger = $null
            $script:CurrentActivity = $null
        }
        
        It 'Should create GlobalActivitySource when initialized' {
            # Mock the .NET types to avoid actual instantiation
            Mock New-Object { [PSCustomObject]@{ Name = 'TestService' } } -ParameterFilter { $TypeName -eq 'System.Diagnostics.ActivitySource' }
            Mock New-Object { [PSCustomObject]@{} } -ParameterFilter { $TypeName -eq 'OpenTelemetry.Exporter.OtlpExporterOptions' }
            Mock New-Object { [PSCustomObject]@{} } -ParameterFilter { $TypeName -eq 'OpenTelemetry.Extensions.Logging.OpenTelemetryLoggerOptions' }
            Mock New-Object { [PSCustomObject]@{} } -ParameterFilter { $TypeName -eq 'System.Uri' }
            
            # Mock static method calls
            Mock [OpenTelemetry.Trace.TracerProviderBuilderExtensions]::NewTracerProviderBuilder { [PSCustomObject]@{} }
            Mock [OpenTelemetry.Trace.TracerProviderBuilderExtensions]::AddOtlpExporter { [PSCustomObject]@{} }
            Mock [OpenTelemetry.Trace.TracerProviderBuilderExtensions]::AddSource { [PSCustomObject]@{} }
            Mock [OpenTelemetry.Trace.TracerProviderBuilderExtensions]::Build { [PSCustomObject]@{} }
            Mock [Microsoft.Extensions.Logging.LoggingFactoryExtensions]::CreateLoggingBuilder { [PSCustomObject]@{} }
            Mock [Microsoft.Extensions.Logging.ConsoleLoggerExtensions]::AddConsole { [PSCustomObject]@{} }
            Mock [OpenTelemetry.Extensions.Logging.OpenTelemetryLoggingExtensions]::AddOpenTelemetry { [PSCustomObject]@{} }
            Mock [OpenTelemetry.Extensions.Logging.OpenTelemetryLoggingExtensions]::AddOpenTelemetry { [PSCustomObject]@{} }
            
            Initialize-OTel -ServiceName 'TestService' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc'
            
            $script:GlobalActivitySource | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle initialization errors gracefully' {
            # Mock to throw an exception during initialization
            Mock New-Object { throw [System.Exception]::new('Test exception') } -ParameterFilter { $TypeName -eq 'System.Diagnostics.ActivitySource' }
            
            { Initialize-OTel -ServiceName 'TestService' -OtlpEndpoint 'http://localhost:4317' } | Should -Throw
        }
    }
}

Describe 'Start-OTelTrace Unit Tests' {
    Context 'Activity Creation' {
        BeforeEach {
            # Reset global variables
            $script:GlobalActivitySource = $null
            $script:CurrentActivity = $null
        }
        
        It 'Should return null when OpenTelemetry is not initialized' {
            $result = Start-OTelTrace -Name 'TestOperation'
            $result | Should -BeNullOrEmpty
        }
        
        It 'Should create activity with correct name' {
            # Mock the ActivitySource
            $mockActivitySource = [PSCustomObject]@{
                StartActivity = {
                    param($name, $kind)
                    [PSCustomObject]@{
                        DisplayName = $name
                        Kind = $kind
                        Start = {}
                        Stop = {}
                        Dispose = {}
                        SetTag = {}
                    }
                }
            }
            $script:GlobalActivitySource = $mockActivitySource
            
            $result = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be 'TestOperation'
        }
        
        It 'Should accept valid Kind values' {
            $mockActivitySource = [PSCustomObject]@{
                StartActivity = {
                    param($name, $kind)
                    [PSCustomObject]@{
                        DisplayName = $name
                        Kind = $kind
                        Start = {}
                        Stop = {}
                        Dispose = {}
                        SetTag = {}
                    }
                }
            }
            $script:GlobalActivitySource = $mockActivitySource
            
            $kinds = @('Internal', 'Server', 'Client', 'Producer', 'Consumer')
            foreach ($kind in $kinds) {
                $result = Start-OTelTrace -Name 'TestOperation' -Kind $kind
                $result | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should set CurrentActivity when trace is started' {
            $mockActivity = [PSCustomObject]@{
                DisplayName = 'TestOperation'
                Start = {}
                Stop = {}
                Dispose = {}
                SetTag = {}
            }
            
            $mockActivitySource = [PSCustomObject]@{
                StartActivity = { $mockActivity }
            }
            $script:GlobalActivitySource = $mockActivitySource
            
            Start-OTelTrace -Name 'TestOperation'
            $script:CurrentActivity | Should -Be $mockActivity
        }
    }
    
    Context 'Parent Activity Handling' {
        BeforeEach {
            $script:GlobalActivitySource = $null
            $script:CurrentActivity = $null
        }
        
        It 'Should handle parent activity correctly' {
            $parentActivity = [PSCustomObject]@{ DisplayName = 'Parent' }
            $childActivity = [PSCustomObject]@{
                DisplayName = 'Child'
                Start = {}
                Stop = {}
                Dispose = {}
                SetTag = {}
            }
            
            $mockActivitySource = [PSCustomObject]@{
                StartActivity = { $childActivity }
            }
            $script:GlobalActivitySource = $mockActivitySource
            
            # Mock System.Diagnostics.Activity::Current setter
            Mock [System.Diagnostics.Activity]::Current = $parentActivity
            
            $result = Start-OTelTrace -Name 'ChildOperation' -ParentActivity $parentActivity
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Stop-OTelTrace Unit Tests' {
    Context 'Activity Disposal' {
        BeforeEach {
            $script:CurrentActivity = $null
        }
        
        It 'Should handle null activity gracefully' {
            { Stop-OTelTrace -Activity $null } | Should -Not -Throw
        }
        
        It 'Should handle no current activity gracefully' {
            { Stop-OTelTrace } | Should -Not -Throw
        }
        
        It 'Should stop and dispose specified activity' {
            $mockActivity = [PSCustomObject]@{
                DisplayName = 'TestOperation'
                Stop = { }
                Dispose = { }
            }
            
            Mock $mockActivity.Stop { }
            Mock $mockActivity.Dispose { }
            
            { Stop-OTelTrace -Activity $mockActivity } | Should -Not -Throw
        }
        
        It 'Should clear CurrentActivity when stopping current activity' {
            $mockActivity = [PSCustomObject]@{
                DisplayName = 'TestOperation'
                Stop = { }
                Dispose = { }
            }
            $script:CurrentActivity = $mockActivity
            
            Stop-OTelTrace -Activity $mockActivity
            $script:CurrentActivity | Should -BeNullOrEmpty
        }
        
        It 'Should not clear CurrentActivity when stopping different activity' {
            $currentActivity = [PSCustomObject]@{
                DisplayName = 'CurrentOperation'
                Stop = { }
                Dispose = { }
            }
            $otherActivity = [PSCustomObject]@{
                DisplayName = 'OtherOperation'
                Stop = { }
                Dispose = { }
            }
            
            $script:CurrentActivity = $currentActivity
            
            Stop-OTelTrace -Activity $otherActivity
            $script:CurrentActivity | Should -Be $currentActivity
        }
    }
}

Describe 'Write-OTelLog Unit Tests' {
    Context 'Logging Functionality' {
        BeforeEach {
            $script:GlobalLogger = $null
        }
        
        It 'Should return when OpenTelemetry is not initialized' {
            { Write-OTelLog -Message 'Test message' } | Should -Not -Throw
        }
        
        It 'Should accept valid log levels' {
            $mockLogger = [PSCustomObject]@{
                Log = { }
            }
            $script:GlobalLogger = $mockLogger
            
            Mock $mockLogger.Log { }
            
            $levels = @('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')
            foreach ($level in $levels) {
                { Write-OTelLog -Message 'Test message' -Level $level } | Should -Not -Throw
            }
        }
        
        It 'Should handle exception logging' {
            $mockLogger = [PSCustomObject]@{
                Log = { }
            }
            $script:GlobalLogger = $mockLogger
            
            Mock $mockLogger.Log { }
            $testException = [System.Exception]::new('Test exception')
            
            { Write-OTelLog -Message 'Test message' -Level 'Error' -Exception $testException } | Should -Not -Throw
        }
        
        It 'Should handle activity association' {
            $mockLogger = [PSCustomObject]@{
                Log = { }
            }
            $script:GlobalLogger = $mockLogger
            
            Mock $mockLogger.Log { }
            $mockActivity = [PSCustomObject]@{ DisplayName = 'TestActivity' }
            
            { Write-OTelLog -Message 'Test message' -Activity $mockActivity } | Should -Not -Throw
        }
    }
}

Describe 'Get-OTelActivity Unit Tests' {
    Context 'Activity Retrieval' {
        It 'Should return current activity' {
            $testActivity = [PSCustomObject]@{ DisplayName = 'TestActivity' }
            
            # Mock System.Diagnostics.Activity::Current getter
            Mock [System.Diagnostics.Activity]::Current { $testActivity }
            
            $result = Get-OTelActivity
            $result | Should -Be $testActivity
        }
        
        It 'Should return null when no activity is current' {
            Mock [System.Diagnostics.Activity]::Current { $null }
            
            $result = Get-OTelActivity
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Module Aliases' {
    Context 'Alias Verification' {
        It 'Start-Trace should alias to Start-OTelTrace' {
            (Get-Alias -Name 'Start-Trace').Definition | Should -Be 'Start-OTelTrace'
        }
        
        It 'Stop-Trace should alias to Stop-OTelTrace' {
            (Get-Alias -Name 'Stop-Trace').Definition | Should -Be 'Stop-OTelTrace'
        }
        
        It 'Write-OTLog should alias to Write-OTelLog' {
            (Get-Alias -Name 'Write-OTLog').Definition | Should -Be 'Write-OTelLog'
        }
    }
}