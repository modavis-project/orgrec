# VAO 0.5.0 implementation and compatibility

Status: implemented against the final VAO 0.5.0 release

OrgRec pins VAO 0.5.0 to release commit `ad2d4f0`, DOI
`10.5281/zenodo.22214248`, and release-bundle SHA-256
`d98cd8453a776217d9e7bd457ea50e5be087e04f1db36869b9935806e84c15b8`.
The vendored schema, context, vocabulary, mapping, shapes, carrier and release
schemas, and bundle descriptor match that release byte for byte.

## Implemented behavior

- exact `formatVersion` dispatch before version-specific decoding;
- isolated 0.5.0 manifest and carrier models, including the required carrier
  identifier and carrier-member distribution fields;
- structural, identifier, reference, profile, path, size, and SHA-256 checks;
- preservation-closure carrier inspection and verified realization extraction;
- verified workspace import with cleanup on failure;
- self-contained OrgRec project export with a closed payload inventory;
- final MODAVIS binding, explicit rights state, and typed export provenance;
- independent Python validation of the normative fixture and Swift-generated
  packages in CI;
- offline verification of every normative release-bundle artifact.

OrgRec-generated packages declare Core, Dynamic Delivery, and the limited
Scientific registry needed for software/export provenance. Detailed OrgRec
project records remain identified payload bytes. The exporter does not invent
scientific assertions, permissions, or descriptive certainty that are absent
from the project.

## Compatibility declaration

| Operation | Supported behavior |
| --- | --- |
| Read VAO 0.5.0 | Exact validation, inspection, workspace import, and realization extraction |
| Write VAO 0.5.0 | Default; self-contained preservation closure |
| Read VAO 0.4.0 | Exact historical read-only workspace path |
| Read VAO 0.3.3 | Exact historical read-only workspace path |
| Read VAO 0.2.x | Historical OrgRec project importer |
| Write historical VAO | Not exposed by the public application or current CLI |
| Generic 0.4-to-0.5 migration | Not implemented; no semantic fields are guessed |
| Edit an arbitrary foreign VAO graph | Not claimed; the verified workspace is preserved |

VAO 0.5.0 is a compatible semantic extension of 0.4.0, but compatibility does
not make the two JSON contracts interchangeable. Near versions such as `0.5`
or an editor's draft are rejected.

## Profile handling

OrgRec validates the required core graph, fixity, carrier mapping, and profile
references. Registries outside the application feature set are decoded as
lossless JSON values for inspection and preservation; that does not mean OrgRec
executes their runtime semantics. A package passing validation is not by itself
a claim that the application can render every represented modality.

## Verification

The implementation is covered by:

- `Tests/OrgRecCoreTests/VAO05Tests.swift`;
- `Tools/test_vao05_conformance.py`;
- `Fixtures/VAO05/valid/minimal`;
- CI execution with `VAO05_REFERENCE_PYTHON=python3`.

The normative Python tool remains the release cross-check for schema and
semantic conformance. Native Swift validation additionally enforces the
application's archive and materialization safety boundary.

## Remaining release actions

No VAO contract work is pending for OrgRec 0.3.0. The remaining actions are
release operations: tag the clean public source snapshot, publish the GitHub
and Zenodo software records, and record their immutable identifiers and
checksums. Changes to VAO itself belong in the separate VAO standard project.
