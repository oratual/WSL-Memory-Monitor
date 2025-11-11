# ProfileFactory - Factory with Strategy Pattern for profile generation
# Supports different strategies for creating profiles based on system resources

# Strategy Interface
class IProfileGenerationStrategy {
    [Profile[]] Generate([SystemResources]$resources) {
        throw "Must be implemented by concrete strategy"
    }

    [string] GetName() {
        throw "Must be implemented by concrete strategy"
    }
}

# Percentage-based strategy (current default)
class PercentageStrategy : IProfileGenerationStrategy {
    [Profile[]] Generate([SystemResources]$resources) {
        $totalRAM = $resources.TotalRAM_GB
        $totalCPUs = $resources.TotalCPUs
        $profiles = @()

        # Profile 1: GAMING - 12.5% RAM (min 4GB, max 8GB)
        $p1_ram = [Math]::Max(4, [Math]::Min(8, [Math]::Floor($totalRAM * 0.125)))
        $p1_cpu = [Math]::Max(2, [Math]::Min(4, [Math]::Floor($totalCPUs * 0.25)))

        $profiles += [Profile]::new(
            "GAMING",
            $p1_ram,
            $p1_cpu,
            "Prioritizes Windows performance for gaming",
            [ProfileCategory]::Gaming
        )

        # Profile 2: WINDOWS_FOCUS - 25% RAM
        $p2_ram = [Math]::Floor($totalRAM * 0.25)
        $p2_cpu = [Math]::Max(2, [Math]::Floor($totalCPUs * 0.30))

        $profiles += [Profile]::new(
            "WINDOWS_FOCUS",
            $p2_ram,
            $p2_cpu,
            "Light WSL usage, Windows-focused work",
            [ProfileCategory]::WindowsFocus
        )

        # Profile 3: BALANCED - 37.5% RAM
        $p3_ram = [Math]::Floor($totalRAM * 0.375)
        $p3_cpu = [Math]::Floor($totalCPUs * 0.50)

        $profiles += [Profile]::new(
            "BALANCED",
            $p3_ram,
            $p3_cpu,
            "Equal priority for Windows and WSL",
            [ProfileCategory]::Balanced
        )

        # Profile 4: WSL_DEV - 50% RAM
        $p4_ram = [Math]::Floor($totalRAM * 0.50)
        $p4_cpu = [Math]::Floor($totalCPUs * 0.60)

        $profiles += [Profile]::new(
            "WSL_DEV",
            $p4_ram,
            $p4_cpu,
            "Development-focused, WSL priority",
            [ProfileCategory]::WSLDev
        )

        # Profile 5: WSL_FOCUS - 75% RAM
        $p5_ram = [Math]::Floor($totalRAM * 0.75)
        $p5_cpu = [Math]::Floor($totalCPUs * 0.75)

        $profiles += [Profile]::new(
            "WSL_FOCUS",
            $p5_ram,
            $p5_cpu,
            "Maximum WSL resources, minimal Windows",
            [ProfileCategory]::WSLFocus
        )

        return $profiles
    }

    [string] GetName() {
        return "Percentage-based"
    }
}

# Tier-based strategy (generates profiles based on system tier)
class TierBasedStrategy : IProfileGenerationStrategy {
    [Profile[]] Generate([SystemResources]$resources) {
        $tier = $resources.GetTier()
        $profiles = @()

        switch ($tier) {
            ([ResourceTier]::Low) {
                # Low RAM systems (< 16GB) - conservative profiles
                $profiles += [Profile]::new("LIGHT", 4, 2, "Minimal WSL usage", [ProfileCategory]::WindowsFocus)
                $profiles += [Profile]::new("STANDARD", 6, 3, "Moderate usage", [ProfileCategory]::Balanced)
                $profiles += [Profile]::new("DEV", 8, 4, "Development work", [ProfileCategory]::WSLDev)
            }
            ([ResourceTier]::Medium) {
                # Medium RAM systems (16-31GB) - balanced profiles
                $profiles += [Profile]::new("LIGHT", 6, 4, "Light usage", [ProfileCategory]::WindowsFocus)
                $profiles += [Profile]::new("BALANCED", 10, 6, "Balanced usage", [ProfileCategory]::Balanced)
                $profiles += [Profile]::new("DEV", 14, 8, "Development work", [ProfileCategory]::WSLDev)
                $profiles += [Profile]::new("HEAVY", 18, 10, "Heavy workloads", [ProfileCategory]::WSLFocus)
            }
            ([ResourceTier]::High) {
                # High RAM systems (32-63GB) - generous profiles
                $profiles += [Profile]::new("LIGHT", 12, 6, "Light usage", [ProfileCategory]::WindowsFocus)
                $profiles += [Profile]::new("BALANCED", 20, 10, "Balanced usage", [ProfileCategory]::Balanced)
                $profiles += [Profile]::new("DEV", 28, 14, "Development work", [ProfileCategory]::WSLDev)
                $profiles += [Profile]::new("HEAVY", 36, 18, "Heavy workloads", [ProfileCategory]::WSLFocus)
            }
            ([ResourceTier]::VeryHigh) {
                # Very high RAM systems (64GB+) - maximum profiles
                $profiles += [Profile]::new("LIGHT", 16, 8, "Light usage", [ProfileCategory]::WindowsFocus)
                $profiles += [Profile]::new("BALANCED", 32, 16, "Balanced usage", [ProfileCategory]::Balanced)
                $profiles += [Profile]::new("DEV", 48, 24, "Development work", [ProfileCategory]::WSLDev)
                $profiles += [Profile]::new("HEAVY", 56, 28, "Heavy workloads", [ProfileCategory]::WSLFocus)
            }
        }

        return $profiles
    }

