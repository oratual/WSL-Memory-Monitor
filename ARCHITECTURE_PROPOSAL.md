# WSL Memory Monitor - Architecture Proposal
## Propuesta de Arquitectura Mejorada

### 📋 Resumen Ejecutivo

Este documento propone una refactorización arquitectural del proyecto WSL Memory Monitor para mejorar mantenibilidad, escalabilidad, testabilidad y agregar funcionalidades avanzadas.

---

## 🏗️ Arquitectura Propuesta

### 1. Layered Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Presentation Layer                       │
│  - PowerShell GUI (Windows Forms)                        │
│  - CLI Interface (Bash/PowerShell)                       │
│  - Web Dashboard (React + REST API)                      │
│  - System Tray (NotifyIcon)                              │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│               Application Services Layer                  │
│  - ProfileService: Gestión de perfiles                   │
│  - SchedulerService: Tareas programadas                  │
│  - OptimizationService: Auto-optimización                │
│  - TelemetryService: Métricas y analytics                │
│  - NotificationService: Alertas y notificaciones          │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│                    Domain Layer                           │
│  - Profile (Entity)                                       │
│  - SystemResources (Value Object)                         │
│  - Configuration (Aggregate)                              │
│  - WorkloadPattern (Domain Service)                       │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│               Infrastructure Layer                        │
│  - WSLAdapter: Interacción con WSL                       │
│  - CgroupsAdapter: Control de cgroups                    │
│  - FileSystemAdapter: I/O de archivos                    │
│  - WindowsAPIAdapter: APIs de Windows                    │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│                Data Access Layer                          │
│  - ConfigRepository: Persistencia de configuración        │
│  - TelemetryRepository: Almacén de métricas               │
│  - ProfileRepository: Gestión de perfiles guardados       │
└──────────────────────────────────────────────────────────┘
```

---

## 🎯 Patrones de Diseño

### 1. Repository Pattern

**Propósito:** Abstraer el acceso a datos

```powershell
# Interface
interface IConfigRepository {
    [Configuration] Get()
    [void] Save([Configuration]$config)
    [Configuration[]] GetHistory()
    [void] Backup([string]$name)
    [void] Restore([string]$name)
}

# Implementation
class FileConfigRepository : IConfigRepository {
    [string]$configPath

    [Configuration] Get() {
        $content = Get-Content $this.configPath
        return [ConfigParser]::Parse($content)
    }

    [void] Save([Configuration]$config) {
        $content = [ConfigSerializer]::Serialize($config)
        Set-Content $this.configPath $content
    }
}
```

### 2. Strategy Pattern

**Propósito:** Diferentes estrategias de aplicación de perfiles

```powershell
interface IProfileApplicationStrategy {
    [void] Apply([Profile]$profile)
}

class DynamicProfileStrategy : IProfileApplicationStrategy {
    [void] Apply([Profile]$profile) {
        # Aplicar usando daemon (sin reinicio)
        $this.daemonService.ApplyProfile($profile)
    }
}

class RestartProfileStrategy : IProfileApplicationStrategy {
    [void] Apply([Profile]$profile) {
        # Aplicar con reinicio tradicional
        $this.configRepo.Save($profile.ToConfig())
        $this.wslService.Restart()
    }
}
```

### 3. Factory Pattern

**Propósito:** Crear perfiles dinámicamente

```powershell
class ProfileFactory {
    [Profile] CreateGaming([SystemResources]$resources) {
        $wslRAM = [Math]::Max(4, [Math]::Min(8, $resources.TotalRAM * 0.125))
        $wslCPU = [Math]::Max(2, $resources.TotalCPUs * 0.25)

        return [Profile]::new(
            "GAMING",
            $wslRAM,
            $wslCPU,
            "Maximum Windows performance"
        )
    }

