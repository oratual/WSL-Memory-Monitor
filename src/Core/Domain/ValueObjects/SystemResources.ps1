# Value Object: SystemResources
# Represents system hardware resources (immutable)

class SystemResources {
    [int]$TotalRAM_GB
    [int]$TotalCPUs
    [string]$CPUName
    [string]$OSVersion
    [string]$WSLVersion
    [string[]]$Distributions

    # Constructor
    SystemResources(
        [int]$totalRAM,
        [int]$totalCPUs,
        [string]$cpuName
    ) {
        $this.TotalRAM_GB = $totalRAM
        $this.TotalCPUs = $totalCPUs
        $this.CPUName = $cpuName
        $this.OSVersion = [System.Environment]::OSVersion.VersionString
        $this.WSLVersion = $this.DetectWSLVersion()
        $this.Distributions = $this.DetectDistributions()
    }

    # Detect WSL version
    hidden [string] DetectWSLVersion() {
        try {
            $version = wsl --version 2>&1 | Select-Object -First 1
            if ($version -match '(\d+\.\d+\.\d+)') {
                return $matches[1]
            }
        } catch {
            # Ignore errors
        }
        return "Unknown"
    }

    # Detect installed distributions
    hidden [string[]] DetectDistributions() {
        try {
            $distros = wsl --list --quiet 2>&1 | Where-Object { $_ -match '\S' }
            return $distros
        } catch {
            return @()
        }
    }

    # Calculate safe maximum allocation
    [hashtable] GetSafeMaximums() {
        return @{
            RAM_GB = [Math]::Max(4, $this.TotalRAM_GB - 4)  # Leave 4GB for Windows
            CPUs = [Math]::Max(1, $this.TotalCPUs - 1)      # Leave 1 CPU for Windows
        }
    }

    # Check if profile is safe
    [bool] IsProfileSafe([Profile]$profile) {
        $safe = $this.GetSafeMaximums()
        return ($profile.WSL_RAM_GB -le $safe.RAM_GB -and
                $profile.WSL_CPUs -le $safe.CPUs)
    }

    # Get resource tier (for dynamic profile calculation)
    [ResourceTier] GetTier() {
        if ($this.TotalRAM_GB -lt 16) {
            return [ResourceTier]::Low
        } elseif ($this.TotalRAM_GB -lt 32) {
            return [ResourceTier]::Medium
        } elseif ($this.TotalRAM_GB -lt 64) {
            return [ResourceTier]::High
        } else {
            return [ResourceTier]::VeryHigh
        }
    }

    # Static factory method to detect current system
    static [SystemResources] DetectCurrent() {
        try {
            $totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
            $totalCPUs = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
            $cpuName = (Get-CimInstance Win32_Processor).Name -replace '\s+', ' '

            return [SystemResources]::new($totalRAM, $totalCPUs, $cpuName)
        } catch {
            # Fallback to defaults
            return [SystemResources]::new(16, 8, "Unknown CPU")
        }
    }

    # Serialize to hashtable
    [hashtable] ToHashtable() {
        return @{
            TotalRAM_GB = $this.TotalRAM_GB
            TotalCPUs = $this.TotalCPUs
            CPUName = $this.CPUName
            OSVersion = $this.OSVersion
            WSLVersion = $this.WSLVersion
            Distributions = $this.Distributions
            Tier = $this.GetTier().ToString()
        }
    }

    # Value object equality
    [bool] Equals([SystemResources]$other) {
        return ($this.TotalRAM_GB -eq $other.TotalRAM_GB -and
                $this.TotalCPUs -eq $other.TotalCPUs)
    }

    # String representation
    [string] ToString() {
        return "SystemResources(RAM: $($this.TotalRAM_GB)GB, CPUs: $($this.TotalCPUs), CPU: $($this.CPUName))"
    }
}

enum ResourceTier {
    Low        # < 16GB
    Medium     # 16-31GB
    High       # 32-63GB
    VeryHigh   # 64GB+
}
