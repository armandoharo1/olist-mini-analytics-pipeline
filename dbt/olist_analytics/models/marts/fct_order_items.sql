-- Grain: one row per item sold within an order (order_id, order_item_id).
-- Every order item is kept; is_valid_sale tells whether it counts as revenue.
with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
)

select
    -- keys
    order_items.order_id,
    order_items.order_item_id,
    order_items.product_id,
    order_items.seller_id,
    customers.customer_unique_id,
    orders.purchased_at::date            as purchase_date,

    -- order context
    orders.purchased_at,
    orders.order_status,
    {{ is_valid_sale('orders.order_status') }}  as is_valid_sale,

    -- measures (BRL)
    order_items.item_price,
    order_items.freight_value,
    order_items.item_price + order_items.freight_value  as item_total
from order_items
inner join orders
    on order_items.order_id = orders.order_id
inner join customers
    on orders.customer_id = customers.customer_id