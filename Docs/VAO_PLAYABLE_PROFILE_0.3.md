# VAO Playable profile 0.3

Status: normative profile of the VAO 0.3.3 editor's draft  
Profile IRI: `https://w3id.org/modavis/vao/profile/playable/0.3`

## Purpose

The Playable profile describes protocol-independent interaction for sampled, synthesized, modelled, or externally rendered instruments. Its optional sampled-instrument contract explains how exact audio realizations become playable without confusing byte identity, sampler behavior, acoustic perspective, or evidential status. Pipe-organ ranks, piano velocity layers, percussion round robins, and environmental sound controls use the same sample registries.

## Required contract

A conforming claim MUST:

- include the profile IRI in `conformsTo` and in exactly one of `profiles` or `materializableProfiles`;
- include the `interaction` capability (or the legacy-compatible `playable-interaction` capability), at least one `interaction` entity with `interactionType`, `controlProtocol`, `controlDomain`, and `timingPolicy`, and an active `activates` or `modulates` relation;
- resolve all local identifiers and satisfy the semantic checks in `Docs/VAO_CONFORMANCE_0.3.md`.

To claim `sampled-instrument-playback`, a manifest additionally MUST include the closed top-level `playable` object and at least one usable `sampleMapping`. Sample sub-capabilities require `sampled-instrument-playback`; they do not redefine the baseline profile. The `playable` object always contains all six arrays, including empty arrays for unused features. It never contains file paths that override carrier mappings. `sourceLocator` is evidence that locates a field in a native sampler definition; it is not a distribution or filesystem instruction.

`sampleMapping.keyRange` identifies the input/control range. `controlKeyMeaning`, `soundingKeyOffset`, and `sampleRootKey` distinguish the controller, acoustic result, and transposition anchor. A mapping has either a `velocityRange` or an explicit `velocitySensitivity`. `none` omits `velocityRange`; `range` requires it; `transfer-function` resolves an applicable record in `interactionModel.transferFunctions`.

## Structured complex-instrument contract

The optional `interactionModel` is required when any of the following capabilities is claimed:

- `stateful-interaction`;
- `conditional-routing`;
- `composite-actuation`;
- `timed-process`;
- `actuator-transfer`;
- `capture-event-alignment`.

The model contains ten arrays, including empty arrays for unused features: `controls`, `eventTypes`, `protocolBindings`, `stateVariables`, `transitions`, `routingRules`, `processModels`, `timingConstraints`, `transferFunctions`, and `renderBindings`. It is closed and declarative. Identifiers are package-global.

Controls describe affordances and persistent bindings. Event types describe occurrences. A MIDI binding retains its literal channel and data numbering bases, so a source library using zero-based channels and a manual using one-based program numbers remain unambiguous. State transitions use guarded, allowlisted operations and declare whether their actions are atomic. A consumer MUST reject an unresolved or incompatible action target.

Routing rules bind divisions, stops, ranks, and actuators without duplicating physical identities or samples. Each rule distinguishes input and output key meanings and supplies an identity, transposition, fixed-output, or explicit table transform. Copy and transposition graphs are acyclic. A stop condition is represented by a state guard; a coupler is a routing rule, not a second sample mapping.

Process kinds are `one-shot`, `sustained`, `repeating`, `sequenced`, `compound`, and `stochastic`. Repeating or stochastic behavior requires an iteration/duration bound or an explicit release/cancellation control. Compound actuation requires at least two operations or child processes. `executionGroup` expresses simultaneous actions without embedding code or a host-specific script.

Timing records state minimum, typical, and maximum values in one unit, plus optional measurement uncertainty and evidence. Transfer-function points have unique ascending inputs. A stepwise shutter, gate-duration-sensitive striker, or pedal-versus-switch selection therefore remains a measured control contract rather than a fabricated MIDI velocity layer.

Render bindings connect event/process and state semantics to exact `sampleMapping` or `sampleVariant` records. They do not change realization identity and do not authorize code execution.

## Capture and derivation documentation

The optional `captureDocumentation` object contains four arrays: `captureStates`, `eventAlignments`, `takeSets`, and `derivationMaps`.

