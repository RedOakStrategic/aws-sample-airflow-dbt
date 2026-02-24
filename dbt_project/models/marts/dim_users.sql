-- Dimension table: Users with Iceberg table configuration
-- Business-ready user dimension for analytics and reporting
{{
  config(
    materialized='table',
    table_type='iceberg',
    format='parquet',
    write_compression='snappy',
    s3_data_dir='s3://' ~ var('data_lake_bucket') ~ '/curated/dim_users/'
  )
}}

SELECT
    user_id,
    username,
    email,
    is_active,
    created_at,
    updated_at
FROM {{ ref('stg_raw_users') }}
