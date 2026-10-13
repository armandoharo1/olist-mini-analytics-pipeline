#!/usr/bin/env bash
# End-to-end run: start services -> load raw CSVs -> build and test dbt models.
# Usage: bash run_pipeline.sh  (from the project root, virtual environment active)
set -euo pipefail

echo "==> 1/3 Starting Docker services"
docker compose up -d
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
