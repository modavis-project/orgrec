# Loop analysis and sustained sampled-instrument playback

The method's provenance classification and related signal-analysis sources are
in the [scientific-method register](SCIENTIFIC_METHODS.md).

## Scope and evidence policy

OrgRec detects, reviews, stores, visualizes, and plays sustain-loop point sets
for pipe-organ sampling. Detection is a proposal, not a curatorial decision.
Automated candidates, accepted revisions, superseded revisions, and review
records remain distinct. Reanalysis may replace unreviewed proposals, but it
retains reviewed sets when the source-audio SHA-256 is unchanged.

Loop coordinates use the source sample clock. Every region is the half-open
interval `[startFrameInclusive, endFrameExclusive)`, shared by all channels.
Seconds shown in the interface are derived views. A future RIFF/WAVE `smpl`
writer must convert the exclusive end to that chunk's inclusive end by
subtracting one frame; it must not alter the stored OrgRec/VAO coordinates.

## Detector and pipe behaviour

`LoopPointDetector` restricts its search to the observed stable sustain, with a
safety margin after sustain start and before operator key-up or sound offset.
It returns no candidates when that interval cannot contain the configured
minimum loop and comparison windows.

The detector reads every channel at the native sample rate, estimates sustain
stationarity and amplitude-modulation rate/depth, proposes fundamental- and
modulation-period-aligned lengths, then performs coarse and sample-frame seam
refinement. Its retained score contains normalized penalties for waveform,
derivative, harmonic spectral magnitude, partial phase, level, pitch/cycle
alignment, within-loop stationarity, interchannel disagreement, and audible
short-cycle repetition. Zero is ideal. Rank and confidence are summaries; the
components permit later re-ranking without claiming new source evidence.

The pipe-sound behaviour summary separately stores attack duration (seconds and
fundamental periods), partial-onset order, sustain stationarity, amplitude and
frequency modulation, release and room-tail durations, partial-decay
dispersion, interchannel correlation, and loopability class. Missing fields
mean that the corresponding phase was censored or lacked sufficient evidence.

## Review interaction

The waveform and spectrogram share one staged loop region. The translucent body
shows the repeated region, stronger edge bands show the equal-power crossfade,
and labeled dashed handles show loop in and loop out. A reviewer can select a
handle and drag it in either visualization, enter seconds, use the playhead, or
nudge by one exact source frame. Invalid order or excessive crossfade is shown
as an error and cannot be accepted.

Candidate cards expose rank, confidence, frame-derived times, and total seam
score. Selecting a card changes the staged view and audition source; it does not
change stored evidence. Acceptance requires reviewer identity and a reason and
creates a new `accepted` `LoopPointSet` with `wasRevisionOf`. A former accepted
set becomes `superseded`; rejection is an immutable `LoopPointReview` and does
not delete the candidate.

## Sustained play mode

The analysis workspace provides a sampled-instrument note gate:

- **Hold note** plays recorded attack and pre-loop material, then repeats the
  staged or accepted sustain region.
- Every repetition uses an equal-power overlap between loop tail and head on
  all channels with shared frame coordinates.
- The articulation envelope stores attack, sustain level, release, and linear
  or equal-power curve separately from loop evidence.
- **Release note** crossfades to the recorded release, fades the loop with the
  envelope, or finishes the current cycle before release.
- Runtime visualization reports attack/sustain/release state, envelope level,
  source-time position, and loop iteration. Whole-file looping remains a
  separate transport option.

Recorded release uses a second audio node, so sustain and release overlap
rather than stop/reschedule at note-off. When no recorded release is
addressable, envelope release is the safe policy. Audition never silently
accepts a loop or changes analysis evidence.

## Persistence and exchange

`TakeRecord` stores `loopPointSets`, `acceptedLoopPointSetID`, and
`loopPointReviews`. `AnalysisSummary.detectedLoopPointSets` retains the current
detector output, while `pipeSoundBehavior` retains phase-resolved descriptors.
The capture analysis JSON includes all take-level fields. An accepted loop is
also projected to IAD `audio.segment` with type `sustain-loop` and source
`reviewed-loop-point-set`.

VAO exports use the provisional MODAVIS audio namespace
`https://w3id.org/modavis/ontology/audio#`:

| Record | VAO/MODAVIS representation |
| --- | --- |
| loop set | `loopPointSet` entity typed `modaudio:LoopPointSet` |
| exact region | `signalRegion` typed `modaudio:SustainLoopRegion` |
| source binding | `modaudio:appliesToSignal` plus source SHA-256 |
| region membership | `modaudio:hasLoopRegion` |
| reviewed revision | `prov:wasRevisionOf` plus review paradata |
| playable gate | interaction with `vao:usesSample`, `modaudio:usesLoopPointSet`, and `vao:activates` |
| full sample mapping | `modaudio:SamplePlaybackParameters` linked by `modaudio:usesPlaybackParameters` |
| exact tuning | `modaudio:TuningMap` linked by `modaudio:usesTuningMap` |
| recorded release | `modaudio:ReleaseRegion` linked by `modaudio:usesReleaseRegion` |

Properties retain sample rate, channel count, total frames, status,
loopability, confidence, algorithm/version, envelope, half-open coordinates,
crossfade, mode, exit policy, release start, and score components. Accepted
loops cause the package to claim the playable profile and
`capability/sample-looping`.

VAO 0.2.0 does not treat a valid loop as a complete sampler mapping. The
separate reviewed playback parameter set carries root/key/velocity domains,
measured and target frequency, pitch mode, gain, channel policy, envelope,
latency, selection/round-robin information, and note-off policy. This keeps
algorithmic loop evidence, the accepted loop decision, and the settings used by
the renderer independently reviewable.

Both Swift and Python VAO validators require valid source clock/fixity, exactly
one resolved sustain region, bounded half-open frames, crossfade shorter than
half the region, matching linked-audio SHA-256, and—for accepted sets—a
playable interaction resolving both sample and loop set.

## Verification and limitations

Tests analyze a synthetic stable tone, require a valid proposal and behaviour
summary, round-trip an accepted set through capture/IAD JSON, export the
MODAVIS/VAO graph, and validate it in both implementations. Hardware audio
output is not exercised by unit tests; playback uses the same validated frame
contract as detection and export.

Confidence describes seam suitability within the supplied capture. It does not
prove that a short loop preserves the long-term behaviour of a slowly beating,
wind-unstable, or tremulated pipe. Such material needs a longer modulation-
aligned region or should remain `unsuitable`, and always requires multichannel
audition.

## Method provenance

`orgrec-loop-detector/1` is an OrgRec engineering synthesis. Its weighted seam
score combines waveform and derivative continuity, harmonic magnitude and
phase, level, pitch/cycle alignment, stationarity, interchannel mismatch, and
short-cycle repetition; no cited publication is claimed as the source of that
complete detector or its weights. Period alignment uses pitch/modulation
evidence documented by the audio-analysis methods, while the equal-power
overlap is a playback design choice. Confidence is therefore a deterministic
ranking of candidates under the frozen OrgRec parameters, not a perceptual
inaudibility probability or a guarantee of long-term musical naturalness.
