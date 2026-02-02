#!/bin/bash

# Install Flutter
if cd flutter; then git pull && cd .. ; else git clone https://github.com/flutter/flutter.git; fi
ls -la flutter/bin
export PATH="$PATH:`pwd`/flutter/bin"

# Enable web support and build
flutter config --enable-web
flutter pub get
flutter build web --release
