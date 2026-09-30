#!/usr/bin/env /usr/bin/python3
"""Upload the rendered store screenshots to an App Store version.

    /usr/bin/python3 tools/asc_screenshots.py 1.4.0          # show what would change
    /usr/bin/python3 tools/asc_screenshots.py 1.4.0 --push   # do it

Reads ios/fastlane/screenshots/<locale>/slot-N-*.png and replaces the
6.7-inch set for that locale, in slot order. The three English locales
that have no folder of their own take en-US's, because the alternative is
what the store had: three listings showing a version of the app from
months ago.

--prune also deletes the older 6.5-inch sets, which held screenshots of
an app that no longer looks like that. Apple shows the 6.7-inch art for
that size class once they are gone. iPad sets are left alone: an app that
supports iPad needs them, and these have to be captured, not deleted.

Replacing means deleting what is there first: App Store Connect keeps
screenshots in an ordered set, and uploading into a set that already has
six leaves you with twelve in an order nobody chose.

Auth: the same ASC API key asc_submit.py uses.
"""
import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / 'ios/fastlane/screenshots'
APP = '6760210043'
KEY_ID = 'L47N29CGTL'
ISSUER = '3d14c11e-b644-4714-8724-ed2636d79f7d'
BASE = 'https://api.appstoreconnect.apple.com'
# 1290 × 2796 — iPhone 15/16 Pro Max and the like.
DISPLAY = 'APP_IPHONE_67'
# Locales that show another locale's art.
BORROWS = {'en-GB': 'en-US', 'en-AU': 'en-US', 'en-CA': 'en-US'}
# Sets we clear out with --prune: an older phone class whose screenshots
# are three releases behind.
STALE = ('APP_IPHONE_65',)


def token():
    pk = (Path.home() / f'.private_keys/AuthKey_{KEY_ID}.p8').read_text()
    now = int(time.time())
    return jwt.encode({'iss': ISSUER, 'iat': now, 'exp': now + 1100,
                       'aud': 'appstoreconnect-v1'},
                      pk, algorithm='ES256', headers={'kid': KEY_ID})


def call(method, path, body=None, raw=None, headers=None):
    url = path if path.startswith('http') else BASE + path
    hdrs = {'Authorization': f'Bearer {token()}'}
    if raw is None:
        hdrs['Content-Type'] = 'application/json'
    hdrs.update(headers or {})
    data = raw if raw is not None else (
        json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url, method=method, data=data, headers=hdrs)
    try:
        r = urllib.request.urlopen(req, timeout=300)
        d = r.read()
        return json.loads(d) if d else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f'{method} {url} -> {e.code}: {e.read().decode()[:600]}')


def upload(method, url, chunk, headers):
    req = urllib.request.Request(url, method=method, data=chunk,
                                 headers=headers)
    try:
        urllib.request.urlopen(req, timeout=600).read()
    except urllib.error.HTTPError as e:
        raise SystemExit(f'{method} upload -> {e.code}: {e.read().decode()[:400]}')


def slots(locale):
    folder = SHOTS / BORROWS.get(locale, locale)
    if not folder.is_dir():
        return []
    def order(p):
        m = re.search(r'slot-(\d+)', p.name)
        return int(m.group(1)) if m else 99
    return sorted(folder.glob('slot-*.png'), key=order)


def main(argv):
    if not argv:
        raise SystemExit(__doc__)
    version = argv[0]
    push = '--push' in argv
    prune = '--prune' in argv

    versions = call('GET', f'/v1/apps/{APP}/appStoreVersions?limit=5'
                    '&fields[appStoreVersions]=versionString,appVersionState')['data']
    target = next((v for v in versions
                   if v['attributes']['versionString'] == version), None)
    if target is None:
        raise SystemExit(f'no {version} in App Store Connect')
    print(version, target['attributes']['appVersionState'])

    locs = call('GET', f"/v1/appStoreVersions/{target['id']}"
                '/appStoreVersionLocalizations'
                '?fields[appStoreVersionLocalizations]=locale')['data']

    for loc in locs:
        locale = loc['attributes']['locale']
        files = slots(locale)
        if not files:
            print(f'{locale}: no folder, left alone')
            continue

        sets = call('GET', f"/v1/appStoreVersionLocalizations/{loc['id']}"
                    '/appScreenshotSets'
                    '?fields[appScreenshotSets]=screenshotDisplayType')['data']
        for old_set in sets:
            if old_set['attributes']['screenshotDisplayType'] in STALE:
                print(f"{locale}: stale "
                      f"{old_set['attributes']['screenshotDisplayType']} set")
                if push and prune:
                    call('DELETE', f"/v1/appScreenshotSets/{old_set['id']}")
                    print('    deleted')
        existing = next((s for s in sets
                         if s['attributes']['screenshotDisplayType'] == DISPLAY),
                        None)
        have = []
        if existing:
            have = call('GET', f"/v1/appScreenshotSets/{existing['id']}"
                        '/appScreenshots?fields[appScreenshots]=fileName')['data']
        print(f'{locale}: {len(have)} on the store -> {len(files)} from the repo')
        for f in files:
            print(f'    {f.name}')
        if not push:
            continue

        if existing is None:
            existing = call('POST', '/v1/appScreenshotSets', {'data': {
                'type': 'appScreenshotSets',
                'attributes': {'screenshotDisplayType': DISPLAY},
                'relationships': {'appStoreVersionLocalization': {'data': {
                    'type': 'appStoreVersionLocalizations',
                    'id': loc['id']}}}}})['data']
        for old in have:
            call('DELETE', f"/v1/appScreenshots/{old['id']}")

        for f in files:
            blob = f.read_bytes()
            made = call('POST', '/v1/appScreenshots', {'data': {
                'type': 'appScreenshots',
                'attributes': {'fileSize': len(blob), 'fileName': f.name},
                'relationships': {'appScreenshotSet': {'data': {
                    'type': 'appScreenshotSets', 'id': existing['id']}}}}})['data']
            for op in made['attributes']['uploadOperations']:
                chunk = blob[op['offset']:op['offset'] + op['length']]
                headers = {h['name']: h['value'] for h in op['requestHeaders']}
                # The upload URL is pre-signed and belongs to Apple's asset
                # storage, not to the API: adding our own Authorization
                # header invalidates the signature and it answers 400.
                upload(op['method'], op['url'], chunk, headers)
            call('PATCH', f"/v1/appScreenshots/{made['id']}", {'data': {
                'type': 'appScreenshots', 'id': made['id'],
                'attributes': {'uploaded': True,
                               'sourceFileChecksum': hashlib.md5(blob).hexdigest()}}})
            print(f'    uploaded {f.name}')
    if not push:
        print('\nDry run. Add --push to replace them.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
