-- Grain: one row per customer_id.
-- NOTE: customer_id is created per order. The real person is customer_unique_id,
-- which is the key we will use for repeat-purchase metrics.
select
    customer_id,
    customer_unique_id,
    lpad(customer_zip_code_prefix, 5, '0') as customer_zip_code_prefix,
    customer_city,
    upper(customer_state)                  as customer_state
from {{ source('raw', 'customers') }}