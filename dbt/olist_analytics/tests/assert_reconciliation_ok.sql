-- Fails if any reconciliation check is out of tolerance.
select *
from {{ ref('rpt_reconciliation') }}
where status <> 'OK'