    [Profile[]] CreateAllProfiles([SystemResources]$resources) {
        return @(
            $this.CreateGaming($resources),
            $this.CreateWindowsFocus($resources),
            $this.CreateBalanced($resources),
            $this.CreateWSLDev($resources),
            $this.CreateWSLFocus($resources)
        )
    }
}
```

### 4. Observer Pattern

**Propósito:** Sincronizar componentes cuando cambia la configuración

```powershell
interface IConfigObserver {
    [void] OnConfigChanged([Configuration]$newConfig)
}

class TrayIconObserver : IConfigObserver {
    [void] OnConfigChanged([Configuration]$newConfig) {
        $this.UpdateIcon($newConfig.CurrentProfile)
        $this.UpdateTooltip($newConfig)
    }
}

class DaemonObserver : IConfigObserver {
    [void] OnConfigChanged([Configuration]$newConfig) {
        $this.ApplyDynamically($newConfig)
    }
}

class ConfigurationManager {
    [List[IConfigObserver]]$observers = @()

    [void] Subscribe([IConfigObserver]$observer) {
        $this.observers.Add($observer)
    }

    [void] NotifyChange([Configuration]$config) {
        foreach ($observer in $this.observers) {
            $observer.OnConfigChanged($config)
        }
    }
}
```

### 5. Command Pattern

**Propósito:** Deshacer/Rehacer cambios de perfil

```powershell
interface ICommand {
    [void] Execute()
    [void] Undo()
}

class ApplyProfileCommand : ICommand {
    [Profile]$newProfile
    [Profile]$previousProfile
    [IProfileService]$profileService

    [void] Execute() {
        $this.profileService.Apply($this.newProfile)
    }

    [void] Undo() {
        $this.profileService.Apply($this.previousProfile)
    }
}

class CommandHistory {
    [Stack[ICommand]]$history = @()

    [void] Execute([ICommand]$command) {
        $command.Execute()
        $this.history.Push($command)
    }

    [void] Undo() {
        if ($this.history.Count -gt 0) {
            $command = $this.history.Pop()
            $command.Undo()
        }
    }
}
```

---

## 🌐 API REST Propuesta

### Endpoints

```
# Profiles
GET    /api/v1/profiles                    # List all available profiles
GET    /api/v1/profiles/current            # Get current profile
POST   /api/v1/profiles/apply              # Apply a profile
POST   /api/v1/profiles/custom             # Create custom profile

# System
GET    /api/v1/system/resources            # Get system resources
GET    /api/v1/system/status               # Get WSL status
POST   /api/v1/system/restart              # Restart WSL

# Configuration
GET    /api/v1/config                      # Get current config
PATCH  /api/v1/config                      # Update config
GET    /api/v1/config/history              # Get config history
POST   /api/v1/config/backup               # Create backup
POST   /api/v1/config/restore              # Restore backup

# Telemetry
GET    /api/v1/telemetry/usage             # Get usage stats
GET    /api/v1/telemetry/recommendations   # Get AI recommendations

# Scheduler
GET    /api/v1/schedules                   # List schedules
POST   /api/v1/schedules                   # Create schedule
DELETE /api/v1/schedules/:id               # Delete schedule

# Health
GET    /api/v1/health                      # Health check
GET    /api/v1/health/diagnostics          # Run diagnostics
```

### Ejemplos de Uso

```bash
# Get current profile
curl http://localhost:8080/api/v1/profiles/current

{
  "name": "BALANCED",
  "memory": "24GB",
  "cpus": 12,
  "appliedAt": "2025-11-11T10:30:00Z"
}

# Apply profile
curl -X POST http://localhost:8080/api/v1/profiles/apply \
  -H "Content-Type: application/json" \
  -d '{"name": "WSL-FOCUS", "dynamic": true}'

{
  "success": true,
  "profile": "WSL-FOCUS",
  "memory": "48GB",
  "cpus": 20,
  "appliedDynamically": true
}

# Get system resources
curl http://localhost:8080/api/v1/system/resources

