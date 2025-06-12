# WSL Memory Monitor

A comprehensive visual memory management tool for WSL2 on Windows. Control and monitor memory allocation between Windows and WSL with an intuitive slider interface and persistent system tray indicator.

![WSL Memory Monitor](https://img.shields.io/badge/WSL-Memory%20Monitor-blue)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Windows 10/11](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows)
![PowerShell](https://img.shields.io/badge/PowerShell-5.0+-5391FE?logo=powershell)
![WSL2](https://img.shields.io/badge/WSL-2.0+-FCC624?logo=linux)

## 📋 Table of Contents

- [Features](#-features)
- [Screenshots](#-screenshots)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
  - [GUI Mode](#gui-mode-windows)
  - [System Tray Monitor](#system-tray-monitor)
  - [CLI Mode](#cli-mode-wslterminal)
- [Configuration](#-configuration)
- [Architecture](#-architecture)
- [Troubleshooting](#-troubleshooting)
- [Advanced Usage](#-advanced-usage)
- [Contributing](#-contributing)
- [License](#-license)

## 🎯 Features

### Core Features
- **🎚️ Visual Memory Slider**: Intuitive horizontal slider interface to balance memory between Windows and WSL
- **📊 System Tray Monitor**: Persistent color-coded icon (1-5) showing current memory profile at a glance
- **⚡ Real-time Updates**: Monitor updates every 30 seconds to reflect configuration changes
- **🖱️ One-click Access**: Left-click tray icon to instantly open Memory Switch
- **🔄 Hot Restart**: Integrated WSL restart functionality without closing applications

### Memory Profiles
The tool includes 5 carefully calibrated profiles for different use cases:

| Level | Profile | WSL Memory | Windows Free | WSL CPUs | Use Case |
|-------|---------|------------|--------------|----------|----------|
| 🔵 5 | GAMING | 8GB | 56GB | 4 | AAA Gaming, Streaming, Video Editing |
| 🔷 4 | WIN-FOCUS | 16GB | 48GB | 8 | Windows-heavy tasks, VMs, Design |
| ⚪ 3 | BALANCED | 24GB | 40GB | 12 | Mixed usage, light dev + Windows apps |
| 🟢 2 | WSL-DEV | 32GB | 32GB | 16 | Development, Docker, Build tasks |
| 🟢 1 | WSL-FOCUS | 48GB | 16GB | 20 | Heavy compilation, Multiple containers |

### Visual Indicators
- **Color Gradient System**: Icons transition from blue (Windows-focused) through gray (balanced) to green (WSL-focused)
- **3D Effect**: Icons feature gradient shading and shadows for better visibility
- **Tooltip Information**: Hover for instant memory allocation details

### CLI Features
- Full command-line control from both Windows and WSL
- Scriptable interface for automation
- Profile management and custom configurations
- Status reporting and system health checks

## 📸 Screenshots

### Memory Switch Interface
```
                    WSL MEMORY SWITCH v2.0
                 Ryzen 9 5900X + 64GB RAM System

     WINDOWS                                                     WSL/LINUX
      16 GB                                                       48 GB
       4 CPUs                                                     20 CPUs

     ===============================================||===============================

     0GB                              32GB                             64GB

                         [WSL-FOCUS] Heavy Dev
                      
                      CONFIGURATION CURRENT

 ============================================================================

 [←] [→]  Move slider     [ENTER] Apply     [R] Restart WSL     [Q] Quit

 Status WSL: ACTIVE (requires restart to apply changes)
```

### System Tray Icon Examples
- Level 5 (Gaming): 🔵 Blue circle with white "5"
- Level 3 (Balanced): ⚪ Gray circle with white "3"  
- Level 1 (WSL Focus): 🟢 Green circle with white "1"

## 📋 Requirements

### System Requirements
- **OS**: Windows 10 version 2004+ or Windows 11
- **WSL**: WSL2 (version 2.0.0 or higher recommended)
- **RAM**: Minimum 16GB, designed for 32GB+ systems
- **PowerShell**: Version 5.0 or higher
- **.NET Framework**: 4.5+ (usually pre-installed)

### Permissions
- Standard user for basic operations
- Administrator for:
  - WSL service restart
  - Auto-start installation
  - First-time icon visibility setup

## 🚀 Installation

### Method 1: Quick Install (Recommended)
1. Download the latest release from [Releases](https://github.com/yourusername/WSL-Memory-Monitor/releases)
2. Extract to your preferred location (e.g., `C:\Tools\WSL-Memory-Monitor`)
3. Right-click `Install-AutoStart.ps1` → Run with PowerShell
4. Follow the prompts to configure auto-start

### Method 2: Git Clone
```bash
# From Windows PowerShell or WSL
git clone https://github.com/yourusername/WSL-Memory-Monitor.git
cd WSL-Memory-Monitor

# Windows: Install auto-start
powershell -ExecutionPolicy Bypass -File Install-AutoStart.ps1

# WSL: Install CLI tool
chmod +x wsl-memory-switch-cli.sh
ln -s $(pwd)/wsl-memory-switch-cli.sh ~/.local/bin/wsl-memory-switch
```

### Method 3: Manual Installation
1. Download ZIP from GitHub
2. Extract to desired location
3. Create shortcut to `START-MONITOR.bat` in:
   ```
   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
   ```

### Post-Installation Setup
1. Run `Make-Icon-Visible.ps1` to pin the tray icon
2. Or manually drag the icon from hidden tray area to visible area
3. Configure your preferred default profile

## 🎮 Usage

### GUI Mode (Windows)

#### Launching the Memory Switch
- **Method 1**: Double-click `RUN-MEMORY-SWITCH.bat`
- **Method 2**: Left-click the system tray icon
- **Method 3**: PowerShell: `.\WSL-Memory-Switch.ps1`

#### Keyboard Controls
- **← / →**: Navigate between memory profiles
- **Enter**: Apply selected profile
- **R**: Restart WSL (applies pending changes)
- **Q**: Quit application

#### Visual Feedback
- Blue bar represents Windows memory
- Green bar represents WSL memory
- Current profile highlighted in cyan
- "CHANGE PENDING" indicator when selection differs from current

### System Tray Monitor

#### Starting the Monitor
```batch
# Run once
START-MONITOR.bat

# Or install for auto-start
powershell -ExecutionPolicy Bypass -File Install-AutoStart.ps1
```

#### Tray Icon Interactions
- **Left-click**: Open Memory Switch
- **Right-click**: Context menu
  - View current status
  - Select profiles directly
  - Refresh status
  - Exit monitor

#### Icon States
The icon displays a number (1-5) with color coding:
- Higher numbers = More memory for Windows
- Lower numbers = More memory for WSL
- Color transitions from blue to green

### CLI Mode (WSL/Terminal)

#### Basic Commands
```bash
# Check current configuration
wsl-memory-switch current

# List available profiles
wsl-memory-switch list

# Show detailed status
wsl-memory-switch status
```

#### Applying Profiles
```bash
# Apply preset profiles
wsl-memory-switch apply gaming      # 8GB for WSL
wsl-memory-switch apply balanced    # 24GB for WSL
wsl-memory-switch apply wsl-focus   # 48GB for WSL

# Custom configuration
wsl-memory-switch custom 32 16      # 32GB RAM, 16 CPUs
```

#### System Management
```bash
# Restart WSL to apply changes
wsl-memory-switch restart

# Show help
wsl-memory-switch help
```

## ⚙️ Configuration

### WSL Configuration File
The tool manages `~/.wslconfig` (Windows user directory) with optimized settings:

```ini
[wsl2]
# Memory allocation (adjusted per profile)
memory=48GB              

# CPU allocation (adjusted per profile)
processors=20            

# Swap disabled for better performance
swap=0                   

# GUI disabled for stability (prevents Xorg crashes)
guiApplications=false    

# Network configuration
networkingMode=mirrored  # Better Windows integration
dnsTunneling=true       # Improved DNS resolution
firewall=true           # Security

[experimental]
# Memory optimizations
autoMemoryReclaim=gradual  # Gradual memory reclaim
sparseVhd=true            # Disk space optimization
```

### Profile Configuration
Edit `wsl-memory-profiles.conf` to customize profiles:

```bash
# Format: PROFILE_NAME|MEMORY|PROCESSORS|DESCRIPTION
GAMING|8GB|4|Windows Gaming - Minimal WSL
BALANCED|24GB|12|Balanced - Both systems
WSL_FOCUS|48GB|20|WSL Priority - Heavy development
CUSTOM|32GB|16|Custom configuration
```

### Monitor Settings
- **Update Interval**: 30 seconds (hardcoded)
- **Icon Size**: 32x32 pixels with anti-aliasing
- **Tooltip Format**: "L[Level]: W[Windows]GB|WSL[WSL]GB"

## 🏗️ Architecture

### Component Overview
```
WSL-Memory-Monitor/
├── Core Components
│   ├── WSL-Memory-Switch.ps1      # Main GUI application
│   ├── WSL-Memory-Monitor.ps1     # System tray monitor
│   └── wsl-memory-switch-cli.sh   # Linux CLI interface
├── Launchers
│   ├── RUN-MEMORY-SWITCH.bat      # GUI launcher
│   └── START-MONITOR.bat          # Monitor launcher
├── Utilities
│   ├── Install-AutoStart.ps1      # Startup installer
│   └── Make-Icon-Visible.ps1      # Tray icon helper
└── Configuration
    └── wsl-memory-profiles.conf   # Profile definitions
```

### Technical Details

#### Memory Switch GUI
- **Technology**: PowerShell + Windows Forms
- **Rendering**: GDI+ for custom graphics
- **Input**: Raw keyboard input handling
- **State Management**: File-based configuration

#### System Tray Monitor
- **Framework**: .NET Windows Forms NotifyIcon
- **Icon Generation**: Dynamic GDI+ bitmap rendering
- **Update Mechanism**: Timer-based polling
- **Memory Management**: Proper disposal of graphics resources

#### CLI Tool
- **Language**: Bash script
- **Compatibility**: POSIX-compliant
- **Integration**: Direct .wslconfig manipulation
- **Windows Interop**: PowerShell command execution

### Data Flow
1. User interacts with GUI/CLI/Tray
2. Tool modifies `~/.wslconfig`
3. User triggers WSL restart
4. Windows applies new configuration
5. Monitor reflects changes

## 🔧 Troubleshooting

### Common Issues

#### Monitor Not Visible in System Tray
**Problem**: Icon appears in hidden area instead of visible tray

**Solutions**:
1. Run `Make-Icon-Visible.ps1` as Administrator
2. Manually drag icon from overflow area (^ arrow)
3. Windows 11: Settings → Personalization → Taskbar → System tray icons
4. Windows 10: Settings → Personalization → Taskbar → Select icons

#### WSL Not Restarting Properly
**Problem**: WSL doesn't restart or changes don't apply

**Solutions**:
```powershell
# Run as Administrator
wsl --shutdown
Stop-Service LxssManager -Force
Start-Service LxssManager
wsl
```

#### Icon Shows Wrong Number/Color
**Problem**: Tray icon doesn't match actual configuration

**Solutions**:
1. Right-click tray icon → "Refresh"
2. Verify `~/.wslconfig` contents
3. Restart monitor: Close and run `START-MONITOR.bat`

#### PowerShell Execution Policy Error
**Problem**: "Scripts disabled on this system"

**Solution**:
```powershell
# Run as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Memory Settings Not Applying
**Problem**: WSL ignores memory settings

**Possible Causes**:
1. WSL version too old (update with `wsl --update`)
2. Windows version doesn't support setting
3. Syntax error in .wslconfig
4. Insufficient system memory

### Diagnostic Commands

```powershell
# Check WSL version
wsl --version

# Verify configuration
Get-Content $env:USERPROFILE\.wslconfig

# Check WSL status
wsl --list --verbose

# View system memory
Get-WmiObject Win32_OperatingSystem | Select TotalVisibleMemorySize
```

## 🚀 Advanced Usage

### Automation Scripts

#### Auto-switch based on time
```powershell
# Morning: Development focus
$hour = (Get-Date).Hour
if ($hour -ge 9 -and $hour -lt 17) {
    & ".\WSL-Memory-Switch.ps1" -Profile "WSL_FOCUS"
} else {
    & ".\WSL-Memory-Switch.ps1" -Profile "BALANCED"
}
```

#### Integration with Task Scheduler
1. Create new task in Task Scheduler
2. Trigger: At startup or specific time
3. Action: Start program
4. Program: `powershell.exe`
5. Arguments: `-ExecutionPolicy Bypass -File "C:\Path\To\Script.ps1"`

### Custom Profiles

#### Creating a Video Editing Profile
```bash
# Edit wsl-memory-profiles.conf
VIDEO_EDIT|12GB|6|Video Editing - Max Windows RAM

# Apply via CLI
wsl-memory-switch apply video_edit
```

#### Dynamic Profile Based on Running Apps
```powershell
# Check if specific apps are running
$gaming = Get-Process "game_executable" -ErrorAction SilentlyContinue
if ($gaming) {
    # Switch to gaming profile
    wsl-memory-switch apply gaming
}
```

### Monitoring and Alerts

#### Memory Usage Alert
```bash
#!/bin/bash
# Add to crontab for periodic checks
used=$(free -g | awk '/^Mem:/{print $3}')
total=$(free -g | awk '/^Mem:/{print $2}')
if [ $used -gt $((total * 90 / 100)) ]; then
    notify-send "WSL Memory Alert" "Using $used/$total GB"
fi
```

### API Usage (Unofficial)

#### Get Current Profile Programmatically
```powershell
function Get-WSLMemoryProfile {
    $config = Get-Content "$env:USERPROFILE\.wslconfig" -Raw
    if ($config -match 'memory=(\d+)GB') {
        return @{
            Memory = [int]$matches[1]
            Profile = switch([int]$matches[1]) {
                8 { "GAMING" }
                16 { "WIN_FOCUS" }
                24 { "BALANCED" }
                32 { "WSL_DEV" }
                48 { "WSL_FOCUS" }
                default { "CUSTOM" }
            }
        }
    }
}
```

## 🛠️ Development

### Building from Source

#### Prerequisites
- Visual Studio Code or PowerShell ISE
- Git for Windows
- WSL2 with Ubuntu/Debian

#### Build Steps
```bash
# Clone repository
git clone https://github.com/yourusername/WSL-Memory-Monitor.git
cd WSL-Memory-Monitor

# No compilation needed - PowerShell scripts
# Test locally
./RUN-MEMORY-SWITCH.bat
```

### Testing

#### Unit Tests (PowerShell)
```powershell
# Test profile switching
$profiles = @("gaming", "balanced", "wsl-focus")
foreach ($profile in $profiles) {
    Write-Host "Testing profile: $profile"
    & ".\WSL-Memory-Switch.ps1" -Profile $profile -NoRestart
    Start-Sleep -Seconds 2
}
```

#### Integration Tests
```bash
# Test CLI commands
./test-cli.sh

# Test cases
- Profile switching
- Custom configurations  
- Restart functionality
- Error handling
```

### Code Structure

#### WSL-Memory-Switch.ps1
```powershell
# Main sections:
1. Configuration loading
2. UI rendering engine
3. Input handling
4. Profile management
5. WSL service control
```

#### WSL-Memory-Monitor.ps1
```powershell
# Components:
1. Icon generation system
2. Tray icon management
3. Context menu builder
4. Update timer
5. Event handlers
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Ways to Contribute
- 🐛 Report bugs and issues
- 💡 Suggest new features
- 📖 Improve documentation
- 🌐 Add translations
- 💻 Submit pull requests

### Development Process
1. Fork the repository
2. Create feature branch: `git checkout -b feature/AmazingFeature`
3. Commit changes: `git commit -m 'Add AmazingFeature'`
4. Push to branch: `git push origin feature/AmazingFeature`
5. Open Pull Request

### Code Style
- PowerShell: Follow [PowerShell Best Practices](https://poshcode.gitbook.io/powershell-practice-and-style/)
- Use meaningful variable names
- Comment complex logic
- Include error handling

## 📜 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

### Key Points:
- ✅ Freedom to use, modify, and distribute
- ✅ Source code must remain open
- ✅ Derivative works must use GPL v3
- ❌ No warranty provided

## 🙏 Acknowledgments

- **Designed for**: High-memory systems (32GB+) where resource allocation matters
- **Inspired by**: The need to balance gaming and development on the same machine
- **Thanks to**: WSL2 team for making Linux on Windows awesome
- **Icon Design**: Using Windows GDI+ for native look and feel

## 📞 Support

### Getting Help
- 📋 Check [Issues](https://github.com/yourusername/WSL-Memory-Monitor/issues) for known problems
- 💬 Join our [Discussions](https://github.com/yourusername/WSL-Memory-Monitor/discussions)
- 📧 Email: your.email@example.com

### Reporting Issues
Please include:
- Windows version (`winver`)
- WSL version (`wsl --version`)
- System RAM and CPU
- Error messages/screenshots
- Steps to reproduce

### Feature Requests
- Check existing requests first
- Describe use case clearly
- Explain expected behavior
- Consider submitting a PR!

---

<div align="center">

Made with ❤️ for the WSL community

[⬆ Back to top](#wsl-memory-monitor)

</div>