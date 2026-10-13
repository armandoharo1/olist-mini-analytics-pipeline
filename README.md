# E-commerce Analytics Pipeline — Brazilian Marketplace (Olist)

An end-to-end analytics engineering project that turns raw marketplace exports into a tested,
documented and business-ready analytics layer.

The pipeline ingests ~1.5M rows from 9 related CSV files (orders, items, payments, reviews, customers,
sellers, products) into **PostgreSQL**, models them with **dbt** into a star schema, validates every
number against the source, and serves sales, retention, product and delivery KPIs through a
**Metabase** dashboard. Everything runs locally with **Docker** and a single command.

![Dashboard](dashboard/docs/dashboard.png)

**Highlights**

* Layered ELT: `raw → staging → marts (facts & dimensions) → metrics`, fully reproducible.
* Dimensional model with explicit grain: 2 fact tables and 4 dimensions.
* 68 automated data tests plus a raw-vs-model reconciliation report that ties every total back to the source, to the cent.
* Data-quality issues found in the source (duplicates, cancellations, inconsistent statuses) documented and handled explicitly.
* Curated KPI tables so the dashboard contains no hidden logic; the SQL behind every chart is versioned.

**Data source:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100k orders placed between 2016 and 2018.

---

## 1. Architecture

```mermaid
flowchart LR
    CSV["📄 <b>9 CSV files</b><br/>Olist marketplace<br/>~1.5M rows"]

    subgraph ING["🐍 Ingestion · Python"]
        LOAD["<b>load_raw.py</b><br/>COPY · all TEXT<br/>row-count check"]
    end

    subgraph PG["🐘 PostgreSQL 16 · Docker"]
        RAW[("<b>raw</b><br/>9 tables<br/>exact copy")]
        subgraph DBT["⚙️ dbt · 20 models · 68 tests"]
            STG["<b>staging</b><br/>9 views<br/>types · renames"]
            MARTS["<b>marts</b><br/>star schema<br/>2 facts · 4 dims"]
            MET["<b>metrics</b><br/>4 KPI tables"]
            REC["<b>reconciliation</b><br/>raw vs model<br/>9 checks"]
        end
    end

    subgraph BI["📊 Metabase · Docker"]
        DASH["<b>E-commerce<br/>dashboard</b>"]
    end

    CSV --> LOAD --> RAW --> STG --> MARTS --> MET --> DASH
    RAW -. totals .-> REC
    MARTS -. totals .-> REC
    REC --> DASH

    classDef source fill:#ECEFF1,stroke:#607D8B,color:#263238
    classDef python fill:#FFF8E1,stroke:#F9A825,color:#3E2723
    classDef raw fill:#E3F2FD,stroke:#1E88E5,color:#0D47A1
    classDef stg fill:#E8F5E9,stroke:#43A047,color:#1B5E20
    classDef marts fill:#C8E6C9,stroke:#2E7D32,color:#1B5E20
    classDef metrics fill:#A5D6A7,stroke:#1B5E20,color:#1B5E20
    classDef rec fill:#FFEBEE,stroke:#E53935,color:#B71C1C
    classDef bi fill:#EDE7F6,stroke:#5E35B1,color:#311B92
    class CSV source
    class LOAD python
    class RAW raw
    class STG stg
    class MARTS marts
    class MET metrics
    class REC rec
    class DASH bi
    style ING fill:#FFFDF5,stroke:#F9A825,color:#3E2723
    style PG fill:#F5F9FF,stroke:#1E88E5,color:#0D47A1
    style DBT fill:#F6FBF6,stroke:#43A047,color:#1B5E20
    style BI fill:#FAF8FE,stroke:#5E35B1,color:#311B92
```

| Layer | Schema | Built by | Contents |
|---|---|---|---|
| Raw | `raw` | `ingestion/load_raw.py` | Exact copy of the 9 CSVs. All columns `TEXT`, plus `_source_file` and `_loaded_at`. |
| Staging | `analytics_staging` | dbt (views) | 1:1 with raw: types cast, columns renamed, typos fixed. No business rules. |
| Marts | `analytics_marts` | dbt (tables) | Star schema: `fct_orders`, `fct_order_items`, `dim_customers`, `dim_products`, `dim_sellers`, `dim_date`. |
| Metrics | `analytics_metrics` | dbt (tables) | Business-ready KPI tables used by the dashboard. |
| Reconciliation | `analytics_reconciliation` | dbt (table) | Checks that tie the model back to the raw source. |

