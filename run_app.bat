@echo off
REM Flutter Run Script with Increased Memory for Windows
REM This script sets Dart VM memory options and runs the Flutter app

echo Setting Dart VM memory options...
set DART_VM_OPTIONS=--old_gen_heap_size=2048 --new_gen_heap_size=512

echo Running Flutter app...
flutter run






