# dags/lakehouse_pipeline.py
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.step_function import StepFunctionStartExecutionOperator
from airflow.providers.amazon.aws.sensors.step_function import StepFunctionExecutionSensor

# Hardcoded ARN for MVP - in production use Airflow Variables
STATE_MACHINE_ARN = 'arn:aws:states:us-east-1:088130860316:stateMachine:lakehouse-mvp-sandbox-data-pipeline'

default_args = {
    'owner': 'data-engineering',
    'depends_on_past': False,
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 0,  # Step Functions handles retries
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='lakehouse_raw_to_curated',
    default_args=default_args,
    description='Orchestrate data lakehouse pipeline via Step Functions',
    schedule_interval='0 6 * * *',  # Daily at 6 AM UTC
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['lakehouse', 'production'],
) as dag:

    start_pipeline = StepFunctionStartExecutionOperator(
        task_id='start_pipeline',
        state_machine_arn=STATE_MACHINE_ARN,
    )

    wait_for_completion = StepFunctionExecutionSensor(
        task_id='wait_for_completion',
        execution_arn="{{ task_instance.xcom_pull(task_ids='start_pipeline') }}",
        poke_interval=60,
        timeout=3600,  # 1 hour timeout
    )

    start_pipeline >> wait_for_completion
