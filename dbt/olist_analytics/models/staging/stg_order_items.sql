-- Grain: one row per item within an order (order_id, order_item_id).
-- An order with 3 units of the same product has 3 rows (order_item_id 1..3).
select
    order_id,
    order_item_id::int                  as order_item_id,
    product_id,
    seller_id,
    shipping_limit_date::timestamp      as shipping_limit_at,
    price::numeric(12, 2)               as item_price,
    freight_value::numeric(12, 2)       as freight_value
from {{ source('raw', 'order_items') }}