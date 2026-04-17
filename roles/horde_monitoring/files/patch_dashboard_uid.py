#!/usr/bin/env python3
"""Patch Grafana dashboard datasource references.

Recursively walks all JSON objects in a dashboard file and patches
datasource references so provisioned dashboards bind to the datasource
configured for the target org.

Supported rewrites:
- Legacy panel objects with ``{"type": "prometheus", "uid": "..."}``
- Any ``uid`` field using a Grafana datasource variable (for example ``${DS_PROMETHEUS}``)
- V2 resources with ``{"datasource": {"name": "${DS_PROMETHEUS}"}}``
- Datasource variable defaults for ``DS_PROMETHEUS`` (``current.text/value``)

Usage:
    patch_dashboard_uid.py <dashboard.json> <target-uid> [target-datasource-name]

The file is modified in-place.
"""
import json
import re
import sys
from pathlib import Path

_DS_VAR_RE = re.compile(r'^\$\{DS_[^}]*\}$')


def _is_ds_var(value):
    return isinstance(value, str) and _DS_VAR_RE.match(value)


def patch(obj, uid, datasource_name=None):
    """Recursively replace datasource references in legacy and v2 dashboards."""
    if isinstance(obj, dict):
        # Legacy panel shape: {"type": "prometheus", "uid": "..."}
        if obj.get("type") == "prometheus" and "uid" in obj:
            obj["uid"] = uid

        # Generic UID replacement for datasource-variable UID placeholders.
        if "uid" in obj and _is_ds_var(obj["uid"]):
            obj["uid"] = uid

        # Grafana v2 panel/query shape often stores datasource as nested object.
        datasource = obj.get("datasource")
        if isinstance(datasource, dict):
            if "uid" in datasource and _is_ds_var(datasource["uid"]):
                datasource["uid"] = uid
            if datasource_name and "name" in datasource and _is_ds_var(datasource["name"]):
                datasource["name"] = datasource_name

        # Keep DS_PROMETHEUS variable default aligned with target datasource.
        if (
            datasource_name
            and obj.get("name") == "DS_PROMETHEUS"
            and isinstance(obj.get("current"), dict)
        ):
            obj["current"]["text"] = datasource_name
            obj["current"]["value"] = datasource_name

        for v in obj.values():
            patch(v, uid, datasource_name)
    elif isinstance(obj, list):
        for v in obj:
            patch(v, uid, datasource_name)


def main():
    if len(sys.argv) not in (3, 4):
        print(
            f"Usage: {sys.argv[0]} <dashboard.json> <target-uid> [target-datasource-name]",
            file=sys.stderr,
        )
        sys.exit(1)

    path = Path(sys.argv[1])
    uid = sys.argv[2]
    datasource_name = sys.argv[3] if len(sys.argv) == 4 else None

    data = json.loads(path.read_text())
    patch(data, uid, datasource_name)
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
