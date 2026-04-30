#!/bin/bash
set -e

DEST_DB_URL="$SCALINGO_POSTGRESQL_URL"
MATOMO_TOKEN="${MATOMO_TOKEN_AUTH}"
MATOMO_SITE_ID="${MATOMO_SITE_ID}"
MATOMO_BASE_URL="https://stats.beta.gouv.fr/index.php"

YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
DAY_OF_WEEK=$(date -d "$YESTERDAY" +%u)  # 1=lundi, 7=dimanche
WEEK_START=$(date -d "$YESTERDAY - $(( DAY_OF_WEEK - 1 )) days" +%Y-%m-%d)
MONTH_START=$(date -d "$YESTERDAY" +%Y-%m-01)

echo "Fetching Matomo stats for $YESTERDAY (semaine: $WEEK_START, mois: $MONTH_START)..."

RESPONSE_DAY=$(curl -sf \
  "${MATOMO_BASE_URL}?module=API&format=JSON&idSite=${MATOMO_SITE_ID}&period=day&date=yesterday&method=API.get&token_auth=${MATOMO_TOKEN}")

RESPONSE_WEEK=$(curl -sf \
  "${MATOMO_BASE_URL}?module=API&format=JSON&idSite=${MATOMO_SITE_ID}&period=week&date=yesterday&method=API.get&token_auth=${MATOMO_TOKEN}")

RESPONSE_MONTH=$(curl -sf \
  "${MATOMO_BASE_URL}?module=API&format=JSON&idSite=${MATOMO_SITE_ID}&period=month&date=yesterday&method=API.get&token_auth=${MATOMO_TOKEN}")

NB_UNIQ_DAY=$(echo "$RESPONSE_DAY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'nb_uniq_visitors' not in data:
    print('ERROR: missing nb_uniq_visitors, got: ' + str(data)[:200], file=sys.stderr)
    sys.exit(1)
print(int(data['nb_uniq_visitors']))
")

NB_UNIQ_WEEK=$(echo "$RESPONSE_WEEK" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'nb_uniq_visitors' not in data:
    print('ERROR: missing nb_uniq_visitors, got: ' + str(data)[:200], file=sys.stderr)
    sys.exit(1)
print(int(data['nb_uniq_visitors']))
")

NB_UNIQ_MONTH=$(echo "$RESPONSE_MONTH" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'nb_uniq_visitors' not in data:
    print('ERROR: missing nb_uniq_visitors, got: ' + str(data)[:200], file=sys.stderr)
    sys.exit(1)
print(int(data['nb_uniq_visitors']))
")

echo "Visiteurs uniques — jour: $NB_UNIQ_DAY, semaine: $NB_UNIQ_WEEK, mois: $NB_UNIQ_MONTH"

dbclient-fetcher psql

psql "$DEST_DB_URL" -c "
INSERT INTO analytics.matomo_daily_stats (date, nb_uniq_visitors)
VALUES ('$YESTERDAY', $NB_UNIQ_DAY)
ON CONFLICT (date) DO UPDATE SET nb_uniq_visitors = EXCLUDED.nb_uniq_visitors;

INSERT INTO analytics.matomo_weekly_stats (week_start, nb_uniq_visitors)
VALUES ('$WEEK_START', $NB_UNIQ_WEEK)
ON CONFLICT (week_start) DO UPDATE SET nb_uniq_visitors = EXCLUDED.nb_uniq_visitors;

INSERT INTO analytics.matomo_monthly_stats (month_start, nb_uniq_visitors)
VALUES ('$MONTH_START', $NB_UNIQ_MONTH)
ON CONFLICT (month_start) DO UPDATE SET nb_uniq_visitors = EXCLUDED.nb_uniq_visitors;
"

echo "Done."