    [string] GetName() {
        return "Tier-based"
    }
}

# Workload-based strategy (optimized for specific workloads)
class WorkloadStrategy : IProfileGenerationStrategy {
    [Profile[]] Generate([SystemResources]$resources) {
        $totalRAM = $resources.TotalRAM_GB
        $totalCPUs = $resources.TotalCPUs
        $profiles = @()

        # Docker/Container workload
        $docker_ram = [Math]::Min($totalRAM - 8, [Math]::Floor($totalRAM * 0.60))
        $docker_cpu = [Math]::Floor($totalCPUs * 0.60)
        $profiles += [Profile]::new(
            "DOCKER",
            $docker_ram,
            $docker_cpu,
            "Optimized for Docker/containers",
            [ProfileCategory]::WSLDev
        )

        # Data Science workload
        $datascience_ram = [Math]::Min($totalRAM - 6, [Math]::Floor($totalRAM * 0.70))
        $datascience_cpu = [Math]::Floor($totalCPUs * 0.70)
        $profiles += [Profile]::new(
            "DATA_SCIENCE",
            $datascience_ram,
            $datascience_cpu,
            "Optimized for data science/ML",
            [ProfileCategory]::WSLFocus
        )

        # Web Development workload
        $webdev_ram = [Math]::Floor($totalRAM * 0.40)
        $webdev_cpu = [Math]::Floor($totalCPUs * 0.50)
        $profiles += [Profile]::new(
            "WEB_DEV",
            $webdev_ram,
            $webdev_cpu,
            "Optimized for web development",
            [ProfileCategory]::WSLDev
        )

        # Compilation workload (CPU-heavy)
        $compile_ram = [Math]::Floor($totalRAM * 0.50)
        $compile_cpu = [Math]::Max($totalCPUs - 2, [Math]::Floor($totalCPUs * 0.80))
        $profiles += [Profile]::new(
            "COMPILATION",
            $compile_ram,
            $compile_cpu,
            "Optimized for compilation tasks",
            [ProfileCategory]::WSLFocus
        )

        return $profiles
    }

    [string] GetName() {
        return "Workload-based"
    }
}

# Conservative strategy (prioritizes Windows, minimal WSL)
class ConservativeStrategy : IProfileGenerationStrategy {
    [Profile[]] Generate([SystemResources]$resources) {
        $totalRAM = $resources.TotalRAM_GB
        $totalCPUs = $resources.TotalCPUs
        $profiles = @()

        # Ultra Light - 10% RAM
        $p1_ram = [Math]::Max(2, [Math]::Floor($totalRAM * 0.10))
        $p1_cpu = [Math]::Max(1, [Math]::Floor($totalCPUs * 0.15))
        $profiles += [Profile]::new(
            "ULTRA_LIGHT",
            $p1_ram,
            $p1_cpu,
            "Minimal WSL footprint",
            [ProfileCategory]::WindowsFocus
        )

        # Light - 20% RAM
        $p2_ram = [Math]::Max(4, [Math]::Floor($totalRAM * 0.20))
        $p2_cpu = [Math]::Max(2, [Math]::Floor($totalCPUs * 0.25))
        $profiles += [Profile]::new(
            "LIGHT",
            $p2_ram,
            $p2_cpu,
            "Light WSL usage",
            [ProfileCategory]::WindowsFocus
        )

        # Moderate - 30% RAM
        $p3_ram = [Math]::Floor($totalRAM * 0.30)
        $p3_cpu = [Math]::Floor($totalCPUs * 0.35)
        $profiles += [Profile]::new(
            "MODERATE",
            $p3_ram,
            $p3_cpu,
            "Moderate WSL usage",
            [ProfileCategory]::Balanced
        )

        return $profiles
    }

    [string] GetName() {
        return "Conservative"
    }
}

