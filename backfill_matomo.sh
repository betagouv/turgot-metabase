#!/bin/bash
# Usage: ./backfill_matomo.sh [FROM_DATE]
#   FROM_DATE: date de début au format YYYY-MM-DD (défaut: 2020-01-01)
#   Exemple: ./backfill_matomo.sh 2023-01-01
set -e

DEST_DB_URL="$SCALINGO_POSTGRESQL_URL"
MATOMO_TOKEN="${MATOMO_TOKEN_AUTH}"
MATOMO_SITE_ID="${MATOMO_SITE_ID}"
MATOMO_BASE_URL="https://stats.beta.gouv.fr/index.php"

FROM_DATE="${1:-2020-01-01}"
TO_DATE=$(date -d "yesterday" +%Y-%m-%d)

echo "Backfill Matomo stats from $FROM_DATE to $TO_DATE..."

dbclient-fetcher psql

# Daily
echo "Fetching daily stats..."
RESPONSE_DAY=$(curl -sf \
  "${MATOMO_BASE_URL}?module=API&format=JSON&idSite=${MATOMO_SITE_ID}&period=day&date=${FROM_DATE},${TO_DATE}&method=API.get&token_auth=${MATOMO_TOKEN}&filter_limit=-1")

echo "$RESPONSE_DAY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not isinstance(data, dict):
    print('Unexpected response: ' + str(data)[:300], file=sys.stderr)
    sys.exit(1)
rows = []
for date, stats in sorted(data.items()):
    if isinstance(stats, dict) and 'nb_uniq_visitors' in stats:
        rows.append((date, int(stats['nb_uniq_visitors'])))
print(f'Found {len(rows)} days with data.', file=sys.stderr)
print('BEGIN;')
for date, visitors in rows:
    print(f\"INSERT INTO analytics.matomo_daily_stats (date, nb_uniq_visitors) VALUES ('{date}', {visitors}) ON CONFLICT (date) DO UPDATE SET nb_uniq_visitors = EXCLUDED.nb_uniq_visitors;\")
print('COMMIT;')
" | psql "$DEST_DB_URL"

# Weekly
echo "Fetching weekly stats..."
RESPONSE_WEEK=$(curl -sf \
  "${MATOMO_BASE_URL}?module=API&format=JSON&idSite=${MATOMO_SITE_ID}&period=week&date=${FROM_DATE},${TO_DATE}&method=API.get&token_auth=${MATOMO_TOKEN}&filter_limit=-1")

echo "$RESPONSE_WEEK" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not isinstance(data, dict):
    print('Unexpected response: ' + str(data)[:300], file=sys.stderr)
    sys.exit(1)
rows = []
for date_range, stats in sorted(data.items()):
    if isinstance(stats, dict) and 'nb_uniq_visitors' in stats:
        week_start = date_range.split(',')[0]
        rows.append((week_start, int(stats['nb_uniq_visitors'])))
print(f'Found {len(rows)} weeks with data.', file=sys.stderr)
print('BEGIN;')
for week_start, visitors in rows:
    print(f\"INSERT INTO analytics.matomo_weekly_stats (week_start, nb_uniq_visitors) VALUES ('{week_start}', {visitors}) ON CONFLICT (week_start) DO UPDATE SET nb_uniq_visitors = EXCLUDED.nb_uniq_visitors;\")
print('COMMIT;')
" | psql "$DEST_DB_URL"

# Monthly
echo "Fetching monthly stats..."
RESPONSE_MONTH=$(curl -sf \
  "${MATOMO_BASE_URL}?module=API&format=JSON&idSite=${MATOMO_SITE_ID}&period=month&date=${FROM_DATE},${TO_DATE}&method=API.get&token_auth=${MATOMO_TOKEN}&filter_limit=-1")

echo "$RESPONSE_MONTH" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not isinstance(data, dict):
    print('Unexpected response: ' + str(data)[:300], file=sys.stderr)
    sys.exit(1)
rows = []
for date_range, stats in sorted(data.items()):
    if isinstance(stats, dict) and 'nb_uniq_visitors' in stats:
        month_start = date_range.split(',')[0]
        if len(month_start) == 7:  # format "YYYY-MM" -> "YYYY-MM-01"
            month_start = month_start + '-01'
        rows.append((month_start, int(stats['nb_uniq_visitors'])))
print(f'Found {len(rows)} months with data.', file=sys.stderr)
print('BEGIN;')
for month_start, visitors in rows:
    print(f\"INSERT INTO analytics.matomo_monthly_stats (month_start, nb_uniq_visitors) VALUES ('{month_start}', {visitors}) ON CONFLICT (month_start) DO UPDATE SET nb_uniq_visitors = EXCLUDED.nb_uniq_visitors;\")
print('COMMIT;')
" | psql "$DEST_DB_URL"

echo "Backfill complete."
