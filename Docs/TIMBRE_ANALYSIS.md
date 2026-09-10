# Timbre and rank-family analysis

The authoritative cross-subsystem provenance and standards boundary are in the
[scientific-method register](SCIENTIFIC_METHODS.md); this guide supplies the
organ-timbre-specific derivation and interpretation detail.

OrgRec provides **Timbre & rank-family analysis** as a designated, manually
started process on the Analysis page. It is separate from per-take pitch,
transient, loop, and quality-control analysis. Running it does not accept or
reject takes and does not replace a documented MODAVIS stop or rank identity.

The primary result is an immutable rank characterization plus a
pitch-dependent rank fingerprint. The optional family mode adds a calibrated,
abstaining hierarchy over four broad tonal families: flute,
diapason/principal, string, and reed. It deliberately does not infer an exact
stop name, footage, maker, date, construction, or material. The earlier
engineering-profile relative support remains stored for transparent backward
comparison but is not presented as a probability.

## Processing contract

The stored contract is `orgrec-timbre-analysis/2`; the signal path is
`orgrec-harmonic-ltas/2`; and the current transparent family profile is
`orgrec-hergert-family-profile/1`.

For each recorded key, OrgRec chooses one best usable take, preferring an
accepted take and then measured-pitch confidence. It then:

1. uses the take's existing stable-sustain and sound-offset/key-up evidence;
2. reads only the designated reference channel, never a waveform sum or stereo
   downmix;
3. converts that channel to 48 kHz with `AVAudioConverter`;
4. averages Hann-window power spectra over the stable interval;
5. chooses a pitch-adaptive FFT from 8,192, 16,384, 32,768, or 65,536 samples;
6. searches disjoint regions for harmonic partials 1–20 below 20 kHz, retains a
   partial only when its peak is at least 6 dB above a local spectral-noise
   estimate, and integrates noise-subtracted power over its Hann main lobe;
7. stores the audio SHA-256, source take and analysis-run IDs, channel, stable
   interval, fundamental and its source, FFT, frame count, partial levels, and
   applicability with the observation.

Every report also embeds the complete parameter object, a SHA-256 fingerprint
of its canonical JSON representation, and the generating OrgRec software
name, semantic version, build, and identifier. These are distinct from the
method and data-contract versions.

Spectrum segmentation `/2` treats the earliest sound-offset or key-up marker
as a hard upper bound, with a 100 ms guard. The selected sustain is at most ten
seconds. A short interval is never extended into the release to meet a minimum
duration. Missing boundaries or less than two seconds of sustain limit the
observation; an empty or unreadably short interval is refused.

