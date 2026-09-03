# VAO–MODAVIS term ledger

Status: private prepublication ledger for the VAO 0.2.2 candidate  
Final controlled-vocabulary rows: blocked on the immutable MODAVIS Release 1.3
vocabulary snapshot

This ledger prevents container mechanics, provisional VAO abstractions, and
draft vocabulary labels from becoming accidental MODAVIS commitments.

## Disposition classes

- **MODAVIS:** use the stable MODAVIS class/property IRI directly.
- **MODAVIS candidate:** reusable semantics proposed for a reviewed module.
- **External:** reuse an established external vocabulary.
- **VAO extension:** semantic term specific to the VAO application profile.
- **Container only:** JSON/ZIP contract; no domain ontology promotion.
- **Release 1.3 gate:** exact concept mapping waits for the frozen vocabulary.

## Ledger

| VAO surface | Disposition | Target or action | Gate |
| --- | --- | --- | --- |
| instrument, component, state, configuration | MODAVIS | `modinst:*` classes | ontology RC |
| component membership and role assignment | MODAVIS | qualified `modinst:*` resources | ontology RC |
| source, snapshot, fragment, evidence support | MODAVIS | `modevidence:*`; structured selectors | ontology RC |
| assertion, conflict, projection | MODAVIS | `modassert:*` | ontology RC |
| domain event versus processing activity | MODAVIS/external | `modevent:*` plus `modprov:*`/PROV-O | ontology RC |
| digital asset/representation | MODAVIS candidate | minimal media module; VAO asset is likely narrower | module decision |
| audio signal, take, channel, sample, impulse response | MODAVIS candidate | later audio module | post-0.1 unless promoted |
| source-bound extraction, attack, stable-sustain, loop, and release regions | MODAVIS candidate implemented provisionally | `modaudio:SignalRegion` specializations with half-open frames, source hash/rate/channel, confidence and censoring; keep region semantics independent of VAO ZIP paths | audio-module review |
| loop point set and loop/release policy | MODAVIS candidate implemented provisionally | `modaudio:LoopPointSet`, exact-frame region and interaction binding; review before namespace freeze | audio-module review |
| protocol-neutral sample playback parameters | MODAVIS candidate implemented provisionally | `modaudio:SamplePlaybackParameters`; retain root/ranges, source/target pitch, gain, envelope, channel, selection, loop/release links and review state; MIDI/OSC are derived bindings | audio-module review plus independent sampler |
| tuning calibration and exact tuning map | MODAVIS candidate implemented provisionally | separate measured calibration and inferred temperament from accepted per-key playback targets; align with measurement ontology and MIDI Tuning Standard without making MIDI normative | audio/measurement review |
| analysis observation qualification | MODAVIS candidate | split activity, observation/result; retain status, applicability, censoring, coverage, evidence count, aggregation, channel, region, value asset and exact clock; align SOSA/SSN and PROV-O | ontology review |
| evidence-qualified collection acoustic diagnostics | VAO extension/MODAVIS candidate | retain the optional capability, analysis activity, per-take eligibility/quality ledger, declared-or-inferred analytical grouping provenance, exact assessed inputs and inclusion decisions, and eight governed result properties in VAO; consider only the reusable evidence-qualification pattern for MODAVIS | audio/measurement and independent-implementation review |
| collection aggregation methods | VAO extension/MODAVIS candidate | keep `quality-weighted-median`, `siegel-repeated-median`, `median`, `within-target-median-slope`, `robust-multivariate-distance`, and `harmonic-aligned-cosine` as explicit method identifiers; retain frozen parameters and describe observed slope bounds as evidence envelopes, not population confidence intervals | statistical review plus independent implementation |
| acoustic anomaly and similarity candidates | VAO extension/MODAVIS candidate | retain review-only candidate observations in VAO; similarity is harmonic-number aligned and non-transitive, and anomaly distance is a screening result rather than a diagnosis; do not mint physical-identity, shared-pipe, construction, or fault relations from either result | domain and statistical review |
| persistent control, event type, guarded transition, routing rule, process, and actuator transfer | VAO extension/MODAVIS candidates implemented provisionally | VAO 0.3.3 separates control bindings from occurrences and composes state, routing, generator, and timing axes; evaluate reusable pieces independently rather than promoting one broad interaction class | ontology/event/audio-module review plus independent implementation |
| spatial region/pose/transform | MODAVIS candidate/external | spatial module plus Web Annotation/media selectors | ontology review |
| experience and asset group | VAO extension | capability-scoped presentation node and logical acquisition/cache grouping; do not equate with a UI route or storage API | experiential-profile review |
| performance-media transport, carriers, label images, and animation bindings | VAO extension/MODAVIS candidate | retain allowlisted declarative transition and local target graph in VAO; consider reusable performance/carrier semantics only after independent implementation | media-module review |
| instrument classification concepts | Release 1.3 gate | map exact reviewed concept IRIs, codes, schemes, and editions | Release 1.3 |
| functional roles and membership types | Release 1.3 gate | compare VAO needs with frozen MODAVIS schemes | Release 1.3 |
| asset roles | VAO extension or MODAVIS candidate | promote only roles reusable outside VAO | Release 1.3 review |
| tuning-table and feature-track asset roles | VAO extension or MODAVIS candidate | retain as indexed result/evidence roles; do not infer semantics from filename or codec | media-module review |
| asset representation status | VAO extension or MODAVIS candidate | retain mandatory capture/authored/processed/reconstructed/simulated/inferred/creative distinction; align with provenance vocabularies without conflating activity and result | ontology review |
| VAO capabilities and profiles | VAO extension | retain under `vao/`; describe conformance with DCTERMS/PROF | none |
| rights/license/access | External/profile | DCTERMS, ODRL where justified, VAO validation | review |
| byte size, media type, checksum | External/MODAVIS candidate | qualified checksum; DCAT/SPDX where applicable | media decision |
| archive path, ZIP method, `mimetype`, extraction limits | Container only | JSON Schema and container validator | none |
| `vao-manifest.json`, OrgRec `project.json` | Container/profile only | never promote private application shape to MODAVIS | none |

