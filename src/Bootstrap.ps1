# Bootstrap - Initialize the entire application architecture
# This script sets up dependency injection and wires all components together

# Load all dependencies in order
$ErrorActionPreference = "Stop"

# Domain Layer
. "$PSScriptRoot/Core/Domain/ValueObjects/SystemResources.ps1"
. "$PSScriptRoot/Core/Domain/Entities/Configuration.ps1"
. "$PSScriptRoot/Core/Domain/Entities/Profile.ps1"

# Infrastructure Layer
. "$PSScriptRoot/Core/Infrastructure/External/Logger.ps1"
. "$PSScriptRoot/Core/Infrastructure/External/EventBus.ps1"
. "$PSScriptRoot/Core/Application/Interfaces/IConfigRepository.ps1"

# Application Services (to be loaded)
# . "$PSScriptRoot/Core/Application/Services/ProfileService.ps1"
# . "$PSScriptRoot/Core/Application/Services/ConfigurationManager.ps1"
# . "$PSScriptRoot/Core/Application/Services/SchedulerService.ps1"

# Dependency Injection Container
class ServiceContainer {
    hidden [hashtable]$services = @{}
    hidden [hashtable]$singletons = @{}

    # Register a service
    [void] Register([string]$name, [ScriptBlock]$factory, [bool]$singleton = $false) {
        $this.services[$name] = @{
            Factory = $factory
            Singleton = $singleton
        }
    }

    # Resolve a service
    [object] Resolve([string]$name) {
        if (-not $this.services.ContainsKey($name)) {
            throw "Service '$name' not registered"
        }

        $service = $this.services[$name]

        if ($service.Singleton) {
            if (-not $this.singletons.ContainsKey($name)) {
                $this.singletons[$name] = & $service.Factory $this
            }
            return $this.singletons[$name]
        }

        return & $service.Factory $this
    }

    # Check if service is registered
    [bool] Has([string]$name) {
        return $this.services.ContainsKey($name)
    }
}

# Application class - Main entry point
class WSLMemoryMonitorApp {
    [ServiceContainer]$Container
    [ILogger]$Logger
    [EventBus]$EventBus
    [SystemResources]$SystemResources

    WSLMemoryMonitorApp() {
        $this.Container = [ServiceContainer]::new()
        $this.ConfigureServices()
        $this.Initialize()
    }

    # Configure dependency injection
    hidden [void] ConfigureServices() {
        # Logger (singleton)
        $this.Container.Register("Logger", {
            param($container)
            return [Logger]::CreateDefault()
        }, $true)

        # EventBus (singleton)
        $this.Container.Register("EventBus", {
            param($container)
            $logger = $container.Resolve("Logger")
            return [EventBus]::new($logger)
        }, $true)

        # SystemResources (singleton)
        $this.Container.Register("SystemResources", {
            param($container)
            return [SystemResources]::DetectCurrent()
        }, $true)

        # Add more services here...
    }

    # Initialize application
    hidden [void] Initialize() {
        $this.Logger = $this.Container.Resolve("Logger")
        $this.EventBus = $this.Container.Resolve("EventBus")
        $this.SystemResources = $this.Container.Resolve("SystemResources")

        $this.Logger.Info("WSL Memory Monitor Application Initialized", @{
            Version = "2.0.0-arch"
            SystemRAM = "$($this.SystemResources.TotalRAM_GB)GB"
            SystemCPUs = $this.SystemResources.TotalCPUs
        })

        $this.SetupEventHandlers()
    }

    # Setup event handlers
    hidden [void] SetupEventHandlers() {
        # Profile changed handler
        $this.EventBus.Subscribe("ProfileChanged", {
            param($event)
            $this.Logger.Info("Profile changed", @{
                From = $event.OldProfile
                To = $event.NewProfile
                Dynamic = $event.AppliedDynamically
            })
        }.GetNewClosure())

        # Memory threshold handler
        $this.EventBus.Subscribe("MemoryThresholdExceeded", {
            param($event)
            $this.Logger.Warn("Memory threshold exceeded", @{
                Usage = "$($event.CurrentUsagePercent)%"
                Threshold = "$($event.Threshold)%"
                Profile = $event.ProfileName
            })
        }.GetNewClosure())
    }

