-- (e) Avg review score: on-time vs late delivery | Metabase: Bar chart
select
    case when is_late then 'Late' else 'On time' end as delivery,
    round(avg(review_score), 2)                      as avg_review_score
from analytics_marts.fct_orders
where is_delivered
group by 1
order by 1 desc;
