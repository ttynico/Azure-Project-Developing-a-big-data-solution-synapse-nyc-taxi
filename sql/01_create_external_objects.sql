-- =============================================================================
-- 01_create_external_objects.sql
--
-- Sets up the objects needed to query the ingested NYC Taxi Parquet files
-- from the serverless SQL pool. Run each statement as its own batch in
-- Synapse Studio (select the statement, then Run) rather than the whole
-- file at once - CREATE DATABASE and database-scoped objects can't always
-- share a batch with the CREATE DATABASE statement itself.
--
-- Replace <STORAGE_ACCOUNT> with your real storage account name
-- (also saved in .synapse_project_config) before running.
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
-- (puYear=2018/puMonth=6/) rather than flattening it into yellow_2018_06/
-- directly. Always verify actual paths with `azcopy list` rather than
-- assuming a flat structure.
SELECT TOP 10 *
FROM OPENROWSET(
    BULK 'yellow_2018_06/puMonth=6/*.parquet',
    DATA_SOURCE = 'nyc_taxi_raw',
    FORMAT = 'PARQUET'
) AS rows_preview;

-- Step 6: external table with an explicit schema for repeated querying.
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
    LOCATION = 'yellow_2018_06/puMonth=6/*.parquet',
    DATA_SOURCE = nyc_taxi_raw,
    FILE_FORMAT = parquet_format
);

-- Confirm row count landed as expected (June 2018 Yellow Taxi is
-- roughly 9 million trips across the full month; the 20 files we
-- ingested should total in that range).
SELECT COUNT(*) AS total_trips FROM dbo.YellowTaxiTrips;
