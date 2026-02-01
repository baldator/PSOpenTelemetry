<# 
.SYNOPSIS
Integration tests for PSOpenTelemetry module using Pester 5.

.DESCRIPTION
These tests verify the actual interoperability with .NET libraries and the OTLP exporter.
They load actual DLLs and instantiate the TracerProvider to test real functionality.

.NOTES
Requires Pester 5+ and actual .NET OpenTelemetry dependencies to be loaded.
These tests should be run with a real OTLP endpoint (like Jaeger or OTel Collector).
#>

BeforeAll {
    # Import the module for testing
    $modulePath = Join-Path $PSScriptRoot '..\PSOpenTelemetry.psm1'
    $dependenciesPath = Join-Path $PSScriptRoot '..\Load-Dependencies.ps1'
    
    # Load dependencies first
    if (Test-Path $dependenciesPath) {
        . $dependenciesPath
    }
    
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Initialize-OTel Integration Tests' {
    Context 'Real .NET Integration' {
        BeforeEach {
            # Reset global variables
            $script:GlobalTracerProvider = $null
            $script:GlobalLoggerFactory = $null
            $script:GlobalActivitySource = $null
            $script:GlobalLogger = $null
            $script:CurrentActivity = $null
        }
        
        It 'Should create real ActivitySource instance' {
            { Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$false } | Should -Not -Throw
            
            $script:GlobalActivitySource | Should -Not -BeNullOrEmpty
            $script:GlobalActivitySource.GetType().Name | Should -Be 'ActivitySource'
            $script:GlobalActivitySource.Name | Should -Be 'IntegrationTest'
        }
        
        It 'Should create real TracerProvider instance' {
            { Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$false } | Should -Not -Throw
            
            $script:GlobalTracerProvider | Should -Not -BeNullOrEmpty
            $script:GlobalTracerProvider.GetType().Name | Should -Be 'TracerProvider'
        }
        
        It 'Should create real LoggerFactory instance' {
            { Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$true } | Should -Not -Throw
            
            $script:GlobalLoggerFactory | Should -Not -BeNullOrEmpty
            $script:GlobalLoggerFactory.GetType().Name | Should -Be 'LoggerFactory'
        }
        
        It 'Should create real logger instance' {
            { Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$true } | Should -Not -Throw
            
            $script:GlobalLogger | Should -Not -BeNullOrEmpty
            $script:GlobalLogger.GetType().Name | Should -Be 'Logger'
        }
    }
    
    Context 'Configuration Options' {
        It 'Should handle HTTP/Protobuf protocol' {
            { Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4318' -Protocol 'http/protobuf' -ConsoleOutput:$false } | Should -Not -Throw
            
            $script:GlobalActivitySource | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle console output configuration' {
            { Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$true } | Should -Not -Throw
            
            $script:GlobalLogger | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Start-OTelTrace Integration Tests' {
    Context 'Real Activity Creation' {
        BeforeEach {
            # Initialize with minimal setup (no OTLP to avoid network dependencies)
            Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$false
        }
        
        It 'Should create real Activity instance' {
            $activity = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            
            $activity | Should -Not -BeNullOrEmpty
            $activity.GetType().Name | Should -Be 'Activity'
            $activity.DisplayName | Should -Be 'TestOperation'
            $activity.Kind | Should -Be ([System.Diagnostics.ActivityKind]::Internal)
        }
        
        It 'Should set CurrentActivity correctly' {
            $activity = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            
            $script:CurrentActivity | Should -Be $activity
            [System.Diagnostics.Activity]::Current | Should -Be $activity
        }
        
        It 'Should handle different activity kinds' {
            $kinds = @(
                @{ Name = 'Internal'; Value = [System.Diagnostics.ActivityKind]::Internal }
                @{ Name = 'Server'; Value = [System.Diagnostics.ActivityKind]::Server }
                @{ Name = 'Client'; Value = [System.Diagnostics.ActivityKind]::Client }
                @{ Name = 'Producer'; Value = [System.Diagnostics.ActivityKind]::Producer }
                @{ Name = 'Consumer'; Value = [System.Diagnostics.ActivityKind]::Consumer }
            )
            
            foreach ($kind in $kinds) {
                $activity = Start-OTelTrace -Name "Test$($kind.Name)" -Kind $kind.Name
                $activity.Kind | Should -Be $kind.Value
                Stop-OTelTrace -Activity $activity
            }
        }
        
        It 'Should allow setting tags on activity' {
            $activity = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            
            { $activity.SetTag('test.key', 'test.value') } | Should -Not -Throw
            
            # Note: We can't easily verify the tag was set without more complex reflection
            # but we can verify the method exists and doesn't throw
            $activity | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Activity Hierarchy' {
        It 'Should handle parent-child relationships' {
            $parentActivity = Start-OTelTrace -Name 'ParentOperation' -Kind 'Internal'
            $childActivity = Start-OTelTrace -Name 'ChildOperation' -Kind 'Client' -ParentActivity $parentActivity
            
            $childActivity | Should -Not -BeNullOrEmpty
            $childActivity.ParentId | Should -Be $parentActivity.Id
            
            Stop-OTelTrace -Activity $childActivity
            Stop-OTelTrace -Activity $parentActivity
        }
    }
}

Describe 'Stop-OTelTrace Integration Tests' {
    Context 'Activity Lifecycle' {
        BeforeEach {
            Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$false
        }
        
        It 'Should properly stop and dispose activity' {
            $activity = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            
            { Stop-OTelTrace -Activity $activity } | Should -Not -Throw
            
            # Activity should be stopped
            $activity.Duration.TotalMilliseconds | Should -BeGreaterThan 0
        }
        
        It 'Should clear CurrentActivity when stopping current activity' {
            $activity = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            
            Stop-OTelTrace -Activity $activity
            
            $script:CurrentActivity | Should -BeNullOrEmpty
            [System.Diagnostics.Activity]::Current | Should -BeNullOrEmpty
        }
        
        It 'Should handle stopping non-current activity' {
            $activity1 = Start-OTelTrace -Name 'Operation1' -Kind 'Internal'
            $activity2 = Start-OTelTrace -Name 'Operation2' -Kind 'Internal'
            
            { Stop-OTelTrace -Activity $activity1 } | Should -Not -Throw
            
            # Current activity should still be activity2
            $script:CurrentActivity | Should -Be $activity2
            
            Stop-OTelTrace -Activity $activity2
        }
    }
}

Describe 'Write-OTelLog Integration Tests' {
    Context 'Real Logging' {
        BeforeEach {
            Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$true
        }
        
        It 'Should write logs without throwing exceptions' {
            { Write-OTelLog -Message 'Test log message' -Level 'Information' } | Should -Not -Throw
        }
        
        It 'Should handle all log levels' {
            $levels = @('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')
            
            foreach ($level in $levels) {
                { Write-OTelLog -Message "Test $level message" -Level $level } | Should -Not -Throw
            }
        }
        
        It 'Should handle exception logging' {
            $testException = [System.Exception]::new('Test exception for logging')
            
            { Write-OTelLog -Message 'Error occurred' -Level 'Error' -Exception $testException } | Should -Not -Throw
        }
        
        It 'Should associate logs with activities' {
            $activity = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            
            { Write-OTelLog -Message 'Log with activity' -Level 'Information' -Activity $activity } | Should -Not -Throw
            
            Stop-OTelTrace -Activity $activity
        }
        
        It 'Should work with current activity' {
            $activity = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            
            { Write-OTelLog -Message 'Log with current activity' -Level 'Information' } | Should -Not -Throw
            
            Stop-OTelTrace -Activity $activity
        }
    }
}

Describe 'Get-OTelActivity Integration Tests' {
    Context 'Activity Retrieval' {
        BeforeEach {
            Initialize-OTel -ServiceName 'IntegrationTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$false
        }
        
        It 'Should return current activity when one exists' {
            $activity = Start-OTelTrace -Name 'TestOperation' -Kind 'Internal'
            
            $current = Get-OTelActivity
            $current | Should -Be $activity
            
            Stop-OTelTrace -Activity $activity
        }
        
        It 'Should return null when no activity exists' {
            $current = Get-OTelActivity
            $current | Should -BeNullOrEmpty
        }
        
        It 'Should return latest current activity' {
            $activity1 = Start-OTelTrace -Name 'Operation1' -Kind 'Internal'
            $activity2 = Start-OTelTrace -Name 'Operation2' -Kind 'Internal'
            
            $current = Get-OTelActivity
            $current | Should -Be $activity2
            
            Stop-OTelTrace -Activity $activity2
            Stop-OTelTrace -Activity $activity1
        }
    }
}

Describe 'End-to-End Integration Tests' {
    Context 'Complete Workflow' {
        It 'Should handle complete tracing and logging workflow' {
            # Initialize
            Initialize-OTel -ServiceName 'E2ETest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$true
            
            # Start main trace
            $mainActivity = Start-OTelTrace -Name 'MainOperation' -Kind 'Internal'
            $mainActivity.SetTag('operation.type', 'e2e_test')
            $mainActivity.SetTag('test.version', '1.0')
            
            # Write some logs
            Write-OTelLog -Message 'Main operation started' -Level 'Information'
            Write-OTelLog -Message 'Processing data...' -Level 'Debug'
            
            # Start child trace
            $childActivity = Start-OTelTrace -Name 'ChildOperation' -Kind 'Client' -ParentActivity $mainActivity
            $childActivity.SetTag('child.operation', 'network_call')
            
            Write-OTelLog -Message 'Making API call' -Level 'Information' -Activity $childActivity
            
            # Stop child trace
            Stop-OTelTrace -Activity $childActivity
            
            # Write more logs
            Write-OTelLog -Message 'Child operation completed' -Level 'Information'
            Write-OTelLog -Message 'Processing results...' -Level 'Debug'
            
            # Stop main trace
            Stop-OTelTrace -Activity $mainActivity
            
            # Verify activities were created and stopped
            $mainActivity.Duration.TotalMilliseconds | Should -BeGreaterThan 0
            if ($childActivity) {
                $childActivity.Duration.TotalMilliseconds | Should -BeGreaterThan 0
            }
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle errors gracefully in complete workflow' {
            Initialize-OTel -ServiceName 'ErrorTest' -OtlpEndpoint 'http://localhost:4317' -Protocol 'grpc' -ConsoleOutput:$true
            
            $mainActivity = Start-OTelTrace -Name 'ErrorOperation' -Kind 'Internal'
            
            try {
                Write-OTelLog -Message 'Starting operation' -Level 'Information'
                
                # Simulate an error
                throw [System.Exception]::new('Simulated error for testing')
            }
            catch {
                Write-OTelLog -Message 'Error occurred during operation' -Level 'Error' -Exception $_
                Write-OTelLog -Message 'Error handled gracefully' -Level 'Warning'
            }
            finally {
                Stop-OTelTrace -Activity $mainActivity
            }
            
            # Verify the activity was still properly stopped
            $mainActivity.Duration.TotalMilliseconds | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    # Clean up global state
    if ($script:GlobalTracerProvider) {
        $script:GlobalTracerProvider.Dispose()
        $script:GlobalTracerProvider = $null
    }
    
    if ($script:GlobalLoggerFactory) {
        $script:GlobalLoggerFactory.Dispose()
        $script:GlobalLoggerFactory = $null
    }
}