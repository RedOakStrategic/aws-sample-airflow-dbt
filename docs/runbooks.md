# Operational Runbooks

This document provides step-by-step guides for common operational tasks in the AWS Data Lakehouse.

## Table of Contents

- [Pipeline Operations](#pipeline-operations)
- [Glue Crawler Operations](#glue-crawler-operations)
- [MWAA Operations](#mwaa-operations)
- [dbt Operations](#dbt-operations)
- [Troubleshooting](#troubleshooting)

---

## Pipeline Operations

### Manually Trigger a Pipeline Run

**Via AWS Console:**
1. Navigate to AWS Step Functions console
2. Select the `lakehouse-{env}-data-pipeline` state machine
3. Click "Start execution"
4. Enter input JSON:
   ```json
   {
     "triggered_by": "manual",
     "execution_date": "2024-01-15"
   }
   ```
5. Click "Start execution"

**Via AWS CLI:**
```bash
# Start a new execution
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:ACCOUNT_ID:stateMachine:lakehouse-sandbox-data-pipeline \
  --input '{"triggered_by": "manual", "execution_date": "2024-01-15"}'
```

### Check Pipeline Status

**Via AWS Console:**
1. Navigate to Step Functions console
2. Select the state machine
3. View "Executions" tab for recent runs
4. Click on an execution to see detailed state transitions

**Via AWS CLI:**
```bash
# List recent executions
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:us-east-1:ACCOUNT_ID:stateMachine:lakehouse-sandbox-data-pipeline \
  --max-results 10

# Get execution details
aws stepfunctions describe-execution \
  --execution-arn arn:aws:states:us-east-1:ACCOUNT_ID:execution:lakehouse-sandbox-data-pipeline:EXECUTION_ID

# Get execution history (state transitions)
aws stepfunctions get-execution-history \
  --execution-arn arn:aws:states:us-east-1:ACCOUNT_ID:execution:lakehouse-sandbox-data-pipeline:EXECUTION_ID
```

**Via DynamoDB (Pipeline Metadata):**
```bash
# Query pipeline runs by date
aws dynamodb query \
  --table-name lakehouse-sandbox-pipeline-metadata \
  --key-condition-expression "pipeline_name = :name" \
  --expression-attribute-values '{":name": {"S": "raw_to_curated"}}' \
  --scan-index-forward false \
  --limit 10
```

### Cancel a Running Pipeline

**Via AWS Console:**
1. Navigate to Step Functions console
2. Select the running execution
3. Click "Stop execution"
4. Choose stop reason: "Abort" (immediate) or "Stop" (graceful)

**Via AWS CLI:**
```bash
# Stop execution (allows cleanup)
aws stepfunctions stop-execution \
  --execution-arn arn:aws:states:us-east-1:ACCOUNT_ID:execution:lakehouse-sandbox-data-pipeline:EXECUTION_ID \
  --cause "Manual cancellation - reason here"
```

---

## Glue Crawler Operations

### Manually Run a Crawler

**Via AWS Console:**
1. Navigate to AWS Glue console
2. Select "Crawlers" from the left menu
3. Select the crawler (e.g., `lakehouse-sandbox-raw-crawler`)
4. Click "Run crawler"

**Via AWS CLI:**
```bash
# Start the raw layer crawler
aws glue start-crawler --name lakehouse-sandbox-raw-crawler

# Start the processed layer crawler
aws glue start-crawler --name lakehouse-sandbox-processed-crawler

# Start the curated layer crawler
aws glue start-crawler --name lakehouse-sandbox-curated-crawler
```

### Check Crawler Status

**Via AWS Console:**
1. Navigate to Glue console → Crawlers
2. View the "Last run" and "Status" columns
3. Click on crawler name for detailed run history

**Via AWS CLI:**
```bash
# Get crawler status
aws glue get-crawler --name lakehouse-sandbox-raw-crawler

# Get last crawler run details
aws glue get-crawler-metrics --crawler-name-list lakehouse-sandbox-raw-crawler
```

**Expected output fields:**
- `State`: READY, RUNNING, STOPPING
- `LastCrawl.Status`: SUCCEEDED, FAILED, CANCELLED
- `LastCrawl.LogGroup`: CloudWatch log group for debugging

### Troubleshoot Crawler Failures

**Step 1: Check crawler run logs**
```bash
# Get the log group from crawler details
aws glue get-crawler --name lakehouse-sandbox-raw-crawler --query 'Crawler.LastCrawl.LogGroup'

# View recent log events
aws logs filter-log-events \
  --log-group-name /aws-glue/crawlers \
  --log-stream-name-prefix lakehouse-sandbox-raw-crawler \
  --limit 50
```

**Step 2: Common issues and solutions**

| Issue | Cause | Solution |
|-------|-------|----------|
| Access Denied | IAM permissions | Verify crawler role has S3 read access |
| No tables created | Empty S3 prefix | Check data exists in target prefix |
| Schema mismatch | Inconsistent file formats | Ensure consistent schema across files |
| Crawler stuck | Large dataset | Increase crawler timeout or use sampling |

**Step 3: Reset crawler if stuck**
```bash
# Stop the crawler
aws glue stop-crawler --name lakehouse-sandbox-raw-crawler

# Wait for READY state, then restart
aws glue start-crawler --name lakehouse-sandbox-raw-crawler
```

---

## MWAA Operations

### Access Airflow UI

**Via AWS Console:**
1. Navigate to Amazon MWAA console
2. Select the environment `lakehouse-{env}-mwaa`
3. Click "Open Airflow UI"
4. Authenticate with your AWS credentials (federated login)

**Via AWS CLI (get URL):**
```bash
# Get the Airflow web server URL
aws mwaa get-environment --name lakehouse-sandbox-mwaa --query 'Environment.WebserverUrl'

# Create a web login token
aws mwaa create-web-login-token --name lakehouse-sandbox-mwaa
```

### Trigger a DAG Manually

**Via Airflow UI:**
1. Open Airflow UI
2. Find the DAG (e.g., `lakehouse_raw_to_curated`)
3. Click the "Play" button (trigger icon)
4. Optionally provide configuration JSON
5. Click "Trigger"

**Via AWS CLI:**
```bash
# Trigger DAG with default config
aws mwaa create-cli-token --name lakehouse-sandbox-mwaa

# Use the token to call Airflow CLI
# Note: Requires setting up MWAA CLI access
curl -X POST "https://{webserver-url}/aws_mwaa/cli" \
  -H "Authorization: Bearer {cli-token}" \
  -H "Content-Type: application/json" \
  -d '{"command": "dags trigger lakehouse_raw_to_curated"}'
```

### Check DAG Logs

**Via Airflow UI:**
1. Open Airflow UI
2. Click on the DAG name
3. Select a DAG run (by date)
4. Click on a task instance
5. Click "Log" to view task logs

**Via CloudWatch:**
```bash
# List MWAA log groups
aws logs describe-log-groups --log-group-name-prefix airflow-lakehouse-sandbox

# View DAG processor logs
aws logs filter-log-events \
  --log-group-name airflow-lakehouse-sandbox-mwaa-DAGProcessing \
  --limit 50

# View task logs
aws logs filter-log-events \
  --log-group-name airflow-lakehouse-sandbox-mwaa-Task \
  --filter-pattern "lakehouse_raw_to_curated" \
  --limit 50
```

### Update DAGs

**Step 1: Upload new DAG files to S3**
```bash
# Sync local DAGs to S3
aws s3 sync ./dags/ s3://lakehouse-sandbox-mwaa-dags/dags/ \
  --exclude "*.pyc" \
  --exclude "__pycache__/*"
```

**Step 2: Verify DAG sync**
```bash
# List DAGs in S3
aws s3 ls s3://lakehouse-sandbox-mwaa-dags/dags/
```

**Step 3: Wait for Airflow to pick up changes**
- DAGs are synced every 30 seconds by default
- Check Airflow UI for DAG parsing errors
- View DAG processor logs if DAG doesn't appear

**Step 4: Validate DAG (optional)**
```bash
# Use MWAA CLI to test DAG
aws mwaa create-cli-token --name lakehouse-sandbox-mwaa
# Then call: dags test lakehouse_raw_to_curated 2024-01-15
```

---

## dbt Operations

### Run Specific Models

```bash
# Navigate to dbt project
cd dbt_project

# Run a single model
dbt run --select stg_raw_events

# Run a model and its dependencies
dbt run --select +fct_events

# Run a model and its dependents
dbt run --select fct_events+

# Run all models in a directory
dbt run --select staging.*

# Run all mart models
dbt run --select marts.*

# Run with full refresh (rebuild from scratch)
dbt run --select fct_events --full-refresh
```

### Run Tests

```bash
# Run all tests
dbt test

# Run tests for specific model
dbt test --select fct_events

# Run only schema tests
dbt test --select test_type:schema

# Run only data tests
dbt test --select test_type:data

# Run source freshness tests
dbt source freshness
```

### Debug Failed Models

**Step 1: Check compilation**
```bash
# Compile model to see generated SQL
dbt compile --select fct_events

# View compiled SQL
cat target/compiled/lakehouse_mvp/models/marts/fct_events.sql
```

**Step 2: Run with verbose logging**
```bash
dbt run --select fct_events --debug
```

**Step 3: Test SQL directly in Athena**
1. Copy compiled SQL from `target/compiled/`
2. Open Athena console
3. Run the query to see detailed error messages

**Step 4: Check dbt logs**
```bash
# View recent logs
cat logs/dbt.log | tail -100

# Search for errors
grep -i "error" logs/dbt.log
```

**Common dbt issues:**

| Issue | Cause | Solution |
|-------|-------|----------|
| Table not found | Missing dependency | Run upstream models first |
| Permission denied | IAM role | Check Athena workgroup permissions |
| Iceberg error | Table format | Verify Iceberg configuration |
| Timeout | Large dataset | Optimize query or increase timeout |

---

## Troubleshooting

### Pipeline Stuck in RUNNING State

**Symptoms:**
- Step Functions execution shows RUNNING for extended period
- No state transitions in execution history

**Diagnosis:**
```bash
# Check current state
aws stepfunctions describe-execution \
  --execution-arn {execution-arn} \
  --query 'status'

# Get execution history to find stuck state
aws stepfunctions get-execution-history \
  --execution-arn {execution-arn} \
  --reverse-order \
  --max-results 5
```

**Resolution:**

1. **If stuck on crawler wait:**
   ```bash
   # Check crawler status
   aws glue get-crawler --name lakehouse-sandbox-raw-crawler
   
   # If crawler is stuck, stop and restart
   aws glue stop-crawler --name lakehouse-sandbox-raw-crawler
   ```

2. **If stuck on Athena query:**
   ```bash
   # List running queries
   aws athena list-query-executions --work-group lakehouse-sandbox-workgroup
   
   # Cancel stuck query
   aws athena stop-query-execution --query-execution-id {query-id}
   ```

3. **Force stop the execution:**
   ```bash
   aws stepfunctions stop-execution \
     --execution-arn {execution-arn} \
     --cause "Manual intervention - stuck execution"
   ```

### Crawler Not Finding New Data

**Symptoms:**
- Crawler runs successfully but no new tables/partitions
- Table row counts don't reflect new data

**Diagnosis:**
```bash
# Verify data exists in S3
aws s3 ls s3://lakehouse-sandbox-data-lake/raw/ --recursive | head -20

# Check crawler target path
aws glue get-crawler --name lakehouse-sandbox-raw-crawler \
  --query 'Crawler.Targets.S3Targets'
```

**Resolution:**

1. **Verify S3 path matches crawler target:**
   - Crawler targets must match exact S3 prefix
   - Check for trailing slashes in configuration

2. **Check file format compatibility:**
   ```bash
   # Verify files are in supported format (Parquet, JSON, CSV)
   aws s3 ls s3://lakehouse-sandbox-data-lake/raw/events/ | head -5
   ```

3. **Force schema update:**
   ```bash
   # Delete existing table and re-crawl
   aws glue delete-table \
     --database-name lakehouse_sandbox_lakehouse \
     --name raw_events
   
   aws glue start-crawler --name lakehouse-sandbox-raw-crawler
   ```

4. **Check exclusion patterns:**
   - Verify crawler exclusions aren't filtering out new files
   - Review crawler configuration in Glue console

### Athena Query Timeout

**Symptoms:**
- Queries fail with timeout error
- Long-running queries cancelled

**Diagnosis:**
```bash
# Check query execution details
aws athena get-query-execution --query-execution-id {query-id}

# View workgroup limits
aws athena get-work-group --work-group lakehouse-sandbox-workgroup
```

**Resolution:**

1. **Optimize the query:**
   - Add partition filters to reduce data scanned
   - Use `LIMIT` for exploratory queries
   - Select only required columns

2. **Check data size:**
   ```bash
   # Check table size
   aws s3 ls s3://lakehouse-sandbox-data-lake/curated/fct_events/ --recursive --summarize
   ```

3. **Increase workgroup timeout:**
   ```bash
   aws athena update-work-group \
     --work-group lakehouse-sandbox-workgroup \
     --configuration-updates "EnforceWorkGroupConfiguration=true,BytesScannedCutoffPerQuery=21474836480"
   ```

4. **Use Iceberg time travel for debugging:**
   ```sql
   -- Query historical snapshot to compare performance
   SELECT * FROM fct_events 
   FOR TIMESTAMP AS OF TIMESTAMP '2024-01-01 00:00:00'
   LIMIT 100;
   ```

### dbt Model Failures

**Symptoms:**
- dbt run fails with error
- Model doesn't materialize in Athena

**Diagnosis:**
```bash
# Run with debug output
dbt run --select {model_name} --debug 2>&1 | tee dbt_debug.log

# Check compiled SQL
cat target/compiled/lakehouse_mvp/models/marts/{model_name}.sql
```

**Resolution:**

1. **Schema mismatch:**
   ```bash
   # Check source schema
   dbt run-operation get_columns_in_relation --args '{"relation": "ref(\"stg_raw_events\")"}'
   
   # Update model to match schema
   ```

2. **Iceberg table issues:**
   ```sql
   -- Drop and recreate table
   DROP TABLE IF EXISTS curated.fct_events;
   ```
   ```bash
   dbt run --select fct_events --full-refresh
   ```

3. **Permission errors:**
   - Verify Athena workgroup has write access to S3 curated prefix
   - Check IAM role attached to Athena

4. **Dependency failures:**
   ```bash
   # Run upstream models first
   dbt run --select +{model_name}
   
   # Check dependency graph
   dbt docs generate
   dbt docs serve
   ```

### DynamoDB Metadata Query Issues

**Symptoms:**
- Cannot find pipeline execution records
- Query returns empty results

**Diagnosis:**
```bash
# Scan table to verify data exists
aws dynamodb scan \
  --table-name lakehouse-sandbox-pipeline-metadata \
  --limit 5

# Check table schema
aws dynamodb describe-table \
  --table-name lakehouse-sandbox-pipeline-metadata
```

**Resolution:**

1. **Verify key format:**
   ```bash
   # Query with correct key format
   aws dynamodb query \
     --table-name lakehouse-sandbox-pipeline-metadata \
     --key-condition-expression "pipeline_name = :name AND execution_date = :date" \
     --expression-attribute-values '{
       ":name": {"S": "raw_to_curated"},
       ":date": {"S": "2024-01-15"}
     }'
   ```

2. **Use GSI for status queries:**
   ```bash
   aws dynamodb query \
     --table-name lakehouse-sandbox-pipeline-metadata \
     --index-name status-index \
     --key-condition-expression "#status = :status" \
     --expression-attribute-names '{"#status": "status"}' \
     --expression-attribute-values '{":status": {"S": "FAILED"}}'
   ```

---

## Quick Reference

### Common AWS CLI Commands

```bash
# Step Functions
aws stepfunctions list-executions --state-machine-arn {arn} --status-filter RUNNING
aws stepfunctions describe-execution --execution-arn {arn}
aws stepfunctions stop-execution --execution-arn {arn}

# Glue Crawlers
aws glue start-crawler --name {crawler-name}
aws glue get-crawler --name {crawler-name}
aws glue stop-crawler --name {crawler-name}

# Athena
aws athena start-query-execution --query-string "SELECT 1" --work-group {workgroup}
aws athena get-query-execution --query-execution-id {id}
aws athena stop-query-execution --query-execution-id {id}

# MWAA
aws mwaa get-environment --name {env-name}
aws mwaa create-web-login-token --name {env-name}

# S3
aws s3 ls s3://{bucket}/{prefix}/ --recursive --summarize
aws s3 cp {local-file} s3://{bucket}/{prefix}/

# DynamoDB
aws dynamodb scan --table-name {table} --limit 10
aws dynamodb query --table-name {table} --key-condition-expression "pk = :pk"
```

### Environment Variables

Set these for easier CLI usage:

```bash
export AWS_PROFILE=ros-sandbox
export AWS_REGION=us-east-1
export LAKEHOUSE_ENV=sandbox
export STATE_MACHINE_ARN=arn:aws:states:us-east-1:ACCOUNT_ID:stateMachine:lakehouse-${LAKEHOUSE_ENV}-data-pipeline
export METADATA_TABLE=lakehouse-${LAKEHOUSE_ENV}-pipeline-metadata
```
