-- Data quality: raw vs model reconciliation
select check_name, raw_value, model_value, difference, status
from analytics_reconciliation.rpt_reconciliation
order by check_id;
