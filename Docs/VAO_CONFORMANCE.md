# VAO 0.2 conformance

> Historical document. This is the retained private 0.2 compatibility-line
> contract. Current VAO 0.5.0 conformance is provided by `Tools/vao05.py`, the
> frozen release bundle, and the separate public standard repository.

## Conformance targets

VAO conformance is asserted separately for packages and implementations.

A **package** conforms to the core profile only when its container, manifest
schema, semantic graph, payload index, fixity, rights, MODAVIS binding, and all
claimed profiles pass. Passing JSON Schema alone is insufficient.

An implementation may claim one or more roles:

- **validator:** performs every required core check and reports errors separately
  from unsupported optional capabilities;
- **reader:** validates before use, exposes the complete graph and asset index,
  and preserves unknown optional extensions;
- **writer:** emits conforming packages and validates the finished bytes;
- **extractor:** enforces path, type, compression, size, collision, and overwrite
  safety before and during extraction;
- **profile processor:** additionally implements every required capability of a
  named profile;
- **round-trip editor:** preserves all supported and unknown optional data that
  it does not explicitly supersede.

Claims must name the exact `0.2.x` implementation version, roles, profiles,
compression methods, codecs, resource limits, and known limitations.
While VAO remains private, claims must additionally name the source revision or
generated release ZIP SHA-256 and state that the target is an unpublished
development snapshot. Passing the suite does not turn that snapshot into a
published standard or guarantee compatibility with the future public draft.

## Reference implementation matrix

| Implementation | Roles | Profile processing | Compression | Declared limitation |
| --- | --- | --- | --- | --- |
| VAOM 0.2.2 | validator, reader, migrator, stored/deflate extractor, stored writer, graph authoring workspace | core plus research, playable, spatial, acoustics, experiential/XR, preservation, and OrgRec checks; validates acoustic frames, geometry, materials, responses, metrics, scenes, renderers, calibrated timbre inference, rank fingerprints, and evidence-qualified collection diagnostics | reads stored/deflate; writes stored | external codec/HDF5 contents and perceptual/scientific quality require specialized validators |
| OrgRec VAO 0.2.2 | native validator, general reader/inspector, verified workspace and asset extractor, stored writer, OrgRec preservation-aware round-trip editor | validates the closed 0.2 shape and semantic acoustic/profile contracts, including collection evidence, robust aggregates, and candidate safeguards; exposes XR runtime capabilities as metadata | reads/writes stored ZIP/ZIP64 | OrgRec has no XR/acoustic renderer; editable project conversion remains limited to OrgRec-profile pipe-organ packages |

Both use the same identifiers and semantic rules. VAOM remains the portable
release-reference validator. OrgRec independently enforces the closed JSON
shape, archive/fixity rules, graph semantics, and all seven experiential
capabilities in Swift. Runtime support is reported separately from validation:
an experiential package can be valid and safely imported or preserved even
though OrgRec does not execute its XR behavior.

## Required core validation sequence

1. Parse the ZIP central directory without extracting.
2. Enforce local resource limits, safe normalized paths, uniqueness, permitted
   entry types, no encryption, and supported compression.
3. Require the uncompressed `mimetype` entry first and verify its exact bytes.
4. Decode `vao-manifest.json` as UTF-8 JSON and validate it against the release
   JSON Schema.
5. Build the combined identifier registry and reject duplicate or unresolved
   local references.
6. Resolve `primaryEntityId` and every `focusEntityIds` value; require the focus set to include the primary entity.
7. Require one asset record per payload file and one payload file per asset,
   with safe unique paths and valid media types/roles/subjects.
8. Stream every asset to verify its declared byte size, SHA-256, and ZIP CRC.
9. Verify rights coverage, MODAVIS binding, temporal intervals, confidence
   bounds, activity/analysis references, and claimed-profile requirements.
10. Report unsupported required capabilities without executing or automatically
    fetching any embedded or remote content.

A validator returns success only if there are no conformance errors. Warnings
may describe portability, preservation, or unsupported optional behavior but
must not conceal an error.

## Release conformance suite

The checked-in suite uses only Python's standard library:

```sh
python3 Tools/test_vao_conformance.py
```

