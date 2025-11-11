# SchedulerService - Manages scheduled profile switches
# Supports cron-like scheduling for automatic profile changes

class ScheduleEntry {
    [string]$Id
    [string]$Name
    [string]$CronExpression
    [string]$ProfileName
    [DateTime]$NextRun
    [DateTime]$LastRun
    [bool]$Enabled
    [int]$ExecutionCount

    ScheduleEntry([string]$name, [string]$cron, [string]$profileName) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Name = $name
        $this.CronExpression = $cron
        $this.ProfileName = $profileName
        $this.NextRun = $this.CalculateNextRun()
        $this.LastRun = [DateTime]::MinValue
        $this.Enabled = $true
        $this.ExecutionCount = 0
    }

    # Calculate next run time based on cron expression
    # Simplified cron: "HH:mm DayOfWeek" or "HH:mm *" for daily
    [DateTime] CalculateNextRun() {
        try {
            $parts = $this.CronExpression -split ' '
            if ($parts.Length -ne 2) {
                throw "Invalid cron format. Use: 'HH:mm DayOfWeek' or 'HH:mm *'"
            }

            $time = [DateTime]::Parse($parts[0])
            $dayOfWeek = $parts[1]

            $now = Get-Date
            $next = Get-Date -Hour $time.Hour -Minute $time.Minute -Second 0

            # If daily schedule (*)
            if ($dayOfWeek -eq '*') {
                if ($next -le $now) {
                    $next = $next.AddDays(1)
                }
                return $next
            }

            # If specific day of week
            $targetDay = [System.DayOfWeek]$dayOfWeek

            # Find next occurrence of target day
            while ($next.DayOfWeek -ne $targetDay -or $next -le $now) {
                $next = $next.AddDays(1)
            }

            return $next

        } catch {
            # Default to tomorrow at noon if parsing fails
            return (Get-Date).AddDays(1).Date.AddHours(12)
        }
    }

    # Check if schedule should run now
    [bool] ShouldRun() {
        return $this.Enabled -and (Get-Date) -ge $this.NextRun
    }

    # Mark as executed
    [void] MarkExecuted() {
        $this.LastRun = Get-Date
        $this.ExecutionCount++
        $this.NextRun = $this.CalculateNextRun()
    }

    # Serialize to hashtable
    [hashtable] ToHashtable() {
        return @{
            Id = $this.Id
            Name = $this.Name
            CronExpression = $this.CronExpression
            ProfileName = $this.ProfileName
            NextRun = $this.NextRun.ToString("o")
            LastRun = $this.LastRun.ToString("o")
            Enabled = $this.Enabled
            ExecutionCount = $this.ExecutionCount
        }
    }

    # Deserialize from hashtable
    static [ScheduleEntry] FromHashtable([hashtable]$data) {
        $entry = [ScheduleEntry]::new($data.Name, $data.CronExpression, $data.ProfileName)
        $entry.Id = $data.Id
        $entry.NextRun = [DateTime]::Parse($data.NextRun)
        $entry.LastRun = [DateTime]::Parse($data.LastRun)
        $entry.Enabled = $data.Enabled
        $entry.ExecutionCount = $data.ExecutionCount
        return $entry
    }
}

class SchedulerService {
    [EventBus]$eventBus
    [ILogger]$logger
    [ProfileService]$profileService
    [string]$schedulePath
    [ScheduleEntry[]]$schedules = @()
    [bool]$isRunning = $false

    SchedulerService(
        [EventBus]$eventBus,
        [ILogger]$logger,
        [ProfileService]$profileService
    ) {
        $this.eventBus = $eventBus
        $this.logger = $logger
        $this.profileService = $profileService

        # Set schedule storage path
        $this.schedulePath = Join-Path $env:USERPROFILE ".wsl-memory-monitor\schedules.json"

        # Ensure directory exists
        $scheduleDir = Split-Path $this.schedulePath -Parent
        if (-not (Test-Path $scheduleDir)) {
            New-Item -ItemType Directory -Path $scheduleDir -Force | Out-Null
        }

        # Load existing schedules
        $this.LoadSchedules()
    }

