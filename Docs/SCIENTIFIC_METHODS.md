# Scientific and published-method register

Status: authoritative provenance companion for the OrgRec implementation  
Reviewed: 2026-08-31  
Scope: signal analysis, acoustics, statistics, organological inference, and
measurement-affecting standards

## Purpose and claim language

This register states what OrgRec actually calculates, which parts have a
published or normative basis, which parts are OrgRec engineering choices, and
which conclusions the result does **not** support. It is the source-of-truth
index for methodology claims in the subsystem guides and exported method
versions.

The following words are deliberate:

- **implements** means the cited computation is reproduced closely enough for
  its name to identify the algorithm;
- **adapts** means a published method supplies the mathematical structure, but
  the signal representation, gates, or operating domain are changed and are
  stated here;
- **informed by** means the source motivates a descriptor or validation
  principle, not that OrgRec reproduces the complete published experiment;
- **OrgRec synthesis** means the combination, score, threshold, or inference is
  original application engineering and must be evaluated on OrgRec's tests and
  field evidence;
- **references a standard** means the edition guides terminology or a metric.
  It does not mean that OrgRec, its audio interface, or a recording session is
  certified or fully conformant.

No catalogue match, statistical boundary, acoustic similarity, or classifier
output is proof of pipe construction, stop identity, maker, date, historical
temperament, fault, common physical source, or causal mechanism. Such claims
require documentary and/or physical evidence beyond the recording.

## Reproducible comparative-study package

The comparative VPO stop-timbre implementation is indexed separately so it can
be located and cited without searching the application source tree:

- complete scientific protocol: `Docs/COMPARATIVE_STOP_TIMBRE_STUDY.md`;
- data acquisition/equivalence protocol: `Docs/VPO_DATASET_REPRODUCIBILITY.md`;
- command discovery: `python3 Tools/vpo_reproduce.py --help`; and
- frozen and independently rebuilt evidence:
  `Artifacts/ComparativeStopTimbre/`.

The package separates software, source-dataset and derived-result citations.
Passing raw-byte, feature-corpus and result gates establishes reproducibility of
the defined analyzed subset; it does not erase the causal and external-validity
limitations stated in this register.

## Method register

### Pitch, time-frequency, and event analysis

| Stored method or contract | Exact implementation and external basis | OrgRec adaptation and non-claim | Verification |
| --- | --- | --- | --- |
| `orgrec-analysis/5` (previously `orgrec-analysis/4`) with a CREPE model identifier | CREPE supplies framewise monophonic pitch evidence from 16 kHz audio. Kim et al. (2018) describe the model. Hann/Blackman–Harris STFTs, spectral flux, harmonic searches, and parabolic peak interpolation supply independent spectral evidence. | AVAudioConverter resampling, reference-channel selection, 25-cent fusion, 50-cent critical-disagreement gate, confidence policy, transient state machine, window sizes, and censoring policy are OrgRec synthesis. The app does not retrain CREPE or claim polyphonic pitch tracking. | Pitch, estimator-disagreement, transient-censoring, partial-tracking, and spectral fixtures. |
| `orgrec-spectrum-segmentation/2` | Release-bounded sustain selection, disjoint harmonic bin ownership, Hann main-lobe power integration for LTAS, and observed-quiet-region noise gating for partial tracks. | Midpoint ownership, minimum two-bin harmonic spacing, 100/120 ms release guards, provisional missing-boundary regions, five-bin LTAS power sums, and a fixed 2,048-frame extraction cap independent of display bins are OrgRec synthesis. These remain descriptive uncalibrated spectra; unresolved or silent partitions are absent. | Short-sustain/tail exclusion, bin ownership, known harmonic power across FFT-bin phases, continuous tone retention, display independence, low-rate timestamps, and silence tests in `SpectrumSegmentationTests`. |
| `orgrec-pyin/1` | Implements the two-stage pYIN structure: YIN difference/CMNDF trough candidates integrated over a beta threshold prior, followed by voiced/unvoiced Viterbi decoding. Basis: de Cheveigné & Kawahara (2002); Mauch & Dixon (2014). | Candidate grids, priors, transition costs, confidence conversion, expected-note bounds, and finite-frame guards are frozen OrgRec parameters. It is an independent estimator, not a claim of byte-for-byte equivalence with another pYIN library. | Synthetic tones, octave-confusion cases, voicing, continuity, silence, and consensus tests. |
| `orgrec-autocorrelation/2` | Normalized autocorrelation provides a conventional periodicity estimate and third-view adjudicator. | Lag range, peak interpolation, confidence scaling, and fallback eligibility are OrgRec choices. It is not presented as a learned or perceptually complete estimator. | Tone, silence, expected-range, and estimator-disagreement tests. |
| `orgrec-organ-long-take/3` (`orgrec.long-take-analysis/v2`) | Streaming adaptive onset detection, local-baseline harmonic evidence, exact source-frame refinement, frequency-local release detection, and joint sequence decoding. It is informed by Bello et al. (2005), Verge et al. (1994), Hruška (2020), YIN/pYIN, Schroeder decay analysis, and Rabiner's dynamic-programming formulation. | The organ-specific windows, six-harmonic evidence, 10 ms export lead, release gates, penalties, retake/missing-event state model, and roadmap assignment are OrgRec synthesis. It is not a reproduction of one published segmentation algorithm. | Synthetic and fixture long takes, low-pipe/upperwork attacks, retakes, omissions, unrelated events, right-censoring, and imported-master equivalence. |
| `orgrec-loop-detector/1` | Stable-sustain search uses the pitch, harmonic, stationarity, and modulation evidence above, followed by coarse and source-frame seam refinement. Equal-power overlap is used for audition playback. | The combined waveform/derivative, harmonic magnitude/phase, level, pitch/cycle, stationarity, multichannel, and repetition score—and all weights, candidate rules, confidence mapping, and crossfade policy—are OrgRec synthesis. It is not represented as a reproduction of a named published loop detector or as a perceptual inaudibility probability. | Synthetic stable-tone proposals, exact half-open bounds, score components, multichannel behavior, review revisions, playback contract, persistence, and VAO/IAD validation. |

