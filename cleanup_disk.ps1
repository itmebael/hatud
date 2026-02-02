# Disk Cleanup Script for Flutter Build
Write-Host "Cleaning Flutter and Gradle build artifacts..." -ForegroundColor Cyan

# Clean Flutter
Write-Host "`n1. Cleaning Flutter build..." -ForegroundColor Yellow
flutter clean

# Clean Gradle
Write-Host "`n2. Cleaning Gradle build..." -ForegroundColor Yellow
cd android
.\gradlew clean --no-daemon
.\gradlew --stop
cd ..

# Clean Gradle cache (optional - be careful)
Write-Host "`n3. Cleaning Gradle cache (this may take time)..." -ForegroundColor Yellow
$gradleCache = "$env:USERPROFILE\.gradle\caches"
if (Test-Path $gradleCache) {
    $sizeBefore = (Get-ChildItem $gradleCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "Gradle cache size before: $([math]::Round($sizeBefore, 2)) GB" -ForegroundColor Gray
    
    # Only clean old build cache, not everything
    Remove-Item "$gradleCache\build-cache-*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$gradleCache\modules-*\files-*\*.jar" -Recurse -Force -ErrorAction SilentlyContinue -ErrorAction SilentlyContinue
    
    $sizeAfter = (Get-ChildItem $gradleCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "Gradle cache size after: $([math]::Round($sizeAfter, 2)) GB" -ForegroundColor Gray
    Write-Host "Freed: $([math]::Round($sizeBefore - $sizeAfter, 2)) GB" -ForegroundColor Green
}

# Check disk space
Write-Host "`n4. Checking disk space..." -ForegroundColor Yellow
$drive = Get-PSDrive C
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$usedGB = [math]::Round($drive.Used / 1GB, 2)
Write-Host "C: Drive - Free: $freeGB GB | Used: $usedGB GB" -ForegroundColor $(if ($freeGB -lt 5) { "Red" } elseif ($freeGB -lt 10) { "Yellow" } else { "Green" })

if ($freeGB -lt 5) {
    Write-Host "`n⚠️  WARNING: Less than 5GB free space!" -ForegroundColor Red
    Write-Host "Please free up disk space before building." -ForegroundColor Red
    Write-Host "Suggestions:" -ForegroundColor Yellow
    Write-Host "  - Delete old files from Downloads folder" -ForegroundColor Gray
    Write-Host "  - Empty Recycle Bin" -ForegroundColor Gray
    Write-Host "  - Run Windows Disk Cleanup" -ForegroundColor Gray
    Write-Host "  - Delete unused programs" -ForegroundColor Gray
}

Write-Host "`n✅ Cleanup complete!" -ForegroundColor Green


