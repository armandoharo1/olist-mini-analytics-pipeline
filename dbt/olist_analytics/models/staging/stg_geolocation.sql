-- Grain: one row per raw geolocation record.
-- The source has ~1M rows for ~19k zip prefixes (many points per prefix).
select
    lpad(geolocation_zip_code_prefix, 5, '0') as zip_code_prefix,
    geolocation_lat::numeric                   as latitude,
    geolocation_lng::numeric                   as longitude,
    geolocation_city                           as city,
    upper(geolocation_state)                   as state
from {{ source('raw', 'geolocation') }}