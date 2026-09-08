#!/usr/bin/env /usr/bin/python3
"""Create an App Store version, attach the Xcode Cloud build, submit for review.

    /usr/bin/python3 tools/asc_submit.py 1.3.10            # submit
    /usr/bin/python3 tools/asc_submit.py 1.3.10 --wait     # poll for the build first

Binary-only releases: the new version inherits description/keywords/promo
from the live one; the script refuses to submit if they differ (metadata
changes are a separate, deliberate step — see memory aso-ctr-insight).
What's New comes from ios/fastlane/metadata/<locale>/release_notes.txt.

The build is the newest VALID one whose preReleaseVersion matches the
marketing version — Xcode Cloud numbers builds by its own counter, not by
pubspec's +N. Release type AFTER_APPROVAL, like every release so far.

Auth: ASC API key ~/.private_keys/AuthKey_L47N29CGTL.p8 (ES256 JWT).
Needs /usr/bin/python3 (has pyjwt + cryptography).
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / 'ios/fastlane/metadata'
APP = '6760210043'
KEY_ID = 'L47N29CGTL'
ISSUER = '3d14c11e-b644-4714-8724-ed2636d79f7d'
BASE = 'https://api.appstoreconnect.apple.com'
POLL_S = 120
POLL_MAX = 60  # 2 hours


def token():
    pk = (Path.home() / f'.private_keys/AuthKey_{KEY_ID}.p8').read_text()
    now = int(time.time())
    return jwt.encode({'iss': ISSUER, 'iat': now, 'exp': now + 1100,
                       'aud': 'appstoreconnect-v1'},
                      pk, algorithm='ES256', headers={'kid': KEY_ID})


def call(method, path, body=None):
    req = urllib.request.Request(
        BASE + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': f'Bearer {token()}',
                 'Content-Type': 'application/json'})
    try:
        r = urllib.request.urlopen(req)
        d = r.read()
        return json.loads(d) if d else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f'{method} {path} -> {e.code}: {e.read().decode()[:600]}')


def get(path):
    return call('GET', path)


def find_build(version):
    builds = get(f'/v1/builds?filter[app]={APP}'
                 f'&filter[preReleaseVersion.version]={version}'
                 '&fields[builds]=version,processingState,uploadedDate,expired'
                 '&sort=-uploadedDate&limit=5')['data']
    valid = [b for b in builds
             if b['attributes']['processingState'] == 'VALID'
             and not b['attributes']['expired']]
    return valid[0] if valid else None


def main(argv):
    if not argv:
        raise SystemExit(__doc__)
    version = argv[0]
    wait = '--wait' in argv

    build = find_build(version)
    polls = 0
    while build is None and wait and polls < POLL_MAX:
        polls += 1
        print(f'[{time.strftime("%H:%M")}] no VALID build for {version} yet, '
              f'waiting {POLL_S}s ({polls}/{POLL_MAX})', flush=True)
        time.sleep(POLL_S)
        build = find_build(version)
    if build is None:
        raise SystemExit(f'no VALID build for {version} in App Store Connect')
    print('build', build['attributes']['version'], build['id'])

    versions = get(f'/v1/apps/{APP}/appStoreVersions?limit=3'
                   '&fields[appStoreVersions]=versionString,appVersionState,createdDate')['data']
    existing = next((v for v in versions if v['attributes']['versionString'] == version), None)
    previous = next((v for v in versions if v['attributes']['versionString'] != version), None)
    if existing:
        vid = existing['id']
        print('version exists', vid, existing['attributes']['appVersionState'])
    else:
        vid = call('POST', '/v1/appStoreVersions', {'data': {
            'type': 'appStoreVersions',
            'attributes': {'platform': 'IOS', 'versionString': version,
                           'releaseType': 'AFTER_APPROVAL', 'copyright': '©2026 Skillar'},
            'relationships': {'app': {'data': {'type': 'apps', 'id': APP}}}}})['data']['id']
        print('created version', vid)

    fields = 'locale,whatsNew,description,keywords,promotionalText'
    locs = get(f'/v1/appStoreVersions/{vid}/appStoreVersionLocalizations'
               f'?fields[appStoreVersionLocalizations]={fields}')['data']
    prev = {}
    if previous:
        prev = {l['attributes']['locale']: l['attributes'] for l in get(
            f"/v1/appStoreVersions/{previous['id']}/appStoreVersionLocalizations"
            f'?fields[appStoreVersionLocalizations]={fields}')['data']}
    for l in locs:
        loc = l['attributes']['locale']
        p = prev.get(loc)
        if p:
            for k in ('description', 'keywords', 'promotionalText'):
                if l['attributes'].get(k) != p.get(k):
                    raise SystemExit(f'{loc}.{k} differs from the live version — '
                                     'metadata changed; refusing a binary-only submit')
        notes = (META / loc / 'release_notes.txt').read_text().strip()
        call('PATCH', f"/v1/appStoreVersionLocalizations/{l['id']}", {'data': {
            'type': 'appStoreVersionLocalizations', 'id': l['id'],
            'attributes': {'whatsNew': notes}}})
        print('whatsNew', loc, len(notes))

    call('PATCH', f'/v1/appStoreVersions/{vid}/relationships/build',
         {'data': {'type': 'builds', 'id': build['id']}})
    print('build attached')

    open_subs = get(f'/v1/apps/{APP}/reviewSubmissions?filter[state]='
                    'READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES&limit=5')['data']
    if open_subs:
        raise SystemExit(f'a submission is already open: {[(s["id"], s["attributes"]["state"]) for s in open_subs]}')
    sub = call('POST', '/v1/reviewSubmissions', {'data': {
        'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'},
        'relationships': {'app': {'data': {'type': 'apps', 'id': APP}}}}})['data']['id']
    call('POST', '/v1/reviewSubmissionItems', {'data': {
        'type': 'reviewSubmissionItems',
        'relationships': {
            'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': sub}},
            'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}})
    # The final PATCH is where Apple's transient 500s land (1.3.10 hit one
    # after every other step succeeded). Retrying the same call is safe: the
    # submission is idempotent once it is WAITING_FOR_REVIEW.
    for attempt in range(1, 5):
        try:
            r = call('PATCH', f'/v1/reviewSubmissions/{sub}', {'data': {
                'type': 'reviewSubmissions', 'id': sub,
                'attributes': {'submitted': True}}})
            print('submitted:', r['data']['attributes']['state'])
            return 0
        except SystemExit as e:
            if '-> 5' not in str(e) or attempt == 4:
                raise
            print(f'submit attempt {attempt} got a server error, retrying in 20s')
            time.sleep(20)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
