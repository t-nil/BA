#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "requests<3",
# ]
# ///

import csv
import json
import os
import time
from datetime import datetime, timezone
import requests

BASE = "https://services.nvd.nist.gov/rest/json/cves/2.0"

KEYWORD = "filesystem"
KERNEL_CPE_SUBSTR = "cpe:2.3:o:linux:linux_kernel"

# Optional: restrict to a time window (recommended)
# Example: last 10 years relative to today (adjust as you like)
PUB_START = "2016-02-14T00:00:00.000Z"
PUB_END   = "2026-02-14T23:59:59.999Z"

# Optional: if you have an NVD API key, set NVD_API_KEY env var
API_KEY = os.getenv("NVD_API_KEY")

def cve_matches_linux_kernel(cve_item: dict) -> bool:
    """
    Check whether the CVE's configurations contain Linux-kernel CPE match criteria.
    The NVD API returns CPE match criteria inside the 'configurations' object.
    """
    configs = cve_item.get("cve", {}).get("configurations", [])
    # configurations is an array of nodes; each node can contain cpeMatch entries
    # We'll scan the serialized config chunk for the substring (simple + robust).
    try:
        blob = json.dumps(configs, ensure_ascii=False)
    except Exception:
        return False
    return KERNEL_CPE_SUBSTR in blob

def extract_row(cve_item: dict) -> dict:
    cve = cve_item["cve"]
    cve_id = cve["id"]
    published = cve.get("published")
    last_modified = cve.get("lastModified")

    # English description if present
    desc = ""
    for d in cve.get("descriptions", []):
        if d.get("lang") == "en":
            desc = d.get("value", "")
            break

    # CVSS v3.1 (most common); fall back to v4.0 if present
    score = ""
    severity = ""
    metrics = cve.get("metrics", {})
    if "cvssMetricV31" in metrics and metrics["cvssMetricV31"]:
        cvss = metrics["cvssMetricV31"][0].get("cvssData", {})
        score = cvss.get("baseScore", "")
        severity = cvss.get("baseSeverity", "")
    elif "cvssMetricV40" in metrics and metrics["cvssMetricV40"]:
        cvss = metrics["cvssMetricV40"][0].get("cvssData", {})
        score = cvss.get("baseScore", "")
        severity = cvss.get("baseSeverity", "")

    return {
        "cve_id": cve_id,
        "published": published,
        "last_modified": last_modified,
        "severity": severity,
        "score": score,
        "description": desc,
    }

def main():
    headers = {"Accept": "application/json"}
    if API_KEY:
        headers["apiKey"] = API_KEY

    results_per_page = 2000  # max allowed per NVD docs
    start_index = 0
    kept = []
    total = None

    while True:
        params = {
            "keywordSearch": KEYWORD,
            "resultsPerPage": results_per_page,
            "startIndex": start_index,
            "pubStartDate": PUB_START,
            "pubEndDate": PUB_END,
            # If you later identify the right string for your CNA/source filter,
            # you can add: "sourceIdentifier": "<value>"
        }

        r = requests.get(BASE, params=params, headers=headers, timeout=60)
        r.raise_for_status()
        data = r.json()

        if total is None:
            total = data.get("totalResults", 0)

        vulns = data.get("vulnerabilities", [])
        if not vulns:
            break

        for item in vulns:
            if cve_matches_linux_kernel(item):
                kept.append(item)

        start_index += len(vulns)

        if start_index >= total:
            break

        # Be polite to the API (especially without an API key)
        time.sleep(0.7)

    # Write JSON (full kept records)
    out_json = "nvd_filesystem_linux_kernel.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(kept, f, ensure_ascii=False, indent=2)

    # Write CSV (a compact table)
    out_csv = "nvd_filesystem_linux_kernel.csv"
    fieldnames = ["cve_id", "published", "last_modified", "severity", "score", "description"]
    with open(out_csv, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for item in kept:
            w.writerow(extract_row(item))

    print(f"Done. Kept {len(kept)} CVEs.")
    print(f"Wrote: {out_json}")
    pr
