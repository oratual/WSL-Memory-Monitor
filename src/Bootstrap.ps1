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
. "$PSScriptRoot/Core/Infrastructure/Repositories/FileConfigRepository.ps1"

# Application Layer - Factories
. "$PSScriptRoot/Core/Application/Factories/ProfileFactory.ps1"

# Application Layer - Services
. "$PSScriptRoot/Core/Application/Services/ProfileService.ps1"
. "$PSScriptRoot/Core/Application/Services/ConfigurationManager.ps1"
. "$PSScriptRoot/Core/Application/Services/WSLService.ps1"
. "$PSScriptRoot/Core/Application/Services/SchedulerService.ps1"
. "$PSScriptRoot/Core/Application/Services/TelemetryService.ps1"

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
        # Core Infrastructure (singletons)
        $this.Container.Register("Logger", {
            param($container)
            return [Logger]::CreateDefault()
        }, $true)

        $this.Container.Register("EventBus", {
            param($container)
            $logger = $container.Resolve("Logger")
            return [EventBus]::new($logger)
        }, $true)

        $this.Container.Register("SystemResources", {
            param($container)
            return [SystemResources]::DetectCurrent()
        }, $true)

        # Repository (singleton)
        $this.Container.Register("ConfigRepository", {
            param($container)
            $logger = $container.Resolve("Logger")
            return [FileConfigRepository]::CreateDefault($logger)
        }, $true)

        # Factories (singleton)
        $this.Container.Register("ProfileFactory", {
            param($container)
            $logger = $container.Resolve("Logger")
            return [ProfileFactory]::new($logger)
        }, $true)

        # Application Services (singletons)
        $this.Container.Register("ConfigurationManager", {
            param($container)
            $configRepo = $container.Resolve("ConfigRepository")
            $eventBus = $container.Resolve("EventBus")
            $logger = $container.Resolve("Logger")
            $systemResources = $container.Resolve("SystemResources")
            return [ConfigurationManager]::new($configRepo, $eventBus, $logger, $systemResources)
        }, $true)

        $this.Container.Register("ProfileService", {
            param($container)
            $eventBus = $container.Resolve("EventBus")
            $logger = $container.Resolve("Logger")
            $systemResources = $container.Resolve("SystemResources")
            $configRepo = $container.Resolve("ConfigRepository")
            $profileFactory = $container.Resolve("ProfileFactory")
            return [ProfileService]::new($eventBus, $logger, $systemResources, $configRepo, $profileFactory)
        }, $true)

        $this.Container.Register("WSLService", {
            param($container)
            $eventBus = $container.Resolve("EventBus")
            $logger = $container.Resolve("Logger")
            return [WSLService]::new($eventBus, $logger)
        }, $true)

        $this.Container.Register("SchedulerService", {
            param($container)
            $eventBus = $container.Resolve("EventBus")
            $logger = $container.Resolve("Logger")
            $profileService = $container.Resolve("ProfileService")
            return [SchedulerService]::new($eventBus, $logger, $profileService)
        }, $true)

        $this.Container.Register("TelemetryService", {
            param($container)
            $logger = $container.Resolve("Logger")
            $eventBus = $container.Resolve("EventBus")
            return [TelemetryService]::new($logger, $eventBus)
        }, $true)
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
        Write-Host "1. Testing Logger..." -ForegroundColor Yellow
        $this.Logger.Info("Logging system initialized")

        # Test EventBus
        Write-Host "`n2. Testing EventBus..." -ForegroundColor Yellow
        $this.EventBus.Subscribe("TestEvent", {
            param($data)
            Write-Host "  ✓ Event received: $($data.Message)" -ForegroundColor Green
        })
        $this.EventBus.Publish("TestEvent", @{ Message = "Hello from EventBus!" })

        # Test Domain Models
        Write-Host "`n3. Testing Domain Models..." -ForegroundColor Yellow
        Write-Host "  SystemResources: $($this.SystemResources.ToString())" -ForegroundColor Cyan

        # Test ProfileFactory
        Write-Host "`n4. Testing ProfileFactory..." -ForegroundColor Yellow
        $profileFactory = $this.Container.Resolve("ProfileFactory")
        $profiles = $profileFactory.GenerateProfiles($this.SystemResources)
        Write-Host "  ✓ Generated $($profiles.Count) profiles using $($profileFactory.GetCurrentStrategy()) strategy" -ForegroundColor Green
        foreach ($p in $profiles) {
            Write-Host "    - $($p.Name): $($p.WSL_RAM_GB)GB RAM, $($p.WSL_CPUs) CPUs" -ForegroundColor Gray
        }

        # Test ProfileService
        Write-Host "`n5. Testing ProfileService..." -ForegroundColor Yellow
        $profileService = $this.Container.Resolve("ProfileService")
        $generatedProfiles = $profileService.GenerateProfiles()
        Write-Host "  ✓ ProfileService generated $($generatedProfiles.Count) profiles" -ForegroundColor Green
        $recommendation = $profileService.RecommendProfile("development")
        Write-Host "  ✓ Recommended profile for development: $($recommendation.Name)" -ForegroundColor Green

        # Test ConfigurationManager
        Write-Host "`n6. Testing ConfigurationManager..." -ForegroundColor Yellow
        $configManager = $this.Container.Resolve("ConfigurationManager")
        $hasConfig = $configManager.HasConfiguration()
        Write-Host "  Configuration exists: $hasConfig" -ForegroundColor Cyan
        if ($hasConfig) {
            $summary = $configManager.GetSummary()
            Write-Host "  Current profile: $($summary.Profile)" -ForegroundColor Cyan
            Write-Host "  Memory allocation: WSL=$($summary.Memory.WSL_GB)GB, Windows=$($summary.Memory.Windows_GB)GB" -ForegroundColor Cyan
        }

        # Test WSLService
        Write-Host "`n7. Testing WSLService..." -ForegroundColor Yellow
        $wslService = $this.Container.Resolve("WSLService")
        $wslStatus = $wslService.GetStatus()
        Write-Host "  WSL Running: $($wslStatus.IsRunning)" -ForegroundColor Cyan
        Write-Host "  WSL Version: $($wslStatus.Version)" -ForegroundColor Cyan
        Write-Host "  Distributions: $($wslStatus.DistributionCount)" -ForegroundColor Cyan
        $daemonStatus = $wslService.GetDaemonStatus()
        Write-Host "  Daemon available: $($daemonStatus.Available)" -ForegroundColor Cyan

        # Test SchedulerService
        Write-Host "`n8. Testing SchedulerService..." -ForegroundColor Yellow
        $schedulerService = $this.Container.Resolve("SchedulerService")
        $schedules = $schedulerService.GetSchedules()
        Write-Host "  ✓ SchedulerService initialized ($($schedules.Count) schedules)" -ForegroundColor Green

        # Test TelemetryService
        Write-Host "`n9. Testing TelemetryService..." -ForegroundColor Yellow
        $telemetryService = $this.Container.Resolve("TelemetryService")
        $telemetryService.TrackEvent("architecture.test", @{ Success = $true })
        Write-Host "  ✓ TelemetryService initialized and tracking events" -ForegroundColor Green

        # Test Configuration Serialization
        Write-Host "`n10. Testing Configuration Serialization..." -ForegroundColor Yellow
        $testProfile = $profiles[2]  # Use Balanced profile
        $config = $testProfile.ToConfiguration()
        $configStr = $config.Serialize()
        Write-Host "  ✓ Configuration serialized successfully" -ForegroundColor Green

        Write-Host "`n=== All Architecture Components Tested Successfully! ===" -ForegroundColor Green
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

✓ Core Infrastructure:
  - Logger: Structured logging with file/console output
  - EventBus: Pub/Sub pattern for decoupled communication
  - SystemResources: Hardware detection value object

✓ Domain Layer:
  - Profile: Domain entity with business logic and validation
  - Configuration: WSL config with serialization
  - SystemResources: Immutable value object for system hardware

✓ Repository Layer:
  - FileConfigRepository: File-based configuration persistence with backup/history

✓ Factory Layer:
  - ProfileFactory: Strategy Pattern for flexible profile generation
    • Percentage-based strategy (default)
    • Tier-based strategy
    • Workload-based strategy
    • Conservative strategy

✓ Application Services:
  - ProfileService: Profile management and application
  - ConfigurationManager: Configuration lifecycle management
  - WSLService: WSL control and monitoring
  - SchedulerService: Scheduled profile switching (cron-like)
  - TelemetryService: Privacy-focused usage analytics

To use in your scripts:
  . ./src/Bootstrap.ps1
  `$app = Get-WSLMemoryMonitorApp
  `$profileService = `$app.Container.Resolve("ProfileService")
  `$profiles = `$profileService.GenerateProfiles()

"@
}
