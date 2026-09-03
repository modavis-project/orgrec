# Signal-path rehearsal

The quantitative provenance and standards non-claims are indexed in the
[scientific-method register](SCIENTIFIC_METHODS.md).

The signal-path rehearsal is OrgRec's evidence-backed line check before an irreplaceable field take. It is deliberately separate from tuning calibration, musical capture, and the live level meter: a green meter at one instant does not prove that every documented microphone is independently routed, quiet enough, unclipped, and bound to the current setup.

## Guided protocol

For each microphone-setup revision, Core Audio device, channel count, and sample rate used in a recording session, open **Field QA** and run the 12-second rehearsal:

1. **0–3 seconds — room quiet.** Keep the organ silent. OrgRec measures the combined venue, blower/HVAC, microphone, preamplifier, and converter floor.
2. **3–5 seconds — protected transition.** Move or prepare at the console without sounding. This gap is excluded from the quiet and signal windows.
3. **5–12 seconds — planned maximum.** Hold the loudest registration or coupled chord expected during the session. This tests peak headroom using a realistic organ source rather than speech or an unrelated test tone.

The control stops automatically. Stopping before eight seconds is a blocking failure because the signal window is no longer representative.

## Frozen evidence

Every report retains:

- the recording-session ID, microphone-setup ID and revision;
- the Core Audio device UID, configured sample rate, channel count, buffer and latency state;
- the exact versioned protocol and thresholds used for the decision;
- per-assigned-channel quiet RMS, signal RMS, SNR, peak, headroom, DC offset, and clipped-sample count;
- capture-writer continuity diagnostics, BWF metadata-finalization state, and any real-time faults;
- the original 24-bit multichannel BWF under `Audio/Calibration/`, its byte size, and SHA-256;
- typed findings, remediation, and the frozen `passed`, `attention`, or `failed` verdict.

Changing the selected interface, sample rate, input-channel count, setup ID, or setup revision invalidates the readiness match without rewriting old evidence. A separate rehearsal is therefore required for every signal-path configuration used in one session.

## Version 1 gates

| Measurement | Blocking | Caution | Preferred |
| --- | ---: | ---: | ---: |
| Duration | `< 8 s` | — | `12 s` |
| Assigned-channel signal RMS | `< −60 dBFS` | — | audible planned maximum |
| Signal-to-room-noise ratio | `< 15 dB` | `< 24 dB` | `≥ 24 dB` |
| Peak headroom, without clipping | `< 3 dB` | `< 10 dB` | `≥ 10 dB` |
| Room-tone RMS | — | `> −42 dBFS` | assess in context |
| Absolute normalized DC offset | `> 0.03` | `> 0.01` | `≤ 0.01` |
| Clipped samples | any | — | none |
| Writer drops/discontinuities/faults | any | — | none |
| BWF finalization failure | yes | — | finalized |

Unused interface inputs remain visible but cannot fail a setup. Only channels assigned to documented microphone placements are readiness gates.

## Independent-routing check

Correlation alone is not a valid duplicate-channel detector in an organ room: low-frequency pipes, coherent direct sound, and symmetric arrays can be strongly correlated. OrgRec therefore reports duplicated or inverted routing only when both conditions hold in the sounding window:

- absolute Pearson correlation is at least `0.999999`; and
- after fitting gain and polarity, the remaining signal is at least 60 dB below the channel energy.

This intentionally targets digital clones, split feeds, and exact polarity inversions while avoiding claims based merely on legitimate acoustical coherence.

## Readiness and exchange

A missing or failed matching rehearsal is a recording blocker. A report with cautions permits recording but remains visible in Field QA. Successful and failed attempts are both retained; a later passing attempt does not erase prior evidence.

Project loading validates report IDs and contained paths. The consistency audit verifies report/session/setup bindings, verdict consistency, regular-file containment, size, and SHA-256. VAO export retains the source BWF as an indexed audio master and projects the structured protocol, channel measurements, and findings into session properties. The secondary IAD export copies the BWF, indexes it as preflight evidence, and binds the complete report to its session record.

The rehearsal does **not** measure calibrated sound-pressure level and does not replace a microphone calibrator, polarity pulse test, electrical loopback test, or listening judgment. Its result describes the actual field chain and protocol at the recorded time.

## Method provenance

Peak, RMS, DC, clipping, SNR/headroom estimates, Pearson correlation, fitted
gain/polarity, and residual energy are conventional digital-signal measures.
The 12-second schedule and every pass/caution/fail value in the table are
OrgRec field-risk controls, not limits taken from an acoustical calibration or
safety standard. In particular, correlation ≥ `0.999999` plus fitted residual
≤ `−60 dB` is an intentionally strict OrgRec rule for *suspected* digital
duplication. It is not an identity proof and it does not classify acoustically
coherent microphone signals as duplicates.
