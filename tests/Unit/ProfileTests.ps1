# Unit Tests for Profile Domain Entity

. "$PSScriptRoot/../../src/Core/Domain/ValueObjects/SystemResources.ps1"
. "$PSScriptRoot/../../src/Core/Domain/Entities/Configuration.ps1"
. "$PSScriptRoot/../../src/Core/Domain/Entities/Profile.ps1"

function Test-ProfileCreation {
    Write-Host "`nTest: Profile Creation" -ForegroundColor Yellow

    $profile = [Profile]::new(
        "TEST",
        16,
        8,
        "Test profile",
        [ProfileCategory]::Custom
    )

    Assert ($profile.Name -eq "TEST") "Profile name should be TEST"
    Assert ($profile.WSL_RAM_GB -eq 16) "Profile RAM should be 16GB"
    Assert ($profile.WSL_CPUs -eq 8) "Profile CPUs should be 8"
    Assert ($profile.Category -eq [ProfileCategory]::Custom) "Profile category should be Custom"
    Assert (-not $profile.IsCustom) "Profile IsCustom should be false initially"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ProfileValidation {
    Write-Host "`nTest: Profile Validation" -ForegroundColor Yellow

    $resources = [SystemResources]::new(32, 16, "Test CPU")
    $validProfile = [Profile]::new("VALID", 20, 12, "Valid", [ProfileCategory]::Balanced)
    $invalidProfile = [Profile]::new("INVALID", 30, 15, "Invalid", [ProfileCategory]::WSLFocus)

    Assert ($validProfile.IsValidFor($resources)) "Valid profile should pass validation"
    Assert (-not $invalidProfile.IsValidFor($resources)) "Invalid profile should fail validation"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ProfileToConfiguration {
    Write-Host "`nTest: Profile to Configuration Conversion" -ForegroundColor Yellow

    $profile = [Profile]::new("TEST", 16, 8, "Test", [ProfileCategory]::WSLDev)
    $config = $profile.ToConfiguration()

    Assert ($config.GetMemoryGB() -eq 16) "Configuration memory should match profile"
    Assert ($config.Processors -eq 8) "Configuration processors should match profile"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ProfileClone {
    Write-Host "`nTest: Profile Clone" -ForegroundColor Yellow

    $original = [Profile]::new("ORIGINAL", 16, 8, "Original", [ProfileCategory]::Balanced)
    $clone = $original.Clone("CLONE")

    Assert ($clone.Name -eq "CLONE") "Clone should have new name"
    Assert ($clone.WSL_RAM_GB -eq $original.WSL_RAM_GB) "Clone should have same RAM"
    Assert ($clone.WSL_CPUs -eq $original.WSL_CPUs) "Clone should have same CPUs"
    Assert ($clone.IsCustom) "Clone should be marked as custom"
    Assert ($clone.Id -ne $original.Id) "Clone should have different ID"

    Write-Host "  ✓ PASS" -ForegroundColor Green
}

function Test-ProfileSerialization {
    Write-Host "`nTest: Profile Serialization" -ForegroundColor Yellow

    $profile = [Profile]::new("TEST", 16, 8, "Test", [ProfileCategory]::Gaming)
    $hashtable = $profile.ToHashtable()

    Assert ($hashtable.Name -eq "TEST") "Serialized name should match"
    Assert ($hashtable.WSL_RAM_GB -eq 16) "Serialized RAM should match"
    Assert ($hashtable.WSL_CPUs -eq 8) "Serialized CPUs should match"

    $deserialized = [Profile]::FromHashtable($hashtable)

    Assert ($deserialized.Name -eq $profile.Name) "Deserialized name should match original"
    Assert ($deserialized.WSL_RAM_GB -eq $profile.WSL_RAM_GB) "Deserialized RAM should match original"
    Assert ($deserialized.WSL_CPUs -eq $profile.WSL_CPUs) "Deserialized CPUs should match original"

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
Write-Host "`n=== Profile Unit Tests ===" -ForegroundColor Cyan

try {
    Test-ProfileCreation
    Test-ProfileValidation
    Test-ProfileToConfiguration
    Test-ProfileClone
    Test-ProfileSerialization

    Write-Host "`n=== All Tests Passed! ===" -ForegroundColor Green

} catch {
    Write-Host "`n✗ TEST FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
