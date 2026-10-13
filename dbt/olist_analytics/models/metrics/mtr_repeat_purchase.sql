-- Question: repeat-purchase rate.
-- Grain: one row. Base: people (customer_unique_id) with at least one valid order.
-- Strict rate counts purchases on 2+ different days (same-day orders are often split checkouts).
with orders_per_customer as (
    select
        customer_unique_id,
        count(*)                       as valid_orders,
        count(distinct purchase_date)  as purchase_days
    from {{ ref('fct_orders') }}
    where is_valid_sale
      and items_count > 0
    group by customer_unique_id
)

select
    count(*)                                                                  as customers,
    count(*) filter (where valid_orders >= 2)                                 as repeat_customers,
    round(100.0 * count(*) filter (where valid_orders >= 2) / count(*), 2)    as repeat_purchase_rate_pct,
    count(*) filter (where purchase_days >= 2)                                as strict_repeat_customers,
    round(100.0 * count(*) filter (where purchase_days >= 2) / count(*), 2)   as strict_repeat_rate_pct,
    round(avg(valid_orders), 3)                                               as avg_orders_per_customer,
    max(valid_orders)                                                         as max_orders_per_customer
from orders_per_customer
