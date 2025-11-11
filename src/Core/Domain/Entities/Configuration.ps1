# Domain Entity: Configuration
# Represents WSL configuration (.wslconfig format)

class Configuration {
    [string]$Memory
    [int]$Processors
    [int]$Swap
    [bool]$GuiApplications
    [NetworkMode]$NetworkingMode
    [bool]$DnsTunneling
    [bool]$Firewall
    [ExperimentalConfig]$Experimental
    [DateTime]$LastModified
    [string]$AppliedProfile

    # Constructor
    Configuration(
        [string]$memory,
        [int]$processors,
        [int]$swap,
        [bool]$guiApps,
        [NetworkMode]$netMode,
        [bool]$dnsTunnel,
        [bool]$firewall,
        [ExperimentalConfig]$experimental
    ) {
        $this.Memory = $memory
        $this.Processors = $processors
        $this.Swap = $swap
        $this.GuiApplications = $guiApps
        $this.NetworkingMode = $netMode
        $this.DnsTunneling = $dnsTunnel
        $this.Firewall = $firewall
        $this.Experimental = $experimental
        $this.LastModified = Get-Date
        $this.AppliedProfile = "UNKNOWN"
    }

    # Serialize to .wslconfig format
    [string] Serialize() {
        $content = @"
[wsl2]
# Profile: $($this.AppliedProfile) - $(Get-Date -Format "yyyy-MM-dd HH:mm")
memory=$($this.Memory)
processors=$($this.Processors)
swap=$($this.Swap)GB
guiApplications=$($this.GuiApplications.ToString().ToLower())
networkingMode=$($this.NetworkingMode.ToString().ToLower())
dnsTunneling=$($this.DnsTunneling.ToString().ToLower())
firewall=$($this.Firewall.ToString().ToLower())

[experimental]
autoMemoryReclaim=$($this.Experimental.AutoMemoryReclaim)
sparseVhd=$($this.Experimental.SparseVhd.ToString().ToLower())
"@
        return $content
    }

    # Deserialize from .wslconfig content
    static [Configuration] Deserialize([string]$content) {
        $memory = if ($content -match 'memory=(\d+GB)') { $matches[1] } else { "16GB" }
        $processors = if ($content -match 'processors=(\d+)') { [int]$matches[1] } else { 8 }
        $swap = if ($content -match 'swap=(\d+)') { [int]$matches[1] } else { 0 }
        $guiApps = if ($content -match 'guiApplications=(true|false)') { [bool]::Parse($matches[1]) } else { $false }
        $netMode = if ($content -match 'networkingMode=(\w+)') {
            [NetworkMode]$matches[1]
        } else {
            [NetworkMode]::Mirrored
        }
        $dnsTunnel = if ($content -match 'dnsTunneling=(true|false)') { [bool]::Parse($matches[1]) } else { $true }
        $firewall = if ($content -match 'firewall=(true|false)') { [bool]::Parse($matches[1]) } else { $true }

        $autoReclaim = if ($content -match 'autoMemoryReclaim=(\w+)') { $matches[1] } else { "gradual" }
        $sparseVhd = if ($content -match 'sparseVhd=(true|false)') { [bool]::Parse($matches[1]) } else { $true }

        $experimental = [ExperimentalConfig]::new($autoReclaim, $sparseVhd)

        $config = [Configuration]::new(
            $memory, $processors, $swap, $guiApps,
            $netMode, $dnsTunnel, $firewall, $experimental
        )

        if ($content -match '# Profile: (\w+)') {
            $config.AppliedProfile = $matches[1]
        }

        return $config
    }

    # Get memory in GB as integer
    [int] GetMemoryGB() {
        if ($this.Memory -match '(\d+)GB') {
            return [int]$matches[1]
        }
        return 16
    }

    # Compare with another configuration
    [bool] Equals([Configuration]$other) {
        return ($this.Memory -eq $other.Memory -and
                $this.Processors -eq $other.Processors -and
                $this.Swap -eq $other.Swap)
    }

    # Create a copy
    [Configuration] Clone() {
        return [Configuration]::new(
            $this.Memory,
            $this.Processors,
            $this.Swap,
            $this.GuiApplications,
            $this.NetworkingMode,
            $this.DnsTunneling,
            $this.Firewall,
            $this.Experimental.Clone()
        )
    }
}

# Enum for network modes
enum NetworkMode {
    NAT
    Bridged
    Mirrored
}

# Experimental configuration
class ExperimentalConfig {
    [string]$AutoMemoryReclaim
    [bool]$SparseVhd

    ExperimentalConfig([string]$autoReclaim, [bool]$sparseVhd) {
        $this.AutoMemoryReclaim = $autoReclaim
        $this.SparseVhd = $sparseVhd
    }

    [ExperimentalConfig] Clone() {
        return [ExperimentalConfig]::new($this.AutoMemoryReclaim, $this.SparseVhd)
    }
}
