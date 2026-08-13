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
OUT = Path.home() / 'Desktop/skillar-weekly-report.md'

KEY_EVENTS = [
    'first_open', 'onboarding_start', 'onboarding_age_selected',
    'onboarding_name_entered', 'onboarding_magic_moment_complete',
    'tutorial_complete',
    'card_view', 'card_listen', 'pack_open', 'pack_complete',
    'game_start', 'game_complete',
    'paywall_view', 'paywall_product_select',
    'purchase_start', 'purchase_success', 'purchase_error',
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

    lines.extend(crash_summary(bq_token()))

    OUT.parent.mkdir(exist_ok=True)
    header = '# Skillar — щотижнева аналітика\n' if not OUT.exists() else ''
    with open(OUT, 'a') as f:
        f.write(header + '\n'.join(lines) + '\n')

    subprocess.run(['osascript', '-e',
                    'display notification "Звіт на Desktop: skillar-weekly-report.md" '
                    'with title "Skillar analytics"'], check=False)
    print(f'written: {OUT}')


if __name__ == '__main__':
    main()
