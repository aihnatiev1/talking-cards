#!/usr/bin/env python3
"""Weekly Firebase/GA4 report for Картки-розмовлялки.

Pulls the key funnels from the GA4 Data API (property 528033840), compares
week-over-week, writes a dated markdown report to ~/Desktop and pops a
macOS notification. Run from cron (Mondays) or manually:

    /usr/bin/python3 tools/weekly_analytics_report.py
"""
import json
import subprocess
import time
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

import jwt  # PyJWT — present in /usr/bin/python3 site-packages

PROPERTY = 'properties/528033840'
SA_KEY = Path.home() / '.private_keys/play-service-account.json'
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


def startup_health(tok):
    """English-side cold-start funnel per app version.

    Half of the EN installs before 1.3.6 never rendered onboarding — the
    splash hung on an un-time-boxed init. This table is how we watch that
    stay fixed: `% дійшли` is first_open → onboarding_start.
    """
    steps = ['first_open', 'onboarding_start',
             'onboarding_magic_moment_start', 'app_ready']
    r = run_report(tok, {
        'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
        'dimensions': [{'name': 'appVersion'}, {'name': 'eventName'}],
        'metrics': [{'name': 'totalUsers'}],
        'dimensionFilter': {'andGroup': {'expressions': [
            {'filter': {'fieldName': 'eventName',
                        'inListFilter': {'values': steps}}},
            {'filter': {'fieldName': 'country',
                        'inListFilter': {'values': EN_COUNTRIES}}},
        ]}},
        'limit': 200,
    })
    per_ver = {}
    for row in r.get('rows', []):
        ver = row['dimensionValues'][0]['value']
        ev = row['dimensionValues'][1]['value']
        per_ver.setdefault(ver, {})[ev] = int(row['metricValues'][0]['value'])

    lines = ['', '### Холодний старт, EN-ринки (7 дн)',
             '| версія | first_open | онбординг | % дійшли | magic | app_ready |',
             '|---|---|---|---|---|---|']
    for ver in sorted(per_ver):
        v = per_ver[ver]
        fo, ob = v.get('first_open', 0), v.get('onboarding_start', 0)
        pct = f'{ob / fo:.0%}' if fo else '—'
        lines.append(f"| {ver} | {fo} | {ob} | {pct} | "
                     f"{v.get('onboarding_magic_moment_start', 0)} | "
                     f"{v.get('app_ready', 0)} |")

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


def trial_funnel(tok):
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
            'dimensions': [{'name': 'customEvent:trial'}, {'name': 'eventName'}],
            'metrics': [{'name': 'eventCount'}],
            'dimensionFilter': {'filter': {
                'fieldName': 'eventName',
                'inListFilter': {'values': events}}},
            'limit': 50,
        })
    except Exception:
        return ['- Тріал-воронка: запит не вдався (дименшн `trial` не зареєстровано?)']
    per_state = {}
    for row in r.get('rows', []):
        state = row['dimensionValues'][0]['value']
        ev = row['dimensionValues'][1]['value']
        per_state.setdefault(state, {})[ev] = int(row['metricValues'][0]['value'])
    # (not set) is every event from a build older than the dimension.
    per_state.pop('(not set)', None)
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


def default_plan_ab(tok):
    """Paywall A/B: which plan tile starts selected (user property, set on
    every paywall open from Remote Config `paywall_default_plan`)."""
    events = ['paywall_view', 'purchase_start', 'purchase_cancel', 'purchase_success']
    try:
        r = run_report(tok, {
            'dateRanges': [{'startDate': '7daysAgo', 'endDate': 'today'}],
            'dimensions': [{'name': 'customUser:paywall_default_plan'},
                           {'name': 'eventName'}],
            'metrics': [{'name': 'totalUsers'}],
            'dimensionFilter': {'filter': {
                'fieldName': 'eventName', 'inListFilter': {'values': events}}},
            'limit': 50,
        })
    except Exception:
        return ['- A/B дефолтного плану: запит не вдався (дименшн не зареєстровано?)']
    per = {}
    for row in r.get('rows', []):
        b = row['dimensionValues'][0]['value']
        if b == '(not set)':
            continue
        per.setdefault(b, {})[row['dimensionValues'][1]['value']] = \
            int(row['metricValues'][0]['value'])
    if not per:
        return ['- A/B дефолтного плану: ще без даних']
    lines = ['', '### A/B: який план обраний за замовчуванням (7 дн, users)',
             '| bucket | пейвол | старти | скасувань | покупок |', '|---|---|---|---|---|']
    for b in sorted(per):
        v = per[b]
        lines.append(f"| {b} | {v.get('paywall_view', 0)} | {v.get('purchase_start', 0)} | "
                     f"{v.get('purchase_cancel', 0)} | {v.get('purchase_success', 0)} |")
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

    # Health ratios worth watching every week.
    cv, _ = cur.get('card_view', (0, 0))
    cl, _ = cur.get('card_listen', (0, 0))
    pw = cur.get('paywall_view', (0, 0))[1]
    ps = cur.get('purchase_success', (0, 0))[1]
    lines.append('')
    if cv:
        lines.append(f'- Прослуховування/перегляди: {cl}/{cv} ({cl / cv:.0%})')
    if pw:
        lines.append(f'- Конверсія paywall→покупка: {ps}/{pw} ({ps / pw:.0%})')

    lines.extend(startup_health(tok))
    lines.extend(trial_funnel(tok))
    lines.extend(default_plan_ab(tok))
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
