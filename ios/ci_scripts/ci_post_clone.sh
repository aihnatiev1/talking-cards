#!/bin/sh
set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios
flutter pub get

cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install
