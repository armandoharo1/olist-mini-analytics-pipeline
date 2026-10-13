-- Revenue by month (BRL) | Metabase: Bar chart
select month_start, revenue
from analytics_metrics.mtr_monthly_sales
where is_complete_month
order by month_start;
