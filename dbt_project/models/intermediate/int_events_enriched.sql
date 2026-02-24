-- Intermediate model: Events enriched with user information
-- This ephemeral model joins events with user data for downstream consumption

SELECT
    e.event_id,
    e.user_id,
    e.event_type,
    from_iso8601_timestamp(e.event_timestamp) as event_timestamp,
    DATE(from_iso8601_timestamp(e.event_timestamp)) as event_date,
    e.session_id,
    e.page,
    e.amount,
    u.username,
    u.email as user_email,
    u.country as user_country
FROM {{ ref('stg_raw_events') }} e
LEFT JOIN {{ ref('stg_raw_users') }} u
    ON e.user_id = u.user_id
