# OrgRec P2: spatial acoustic capture and effect analytics

Scientific provenance, response qualification, standards boundaries, and
non-claims are indexed in the
[scientific-method register](SCIENTIFIC_METHODS.md).

P2 implements two related but distinct evidence families.

## In-situ state-dependent responses

The Roadmap’s **Plan spatial response…** wizard records a local Cartesian
reference frame and revisioned geometry for ranks or effects, enclosures,
screens, and shutters. Each element has a stable identifier, optional source
component and parent, position, orientation, extent, source distribution,
material/open-area data, evidence source, and uncertainty. Microphone setups
must explicitly share that coordinate frame.

The wizard then compiles the Cartesian product of response states and selected
microphone techniques. One state is the reference. Every state has exact typed
assignments and every Roadmap obligation freezes the geometry identifier and
SHA-256 fingerprint, source, propagation path, series identifier, reference
state, minimum accepted repetitions, and planned duration.

During recording, the operator confirms the physical state and marks the source
trigger, stable response, and notable variation. The take freezes the complete
geometry and protocol in provenance. Analysis streams the frozen reference
channel and records peak/RMS level, command-to-acoustic-onset latency, effective
impulse width, source-to-reference-microphone distance when coordinate frames
are compatible, and third-octave levels from 31.5 Hz through the usable Nyquist
limit.

OrgRec only compares accepted reference and target takes with the same series,
geometry fingerprint, microphone setup, technique, and reference channel.
Reported deltas therefore remain in-situ state-dependent responses. They are
not labelled as isolated shutter transfer functions: source position and
spectrum, enclosure, screen, shutter state, room, gain, and microphone geometry
remain jointly present unless the experimental design controls them.

## Non-pitched effect analysis

Atonal percussion and sustained, one-shot, repeating, sequenced, composite, and
other non-pitched sounding targets receive an explicit P2 analysis protocol.
Pipe speech and tonal percussion do not. Existing compatible Roadmap items infer
the same protocol on load, while newly compiled items store it explicitly.

Analysis preserves:

- synchronized control or operator-marker command time, timing evidence, and
  uncertainty;
- acoustic onset and command-to-onset latency;
- peak and RMS dBFS plus effective impulse width;
- repetition count/rate and interval mean, standard deviation, coefficient of
  variation, minimum, and maximum;
- envelope-autocorrelation periodicity rate and confidence;
- normalized temporal entropy and a bounded stochasticity index; and
- begin/end/duration, planned typical duration, deviation, evidence, and
  uncertainty for every P1 declarative-process stage.

Insufficient events produce explicit non-applicability warnings rather than
invented values. Original audio is never denoised or replaced by the analysis.

## Review, audit, and exchange

Acceptance requires P2 analysis for non-pitched effects. Spatial-response takes
also require a matching protocol, frozen geometry, state confirmation, and a
manual or synchronized source trigger. The consistency auditor rejects missing
or stale geometry, unresolved source/path elements, incompatible setup frames,
cross-protocol paradata, accepted observations without evidence, and aggregate
comparisons containing unaccepted takes.

All P2 geometry, protocols, events, observations, effect analyses, and frozen
provenance are encoded in the editable OrgRec project, capture-analysis JSON,
and secondary IAD take index. VAO 0.4.0 alignment is deliberately outside this
implementation.

## Method provenance and measurement boundary

Qualified impulsive or externally deconvolved responses use the noise-aware
Schroeder/decay method documented in
[`ADVANCED_ACOUSTIC_ANALYSIS.md`](ADVANCED_ACOUSTIC_ANALYSIS.md). Ordinary pipe
releases remain pipe-plus-room evidence and cannot receive C50, C80, D50, or an
ISO room-response claim. Normalized temporal entropy uses Shannon's information
entropy definition
([1948 DOI](https://doi.org/10.1002/j.1538-7305.1948.tb01338.x)); the temporal
binning, normalization, stochasticity combination, periodicity scan, onset
gates, and interpretation labels are OrgRec synthesis.

The octave and third-octave results are windowed spectral-energy integrations,
not verified class filters under
[IEC 61260-1:2014](https://webstore.iec.ch/en/publication/5063). Spatial
differences describe the frozen source, state, path, room, gain, and receiver
geometry together. They are not isolated shutter transfer functions, causal
mechanism diagnoses, or certified room-acoustic surveys.
