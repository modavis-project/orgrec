#!/usr/bin/env python3
"""Prepare a VAO 0.6.0 preservation carrier and its migration receipt."""

from __future__ import annotations

import argparse
import hashlib
from io import BytesIO
import os
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory
from zipfile import ZipFile


# GitHub and Zenodo distribute the same reference wheel for VAO v0.6.0.
REFERENCE_WHEEL_BYTES = 468_079
REFERENCE_WHEEL_SHA256 = "fb65e0e76b9718cd97bc4433997811bcf886455fd1c6b66239e138fc239a9944"


def unpack_reference(wheel: Path, directory: Path) -> None:
    with wheel.open("rb") as stream:
        data = stream.read(REFERENCE_WHEEL_BYTES + 1)
    if len(data) != REFERENCE_WHEEL_BYTES or hashlib.sha256(data).hexdigest() != REFERENCE_WHEEL_SHA256:
        raise ValueError("Use the reference wheel from the published VAO v0.6.0 release.")
    with ZipFile(BytesIO(data)) as archive:
        archive.extractall(directory)


def run_reference(directory: Path, module: str, *arguments: Path | str) -> None:
    # Isolate imports from Tools/ (which contains the historical OrgRec validators).
    subprocess.run(
        [
            sys.executable, "-I", "-c",
            "import runpy,sys; sys.path.insert(0,sys.argv.pop(1)); "
            "module=sys.argv.pop(1); runpy.run_module(module,run_name='__main__',alter_sys=True)",
            directory, module, *arguments,
        ],
        check=True,
    )


def make_export(
    source: Path,
    output: Path,
    *,
    migrate_existing: bool,
    orgrec_tool: Path,
    reference_wheel: Path,
) -> Path:
    source = source.resolve(strict=True)
    orgrec_tool = orgrec_tool.resolve(strict=True)
    # Resolve the parent, but keep the output leaf so a dangling link still fails.
    output = output.parent.resolve(strict=True) / output.name
    if output.exists() or output.is_symlink():
        raise FileExistsError(f"Output already exists: {output}")
    if source.is_dir() and any(parent.samefile(source) for parent in output.parents):
        raise ValueError("Choose an output directory outside the source.")
    if migrate_existing and not source.is_file():
        raise ValueError("Migration takes an existing complete VAO 0.5.0 carrier.")
    if not migrate_existing and not source.is_dir():
        raise ValueError("Export takes an editable OrgRec project directory.")

    with TemporaryDirectory(prefix=".orgrec-vao06-", dir=output.parent) as temporary:
        staging = Path(temporary)
        reference = staging / "reference"
        unpack_reference(reference_wheel, reference)
        source_carrier = source
        if not migrate_existing:
            source_carrier = staging / "original.vao"
            subprocess.run([orgrec_tool, "vao-export", source, source_carrier], check=True)

        original = staging / "original-workspace"
        subprocess.run([orgrec_tool, "vao-workspace-import", source_carrier, original], check=True)
        if not migrate_existing:
            source_carrier.unlink()
        migrated = staging / "migrated-workspace"
        receipt = staging / "migration-receipt.json"
        # The released migration requires a valid 0.5.0 source and a complete closure.
        run_reference(reference, "migrate_vao05", original, migrated, "--receipt", receipt)
        shutil.rmtree(original)
        carrier_name = source.stem + ".vao"
        carrier = staging / carrier_name
        # The released packer also validates the finished archive.
        run_reference(reference, "vao06", "pack", migrated, carrier)

        # Claim this output only after both staged files are ready. An existing
        # directory or symlink, including one made by another export, wins.
        output.mkdir(mode=0o700)
        moved = []
        try:
            for artifact in (receipt, carrier):
                target = output / artifact.name
                os.rename(artifact, target)
                moved.append(target)
        except BaseException:
            for target in moved:
                target.unlink()
            output.rmdir()
            raise
    return output / carrier_name


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["export", "migrate"])
    parser.add_argument("source", type=Path, help="OrgRec project (export) or complete 0.5.0 carrier (migrate)")
    parser.add_argument("output", type=Path, help="New directory for the carrier and its receipt")
    parser.add_argument("--orgrec-tool", required=True, type=Path, help="Path to the built OrgRecDatasetTool")
    parser.add_argument("--reference-wheel", required=True, type=Path, help="Published VAO reference wheel for v0.6.0")
    args = parser.parse_args()
    try:
        carrier = make_export(
            args.source,
            args.output,
            migrate_existing=args.operation == "migrate",
            orgrec_tool=args.orgrec_tool,
            reference_wheel=args.reference_wheel,
        )
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f"VAO 0.6.0 export failed: {exc}\n")
    print(f"Verified VAO 0.6.0 carrier at {carrier}")
    print(f"Migration receipt at {carrier.parent / 'migration-receipt.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
