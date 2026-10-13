"""
Load the Olist CSV files into the `raw` schema of Postgres.

This is the "Load raw" step of an ELT pipeline:
  * Every CSV becomes one table in the `raw` schema, with the same column names.
  * Every column is stored as TEXT: we do NOT clean or convert anything here.
    Data types and cleaning happen later in dbt, so `raw` is always an exact
    copy of the source files.
  * Two extra columns are added for traceability: `_source_file`, `_loaded_at`.
  * Each table is dropped and recreated on every run, so running the script
    twice gives the same result (idempotent).
  * At the end we compare the number of records in each file vs the rows
    loaded in Postgres, so we know nothing was lost.

Usage (from the project root, with the virtual environment active):
    python ingestion/load_raw.py
"""

import csv
import os
from pathlib import Path

import psycopg

# Folder with the 9 CSV files
DATA_DIR = Path("data/raw")

# CSV file name -> table name in the raw schema
FILES = {
    "olist_customers_dataset.csv": "customers",
    "olist_geolocation_dataset.csv": "geolocation",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_orders_dataset.csv": "orders",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "product_category_name_translation.csv": "product_category_name_translation",
}

# Same credentials as docker-compose.yml (can be overridden with env variables)
CONNECTION = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", "5432")),
    "user": os.getenv("POSTGRES_USER", "olist"),
    "password": os.getenv("POSTGRES_PASSWORD", "olist"),
    "dbname": os.getenv("POSTGRES_DB", "olist"),
}


def read_header_and_count(path: Path) -> tuple[list[str], int]:
    """Return the column names and the number of records in a CSV file.

    We use the csv module instead of counting lines because some review
    comments contain line breaks inside quotes (1 record = several lines).
    """
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        record_count = sum(1 for _ in reader)
    return header, record_count


def load_table(conn: psycopg.Connection, path: Path, table: str) -> tuple[int, int]:
    """Drop, recreate and fill raw.<table> from one CSV file."""
    header, file_records = read_header_and_count(path)

    columns_ddl = ", ".join(f'"{col}" text' for col in header)
    columns_list = ", ".join(f'"{col}"' for col in header)

    with conn.cursor() as cur:
        cur.execute(f"DROP TABLE IF EXISTS raw.{table}")
        cur.execute(
            f"""
            CREATE TABLE raw.{table} (
                {columns_ddl},
                _source_file text        DEFAULT '{path.name}',
                _loaded_at   timestamptz DEFAULT now()
            )
            """
        )
        # COPY is Postgres' bulk loader: much faster than row-by-row INSERTs.
        copy_sql = f"COPY raw.{table} ({columns_list}) FROM STDIN WITH (FORMAT csv, HEADER true)"
        with path.open(encoding="utf-8-sig", newline="") as f, cur.copy(copy_sql) as copy:
            while chunk := f.read(1024 * 1024):  # 1 MB at a time
                copy.write(chunk)

        cur.execute(f"SELECT count(*) FROM raw.{table}")
        loaded_rows = cur.fetchone()[0]

    conn.commit()
    return file_records, loaded_rows


def main() -> None:
    with psycopg.connect(**CONNECTION) as conn:
        conn.execute("CREATE SCHEMA IF NOT EXISTS raw")
        conn.commit()

        all_ok = True
        for file_name, table in FILES.items():
            file_records, loaded_rows = load_table(conn, DATA_DIR / file_name, table)
            status = "OK" if file_records == loaded_rows else "MISMATCH"
            all_ok = all_ok and status == "OK"
            print(f"[{status:>8}] raw.{table:<35} file={file_records:>9,}  loaded={loaded_rows:>9,}")

    print("\nAll files loaded and row counts match." if all_ok else "\nSome tables do not match!")


if __name__ == "__main__":
    main()