# VAO 0.3.2 implementation report

Historical implementation snapshot: 2026-08-24.
OrgRec 0.3.0 uses VAO 0.5.0 for new exports; see the
[current compatibility guide](VAO_0.5.0_MIGRATION_PLAN.md).

## Data model

The 0.3 line separates logical assets, exact byte realizations, distributions,
repository records, carrier contents, and local materialization receipts.
The release manifest identifies the scientific content; a carrier records the
realizations embedded in a particular package. A preservation closure embeds
the complete required set.

Repository use is optional. Fully embedded carriers support offline validation
and exchange. Zenodo is one repository adapter, not a dependency of VAO Core.
Single-record and record-family publication descriptors bind exact version
identifiers and typed file inventories. Concept identifiers serve discovery,
not dependency resolution.

Acoustic scenes distinguish source and receiver identities from response-file
storage. Geometry declares coordinate frames and transformations. The playable
profile supports sample regions, loop points, tuning maps, microphone
perspectives, note-on/note-off variants, and key/velocity mappings.

## Validation and security

Python and Swift implementations validate semantic references, carrier
inventories, payload sizes and digests, and publication descriptors. JSON
readers reject duplicate properties and non-finite numbers. Archive readers
reject unsafe paths, links, duplicate entries, encryption, unsupported
compression, and resource-limit violations.

Materialization planning is side-effect-free. Downloads use locally configured
repository adapters and are verified before cache insertion. Package metadata
cannot provide credentials, replace API endpoints, or widen host allowlists.

## Compatibility

Version 0.3.2 superseded the unpublished 0.3.0 and 0.3.1 draft contracts.
VAO 0.2.2 remained a separate compatibility line. The historical Zenodo Sandbox
record `10.5072/zenodo.590947` documents the 0.3.0 adapter experiment, not the
later standard release.

Detailed contracts and changes are recorded in:

- [VAO 0.3 specification](VAO_STANDARD_0.3.md);
- [conformance requirements](VAO_CONFORMANCE_0.3.md);
- [0.3.2 changes](VAO_0.3.2_CHANGELOG.md);
- [0.2-to-0.3 migration](VAO_0.2_TO_0.3_MIGRATION.md);
- [acoustic scenes](VAO_ACOUSTIC_SCENES_0.3.md);
- [Zenodo adapter profile](VAO_ZENODO_PROFILE_0.3.md).

## Regression checks

The maintained 0.3 conformance suite checks the final 0.3.3 contract, including
the data-model and validation features introduced in 0.3.2:

```sh
python3 Tools/test_vao03_conformance.py
python3 Tools/test_vao_conformance.py
swift test --no-parallel
```
