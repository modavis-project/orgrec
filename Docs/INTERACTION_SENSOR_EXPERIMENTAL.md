# Experimental interaction-sensor layer

The method's provenance classification, mathematical scope, and non-claims are
in the [scientific-method register](SCIENTIFIC_METHODS.md).

OrgRec can capture constrained organ-control motion from the CRC-protected
`organ_imu_node` packet-v1 stream used by `organ_imu_framework`. The feature is
explicitly experimental: it preserves enough raw evidence and paradata to
evaluate the method without presenting an MPU-6050 estimate as a ground-truth
mechanical measurement.

## Appropriate use

The initial layer supports one active node and three motion models:

- hinge motion for a representative key, pedal key, or expression pedal;
- endpoint-constrained translation for a drawstop with independent endpoint
  switches; and
- angular-rate-only observation when absolute angle is not observable.

It is not a keyboard scanner, force sensor, general 3D tracker, or source of
authoritative static drawstop state. A force sensor is still required for touch
and key-action-force characterization.

The strongest organ-recording uses are a permanently mounted representative
key or pedal action, a swell shoe or other continuous pedal, a drawknob/tablet
or accessory transition, and a dedicated mechanical-noise take. Moving one IMU
from key to key is weak evidence: the mount and geometry change, so the previous
calibration no longer applies.

## Pipe-sound recording sequence

Interaction evidence is useful only when it covers the same complete action as
the audio. For an isolated pipe take, record in this order:

1. Start the audio take and retain room tone before touching the mechanism.
2. Move the key or control through its positive/activation travel.
3. Hold it unchanged through the planned steady-state sound.
4. Release it through negative travel.
5. Keep recording until the acoustic offset and room tail are complete.

OrgRec starts an opted-in sensor writer before starting the Core Audio writer
and stops it after audio, so startup and release boundaries are not clipped.
Derived preview points are expressed on the audio timeline; negative times are
valid sensor samples obtained while the audio engine was starting. After audio
analysis, OrgRec associates positive motion with acoustic onset and negative
motion with key-up/release, and reports onset-from-motion, held interval, and
sound-after-release together with clock and boundary uncertainty. These values
describe the mounted control and recording setup—not pallet motion or wind-chest
pressure.

## Guided workflow

Open **Interaction Sensors** for the five-stage workflow:

1. Bind the node to an organ component and select the constrained-motion model.
2. Connect over `/dev/cu.*`, or use the protocol-compatible simulator.
3. Inspect the live angle/rate trace and packet, gravity, range, timing, and
   endpoint checks.
4. Acquire a fresh two-second neutral window, then exercise at least three full
   slow and fast strokes to learn the gyro bias, gravity reference, and PCA
   hinge axis. Perform the positive action first so subsequent positive and
   negative events can be interpreted consistently.
5. Validate repeated movements against an encoder, laser displacement sensor,
   high-speed video, or measured geometry before accepting the calibration for
   experimental use.

The simulator emits packet-v1 bytes at 200 Hz and is suitable for checking the
entire decoder, live feedback, calibration, event detection, and artifact path
without hardware.

Event detection uses calibration-noise-aware hysteresis. Representative keys
use a fast threshold, while swell/pedal and stop/accessory modes use lower
thresholds and longer quiet windows so slow intentional motion is not lost or
split into multiple events. The active thresholds are shown in Immediate
checks.

## MIDI piano evaluation

A connected MIDI piano is useful for automated trial association. OrgRec pairs
MIDI note-on velocity and contact time with the nearest detected IMU movement,
then fits peak angular velocity against MIDI velocity after at least five
presses spanning at least three distinct velocity values.

MIDI velocity is **not** treated as physical calibration truth. It may be
fixed, quantized, curved, scanned at a different point in the key motion, or
specific to one action. A good regression means only that MIDI velocity is a
useful comparative predictor for the exact keyboard, key, firmware, mount, and
test conditions. It does not calibrate angle, displacement, force, or absolute
speed and must not be transferred from a piano to an organ.

