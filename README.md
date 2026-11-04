# Indego bike share: is H1 2026 growth real demand or just more stations?

Philadelphia's Indego bike share grew a lot in the first half of 2026. Some of that is expected because new stations opened. I wanted to know how much growth was left after accounting for the bigger network, and which bikes were driving it.

**[Interactive dashboard on Tableau Public →](https://public.tableau.com/app/profile/emily.ou2684/viz/IndegoTablet2_17905244322180/Demandisoutpacingnetworkexpansionledbye-bikes)**

[![Dashboard](https://public.tableau.com/static/images/In/IndegoTablet2_17905244322180/Demandisoutpacingnetworkexpansionledbye-bikes/1.png)](https://public.tableau.com/app/profile/emily.ou2684/viz/IndegoTablet2_17905244322180/Demandisoutpacingnetworkexpansionledbye-bikes)

## What I found (H1 2026 vs. H1 2025)

| Metric | Change |
|---|---:|
| Trips | +21.5% |
| Trip minutes | +22.8% |
| Active stations | +16.1% |
| Minutes per active station | +5.8% |
| Average trip length | +1.1% |
| E-bike minutes | **+37.2%** |
| Standard bike minutes | −0.8% |

- Most of the growth comes from more stations, but not all of it. Minutes per station still went up about 6%, so existing capacity is being used harder.
- Trips are about as long as before (+1.1%), so the increase is more rides, not longer rides.
- The growth is almost entirely e-bikes. Standard bike usage was flat.

**Recommendation:** prioritize adding e-bikes and rebalancing them toward high-use stations, rather than only adding new stations with the current bike mix.

## Pipeline

All 4.9 million trips from 2023 Q1 to 2026 Q3 are rebuilt from Indego's raw quarterly files with DuckDB, inside GitHub Actions ([pipeline.yml](.github/workflows/pipeline.yml)). It runs monthly and picks up new quarters on its own.

```text
pipeline/download.py   finds and downloads every quarterly zip from 2023 on
sql/01_trips.sql       parses both date formats Indego has used, drops bad rows, logs what was dropped
sql/02_summaries.sql   builds the summary tables below
pipeline/build.py      runs the SQL and writes output/
```

| Output | What it is |
|---|---|
| [`quality_report.csv`](output/quality_report.csv) | rows loaded vs. kept, and why rows were dropped |
| [`monthly_system.csv`](output/monthly_system.csv) | trips, minutes and active stations per month, by bike type |
| [`station_month.csv`](output/station_month.csv) | starts, ends and net inflow per station per month |
| [`station_hour_profile.csv`](output/station_hour_profile.csv) | average starts per hour by station, weekday vs. weekend (last 12 months) |
| [`h1_check.csv`](output/h1_check.csv) | the H1 comparison above, recomputed from raw data |

The pipeline matches the Tableau numbers to within rounding (trips +21.49%, e-bike minutes +37.2%, stations +16.06%). The small gaps come from cleaning: 166 trips logged at Indego's virtual station (3000) are dropped.

### Definitions

- H1 = trips that started January 1 to June 30.
- Trip minutes = sum of `duration` (minutes) from the trip files.
- Active station = a station with at least one trip starting there in the period.
- Minutes per station = trip minutes / active stations. This is the main check for "growth vs. expansion".

To run locally:

```bash
pip install -r requirements.txt
python pipeline/download.py
python pipeline/build.py
```

## What's next

The trip files only show rides that happened. A separate repo, [indego-station-status-archive](https://github.com/emilyou561-beep/indego-station-status-archive), saves every station's bike and dock counts every 15 minutes. Combined with `station_hour_profile.csv`, that will show how many rides are lost to empty stations, and where adding e-bikes would recover the most.

## Data

[Indego trip data](https://www.rideindego.com/about/data/), 2023 Q1 to 2026 Q3. Public, published quarterly.

## Limits

- The files only include completed trips. Demand that didn't happen because no bike or dock was available isn't visible, so this probably *understates* e-bike demand.
- Two half-years is a short comparison. Weather and events in either year could move the numbers a few points.
- "Active stations" counts a station from its first trip, so stations opened mid-period count as active for the whole half.