{
  "totalRAM": 64,
  "totalCPUs": 24,
  "cpuName": "AMD Ryzen 9 5900X",
  "wslVersion": "2.0.9",
  "distributions": ["Ubuntu", "Debian"]
}
```

---

## 📊 Modelo de Datos

### Entidades

```powershell
class Profile {
    [string]$Name
    [int]$WSL_RAM_GB
    [int]$WSL_CPUs
    [string]$Description
    [ProfileCategory]$Category
    [DateTime]$CreatedAt
    [DateTime]$LastUsed

    [Configuration] ToConfiguration() {
        # Convert to WSL config format
    }
}

enum ProfileCategory {
    Gaming
    WindowsFocus
    Balanced
    WSLDev
    WSLFocus
    Custom
}

class Configuration {
    [string]$Memory
    [int]$Processors
    [int]$Swap
    [bool]$GuiApplications
    [NetworkMode]$NetworkingMode
    [bool]$DnsTunneling
    [bool]$Firewall
    [ExperimentalConfig]$Experimental

    [string] Serialize() {
        # Convert to .wslconfig format
    }
}

class SystemResources {
    [int]$TotalRAM_GB
    [int]$TotalCPUs
    [string]$CPUName
    [string]$OSVersion
    [string]$WSLVersion
    [string[]]$Distributions
}

class UsageMetrics {
    [DateTime]$Timestamp
    [string]$ProfileName
    [int]$MemoryUsed_GB
    [int]$MemoryAllocated_GB
    [double]$CPUUsage_Percent
    [TimeSpan]$Duration
}

class Schedule {
    [string]$Id
    [string]$Name
    [string]$CronExpression
    [string]$ProfileName
    [bool]$Enabled
    [DateTime]$NextRun
}
```

---

## 🔄 Event-Driven Architecture

### Event Bus

```powershell
class EventBus {
    [Hashtable]$subscribers = @{}

    [void] Subscribe([string]$eventType, [ScriptBlock]$handler) {
        if (-not $this.subscribers.ContainsKey($eventType)) {
            $this.subscribers[$eventType] = @()
        }
        $this.subscribers[$eventType] += $handler
    }

    [void] Publish([string]$eventType, [object]$eventData) {
        if ($this.subscribers.ContainsKey($eventType)) {
            foreach ($handler in $this.subscribers[$eventType]) {
                & $handler $eventData
            }
        }
    }
}
```

### Eventos Propuestos

```
ProfileChanged
├─ Data: OldProfile, NewProfile, Timestamp, User
├─ Subscribers: TrayIcon, Telemetry, Logger, Dashboard

SystemResourcesChanged
├─ Data: NewResources, Delta
├─ Subscribers: ProfileRecalculator, Dashboard

WSLRestarted
├─ Data: Reason, Duration
├─ Subscribers: Logger, Telemetry, NotificationService

MemoryThresholdExceeded
├─ Data: CurrentUsage, Threshold, Profile
├─ Subscribers: NotificationService, OptimizationService

DaemonStatusChanged
├─ Data: OldStatus, NewStatus
├─ Subscribers: GUI, TrayIcon, HealthMonitor
```

---

## 📈 Telemetría y Analytics

### Métricas a Recopilar

```powershell
class TelemetryService {
    [void] TrackProfileChange([string]$from, [string]$to) {
        $this.telemetryRepo.Record(@{
            EventType = "ProfileChange"
            From = $from
            To = $to
            Timestamp = Get-Date
            User = $env:USERNAME
        })
    }

    [void] TrackMemoryUsage() {
        $usage = $this.systemMonitor.GetMemoryUsage()
        $this.telemetryRepo.Record(@{
            EventType = "MemoryUsage"
            WSL_Used = $usage.WSL_Used
            WSL_Allocated = $usage.WSL_Allocated
            Windows_Free = $usage.Windows_Free
            Timestamp = Get-Date
        })
    }

