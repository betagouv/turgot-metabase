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

RESPONSE=$(curl -sf \
  "${MATOMO_BASE_URL}?module=API&format=JSON&idSite=${MATOMO_SITE_ID}&period=day&date=${FROM_DATE},${TO_DATE}&method=API.get&token_auth=${MATOMO_TOKEN}&filter_limit=-1")

echo "$RESPONSE" | python3 -c "
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

echo "Backfill complete."
