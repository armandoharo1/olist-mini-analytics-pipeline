-- Grain: one row per real customer (customer_unique_id).
-- In the source, customer_id is created per order, so the same person can
-- have several customer_ids. Here we collapse them into one row per person.
-- Location = the address used in the customer's most recent order.
with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_orders as (
    -- one row per order, with the person behind it
    select
        customers.customer_unique_id,
        customers.customer_zip_code_prefix,
        customers.customer_city,
        customers.customer_state,
        orders.purchased_at,
        row_number() over (
            partition by customers.customer_unique_id
            order by orders.purchased_at desc, orders.order_id
        ) as recency_rank                     -- 1 = most recent order
    from customers
    inner join orders
        on customers.customer_id = orders.customer_id
),

latest_location as (
    select
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    from customer_orders
    where recency_rank = 1
),

purchase_dates as (
    select
        customer_unique_id,
        min(purchased_at) as first_purchase_at,
        max(purchased_at) as last_purchase_at
    from customer_orders
    group by customer_unique_id
)

select
    latest_location.customer_unique_id,
    latest_location.customer_zip_code_prefix,
    latest_location.customer_city,
    latest_location.customer_state,
    purchase_dates.first_purchase_at,
    purchase_dates.last_purchase_at
from latest_location
inner join purchase_dates
    on latest_location.customer_unique_id = purchase_dates.customer_unique_id