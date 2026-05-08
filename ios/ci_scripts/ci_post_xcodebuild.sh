#!/bin/bash
# Xcode Cloud post-xcodebuild hook: upload dSYMs to Firebase Crashlytics so
# iOS crashes are symbolicated in the Firebase console (otherwise stack
# traces show raw addresses).
#
# Notes:
#  - $CI_ARCHIVE_PATH is set by Xcode Cloud only for archive actions; we no-op
#    on test/build actions where no dSYMs are produced.
#  - upload-symbols ships with the FirebaseCrashlytics pod, which is pulled in
#    via the firebase_crashlytics Flutter plugin. If the path is missing,
#    pod install hasn't run — fail loud.
set -euo pipefail

if [ -z "${CI_ARCHIVE_PATH:-}" ]; then
  echo "▶ post-xcodebuild: not an archive action (no CI_ARCHIVE_PATH) — skipping dSYM upload"
  exit 0
fi

UPLOAD_SYMBOLS="${CI_PRIMARY_REPOSITORY_PATH}/ios/Pods/FirebaseCrashlytics/upload-symbols"
GSP="${CI_PRIMARY_REPOSITORY_PATH}/ios/Runner/GoogleService-Info.plist"
DSYMS_DIR="${CI_ARCHIVE_PATH}/dSYMs"

if [ ! -x "$UPLOAD_SYMBOLS" ]; then
  echo "✗ upload-symbols not found at $UPLOAD_SYMBOLS — did pod install run?"
  exit 1
fi

if [ ! -d "$DSYMS_DIR" ]; then
  echo "✗ dSYMs dir missing: $DSYMS_DIR"
  exit 1
fi

echo "▶ Uploading dSYMs from $DSYMS_DIR to Crashlytics"
"$UPLOAD_SYMBOLS" -gsp "$GSP" -p ios "$DSYMS_DIR"
echo "✓ dSYM upload complete"
