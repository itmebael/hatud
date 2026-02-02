# Flutter Run Script with Increased Memory
# This script sets Dart VM memory options and runs the Flutter app

Write-Host "Setting Dart VM memory options..." -ForegroundColor Cyan
$env:DART_VM_OPTIONS = "--old_gen_heap_size=2048 --new_gen_heap_size=512"

Write-Host "Running Flutter app..." -ForegroundColor Green
flutter run