    # Add a schedule
    [void] AddSchedule([string]$name, [string]$cronExpression, [string]$profileName) {
        $this.logger.Info("Adding schedule", @{
            Name = $name
            Cron = $cronExpression
            Profile = $profileName
        })

        try {
            $entry = [ScheduleEntry]::new($name, $cronExpression, $profileName)
            $this.schedules += $entry

            $this.SaveSchedules()

            $this.eventBus.Publish("schedule.added", @{
                Schedule = $entry.ToHashtable()
            })

            $this.logger.Info("Schedule added", @{
                Name = $name
                NextRun = $entry.NextRun
            })

        } catch {
            $this.logger.Error("Failed to add schedule", @{
                Name = $name
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Remove a schedule
    [void] RemoveSchedule([string]$id) {
        $this.logger.Info("Removing schedule", @{ Id = $id })

        $schedule = $this.schedules | Where-Object { $_.Id -eq $id } | Select-Object -First 1

        if ($null -eq $schedule) {
            throw "Schedule not found: $id"
        }

        $this.schedules = $this.schedules | Where-Object { $_.Id -ne $id }
        $this.SaveSchedules()

        $this.eventBus.Publish("schedule.removed", @{
            Schedule = $schedule.ToHashtable()
        })

        $this.logger.Info("Schedule removed", @{ Name = $schedule.Name })
    }

    # Enable/disable a schedule
    [void] SetScheduleEnabled([string]$id, [bool]$enabled) {
        $schedule = $this.schedules | Where-Object { $_.Id -eq $id } | Select-Object -First 1

        if ($null -eq $schedule) {
            throw "Schedule not found: $id"
        }

        $schedule.Enabled = $enabled
        $this.SaveSchedules()

        $this.logger.Info("Schedule updated", @{
            Name = $schedule.Name
            Enabled = $enabled
        })
    }

    # Get all schedules
    [ScheduleEntry[]] GetSchedules() {
        return $this.schedules
    }

    # Get enabled schedules
    [ScheduleEntry[]] GetEnabledSchedules() {
        return $this.schedules | Where-Object { $_.Enabled }
    }

    # Check and execute due schedules
    [void] CheckSchedules() {
        $due = $this.GetEnabledSchedules() | Where-Object { $_.ShouldRun() }

        foreach ($schedule in $due) {
            $this.ExecuteSchedule($schedule)
        }
    }

    # Execute a specific schedule
    [void] ExecuteSchedule([ScheduleEntry]$schedule) {
        $this.logger.Info("Executing schedule", @{
            Name = $schedule.Name
            Profile = $schedule.ProfileName
        })

        try {
            # Find profile
            $profiles = $this.profileService.GenerateProfiles()
            $profile = $profiles | Where-Object { $_.Name -eq $schedule.ProfileName } | Select-Object -First 1

            if ($null -eq $profile) {
                throw "Profile not found: $($schedule.ProfileName)"
            }

            # Apply profile
            $this.profileService.ApplyProfile($profile, $false)

            # Mark as executed
            $schedule.MarkExecuted()
            $this.SaveSchedules()

            $this.eventBus.Publish("schedule.executed", @{
                Schedule = $schedule.ToHashtable()
                Profile = $profile.ToHashtable()
            })

            $this.logger.Info("Schedule executed successfully", @{
                Name = $schedule.Name
                NextRun = $schedule.NextRun
            })

        } catch {
            $this.logger.Error("Failed to execute schedule", @{
                Name = $schedule.Name
                Error = $_.Exception.Message
            })

            $this.eventBus.Publish("schedule.failed", @{
                Schedule = $schedule.ToHashtable()
                Error = $_.Exception.Message
            })
        }
    }

    # Start scheduler background loop
    [void] Start() {
        if ($this.isRunning) {
            $this.logger.Warn("Scheduler already running")
            return
        }

        $this.logger.Info("Starting scheduler")
        $this.isRunning = $true

        $this.eventBus.Publish("scheduler.started", @{})
    }

    # Stop scheduler
    [void] Stop() {
        if (-not $this.isRunning) {
            return
        }

        $this.logger.Info("Stopping scheduler")
        $this.isRunning = $false

        $this.eventBus.Publish("scheduler.stopped", @{})
    }

    # Get scheduler status
    [hashtable] GetStatus() {
        $nextSchedule = $this.GetEnabledSchedules() |
            Sort-Object NextRun |
            Select-Object -First 1

        return @{
            IsRunning = $this.isRunning
            TotalSchedules = $this.schedules.Count
            EnabledSchedules = ($this.GetEnabledSchedules()).Count
            NextSchedule = if ($null -ne $nextSchedule) {
                @{
                    Name = $nextSchedule.Name
                    Profile = $nextSchedule.ProfileName
                    NextRun = $nextSchedule.NextRun
                }
            } else {
                $null
            }
        }
    }

    # Save schedules to disk
    hidden [void] SaveSchedules() {
        try {
            $data = @{
                Version = "1.0"
                Schedules = $this.schedules | ForEach-Object { $_.ToHashtable() }
            }

            $json = $data | ConvertTo-Json -Depth 10
            Set-Content -Path $this.schedulePath -Value $json -Encoding UTF8

            $this.logger.Debug("Schedules saved", @{ Count = $this.schedules.Count })

        } catch {
            $this.logger.Error("Failed to save schedules", @{
                Error = $_.Exception.Message
            })
        }
    }

    # Load schedules from disk
    hidden [void] LoadSchedules() {
        try {
            if (-not (Test-Path $this.schedulePath)) {
                $this.logger.Debug("No schedule file found, starting fresh")
                return
            }

            $json = Get-Content $this.schedulePath -Raw
            $data = $json | ConvertFrom-Json

            $this.schedules = @()
            foreach ($scheduleData in $data.Schedules) {
                $hashtable = @{}
                $scheduleData.PSObject.Properties | ForEach-Object {
                    $hashtable[$_.Name] = $_.Value
                }
                $this.schedules += [ScheduleEntry]::FromHashtable($hashtable)
            }

            $this.logger.Info("Schedules loaded", @{ Count = $this.schedules.Count })

        } catch {
            $this.logger.Error("Failed to load schedules", @{
                Error = $_.Exception.Message
            })
        }
    }

    # Create common schedules (helper method)
    [void] CreateWorkdaySchedules() {
        # Work hours: WSL Dev profile
        $this.AddSchedule(
            "Workday Start",
            "09:00 Monday",
            "WSL Dev"
        )

        # Evening: Balanced profile
        $this.AddSchedule(
            "Evening Balance",
            "18:00 *",
            "Balanced"
        )

        # Weekend: Gaming profile
        $this.AddSchedule(
            "Weekend Gaming",
            "10:00 Saturday",
            "Gaming"
        )
    }
}
