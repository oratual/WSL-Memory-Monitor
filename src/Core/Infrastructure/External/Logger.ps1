# Structured Logging Implementation
# Supports multiple outputs: File, Console, EventLog

class Logger {
    [LogLevel]$MinLevel
    [string]$LogDirectory
    [bool]$EnableConsole
    [bool]$EnableFile
    [string]$CurrentLogFile

    Logger([LogLevel]$minLevel, [string]$logDir, [bool]$console, [bool]$file) {
        $this.MinLevel = $minLevel
        $this.LogDirectory = $logDir
        $this.EnableConsole = $console
        $this.EnableFile = $file

        if ($this.EnableFile) {
            if (-not (Test-Path $this.LogDirectory)) {
                New-Item -ItemType Directory -Path $this.LogDirectory -Force | Out-Null
            }
            $this.CurrentLogFile = Join-Path $this.LogDirectory "wsl-memory-monitor-$(Get-Date -Format 'yyyy-MM-dd').log"
        }
    }

    # Log at different levels
    [void] Debug([string]$message, [hashtable]$context = @{}) {
        $this.Log([LogLevel]::Debug, $message, $context)
    }

    [void] Info([string]$message, [hashtable]$context = @{}) {
        $this.Log([LogLevel]::Info, $message, $context)
    }

    [void] Warn([string]$message, [hashtable]$context = @{}) {
        $this.Log([LogLevel]::Warn, $message, $context)
    }

    [void] Error([string]$message, [hashtable]$context = @{}) {
        $this.Log([LogLevel]::Error, $message, $context)
    }

    # Core log method
    hidden [void] Log([LogLevel]$level, [string]$message, [hashtable]$context) {
        if ($level -lt $this.MinLevel) {
            return
        }

        $logEntry = $this.CreateLogEntry($level, $message, $context)

        if ($this.EnableConsole) {
            $this.WriteToConsole($logEntry)
        }

        if ($this.EnableFile) {
            $this.WriteToFile($logEntry)
        }
    }

    # Create structured log entry
    hidden [hashtable] CreateLogEntry([LogLevel]$level, [string]$message, [hashtable]$context) {
        return @{
            Timestamp = Get-Date -Format "o"
            Level = $level.ToString()
            Message = $message
            Context = $context
            Machine = $env:COMPUTERNAME
            User = $env:USERNAME
            ProcessId = $PID
        }
    }

    # Write to console with colors
    hidden [void] WriteToConsole([hashtable]$entry) {
        $color = switch ($entry.Level) {
            "Debug" { "Gray" }
            "Info" { "White" }
            "Warn" { "Yellow" }
            "Error" { "Red" }
            default { "White" }
        }

        $contextStr = if ($entry.Context.Count -gt 0) {
            " | Context: $($entry.Context | ConvertTo-Json -Compress)"
        } else {
            ""
        }

        Write-Host "[$($entry.Timestamp)] [$($entry.Level)] $($entry.Message)$contextStr" -ForegroundColor $color
    }

    # Write to file as JSON
    hidden [void] WriteToFile([hashtable]$entry) {
        try {
            $json = $entry | ConvertTo-Json -Compress
            Add-Content -Path $this.CurrentLogFile -Value $json -Encoding UTF8
        } catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }

    # Query logs (basic implementation)
    [hashtable[]] Query([DateTime]$since, [LogLevel]$minLevel = [LogLevel]::Debug) {
        if (-not $this.EnableFile -or -not (Test-Path $this.CurrentLogFile)) {
            return @()
        }

        $logs = Get-Content $this.CurrentLogFile | ForEach-Object {
            try {
                $entry = $_ | ConvertFrom-Json
                if ([DateTime]::Parse($entry.Timestamp) -ge $since -and
                    [LogLevel]$entry.Level -ge $minLevel) {
                    return $entry
                }
            } catch {
                # Skip malformed entries
            }
        }

        return $logs
    }

    # Rotate log files (keep last N days)
    [void] RotateLogs([int]$keepDays) {
        $cutoffDate = (Get-Date).AddDays(-$keepDays)
        Get-ChildItem $this.LogDirectory -Filter "*.log" | Where-Object {
            $_.LastWriteTime -lt $cutoffDate
        } | Remove-Item -Force
    }

    # Static factory for default logger
    static [Logger] CreateDefault() {
        $logDir = Join-Path $env:APPDATA "WSL-Memory-Monitor\logs"
        return [Logger]::new([LogLevel]::Info, $logDir, $true, $true)
    }
}

# Interface for dependency injection
interface ILogger {
    [void] Debug([string]$message, [hashtable]$context)
    [void] Info([string]$message, [hashtable]$context)
    [void] Warn([string]$message, [hashtable]$context)
    [void] Error([string]$message, [hashtable]$context)
}

enum LogLevel {
    Debug = 0
    Info = 1
    Warn = 2
    Error = 3
}
