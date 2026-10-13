-- Average order value by month (BRL) | Metabase: Line chart
select month_start, aov
from analytics_metrics.mtr_monthly_sales
where is_complete_month
order by month_start;
