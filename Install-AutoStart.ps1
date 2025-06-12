# Instalador para inicio automático con Windows

$StartupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ShortcutPath = "$StartupPath\WSL Memory Monitor.lnk"
$TargetPath = "$PSScriptRoot\START-MONITOR.bat"

Write-Host "Instalando WSL Memory Monitor en inicio de Windows..." -ForegroundColor Yellow

# Crear acceso directo
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $TargetPath
$Shortcut.WorkingDirectory = $PSScriptRoot
$Shortcut.IconLocation = "imageres.dll,11"
$Shortcut.Description = "Monitor de memoria WSL"
$Shortcut.Save()

Write-Host "Instalacion completada!" -ForegroundColor Green
Write-Host ""
Write-Host "El monitor se iniciara automaticamente con Windows." -ForegroundColor Cyan
Write-Host "Tambien puedes iniciarlo ahora ejecutando START-MONITOR.bat" -ForegroundColor Cyan
Write-Host ""

$start = Read-Host "Quieres iniciar el monitor ahora? (S/N)"
if ($start -eq 'S' -or $start -eq 's') {
    & "$PSScriptRoot\START-MONITOR.bat"
    Write-Host "Monitor iniciado!" -ForegroundColor Green
}

Write-Host ""
Read-Host "Presiona Enter para salir"