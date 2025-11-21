# deploy.ps1 - Script de déploiement rapide pour Event Flow
# Usage: .\deploy.ps1 [options]
# Options: -Build, -Install, -Launch, -Logs, -Clean, -Full

param(
    [switch]$Build,
    [switch]$Install,
    [switch]$Launch,
    [switch]$Logs,
    [switch]$Clean,
    [switch]$Full,
    [switch]$Help
)

$AppPackage = "com.example.event_flow"
$ApkPath = "build\app\outputs\flutter-apk\app-release.apk"

function Show-Help {
    Write-Host @"
╔═══════════════════════════════════════════════════════╗
║         Event Flow - Déploiement Android             ║
╚═══════════════════════════════════════════════════════╝

Usage: .\deploy.ps1 [options]

Options:
  -Build      Compiler l'APK
  -Install    Installer l'APK sur l'appareil
  -Launch     Lancer l'application
  -Logs       Afficher les logs Flutter
  -Clean      Nettoyer avant compilation
  -Full       Tout faire (Clean + Build + Install + Launch)
  -Help       Afficher cette aide

Exemples:
  .\deploy.ps1 -Full                    # Tout faire
  .\deploy.ps1 -Build -Install          # Compiler et installer
  .\deploy.ps1 -Install -Launch         # Installer et lancer
  .\deploy.ps1 -Logs                    # Voir les logs
  .\deploy.ps1 -Clean -Build            # Clean et compiler

"@ -ForegroundColor Cyan
}

function Check-Device {
    Write-Host "📱 Vérification des appareils..." -ForegroundColor Cyan
    $devices = adb devices | Select-String "device$"
    
    if ($devices.Count -eq 0) {
        Write-Host "❌ Aucun appareil connecté!" -ForegroundColor Red
        Write-Host "💡 Lancez un émulateur ou connectez un appareil" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "✅ Appareil détecté" -ForegroundColor Green
}

function Clean-Project {
    Write-Host "🧹 Nettoyage du projet..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Nettoyage terminé" -ForegroundColor Green
    }
}

function Build-Apk {
    Write-Host "🔨 Compilation de l'APK..." -ForegroundColor Cyan
    flutter build apk --release
    
    if ($LASTEXITCODE -eq 0 -and (Test-Path $ApkPath)) {
        $size = (Get-Item $ApkPath).Length / 1MB
        Write-Host "✅ APK compilé avec succès ($([math]::Round($size, 2)) MB)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Échec de la compilation" -ForegroundColor Red
        return $false
    }
}

function Install-Apk {
    if (-not (Test-Path $ApkPath)) {
        Write-Host "❌ APK non trouvé. Compilez d'abord avec -Build" -ForegroundColor Red
        return $false
    }
    
    Write-Host "📦 Installation de l'APK..." -ForegroundColor Cyan
    
    # Désinstaller l'ancienne version
    Write-Host "🗑️  Désinstallation de l'ancienne version..." -ForegroundColor Yellow
    adb uninstall $AppPackage 2>$null
    
    # Installer la nouvelle version
    adb install $ApkPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Installation réussie!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Échec de l'installation" -ForegroundColor Red
        return $false
    }
}

function Launch-App {
    Write-Host "🚀 Lancement de l'application..." -ForegroundColor Cyan
    adb shell am start -n "$AppPackage/.MainActivity"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Application lancée" -ForegroundColor Green
        Start-Sleep -Seconds 2
        return $true
    } else {
        Write-Host "❌ Échec du lancement" -ForegroundColor Red
        return $false
    }
}

function Show-Logs {
    Write-Host "📊 Affichage des logs Flutter..." -ForegroundColor Cyan
    Write-Host "Appuyez sur Ctrl+C pour arrêter" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Gray
    adb logcat | Select-String "flutter"
}

# Fonction principale
function Main {
    Write-Host @"
╔═══════════════════════════════════════════════════════╗
║         Event Flow - Déploiement Android             ║
╚═══════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    if ($Help) {
        Show-Help
        return
    }

    # Si aucune option, afficher l'aide
    if (-not ($Build -or $Install -or $Launch -or $Logs -or $Clean -or $Full)) {
        Show-Help
        return
    }

    # Mode Full : tout faire
    if ($Full) {
        $Clean = $true
        $Build = $true
        $Install = $true
        $Launch = $true
    }

    # Vérifier l'appareil (sauf si seulement Clean ou Build)
    if ($Install -or $Launch -or $Logs) {
        Check-Device
    }

    # Exécuter les actions dans l'ordre
    if ($Clean) {
        Clean-Project
        Write-Host ""
    }

    if ($Build) {
        if (-not (Build-Apk)) {
            exit 1
        }
        Write-Host ""
    }

    if ($Install) {
        if (-not (Install-Apk)) {
            exit 1
        }
        Write-Host ""
    }

    if ($Launch) {
        if (-not (Launch-App)) {
            exit 1
        }
        Write-Host ""
    }

    if ($Logs) {
        Show-Logs
    }

    if (-not $Logs) {
        Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║              ✅ Déploiement terminé !                ║" -ForegroundColor Green
        Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
    }
}

# Exécuter
Main