### Stable spectrum, timbre, and rank structure

| Stored method or contract | Exact implementation and external basis | OrgRec adaptation and non-claim | Verification |
| --- | --- | --- | --- |
| `orgrec-perceptual-spectral-summary/1` | Hann STFT descriptors include spectral moments, flatness, entropy, crest, flux, harmonic regions, harmonic slope/residual, tristimulus, a 32-band triangular ERB-rate summary, and independent envelope/ERB-centroid modulation scans. Descriptor selection is informed by Peeters et al. (2011) and the perceptual evaluation of Kazazis et al. (2021). | FFT selection, 600-frame/30-second caps, ERB triangles, harmonic-region widths, robust modulation depth, scan range, and confidence are OrgRec synthesis. ERB bands are not a loudness, masking, or calibrated auditory excitation model. | Tonal-versus-noise, tristimulus, beating, brightness modulation, bounds, legacy decoding, and finite-value tests. |
| `orgrec-harmonic-ltas/2` (previously `orgrec-harmonic-ltas/1`; contract `orgrec-timbre-analysis/2`) | Stable-sustain long-term averaged harmonic power, normalized spectral centroid, weighted adjacent-harmonic slope, even/odd balance, and lowest-partial pattern descriptors adapt the organ-pipe analyses of Hergert and collaborators (2023–2024). | OrgRec uses a reference channel, 48 kHz conversion, pitch-adaptive FFT, local-noise detection, harmonics 1–20, and an explicit plot-consistent slope sign. The family-profile centers and applicability bounds are engineering parameters, not values fitted or published by those papers. | Analytic slope, harmonic-pattern, partial-threshold, applicability, rank aggregation, serialization, and source-fixity tests. |
| `orgrec-empirical-hierarchical-timbre-model/1` | Class-balanced multinomial logistic nodes are trained with instrument-grouped partitions. Held-out temperature scaling follows the calibration method evaluated by Guo et al. (2017). Accuracy, macro-F1, log loss, Brier score, ECE, confusion matrices, and coverage are retained. | Documentary names are versioned weak labels. Hierarchy, features, split seed, empirical centroid-distance OOD envelope, finite-sample acceptance quantile, threshold, and abstention policy are OrgRec design. The finite-sample quantile is a validation heuristic, **not** a conformal prediction coverage guarantee. | Corpus provenance/exclusion, group-disjoint split, deterministic training, calibration, abstention, OOD, artifact decoding, and untouched-test metrics. |
| `orgrec-multivariate-segmented-rank-trajectory/1` | Median/MAD standardization and continuous piecewise-linear alternatives are compared using Schwarz's BIC. A deterministic residual-permutation maximum search screens all eligible boundaries; resampling-based multiple-testing principles are discussed by Westfall & Young (1993). | Features, segment constraints, gap rule, ΔBIC ≥ 10, 199 permutations, fixed seed, maximum-statistic p-value, and effect-strength labels are OrgRec synthesis. The procedure is not the exact Westfall–Young step-down algorithm and a boundary has no automatic organological cause. | Null/known-boundary synthetic trajectories, determinism, gap and sample-size refusal, serialization, and report interpretation tests. |
| `orgrec-comparative-stop-timbre-study/1` with `orgrec-comparative-stop-timbre-analysis-run/1` | Existing rank features are compared with instrument and footage fixed effects; lexical-name tests additionally adjust for documentary family. Family/name effect is partial R² and its finite-sample p-value uses Freedman–Lane reduced-model residual permutations restricted within instruments. Benjamini–Hochberg adjusts each set of three endpoints. Predictive stress testing leaves one complete instrument out. | Documentary names supply weak labels, not expert ground truth. Canonical-name rules, three-instrument eligibility, rank vector, frozen descriptor domains, robust scaling, nearest-centroid classifier, 95th-percentile training-distance abstention, seeds, and permutation counts are OrgRec study choices. VPO processing and organ identity remain confounded; association is not causal construction evidence or universal recognition accuracy. | Contract/provenance, deterministic group split, source/label retention, feature-schema reuse, CSV export, synthetic grouped-association, permutation, domain exclusion, and no-leakage checks. |

