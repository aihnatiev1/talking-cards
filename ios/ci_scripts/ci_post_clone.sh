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

# 1. Fetch a PINNED Flutter SDK. Do NOT clone floating `stable`: CI stable
#    drifts ahead of the version the app is built/released with locally, and a
#    newer toolchain regenerates the iOS plugin registrant / pods differently,
#    which surfaced as "Module 'audio_session' not found" on Xcode Cloud while
#    local builds were clean. Keep this in lockstep with the local Flutter
#    version (`flutter --version`) on every SDK upgrade.
FLUTTER_VERSION="3.41.5"
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"

# Reconcile a cached SDK from a prior build if its version differs from the pin.
if ! flutter --version | grep -q "Flutter $FLUTTER_VERSION "; then
  git -C "$HOME/flutter" fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION" \
    && git -C "$HOME/flutter" checkout FETCH_HEAD
fi

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
