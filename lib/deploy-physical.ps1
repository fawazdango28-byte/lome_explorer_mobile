# deploy-physical.ps1 - Déploiement optimisé pour appareil physique
# Détecte automatiquement les appareils physiques et émulateurs

param(
    [switch]$Full,
    [switch]$Install,
    [switch]$Launch,
    [switch]$Logs,
    [switch]$Info
)

$AppPackage = "com.example.event_flow"
$ApkPath = "build\app\outputs\flutter-apk\app-release.apk"

function Get-ConnectedDevices {
    $devices = adb devices | Select-String "device$" | ForEach-Object {
        $line = $_.Line.Trim()
        $parts = $line -split '\s+'
        if ($parts.Count -ge 2) {
            [PSCustomObject]@{
                ID = $parts[0]
                Type = if ($parts[0] -match "emulator") { "Émulateur" } else { "Physique" }
            }
        }
    }
    return $devices
}

function Show-DeviceInfo {
    # Caractères de cadre remplacés par des tirets et des plus
    Write-Host "+---------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|           Appareils connectés                     |" -ForegroundColor Cyan
    Write-Host "+---------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    
    $devices = Get-ConnectedDevices
    
    if ($devices.Count -eq 0) {
        Write-Host "X Aucun appareil connecté!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Pour connecter un appareil physique:" -ForegroundColor Yellow
        Write-Host "  1. Activez le mode développeur" -ForegroundColor White
        Write-Host "  2. Activez le débogage USB" -ForegroundColor White
        Write-Host "  3. Connectez le câble USB" -ForegroundColor White
        Write-Host "  4. Autorisez le débogage sur le téléphone" -ForegroundColor White
        return $false
    }
    
    foreach ($device in $devices) {
        # Emojis remplacés par du texte
        $icon = if ($device.Type -eq "Physique") { "[P]" } else { "[E]" }
        Write-Host "$icon $($device.Type): $($device.ID)" -ForegroundColor Green
        
        # Obtenir des infos supplémentaires
        $model = adb -s $device.ID shell getprop ro.product.model 2>$null
        $android = adb -s $device.ID shell getprop ro.build.version.release 2>$null
        
        if ($model) {
            Write-Host "   Modèle: $model" -ForegroundColor Gray
        }
        if ($android) {
            Write-Host "   Android: $android" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    return $true
}

function Select-TargetDevice {
    $devices = Get-ConnectedDevices
    
    if ($devices.Count -eq 0) {
        Write-Host "X Aucun appareil connecté!" -ForegroundColor Red
        return $null
    }
    
    if ($devices.Count -eq 1) {
        return $devices[0].ID
    }
    
    # Si plusieurs appareils, demander lequel utiliser
    Write-Host "Plusieurs appareils détectés:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $devices.Count; $i++) {
        # CORRECTION DE SYNTAXE (if/else block) et remplacement de l'emoji
        if ($devices[$i].Type -eq "Physique") { 
            $icon = "[P]" 
        } else { 
            $icon = "[E]" 
        }
        Write-Host "  [$($i+1)] $icon $($devices[$i].Type): $($devices[$i].ID)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Préférer l'appareil physique par défaut
    $physicalIndex = 0
    for ($i = 0; $i -lt $devices.Count; $i++) {
        if ($devices[$i].Type -eq "Physique") {
            $physicalIndex = $i
            break
        }
    }
    
    Write-Host "Utilisation de l'appareil: $($devices[$physicalIndex].ID)" -ForegroundColor Green
    return $devices[$physicalIndex].ID
}

function Install-ToDevice {
    param([string]$DeviceID)
    
    if (-not (Test-Path $ApkPath)) {
        Write-Host "X APK non trouvé. Compilez d'abord!" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Installation sur $DeviceID..." -ForegroundColor Cyan
    
    # Désinstaller
    Write-Host "Uninstall..." -ForegroundColor Yellow
    adb -s $DeviceID uninstall $AppPackage 2>$null
    
    # Installer
    Write-Host "Installation..." -ForegroundColor Cyan
    adb -s $DeviceID install $ApkPath
    
    if ($LASTEXITCODE -eq 0) {
        $size = (Get-Item $ApkPath).Length / 1MB
        Write-Host "OK Installation réussie! ($([math]::Round($size, 2)) MB)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "X Échec de l'installation" -ForegroundColor Red
        return $false
    }
}

function Launch-OnDevice {
    param([string]$DeviceID)
    
    Write-Host "Lancement de l'application..." -ForegroundColor Cyan
    adb -s $DeviceID shell am start -n "$AppPackage/.MainActivity"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK Application lancée!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "X Échec du lancement" -ForegroundColor Red
        return $false
    }
}

function Show-DeviceLogs {
    param([string]$DeviceID)
    
    Write-Host "Logs de l'appareil..." -ForegroundColor Cyan
    Write-Host "Appuyez sur Ctrl+C pour arrêter" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    if ($DeviceID) {
        adb -s $DeviceID logcat | Select-String "flutter"
    } else {
        adb logcat | Select-String "flutter"
    }
}

# Main
Write-Host @"
+---------------------------------------------------+
|      Event Flow - Déploiement Appareil Physique   |
+---------------------------------------------------+
"@ -ForegroundColor Cyan
Write-Host ""

if ($Info -or (-not ($Full -or $Install -or $Launch -or $Logs))) {
    Show-DeviceInfo
    exit
}

# Sélectionner l'appareil cible
$targetDevice = Select-TargetDevice

if (-not $targetDevice) {
    Write-Host ""
    Write-Host "Connectez votre téléphone et réessayez" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Appareil cible: $targetDevice" -ForegroundColor Cyan
Write-Host ""

# Exécuter les actions
if ($Full -or $Install) {
    if (Install-ToDevice -DeviceID $targetDevice) {
        Write-Host ""
        
        if ($Full -or $Launch) {
            Launch-OnDevice -DeviceID $targetDevice
        }
    } else {
        exit 1
    }
}

if ($Launch -and -not ($Full -or $Install)) {
    Launch-OnDevice -DeviceID $targetDevice
}

if ($Logs) {
    Write-Host ""
    Show-DeviceLogs -DeviceID $targetDevice
}

if (-not $Logs) {
    Write-Host ""
    # Caractères de cadre remplacés par des tirets et des plus
    Write-Host "+---------------------------------------------------+" -ForegroundColor Green
    Write-Host "|              OK Déploiement terminé !             |" -ForegroundColor Green
    Write-Host "+---------------------------------------------------+" -ForegroundColor Green
}