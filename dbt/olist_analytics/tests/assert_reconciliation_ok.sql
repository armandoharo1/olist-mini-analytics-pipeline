-- Fails (returns rows) if any reconciliation check is not OK.
select *
from {{ ref('rpt_reconciliation') }}
where status <> 'OK'