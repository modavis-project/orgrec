# OrgRec

OrgRec is a native macOS application for documented pipe-organ recording. It
turns an instrument specification into a field-work roadmap, records
multichannel Broadcast Wave audio, retains capture and review provenance, and
exports research packages for preservation and exchange.

The current source release is OrgRec 0.3.1, build 9, tagged `v0.3.1` in
`modavis-project/orgrec`. The preceding 0.3.0 release is archived at
[`10.5281/zenodo.22216026`](https://doi.org/10.5281/zenodo.22216026).
The 0.3.0 macOS candidate is ad-hoc signed; version 0.3.1 is a source update.
Developer ID signing and notarization remain required for normal Gatekeeper
distribution.

## Capabilities

- MODAVIS Navigator search and specification-bound recording roadmaps;
- session planning, equipment and microphone-geometry records, and field QA;
- Core Audio input selection and multichannel 24-bit PCM BWF recording;
- signal-path rehearsal, live meters, pitch checks, and capture-integrity gates;
- review, non-destructive analysis, long-take segmentation, and sustained-loop
  inspection;
- editable `.orgrec` projects and checked VAO/IAD import and export;
- dataset and GrandOrgue conversion tools;
- exact validation, offline search, and roadmap import for the POD 1.5 SQLite database.

OrgRec requires macOS 14 or later. Capture and hardware behavior are macOS-only;
the Python VAO reference tools are cross-platform.

## VAO 0.5.0

VAO 0.5.0 is the default public export format. OrgRec writes a self-contained
preservation closure, verifies its carrier mappings and payload digests, and
cross-checks generated packages with the independent Python validator.

The implementation is pinned to the final standard release:

- version: `0.5.0`;
- DOI: [`10.5281/zenodo.22214248`](https://doi.org/10.5281/zenodo.22214248);
- release commit: `ad2d4f0`;
- release-bundle SHA-256:
  `d98cd8453a776217d9e7bd457ea50e5be087e04f1db36869b9935806e84c15b8`.

The application retains version-specific readers for exact VAO 0.4.0 and 0.3.3
packages and a historical 0.2 reader. It does not reinterpret a near version as
0.5.0. The compatibility declaration is in
[`Docs/VAO_0.5.0_MIGRATION_PLAN.md`](Docs/VAO_0.5.0_MIGRATION_PLAN.md).

## POD 1.5 local database

The separately published, reduced MODAVIS Pipe Organ Dataset 1.5 OrgRec
projection is an optional read-only SQLite catalogue. OrgRec can retrieve or
select it, verify SQLite integrity, Release 1.5 metadata, the required schema,
FTS5 indexes, relationships, byte size, and pinned SHA-256, then atomically
cache it for offline organ search and roadmap creation. No POD database or raw
source media are included in this repository.

The private Zenodo draft was verified; its access URL is intentionally not
stored. The public URL will be added after publication. See
[`Docs/POD_INTEGRATION_PLAN.md`](Docs/POD_INTEGRATION_PLAN.md) for the pinned
artifact identity, observed row counts, commands, and compatibility limits.

## Build

Requirements:

- macOS 14 or later;
- Xcode 16 or later with Swift 6 support;
- Python 3.12 for the VAO reference validator.

Run from source:

```sh
swift run OrgRec
```

Build a universal arm64/x86_64, ad-hoc-signed application bundle:

```sh
Scripts/build-app.sh
open dist/OrgRec.app
```

An externally distributed binary must be Developer ID signed, notarized,
stapled, and checked with Gatekeeper. The local build script does not claim to
produce that release artifact.

## Test

```sh
python3 -m pip install -r requirements-vao05.txt
VAO05_REFERENCE_PYTHON=python3 swift test
python3 Tools/test_vao_conformance.py
python3 Tools/test_vao03_conformance.py
python3 Tools/test_vao04_conformance.py
python3 Tools/test_vao05_conformance.py
```

The hardware-independent writer stress check is:

```sh
swift run -c release OrgRecStress --duration 30 --channels 8 --sample-rate 96000
```

Hardware, permission, interruption, accessibility, signing, and notarization
checks are tracked in
[`Docs/APPLICATION_QUALITY_AUDIT.md`](Docs/APPLICATION_QUALITY_AUDIT.md).

## Command-line examples

```sh
swift run OrgRecDatasetTool vao-validate Instrument.vao
swift run OrgRecDatasetTool vao-inspect Instrument.vao inspection.json
swift run OrgRecDatasetTool pod-db-validate /path/to/modavis-pod-1.5-orgrec.sqlite
swift run OrgRecDatasetTool pod-db-search /path/to/modavis-pod-1.5-orgrec.sqlite "St Laurentius"
python3 Tools/vao05.py validate Instrument.vao
```

Historical conformance tools remain under `Tools/` and are not the default
writer path.

## Repository boundary

Generated research outputs, converted third-party sample sets, restricted
interoperability material, and locally trained models are excluded from the
public software source set. `Artifacts/README.md` documents the local output
directory. Public fixtures are compact, synthetic, or carry explicit source
license evidence.

The repository audit is:

```sh
python3 Tools/audit_public_release.py
```

Because earlier private commits contained restricted and machine-specific
material, the first public repository must be created from a clean exported
source snapshot or from reviewed rewritten history. Removing files only from the
latest commit is insufficient.

## Documentation

- [Public-release readiness](Docs/PUBLIC_RELEASE_READINESS.md)
- [Application quality audit](Docs/APPLICATION_QUALITY_AUDIT.md)
- [Scientific methods](Docs/SCIENTIFIC_METHODS.md)
- [Project library and package behavior](Docs/PROJECT_LIBRARY.md)
- [Field QA and paradata](Docs/FIELD_QA_AND_PARADATA.md)
- [Audio and spectral analysis](Docs/AUDIO_AND_SPECTRAL_ANALYSIS.md)
- [VAO 0.5.0 implementation and compatibility](Docs/VAO_0.5.0_MIGRATION_PLAN.md)
- [Reduced POD integration](Docs/POD_INTEGRATION_PLAN.md)

## Privacy, security, citation, and license

Projects may contain recordings, venue coordinates, contributor names, rights
statements, and unpublished research data. Review every export before sharing
it. See [`PRIVACY.md`](PRIVACY.md), [`SECURITY.md`](SECURITY.md), and
[`SUPPORT.md`](SUPPORT.md).

Software citation metadata is in [`CITATION.cff`](CITATION.cff). The repository
URL and published Zenodo version DOI are recorded there. The repository remains
private while its source-publication review is completed.

OrgRec code is licensed under Apache-2.0; documentation, schemas, semantic
artifacts, metadata, and synthetic fixtures are licensed under CC-BY-4.0 unless
a narrower notice applies. The exact path mapping is in `REUSE.toml`, and
third-party attribution is in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