### Decay, room response, and spatial/effect evidence

| Stored method or contract | Exact implementation and external basis | OrgRec adaptation and non-claim | Verification |
| --- | --- | --- | --- |
| `orgrec-acoustic-response-analysis/1` | Tail-DC removal, robust stationary-noise estimation, decay/noise intersection, noise-power subtraction, Schroeder reverse integration, EDT/T20/T30 regression, slope uncertainty, and one- versus two-slope BIC comparison. Basis: Schroeder (1965), Lundeby et al. (1995), and Xiang et al. (2011). Declared impulse responses additionally expose C50, C80, D50, center time, and direct/reverberant energy. | Origin detection, fit guards, minimum dynamic ranges, tail selection, ΔBIC and slope-separation gates are OrgRec parameters. ISO 3382-1:2009 is recorded only for a declared impulsive-source or deconvolved impulse response. A pipe-plus-room release never receives room-clarity metrics or an ISO reference. | Known exponential RT, insufficient-range refusal, coupled-decay selection, qualification integrity, uncertainty, and P2 provenance tests. |
| `orgrec.effect-analysis/v1` | Peak/RMS, onset and latency, effective impulse width, spectral-band energy, envelope autocorrelation periodicity, and normalized Shannon entropy are descriptive response features. Shannon (1948) supplies the information-entropy definition. | Onset gates, response windows, entropy normalization, repetition confidence, and interpretation labels are OrgRec synthesis. A descriptive periodicity or stochasticity score does not identify a mechanical cause. | Deterministic pulse/repetition/noise fixtures, stage timing, missing-evidence behavior, persistence, and export tests. |
| `orgrec.spatial-acoustic-observation/v1` | Spatial P2 observations bind source/receiver geometry, excitation provenance, response analysis, and state comparisons. Qualified response metrics delegate to `orgrec-acoustic-response-analysis/1`. | One-shot octave/third-octave estimates are spectral integrations. They do not meet IEC 61260-1:2014 filter-class verification. Geometry and state differences are evidence at the recorded positions, not a complete sound-field model. | Geometry integrity, excitation eligibility, state comparison, response binding, roadmap compilation, and legacy-decoding tests. |

### Collection statistics and historical hypotheses