    # Run application
    [void] Run([string]$mode = "GUI") {
        $this.Logger.Info("Starting application in $mode mode")

        switch ($mode) {
            "GUI" {
                # Load and run GUI
                # . "$PSScriptRoot/Presentation/GUI/MainWindow.ps1"
                Write-Host "GUI mode would start here" -ForegroundColor Cyan
            }
            "CLI" {
                # Run CLI
                Write-Host "CLI mode would start here" -ForegroundColor Cyan
            }
            "API" {
                # Start API server
                Write-Host "API server would start here" -ForegroundColor Cyan
            }
            default {
                throw "Unknown mode: $mode"
            }
        }
    }

    # Test the architecture
    [void] Test() {
        Write-Host "`n=== Testing New Architecture ===" -ForegroundColor Cyan
        Write-Host ""

        # Test Logger
        Write-Host "Testing Logger..." -ForegroundColor Yellow
        $this.Logger.Debug("Debug message", @{ Test = "Value" })
        $this.Logger.Info("Info message")
        $this.Logger.Warn("Warning message")
        $this.Logger.Error("Error message", @{ Error = "Test error" })

        # Test EventBus
        Write-Host "`nTesting EventBus..." -ForegroundColor Yellow
        $this.EventBus.Subscribe("TestEvent", {
            param($data)
            Write-Host "  Event received: $($data.Message)" -ForegroundColor Green
        })
        $this.EventBus.Publish("TestEvent", @{ Message = "Hello from EventBus!" })

        # Test Domain Models
        Write-Host "`nTesting Domain Models..." -ForegroundColor Yellow
        Write-Host "  SystemResources: $($this.SystemResources.ToString())"

        $profile = [Profile]::new("TEST", 16, 8, "Test profile", [ProfileCategory]::Custom)
        Write-Host "  Profile created: $($profile.Name) - $($profile.WSL_RAM_GB)GB, $($profile.WSL_CPUs) CPUs"
        Write-Host "  Is valid for system: $($profile.IsValidFor($this.SystemResources))"

        $config = $profile.ToConfiguration()
        Write-Host "  Configuration generated"

        # Test Serialization
        Write-Host "`nTesting Serialization..." -ForegroundColor Yellow
        $configStr = $config.Serialize()
        Write-Host "  Serialized config (first 100 chars): $($configStr.Substring(0, [Math]::Min(100, $configStr.Length)))..."

        # Test Events
        Write-Host "`nTesting Profile Changed Event..." -ForegroundColor Yellow
        $event = [ProfileChangedEvent]::new("BALANCED", "GAMING", $true)
        $this.EventBus.Publish("ProfileChanged", $event)

        Write-Host "`n=== Architecture Test Complete ===" -ForegroundColor Green
        Write-Host ""
    }
}

# Export for use in other scripts
$global:App = $null

function Initialize-WSLMemoryMonitor {
    $global:App = [WSLMemoryMonitorApp]::new()
    return $global:App
}

function Get-WSLMemoryMonitorApp {
    if ($null -eq $global:App) {
        return Initialize-WSLMemoryMonitor
    }
    return $global:App
}

# If run directly, test the architecture
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host @"

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       WSL MEMORY MONITOR - NEW ARCHITECTURE v2.0         ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    $app = Initialize-WSLMemoryMonitor
    $app.Test()

    Write-Host @"
Architecture components loaded successfully!

Available services:
  - Logger: Structured logging with file/console output
  - EventBus: Pub/Sub pattern for decoupled communication
  - SystemResources: Hardware detection value object
  - Profile: Domain entity with business logic
  - Configuration: WSL config with serialization

Next steps:
  1. Complete ProfileService implementation
  2. Add API REST server
  3. Implement Scheduler
  4. Add Telemetry service
  5. Build Web Dashboard

To use in your scripts:
  . ./src/Bootstrap.ps1
  `$app = Get-WSLMemoryMonitorApp
  `$app.Run("GUI")

"@
}
