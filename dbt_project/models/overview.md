{% docs __overview__ %}

# AWS Data Lakehouse MVP - dbt Documentation

Welcome to the dbt documentation for the AWS Data Lakehouse MVP project. This project demonstrates a modern data lakehouse architecture using AWS services with dbt for transformations.

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Raw Layer     │────▶│ Staging Layer   │────▶│  Marts Layer    │
│   (S3/JSON)     │     │   (Views)       │     │  (Iceberg)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
       │                        │                       │
       ▼                        ▼                       ▼
   Glue Crawler            dbt Models              Business-Ready
   Schema Discovery        Cleaning &              Analytics Tables
                          Standardization
```

## Data Flow

1. **Raw Data** lands in S3 as JSON files
2. **Glue Crawlers** discover schemas and create catalog tables
3. **Staging Models** clean and standardize the raw data
4. **Intermediate Models** enrich and join data (ephemeral)
5. **Mart Models** create business-ready Iceberg tables

## Model Layers

### Staging (`models/staging/`)
- **Purpose**: Clean, rename, and cast raw data
- **Materialization**: Views (lightweight, always current)
- **Naming**: `stg_<source>_<entity>`

### Intermediate (`models/intermediate/`)
- **Purpose**: Business logic, joins, enrichment
- **Materialization**: Ephemeral (not persisted)
- **Naming**: `int_<entity>_<transformation>`

### Marts (`models/marts/`)
- **Purpose**: Business-ready tables for analytics
- **Materialization**: Iceberg tables (ACID, time-travel)
- **Naming**: `fct_<entity>` for facts, `dim_<entity>` for dimensions

## Key Features

### Iceberg Tables
All mart models are stored as Apache Iceberg tables, providing:
- **ACID transactions** for reliable updates
- **Time travel** for historical queries
- **Schema evolution** without table rewrites
- **Partition evolution** for query optimization

### Data Quality
Tests are defined for all models:
- `not_null` - Ensures required fields are populated
- `unique` - Validates primary keys
- `accepted_values` - Validates categorical fields
- `relationships` - Validates foreign keys

## Getting Started

1. Configure your `profiles.yml` with AWS credentials
2. Run `dbt deps` to install packages
3. Run `dbt build` to execute models and tests
4. Run `dbt docs generate && dbt docs serve` to view documentation

## Related Resources

- [AWS Data Lakehouse Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/defining-bucket-names-data-lakes/)
- [Apache Iceberg Documentation](https://iceberg.apache.org/docs/latest/)
- [dbt-athena Adapter](https://github.com/dbt-athena/dbt-athena)

{% enddocs %}
