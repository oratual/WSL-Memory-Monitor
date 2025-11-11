# WSLService - Manages WSL lifecycle and operations
# Handles WSL restart, shutdown, status checks, and distribution management

class WSLService {
    [EventBus]$eventBus
    [ILogger]$logger
    [int]$restartTimeoutSeconds = 60

    WSLService([EventBus]$eventBus, [ILogger]$logger) {
        $this.eventBus = $eventBus
        $this.logger = $logger
    }

    # Check if WSL is running
    [bool] IsRunning() {
        try {
            $process = Get-Process -Name "wsl" -ErrorAction SilentlyContinue
            return $null -ne $process
        } catch {
            return $false
        }
    }

    # Get WSL status
    [hashtable] GetStatus() {
        $this.logger.Debug("Getting WSL status")

        try {
            $isRunning = $this.IsRunning()
            $distributions = $this.GetDistributions()
            $version = $this.GetVersion()

            return @{
                IsRunning = $isRunning
                Version = $version
                Distributions = $distributions
                DistributionCount = $distributions.Count
            }
        } catch {
            $this.logger.Error("Failed to get WSL status", @{
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Get WSL version
    [string] GetVersion() {
        try {
            $output = wsl --version 2>&1 | Select-Object -First 1
            if ($output -match '(\d+\.\d+\.\d+)') {
                return $matches[1]
            }
            return "Unknown"
        } catch {
            $this.logger.Warn("Failed to get WSL version")
            return "Unknown"
        }
    }

    # Get list of distributions
    [hashtable[]] GetDistributions() {
        try {
            $output = wsl --list --verbose 2>&1
            $distributions = @()

            foreach ($line in $output) {
                # Parse WSL list output
                if ($line -match '^\s*(\*?)\s*(\S+)\s+(\w+)\s+(\d+)') {
                    $distributions += @{
                        Name = $matches[2]
                        State = $matches[3]
                        Version = $matches[4]
                        IsDefault = $matches[1] -eq '*'
                    }
                }
            }

            return $distributions
        } catch {
            $this.logger.Error("Failed to get distributions", @{
                Error = $_.Exception.Message
            })
            return @()
        }
    }

    # Shutdown WSL
    [void] Shutdown() {
        $this.logger.Info("Shutting down WSL")

        try {
            $this.eventBus.Publish("wsl.shutdown.started", @{})

            wsl --shutdown 2>&1 | Out-Null

            # Wait for shutdown
            $timeout = 30
            $elapsed = 0
            while ($this.IsRunning() -and $elapsed -lt $timeout) {
                Start-Sleep -Seconds 1
                $elapsed++
            }

            if ($this.IsRunning()) {
                throw "WSL shutdown timeout after $timeout seconds"
            }

            $this.eventBus.Publish("wsl.shutdown.completed", @{})
            $this.logger.Info("WSL shutdown completed")

        } catch {
            $this.logger.Error("Failed to shutdown WSL", @{
                Error = $_.Exception.Message
            })

            $this.eventBus.Publish("wsl.shutdown.failed", @{
                Error = $_.Exception.Message
            })

            throw
        }
    }

    # Restart WSL
    [void] Restart() {
        $this.logger.Info("Restarting WSL")

        try {
            $this.eventBus.Publish("wsl.restart.started", @{})

            # Shutdown first
            $this.Shutdown()

            # Wait a bit before starting
            Start-Sleep -Seconds 2

            # Start default distribution
            $this.Start()

            $this.eventBus.Publish("wsl.restart.completed", @{})
            $this.logger.Info("WSL restart completed")

        } catch {
            $this.logger.Error("Failed to restart WSL", @{
                Error = $_.Exception.Message
            })

            $this.eventBus.Publish("wsl.restart.failed", @{
                Error = $_.Exception.Message
            })

            throw
        }
    }

    # Start WSL (default distribution)
    [void] Start() {
        $this.logger.Info("Starting WSL")

        try {
            # Start WSL by running a simple command
            wsl echo "WSL started" 2>&1 | Out-Null

            # Wait for WSL to be running
            $timeout = 30
            $elapsed = 0
            while (-not $this.IsRunning() -and $elapsed -lt $timeout) {
                Start-Sleep -Seconds 1
                $elapsed++
            }

            if (-not $this.IsRunning()) {
                throw "WSL start timeout after $timeout seconds"
            }

            $this.logger.Info("WSL started successfully")

        } catch {
            $this.logger.Error("Failed to start WSL", @{
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Restart specific distribution
    [void] RestartDistribution([string]$distribution) {
        $this.logger.Info("Restarting distribution", @{ Distribution = $distribution })

        try {
            # Terminate distribution
            wsl --terminate $distribution 2>&1 | Out-Null
            Start-Sleep -Seconds 1

            # Start distribution
            wsl -d $distribution echo "Distribution started" 2>&1 | Out-Null

            $this.logger.Info("Distribution restarted", @{ Distribution = $distribution })

        } catch {
            $this.logger.Error("Failed to restart distribution", @{
                Distribution = $distribution
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Execute command in WSL
    [string] ExecuteCommand([string]$command, [string]$distribution = $null) {
        $this.logger.Debug("Executing WSL command", @{
            Command = $command
            Distribution = $distribution
        })

        try {
            if ($null -ne $distribution -and $distribution -ne "") {
                $output = wsl -d $distribution -- bash -c $command 2>&1
            } else {
                $output = wsl -- bash -c $command 2>&1
            }

            return $output
        } catch {
            $this.logger.Error("Failed to execute command", @{
                Command = $command
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Check if daemon is available
    [bool] IsDaemonAvailable() {
        try {
            $result = $this.ExecuteCommand("systemctl is-active wsl-memory-daemon 2>/dev/null")
            return $result -match "active"
        } catch {
            return $false
        }
    }

    # Get daemon status
    [hashtable] GetDaemonStatus() {
        if (-not $this.IsDaemonAvailable()) {
            return @{
                Available = $false
                Active = $false
                Message = "Daemon not installed or not running"
            }
        }

        try {
            $status = $this.ExecuteCommand("systemctl status wsl-memory-daemon --no-pager 2>/dev/null")

            return @{
                Available = $true
                Active = $status -match "Active: active"
                Status = $status
            }
        } catch {
            return @{
                Available = $true
                Active = $false
                Error = $_.Exception.Message
            }
        }
    }

    # Trigger daemon reload (forces immediate config check)
    [void] TriggerDaemonReload() {
        if (-not $this.IsDaemonAvailable()) {
            throw "Daemon not available"
        }

        $this.logger.Info("Triggering daemon reload")

        try {
            # Send SIGHUP to daemon to force reload
            $this.ExecuteCommand("systemctl reload wsl-memory-daemon 2>/dev/null")

            $this.eventBus.Publish("daemon.reloaded", @{})
            $this.logger.Info("Daemon reload triggered")

        } catch {
            $this.logger.Error("Failed to trigger daemon reload", @{
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Apply configuration with restart
    [void] ApplyConfigurationWithRestart([string]$message = "Applying configuration") {
        $this.logger.Info($message)

        try {
            Write-Host "`n⚠️  WSL restart required to apply changes" -ForegroundColor Yellow
            Write-Host "This will close all WSL sessions" -ForegroundColor Yellow

            $confirm = Read-Host "`nProceed with restart? (y/n)"

            if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                Write-Host "`nRestarting WSL..." -ForegroundColor Cyan

                $this.Restart()

                Write-Host "✓ WSL restarted successfully" -ForegroundColor Green
                Write-Host "Configuration applied!" -ForegroundColor Green
            } else {
                Write-Host "`nRestart cancelled. Changes will apply on next WSL restart." -ForegroundColor Yellow
            }

        } catch {
            Write-Host "✗ Failed to restart WSL: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }

    # Get memory usage from WSL
    [hashtable] GetMemoryUsage() {
        try {
            # Get memory info from WSL
            $totalMem = $this.ExecuteCommand("free -g | awk '/^Mem:/ {print `$2}'")
            $usedMem = $this.ExecuteCommand("free -g | awk '/^Mem:/ {print `$3}'")
            $availMem = $this.ExecuteCommand("free -g | awk '/^Mem:/ {print `$7}'")

            return @{
                Total_GB = [int]$totalMem
                Used_GB = [int]$usedMem
                Available_GB = [int]$availMem
                UsedPercent = if ([int]$totalMem -gt 0) {
                    [Math]::Round(([int]$usedMem / [int]$totalMem) * 100, 1)
                } else {
                    0
                }
            }
        } catch {
            $this.logger.Warn("Failed to get WSL memory usage", @{
                Error = $_.Exception.Message
            })

            return @{
                Total_GB = 0
                Used_GB = 0
                Available_GB = 0
                UsedPercent = 0
                Error = $_.Exception.Message
            }
        }
    }
}
