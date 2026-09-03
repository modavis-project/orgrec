# VAO 0.3.3 Zenodo repository profile

This is an OPTIONAL adapter profile. It is not a dependency of VAO Core, the carrier format, development, testing, private exchange, preservation closure, or dynamic delivery through another repository. A manifest with no Zenodo binding neither claims nor validates against this profile. `vao-release.json` and the Zenodo metadata projection are publication artifacts and are not required in an unpublished or repository-free VAO.

## Binding and exact acquisition

- Repository type: `https://w3id.org/modavis/vao/repository/zenodo`
- Adapter profile: `https://w3id.org/modavis/vao/repository/zenodo/records-api/1`
- Resolution policy: `version-pid-record-file`
- Production instance: `https://zenodo.org`
- Test instance: `https://sandbox.zenodo.org`

The instance identifies the service; it is not an API-base override. The client owns the trusted API configuration and host/redirect allowlist.

A Zenodo distribution uses a version-specific DOI URL in `persistentIdentifier`, an optional concept DOI in `conceptIdentifier` for discovery only, the decimal Zenodo record ID in `recordIdentifier`, the exact record file key in `fileIdentifier`, and an access expectation. A resolver fetches that exact record, confirms the DOI, selects exactly one matching file key, follows only locally trusted links, and verifies VAO byte size and SHA-256 before cache commit. Zenodo MD5 is supplementary transport evidence.

## Default topology: one modular record

The default is `publication.topology: "single-record"` when the complete publication fits the current repository limits and can share one access/licensing policy and one update lifecycle. “Single record” means one Zenodo record with multiple independently downloadable files, not one compulsory giant ZIP.

An ideal root record contains:

1. `vao-manifest.json`;
2. at least one small bootstrap `.vao` carrier;
3. the exact 3D model and audio realizations, or natural asset-pack archives with their pack manifests;
4. `vao-release.json`, which is intentionally not self-hashed inside its own inventory;
5. checksums, documentation, and an optional preview;
6. the saved VAO Zenodo metadata projection used for publication.

Zenodo currently documents a default limit of 100 files and 50 GB total per record, recommends an archive when a deposit has more than 20 files, and permits approved quota increases. These are service constraints, not VAO conformance rules and must be checked at publication time. The 50 GB figure is therefore a useful default decision boundary, not a permanent normative threshold. A producer should keep useful files independently downloadable and use ZIP only for a coherent pack, very large file sets, or formats that require directory structure.

## Optional topology: related record family

Use `publication.topology: "record-family"` only when at least one operational boundary justifies it: current size/file-count limits, different access or rights, independent version cycles, reuse by multiple VAOs, different ownership, or a legitimate separate citation unit. The root still contains the exact manifest and bootstrap carrier. Every member is pinned by its version PID, record ID, files, sizes, and SHA-256 values.

The release descriptor distinguishes two membership semantics:

| Membership | Root relation | Member inverse | Meaning |
| --- | --- | --- | --- |
| `exclusive` | `hasPart` | required `isPartOf` | The member belongs to this VAO release and reciprocal ownership is accurate. |
| `shared` | `requires`, `references`, `isSupplementedBy`, `isDocumentedBy`, or `isDerivedFrom` | optional corresponding inverse | The record is reusable or independently governed; no false one-root ownership is asserted. |

Family relations MUST use exact member version PIDs. A concept DOI may additionally appear as a discovery/update link, but MUST NOT replace the exact dependency. A reusable asset pack normally uses root `requires` and omits member `isPartOf`. A member exclusive to one root uses `hasPart`/`isPartOf`. Sources, documentation, and other related works can use the relation that states their actual semantics; they must not be called family members merely because they are cited.

The root DOI is the citation target for the VAO as a whole. A pack DOI may also be cited when the pack itself is the subject. The root `vao-release.json` is the machine-readable closure over exact family-member versions.

## Zenodo metadata projection

`Schemas/vao-zenodo-metadata-0.3.schema.json` defines `VAOZenodoMetadata`, a VAO binding around the Zenodo deposit API `metadata` object. A publisher submits only the nested `metadata` value to Zenodo and retains the wrapper as publication evidence.

The projection requires the fields needed for a discoverable, citable VAO: dataset resource type, descriptive title and description, creators, publication date, content version, access state, keywords, and an explicit `related_identifiers` array. Open and embargoed records require a license; embargoed and restricted records require their corresponding date or access conditions. Producers SHOULD supply, when known, creator/contributor identifiers and affiliations, contributor roles, language, subjects, collection/capture dates, method, references, communities, grants, and notes.

VAO fields map as follows:

| VAO source | Zenodo field |
| --- | --- |
| localized title and description | `title`, `description` |
| responsible agents and paradata | `creators`, typed `contributors` |
| `release.contentVersion` | root `version` |
| rights and access records | record-level `access_right`, `license`, embargo/access conditions |
| object type, collection, profiles, media | `keywords`, `subjects`, `language` |
| capture/creation events and method | `dates`, `method`, `references`, `notes` |
| family and source dependencies | `related_identifiers` using exact relation vocabulary |
| approved discovery/funding scope | `communities`, `grants` |

Record-level license metadata is a discovery summary and does not replace realization-level VAO rights. Assets with incompatible licenses or access policies should be split into a justified family record rather than flattened into an inaccurate root license.

## DOI reservation, publication, and versions

Reserve the DOI before final byte generation when a record’s own files must contain that DOI. After upload, compare every returned file key and size with the release descriptor, then publish. Publication does not make the concept DOI an exact resolver: runtime acquisition continues to use the record version DOI and record ID.

A new Zenodo version is a new record with separate metadata, files, and PID linked into Zenodo’s version chain. It may import unchanged files from the previous version. Under VAO policy, changed bytes or a changed manifest always require a new VAO release and repository version. VAO applies this stricter rule even where repository operations may allow a limited correction workflow.

## Discovery and operational states

Interactive clients may search published records by community, keywords, concept DOI, related identifiers, resource type, or version and then inspect the small release descriptor. Discovery results are never sufficient for byte acquisition until exact version, record, file, size, and SHA-256 checks pass.

The adapter reports availability, authentication, local-policy, and integrity independently. HTTP failure is not package corruption. A DOI, record ID, file key, size, or SHA-256 mismatch is an integrity failure and MUST NOT fall back silently to another version.

## Examples

- `Fixtures/VAO03/descriptors/release-single-record.example.json` with `zenodo-metadata-single-record.example.json` is the preferred complete-record form.
- `Fixtures/VAO03/descriptors/release-record-family.example.json` and its three metadata projections demonstrate an exclusive model pack and a shared audio dependency.
- `Release/VAO03Sandbox` is immutable historical 0.3.0 adapter evidence. It was not rewritten as a 0.3.3 publication and is not the ideal metadata example.
