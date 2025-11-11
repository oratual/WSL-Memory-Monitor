# WSL Memory Monitor - New Architecture Implementation

## 🏗️ Architecture Overview

This directory contains the new layered architecture implementation of WSL Memory Monitor, following Clean Architecture and SOLID principles.

## 📁 Directory Structure

```
src/
├── Bootstrap.ps1                    # Application initialization & DI container
├── Core/
│   ├── Domain/                      # Business logic & domain models
│   │   ├── Entities/               # Domain entities (Profile, Configuration)
│   │   ├── ValueObjects/           # Immutable value objects (SystemResources)
│   │   └── Services/               # Domain services
│   ├── Application/                # Application business logic
│   │   ├── Services/               # Application services
│   │   └── Interfaces/             # Service interfaces (Repository patterns)
│   └── Infrastructure/             # External concerns
│       ├── Repositories/           # Data persistence implementations
│       ├── Adapters/               # External system adapters (WSL, Windows API)
│       └── External/               # External libraries (EventBus, Logger)
├── Presentation/                    # User interfaces
│   ├── GUI/                        # Windows Forms GUI
│   ├── CLI/                        # Command-line interface
│   └── API/                        # REST API
│       └── Controllers/            # API endpoints
└── Daemon/                         # Background services

## 🎯 Key Components Implemented

### ✅ Domain Layer

**Entities:**
- `Profile.ps1` - Memory profile with business logic
  - Validation against system resources
  - Conversion to Configuration
  - Serialization/deserialization
  - Profile cloning and comparison

- `Configuration.ps1` - WSL configuration representation
  - .wslconfig format serialization
  - Deserialization with validation
  - Configuration comparison and cloning

**Value Objects:**
- `SystemResources.ps1` - Immutable system hardware info
  - Auto-detection of RAM, CPUs, WSL version
  - Resource tier calculation (Low/Medium/High/VeryHigh)
  - Safe maximum calculations
  - Profile validation

### ✅ Infrastructure Layer

**External Services:**
- `EventBus.ps1` - Pub/Sub pattern implementation
  - Subscribe/Unsubscribe to events
  - Synchronous and asynchronous publishing
  - Error handling for subscribers
  - Event definitions (ProfileChanged, MemoryThresholdExceeded, etc.)

- `Logger.ps1` - Structured logging
  - Multiple log levels (Debug, Info, Warn, Error)
  - Multiple outputs (Console, File)
  - Colored console output
  - JSON file logging
  - Log rotation
  - Query interface

**Interfaces:**
- `IConfigRepository.ps1` - Configuration persistence contract
- `ILogger.ps1` - Logging interface for DI

### ✅ Application Bootstrap

**Dependency Injection:**
- `ServiceContainer` class - Simple DI container
  - Service registration (transient/singleton)
  - Service resolution
  - Dependency graph management

**Application Class:**
- `WSLMemoryMonitorApp` - Main application class
  - Service configuration
  - Event handler setup
  - Multiple run modes (GUI/CLI/API)
  - Architecture testing

## 🚀 Usage

### Initialize the Application

```powershell
# Load the bootstrap
. ./src/Bootstrap.ps1

# Initialize (creates singleton instance)
$app = Initialize-WSLMemoryMonitor

# Or get existing instance
$app = Get-WSLMemoryMonitorApp
```

### Test the Architecture

```powershell
# Run architecture test
$app.Test()
```

This will test:
- Logger with all levels
- EventBus pub/sub
- Domain models (Profile, Configuration, SystemResources)
- Serialization/deserialization
- Event publishing

### Use Individual Components

```powershell
# Get services from container
$logger = $app.Container.Resolve("Logger")
$eventBus = $app.Container.Resolve("EventBus")
$resources = $app.Container.Resolve("SystemResources")

# Use logger
$logger.Info("Application started", @{ User = $env:USERNAME })
$logger.Error("Something went wrong", @{ ErrorCode = 500 })

# Use event bus
$eventBus.Subscribe("ProfileChanged", {
    param($event)
    Write-Host "Profile changed from $($event.OldProfile) to $($event.NewProfile)"
})

$event = [ProfileChangedEvent]::new("BALANCED", "GAMING", $true)
$eventBus.Publish("ProfileChanged", $event)

