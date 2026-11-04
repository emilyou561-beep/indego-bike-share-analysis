"""H1 2025 vs H1 2026 metrics for Indego bike share, same definitions as the Tableau dashboard.

Download the quarterly trip files from https://www.rideindego.com/about/data/
and put them in data/ (e.g. indego-trips-2025-q1.csv ... indego-trips-2026-q2.csv).

    python h1_metrics.py
"""

from pathlib import Path

import pandas as pd

DATA_DIR = Path("data")
YEARS = [2025, 2026]


def load_trips(data_dir: Path) -> pd.DataFrame:
    files = sorted(data_dir.glob("indego-trips-*.csv"))
    if not files:
        raise SystemExit(f"No trip files found in {data_dir}/")
    trips = pd.concat(
        (pd.read_csv(f, usecols=["trip_id", "duration", "start_time", "start_station", "bike_type"])
         for f in files),
        ignore_index=True,
    )
    trips["start_time"] = pd.to_datetime(trips["start_time"], format="mixed")
    return trips.drop_duplicates("trip_id")


def h1_only(trips: pd.DataFrame) -> pd.DataFrame:
    t = trips[trips.start_time.dt.year.isin(YEARS) & (trips.start_time.dt.month <= 6)].copy()
    t["year"] = t.start_time.dt.year
    return t


def summarize(h1: pd.DataFrame) -> pd.DataFrame:
    by_year = h1.groupby("year").agg(
        trips=("trip_id", "count"),
        trip_minutes=("duration", "sum"),
        avg_duration=("duration", "mean"),
        active_stations=("start_station", "nunique"),
    )
    by_year["minutes_per_station"] = by_year.trip_minutes / by_year.active_stations

    by_type = h1.pivot_table(index="year", columns="bike_type", values="duration", aggfunc="sum")
    by_type.columns = [f"{c}_minutes" for c in by_type.columns]

    out = by_year.join(by_type).T
    out["change_pct"] = (out[2026] / out[2025] - 1) * 100
    return out.round(2)


def seasonality_check(trips: pd.DataFrame) -> pd.DataFrame:
    """Monthly trips per active station. If growth were only new stations,
    this would stay flat year over year."""
    t = trips.copy()
    t["month"] = t.start_time.dt.to_period("M")
    m = t.groupby("month").agg(trips=("trip_id", "count"), stations=("start_station", "nunique"))
    m["trips_per_station"] = (m.trips / m.stations).round(1)
    return m


if __name__ == "__main__":
    trips = load_trips(DATA_DIR)
    print(summarize(h1_only(trips)).to_string())
    print()
    print(seasonality_check(trips).tail(18).to_string())
