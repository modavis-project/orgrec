# Implementing VAO 0.2

Status: implementation guidance for the private VAO 0.2 development line  
Applies to: checksum-pinned source or generated `0.2.2` candidate snapshots  
Public-standard status: not published; not stable; reserved IRIs are not deployed

## Readiness decision

VAO 0.2 is technically complete enough for prototypes, research software,
internal tools, and controlled interoperability trials when every participant
pins the same source commit or generated release-candidate checksum. It has a
normative container contract, manifest schema, semantic rules, two
implementations, a positive fixture, negative tests, and a deterministic
release bundle.

VAO 0.2 is not yet an appropriate dependency for a production product that
promises compatibility with a published or stable external standard. There is
no public VAO release, the reserved W3ID resources are not deployed, the media
type is provisional, licensing and governance approvals are pending, and the
released MODAVIS ontology/vocabulary/mapping pins have not been supplied. A
`0.2.2` file produced from the private draft may therefore require migration
before the first public draft.

VAO 0.2.0 established the pre-public breaking minor line after the private
0.1.x snapshots. VAO 0.2.1 was a backward-compatible patch that added optional
empirical-timbre and rank-fingerprint contracts. VAO 0.2.2 adds the optional
evidence-qualified collection-acoustic-diagnostics contract without changing
the `/0.2/` schema, context, or profile identifiers. A 0.2 reader accepts 0.2.x
and rejects other minor lines. Writers implementing this snapshot emit 0.2.2,
preserve a source package's original `formatVersion` during a lossless
read/copy operation, and create a new immutable package revision when migration
or editing changes the source archive.

Use the following claim for current software:

> Implements the checksum-pinned private VAO 0.2 development snapshot
> `[source revision or release ZIP SHA-256]`; this is not an implementation of
> a published VAO standard.

Do not advertise current support as “VAO certified,” “VAO standard compliant,”
or compatible with an unspecified future VAO release.

## Which files are authoritative

For a pinned snapshot, read these together:

1. [`VAO_STANDARD.md`](VAO_STANDARD.md) — normative container and semantic
   requirements;
2. [`../Schemas/vao-manifest.schema.json`](../Schemas/vao-manifest.schema.json)
   — normative JSON Schema 2020-12 manifest shape;
3. [`../Schemas/vao-context.jsonld`](../Schemas/vao-context.jsonld) and
   [`../Schemas/vao-vocabulary.ttl`](../Schemas/vao-vocabulary.ttl) — normative
   term expansion and VAO vocabulary;
4. [`VAO_CONFORMANCE.md`](VAO_CONFORMANCE.md) — required validation behavior
   and implementation roles;
5. [`VAO_GOVERNANCE.md`](VAO_GOVERNANCE.md) — compatibility and change policy.

The semantic and archive rules in the specification cannot be replaced by JSON
Schema validation. The reference validator at [`../Tools/vaom.py`](../Tools/vaom.py)
is executable evidence of the rules, but the normative documents take
precedence if an implementation and the contract disagree.

The collection methodology and interpretation guidance is in
[`COLLECTION_ACOUSTIC_DIAGNOSTICS.md`](COLLECTION_ACOUSTIC_DIAGNOSTICS.md). Its
normative machine requirements are in `VAO_STANDARD.md` section 6.2.1.

The reserved `https://w3id.org/modavis/vao/...` identifiers currently identify
terms inside the pinned bundle; they do not assert that a network resource is
available. During private development, vendor the schema, context, vocabulary,
and any MODAVIS snapshot used by the application. Do not fetch them at import
time, silently substitute a newer copy, or treat network failure as package
invalidity.

## Minimum safe reader/importer pipeline

Treat every `.vao` as untrusted input and complete these stages in order:

1. Read the ZIP central directory without extracting. Apply configured limits
   to entry count, manifest size, per-entry expanded size, and total expanded
   size.
2. Reject encryption, links and special files, duplicate paths, backslashes,
   absolute or traversal paths, unsupported compression, and invalid UTF-8
   names. Warn or fail on case-fold collisions as required by the claimed
   profile.
3. Require `mimetype` as the first entry, stored without compression, with the
   exact bytes `application/vnd.modavis.vao+zip` and no trailing newline or BOM.
