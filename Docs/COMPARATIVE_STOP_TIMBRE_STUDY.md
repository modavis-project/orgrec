# Comparative stop-name and spectral study

Status: implemented protocol, version 1  
Study contract: `orgrec-comparative-stop-timbre-study/1`  
Analysis-run contract: `orgrec-comparative-stop-timbre-analysis-run/1`  
Reviewed: 2026-08-31

## Decision and software boundary

The comparative study is not a second spectral analyzer and is not part of the
field-recording UI. Signal measurement remains in `OrgRecCore`; the study
export calls the existing `TimbreRankFeatureVectorizer` and
`RankFingerprintAnalyzer`. A thin `OrgRecDatasetTool comparative-study-export`
command freezes those results and their provenance. A small independent Python
research runner performs statistics and figures from the frozen JSON contract.

This separation is intentional:

- OrgRec owns audio decoding, channel policy, spectral measurements, rank
  vectors, method versions, source hashes, and exclusions;
- the export is immutable, inspectable, and usable without the macOS app;
- the statistical analysis can evolve, be peer reviewed, or be reimplemented
  in R without silently changing the signal-processing method;
- every run records the input and script SHA-256, Git commit, package versions,
  command, random seed, and permutation counts.

The Swift layer is therefore reusable research infrastructure inside OrgRec,
while `Research/ComparativeStopTimbre` is study code. Turning the study into a
general user-facing app tool would be premature until labels, format coverage,
and independent-organ coverage are materially broader.

## Research questions and prespecified endpoints

The initial methodology tests two questions.

1. After controlling for instrument identity, are documentary stop-family
   labels associated with rank-level spectral characteristics?
2. Do conservatively normalized stop names show reproducible spectral patterns
   across independent instruments?

The three primary endpoints are fixed before analysis:

- median normalized spectral centroid (`c/f₁`);
- median Hergert weighted spectral slope in dB/octave;
- median even-to-odd harmonic-energy ratio in dB.

Medians/IQRs of partials 1–8, pitch slopes, lowest-five-partial prototype
fractions, transition candidates, PCA, and the full-feature classifier are
secondary or exploratory. The word *pattern* means a reproducible association
in the sampled corpus, not proof of stop construction, identity, maker, period,
or causal acoustical mechanism.

The export freezes the existing OrgRec descriptor domains with the study
parameters: normalized centroid 0.95…12 and slope −70…45 dB/octave. A rank
whose median lies outside either domain remains in the immutable export but is
listed in `analysis-exclusions.csv` and does not enter inference or validation.
This is a method-level eligibility rule, not post-hoc deletion of an inconvenient
observation.

## Corpus construction and identity

The source inventory distinguishes a dataset, sampled instrument, and physical
organ. Only an inventory representative described as a single real pipe organ
is admitted by default. The current exact mapping adapter follows GrandOrgue
ODF stop/rank and `REF:` semantics to the source audio. It samples pipes across
each rank, uses the existing pitch-consensus safeguards, analyzes one declared
reference channel, and records all parsing, rights, label, audio, pitch, and
minimum-observation exclusions.

The two supplied native roots were read-only throughout corpus construction:

- `/path/to/pipe-organ-datasets-a`
- `/path/to/pipe-organ-datasets-b`

They were removed after the executed study and a separate backup remains on
another machine. The exact analyzed-input acquisition lock, current download
routes, cryptographic verifier, and the distinction between an equivalent
reconstruction and a dataset variant are documented in
`Docs/VPO_DATASET_REPRODUCIBILITY.md`.

The native-file inspection quantifies all available formats. Hauptwerk,
jOrgan, SF2, Kontakt, and other packages are not made statistically equivalent
by merely finding WAV files: without reviewed definition-to-rank mapping, that
would mix releases, noises, room channels, attacks, and pipes. Each future
format adapter should emit the same retrieved-corpus contract; no change to the
study statistics is then required.

Source licences are evidence fields, not automatic permission to redistribute
audio. `--include-unreviewed-rights` is only for local analysis. Results and
feature tables must retain the rights warning, and source audio must not be
published without a separate review.

## Labels and feature construction

Documentary family is weak supervision derived by the versioned
`orgrec-organ-stop-label-rules/3`. Source label, normalized label, matched rule,
division, footage, instrument, producer, and definition hash are retained.
Labels never enter the spectral feature vector.

`orgrec-rank-timbre-features/1` makes the rank—not the individual pipe—the
primary unit. It includes medians and IQRs of centroid, slope, even/odd balance,
and partials 1–8; per-octave pitch trends for the first three measures; and
fractions of the lowest-five-partial patterns. At least three usable pipes are
required. The export additionally runs the existing pitch-dependent fingerprint
procedure so limited/applicable state, selected segment count, and transition
count remain available for exploratory rank-structure work.

Canonical stop-name normalization is deliberately conservative: case and
diacritics are folded, punctuation and letter/digit boundaries are normalized,
common leading division tokens and terminal integer footages are removed. The
source spelling is never replaced. A name is eligible for an inferential exact-
name comparison only when it occurs in at least three independent instruments;
the threshold is stored in the parameters. Otherwise its table is descriptive.

## Statistical protocol

### Family association

For every primary endpoint, the reduced ordinary least-squares model includes
an intercept, instrument fixed effects, and footage fixed effects. The full
model additionally includes documentary family. The reported effect is partial R²:

`(RSS_reduced − RSS_full) / RSS_reduced`.

Its finite-sample p-value uses the Freedman–Lane procedure: the reduced nuisance
model is fitted; its residuals are permuted *within each instrument*; the fitted
nuisance value and permuted residual are recombined; and the original family
term is tested against that null outcome. This conditions on footage without
permuting residual evidence across organs. The default is 999 permutations plus
the observed arrangement. Benjamini–Hochberg controls false discovery rate
across the three prespecified endpoints. Exact-name tests use the same procedure
on eligible lexical names, with footage and broad documentary family retained
as nuisance factors, and are a distinct family of results. The name test thus
does not merely rediscover the broader family contrast.

