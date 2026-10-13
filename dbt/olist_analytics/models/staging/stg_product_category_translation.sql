-- Grain: one row per Portuguese category name.
select
    product_category_name,
    product_category_name_english
from {{ source('raw', 'product_category_name_translation') }}
