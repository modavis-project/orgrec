# Project initialization, A4, and live intended-note checking

Scientific provenance and the distinction between a pitch coordinate and a
temperament claim are indexed in the
[scientific-method register](SCIENTIFIC_METHODS.md).

## Why initialization is explicit

An organ's documented pitch and its pitch during a recording session are two
different observations. MODAVIS may state a historical, contractual, or
source-reconciled pitch. Temperature, wind, instrument state, and tuning work
can change the field value. OrgRec therefore imports the MODAVIS value as a
documentary prior and requires a session-scoped field measurement before normal
recording.

Open **Initialize** in the active-project sidebar. The screen is the navigable
preflight checklist for organ identity, compiled roadmap, recording session,
environment, audio setup, documentary A4, and field A4.

## MODAVIS 1.2 ingestion

OrgRec accepts the release identifier supplied by Navigator's
`X-MODAVIS-Release` response header. For the 1.2 technical-evidence response it
reads:

```text
technicalEvidence.pitch.preferredValue
technicalEvidence.pitch.status
technicalEvidence.pitch.assertions[].sourcePath
technicalEvidence.pitch.assertions[].sourceRecordId
```

Legacy `referencePitchHz`, `pitch`, `pitch_standard`, and `tuning_pitch` fields
remain supported. A candidate is accepted only if a numeric frequency between
350 and 550 Hz can be parsed. Stop-foot fields such as `8′` cannot be mistaken
for A4. The frequency, original display value, evidence status, source path,
source record, and MODAVIS release are stored in `documentedPitchStandard`.

The app shows **Inserted automatically from MODAVIS 1.2** when this succeeded.
This does not unlock recording by itself.

## Field calibration procedure

1. Enter the operator and current temperature/humidity for the active session.
2. Select and apply the input interface and verify the reference channel.
3. Select an isolated unison 8′ stop containing A4. Prefer Principal, Gedackt,
   or another stable rank. Disable tremulant, celeste, and couplers.
4. Choose **Record field A4**, hold A4 steadily for at least three seconds, then
   choose **Stop and estimate A4**.
5. Review frequency, estimator confidence, and cents from the MODAVIS prior.
   Accept only a credible stable measurement; otherwise reject and repeat.

Acceptance attaches the calibration to the active recording session and
recalculates expected sounding frequencies for all future roadmap captures.
Foot length is included, so 4′ and 2′ ranks receive the corresponding octave
transposition. A new session deliberately begins without a calibration.

The calibration record preserves its WAV path, checksum, size, environment,
reference component locator/channel, documented prior, measured and normalized
A4, confidence, method/version, reviewer, and decision. Existing takes are not
rewritten: each take freezes the calibration and expected frequency that were
active when it began.

## Live warning semantics

During a normal take the reference channel is analyzed outside the audio-writer
path. Several estimates must stabilize before a decision is shown:

| State | Meaning |
| --- | --- |
| Waiting / acquiring | Silence or too little stable evidence |
| Ambiguous | Confidence is below the decision threshold |
| Intended note matches | Stable pitch is within 35 cents of the target |
| Tuning warning | Target is plausible but differs by 35–60 cents |
| Probable wrong note | More than 60 cents from target, or another planned key is substantially closer |

The warning is visual; OrgRec does not play an alert into the recording space
and does not discard or stop a scientifically useful take. The live decisions
are stored with the take and a probable-wrong-note result forces human review.
A4 establishes a global pitch reference, not the organ's temperament, so
per-note cent values must not be interpreted as a temperament determination.

The pitch coordinate uses MIDI key 69 as A4 and the conventional twelve-tone
equal-tempered relation `f(m) = A4 × 2^((m−69)/12)`; MIDI semantics are defined
by the [MIDI 1.0 Detailed
Specification](https://midi.org/midi-1-0-detailed-specification). Footage
scaling, the 35/60-cent live gates, confidence policy, and documentary-versus-
measured acceptance workflow are OrgRec choices. Equal temperament is the
comparison coordinate, not an assertion about the organ's historical or
present temperament.

## IAD preservation

`project.json` carries the documentary pitch, all calibration decisions, and
per-take live pitch/provenance. `manifests/calibrations.jsonl` is the normalized
discovery index. Calibration WAVs use `audio/calibration-<uuid>.wav`, are
inventoried and checksummed by `iad-manifest.json`, and are restored to
`Audio/Calibration` on IAD import. Accepted calibration audio is required for a
checked export.
