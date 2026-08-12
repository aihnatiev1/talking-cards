#!/usr/bin/env python3
"""One-shot migration: add a "category" field to every pack in the cards
JSONs, mirroring the (now removed) packCategoriesUk/En maps from
lib/utils/pack_categories.dart.

Category ids: speech | sounds | world
Idempotent — re-running produces the same output.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Exact transcription of the legacy Dart maps (uk labels Мовлення/Звуки/Світ,
# en labels Speaking/Sounds/World) onto stable category ids.
CATEGORIES = {
    # uk — speech
    'rozmovlyalky': 'speech', 'phrases': 'speech', 'actions': 'speech',
    'opposites': 'speech', 'adjectives': 'speech', 'poems': 'speech',
    # uk — sounds
    'sound_r': 'sounds', 'sound_l': 'sounds', 'sound_sh': 'sounds',
    'sound_s': 'sounds', 'sound_z': 'sounds', 'sound_zh': 'sounds',
    'sound_ch': 'sounds', 'sound_shch': 'sounds', 'sound_ts': 'sounds',
    # uk — world
    'animals': 'world', 'transport': 'world', 'home': 'world',
    'food': 'world', 'body': 'world', 'emotions': 'world', 'colors': 'world',
    # en — speech
    'en_phrases': 'speech', 'en_actions': 'speech', 'en_opposites': 'speech',
    'en_adjectives': 'speech',
    # en — sounds
    'en_sound_r': 'sounds', 'en_sound_l': 'sounds', 'en_sound_s': 'sounds',
    'en_sound_z': 'sounds', 'en_sound_sh': 'sounds', 'en_sound_zh': 'sounds',
    'en_sound_ch': 'sounds', 'en_sound_th': 'sounds', 'en_sound_w': 'sounds',
    'en_sound_bl': 'sounds',
    # en — world
    'en_animals': 'world', 'en_transport': 'world', 'en_home': 'world',
    'en_food': 'world', 'en_body': 'world', 'en_emotions': 'world',
    'en_colors': 'world',
}


def inject(path: Path) -> None:
    packs = json.loads(path.read_text(encoding='utf-8'))
    for pack in packs:
        category = CATEGORIES.get(pack['id'])
        if category is None:
            raise SystemExit(f"{path.name}: pack '{pack['id']}' has no category")
        # Insert right after "id" for readable diffs.
        rebuilt = {}
        for key, value in pack.items():
            if key == 'category':
                continue
            rebuilt[key] = value
            if key == 'id':
                rebuilt['category'] = category
        pack.clear()
        pack.update(rebuilt)
    path.write_text(
        json.dumps(packs, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8',
    )
    print(f'{path.name}: {len(packs)} packs updated')


if __name__ == '__main__':
    inject(ROOT / 'assets' / 'data' / 'uk_cards.json')
    inject(ROOT / 'assets' / 'data' / 'en_cards.json')