# Work with domain models
$profile = [Profile]::new("CUSTOM", 32, 16, "My profile", [ProfileCategory]::Custom)
$isValid = $profile.IsValidFor($resources)
$config = $profile.ToConfiguration()
$configStr = $config.Serialize()
```

## 📊 Architecture Benefits

### Implemented ✅

1. **Separation of Concerns**
   - Clear boundaries between layers
   - Each layer has specific responsibility
   - Dependencies point inward (Dependency Inversion)

2. **Testability**
   - All components can be unit tested
   - Dependencies can be mocked via interfaces
   - Pure business logic in domain layer

3. **Maintainability**
   - Changes isolated to specific layers
   - Easy to understand and modify
   - Clear dependency flow

4. **Extensibility**
   - New features added without modifying existing code
   - Plugin architecture possible
   - Multiple UI implementations

5. **Observability**
   - Structured logging throughout
   - Event-driven notifications
   - Easy to add telemetry

### Design Patterns Used ✅

- **Dependency Injection** - ServiceContainer
- **Repository Pattern** - IConfigRepository interface
- **Observer Pattern** - EventBus pub/sub
- **Factory Pattern** - Profile.FromHashtable()
- **Value Object Pattern** - SystemResources
- **Domain Entity Pattern** - Profile, Configuration

## 🔄 Migration Path

### Phase 1: ✅ DONE
- [x] Create folder structure
- [x] Implement Domain entities
- [x] Implement Value Objects
- [x] Create EventBus
- [x] Create Logger
- [x] Create Bootstrap & DI Container
- [x] Test architecture

### Phase 2: IN PROGRESS
- [ ] Implement ProfileService
- [ ] Implement ConfigRepository (file-based)
- [ ] Implement ProfileRepository
- [ ] Implement WSLAdapter
- [ ] Refactor existing GUI to use services

### Phase 3: PLANNED
- [ ] Implement API REST server
- [ ] Implement Scheduler service
- [ ] Implement Telemetry service
- [ ] Create Web Dashboard
- [ ] Add Health Checks

### Phase 4: PLANNED
- [ ] Complete test suite
- [ ] Add ML-based optimization
- [ ] Cloud sync feature
- [ ] Multi-distribution support

## 🧪 Testing

### Unit Tests (Planned)

```powershell
# Run all tests
Invoke-Pester ./tests/unit/

# Run specific test
Invoke-Pester ./tests/unit/Profile.Tests.ps1
```

### Test Structure

```
tests/
├── unit/
│   ├── Profile.Tests.ps1
│   ├── Configuration.Tests.ps1
│   ├── SystemResources.Tests.ps1
│   ├── EventBus.Tests.ps1
│   └── Logger.Tests.ps1
├── integration/
│   ├── ConfigRepository.Tests.ps1
│   └── ProfileService.Tests.ps1
└── e2e/
    └── ApplyProfile.Tests.ps1
```

## 📚 Documentation

- `ARCHITECTURE_PROPOSAL.md` - Detailed architecture documentation
- `src/README.md` - This file
- Individual class documentation in source files

## 🎓 Learning Resources

- **Clean Architecture** - Robert C. Martin
- **Domain-Driven Design** - Eric Evans
- **Dependency Injection in .NET** - Mark Seemann
- **Enterprise Integration Patterns** - Gregor Hohpe

## 🤝 Contributing

When adding new features:

1. Follow the layered architecture
2. Add interfaces for dependencies
3. Use dependency injection
4. Add structured logging
5. Publish events for important actions
6. Write unit tests
7. Update documentation

## 📝 Notes

- All PowerShell classes require PS 5.0+
- Logger writes to `%APPDATA%\WSL-Memory-Monitor\logs`
- EventBus is thread-safe for synchronous operations
- Domain entities are mutable (by design for this app)
- Value Objects are immutable

## 🐛 Known Limitations

- ServiceContainer is basic (no constructor injection)
- EventBus doesn't persist events
- Logger doesn't support remote logging yet
- No metrics collection yet

These will be addressed in future phases.

---

**Status:** Phase 1 Complete ✅ | Phase 2 In Progress 🚧

Last Updated: 2025-11-11
