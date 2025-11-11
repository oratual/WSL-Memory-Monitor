# ConfigurationManager - Manages configuration lifecycle
# Handles configuration changes, validation, and notifications

class ConfigurationManager {
    [IConfigRepository]$configRepository
    [EventBus]$eventBus
    [ILogger]$logger
    [SystemResources]$systemResources

    ConfigurationManager(
        [IConfigRepository]$configRepo,
        [EventBus]$eventBus,
        [ILogger]$logger,
        [SystemResources]$systemResources
    ) {
        $this.configRepository = $configRepo
        $this.eventBus = $eventBus
        $this.logger = $logger
        $this.systemResources = $systemResources
    }

    # Get current configuration
    [Configuration] GetCurrent() {
        $this.logger.Debug("Getting current configuration")

        try {
            $config = $this.configRepository.Get()
            $this.eventBus.Publish("config.loaded", @{ Configuration = $config })
            return $config
        } catch {
            $this.logger.Error("Failed to get configuration", @{ Error = $_.Exception.Message })
            throw
        }
    }

    # Update configuration with validation
    [void] Update([Configuration]$newConfig) {
        $this.logger.Info("Updating configuration", @{
            Memory = $newConfig.Memory
            Processors = $newConfig.Processors
            Profile = $newConfig.AppliedProfile
        })

        try {
            # Validate configuration
            $this.ValidateConfiguration($newConfig)

            # Get old configuration for comparison
            $oldConfig = $null
            if ($this.configRepository.Exists()) {
                $oldConfig = $this.configRepository.Get()
            }

            # Save new configuration
            $this.configRepository.Save($newConfig)

            # Publish events
            $this.eventBus.Publish("config.changed", @{
                OldConfig = $oldConfig
                NewConfig = $newConfig
            })

            $this.eventBus.Publish("config.saved", @{
                Configuration = $newConfig
            })

            $this.logger.Info("Configuration updated successfully")

        } catch {
            $this.logger.Error("Failed to update configuration", @{
                Error = $_.Exception.Message
            })

            $this.eventBus.Publish("config.error", @{
                Error = $_.Exception.Message
                Configuration = $newConfig
            })

            throw
        }
    }

    # Apply profile as configuration
    [void] ApplyProfile([Profile]$profile) {
        $this.logger.Info("Applying profile as configuration", @{
            ProfileName = $profile.Name
            RAM = $profile.WSL_RAM_GB
            CPUs = $profile.WSL_CPUs
        })

        $config = $profile.ToConfiguration()
        $config.AppliedProfile = $profile.Name

        $this.Update($config)
    }

    # Validate configuration against system resources
    [void] ValidateConfiguration([Configuration]$config) {
        $memoryGB = $config.GetMemoryGB()
        $processors = $config.Processors

        # Check memory limits
        if ($memoryGB -gt $this.systemResources.TotalRAM_GB) {
            throw "Memory allocation ($($memoryGB)GB) exceeds system RAM ($($this.systemResources.TotalRAM_GB)GB)"
        }

        # Check CPU limits
        if ($processors -gt $this.systemResources.TotalCPUs) {
            throw "CPU allocation ($processors) exceeds system CPUs ($($this.systemResources.TotalCPUs))"
        }

        # Check minimum Windows allocation
        $windowsRAM = $this.systemResources.TotalRAM_GB - $memoryGB
        $windowsCPUs = $this.systemResources.TotalCPUs - $processors

        if ($windowsRAM -lt 4) {
            $this.logger.Warn("Low Windows RAM allocation", @{
                WindowsRAM = $windowsRAM
                RecommendedMinimum = 4
            })
        }

        if ($windowsCPUs -lt 1) {
            throw "Must leave at least 1 CPU for Windows"
        }

        $this.logger.Debug("Configuration validated successfully", @{
            Memory = "$($memoryGB)GB"
            Processors = $processors
            WindowsRAM = "$($windowsRAM)GB"
            WindowsCPUs = $windowsCPUs
        })
    }

    # Get configuration history
    [Configuration[]] GetHistory([int]$limit = 10) {
        return $this.configRepository.GetHistory($limit)
    }

    # Create backup
    [void] CreateBackup([string]$name) {
        $this.logger.Info("Creating configuration backup", @{ Name = $name })

        try {
            $this.configRepository.Backup($name)
            $this.eventBus.Publish("config.backup.created", @{ BackupName = $name })

        } catch {
            $this.logger.Error("Failed to create backup", @{
                Name = $name
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Restore from backup
    [Configuration] RestoreBackup([string]$name) {
        $this.logger.Info("Restoring configuration backup", @{ Name = $name })

        try {
            $config = $this.configRepository.Restore($name)

            $this.eventBus.Publish("config.backup.restored", @{
                BackupName = $name
                Configuration = $config
            })

            return $config

        } catch {
            $this.logger.Error("Failed to restore backup", @{
                Name = $name
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # List available backups
    [string[]] ListBackups() {
        return $this.configRepository.ListBackups()
    }

    # Check if configuration exists
    [bool] HasConfiguration() {
        return $this.configRepository.Exists()
    }

    # Get configuration summary
    [hashtable] GetSummary() {
        if (-not $this.HasConfiguration()) {
            return @{
                Exists = $false
                Message = "No configuration found"
            }
        }

        $config = $this.GetCurrent()
        $memoryGB = $config.GetMemoryGB()

        return @{
            Exists = $true
            Profile = $config.AppliedProfile
            Memory = @{
                WSL_GB = $memoryGB
                Windows_GB = $this.systemResources.TotalRAM_GB - $memoryGB
                Total_GB = $this.systemResources.TotalRAM_GB
                WSL_Percent = [Math]::Round(($memoryGB / $this.systemResources.TotalRAM_GB) * 100, 1)
            }
            Processors = @{
                WSL = $config.Processors
                Windows = $this.systemResources.TotalCPUs - $config.Processors
                Total = $this.systemResources.TotalCPUs
            }
            NetworkMode = $config.NetworkingMode.ToString()
            LastModified = $config.LastModified
        }
    }

    # Compare current with desired configuration
    [hashtable] CompareConfigurations([Configuration]$desired) {
        $current = $this.GetCurrent()

        return @{
            IsEqual = $current.Equals($desired)
            Changes = @{
                Memory = @{
                    Current = $current.Memory
                    Desired = $desired.Memory
                    Changed = $current.Memory -ne $desired.Memory
                }
                Processors = @{
                    Current = $current.Processors
                    Desired = $desired.Processors
                    Changed = $current.Processors -ne $desired.Processors
                }
                Swap = @{
                    Current = $current.Swap
                    Desired = $desired.Swap
                    Changed = $current.Swap -ne $desired.Swap
                }
            }
        }
    }
}