4. Read `vao-manifest.json` as UTF-8 JSON, inspect `formatVersion`, and select
   the locally vendored `0.2` contract. A `0.2` reader accepts `0.2.x`; it
   rejects another minor line rather than guessing.
5. Validate the manifest against the vendored JSON Schema and then apply every
   semantic check in `VAO_STANDARD.md` section 7 and the sequence in
   `VAO_CONFORMANCE.md`.
6. Match every regular file below `payload/` to exactly one asset record and
   every asset record to exactly one file. Stream each file to check byte size,
   ZIP CRC, and lowercase SHA-256 before decoding or previewing it.
7. Determine support from declared profiles and `requiredCapabilities`. Reject
   false profile claims as invalid. If a valid package requires a capability
   the application does not implement, report that profile as unsupported; do
   not relabel the package corrupt and do not partially execute the profile.
8. Construct the entity and relation graph only after validation. Never execute
   active content or fetch remote identifiers merely because a relation or
   asset references it.
9. Decode only media types and codecs the application explicitly supports.
   Keep unsupported assets visible in the inventory and available for lossless
   copying.
10. If extraction is needed, write to a new transactional destination beneath
    the selected directory, refuse overwrite by default, and remove the new
    destination if verification or extraction fails.

Importers should expose validation errors, unsupported capabilities, and media
decoder limitations as three different result classes.

## Importing a virtual instrument

A conforming core VAO is an evidence package, not necessarily a playable
instrument. An importer that intends to instantiate a sampler or virtual
instrument must additionally require the playable profile:

`https://w3id.org/modavis/vao/profile/playable/0.2`

For a playable import:

- build instrument/component identity from `entities` and `relations`, never
  from filenames;
- use `interaction` entities and their `activates` or `modulates` relations for
  control behavior;
- resolve audio through `usesSample` relations to indexed assets and verify the
  asset before decoding it;
- apply explicit controller domain, protocol binding, range, configuration,
  timing, envelope, loop, and release data;
- interpret loop coordinates as half-open sample-frame intervals at the
  declared sample rate and verify the loop set against the source audio hash;
- preserve the distinction between captured, processed, reconstructed,
  simulated, inferred, and creative assets;
- enforce the applicable rights and access statements outside the audio engine.

For `sampled-instrument-playback`, compile each playable voice from graph data:

1. Resolve the interaction's one `usesSample` audio asset and verify its hash.
2. Resolve `usesPlaybackParameters`, reject an unreviewed mapping, and apply its
   root/key/velocity range, source and target frequency, gain, channel policy,
   latency, envelope, round-robin group, selection priority, and note-off policy.
3. If pitch mode is `resampleToTarget`, derive the ratio from positive measured
   source F0 and exact target frequency rather than a filename or a nominal
   equal-temperament assumption.
4. Resolve `usesTuningMap` when present and prefer its exact per-key frequency
   to a protocol default; translate to MIDI Tuning Standard only at the binding
   edge.
5. Resolve an accepted loop set and optional recorded release region on the
   same source clock. Never substitute an algorithmic candidate for a reviewed
   decision without an explicit new revision.
6. Retain absent notes and alternate takes. Apply velocity, round-robin, and
   priority policy instead of discarding duplicates or inventing a complete
   compass.

For `source-segmentation`, retain the long-take master, verify the region's
`sourceAudioSHA256`, and cut the exact half-open frames. Do not use rounded
seconds for extraction. Boundary confidence and left/right censoring must
remain visible to review and downstream analysis.

Passing the playable profile's machine checks proves that the declared graph is
structurally processable. It does not guarantee that the application supports
the referenced codec, controller protocol, synthesis method, or every
instrument-specific behavior. An importer must report those limitations before
claiming that the virtual instrument was imported successfully.

## Importing room/building acoustics and XR scenes

An acoustic renderer consumes three layers independently: preserved evidence,
the semantic acoustic scene, and one or more runtime representations. It MUST
NOT treat a visual mesh as an authoritative building model, a PBR material as
an acoustic material, or a learned response as a measurement.

For spatial/acoustics import:

1. Resolve the coordinate-frame DAG and reject cycles, missing transforms,
   singular matrices, pose/frame dimension mismatch, and non-normalized XYZW
   quaternions before placing any object.
