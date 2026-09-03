# Complex instrument capture P1

Scientific provenance and the limits of the derived measurements are indexed
in the [scientific-method register](SCIENTIFIC_METHODS.md).

OrgRec P1 adds five Roadmap protocol families for cinema/theatre-organ behavior
that cannot be represented faithfully as an ordinary key velocity or a single
continuous control value. The implementation is OrgRec-native and deliberately
does not claim VAO 0.4.0 alignment.

## Planning workflow

Open **Roadmap → Plan complex capture…** and choose one of these protocol
families:

1. **Physical actuator response** keeps MIDI velocity, gate duration,
   deactivation offset and reference event, actuator route, force, pressure,
   controller value, and pedal/action path as independent input dimensions.
   Multiple variants create separate repeated-take obligations. Analysis stores
   peak and RMS level, acoustic onset latency, acoustic duration, and process
   outcome as measured response points. Project-level response functions retain
   all points and their take review states; when at least two distinct numeric
   inputs exist they also report explicit least-squares slope/intercept, input
   range, units, sample count, R², and contributing take IDs for each numeric
   output rather than presenting raw points as though they were already a fit.
2. **Declarative process** represents one-shot, sustained, periodic, irregular,
   sequential, composite, and stochastic behavior. Stages have stable IDs,
   ordering, child-stage relations, actions, min/typical/max timing,
   distributions, and repeat bounds. Repeating processes require a hard
   iteration or duration limit and an explicit cancellation path; cycles are
   rejected.
3. **Discrete shutter mapping** represents each jalousie shutter separately.
   Pedal detents resolve to complete per-shutter states, with optional distinct
   opening and closing maps for hysteresis. It never treats the enclosure as a
   single undocumented global-openness scalar.
4. **Tremulant response** compiles four paired conditions for every selected
   affected stop/rank: without tremulant, steady with tremulant, activation
   transition, and deactivation transition. Representative coverage records
   low/middle/high notes; complete coverage follows the chromatic Roadmap step.
5. **Operational baseline** schedules at least two minutes of room,
   blower/wind, electrical, ventilation, or instrument-idle sound in explicit
   subsystem states. Masters remain unprocessed virtualization layers;
   automatic denoising is prohibited.

The session planner accounts for the complete repeated duration of these
obligations, including multi-minute baselines and bounded process duration.

## Capture and acceptance

Every P1 Roadmap item produces an exact typed capture-state fingerprint. At
recording start, OrgRec freezes the complete protocol, control bindings, state,
session, setup, registration, and Navigator snapshot into take provenance.
The Record view provides protocol-specific structured markers:

- action begin/end and observed physical values;
- process-stage begin/end and cancellation;
- observed shutter state at a documented pedal position;
- tremulant activation, deactivation, or stable modulation;
- stable baseline operation and notable variations.

Acceptance is gated by the evidence appropriate to the protocol. Processes
must have complete stage markers and may not satisfy a completed obligation
after cancellation. Shutter takes must mark the planned discrete state.
Tremulant transitions need an aligned command or manual transition marker.
Operational baselines must meet their planned duration, include a stable-state
marker, and complete analysis. Physical actuator takes must yield a measured
response point.

## Analysis and preservation

The Analysis workspace presents the frozen protocol, event timeline, and the
derived evidence:

- actuator input/output values, acoustic latency, and response duration;
- tremulant amplitude/frequency modulation rate and depth, transition time,
  settling time, timing uncertainty, and warnings;
- baseline peak/RMS, L10/L50/L90, crest factor, 100 ms level variability,
  stationarity, and octave-band spectrum from 31.5 Hz to 16 kHz.

Long baseline analysis streams the original multichannel WAVE rather than
loading it all into memory. Results remain explicitly uncalibrated dBFS unless
a calibration reference exists. Original audio is never replaced by an
automatically denoised derivative.

## Stored contract

The normative internal contract is `orgrec.complex-capture/v1`. Optional fields
preserve backward decoding of earlier OrgRec projects. P1 protocol snapshots
and take paradata are included in project JSON, take provenance, analysis JSON,
and IAD take records. Structured event annotations remain on the take timeline,
and export consistency checks verify protocol identity, duration, analysis,
and exact-state bindings.

## Method provenance and measurement boundary

Actuator response is an ordinary least-squares line with slope, intercept, and
R², calculated only when repeated observations contain sufficient input
variation. Tremulant response reuses the independently calculated amplitude and
frequency/spectral modulation evidence. Model gates, confidence labels, and
physical interpretations are OrgRec engineering; neither result is a complete
system-identification transfer function or proof of causality.

Operational-baseline peak, RMS, crest, L10/L50/L90, 100 ms variability, and
octave spectra are uncalibrated digital descriptors. Here L10/L50/L90 are
sample-amplitude distribution quantiles, not environmental sound-pressure
levels or compliance with
[ISO 1996-2:2017](https://www.iso.org/standard/59766.html). The FFT octave
integration is not an IEC 61260 class filter. A standards-grade noise survey
would additionally require calibrated instrumentation, prescribed acquisition,
traceability, and an uncertainty budget.
