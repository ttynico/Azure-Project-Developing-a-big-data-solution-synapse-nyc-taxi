# Big Data Solution — Azure Synapse Serverless SQL + Data Lake

**Project 10** — a data lake analytics solution built with Azure Synapse Analytics
**serverless SQL pool**, querying NYC Taxi trip data (Parquet) directly from Azure
Data Lake Storage Gen2 using T-SQL — no cluster, no data warehouse load, no
always-on compute.

## Architecture

```
NYC TLC public dataset (Azure Open Datasets)
        │  azcopy (service-to-service copy)
        ▼
┌─────────────────────────────┐
│  ADLS Gen2 storage account   │
│  ┌─────────┐   ┌──────────┐  │
│  │  raw/   │   │ curated/ │  │   <- CETAS writes transformed output here
│  └─────────┘   └──────────┘  │
└─────────────────────────────┘
        │
        ▼
┌─────────────────────────────┐
│  Synapse workspace           │
│  Built-in serverless SQL pool│  <- pay-per-TB-scanned, no idle cost
│  External tables / OPENROWSET│
└─────────────────────────────┘
        │
        ▼
   T-SQL analytical queries
```

## Why serverless SQL (not a dedicated SQL pool or Spark)

- **No idle cost.** Serverless SQL pools have no cluster to provision or leave
  running — you're billed per data volume scanned by each query
  (~$5/TB), not per hour. This is the opposite cost model from the always-on
  online endpoint in Project 11 — worth contrasting the two in an interview.
- **Query in place.** T-SQL runs directly against Parquet/CSV files in the
  data lake — no ETL load step required before you can start analyzing.
- **Familiar tooling.** Standard T-SQL, works with existing BI tools (Power BI,
  SSMS, Azure Data Studio) via the serverless SQL endpoint.

## Repo structure

```
azure-synapse-nyc-taxi/
├── README.md
├── setup/
│   ├── create_resources.sh   # resource group, ADLS Gen2, Synapse workspace
│   ├── ingest_data.sh        # copy NYC Taxi Parquet data into the data lake
│   └── cleanup.sh            # full teardown
├── sql/
│   ├── 01_create_external_objects.sql   # data source, file format, external table
│   └── 02_analysis_queries.sql          # analytical T-SQL queries
└── docs/
    └── screenshots/           # Synapse Studio screenshots (added after running)
```

## Prerequisites

- Azure CLI logged in (`az login`)
- `azcopy` installed ([download](https://learn.microsoft.com/azure/storage/common/storage-use-azcopy-v10))
- An Azure subscription with quota for a Synapse workspace in your target region

## Setup

Run one command at a time, verify output before proceeding.

```bash
# 1. Provision the storage account (ADLS Gen2) and Synapse workspace
bash setup/create_resources.sh

# 2. Copy one month of NYC Yellow Taxi trip data into your own data lake
bash setup/ingest_data.sh
```

`create_resources.sh` provisions:
- Resource group `rg-synapse-nyc-taxi`
- Storage account with hierarchical namespace enabled (`raw` and `curated` containers)
- Synapse workspace `synapse-nyc-taxi-<suffix>` (built-in serverless SQL pool
  included automatically — nothing extra to create or pay for until queried)
- A firewall rule allowing your current IP to reach the workspace

`ingest_data.sh` copies **one month** of Yellow Taxi Parquet files (~100-150MB)
from Microsoft's public NYC TLC dataset directly into your `raw` container via
`azcopy` — a service-to-service copy, so the data never touches your local
machine.

## Querying

Open the Synapse Studio URL printed at the end of `create_resources.sh`
(or `https://web.azuresynapse.net`), connect to the **Built-in** serverless
SQL pool, and run:

1. `sql/01_create_external_objects.sql` — sets up the external data source,
   file format, and an external table over the ingested Parquet files
2. `sql/02_analysis_queries.sql` — sample analytical queries: trips per day,
   average fare by hour, tip percentage by payment type, top pickup zones

You can also run these via `sqlcmd` or Azure Data Studio against the
serverless SQL endpoint shown in the workspace overview
(`<workspace-name>-ondemand.sql.azuresynapse.net`).

## Cost

- **Storage**: pennies/month for ~150MB of Parquet data
- **Synapse workspace**: free to have provisioned — no charge for the
  workspace itself or the built-in serverless SQL pool sitting idle
- **Queries**: ~$5 per TB of data scanned — a handful of exploratory queries
  against 150MB of data costs a fraction of a cent

This is intentionally the cheapest project in the portfolio to leave
provisioned for a demo — there's no compute to forget to turn off. Still,
run `setup/cleanup.sh` when you're done to remove the storage account.

## Cleanup

```bash
bash setup/cleanup.sh
```

## What this demonstrates

- Azure Data Lake Storage Gen2 provisioning and organization (raw/curated zones)
- Azure Synapse Analytics serverless SQL pool — external tables, OPENROWSET,
  querying Parquet in place without an ETL load step
- Service-to-service data ingestion with `azcopy` (no local data movement)
- Pay-per-query cost model vs. always-on compute — a deliberate contrast to
  the online endpoint cost lessons in Project 11
- T-SQL analytics over a realistic multi-hundred-thousand-row dataset
