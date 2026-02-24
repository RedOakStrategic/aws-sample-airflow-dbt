-- Fact table: Events with Iceberg table configuration
-- Business-ready event data partitioned by event_date for efficient querying
{{
  config(
    materialized='table',
    table_type='iceberg',
    format='parquet',
    write_compression='snappy',
    partitioned_by=['date(event_date)'],
    s3_data_dir='s3://' ~ var('data_lake_bucket') ~ '/curated/fct_events/'
  )
}}

SELECT
    event_id,
    user_id,
    event_type,
    event_timestamp,
    event_date,
    event_properties,
    username,
    user_email,
    user_is_active,
    event_created_at as created_at
FROM {{ ref('int_events_enriched') }}
