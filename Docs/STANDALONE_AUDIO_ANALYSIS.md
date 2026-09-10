# Standalone audio analysis

Use **Analyze Audio** in the sidebar or **File → Analyze Audio File…** (Shift–Command–A). An audio file can also be dropped onto the application or opened through Finder's Open With menu. No project, POD database or microphone access is required. On a fresh installation, Getting Started and Analyze Audio do not load or create the demonstration project.

## Workflow

1. Drop one local audio file, or choose it using the file picker. Decoding uses macOS audio support, including common WAV, AIFF, FLAC, MP3 and M4A files. Unreadable or empty files produce a recoverable error.
2. Short files are analyzed automatically with an **Unknown / exploratory** sound type. Confirm **Single pitched source** for an isolated note, or select **Polyphonic / multiple sources** or **Non-pitched sound** to disable single-source pitch estimation. An optional reference frequency enables tuning-deviation measurements.
3. Choose the reference channel and an excerpt. Long files require an explicit Analyze action. The default excerpt is up to 120 seconds; the absolute limit is 600 seconds and may be lower for high sample rates or many channels. The decoded excerpt is bounded to approximately 128 MiB, excluding analysis arrays. UI channels are numbered from one; machine-readable reference-channel indices start at zero.
4. Inspect the linked waveform, spectrogram, pitch evidence and partial trajectories. Zoom, pan and seek through the excerpt. Review signal measurements, spectral descriptors, release evidence, detected boundaries, loop candidates, source identity and all stored measurement fields. Changing settings leaves the preceding result visible with a notice until Reanalyze succeeds.
5. Use **Export** to save a complete analysis folder, PDF report, full JSON, CSV tables, or PNG/SVG plots. A failed or cancelled reanalysis preserves the preceding completed result. Cancellation takes effect at the next safe processing boundary; expensive estimator work can take time to finish that boundary.

## Evidence and interpretation

The original file is opened for reading and its checksum is checked before and after processing. Analysis and playback use a private temporary WAV excerpt with its own checksum, exact source start frame and frame count. All channels are retained in this excerpt; signal and pitch measurements use the chosen reference channel, with channel-relationship evidence retained separately. No source organ, intended note, microphone geometry or acquisition history is invented.

Plot times and analysis fields are relative to the excerpt. CSV time series additionally include source-relative times. The waveform is a reduced display summary, not a raw sample export. Spectrogram CSV data retain every stored display-grid bin; plot rendering may aggregate neighboring cells using their peak value. Unobserved boundaries and unavailable values remain distinguishable from zero.

Segmentation and sustain descriptors assume an isolated event. For music, multiple notes, speech or environmental recordings, select an appropriate event and qualify the interpretation. Unknown sound types receive provisional pitch interpretation; multiple-source and non-pitched selections suppress the single-source estimator. Release decay describes the recorded instrument and room together, not calibrated reverberation time. Temperament, rank/collection comparisons, spatial geometry, sound-pressure calibration and recording-hardware diagnostics require additional evidence and are not inferred from a bare file.

## Exports

- **Complete analysis folder:** `analysis.json`, `waveform.json`, `spectrogram.json`, `report.pdf`, six CSV tables, four plots in PNG and SVG, the exact `excerpt.wav`, `provenance.json`, interpretation notes and `SHA256SUMS`.
- **PDF:** source identity, a measurement overview, interpretation and quality statements, four plots, analysis parameters and a complete measurement-summary appendix. Dense time-series matrices remain in JSON and CSV exports.
- **JSON:** the complete standalone document, including the measurement summary, waveform, spectrogram, pitch/partial tracks, configuration, run record, source and excerpt identities.
- **CSV:** measurements, waveform, spectrogram, pitch, partials and boundaries. Text cells are quoted and formula-like text is neutralized for spreadsheet import. Missing optional values are blank. Provenance, notes and checksums accompany the tables.
- **Plots:** waveform with observed boundaries, spectrogram, voiced pitch evidence and valid partial evidence from tracks meeting the existing detected-partial confidence threshold of 0.2. Lower-confidence tracks remain in JSON and CSV. Each is available as a 2000 × 1160 PNG and editable SVG, with matching coordinates and labels. Provenance, notes and checksums accompany the figures.

Folder exports are staged beside their destination and installed only on success; existing folders are not replaced. The source audio cannot be selected as the export destination. The complete folder includes only the selected excerpt, not the rest of a long recording. Results persist in memory while the app is open; export them before quitting. The temporary excerpt is removed when replaced or when the application terminates normally.

## Verification

Tests cover exact excerpt frames and channel selection, source preservation, pitch estimation without organ metadata, unsupported ranges and reference values, non-finite audio, cancellation, long-file confirmation, retention of preceding results, CSV escaping, JSON round trips, readable PDFs/PNGs/SVGs, export closure and checksums, and refusal to replace existing folders. Rendered figures and report pages were inspected separately. Finder drag-and-drop on a clean installation has not yet been verified.