2. Bind geometry by fixed asset plus format selector. Treat IFC/CityGML as
   semantic geometry and glTF/USD as runtime derivatives according to each
   binding role. Never use a glTF `name` as a unique identifier.
3. Resolve every response measurement to source, receiver, source/receiver
   pose, room/state/configuration, indexed asset, and generating method. Send
   multidimensional SOFA content to an AES69-aware decoder; VAO validation does
   not replace HDF5/SOFA convention validation.
4. Keep room metrics and building-transmission metrics separate. Check exact
   standard/edition, frequency axis, aligned values/uncertainties, and for
   building acoustics the source room, receiving room, separating element, and
   known paths.
5. Negotiate the audio-scene representation and renderer strategy. Validate
   ADM/BW64, MPEG-I, MPEG-H, HOA, object, channel, binaural, or hybrid content
   with its external codec/standard before playback.
6. Convert source and listener tracking into the declared frame. Bind fixed,
   3DoF, 6DoF, or trajectory listeners explicitly; HRTF personalization and
   headphone compensation remain replaceable indexed resources.
7. Implement only declared distance, directivity, occlusion, diffraction,
   reflection, reverb, Doppler, portal, room-adaptation, and tracking modes.
   Do not silently invent missing physics.
8. Apply `validDomainId` and `outsideDomainPolicy` on every update. If the
   requested strategy, codec, model, or level of detail is unavailable, report
   it and use only an explicitly declared fallback.

A neural/differentiable field is eligible for runtime use only after its model,
training and validation inputs, held-out quality metric, domain,
determinism/seed, representation status, and non-learned fallback resolve.
Inference output remains linked to the model activity. Privacy-sensitive HRTF,
tracking, voice, occupancy, and room-capture data are subject to the package's
rights/access records and SHOULD be processed locally when possible.

## Consuming collection acoustic diagnostics

`collection-acoustic-diagnostics` is an optional research capability. A reader
that does not implement it preserves its ordinary analysis/paradata JSON and
reports the research profile as unsupported; it does not reject an otherwise
valid 0.2.2 package. A validator still enforces the contract even when it cannot
recompute the method.

Before presenting or using a governed collection analysis:

1. Require the capability and `acoustical-analysis` in the same research
   profile and resolve the evidence-qualified analysis and its inferred
   metric-calculation activity.
2. Verify the complete parameter set, value domains, method version, lowercase
   parameter SHA-256, exact activity/analysis inputs and outputs, and the eight
   unique observation properties, units, and aggregation IRIs.
3. Reconcile the evidence summary with the take ledger and analysis inputs.
   Keep excluded takes and their reasons visible; never infer coverage from the
   number of plotted aggregate points.
4. Resolve every take, analytical rank group, and session. Treat an inferred
   grouping basis as a comparison scope, not a documentary component-identity
   assertion.
5. Check ascending unique rank keys and finite values before plotting. Keep
   median/MAD, uncertainty/weighting detail, evidence count, and applicability
   visible with each curve or stretch estimate.
6. Present session offset separately from drift. Accept a numeric drift only
   when it is applicable and its repeated-target, pair-comparison, and time-span
   gates are met; interpret null/indeterminate as insufficient evidence, not
   zero drift.
7. Present anomaly and similarity outputs as review queues. Enforce thresholds,
   canonical unique take pairs, harmonic evidence, and the candidate cap. Never
   turn an anomaly into a fault diagnosis or similarity into common identity.
8. Preserve empty candidate arrays as explicit negative results and preserve
   unknown additional method detail on round trip. Recalculation creates a new
   activity and analysis rather than overwriting the prior evidence-qualified
   result.

These records intentionally use the existing open observation `value` and
URI-keyed paradata parameter locations. Implementations must continue selecting
`https://w3id.org/modavis/vao/0.2/schema/manifest.json` and
`https://w3id.org/modavis/vao/0.2/context.jsonld` for every 0.2.x patch rather
than inventing patch-specific schema or context IRIs.

## Extensions and lossless round trips

VAO 0.2 does not permit arbitrary undeclared members beside standard fields.
Extension data belongs only in these schema-defined locations:

