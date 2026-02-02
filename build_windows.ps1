# Build script for Windows with proper Visual Studio environment
# This script initializes the Visual Studio Developer PowerShell and builds the Flutter app

Write-Host "Initializing Visual Studio Developer PowerShell..." -ForegroundColor Cyan

# Initialize Visual Studio Developer PowerShell
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Preview\Common7\Tools\Launch-VsDevShell.ps1"
if (Test-Path $vsPath) {
    & $vsPath -Arch amd64 -HostArch amd64
    Write-Host "Visual Studio Developer PowerShell initialized" -ForegroundColor Green
} else {
    Write-Host "Warning: Visual Studio Developer PowerShell not found at expected path" -ForegroundColor Yellow
    Write-Host "Make sure Visual Studio 2022 with C++ desktop development workload is installed" -ForegroundColor Yellow
}

Write-Host "`nCleaning build artifacts..." -ForegroundColor Cyan
flutter clean

Write-Host "`nGetting dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "`nBuilding Windows application..." -ForegroundColor Cyan
flutter run -d windows











