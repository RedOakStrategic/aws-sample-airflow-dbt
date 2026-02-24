# dags/lakehouse_pipeline.py
"""
Data Lakehouse Pipeline DAG
===========================
Orchestrates the full data pipeline via Step Functions:
1. Step Functions handles: Raw crawling → Lambda dbt transforms (Athena) → Curated crawling → Tests
2. Airflow monitors the execution and provides scheduling/alerting

Pipeline Steps (executed by Step Functions):
- RecordPipelineStart: Log execution start to DynamoDB
- StartRawCrawler: Crawl raw S3 data to Glue catalog
- RunDbtStaging: Lambda executes staging views via Athena
- RunDbtMarts: Lambda executes marts Iceberg tables via Athena
- StartCuratedCrawler: Crawl curated Iceberg tables
- RunDbtTests: Lambda runs 23+ data quality tests, records to Elementary
- RecordPipelineSuccess: Log completion to DynamoDB

The pipeline runs daily at 6 AM UTC or can be triggered manually.
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.step_function import StepFunctionStartExecutionOperator
from airflow.providers.amazon.aws.sensors.step_function import StepFunctionExecutionSensor

# Configuration - in production, use Airflow Variables
STATE_MACHINE_ARN = 'arn:aws:states:us-east-1:088130860316:stateMachine:lakehouse-mvp-sandbox-data-pipeline'

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
    description='Full data lakehouse pipeline: Step Functions orchestrates ingestion + dbt transformations',
    schedule_interval='0 6 * * *',  # Daily at 6 AM UTC
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['lakehouse', 'production', 'dbt', 'step-functions'],
) as dag:

    # ============================================
    # Start Step Functions Pipeline
    # ============================================
    # Step Functions handles the complete workflow:
    # 1. Record pipeline start in DynamoDB
    # 2. Run raw crawler (catalog raw JSON data)
    # 3. Execute dbt staging models via Lambda+Athena (views)
    # 4. Execute dbt marts models via Lambda+Athena (Iceberg tables)
    # 5. Run curated crawler (catalog Iceberg tables)
    # 6. Execute dbt tests via Lambda+Athena (23+ data quality tests)
    # 7. Record test results to Elementary table
    # 8. Record pipeline completion in DynamoDB
    
    start_pipeline = StepFunctionStartExecutionOperator(
        task_id='start_pipeline',
        state_machine_arn=STATE_MACHINE_ARN,
    )

    # ============================================
    # Wait for Pipeline Completion
    # ============================================
    wait_for_completion = StepFunctionExecutionSensor(
        task_id='wait_for_completion',
        execution_arn="{{ task_instance.xcom_pull(task_ids='start_pipeline') }}",
        poke_interval=60,  # Check every minute
        timeout=7200,  # 2 hour timeout
    )

    # ============================================
    # Pipeline Dependencies
    # ============================================
    start_pipeline >> wait_for_completion
