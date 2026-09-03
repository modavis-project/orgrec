# Instrument-noise planning and capture

OrgRec treats an instrument mechanism as an independently recordable acoustic
target, not merely as contamination inside a pipe-speech take. Choose **Plan
instrument noise…** in the Roadmap to create exact action, direction, velocity,
configuration, microphone-technique, and repetition variants.

## Classification

The model uses orthogonal dimensions instead of forcing unlike concepts into
one hierarchy:

- source scope: instrument, instrument auxiliary, recording system, building
  services, venue activity, external environment, human, or unknown;
- mechanism: sounding element, mechanical, pneumatic, wind/flow, electrical,
  electromagnetic, structural/contact, human, environmental, or unknown;
- temporal behaviour: impulse, attack or release transient, intermittent,
  periodic, continuous, ramp, startup, shutdown, or unknown;
- operating phase: idle baseline, activation, deactivation, transition, steady
  operation, startup, shutdown, or suspected fault; and
- role: intended target, characteristic by-product, context, interference,
  fault, or uncertain.

Instrument-noise families cover key, pedal, stop, coupler, accessory, blower,
wind-system, tremulant, and sweller/jalousie actions. Each planned variant
freezes these classifications.

## Velocity, configuration, and variability

Slow, normal, and fast presets retain normalized values and reference MIDI
velocities 32, 80, and 127. MIDI velocity is a reproducible reference value;
for a purely mechanical control it does not claim that the organ itself emits
or measures MIDI. Sweller/jalousie sweeps also retain target movement duration.

## Intensity and action trajectories

Every actionable protocol may carry a structured **actuation profile**. This
documents what was actually meant by “slow”, “fast”, “gently”, or “fully”
instead of relying on those words alone. A profile records:

- the physical or control quantity: action progress, position/openness,
  displacement, force, movement velocity, wind pressure, air flow, electrical
  command, MIDI velocity, switch state, or a named custom quantity;
- its unit and documented minimum/maximum;
- an exact, strictly time-ordered sequence of control points;
- normalized-time or elapsed-seconds time basis, interpolation rule, and target
  duration;
- a curve family (linear, ease-in, ease-out, S-curve, stepped, impulse, or
  custom points); and
- evidence provenance, device identity, calibration reference, uncertainty,
  and notes.

The planner authors the forward activation/opening/press curve. For a
position-like quantity, OrgRec reverses its values for release, deactivation,
closing, pedal release, and shutdown while retaining its shape, interpolation,
evidence, and calibration metadata. It does not reverse force, pressure, flow,
or other quantities whose physical direction cannot be inferred safely.

Velocity variants retain separate protocol snapshots. Preset layers share the
normalized curve shape and apply their own target durations. To use genuinely
different shapes at different velocities, add one velocity variant at a time
with its own curve.

The evidence type is explicit. **Operator-planned** means an intended gesture;
**controller-commanded** means a command emitted by an identified device;
**operator-observed** means values entered by a person during a take; and
**sensor-observed** is reserved for a trace from identified measurement
hardware. Operator observations are never presented as sensor measurements.

One plan may name several configurations, such as separate swell boxes,
jalousie banks, linkages, console modes, or wind states. Opening, closing,
pedal press, and pedal release can be separate variants. The minimum accepted
take count is stored per variant. A Roadmap obligation remains incomplete until
that many takes have been accepted, allowing stochastic and velocity-dependent
mechanical character to survive for later virtualization.

## Capture workflow and paradata

The Record view replaces the pitched-note protocol with the selected mechanism
protocol. Record room tone, mark **action begin**, perform the planned action,
use **Sample** to retain intermediate observed values when useful, mark
**action end**, and retain the decay. **Mark notable variation** records an
additional structured event when a repetition differs audibly.

Each take stores:

- an immutable protocol snapshot in take provenance;
- a repetition ordinal and planned/actual velocity fields;
- action begin/end offsets and actual duration;
- a take-specific observed actuation curve in elapsed seconds, with evidence
  source and device provenance;
- structured timed event annotations carrying the source, mechanism, temporal,
  operating-phase, role, observed value, and unit classification; and
- the usual session, setup, environment, external Noise Context, fixity, and
  analysis records.

The capture package analysis record and IAD take record export the protocol and
take paradata. Annotation JSON exports the structured event markers. This
feature does not add or align VAO 0.4.0 contracts.

The Analysis view overlays commanded and observed curves and reports planned
and actual duration. Capture readiness and the project audit block invalid
profiles, including non-increasing times, out-of-range points, invalid units,
and controller/sensor evidence without a device identity.

## Best next extensions

The current workflow supports exact manual/controller planning and honest
operator-timed observations. The most valuable next improvement is direct,
sample-synchronous ingestion from MIDI, OSC, HID, or calibrated displacement,
force, pressure, and optical sensors. That would allow automatic observed
traces rather than manual points. Further useful work is multi-axis profiles
(for example pedal position plus jalousie angle), calibration records as
first-class project assets, commanded-versus-observed tracking-error metrics,
and alignment of trajectory features with the recorded acoustic transient for
virtual-instrument modeling.

## Recommended Roadmap items

The Roadmap compiler suggests optional protocols for source-backed keyboards,
stops, couplers, and accessories. Recognized blower/wind-machine, tremulant,
and sweller/jalousie names receive specialized protocols. These suggestions do
not lower ordinary pipe-speech coverage. The session wizard lists them as
optional and leaves them unselected until the operator chooses them; protocols
explicitly created as required are selected with other required obligations.
