-- Staging model for raw events
-- Cleans and standardizes event data from the raw layer

SELECT
    event_id,
    user_id,
    event_type,
    page,
    CAST(timestamp AS TIMESTAMP) as event_timestamp,
    session_id,
    amount
FROM {{ source('raw', 'events') }}
WHERE event_id IS NOT NULL
