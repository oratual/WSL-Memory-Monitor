# WSL Memory Monitor - Complete Testing Guide

This guide walks you through testing all features of the WSL Memory Monitor as an end user.

## Prerequisites

- Windows 10/11 with WSL2 installed
- PowerShell 5.0 or higher
- Administrator privileges (for some features)

## Test Workflow

### 1. Architecture Validation (5 minutes)

First, verify that the new architecture loads correctly:

```powershell
# Run the architecture test
.\test-architecture.ps1
```

**Expected Results:**
- All 10 tests pass (Logger, EventBus, Domain Models, ProfileFactory, ProfileService, ConfigurationManager, WSLService, SchedulerService, TelemetryService, Event System)
- No errors or exceptions
- Services resolve correctly from DI container

**What to check:**
- ✓ Logger writes to console and file
- ✓ EventBus publishes and receives events
- ✓ Profiles generate correctly based on your system RAM
- ✓ WSL status is detected
- ✓ Daemon status is reported (available/unavailable)

---

### 2. Unit Tests (2 minutes)

Run the unit tests to verify core logic:

```powershell
# Run all unit tests
.\tests\run-tests.ps1
```

**Expected Results:**
- All test files pass (ProfileTests.ps1, ConfigurationTests.ps1)
- No assertion failures

---

### 3. Bootstrap Test (3 minutes)

Verify the Bootstrap loads all components:

```powershell
# Run Bootstrap directly
.\src\Bootstrap.ps1
```

**Expected Results:**
- Architecture banner displays
- All components load without errors
- Test output shows all 10 integration tests passing
- Summary lists all available services

---

### 4. Original GUI Test (5 minutes)

Test the existing PowerShell GUI (without new architecture):

```powershell
# Run the original GUI
.\WSL-Memory-Switch.ps1
```

**Test Steps:**
1. Verify menu displays with 5 dynamic profiles based on your RAM
2. Check that Windows/WSL allocations are shown correctly
3. Try selecting a profile (Profile 3: Balanced recommended for testing)
4. If daemon is not installed, confirm it asks for WSL restart
5. If daemon is installed, confirm it applies changes immediately
6. Try Custom Mode (option 6):
   - Enter custom RAM allocation (e.g., 12GB)
   - Enter custom CPU allocation (e.g., 6 CPUs)
   - Verify validation works (warnings for low Windows allocation)
7. Try viewing current configuration (if applicable)

**Expected Results:**
- Profiles are generated dynamically based on system RAM
- All allocations respect min/max constraints
- Custom mode validates input correctly
- Changes apply successfully (with or without restart)

---

### 5. CLI Test (5 minutes)

Test the Bash CLI from within WSL:

```bash
# From within WSL
./wsl-memory-switch-cli.sh
```

**Test Steps:**
1. Verify menu displays with 5 profiles
2. Check system information shows correctly
3. Try selecting a profile
4. Try custom configuration option
5. View current configuration

**Expected Results:**
- CLI displays same profiles as GUI
- System detection works
- Profile application works
- Configuration is readable

---

### 6. Installer Test (10 minutes)

Test the automated installer:

```powershell
# Run installer
.\Setup-WSLMemoryMonitor.ps1 -Install
```

**Test Steps:**
1. Verify it detects your system resources
2. Check it creates desktop shortcuts
3. Verify Start Menu shortcuts are created
4. Confirm auto-start entry is added (if selected)
5. Check that WSL tools are installed

**Expected Results:**
- Installer completes without errors
- Shortcuts work correctly
- WSL CLI tools are accessible
- Paths are configured automatically

---

### 7. Dynamic Mode Test (10 minutes)

**Only if daemon is installed.** If not installed, test the installer's daemon installation:

```powershell
# Install daemon via installer
.\Setup-WSLMemoryMonitor.ps1 -InstallDaemon
```

Then from WSL:

```bash
# Check daemon status
systemctl status wsl-memory-daemon

# View daemon logs
journalctl -u wsl-memory-daemon -f
```

**Test Steps:**
1. Apply a profile from PowerShell GUI
2. Verify daemon detects the change (check logs)
3. Confirm memory limit is applied via cgroups
4. Check that WSL does NOT restart
5. Verify memory allocation from WSL:
   ```bash
   free -h
   ```

**Expected Results:**
- Daemon applies changes within 5 seconds
- No WSL restart required
- Memory limits are enforced
- Logs show configuration updates

---

### 8. Traditional Mode Test (5 minutes)

**Test without daemon** (stop daemon if installed):

```bash
# Stop daemon
sudo systemctl stop wsl-memory-daemon
```

```powershell
# Apply a profile
.\WSL-Memory-Switch.ps1
# Select a different profile
```

**Expected Results:**
- System prompts for WSL restart
- Configuration is written to .wslconfig
- After restart, new allocation is active

---

### 9. Scheduler Test (Optional - 5 minutes)

Test the new SchedulerService:

```powershell
# Load Bootstrap
. .\src\Bootstrap.ps1
$app = Get-WSLMemoryMonitorApp

# Get scheduler
$scheduler = $app.Container.Resolve("SchedulerService")

# Create a test schedule (runs tomorrow at 10 AM)
$scheduler.AddSchedule("Morning Profile", "10:00 *", "BALANCED")

# View schedules
$scheduler.GetSchedules() | Format-Table

# Get status
$scheduler.GetStatus()

# Remove test schedule
$schedules = $scheduler.GetSchedules()
$scheduler.RemoveSchedule($schedules[0].Id)
```

