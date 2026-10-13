-- Answers (c) repeat-purchase rate.
-- Grain: one row (overall metric).
-- Definition: % of customers (real people, customer_unique_id) with 2 or more
-- valid orders, over all customers with at least 1 valid order.
with orders_per_customer as (
    select
        customer_unique_id,
        count(*) as valid_orders
    from {{ ref('fct_orders') }}
    where is_valid_sale
      and items_count > 0
    group by customer_unique_id
)

select
    count(*)                                                 as customers,
    count(*) filter (where valid_orders >= 2)                as repeat_customers,
    round(100.0 * count(*) filter (where valid_orders >= 2) / count(*), 2) as repeat_purchase_rate_pct,
    round(avg(valid_orders), 3)                              as avg_orders_per_customer,
    max(valid_orders)                                        as max_orders_per_customer
from orders_per_customer