# AWS Data Lakehouse Best Practices

This document outlines best practices for each AWS service used in the data lakehouse architecture.

## Table of Contents

- [S3 Data Lake](#s3-data-lake)
- [AWS Glue Crawlers](#aws-glue-crawlers)
- [AWS Step Functions](#aws-step-functions)
- [Amazon MWAA (Airflow)](#amazon-mwaa-airflow)
- [Amazon Athena](#amazon-athena)
- [dbt with Iceberg](#dbt-with-iceberg)
- [Cross-Service Best Practices](#cross-service-best-practices)
- [Cost Optimization](#cost-optimization)
- [Security Considerations and IAM Best Practices](#security-considerations-and-iam-best-practices)

---

## S3 Data Lake

### Data Organization

- **Use consistent prefix structure**: Organize data into logical layers:
  - `raw/` - Landing zone for ingested data (immutable)
  - `processed/` - Cleaned and validated data
  - `curated/` - Business-ready datasets (Iceberg tables)

- **Partition data by date**: Use `year=YYYY/month=MM/day=DD` partitioning for time-series data to enable efficient querying and lifecycle management.

- **Use descriptive naming**: Follow `{domain}/{entity}/{partition}` naming conventions for clarity.

### Security

- **Enable versioning**: Protect against accidental deletions and enable data recovery. Critical for maintaining data lineage and audit trails.

- **Use KMS encryption**: Enable server-side encryption with AWS KMS for data at rest. Use customer-managed keys (CMK) for production workloads to maintain key rotation control.

- **Block public access**: Always enable S3 Block Public Access at the bucket level. Use bucket policies to explicitly deny public access.

- **Enable access logging**: Configure S3 server access logging to track requests for security auditing.

### Cost Optimization

- **Configure lifecycle policies**: Transition data to cost-effective storage classes:
  - Raw data older than 30 days → S3 Standard-IA
  - Raw data older than 90 days → S3 Glacier Instant Retrieval
  - Archive data older than 365 days → S3 Glacier Deep Archive

- **Enable Intelligent-Tiering**: For data with unpredictable access patterns, use S3 Intelligent-Tiering to automatically optimize costs.

- **Delete incomplete multipart uploads**: Configure lifecycle rules to abort incomplete multipart uploads after 7 days.

- **Use S3 Storage Lens**: Monitor storage usage and activity trends to identify optimization opportunities.

---

## AWS Glue Crawlers

### Scheduling

- **Schedule during off-peak hours**: Run crawlers during low-activity periods to minimize resource contention and costs.

- **Use event-driven triggers**: For real-time schema updates, trigger crawlers via S3 events or Step Functions instead of fixed schedules.

- **Avoid overlapping schedules**: Ensure crawler schedules don't overlap to prevent conflicts and unnecessary runs.

### Schema Management

- **Use table grouping**: Enable table grouping to handle schema evolution gracefully. Group tables by common schema patterns.

- **Configure schema change policies**: Set appropriate policies for schema changes:
  - `UPDATE_IN_DATABASE` - Update existing table definitions
  - `LOG` - Log changes without updating (for review)
  - `ADD_NEW_COLUMNS` - Only add new columns, never remove

- **Use exclusion patterns**: Exclude temporary files, logs, and non-data files from crawling using exclusion patterns.

### Performance

- **Limit crawler scope**: Target specific prefixes rather than entire buckets to reduce crawl time and costs.

- **Use sampling**: For large datasets, enable sampling to speed up schema discovery while maintaining accuracy.

- **Monitor crawler metrics**: Track crawler run times and table updates via CloudWatch to identify performance issues.

### Partitioning

- **Define partition keys**: Explicitly define partition keys in crawler configuration for consistent partitioning.

- **Use Hive-style partitions**: Follow `key=value` format for partition paths to enable automatic partition detection.

---

## AWS Step Functions

### Error Handling

- **Implement retry policies on all task states**: Configure retries with exponential backoff:
  ```json
  "Retry": [{
    "ErrorEquals": ["States.TaskFailed"],
    "IntervalSeconds": 3,
    "MaxAttempts": 3,
    "BackoffRate": 2.0
  }]
  ```

- **Use catch blocks for graceful failure handling**: Route errors to cleanup or notification states:
  ```json
  "Catch": [{
    "ErrorEquals": ["States.ALL"],
    "Next": "HandleError",
    "ResultPath": "$.error"
  }]
  ```

- **Distinguish between retryable and non-retryable errors**: Use specific error codes to handle different failure scenarios appropriately.

### Timeouts

- **Set appropriate timeouts**: Configure `TimeoutSeconds` on all task states to prevent hung executions:
  - Short tasks (API calls): 30-60 seconds
  - Medium tasks (Glue jobs): 15-30 minutes
  - Long tasks (ETL pipelines): 1-4 hours

- **Use heartbeat for long-running tasks**: Configure `HeartbeatSeconds` for tasks that may take variable time.

### Design Patterns

- **Use SDK integrations instead of Lambda**: Prefer direct service integrations (`.sync` suffix) over Lambda wrappers for AWS service calls. This reduces latency, cost, and complexity.

- **Implement idempotency**: Design states to be safely re-executable. Use unique execution IDs and conditional writes.

- **Use parallel states for independent tasks**: Execute independent operations concurrently to reduce total execution time.

- **Keep state machine definitions modular**: Break complex workflows into nested state machines for reusability and maintainability.

### Monitoring

- **Enable X-Ray tracing**: Configure X-Ray for end-to-end visibility into workflow execution.

- **Use CloudWatch metrics**: Monitor execution counts, failures, and duration via CloudWatch dashboards.

- **Log execution history**: Retain execution history for debugging and audit purposes.

---

## Amazon MWAA (Airflow)

### DAG Design

- **Keep DAGs simple**: Delegate complex workflow logic to Step Functions. MWAA should focus on:
  - Scheduling and triggering
  - Cross-pipeline dependencies
  - High-level monitoring

- **Set `retries=0` when using Step Functions**: Let Step Functions handle retry logic to avoid duplicate retries and conflicting behavior.

- **Use sensors for monitoring**: Use `StepFunctionExecutionSensor` to monitor external workflow completion rather than polling in tasks.

- **Avoid heavy processing in DAGs**: DAGs should orchestrate, not process. Move data processing to Step Functions, Glue, or EMR.

### Configuration

- **Use Airflow Variables for configuration**: Store environment-specific values (ARNs, bucket names) in Airflow Variables, not hardcoded in DAGs.

- **Use Connections for credentials**: Configure AWS connections in Airflow rather than embedding credentials.

- **Set appropriate pool sizes**: Configure task pools to limit concurrent executions and prevent resource exhaustion.

### Version Control

- **Version control DAGs in S3**: Use S3 versioning on the DAGs bucket to track changes and enable rollback.

- **Use CI/CD for DAG deployment**: Implement automated testing and deployment pipelines for DAG changes.

- **Test DAGs locally**: Use `airflow dags test` and `pytest` to validate DAGs before deployment.

### Monitoring

- **Configure alerting**: Set up email or SNS notifications for DAG failures.

- **Monitor task duration**: Track task execution times to identify performance degradation.

- **Use DAG tags**: Tag DAGs by domain, team, or criticality for organization and filtering.

### Resource Management

- **Right-size the environment**: Start with `mw1.small` and scale based on actual workload requirements.

- **Monitor worker utilization**: Track worker CPU and memory to optimize environment sizing.

- **Schedule maintenance windows**: Plan for MWAA version upgrades and maintenance during low-activity periods.

---

## Amazon Athena

### Query Performance

- **Partition data effectively**: Design partition schemes based on common query patterns:
  - Time-based queries → partition by date
  - Regional queries → partition by region
  - Combine multiple partition keys for complex access patterns

- **Use columnar formats**: Store data in Parquet or ORC format for:
  - Reduced storage costs (compression)
  - Faster query performance (column pruning)
  - Schema evolution support

- **Optimize file sizes**: Target 128MB-1GB file sizes for optimal query performance. Use compaction for small files.

### Cost Control

- **Set `bytes_scanned_cutoff`**: Configure workgroup limits to prevent runaway queries:
  ```hcl
  bytes_scanned_cutoff_per_query = 10737418240  # 10 GB
  ```

- **Use workgroups for access control**: Create separate workgroups for different teams or use cases with appropriate limits.

- **Monitor query costs**: Track bytes scanned per query and per workgroup via CloudWatch.

- **Use LIMIT clauses**: Always use LIMIT during development and exploration to minimize scanned data.

### Compression

- **Use Snappy compression**: Default to Snappy for balanced compression ratio and query performance.

- **Consider ZSTD for cold data**: Use ZSTD compression for archived data where query frequency is low.

### Iceberg Tables

- **Leverage time travel**: Use Iceberg's time travel for debugging and auditing:
  ```sql
  SELECT * FROM table FOR TIMESTAMP AS OF timestamp '2024-01-01 00:00:00'
  ```

- **Optimize table maintenance**: Schedule regular compaction and snapshot expiration:
  ```sql
  OPTIMIZE table REWRITE DATA USING BIN_PACK
  VACUUM table
  ```

- **Use hidden partitioning**: Leverage Iceberg's hidden partitioning for cleaner queries without explicit partition filters.

---

## dbt with Iceberg

### Model Organization

- **Use layered architecture**: Organize models in logical layers:
  ```
  models/
  ├── staging/      # 1:1 with sources, light transformations
  ├── intermediate/ # Business logic, joins, aggregations
  └── marts/        # Business-ready datasets, Iceberg tables
  ```

- **Follow naming conventions**:
  - Staging: `stg_{source}_{entity}`
  - Intermediate: `int_{entity}_{verb}`
  - Marts: `dim_{entity}`, `fct_{entity}`

- **Use ephemeral models for intermediate logic**: Materialize intermediate models as `ephemeral` to reduce storage while maintaining modularity.

### Iceberg Configuration

- **Configure Iceberg for mart models**:
  ```yaml
  models:
    marts:
      +materialized: table
      +table_type: iceberg
      +format: parquet
      +write_compression: snappy
  ```

- **Use partitioning for large tables**: Configure partition transforms based on query patterns:
  ```sql
  {{ config(
    partitioned_by=['date(event_date)', 'bucket(16, user_id)']
  ) }}
  ```

- **Set explicit S3 locations**: Define `s3_data_dir` to control where Iceberg data files are written.

### Testing

- **Implement schema tests**: Add tests for data quality validation:
  ```yaml
  columns:
    - name: user_id
      tests:
        - not_null
        - unique
    - name: status
      tests:
        - accepted_values:
            values: ['active', 'inactive', 'pending']
  ```

- **Use custom data tests**: Create tests for business rules and cross-table consistency.

- **Test source freshness**: Configure source freshness tests to detect stale data:
  ```yaml
  sources:
    - name: raw
      freshness:
        warn_after: {count: 12, period: hour}
        error_after: {count: 24, period: hour}
  ```

### Macros and Reusability

- **Create reusable macros**: Define macros for common Iceberg configurations:
  ```sql
  {% macro iceberg_config(partition_by=none) %}
    {{ config(
      materialized='table',
      table_type='iceberg',
      format='parquet',
      write_compression='snappy',
      partitioned_by=partition_by
    ) }}
  {% endmacro %}
  ```

- **Use packages**: Leverage dbt packages for common utilities (dbt-utils, dbt-expectations).

### Performance

- **Use incremental models**: For large fact tables, use incremental materialization:
  ```sql
  {{ config(
    materialized='incremental',
    unique_key='event_id',
    incremental_strategy='merge'
  ) }}
  ```

- **Optimize model dependencies**: Minimize model fan-out and use `ref()` efficiently to enable parallel execution.

---

## Cross-Service Best Practices

### Naming Conventions

Use consistent naming across all services:
```
{project}-{environment}-{service}-{resource}
```

Example: `lakehouse-prod-glue-raw-crawler`

### Tagging Strategy

Apply consistent tags for:
- Cost allocation: `Project`, `Environment`, `Team`
- Operations: `ManagedBy`, `CreatedDate`
- Compliance: `DataClassification`, `RetentionPolicy`

### Monitoring and Alerting

- Centralize logs in CloudWatch Logs
- Create unified dashboards for pipeline health
- Set up SNS alerts for critical failures
- Use AWS X-Ray for distributed tracing

### Security

- Follow least-privilege IAM principles
- Use IAM roles instead of access keys
- Enable CloudTrail for audit logging
- Encrypt data in transit and at rest
- Regularly review and rotate credentials

---

## Cost Optimization

This section provides comprehensive cost optimization recommendations for the data lakehouse architecture.

### S3 Storage Costs

**Lifecycle Policies**
- Configure automatic transitions to reduce storage costs:
  ```hcl
  # Example lifecycle configuration
  lifecycle_rule {
    id      = "raw-data-tiering"
    enabled = true
    prefix  = "raw/"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
  ```

**Storage Class Selection**
| Data Type | Access Pattern | Recommended Class |
|-----------|---------------|-------------------|
| Raw (recent) | Frequent | S3 Standard |
| Raw (30+ days) | Infrequent | S3 Standard-IA |
| Raw (90+ days) | Rare | Glacier Instant Retrieval |
| Archive | Very rare | Glacier Deep Archive |
| Curated (Iceberg) | Frequent queries | S3 Standard |

**Iceberg Table Optimization**
- Run regular compaction to reduce small files:
  ```sql
  OPTIMIZE curated.fct_events REWRITE DATA USING BIN_PACK
  ```
- Expire old snapshots to reclaim storage:
  ```sql
  VACUUM curated.fct_events
  ```
- Target 128MB-1GB file sizes for optimal cost/performance balance

**Multipart Upload Cleanup**
- Configure lifecycle rules to abort incomplete uploads:
  ```hcl
  lifecycle_rule {
    id      = "abort-incomplete-uploads"
    enabled = true
    abort_incomplete_multipart_upload_days = 7
  }
  ```

### Glue Crawler Costs

**Optimize Crawler Runs**
- Schedule crawlers during off-peak hours to reduce costs
- Use event-driven triggers instead of frequent schedules when possible
- Limit crawler scope to specific prefixes rather than entire buckets
- Enable sampling for large datasets to reduce DPU usage

**Crawler Scheduling Recommendations**
| Data Volume | Update Frequency | Recommended Schedule |
|-------------|-----------------|---------------------|
| Low (<1GB/day) | Daily | `cron(0 6 * * ? *)` |
| Medium (1-10GB/day) | Every 6 hours | `cron(0 */6 * * ? *)` |
| High (>10GB/day) | Event-driven | S3 event triggers |

**Cost Monitoring**
- Monitor crawler DPU-hours via CloudWatch
- Set billing alerts for unexpected crawler costs
- Review crawler run times and optimize exclusion patterns

### Step Functions Costs

**State Transition Optimization**
- Minimize state transitions by combining related operations
- Use Express Workflows for high-volume, short-duration workflows (<5 minutes)
- Use Standard Workflows for long-running pipelines with audit requirements

**Workflow Type Selection**
| Workflow Characteristic | Recommended Type | Pricing Model |
|------------------------|------------------|---------------|
| <5 min duration, high volume | Express | Per request + duration |
| >5 min duration | Standard | Per state transition |
| Audit/compliance required | Standard | Per state transition |

**Reduce Unnecessary Transitions**
- Batch DynamoDB operations where possible
- Use `ResultPath` to avoid unnecessary Pass states
- Combine sequential AWS SDK calls into single states when logical

### MWAA Costs

**Environment Sizing**
- Start with `mw1.small` for development/testing
- Monitor worker utilization before scaling up
- Use auto-scaling for production workloads with variable demand

**Environment Class Recommendations**
| Workload | DAG Count | Recommended Class | Monthly Estimate |
|----------|-----------|-------------------|------------------|
| Dev/Test | <10 | mw1.small | ~$350 |
| Small Prod | 10-25 | mw1.medium | ~$700 |
| Large Prod | 25-50 | mw1.large | ~$1,400 |

**Cost Reduction Strategies**
- Consolidate DAGs to reduce environment count
- Use Step Functions for complex workflows (reduces MWAA load)
- Schedule environment scaling during off-hours if supported
- Delete unused environments promptly

### Athena Query Costs

**Query Optimization**
- Always use partition filters to reduce data scanned:
  ```sql
  -- Good: Uses partition pruning
  SELECT * FROM fct_events WHERE event_date = '2024-01-15'
  
  -- Bad: Full table scan
  SELECT * FROM fct_events WHERE DATE(event_timestamp) = '2024-01-15'
  ```

**Workgroup Cost Controls**
- Set `bytes_scanned_cutoff_per_query` to prevent runaway queries:
  ```hcl
  configuration {
    bytes_scanned_cutoff_per_query = 10737418240  # 10 GB
    enforce_workgroup_configuration = true
  }
  ```

**Data Format Optimization**
- Use columnar formats (Parquet) for 30-90% cost reduction vs CSV/JSON
- Enable compression (Snappy recommended) for additional savings
- Partition large tables by common query dimensions

**Query Cost Estimation**
| Data Scanned | Cost (us-east-1) |
|--------------|------------------|
| 1 GB | $0.005 |
| 10 GB | $0.05 |
| 100 GB | $0.50 |
| 1 TB | $5.00 |

### DynamoDB Costs

**Capacity Mode Selection**
- Use PAY_PER_REQUEST (on-demand) for unpredictable workloads
- Use PROVISIONED for steady-state workloads with predictable patterns
- Consider reserved capacity for production workloads (up to 77% savings)

**Cost Optimization Strategies**
- Design efficient key schemas to minimize read/write operations
- Use sparse indexes (GSIs) only when necessary
- Enable TTL to automatically delete old records:
  ```hcl
  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }
  ```

### Cost Monitoring and Alerts

**AWS Cost Explorer Tags**
- Apply consistent tags for cost allocation:
  ```hcl
  default_tags {
    tags = {
      Project     = "lakehouse"
      Environment = "sandbox"
      Team        = "data-engineering"
      CostCenter  = "analytics"
    }
  }
  ```

**CloudWatch Billing Alerts**
- Set up billing alerts at 50%, 80%, and 100% of budget
- Create per-service cost anomaly detection
- Review Cost Explorer weekly for optimization opportunities

**Cost Optimization Checklist**
- [ ] S3 lifecycle policies configured for all prefixes
- [ ] Glue crawlers scheduled appropriately (not too frequent)
- [ ] Athena workgroup byte limits enforced
- [ ] MWAA environment right-sized for workload
- [ ] DynamoDB TTL enabled for transient data
- [ ] Unused resources cleaned up (old snapshots, test data)
- [ ] Cost allocation tags applied to all resources

---

## Security Considerations and IAM Best Practices

This section documents security considerations and IAM best practices for the data lakehouse architecture.

### IAM Principles

**Least Privilege Access**
- Grant only the minimum permissions required for each service
- Use specific resource ARNs instead of wildcards where possible
- Regularly audit and remove unused permissions

**Service Role Design**
```hcl
# Example: Glue Crawler role with least privilege
resource "aws_iam_role" "glue_crawler" {
  name = "${var.project_name}-${var.environment}-glue-crawler"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

# Specific S3 permissions (not s3:*)
resource "aws_iam_role_policy" "crawler_s3" {
  role = aws_iam_role.glue_crawler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.data_lake.arn,
        "${aws_s3_bucket.data_lake.arn}/*"
      ]
    }]
  })
}
```

### Service-Specific IAM Policies

**MWAA Execution Role**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "states:StartExecution",
      "Resource": "arn:aws:states:*:*:stateMachine:lakehouse-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "states:DescribeExecution",
        "states:StopExecution"
      ],
      "Resource": "arn:aws:states:*:*:execution:lakehouse-*:*"
    },
    {
      "Effect": "Allow",
      "Action": "glue:StartCrawler",
      "Resource": "arn:aws:glue:*:*:crawler/lakehouse-*"
    }
  ]
}
```

**Step Functions Execution Role**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "glue:StartCrawler",
        "glue:GetCrawler"
      ],
      "Resource": "arn:aws:glue:*:*:crawler/lakehouse-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/lakehouse-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults"
      ],
      "Resource": "*"
    }
  ]
}
```

**Athena Workgroup Permissions**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults",
        "athena:StopQueryExecution"
      ],
      "Resource": "arn:aws:athena:*:*:workgroup/lakehouse-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:GetPartitions"
      ],
      "Resource": [
        "arn:aws:glue:*:*:catalog",
        "arn:aws:glue:*:*:database/lakehouse_*",
        "arn:aws:glue:*:*:table/lakehouse_*/*"
      ]
    }
  ]
}
```

### Data Encryption

**Encryption at Rest**
- S3: Enable SSE-KMS with customer-managed keys (CMK)
- DynamoDB: Enable encryption with AWS-managed or customer-managed keys
- Athena: Query results encrypted in S3

```hcl
# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data_lake.arn
    }
    bucket_key_enabled = true  # Reduces KMS costs
  }
}
```

**Encryption in Transit**
- All AWS service communications use TLS 1.2+
- Enforce HTTPS-only access to S3:
  ```json
  {
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::bucket/*"],
    "Condition": {
      "Bool": {"aws:SecureTransport": "false"}
    }
  }
  ```

**KMS Key Policy Best Practices**
- Separate keys for different data classifications
- Enable automatic key rotation
- Restrict key administration to specific IAM roles
- Audit key usage via CloudTrail

### Network Security

**VPC Configuration for MWAA**
- Deploy MWAA in private subnets
- Use VPC endpoints for AWS service access (S3, DynamoDB, Glue)
- Configure security groups with minimal ingress rules

```hcl
# MWAA security group
resource "aws_security_group" "mwaa" {
  name_prefix = "lakehouse-mwaa-"
  vpc_id      = aws_vpc.main.id
  
  # Self-referencing for Airflow workers
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  
  # Outbound to VPC endpoints and internet (via NAT)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**VPC Endpoints**
- Create interface endpoints for: Glue, Step Functions, DynamoDB, Athena
- Create gateway endpoint for S3
- Reduces data transfer costs and improves security

### Access Control

**S3 Bucket Policies**
- Block public access at account and bucket level
- Use bucket policies to restrict access to specific IAM roles
- Enable MFA delete for critical buckets

```hcl
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Athena Workgroup Isolation**
- Create separate workgroups for different teams/use cases
- Enforce workgroup configuration to prevent overrides
- Use workgroup-level encryption settings

**DynamoDB Access Patterns**
- Use IAM conditions to restrict access by partition key
- Implement row-level security via application logic
- Enable fine-grained access control for sensitive metadata

### Audit and Compliance

**CloudTrail Configuration**
- Enable CloudTrail for all regions
- Log management events and data events for S3
- Store logs in a separate, secured S3 bucket

```hcl
resource "aws_cloudtrail" "lakehouse" {
  name                          = "lakehouse-audit-trail"
  s3_bucket_name               = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.data_lake.arn}/"]
    }
  }
}
```

**S3 Access Logging**
- Enable server access logging for data lake buckets
- Analyze logs for unauthorized access attempts
- Retain logs for compliance requirements

**DynamoDB Streams for Audit**
- Enable DynamoDB Streams for pipeline metadata table
- Archive stream records for audit trail
- Monitor for unexpected data modifications

### Security Monitoring

**CloudWatch Alarms**
- Alert on unauthorized API calls (AccessDenied errors)
- Monitor for unusual data access patterns
- Track failed authentication attempts

**AWS Config Rules**
- Enable Config rules for security compliance:
  - `s3-bucket-public-read-prohibited`
  - `s3-bucket-ssl-requests-only`
  - `dynamodb-table-encrypted-kms`
  - `iam-policy-no-statements-with-admin-access`

**Security Hub Integration**
- Enable AWS Security Hub for centralized security findings
- Review and remediate high-severity findings
- Integrate with ticketing systems for tracking

### Security Checklist

**Infrastructure Security**
- [ ] S3 buckets have public access blocked
- [ ] S3 buckets use KMS encryption
- [ ] DynamoDB tables are encrypted
- [ ] MWAA deployed in private subnets
- [ ] VPC endpoints configured for AWS services
- [ ] Security groups follow least privilege

**IAM Security**
- [ ] Service roles use least privilege permissions
- [ ] No wildcard (*) resource permissions where avoidable
- [ ] IAM policies use specific resource ARNs
- [ ] Cross-account access properly configured (if applicable)
- [ ] Regular IAM access reviews scheduled

**Data Security**
- [ ] Encryption at rest enabled for all data stores
- [ ] Encryption in transit enforced (HTTPS only)
- [ ] KMS key rotation enabled
- [ ] Sensitive data classified and protected

**Monitoring and Audit**
- [ ] CloudTrail enabled for all regions
- [ ] S3 access logging enabled
- [ ] CloudWatch alarms configured for security events
- [ ] AWS Config rules enabled
- [ ] Regular security assessments scheduled
