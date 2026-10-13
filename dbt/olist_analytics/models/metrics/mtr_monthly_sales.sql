-- Questions:  revenue by month and AOV trend.
-- Grain: one row per month of purchase.
-- Revenue = items + freight of valid orders; AOV = revenue / orders with items.
with months as (
    select distinct month_start
    from {{ ref('dim_date') }}
    where month_start between
        (select date_trunc('month', min(purchase_date)) from {{ ref('fct_orders') }})
        and (select date_trunc('month', max(purchase_date)) from {{ ref('fct_orders') }})
),

monthly as (
    select
        date_trunc('month', purchase_date)::date  as month_start,
        count(*)                                   as orders,
        sum(order_total)                           as revenue
    from {{ ref('fct_orders') }}
    where is_valid_sale
      and items_count > 0
    group by 1
),

monthly_sales as (
    select
        months.month_start,
        coalesce(monthly.orders, 0)                           as orders,
        coalesce(monthly.revenue, 0)                          as revenue,
        round(monthly.revenue / nullif(monthly.orders, 0), 2) as aov,
        months.month_start between '{{ var("first_complete_month") }}'
                               and '{{ var("last_complete_month") }}' as is_complete_month
    from months
    left join monthly
        on months.month_start = monthly.month_start
)

select
    month_start,
    to_char(month_start, 'YYYY-MM')  as year_month,
    orders,
    revenue,
    aov,
    -- month-over-month growth, only between complete months
    case
        when is_complete_month
         and lag(is_complete_month) over (order by month_start)
        then round(
            100.0 * (revenue - lag(revenue) over (order by month_start))
            / nullif(lag(revenue) over (order by month_start), 0),
            1
        )
    end                               as revenue_growth_pct,
    is_complete_month
from monthly_sales
order by month_start
