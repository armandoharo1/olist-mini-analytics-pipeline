-- Grain: one row per customer_id (one id per order; customer_unique_id is the person).
select
    customer_id,
    customer_unique_id,
    lpad(customer_zip_code_prefix, 5, '0') as customer_zip_code_prefix,
    customer_city,
    upper(customer_state)                  as customer_state
from {{ source('raw', 'customers') }}
