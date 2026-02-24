"""
Lambda function to execute dbt tests via Athena and record results to Elementary.
Runs test SQL queries and inserts results into elementary_test_results table.
"""
import boto3
import json
import time
import os
import uuid
from datetime import datetime

athena = boto3.client('athena')

# Configuration from environment
WORKGROUP = os.environ.get('ATHENA_WORKGROUP', 'primary')
DATABASE = os.environ.get('GLUE_DATABASE', 'default')
S3_BUCKET = os.environ.get('S3_BUCKET')

# Test definitions - compiled from dbt schema tests
# Each test returns rows that FAIL the test (empty result = pass)
TESTS = {
    'staging': [
        {
            'name': 'not_null_stg_raw_events_event_id',
            'model': 'stg_raw_events',
            'column': 'event_id',
            'test_type': 'not_null',
            'sql': 'SELECT event_id FROM "{database}".stg_raw_events WHERE event_id IS NULL'
        },
        {
            'name': 'unique_stg_raw_events_event_id',
            'model': 'stg_raw_events',
            'column': 'event_id',
            'test_type': 'unique',
            'sql': '''
SELECT event_id, COUNT(*) as cnt
FROM "{database}".stg_raw_events
GROUP BY event_id
HAVING COUNT(*) > 1
'''
        },
        {
            'name': 'not_null_stg_raw_events_user_id',
            'model': 'stg_raw_events',
            'column': 'user_id',
            'test_type': 'not_null',
            'sql': 'SELECT user_id FROM "{database}".stg_raw_events WHERE user_id IS NULL'
        },
        {
            'name': 'not_null_stg_raw_events_event_type',
            'model': 'stg_raw_events',
            'column': 'event_type',
            'test_type': 'not_null',
            'sql': 'SELECT event_type FROM "{database}".stg_raw_events WHERE event_type IS NULL'
        },
        {
            'name': 'not_null_stg_raw_events_event_timestamp',
            'model': 'stg_raw_events',
            'column': 'event_timestamp',
            'test_type': 'not_null',
            'sql': 'SELECT event_timestamp FROM "{database}".stg_raw_events WHERE event_timestamp IS NULL'
        },
        {
            'name': 'not_null_stg_raw_users_user_id',
            'model': 'stg_raw_users',
            'column': 'user_id',
            'test_type': 'not_null',
            'sql': 'SELECT user_id FROM "{database}".stg_raw_users WHERE user_id IS NULL'
        },
        {
            'name': 'unique_stg_raw_users_user_id',
            'model': 'stg_raw_users',
            'column': 'user_id',
            'test_type': 'unique',
            'sql': '''
SELECT user_id, COUNT(*) as cnt
FROM "{database}".stg_raw_users
GROUP BY user_id
HAVING COUNT(*) > 1
'''
        },
        {
            'name': 'not_null_stg_raw_users_username',
            'model': 'stg_raw_users',
            'column': 'username',
            'test_type': 'not_null',
            'sql': 'SELECT username FROM "{database}".stg_raw_users WHERE username IS NULL'
        },
        {
            'name': 'not_null_stg_raw_users_email',
            'model': 'stg_raw_users',
            'column': 'email',
            'test_type': 'not_null',
            'sql': 'SELECT email FROM "{database}".stg_raw_users WHERE email IS NULL'
        },
        {
            'name': 'unique_stg_raw_users_email',
            'model': 'stg_raw_users',
            'column': 'email',
            'test_type': 'unique',
            'sql': '''
SELECT email, COUNT(*) as cnt
FROM "{database}".stg_raw_users
GROUP BY email
HAVING COUNT(*) > 1
'''
        },
    ],
    'marts': [
        {
            'name': 'not_null_fct_events_event_id',
            'model': 'fct_events',
            'column': 'event_id',
            'test_type': 'not_null',
            'sql': 'SELECT event_id FROM "{database}".fct_events WHERE event_id IS NULL'
        },
        {
            'name': 'unique_fct_events_event_id',
            'model': 'fct_events',
            'column': 'event_id',
            'test_type': 'unique',
            'sql': '''
SELECT event_id, COUNT(*) as cnt
FROM "{database}".fct_events
GROUP BY event_id
HAVING COUNT(*) > 1
'''
        },
        {
            'name': 'not_null_fct_events_user_id',
            'model': 'fct_events',
            'column': 'user_id',
            'test_type': 'not_null',
            'sql': 'SELECT user_id FROM "{database}".fct_events WHERE user_id IS NULL'
        },
        {
            'name': 'not_null_fct_events_event_type',
            'model': 'fct_events',
            'column': 'event_type',
            'test_type': 'not_null',
            'sql': 'SELECT event_type FROM "{database}".fct_events WHERE event_type IS NULL'
        },
        {
            'name': 'accepted_values_fct_events_event_type',
            'model': 'fct_events',
            'column': 'event_type',
            'test_type': 'accepted_values',
            'sql': '''
SELECT event_type
FROM "{database}".fct_events
WHERE event_type NOT IN ('page_view', 'click', 'purchase', 'signup', 'login', 'logout')
'''
        },
        {
            'name': 'not_null_fct_events_event_timestamp',
            'model': 'fct_events',
            'column': 'event_timestamp',
            'test_type': 'not_null',
            'sql': 'SELECT event_timestamp FROM "{database}".fct_events WHERE event_timestamp IS NULL'
        },
        {
            'name': 'not_null_fct_events_event_date',
            'model': 'fct_events',
            'column': 'event_date',
            'test_type': 'not_null',
            'sql': 'SELECT event_date FROM "{database}".fct_events WHERE event_date IS NULL'
        },
        {
            'name': 'not_null_dim_users_user_id',
            'model': 'dim_users',
            'column': 'user_id',
            'test_type': 'not_null',
            'sql': 'SELECT user_id FROM "{database}".dim_users WHERE user_id IS NULL'
        },
        {
            'name': 'unique_dim_users_user_id',
            'model': 'dim_users',
            'column': 'user_id',
            'test_type': 'unique',
            'sql': '''
SELECT user_id, COUNT(*) as cnt
FROM "{database}".dim_users
GROUP BY user_id
HAVING COUNT(*) > 1
'''
        },
        {
            'name': 'not_null_dim_users_username',
            'model': 'dim_users',
            'column': 'username',
            'test_type': 'not_null',
            'sql': 'SELECT username FROM "{database}".dim_users WHERE username IS NULL'
        },
        {
            'name': 'not_null_dim_users_email',
            'model': 'dim_users',
            'column': 'email',
            'test_type': 'not_null',
            'sql': 'SELECT email FROM "{database}".dim_users WHERE email IS NULL'
        },
        {
            'name': 'unique_dim_users_email',
            'model': 'dim_users',
            'column': 'email',
            'test_type': 'unique',
            'sql': '''
SELECT email, COUNT(*) as cnt
FROM "{database}".dim_users
GROUP BY email
HAVING COUNT(*) > 1
'''
        },
        {
            'name': 'not_null_dim_users_created_at',
            'model': 'dim_users',
            'column': 'created_at',
            'test_type': 'not_null',
            'sql': 'SELECT created_at FROM "{database}".dim_users WHERE created_at IS NULL'
        },
    ]
}


