# dags/lakehouse_pipeline.py
"""
Data Lakehouse Pipeline DAG
===========================
Orchestrates the full data pipeline:
1. Step Functions: Raw data ingestion and initial processing
2. dbt: Transform data through staging -> intermediate -> marts layers
3. dbt tests: Validate data quality

The pipeline runs daily at 6 AM UTC or can be triggered manually.
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.providers.amazon.aws.operators.step_function import StepFunctionStartExecutionOperator
from airflow.providers.amazon.aws.sensors.step_function import StepFunctionExecutionSensor

# Configuration - in production, use Airflow Variables
STATE_MACHINE_ARN = 'arn:aws:states:us-east-1:088130860316:stateMachine:lakehouse-mvp-sandbox-data-pipeline'
DBT_PROJECT_PATH = '/usr/local/airflow/dbt_project'

default_args = {
    'owner': 'data-engineering',
    'depends_on_past': False,
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='lakehouse_raw_to_curated',
    default_args=default_args,
    description='Full data lakehouse pipeline: Step Functions ingestion + dbt transformations',
    schedule_interval='0 6 * * *',  # Daily at 6 AM UTC
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['lakehouse', 'production', 'dbt'],
) as dag:

    # ============================================
    # STAGE 1: Raw Data Ingestion via Step Functions
    # ============================================
    start_pipeline = StepFunctionStartExecutionOperator(
        task_id='start_step_functions_pipeline',
        state_machine_arn=STATE_MACHINE_ARN,
    )

    wait_for_ingestion = StepFunctionExecutionSensor(
        task_id='wait_for_ingestion',
        execution_arn="{{ task_instance.xcom_pull(task_ids='start_step_functions_pipeline') }}",
        poke_interval=60,
        timeout=3600,  # 1 hour timeout
    )

    # ============================================
    # STAGE 2: dbt Transformations
    # ============================================
    
    # Install dbt dependencies (packages like elementary)
    dbt_deps = BashOperator(
        task_id='dbt_deps',
        bash_command=f'cd {DBT_PROJECT_PATH} && dbt deps --profiles-dir .',
    )

    # Run staging models first (views on raw data)
    dbt_run_staging = BashOperator(
        task_id='dbt_run_staging',
        bash_command=f'cd {DBT_PROJECT_PATH} && dbt run --profiles-dir . --select staging',
    )

    # Run intermediate models (enriched data)
    dbt_run_intermediate = BashOperator(
        task_id='dbt_run_intermediate',
        bash_command=f'cd {DBT_PROJECT_PATH} && dbt run --profiles-dir . --select intermediate',
    )

    # Run mart models (business-ready Iceberg tables)
    dbt_run_marts = BashOperator(
        task_id='dbt_run_marts',
        bash_command=f'cd {DBT_PROJECT_PATH} && dbt run --profiles-dir . --select marts',
    )

    # ============================================
    # STAGE 3: Data Quality Tests
    # ============================================
    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command=f'cd {DBT_PROJECT_PATH} && dbt test --profiles-dir .',
    )

    # ============================================
    # Pipeline Dependencies
    # ============================================
    # Step Functions ingestion -> dbt transformations -> tests
    start_pipeline >> wait_for_ingestion >> dbt_deps
    dbt_deps >> dbt_run_staging >> dbt_run_intermediate >> dbt_run_marts >> dbt_test
