#!/usr/bin/env python3
"""Create a reproducible coverage audit for the available VPO source collection."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import platform
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inventory", type=Path)
    parser.add_argument("native_inspection", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--catalog", type=Path)
    parser.add_argument("--root", type=Path, action="append", default=[])
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def counts(rows: list[dict], field: str) -> dict[str, int]:
    return dict(sorted(Counter((row.get(field) or "(unspecified)").strip() for row in rows).items()))


def yes(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes", "y"}


def main() -> int:
    args = parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with args.inventory.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    with args.native_inspection.open(encoding="utf-8") as handle:
        native = json.load(handle)

    representatives = [row for row in rows if yes(row.get("counted_distinct_representative"))]
    local_representatives = [row for row in representatives if yes(row.get("path_exists"))]
    grandorgue = [row for row in local_representatives if "grandorgue" in (row.get("native_platform") or "").lower()]
    pending = [row for row in local_representatives if row not in grandorgue]
    definition_counts = Counter(item.get("format", "unknown") for item in native.get("definitions", []))
    roots = []
    for root in args.root:
        roots.append({"path": str(root.resolve()), "exists": root.exists(), "is_directory": root.is_dir()})
    git_commit = None
    try:
        git_commit = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=Path(__file__).resolve().parents[2], check=True,
            capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        pass

    audit = {
        "contract": "orgrec-comparative-vpo-source-audit/1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_mutation_policy": "Read-only inspection of the supplied VPO roots; no source package, definition, manifest, directory, or sample was changed.",
        "reproducibility": {
            "command": " ".join(sys.argv),
            "script_path": str(Path(__file__).resolve()),
            "script_sha256": sha256(Path(__file__).resolve()),
            "git_commit": git_commit,
            "python": sys.version,
            "platform": platform.platform(),
        },
        "inputs": {
            "inventory_path": str(args.inventory.resolve()),
            "inventory_sha256": sha256(args.inventory),
            "native_inspection_path": str(args.native_inspection.resolve()),
            "native_inspection_sha256": sha256(args.native_inspection),
            "catalog_path": str(args.catalog.resolve()) if args.catalog else None,
            "catalog_sha256": sha256(args.catalog) if args.catalog else None,
            "roots": roots,
        },
        "inventory": {
            "record_count": len(rows),
            "distinct_representative_count": len(representatives),
            "local_distinct_representative_count": len(local_representatives),
            "by_native_platform": counts(representatives, "native_platform"),
            "by_producer": counts(representatives, "producer"),
            "by_country": counts(representatives, "country"),
            "by_license_class": counts(representatives, "license_class"),
        },
        "current_exact_mapping_adapter": {
            "format": "GrandOrgue",
            "eligible_local_representative_count": len(grandorgue),
            "coverage_fraction_of_local_representatives": len(grandorgue) / len(local_representatives) if local_representatives else 0,
            "pending_adapter_representative_count": len(pending),
            "pending_by_platform": counts(pending, "native_platform"),
            "scope_note": "Eligibility is an inventory route count. The retrieved-corpus build applies recording-basis, rights, parsing, label, pitch, and minimum-pipe filters and reports its own exclusions.",
        },
        "native_file_inspection": {
            "contract": native.get("contract"),
            "regular_file_count": native.get("regularFileCount"),
            "total_bytes": native.get("totalBytes"),
            "definition_count": len(native.get("definitions", [])),
            "definition_counts_by_format": dict(sorted(definition_counts.items())),
            "wav_metadata": native.get("wavMetadata"),
            "rights_evidence_path_count": len(native.get("rightsEvidencePaths", [])),
            "interpretation_caveats": native.get("interpretationCaveats", []),
        },
    }
    (args.output / "source-audit.json").write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    with (args.output / "source-inventory-adapter-coverage.csv").open("w", newline="", encoding="utf-8") as handle:
        fields = [
            "entity_id", "entity_name", "sampled_instrument_name", "producer", "country", "native_platform",
            "license_class", "path", "path_exists", "current_exact_mapping_adapter", "adapter_status",
        ]
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in representatives:
            current = yes(row.get("path_exists")) and "grandorgue" in (row.get("native_platform") or "").lower()
            writer.writerow({
                **{field: row.get(field, "") for field in fields},
                "current_exact_mapping_adapter": "yes" if current else "no",
                "adapter_status": "ready" if current else ("pending-format-adapter" if yes(row.get("path_exists")) else "not-local"),
            })

    platform_lines = "\n".join(
        f"- {name}: {value}" for name, value in audit["inventory"]["by_native_platform"].items()
    )
    definition_lines = "\n".join(
        f"- {name}: {value}" for name, value in audit["native_file_inspection"]["definition_counts_by_format"].items()
    )
    report = f"""# VPO source and adapter coverage audit

This audit separates the available collection from the subset the present comparative pipeline can decode semantically. It is a coverage statement, not a claim that every folder is an independent physical organ or legally redistributable.

## Available inventory

- Inventory records: **{len(rows)}**
- Distinct representative datasets: **{len(representatives)}**
- Locally present distinct representatives: **{len(local_representatives)}**
- Current exact GrandOrgue mapping route: **{len(grandorgue)}** locally present representatives ({audit['current_exact_mapping_adapter']['coverage_fraction_of_local_representatives']:.1%})
- Locally present representatives requiring another format adapter: **{len(pending)}**

Representative native-platform labels:

{platform_lines}

## Filesystem-scale inspection

The supplied immutable native inspection indexes **{native.get('regularFileCount', 0):,} regular files** ({native.get('totalBytes', 0):,} bytes), **{len(native.get('definitions', []))} detected definition files**, and the following definition formats:

{definition_lines}

Only GrandOrgue currently has a reviewed importer that resolves stop/rank definitions to exact audio files before OrgRec analysis. Counting WAV files alone would inflate sample size, mix noise/release/room channels with pipes, and break the rank–instrument hierarchy. Hauptwerk, jOrgan, SF2, Kontakt, and other formats therefore remain documented future adapter work rather than being silently treated as equivalent observations.

## Rights and identity boundary

The inventory's licence class and the inspection's rights-evidence paths are discovery metadata. They do not establish redistribution permission for every sample. Corpus construction keeps the roots read-only, preserves dataset and sampled-organ identifiers separately, and records all inclusion/exclusion decisions. Scientific summaries may be distributed independently of source audio only after the intended rights review.

Machine-readable provenance, hashes, root availability, producer/country/licence distributions, and pending adapter routes are in `source-audit.json`; the row-level adapter table is `source-inventory-adapter-coverage.csv`.
"""
    (args.output / "SOURCE_AUDIT.md").write_text(report, encoding="utf-8")
    print(f"Audited {len(representatives)} representative datasets; wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
