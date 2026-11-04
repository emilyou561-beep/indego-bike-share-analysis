"""Download Indego quarterly trip files (2023 Q1 onward) into data/raw/.

Links are scraped from the Indego data page, so new quarters get picked up
automatically. Files already on disk are skipped.
"""

import io
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

DATA_PAGE = "https://www.rideindego.com/about/data/"
RAW = Path("data/raw")
FIRST_YEAR = 2023
UA = {"User-Agent": "Mozilla/5.0 (indego-bike-share-analysis)"}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def trip_links(html: str) -> dict[str, str]:
    """Map 'YYYY-qN' -> zip url."""
    links = {}
    for url in re.findall(r'href="([^"]+indego-trips-(\d{4})-[qQ](\d)[^"]*\.zip)"', html):
        href, year, q = url
        if int(year) >= FIRST_YEAR:
            links[f"{year}-q{q}"] = href
    return dict(sorted(links.items()))


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    links = trip_links(fetch(DATA_PAGE).decode("utf-8", "ignore"))
    if not links:
        sys.exit("no trip files found on the data page, check the regex")

    for quarter, url in links.items():
        out = RAW / f"indego-trips-{quarter}.csv"
        if out.exists():
            print(f"{quarter}: cached")
            continue
        with zipfile.ZipFile(io.BytesIO(fetch(url))) as z:
            csv_name = next(n for n in z.namelist() if n.lower().endswith(".csv") and "__MACOSX" not in n)
            out.write_bytes(z.read(csv_name))
        print(f"{quarter}: {out.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