- the root `extensions` object, whose keys are absolute IRIs;
- `properties` objects on entities, relations, and assets, using absolute IRI
  keys;
- paradata `parameters`, which hold immutable method-specific parameter names
  and values rather than new VAO manifest fields.

A reader may ignore an optional extension for presentation, but a round-trip
editor must retain its parsed JSON value exactly in meaning and must not move,
rename, or reinterpret it. JSON member order and insignificant whitespace need
not be retained. Required behavior belongs in a declared profile capability,
not in an extension that a consumer could silently ignore.

Applications that cannot preserve unknown extensions may claim `reader`, but
not `round-trip editor`, conformance.

Experiential/XR readers must compile behavior from the claimed capability and
its URI-keyed entity/relation graph. They must not discover models, image
targets, listening points, offline packs, carriers, animations, or performances
by matching archive filenames. Declarative replaceable-media action sequences
are allowlisted data: readers resolve their local typed targets and implement
supported transitions themselves; they never evaluate a string, script,
expression, command, callback, or external fetch instruction from a package.
Spatial dependencies and optional playable dependencies are validated before a
capability is exposed. Unsupported capabilities remain visible as metadata and
do not prevent access to the otherwise valid core graph.

OrgRec's native `VAOPackageReader` implements that non-executing reader role:
it validates the complete experiential graph, returns typed capability reports
and experience descriptors, and can copy or extract verified payload bytes.
Its processing status for the seven standard experiential capabilities is
`metadataOnly`, not native runtime support. `VAOPackageWriter` can write any
validated caller-supplied 0.2.2 graph, including experiential profiles, while
the OrgRec project exporter additionally preserves an imported package's
unknown graph and external payload across an editable OrgRec revision.

The corresponding command-line operations are:

```sh
swift run OrgRecDatasetTool vao-validate source.vao report.json
swift run OrgRecDatasetTool vao-inspect source.vao inspection.json
swift run OrgRecDatasetTool vao-workspace-import source.vao workspace
swift run OrgRecDatasetTool vao-extract-asset source.vao asset-id output.bin
swift run OrgRecDatasetTool vao-copy source.vao copy.vao
```

## Writer requirements

A writer must create the complete manifest and asset index, compute fixity from
the final payload bytes, write the required ZIP entries in the normative order,
and validate the finished archive with an independent read pass. It must not
write a profile claim merely because it emits some related fields.

Released `.vao` objects are immutable. An edit produces a new VAO revision and
records provenance; it never overwrites the only copy of the source package.

## Development and conformance workflow

From the repository root:

```sh
python3 Tools/check_vao_release.py
python3 Tools/test_vao_conformance.py
python3 Tools/vaom.py validate Fixtures/VAO/valid/minimal-string-instrument
```

Build a checksum-indexed private candidate, including a packed example:

```sh
python3 Tools/build_vao_release.py --output-directory /new/empty/directory
```

Pin the SHA-256 in the adjacent `.sha256` file and keep the bundle with the
implementation's test dependencies. The generated
`Examples/minimal-string-instrument.vao` and
`Examples/minimal-playable-string-instrument.vao` files are the exchange-form
positive examples; the checked-in fixture directories are their authoring
forms.

Before claiming an implementation role, run the applicable tests in
[`VAO_CONFORMANCE.md`](VAO_CONFORMANCE.md) and publish a support statement that
names:

- pinned snapshot or release checksum;
- reader, writer, validator, extractor, profile processor, and/or round-trip
  editor roles;
- supported profiles, capabilities, compression methods, media types, and
  codecs;
- resource limits and platform constraints;
- unknown-extension preservation behavior;
- known semantic or playback limitations.

## What must happen before public production use

The authoritative list is [`VAO_RELEASE_CHECKLIST.md`](VAO_RELEASE_CHECKLIST.md).
At minimum, the release authority must approve licensing and maintainership,
freeze and publish the MODAVIS/vocabulary/mapping dependencies, complete the
named independent reviews, deploy and test the reserved namespaces, publish an
immutable numbered bundle, and provide a public security and change-reporting
route. Production adopters should then pin that published bundle and evaluate
its release notes and migration statement rather than assuming that this
private snapshot became the release unchanged.
