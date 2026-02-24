-- Intermediate model: Events enriched with user information
-- This ephemeral model joins events with user data for downstream consumption

SELECT
    e.event_id,
    e.user_id,
    e.event_type,
    e.event_timestamp,
    DATE(e.event_timestamp) as event_date,
    e.event_properties,
    e.created_at as event_created_at,
    u.username,
    u.email as user_email,
    u.is_active as user_is_active,
    u.created_at as user_created_at
FROM {{ ref('stg_raw_events') }} e
LEFT JOIN {{ ref('stg_raw_users') }} u
    ON e.user_id = u.user_id
