# Continuous-stop recording and long-take import

The complete publication-to-code mapping, OrgRec-specific adaptations, and
non-claims are indexed in the
[scientific-method register](SCIENTIFIC_METHODS.md).

OrgRec can record or import one long audio file containing many isolated organ
notes and turn it into ordinary note-level takes. This matches the usual field
practice of recording a complete stop, or a useful part of one, in a single
pass. Imported and newly recorded audio use the same detector, classifier,
review screen, exact-frame exporter, and provenance model.

This workflow is designed for monophonic, one-pipe-at-a-time material. It can
also process a subset of a stop, retries, missing pipes, and non-sequential
notes. It is not a polyphonic transcription system and does not infer organ
structure that is absent from the project roadmap.

## Quick workflow

### Record a continuous stop

1. Select the first expected roadmap note and open **Record**.
2. Under **Continuous stop recording**, choose an assignment mode. For a normal
   chromatic pass, use **Ascending from selected note**.
3. Choose **Record long take**.
4. Play one pipe at a time. Release the key fully and leave at least 0.4 seconds
   before the next note. The previous pipe's room decay may occupy this gap.
5. Stop capture. OrgRec closes and checksums the master before analyzing it.
6. Review every proposed region, note assignment, warning, onset, and ending.
7. Choose **Create note takes**. Generated takes begin in `needsReview` state.

### Import an existing session recording

1. Select the first expected roadmap note and open **Record**.
2. Choose **Import long WAV** and select a PCM WAV or AIFF recording.
3. Confirm the assignment mode and reference input channel.
4. Review the proposed regions and choose **Create note takes**.

Import never edits the selected file. OrgRec copies it into
`Audio/LongTakes/`, records its SHA-256 checksum, and creates derived files in
`Audio/Originals/`.

## Assignment modes

| Mode | Best use | Behaviour |
| --- | --- | --- |
| **Ascending from selected note** | A chromatic or roadmap-ordered stop pass | Jointly aligns detected regions with roadmap positions. It can retain a retry, skip a missing pipe, or discard an unrelated sound without shifting every later note. |
| **Automatic by pitch** | Sparse or deliberately unordered isolated notes | Assigns a region to the closest available expected frequency using stable-pitch evidence. |

Ascending assignment is usually more robust for mixtures, upperwork, pipes
with weak fundamentals, and historical temperaments. Pitch is still evidence,
but the recorded order constrains ambiguous decisions.

## What the preview means

Each row represents one proposed acoustic event. It reports:

- exact source-frame and time bounds;
- assigned roadmap note, or **Unassigned**;
- stable pitch and deviation where applicable;
- assignment and boundary confidence;
- measured harmonic-tail duration and ending method; and
- warnings for ambiguous pitch, missing or repeated notes, discarded regions,
  fallback boundaries, and censored endings.

The preview is a proposal, not an acceptance decision. Listen to the first
attack and final decay of questionable regions before creating or accepting
takes.

## Boundary vocabulary

OrgRec keeps acoustically different instants separate:

| Boundary | Meaning |
| --- | --- |
| **Detected onset** | Best estimate of the first acoustically connected pipe speech or initial transient. This is the scientific marker retained in provenance. |
| **Export start** | Exact source frame written to the split file. It is normally 10 ms before the detected onset so that localization uncertainty cannot remove chiff or another initial transient. |
| **Sound offset** | End of clearly sustained pipe speech. |
| **Tail end** | Conservative export-ready ending after frequency-local decay becomes quiet. It is not an RT60 measurement. |
| **Export end** | Exact exclusive source frame of the split file, including the final release guard where available. |

This distinction is intentional: a sample can include a small safety lead while
the analytical onset remains exactly localized.

## Detection and classification method (version 3)

### 1. Streaming candidate discovery

The source is read in bounded chunks, so multi-gigabyte 192 kHz masters do not
need to be loaded into memory. A 20 ms analysis hop measures reference-channel
energy. The activity gate is estimated from both the recording's lower energy
distribution and its robust peak, rather than assuming a universal dBFS value.

The detector uses hysteresis, requires about 60 ms of persistent onset
activity, retains at least 0.8 seconds of sustained sound, and requires about
0.38 seconds of intervening quiet. These constraints reject most handling
clicks while preserving slowly speaking pipes. The implementation defaults
limit an analyzed release to four seconds and estimate stable pitch from up to
2.5 seconds of the sustained region.

