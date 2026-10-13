-- Answers (c) repeat-purchase rate.
-- Grain: one row (overall metric).
-- Definitions (over customers = real people with at least 1 valid order):
--   repeat_purchase_rate_pct : % of customers with 2+ valid orders
--   strict_repeat_rate_pct   : % of customers who bought on 2+ DIFFERENT days.
--     ~29% of "repeat" customers placed all their orders on the same day
--     (likely one shopping session split into several orders), so this
--     stricter version measures real returning customers.
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