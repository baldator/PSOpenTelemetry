<# 
.SYNOPSIS
Loads required OpenTelemetry .NET dependencies for the PSOpenTelemetry module.

.DESCRIPTION
This script downloads and loads the necessary NuGet packages for OpenTelemetry functionality.
It handles downloading packages from nuget.org and loading the required DLLs into the PowerShell session.

.PARAMETER PackagePath
Optional path where NuGet packages will be downloaded and extracted. Defaults to a temp directory.

.PARAMETER ForceDownload
If $true, forces re-download of packages even if they already exist locally.

.EXAMPLE
.\Load-Dependencies.ps1

.EXAMPLE
.\Load-Dependencies.ps1 -ForceDownload $true

.EXAMPLE
.\Load-Dependencies.ps1 -PackagePath "C:\MyPackages"

.NOTES
Requires PowerShell 5.1+ and internet access to download NuGet packages.
#>
param(
    [Parameter()]
    [string]$PackagePath = $null,
    
    [Parameter()]
    [switch]$ForceDownload = $false
)

# Set default package path if not provided
if (-not $PackagePath) {
    $PackagePath = Join-Path $env:TEMP "PSOpenTelemetryPackages"
}

# Create package directory if it doesn't exist
if (-not (Test-Path $PackagePath)) {
    New-Item -ItemType Directory -Path $PackagePath -Force | Out-Null
}

# Define required packages and their versions
$requiredPackages = @(
    @{ Name = 'System.Diagnostics.DiagnosticSource'; Version = '10.0.2' },
    @{ Name = 'OpenTelemetry.Exporter.OpenTelemetryProtocol'; Version = '1.15.0' },
    @{ Name = 'Microsoft.Extensions.Logging'; Version = '10.0.2' },
    @{ Name = 'Microsoft.Extensions.Logging.Abstractions'; Version = '10.0.2' },
    @{ Name = 'Microsoft.Extensions.Logging.Console'; Version = '10.0.2' }
)

# Function to download NuGet package
function Download-NuGetPackage {
    param(
        [string]$PackageName,
        [string]$Version,
        [string]$TargetPath
    )
    
    $nupkgUrl = "https://www.nuget.org/api/v2/package/$PackageName/$Version"
    $nupkgPath = Join-Path $TargetPath "$PackageName.$Version.nupkg"
    
    Write-Host "Downloading $PackageName version $Version..." -ForegroundColor Cyan
    Write-Host "  from $nupkgUrl" -ForegroundColor Cyan
    
    try {
        # Use Invoke-WebRequest to download the package
        Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath -UseBasicParsing
        Write-Host "Downloaded $PackageName to $nupkgPath" -ForegroundColor Green
        return $nupkgPath
    }
    catch {
        Write-Error ("Failed to download {0}: {1}" -f $PackageName, $_.Exception.Message)
        return $null
    }
}

# Function to extract NuGet package
function Expand-NuGetPackage {
    param(
        [string]$NupkgPath,
        [string]$ExtractPath
    )
    
    try {
        # Create extraction directory
        if (-not (Test-Path $ExtractPath)) {
            New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
        }
        
        # Extract the .nupkg file (which is a ZIP archive)
        Expand-Archive -Path $NupkgPath -DestinationPath $ExtractPath -Force
        Write-Host "Extracted $NupkgPath to $ExtractPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error ("Failed to extract {0}: {1}" -f $NupkgPath, $_.Exception.Message)
        return $false
    }
}

# Function to load DLLs from package
function Load-PackageAssemblies {
    param(
        [string]$PackageExtractPath
    )
    
    # Find all .dll files in the package
    $dllFiles = Get-ChildItem -Path $PackageExtractPath -Recurse -Filter "*.dll" | Where-Object { -not $_.PSIsContainer }
    
    foreach ($dll in $dllFiles) {
        try {
            # Load the assembly
            Add-Type -Path $dll.FullName -ErrorAction SilentlyContinue
            Write-Verbose "Loaded assembly: $($dll.Name)"
        }
        catch {
            # Some assemblies might not be loadable in PowerShell context, which is okay
            Write-Verbose "Could not load assembly $($dll.Name): $($_.Exception.Message)"
        }
    }
}

# Main execution
Write-Host "PSOpenTelemetry Dependency Loader" -ForegroundColor Yellow
Write-Host "Package path: $PackagePath" -ForegroundColor Yellow
Write-Host ""

$loadedAssemblies = @()

foreach ($package in $requiredPackages) {
    $packageName = $package.Name
    $version = $package.Version
    $packageDir = Join-Path $PackagePath $packageName
    
    # Check if package already exists and we don't want to force download
    $packageExists = (Test-Path $packageDir) -and (-not $ForceDownload)
    
    if ($packageExists) {
        Write-Host "$packageName version $version already exists, skipping download." -ForegroundColor Gray
    } else {
        # Clean up existing package directory if forcing download
        if ($ForceDownload -and (Test-Path $packageDir)) {
            Remove-Item $packageDir -Recurse -Force
        }
        
        # Download package
        $nupkgPath = Download-NuGetPackage -PackageName $packageName -Version $version -TargetPath $PackagePath
        if (-not $nupkgPath) { continue }
        
        # Extract package
        if (-not (Expand-NuGetPackage -NupkgPath $nupkgPath -ExtractPath $packageDir)) { continue }
        
        # Clean up .nupkg file
        Remove-Item $nupkgPath -Force
    }
    
    # Load assemblies from the package
    Load-PackageAssemblies -PackageExtractPath $packageDir
    $loadedAssemblies += $packageName
}

Write-Host ""
Write-Host "Dependency loading complete!" -ForegroundColor Green
Write-Host "Loaded assemblies from packages:" -ForegroundColor Green
$loadedAssemblies | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }

# Verify critical assemblies are loaded
$criticalTypes = @(
    'System.Diagnostics.ActivitySource',
    'OpenTelemetry.Trace.TracerProviderBuilder',
    'OpenTelemetry.Exporter.OtlpExporter',
    'Microsoft.Extensions.Logging.ILogger'
)

Write-Host ""
Write-Host "Verifying critical types are available:" -ForegroundColor Yellow
foreach ($type in $criticalTypes) {
    try {
        $loaded = [System.Type]::GetType($type)
        if ($loaded) {
            Write-Host "  load ok $type" -ForegroundColor Green
        } else {
            Write-Host "  failed to load $type" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  failed to load $type" -ForegroundColor Red
        Write-Host "    Exception: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "To use the PSOpenTelemetry module, import it with:" -ForegroundColor Yellow
Write-Host "Import-Module .\PSOpenTelemetry.psm1" -ForegroundColor Cyan