- A capture state fixes the relevant instrument state assignments.
- An event alignment binds exact audio and event-log realizations to frame locations, offset, drift, and uncertainty.
- A take set says whether files are source takes, segmentation hypotheses, playback alternatives, accepted round robins, or preservation variants.
- A derivation map records exact source/result realizations, half-open source frames, channel selection, and ordered processing operations.

Derivation graphs are acyclic. A filename suffix, take number, backtracking directory, or repeated effect index is evidence only; it MUST NOT establish round-robin, accepted segmentation, loop, or release semantics. `capture-event-alignment` requires a usable alignment, not merely adjacent MIDI and audio files.

## Frame and loop convention

All VAO signal regions use zero-based, half-open frame ranges: the first frame is included and `endFrameExclusive` is excluded. The interval length is `endFrameExclusive - startFrameInclusive`. RIFF/WAVE `smpl` uses an inclusive loop end, therefore:

- RIFF to VAO: `endFrameExclusive = smpl.end + 1`;
- VAO to RIFF: `smpl.end = endFrameExclusive - 1`.

The conversion MUST use overflow-safe integer arithmetic. Importers MUST retain all valid loop records. A host MAY choose among alternatives according to `selectionPolicy`, but MUST NOT discard them from the exchanged metadata. Invalid embedded ranges are retained only as rejected evidence and MUST NOT drive playback.

## Evidence states

`source` says where a value came from; `status` says how it has been assessed. They are independent:

| Example | `source` | initial `status` |
| --- | --- | --- |
| GrandOrgue/SF2 mapping | `native-definition` | `asserted` |
| WAVE `smpl` loop | `embedded-metadata` | `asserted` |
| Measured source pitch | `measured` | `asserted` |
| Detected loop or filename perspective | `algorithmic` | `inferred` |
| Human-confirmed inference | original source retained | `reviewed` or `accepted` |

Inferred or algorithmic records require `generatedById`. Rejected and superseded records remain auditable but cannot drive a mapping. An inferred loop or variant becomes usable only after review or acceptance. Importing asserted source metadata does not imply that the producer independently verified its acoustic correctness.

## Capability truth conditions

- `sampled-instrument-playback`: the closed sample registries contain at least one usable sample mapping and its exact variants.
- `sample-looping`: at least one mapped sample variant resolves a usable loop-point set.
- `tuning-map`: at least one usable sample mapping resolves a usable tuning map.
- `multi-perspective-sampling`: mapped variants resolve at least two perspective groups; position-registered groups additionally require the Spatial profile and resolve its poses.
- `recorded-release`: at least one mapping uses `recorded-release` and includes a note-off release variant.
- `source-sampler-semantics`: mappings were decoded from a native definition and variants are backed by native or embedded metadata. An opaque proprietary inventory is insufficient.
- `stateful-interaction`: usable state variables and guarded transitions exist.
- `conditional-routing`: at least one usable routing rule has a resolvable state condition.
- `composite-actuation`: at least one usable compound process has multiple actions or child processes.
- `timed-process`: at least one process resolves measured timing constraints.
- `actuator-transfer`: at least one usable transfer function is present and referenced where required.
- `capture-event-alignment`: at least one usable audio/event-log alignment is present.

Capability claims describe the supplied records, not format names. The presence of a Hauptwerk, Kontakt, SF2, GrandOrgue, or jOrgan file alone proves no mapping capability.

## Pipe-organ guidance

A physical organ, an organ model, a sample-set product, an installed package, and a folder are different identities. Stops may bind multiple ranks, and ranks may be shared by stops. Implementations SHOULD create separate instrument, division/stop, and rank entities where source evidence supports them. Mutation/compound stops retain every rank binding. Recorded tremulant, attack/release alternatives, round robins, and microphone perspectives remain variants; they are not flattened into one canonical sample.

A multiplex organ SHOULD encode each stop/coupler as state plus routing into shared ranks. The mapping input key, sounding key, and sample root key MUST remain distinct. Tremulant and motor state belong in capture states and render conditions. Combination pistons and crescendo controls are snapshots or guarded atomic transitions. Expression shutters are stepped controls when the mechanism is stepped, even if the host exposes a continuous UI.

Filename language and historical stop nomenclature are documentary labels. A four-family timbre classifier MUST NOT be used to assert organological construction, mixture composition, mutation pitch, celeste detuning, or physical rank identity.
