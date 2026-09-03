#!/usr/bin/env python3
"""Optional, locally configured Zenodo resolver for VAO 0.3 distributions.

The manifest identifies an adapter and instance but cannot supply API bases,
host allowlists, credentials, redirect rules, or trust policy. Those values are
compiled into this adapter or supplied by the invoking application.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, build_opener

import vao03


INSTANCES = {
    "production": {
        "identity": "https://zenodo.org",
        "apiBase": "https://zenodo.org/api",
        "allowedHosts": {"zenodo.org"},
        "doiPrefixes": ("10.5281/zenodo.",),
    },
    "sandbox": {
        "identity": "https://sandbox.zenodo.org",
        "apiBase": "https://sandbox.zenodo.org/api",
        "allowedHosts": {"sandbox.zenodo.org"},
        "doiPrefixes": ("10.5072/zenodo.",),
    },
}
MAX_METADATA_BYTES = 16 * 1024 * 1024
CHUNK = 1024 * 1024


class ResolverError(vao03.VAO03Error):
    pass


def doi_value(value: str) -> str:
    prefix = "https://doi.org/"
    return value[len(prefix):] if value.startswith(prefix) else value


def safe_request(url: str, configuration: dict[str, Any], *, token: str | None = None) -> Request:
    parsed = urlsplit(url)
    if parsed.scheme != "https" or parsed.hostname not in configuration["allowedHosts"]:
        raise ResolverError(f"Adapter policy blocks URL host or scheme: {url}")
    headers = {"Accept": "application/json", "User-Agent": "VAO-0.3-reference-resolver/0.3.3"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return Request(url, headers=headers)


def fetch_json(url: str, configuration: dict[str, Any], token: str | None) -> dict[str, Any]:
    request = safe_request(url, configuration, token=token)
    try:
        with build_opener().open(request, timeout=30) as response:
            final = response.geturl()
            safe_request(final, configuration)
            data = response.read(MAX_METADATA_BYTES + 1)
    except (HTTPError, URLError, TimeoutError, OSError) as exc:
        raise ResolverError(f"Zenodo metadata request failed: {exc}") from exc
    if len(data) > MAX_METADATA_BYTES:
        raise ResolverError("Zenodo metadata response exceeds the adapter limit")
    try:
        value = json.loads(data.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ResolverError(f"Zenodo returned invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ResolverError("Zenodo record response is not an object")
    return value


def file_records(record: dict[str, Any]) -> list[dict[str, Any]]:
    files = record.get("files", [])
    if isinstance(files, list):
        return [value for value in files if isinstance(value, dict)]
    if isinstance(files, dict):
        entries = files.get("entries", {})
        if isinstance(entries, dict):
            return [dict(value, key=value.get("key", key)) for key, value in entries.items() if isinstance(value, dict)]
    return []


def resolve(
    manifest_path: Path,
    distribution_id: str,
    instance_name: str,
    *,
    output: Path | None = None,
    metadata_only: bool = False,
    token: str | None = None,
) -> dict[str, Any]:
    manifest, _ = vao03.load_json(manifest_path)
    validation = vao03.validate_manifest(manifest)
    if not validation["valid"]:
        raise ResolverError("Manifest is invalid: " + "; ".join(validation["errors"][:8]))
    configuration = INSTANCES[instance_name]
    distributions = {value["id"]: value for value in manifest["distributions"]}
    distribution = distributions.get(distribution_id)
    if not distribution or distribution.get("kind") != "repository":
        raise ResolverError(f"No repository distribution {distribution_id!r}")
    bindings = {value["id"]: value for value in manifest["repositoryBindings"]}
    binding = bindings.get(distribution.get("repositoryBindingId"))
    if not binding or binding.get("repositoryType") != "https://w3id.org/modavis/vao/repository/zenodo":
        raise ResolverError("Distribution is not bound to the Zenodo adapter")
    if binding.get("instance") != configuration["identity"]:
        raise ResolverError("Manifest instance does not match the locally selected adapter instance")
    if binding.get("apiProfile") != "https://w3id.org/modavis/vao/repository/zenodo/records-api/1" or binding.get("resolutionPolicy") != "version-pid-record-file":
        raise ResolverError("Unsupported Zenodo adapter profile or resolution policy")
    expected_doi = doi_value(distribution["persistentIdentifier"])
    if not expected_doi.startswith(configuration["doiPrefixes"]):
        raise ResolverError("Version DOI does not belong to the selected adapter instance")
    record_id = distribution["recordIdentifier"]
    if not record_id.isdecimal():
        raise ResolverError("Zenodo recordIdentifier must be decimal")
    record_url = f"{configuration['apiBase']}/records/{record_id}"
    record = fetch_json(record_url, configuration, token)
    actual_id = str(record.get("id", record.get("recid", "")))
    actual_doi = str(record.get("doi") or record.get("pids", {}).get("doi", {}).get("identifier", ""))
    if actual_id != record_id:
        raise ResolverError(f"Record ID mismatch: expected {record_id}, got {actual_id}")
    if actual_doi != expected_doi:
        raise ResolverError(f"Version DOI mismatch: expected {expected_doi}, got {actual_doi}")
    matches = [value for value in file_records(record) if value.get("key") == distribution["fileIdentifier"]]
    if len(matches) != 1:
        raise ResolverError("Exact Zenodo file key does not resolve exactly once")
    file_record = matches[0]
    realizations = {value["id"]: value for value in manifest["realizations"]}
    owners = [value for value in realizations.values() if distribution_id in value.get("distributionIds", [])]
    if len(owners) != 1:
        raise ResolverError("Distribution must be referenced by exactly one realization")
    realization = owners[0]
    if file_record.get("size") != realization["byteSize"]:
        raise ResolverError(f"Repository file size mismatch: expected {realization['byteSize']}, got {file_record.get('size')}")
    report: dict[str, Any] = {
        "valid": True,
        "state": "repository-binding-valid",
        "instance": instance_name,
        "recordId": record_id,
        "versionDOI": actual_doi,
        "fileIdentifier": distribution["fileIdentifier"],
        "realizationId": realization["id"],
        "expectedByteSize": realization["byteSize"],
        "expectedSHA256": realization["sha256"],
        "repositoryChecksum": file_record.get("checksum"),
    }
    if metadata_only:
        return report
    link = file_record.get("links", {}).get("self") or file_record.get("links", {}).get("content")
    if not isinstance(link, str):
        raise ResolverError("Zenodo file record has no trusted content link")
    request = safe_request(link, configuration, token=token)
    destination = output
    if destination is not None and destination.exists():
        raise ResolverError(f"Output already exists: {destination}")
    temporary_parent = destination.parent if destination is not None else Path(tempfile.gettempdir())
    temporary_parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(prefix=".vao03-download-", dir=temporary_parent)
    os.close(file_descriptor)
    temporary = Path(temporary_name)
    try:
        digest = hashlib.sha256()
        size = 0
        try:
            with build_opener().open(request, timeout=120) as response, temporary.open("wb") as stream:
                safe_request(response.geturl(), configuration)
                while True:
                    block = response.read(CHUNK)
                    if not block:
                        break
                    size += len(block)
                    if size > realization["byteSize"]:
                        raise ResolverError("Download exceeds the declared realization size")
                    digest.update(block)
                    stream.write(block)
                stream.flush()
                os.fsync(stream.fileno())
        except (HTTPError, URLError, TimeoutError, OSError) as exc:
            raise ResolverError(f"Zenodo file download failed: {exc}") from exc
        actual_sha = digest.hexdigest()
        if size != realization["byteSize"] or actual_sha != realization["sha256"]:
            raise ResolverError(f"Downloaded realization fails VAO fixity: size={size}, sha256={actual_sha}")
        if destination is not None:
            os.replace(temporary, destination)
        report.update({"state": "verified", "actualByteSize": size, "actualSHA256": actual_sha, "output": str(destination) if destination else None})
        return report
    finally:
        temporary.unlink(missing_ok=True)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Resolve an optional VAO 0.3 Zenodo distribution under local trust policy")
    result.add_argument("manifest")
    result.add_argument("distribution_id")
    result.add_argument("--instance", choices=sorted(INSTANCES), required=True)
    result.add_argument("--metadata-only", action="store_true")
    result.add_argument("--output")
    result.add_argument("--json", action="store_true")
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        report = resolve(
            Path(args.manifest), args.distribution_id, args.instance,
            output=Path(args.output) if args.output else None,
            metadata_only=args.metadata_only,
            token=os.environ.get("ZENODO_TOKEN"),
        )
    except ResolverError as exc:
        report = {"valid": False, "state": "integrity-failed", "error": str(exc)}
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(("VALID" if report["valid"] else "INVALID") + f": {report.get('state')}")
        if not report["valid"]: print(f"error: {report['error']}")
    return 0 if report["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