### 2. Stable-pitch evidence

OrgRec applies probabilistic YIN (pYIN) to a stable portion of every candidate.
Unlike a single autocorrelation maximum, pYIN integrates candidate troughs over
a threshold distribution and decodes a temporally coherent voiced/unvoiced
path. OrgRec retains estimator confidence and applicability; lack of a reliable
fundamental is not converted into false pitch certainty.

### 3. Frequency-aware exact onset

The fine pass rereads original PCM around the coarse attack. It combines:

- broadband energy rise;
- low- and high-frequency energy;
- spectral change;
- energy around the estimated fundamental and its harmonics; and
- temporal connection to the sustained pipe sound.

Its spectral window follows the pipe period:

`window = clamp(2.5 / f0, 2.5 ms, 45 ms)`

The last localization step uses a 1–4 ms micro-envelope, normally 0.25 ms for
the supplied 192 kHz recordings. It walks back through quieter connected
precursors and snaps to a preceding waveform zero crossing. The maximum
backward search is also frequency dependent:

`maximum onset lead = clamp(8 / f0 + 30 ms, 55 ms, 300 ms)`

An isolated action click is therefore not accepted merely because it is the
first high-energy impulse. The rise must connect acoustically to the subsequent
pipe speech. When the evidence is inconclusive, OrgRec places a conservative
boundary before the coarse gate and warns the reviewer instead of risking a
clipped attack.

This follows the established distinction between a physical transient, an
onset, and the perceptual attack interval in musical-onset research. It also
reflects flue-pipe measurements showing that jet formation and the initial
pipe transient evolve over time rather than appearing as an ideal amplitude
step.

### 4. Frequency-local release and tail

Broadband room noise is a poor ending criterion for organs: HVAC and audience
noise may mask one band while a pipe partial remains measurable in another.
OrgRec therefore follows the fundamental and up to six harmonics with a
period-aware window:

`window = clamp(4 / f0, 12 ms, 90 ms)`

For each region it estimates a local, frequency-specific baseline from material
before the onset. A contrast-dependent threshold of roughly 3–6 dB above that
baseline adapts to both weak upperwork and strong low pipes. A tail is complete
only when at least 90% of the harmonic evidence remains quiet for 400–600 ms.
The exporter then retains a 250 ms guard where the next onset and source bounds
permit it.

If a tail reaches the next attack or the four-second analysis limit, it is
marked **right-censored**. If harmonic evidence is not usable, a conservative
broadband fallback is recorded explicitly. The result applies the physical
idea of band-limited decay analysis but does not claim ISO 3382 compliance or a
reverberation-time measurement.

### 5. Joint sequence assignment

Ascending mode uses dynamic programming across the entire detected sequence.
At each region it can:

- advance to the next expected roadmap pipe;
- remain on the previous pipe for a retake;
- skip a roadmap position representing a missing or unrecorded pipe; or
- discard a spurious acoustic event.

The score combines order, pitch confidence, direct and octave-normalized cents
distance, and transition penalties. This is an application-specific sequence
decoder, conceptually related to state-sequence methods such as Viterbi
decoding; it is not a trained speech HMM and its confidence is not a calibrated
probability.

If fewer than half of the regions in compound or unusual material yield
plausible monophonic assignments, OrgRec falls back to documented order with
reduced confidence. Each imported source is independently anchored at the
selected roadmap position; several files are not silently optimized as one
global sequence.

## Warnings and recommended action

| Warning | Interpretation | Recommended review |
| --- | --- | --- |
| Low onset confidence / conservative onset | Fine evidence was inconclusive. | Listen from the sample start and inspect the attack spectrogram. Keeping extra lead is safer than trimming it. |
| Pitch unavailable | No reliable monophonic fundamental was retained. | Use roadmap order and timbral/context evidence; common for compound stops. |
| Pitch deviation above 80 cents | Assignment and measured F0 disagree materially. | Check octave ambiguity, wrong starting roadmap note, retry, or misplayed pipe. |
| Retake | Consecutive regions best match the same roadmap pipe. | Keep the best take or retain both as documented alternatives. |
| Missing pipe / skipped position | Alignment advanced over an expected pipe. | Confirm whether the pipe was omitted, silent, absent, or failed. |
| Spurious / unassigned region | A region does not plausibly fit the roadmap. | Inspect for action noise, speech, aborted notes, or an intentionally unordered note. |
| Right-censored tail | Decay met the next note or analysis limit. | Keep for review; do not interpret the stored endpoint as an observed acoustic tail end. |
| Broadband tail fallback | Frequency-local decay evidence was insufficient. | Inspect the final partials and room-noise interaction. |