**Expected Results:**
- Schedule is created successfully
- Next run time is calculated correctly
- Schedule can be removed

---

### 10. Telemetry Test (Optional - 5 minutes)

Test the TelemetryService:

```powershell
# Load Bootstrap
. .\src\Bootstrap.ps1
$app = Get-WSLMemoryMonitorApp

# Get telemetry service
$telemetry = $app.Container.Resolve("TelemetryService")

# Track some events
$telemetry.TrackEvent("test.event", @{ TestData = "value" })

# Get statistics
$stats = $telemetry.GetStatistics(30)
$stats

# Export to JSON
$telemetry.ExportToJSON("$env:USERPROFILE\Desktop\telemetry.json", 30)
```

**Expected Results:**
- Events are tracked
- Statistics are calculated
- Export creates valid JSON file

---

### 11. Backup/Restore Test (5 minutes)

Test configuration backup and restore:

```powershell
. .\src\Bootstrap.ps1
$app = Get-WSLMemoryMonitorApp

$configManager = $app.Container.Resolve("ConfigurationManager")

# Create a backup
$configManager.CreateBackup("before-test")

# List backups
$backups = $configManager.ListBackups()
$backups

# Restore backup (if needed)
# $configManager.RestoreBackup("before-test")

# View history
$history = $configManager.GetHistory(5)
$history | Format-Table
```

**Expected Results:**
- Backup is created successfully
- Backups are listed
- Restore works (if tested)
- History shows recent changes

---

### 12. ProfileFactory Strategies Test (Optional - 5 minutes)

Test different profile generation strategies:

```powershell
. .\src\Bootstrap.ps1
$app = Get-WSLMemoryMonitorApp

$factory = $app.Container.Resolve("ProfileFactory")

# List available strategies
$strategies = $factory.GetAvailableStrategies()
Write-Host "Available strategies: $($strategies -join ', ')"

# Compare all strategies
$comparison = $factory.CompareStrategies($app.SystemResources)

foreach ($strategy in $comparison.Keys) {
    Write-Host "`n$strategy Strategy:"
    $comparison[$strategy].Profiles | Format-Table Name, RAM_GB, CPUs, Category
}
```

**Expected Results:**
- Multiple strategies are available
- Each strategy generates different profiles
- All profiles are valid for your system

---

## Common Issues and Solutions

### Issue 1: "Service not registered" error

**Solution:** Make sure Bootstrap.ps1 is loaded:
```powershell
. .\src\Bootstrap.ps1
$app = Get-WSLMemoryMonitorApp
```

### Issue 2: Daemon not available

**Solution:** Install the daemon:
```powershell
.\Setup-WSLMemoryMonitor.ps1 -InstallDaemon
```

### Issue 3: WSL restart fails

**Solution:** Manually restart WSL:
```powershell
wsl --shutdown
wsl
```

### Issue 4: Permission denied errors

**Solution:** Run PowerShell as Administrator

### Issue 5: Profiles not generating

**Solution:** Check system detection:
```powershell
. .\src\Bootstrap.ps1
$app = Get-WSLMemoryMonitorApp
$app.SystemResources | Format-List
```

---

## Test Checklist

Use this checklist to track your testing:

- [ ] Architecture validation passes
- [ ] Unit tests pass
- [ ] Bootstrap loads successfully
- [ ] Original GUI works with dynamic profiles
- [ ] CLI works correctly
- [ ] Installer completes successfully
- [ ] Dynamic mode applies changes without restart (if daemon installed)
- [ ] Traditional mode applies changes with restart
- [ ] Scheduler can create/remove schedules
- [ ] Telemetry tracks events and exports data
- [ ] Backup/restore works correctly
- [ ] Multiple profile strategies work
- [ ] Custom profiles can be created
- [ ] Validation prevents invalid configurations
- [ ] Events are published and received correctly

---

## Performance Test (Optional)

Test system performance under different profiles:

1. Apply "GAMING" profile
2. Run a game or Windows app
3. Note Windows performance

4. Apply "WSL_FOCUS" profile
5. Run a WSL workload (e.g., compilation)
6. Note WSL performance

7. Apply "BALANCED" profile
8. Run both Windows and WSL tasks
9. Verify balanced performance

---

## Success Criteria

The system is working correctly if:

✓ All tests pass without errors
✓ Profiles are generated based on actual system RAM
✓ Configuration applies successfully (with or without restart)
✓ Custom profiles can be created and validated
✓ Backup/restore functionality works
✓ Events are tracked correctly
✓ Logs are written properly
✓ No crashes or exceptions occur

---

## Reporting Issues

If you find any issues during testing:

1. Note the exact steps to reproduce
2. Copy any error messages
3. Check logs at `%USERPROFILE%\.wsl-memory-monitor\logs`
4. Include your system information:
   ```powershell
   . .\src\Bootstrap.ps1
   $app = Get-WSLMemoryMonitorApp
   $app.SystemResources | Format-List
   ```

---

## Next Steps After Testing

Once all tests pass:

1. Choose your preferred default profile
2. Set up scheduler (optional) for automatic switching
3. Review telemetry data to understand your usage patterns
4. Create custom profiles for specific workflows
5. Configure auto-start if desired

Enjoy your optimized WSL memory management!
