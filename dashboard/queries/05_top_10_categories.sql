-- (d) Top 10 product categories by revenue (BRL)
select category_name, revenue
from analytics_metrics.mtr_category_sales
where revenue_rank <= 10
order by revenue_rank;
