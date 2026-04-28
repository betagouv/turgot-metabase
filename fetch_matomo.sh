#!/bin/bash
set -e

DEST_DB_URL="$SCALINGO_POSTGRESQL_URL"
MATOMO_TOKEN="${MATOMO_TOKEN_AUTH}"
MATOMO_SITE_ID="${MATOMO_SITE_ID}"
MATOMO_BASE_URL="https://stats.beta.gouv.fr/index.php"

YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)

echo "Fetching Matomo stats for $YESTERDAY..."

RESPONSE=$(curl -sf \
  "${MATOMO_BASE_URL}?module=API&format=JSON&idSite=${MATOMO_SITE_ID}&period=day&date=yesterday&method=API.get&token_auth=${MATOMO_TOKEN}")

NB_UNIQ_VISITORS=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'nb_uniq_visitors' not in data:
    print('ERROR: missing nb_uniq_visitors, got: ' + str(data)[:200], file=sys.stderr)
    sys.exit(1)
print(int(data['nb_uniq_visitors']))
")

echo "Unique visitors: $NB_UNIQ_VISITORS"

dbclient-fetcher psql

psql "$DEST_DB_URL" -c "
INSERT INTO analytics.matomo_daily_stats (date, nb_uniq_visitors)
VALUES ('$YESTERDAY', $NB_UNIQ_VISITORS)
ON CONFLICT (date) DO UPDATE SET
    nb_uniq_visitors = EXCLUDED.nb_uniq_visitors;
"

echo "Done. Stored $NB_UNIQ_VISITORS unique visitors for $YESTERDAY."
