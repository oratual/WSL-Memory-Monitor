# ProfileService - Core business logic for profile management
# Implements profile generation, application, and recommendations

class ProfileService {
    [ILogger]$logger
    [EventBus]$eventBus
    [SystemResources]$systemResources
    [IConfigRepository]$configRepository

    ProfileService(
        [ILogger]$logger,
        [EventBus]$eventBus,
        [SystemResources]$systemResources,
        [IConfigRepository]$configRepository
    ) {
        $this.logger = $logger
        $this.eventBus = $eventBus
        $this.systemResources = $systemResources
        $this.configRepository = $configRepository
    }

    # Generate all dynamic profiles for current system
    [Profile[]] GenerateProfiles() {
        $this.logger.Info("Generating dynamic profiles", @{
            RAM = "$($this.systemResources.TotalRAM_GB)GB"
            CPUs = $this.systemResources.TotalCPUs
        })

        $totalRAM = $this.systemResources.TotalRAM_GB
        $totalCPUs = $this.systemResources.TotalCPUs

        # Profile 1: GAMING - 12.5% RAM (min 4GB, max 8GB)
        $p1_ram = [Math]::Max(4, [Math]::Min(8, [Math]::Floor($totalRAM * 0.125)))
        $p1_cpu = [Math]::Max(2, [Math]::Floor($totalCPUs * 0.25))

        # Profile 2: WINDOWS FOCUS - 25% RAM (min 8GB)
        $p2_ram = [Math]::Max(8, [Math]::Floor($totalRAM * 0.25))
        $p2_cpu = [Math]::Max(4, [Math]::Floor($totalCPUs * 0.33))

        # Profile 3: BALANCED - 37.5% RAM (min 12GB)
        $p3_ram = [Math]::Max(12, [Math]::Floor($totalRAM * 0.375))
        $p3_cpu = [Math]::Max(6, [Math]::Floor($totalCPUs * 0.50))

        # Profile 4: WSL DEV - 50% RAM (min 16GB)
        $p4_ram = [Math]::Max(16, [Math]::Floor($totalRAM * 0.50))
        $p4_cpu = [Math]::Max(8, [Math]::Floor($totalCPUs * 0.67))

        # Profile 5: WSL FOCUS - 75% RAM (min 24GB, leave 8GB for Windows)
        $p5_ram = [Math]::Max(24, [Math]::Min($totalRAM - 8, [Math]::Floor($totalRAM * 0.75)))
        $p5_cpu = [Math]::Max(12, [Math]::Floor($totalCPUs * 0.83))

        return @(
            [Profile]::new("GAMING", $p1_ram, $p1_cpu, "Maximum Windows performance for gaming and streaming", [ProfileCategory]::Gaming),
            [Profile]::new("WINDOWS-FOCUS", $p2_ram, $p2_cpu, "Windows priority for video editing, design, VMs", [ProfileCategory]::WindowsFocus),
            [Profile]::new("BALANCED", $p3_ram, $p3_cpu, "Balanced allocation for mixed usage", [ProfileCategory]::Balanced),
            [Profile]::new("WSL-DEV", $p4_ram, $p4_cpu, "WSL priority for development and Docker", [ProfileCategory]::WSLDev),
            [Profile]::new("WSL-FOCUS", $p5_ram, $p5_cpu, "Maximum WSL for intensive development and compilation", [ProfileCategory]::WSLFocus)
        )
    }

    # Get profile by name
    [Profile] GetProfileByName([string]$name) {
        $profiles = $this.GenerateProfiles()
        $profile = $profiles | Where-Object { $_.Name -eq $name.ToUpper() }

        if ($null -eq $profile) {
            throw "Profile '$name' not found"
        }

        return $profile
    }

    # Apply profile (dynamic if daemon available, otherwise traditional)
    [void] ApplyProfile([Profile]$profile, [bool]$forceDynamic = $false) {
        $this.logger.Info("Applying profile", @{
            Profile = $profile.Name
            RAM = "$($profile.WSL_RAM_GB)GB"
            CPUs = $profile.WSL_CPUs
        })

        # Validate profile
        if (-not $profile.IsValidFor($this.systemResources)) {
            $this.logger.Error("Profile is not valid for this system", @{
                Profile = $profile.Name
                SystemRAM = $this.systemResources.TotalRAM_GB
            })
            throw "Profile validation failed"
        }

        # Get current profile for event
        $currentConfig = $this.configRepository.Get()
        $oldProfileName = $currentConfig.AppliedProfile

        # Create configuration from profile
        $config = $profile.ToConfiguration()
        $config.AppliedProfile = $profile.Name

        # Check if daemon is available
        $daemonAvailable = $this.IsDaemonAvailable()

        if ($forceDynamic -or $daemonAvailable) {
            # Try dynamic application
            try {
                $this.ApplyDynamic($profile)

                # Also save to config for persistence
                $this.configRepository.Save($config)

                # Publish event
                $event = [ProfileChangedEvent]::new($oldProfileName, $profile.Name, $true)
                $this.eventBus.Publish("ProfileChanged", $event)

                $this.logger.Info("Profile applied dynamically", @{ Profile = $profile.Name })
                return
            } catch {
                $this.logger.Warn("Dynamic application failed, falling back to traditional", @{
                    Error = $_.Exception.Message
                })
            }
        }

        # Traditional application (requires restart)
        $this.configRepository.Save($config)

        # Publish event
        $event = [ProfileChangedEvent]::new($oldProfileName, $profile.Name, $false)
        $this.eventBus.Publish("ProfileChanged", $event)

        $this.logger.Info("Profile saved, WSL restart required", @{ Profile = $profile.Name })
    }

