-- Question: delivery performance.
-- Grain: one row per month of purchase, delivered orders only.
-- On time = delivered on or before the estimated delivery date.
select
    date_trunc('month', purchase_date)::date                        as month_start,
    to_char(date_trunc('month', purchase_date), 'YYYY-MM')          as year_month,
    count(*)                                                        as delivered_orders,
    count(*) filter (where is_late)                                 as late_orders,
    round(100.0 * count(*) filter (where not is_late) / count(*), 1) as on_time_pct,
    round(avg(delivery_days), 1)                                    as avg_delivery_days,
    round(avg(review_score) filter (where not is_late), 2)          as avg_review_on_time,
    round(avg(review_score) filter (where is_late), 2)              as avg_review_late,
    date_trunc('month', purchase_date)::date
        between '{{ var("first_complete_month") }}'
            and '{{ var("last_complete_month") }}'                  as is_complete_month
from {{ ref('fct_orders') }}
where is_delivered
group by 1, 2
order by 1
