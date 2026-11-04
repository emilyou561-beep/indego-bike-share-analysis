"""Run the SQL in sql/ against data/raw/ and write the summary tables to output/.

    python pipeline/download.py
    python pipeline/build.py
"""

from pathlib import Path

import duckdb

SQL_DIR = Path("sql")
OUT = Path("output")
DB = Path("data/indego.duckdb")

EXPORT = ["quality_report", "monthly_system", "station_month", "station_hour_profile"]


def main() -> None:
    OUT.mkdir(exist_ok=True)
    con = duckdb.connect(str(DB))

    for f in sorted(SQL_DIR.glob("*.sql")):
        print("running", f.name)
        con.execute(f.read_text())

    for t in EXPORT:
        con.execute(f"COPY {t} TO '{OUT / t}.csv' (HEADER)")

    h1 = (con.execute("SELECT metric, yr, value FROM h1_check").df()
            .pivot(index="metric", columns="yr", values="value")
            .rename(columns=str).reset_index())
    h1["change_pct"] = (h1["2026"] / h1["2025"] - 1) * 100
    h1.round(2).to_csv(OUT / "h1_check.csv", index=False)

    print(con.execute("SELECT * FROM quality_report").df().to_string(index=False))
    print()
    print(h1.round(2).to_string(index=False))


if __name__ == "__main__":
    main()
