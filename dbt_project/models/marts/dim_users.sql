-- Dimension table: Users with Iceberg table configuration
-- Business-ready user dimension for analytics and reporting
{{
  config(
    materialized='table',
    table_type='iceberg',
    format='parquet',
    write_compression='snappy',
    s3_data_dir='s3://lakehouse-mvp-sandbox-data-lake/curated/dbt_dim_users/'
  )
}}

SELECT
    user_id,
    username,
    email,
    from_iso8601_timestamp(created_at) as created_at,
    country
FROM {{ ref('stg_raw_users') }}
