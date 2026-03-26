#!/usr/bin/env python3
"""Patch Grafana dashboard datasource UIDs.

Recursively walks all JSON objects in a dashboard file and replaces the
``uid`` value of any ``{"type": "prometheus", "uid": "..."}`` object
with the target UID.  This normalises upstream dashboards (which may
embed arbitrary datasource UIDs) to match the UIDs provisioned by the
horde_monitoring role.

Usage:
    patch_dashboard_uid.py <dashboard.json> <target-uid>

The file is modified in-place.
"""
import json
import sys
from pathlib import Path


def patch(obj, uid):
    """Recursively replace datasource UIDs in prometheus-typed objects."""
    if isinstance(obj, dict):
        if obj.get("type") == "prometheus" and "uid" in obj:
            obj["uid"] = uid
        for v in obj.values():
            patch(v, uid)
    elif isinstance(obj, list):
        for v in obj:
            patch(v, uid)


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <dashboard.json> <target-uid>", file=sys.stderr)
        sys.exit(1)

    path = Path(sys.argv[1])
    uid = sys.argv[2]

    data = json.loads(path.read_text())
    patch(data, uid)
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
