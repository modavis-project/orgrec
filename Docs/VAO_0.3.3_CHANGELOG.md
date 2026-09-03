# VAO 0.3.3 decision and changelog

Status: implemented private editor's draft  
Date: 2026-08-25

## Decision

VAO 0.3.3 adds an optional, compositional complex-instrument behavior contract. The change is motivated by the MIMUL Kinoorgel case but is intentionally instrument-neutral: organs, orchestrions, carillons, robotic instruments, synthesizers, and other stateful acoustic systems use the same control, event, routing, process, timing, transfer, and capture primitives.

Baseline Core, Dynamic Delivery, Spatial, Acoustics, and Playable semantics remain structurally unchanged. Exact editor-draft dispatch advances to `formatVersion: "0.3.3"`; a 0.3.2 manifest must be regenerated, but it does not need the new objects unless it claims their capabilities.

## Normative changes

- Added the closed optional `interactionModel` with ten registries: controls, event types, protocol bindings, state variables, transitions, routing rules, process models, timing constraints, transfer functions, and render bindings.
- Split persistent controls from event occurrences and factorized control, routing, generator, and temporal behavior rather than adding one flat instrument-specific taxonomy.
- Added explicit MIDI channel/data numbering bases.
- Added shared-rank/key-transform semantics that distinguish controller key, played key, sounding key, actuator key, and sample root key.
- Added allowlisted declarative state/process actions, atomic transitions, conflict policies, acyclic routing/process graphs, and bounded repeating/stochastic behavior.
- Added ordered, evidence-qualified timing constraints and actuator transfer functions.
- Made sample velocity ranges optional when `velocitySensitivity` explicitly states `none`, `transfer-function`, or host-defined behavior.
- Added the closed optional `captureDocumentation` object for capture states, audio/event alignment, take-set semantics, and exact derivation maps.
- Added capability truth checks for `stateful-interaction`, `conditional-routing`, `composite-actuation`, `timed-process`, `actuator-transfer`, and `capture-event-alignment`.
- Defined Unicode NFC as the carrier-path comparison form and reject normalization-equivalent collisions in the Python and Swift implementations.
- Added the carrier-independent Kinoorgel conformance fixture and corresponding positive/negative Python and Swift tests.

## Safety and evidence boundaries

The interaction model contains no scripts or executable expressions. Actions and targets are closed enumerations, repetition is bounded or cancellable, and graph cycles are rejected. Timing and transfer records preserve source, status, activities, review, and uncertainty. Filename patterns and directory labels do not establish round-robin, accepted segmentation, loop, release, actuator, or sounding-pitch semantics.

## Compatibility

The profile IRIs and 0.3 schema/context IRIs remain stable. Ordinary 0.3.2 semantic content maps directly to 0.3.3. New objects are optional, and new behavior is enforced only when its capability is claimed. The historical 0.3.0 Sandbox record and built 0.3.2 release artifacts remain immutable evidence and are not relabelled.

## Validation evidence

The reference Python suite validates the Kinoorgel fixture and rejects missing interaction models, ambiguous MIDI numbering, unbounded repeaters, malformed compound actions, timing inversions, routing/derivation cycles, out-of-range event alignment, and Unicode-equivalent carrier paths. The native Swift suite decodes the new records as typed models and exercises the same principal semantic boundaries.
