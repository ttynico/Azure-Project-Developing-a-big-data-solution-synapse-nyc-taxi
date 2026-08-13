-- =============================================================================
-- 01_create_external_objects.sql
--
-- Sets up the objects needed to query the ingested NYC Taxi Parquet files
-- from the serverless SQL pool. Run each statement as its own batch in
-- Synapse Studio (select the statement, then Run) rather than the whole
-- file at once.
--
-- Replace <STORAGE_ACCOUNT> and <SAS_TOKEN> before running.
-- =============================================================================

-- Step 1: create a dedicated database, then switch the Studio "Use database"
-- dropdown to nyc_taxi_db before running anything below.
CREATE DATABASE nyc_taxi_db;

-- Step 2: master key, required before creating any database scoped credential.
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<CHOOSE-A-STRONG-PASSWORD>';

-- Step 3: SAS-based credential. Generate the token with:
--   az storage container generate-sas --account-name <STORAGE_ACCOUNT> \
--     --account-key <key> --name raw --permissions rl --expiry <date>
-- Note the syntax: CREATE DATABASE SCOPED CREDENTIAL does NOT take
-- parentheses after WITH (unlike CREATE EXTERNAL DATA SOURCE, which does).
CREATE DATABASE SCOPED CREDENTIAL nyc_taxi_sas_cred
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = '<SAS_TOKEN_WITHOUT_LEADING_QUESTION_MARK>';

-- Step 4: external data source. Use the .blob.core.windows.net endpoint
-- (not .dfs.core.windows.net) when authenticating via SAS token.
CREATE EXTERNAL DATA SOURCE nyc_taxi_raw
WITH (
    LOCATION = 'https://<STORAGE_ACCOUNT>.blob.core.windows.net/raw',
    CREDENTIAL = nyc_taxi_sas_cred
);

CREATE EXTERNAL FILE FORMAT parquet_format
WITH (
    FORMAT_TYPE = PARQUET
);

-- Step 5: sanity check. Note the nested puMonth=6/ folder - azcopy's
-- --recursive copy preserved the source's internal partition structure
-- (puYear=2018/puMonth=6/) rather than flattening it. Always verify actual
-- paths with `azcopy list` rather than assuming a flat structure.
--
-- Also worth checking real column names/types before writing a schema:
-- SELECT TOP 0 * FROM OPENROWSET(...) - this 2018 file uses lowercase
-- puLocationId/doLocationId (not PascalCase PULocationID/DOLocationID as
-- Microsoft's own newer tutorials show), and stores paymentType,
-- puLocationId, doLocationId, and rateCodeId as strings (BYTE_ARRAY/UTF8)
-- despite the values looking numeric - an external table with an INT
-- column for these silently returns NULL for every row rather than
-- erroring, and only throws "not compatible with external data type"
-- once you actually query that column. Cast to INT in queries as needed.
SELECT TOP 10 *
FROM OPENROWSET(
    BULK 'yellow_2018_06/puMonth=6/*.parquet',
    DATA_SOURCE = 'nyc_taxi_raw',
    FORMAT = 'PARQUET'
) AS rows_preview;

-- Step 6: external table with the verified schema (confirmed via
-- SELECT TOP 0 * against the real file - don't assume column names/casing
-- from documentation examples, they vary by dataset vintage).
CREATE EXTERNAL TABLE dbo.YellowTaxiTrips (
    vendorID              VARCHAR(10),
    tpepPickupDateTime     DATETIME2,
    tpepDropoffDateTime    DATETIME2,
    passengerCount          INT,
    tripDistance             FLOAT,
    puLocationId            VARCHAR(10),
    doLocationId            VARCHAR(10),
    startLon                 FLOAT,
    startLat                 FLOAT,
    endLon                   FLOAT,
    endLat                   FLOAT,
    rateCodeId               VARCHAR(10),
    storeAndFwdFlag         VARCHAR(3),
    paymentType              VARCHAR(10),
    fareAmount               FLOAT,
    extra                    FLOAT,
    mtaTax                  FLOAT,
    improvementSurcharge    FLOAT,
    tipAmount                FLOAT,
    tollsAmount               FLOAT,
    totalAmount               FLOAT
)
WITH (
    LOCATION = 'yellow_2018_06/puMonth=6/*.parquet',
    DATA_SOURCE = nyc_taxi_raw,
    FILE_FORMAT = parquet_format
);

-- Confirm row count (June 2018 Yellow Taxi, 20 ingested files): ~8.7M rows.
SELECT COUNT(*) AS total_trips FROM dbo.YellowTaxiTrips;