**Stack:** PostgreSQL 16 · Python 3.11 + psycopg 3 · dbt-core 1.12 + dbt-postgres + dbt_utils · Metabase · Docker Compose.

## 2. Repository structure

```
├── docker-compose.yml          # Postgres + Metabase
├── requirements.txt            # Python dependencies
├── run_pipeline.sh             # One command: start services → load raw → dbt build
├── data/raw/                   # The 9 Olist CSVs go here (not committed)
├── ingestion/load_raw.py       # Raw load into Postgres
├── dbt/olist_analytics/
│   ├── models/staging/         # stg_*
│   ├── models/marts/           # fct_* and dim_*
│   ├── models/metrics/         # mtr_* (KPI tables)
│   ├── models/reconciliation/  # rpt_reconciliation
│   ├── macros/is_valid_sale.sql
│   └── tests/assert_reconciliation_ok.sql
└── dashboard/
    ├── queries/                # SQL behind every dashboard card
    └── docs/dashboard.png
```

## 3. Getting started

**Prerequisites:** Docker Desktop, Python 3.10+, Git.

```bash
# 1. Clone the repository
git clone https://github.com/armandoharo1/olist-mini-analytics-pipeline.git
cd olist-mini-analytics-pipeline

# 2. Download the 9 CSVs from Kaggle and copy them into data/raw/

# 3. Create a virtual environment and install dependencies
python -m venv .venv
source .venv/Scripts/activate        # Windows (Git Bash) | macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt

# 4. Run the full pipeline
bash run_pipeline.sh
```

`run_pipeline.sh` runs these steps, which can also be run one by one:

```bash
docker compose up -d                                   # Postgres (5432) + Metabase (3500)
python ingestion/load_raw.py                           # CSV -> raw schema, row counts checked
cd dbt/olist_analytics && dbt deps && dbt build        # 20 models + 68 tests
```

Expected result: `Done. PASS=88 WARN=0 ERROR=0`.

**Dashboard:** open http://localhost:3500, create a local admin user and add a PostgreSQL connection with
host `postgres`, port `5432`, database/user/password `olist`, limited to the schemas `analytics_metrics`,
`analytics_marts` and `analytics_reconciliation`. The SQL for every card is in `dashboard/queries/`.

> **Windows note:** Metabase is exposed on port **3500** because Windows (Hyper-V/WSL) may reserve
> the range that includes 3000. If 3500 is blocked too, check `netsh interface ipv4 show excludedportrange protocol=tcp`
> and choose a free port in `docker-compose.yml`.

## 4. Data model

```mermaid
erDiagram
    dim_customers ||--o{ fct_orders : places
    dim_date ||--o{ fct_orders : "purchase date"
    fct_orders ||--o{ fct_order_items : contains
    dim_customers ||--o{ fct_order_items : buys
    dim_products ||--o{ fct_order_items : "sold as"
    dim_sellers ||--o{ fct_order_items : sells
    dim_date ||--o{ fct_order_items : "purchase date"

    fct_orders {
        string order_id PK
        string customer_unique_id FK
        date purchase_date FK
        boolean is_valid_sale
        numeric order_total "items + freight"
        numeric payment_total
        int review_score
        boolean is_delivered
        boolean is_late
    }
    fct_order_items {
        string order_id PK
        int order_item_id PK
        string product_id FK
        string seller_id FK
        string customer_unique_id FK
        date purchase_date FK
        boolean is_valid_sale
        numeric item_total "price + freight"
    }
    dim_customers {
        string customer_unique_id PK
        string customer_city
        string customer_state
        timestamp first_purchase_at
    }
    dim_products {
        string product_id PK
        string category_name "English"
    }
    dim_sellers {
        string seller_id PK
        string seller_state
    }
    dim_date {
        date date_day PK
        date month_start
        int year
    }
```

