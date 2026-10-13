-- Grain: one row per calendar day.
-- Covers the full years of the dataset (orders go from 2016-09 to 2018-10).
select
    day::date                                as date_day,
    extract(year from day)::int              as year,
    extract(quarter from day)::int           as quarter,
    extract(month from day)::int             as month,
    date_trunc('month', day)::date           as month_start,
    to_char(day, 'YYYY-MM')                  as year_month,
    extract(isodow from day)::int            as day_of_week,   -- 1 = Monday ... 7 = Sunday
    trim(to_char(day, 'Day'))                as day_name,
    extract(isodow from day) in (6, 7)       as is_weekend
from generate_series(
    '2016-01-01'::date,
    '2018-12-31'::date,
    interval '1 day'
) as day