## Provisional VAO vocabulary review

- Do not promote broad `vao:causes` into MODAVIS core.
- Do not declare `vao:Analysis` equivalent to a MODAVIS class until activity
  and result are separated.
- Do not declare the legacy graph `vao:Interaction` equivalent to a MODAVIS
  event or control. VAO 0.3.3 now separates `InteractionControl` and
  `InteractionEventType`; equivalence still requires reviewed MODAVIS terms.
- Model units, protocols, coordinate systems, roles, and types as IRIs or
  structured resources where they denote concepts; do not freeze IRI-looking
  string literals as the semantic design.
- Do not use `qudt:Centi` for musical cents. Retain the VAO cent defined as
  exactly 1/1200 octave until a reviewed external unit mapping exists.
- Do not treat an inferred analytical rank grouping as documentary component
  membership or organological identity; retain its grouping basis and source
  identifier.
- Do not turn acoustic similarity into a relation. Every interpretation remains
  a “candidate,” is non-transitive, and requires independent source or curator
  evidence before any physical-identity or shared-pipe assertion.
- Do not turn a robust acoustic-anomaly candidate into a defect, construction,
  or maintenance diagnosis. Retain its contributing feature scores and quality
  evidence for review.
- Treat OrgRec's quality thresholds, minimum sample sizes, drift span, anomaly
  cutoffs, and similarity threshold as frozen analysis parameters, not as
  universal MODAVIS concept definitions.
- Use subclass/subproperty mappings for narrower VAO concepts. Equivalence
  requires bidirectional review and tests.

## Release 1.3 completion procedure

For every candidate concept, compare IRI, scheme, notation, definition, status,
hierarchy, language labels, provenance, and mappings. Record one of: direct
reuse, narrower mapping, broader mapping, close match, no match, or deferred.
Matching labels alone are never sufficient.
