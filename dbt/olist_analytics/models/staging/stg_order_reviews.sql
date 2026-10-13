-- Grain: one row per (review_id, order_id).
-- review_id alone is NOT unique (the same review can be linked to several
-- orders) and some orders have more than one review. Choosing one review
-- per order is a business rule, so it is done later in the marts layer.
select
    review_id,
    order_id,
    review_score::int                   as review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date::timestamp     as review_created_at,
    review_answer_timestamp::timestamp  as review_answered_at
from {{ source('raw', 'order_reviews') }}