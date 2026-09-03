#!/usr/bin/env python3
"""OrgRec's independent release gate for the vendored VAO 0.5.0 contract."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import tempfile

import vao05


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Fixtures" / "VAO05" / "valid" / "minimal"
BUNDLE = ROOT / "Schemas" / "vao-release-bundle-0.5.0.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    bundle = json.loads(BUNDLE.read_text(encoding="utf-8"))
    require(bundle["formatVersion"] == "0.5.0", "Release bundle is not VAO 0.5.0.")
    checked = 0
    for artifact in bundle["artifacts"]:
        path = ROOT / artifact["path"]
        if not path.exists():
            continue
        data = path.read_bytes()
        require(len(data) == artifact["byteSize"], f"Byte size differs for {artifact['path']}.")
        require(hashlib.sha256(data).hexdigest() == artifact["sha256"], f"SHA-256 differs for {artifact['path']}.")
        checked += 1
    require(checked == 10, f"Expected ten vendored normative schema/semantic artifacts, checked {checked}.")

    workspace = vao05.validate(FIXTURE)
    require(workspace["valid"], "Reference workspace failed: " + "; ".join(workspace["errors"]))
    manifest = json.loads((FIXTURE / vao05.MANIFEST_NAME).read_text(encoding="utf-8"))
    require(vao05.validate_manifest(manifest)["valid"], "Reference manifest is invalid.")
    invalid = copy.deepcopy(manifest)
    invalid["formatVersion"] = "0.5"
    require(not vao05.validate_manifest(invalid)["valid"], "Draft version was accepted as final 0.5.0.")

    with tempfile.TemporaryDirectory(prefix="orgrec-vao05-") as temporary:
        carrier = Path(temporary) / "minimal.vao"
        vao05.pack_workspace(FIXTURE, carrier)
        packed = vao05.validate(carrier)
        require(packed["valid"], "Packed carrier failed: " + "; ".join(packed["errors"]))

    print(f"VAO 0.5.0 conformance PASS ({checked} normative artifacts, workspace, carrier, negative dispatch)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
