#!/usr/bin/env bash
# Trim every mp3 in assets/audio_mp3 to just the first word.
#
# Pipeline per file:
#   1. Strip leading silence (everything before the first sound).
#   2. After audio starts, stop at the first silence of >=STOP_DUR seconds —
#      that gap marks the end of the first word.
#   3. Apply a short fade-out on the tail so the cut isn't a hard click.
#
# Outputs to assets/audio_mp3_trimmed/ (originals untouched).
#
# Usage:
#   tools/trim_audio_to_first_word.sh            # full batch
#   tools/trim_audio_to_first_word.sh kavun apelsin   # single files for QA

set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/assets/audio_mp3"
DST="$(cd "$(dirname "$0")/.." && pwd)/assets/audio_mp3_trimmed"

# Tuning knobs — threshold & min-silence work for the current voice recordings.
NOISE="-38dB"
START_DUR="0.05"  # leading silence to strip
STOP_DUR="0.30"   # silence long enough to mark end of first word

mkdir -p "$DST"

process() {
  local in="$1"
  local name
  name="$(basename "$in")"
  local out="$DST/$name"
  ffmpeg -y -loglevel error \
    -i "$in" \
    -af "silenceremove=start_periods=1:start_duration=$START_DUR:start_threshold=$NOISE:detection=peak,\
silenceremove=stop_periods=1:stop_duration=$STOP_DUR:stop_threshold=$NOISE:detection=peak,\
areverse,afade=t=in:st=0:d=0.08,areverse" \
    -ar 44100 -ac 1 -b:a 96k \
    "$out"
  local din
  din="$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$in")"
  local dout
  dout="$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$out")"
  printf "  %-25s %5.2fs → %5.2fs\n" "$name" "$din" "$dout"
}

if [ "$#" -gt 0 ]; then
  # Process only the names passed (with or without .mp3).
  for arg in "$@"; do
    f="$SRC/${arg%.mp3}.mp3"
    [ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
    process "$f"
  done
else
  shopt -s nullglob
  total=0
  for f in "$SRC"/*.mp3; do
    process "$f"
    total=$((total + 1))
  done
  echo "done: $total files → $DST"
fi
