# Audio interfaces and spectral analysis

Scientific provenance, exact adaptations, method versions, verification, and
standards non-claims are indexed in the
[scientific-method register](SCIENTIFIC_METHODS.md).

## macOS audio path

OrgRec enumerates the Core Audio Hardware Abstraction Layer rather than relying
only on the system-default microphone. Every live device with input channels is
available, including class-compliant USB, Thunderbolt, PCI, AVB, built-in,
Aggregate Device, virtual, and Bluetooth endpoints.

The chosen AudioDeviceID is applied directly to the AVAudioEngine AUHAL input
unit. Before capture, OrgRec negotiates the device's nominal sample rate and I/O
buffer frame size. Safe, Balanced, and Ultra-low policies target 512, 256, and
64 frames respectively, bounded by the driver's advertised range. Custom sizes
are also available.

The take freezes:

- persistent Core Audio device UID, name, manufacturer, and transport;
- input channel count and actual stream sample rate;
- actual HAL buffer size;
- device latency and safety-offset frames;
- estimated input-path latency; and
- the selected latency policy.

Aggregate Devices are selected like physical interfaces. Audio MIDI Setup is
linked from OrgRec so researchers can define clock source and drift correction
using Apple's system facility. Bluetooth and virtual devices remain selectable
but receive a phase-coherence and variable-latency warning.

## Real-time writer and channel routing

The Core Audio callback copies into a bounded pool of preallocated buffers; a
dedicated serial queue performs the 24-bit PCM WAVE writes. Queue overruns,
sample-time discontinuities, device loss, format changes, writer errors, and
low-disk observations become structured capture diagnostics on the take.

Setup placements map one-based hardware input channels to microphone roles.
OrgRec meters peak and RMS per input, counts clipped samples and silent buffers,
and freezes those statistics with the take. One configured input is the
analysis reference channel; CREPE, pYIN, broadband transients, the spectrogram, and
partial tracking all read that channel rather than assuming channel one.

Completed files receive an EBU Tech 3285 Broadcast Wave `bext` chunk plus a
JSON metadata sidecar. The audio device snapshot, BWF fields, routing, capture
diagnostics, and reference-channel selection are also included in capture
package analysis envelopes.

## Spectrogram profile

The default organ profile uses an 8192-point FFT, 512-sample hop,
Blackman–Harris window, logarithmic 20 Hz–20 kHz display, 100 dB dynamic range,
and a 120-second analysis limit. Each setting is editable and stored in both the
project and take:

- FFT: 1024 through 32768 samples;
- hop: 64 through 4096 samples;
- Hann, Hamming, or Blackman–Harris window;
- linear or logarithmic frequency axis;
- arbitrary minimum and maximum frequency;
- 40–140 dB display range;
- display and time-frame limits; and
- 10–600 second analysis duration.

Larger FFTs resolve closely spaced low organ partials. Smaller hops improve the
time resolution of partial onset and offset. Blackman–Harris is the default
because its sidelobe suppression helps distinguish weak decaying partials from
leakage around stronger neighbors.

## Partial-offset tracking

After the retained CREPE–pYIN result establishes the fundamental, OrgRec searches
around each harmonic. Search tolerance is adjustable from ±10 to ±150 cents,
with a minimum width of 1.5 FFT bins and ownership clipped at the midpoint to
each neighboring harmonic. No bin can supply two harmonics. Adjacent harmonics
with fewer than two bins per fundamental are unresolved. A three-bin parabolic
interpolation estimates sub-bin frequency.

For every tracked partial OrgRec stores:

- harmonic number and expected frequency;
- median observed frequency and cents offset;
- peak spectral amplitude;
- spectral onset;
- acoustic offset;
- decay span; and
- the complete time/frequency/amplitude trace.

Onset and offset thresholds are independently configurable in decibels below
that partial's own peak. A configurable persistence requirement suppresses
single-frame noise crossings. This is intentionally separate from the
broadband sound offset: different pipe partials can decay at substantially
different times.

## Analysis v2 evidence model

Analysis v2 retains the framewise pitch evidence instead of reducing model
output immediately to one number. Every voiced frame stores time, frequency,
estimator score, expected-pitch distance, and applicability. The take summary
adds voiced ratio, IQR and MAD in cents, drift, modulation rate/depth, a 95%
empirical interval, suspected octave errors, and cross-estimator agreement.
AVAudioConverter performs band-limited conversion to the CREPE 16 kHz input.

