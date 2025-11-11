# Interface: IConfigRepository
# Contract for configuration persistence

interface IConfigRepository {
    # Get current configuration
    [Configuration] Get()

    # Save configuration
    [void] Save([Configuration]$config)

    # Get configuration history
    [Configuration[]] GetHistory([int]$limit)

    # Create backup with name
    [void] Backup([string]$name)

    # Restore from backup
    [Configuration] Restore([string]$name)

    # List available backups
    [string[]] ListBackups()

    # Check if configuration file exists
    [bool] Exists()
}
