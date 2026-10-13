-- Grain: one row per reconciliation check.
-- Compares totals computed from the raw layer with the same totals from the model.
with raw_item_values as (
    select
        count(*)                                        as item_rows,
        sum(price::numeric + freight_value::numeric)    as gross_item_value
    from {{ source('raw', 'order_items') }}
),

checks as (
    select
        1 as check_id,
        'Orders: row count' as check_name,
        (select count(*) from {{ source('raw', 'orders') }})::numeric as raw_value,
        (select count(*) from {{ ref('fct_orders') }})::numeric       as model_value,
        0 as tolerance_pct,
        'raw.orders vs fct_orders' as note

    union all
    select 2, 'Order items: row count',
        (select item_rows from raw_item_values),
        (select count(*) from {{ ref('fct_order_items') }}),
        0, 'raw.order_items vs fct_order_items'

    union all
    select 3, 'Customers: distinct people',
        (select count(distinct customer_unique_id) from {{ source('raw', 'customers') }}),
        (select count(*) from {{ ref('dim_customers') }}),
        0, 'distinct customer_unique_id vs dim_customers'

    union all
    select 4, 'Products: row count',
        (select count(*) from {{ source('raw', 'products') }}),
        (select count(*) from {{ ref('dim_products') }}),
        0, 'raw.products vs dim_products'

    union all
    select 5, 'Gross item value (price + freight), all orders',
        (select gross_item_value from raw_item_values),
        (select sum(order_total) from {{ ref('fct_orders') }}),
        0, 'raw.order_items vs fct_orders.order_total'

    union all
    select 6, 'Gross item value, order-items fact',
        (select gross_item_value from raw_item_values),
        (select sum(item_total) from {{ ref('fct_order_items') }}),
        0, 'raw.order_items vs fct_order_items.item_total'

    union all
    select 7, 'Payments total, all orders',
        (select sum(payment_value::numeric) from {{ source('raw', 'order_payments') }}),
        (select sum(payment_total) from {{ ref('fct_orders') }}),
        0, 'raw.order_payments vs fct_orders.payment_total'

    union all
    select 8, 'Valid revenue: fct_orders vs fct_order_items',
        (select sum(item_total) from {{ ref('fct_order_items') }} where is_valid_sale),
        (select sum(order_total) from {{ ref('fct_orders') }} where is_valid_sale),
        0, 'both facts must agree'

    union all
    select 9, 'Valid orders: payments vs revenue',
        (select sum(payment_total) from {{ ref('fct_orders') }} where is_valid_sale),
        (select sum(order_total) from {{ ref('fct_orders') }} where is_valid_sale),
        0.5, 'installment interest and vouchers; up to 0.5% allowed'
)

select
    check_id,
    check_name,
    raw_value,
    model_value,
    model_value - raw_value                                          as difference,
    round(100 * (model_value - raw_value) / nullif(raw_value, 0), 4) as difference_pct,
    tolerance_pct,
    case
        when abs(model_value - raw_value) <= abs(raw_value) * tolerance_pct / 100 then 'OK'
        else 'FAIL'
    end                                                              as status,
    note
from checks
order by check_id
