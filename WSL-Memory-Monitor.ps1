# WSL Memory Monitor - Sistema de bandeja para Windows
# Muestra el perfil de memoria actual en la bandeja del sistema

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Configuración
$ConfigPath = "$env:USERPROFILE\.wslconfig"

# Perfiles (mismo orden que el switch)
$Profiles = @(
    @{Name="GAMING"; Memory=8; CPU=4; Level=5; Color="Blue"},
    @{Name="WIN-FOCUS"; Memory=16; CPU=8; Level=4; Color="DarkBlue"},
    @{Name="BALANCED"; Memory=24; CPU=12; Level=3; Color="Gray"},
    @{Name="WSL-DEV"; Memory=32; CPU=16; Level=2; Color="DarkGreen"},
    @{Name="WSL-FOCUS"; Memory=48; CPU=20; Level=1; Color="Green"}
)

# Función para crear iconos con números usando gradiente de color
function Create-NumberIcon {
    param($Number)
    
    try {
        # Crear bitmap más grande para mejor calidad
        $size = 32
        $bitmap = New-Object System.Drawing.Bitmap $size, $size
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        
        # Calcular color basado en el número (1-5)
        # 5 = Azul puro (Windows), 1 = Verde puro (WSL), 2-4 = Gradiente
        $bgColor = switch ($Number) {
            5 { 
                # Azul Windows
                [System.Drawing.Color]::FromArgb(0, 120, 215) 
            }
            4 { 
                # Azul-Cyan
                [System.Drawing.Color]::FromArgb(0, 150, 180) 
            }
            3 { 
                # Gris-Azulado (Balanced)
                [System.Drawing.Color]::FromArgb(60, 120, 120) 
            }
            2 { 
                # Verde-Azulado
                [System.Drawing.Color]::FromArgb(0, 150, 100) 
            }
            1 { 
                # Verde WSL
                [System.Drawing.Color]::FromArgb(0, 176, 80) 
            }
            default { 
                [System.Drawing.Color]::Gray 
            }
        }
        
        # Crear gradiente radial para efecto 3D
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse(2, 2, $size-4, $size-4)
        
        $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
        $brush.CenterColor = [System.Drawing.Color]::FromArgb(
            [Math]::Min(255, $bgColor.R + 60),
            [Math]::Min(255, $bgColor.G + 60),
            [Math]::Min(255, $bgColor.B + 60)
        )
        $brush.SurroundColors = @($bgColor)
        
        # Dibujar círculo con gradiente
        $graphics.FillEllipse($brush, 2, 2, $size-4, $size-4)
        
        # Borde sutil
        $borderColor = [System.Drawing.Color]::FromArgb(
            [Math]::Max(0, $bgColor.R - 30),
            [Math]::Max(0, $bgColor.G - 30),
            [Math]::Max(0, $bgColor.B - 30)
        )
        $pen = New-Object System.Drawing.Pen($borderColor, 1)
        $graphics.DrawEllipse($pen, 2, 2, $size-4, $size-4)
        
        # Dibujar número con sombra
        $font = New-Object System.Drawing.Font("Arial", 18, [System.Drawing.FontStyle]::Bold)
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        
        $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
        
        # Sombra
        $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 0, 0, 0))
        $shadowRect = New-Object System.Drawing.RectangleF(1, 1, $size, $size)
        $graphics.DrawString($Number.ToString(), $font, $shadowBrush, $shadowRect, $format)
        
        # Número principal
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $graphics.DrawString($Number.ToString(), $font, $textBrush, $rect, $format)
        
        # Limpiar recursos
        $font.Dispose()
        $textBrush.Dispose()
        $shadowBrush.Dispose()
        $brush.Dispose()
        $pen.Dispose()
        $path.Dispose()
        $graphics.Dispose()
        
        # Convertir a Icon
        $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
        return $icon
    }
    catch {
        Write-Host "Error creando icono: $_" -ForegroundColor Red
        # Devolver icono por defecto
        return [System.Drawing.SystemIcons]::Information
    }
}

# Función para obtener perfil actual
function Get-CurrentProfile {
    if (Test-Path $ConfigPath) {
        $content = Get-Content $ConfigPath -Raw
        if ($content -match 'memory=(\d+)GB') {
            $memory = [int]($matches[1])
            foreach ($profile in $Profiles) {
                if ($profile.Memory -eq $memory) {
                    return $profile
                }
            }
        }
    }
    return $Profiles[2]  # Default: Balanced
}

# Crear formulario oculto (necesario para el NotifyIcon)
$form = New-Object System.Windows.Forms.Form
$form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
$form.ShowInTaskbar = $false
$form.Visible = $false

# Crear NotifyIcon
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Visible = $true

# Crear menú contextual
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Agregar título del menú
$titleItem = New-Object System.Windows.Forms.ToolStripMenuItem
$titleItem.Text = "WSL Memory Monitor"
$titleItem.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$titleItem.Enabled = $false
$contextMenu.Items.Add($titleItem) | Out-Null

$separator1 = New-Object System.Windows.Forms.ToolStripSeparator
$contextMenu.Items.Add($separator1) | Out-Null

# Agregar estado actual
$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$statusItem.Text = "Estado actual..."
$statusItem.Enabled = $false
$contextMenu.Items.Add($statusItem) | Out-Null

