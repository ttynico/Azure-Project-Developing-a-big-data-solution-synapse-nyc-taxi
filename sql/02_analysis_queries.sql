-- =============================================================================
-- 02_analysis_queries.sql
--
-- Analytical queries against the YellowTaxiTrips external table.
-- Run after 01_create_external_objects.sql. Each query scans only the
-- Parquet columns it references (columnar pruning), keeping the amount of
-- data scanned - and therefore the cost - low even against millions of rows.
-- =============================================================================

USE nyc_taxi_db;
GO

-- 1. Trip volume by day of month
SELECT
    CAST(tpepPickupDateTime AS DATE) AS trip_date,
    COUNT(*) AS trip_count
FROM dbo.YellowTaxiTrips
GROUP BY CAST(tpepPickupDateTime AS DATE)
ORDER BY trip_date;
GO

-- 2. Average fare and trip distance by hour of day
SELECT
    DATEPART(HOUR, tpepPickupDateTime) AS pickup_hour,
    COUNT(*) AS trip_count,
    AVG(fareAmount) AS avg_fare,
    AVG(tripDistance) AS avg_distance_miles
FROM dbo.YellowTaxiTrips
WHERE fareAmount > 0 AND tripDistance > 0  -- exclude bad/void records
GROUP BY DATEPART(HOUR, tpepPickupDateTime)
ORDER BY pickup_hour;
GO

-- 3. Tip percentage by payment type
-- paymentType: 1 = credit card, 2 = cash, 3 = no charge, 4 = dispute
SELECT
    paymentType,
    COUNT(*) AS trip_count,
    AVG(fareAmount) AS avg_fare,
    AVG(tipAmount) AS avg_tip,
    AVG(CASE WHEN fareAmount > 0 THEN tipAmount / fareAmount * 100 END) AS avg_tip_pct
FROM dbo.YellowTaxiTrips
WHERE fareAmount > 0
GROUP BY paymentType
ORDER BY paymentType;
GO

-- 4. Top 10 busiest pickup zones
SELECT TOP 10
    PULocationID,
    COUNT(*) AS pickup_count,
    AVG(totalAmount) AS avg_total_fare
FROM dbo.YellowTaxiTrips
GROUP BY PULocationID
ORDER BY pickup_count DESC;
GO

-- 5. Trip duration vs. fare - flag likely data quality issues
-- (very short trips with high fares, or long trips with $0 fare)
SELECT
    VendorID,
    tpepPickupDateTime,
    tpepDropoffDateTime,
    DATEDIFF(MINUTE, tpepPickupDateTime, tpepDropoffDateTime) AS duration_minutes,
    tripDistance,
    fareAmount
FROM dbo.YellowTaxiTrips
WHERE
    (DATEDIFF(MINUTE, tpepPickupDateTime, tpepDropoffDateTime) < 2 AND fareAmount > 50)
    OR (DATEDIFF(MINUTE, tpepPickupDateTime, tpepDropoffDateTime) > 60 AND fareAmount = 0)
ORDER BY fareAmount DESC;
GO

-- 6. CETAS example: write a curated, aggregated dataset back to the data
-- lake in Parquet format - demonstrates using serverless SQL as a
-- lightweight transformation engine, not just a read-only query tool.
CREATE EXTERNAL TABLE dbo.DailyTripSummary
WITH (
    LOCATION = 'daily_trip_summary/',
    DATA_SOURCE = nyc_taxi_raw,   -- points at raw; swap for a "curated" data source in production
    FILE_FORMAT = parquet_format
)
AS
SELECT
    CAST(tpepPickupDateTime AS DATE) AS trip_date,
    COUNT(*) AS trip_count,
    AVG(fareAmount) AS avg_fare,
    SUM(totalAmount) AS total_revenue
FROM dbo.YellowTaxiTrips
GROUP BY CAST(tpepPickupDateTime AS DATE);
GO
