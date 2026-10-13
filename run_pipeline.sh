#!/usr/bin/env bash
# Runs the whole pipeline end-to-end:
#   1. start Postgres + Metabase (Docker)
#   2. load the raw CSVs into Postgres
#   3. build and test the dbt project (staging -> marts -> metrics -> reconciliation)
#
# Usage (from the project root, with the virtual environment active):
#   bash run_pipeline.sh

set -euo pipefail

echo "==> 1/3 Starting Docker services"
docker compose up -d

echo "==> Waiting for Postgres to accept connections"
until docker exec olist_postgres pg_isready -U olist -d olist > /dev/null 2>&1; do
    sleep 2
done

echo "==> 2/3 Loading raw CSV files"
python ingestion/load_raw.py

echo "==> 3/3 Building and testing dbt models"
cd dbt/olist_analytics
dbt deps
dbt build

echo "==> Done. Dashboard: http://localhost:3500"