It verifies the minimal core workspace, the positive playable,
experiential/XR, and acoustic-room workspaces, and a generated positive
collection-diagnostics claim; packs the core fixture; validates the single-file
archive, unpacks it, and tests required rejection of corrupted
fixity, unindexed payload, missing rights or representation status, unsafe
manifest and archive paths, incompatible versions, unknown standard fields,
non-IRI extension-property keys, unpinned released ontology/vocabulary bindings,
incomplete exact-frame clocks, invalid sample ranges, duplicate tuning keys,
unbound extraction regions, misidentified cent units, and incomplete research,
playable, spatial, experiential, preservation, or OrgRec profile claims.
Experiential negative mutations cover missing capability
graphs and dependencies, malformed physical/coordinate metadata, synchronized
performance bindings, AR targets and placement policies, listening-point media,
offline asset groups, and allowlisted replaceable-media action sequences.
Acoustic negative mutations cover coordinate-frame cycles, non-normalized
quaternions, measured-response provenance, SOFA declaration, response/metric
band alignment, learned-field lineage, building-acoustic pairs, material bands,
runtime fallback policy, incomplete tracked-source claims, and capabilities
placed under the wrong profile.
The generated collection claim exercises the complete governed observation and
paradata shape. Its negative mutations require the evidence-qualified analysis
when the capability is claimed and reject an inconsistent evidence summary.
The reference validators additionally enforce the parameter, ledger,
rank/session, finite-value, drift, and candidate constraints required by the
normative contract.
The suite also performs a positive 0.1-to-0.2 copy migration and verifies that
the source stays unchanged, the old manifest is retained as hashed evidence,
the migration activity is linked to it, and the resulting workspace validates.

The native interoperability test is:

```sh
swift test --filter testVAOIsPrimarySingleFileRoundTripWithGraphFixityAndOrgRecProfile
```

It performs Swift writer → Swift archive/profile check → Python validator → Swift importer
and verifies lossless project evidence. A release must also pass the full
`swift test` suite and a production `swift build -c release`.

Fixtures live under `Fixtures/VAO/`. `valid/minimal-string-instrument` is a
directory-form authoring workspace. The directory form is not itself the
exchange format; VAOM packs it into the normative single-file container during
the suite. `valid/minimal-playable-string-instrument` is the positive
playable-profile workspace and is packed into the generated release examples.
`valid/minimal-experiential-instrument` is the positive modular
experiential/XR source graph fixture. The suite validates its manifest and
payload bytes directly. It exercises the standard experiential capabilities
plus sampled playback, source segmentation, acoustical observation, and tuning
map contracts without depending on filenames, a route, a sampler, or a
particular XR engine.
`valid/minimal-acoustic-room` joins a semantic IFC-bound building/room graph,
explicit source/receiver poses, measured AES69 SOFA response, ISO 3382 metric,
spatial audio scene, and tracked-listener render configuration. The compact
fixture tests VAO container/metadata semantics; an external SOFA/HDF5 validator
is required for scientific payload conformance.

The current 0.2.2 experiential fixture retains the sampled-playback and
acoustical-analysis path introduced in 0.2.1 and proves these invariants
together: the
sample interaction resolves one audio asset and reviewed playback parameter
set; its target frequency resolves through a unique-key tuning map; an exact
extraction region resolves the fixed source audio and derived take; and the
analysis observation resolves subject, region, channel, unit, and exact source
clock. Negative mutations demonstrate that each link is independently
enforced. Codec decoding and perceptual boundary quality remain implementation
evaluations rather than manifest-conformance claims.

## Profile assertions

Core conformance does not imply research, playable, spatial, experiential,
preservation, or OrgRec conformance. A claimed profile is false if any of its required
capabilities or relations is missing. Applications may open a valid core VAO
while reporting a claimed optional profile as unsupported, but validators must
reject a package that claims a profile while violating its requirements.

For the experiential profile, conformance is evaluated only for the standard
capabilities listed as required by that profile record. `presents` resolves to
an entity; capability-specific predicates resolve to the required entity or
asset kind. Rejected and superseded relations never satisfy a requirement.
Spatial dependency claims are required for model viewing, both AR modes, and
spatial listening. Synchronized pre-rendered media and replaceable performance
media are independent of the playable profile; a synchronized performance with
`triggeredBy` interaction does require playable conformance. Offline groups
depend only on core. Replaceable-media action sequences accept only the
normative declarative action set and local typed targets. Capability support by
a consumer is reported separately from package validity.

For the research profile,
`https://w3id.org/modavis/vao/vocab/capability/collection-acoustic-diagnostics`
is optional. When declared, it and `acoustical-analysis` must occur in the
research profile record, and every governed collection analysis is checked
against [`VAO_STANDARD.md` section 6.2.1](VAO_STANDARD.md#621-collection-acoustic-diagnostics).
Unsupported processing is reported separately from validity. A validator must
still enforce the evidence counts and ledger, parameter domains, array shapes,
finite/range constraints, required units/aggregations, drift applicability, and
candidate-safety rules; it must not accept the claim merely because it does not
compute these analytics itself.

## Publishing results

A conformance report should include package SHA-256, VAO identifier and
revision, format version, validator name/version, time, limits, verified asset
count and bytes, claimed profiles, supported/unsupported capabilities, errors,
and warnings. Reports are evidence about validation at a point in time, not a
certificate of historical truth, copyright clearance, or scientific quality.
