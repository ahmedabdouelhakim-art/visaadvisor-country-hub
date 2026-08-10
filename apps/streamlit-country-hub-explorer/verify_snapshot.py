"""Pre-deployment contract check for the read-only Streamlit presentation layer."""

from __future__ import annotations

import csv
from pathlib import Path


EXPECTED = {
    "places.csv": 21,
    "country-planning-profiles.csv": 12,
    "sources.csv": 58,
    "field-evidence.csv": 150,
    "coverage-matrix.csv": 9,
    "datasets.csv": 2,
}


def main() -> None:
    repository_root = Path(__file__).resolve().parents[2]
    release_dir = repository_root / "data" / "seed" / "v0.1.0"

    for filename, expected_count in EXPECTED.items():
        with (release_dir / filename).open("r", encoding="utf-8-sig", newline="") as handle:
            count = sum(1 for _ in csv.DictReader(handle))
        if count != expected_count:
            raise SystemExit(
                f"FAIL: {filename} has {count} rows; expected {expected_count} for CH-0.1.0."
            )
        print(f"PASS: {filename} — {count} rows")


if __name__ == "__main__":
    main()
