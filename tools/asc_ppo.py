#!/usr/bin/env /usr/bin/python3
"""Prepare an App Store product page optimization (PPO) test as a draft.

    /usr/bin/python3 tools/asc_ppo.py            # show what would be made
    /usr/bin/python3 tools/asc_ppo.py --push     # make the draft

Control is whatever the live version shows. The treatment is the set in
ios/fastlane/screenshots (the seven slides of the 1.4.3 refresh), which was
prepared but never uploaded: on 2026-09-30 the store still showed the older
six slides. Whether to ship the new set is the open question, so the test
asks exactly that. The first-slide headline variant ("через гру / Through
Play", docs/ui-aso-direction-2026-09-22.md) is the test after this one —
against the winner, one change at a time.

This only prepares. It never submits the treatment for review and never
starts the experiment: both are the owner's call, made in App Store
Connect (Product Page Optimization) or with a separate, explicit step.
Re-running reuses an experiment of the same name instead of making a
second one, and refuses to touch one that is no longer a draft.
"""
import hashlib
import sys

from asc_screenshots import APP, DISPLAY, ROOT, call, slots, upload

NAME = 'New 7-slide set vs live'
TREATMENT_NAME = '1.4.3 refresh, 7 slides'
TRAFFIC = 50  # percent of product-page visitors who take part
LOCALES = ('uk', 'en-US', 'en-GB', 'en-AU', 'en-CA')


def treatment_files(locale):
    files = slots(locale)
    if not files:
        raise SystemExit(f'{locale}: no slides in the repo')
    return files


def upload_set(set_id, files):
    for f in files:
        blob = f.read_bytes()
        made = call('POST', '/v1/appScreenshots', {'data': {
            'type': 'appScreenshots',
            'attributes': {'fileSize': len(blob), 'fileName': f.name},
            'relationships': {'appScreenshotSet': {'data': {
                'type': 'appScreenshotSets', 'id': set_id}}}}})['data']
        for op in made['attributes']['uploadOperations']:
            chunk = blob[op['offset']:op['offset'] + op['length']]
            headers = {h['name']: h['value'] for h in op['requestHeaders']}
            upload(op['method'], op['url'], chunk, headers)
        call('PATCH', f"/v1/appScreenshots/{made['id']}", {'data': {
            'type': 'appScreenshots', 'id': made['id'],
            'attributes': {'uploaded': True,
                           'sourceFileChecksum': hashlib.md5(blob).hexdigest()}}})
        print(f'    uploaded {f.relative_to(ROOT)}')


def main(argv):
    push = '--push' in argv
    plan = {loc: treatment_files(loc) for loc in LOCALES}
    for loc, files in plan.items():
        print(f'{loc}:')
        for f in files:
            print(f'    {f.relative_to(ROOT)}')

    found = call('GET', f'/v1/apps/{APP}/appStoreVersionExperimentsV2'
                 '?fields[appStoreVersionExperiments]=name,state')['data']
    exp = next((e for e in found if e['attributes']['name'] == NAME), None)
    if exp and exp['attributes']['state'] != 'PREPARE_FOR_SUBMISSION':
        raise SystemExit(f"'{NAME}' is {exp['attributes']['state']}; left alone")
    if not push:
        print(f"\n{'Reuses' if exp else 'Creates'} draft '{NAME}', "
              f'{TRAFFIC}% of traffic. Dry run; add --push.')
        return 0

    if exp is None:
        exp = call('POST', '/v2/appStoreVersionExperiments', {'data': {
            'type': 'appStoreVersionExperiments',
            'attributes': {'name': NAME, 'platform': 'IOS',
                           'trafficProportion': TRAFFIC},
            'relationships': {'app': {'data': {'type': 'apps', 'id': APP}}}}})['data']
        print(f"experiment {exp['id']} created")

    treatments = call('GET', f"/v2/appStoreVersionExperiments/{exp['id']}"
                      '/appStoreVersionExperimentTreatments')['data']
    treat = next((t for t in treatments
                  if t['attributes']['name'] == TREATMENT_NAME), None)
    if treat is None:
        treat = call('POST', '/v1/appStoreVersionExperimentTreatments', {'data': {
            'type': 'appStoreVersionExperimentTreatments',
            'attributes': {'name': TREATMENT_NAME},
            'relationships': {'appStoreVersionExperimentV2': {'data': {
                'type': 'appStoreVersionExperiments', 'id': exp['id']}}}}})['data']
        print(f"treatment {treat['id']} created")

    locs = call('GET', f"/v1/appStoreVersionExperimentTreatments/{treat['id']}"
                '/appStoreVersionExperimentTreatmentLocalizations')['data']
    by_locale = {l['attributes']['locale']: l for l in locs}
    for loc, files in plan.items():
        tl = by_locale.get(loc) or call(
            'POST', '/v1/appStoreVersionExperimentTreatmentLocalizations', {'data': {
                'type': 'appStoreVersionExperimentTreatmentLocalizations',
                'attributes': {'locale': loc},
                'relationships': {'appStoreVersionExperimentTreatment': {'data': {
                    'type': 'appStoreVersionExperimentTreatments',
                    'id': treat['id']}}}}})['data']
        sets = call('GET', '/v1/appStoreVersionExperimentTreatmentLocalizations/'
                    f"{tl['id']}/appScreenshotSets")['data']
        shot_set = next((s for s in sets
                         if s['attributes']['screenshotDisplayType'] == DISPLAY), None)
        if shot_set is None:
            shot_set = call('POST', '/v1/appScreenshotSets', {'data': {
                'type': 'appScreenshotSets',
                'attributes': {'screenshotDisplayType': DISPLAY},
                'relationships': {'appStoreVersionExperimentTreatmentLocalization': {
                    'data': {'type': 'appStoreVersionExperimentTreatmentLocalizations',
                             'id': tl['id']}}}}})['data']
        for old in call('GET', f"/v1/appScreenshotSets/{shot_set['id']}"
                        '/appScreenshots')['data']:
            call('DELETE', f"/v1/appScreenshots/{old['id']}")
        print(f'{loc}:')
        upload_set(shot_set['id'], files)

    print(f"\nDraft ready: experiment {exp['id']}. Not submitted, not started.")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
