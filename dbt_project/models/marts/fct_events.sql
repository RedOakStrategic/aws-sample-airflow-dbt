-- Fact table: Events with Iceberg table configuration
-- Business-ready event data partitioned by event_date for efficient querying
{{
  config(
    materialized='table',
    table_type='iceberg',
    format='parquet',
    write_compression='snappy',
    s3_data_dir='s3://lakehouse-mvp-sandbox-data-lake/curated/dbt_fct_events/'
  )
}}

SELECT
    event_id,
    user_id,
    event_type,
    event_timestamp,
    event_date,
    session_id,
    page,
    amount,
    username,
    user_email,
    user_country
FROM {{ ref('int_events_enriched') }}
