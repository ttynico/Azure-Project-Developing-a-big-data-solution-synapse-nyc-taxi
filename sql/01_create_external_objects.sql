-- =============================================================================
-- 01_create_external_objects.sql
--
-- Sets up the objects needed to query the ingested NYC Taxi Parquet files
-- from the serverless SQL pool: a database, an external data source pointing
-- at the "raw" container, a Parquet file format, and an external table.
--
-- Run against the Built-in serverless SQL pool in Synapse Studio.
-- Replace <STORAGE_ACCOUNT> with the value printed by create_resources.sh
-- (also saved in .synapse_project_config).
-- =============================================================================

-- A dedicated database keeps this project's objects separate from the
-- default master database.
CREATE DATABASE nyc_taxi_db;
GO

USE nyc_taxi_db;
GO

-- Data source pointing at the raw container. Uses your Azure AD identity
-- (the Storage Blob Data Contributor role granted in create_resources.sh)
-- rather than a storage key, so no secret is stored in the script.
CREATE EXTERNAL DATA SOURCE nyc_taxi_raw
WITH (
    LOCATION = 'https://<STORAGE_ACCOUNT>.dfs.core.windows.net/raw'
);
GO

CREATE EXTERNAL FILE FORMAT parquet_format
WITH (
    FORMAT_TYPE = PARQUET
);
GO

-- Quick sanity check: query the files directly with OPENROWSET before
-- committing to an external table schema. Automatic schema inference works
-- for Parquet, so this needs no column list.
SELECT TOP 10 *
FROM OPENROWSET(
    BULK 'yellow_2022_01/*.parquet',
    DATA_SOURCE = 'nyc_taxi_raw',
    FORMAT = 'PARQUET'
) AS rows_preview;
GO

-- External table with an explicit schema for repeated querying and for
-- tools (Power BI, SSMS) that expect a stable table rather than a view
-- over OPENROWSET.
CREATE EXTERNAL TABLE dbo.YellowTaxiTrips (
    VendorID              INT,
    tpepPickupDateTime     DATETIME2,
    tpepDropoffDateTime    DATETIME2,
    passengerCount          INT,
    tripDistance             FLOAT,
    RatecodeID              INT,
    storeAndFwdFlag         VARCHAR(3),
    PULocationID            INT,
    DOLocationID            INT,
    paymentType              INT,
    fareAmount               FLOAT,
    extra                    FLOAT,
    mtaTax                  FLOAT,
    tipAmount                FLOAT,
    tollsAmount               FLOAT,
    improvementSurcharge    FLOAT,
    totalAmount               FLOAT
)
WITH (
    LOCATION = 'yellow_2022_01/*.parquet',
    DATA_SOURCE = nyc_taxi_raw,
    FILE_FORMAT = parquet_format
);
GO

-- Confirm row count landed as expected (January 2022 Yellow Taxi is
-- roughly 2.5 million trips).
SELECT COUNT(*) AS total_trips FROM dbo.YellowTaxiTrips;
GO
