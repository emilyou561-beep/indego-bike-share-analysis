-- Load every quarterly file as text, then parse.
-- Date format changed in 2026 (m/d/yyyy h:mm -> yyyy-mm-dd hh:mm:ss), so try both.

CREATE OR REPLACE TABLE raw_trips AS
SELECT *
FROM read_csv('data/raw/indego-trips-*.csv',
              header = true, all_varchar = true, union_by_name = true, filename = true);

CREATE OR REPLACE TABLE parsed AS
SELECT
    TRY_CAST(trip_id AS BIGINT)                                   AS trip_id,
    TRY_CAST(duration AS INTEGER)                                 AS duration_min,
    COALESCE(TRY_STRPTIME(start_time, '%Y-%m-%d %H:%M:%S'),
             TRY_STRPTIME(start_time, '%m/%d/%Y %H:%M'))          AS start_time,
    COALESCE(TRY_STRPTIME(end_time, '%Y-%m-%d %H:%M:%S'),
             TRY_STRPTIME(end_time, '%m/%d/%Y %H:%M'))            AS end_time,
    TRY_CAST(start_station AS INTEGER)                            AS start_station,
    TRY_CAST(end_station AS INTEGER)                              AS end_station,
    LOWER(TRIM(bike_type))                                        AS bike_type,
    TRIM(passholder_type)                                         AS passholder_type,
    TRIM(trip_route_category)                                     AS route_type,
    regexp_extract(filename, 'indego-trips-(\d{4}-q\d)', 1)       AS source_quarter
FROM raw_trips;

-- Station 3000 is Indego's "virtual station" for bikes checked in by staff.
-- Trips over 24h are almost always lost or unreturned bikes.
CREATE OR REPLACE TABLE trips AS
SELECT *
FROM parsed
WHERE trip_id IS NOT NULL
  AND start_time IS NOT NULL
  AND start_station IS NOT NULL AND start_station <> 3000
  AND duration_min BETWEEN 1 AND 1440
QUALIFY ROW_NUMBER() OVER (PARTITION BY trip_id ORDER BY start_time) = 1;

CREATE OR REPLACE TABLE quality_report AS
SELECT 'rows loaded'                 AS check_name, COUNT(*) AS n FROM raw_trips
UNION ALL SELECT 'unparseable start_time', COUNT(*) FROM parsed WHERE start_time IS NULL
UNION ALL SELECT 'virtual station 3000',   COUNT(*) FROM parsed WHERE start_station = 3000
UNION ALL SELECT 'duration < 1 or > 24h',  COUNT(*) FROM parsed WHERE duration_min NOT BETWEEN 1 AND 1440
UNION ALL SELECT 'duplicate trip_id',      COUNT(*) - COUNT(DISTINCT trip_id) FROM parsed
UNION ALL SELECT 'rows kept',              COUNT(*) FROM trips;
