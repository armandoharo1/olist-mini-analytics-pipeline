-- (e) On-time delivery rate by month (%) | Metabase: Line chart
select month_start, on_time_pct
from analytics_metrics.mtr_delivery_performance
where is_complete_month
order by month_start;
