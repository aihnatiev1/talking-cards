#!/usr/bin/env python3
"""Re-encode card illustrations and voice clips to what the app can actually
show and hear.

    python3 tools/compress_assets.py            # rewrite in place, print totals
    python3 tools/compress_assets.py --dry-run  # totals only, nothing written
    python3 tools/compress_assets.py --audio-only | --images-only

Images: cards shipped at 800×1072 while no screen decodes them wider than
`kCardSourceWidth` (lib/utils/image_cache_size.dart). They become ≤640 px
wide at WebP q80 with sharp YUV — about a third of the bytes, no visible
change at phone density. Files already narrower are re-encoded without
resizing. UI art (splash, quest map) is left alone.

Audio: 96 kbps mono → 64 kbps mono, still 44.1 kHz. Speech is clean at 64k
and the duration is preserved to the sample, which matters: playWordOnly()
stops the clip at a millisecond offset from assets/data/audio_word_lengths.json.

Needs cwebp (libwebp) and ffmpeg on PATH. Audio is idempotent (clips already
at the target bitrate are skipped). Images are NOT: a second pass re-encodes
q80 over q80 and loses a little more each time, so run it once per source
export — or with --audio-only.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'assets'
IMAGE_DIRS = [ASSETS / 'images/webp', ASSETS / 'pad_content/images/webp']
AUDIO_DIRS = [ASSETS / 'audio_mp3', ASSETS / 'pad_content/audio_mp3']
# UI art, not card illustrations — sized for its own layout.
SKIP_IMAGES = {'splash'}
MAX_WIDTH = 640  # keep equal to kCardSourceWidth
WEBP_QUALITY = 80
AUDIO_KBPS = 64
# MP3 frames are 26 ms; the encoder may pad the tail by up to one. The word
# cut-off is a timer, so this is inaudible — but a bigger drift is a bug.
DURATION_TOLERANCE_S = 0.03


def probe(args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout.strip()


def image_width(path):
    out = probe(['sips', '-g', 'pixelWidth', str(path)])
    return int(out.rsplit(' ', 1)[-1])


def audio_kbps(path):
    out = probe(['ffprobe', '-v', 'error', '-select_streams', 'a:0',
                 '-show_entries', 'stream=bit_rate', '-of', 'csv=p=0', str(path)])
    return int(out) // 1000 if out.isdigit() else 0


def duration(path):
    return probe(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                  '-of', 'csv=p=0', str(path)])


def compress_image(path, dry):
    args = ['cwebp', '-quiet', '-q', str(WEBP_QUALITY), '-sharp_yuv', '-m', '6']
    if image_width(path) > MAX_WIDTH:
        args += ['-resize', str(MAX_WIDTH), '0']
    tmp = path.with_suffix('.tmp.webp')
    if dry:
        return None
    subprocess.run(args + [str(path), '-o', str(tmp)], check=True)
    if tmp.stat().st_size >= path.stat().st_size:
        tmp.unlink()  # already smaller than we would make it
        return path.stat().st_size
    tmp.replace(path)
    return path.stat().st_size


def compress_audio(path, dry):
    tmp = path.with_suffix('.tmp.mp3')
    if dry:
        return None
    before = duration(path)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(path), '-ac', '1',
                    '-ar', '44100', '-b:a', f'{AUDIO_KBPS}k', str(tmp)], check=True)
    after = duration(tmp)
    if abs(float(before) - float(after)) > DURATION_TOLERANCE_S:
        tmp.unlink()
        raise SystemExit(f'{path.name}: duration changed {before} -> {after}; '
                         'word cut-offs would drift, aborting')
    if tmp.stat().st_size >= path.stat().st_size:
        tmp.unlink()
        return path.stat().st_size
    tmp.replace(path)
    return path.stat().st_size


def main(argv):
    dry = '--dry-run' in argv
    do_images = '--audio-only' not in argv
    do_audio = '--images-only' not in argv
    img_before = img_after = aud_before = aud_after = 0
    n_img = n_aud = 0
    for d in IMAGE_DIRS if do_images else []:
        for p in sorted(d.glob('*.webp')):
            if p.stem in SKIP_IMAGES:
                continue
            size = p.stat().st_size
            img_before += size
            new = compress_image(p, dry)
            img_after += new if new is not None else size
            n_img += 1
    for d in AUDIO_DIRS if do_audio else []:
        for p in sorted(d.glob('*.mp3')):
            size = p.stat().st_size
            aud_before += size
            if audio_kbps(p) <= AUDIO_KBPS:
                aud_after += size
                continue
            new = compress_audio(p, dry)
            aud_after += new if new is not None else size
            n_aud += 1
    mb = lambda b: f'{b / 1048576:.1f} MB'
    print(f'images: {n_img} files {mb(img_before)} -> {mb(img_after)}'
          + (' (dry run)' if dry else ''))
    print(f'audio:  {n_aud} files {mb(aud_before)} -> {mb(aud_after)}'
          + (' (dry run)' if dry else ''))
    # Sanity: every clip the word-cut table knows about still exists.
    lengths = json.loads((ASSETS / 'data/audio_word_lengths.json').read_text())
    missing = [k for k in lengths
               if not any((d / f'{k}.mp3').exists() for d in AUDIO_DIRS)]
    if missing:
        print(f'warning: {len(missing)} keys in audio_word_lengths.json have no file, e.g. {missing[:5]}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