    # Apply profile dynamically using daemon
    hidden [void] ApplyDynamic([Profile]$profile) {
        $result = wsl -e bash -c "wsl-memory-daemon set $($profile.WSL_RAM_GB) $($profile.WSL_CPUs) 2>&1"
        if ($LASTEXITCODE -ne 0) {
            throw "Daemon command failed: $result"
        }
    }

    # Check if daemon is available
    hidden [bool] IsDaemonAvailable() {
        try {
            $status = wsl -e bash -c "wsl-memory-daemon status 2>&1 | grep -q 'RUNNING' && echo 'true' || echo 'false'" 2>$null
            return ($status -eq 'true')
        } catch {
            return $false
        }
    }

    # Create custom profile
    [Profile] CreateCustomProfile([string]$name, [int]$ramGB, [int]$cpus) {
        $this.logger.Info("Creating custom profile", @{
            Name = $name
            RAM = "${ramGB}GB"
            CPUs = $cpus
        })

        $profile = [Profile]::new($name, $ramGB, $cpus, "Custom profile", [ProfileCategory]::Custom)
        $profile.IsCustom = $true

        # Validate
        if (-not $profile.IsValidFor($this.systemResources)) {
            throw "Custom profile exceeds system resources"
        }

        return $profile
    }

    # Get current profile
    [Profile] GetCurrentProfile() {
        $config = $this.configRepository.Get()
        $memoryGB = $config.GetMemoryGB()

        # Try to match with generated profiles
        $profiles = $this.GenerateProfiles()
        foreach ($profile in $profiles) {
            if ($profile.WSL_RAM_GB -eq $memoryGB -and $profile.WSL_CPUs -eq $config.Processors) {
                return $profile
            }
        }

        # Return custom profile
        return [Profile]::new("CUSTOM", $memoryGB, $config.Processors, "Custom configuration", [ProfileCategory]::Custom)
    }

    # Get profile recommendations based on usage
    [hashtable] GetRecommendations() {
        $currentProfile = $this.GetCurrentProfile()
        $tier = $this.systemResources.GetTier()

        $recommendations = @{
            CurrentProfile = $currentProfile.Name
            Tier = $tier.ToString()
            Suggestions = @()
        }

        # Basic recommendations based on tier
        switch ($tier) {
            "Low" {
                $recommendations.Suggestions += "System has limited RAM. Consider GAMING or WINDOWS-FOCUS profiles."
            }
            "Medium" {
                $recommendations.Suggestions += "System has moderate RAM. BALANCED profile recommended for general use."
            }
            "High" {
                $recommendations.Suggestions += "System has good RAM. WSL-DEV recommended for development work."
            }
            "VeryHigh" {
                $recommendations.Suggestions += "System has excellent RAM. WSL-FOCUS recommended for heavy workloads."
            }
        }

        return $recommendations
    }

    # Get allocation summary
    [hashtable] GetAllocationSummary([Profile]$profile) {
        $windows = $profile.GetWindowsAllocation(
            $this.systemResources.TotalRAM_GB,
            $this.systemResources.TotalCPUs
        )

        return @{
            Profile = $profile.Name
            WSL = @{
                RAM_GB = $profile.WSL_RAM_GB
                CPUs = $profile.WSL_CPUs
                Percentage = [Math]::Round(($profile.WSL_RAM_GB / $this.systemResources.TotalRAM_GB) * 100, 1)
            }
            Windows = @{
                RAM_GB = $windows.RAM_GB
                CPUs = $windows.CPUs
                Percentage = [Math]::Round(($windows.RAM_GB / $this.systemResources.TotalRAM_GB) * 100, 1)
            }
            System = @{
                TotalRAM_GB = $this.systemResources.TotalRAM_GB
                TotalCPUs = $this.systemResources.TotalCPUs
            }
        }
    }
}
