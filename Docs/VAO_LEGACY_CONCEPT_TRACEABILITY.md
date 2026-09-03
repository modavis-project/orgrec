# Legacy VAO concept traceability

Status: informative traceability record updated for VAO 0.2

This record checks the new standard against the benefits and risks described in
the earlier VAO publications. Those publications document a research concept
and prototypes; they are evidence for design intent, not normative definitions
of the new file format.

## Preserved and strengthened concepts

| Legacy concept or benefit | VAO 0.2 realization |
| --- | --- |
| One shareable `.vao` archive containing multimodal data | Normative ZIP/ZIP64 container with a fixed MIME marker, manifest, complete payload index, and conventional-tool extraction |
| Audio, 3D models, animation, control data, room models, measurements, analysis, literature, and annotations belong together | Instrument-neutral entities, assets, paradata, analyses, sources, selectors, and typed relations |
| Internal causal and functional relations drive interactive behavior | Identifier-addressable relation graph with contextual component roles, configurations, states, interaction bindings, samples, animations, and acoustic responses |
| Every file remains identifiable and traceable across versions | Stable asset IDs, SHA-256, byte size, original filename, immutable released revisions, migration provenance, and predecessor/successor lineage |
| Processing must be reproducible | Activities record actors, software/build, immutable parameters, inputs, outputs, time, and notes; raw assets are not replaced by derivatives |
| Complex and unconventional instruments must be representable | Generic musical-instrument/component model, open classifications, contextual roles, non-keyboard controls, and profiles rather than an organ-shaped universal schema |
| Existing data can be imported and improved | Open media types, evidence-preserving import, explicit inferred values, migration records, and unknown-IRI round-trip requirements |
| Data should be usable without specialist software | Standard archive extraction plus JSON/JSON-LD/Turtle artifacts and the dependency-free Python VAOM CLI |
| Research, museums, education, AR/VR, auralization, and creative work should share one evidence base | Capability profiles and explicit representation status allow the same package to support different consumers without confusing captured evidence with simulation or creative transformation |
| Metadata, paradata, FAIR publication, and persistent identifiers are central | Required rights and MODAVIS binding, absolute IRIs/URNs, release/version distinction, fixity, citation metadata, and the prepared `w3id.org/modavis` architecture |
| Fragile or inaccessible objects and hidden mechanics become explorable | Model-segment selectors, component annotations, transforms, interaction/animation relations, and preservation of interior/exterior representations |
| Low-cost and geographically broad participation should remain possible | Open formats, general ZIP tools, a standard-library CLI on macOS/Linux/Windows, and no proprietary codec or authoring-suite requirement in core |

## Deliberate corrections to the legacy design

- File names may remain human-readable but are no longer an authoritative
  database. All meaning and relations survive renaming through identifiers and
  graph records.
- Category-specific identifiers no longer force every exchange participant to
  mint an MDVS identifier. Stable IRIs or UUID URNs are valid in exchange;
  MDVS allocation belongs to a separate MODAVIS publication profile.
- A broad causal vocabulary is not frozen from a single pipe-organ model.
  Physical membership, functional role, control binding, event, evidence, and
  processing provenance are distinct.
- Asset representation status is mandatory. Captured, authored, processed,
  reconstructed, simulated, inferred, and creative assets cannot silently
  masquerade as one another.
- Rights statements are required but the archive is not DRM. Authentication,
  access control, embargoes, and contributor authorization remain repository or
  workflow responsibilities.
- A valid VAO is not certified as historically true, complete, perceptually
  authentic, or a replacement for preservation of a physical object and its
  cultural practices.
- VST/AU compilation, a universal renderer, selective revision merging, and
  real-time synthesis are application functions, not promises of the exchange
  format. A future desktop VAOM may implement them without changing core VAO.

## Source basis

The review used Dominik Ukolov's *Unlocking the Sounds of Historical Keyboard
Instruments: Methodological Developments towards a Sustainable Capturing and
Preservation of Instrumental Audio Data*; Ukolov et al., *Improving the
Accessibility of Historical Musical Instruments through Interactive Virtual
Representations*; and *Reviving the Sounds of Sacral Environments:
Personalized Real-Time Auralization and Visualization of Location-Based Virtual
Acoustic Objects on Mobile Devices*.
