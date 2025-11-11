# TelemetryService - Tracks usage metrics and analytics
# Privacy-focused telemetry without external data transmission

class MetricEntry {
    [DateTime]$Timestamp
    [string]$EventType
    [hashtable]$Data

    MetricEntry([string]$eventType, [hashtable]$data) {
        $this.Timestamp = Get-Date
        $this.EventType = $eventType
        $this.Data = $data
    }

    [hashtable] ToHashtable() {
        return @{
            Timestamp = $this.Timestamp.ToString("o")
            EventType = $this.EventType
            Data = $this.Data
        }
    }
}

class TelemetryService {
    [ILogger]$logger
    [EventBus]$eventBus
    [string]$metricsPath
    [string]$currentSessionId
    [DateTime]$sessionStart
    [hashtable]$sessionMetrics = @{}

    TelemetryService([ILogger]$logger, [EventBus]$eventBus) {
        $this.logger = $logger
        $this.eventBus = $eventBus

        # Set metrics storage path
        $this.metricsPath = Join-Path $env:USERPROFILE ".wsl-memory-monitor\metrics"

        # Ensure directory exists
        if (-not (Test-Path $this.metricsPath)) {
            New-Item -ItemType Directory -Path $this.metricsPath -Force | Out-Null
        }

        # Initialize session
        $this.StartSession()

        # Subscribe to events for automatic tracking
        $this.SubscribeToEvents()
    }

    # Start new session
    [void] StartSession() {
        $this.currentSessionId = [Guid]::NewGuid().ToString()
        $this.sessionStart = Get-Date

        $this.sessionMetrics = @{
            SessionId = $this.currentSessionId
            StartTime = $this.sessionStart
            ProfileChanges = 0
            WSLRestarts = 0
            ConfigurationChanges = 0
            CustomProfilesCreated = 0
            BackupsCreated = 0
            BackupsRestored = 0
            SchedulesCreated = 0
            Events = @()
        }

        $this.logger.Debug("Telemetry session started", @{
            SessionId = $this.currentSessionId
        })
    }

    # End current session
    [void] EndSession() {
        $this.sessionMetrics.EndTime = Get-Date
        $this.sessionMetrics.Duration = ($this.sessionMetrics.EndTime - $this.sessionStart).TotalMinutes

        $this.SaveSession()

        $this.logger.Debug("Telemetry session ended", @{
            SessionId = $this.currentSessionId
            Duration = $this.sessionMetrics.Duration
        })
    }

    # Track event
    [void] TrackEvent([string]$eventType, [hashtable]$data = @{}) {
        $entry = [MetricEntry]::new($eventType, $data)

        $this.sessionMetrics.Events += $entry.ToHashtable()

        $this.logger.Debug("Event tracked", @{
            EventType = $eventType
            SessionId = $this.currentSessionId
        })
    }

    # Track profile change
    [void] TrackProfileChange([string]$fromProfile, [string]$toProfile, [bool]$isDynamic) {
        $this.sessionMetrics.ProfileChanges++

        $this.TrackEvent("profile.changed", @{
            FromProfile = $fromProfile
            ToProfile = $toProfile
            IsDynamic = $isDynamic
        })
    }

    # Track WSL restart
    [void] TrackWSLRestart([bool]$success, [double]$durationSeconds) {
        $this.sessionMetrics.WSLRestarts++

        $this.TrackEvent("wsl.restart", @{
            Success = $success
            DurationSeconds = $durationSeconds
        })
    }

    # Track configuration change
    [void] TrackConfigurationChange([hashtable]$changes) {
        $this.sessionMetrics.ConfigurationChanges++

        $this.TrackEvent("configuration.changed", @{
            Changes = $changes
        })
    }

    # Track custom profile creation
    [void] TrackCustomProfile([string]$profileName, [int]$ramGB, [int]$cpus) {
        $this.sessionMetrics.CustomProfilesCreated++

        $this.TrackEvent("custom.profile.created", @{
            ProfileName = $profileName
            RAM_GB = $ramGB
            CPUs = $cpus
        })
    }