| Stored method or contract | Exact implementation and external basis | OrgRec adaptation and non-claim | Verification |
| --- | --- | --- | --- |
| `orgrec-collection-analysis/2` | Per-key robust median/MAD, bounded inverse-variance quality weighting, weighted quantiles, effective sample size `(Σw)²/Σw²`, Siegel repeated-median rank slope, within-target session slopes, robust normalized feature distances, and harmonic-number-aligned cosine similarity. Siegel (1982) is the direct slope source; Kish (1965) is the conventional effective-sample-size reference. | Quality formula, weight clipping, variance floors, gates, anomaly scales, candidate thresholds, and ranking/caps are OrgRec synthesis. Pairwise-slope bounds are observed bounds, not population confidence intervals. Anomaly and similarity outputs are review candidates, never identity or defect findings. | Evidence-ledger reconciliation, exclusions, sparse/refusal states, repeated-median robustness, confounding guards, deterministic candidate ordering, and stale-fingerprint tests. |
| `orgrec.temperament-analysis/v1` and `orgrec.temperament-consensus/v1` | Frequency is expressed as cents relative to the accepted A4, MIDI key, and footage; pitch-class medians/MADs are aligned to named MODAVIS/BDO catalogue vectors by a constant offset. | Confidence ≥ .35, ±150-cent admission, removal of the measured A-class offset, capped 20-cent error, eight-class minimum, uncertainty weights, evidence labels, leave-one-class-out support, and consensus gates are OrgRec synthesis. Named classes are never rotated. A result ranks acoustic similarity to catalogue vectors; it is not historical temperament identification or evidence that a catalogue entry caused the observed tuning. | Accidental-name parsing, A4/footage relation, robust aggregation, no-rotation matching, uncertainty weighting, leave-one-class-out stability, insufficient coverage, cache provenance, consensus, and serialization tests. |

### Capture-chain, mechanisms, and operational baselines

| Stored method or contract | Exact implementation and external basis | OrgRec adaptation and non-claim | Verification |
| --- | --- | --- | --- |
| `orgrec.signal-path-rehearsal/v1` | Per-channel peak, RMS, DC, clipping, SNR/headroom estimates, Pearson correlation, fitted polarity/gain, and residual energy detect routing hazards and probable duplicate digital feeds. | All rehearsal gates—including correlation ≥ .999999 and fitted residual ≤ −60 dB for duplicate-feed suspicion—are OrgRec risk controls, not calibration-standard limits. Uncalibrated values are dBFS and cannot establish SPL, self-noise, or standards compliance. | Silence, clipping, DC, low headroom/SNR, correlated duplicate, legitimate stereo, persistence, and preflight blocking tests. |
| `orgrec.interaction-sensor-calibration/v1-experimental` and related `v1-experimental` contracts | A constrained mechanism's hinge axis is estimated from centered accelerometer covariance by power-iteration PCA; gyro bias is removed and angular rate integrated; signed gravity angle provides a second observable; affine ordinary-least-squares clock mapping aligns device and host time; OLS relates motion features to MIDI velocity. | Axis sign anchoring, confidence, clock and MIDI RMSE gates, CRC packet format, smoothing, event thresholds, and validation grades are provisional OrgRec engineering. This is constrained-mechanism processing, not general 3-D pose tracking; it does not implement a Kalman or complementary filter, remove USB scheduling uncertainty, or measure acoustic latency by itself. | Packet/CRC, calibration, sign, clock fit, synthetic motion, MIDI regression, validation gates, persistence, and opt-in workflow tests. |
| `orgrec.actuator-response-function/v1` and `orgrec.tremulant-response-analysis/v1` | Ordinary least-squares slope/intercept/R² summarize repeated actuator input-response evidence; tremulant analysis reuses independently derived amplitude and frequency/spectral modulation tracks. | Minimum observations, operating ranges, confidence labels, and interpretation are OrgRec choices. Association is not a physical transfer-function identification or causal diagnosis. | Linear synthetic responses, insufficient variation, tremulant assignment, persistence, and validation tests. |
| `orgrec.operational-baseline-analysis/v1` | Streaming peak/RMS, crest factor, sample-level L10/L50/L90, 100 ms variability/stationarity, and FFT octave-band energy summarize a frozen operating state. | Values are uncalibrated dBFS. L10/L50/L90 are sample-amplitude distribution descriptors—not environmental-noise levels, sound-exposure statistics, or ISO 1996-2:2017 compliance—and FFT bands are not IEC 61260 filter measurements. Denoising is forbidden for preservation baselines. | Quantiles, stationarity, band ordering, minimum duration, state binding, persistence, and export tests. |

### Tuning and archival carriers

