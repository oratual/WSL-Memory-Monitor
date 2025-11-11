# Domain Entity: Profile
# Represents a memory/CPU configuration profile for WSL

class Profile {
    [string]$Id
    [string]$Name
    [int]$WSL_RAM_GB
    [int]$WSL_CPUs
    [string]$Description
    [ProfileCategory]$Category
    [DateTime]$CreatedAt
    [DateTime]$LastUsed
    [bool]$IsCustom

    # Constructor
    Profile(
        [string]$name,
        [int]$wslRAM,
        [int]$wslCPUs,
        [string]$description,
        [ProfileCategory]$category
    ) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Name = $name
        $this.WSL_RAM_GB = $wslRAM
        $this.WSL_CPUs = $wslCPUs
        $this.Description = $description
        $this.Category = $category
        $this.CreatedAt = Get-Date
        $this.LastUsed = Get-Date
        $this.IsCustom = $false
    }

    # Convert to Configuration
    [Configuration] ToConfiguration() {
        return [Configuration]::new(
            "${_}($this.WSL_RAM_GB)GB",
            $this.WSL_CPUs,
            0,  # swap
            $false,  # guiApplications
            [NetworkMode]::Mirrored,
            $true,  # dnsTunneling
            $true,  # firewall
            [ExperimentalConfig]::new($true, $true)
        )
    }

    # Calculate Windows allocation
    [hashtable] GetWindowsAllocation([int]$totalRAM, [int]$totalCPUs) {
        return @{
            RAM_GB = $totalRAM - $this.WSL_RAM_GB
            CPUs = $totalCPUs - $this.WSL_CPUs
        }
    }

    # Validate against system resources
    [bool] IsValidFor([SystemResources]$resources) {
        $minWindowsRAM = 4
        $minWindowsCPUs = 1

        $windowsRAM = $resources.TotalRAM_GB - $this.WSL_RAM_GB
        $windowsCPUs = $resources.TotalCPUs - $this.WSL_CPUs

        return ($windowsRAM -ge $minWindowsRAM -and
                $windowsCPUs -ge $minWindowsCPUs -and
                $this.WSL_RAM_GB -le $resources.TotalRAM_GB -and
                $this.WSL_CPUs -le $resources.TotalCPUs)
    }

    # Mark as used
    [void] MarkAsUsed() {
        $this.LastUsed = Get-Date
    }

    # Clone profile
    [Profile] Clone([string]$newName) {
        $cloned = [Profile]::new(
            $newName,
            $this.WSL_RAM_GB,
            $this.WSL_CPUs,
            $this.Description,
            $this.Category
        )
        $cloned.IsCustom = $true
        return $cloned
    }

    # Serialize to hashtable
    [hashtable] ToHashtable() {
        return @{
            Id = $this.Id
            Name = $this.Name
            WSL_RAM_GB = $this.WSL_RAM_GB
            WSL_CPUs = $this.WSL_CPUs
            Description = $this.Description
            Category = $this.Category.ToString()
            CreatedAt = $this.CreatedAt.ToString("o")
            LastUsed = $this.LastUsed.ToString("o")
            IsCustom = $this.IsCustom
        }
    }

    # Deserialize from hashtable
    static [Profile] FromHashtable([hashtable]$data) {
        $profile = [Profile]::new(
            $data.Name,
            $data.WSL_RAM_GB,
            $data.WSL_CPUs,
            $data.Description,
            [ProfileCategory]$data.Category
        )
        $profile.Id = $data.Id
        $profile.CreatedAt = [DateTime]::Parse($data.CreatedAt)
        $profile.LastUsed = [DateTime]::Parse($data.LastUsed)
        $profile.IsCustom = $data.IsCustom
        return $profile
    }
}

# Enum for profile categories
enum ProfileCategory {
    Gaming
    WindowsFocus
    Balanced
    WSLDev
    WSLFocus
    Custom
}
