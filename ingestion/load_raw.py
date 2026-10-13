"""
Load the Olist CSV files into the `raw` schema of Postgres (ELT "load raw" step).

- All columns are loaded as TEXT; typing and cleaning happen in dbt.
- Each table is truncated and reloaded in one transaction (idempotent).
  Tables are not dropped because the dbt staging views depend on them.
- Row counts are checked against the number of records in each file.

Usage: python ingestion/load_raw.py
"""

import csv
import os
from pathlib import Path

import psycopg

DATA_DIR = Path("data/raw")

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

CONNECTION = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", "5432")),
    "user": os.getenv("POSTGRES_USER", "olist"),
    "password": os.getenv("POSTGRES_PASSWORD", "olist"),
    "dbname": os.getenv("POSTGRES_DB", "olist"),
}


def read_header_and_count(path: Path) -> tuple[list[str], int]:
    # Count CSV records, not lines: some review comments contain line breaks.
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        record_count = sum(1 for _ in reader)
    return header, record_count


def load_table(conn: psycopg.Connection, path: Path, table: str) -> tuple[int, int]:
    header, file_records = read_header_and_count(path)

    columns_ddl = ", ".join(f'"{col}" text' for col in header)
    columns_list = ", ".join(f'"{col}"' for col in header)

    with conn.cursor() as cur:
        cur.execute(
            f"""
            CREATE TABLE IF NOT EXISTS raw.{table} (
                {columns_ddl},
                _source_file text        DEFAULT '{path.name}',
                _loaded_at   timestamptz DEFAULT now()
            )
            """
        )
        cur.execute(f"TRUNCATE TABLE raw.{table}")

        copy_sql = f"COPY raw.{table} ({columns_list}) FROM STDIN WITH (FORMAT csv, HEADER true)"
        with path.open(encoding="utf-8-sig", newline="") as f, cur.copy(copy_sql) as copy:
            while chunk := f.read(1024 * 1024):
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
