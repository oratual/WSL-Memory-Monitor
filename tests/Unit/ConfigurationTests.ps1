# Unit Tests for Configuration Domain Entity

. "$PSScriptRoot/../../src/Core/Domain/Entities/Configuration.ps1"

function Test-ConfigurationCreation {
    Write-Host "`nTest: Configuration Creation" -ForegroundColor Yellow

    $config = [Configuration]::new(
        "16GB",
        8,
        0,
        $false,
        [NetworkMode]::Mirrored,
        $true,
        $true,
        [ExperimentalConfig]::new("gradual", $true)
    )

    Assert ($config.Memory -eq "16GB") "Memory should be 16GB"
    Assert ($config.Processors -eq 8) "Processors should be 8"
    Assert ($config.NetworkingMode -eq [NetworkMode]::Mirrored) "Network mode should be Mirrored"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ConfigurationSerialization {
    Write-Host "`nTest: Configuration Serialization" -ForegroundColor Yellow

    $config = [Configuration]::new(
        "16GB",
        8,
        0,
        $false,
        [NetworkMode]::Mirrored,
        $true,
        $true,
        [ExperimentalConfig]::new("gradual", $true)
    )

    $config.AppliedProfile = "TEST"
    $serialized = $config.Serialize()

    Assert ($serialized.Contains("[wsl2]")) "Serialization should contain [wsl2] section"
    Assert ($serialized.Contains("memory=16GB")) "Serialization should contain memory setting"
    Assert ($serialized.Contains("processors=8")) "Serialization should contain processors setting"
    Assert ($serialized.Contains("# Profile: TEST")) "Serialization should contain profile comment"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ConfigurationDeserialization {
    Write-Host "`nTest: Configuration Deserialization" -ForegroundColor Yellow

    $content = @"
[wsl2]
# Profile: BALANCED - 2025-01-15 14:30
memory=16GB
processors=8
swap=0GB
guiApplications=false
networkingMode=mirrored
dnsTunneling=true
firewall=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
"@

    $config = [Configuration]::Deserialize($content)

    Assert ($config.Memory -eq "16GB") "Deserialized memory should be 16GB"
    Assert ($config.Processors -eq 8) "Deserialized processors should be 8"
    Assert ($config.AppliedProfile -eq "BALANCED") "Deserialized profile should be BALANCED"
    Assert ($config.NetworkingMode -eq [NetworkMode]::Mirrored) "Network mode should be Mirrored"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ConfigurationGetMemoryGB {
    Write-Host "`nTest: Configuration GetMemoryGB" -ForegroundColor Yellow

    $config = [Configuration]::new(
        "24GB",
        8,
        0,
        $false,
        [NetworkMode]::Mirrored,
        $true,
        $true,
        [ExperimentalConfig]::new("gradual", $true)
    )

    $memoryGB = $config.GetMemoryGB()

    Assert ($memoryGB -eq 24) "GetMemoryGB should return 24"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ConfigurationEquals {
    Write-Host "`nTest: Configuration Equals" -ForegroundColor Yellow

    $config1 = [Configuration]::new(
        "16GB", 8, 0, $false,
        [NetworkMode]::Mirrored, $true, $true,
        [ExperimentalConfig]::new("gradual", $true)
    )

    $config2 = [Configuration]::new(
        "16GB", 8, 0, $false,
        [NetworkMode]::Mirrored, $true, $true,
        [ExperimentalConfig]::new("gradual", $true)
    )

    $config3 = [Configuration]::new(
        "24GB", 12, 0, $false,
        [NetworkMode]::Mirrored, $true, $true,
        [ExperimentalConfig]::new("gradual", $true)
    )

    Assert ($config1.Equals($config2)) "Identical configurations should be equal"
    Assert (-not $config1.Equals($config3)) "Different configurations should not be equal"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ConfigurationClone {
    Write-Host "`nTest: Configuration Clone" -ForegroundColor Yellow

    $original = [Configuration]::new(
        "16GB", 8, 0, $false,
        [NetworkMode]::Mirrored, $true, $true,
        [ExperimentalConfig]::new("gradual", $true)
    )

    $clone = $original.Clone()

    Assert ($clone.Memory -eq $original.Memory) "Clone memory should match original"
    Assert ($clone.Processors -eq $original.Processors) "Clone processors should match original"
    Assert ($clone.NetworkingMode -eq $original.NetworkingMode) "Clone network mode should match original"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Assert {
    param(
        [bool]$condition,
        [string]$message
    )

    if (-not $condition) {
        throw "Assertion failed: $message"
    }
}

# Run all tests
Write-Host "`n=== Configuration Unit Tests ===" -ForegroundColor Cyan

try {
    Test-ConfigurationCreation
    Test-ConfigurationSerialization
    Test-ConfigurationDeserialization
    Test-ConfigurationGetMemoryGB
    Test-ConfigurationEquals
    Test-ConfigurationClone

    Write-Host "`n=== All Tests Passed! ===" -ForegroundColor Green

} catch {
    Write-Host "`n✗ TEST FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
