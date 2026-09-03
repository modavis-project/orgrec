#!/usr/bin/env python3
"""Schema-level checks for the OrgRec reduced POD subset manifest contract."""

from __future__ import annotations

import copy
import json
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker


ROOT = Path(__file__).resolve().parent.parent
SCHEMA = json.loads((ROOT / "Schemas/orgrec-pod-subset-1.schema.json").read_text(encoding="utf-8"))
FIXTURE = json.loads((ROOT / "Fixtures/POD/valid/synthetic-minimal/pod-subset-manifest.json").read_text(encoding="utf-8"))


def main() -> int:
    Draft202012Validator.check_schema(SCHEMA)
    validator = Draft202012Validator(SCHEMA, format_checker=FormatChecker())
    cases: list[tuple[str, bool]] = []

    def valid(name: str, value: dict) -> None:
        cases.append((name, not list(validator.iter_errors(value))))

    def invalid(name: str, value: dict) -> None:
        cases.append((name, bool(list(validator.iter_errors(value)))))

    valid("synthetic fixture", FIXTURE)

    wrong_release = copy.deepcopy(FIXTURE)
    wrong_release["source"]["releaseVersion"] = "1.4"
    invalid("wrong source release", wrong_release)

    traversal = copy.deepcopy(FIXTURE)
    traversal["files"][0]["path"] = "../records.jsonl"
    invalid("path traversal", traversal)

    fake_publication = copy.deepcopy(FIXTURE)
    fake_publication["publicationStatus"] = "published-subset"
    invalid("published record requires final identifiers", fake_publication)

    synthetic_with_doi = copy.deepcopy(FIXTURE)
    synthetic_with_doi["dataset"]["persistentIdentifier"] = "https://doi.org/10.0000/not-issued"
    invalid("synthetic fixture cannot impersonate DOI", synthetic_with_doi)

    failures = [name for name, passed in cases if not passed]
    for name, passed in cases:
        print(f"{'PASS' if passed else 'FAIL'}  {name}")
    print(f"{len(cases) - len(failures)}/{len(cases)} POD contract checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
