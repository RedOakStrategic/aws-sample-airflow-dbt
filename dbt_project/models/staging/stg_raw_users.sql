-- Staging model for raw users
-- Cleans and standardizes user data from the raw layer

SELECT
    user_id,
    name as username,
    email,
    created_at,
    country
FROM {{ source('raw', 'users') }}
WHERE user_id IS NOT NULL
