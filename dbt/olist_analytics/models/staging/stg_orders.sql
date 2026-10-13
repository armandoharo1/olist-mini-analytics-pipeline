-- Grain: one row per order (order_id).
-- Source timestamps have no time zone. They are Brazilian local time
-- (America/Sao_Paulo); we keep them as plain timestamps and document it.
select
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp::timestamp       as purchased_at,
    order_approved_at::timestamp              as approved_at,
    order_delivered_carrier_date::timestamp   as delivered_to_carrier_at,
    order_delivered_customer_date::timestamp  as delivered_to_customer_at,
    order_estimated_delivery_date::timestamp  as estimated_delivery_at
from {{ source('raw', 'orders') }}