## Source preservation and provenance

The master remains immutable. Every generated take stores:

- source-master identifier, relative path, and SHA-256;
- exact inclusive start and exclusive end frame;
- detected onset, sound offset, and tail frames with equivalent times;
- source sample rate, channel layout, and PCM representation;
- reference channel;
- assignment mode, expected note, confidence, and warnings;
- boundary method, tail method, censoring state, and algorithm version; and
- backlinks between the master and every generated take.

The splitter seeks using integer source frames. It does not reconstruct bounds
from rounded seconds. It does not resample, normalize, denoise, crossfade, or
otherwise alter the source waveform. Project consistency auditing checks the
master checksum, frame ordering and bounds, time/frame agreement, and both
directions of the source/take relationship.

## Recording protocol for reliable segmentation

- Record isolated notes, not chords or legato scales.
- Hold every pipe long enough to establish stable speech; 1.5–3 seconds is a
  useful field target, with longer holds for slow low pipes.
- Release fully and leave at least 0.4 seconds before the next key-down.
- Use the roadmap order when practical and note the first selected pipe.
- Do not stop the recorder between harmless retries; the sequence decoder is
  designed to retain them.
- Avoid speaking, moving stands, or operating noisy mechanisms during gaps.
- Preserve microphone and console gain throughout a stop whenever possible.
- Record room tone before or after the pass so local baselines remain
  representative.

## Validation on supplied organ sessions

The version 3 detector was regression-tested against representative uncut
masters from all three supplied sessions. Each is stereo, 192 kHz, 32-bit
float:

| Session and source | Duration | Regions | Harmonic tails | Censored | Broadband fallback |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cuntz Positiv, `Gedackt 8' 0017 [2019-02-11 144824].wav` | 667.445 s | 57 | 47 | 9 | 1 |
| Silbermann Leipzig, `Gedackt 8' 0017 [2019-01-28 134801].wav` | 344.752 s | 20 | 18 | 1 | 1 |
| Klanglabor, `Quintade 4' 0001 [2019-02-12 152733].wav` | 305.269 s | 18 | 16 | 1 | 1 |

These are detector counts, not assertions about rank compass. A pass can
contain retakes, aborted notes, missing or silent pipes, or only part of a
rank. MODAVIS roadmap comparison occurs during sequence assignment and review,
where mismatches remain visible rather than forcing the region count to equal
an assumed pipe quantity.

Five representative split notes were also inspected as onset/offset
spectrograms. The check covered low, middle, and high regions and included the
historically difficult very-high-pipe case. The onset marker retained the
initial transient while the exported sample supplied only the documented 10 ms
safety lead; harmonic endings were plausible or explicitly warned as censored
or fallback. This targeted audit detects gross boundary failures but is not a
statistical accuracy estimate for every organ, stop, room, and microphone
position.

Automated tests cover non-grid-aligned speech, a slow-blooming 32.7 Hz pipe, a
fast 4.186 kHz pipe, a detached mechanical click, quiet extended harmonic
release, retakes, missing pipes, spurious regions, exact export lengths, and
frame-for-frame equality between exported openings and their source intervals.

## Limitations and improvement path

- Detection uses the configured reference channel. A severely obstructed or
  noisy reference microphone can be less reliable than another recorded
  channel; compare channels during review.
- Stable F0 estimation assumes one dominant pipe. Mixtures and strong
  subharmonics may rely primarily on sequence order.
- Legato transitions without a quiet or spectrally separable interval can
  remain a single region.
- A following attack can mask the prior room tail; this is correctly censored,
  not extrapolated.
- Loud key action physically coincident with pipe speech cannot always be
  separated from chiff by signal analysis alone.
- Historic instruments, unstable wind, tremulants, weak speech, very noisy
  rooms, and unusual temperaments require more human review.
