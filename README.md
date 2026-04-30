# turgot-metabase

Copie la DB de prod dans une réplique lue par Metabase, et collecte des statistiques Matomo (visiteurs uniques par jour, semaine et mois).

## Architecture

- **`sync_tables.sh`** — copie les tables de la DB de prod vers la DB Metabase (schéma `public`), tourne à 2h UTC
- **`fetch_matomo.sh`** — récupère les stats Matomo de la veille et les stocke dans le schéma `analytics`, tourne à 4h UTC
- **`backfill_matomo.sh`** — rattrapage historique des stats Matomo depuis une date de départ
- **`setup_matomo_table.sql`** — initialise les tables du schéma `analytics` (à lancer une seule fois)

Le schéma `analytics` est séparé du schéma `public` pour que les données Matomo survivent au sync quotidien (qui recrée entièrement le schéma `public`).

## Connexion à l'app Scalingo

Toutes les commandes ci-dessous s'exécutent depuis la racine du projet avec :

```sh
scalingo --app <app> --region <region> run bash
```

Cela ouvre un shell dans le conteneur de l'app, avec accès aux fichiers du repo et aux variables d'environnement.

## Initialiser les tables Matomo

À lancer une seule fois (ou après un `DROP` du schéma `analytics`) :

```sh
scalingo --app <app> --region <region> run -- bash -c \
  "dbclient-fetcher psql && psql \$SCALINGO_POSTGRESQL_URL -f setup_matomo_table.sql"
```

## Lancer les scripts manuellement

**Sync des tables de prod :**
```sh
scalingo --app <app> --region <region> run bash ./sync_tables.sh
```

**Récupération des stats Matomo du jour précédent :**
```sh
scalingo --app <app> --region <region> run bash ./fetch_matomo.sh
```

**Rattrapage historique depuis une date donnée :**
```sh
scalingo --app <app> --region <region> run bash ./backfill_matomo.sh 2023-01-01
```

Par défaut (sans argument), le backfill part du 2020-01-01.

## Tables Matomo

| Table | Clé primaire | Description |
|---|---|---|
| `analytics.matomo_daily_stats` | `date` | Visiteurs uniques par jour |
| `analytics.matomo_weekly_stats` | `week_start` (lundi) | Visiteurs uniques par semaine |
| `analytics.matomo_monthly_stats` | `month_start` (1er du mois) | Visiteurs uniques par mois |

Les stats hebdomadaires et mensuelles sont des totaux glissants : elles sont mises à jour chaque jour avec le cumul de la semaine / du mois en cours. En fin de période, la valeur finale est définitive.