Harmonic bin ownership ends at the midpoint to each neighboring harmonic, with
each exact midpoint assigned to the higher harmonic. Extraction requires at
least two bins per fundamental. Relative levels integrate five bins around the
peak, clipped to this ownership interval, rather than using the peak bin alone.
This reduces sensitivity to a sinusoid's position between FFT bins. Frequencies
use three-bin interpolation of log power. The five-bin rule and local-noise
subtraction are OrgRec choices; windowing and spectral power conventions are
explained in the [SciPy spectral-analysis guide](https://docs.scipy.org/doc/scipy/tutorial/signal.html#spectral-analysis).
Levels remain relative and uncalibrated. Stored `orgrec-harmonic-ltas/1` results
retain their original method identity; comparisons should use a common version.

A measured CREPE–pYIN consensus with confidence at least 0.35 supplies `f₁`.
When that is unavailable, characterization can use the roadmap expectation but
the observation is marked limited. At least five detected partials and three
usable recorded pipes are required for an applicable rank trajectory.

## Calculated features

For harmonic power `Pₙ`, the unitless normalized centroid is:

`c/f₁ = Σ(n Pₙ) / ΣPₙ`

For adjacent levels `Lₙ` in dB, the weighted slope is:

`s = Σ[n^-q (Lₙ₊₁ − Lₙ) / log₂((n+1)/n)] / Σn^-q`, with `q = 1.729`.

OrgRec uses the plot-consistent sign convention: rising adjacent partials are
positive and a falling spectrum is negative. The typeset Eq. 13 in Hergert &
Höper can be read with the opposite order even though the paper's plots and
prose describe the convention implemented here. A synthetic −12 dB/octave
test fixes the behavior at −12 dB/octave.

OrgRec also stores the even-to-odd harmonic energy ratio and assigns one of the
six lowest-five-partial descriptors used by Hergert & Haverkamp: dominant
fundamental, weak even/chalumeau-like, weak second, weak fourth, harmonically
rich, or strong-second/octavial. An indeterminate value is retained when the
pattern is incomplete or ambiguous.

## Empirically calibrated hierarchical classifier

The bundled `orgrec-empirical-hierarchical-timbre-model/1` first classifies
flue versus reed and then classifies a flue result as flute,
diapason/principal, or string. The statistical unit is a rank, never an
individual pipe: rank vectors contain medians and interquartile ranges of
centroid, slope, even/odd balance, and partials 1–8; pitch slopes for the first
three measures; and fractions of each partial-pattern prototype. Stop name,
footage, filename, maker, and dataset identity are excluded from the inference
features.

Training data is built from the acquired inventory and source catalog described
in `orgsamples-retriever/DATASET_REFERENCE_GUIDE.md`. The default policy admits
only explicitly Creative-Commons records catalogued as a single real pipe
organ. It resolves GrandOrgue definitions, preserves source hashes and license
provenance, decodes WavPack streams only into disposable analysis copies, uses
stratified pipes across each rank, and retains pitch only when CREPE, pYIN, and
autocorrelation do not show a critical disagreement. Mixtures, celestes,
noise/control samples, ambiguous names, missing audio, and unresolved package
definitions are excluded with machine-readable reasons.

Documentary stop names are converted by the versioned, auditable
`orgrec-organ-stop-label-rules/1`. These are weak labels: they encode the
cataloguer's broad stop-family description, not destructive pipe inspection or
universal organological ground truth. Instrument identities—not files or
pipes—are assigned disjointly to training, temperature-calibration, and
untouched test partitions. Training uses class-balanced multinomial logistic
nodes. The calibration instruments determine node temperatures, the empirical
class-centroid out-of-distribution envelope, and the acceptance threshold.
Reports retain accuracy, macro-F1, log loss, Brier score, expected calibration
error, accepted coverage/accuracy, confusion matrices, split assignments,
model/corpus versions, and the corpus SHA-256.

Inference emits a four-class calibrated distribution but returns a family only
when the maximum probability reaches the frozen validation-selected threshold
and the rank lies inside the empirical OOD envelope. Otherwise it explicitly
abstains, retains the distribution as limited evidence, and records the reason.
Small or geographically/constructionally narrow corpora remain a limitation;
the bundled model is an installed research candidate, not population-wide
organological validation.

## Pitch-dependent fingerprints and transition detection

Every analysis derives a key-ordered fingerprint from centroid, spectral
slope, even/odd balance, and partials 1–8. It stores the complete trajectory,
robust bass/middle/treble summaries, and quadratic per-feature pitch trends.
If at least eight usable pipes are present, OrgRec robustly standardizes the
multivariate trajectory and compares continuous piecewise-linear models using
BIC, with at least four observations per segment and no boundary spanning a
gap wider than four semitones.

A selected boundary is reported only when the BIC improvement reaches 10 and a
deterministic residual-permutation test controls the family-wise search across
all eligible boundaries at p ≤ .05. Each candidate stores adjacent key numbers,
ΔBIC, family-wise p-value, standardized effect size, evidence strength, seed,
parameters, and a cautious interpretation. With fewer pipes, OrgRec retains a
descriptive fingerprint but makes no transition claim. A detected spectral
discontinuity may be consistent with a construction, scaling, voicing,
material, resonator, wind-supply, sampling, or recording change; documentary
and physical evidence is required before naming its organological cause.

The transition procedure uses Schwarz's BIC
([doi:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)). Its
residual-permutation maximum-statistic screen is informed by resampling-based
multiple-testing practice, but is an OrgRec procedure: it is not the exact
Westfall–Young step-down algorithm. Likewise, the learned hierarchy's held-out
temperature scaling follows Guo et al.
([official PMLR record](https://proceedings.mlr.press/v70/guo17a.html)), while
the empirical OOD envelope, finite-sample acceptance quantile, feature set,
threshold, hierarchy, and abstention rule are OrgRec choices. The acceptance
quantile is not a conformal coverage guarantee.

## Legacy family support and applicability

The legacy comparison measures distance in the `c/f₁`–`s` plane to four explicit
OrgRec profile centers. The centers and scale factors are engineering choices
placed in the broad family regions reported by Hergert & Höper; they were not
fitted to a labelled population and are not parameters published by the paper.
The UI therefore calls the normalized result **relative support**, not a
calibrated probability. Legacy stored `probability` keys remain readable, but
new reports and exports emit only `relativeSupport`.

The frozen profile is:

| Family | center `c/f₁` | center slope (dB/oct) | `c/f₁` scale | slope scale |
| --- | ---: | ---: | ---: | ---: |
| Flute | 1.10 | −21 | 0.38 | 7 |
| Diapason/principal | 1.50 | −12 | 0.48 | 6 |
| String | 2.55 | −4 | 0.85 | 6 |
| Reed | 4.00 | −4 | 1.65 | 8 |

Family inference is explicitly out of distribution when `c/f₁` is outside
0.95…12, slope is outside −70…45 dB/oct, or the nearest normalized profile
distance exceeds 3.25. In that case OrgRec retains the characterization,
marks the observation limited, records the reason, and emits no family
support. These boundaries are conservative OrgRec engineering controls, not
claims from the papers.

Rank support uses quality-weighted observations: applicable evidence has
weight 1, limited evidence 0.35, and not-applicable evidence 0. The aggregate
stores the weighted mean profile distance, between-pipe relative-support
standard deviation, and effective observation count. This prevents fallback
evidence from silently carrying the same weight as measured-pitch evidence.

Mixtures and other compound ranks are reported as not applicable. Their
perception depends on several simultaneous ranks, composition, breaks, ERB
interaction, and pitch salience. Celestes, `Schwebung` stops, and other
deliberately detuned ranks are also not applicable because beating and
fluctuation strength require joint temporal analysis. These are scope results,
not processing failures.

OrgRec flags abrupt nearby-key movement in the timbre plane only across gaps of
one to four semitones and normalizes the jump by the square root of the pitch
gap. Wider sampling gaps produce an explicit no-claim note. A flagged jump
must not automatically be smoothed or labelled an outlier: changed, shortened,
or hybrid bass construction can create a real rank transition.

## Publication-to-method mapping

- Frank Hergert and Nicolas Höper, “Envelope Functions for Sound Spectra of
  Pipe Organ Ranks and the Influence of Pitch on Tonal Timbre,”
  [doi:10.1121/2.0001673](https://doi.org/10.1121/2.0001673): steady-state LTAS,
  up to 20 harmonic partials, `c/f₁`, the `q = 1.729` weighted slope, pitch
  trajectories, and broad tone-family regions.
- Frank Hergert and Michael Haverkamp, “Tonal Timbre Variations of Historical
  Recorders and Transverse Flutes Compared to Pipe Organ Ranks,”
  [doi:10.61782/fa.2023.0327](https://doi.org/10.61782/fa.2023.0327): the six
  lowest-five-partial pattern descriptors and the limitation that two scalar
  coordinates do not distinguish every spectral pattern.
- Frank Hergert, “Design Principles of Pipe Organ Mixtures – viewed from a
  psychoacoustic Position,”
  [doi:10.1121/2.0001671](https://doi.org/10.1121/2.0001671): the compound-stop
  scope gate and the relevance of composition, breaks, ERBs, and pitch salience.
- Frank Hergert and Paul Hale, “A Review of Technical Inventions to include deep
  Bass Tones into Pipe Organs despite Space Constraints,”
  [doi:10.1121/2.0001672](https://doi.org/10.1121/2.0001672): interpretation of
  real bass construction transitions and discontinuities.
- Frank Hergert, “Targeted detuning aiming for sensory pleasantness – A case
  study of Pipe Organs and Accordions,”
  [doi:10.1051/aacus/2024020](https://doi.org/10.1051/aacus/2024020): the
  detuned/celeste scope gate and need for temporal modulation evidence.

The same mapping is available from the in-app **Method & publications** modal.
The modal additionally distinguishes paper-derived methodology from OrgRec's
FFT adaptation, threshold, applicability, and family-profile decisions.

## PositivXR use

After importing `test-data/PositivXR` with the documented legacy-dataset
profile, open Analysis and select a stop/rank in **Timbre & rank-family
analysis**. Characterization is suitable for all five isolated stops. Family
suggestion is an exploratory check across the 45-key rank trajectories, not a
training/evaluation claim: all files come from one instrument, and filename,
duration, footage, and rank order must never be used as classifier inputs.

The PositivXR stereo files can contain strongly negative interchannel
correlation. Reference-channel-only processing is therefore required; summing
the two waveforms could cancel valid organ sound. Split development and test
sets by rank or instrument—not by randomly mixed files from the same rank—when
additional labelled corpora become available.

The historical OrgRec 0.2.0 (build 2) validation also ran the designated
legacy process over all 225 source WAVs
on both reference channels (450 channel analyses). The retained report records
zero processing failures, 9 out-of-distribution observations, one observation
without two usable coordinates, and 10 observations without family support.
All otherwise successful observations are intentionally marked limited because
the validation uses the previously inferred A4=462.95 Hz corpus reference and
mapped footage rather than relabelling that prior as a fresh per-file measured
pitch. Median absolute interchannel differences were 0.174 in `c/f₁` and 2.985
dB/oct in slope; top-family agreement among comparable channel pairs was
69.3%. This sensitivity is material and confirms that reference-channel choice
must remain paradata rather than being hidden by averaging.

The machine-readable evidence, including every observation, two-channel rank
trajectories, processing times, frozen parameters, software version/build,
failures, OOD reasons, and caveats, is retained at
[`Artifacts/PositivXR/TIMBRE_VALIDATION_0.2.0.json`](../Artifacts/PositivXR/TIMBRE_VALIDATION_0.2.0.json).

## Storage and VAO export

Reports are appended to `OrgRecProject.timbreAnalyses`; earlier runs remain
selectable in the Analysis-page history. VAO export writes the designated
analysis type
`https://w3id.org/modavis/vao/vocab/analysis/pipe-timbre-characterization` with
inferred status, applicability, per-pipe provenance, feature observations,
optional broad-family relative support, profile versions, and the DOI mapping.
VAO 0.2.1 additionally exports the empirical classifier and pitch-dependent
fingerprint as separate analysis records and declares their optional research
capabilities. The classifier activity names an indexed immutable model asset,
learned-inference method, calibrated distribution, abstention/OOD decision,
and training-corpus fingerprint. The fingerprint activity names its parameter
hash and random seed and exports typed trajectories, trends, and transition
candidates. The project, analysis reports, analysis runs, capture manifest, IAD manifest and
per-take paradata, VAO producer extension, and every generated VAO activity all
carry OrgRec's software version/build. Timbre VAO paradata additionally embeds
the full frozen parameter set and its SHA-256 fingerprint.

VAO 0.2.2 retains all of those 0.2.1 contracts unchanged and adds a separate
optional `collection-acoustic-diagnostics` capability. Its
`evidence-qualified-collection-acoustic-diagnostics` analysis can consume the
current per-take tuning, spectral-summary, partial-track, and pipe-behaviour
evidence to screen multivariate within-rank anomaly candidates and
harmonic-number-aligned similarity candidates. It does not alter the timbre
characterization, learned family distribution, or pitch-dependent rank
fingerprint, and its scores must not be interpreted as family classifications.
An anomaly remains a non-diagnostic review candidate; a similarity candidate
does not assert identity, shared pipes, common construction, or any physical
relation. See [Collection Analysis v2](AUDIO_AND_SPECTRAL_ANALYSIS.md#collection-analysis-v2)
for its evidence gates, robust methods, applicability rules, and eight governed
VAO observations.