| Stored method or contract | Exact implementation and external basis | OrgRec adaptation and non-claim | Verification |
| --- | --- | --- | --- |
| `orgrec.documented-pitch/v1`, `orgrec.tuning-calibration/v1`, `orgrec.live-pitch-evidence/v1` | MIDI key 69 is A4 and twelve-tone equal-tempered frequency is `A4 × 2^((m−69)/12)`; cents are `1200 log₂(f₂/f₁)`. The accepted project A4 and its documentary or measured provenance are preserved. | Footage scaling, acceptance workflow, uncertainty/confidence fields, and cross-evidence conflict gates are OrgRec contracts. Equal-tempered frequency is a measurement coordinate, not an assertion that the organ is equally tempered. | Formula, cents, A4 bounds, source provenance, calibration conflict, and serialization tests. |
| BWF and exchange carriers | WAVE output uses a Broadcast Wave `bext` chunk based on EBU Tech 3285 v2. SOFA references identify AES69-2022/SOFA 2.1 carrier expectations where applicable. | Carrier metadata does not validate microphone geometry, acoustic calibration, or the truth of an analysis. OrgRec's private VAO/MODAVIS projections remain separate from standards conformance. | Chunk parsing, time reference, metadata/fixity, package round trips, and validators. |

## Standards boundary

OrgRec currently records or cites the following exact editions:

- ISO 3382-1:2009 for room-acoustic parameters in performance spaces;
- ISO 3382-2:2008 where ordinary-room reverberation terminology is discussed;
- IEC 61260-1:2014 for octave/third-octave filter requirements that OrgRec's
  FFT integrations explicitly do not claim to meet;
- ISO 1996-2:2017 only to distinguish OrgRec's uncalibrated operational
  descriptors from environmental sound-level determination;
- EBU Tech 3285 v2 (2011) for Broadcast Wave metadata;
- AES69-2022, SOFA 2.1, when SOFA carrier semantics are referenced; and
- MIDI 1.0 Detailed Specification, 1996 revision 4.2.1, for MIDI note/event
  semantics.

Certification additionally requires suitable calibrated instrumentation,
field procedure, positions/repetitions, traceability, uncertainty budgets, and
the standard's complete reporting rules. Software output alone cannot supply
those conditions.

## Primary bibliography