    # Get usage statistics
    [hashtable] GetStatistics([int]$days = 30) {
        $this.logger.Debug("Getting usage statistics", @{ Days = $days })

        try {
            $sessions = $this.LoadRecentSessions($days)

            $stats = @{
                TotalSessions = $sessions.Count
                TotalProfileChanges = ($sessions | Measure-Object -Property ProfileChanges -Sum).Sum
                TotalWSLRestarts = ($sessions | Measure-Object -Property WSLRestarts -Sum).Sum
                TotalConfigChanges = ($sessions | Measure-Object -Property ConfigurationChanges -Sum).Sum
                CustomProfilesCreated = ($sessions | Measure-Object -Property CustomProfilesCreated -Sum).Sum
                BackupsCreated = ($sessions | Measure-Object -Property BackupsCreated -Sum).Sum
                TotalDuration = ($sessions | Measure-Object -Property Duration -Sum).Sum
                MostUsedProfiles = $this.CalculateMostUsedProfiles($sessions)
                AverageSessionDuration = if ($sessions.Count -gt 0) {
                    [Math]::Round(($sessions | Measure-Object -Property Duration -Average).Average, 2)
                } else {
                    0
                }
                Period = @{
                    Days = $days
                    From = (Get-Date).AddDays(-$days)
                    To = Get-Date
                }
            }

            return $stats

        } catch {
            $this.logger.Error("Failed to get statistics", @{
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Calculate most used profiles
    hidden [hashtable[]] CalculateMostUsedProfiles([hashtable[]]$sessions) {
        $profileUsage = @{}

        foreach ($session in $sessions) {
            foreach ($event in $session.Events) {
                if ($event.EventType -eq "profile.changed") {
                    $profile = $event.Data.ToProfile
                    if (-not $profileUsage.ContainsKey($profile)) {
                        $profileUsage[$profile] = 0
                    }
                    $profileUsage[$profile]++
                }
            }
        }

        $sorted = $profileUsage.GetEnumerator() |
            Sort-Object Value -Descending |
            Select-Object -First 5

        return $sorted | ForEach-Object {
            @{
                ProfileName = $_.Key
                UsageCount = $_.Value
            }
        }
    }

    # Get profile usage over time
    [hashtable] GetProfileUsageTrend([int]$days = 30) {
        $sessions = $this.LoadRecentSessions($days)
        $trend = @{}

        foreach ($session in $sessions) {
            $date = ([DateTime]$session.StartTime).ToString("yyyy-MM-dd")

            if (-not $trend.ContainsKey($date)) {
                $trend[$date] = @{}
            }

            foreach ($event in $session.Events) {
                if ($event.EventType -eq "profile.changed") {
                    $profile = $event.Data.ToProfile

                    if (-not $trend[$date].ContainsKey($profile)) {
                        $trend[$date][$profile] = 0
                    }
                    $trend[$date][$profile]++
                }
            }
        }

        return $trend
    }

    # Export metrics to CSV
    [void] ExportToCSV([string]$outputPath, [int]$days = 30) {
        $this.logger.Info("Exporting metrics to CSV", @{
            Path = $outputPath
            Days = $days
        })

        try {
            $sessions = $this.LoadRecentSessions($days)
            $events = @()

            foreach ($session in $sessions) {
                foreach ($event in $session.Events) {
                    $events += [PSCustomObject]@{
                        SessionId = $session.SessionId
                        Timestamp = $event.Timestamp
                        EventType = $event.EventType
                        Data = ($event.Data | ConvertTo-Json -Compress)
                    }
                }
            }

            $events | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

            $this.logger.Info("Metrics exported successfully", @{
                EventCount = $events.Count
            })

        } catch {
            $this.logger.Error("Failed to export metrics", @{
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Export metrics to JSON
    [void] ExportToJSON([string]$outputPath, [int]$days = 30) {
        $this.logger.Info("Exporting metrics to JSON", @{
            Path = $outputPath
            Days = $days
        })

        try {
            $sessions = $this.LoadRecentSessions($days)
            $stats = $this.GetStatistics($days)

            $export = @{
                Statistics = $stats
                Sessions = $sessions
                ExportDate = Get-Date
            }

            $json = $export | ConvertTo-Json -Depth 10
            Set-Content -Path $outputPath -Value $json -Encoding UTF8

            $this.logger.Info("Metrics exported successfully")

        } catch {
            $this.logger.Error("Failed to export metrics", @{
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Subscribe to events for automatic tracking
    hidden [void] SubscribeToEvents() {
        $this.eventBus.Subscribe("profile.applied", {
            param($data)
            $this.TrackProfileChange(
                $data.OldProfile,
                $data.NewProfile,
                $data.IsDynamic
            )
        }.GetNewClosure())

        $this.eventBus.Subscribe("wsl.restart.completed", {
            param($data)
            $this.TrackWSLRestart($true, $data.Duration)
        }.GetNewClosure())

        $this.eventBus.Subscribe("config.changed", {
            param($data)
            $this.TrackConfigurationChange($data.Changes)
        }.GetNewClosure())

        $this.eventBus.Subscribe("config.backup.created", {
            param($data)
            $this.sessionMetrics.BackupsCreated++
            $this.TrackEvent("backup.created", $data)
        }.GetNewClosure())

        $this.eventBus.Subscribe("config.backup.restored", {
            param($data)
            $this.sessionMetrics.BackupsRestored++
            $this.TrackEvent("backup.restored", $data)
        }.GetNewClosure())

        $this.eventBus.Subscribe("schedule.added", {
            param($data)
            $this.sessionMetrics.SchedulesCreated++
            $this.TrackEvent("schedule.added", $data)
        }.GetNewClosure())

        $this.logger.Debug("Subscribed to telemetry events")
    }

    # Save current session
    hidden [void] SaveSession() {
        try {
            $sessionFile = Join-Path $this.metricsPath "$($this.currentSessionId).json"
            $json = $this.sessionMetrics | ConvertTo-Json -Depth 10
            Set-Content -Path $sessionFile -Value $json -Encoding UTF8

            $this.logger.Debug("Session saved", @{
                SessionId = $this.currentSessionId
            })

            # Cleanup old sessions (keep last 100)
            $this.CleanupOldSessions(100)

        } catch {
            $this.logger.Error("Failed to save session", @{
                Error = $_.Exception.Message
            })
        }
    }

    # Load recent sessions
    hidden [hashtable[]] LoadRecentSessions([int]$days) {
        try {
            $cutoffDate = (Get-Date).AddDays(-$days)
            $sessionFiles = Get-ChildItem $this.metricsPath -Filter "*.json" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $cutoffDate } |
                Sort-Object LastWriteTime -Descending

            $sessions = @()
            foreach ($file in $sessionFiles) {
                try {
                    $json = Get-Content $file.FullName -Raw
                    $session = $json | ConvertFrom-Json
                    $hashtable = @{}
                    $session.PSObject.Properties | ForEach-Object {
                        $hashtable[$_.Name] = $_.Value
                    }
                    $sessions += $hashtable
                } catch {
                    $this.logger.Warn("Failed to load session file", @{
                        File = $file.Name
                    })
                }
            }

            return $sessions

        } catch {
            $this.logger.Error("Failed to load sessions", @{
                Error = $_.Exception.Message
            })
            return @()
        }
    }

    # Cleanup old sessions
    hidden [void] CleanupOldSessions([int]$keepCount) {
        try {
            $sessionFiles = Get-ChildItem $this.metricsPath -Filter "*.json" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip $keepCount

            foreach ($file in $sessionFiles) {
                Remove-Item $file.FullName -Force
            }

            if ($sessionFiles.Count -gt 0) {
                $this.logger.Debug("Cleaned up old sessions", @{
                    RemovedCount = $sessionFiles.Count
                })
            }

        } catch {
            $this.logger.Warn("Failed to cleanup old sessions", @{
                Error = $_.Exception.Message
            })
        }
    }

    # Clear all metrics
    [void] ClearAll() {
        $this.logger.Info("Clearing all telemetry data")

        try {
            Get-ChildItem $this.metricsPath -Filter "*.json" |
                Remove-Item -Force

            $this.StartSession()

            $this.logger.Info("Telemetry data cleared")

        } catch {
            $this.logger.Error("Failed to clear telemetry", @{
                Error = $_.Exception.Message
            })
            throw
        }
    }
}