| Model | Grain (one row per…) | Notes |
|---|---|---|
| `fct_orders` | order | Main fact. Items and payments are **aggregated before joining** to avoid fan-out. Revenue, payments, latest review, delivery days, `is_late`. |
| `fct_order_items` | item within an order (`order_id`, `order_item_id`) | Product, category and seller analysis. Keys to all dimensions. |
| `dim_customers` | person (`customer_unique_id`) | The source `customer_id` changes with every order; collapsed to one row per person. Location from the most recent order. |
| `dim_products` | product | English category; `unknown` if missing; Portuguese name if not translated. |
| `dim_sellers` | seller | |
| `dim_date` | calendar day (2016–2018) | Generated with `generate_series`; makes months without orders visible. |

Both fact tables keep **every** source row and flag business rules with columns (`is_valid_sale`,
`is_delivered`) instead of deleting rows, so they reconcile 1:1 with the raw layer.

## 5. Metric definitions

| Metric | Definition | Table |
|---|---|---|
| Valid sale | Order status is not `canceled` or `unavailable` (orders in progress count). Defined once in `macros/is_valid_sale.sql`. | — |
| Revenue | Σ (item price + freight) of valid orders, by **month of purchase**, in BRL. | `mtr_monthly_sales` |
| Average order value (AOV) | Revenue ÷ valid orders with at least one item. | `mtr_monthly_sales` |
| Repeat-purchase rate | % of customers (`customer_unique_id`) with 2+ valid orders. **Strict:** purchases on 2+ different days. | `mtr_repeat_purchase` |
| Category revenue | Revenue (price + freight) of valid items per English category, ranked. | `mtr_category_sales` |
| On-time delivery | % of delivered orders received on or before the estimated date, by month of purchase; plus average delivery days and review score on time vs late. | `mtr_delivery_performance` |

Trend charts use **complete months only (2017-01 to 2018-08)**, configured as dbt `vars`. Earlier and
later months have very few orders because the dataset starts and ends there; they are kept and flagged
with `is_complete_month = false`.

## 6. Data quality & reconciliation

* **68 dbt tests:** primary keys (`unique`, `not_null`), composite keys (`dbt_utils.unique_combination_of_columns`),
  accepted values, and `relationships` between every fact and its dimensions.
* **`rpt_reconciliation`** compares totals computed directly from `raw` with the same totals from the model.
  The test `assert_reconciliation_ok` fails the build if any check is out of tolerance.

| Check | Raw | Model | Diff |
|---|---:|---:|---:|
| Orders: row count | 99,441 | 99,441 | 0 |
| Order items: row count | 112,650 | 112,650 | 0 |
| Customers: distinct people | 96,096 | 96,096 | 0 |
| Products: row count | 32,951 | 32,951 | 0 |
| Gross item value (price + freight), all orders | 15,843,553.24 | 15,843,553.24 | 0 |
| Gross item value, order-items fact | 15,843,553.24 | 15,843,553.24 | 0 |
| Payments total, all orders | 16,008,872.12 | 16,008,872.12 | 0 |
| Valid revenue: `fct_orders` vs `fct_order_items` | 15,735,527.03 | 15,735,527.03 | 0 |
| Valid orders: payments vs revenue (tolerance 0.5%) | 15,739,137.01 | 15,735,527.03 | −3,609.98 (−0.02%) |

The KPIs were also recomputed independently with pandas directly from the CSV files; all values matched to the cent.

### Issues found in the source data

