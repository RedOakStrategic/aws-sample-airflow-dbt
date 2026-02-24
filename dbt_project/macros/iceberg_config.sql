-- Reusable Iceberg table configuration macros
-- Provides consistent Iceberg table properties across all mart models

{#
  Macro: iceberg_config
  Description: Returns common Iceberg table configuration for mart models.
               Call this macro within a model's config block to apply
               standardized Iceberg settings.
  
  Parameters:
    - table_name: Name of the table (used for s3_data_dir path)
    - partitioned_by: Optional partition specification (e.g., ['date(event_date)'])
  
  Usage:
    {{
      config(
        **iceberg_config('fct_events', partitioned_by=['date(event_date)'])
      )
    }}
#}
{% macro iceberg_config(table_name, partitioned_by=none) %}
  {{
    return({
      'materialized': 'table',
      'table_type': 'iceberg',
      'format': 'parquet',
      'write_compression': 'snappy',
      'partitioned_by': partitioned_by,
      's3_data_dir': get_iceberg_s3_path(table_name)
    })
  }}
{% endmacro %}


{#
  Macro: get_iceberg_s3_path
  Description: Generates the S3 data directory path for Iceberg tables.
               Constructs path using the data_lake_bucket variable and
               places tables in the curated layer.
  
  Parameters:
    - table_name: Name of the table to generate path for
  
  Returns:
    S3 path in format: s3://{data_lake_bucket}/curated/{table_name}/
  
  Usage:
    {{ get_iceberg_s3_path('fct_events') }}
    -- Returns: s3://my-bucket/curated/fct_events/
#}
{% macro get_iceberg_s3_path(table_name) %}
  {{- return('s3://' ~ var('data_lake_bucket') ~ '/curated/' ~ table_name ~ '/') -}}
{% endmacro %}


{#
  Macro: iceberg_table_properties
  Description: Returns additional Iceberg table properties for advanced
               configuration scenarios. Can be used alongside iceberg_config
               for fine-grained control.
  
  Parameters:
    - vacuum_min_snapshots: Minimum snapshots to retain (default: 5)
    - vacuum_max_snapshot_age_seconds: Max age of snapshots in seconds (default: 432000 = 5 days)
  
  Usage:
    {{
      config(
        **iceberg_config('my_table'),
        table_properties=iceberg_table_properties()
      )
    }}
#}
{% macro iceberg_table_properties(vacuum_min_snapshots=5, vacuum_max_snapshot_age_seconds=432000) %}
  {{
    return({
      'vacuum_min_snapshots_to_keep': vacuum_min_snapshots,
      'vacuum_max_snapshot_age_seconds': vacuum_max_snapshot_age_seconds
    })
  }}
{% endmacro %}
