# Advanced acoustical and perceptual-spectral analysis

The complete publication-to-code mapping and standards boundary are maintained
in the [scientific-method register](SCIENTIFIC_METHODS.md).

OrgRec analysis v4 adds two evidence families: a perceptually organized
description of a stable organ sound and a qualification-aware analysis of its
decay or of a deliberately recorded room response. Both are descriptive,
versioned observations. Neither assigns pipe construction, rank family, or
room compliance from a number alone.

## Why the evidence is separated

An ordinary pipe release is the convolution of valve and wind transient,
partial-dependent radiation, enclosure and room response, microphone position,
and noise. It is useful evidence about the captured event, but it is not a room
impulse response. OrgRec therefore uses three explicit qualifications:

- **Observed pipe-plus-room release** permits decay fits and multi-slope
  evidence, but never C50, C80, D50, direct-to-reverberant ratio, or an ISO
  reference.
- **Impulsive-source response** permits early-energy room descriptors when the
  operator states that a suitable impulse source was recorded.
- **Deconvolved impulse response** permits the same descriptors after the
  excitation sweep has been deconvolved outside OrgRec. A raw sweep must not be
  labelled as a deconvolved response.

The selected excitation is frozen into every P2 spatial-capture protocol and
observation. Project validation rejects a response whose metric eligibility no
longer matches that provenance.

## Perceptual spectral evidence

The analyzer selects a bounded 1,024–8,192-sample Hann STFT according to sample
extent and fundamental, covers 20 Hz to the lower of 20 kHz or the reliable
Nyquist region, and caps retained work to 600 frames and 30 seconds. The stable
sustain contributes:

- spectral spread, skewness, kurtosis, flatness, entropy, crest, and framewise
  flux;
- centroid, spread, and flatness in a 32-band triangular ERB-rate
  representation;
- energy within frequency- and resolution-aware harmonic regions;
- harmonic spectral slope in dB/octave, residual deviation from that slope,
  and tristimulus energy groups (fundamental, harmonics 2–4, harmonics 5+);
- independent 0.2–20 Hz detrended sinusoidal scans of RMS-envelope modulation
  and ERB-centroid modulation, each with rate, robust 5–95% depth, and explained-
  energy confidence.

The separate amplitude and spectral-centroid modulation tracks are particularly
important for beating mixtures, celestes, and tremulated pipes: two sounds may
have similar loudness beating while their spectral motion differs, or vice
versa. OrgRec only presents an agreement cue when independently estimated rates
support it; it does not infer a celeste or tremulant identity automatically.

The ERB filters are a compact auditory-rate summary, not a calibrated loudness,
specific-loudness, excitation-pattern, or masking model. Descriptor covariance,
fundamental error, room transfer, level, microphone directivity, position, and
recording chain remain interpretation constraints. The retained spectrogram and
partial trajectories remain authoritative for inspection.

This descriptor family follows the reproducible signal-representation approach
of the [Timbre Toolbox](https://pubmed.ncbi.nlm.nih.gov/22087919/) and uses
descriptor classes that have subsequently received perceptual validation for
musical timbre, including spectral centroid, spread, decrease and deviation
([Kazazis et al., 2021](https://pubmed.ncbi.nlm.nih.gov/34241417/)).

## Energy-decay analysis

For every qualified response, OrgRec:

1. detects or accepts the response origin and removes tail DC;
2. estimates stationary tail power robustly;
3. fits the usable decay above the tail and truncates at the estimated
   decay/noise intersection;
4. subtracts estimated noise power before reverse energy integration;
5. forms the Schroeder energy-decay curve;
6. fits EDT over 0…−10 dB, T20 over −5…−25 dB, and T30 over −5…−35 dB only
   when the measured usable range actually contains that interval;
7. retains slope, R², point count, extrapolated −60 dB time, and standard
   uncertainty propagated from the regression-slope standard error;
8. compares a single line with a two-line piecewise decay using BIC. Multi-slope
   evidence is retained only for ΔBIC at least 10, meaningfully different decay
   rates, and strong early and late fits.

Noise-aware truncation prevents the numerical end of reverse integration from
being mistaken for real dynamic range. A response below 25 dB usable range is
explicitly limited; T30 requires at least 35 dB. Multiple slopes are not reduced
to a deceptively definitive single RT value. This follows the foundations of
[Schroeder integration](https://labrosa.ee.columbia.edu/~dpwe/papers/Schro65-reverb.pdf),
the intersection treatment developed by
[Lundeby et al.](https://publications.rwth-aachen.de/record/192049), and the
model-selection approach for coupled-volume decays described by
[Xiang et al.](https://pubmed.ncbi.nlm.nih.gov/21361433/).

Declared impulse responses also expose broadband C50, C80, D50, center time,
and direct-to-reverberant ratio. Octave decay views use base-10 nominal center
frequencies and store exact lower and upper edges. They are Hann-STFT research
estimates; they do not claim the verified filter-class performance of
[IEC 61260-1:2014](https://webstore.iec.ch/en/publication/5063).

## Standards boundary

For declared room impulse responses, the evidence stores the exact
[ISO 3382-1:2009](https://www.iso.org/standard/40979.html) reference and says
that the result is a research estimate, not a certified test report. ISO lists
the 2009 edition as current but under revision; freezing the edition prevents a
future standards change from silently changing old evidence.

OrgRec does not claim:

- calibrated sound-pressure level without a calibration chain;
- IEC filter-instrument conformance;
- full ISO source positions, receiver positions, repetitions, uncertainty
  budget, or reporting compliance;
- a room RT from an ordinary stopped-pipe recording; or
- causal identification of enclosure coupling from a two-slope curve alone.

## Persistence, exchange, and validation

The complete `orgrec-perceptual-spectral-summary/1` and
`orgrec-acoustic-response-analysis/1` structures are optional additions to the
take summary, so legacy projects decode unchanged. Scalar observations and
uncertainties are projected into VAO and IAD exchange while the full structures,
method statement, qualification, warnings, source analysis run, and hash-bound
take evidence remain in OrgRec capture envelopes.

Validation rejects non-finite descriptors, out-of-range ratios, inconsistent
tristimulus sums, invalid decay regressions, duplicate bands, early-energy
metrics on ordinary releases, and standard claims without qualifying response
provenance. Accepted P2 impulse-response takes must carry the qualified analysis;
low decay range remains a visible consistency warning rather than being hidden.

## Synthetic verification

Automated fixtures cover known exponential RT recovery, refusal to report T30
at inadequate dynamic range, tonal-versus-noise descriptor behavior,
tristimulus partitioning, close-frequency beating, independent spectral-
brightness modulation, BIC-supported coupled-volume decay, legacy decoding,
qualification integrity, and preservation of excitation through the P2 roadmap
compiler. They test estimator correctness and failure behavior; calibrated
field validation remains a release gate.
