-- Staging model for raw users
-- Cleans and standardizes user data from the raw layer

SELECT
    user_id,
    name as username,
    email,
    CAST(created_at AS TIMESTAMP) as created_at,
    country
FROM {{ source('raw', 'users') }}
WHERE user_id IS NOT NULL
