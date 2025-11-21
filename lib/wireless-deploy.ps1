# wireless-deploy.ps1 - Installation via WiFi
# Usage: .\wireless-deploy.ps1 [IP_du_téléphone]

param(
    [Parameter(Position=0)]
    [string]$DeviceIP = "",
    [switch]$Setup,
    [switch]$Install,
    [switch]$Disconnect
)

$AppPackage = "com.example.event_flow"
$ApkPath = "build\app\outputs\flutter-apk\app-release.apk"

function Show-Help {
    Write-Host @"
╔═══════════════════════════════════════════════════════╗
║         Installation sans fil (WiFi)                 ║
╚═══════════════════════════════════════════════════════╝

Prérequis:
  1. Téléphone et PC sur le même réseau WiFi
  2. Débogage USB activé sur le téléphone
  3. Première connexion doit être en USB

Étapes:
  1. Connectez le téléphone en USB
  2. Exécutez: .\wireless-deploy.ps1 -Setup
  3. Débranchez le câble USB
  4. Utilisez: .\wireless-deploy.ps1 192.168.1.XX -Install

Commandes:
  -Setup          Configuration initiale (USB requis)
  -Install        Installer l'APK
  -Disconnect     Se déconnecter du WiFi
  
Exemples:
  .\wireless-deploy.ps1 -Setup
  .\wireless-deploy.ps1 192.168.1.100 -Install
  .\wireless-deploy.ps1 -Disconnect

"@ -ForegroundColor Cyan
}

function Setup-WirelessADB {
    Write-Host "🔧 Configuration de ADB sans fil..." -ForegroundColor Cyan
    
    # Vérifier qu'un appareil est connecté en USB
    $devices = adb devices | Select-String "device$"
    if ($devices.Count -eq 0) {
        Write-Host "❌ Aucun appareil USB détecté!" -ForegroundColor Red
        Write-Host "💡 Connectez votre téléphone en USB d'abord" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "✅ Appareil USB détecté" -ForegroundColor Green
    
    # Activer TCP/IP sur le port 5555
    Write-Host "📡 Activation du mode TCP/IP..." -ForegroundColor Cyan
    adb tcpip 5555
    Start-Sleep -Seconds 2
    
    # Obtenir l'adresse IP du téléphone
    Write-Host "🔍 Recherche de l'adresse IP..." -ForegroundColor Cyan
    $ip = adb shell ip addr show wlan0 | Select-String "inet " | ForEach-Object {
        if ($_ -match "inet (\d+\.\d+\.\d+\.\d+)") {
            $matches[1]
        }
    }
    
    if ($ip) {
        Write-Host "✅ Adresse IP trouvée: $ip" -ForegroundColor Green
        Write-Host ""
        Write-Host "🔌 Vous pouvez maintenant débrancher le câble USB" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "📝 Pour vous connecter en WiFi, utilisez:" -ForegroundColor Cyan
        Write-Host "   .\wireless-deploy.ps1 $ip -Install" -ForegroundColor White
        Write-Host ""
        
        # Sauvegarder l'IP pour la prochaine fois
        $ip | Out-File -FilePath ".adb-wifi-ip.txt" -Encoding UTF8
        
        return $true
    } else {
        Write-Host "❌ Impossible de trouver l'adresse IP" -ForegroundColor Red
        Write-Host "💡 Vérifiez que le WiFi est activé sur le téléphone" -ForegroundColor Yellow
        return $false
    }
}

function Connect-WirelessADB {
    param([string]$IP)
    
    Write-Host "📡 Connexion à $IP..." -ForegroundColor Cyan
    
    # Se connecter
    adb connect "${IP}:5555"
    Start-Sleep -Seconds 2
    
    # Vérifier la connexion
    $connected = adb devices | Select-String "${IP}:5555"
    
    if ($connected) {
        Write-Host "✅ Connecté en WiFi!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Échec de la connexion" -ForegroundColor Red
        Write-Host "💡 Vérifiez que :" -ForegroundColor Yellow
        Write-Host "   - Le téléphone et le PC sont sur le même WiFi" -ForegroundColor Yellow
        Write-Host "   - Vous avez exécuté -Setup d'abord" -ForegroundColor Yellow
        return $false
    }
}

function Disconnect-WirelessADB {
    Write-Host "🔌 Déconnexion du WiFi..." -ForegroundColor Cyan
    adb disconnect
    Write-Host "✅ Déconnecté" -ForegroundColor Green
}

function Install-WirelessAPK {
    if (-not (Test-Path $ApkPath)) {
        Write-Host "❌ APK non trouvé. Compilez d'abord avec: flutter build apk --release" -ForegroundColor Red
        return $false
    }
    
    Write-Host "📦 Installation de l'APK via WiFi..." -ForegroundColor Cyan
    
    # Désinstaller l'ancienne version
    Write-Host "🗑️  Désinstallation de l'ancienne version..." -ForegroundColor Yellow
    adb uninstall $AppPackage 2>$null
    
    # Installer
    adb install $ApkPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Installation réussie!" -ForegroundColor Green
        
        # Lancer l'app
        Write-Host "🚀 Lancement de l'application..." -ForegroundColor Cyan
        adb shell am start -n "$AppPackage/.MainActivity"
        Write-Host "✅ Application lancée" -ForegroundColor Green
        
        return $true
    } else {
        Write-Host "❌ Échec de l'installation" -ForegroundColor Red
        return $false
    }
}

# Main
if (-not $Setup -and -not $Install -and -not $Disconnect -and -not $DeviceIP) {
    Show-Help
    exit
}

if ($Setup) {
    Setup-WirelessADB
    exit
}

if ($Disconnect) {
    Disconnect-WirelessADB
    exit
}

if ($Install) {
    # Si pas d'IP fournie, essayer de la charger
    if (-not $DeviceIP -and (Test-Path ".adb-wifi-ip.txt")) {
        $DeviceIP = Get-Content ".adb-wifi-ip.txt" -Raw
        $DeviceIP = $DeviceIP.Trim()
        Write-Host "📝 Utilisation de l'IP sauvegardée: $DeviceIP" -ForegroundColor Cyan
    }
    
    if (-not $DeviceIP) {
        Write-Host "❌ Veuillez fournir l'adresse IP du téléphone" -ForegroundColor Red
        Write-Host "Exemple: .\wireless-deploy.ps1 192.168.1.100 -Install" -ForegroundColor Yellow
        exit 1
    }
    
    if (Connect-WirelessADB -IP $DeviceIP) {
        Install-WirelessAPK
    }
    exit
}

if ($DeviceIP) {
    Connect-WirelessADB -IP $DeviceIP
}