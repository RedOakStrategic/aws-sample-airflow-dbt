"""
Lambda function to execute dbt-compiled SQL via Athena.
Executes CREATE VIEW/TABLE statements for each dbt model layer.

Note: Athena uses Glue databases as the namespace. There's no separate "schema" concept.
All tables/views are created in the same Glue database.
Identifiers with special characters (like hyphens) must be quoted with double quotes.
"""
import boto3
import json
import time
import os

athena = boto3.client('athena')

# Configuration from environment
WORKGROUP = os.environ.get('ATHENA_WORKGROUP', 'primary')
DATABASE = os.environ.get('GLUE_DATABASE', 'default')
S3_BUCKET = os.environ.get('S3_BUCKET')

# SQL for each model - compiled from dbt
# All tables/views are in the same Glue database
# Use double quotes for identifiers with special characters
MODELS = {
    'staging': {
        'stg_raw_events': {
            'materialization': 'view',
            'sql': '''
SELECT
    event_id,
    user_id,
    event_type,
    page,
    timestamp as event_timestamp,
    session_id,
    amount
FROM "{database}".events
WHERE event_id IS NOT NULL
'''
        },
        'stg_raw_users': {
            'materialization': 'view',
            'sql': '''
SELECT
    user_id,
    name as username,
    email,
    created_at,
    country
FROM "{database}".users
WHERE user_id IS NOT NULL
'''
        }
    },
    'marts': {
        'dim_users': {
            'materialization': 'iceberg',
            'sql': '''
SELECT
    user_id,
    username,
    email,
    from_iso8601_timestamp(created_at) as created_at,
    country
FROM "{database}".stg_raw_users
'''
        },
        'fct_events': {
            'materialization': 'iceberg',
            'sql': '''
WITH int_events_enriched AS (
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
    FROM "{database}".stg_raw_events e
    LEFT JOIN "{database}".stg_raw_users u
        ON e.user_id = u.user_id
)
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
FROM int_events_enriched
'''
        }
    }
}


def execute_athena_query(sql: str, wait: bool = True) -> dict:
    """Execute SQL via Athena and optionally wait for completion."""
    print(f"Executing SQL:\n{sql[:1000]}...")
    
    response = athena.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={'Database': DATABASE},
        WorkGroup=WORKGROUP
    )
    
    query_id = response['QueryExecutionId']
    print(f"Query started: {query_id}")
    
    if not wait:
        return {'QueryExecutionId': query_id, 'Status': 'RUNNING'}
    
    # Poll for completion
    max_attempts = 60  # 2 minutes max
    attempts = 0
    while attempts < max_attempts:
        result = athena.get_query_execution(QueryExecutionId=query_id)
        state = result['QueryExecution']['Status']['State']
        
        if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            if state == 'FAILED':
                reason = result['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
                raise Exception(f"Query failed: {reason}")
            return {
                'QueryExecutionId': query_id,
                'Status': state,
                'Statistics': result['QueryExecution'].get('Statistics', {})
            }
        
        time.sleep(2)
        attempts += 1
    
    raise Exception(f"Query timed out after {max_attempts * 2} seconds")


def run_staging_model(model_name: str, model_config: dict) -> dict:
    """Run a staging model as a VIEW."""
    sql_template = model_config['sql']
    sql = sql_template.format(database=DATABASE)
    
    # Drop view if exists first (Athena doesn't support CREATE OR REPLACE VIEW)
    # Use simple table name - database is set in query context
    drop_sql = f'DROP VIEW IF EXISTS {model_name}'
    try:
        execute_athena_query(drop_sql)
    except Exception as e:
        print(f"Warning dropping view: {e}")
    
    # Create view - use simple table name
    create_sql = f'''CREATE VIEW {model_name} AS
{sql}
'''
    return execute_athena_query(create_sql)


def run_marts_model(model_name: str, model_config: dict, s3_location: str) -> dict:
    """Run a marts model as an Iceberg table."""
    sql_template = model_config['sql']
    sql = sql_template.format(database=DATABASE)
    
    # For Iceberg tables, we need to drop and recreate for full refresh
    # Use simple table name - database is set in query context
    drop_sql = f'DROP TABLE IF EXISTS {model_name}'
    try:
        execute_athena_query(drop_sql)
    except Exception as e:
        print(f"Warning dropping table: {e}")
    
    # Create Iceberg table with CTAS - use simple table name
    create_sql = f'''CREATE TABLE {model_name}
WITH (
    table_type = 'ICEBERG',
    location = '{s3_location}/{model_name}/',
    is_external = false,
    format = 'PARQUET'
) AS
{sql}
'''
    return execute_athena_query(create_sql)


def run_layer(layer: str, s3_location: str) -> list:
    """Run all models in a layer."""
    if layer not in MODELS:
        raise ValueError(f"Unknown layer: {layer}")
    
    results = []
    layer_models = MODELS[layer]
    
    for model_name, model_config in layer_models.items():
        print(f"Running model: {layer}/{model_name}")
        
        if layer == 'staging':
            result = run_staging_model(model_name, model_config)
        elif layer == 'marts':
            result = run_marts_model(model_name, model_config, s3_location)
        else:
            raise ValueError(f"Unknown layer: {layer}")
        
        results.append({
            'model': model_name,
            'layer': layer,
            **result
        })
    
    return results


def lambda_handler(event, context):
    """
    Lambda handler for dbt execution.
    
    Event format:
    {
        "action": "run_layer",
        "layer": "staging" | "marts",
        "s3_location": "s3://bucket/curated"
    }
    """
    print(f"Event: {json.dumps(event)}")
    
    action = event.get('action', 'run_layer')
    layer = event.get('layer')
    s3_location = event.get('s3_location', f's3://{S3_BUCKET}/curated')
    
    try:
        if action == 'run_layer':
            if not layer:
                raise ValueError("layer is required for run_layer action")
            results = run_layer(layer, s3_location)
            return {
                'statusCode': 200,
                'body': {
                    'action': action,
                    'layer': layer,
                    'results': results,
                    'status': 'SUCCESS'
                }
            }
        else:
            raise ValueError(f"Unknown action: {action}")
    
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': {
                'action': action,
                'error': str(e),
                'status': 'FAILED'
            }
        }
