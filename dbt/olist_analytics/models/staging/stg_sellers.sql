-- Grain: one row per seller_id.
select
    seller_id,
    lpad(seller_zip_code_prefix, 5, '0') as seller_zip_code_prefix,
    seller_city,
    upper(seller_state)                  as seller_state
from {{ source('raw', 'sellers') }}