$separator2 = New-Object System.Windows.Forms.ToolStripSeparator
$contextMenu.Items.Add($separator2) | Out-Null

# Agregar opciones de perfil
foreach ($profile in $Profiles) {
    $menuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $winGB = 64 - $profile.Memory
    $menuItem.Text = "Nivel $($profile.Level): $($profile.Name)"
    $menuItem.Tag = $profile
    $menuItem.Add_Click({
        # Abrir el switch directamente
        try {
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSScriptRoot\WSL-Memory-Switch.ps1`"" -ErrorAction Stop
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error al abrir Memory Switch: $_", "Error", "OK", "Error")
        }
    })
    $contextMenu.Items.Add($menuItem) | Out-Null
}

$separator3 = New-Object System.Windows.Forms.ToolStripSeparator
$contextMenu.Items.Add($separator3) | Out-Null

# Opción para abrir el switch
$switchItem = New-Object System.Windows.Forms.ToolStripMenuItem
$switchItem.Text = "Abrir Memory Switch"
$switchItem.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$switchItem.Add_Click({
    try {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSScriptRoot\WSL-Memory-Switch.ps1`"" -ErrorAction Stop
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error al abrir Memory Switch: $_", "Error", "OK", "Error")
    }
})
$contextMenu.Items.Add($switchItem) | Out-Null

# Opción de actualizar
$refreshItem = New-Object System.Windows.Forms.ToolStripMenuItem
$refreshItem.Text = "Actualizar"
$refreshItem.Add_Click({
    Update-TrayIcon
})
$contextMenu.Items.Add($refreshItem) | Out-Null

$separator4 = New-Object System.Windows.Forms.ToolStripSeparator
$contextMenu.Items.Add($separator4) | Out-Null

# Opción de salir
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Salir"
$exitItem.Add_Click({
    $script:running = $false
    $notifyIcon.Visible = $false
    if ($script:currentIcon) {
        $script:currentIcon.Dispose()
    }
    $form.Close()
})
$contextMenu.Items.Add($exitItem) | Out-Null

$notifyIcon.ContextMenuStrip = $contextMenu

# Variable para almacenar el icono actual
$script:currentIcon = $null

# Función para actualizar el icono y tooltip
function Update-TrayIcon {
    try {
        $current = Get-CurrentProfile
        
        # Crear/actualizar icono
        if ($script:currentIcon) {
            $script:currentIcon.Dispose()
        }
        $script:currentIcon = Create-NumberIcon -Number $current.Level
        $notifyIcon.Icon = $script:currentIcon
        
        # Actualizar tooltip (máximo 63 caracteres)
        $winGB = 64 - $current.Memory
        $tooltip = "Nivel $($current.Level): Win $($winGB)GB | WSL $($current.Memory)GB"
        if ($tooltip.Length -gt 63) {
            $tooltip = "L$($current.Level): W$($winGB)GB|WSL$($current.Memory)GB"
        }
        $notifyIcon.Text = $tooltip
        
        # Actualizar estado en el menú
        $statusText = "Windows: $($winGB)GB | WSL: $($current.Memory)GB"
        foreach ($item in $contextMenu.Items) {
            if ($item -is [System.Windows.Forms.ToolStripMenuItem]) {
                if ($item.Text -eq "Estado actual...") {
                    $item.Text = $statusText
                }
                elseif ($item.Tag) {
                    $item.Checked = ($item.Tag.Name -eq $current.Name)
                }
            }
        }
    }
    catch {
        Write-Host "Error actualizando icono: $_" -ForegroundColor Red
    }
}

# Click en el icono abre el switch
$notifyIcon.Add_MouseClick({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        try {
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSScriptRoot\WSL-Memory-Switch.ps1`"" -ErrorAction Stop
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error al abrir Memory Switch: $_", "Error", "OK", "Error")
        }
    }
})

# Timer para actualizar periódicamente
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000  # 30 segundos
$timer.Add_Tick({
    if ($script:running) {
        Update-TrayIcon
    }
})

# Variable de control
$script:running = $true

# Actualizar icono inicial
Update-TrayIcon

# Iniciar timer
$timer.Start()

# Mostrar notificación inicial
try {
    $notifyIcon.BalloonTipTitle = "WSL Memory Monitor"
    $notifyIcon.BalloonTipText = "Monitor activo. Click para abrir Memory Switch."
    $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $notifyIcon.ShowBalloonTip(3000)
}
catch {
    # Ignorar errores de notificación
}

Write-Host "WSL Memory Monitor iniciado" -ForegroundColor Green
Write-Host "El icono aparece en la bandeja del sistema" -ForegroundColor Cyan
Write-Host "Minimiza esta ventana (no la cierres)" -ForegroundColor Yellow
Write-Host ""

# Ejecutar el formulario
try {
    [System.Windows.Forms.Application]::Run($form)
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
finally {
    # Limpiar al salir
    Write-Host "Cerrando monitor..." -ForegroundColor Yellow
    $timer.Stop()
    $timer.Dispose()
    if ($script:currentIcon) {
        $script:currentIcon.Dispose()
    }
    $notifyIcon.Dispose()
    $form.Dispose()
    Write-Host "Monitor cerrado" -ForegroundColor Green
}