# ProfileFactory - Main factory class
class ProfileFactory {
    [ILogger]$logger
    [IProfileGenerationStrategy]$currentStrategy
    [hashtable]$strategies = @{}

    ProfileFactory([ILogger]$logger) {
        $this.logger = $logger

        # Register available strategies
        $this.RegisterStrategy([PercentageStrategy]::new())
        $this.RegisterStrategy([TierBasedStrategy]::new())
        $this.RegisterStrategy([WorkloadStrategy]::new())
        $this.RegisterStrategy([ConservativeStrategy]::new())

        # Set default strategy
        $this.SetStrategy("Percentage-based")

        $this.logger.Debug("ProfileFactory initialized", @{
            AvailableStrategies = $this.strategies.Count
        })
    }

    # Register a strategy
    [void] RegisterStrategy([IProfileGenerationStrategy]$strategy) {
        $name = $strategy.GetName()
        $this.strategies[$name] = $strategy

        $this.logger.Debug("Strategy registered", @{ Name = $name })
    }

    # Set active strategy
    [void] SetStrategy([string]$strategyName) {
        if (-not $this.strategies.ContainsKey($strategyName)) {
            throw "Strategy not found: $strategyName"
        }

        $this.currentStrategy = $this.strategies[$strategyName]

        $this.logger.Info("Strategy changed", @{ Strategy = $strategyName })
    }

    # Generate profiles using current strategy
    [Profile[]] GenerateProfiles([SystemResources]$resources) {
        $this.logger.Info("Generating profiles", @{
            Strategy = $this.currentStrategy.GetName()
            SystemRAM = $resources.TotalRAM_GB
            SystemCPUs = $resources.TotalCPUs
        })

        try {
            $profiles = $this.currentStrategy.Generate($resources)

            # Validate all profiles
            foreach ($profile in $profiles) {
                if (-not $profile.IsValidFor($resources)) {
                    $this.logger.Warn("Generated invalid profile", @{
                        ProfileName = $profile.Name
                        RAM = $profile.WSL_RAM_GB
                        CPUs = $profile.WSL_CPUs
                    })
                }
            }

            $this.logger.Info("Profiles generated", @{
                Count = $profiles.Count
                Strategy = $this.currentStrategy.GetName()
            })

            return $profiles

        } catch {
            $this.logger.Error("Failed to generate profiles", @{
                Strategy = $this.currentStrategy.GetName()
                Error = $_.Exception.Message
            })
            throw
        }
    }

    # Generate profiles using specific strategy
    [Profile[]] GenerateProfilesWithStrategy([SystemResources]$resources, [string]$strategyName) {
        $previousStrategy = $this.currentStrategy.GetName()

        try {
            $this.SetStrategy($strategyName)
            $profiles = $this.GenerateProfiles($resources)

            # Restore previous strategy
            $this.SetStrategy($previousStrategy)

            return $profiles

        } catch {
            # Restore previous strategy on error
            $this.SetStrategy($previousStrategy)
            throw
        }
    }

    # Get available strategies
    [string[]] GetAvailableStrategies() {
        return $this.strategies.Keys
    }

    # Get current strategy name
    [string] GetCurrentStrategy() {
        return $this.currentStrategy.GetName()
    }

    # Create custom profile
    [Profile] CreateCustomProfile(
        [string]$name,
        [int]$ramGB,
        [int]$cpus,
        [string]$description,
        [SystemResources]$resources
    ) {
        $this.logger.Info("Creating custom profile", @{
            Name = $name
            RAM_GB = $ramGB
            CPUs = $cpus
        })

        $profile = [Profile]::new(
            $name,
            $ramGB,
            $cpus,
            $description,
            [ProfileCategory]::Custom
        )

        $profile.IsCustom = $true

        # Validate
        if (-not $profile.IsValidFor($resources)) {
            throw "Invalid profile: Exceeds system resources or leaves insufficient resources for Windows"
        }

        $this.logger.Info("Custom profile created successfully", @{
            Name = $name
        })

        return $profile
    }

    # Compare strategies for given resources
    [hashtable] CompareStrategies([SystemResources]$resources) {
        $comparison = @{}

        foreach ($strategyName in $this.strategies.Keys) {
            try {
                $profiles = $this.GenerateProfilesWithStrategy($resources, $strategyName)

                $comparison[$strategyName] = @{
                    ProfileCount = $profiles.Count
                    Profiles = $profiles | ForEach-Object {
                        @{
                            Name = $_.Name
                            RAM_GB = $_.WSL_RAM_GB
                            CPUs = $_.WSL_CPUs
                            Category = $_.Category.ToString()
                        }
                    }
                }
            } catch {
                $comparison[$strategyName] = @{
                    Error = $_.Exception.Message
                }
            }
        }

        return $comparison
    }
}
