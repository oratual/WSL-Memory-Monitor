# FileConfigRepository - File-based configuration persistence
# Implements IConfigRepository interface

class FileConfigRepository {
    [string]$configPath
    [string]$backupDir
    [string]$historyDir
    [ILogger]$logger

    FileConfigRepository([string]$configPath, [ILogger]$logger) {
        $this.configPath = $configPath
        $this.logger = $logger
        $this.backupDir = Join-Path (Split-Path $configPath -Parent) ".wslconfig-backups"
        $this.historyDir = Join-Path (Split-Path $configPath -Parent) ".wslconfig-history"

        # Ensure directories exist
        if (-not (Test-Path $this.backupDir)) {
            New-Item -ItemType Directory -Path $this.backupDir -Force | Out-Null
        }
        if (-not (Test-Path $this.historyDir)) {
            New-Item -ItemType Directory -Path $this.historyDir -Force | Out-Null
        }
    }

    # Get current configuration
    [Configuration] Get() {
        $this.logger.Debug("Reading configuration", @{ Path = $this.configPath })

        if (-not (Test-Path $this.configPath)) {
            $this.logger.Warn("Configuration file not found, returning default")
            return $this.GetDefaultConfiguration()
        }

        try {
            $content = Get-Content $this.configPath -Raw -ErrorAction Stop
            $config = [Configuration]::Deserialize($content)
            $this.logger.Debug("Configuration loaded successfully")
            return $config
        } catch {
            $this.logger.Error("Failed to read configuration", @{
                Error = $_.Exception.Message
                Path = $this.configPath
            })
            throw
        }
    }

    # Save configuration
    [void] Save([Configuration]$config) {
        $this.logger.Info("Saving configuration", @{
            Profile = $config.AppliedProfile
            Memory = $config.Memory
            CPUs = $config.Processors
        })

        try {
            # Create backup of current config if it exists
            if (Test-Path $this.configPath) {
                $this.CreateAutoBackup()
            }

            # Save new configuration
            $content = $config.Serialize()
            Set-Content -Path $this.configPath -Value $content -Encoding UTF8 -ErrorAction Stop

            # Save to history
            $this.SaveToHistory($config)

            $this.logger.Info("Configuration saved successfully")
        } catch {
            $this.logger.Error("Failed to save configuration", @{
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Get configuration history
    [Configuration[]] GetHistory([int]$limit) {
        $historyFiles = Get-ChildItem $this.historyDir -Filter "*.wslconfig" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $limit

        $configs = @()
        foreach ($file in $historyFiles) {
            try {
                $content = Get-Content $file.FullName -Raw
                $config = [Configuration]::Deserialize($content)
                $config.LastModified = $file.LastWriteTime
                $configs += $config
            } catch {
                $this.logger.Warn("Failed to load history file", @{ File = $file.Name })
            }
        }

        return $configs
    }

    # Create named backup
    [void] Backup([string]$name) {
        if (-not (Test-Path $this.configPath)) {
            throw "No configuration to backup"
        }

        $backupPath = Join-Path $this.backupDir "$name.wslconfig"
        Copy-Item $this.configPath $backupPath -Force

        $this.logger.Info("Backup created", @{
            Name = $name
            Path = $backupPath
        })
    }

    # Restore from named backup
    [Configuration] Restore([string]$name) {
        $backupPath = Join-Path $this.backupDir "$name.wslconfig"

        if (-not (Test-Path $backupPath)) {
            throw "Backup '$name' not found"
        }

        # Backup current before restoring
        if (Test-Path $this.configPath) {
            $this.CreateAutoBackup()
        }

        # Restore backup
        Copy-Item $backupPath $this.configPath -Force

        $this.logger.Info("Configuration restored", @{ Backup = $name })

        return $this.Get()
    }

    # List available backups
    [string[]] ListBackups() {
        $backups = Get-ChildItem $this.backupDir -Filter "*.wslconfig" -ErrorAction SilentlyContinue |
            ForEach-Object { $_.BaseName }
        return $backups
    }

    # Check if configuration exists
    [bool] Exists() {
        return (Test-Path $this.configPath)
    }

    # Create automatic backup (timestamped)
    hidden [void] CreateAutoBackup() {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = Join-Path $this.backupDir "auto-$timestamp.wslconfig"
        Copy-Item $this.configPath $backupPath -Force

        # Cleanup old auto-backups (keep last 10)
        $autoBackups = Get-ChildItem $this.backupDir -Filter "auto-*.wslconfig" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 10

        foreach ($old in $autoBackups) {
            Remove-Item $old.FullName -Force
        }
    }

    # Save to history
    hidden [void] SaveToHistory([Configuration]$config) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $historyPath = Join-Path $this.historyDir "$timestamp-$($config.AppliedProfile).wslconfig"

        $content = $config.Serialize()
        Set-Content -Path $historyPath -Value $content -Encoding UTF8

        # Cleanup old history (keep last 50)
        $oldHistory = Get-ChildItem $this.historyDir -Filter "*.wslconfig" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 50

        foreach ($old in $oldHistory) {
            Remove-Item $old.FullName -Force
        }
    }

    # Get default configuration
    hidden [Configuration] GetDefaultConfiguration() {
        return [Configuration]::new(
            "16GB",
            8,
            0,
            $false,
            [NetworkMode]::Mirrored,
            $true,
            $true,
            [ExperimentalConfig]::new("gradual", $true)
        )
    }

    # Static factory method
    static [FileConfigRepository] CreateDefault([ILogger]$logger) {
        $configPath = Join-Path $env:USERPROFILE ".wslconfig"
        return [FileConfigRepository]::new($configPath, $logger)
    }
}
