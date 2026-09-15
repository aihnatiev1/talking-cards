#!/usr/bin/env /usr/bin/python3
"""Upload the release AAB to Google Play and put it on every track.

    /usr/bin/python3 tools/play_upload.py 32          # expected versionCode
    /usr/bin/python3 tools/play_upload.py --diff      # repo vs the live listing

All four tracks (internal/alpha/beta/production) get the same versionCode:
Play's "Billing Library" warning keyed on the oldest track, which used to
lag years behind. Release notes come from
android/fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt.

Managed publishing is ON for this app: the commit only queues the release.
After this script, press "Огляд публікації → Надіслати на перевірку" in
Play Console — without it nothing ships (v22/v23 were lost that way).

--diff compares the store listing in this repo against the one Play is
actually serving. The App Store side had drifted — keywords tuned in the
console, never committed, then overwritten by an upload — and nothing had
ever compared the two. This is that check for Play, and it does not open
an edit, so it is safe to run at any time.

Auth: service account ~/.private_keys/play-service-account.json (RS256 JWT).
Needs /usr/bin/python3 (has pyjwt); the Homebrew python does not.
"""
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import jwt

ROOT = Path(__file__).resolve().parent.parent
AAB = ROOT / 'build/app/outputs/bundle/release/app-release.aab'
NOTES = ROOT / 'android/fastlane/metadata/android'
PKG = 'com.talkingcards.app'
BASE = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}'
UP = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}'
TRACKS = ('internal', 'alpha', 'beta', 'production')
# Repo folder → the language code Play actually uses. Fastlane's tree is
# named uk-UA; Play's listing for it is plain `uk`, and it rejects uk-UA
# outright for listings while quietly accepting it for release notes —
# which is how notes can end up stored under a language nobody is served.
LOCALES = ('uk-UA', 'en-US')
PLAY_LANG = {'uk-UA': 'uk', 'en-US': 'en-US'}


def token():
    sa = json.load(open(Path.home() / '.private_keys/play-service-account.json'))
    now = int(time.time())
    assertion = jwt.encode(
        {'iss': sa['client_email'],
         'scope': 'https://www.googleapis.com/auth/androidpublisher',
         'aud': 'https://oauth2.googleapis.com/token',
         'iat': now, 'exp': now + 3600},
        sa['private_key'], algorithm='RS256')
    resp = urllib.request.urlopen(urllib.request.Request(
        'https://oauth2.googleapis.com/token',
        data=urllib.parse.urlencode({
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': assertion}).encode()))
    return json.load(resp)['access_token']


LISTING = {'title': 'title.txt',
           'shortDescription': 'short_description.txt',
           'fullDescription': 'full_description.txt'}


def http(tok):
    def call(method, url, body=None, raw=None, ctype='application/json'):
        data = raw if raw is not None else (
            json.dumps(body).encode() if body is not None else None)
        req = urllib.request.Request(url, method=method, data=data, headers={
            'Authorization': f'Bearer {tok}', 'Content-Type': ctype})
        try:
            d = urllib.request.urlopen(req, timeout=900).read()
            return json.loads(d) if d else {}
        except urllib.error.HTTPError as e:
            raise SystemExit(f'{method} {url} -> {e.code}: {e.read().decode()[:800]}')
    return call


def diff():
    """Every field where this repo and the live Play listing disagree."""
    call = http(token())
    # Listings are only readable inside an edit; this one is never
    # committed, so nothing changes on the store.
    edit = call('POST', f'{BASE}/edits', {})['id']
    differences = 0
    for loc in LOCALES:
        live = call('GET', f'{BASE}/edits/{edit}/listings/{PLAY_LANG[loc]}')
        for field, name in LISTING.items():
            path = NOTES / loc / name
            if not path.exists():
                continue
            mine = path.read_text().strip()
            theirs = (live.get(field) or '').strip()
            if mine == theirs:
                continue
            differences += 1
            print(f'\n  {loc}.{field}')
            a, b = theirs.splitlines(), mine.splitlines()
            for i in range(max(len(a), len(b))):
                x = a[i] if i < len(a) else ''
                y = b[i] if i < len(b) else ''
                if x != y:
                    print(f'    line {i + 1}')
                    print(f'      store: {x[:150] or "(nothing)"}')
                    print(f'      repo : {y[:150] or "(nothing)"}')
                    break
    call('DELETE', f'{BASE}/edits/{edit}')
    print(f'\n{differences} difference(s).' if differences
          else '\nrepo matches the store.')
    return 0


def main(argv):
    if argv and argv[0] == '--diff':
        return diff()
    if len(argv) != 1 or not argv[0].isdigit():
        raise SystemExit(__doc__)
    expected = int(argv[0])
    tok = token()

    call = http(tok)

    notes = []
    for loc in LOCALES:
        text = (NOTES / loc / 'changelogs' / f'{expected}.txt').read_text().strip()
        if len(text) > 500:
            raise SystemExit(f'{loc}/changelogs/{expected}.txt is {len(text)} chars (max 500)')
        notes.append({'language': PLAY_LANG[loc], 'text': text})

    edit = call('POST', f'{BASE}/edits', {})['id']
    print('edit', edit)
    aab = AAB.read_bytes()
    print(f'uploading {len(aab) // 1048576} MB ...')
    bundle = call('POST', f'{UP}/edits/{edit}/bundles?uploadType=media',
                  raw=aab, ctype='application/octet-stream')
    code = bundle['versionCode']
    if code != expected:
        raise SystemExit(f'AAB is versionCode {code}, expected {expected} — rebuild first')
    print('bundle versionCode', code)
    for track in TRACKS:
        r = call('PUT', f'{BASE}/edits/{edit}/tracks/{track}', {
            'track': track,
            'releases': [{'name': f'v{code}', 'versionCodes': [str(code)],
                          'status': 'completed', 'releaseNotes': notes}]})
        print('track', track, '->', [(x['name'], x['status']) for x in r['releases']])
    call('POST', f'{BASE}/edits/{edit}:validate', {})
    print('commit', call('POST', f'{BASE}/edits/{edit}:commit?changesNotSentForReview=false', {}))
    print('\nQueued. Now in Play Console: «Огляд публікації» → «Надіслати на перевірку».')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