pYIN follows the two-stage design of Mauch and Dixon: framewise YIN troughs are
integrated over a beta-distributed threshold prior, then voiced/unvoiced pitch
candidates are Viterbi-decoded into a temporally coherent track. CREPE and pYIN
values within 25 cents are fused in log-frequency space. A larger difference is
retained as material evidence; a difference above 50 cents is critical when
both confidences are at least 0.55. Critical values are never averaged, reduce
the retained confidence, trigger QC, and require a written reason before take
acceptance. Normalized autocorrelation runs only as a fallback or independent
adjudicator when critical evidence needs a third view. CREPE is the model
described by Kim et al.
([doi:10.1109/ICASSP.2018.8461329](https://doi.org/10.1109/ICASSP.2018.8461329));
pYIN follows Mauch and Dixon
([doi:10.1109/ICASSP.2014.6853678](https://doi.org/10.1109/ICASSP.2014.6853678)).
OrgRec's resampling, consensus, confidence conversion, expected-note bounds,
and disagreement thresholds are application choices, not parameters asserted
by either publication.

Transient evidence is explicitly censored. A sound already present at the
first frame is `leftCensored`; a sound or tail continuing at the analysis limit
is `rightCensored`. OrgRec never substitutes the sound offset for an unobserved
tail end. Adaptive RMS, spectral-flux and high-frequency proxies, hysteresis,
and level-stability jointly propose onset, stable sustain, acoustic offset, and
tail end. Each boundary retains its state, confidence, and contributing
features.

### Long-take analysis v3

Continuous-stop recordings use a separate segmentation pass before the normal
per-take analysis above. The long-take v3 detector streams the reference
channel, refines every attack against the original source frames, and tracks
the estimated fundamental plus up to six harmonics against a local pre-onset
baseline. Its period-dependent windows preserve both slow low-pipe speech and
fast upperwork attacks. The exact detected onset remains an analytical marker;
the exported sample starts 10 ms earlier as an explicit safety lead.

Release is accepted only after persistent frequency-local quiet. Endings that
meet the next attack or the analysis limit are right-censored, not reported as
observed tail ends. A sequence decoder then aligns all regions jointly with the
MODAVIS roadmap, allowing retakes, missing pipes, and unrelated events without
causing a one-position error in every later assignment. Imported and newly
recorded masters use this identical path. The complete algorithm, validation
counts, limitations, field protocol, and scientific sources are documented in
[`LONG_TAKE_RECORDING.md`](LONG_TAKE_RECORDING.md).

Partial tracks distinguish valid detections from the largest noise bin in a
search region. Local and observed-quiet-region noise floors, SNR, valid-frame ratio,
frequency MAD, decay slope, and track confidence accompany every partial.
Derived pipe summaries include spectral centroid, 85% rolloff, odd/even energy
ratio, energy-weighted inharmonicity, partial attack spread, and median decay
rate.

Multichannel files are read in bounded chunks. Besides the selected reference
signal, OrgRec records level difference, correlation, sample delay, and strong
polarity-inversion evidence for every other channel. These are QA observations,
not automatic microphone or spatial assertions.

Every run is immutable and includes the input SHA-256, exact parameters,
reference channel, applicability, start/end time, algorithm/model version, and
warnings. Reanalysis appends a run while updating the convenient current
summary. Pitch tracks and runs are included in capture packages; VAO and IAD
observations carry supported uncertainty and reference the source run. VAO
0.2.0 additionally records observation status, applicability, censoring,
coverage, evidence count, channels, source region, optional large value asset,
and exact source clock. It uses the VAO musical-cent IRI (exactly 1/1200
octave), not the unrelated `qudt:Centi` spelling.

Each analysis also proposes multichannel sustain-loop sets and a phase-resolved
pipe-sound behaviour summary. Loop scoring retains waveform, derivative,
spectrum, phase, level, pitch-period, stationarity, channel, and repetition
penalties; exact source frames remain authoritative. Attack, sustain modulation,
release, tail, partial-onset order, and decay dispersion are not collapsed into
one global timbre value. See
[`LOOP_ANALYSIS_AND_SUSTAINED_PLAYBACK.md`](LOOP_ANALYSIS_AND_SUSTAINED_PLAYBACK.md).

### Perceptual spectrum and qualified decay in analysis v4

Analysis v4 adds an ERB-rate auditory summary, validated spectral descriptor
families, harmonic slope/deviation and tristimulus evidence, and separate
amplitude and spectral-brightness modulation tracks. It also adds noise-aware
Schroeder decay fitting, uncertainty and multi-slope model selection while
strictly separating an ordinary pipe release from a declared room impulse
response. The algorithms, applicability rules, standards boundary, references,
exchange mapping, and synthetic verification are documented in
[`ADVANCED_ACOUSTIC_ANALYSIS.md`](ADVANCED_ACOUSTIC_ANALYSIS.md).

### Spectrum segmentation in analysis v5

`orgrec-analysis/5` records `orgrec-spectrum-segmentation/2`. Stable-sustain
regions stop before the observed release, using a 120 ms guard for per-take
analysis and 100 ms for harmonic LTAS. Short regions are never extended into a
release or tail. Missing boundaries and short sustain remain explicit
limitations. Transient timestamps and their resolution use the actual sample
hop, including the minimum 64-sample hop at low sample rates. Silence does not
produce phase boundaries or perceptual harmonic partitions.

Partial extraction uses at most 2,048 uniformly spaced STFT frames, independent
of the display time-bin limit. Long sources increase the extraction hop to
respect this budget; the point timestamps preserve that spacing. Display rows
are sampled afterward and retain their separate time step. Changing display
time bins therefore does not change partial tracks or their derived summaries.

Local noise is the median of bins outside the window's main lobe within the
harmonic ownership region (two bins for Hann/Hamming, four for Blackman–Harris).
Where no sidebands remain, the search-region median supplies a conservative
fallback. The temporal noise gate needs at least three complete STFT windows
before an observed onset or after an observed tail end. Without those windows,
the temporal noise floor is absent and local spectral contrast supplies the
validity gate. A continuous tone is no longer rejected because its own sustained
level was mistaken for noise. Partial decay slopes use only frames at or after
an observed sound offset and are absent when that boundary is unavailable.

The run records the segmentation version, extraction cap, partial thresholds,
persistence, source sample rate, reference channel, expected frequency, and
selected sustain interval in the parameter fingerprint. Synthetic regression
tests cover release exclusion, unique harmonic ownership, bin-phase power
accuracy, continuous tones, display independence, low-rate timing, and silence.

## Collection Analysis v2

After per-take analysis, OrgRec can recompute an
`orgrec-collection-analysis/2` report from the project's current evidence. The
report is a derived analytical view, not a replacement for its take records,
immutable source-analysis runs, roadmap, or documentary component graph. It
freezes the full parameter set and its SHA-256 fingerprint; the exact assessed
and aggregate-contributing take identifiers; contributing source-analysis-run
identifiers; analysis time; and deterministically ordered evidence and result
arrays. Stored `orgrec-collection-analysis/1` reports remain decodable.

### Evidence qualification and coverage

Every take whose roadmap item resolves to a MIDI-keyed position enters the
assessment denominator, including evidence later excluded from aggregation.
The per-take ledger records its analytical rank group, key number, normalized
quality score, `high`, `moderate`, `limited`, or `excluded` tier, number of
available quality dimensions, inclusion decision, exclusion reasons, and
quality flags. Missing analysis or a missing/non-finite pitch deviation,
polyphonic or non-pitched applicability, a critical estimator mismatch, a
rejected or failed take, and an unfinished recording or analysis are hard
exclusions.

For otherwise eligible evidence, the score combines retained pitch confidence,
voiced ratio, CREPE–pYIN agreement, signal-to-noise ratio, valid partial count,
clipping state, and review status. Quality flags and clipping apply explicit
penalties. The default aggregate threshold is 0.45, with moderate and high
thresholds of 0.60 and 0.80. These thresholds are frozen parameters, not claims
that evidence quality is a universal physical scale.

The evidence summary reports eligible, analyzed, aggregate-contributing,
high-, moderate-, limited-, and excluded-take counts; median contributing
quality; reason-grouped exclusions; and aggregate coverage. Aggregate coverage
is contributing takes divided by assessed MIDI-keyed takes. It is deliberately
not roadmap completion, unique-physical-target coverage, or rank-by-pitch-cell
coverage. Below 50% the exported collection analysis is `limited`; neither an
empty evidence set nor an insufficient-evidence state is represented as a
measured zero.

### Rank grouping, tuning curves, and stretch

A roadmap position with a declared parent component uses that parent as its
analytical rank. A custom registration without such a parent uses its
registration identifier. Otherwise OrgRec constructs a stable hash from organ,
division, normalized label, and footage and labels the basis
`inferred-division-label-footage-signature`. This fallback lets explicit-pipe
and demo roadmaps form useful rank curves when every note lacks a parent, but
it is an analytical grouping only. It does not assert documentary component
membership, rank identity, or shared physical pipes.

For every rank and key, OrgRec retains the ordinary median and MAD in cents and
also computes a quality- and inverse-variance-weighted median. Per-take pitch
uncertainty is assembled conservatively from its empirical pitch interval,
pitch MAD, estimator disagreement, and confidence. Inverse-variance weights are
multiplied by evidence quality and capped at a 25:1 ratio so one unusually
precise-looking take cannot dominate. Each point retains weighted observed
bounds, aggregate standard uncertainty, effective sample size, median evidence
quality, and contributing take identifiers.

With at least three distinct key points, octave stretch is the Siegel
repeated-median slope of weighted tuning offset against MIDI key divided by 12.
The lower and upper values are the observed 2.5% and 97.5% quantiles of
pairwise slopes; they are evidence envelopes, not population confidence
intervals. Span coverage is the fraction of observed semitone positions between
the lowest and highest observed key. Residual review candidates are flagged
only beyond the larger of 15 cents or 3.5 robust MAD scales from the fitted
trend.

### Session offset and identifiable drift

Session median pitch offset and session drift are separate results. Offset is
the median of all contributing pitch deviations in the session. Drift is
identified only from repeated measurements of comparable physical targets in
the same setup and reference-channel stratum. When no physical-target
identifier exists, the fallback stratum is analytical rank plus MIDI key;
different notes are never regressed against capture time.

Within each repeated-target stratum, OrgRec takes the median of all pairwise
cents-per-hour slopes, then the median across target strata. The defaults
require at least two repeated targets, three pair comparisons, and a 0.25-hour
observed span. If any requirement fails, drift and its bounds remain absent and
applicability is `indeterminate`; the UI reports that more same-target repeats
are needed. When applicable, bounds are the observed 2.5% and 97.5% target-slope
quantiles, not population confidence intervals. The frozen environmental
reading is displayed as context and is not silently used to temperature-correct
the estimate.

### Acoustic-anomaly candidates

Within an analytical rank containing at least four contributing takes, OrgRec
screens available tuning deviation, spectral-centroid/fundamental ratio,
85%-rolloff/fundamental ratio, odd/even energy ratio, inharmonicity, attack
duration in fundamental periods, sustain stationarity, and amplitude- and
frequency-modulation depths. Each feature is robustly centered and scaled by
its within-rank median and MAD with a physical scale floor; tuning also respects
the take's pitch uncertainty. A root-mean-square robust multivariate distance
avoids making the score grow merely because one take has more populated
features. Missing features are omitted and the retained feature count and all
feature scores remain inspectable.

Default warning and critical thresholds are 3.5 and 5.0. Every result is an
acoustic-anomaly **candidate** for review, not a fault, defect, voicing,
construction, or maintenance diagnosis. Its evidence quality, strongest
contributing dimensions, and within-rank reference centers remain attached.

### Acoustic-similarity candidates

Similarity uses valid tracked partials for harmonics 1 through 16, converts
peak levels to amplitudes relative to each take's strongest partial, and aligns
vectors by harmonic number rather than raw frequency-bin position. A pair must
have the same intended MIDI note, distinct physical-target strata, comparable
setup and reference channel, at least six shared harmonics by default, and a
cosine similarity of at least 0.97. The ranking score also incorporates both
takes' evidence quality and shared-harmonic count, and the default report keeps
at most 100 candidates.

Every interpretation contains “candidate.” Similarity is non-transitive and
does not merge takes, create a relation, or assert physical identity, shared
pipes, common construction, or provenance. Any such assertion requires
independent source or curator evidence.

### VAO 0.2.2 projection

A complete v2 report declares the optional capability
`https://w3id.org/modavis/vao/vocab/capability/collection-acoustic-diagnostics`
and uses the analysis type
`https://w3id.org/modavis/vao/vocab/analysis/evidence-qualified-collection-acoustic-diagnostics`.
Its activity names the exact assessed take inputs and frozen parameters. The
analysis carries all eight governed properties under
`https://w3id.org/modavis/vao/vocab/analysis/collection/`:

- `evidence-summary` and `take-evidence` retain the denominator, exclusions,
  quality, coverage, and inclusion ledger;
- `rank-tuning-curves` uses `aggregation/quality-weighted-median` and the VAO
  musical-cent unit;
- `rank-stretch` uses `aggregation/siegel-repeated-median` and
  `unit/cent-per-octave`;
- `session-offset` uses `aggregation/median` and `unit/cent`;
- `session-drift` uses `aggregation/within-target-median-slope` and
  `unit/cent-per-hour`;
- `acoustic-anomaly-candidates` uses
  `aggregation/robust-multivariate-distance`; and
- `acoustic-similarity-candidates` uses
  `aggregation/harmonic-aligned-cosine`.

The aggregation and unit identifiers share the
`https://w3id.org/modavis/vao/vocab/` base. Validators require all eight
observations, consistent evidence counts and assessed inputs, valid coverage,
the governed aggregation and unit combinations, indeterminate drift when no
slope is present, and similarity interpretations containing “candidate.” The
normative interpretation also keeps anomaly results non-diagnostic. A legacy
`/1` report can still be projected as the earlier
`analysis/collection-tuning` record, but it does not claim the 0.2.2
collection-acoustic-diagnostics capability. See
[`COLLECTION_ACOUSTIC_DIAGNOSTICS.md`](COLLECTION_ACOUSTIC_DIAGNOSTICS.md) for
the compact manifest pattern and review checklist.

## Interactive evidence workspace

The waveform, framewise pitch plot, spectrogram, playback head, transient
boundaries, timed annotations, and partial table share one time viewport. Hover
provides a linked inspection cursor; releasing a drag seeks playback. Zoom and
pan affect presentation only and never alter an analysis run. Selecting a
partial-table row highlights its inferred trajectory and seeks to its onset.
Staged and reviewed loop regions share the viewport too. Their region body,
crossfade bands, and independently selectable loop-in/out handles appear in
both waveform and spectrogram; one-frame nudging preserves the source clock.

The spectrogram inspector reports the exact stored time bin, frequency bin, and
magnitude. Magnitudes are explicitly labeled as dB relative to the derivative's
global peak and must not be interpreted as calibrated SPL. A fixed legend shows
the configured display floor. Nearby partial readouts retain validity and local
SNR rather than presenting every local maximum as a detection.

Visual semantics distinguish evidence classes:

- waveform and heatmap cells are stored analysis derivatives;
- solid pitch points are voiced frame measurements, with confidence encoded by
  opacity;
- dashed partial paths and transient markers are algorithmic inferences;
- gaps are failed validity gates, optionally inspectable as low-confidence
  evidence; and
- censored boundaries are named and drawn differently from observed events.

All major canvases expose combined accessibility labels, numeric summaries, and
interaction hints. Color is supplemented by line style, gaps, labels, and
selection weight, so evidential status does not depend on hue alone. An inline
interpretation panel states resolution, uncertainty, relative-level semantics,
and the immutable source-run identifier.

Manual boundary changes remain visually labeled as reviewed evidence. Saving a
change requires a reason and rejects non-chronological marker sequences; the
automated values remain in the immutable correction history.

Attack, sustain, release, and room-tail intervals are shaded only when their
required endpoints exist; an unresolved or censored endpoint is not invented to
complete a phase. Selecting a boundary exposes a solid draggable handle in the
waveform and spectrogram. Reviewers can alternatively enter a value, set it to the playhead,
nudge it by 1 or 10 ms, or restore the automatic proposal. All changes remain
staged and reversible until Save reviewed boundaries is invoked.
Automatic markers retain the detector's time-grid resolution and display it as
a narrow band around the proposed instant; reviewed values are points and do
not misleadingly inherit that automatic localization band.
