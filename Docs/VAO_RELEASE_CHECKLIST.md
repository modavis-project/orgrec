# VAO release checklist

Use this checklist for every numbered VAO release. A tag or archive must not be
described as a complete release while a required item is unresolved.

## Contract freeze

- [x] Version selected as `0.2.2`, with `0.2.1` recorded as its immediate
  predecessor; the backward-compatible patch classification, unchanged 0.2
  compatibility line, validity of conforming 0.2.0/0.2.1 packages, inherited
  0.1 migration, forward-compatibility limit, and private status are
  documented.
- [x] Specification identifies normative versus informative material.
- [x] Container, schema, semantic, profile, security, rights, and versioning
  requirements are documented.
- [x] MODAVIS ontology status and mapping version are explicit and independent.
- [x] The schema, context, and profile IRIs remain on the 0.2 compatibility
  line, while the exact-release IRI, writer format version, vocabulary, VAOM,
  OrgRec, and mapping metadata agree on 0.2.2.
- [x] Earlier unpublished `1.0.0` wording is recorded as superseded.

## Evidence and interoperability

- [x] Minimal non-organ fixture validates and round-trips.
- [x] Minimal playable-profile fixture validates and is included as a packed
  release example.
- [x] Positive fixture validates sampled playback, source-bound extraction,
  acoustical observations, exact-frame clocks, and unique-key tuning maps.
- [x] Swift-generated output validates the optional
  `collection-acoustic-diagnostics` capability, its exact assessed take inputs,
  frozen parameter fingerprint and activity, the
  `evidence-qualified-collection-acoustic-diagnostics` record, and all eight
  governed collection observations.
- [x] Collection evidence tests retain per-take eligibility, exclusions,
  quality tiers and flags; distinguish insufficient evidence from a measured
  zero; preserve declared versus inferred rank grouping; and keep session
  offset separate from identifiable within-target session drift.
- [x] Collection rank curves and stretch, anomaly candidates, and similarity
  candidates use their governed aggregation identifiers and units. Similarity
  interpretations contain “candidate” and do not assert physical identity,
  shared pipes, construction, or a documentary component relation.
- [x] Positive acoustic-room fixture validates semantic building geometry,
  coordinate/pose contracts, AES69 response metadata, ISO metric arrays,
  spatial audio scene bindings, and tracked-listener fallback behavior.
- [x] Private 0.1 copy migration leaves the source unchanged, retains its
  manifest as hashed evidence, records migration paradata, and produces a
  conforming 0.2 workspace.
- [x] Negative cases reject corrupt fixity, unindexed files, missing rights,
  unsafe manifest/archive paths, incompatible versions, unknown standard
  fields, invalid sample ranges, duplicate tuning entries, unbound extraction
  regions, incomplete exact-frame clocks, invalid cent IRIs, malformed
  collection evidence counts, inputs, observations, aggregations, units, drift
  applicability, or candidate wording, and invalid optional/OrgRec profile
  claims.
- [x] Swift writer output validates in the independent Python validator.
- [x] OrgRec VAO imports losslessly after validation.
- [x] Full Swift tests and production build pass.
- [x] PositivXR multimedia migration and acceptance criteria are documented.
- [x] Existing-audio conversion lifecycle, GrandOrgue adapter contract, and
  machine-readable import-evidence schema are documented.
- [x] The historical Bureå GrandOrgue acceptance record is retained with its
  original private 0.1 profile identifiers and explicitly excluded from 0.2
  conformance claims until that conversion is re-run and migrated.

## Publication package

- [x] Changelog, governance, conformance, VAOM, OrgRec profile, generic
  conversion, adapter, case-study, and migration documentation are included.
- [x] Implementer guidance separates checksum-pinned private development from
  public production adoption and defines a safe importer/playable-profile path.
- [x] Release builder creates a clean versioned directory, checksum manifest,
  and distributable ZIP without modifying normative sources.
- [x] Release verifier detects version drift and checksum mismatch.
- [x] Creator, ORCID, affiliations, citation template, and no-publish metadata
  are recorded without claiming institutional endorsement.
- [x] Common `https://w3id.org/modavis/` route architecture is prepared in the
  MODAVIS ontology workspace.
- [x] MODAVIS Release 1.3 is isolated as a vocabulary/mapping gate rather than
  a blocker for unrelated preparation.
- [ ] Copyright holders approve the release license. Proposed policy: CC BY 4.0
  for specification/schema/vocabulary/documentation and Apache-2.0 for reference
  code. Do not add license claims until authorized.
- [ ] Maintainers provide the public repository URL, contact/security address,
  and citation authorship metadata.
- [ ] MODAVIS ontology version IRI, VAO mapping IRI, and immutable Release 1.3
  vocabulary release IRI/manifest checksum are pinned.
- [ ] Domain, ontology-engineering, preservation/security, and independent
  implementation reviewers are named and their reviews are resolved.

## Namespace and distribution

- [ ] Namespace owner deploys and tests all reserved `w3id.org` redirects.
- [ ] Maintainers decide whether the public draft retains the provisional vendor
  media type or begins an IANA registration process.
- [ ] Release tag, source archive, generated release ZIP, SHA-256 file, and
  conformance results are published together.
- [ ] Published downloads are tested from a clean machine on macOS, Linux, and
  Windows with Python 3; the OrgRec implementation is additionally tested on its
  supported macOS version.
- [ ] Announcement clearly says “VAO 0.2 public draft,” lists known limitations,
  and provides the feedback/change-proposal route.

The unchecked items require authority or infrastructure not present in the
source tree. They are deliberate release gates, not facts that implementations
may infer.
