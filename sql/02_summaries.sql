-- System-wide monthly volume by bike type
CREATE OR REPLACE TABLE monthly_system AS
SELECT
    DATE_TRUNC('month', start_time)::DATE  AS month,
    bike_type,
    COUNT(*)                               AS trips,
    SUM(duration_min)                      AS trip_minutes,
    ROUND(AVG(duration_min), 2)            AS avg_duration_min,
    COUNT(DISTINCT start_station)          AS active_stations
FROM trips
GROUP BY ALL
ORDER BY month, bike_type;

-- Starts and ends per station per month
CREATE OR REPLACE TABLE station_month AS
WITH starts AS (
    SELECT start_station AS station_id, DATE_TRUNC('month', start_time)::DATE AS month,
           COUNT(*) AS starts,
           COUNT(*) FILTER (WHERE bike_type = 'electric') AS ebike_starts
    FROM trips GROUP BY ALL
), ends AS (
    SELECT end_station AS station_id, DATE_TRUNC('month', end_time)::DATE AS month,
           COUNT(*) AS ends
    FROM trips WHERE end_station IS NOT NULL AND end_station <> 3000 AND end_time IS NOT NULL
    GROUP BY ALL
)
SELECT
    COALESCE(s.station_id, e.station_id)   AS station_id,
    COALESCE(s.month, e.month)             AS month,
    COALESCE(s.starts, 0)                  AS starts,
    COALESCE(s.ebike_starts, 0)            AS ebike_starts,
    COALESCE(e.ends, 0)                    AS ends,
    COALESCE(e.ends, 0) - COALESCE(s.starts, 0) AS net_inflow
FROM starts s
FULL JOIN ends e USING (station_id, month)
ORDER BY station_id, month;

-- Average starts per hour for each station, weekday vs weekend, last 12 months.
-- This is the "expected demand" baseline used later to price out empty-station hours.
CREATE OR REPLACE TABLE station_hour_profile AS
WITH bounds AS (
    SELECT DATE_TRUNC('month', MAX(start_time)) + INTERVAL 1 MONTH AS period_end FROM trips
), period AS (
    SELECT period_end - INTERVAL 12 MONTH AS period_start, period_end FROM bounds
), calendar AS (
    -- how many weekday / weekend days are in the window, so counts become rates
    SELECT CASE WHEN ISODOW(d) >= 6 THEN 'weekend' ELSE 'weekday' END AS day_type,
           COUNT(*) AS n_days
    FROM period, generate_series(period_start, period_end - INTERVAL 1 DAY, INTERVAL 1 DAY) AS g(d)
    GROUP BY 1
), counts AS (
    SELECT
        start_station AS station_id,
        CASE WHEN ISODOW(start_time) >= 6 THEN 'weekend' ELSE 'weekday' END AS day_type,
        HOUR(start_time) AS hour,
        COUNT(*) AS starts,
        COUNT(*) FILTER (WHERE bike_type = 'electric') AS ebike_starts
    FROM trips, period
    WHERE start_time >= period_start AND start_time < period_end
    GROUP BY ALL
)
SELECT
    c.station_id, c.day_type, c.hour,
    c.starts, c.ebike_starts,
    ROUND(c.starts / cal.n_days, 4)        AS starts_per_hour,
    ROUND(c.ebike_starts / cal.n_days, 4)  AS ebike_starts_per_hour
FROM counts c
JOIN calendar cal USING (day_type)
ORDER BY station_id, day_type, hour;

-- H1 2025 vs H1 2026, to check the pipeline against the Tableau dashboard
CREATE OR REPLACE TABLE h1_check AS
WITH h1 AS (
    SELECT YEAR(start_time) AS yr, *
    FROM trips
    WHERE MONTH(start_time) <= 6 AND YEAR(start_time) IN (2025, 2026)
), y AS (
    SELECT yr,
           COUNT(*)::DOUBLE                                          AS trips,
           SUM(duration_min)::DOUBLE                                 AS trip_minutes,
           AVG(duration_min)                                         AS avg_duration,
           COUNT(DISTINCT start_station)::DOUBLE                     AS active_stations,
           SUM(duration_min) / COUNT(DISTINCT start_station)         AS minutes_per_station,
           SUM(duration_min) FILTER (WHERE bike_type = 'electric')::DOUBLE AS ebike_minutes,
           SUM(duration_min) FILTER (WHERE bike_type = 'standard')::DOUBLE AS standard_minutes
    FROM h1 GROUP BY yr
)
UNPIVOT y ON trips, trip_minutes, avg_duration, active_stations, minutes_per_station, ebike_minutes, standard_minutes
INTO NAME metric VALUE value;
