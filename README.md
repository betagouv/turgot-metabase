# turgot-metabase

Le but de ce repo est de proposer un script (`sync_tables.sh`) qui va copier la DB de prod dans une réplique qui sera lue par Metabase.
L'idée est donc de déployer ce script sur l'app `turgot-metabase-data`.

`sync_review_app.sh` fait la même chose mais en utilisant la DB de staging comme source (via `$STAGING_DATABASE_URL`) pour mettre
à jour les review app. Le script ne s'appelle que manuellement.

### Pour lancer le script manuellement

```sh
# Sync depuis la prod vers metabase
scalingo --app turgot-metabase-data --region osc-secnum-fr1 run bash ./sync_tables.sh

# Sync depuis staging vers une review app
scalingo --app turgot-metabase-data --region osc-secnum-fr1 run bash DEST_DB_URL=<***> ./sync_review_app.sh 
```
