#!/usr/bin/env python3
"""Audit the local OrgRec source boundary and list external publication gates."""

from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parent.parent
GIT_WARNING_BYTES = 50 * 1024 * 1024
PRIVATE_PATH = re.compile(r"/(?:Users|Volumes)/[^\s\"']+")
TARGET_VERSION = "0.3.1"
TARGET_BUILD = "9"


def git(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *arguments],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def public_source_files() -> list[Path]:
    """Return the current source candidate, including intended untracked files.

    Staged removals and ignored local data are excluded. This matches the file
    set used to create a clean first public repository.
    """
    result = git("ls-files", "--cached", "--others", "--exclude-standard", "-z")
    if result.returncode:
        return []
    return [ROOT / name for name in result.stdout.split("\0") if name and (ROOT / name).exists()]


def text(path: str) -> str:
    candidate = ROOT / path
    return candidate.read_text(encoding="utf-8") if candidate.is_file() else ""


def main() -> int:
    files = public_source_files()
    relative = {path.relative_to(ROOT).as_posix() for path in files}
    blockers: list[dict[str, object]] = []
    external: list[dict[str, object]] = []
    warnings: list[dict[str, object]] = []

    required_licensing = [
        "LICENSE",
        "LICENSES/Apache-2.0.txt",
        "LICENSES/CC-BY-4.0.txt",
        "LICENSES/MIT.txt",
        "REUSE.toml",
        "THIRD_PARTY_NOTICES.md",
    ]
    missing = [name for name in required_licensing if not (ROOT / name).is_file()]
    if missing:
        blockers.append({"code": "license", "detail": "Licensing files are missing.", "files": missing})

    required_vao = [
        "Schemas/vao-manifest-0.5.0.schema.json",
        "Schemas/vao-carrier-0.5.0.schema.json",
        "Schemas/vao-release-bundle-0.5.0.json",
        "Sources/OrgRecCore/VAO05Models.swift",
        "Sources/OrgRecCore/VAO05PackageBuilder.swift",
        "Tools/vao05.py",
        "Tools/test_vao05_conformance.py",
        "Fixtures/VAO05/valid/minimal/vao-manifest.json",
    ]
    missing = [name for name in required_vao if not (ROOT / name).is_file()]
    if missing:
        blockers.append({"code": "vao-0.5.0", "detail": "The pinned VAO 0.5.0 implementation is incomplete.", "files": missing})

    required_pod = [
        "Sources/OrgRecCore/PODSubset.swift",
        "Tests/OrgRecCoreTests/PODSubsetTests.swift",
        "Schemas/orgrec-pod-subset-1.schema.json",
        "Tools/test_pod_subset_contract.py",
        "Fixtures/POD/valid/synthetic-minimal/pod-subset-manifest.json",
    ]
    missing = [name for name in required_pod if not (ROOT / name).is_file()]
    if missing:
        blockers.append({"code": "pod-contract", "detail": "The reduced POD import contract is incomplete.", "files": missing})

    restricted_prefix = "Fixtures/VAO04/valid/cuntz-positiv-acoustic-test/"
    if any(name.startswith(restricted_prefix) for name in relative):
        blockers.append({"code": "restricted-fixture", "detail": "The rights-restricted Cuntz payload remains tracked."})
    generated = sorted(name for name in relative if name.startswith("Artifacts/") and name != "Artifacts/README.md")
    if generated:
        blockers.append({"code": "generated-artifacts", "detail": "Generated research artifacts remain in the public source set.", "examples": generated[:20]})
    if "Sources/OrgRecCore/Resources/empirical-timbre-model-v1.json" in relative:
        blockers.append({"code": "unreleased-model", "detail": "The classifier awaiting POD/model-card review remains tracked."})

    private_paths = []
    for path in files:
        try:
            if path.stat().st_size > 10 * 1024 * 1024:
                continue
            contents = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        if PRIVATE_PATH.search(contents):
            private_paths.append(path.relative_to(ROOT).as_posix())
    if private_paths:
        blockers.append({
            "code": "workstation-paths",
            "detail": "Tracked text contains personal workstation or mounted-volume paths.",
            "count": len(private_paths),
            "examples": private_paths[:20],
        })

    software = text("Sources/OrgRecCore/SoftwareVersion.swift")
    plist = text("Packaging/Info.plist")
    citation = text("CITATION.cff")
    version_ok = (
        f'public static let version = "{TARGET_VERSION}"' in software
        and f'public static let build = "{TARGET_BUILD}"' in software
        and f"<string>{TARGET_VERSION}</string>" in plist
        and f"<string>{TARGET_BUILD}</string>" in plist
        and f'version: "{TARGET_VERSION}"' in citation
        and "license: Apache-2.0" in citation
    )
    if not version_ok:
        blockers.append({"code": "version", "detail": f"App, package, and citation metadata must agree at {TARGET_VERSION} build {TARGET_BUILD}."})

    large = []
    for path in files:
        try:
            size = path.stat().st_size
        except OSError:
            continue
        if size > GIT_WARNING_BYTES:
            large.append({"path": path.relative_to(ROOT).as_posix(), "byteSize": size})
    if large:
        blockers.append({
            "code": "large-git-objects",
            "detail": "Tracked files exceed GitHub's 50 MiB warning threshold.",
            "files": sorted(large, key=lambda item: int(item["byteSize"]), reverse=True),
        })

    remote = git("remote", "get-url", "origin")
    if remote.returncode or not remote.stdout.strip():
        external.append({"code": "repository-url", "detail": "Create the public repository and set its durable origin URL."})
    if "repository-code:" not in citation:
        external.append({"code": "citation-repository", "detail": "Insert the issued public repository URL in CITATION.cff."})
    if not re.search(r"(?m)^doi:\s*[\"']?10\.\d+", citation):
        external.append({"code": "software-doi", "detail": "Publish the Zenodo software record and insert its version DOI after issuance."})
    elif not (ROOT / "Release/zenodo-published.json").is_file():
        external.append({
            "code": "zenodo-draft",
            "detail": "The reserved software DOI remains attached to an unpublished Zenodo draft.",
        })
    if not (ROOT / "Release/pod-subset-manifest.json").is_file():
        external.append({"code": "pod-deposit", "detail": "The separately published reduced POD dataset manifest and DOI are not final."})

    history = git("rev-list", "--objects", "--all")
    if history.returncode == 0 and (
        "Fixtures/VAO04/valid/cuntz-positiv-acoustic-test/" in history.stdout
        or "Artifacts/CuntzPositivVAO04/" in history.stdout
    ):
        external.append({
            "code": "clean-public-history",
            "detail": "Private history contains excluded material; create the public repository from a clean export or reviewed rewritten history.",
        })

    tag = git("rev-parse", "-q", "--verify", f"refs/tags/v{TARGET_VERSION}")
    if tag.returncode:
        external.append({"code": "release-tag", "detail": f"Create the reviewed signed tag v{TARGET_VERSION}."})

    status = git("status", "--porcelain")
    if status.stdout.strip():
        warnings.append({"code": "worktree", "detail": "The release worktree is not clean; tag only after review and commit."})
    warnings.append({
        "code": "binary-distribution",
        "detail": "Any public app binary still needs Developer ID signing, notarization, Gatekeeper, hardware, and accessibility evidence.",
    })

    result = {
        "project": "OrgRec",
        "targetVersion": TARGET_VERSION,
        "targetBuild": TARGET_BUILD,
        "sourceCandidateReady": not blockers,
        "publicationReady": not blockers and not external,
        "sourceBlockers": blockers,
        "externalPublicationGates": external,
        "warnings": warnings,
    }
    print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True))
    return 0 if not blockers else 1


if __name__ == "__main__":
    raise SystemExit(main())