- The current confidence values rank evidence within the workflow. A future
  labelled corpus of expert-corrected organ boundaries would permit formal
  precision/recall, boundary-error, and confidence-calibration evaluation.
- A future multichannel consensus detector could use spatial coherence to
  reject local action noise, provided channel delay and polarity are accounted
  for.

The system deliberately retains questionable events and corrections instead
of optimizing for a superficially clean region count. Expert review is part of
the evidential workflow.

## VAO 0.2.0 projection

VAO export retains the uncut master and represents each non-destructive cut as
a `modaudio:SampleExtractionRegion`. The half-open start/end frames, source
sample rate, total frames, SHA-256, reference channel, boundary confidence, and
censoring bind the region to one source clock. The derived take links back with
`modaudio:extractedFromRegion` and PROV derivation. Seconds remain available for
navigation, but frames are authoritative for cutting.

Segmentation analysis observations retain the assigned key/component,
assignment confidence, onset and offset frames, warnings, and exact-frame
`timeRange`. Accepted cut notes can additionally expose reviewed
`SamplePlaybackParameters`, a per-key `TuningMap`, an accepted loop set, and a
recorded release region. The public graph therefore supports another sampler
without decoding `payload/orgrec/project.json`, while the private payload still
provides lossless OrgRec editing.

## Command-line inspection

The same detector can generate a JSON report without changing the source:

```sh
swift run OrgRecDatasetTool long-take-inspect \
  /path/to/continuous-stop.wav /path/to/analysis.json \
  --reference-channel 1
```

`--reference-channel` is one-based. The app obtains it from the selected
microphone setup. The command-line form has no project roadmap, so its regions
remain unassigned; use the app to classify them against MODAVIS data and create
project takes.

## Scientific basis and references

The references below explain the signal-processing principles; OrgRec's
thresholds, guards, evidence fusion, and roadmap decoder are application-
specific implementations validated as described above.

- Bello, J. P., Daudet, L., Abdallah, S., Duxbury, C., Davies, M., & Sandler,
  M. B. (2005). “A tutorial on onset detection in music signals.” *IEEE
  Transactions on Speech and Audio Processing, 13*(5), 1035–1047.
  [doi:10.1109/TSA.2005.851998](https://doi.org/10.1109/TSA.2005.851998).
- Verge, M.-P., Hirschberg, A., & Caussé, R. (1994). “Jet formation and jet
  velocity fluctuations in a flue organ pipe.” *Journal of the Acoustical
  Society of America, 95*(2), 1119–1132.
  [doi:10.1121/1.408460](https://doi.org/10.1121/1.408460).
- Hruška, V., & Dlask, P. (2020). “On a robust descriptor of the flue organ
  pipe transient.” *Archives of Acoustics, 45*(3), 377–384.
  [doi:10.24425/aoa.2020.134054](https://doi.org/10.24425/aoa.2020.134054).
- de Cheveigné, A., & Kawahara, H. (2002). “YIN, a fundamental frequency
  estimator for speech and music.” *Journal of the Acoustical Society of
  America, 111*(4), 1917–1930.
  [doi:10.1121/1.1458024](https://doi.org/10.1121/1.1458024).
- Mauch, M., & Dixon, S. (2014). “pYIN: A fundamental frequency estimator
  using probabilistic threshold distributions.” *Proceedings of ICASSP*,
  659–663.
  [doi:10.1109/ICASSP.2014.6853678](https://doi.org/10.1109/ICASSP.2014.6853678).
- Schroeder, M. R. (1965). “New method of measuring reverberation time.”
  *Journal of the Acoustical Society of America, 37*(3), 409–412.
  [doi:10.1121/1.1909343](https://doi.org/10.1121/1.1909343).
- International Organization for Standardization. (2008). *ISO 3382-2:2008,
  Acoustics—Measurement of room acoustic parameters—Part 2: Reverberation time
  in ordinary rooms.* [Official standard record](https://www.iso.org/standard/36201.html).
- Rabiner, L. R. (1989). “A tutorial on hidden Markov models and selected
  applications in speech recognition.” *Proceedings of the IEEE, 77*(2),
  257–286. [doi:10.1109/5.18626](https://doi.org/10.1109/5.18626).

For the separate full single-take CREPE/pYIN and spectral-analysis workflow,
see [Audio interfaces and spectral analysis](AUDIO_AND_SPECTRAL_ANALYSIS.md).