def execute_athena_query(sql: str, wait: bool = True) -> dict:
    """Execute SQL via Athena and optionally wait for completion."""
    print(f"Executing SQL:\n{sql[:500]}...")
    
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
    max_attempts = 60
    attempts = 0
    while attempts < max_attempts:
        result = athena.get_query_execution(QueryExecutionId=query_id)
        state = result['QueryExecution']['Status']['State']
        
        if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            return {
                'QueryExecutionId': query_id,
                'Status': state,
                'Statistics': result['QueryExecution'].get('Statistics', {}),
                'StateChangeReason': result['QueryExecution']['Status'].get('StateChangeReason')
            }
        
        time.sleep(2)
        attempts += 1
    
    raise Exception(f"Query timed out after {max_attempts * 2} seconds")


def get_query_result_count(query_id: str) -> int:
    """Get the number of rows returned by a query."""
    try:
        result = athena.get_query_results(QueryExecutionId=query_id, MaxResults=10)
        rows = result.get('ResultSet', {}).get('Rows', [])
        # First row is header, so subtract 1
        return max(0, len(rows) - 1)
    except Exception as e:
        print(f"Error getting query results: {e}")
        return 0


def run_test(test_config: dict, invocation_id: str) -> dict:
    """Run a single test and return the result."""
    test_name = test_config['name']
    sql = test_config['sql'].format(database=DATABASE)
    
    start_time = datetime.utcnow()
    
    try:
        result = execute_athena_query(sql)
        
        if result['Status'] == 'SUCCEEDED':
            # Get number of failing rows
            failures = get_query_result_count(result['QueryExecutionId'])
            status = 'pass' if failures == 0 else 'fail'
        else:
            status = 'error'
            failures = 0
        
        end_time = datetime.utcnow()
        execution_time = (end_time - start_time).total_seconds()
        
        return {
            'test_name': test_name,
            'model': test_config['model'],
            'column': test_config['column'],
            'test_type': test_config['test_type'],
            'status': status,
            'failures': failures,
            'execution_time': execution_time,
            'query_id': result['QueryExecutionId'],
            'invocation_id': invocation_id,
            'executed_at': start_time.strftime('%Y-%m-%d %H:%M:%S')
        }
    
    except Exception as e:
        end_time = datetime.utcnow()
        return {
            'test_name': test_name,
            'model': test_config['model'],
            'column': test_config['column'],
            'test_type': test_config['test_type'],
            'status': 'error',
            'failures': 0,
            'execution_time': (end_time - start_time).total_seconds(),
            'error': str(e),
            'invocation_id': invocation_id,
            'executed_at': start_time.strftime('%Y-%m-%d %H:%M:%S')
        }