## Optional take capture and artifacts

A saved configuration or live connection never creates interaction data by
itself. In **Record**, the operator must enable **Include interaction data in
this take** for each standard take. If the switch is off, no sensor file is
created. If it is on but the node is unavailable or unhealthy, OrgRec warns and
continues with audio-only recording; sensor state never blocks an ordinary pipe
recording. Legacy `required` configurations are treated as optional.

For an opted-in take with the exact node streaming, OrgRec retains:

```text
Sensors/Raw/<take>-<capture>.imu
Sensors/Derived/<take>-<capture>.json
Metadata/SensorCaptures/<take>-<capture>.json
```

The metadata contains configuration and calibration snapshots, SHA-256 and
byte count, packet-loss/CRC/I2C/overrun/saturation/reset counters, motion-event
count, and a separate sensor-to-audio clock mapping. The raw packet stream is
authoritative; derived JSON and `ActuationCurve` previews are reproducible
convenience representations. The post-analysis metadata can also contain the
sensor–acoustic coupling summary.

Capture packages copy and verify all three artifacts. VAO export retains them
as sensor data, analysis, and paradata assets. Field QA audits attached evidence
for stream faults, calibration, clock alignment, validation status, and missing
sensor–acoustic coupling. Missing or checksum-mismatched raw bytes remain an
integrity error once a capture has been attached, but the absence of optional
sensor evidence is not an error.

## Synchronization

Packet-v1 has an independent microcontroller clock. OrgRec records monotonic
host receipt time, corrects packet order within each serial batch using the
configured UART rate, and fits an affine device-to-CoreAudio mapping. The fit
reports oscillator drift, residuals, and a base uncertainty that includes at
least half a sample and one packet's wire time.

USB buffering is not eliminated. A future firmware/node revision should latch
an isolated hardware synchronization pulse also recorded on an audio channel.
Until that exists, sub-millisecond interaction/audio timing claims are not
supported.

## Provisional validation gate

The UI uses a deliberately conservative gate:

- at least 10 trials with an independent physical reference;
- travel RMSE no greater than 0.5 degrees; and
- duration RMSE no greater than 10 ms when reference durations are supplied.

Take QA separately expects at least 99.9% packet retention and flags CRC/I2C
faults, resets, saturation, endpoint conflict, and missing clock alignment.
Passing is local to the exact calibration and is not sensor certification.

## Current boundaries

- One live sensor node is supported.
- Packet-v1 scaling is fixed to MPU-6050 ±500 degrees/s and ±4 g.
- Hardware-pulse synchronization and firmware-v2 identity/reset packets are
  not yet available in the reference firmware.
- Standard takes are supported; long-take slicing and imported capture binding
  are intentionally excluded from the v1 experimental contract.
- The MPU-6050 is appropriate for existing prototypes but obsolete for a new
  permanent installation. The native layer keeps configuration and protocol
  identity explicit so another driver can be added without changing the take
  evidence contract.

## Method provenance and observability

Calibration estimates one constrained hinge axis from centered accelerometer
covariance using power-iteration principal-component analysis. It removes
measured gyro bias, integrates angular rate, and uses a signed gravity-vector
angle as an independent observable. Affine device/host clock alignment and the
MIDI-velocity relation are ordinary least-squares fits. Axis sign is anchored
to the first calibration movement; the result is not a general six-degree-of-
freedom pose estimate and does not contain a Kalman or complementary filter.

Packet CRC, smoothing, event thresholds, confidence conversion, validation
grades, clock residual gates, and MIDI RMSE gates are provisional OrgRec
engineering. They have synthetic and local validation coverage but no claim of
sensor certification, biomechanical validity, or sub-millisecond audio timing.
MIDI note/event semantics follow the [MIDI 1.0 Detailed
Specification](https://midi.org/midi-1-0-detailed-specification); that standard
does not validate OrgRec's motion-to-velocity regression.
