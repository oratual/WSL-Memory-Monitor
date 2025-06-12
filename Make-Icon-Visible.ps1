# Script para sugerir a Windows que muestre el icono siempre visible
# Requiere ejecutar como Administrador

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  WSL Memory Monitor" -ForegroundColor Cyan
Write-Host "  Configurar Icono Visible" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si se ejecuta como admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Este script necesita permisos de Administrador" -ForegroundColor Yellow
    Write-Host "Reiniciando como Administrador..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "NOTA: Windows requiere que el usuario configure manualmente" -ForegroundColor Yellow
Write-Host "que iconos son siempre visibles por razones de seguridad." -ForegroundColor Yellow
Write-Host ""
Write-Host "Este script abrira la configuracion correcta." -ForegroundColor Cyan
Write-Host ""

# Detectar version de Windows
$os = Get-WmiObject -Class Win32_OperatingSystem
$build = [int]$os.BuildNumber

Write-Host "Sistema detectado: Windows $($os.Caption)" -ForegroundColor Gray
Write-Host "Build: $build" -ForegroundColor Gray
Write-Host ""

Read-Host "Presiona Enter para abrir la configuracion"

# Windows 11 (Build 22000+)
if ($build -ge 22000) {
    Write-Host "Abriendo configuracion de Windows 11..." -ForegroundColor Green
    Start-Process "ms-settings:taskbar"
    Write-Host ""
    Write-Host "Pasos a seguir:" -ForegroundColor Cyan
    Write-Host "1. Busca 'Iconos de la bandeja del sistema'" -ForegroundColor White
    Write-Host "2. Expande esa seccion" -ForegroundColor White
    Write-Host "3. Busca 'WSL Memory Monitor'" -ForegroundColor White
    Write-Host "4. Activa el interruptor" -ForegroundColor White
}
# Windows 10
else {
    Write-Host "Abriendo configuracion de Windows 10..." -ForegroundColor Green
    Start-Process "ms-settings:taskbar"
    Write-Host ""
    Write-Host "Pasos a seguir:" -ForegroundColor Cyan
    Write-Host "1. Click en 'Seleccionar los iconos que apareceran en la barra'" -ForegroundColor White
    Write-Host "2. Busca 'WSL Memory Monitor'" -ForegroundColor White
    Write-Host "3. Activa el interruptor" -ForegroundColor White
}

Write-Host ""
Write-Host "Alternativa rapida:" -ForegroundColor Yellow
Write-Host "Arrastra el icono desde la bandeja oculta (flecha ^)" -ForegroundColor White
Write-Host "hacia la bandeja visible" -ForegroundColor White
Write-Host ""

Read-Host "Presiona Enter para salir"