    [UsageReport] GetUsageReport([TimeSpan]$period) {
        $metrics = $this.telemetryRepo.GetMetrics($period)
        return [UsageAnalyzer]::Analyze($metrics)
    }
}
```

### Dashboard de Analytics

```
┌─────────────────────────────────────────────────────────┐
│  Usage Analytics - Last 30 Days                         │
├─────────────────────────────────────────────────────────┤
│  Profile Usage:                                         │
│    GAMING:      15% (45 hours)                          │
│    BALANCED:    40% (120 hours)                         │
│    WSL-FOCUS:   45% (135 hours)                         │
│                                                         │
│  Memory Efficiency:                                     │
│    Average Allocated: 32GB                              │
│    Average Used:      24GB                              │
│    Efficiency:        75%                               │
│                                                         │
│  Recommendations:                                       │
│    💡 You could use BALANCED profile and save 8GB       │
│    💡 Consider scheduling GAMING for evenings only      │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing Strategy

### Pirámide de Testing

```
        /\
       /E2E\           ← 10% End-to-End Tests
      /──────\
     /Integr.\        ← 20% Integration Tests
    /──────────\
   /Unit Tests \      ← 70% Unit Tests
  /──────────────\
```

### Estructura de Tests

```
tests/
├── unit/
│   ├── ProfileService.Tests.ps1
│   ├── ConfigRepository.Tests.ps1
│   ├── ProfileFactory.Tests.ps1
│   └── SystemResourcesDetector.Tests.ps1
├── integration/
│   ├── WSLAdapter.Tests.ps1
│   ├── DaemonCommunication.Tests.ps1
│   └── API.Tests.ps1
└── e2e/
    ├── ApplyProfile.Tests.ps1
    ├── ScheduledProfile.Tests.ps1
    └── DynamicApplication.Tests.ps1
```

### Ejemplo de Test

```powershell
Describe "ProfileFactory" {
    Context "When creating gaming profile" {
        It "Should allocate 12.5% RAM with min 4GB" {
            # Arrange
            $resources = [SystemResources]::new(32, 16, "Test CPU")
            $factory = [ProfileFactory]::new()

            # Act
            $profile = $factory.CreateGaming($resources)

            # Assert
            $profile.WSL_RAM_GB | Should -Be 4
            $profile.WSL_CPUs | Should -Be 4
        }

        It "Should not exceed 8GB even on 128GB system" {
            # Arrange
            $resources = [SystemResources]::new(128, 32, "Test CPU")
            $factory = [ProfileFactory]::new()

            # Act
            $profile = $factory.CreateGaming($resources)

            # Assert
            $profile.WSL_RAM_GB | Should -BeLessOrEqual 8
        }
    }
}
```

---

## 🔐 Seguridad

### Consideraciones

1. **Validación de Input:**
   - Sanitizar todos los inputs del usuario
   - Validar rangos de memoria y CPUs
   - Prevenir command injection

2. **Privilegios:**
   - Principio de menor privilegio
   - Elevar privilegios solo cuando necesario
   - Auditar acciones administrativas

3. **API Security:**
   - Authentication con tokens
   - Rate limiting
   - CORS apropiado
   - HTTPS solo

4. **Datos Sensibles:**
   - No guardar credenciales
   - Encriptar telemetría si contiene info sensible
   - Logs sin información personal

---

## 📦 Estructura de Proyecto Propuesta