| Issue | Finding | Handling |
|---|---|---|
| Duplicate reviews | `review_id` is not unique (789 ids repeated); 551 orders have more than one review. | Staging key is (`review_id`, `order_id`); `fct_orders` keeps the most recently answered review. |
| Cancellations | 1,234 canceled/unavailable orders; most have no items but were paid (R$ 269.7k paid vs R$ 108k in items). | Kept in the facts, excluded from revenue via `is_valid_sale`. Refunds are not in the data, so payments are not used as revenue. |
| Revenue vs payments | Total payments exceed items + freight by R$ 165k. | For valid orders the gap is R$ 3.6k (0.02%), explained by installment interest and vouchers. Revenue = items + freight. |
| Inconsistent delivery data | 6 canceled orders have a delivery date; 8 delivered orders do not. | "Delivered" = status `delivered` **and** a delivery date. |
| Orders without items | 775 orders (8 of them valid, still in progress). | Revenue 0 (not NULL); excluded from the AOV denominator. |
| Customer identity | `customer_id` changes per order (99,441 ids for 96,096 people). | All customer metrics use `customer_unique_id`. |
| Same-day "repeat" orders | 823 of 2,887 repeat customers placed all their orders on the same day (split checkouts). | Added a strict repeat rate (2+ purchase days): **2.17%** vs 3.04%. |
| Missing categories | 610 products without category; 2 categories without English translation. | `unknown` / Portuguese-name fallback in `dim_products`. |
| Nulls | Approval and delivery timestamps missing for undelivered orders. | Kept as NULL; delivery metrics use delivered orders only. |
| Time zones | Source timestamps have no time zone. | Treated as Brazil local time, no conversion. |
| Incomplete months | 2016-09 to 2016-12 and 2018-09/10 have very few orders (2016-11 has none). | Kept, flagged, excluded from trend charts. |
| Zip codes | Leading zeros are lost if parsed as numbers. | Loaded as `TEXT`; `lpad(…, 5, '0')` in staging. |

## 7. Key insights

| Topic | Insight |
|---|---|
| Revenue | Grows from R$ 137k (Jan-2017) to a R$ 1.0–1.16M monthly plateau in 2018. Peak in **Nov-2017 (Black Friday): R$ 1.17M, +53% MoM**. Total valid revenue: **R$ 15.74M**. |
| Average order value | Stable between **R$ 147 and R$ 174** (R$ 160 overall): growth came from more orders, not larger baskets. |
| Retention | Only **3.04%** of 94,983 customers bought more than once (2.17% strict). Retention is the largest growth opportunity. |
| Categories | `health_beauty` leads (R$ 1.44M, 9.1%), followed by `watches_gifts`, `bed_bath_table`, `sports_leisure` and `computers_accessories`. The top 10 make up 62% of revenue. |
| Delivery | **93.2% on time**, 12.6 days on average. Late deliveries drop the review score from **4.29 to 2.27**. On-time rate fell during demand peaks (Nov-2017: 87.6%, Feb–Mar 2018: 81–86%). |

## 8. Design decisions & trade-offs

* **ELT with a faithful raw layer.** Everything lands as `TEXT`; typing and cleaning happen in dbt, so rules can change and be replayed without re-ingesting.
* **Postgres + dbt + Metabase on Docker.** Reproducible on any machine. DuckDB would be lighter, but Metabase support for it is weaker.
* **Two fact tables with different grains** (order vs order item) instead of one wide table, to avoid double counting.
* **Flags instead of filters** (`is_valid_sale`, `is_delivered`, `is_complete_month`): facts reconcile 1:1 with raw, and business rules live in one place (macro / vars).
* **Revenue = items + freight**, not payments: payments include interest and charges for canceled orders without refund records.
* **KPI tables in dbt**, so the dashboard has no hidden logic and every chart's SQL is versioned.
* **Full refresh** on every run: each raw table is truncated and reloaded with `COPY` in one transaction, so re-runs are idempotent and a failed load keeps the previous data. Tables are not dropped because the staging views depend on them.
* **Geolocation** is loaded and staged but not modeled, since no current KPI needs it.

## 9. Roadmap

* **Cohort-based retention** (e.g. % of customers who buy again within 90 days): 19% of customers made their first purchase in the last 3 months of data, which understates the overall repeat rate.
* **Incremental models** and an orchestrator (Airflow/Dagster) for scheduled loads.
* **Seller and geography analysis:** delivery time by state, seller–customer distance using geolocation.
* **Freshness and anomaly checks** (`dbt source freshness`, volume/metric thresholds) and CI running `dbt build` on every pull request.
* **Dashboard as code** (Metabase serialization/API), so the dashboard is reproducible from the repository.
* **AI-ready metrics:** a read-only API / MCP tool that answers questions like "what was revenue last month?" from the KPI tables, using parameterized queries only.
