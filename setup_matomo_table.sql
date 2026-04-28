-- Schéma séparé pour que les données survivent au sync quotidien de sync_tables.sh
-- (qui supprime toutes les tables du schéma public)
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.matomo_daily_stats (
    date               DATE PRIMARY KEY,
    nb_uniq_visitors   INTEGER NOT NULL,
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