```
WSL-Memory-Monitor/
├── src/
│   ├── Core/
│   │   ├── Domain/
│   │   │   ├── Entities/
│   │   │   │   ├── Profile.ps1
│   │   │   │   ├── Configuration.ps1
│   │   │   │   └── Schedule.ps1
│   │   │   ├── ValueObjects/
│   │   │   │   ├── SystemResources.ps1
│   │   │   │   └── MemoryAllocation.ps1
│   │   │   └── Services/
│   │   │       └── ProfileCalculator.ps1
│   │   ├── Application/
│   │   │   ├── Services/
│   │   │   │   ├── ProfileService.ps1
│   │   │   │   ├── SchedulerService.ps1
│   │   │   │   ├── TelemetryService.ps1
│   │   │   │   └── OptimizationService.ps1
│   │   │   └── Interfaces/
│   │   │       ├── IConfigRepository.ps1
│   │   │       ├── IProfileRepository.ps1
│   │   │       └── IWSLService.ps1
│   │   └── Infrastructure/
│   │       ├── Repositories/
│   │       │   ├── FileConfigRepository.ps1
│   │       │   └── SQLiteTelemetryRepository.ps1
│   │       ├── Adapters/
│   │       │   ├── WSLAdapter.ps1
│   │       │   ├── CgroupsAdapter.ps1
│   │       │   └── WindowsAPIAdapter.ps1
│   │       └── External/
│   │           └── EventBus.ps1
│   ├── Presentation/
│   │   ├── GUI/
│   │   │   ├── MainWindow.ps1
│   │   │   └── TrayIcon.ps1
│   │   ├── CLI/
│   │   │   └── CommandHandler.sh
│   │   └── API/
│   │       ├── Controllers/
│   │       │   ├── ProfilesController.ps1
│   │       │   ├── SystemController.ps1
│   │       │   └── ConfigController.ps1
│   │       └── Server.ps1
│   └── Daemon/
│       ├── MemoryDaemon.sh
│       └── DaemonService.service
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── config/
│   ├── appsettings.json
│   └── appsettings.Development.json
├── docs/
│   ├── architecture/
│   ├── api/
│   └── user-guide/
└── scripts/
    ├── setup/
    ├── build/
    └── deploy/
```

---

## 🚀 Plan de Implementación

### Fase 1: Fundamentos (2-3 semanas)
- [ ] Refactorizar a clases y separación de capas
- [ ] Implementar Repository Pattern
- [ ] Configuración centralizada
- [ ] Logging estructurado
- [ ] Tests unitarios básicos

### Fase 2: API y Comunicación (2 semanas)
- [ ] Implementar API REST local
- [ ] Event Bus
- [ ] Migrar componentes a usar API

### Fase 3: Features Avanzados (3-4 semanas)
- [ ] Scheduler
- [ ] Telemetría
- [ ] Dashboard web
- [ ] Auto-optimización

### Fase 4: Refinamiento (1-2 semanas)
- [ ] Tests completos
- [ ] Documentación
- [ ] Performance optimization
- [ ] Security audit

---

## 💰 Beneficios de la Refactorización

### Técnicos:
- ✅ Código más mantenible y testeable
- ✅ Separación clara de responsabilidades
- ✅ Fácil de extender con nuevas features
- ✅ Mejor manejo de errores
- ✅ Reutilización de código

### Para Usuarios:
- ✅ Más confiable y estable
- ✅ Más features (scheduler, analytics, etc.)
- ✅ Mejor experiencia (dashboard web)
- ✅ Optimización automática
- ✅ Sincronización multi-dispositivo

### Para Desarrollo:
- ✅ Onboarding más fácil para contribuidores
- ✅ Tests automatizados → menos bugs
- ✅ CI/CD más simple
- ✅ Documentación clara
- ✅ Escalabilidad

---

## 📚 Referencias

- **Clean Architecture** by Robert C. Martin
- **Domain-Driven Design** by Eric Evans
- **Enterprise Integration Patterns** by Gregor Hohpe
- **Microservices Patterns** by Chris Richardson
- **PowerShell Best Practices** - Microsoft Docs

---

## 🎯 Conclusión

Esta propuesta transforma WSL Memory Monitor de un conjunto de scripts a una aplicación empresarial robusta, manteniendo la simplicidad de uso pero agregando capacidades profesionales de monitoreo, optimización y gestión de recursos.

La implementación gradual permite adoptar estas mejoras sin romper la funcionalidad existente, y cada fase agrega valor incremental al proyecto.
