# Acoustic temperament suggestions

The method's provenance classification and cross-subsystem limitations are in
the [scientific-method register](SCIENTIFIC_METHODS.md).

OrgRec can compare a recorded chromatic rank with the temperament vectors in
the MODAVIS Navigator catalogue. The result is explicitly a ranked acoustic
hypothesis. It does not modify the organ's documented temperament and does not
create a canonical MODAVIS assertion.

## App workflow

Open **Analysis → Temperament suggestion**. Select a recorded unison 8′ rank
and choose **Analyze nearest temperament**. OrgRec:

1. retrieves all pages of `GET /api/temperaments?mode=surface`, or uses the
   project's frozen cache when Navigator is temporarily unavailable;
2. selects one best usable take for each MIDI note in the rank;
3. runs normal OrgRec frequency analysis for takes without an estimate;
4. uses the accepted session A4, or measures the selected rank's A4 recording;
5. groups reliable measurements by pitch class and calculates a robust median,
   dispersion, confidence, octave coverage, and take provenance;
6. compares the resulting pitch-class shape with every usable MODAVIS/BDO cent
   vector; and
7. stores and displays the ten nearest candidates with direct Navigator links.

The complete report and catalogue snapshot remain in `project.json`.
`manifests/temperament-analyses.jsonl` makes reports discoverable in IAD export.

## Comparison method

For a measured frequency `f`, key MIDI number `m`, accepted A4 `a`, and stop
foot length `L`, the equal-temperament sounding expectation is:

```text
expected = a × 2^((m − 69)/12) × 8/L
residual cents = 1200 × log2(f/expected)
```

Samples below 0.35 estimator confidence or more than 150 cents from their
expected note are excluded. Repeated octaves are represented by the median;
median absolute deviation records within-class disagreement. The observed A
residual is removed so global pitch cannot masquerade as temperament shape.

MODAVIS `toneOrder` and `centValues` are paired by tone name. OrgRec recognizes
English accidentals and BDO/German forms including `Cis`, `Des`, `Es`, `Fis`,
`As`, `B`, and `H`. A fitted constant aligns each catalogue vector without
rotating its named pitch classes. Rotation would allow musically false matches
and is intentionally not performed.

Candidates with fewer than eight comparable classes are excluded. Ranking uses
a robust RMSE in which individual errors are capped at 20 cents, plus median
and maximum absolute error. The runner-up margin records how uniquely the best
vector fits.

## Evidence labels

- **Insufficient:** fewer than eight observed pitch classes or no comparable
  catalogue vector.
- **Tentative:** incomplete chromatic coverage, weighted RMSE above 12 cents,
  less than 1 cent separation from the runner-up, dispersion above 10 cents, or
  mean estimator confidence below 0.55.
- **Suggestive:** all pitch classes are present and the result clears the
  tentative conditions.
- **Strong:** all 12 classes, at least 24 measurements, weighted RMSE at most 5
  cents, at least a 2.5-cent runner-up margin, dispersion at most 5 cents, mean
  confidence at least 0.70, and at least 80% leave-one-class-out support.

Even “Strong” means strong evidence for the nearest catalogue vector, not proof
of historical identity. Rank regulation, pipe condition, temperature, stretch,
voicing, and later tuning work can produce a similar pattern. Compare at least
two stable ranks and review documentary evidence before drawing a curatorial
conclusion.

## PositivXR

The complete Cuntz Positiv dataset contains sufficient chromatic coverage. The
earlier 15-file stratified analysis contains mainly C and D and is insufficient
by design. Select **Gedackt 8′** to analyze its complete recorded compass, then
repeat with **Regal 8′** as a cross-rank sensitivity check. A disagreement
between the two reports is evidence of rank regulation or measurement effects,
not a reason to choose whichever catalogue result is preferred.

## Uncertainty-weighted inference

Analysis v2 retains every usable take for a MIDI note instead of selecting only
one winner. A sample weight combines its estimator confidence with pitch-track
uncertainty or MAD. Candidate ranking uses an uncertainty-weighted robust RMSE;
the unweighted capped RMSE remains in the report for compatibility.

Evidence strength now also depends on within-class dispersion, mean estimator
confidence, and leave-one-pitch-class-out stability. A nominally close fit
cannot be `Strong` when replicated measurements disagree or the leading
candidate changes after omitting one class. The report additionally records
octave stretch, take-level outliers, improvement over an equal-temperament
catalogue entry when present, and sensitivity support.

OrgRec derives a cross-rank consensus whenever usable reports exist. It counts
independent rank support, averages weighted fit error, and reports rank
agreement. One rank remains explicitly insufficient for cross-rank validation;
rank disagreement is preserved rather than resolved by choosing the preferred
candidate.

## Method provenance

The frequency/cents coordinate is conventional and MIDI key 69 is treated as
A4 according to the [MIDI 1.0 Detailed
Specification](https://midi.org/midi-1-0-detailed-specification). The
catalogue vectors and tone names are MODAVIS/BDO data whose retrieved snapshot
is retained with the report. The named-class alignment, robust aggregation,
uncertainty weighting, capped error, evidence thresholds, leave-one-class-out
support, and cross-rank consensus are an OrgRec synthesis rather than a named
published temperament-identification algorithm. Consequently the result is a
reproducible nearest-vector acoustic hypothesis, not evidence of historical
authenticity or attribution.
