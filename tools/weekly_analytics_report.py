#!/usr/bin/env python3
"""Weekly Firebase/GA4 report for Картки-розмовлялки.

Pulls the key funnels from the GA4 Data API (property 528033840), compares
week-over-week, writes a dated markdown report to ~/Desktop and pops a
macOS notification. Run from cron (Mondays) or manually:

    /usr/bin/python3 tools/weekly_analytics_report.py
"""
import gzip
import json
import subprocess
import time
import urllib.parse
import urllib.request
from datetime import date, timedelta
from pathlib import Path

import jwt  # PyJWT — present in /usr/bin/python3 site-packages

PROPERTY = 'properties/528033840'
SA_KEY = Path.home() / '.private_keys/play-service-account.json'
# App Store Connect — only for the review calendar (see release_calendar).
ASC_APP = '6760210043'
ASC_KEY_ID = 'L47N29CGTL'
ASC_ISSUER = '3d14c11e-b644-4714-8724-ed2636d79f7d'
ASC_KEY = Path.home() / f'.private_keys/AuthKey_{ASC_KEY_ID}.p8'
# ~/Desktop is TCC-protected: a scheduled run can be denied it without ever
# showing a prompt, and then the report exists nowhere. Home is not
# protected, so it is the guaranteed landing spot.
OUT = Path.home() / 'Desktop/skillar-weekly-report.md'
OUT_FALLBACK = Path.home() / 'skillar-weekly-report.md'

KEY_EVENTS = [
    'first_open', 'onboarding_start', 'onboarding_age_selected',
    'onboarding_name_entered', 'onboarding_magic_moment_complete',
    'tutorial_complete',
    'app_ready', 'splash_timeout',
    'notif_optin_shown', 'notif_optin_result',
    'card_view', 'card_listen', 'pack_open', 'pack_complete',
    'game_start', 'game_complete',
    'paywall_view', 'paywall_product_select',
    'purchase_start', 'purchase_success', 'purchase_cancel', 'purchase_error',
    'purchase_pending', 'store_unavailable', 'pro_revoked',
    'app_exception', 'app_remove',
]


