-- =============================================================================
-- 02_analysis_queries.sql
--
-- Analytical queries against the YellowTaxiTrips external table.
-- Run after 01_create_external_objects.sql. Each query scans only the
-- Parquet columns it references (columnar pruning), keeping the amount of
-- data scanned - and therefore the cost - low even against millions of rows.
--
-- Note: puLocationId, doLocationId, rateCodeId, and paymentType are all
-- VARCHAR in this table (the underlying Parquet stores them as strings
-- despite looking numeric) - cast to INT where numeric sorting/comparison
-- is needed.
-- =============================================================================

-- 1. Trip volume by day of month
SELECT
    CAST(tpepPickupDateTime AS DATE) AS trip_date,
    COUNT(*) AS trip_count
FROM dbo.YellowTaxiTrips
GROUP BY CAST(tpepPickupDateTime AS DATE)
ORDER BY trip_date;

-- 2. Average fare and trip distance by hour of day
SELECT
    DATEPART(HOUR, tpepPickupDateTime) AS pickup_hour,
    COUNT(*) AS trip_count,
    AVG(fareAmount) AS avg_fare,
    AVG(tripDistance) AS avg_distance_miles
FROM dbo.YellowTaxiTrips
WHERE fareAmount > 0 AND tripDistance > 0
GROUP BY DATEPART(HOUR, tpepPickupDateTime)
ORDER BY pickup_hour;

-- 3. Tip percentage by payment type
-- paymentType: '1' = credit card, '2' = cash, '3' = no charge, '4' = dispute
-- Cash tips aren't recorded in the trip data, so type '2' shows ~0% here -
-- that's a real characteristic of the dataset, not a query bug.
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

-- 4. Top 10 busiest pickup zones
SELECT TOP 10
    CAST(puLocationId AS INT) AS puLocationId,
    COUNT(*) AS pickup_count,
    AVG(totalAmount) AS avg_total_fare
FROM dbo.YellowTaxiTrips
GROUP BY puLocationId
ORDER BY pickup_count DESC;

-- 5. Trip duration vs. fare - flag likely data quality issues
-- (very short trips with high fares, or long trips with $0 fare)
SELECT
    vendorID,
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

-- 6. CETAS example: write a curated, aggregated dataset back to the data
-- lake in Parquet format - demonstrates using serverless SQL as a
-- lightweight transformation engine, not just a read-only query tool.
CREATE EXTERNAL TABLE dbo.DailyTripSummary
WITH (
    LOCATION = 'daily_trip_summary/',
    DATA_SOURCE = nyc_taxi_raw,
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
