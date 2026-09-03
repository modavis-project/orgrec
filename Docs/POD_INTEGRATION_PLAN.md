# Reduced POD integration plan

Status: application boundary implemented; final dataset deposit pending

OrgRec is expected to use a highly reduced MODAVIS Pipe Organ Dataset (POD)
subset derived from Dataset Release 1.5. The import boundary is implemented;
the final subset identity and payload remain pending. This document fixes what
the separate dataset release must provide.

## Dataset identity

The reduced collection is a derivative dataset, not a renamed copy of POD
Release 1.5. Give it:

- its own title, semantic version, creators/contributors, release date, and
  Zenodo dataset DOI;
- an exact reference to the immutable POD 1.5 version identifier or DOI;
- a documented selection purpose and algorithm;
- its own license or a clear statement of the inherited per-item licenses;
- a change log independent of the OrgRec software version.

Use the exact POD 1.5 version identifier for provenance. A concept DOI or
project home page may be added for discovery but does not replace the version
pin.

## Selection manifest

Before copying any payload, create a machine-readable manifest containing:

- source dataset title, version, version identifier, and manifest SHA-256;
- subset title, version, creation time, and responsible agents;
- selection protocol identifier and source-code commit;
- each included source item identifier and source-relative path;
- source and subset SHA-256, byte size, media type, and technical metadata;
- instrument, division, stop/rank, pitch, channel, and take identifiers needed
  by the intended test;
- original and derivative license identifiers, rights holder, attribution, and
  any access or use condition;
- transformation activity and parameters for every changed byte stream;
- exclusions and their reasons;
- the expected aggregate counts and byte total.

Do not record workstation mount points, account names, access tokens, or
mutable download URLs as identity fields.

## Minimum useful subset

Select the smallest set that exercises the product claim. A defensible
integration fixture should cover only the required combinations, for example:

- at least two contrasting stops or ranks;
- more than one pitch where pitch-dependent behavior is under test;
- the metadata required to construct a roadmap and resolve audio;
- one expected import success and one deliberately invalid metadata case;
- explicit rights and provenance records.

Do not call the subset representative of POD 1.5 unless a separate sampling
analysis supports that claim. A compact interoperability example and a
scientific evaluation sample are different products and may need different
selection designs.

## Repository and Zenodo placement

Keep only the manifest, schema, tiny synthetic test material, and download or
verification tooling in the OrgRec repository. Deposit cleared POD-derived
payloads in a separate Zenodo dataset record. The application may support an
explicit user-initiated download, but it must verify the expected version,
length, and digest before using the data and must also work without network
access.

Do not use Git LFS to obscure the publication boundary. LFS is storage, not
rights management or dataset versioning.

## Application work

OrgRec 0.3.0 now provides:

- a versioned POD subset manifest decoder and validator;
- item and source identifier mapping that does not treat filenames as canonical
  organ identity;
- checksum-verified import with a staging directory and atomic commit;
- explicit handling for missing, extra, corrupt, and wrong-release files;
- UI and CLI wording that names the derivative subset and Release 1.5 source;
- a removable local cache with no bundled user recordings;
- a synthetic, source-free fixture for success and failure tests.

Export provenance that cites the final subset and exact source release cannot
be enabled until their version identifiers exist. The manifest validator
requires those fields for `published-subset` records and rejects a synthetic
fixture that impersonates a published identifier.

## Acceptance tests

The dataset integration is complete when tests demonstrate:

- clean acquisition from the published dataset record;
- anonymous resolution of the version DOI and every required file;
- exact manifest, file-count, byte-count, and SHA-256 agreement;
- deterministic selection or a frozen item inventory;
- rejection of altered bytes, wrong source release, duplicate identifiers, and
  path traversal;
- the same application result from a fresh offline cache;
- no unreviewed source data in the software source archive or app bundle;
- license and attribution display in the app and exported provenance.

Current automated tests cover exact local validation, staged import, altered
bytes, wrong source release, and path traversal. Acquisition, anonymous DOI
resolution, final aggregate checks, and fresh-cache scientific equivalence must
be completed against the published dataset record.

The dataset DOI, subset version, and checksums remain absent from release
metadata until the final deposit exists.