def token():
    sa = json.load(open(SA_KEY))
    now = int(time.time())
    assertion = jwt.encode(
        {'iss': sa['client_email'],
         'scope': 'https://www.googleapis.com/auth/analytics.readonly',
         'aud': 'https://oauth2.googleapis.com/token',
         'iat': now, 'exp': now + 3600},
        sa['private_key'], algorithm='RS256')
    resp = urllib.request.urlopen(urllib.request.Request(
        'https://oauth2.googleapis.com/token',
        data=urllib.parse.urlencode({
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': assertion}).encode()))
    return json.load(resp)['access_token']


def run_report(tok, body):
    req = urllib.request.Request(
        f'https://analyticsdata.googleapis.com/v1beta/{PROPERTY}:runReport',
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {tok}',
                 'Content-Type': 'application/json'})
    return json.load(urllib.request.urlopen(req))


def event_counts(tok, start, end):
    r = run_report(tok, {
        'dateRanges': [{'startDate': start, 'endDate': end}],
        'dimensions': [{'name': 'eventName'}],
        'metrics': [{'name': 'eventCount'}, {'name': 'totalUsers'}],
        'limit': 100,
    })
    out = {}
    for row in r.get('rows', []):
        name = row['dimensionValues'][0]['value']
        out[name] = (int(row['metricValues'][0]['value']),
                     int(row['metricValues'][1]['value']))
    return out


def users(tok, start, end):
    r = run_report(tok, {
        'dateRanges': [{'startDate': start, 'endDate': end}],
        'metrics': [{'name': 'activeUsers'}, {'name': 'newUsers'}],
    })
    row = (r.get('rows') or [{}])[0].get('metricValues', [{}, {}])
    return (int(row[0].get('value', 0)), int(row[1].get('value', 0)))


EN_COUNTRIES = ['United States', '(not set)', 'Canada',
                'United Kingdom', 'Australia']


def release_calendar():
    """iOS version -> (first submission date, assumed release date).

    App Review opens every build the day it is submitted, from US-registered
    iPhone 16/17 Pro devices, for ~10 seconds — and GA4 counts each of those
    as a new US user. In Aug 2026 that was 25 of 44 US first_opens. Release
    is AFTER_APPROVAL and approval has been <24h, so the release day is taken
    as (last submission for that version) + 1. Real installs on the approval
    day itself are lost to the filter; that is the price of not counting
    reviewers, and it is a day out of seven.

    Empty dict on any failure: the report then runs unfiltered and says so.
    """
    try:
        now = int(time.time())
        tok = jwt.encode(
            {'iss': ASC_ISSUER, 'iat': now, 'exp': now + 1100,
             'aud': 'appstoreconnect-v1'},
            ASC_KEY.read_text(), algorithm='ES256', headers={'kid': ASC_KEY_ID})

        def asc(path):
            return json.load(urllib.request.urlopen(urllib.request.Request(
                'https://api.appstoreconnect.apple.com' + path,
                headers={'Authorization': f'Bearer {tok}'})))

        subs = asc(f'/v1/apps/{ASC_APP}/reviewSubmissions?limit=200'
                   '&filter[platform]=IOS'
                   '&fields[reviewSubmissions]=submittedDate')['data']
        cal = {}
        for sub in subs:
            when = (sub['attributes'].get('submittedDate') or '')[:10]
            if not when:
                continue
            items = asc(f"/v1/reviewSubmissions/{sub['id']}/items"
                        '?include=appStoreVersion'
                        '&fields[appStoreVersions]=versionString')
            for inc in items.get('included', []):
                if inc['type'] != 'appStoreVersions':
                    continue
                ver = inc['attributes']['versionString']
                first, last = cal.get(ver, (when, when))
                cal[ver] = (min(first, when), max(last, when))
        out = {}
        for ver, (first, last) in cal.items():
            release = date.fromisoformat(last) + timedelta(days=1)
            out[ver] = (date.fromisoformat(first), release)
        return out
    except Exception:
        return {}


def version_key(ver):
    return tuple(int(x) if x.isdigit() else 0 for x in ver.split('.'))


class ReviewerFilter:
    """Decides whether an iOS (appVersion, date) cell is a store install.

    Two things are not: a version inside its own review window (submitted..
    released), and a first_open on a version the App Store no longer serves
    — the store only ever hands out the current release, so a Sept 2026
    first_open on 1.0.0 is a scanner or a sideload, not a parent.
    """

    def __init__(self, calendar):
        self.cal = calendar
        self.active = bool(calendar)
        self.in_review = 0
        self.stale = 0

    def live_version_on(self, day):
        live = [v for v, (_, rel) in self.cal.items() if rel <= day]
        return max(live, key=version_key) if live else None

    def is_reviewer(self, ver, day, event=None):
        if not self.active:
            return False
        if ver in self.cal:
            submitted, released = self.cal[ver]
            if submitted <= day <= released:
                self.in_review += 1
                return True
        if event == 'first_open':
            # Versions older than the calendar (pre-API submissions) are
            # exactly the ones scanners open, so this must not need `ver`
            # to be in the calendar.
            live = self.live_version_on(day)
            if live and version_key(ver) < version_key(live):
                self.stale += 1
                return True
        return False

    def drop_rows(self, rows, ver_i, day_i, platform_i, event_i=None):
        """Yield GA4 rows that are not App Review; dimensions by index."""
        for row in rows:
            dims = [d['value'] for d in row['dimensionValues']]
            ev = dims[event_i] if event_i is not None else None
            if dims[platform_i] == 'iOS' and self.is_reviewer(
                    dims[ver_i], ga_day(dims[day_i]), ev):
                continue
            yield row

    def note(self, scope):
        if not self.active:
            return f'- {scope}: календар рев\'ю з ASC недоступний, рев\'юверів НЕ відфільтровано'
        return (f'- {scope}: відкинуто {self.in_review} подій у вікні App Review '
                f'і {self.stale} first_open на застарілих білдах')


def ga_day(s):
    return date(int(s[:4]), int(s[4:6]), int(s[6:8]))


def startup_health(tok, reviewers):
    """English-side cold-start funnel per app version.

    Half of the EN installs before 1.3.6 never rendered onboarding — the
    splash hung on an un-time-boxed init. This table is how we watch that
    stay fixed: `% дійшли` is first_open → onboarding_start.

    Rows are per (version, day, platform) so App Review can be dropped —
    see ReviewerFilter. Users are summed across days, so a parent who
    spreads the funnel over two days is counted twice; with EN volumes of
    a handful a week that is a smaller error than counting reviewers.
    """
    steps = ['first_open', 'onboarding_start',
             'onboarding_magic_moment_start', 'app_ready']
    r = run_report(tok, {
        'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
        'dimensions': [{'name': 'appVersion'}, {'name': 'eventName'},
                       {'name': 'date'}, {'name': 'platform'}],
        'metrics': [{'name': 'totalUsers'}],
        'dimensionFilter': {'andGroup': {'expressions': [
            {'filter': {'fieldName': 'eventName',
                        'inListFilter': {'values': steps}}},
            {'filter': {'fieldName': 'country',
                        'inListFilter': {'values': EN_COUNTRIES}}},
        ]}},
        'limit': 1000,
    })
    per_ver = {}
    for row in reviewers.drop_rows(r.get('rows', []), 0, 2, 3, 1):
        ver, ev = (d['value'] for d in row['dimensionValues'][:2])
        bucket = per_ver.setdefault(ver, {})
        bucket[ev] = bucket.get(ev, 0) + int(row['metricValues'][0]['value'])

    lines = ['', '### Холодний старт, EN-ринки (7 дн, без App Review)',
             '| версія | first_open | онбординг | % дійшли | magic | app_ready |',
             '|---|---|---|---|---|---|']
    for ver in sorted(per_ver):
        v = per_ver[ver]
        fo, ob = v.get('first_open', 0), v.get('onboarding_start', 0)
        pct = f'{ob / fo:.0%}' if fo else '—'
        lines.append(f"| {ver} | {fo} | {ob} | {pct} | "
                     f"{v.get('onboarding_magic_moment_start', 0)} | "
                     f"{v.get('app_ready', 0)} |")
    lines.append(reviewers.note('EN-воронка'))

    # Which init blew its budget — needs the `service` custom dimension
    # (registered 2026-08-22; no backfill before that date).
    t = run_report(tok, {
        'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
        'dimensions': [{'name': 'customEvent:service'}],
        'metrics': [{'name': 'eventCount'}],
        'dimensionFilter': {'filter': {
            'fieldName': 'eventName',
            'stringFilter': {'value': 'splash_timeout'}}},
        'limit': 20,
    })
    rows = t.get('rows', [])
    if rows:
        lines.append('')
        lines.append('- splash_timeout за сервісом: ' + ', '.join(
            f"{row['dimensionValues'][0]['value']} ×{row['metricValues'][0]['value']}"
            for row in rows))
    return lines


def trial_funnel(tok, reviewers):
    """Checkouts split by what the paywall promised.

    Both stores grant the introductory offer once per subscription group, so
    a returning parent can be shown "3 days free" and then asked for the full
    price by the native sheet. `trial` (registered 2026-09-06, no backfill)
    says which of the two a checkout was, and this table is how we find out
    whether the cancels are price resistance or a broken promise.
    """
    events = ['paywall_view', 'purchase_start',
              'purchase_cancel', 'purchase_success']
    try:
        r = run_report(tok, {
            'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
            'dimensions': [{'name': 'customEvent:trial'}, {'name': 'eventName'},
                           {'name': 'appVersion'}, {'name': 'date'},
                           {'name': 'platform'}],
            'metrics': [{'name': 'eventCount'}],
            'dimensionFilter': {'filter': {
                'fieldName': 'eventName',
                'inListFilter': {'values': events}}},
            'limit': 1000,
        })
    except Exception:
        return ['- Тріал-воронка: запит не вдався (дименшн `trial` не зареєстровано?)']
    per_state = {}
    # The version under review shows up here first — App Review walks the
    # paywall on submission day — so reviewers are dropped before summing.
    for row in reviewers.drop_rows(r.get('rows', []), 2, 3, 4):
        state = row['dimensionValues'][0]['value']
        ev = row['dimensionValues'][1]['value']
        bucket = per_state.setdefault(state, {})
        bucket[ev] = bucket.get(ev, 0) + int(row['metricValues'][0]['value'])
    # (not set) is every event from a build older than the dimension; GA4
    # reports the same thing as '' for today's still-intraday rows.
    per_state.pop('(not set)', None)
    per_state.pop('', None)
    if not per_state:
        return ['- Тріал-воронка: чекаємо на білд із параметром `trial`']
    lines = ['', '### Воронка за обіцянкою тріалу (7 дн)',
             '| trial | пейвол | старти | скасувань | покупок |', '|---|---|---|---|---|']
    for state in sorted(per_state):
        v = per_state[state]
        lines.append(f"| {state} | {v.get('paywall_view', 0)} | "
                     f"{v.get('purchase_start', 0)} | "
                     f"{v.get('purchase_cancel', 0)} | "
                     f"{v.get('purchase_success', 0)} |")
    return lines


def default_plan_ab(tok, reviewers):
    """Paywall A/B: which plan tile starts selected (user property, set on
    every paywall open from Remote Config `paywall_default_plan`).

    Users are summed over (version, day) so App Review can be dropped; a
    parent active on two days counts twice. Small at current volumes."""
    events = ['paywall_view', 'purchase_start', 'purchase_cancel', 'purchase_success']
    try:
        r = run_report(tok, {
            'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
            'dimensions': [{'name': 'customUser:paywall_default_plan'},
                           {'name': 'eventName'}, {'name': 'appVersion'},
                           {'name': 'date'}, {'name': 'platform'}],
            'metrics': [{'name': 'totalUsers'}],
            'dimensionFilter': {'filter': {
                'fieldName': 'eventName', 'inListFilter': {'values': events}}},
            'limit': 1000,
        })
    except Exception:
        return ['- A/B дефолтного плану: запит не вдався (дименшн не зареєстровано?)']
    per = {}
    for row in reviewers.drop_rows(r.get('rows', []), 2, 3, 4):
        b = row['dimensionValues'][0]['value']
        if b in ('(not set)', ''):
            continue
        ev = row['dimensionValues'][1]['value']
        bucket = per.setdefault(b, {})
        bucket[ev] = bucket.get(ev, 0) + int(row['metricValues'][0]['value'])
    if not per:
        return ['- A/B дефолтного плану: ще без даних']
    lines = ['', '### A/B: який план обраний за замовчуванням (7 дн, users)',
             '| bucket | пейвол | старти | скасувань | покупок |', '|---|---|---|---|---|']
    for b in sorted(per):
        v = per[b]
        lines.append(f"| {b} | {v.get('paywall_view', 0)} | {v.get('purchase_start', 0)} | "
                     f"{v.get('purchase_cancel', 0)} | {v.get('purchase_success', 0)} |")
    return lines


def asc_token():
    now = int(time.time())
    return jwt.encode(
        {'iss': ASC_ISSUER, 'iat': now, 'exp': now + 1100,
         'aud': 'appstoreconnect-v1'},
        ASC_KEY.read_text(), algorithm='ES256', headers={'kid': ASC_KEY_ID})


def asc_get(tok, path):
    return json.load(urllib.request.urlopen(urllib.request.Request(
        'https://api.appstoreconnect.apple.com' + path,
        headers={'Authorization': f'Bearer {tok}'})))


def asc_report_rows(tok, name, days):
    """Deduplicated rows of an ONGOING analytics report for the last N
    event days. The Standard reports repeat a row per extra dimension
    (device, source type…), so rows are keyed on the dimensions that make a
    row unique for our purposes and counted once."""
    reqs = asc_get(tok, f'/v1/apps/{ASC_APP}/analyticsReportRequests'
                        '?filter[accessType]=ONGOING')['data']
    if not reqs:
        return []
    reports = asc_get(tok, f"/v1/analyticsReportRequests/{reqs[0]['id']}/reports"
                           '?filter[category]=COMMERCE&limit=50')['data']
    report = next((r for r in reports if r['attributes']['name'] == name), None)
    if report is None:
        return []
    inst = asc_get(tok, f"/v1/analyticsReports/{report['id']}/instances"
                        '?filter[granularity]=DAILY&limit=200')['data']
    inst = sorted(inst, key=lambda i: i['attributes']['processingDate'])[-(days + 2):]
    since = (date.today() - timedelta(days=days)).isoformat()
    rows, seen = [], set()
    for i in inst:
        for seg in asc_get(tok, f"/v1/analyticsReportInstances/{i['id']}/segments")['data']:
            raw = urllib.request.urlopen(seg['attributes']['url']).read()
            lines = gzip.decompress(raw).decode().strip().split('\n')
            hdr = lines[0].split('\t')
            for ln in lines[1:]:
                row = dict(zip(hdr, ln.split('\t')))
                day = row.get('Date') or row.get('Event Date') or ''
                if day < since:
                    continue
                key = (day, row.get('Event Name'), row.get('Subscription Name'),
                       row.get('Content Name'), row.get('Territory'),
                       row.get('Sales in USD'), row.get('Offer Type'))
                if key in seen:
                    continue
                seen.add(key)
                rows.append(row)
    return rows


def money(days=7):
    """Real money, from App Store Connect rather than GA4: GA4's
    purchase_success is a trial *start* and worth $0 until day three.
    Subscription events give trial starts / conversions / churn; the
    purchases report gives sales and proceeds in USD."""
    try:
        tok = asc_token()
        events = asc_report_rows(tok, 'App Store Subscription Event Report Standard', days)
        buys = asc_report_rows(tok, 'App Store Purchases Standard', days)
    except Exception as e:
        return [f'- Гроші (ASC): звіт недоступний ({type(e).__name__})']
    counts = {}
    for r in events:
        counts[r.get('Event Name', '?')] = counts.get(r.get('Event Name', '?'), 0) + int(r.get('Counts', 0) or 0)
    sales = sum(float(r.get('Sales in USD', 0) or 0) for r in buys)
    proceeds = sum(float(r.get('Proceeds in USD', 0) or 0) for r in buys)
    paid = [r for r in buys if float(r.get('Sales in USD', 0) or 0) > 0]
    lines = ['', f'### Гроші за {days} дн (App Store Connect, iOS)',
             f'- Sales **${sales:.2f}**, proceeds **${proceeds:.2f}**, платних транзакцій {len(paid)}']
    if paid:
        lines.append('- ' + ', '.join(
            f"{r.get('Date')} {r.get('Territory')} {r.get('Content Name')} ${float(r.get('Sales in USD', 0)):.2f}"
            for r in sorted(paid, key=lambda r: r.get('Date', ''))))
    wanted = [('Free trial start activation', 'тріалів почато'),
              ('Full price from free trial', 'тріалів → оплата'),
              ('Voluntary churn from free trial', 'тріалів → відмова'),
              ('Renew', 'продовжень'), ('Refund', 'рефандів')]
    parts = [f'{label} {counts[k]}' for k, label in wanted if counts.get(k)]
    lines.append('- Підписки: ' + (', '.join(parts) if parts else 'подій немає'))
    return lines


def paywall_doors(tok, reviewers):
    """paywall_view → purchase_start → purchase_success by entry point
    (`source`: locked_tile, preview_end, games_lock, coloring_gate, reminder,
    paywall_onboarding). Which door converts and which only collects
    cancels — the question behind the preview-first switch (Remote Config
    `locked_pack_tap`, 1.3.11)."""
    r = run_report(tok, {
        'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
        'dimensions': [{'name': 'customEvent:source'}, {'name': 'appVersion'},
                       {'name': 'date'}, {'name': 'platform'}],
        'metrics': [{'name': 'totalUsers'}],
        'dimensionFilter': {'filter': {'fieldName': 'eventName',
                                       'stringFilter': {'value': 'paywall_view'}}},
        'limit': 1000,
    })
    per = {}
    for row in reviewers.drop_rows(r.get('rows', []), 1, 2, 3):
        src = row['dimensionValues'][0]['value']
        if src in ('(not set)', ''):
            continue
        per[src] = per.get(src, 0) + int(row['metricValues'][0]['value'])
    if not per:
        return []
    lines = ['', '### Пейвол за входом (7 дн, users)',
             '| source | users |', '|---|---|']
    for src, n in sorted(per.items(), key=lambda kv: -kv[1]):
        lines.append(f'| {src} | {n} |')
    return lines


def content_pack(tok, reviewers):
    """Play Asset Delivery health (Android only, from 1.3.11): how often a
    paid pack was opened before its content arrived, and how the pack's
    download ended. Silence here after the rollout is the good outcome."""
    r = run_report(tok, {
        'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
        'dimensions': [{'name': 'eventName'}, {'name': 'customEvent:status'},
                       {'name': 'appVersion'}, {'name': 'date'}, {'name': 'platform'}],
        'metrics': [{'name': 'totalUsers'}],
        'dimensionFilter': {'filter': {'fieldName': 'eventName',
                                       'inListFilter': {'values': ['content_pack', 'content_wait']}}},
        'limit': 1000,
    })
    per = {}
    for row in reviewers.drop_rows(r.get('rows', []), 2, 3, 4):
        ev, status = (d['value'] for d in row['dimensionValues'][:2])
        per[(ev, status)] = per.get((ev, status), 0) + int(row['metricValues'][0]['value'])
    if not per:
        return []
    lines = ['', '### Asset pack (Android, 7 дн, users)']
    for (ev, status), n in sorted(per.items()):
        lines.append(f'- {ev} / {status}: {n}')
    return lines


def crash_summary(tok):
    """Top Crashlytics issues for the last 7 days from the BigQuery export.

    Returns a list of markdown lines; empty-safe while the first daily
    export hasn't landed yet.
    """
    sql = '''
        SELECT issue_title, COUNT(*) AS events,
               COUNT(DISTINCT installation_uuid) AS users,
               COUNTIF(is_fatal) AS fatal
        FROM `smartapp-b109a.firebase_crashlytics.*`
        WHERE event_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
        GROUP BY issue_title ORDER BY events DESC LIMIT 10
    '''
    req = urllib.request.Request(
        'https://bigquery.googleapis.com/bigquery/v2/projects/smartapp-b109a/queries',
        data=json.dumps({'query': sql, 'useLegacySql': False,
                         'timeoutMs': 30000}).encode(),
        headers={'Authorization': f'Bearer {tok}',
                 'Content-Type': 'application/json'})
    try:
        d = json.load(urllib.request.urlopen(req))
    except Exception as e:
        return [f'- Crashlytics: експорт ще без даних ({type(e).__name__})']
    rows = d.get('rows') or []
    if not rows:
        return ['- Crashlytics: за тиждень крашів немає 🎉']
    lines = ['', '### Топ крашів (7 дн)',
             '| Проблема | подій | users | fatal |', '|---|---|---|---|']
    for r in rows:
        f = [c.get('v') for c in r['f']]
        lines.append(f'| {f[0][:70]} | {f[1]} | {f[2]} | {f[3]} |')
    return lines


def bq_token():
    sa = json.load(open(SA_KEY))
    now = int(time.time())
    assertion = jwt.encode(
        {'iss': sa['client_email'],
         'scope': 'https://www.googleapis.com/auth/bigquery.readonly',
         'aud': 'https://oauth2.googleapis.com/token',
         'iat': now, 'exp': now + 3600},
        sa['private_key'], algorithm='RS256')
    resp = urllib.request.urlopen(urllib.request.Request(
        'https://oauth2.googleapis.com/token',
        data=urllib.parse.urlencode({
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': assertion}).encode()))
    return json.load(resp)['access_token']


def reviewer_first_opens(tok, reviewers):
    """How many of this week's iOS first_opens, app-wide, were App Review
    or stale-build scanners. The headline table above is unfiltered; this
    line says how much of its `first_open` to discount."""
    if not reviewers.active:
        return 0
    r = run_report(tok, {
        'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
        'dimensions': [{'name': 'appVersion'}, {'name': 'date'}],
        'metrics': [{'name': 'eventCount'}],
        'dimensionFilter': {'andGroup': {'expressions': [
            {'filter': {'fieldName': 'eventName',
                        'stringFilter': {'value': 'first_open'}}},
            {'filter': {'fieldName': 'platform',
                        'stringFilter': {'value': 'iOS'}}},
        ]}},
        'limit': 1000,
    })
    probe = ReviewerFilter(reviewers.cal)
    return sum(int(row['metricValues'][0]['value'])
               for row in r.get('rows', [])
               if probe.is_reviewer(row['dimensionValues'][0]['value'],
                                    ga_day(row['dimensionValues'][1]['value']),
                                    'first_open'))


def fmt_delta(cur, prev):
    if prev == 0:
        return 'new' if cur else '—'
    d = (cur - prev) / prev * 100
    return f'{d:+.0f}%'


def main():
    tok = token()
    cur = event_counts(tok, '7daysAgo', 'today')
    prev = event_counts(tok, '14daysAgo', '8daysAgo')
    au, nu = users(tok, '7daysAgo', 'today')
    pau, pnu = users(tok, '14daysAgo', '8daysAgo')

    lines = [
        f'\n\n## Тиждень до {date.today().isoformat()}',
        f'- Активні: **{au}** ({fmt_delta(au, pau)}), нові: **{nu}** ({fmt_delta(nu, pnu)})',
        '',
        '| Подія | 7 дн | Δ тиждень | користувачів |',
        '|---|---|---|---|',
    ]
    for ev in KEY_EVENTS:
        c, u = cur.get(ev, (0, 0))
        p, _ = prev.get(ev, (0, 0))
        lines.append(f'| {ev} | {c} | {fmt_delta(c, p)} | {u} |')

    reviewers = ReviewerFilter(release_calendar())
    fake = reviewer_first_opens(tok, reviewers)
    lines.append('')
    if reviewers.active:
        lines.append(f'- З first_open вище {fake} — App Review або застарілі '
                     f'білди (iOS), справжніх інсталів ≈ {cur.get("first_open", (0, 0))[0] - fake}')
    else:
        lines.append(reviewers.note('first_open'))

    # Health ratios worth watching every week.
    cv, _ = cur.get('card_view', (0, 0))
    cl, _ = cur.get('card_listen', (0, 0))
    pw = cur.get('paywall_view', (0, 0))[1]
    ps = cur.get('purchase_success', (0, 0))[1]
    if cv:
        lines.append(f'- Прослуховування/перегляди: {cl}/{cv} ({cl / cv:.0%})')
    if pw:
        lines.append(f'- Конверсія paywall→покупка: {ps}/{pw} ({ps / pw:.0%})')

    lines.extend(startup_health(tok, reviewers))
    lines.extend(trial_funnel(tok, reviewers))
    lines.extend(paywall_doors(tok, reviewers))
    lines.extend(default_plan_ab(tok, reviewers))
    lines.extend(money())
    lines.extend(content_pack(tok, reviewers))
    lines.extend(crash_summary(bq_token()))

    body = '\n'.join(lines) + '\n'
    out = OUT
    try:
        out.parent.mkdir(exist_ok=True)
        with open(out, 'a') as f:
            f.write(('# Skillar — щотижнева аналітика\n'
                     if not out.exists() else '') + body)
    except OSError:
        out = OUT_FALLBACK
        with open(out, 'a') as f:
            f.write(('# Skillar — щотижнева аналітика\n'
                     if not out.exists() else '') + body)

    subprocess.run(['osascript', '-e',
                    f'display notification "Звіт: {out}" '
                    'with title "Skillar analytics"'], check=False)
    print(f'written: {out}')


if __name__ == '__main__':
    main()
