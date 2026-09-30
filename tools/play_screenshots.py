#!/usr/bin/env /usr/bin/python3
"""Replace the Google Play listing screenshots with the ones in this repo.

    /usr/bin/python3 tools/play_screenshots.py          # show what would change
    /usr/bin/python3 tools/play_screenshots.py --push   # do it
    ... --push --feature-only                           # the banner alone

Phone: ios/fastlane/screenshots/<locale>/ — the same seven slides as the
App Store. Tablet (7- and 10-inch): ios/fastlane/screenshots_ipad/<locale>/,
real frames from the rig. Feature graphic (1024×500):
android/fastlane/metadata/android/<uk-UA|en-US>/images/featureGraphic.png,
rendered by marketing's PlayFeatureGraphic still.

On 2026-09-30 Play still showed the first-generation set: the old
"TalkCards" name on English screens, "471 voiced cards" on an English
catalogue of 417, and an App Store rating on a Google Play listing — which
Play's metadata policy does not allow in graphics.

Managed publishing is off, so --push commits the edit and the listing goes
to Google's review straight away. The dry run opens an edit only to read
counts and deletes it again.
"""
import sys
from pathlib import Path

from play_upload import BASE, UP, http, token

ROOT = Path(__file__).resolve().parent.parent
# Play language → the repo folder that holds its art.
LANGS = {'uk': 'uk', 'en-US': 'en-US'}
SETS = {
    'phoneScreenshots': ROOT / 'ios/fastlane/screenshots',
    'sevenInchScreenshots': ROOT / 'ios/fastlane/screenshots_ipad',
    'tenInchScreenshots': ROOT / 'ios/fastlane/screenshots_ipad',
}
MAX_PER_TYPE = 8
FEATURE = {'uk': 'uk-UA', 'en-US': 'en-US'}


def files(root, folder):
    def order(p):
        return int(p.stem.split('-')[1])
    found = [p for p in (root / folder).glob('slot-*')
             if p.suffix in ('.png', '.jpg')]
    return sorted(found, key=order)[:MAX_PER_TYPE]


def main(argv):
    push = '--push' in argv
    # Only the banner: the screenshots already on Play stay untouched.
    sets = {} if '--feature-only' in argv else SETS
    call = http(token())
    edit = call('POST', f'{BASE}/edits')['id']
    try:
        for lang, folder in LANGS.items():
            for kind, root in sets.items():
                new = files(root, folder)
                if not new:
                    raise SystemExit(f'{lang} {kind}: nothing in {root / folder}')
                have = call('GET', f'{BASE}/edits/{edit}/listings/{lang}/{kind}'
                            ).get('images', [])
                print(f'{lang} {kind}: {len(have)} on Play -> {len(new)} from the repo')
                if not push:
                    continue
                call('DELETE', f'{BASE}/edits/{edit}/listings/{lang}/{kind}')
                for f in new:
                    ctype = 'image/png' if f.suffix == '.png' else 'image/jpeg'
                    call('POST', f'{UP}/edits/{edit}/listings/{lang}/{kind}'
                         '?uploadType=media', raw=f.read_bytes(), ctype=ctype)
                    print(f'    uploaded {f.relative_to(ROOT)}')
            feature = (ROOT / 'android/fastlane/metadata/android' / FEATURE[lang]
                       / 'images/featureGraphic.png')
            if feature.exists():
                print(f'{lang} featureGraphic: -> {feature.relative_to(ROOT)}')
                if push:
                    call('DELETE', f'{BASE}/edits/{edit}/listings/{lang}/featureGraphic')
                    call('POST', f'{UP}/edits/{edit}/listings/{lang}/featureGraphic'
                         '?uploadType=media', raw=feature.read_bytes(),
                         ctype='image/png')
                    print('    uploaded')
        if push:
            call('POST', f'{BASE}/edits/{edit}:commit')
            edit = None
            print('\nCommitted. Play reviews listing changes before they show.')
        else:
            print('\nDry run. Add --push to replace them.')
    finally:
        if edit:
            call('DELETE', f'{BASE}/edits/{edit}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