1. J. W. Kim, J. Salamon, P. Li, and J. P. Bello, “CREPE: A Convolutional
   Representation for Pitch Estimation,” *Proc. ICASSP*, 2018, pp. 161–165.
   DOI: [10.1109/ICASSP.2018.8461329](https://doi.org/10.1109/ICASSP.2018.8461329).
2. A. de Cheveigné and H. Kawahara, “YIN, a fundamental frequency estimator
   for speech and music,” *JASA* 111(4), 2002, pp. 1917–1930. DOI:
   [10.1121/1.1458024](https://doi.org/10.1121/1.1458024).
3. M. Mauch and S. Dixon, “pYIN: A fundamental frequency estimator using
   probabilistic threshold distributions,” *Proc. ICASSP*, 2014. DOI:
   [10.1109/ICASSP.2014.6853678](https://doi.org/10.1109/ICASSP.2014.6853678).
4. J. P. Bello et al., “A tutorial on onset detection in music signals,”
   *IEEE TASLP* 13(5), 2005. DOI:
   [10.1109/TSA.2005.851998](https://doi.org/10.1109/TSA.2005.851998).
5. M.-P. Verge et al., “Transient behaviour of an organ flue pipe,” *JASA*
   95(2), 1994. DOI: [10.1121/1.408460](https://doi.org/10.1121/1.408460).
6. V. Hruška, “On the transient response of organ pipes,” *Archives of
   Acoustics* 45, 2020. DOI:
   [10.24425/aoa.2020.134054](https://doi.org/10.24425/aoa.2020.134054).
7. L. R. Rabiner, “A tutorial on hidden Markov models and selected applications
   in speech recognition,” *Proceedings of the IEEE* 77(2), 1989. DOI:
   [10.1109/5.18626](https://doi.org/10.1109/5.18626).
8. G. Peeters et al., “The Timbre Toolbox: extracting audio descriptors from
   musical signals,” *JASA* 130(5), 2011. DOI:
   [10.1121/1.3642604](https://doi.org/10.1121/1.3642604).
9. S. Kazazis, P. Depalle, and S. McAdams, “Ordinal scaling of timbre-related
   spectral audio descriptors,” *JASA* 149(6), 2021, pp. 3785–3796. DOI:
   [10.1121/10.0005058](https://doi.org/10.1121/10.0005058).
10. F. Hergert and N. Höper, “Envelope Functions for Sound Spectra of Pipe
    Organ Ranks and the Influence of Pitch on Tonal Timbre,” 2023. DOI:
    [10.1121/2.0001673](https://doi.org/10.1121/2.0001673).
11. F. Hergert and M. Haverkamp, “Tonal Timbre Variations of Historical
    Recorders and Transverse Flutes Compared to Pipe Organ Ranks,” *Forum
    Acusticum*, 2023. DOI:
    [10.61782/fa.2023.0327](https://doi.org/10.61782/fa.2023.0327).
12. L. Hergert et al., related organ-timbre studies, DOI:
    [10.1121/2.0001671](https://doi.org/10.1121/2.0001671),
    [10.1121/2.0001672](https://doi.org/10.1121/2.0001672), and
    [10.1051/aacus/2024020](https://doi.org/10.1051/aacus/2024020).
13. C. Guo, G. Pleiss, Y. Sun, and K. Q. Weinberger, “On Calibration of Modern
    Neural Networks,” *PMLR* 70, 2017, pp. 1321–1330.
    [Official record](https://proceedings.mlr.press/v70/guo17a.html).
14. G. Schwarz, “Estimating the Dimension of a Model,” *The Annals of
    Statistics* 6(2), 1978, pp. 461–464. DOI:
    [10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136).
15. P. H. Westfall and S. S. Young, *Resampling-Based Multiple Testing*, Wiley,
    1993, ISBN 978-0-471-55761-6.
16. M. R. Schroeder, “New Method of Measuring Reverberation Time,” *JASA*
    37(6), 1965. DOI: [10.1121/1.1909343](https://doi.org/10.1121/1.1909343).
17. A. Lundeby et al., “Uncertainties of Measurements in Room Acoustics,”
    *Acustica* 81, 1995, pp. 344–355.
    [Publication record](https://publications.rwth-aachen.de/record/192049).
18. N. Xiang, P. Goggans, T. Jasa, and P. Robinson, “Bayesian characterization
    of multiple-slope sound energy decays in coupled-volume systems,” *JASA*
    129(2), 2011, pp. 741–752. DOI:
    [10.1121/1.3518773](https://doi.org/10.1121/1.3518773).
19. A. F. Siegel, “Robust regression using repeated medians,” *Biometrika*
    69(1), 1982, pp. 242–244. DOI:
    [10.1093/biomet/69.1.242](https://doi.org/10.1093/biomet/69.1.242).
20. L. Kish, *Survey Sampling*, Wiley, 1965, 643 pp.
21. C. E. Shannon, “A Mathematical Theory of Communication,” *Bell System
    Technical Journal* 27, 1948. DOI:
    [10.1002/j.1538-7305.1948.tb01338.x](https://doi.org/10.1002/j.1538-7305.1948.tb01338.x)
    and [10.1002/j.1538-7305.1948.tb00917.x](https://doi.org/10.1002/j.1538-7305.1948.tb00917.x).
22. D. A. Freedman and D. Lane, “A Nonstochastic Interpretation of Reported
    Significance Levels,” *Journal of Business & Economic Statistics* 1(4),
    1983, pp. 292–298. DOI:
    [10.1080/07350015.1983.10509354](https://doi.org/10.1080/07350015.1983.10509354).

Normative edition records: [ISO 3382-1:2009](https://www.iso.org/standard/40979.html),
[ISO 3382-2:2008](https://www.iso.org/standard/36201.html),
[IEC 61260-1:2014](https://webstore.iec.ch/en/publication/5063),
[ISO 1996-2:2017](https://www.iso.org/standard/59766.html),
[EBU Tech 3285 v2](https://tech.ebu.ch/publications/tech3285),
[AES69-2022](https://www.aes.org/publications/standards/preview.cfm?ID=99), and
[MIDI 1.0 Detailed Specification](https://midi.org/midi-1-0-detailed-specification).

## Maintenance rule

Any change that adds or materially changes a scientific descriptor, estimator,
statistical test, classifier, standards reference, inference threshold, or
organological interpretation must update this register in the same change. It
must identify the stored method version, exact adaptation, application limits,
and verification. Published inspiration cannot substitute for validation of
the implemented code, and a changed material method must receive a changed
version or an explicitly documented backward-compatible contract revision.
