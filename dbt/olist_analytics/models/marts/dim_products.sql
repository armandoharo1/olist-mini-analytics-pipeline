-- Grain: one row per product.
-- Category fallback: English name -> Portuguese name -> 'unknown'.
with products as (
    select * from {{ ref('stg_products') }}
),

translations as (
    select * from {{ ref('stg_product_category_translation') }}
)

select
    products.product_id,
    coalesce(
        translations.product_category_name_english,
        products.product_category_name,
        'unknown'
    )                                    as category_name,
    products.product_category_name       as category_name_pt,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm,
    products.product_photos_qty
from products
left join translations
    on products.product_category_name = translations.product_category_name
