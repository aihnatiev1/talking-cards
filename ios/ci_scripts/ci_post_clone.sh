#!/bin/bash
# Xcode Cloud post-clone hook: bootstrap a Flutter toolchain inside the build
# container and prep the iOS workspace so xcodebuild can take over.
#
# Notes:
#  - Xcode Cloud drops us in $CI_PRIMARY_REPOSITORY_PATH/ios/ci_scripts on
#    invocation, NOT at the repo root. `flutter pub get` must run where
#    pubspec.yaml lives, otherwise it exits 1 with "no pubspec".
#  - We call `flutter --version` once so the SDK fully self-installs (Dart
#    toolchain, pub cache) before any pub/build commands.
#  - Use bash, not sh — set -u and set -o pipefail are bash-friendly.
set -euo pipefail

echo "▶ Xcode Cloud post-clone — repo: $CI_PRIMARY_REPOSITORY_PATH"

# 1. Fetch Flutter SDK if not already cached. --depth 1 keeps it small.
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"

# 2. Force first-run init so dart-sdk + pub cache exist before pub get.
flutter --version
flutter precache --ios

# 3. Resolve Dart deps from the Flutter project root, NOT from ios/.
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

# 4. CocoaPods install with repo update so freshly added pods resolve.
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install --repo-update

echo "✓ post-clone complete"
