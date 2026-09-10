import SwiftUI
import OrgRecCore

struct StandaloneAudioView: View {
    @ObservedObject var model: StandaloneAudioModel
    @State private var targeted = false
    @State private var search = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Analyze Audio").font(.system(.largeTitle, design: .serif, weight: .semibold))
                        Text("One file. Inspectable measurements. No project or catalogue required.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose audio…") { model.chooseFile() }.disabled(model.isWorking)
                    if model.document != nil {
                        Menu("Export") {
                            ForEach(StandaloneExportKind.allCases) { kind in Button(kind.title) { model.export(kind) } }
                        }.disabled(model.isWorking)
                    }
                }
                dropArea
                if let source = model.source {
                    settings(source)
                }
                if model.isWorking {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(model.status)
                        Spacer()
                        Button("Cancel analysis") { model.cancel() }
                            .disabled(!model.canCancel)
                    }
                } else {
                    Text(model.status).font(.callout).foregroundStyle(.secondary)
                }
                if let result = model.document {
                    results(result)
                }
            }
            .padding(28)
            .frame(maxWidth: 1250, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .dropDestination(for: URL.self) { urls, _ in model.accept(urls) } isTargeted: { targeted = $0 }
        .alert("Audio analysis", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var dropArea: some View {
        HStack(spacing: 15) {
            Image(systemName: "waveform.badge.plus").font(.largeTitle).foregroundStyle(OrgRecTheme.shu)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.source?.filename ?? "Drop an audio file here").font(.headline).textSelection(.enabled)
                Text("WAV, AIFF, FLAC, MP3, M4A and other formats supported by macOS. The original file stays unchanged.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(targeted ? OrgRecTheme.shu.opacity(0.08) : OrgRecTheme.surface,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(targeted ? OrgRecTheme.shu : OrgRecTheme.hairline, style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
        .accessibilityLabel("Audio file drop area")
    }

    private func settings(_ source: StandaloneAudioSource) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(source.duration.formatted(.number.precision(.fractionLength(2)))) s · \(source.sampleRate.formatted()) Hz · \(source.channelCount) channels")
                .font(.callout.monospacedDigit())
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Sound type").font(.caption)
                    Picker("Sound type", selection: $model.request.applicability) {
                        Text("Unknown / exploratory").tag(PitchAnalysisApplicability.indeterminate)
                        Text("Single pitched source").tag(PitchAnalysisApplicability.monophonic)
                        Text("Polyphonic / multiple sources").tag(PitchAnalysisApplicability.polyphonic)
                        Text("Non-pitched sound").tag(PitchAnalysisApplicability.nonPitched)
                    }.labelsHidden().frame(width: 240)
                }
                VStack(alignment: .leading) {
                    Text("Reference channel").font(.caption)
                    Picker("Reference channel", selection: $model.request.referenceChannel) {
                        ForEach(0..<source.channelCount, id: \.self) { Text("Channel \($0 + 1)").tag($0) }
                    }.labelsHidden().frame(width: 130)
                }
                VStack(alignment: .leading) {
                    Text("Reference pitch (optional, Hz)").font(.caption)
                    TextField("No reference", text: $model.expectedFrequencyText).textFieldStyle(.roundedBorder).frame(width: 175)
                        .disabled(model.request.applicability == .polyphonic || model.request.applicability == .nonPitched)
                }
            }
            HStack(spacing: 12) {
                Text("Excerpt start (s)")
                TextField("Start seconds", value: $model.request.startSeconds, format: .number).frame(width: 90)
                Text("Duration (s)")
                TextField("Duration seconds", value: $model.request.durationSeconds, format: .number).frame(width: 90)
                Text("Maximum \(Int(source.maximumExcerptDuration)) s per analysis").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.document == nil ? "Analyze" : "Reanalyze") { Task { await model.analyze() } }
                    .buttonStyle(.borderedProminent)
            }.textFieldStyle(.roundedBorder)
            DisclosureGroup("Spectral settings") {
                HStack {
                    Picker("FFT size", selection: $model.request.configuration.fftSize) {
                        ForEach([2048, 4096, 8192, 16384], id: \.self) { Text(String($0)).tag($0) }
                    }
                    Picker("Hop", selection: $model.request.configuration.hopSize) {
                        ForEach([256, 512, 1024, 2048], id: \.self) { Text(String($0)).tag($0) }
                    }
                    Picker("Window", selection: $model.request.configuration.window) {
                        ForEach(SpectralWindow.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }.padding(.top, 8)
            }
            Text("For multiple notes or a long recording, select one event. Times in the plots start at zero for this excerpt.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(18).background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .disabled(model.isWorking)
    }

    private func signalSummary(_ result: StandaloneAnalysisDocument) -> some View {
        let analysis = result.analysis
        func number(_ value: Double?, _ unit: String) -> String {
            value.map { $0.formatted(.number.precision(.fractionLength(3))) + " " + unit } ?? "Unavailable"
        }
        let items: [(String, String)] = [
            ("Pitch", number(analysis.frequencyHz, "Hz")),
            ("Reference deviation", number(analysis.centsDeviation, "cents")),
            ("Peak", number(analysis.peakDBFS, "dBFS")),
            ("RMS", number(analysis.rmsDBFS, "dBFS")),
            ("Signal to noise", number(analysis.signalToNoiseDB, "dB")),
            ("Clipped samples", String(analysis.clippedSamples)),
            ("DC offset", number(analysis.dcOffset, "FS")),
            ("Loop candidates", String(analysis.detectedLoopPointSets?.count ?? 0))
        ]
        return VStack(alignment: .leading, spacing: 14) {
            Text("Signal measurements").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), alignment: .leading)], alignment: .leading, spacing: 16) {
                ForEach(items, id: \.0) { title, value in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.caption).foregroundStyle(.secondary)
                        Text(value).font(.title3.monospacedDigit()).textSelection(.enabled)
                    }
                }
            }
            DisclosureGroup("Detected boundaries and channel relationships") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(analysis.boundaries ?? []) { boundary in
                        LabeledContent(boundary.marker.rawValue, value: number(boundary.seconds, "s") + " · " + boundary.state.rawValue)
                    }
                    ForEach(Array((analysis.channelRelationships ?? []).enumerated()), id: \.offset) { _, channel in
                        Text("Channel \(channel.channelIndex + 1): level difference \(number(channel.levelDifferenceDB, "dB")) · correlation \(number(channel.correlationWithReference, "")) · delay \(channel.delaySamples.map { String($0) } ?? "unavailable") samples")
                    }
                    Text("Boundary times refer to the excerpt. Channel comparisons use the selected reference channel. Loop candidates are unreviewed; full evidence is included in the measurement table and exports.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 8)
            }
        }.orgRecCard()
    }

    @ViewBuilder private func results(_ result: StandaloneAnalysisDocument) -> some View {
        if model.hasChangedSettings {
            Label("Settings changed. The displayed and exported results still belong to the previous run. Select Reanalyze to apply them.", systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
        }
        VStack(alignment: .leading, spacing: 6) {
            Text("Analyzed source interval: \(result.sourceStartSeconds.formatted(.number.precision(.fractionLength(3))))–\((result.sourceStartSeconds + result.duration).formatted(.number.precision(.fractionLength(3)))) s · Channel \(result.request.referenceChannel + 1)").font(.headline)
            Text("Run \(result.analysis.analysisRunID?.uuidString ?? "unknown") · \(result.request.applicability.rawValue)").font(.caption.monospaced()).textSelection(.enabled)
            Text("FFT \(result.spectrogram.configuration?.fftSize ?? 0) · hop \(result.spectrogram.configuration?.hopSize ?? 0) · \(result.spectrogram.configuration?.window.rawValue ?? "")").font(.caption)
        }
        DisclosureGroup("Interpretation limits and quality flags (\(result.limitations.count + result.analysis.qualityFlags.count))") {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array((result.limitations + result.analysis.qualityFlags).enumerated()), id: \.offset) { _, text in
                    Text("• " + text).font(.callout)
                }
            }.padding(.top, 8)
        }
        Text("Pitch and harmonic results are exploratory unless a single pitched source is confirmed. Missing measurements are not zero.")
            .font(.callout).foregroundStyle(.secondary)
        signalSummary(result)
        PlaybackBar(playback: model.playback).orgRecCard()
        AnalysisNavigationBar(interaction: model.interaction).orgRecCard()
        InteractiveAnalysisWaveform(waveform: result.waveform, analysis: result.analysis, correctedMarkers: [], annotations: [], interaction: model.interaction, playback: model.playback)
            .frame(height: 180)
        InteractiveSpectrogramView(data: result.spectrogram, analysis: result.analysis, annotations: [], interaction: model.interaction, playback: model.playback).orgRecCard()
        if let comparison = result.analysis.pitchEstimatorComparison { PitchEstimatorComparisonView(comparison: comparison).orgRecCard() }
        if !(result.spectrogram.pitchTrack ?? []).isEmpty {
            InteractivePitchTrackView(track: result.spectrogram.pitchTrack ?? [], summary: result.analysis.pitchTrackSummary, runCount: 1, interaction: model.interaction, playback: model.playback).orgRecCard()
        }
        if !(result.spectrogram.partialTracks ?? []).isEmpty {
            InteractivePartialTracksView(tracks: result.spectrogram.partialTracks ?? [], interaction: model.interaction, playback: model.playback).orgRecCard()
        }
        if let spectral = result.analysis.perceptualSpectralSummary { PerceptualSpectralPanel(summary: spectral).orgRecCard() }
        if let decay = result.analysis.acousticResponseAnalysis { AcousticDecayEvidencePanel(analysis: decay).orgRecCard() }
        DisclosureGroup("All measurements and detected loop candidates") {
            TextField("Filter measurement names", text: $search).textFieldStyle(.roundedBorder)
            LazyVStack(alignment: .leading, spacing: 5) {
                ForEach(model.valueRows.filter { search.isEmpty || $0.path.localizedCaseInsensitiveContains(search) }) { row in
                    HStack(alignment: .top) {
                        Text(row.path).frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.value).frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.caption.monospaced()).textSelection(.enabled)
                }
            }
        }
        DisclosureGroup("Source identity") {
            Text("Original SHA-256: \(result.sourceSHA256)\nAnalyzed excerpt SHA-256: \(result.excerptSHA256)")
                .font(.caption.monospaced()).textSelection(.enabled)
        }
    }
}
