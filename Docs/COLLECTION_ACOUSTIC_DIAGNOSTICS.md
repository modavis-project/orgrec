# Evidence-qualified collection acoustic diagnostics

Status: implementation and interpretation guidance for private VAO 0.2.2  
Normative contract: [`VAO_STANDARD.md` section 6.2.1](VAO_STANDARD.md#621-collection-acoustic-diagnostics)  
Scientific provenance: [method register](SCIENTIFIC_METHODS.md)

## Purpose

Collection analysis is useful only when its aggregates remain traceable to the
quality and comparability of the underlying takes. A smooth rank curve can hide
excluded recordings, a session trend can be confounded by different notes, and
a high spectral similarity can be mistaken for proof that two recordings came
from one physical source. The VAO 0.2.2 collection contract prevents those
shortcuts.

The optional capability is:

```text
https://w3id.org/modavis/vao/vocab/capability/collection-acoustic-diagnostics
```

It is evidence-qualified because a conforming result carries the assessed take
ledger and coverage alongside its rank/session aggregates and review
candidates. It is collection-level because the result compares observations
within declared groups; it does not merge the identities of the things being
compared.

This guide explains one sound processing pattern. The exact machine contract is
normative in `VAO_STANDARD.md`; method choices described here with SHOULD or MAY
remain recommendations.

## Patch-safe VAO representation

VAO 0.2.2 does not add a closed JSON member. It specializes existing IRI-valued
and open-value fields:

| Purpose | Exact identifier |
| --- | --- |
| capability | `https://w3id.org/modavis/vao/vocab/capability/collection-acoustic-diagnostics` |
| required dependency | `https://w3id.org/modavis/vao/vocab/capability/acoustical-analysis` |
| analysis type | `https://w3id.org/modavis/vao/vocab/analysis/evidence-qualified-collection-acoustic-diagnostics` |
| OrgRec reference activity type | `https://w3id.org/modavis/vao/vocab/activity/CollectionAcousticDiagnostics` |
| research profile | `https://w3id.org/modavis/vao/profile/research/0.2` |

The analysis has exactly eight governed observation properties below
`https://w3id.org/modavis/vao/vocab/analysis/collection/`:

1. `evidence-summary`;
2. `take-evidence`;
3. `rank-tuning-curves`;
4. `rank-stretch`;
5. `session-offset`;
6. `session-drift`;
7. `acoustic-anomaly-candidates`;
8. `acoustic-similarity-candidates`.

The first is an object and the other seven are arrays. Empty arrays remain
explicit results: they do not mean the observation was forgotten. A 0.2.x
reader that does not implement the capability can preserve the analysis using
the ordinary manifest model and report the required capability as unsupported.

## Evidence gate before aggregation

Start from every eligible pitched take, not only the takes that happen to have a
usable final estimate. Give every take exactly one ledger entry. A practical
quality score can combine, with documented weights:

- pitch confidence and voiced coverage;
- agreement between independent pitch estimators;
- signal-to-noise and clipping checks;
- usable partial or feature evidence;
- review/finalization state; and
- inherited analysis quality flags.

Hard exclusions should precede threshold tiers. Missing or non-finite pitch,
non-monophonic applicability, critical estimator disagreement, rejected/failed
takes, and unfinished capture state are examples. Exclusion never deletes the
ledger entry. Retain its reason, quality score, flags, rank group, and key.

The three declared quality thresholds divide included evidence into `high`,
`moderate`, and `limited`; evidence below the aggregate threshold is `excluded`.
The summary must reconcile exactly with the ledger. Downstream displays should
show both `aggregateTakeCount` and `eligibleTakeCount`; showing only the former
can make severe selection loss invisible.

Parentless or incomplete source data needs an explicit analytical grouping. A
producer may infer a stable grouping identifier from documented source fields,
but must retain `groupingBasis` such as `declared-parent-component`,
`registration-anchor`, or an identified source-signature rule. Matching labels
alone do not establish common component or physical-source identity.

## Rank tuning curves and stretch

Group included takes by the declared analytical rank group and then by key.
For each key, retain a robust unweighted center and dispersion even when the
primary aggregate uses quality and uncertainty weights:

- `medianDeviationCents` gives an inspectable robust center;
- `medianAbsoluteDeviationCents` records within-key dispersion;
- `evidenceCount` records contributing takes; and
- implementations SHOULD retain the weighted center, observed bounds,
  effective sample size, median evidence quality, and standard uncertainty when
  available.

Quality weights should be bounded so one very small uncertainty cannot dominate
the collection. The OrgRec reference method uses clipped quality divided by
variance and exports its primary rank curve with the
`quality-weighted-median` aggregation IRI.

Rank stretch is a trend in cents per octave, not a statement about intended
temperament or construction. A robust Siegel repeated-median slope is suitable
for sparse or contaminated rank evidence. Its bounds may describe the observed
pairwise-slope distribution, but must not be labelled population confidence
intervals unless the generating method actually supports that interpretation.
With too few distinct keys, emit an empty `rank-stretch` array with
`indeterminate` applicability rather than a zero slope.

The direct robust-slope source is A. F. Siegel, “Robust regression using
repeated medians,” 1982
([doi:10.1093/biomet/69.1.242](https://doi.org/10.1093/biomet/69.1.242)).
OrgRec's clipped quality/variance weight, scale floors, minimum evidence gates,
and pairwise-slope bounds are application choices. The reported effective
sample size uses the conventional Kish form `(Σw)²/Σw²` (Kish, *Survey
Sampling*, 1965); it describes weight concentration and is not a count of
independent physical organs or a replacement for coverage reporting.

## Session offset and drift

Session offset and within-session drift answer different questions:

- `session-offset` is a robust location summary for the available session;
- `session-drift` estimates change over elapsed time only from repeated
  measurements of comparable acoustic targets.

The drift stratum should fix the physical or declared sound target, capture
setup, and analysis channel. Different keys must never be used as if they were
repeated observations of one target. Compute within-target slopes first, then
aggregate those slopes across targets. Require the declared minimum repeated
targets, pair comparisons, and elapsed span before publishing a numeric drift.

If any gate fails, retain the session entry with its evidence counters,
`driftCentsPerHour: null`, and `applicability: "indeterminate"`. A numeric zero
would instead claim measured stability. Temperature, humidity, pressure, or
other environmental measurements may accompany the activity, but correlation
does not establish environmental causality.

## Acoustic anomaly review candidates

An anomaly screen may compare robust, normalized features within an analytical
rank group. Candidate dimensions can include tuning deviation, spectral
centroid or roll-off normalized by fundamental frequency, odd/even energy,
inharmonicity, attack duration, sustain stationarity, and modulation depth.
Only finite, meaningfully comparable dimensions should enter a distance.

The result is a review queue. It is not a fault code, pipe-construction label,
or conservation diagnosis. Retain the feature contributions and robust centers
when practical so a reviewer can see why a take was surfaced. Warning and
critical labels must follow the exported thresholds, not presentation-only
defaults. An empty candidate array is a valid negative result.

## Harmonic-aligned similarity review candidates

Compare relative partial amplitudes by harmonic number rather than by array
position or raw frequency-bin index. Candidate eligibility should require the
same intended key and a comparable setup/channel while excluding repeat
measurements of the same already-declared target. Normalize amplitude before a
cosine comparison and require both the declared similarity threshold and the
declared minimum shared harmonics.

Pairs are unordered but serialized canonically: `firstTakeId` is
lexicographically less than `secondTakeId`. Both identifiers come from the
evidence ledger, each pair appears once, and output is capped by
`maximumSimilarityCandidates`. Ranking candidates by a documented evidence
score that combines similarity, evidence quality, and harmonic coverage is
recommended.

Every interpretation explicitly says “candidate.” Similarity can prompt
provenance or physical-source review; it cannot prove that two takes represent
the same pipe, component, object, maker, period, or construction. An empty list
means no pair passed the declared candidate rule and is a valid negative result.

## Reproducibility and paradata

The generating activity uses `methodType: "metric-calculation"` and
`representationStatus: "inferred"`. It retains software name/version, exact
input and output identifiers, the 12 governed threshold/gating parameters, and
a lowercase SHA-256 parameter fingerprint. If any other setting affects
grouping, weighting, feature extraction, uncertainty, ranking, or truncation,
it belongs in the immutable parameter set or an indexed protocol asset too.

Document the bytes and canonicalization rule hashed by `parameterSHA256`.
Changing a material parameter, feature schema, grouping rule, or software
method version creates a new analysis and activity; it does not silently mutate
an existing result. Stochastic methods additionally record their random seed.

OrgRec also stores a deterministic source fingerprint over the sorted roadmap,
take evidence, recording-session paradata, and collection parameters. An
unchanged fingerprint retains the existing immutable report identity and time;
a review, analysis, grouping, or session change creates a fresh report. A
mismatched fingerprint is a stale-result warning and the VAO builder refreshes
the report before projection.

Large per-frame tracks, partial trajectories, matrices, or feature tables should
remain fixed indexed assets linked through `valueAssetId`. The inline governed
values are the compact, reviewable contract, not a reason to discard source
evidence.

## Applicability and presentation

A user interface should make these states visually distinct:

- `applicable`: the declared evidence gates support the stated aggregate;
- `limited`: a result exists but coverage or domain evidence prevents an
  unrestricted claim;
- `indeterminate`: the estimate cannot be calculated responsibly; and
- empty candidate array: the declared search produced no review candidate.

Never coerce `null`, an empty list, or excluded evidence to zero. Show coverage,
thresholds, evidence counts, and exclusions near the chart or candidate list.
Keep the raw take ledger reachable from every aggregate.

## Compact manifest pattern

The fragment below is structural rather than a complete package. It shows where
the patch-safe terms occur; the normative field and value rules remain in the
standard.

```json
{
  "profiles": [{
    "id": "https://w3id.org/modavis/vao/profile/research/0.2",
    "version": "0.2",
    "requiredCapabilities": [
      "https://w3id.org/modavis/vao/vocab/capability/acoustical-analysis",
      "https://w3id.org/modavis/vao/vocab/capability/collection-acoustic-diagnostics"
    ]
  }],
  "analyses": [{
    "id": "urn:uuid:COLLECTION-ANALYSIS",
    "analysisType": "https://w3id.org/modavis/vao/vocab/analysis/evidence-qualified-collection-acoustic-diagnostics",
    "method": "Evidence-qualified collection acoustic diagnostics",
    "version": "method/version",
    "generatedAt": "2026-08-20T00:00:00Z",
    "inputIds": ["urn:uuid:TAKE-1"],
    "outputIds": [],
    "paradataId": "urn:uuid:COLLECTION-ACTIVITY",
    "observations": [
      {
        "property": "https://w3id.org/modavis/vao/vocab/analysis/collection/evidence-summary",
        "value": {
          "eligibleTakeCount": 1,
          "analyzedTakeCount": 1,
          "aggregateTakeCount": 1,
          "highQualityCount": 1,
          "moderateQualityCount": 0,
          "limitedQualityCount": 0,
          "excludedCount": 0,
          "aggregateCoverage": 1.0
        },
        "status": "inferred",
        "applicability": "applicable",
        "subjectId": "urn:uuid:INSTRUMENT"
      }
    ]
  }]
}
```

The real analysis must include all eight observations exactly once. The
paradata activity and every referenced entity are omitted above only to keep
the pattern compact.

## Review checklist

- The capability and `acoustical-analysis` are in the same research profile.
- The analysis type, eight properties, units, and aggregation IRIs are exact.
- The activity is inferred metric calculation and its inputs/outputs resolve.
- All material parameters and the parameter fingerprint are retained.
- Summary counts, coverage, ledger size, and analysis inputs reconcile.
- Exclusions remain in the ledger with machine-readable reasons.
- Rank keys are unique and ascending; all reported numbers are finite.
- Drift compares repeated targets and encodes insufficient evidence as null.
- Candidate arrays may be empty; candidates resolve to ledger takes.
- Anomalies do not claim fault/construction and similarities do not claim
  identity.