def record_to_elementary(results: list, invocation_id: str) -> dict:
    """Insert test results into Elementary's test_results table.
    
    Elementary table schema (28 columns):
    id, data_issue_id, test_execution_id, test_unique_id, model_unique_id,
    invocation_id, detected_at, created_at, database_name, schema_name,
    table_name, column_name, test_type, test_sub_type, test_results_description,
    owners, tags, test_results_query, other, test_name, test_params,
    severity, status, failures, test_short_name, test_alias, result_rows, failed_row_count
    """
    if not results:
        return {'status': 'no_results'}
    
    # Build INSERT statement for elementary_test_results with all columns
    values = []
    for r in results:
        # Escape single quotes in strings
        test_name = r['test_name'].replace("'", "''")
        model = r['model'].replace("'", "''")
        column = r.get('column', '').replace("'", "''") if r.get('column') else ''
        test_type = r['test_type'].replace("'", "''")
        status = r['status']
        failures = r.get('failures', 0)
        executed_at = r['executed_at']
        test_unique_id = f"test.lakehouse.{test_name}"
        model_unique_id = f"model.lakehouse.{model}"
        
        # Build value tuple matching all 28 columns
        values.append(f"""(
            '{str(uuid.uuid4())}',
            NULL,
            '{str(uuid.uuid4())}',
            '{test_unique_id}',
            '{model_unique_id}',
            '{invocation_id}',
            TIMESTAMP '{executed_at}',
            TIMESTAMP '{executed_at}',
            '{DATABASE}',
            'public',
            '{model}',
            '{column}',
            '{test_type}',
            NULL,
            '{status}: {failures} failures',
            NULL,
            NULL,
            NULL,
            NULL,
            '{test_name}',
            NULL,
            'ERROR',
            '{status}',
            {failures},
            '{test_name}',
            '{test_name}',
            NULL,
            {failures}
        )""")
    
    # Insert into elementary_test_results with all columns
    insert_sql = f"""
INSERT INTO "{DATABASE}".elementary_test_results (
    id,
    data_issue_id,
    test_execution_id,
    test_unique_id,
    model_unique_id,
    invocation_id,
    detected_at,
    created_at,
    database_name,
    schema_name,
    table_name,
    column_name,
    test_type,
    test_sub_type,
    test_results_description,
    owners,
    tags,
    test_results_query,
    other,
    test_name,
    test_params,
    severity,
    status,
    failures,
    test_short_name,
    test_alias,
    result_rows,
    failed_row_count
)
VALUES {', '.join(values)}
"""
    
    try:
        result = execute_athena_query(insert_sql)
        return {'status': 'recorded', 'query_id': result['QueryExecutionId']}
    except Exception as e:
        print(f"Error recording to Elementary: {e}")
        return {'status': 'error', 'error': str(e)}


def run_tests(layer: str = None) -> dict:
    """Run all tests for specified layer or all layers."""
    invocation_id = str(uuid.uuid4())
    all_results = []
    
    layers_to_run = [layer] if layer else list(TESTS.keys())
    
    for test_layer in layers_to_run:
        if test_layer not in TESTS:
            continue
        
        print(f"Running tests for layer: {test_layer}")
        for test_config in TESTS[test_layer]:
            print(f"Running test: {test_config['name']}")
            result = run_test(test_config, invocation_id)
            all_results.append(result)
            print(f"  Result: {result['status']} (failures: {result.get('failures', 0)})")
    
    # Record results to Elementary
    elementary_result = record_to_elementary(all_results, invocation_id)
    
    # Summary
    passed = sum(1 for r in all_results if r['status'] == 'pass')
    failed = sum(1 for r in all_results if r['status'] == 'fail')
    errors = sum(1 for r in all_results if r['status'] == 'error')
    
    return {
        'invocation_id': invocation_id,
        'total': len(all_results),
        'passed': passed,
        'failed': failed,
        'errors': errors,
        'results': all_results,
        'elementary': elementary_result
    }


def lambda_handler(event, context):
    """
    Lambda handler for dbt test execution.
    
    Event format:
    {
        "action": "run_tests",
        "layer": "staging" | "marts" | null (all)
    }
    """
    print(f"Event: {json.dumps(event)}")
    
    action = event.get('action', 'run_tests')
    layer = event.get('layer')
    
    try:
        if action == 'run_tests':
            results = run_tests(layer)
            
            # Determine overall status
            if results['errors'] > 0:
                status_code = 500
                status = 'ERROR'
            elif results['failed'] > 0:
                status_code = 200  # Tests ran successfully, some failed
                status = 'TESTS_FAILED'
            else:
                status_code = 200
                status = 'SUCCESS'
            
            return {
                'statusCode': status_code,
                'body': {
                    'action': action,
                    'layer': layer,
                    'status': status,
                    'summary': {
                        'total': results['total'],
                        'passed': results['passed'],
                        'failed': results['failed'],
                        'errors': results['errors']
                    },
                    'invocation_id': results['invocation_id'],
                    'elementary': results['elementary']
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
