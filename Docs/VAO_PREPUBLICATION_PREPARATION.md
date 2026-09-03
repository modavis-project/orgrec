# VAO prepublication preparation

Status: private preparation; no publication authorized  
Target: VAO `0.2.2` first public draft  
Common identifier architecture: `https://w3id.org/modavis/`

## Work completed without publication

- normative and informative artifacts are separated;
- deterministic package and conformance builders exist;
- creator, ORCID, and affiliation metadata are recorded without implying
  institutional endorsement;
- governance, security, contribution, versioning, and compatibility policies
  exist;
- the exact-release and compatibility-line PID pattern is prepared;
- the MODAVIS interoperability term ledger separates reusable, provisional,
  external, and container-only terms;
- the backward-compatible 0.2.2 collection-acoustic-diagnostics capability is
  specified and implemented as an optional, evidence-qualified contract with
  per-take quality/exclusion evidence, robust rank and session aggregates, and
  explicitly non-identifying anomaly and similarity candidates; conforming
  0.2.0 and 0.2.1 packages remain valid;
- public-draft builds fail closed while owner decisions or semantic pins are
  unresolved.

## MODAVIS Release 1.3 dependency

Release 1.3 does not block VAO container, schema, validator, profile,
governance, PID, or tooling preparation. It blocks only the final vocabulary
crosswalk and released MODAVIS binding.

When Release 1.3 is ready, supply or identify:

1. the immutable vocabulary release IRI;
2. the artifact manifest and SHA-256;
3. SKOS Turtle and/or JSON-LD generated from the same frozen graph;
4. concept status, definition, notation, hierarchy, and mapping metadata;
5. license and provenance metadata;
6. the change report from the vocabulary state used during VAO development.

Mutable database or Navigator state must not be used as a release pin.

## Correct remaining order

1. finish MODAVIS semantic review and ontology release candidate;
2. freeze the Release 1.3 vocabulary snapshot;
3. finalize the term ledger and mapping artifact;
4. build VAO `0.2.2-rc.1` against the exact MODAVIS candidate;
5. complete domain, ontology, preservation/security, and independent
   implementation review;
6. resolve owner approvals in `Release/vao-release-metadata.json`;
7. only then perform public staging, tagging, W3ID, release, archive, and
   announcement actions.

## No-publish boundary

Until the release authority removes `noPublish`, do not make a repository or
site public, create a public tag/release, submit W3ID rules, deposit a DOI,
register the media type, or announce VAO as published.
