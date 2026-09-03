# Complex-instrument capture in OrgRec

OrgRec’s complex-instrument capture contract is independent of VAO 0.4.0. It
exists first as backward-compatible `.orgrec` project, Roadmap, take-provenance,
capture-package, and IAD paradata.

## Intended sound versus instrument noise

Cinema/theatre-organ percussion and effects are intended sounding targets. The
Roadmap represents them as tonal percussion, atonal percussion, sustained,
one-shot, repeating, sequenced, composite/chained, or other sounding elements.
Each target records its temporal behavior, trigger mode, constituent component
IDs where applicable, planned duration/release behavior, and minimum accepted
take count. Ranged keyboard percussion expands into key-specific obligations.
Navigator source kinds and conservative established effect-name terms seed this
classification. **Roadmap → Plan sound/effect…** lets an operator correct an
unrecorded source target or add a locally documented component, including MIDI
range, temporal behavior, trigger, constituent IDs, duration, repetitions,
microphone techniques, and required/optional coverage state. A target with
existing takes cannot be silently redefined; the planner requires a new local
component revision.

The solenoid, tab, valve, relay, pneumatic action, or other mechanism that
triggers such a target remains a separate `instrumentNoise` obligation. This
prevents, for example, a crash cymbal from being mislabeled as mechanical noise
while still allowing the cymbal actuator to be recorded on its own.

## Exact capture state

Every Roadmap obligation carries the UUID and SHA-256 fingerprint of an
immutable typed `CaptureStateSnapshot` in a deduplicated project-level state
library.
Assignments cover stops, couplers, accessories, sounding targets, tremulants,
wind/blower state, shutters, combinations, routing, enclosures, controllers,
and documented custom state. The compiler includes explicit off-state entries,
not only activated controls. A canonical SHA-256 fingerprint covers the semantic
assignments and intentionally ignores the snapshot UUID, date, display name,
and evidence label.

The Record workspace shows the exact assignments and blocks capture until the
operator confirms that the physical instrument matches them. The confirmed
snapshot and fingerprint are frozen into the take and immutable provenance.
Consistency checks reject a take whose frozen fingerprint differs from its
Roadmap obligation; older takes without typed state remain visibly identified
as legacy evidence.

## Control Map and MIDI Learn

Open **Roadmap → Control map…**. Each binding records:

- component and human label;
- protocol and direction;
- independent activation, deactivation, and continuous messages;
- raw channel, number, and value;
- explicit channel and data-number display bases;
- input/output endpoint identity, evidence, notes, verification state, and time.

MIDI Learn arms one field at a time, so two different Program Change messages
can correctly represent activation and deactivation. Running status and the
MIDI convention Note On with velocity zero are decoded. Note velocity and
continuous-controller value changes do not prevent events from matching their
learned component address. MIDI output tests occur only after an explicit
button press and are never sent automatically; the UI warns that a test can
move physical mechanisms. Round-trip verification is an operator-confirmed
evidence state, not inferred merely from a successful API send.

MIDI 1.0 has live Learn and output testing. Other typed protocols can be named
in the map and documented, but do not falsely claim live protocol support.

## Synchronized event recording

Immediately before audio capture, OrgRec opens a take-bound control-event log
using the project’s frozen bindings. Every incoming MIDI message retains raw
bytes, decoded message, binding/component match, event role, source endpoint,
wall-clock date, CoreMIDI host ticks/nanoseconds, and whether the transport
provided its timestamp.

The first Core Audio buffer written to the WAVE file supplies frame-zero’s host
timestamp and sample time. Since CoreMIDI packet timestamps and AVAudioTime use
the same macOS host clock, OrgRec calculates signed audio time and exact nearest
audio frame per event. Events before frame zero remain preserved as negative
pre-roll mappings. Alignment records the clock basis, offset, zero constructed
drift, sample-resolution uncertainty, larger uncertainty for fallback timestamps,
and whether each mapping lies inside the recorded audio.

The event log and alignment are stored in the take, in immutable provenance,
under `Metadata/ControlEvents` in the `.orgrec` package, and as a checksummed
`control-events/<take-id>.json` sidecar in capture exports. They are also present
in analysis and IAD take/paradata records. Analysis displays the decoded event,
raw bytes, mapped frame/time, and uncertainty.

## Field workflow

1. Compile or attach the organ specification and review the intended-effect
   families in Roadmap. Use **Plan sound/effect…** for missing or corrected
   targets.
2. Open **Control map…**, select a CoreMIDI input, and learn activation,
   deactivation, and (where applicable) the continuous controller.
3. Optionally perform an explicit, safety-reviewed outbound test and document
   its verification state.
4. Open a target in Record, physically set and confirm the exact capture state.
5. Record the required separate takes. Natural variation remains separate
   evidence for later virtualization rather than being averaged away.
6. Inspect **Synchronized control events** in Analysis and resolve any Field QA
   consistency finding before export.
