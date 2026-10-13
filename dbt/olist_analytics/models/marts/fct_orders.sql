-- Grain: one row per order (order_id).
-- Items and payments are aggregated before joining to avoid fan-out.
-- one review (the most recent) and delivery timings.
with orders as (
    select
        *,
        -- "Delivered" needs both the status AND a delivery date:
        -- 6 canceled orders have a delivery date and 8 delivered orders do not.
        (order_status = 'delivered' and delivered_to_customer_at is not null) as is_delivered
    from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

items_per_order as (
    select
        order_id,
        count(*)            as items_count,
        sum(item_price)     as products_value,
        sum(freight_value)  as freight_value
    from {{ ref('stg_order_items') }}
    group by order_id
),

payments_per_order as (
    select
        order_id,
        count(*)            as payments_count,
        sum(payment_value)  as payment_total
    from {{ ref('stg_order_payments') }}
    group by order_id
),

latest_review as (
    -- Some orders have more than one review: keep the most recently answered one.
    select
        order_id,
        review_score
    from (
        select
            order_id,
            review_score,
            row_number() over (
                partition by order_id
                order by review_answered_at desc, review_id
            ) as review_rank
        from {{ ref('stg_order_reviews') }}
    ) as ranked
    where review_rank = 1
)

select
    -- keys
    orders.order_id,
    customers.customer_unique_id,
    orders.purchased_at::date                  as purchase_date,

    -- status
    orders.order_status,
    {{ is_valid_sale('orders.order_status') }} as is_valid_sale,

    -- timestamps (Brazil local time)
    orders.purchased_at,
    orders.approved_at,
    orders.delivered_to_customer_at,
    orders.estimated_delivery_at,

    -- money (BRL). Orders without items get 0, not NULL.
    coalesce(items_per_order.items_count, 0)        as items_count,
    coalesce(items_per_order.products_value, 0)     as products_value,
    coalesce(items_per_order.freight_value, 0)      as freight_value,
    coalesce(items_per_order.products_value, 0)
      + coalesce(items_per_order.freight_value, 0)  as order_total,    -- = revenue
    coalesce(payments_per_order.payment_total, 0)   as payment_total,  -- for reconciliation
    coalesce(payments_per_order.payments_count, 0)  as payments_count,

    -- review
    latest_review.review_score,

    -- delivery (NULL when the order was not delivered)
    orders.is_delivered,
    case when orders.is_delivered then
        round(extract(epoch from (orders.delivered_to_customer_at - orders.purchased_at)) / 86400.0, 1)
    end                                             as delivery_days,
    case when orders.is_delivered then
        orders.delivered_to_customer_at::date > orders.estimated_delivery_at::date
    end                                             as is_late
from orders
inner join customers
    on orders.customer_id = customers.customer_id
left join items_per_order
    on orders.order_id = items_per_order.order_id
left join payments_per_order
    on orders.order_id = payments_per_order.order_id
left join latest_review
    on orders.order_id = latest_review.order_id