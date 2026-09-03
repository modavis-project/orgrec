# VAO 0.3.1 change record

Date: 2026-08-24  
Status: implemented private editor's draft  
Compatibility classification: pre-public contract correction

## Decision

An update was required. VAO 0.3.0 already separated logical assets, exact realizations, distributions, carriers, and repository bindings, but its publication descriptor modeled exactly one repository record. It could not unambiguously express the recommended one-record default, an optional root/member family, reusable versus exclusive members, the file roles of a modular record, or the Zenodo `related_identifiers` metadata that projects those relations.

VAO 0.3.1 closes that gap without making Zenodo, a DOI, a repository, or network access mandatory. The semantic manifest remains repository-neutral. Publication descriptors and Zenodo metadata projections are only used when a VAO is published through those mechanisms.

## Normative changes

- The exact current format version is `0.3.1` in manifest, carrier, release, pack, and receipt artifacts.
- `vao-release.json` now declares `publication.topology` as `single-record` or `record-family`.
- A publication record has an internal ID, repository identity, exact version PID, optional concept PID, record ID, and a typed file inventory.
- One modular record is the default. Its files remain independently downloadable; the standard does not require one giant archive.
- A family is justified by size/file-count, access/rights, independent lifecycle, reuse, ownership, or separate citation boundaries.
- Exclusive members require `hasPart`/`isPartOf`. Shared members use actual dependency, reference, supplement, documentation, or source relations and do not imply exclusive ownership.
- Relations bind exact version PIDs. Concept PIDs are discovery/update channels only.
- `vao-release.json` is omitted from its own file inventory to avoid a circular digest.
- `VAOZenodoMetadata` binds one publication record to a validated Zenodo deposit metadata object and covers creators, contributors, access/license, keywords, related identifiers, communities, grants, references, subjects, dates, language, notes, and method.
- Python and Swift validators cross-check topology, PID identity, file inventory, root/member roles, and exact Zenodo relation projections.

## Compatibility and migration

This correction supersedes the unpublished 0.3.0 snapshot without retaining compatibility with that draft. A 0.3.0 draft is migrated by regenerating the manifest/carrier descriptors with `formatVersion: "0.3.1"`, recalculating the manifest binding, and replacing its old `repositoryRecord` release descriptor with the new `publication` object. Published historical evidence must not be rewritten or relabeled.

VAO 0.2.2 remains a separate preserved compatibility line and its migration path now targets 0.3.1.

## Publication examples

- `release-single-record.example.json` and `zenodo-metadata-single-record.example.json` show the preferred sub-50-GB-style modular record with manifest, bootstrap carrier, model, audio pack, and metadata.
- `release-record-family.example.json` shows an exclusive 3D model record and a reusable audio record. The accompanying root/member metadata files demonstrate `hasPart`/`isPartOf` and one-way `requires` semantics.

The 50 GB and 100-file values are current Zenodo defaults, not VAO requirements. Publication tooling must query or verify current repository policy. Other repositories, local files, private exchange, and fully embedded carriers remain valid.

## Historical Sandbox evidence

The Zenodo Sandbox record at version DOI `10.5072/zenodo.590947` remains immutable 0.3.0 adapter evidence. It was read anonymously during this evaluation to confirm its DOI and file inventory, but it was not modified and no 0.3.1 Sandbox record was created. The normative 0.3.1 topology and metadata examples use non-resolving example identifiers and must not be cited as publications.
