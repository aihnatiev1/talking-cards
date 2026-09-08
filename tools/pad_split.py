#!/usr/bin/env python3
"""Move paid-pack illustrations and voice clips into the Play Asset Delivery
fast-follow pack.

    python3 tools/pad_split.py            # move (git mv), print sizes
    python3 tools/pad_split.py --dry-run  # only print what would move
    python3 tools/pad_split.py --check    # exit 1 if any file is misplaced

Everything a first session can touch must stay in the base module, because
the fast-follow pack lands *after* install and a toddler's first minute
cannot wait for it:

  * cards of every pack the JSON ships unlocked (uk, en, seasonal),
  * the free preview (first `freePreviewCount`, default 5) of every locked
    pack — a free user opens those as a teaser without owning the pack,
  * pack covers and any illustration no card references (UI art),
  * praise_/instr_ clips, splash — small and needed from the first tap.

Everything else — cards behind the paywall — goes to assets/pad_content/,
which mirrors the base layout (images/webp, audio_mp3). On iOS and in
debug/APK builds pad_content is still bundled; only the Android app bundle
strips it (see android/app/build.gradle.kts) and ships it as the
`content_pack` asset pack (android/content_pack).

Audio filenames resolve the same way AudioService does: a card's `audio`
(or its `image` when `audio` is absent) is looked up in the Cyrillic alias
map in audio_service.dart, falling back to the key itself.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'assets'
BASE_IMG = ASSETS / 'images/webp'
BASE_AUD = ASSETS / 'audio_mp3'
PAD = ASSETS / 'pad_content'
PAD_IMG = PAD / 'images/webp'
PAD_AUD = PAD / 'audio_mp3'
CARD_JSON = ['uk_cards.json', 'en_cards.json', 'seasonal_packs.json']
BASE_AUDIO_PREFIXES = ('praise_', 'instr_')
# Mirrors PackModel.freePreviewCount.
FREE_PREVIEW_COUNT = 5


def audio_alias_map():
    src = (ROOT / 'lib/services/audio_service.dart').read_text()
    body = src[src.index('const _audioMap = {'):]
    body = body[:body.index('\n};')]
    return dict(re.findall(r"'([^']+)':\s*'([^']+)'", body))


def classify():
    """Returns (base_images, base_audio, pad_images, pad_audio) as name sets."""
    aliases = audio_alias_map()
    free_img, free_aud, all_img, all_aud, covers = set(), set(), set(), set(), set()
    for name in CARD_JSON:
        for pack in json.loads((ASSETS / 'data' / name).read_text()):
            locked = pack.get('isLocked', False)
            preview = pack.get('freePreviewCount', FREE_PREVIEW_COUNT)
            cover = (pack.get('cover') or '').strip()
            if cover:
                covers.add(cover)
            for i, card in enumerate(pack['cards']):
                free = not locked or i < preview
                img = card.get('image')
                key = (card.get('audio') or '').strip() or img
                aud = aliases.get(key, key) if key else None
                if img:
                    all_img.add(img)
                    if free:
                        free_img.add(img)
                if aud:
                    all_aud.add(aud)
                    if free:
                        free_aud.add(aud)

    disk_img = {p.stem for p in BASE_IMG.glob('*.webp')} | {p.stem for p in PAD_IMG.glob('*.webp')}
    disk_aud = {p.stem for p in BASE_AUD.glob('*.mp3')} | {p.stem for p in PAD_AUD.glob('*.mp3')}

    pad_img = {n for n in disk_img
               if n in all_img and n not in free_img and n not in covers}
    pad_aud = {n for n in disk_aud
               if n in all_aud and n not in free_aud
               and not n.startswith(BASE_AUDIO_PREFIXES)}
    return disk_img - pad_img, disk_aud - pad_aud, pad_img, pad_aud


def size_mb(paths):
    return sum(p.stat().st_size for p in paths if p.exists()) / 1048576


def plan_moves(base_img, base_aud, pad_img, pad_aud):
    moves = []
    for n in sorted(pad_img):
        if (BASE_IMG / f'{n}.webp').exists():
            moves.append((BASE_IMG / f'{n}.webp', PAD_IMG / f'{n}.webp'))
    for n in sorted(pad_aud):
        if (BASE_AUD / f'{n}.mp3').exists():
            moves.append((BASE_AUD / f'{n}.mp3', PAD_AUD / f'{n}.mp3'))
    # Anything that stopped being paid content comes back to base.
    for n in sorted(base_img):
        if (PAD_IMG / f'{n}.webp').exists():
            moves.append((PAD_IMG / f'{n}.webp', BASE_IMG / f'{n}.webp'))
    for n in sorted(base_aud):
        if (PAD_AUD / f'{n}.mp3').exists():
            moves.append((PAD_AUD / f'{n}.mp3', BASE_AUD / f'{n}.mp3'))
    return moves


def main(argv):
    dry = '--dry-run' in argv
    check = '--check' in argv
    base_img, base_aud, pad_img, pad_aud = classify()
    moves = plan_moves(base_img, base_aud, pad_img, pad_aud)

    print(f'base: {len(base_img)} images {size_mb(BASE_IMG / f"{n}.webp" for n in base_img):.1f} MB, '
          f'{len(base_aud)} clips {size_mb(BASE_AUD / f"{n}.mp3" for n in base_aud):.1f} MB')
    print(f'pack: {len(pad_img)} images, {len(pad_aud)} clips')
    print(f'{len(moves)} files to move')
    if check:
        return 1 if moves else 0
    if dry:
        for src, dst in moves[:20]:
            print(' ', src.relative_to(ROOT), '->', dst.relative_to(ROOT))
        return 0

    PAD_IMG.mkdir(parents=True, exist_ok=True)
    PAD_AUD.mkdir(parents=True, exist_ok=True)
    marker = PAD / 'marker.txt'
    if not marker.exists():
        # AssetPackService loads this file to learn whether pad_content is
        # inside the running build or has to come from the asset pack.
        marker.write_text('pad_content is bundled in this build\n')
    for src, dst in moves:
        subprocess.run(['git', 'mv', str(src), str(dst)], check=True, cwd=ROOT)
    print(f'moved {len(moves)} files; pack now '
          f'{size_mb(PAD_IMG.glob("*.webp")) + size_mb(PAD_AUD.glob("*.mp3")):.1f} MB')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
