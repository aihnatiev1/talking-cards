#!/usr/bin/env bash
# Capture all 14 store-slot source screenshots (7 screens × uk/en) from the
# real app on an iPhone simulator, then check every one of them.
#
#   tools/capture_store_screenshots.sh              # iPhone 17 Pro Max
#   tools/capture_store_screenshots.sh <sim-udid>
#
# The rig is integration_test/visual_refresh_test.dart. Its screenshots
# travel back to the host in one request at the end of the run (~30 MB of
# PNG), and that transfer drops now and then ("Service connection
# disposed") even though the test itself passed — 1 of 3 English runs on
# 2026-09-30. So each locale gets up to three attempts, and the run only
# counts when all seven files are new and full-size.
set -uo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-$(xcrun simctl list devices available | grep 'iPhone 17 Pro Max' | head -1 | grep -oE '[0-9A-F-]{36}')}"
[ -n "$DEVICE" ] || { echo "no simulator found"; exit 1; }
xcrun simctl boot "$DEVICE" 2>/dev/null || true
OUT=marketing/public/screenshots/auto
SCREENS=(home sounds cards game draw fill quest)
LOG_DIR="${TMPDIR:-/tmp}/store-shots"; mkdir -p "$LOG_DIR"

fresh_set() {  # $1 locale, $2 epoch the run started
  for s in "${SCREENS[@]}"; do
    f="$OUT/refresh-$s-$1.png"
    [ -f "$f" ] || return 1
    [ "$(stat -f %m "$f")" -ge "$2" ] || return 1
    w=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
    [ "${w:-0}" -ge 1200 ] || return 1
  done
}

status=0
for lang in uk en; do
  ok=0
  for attempt in 1 2 3; do
    started=$(date +%s)
    echo "[$lang] attempt $attempt…"
    flutter drive --driver=test_driver/integration_test.dart \
      --target=integration_test/visual_refresh_test.dart \
      --dart-define=AUDIT_LANG="$lang" -d "$DEVICE" \
      > "$LOG_DIR/$lang-$attempt.log" 2>&1
    if fresh_set "$lang" "$started"; then ok=1; break; fi
    grep -qE 'Some tests failed|EXCEPTION CAUGHT' "$LOG_DIR/$lang-$attempt.log" \
      && { echo "[$lang] the rig itself failed — see $LOG_DIR/$lang-$attempt.log"; break; }
    echo "[$lang] transfer dropped, retrying"
  done
  if [ "$ok" = 1 ]; then echo "[$lang] 7/7 captured"; else echo "[$lang] FAILED"; status=1; fi
done
exit $status
