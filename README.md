# Indego bike share: is H1 2026 growth real demand or just more stations?

Philadelphia's Indego system grew a lot in the first half of 2026. Some of that is expected because new stations opened. I wanted to know how much growth was left after accounting for the bigger network, and which bikes were driving it.

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

## How the numbers are defined

- H1 = trips that started January 1 to June 30.
- Trip minutes = sum of `duration` (minutes) from the trip files.
- Active station = a station with at least one trip starting there in the period.
- Minutes per station = trip minutes / active stations. This is the main check for "growth vs. expansion".

`h1_metrics.py` computes the same metrics in pandas from the raw trip files, plus monthly trips per station as a seasonality check.

```bash
pip install -r requirements.txt
# put indego-trips-YYYY-qN.csv files in data/
python h1_metrics.py
```

## Data

[Indego trip data](https://www.rideindego.com/about/data/), 2023 Q1 to 2026 Q2. Public, published quarterly.

## Limits

- The files only include completed trips. Demand that didn't happen because no bike or dock was available isn't visible, so this probably *understates* e-bike demand.
- Two half-years is a short comparison. Weather and events in either year could move the numbers a few points.
- "Active stations" counts a station from its first trip, so stations opened mid-period count as active for the whole half.
