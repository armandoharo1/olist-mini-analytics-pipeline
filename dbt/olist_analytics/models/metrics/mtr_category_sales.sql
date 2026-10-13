-- Answers (d) top product categories.
-- Grain: one row per product category (English name).
-- Definition: revenue = sum(item_total) = item price + freight of valid items,
-- consistent with the revenue definition used in fct_orders.
with category_sales as (
    select
        products.category_name,
        count(*)                              as items_sold,
        count(distinct items.order_id)        as orders,
        sum(items.item_price)                 as product_revenue,
        sum(items.item_total)                 as revenue
    from {{ ref('fct_order_items') }} as items
    inner join {{ ref('dim_products') }} as products
        on items.product_id = products.product_id
    where items.is_valid_sale
    group by products.category_name
)

select
    rank() over (order by revenue desc)                       as revenue_rank,
    category_name,
    items_sold,
    orders,
    product_revenue,
    revenue,
    round(100.0 * revenue / sum(revenue) over (), 2)          as revenue_share_pct
from category_sales
order by revenue_rank