Fixed-effect estimates can be unidentified when an instrument contributes no
within-organ label variation; rank and residual degrees of freedom are therefore
reported. Low p-value resolution and sparse cells remain explicit limitations.

### Transport validation

A nearest-centroid classifier is a transparent predictive stress test, not the
primary inference. Each fold withholds every rank from one instrument. Robust
centering/scaling, family centroids, and a descriptive 95th-percentile
centroid-distance abstention threshold use training instruments only. The
report retains accuracy, macro-F1, confusion, accepted coverage/accuracy, and a
within-instrument label-permutation p-value. The three-endpoint model is
prespecified; the all-feature model is secondary and may overfit small corpora.

The export also freezes deterministic development/calibration/test roles for
future model development. The current methodology uses leave-one-instrument-out
evaluation to make maximum use of a small number of organs; it never uses a
pipe-level random split.

### Descriptive structure

PCA uses all rank features after median/IQR scaling and is exported with scores,
loadings, and explained variance. It is visualization only. Multiple ranks from
one organ are not independent points, so apparent clusters are not p-values.

## Reproduction

If source-level feature extraction must be repeated, first restore or download
and verify the ten analysis-contributing VPO packages as described in
`Docs/VPO_DATASET_REPRODUCIBILITY.md`. The statistical analysis alone can be
rerun from the frozen comparative corpus without source audio.

From the repository root:

```sh
swift run -c release OrgRecDatasetTool native-corpus-inspect \
  Artifacts/ComparativeStopTimbre/native-corpus-inspection.json \
  /path/to/pipe-organ-datasets-a \
  /path/to/pipe-organ-datasets-b \
  --wav-smpl-limit 2000

swift run -c release OrgRecDatasetTool retrieved-corpus-build \
  /path/to/downloaded_instrument_inventory.csv \
  /path/to/source_catalog.csv \
  Artifacts/ComparativeStopTimbre/retrieved-local-research-corpus.json \
  --include-unreviewed-rights --max-pipes 9 --min-pipes 3

swift run -c release OrgRecDatasetTool comparative-study-export \
  Artifacts/ComparativeStopTimbre/retrieved-local-research-corpus.json \
  Artifacts/ComparativeStopTimbre/Study

python3 Research/ComparativeStopTimbre/audit_sources.py \
  /path/to/downloaded_instrument_inventory.csv \
  Artifacts/ComparativeStopTimbre/native-corpus-inspection.json \
  Artifacts/ComparativeStopTimbre/Audit \
  --catalog /path/to/source_catalog.csv \
  --root /path/to/pipe-organ-datasets-a \
  --root /path/to/pipe-organ-datasets-b

python3 Research/ComparativeStopTimbre/analyze.py \
  Artifacts/ComparativeStopTimbre/Study/comparative-corpus.json \
  Artifacts/ComparativeStopTimbre/Results
```

Python dependencies are deliberately small: Python 3.11 or later, NumPy, and
Matplotlib. CSV outputs use invariant decimal formatting. JSON inputs and
outputs are versioned. Reruns with unchanged inputs, environment, and seed are
numerically deterministic; timestamps and absolute paths are documentary
exceptions.

## Extension path

The most valuable next work is format coverage, not a more complex classifier:

1. implement and fixture-test exact Hauptwerk organ-definition mapping;
2. add jOrgan/SF2/Kontakt adapters only where rank, pitch, channel, and release
   semantics can be established;
3. freeze an expert-reviewed label adjudication table without overwriting the
   documentary labels;
4. add instrument-level metadata (organ builder, period, country, action,
   windchest and pipe construction) and use hierarchical models only when the
   number of independent organs supports them;
5. preregister any confirmatory follow-up and reserve newly added instruments
   as a genuinely untouched external test cohort.

## Scientific references

- F. Hergert and N. Höper, “Envelope Functions for Sound Spectra of Pipe Organ
  Ranks and the Influence of Pitch on Tonal Timbre,” *Proceedings of Meetings
  on Acoustics* 49, 035012 (2022).
  [doi:10.1121/2.0001673](https://doi.org/10.1121/2.0001673)
- G. Peeters, B. L. Giordano, P. Susini, N. Misdariis, and S. McAdams, “The
  Timbre Toolbox,” *JASA* 130(5), 2902–2916 (2011).
  [doi:10.1121/1.3642604](https://doi.org/10.1121/1.3642604)
- G. Schwarz, “Estimating the Dimension of a Model,” *Annals of Statistics*
  6(2), 461–464 (1978).
  [doi:10.1214/aos/1176344136](https://doi.org/10.1214/aos/1176344136)
- Y. Benjamini and Y. Hochberg, “Controlling the False Discovery Rate,”
  *Journal of the Royal Statistical Society B* 57(1), 289–300 (1995).
  [doi:10.1111/j.2517-6161.1995.tb02031.x](https://doi.org/10.1111/j.2517-6161.1995.tb02031.x)
- D. A. Freedman and D. Lane, “A Nonstochastic Interpretation of Reported
  Significance Levels,” *Journal of Business & Economic Statistics* 1(4),
  292–298 (1983).
  [doi:10.1080/07350015.1983.10509354](https://doi.org/10.1080/07350015.1983.10509354)
- C. Guo, G. Pleiss, Y. Sun, and K. Q. Weinberger, “On Calibration of Modern
  Neural Networks,” *PMLR* 70, 1321–1330 (2017).
  [official record](https://proceedings.mlr.press/v70/guo17a.html)
