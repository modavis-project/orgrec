import OrgRecCore
import SwiftUI

struct TimbreAnalysisPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var rankID: String?
    @State private var mode: TimbreAnalysisMode = .characterization
    @State private var isExpanded = true
    @State private var showsMethodology = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("A designated rank-level process for steady-state harmonic timbre. It does not change take QC, acceptance, or documentary stop metadata.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Characterization reports measured features and a pitch-dependent rank fingerprint. Family suggestion adds a held-out-instrument calibrated hierarchical classifier with explicit abstention—not an exact stop identification.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showsMethodology = true
                    } label: {
                        Label("Method & publications", systemImage: "info.circle")
                    }
                }

                if model.timbreRankOptions.isEmpty {
                    Label("No rank with usable note-level recordings is available.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(OrgRecTheme.shu)
                } else {
                    HStack(spacing: 12) {
                        Picker("Rank", selection: Binding(
                            get: { rankID ?? model.timbreRankOptions.first?.id },
                            set: { rankID = $0 }
                        )) {
                            ForEach(model.timbreRankOptions) { option in
                                Text("\(option.label) · \(option.division) · \(option.footHeight) · \(option.noteCount) keys")
                                    .tag(Optional(option.id))
                            }
                        }
                        .frame(maxWidth: 520)
                        Picker("Process", selection: $mode) {
                            ForEach(TimbreAnalysisMode.allCases) { value in
                                Text(value.displayName).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)
                        Spacer()
                        Button(mode == .characterization ? "Analyze rank timbre" : "Analyze & suggest family") {
                            run()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                    }
                }

                if let progress = model.timbreProgress {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(progress).font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let report = model.selectedTimbreReport {
                    Divider()
                    reportView(report)
                }
            }
            .padding(.top, 12)
        } label: {
            HStack {
                Label("Timbre & rank-family analysis", systemImage: "waveform.and.magnifyingglass").font(.headline)
                Spacer()
                if let report = model.selectedTimbreReport {
                    Text(applicabilityLabel(report.applicability))
                        .font(.caption.bold())
                        .foregroundStyle(applicabilityColor(report.applicability))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(applicabilityColor(report.applicability).opacity(0.12), in: Capsule())
                }
            }
        }
        .orgRecCard()
        .onAppear { rankID = rankID ?? model.timbreRankOptions.first?.id }
        .sheet(isPresented: $showsMethodology) {
            TimbreMethodologySheet()
        }
    }

    @ViewBuilder
    private func reportView(_ report: TimbreAnalysisReport) -> some View {
        HStack(spacing: 12) {
            TimbreMetric(title: "Pipes", value: "\(report.observations.count)", symbol: "circle.grid.cross")
            TimbreMetric(
                title: "Median c/f₁",
                value: median(report.observations.compactMap(\.normalizedSpectralCentroid))?.formatted(.number.precision(.fractionLength(2))) ?? "—",
                symbol: "scope"
            )
            TimbreMetric(
                title: "Median slope",
                value: median(report.observations.compactMap(\.weightedAverageSlopeDBPerOctave)).map { "\($0.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))) dB/oct" } ?? "—",
                symbol: "chart.line.downtrend.xyaxis"
            )
            TimbreMetric(
                title: "Top broad family",
                value: report.empiricalClassification.flatMap { classification in
                    classification.selectedFamily.flatMap { family in
                        classification.candidates.first(where: { $0.family == family }).map {
                            "\(family.displayName) · \($0.calibratedProbability.formatted(.percent.precision(.fractionLength(0))))"
                        }
                    } ?? (classification.abstained ? "Abstained" : nil)
                } ?? "Not inferred",
                symbol: "square.stack.3d.up"
            )
        }
        Text("\(report.rankLabel) · \(report.mode.displayName) · \(report.analyzedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("Generated by \((report.software ?? OrgRecSoftware.current).displayName) · method \(report.algorithmVersion) · parameters \((report.parameterSHA256 ?? "unrecorded").prefix(12))…")
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)

        if report.observations.isEmpty == false {
            TimbreTrajectoryChart(report: report)
                .frame(height: 250)
            Text("Axes are the normalized spectral centroid c/f₁ and the q = 1.729 weighted adjacent-partial slope. Lines connect recorded keys by pitch; they are not interpolated measurements.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let classification = report.empiricalClassification {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Empirically calibrated hierarchy").font(.subheadline.bold())
                        Spacer()
                        Text(classification.modelVersion).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                    ForEach(classification.candidates) { candidate in
                        HStack {
                            Text(candidate.family.displayName).frame(width: 150, alignment: .leading)
                            ProgressView(value: candidate.calibratedProbability).tint(OrgRecTheme.ai)
                            Text(candidate.calibratedProbability.formatted(.percent.precision(.fractionLength(1))))
                                .font(.caption.monospacedDigit()).frame(width: 52, alignment: .trailing)
                            Text(candidate.hierarchyPath.joined(separator: " › "))
                                .font(.caption2).foregroundStyle(.secondary).frame(width: 180, alignment: .trailing)
                        }
                    }
                    if classification.abstained {
                        Label(classification.reason ?? "The calibrated classifier abstained.", systemImage: "questionmark.diamond")
                            .font(.caption).foregroundStyle(OrgRecTheme.shu)
                    }
                    Text("Probabilities are temperature-calibrated on held-out physical instruments. OOD distance \(classification.outOfDistributionDistance.formatted(.number.precision(.fractionLength(2)))) / \(classification.outOfDistributionThreshold.formatted(.number.precision(.fractionLength(2)))); acceptance threshold \(classification.minimumAcceptedProbability.formatted(.percent.precision(.fractionLength(1)))). Documentary identity remains separate.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(OrgRecTheme.recessed, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
            }

            if let fingerprint = report.pitchDependentFingerprint {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Pitch-dependent rank fingerprint").font(.subheadline.bold())
                        Spacer()
                        Text("\(fingerprint.points.count) pipes · \(fingerprint.selectedSegmentCount) segment\(fingerprint.selectedSegmentCount == 1 ? "" : "s")")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    ForEach(fingerprint.trends.filter { ["centroid", "slopeDBPerOctave", "evenOddDB"].contains($0.feature) }) { trend in
                        HStack {
                            Text(trend.feature).frame(width: 170, alignment: .leading)
                            Text("linear \(trend.linearChangePerOctave.formatted(.number.precision(.fractionLength(3)).sign(strategy: .always()))) / octave")
                            Spacer()
                            Text("RMSE \(trend.residualRMSE.formatted(.number.precision(.fractionLength(3))))")
                                .foregroundStyle(.secondary)
                        }.font(.caption.monospacedDigit())
                    }
                    if fingerprint.transitions.isEmpty {
                        Text("No construction transition met both the predeclared ΔBIC and family-wise permutation thresholds.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(fingerprint.transitions) { transition in
                            Label {
                                Text("\(transition.lowerNoteName)–\(transition.upperNoteName) · ΔBIC \(transition.bicImprovementForSelectedSegmentation.formatted(.number.precision(.fractionLength(1)))) · p \(transition.familyWisePermutationPValue.formatted(.number.precision(.fractionLength(3)))) · effect \(transition.standardizedEffectSize.formatted(.number.precision(.fractionLength(2))))")
                            } icon: { Image(systemName: "point.topleft.down.to.point.bottomright.curvepath") }
                            .font(.caption)
                            .help(transition.interpretation)
                        }
                    }
                    Text("Detected boundaries are acoustic evidence for review, not automatic claims about pipe material or construction.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(OrgRecTheme.recessed, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
            }

            if report.familyCandidates.isEmpty == false {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Legacy uncalibrated distance support").font(.subheadline.bold())
                    ForEach(report.familyCandidates) { candidate in
                        HStack {
                            Text(candidate.family.displayName).frame(width: 150, alignment: .leading)
                            ProgressView(value: candidate.relativeSupport).tint(OrgRecTheme.ai)
                            Text(candidate.relativeSupport.formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption.monospacedDigit()).frame(width: 42, alignment: .trailing)
                            Text("d̄ \(candidate.normalizedDistance.formatted(.number.precision(.fractionLength(2)))) · σ \(candidate.relativeSupportStandardDeviation?.formatted(.number.precision(.fractionLength(2))) ?? "—") · nₑ \(candidate.effectiveObservationCount?.formatted(.number.precision(.fractionLength(1))) ?? "—")")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 190, alignment: .trailing)
                        }
                    }
                    Text("Retained for comparison with OrgRec 0.2.0 reports. Relative support is normalized inverse distance to the original engineering profile; it is not a calibrated probability or curatorial identification.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(OrgRecTheme.recessed, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
            }

            DisclosureGroup("Per-pipe observations and provenance") {
                VStack(spacing: 0) {
                    ForEach(report.observations) { observation in
                        TimbreObservationRow(observation: observation)
                        if observation.id != report.observations.last?.id { Divider() }
                    }
                }
                .padding(.top, 6)
            }
        } else {
            ContentUnavailableView(
                report.applicability == .notApplicable ? "Method not applicable" : "No usable observations",
                systemImage: "waveform.badge.exclamationmark",
                description: Text(report.warnings.first ?? "The report contains no usable pipe measurement.")
            )
            .frame(minHeight: 140)
        }

        if report.warnings.isEmpty == false {
            DisclosureGroup("Applicability and interpretation notes (\(report.warnings.count))") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)
            }
        }

        if let reports = model.project?.timbreAnalyses, reports.count > 1 {
            HStack {
                Text("Analysis history").font(.caption).foregroundStyle(.secondary)
                Picker("Analysis history", selection: Binding(
                    get: { Optional(report.id) },
                    set: { model.selectedTimbreReportID = $0 }
                )) {
                    ForEach(reports.reversed()) { item in
                        Text("\(item.rankLabel) · \(item.mode.displayName) · \(item.analyzedAt.formatted(date: .abbreviated, time: .shortened))")
                            .tag(Optional(item.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 580)
            }
        }
    }

    private func run() {
        guard let id = rankID ?? model.timbreRankOptions.first?.id else { return }
        Task { await model.analyzeTimbre(rankComponentID: id, mode: mode) }
    }

    private func median(_ values: [Double]) -> Double? {
        let sorted = values.sorted()
        guard sorted.isEmpty == false else { return nil }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private func applicabilityLabel(_ value: TimbreAnalysisApplicability) -> String {
        switch value {
        case .applicable: "Applicable"
        case .limited: "Limited evidence"
        case .notApplicable: "Not applicable"
        }
    }

    private func applicabilityColor(_ value: TimbreAnalysisApplicability) -> Color {
        value == .applicable ? OrgRecTheme.ai : OrgRecTheme.shu
    }
}

private struct TimbreMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(OrgRecTheme.recessed, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
    }
}

private struct TimbreObservationRow: View {
    let observation: PipeTimbreObservation

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(observation.noteName ?? observation.midiNote.map { "MIDI \($0)" } ?? "Pipe").font(.caption.bold())
                Text("take \(observation.takeID.uuidString.prefix(8)) · channel \(observation.referenceChannel + 1) · \(observation.averagedFrameCount) LTAS frames")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 210, alignment: .leading)
            LabeledContent("c/f₁", value: observation.normalizedSpectralCentroid?.formatted(.number.precision(.fractionLength(2))) ?? "—")
            LabeledContent("s", value: observation.weightedAverageSlopeDBPerOctave.map { "\($0.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))) dB/oct" } ?? "—")
            LabeledContent("even/odd", value: observation.evenToOddEnergyRatioDB.map { "\($0.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))) dB" } ?? "—")
            VStack(alignment: .trailing, spacing: 2) {
                Text(observation.firstFivePrototype.displayName).font(.caption)
                Text("\(observation.partials.count) partials · \(observation.fftSize)-FFT")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption)
        .padding(.vertical, 8)
        .help("SHA-256 \(observation.sourceAudioSHA256)\nStable segment \(observation.segmentStartSeconds.formatted(.number.precision(.fractionLength(2))))–\(observation.segmentEndSeconds.formatted(.number.precision(.fractionLength(2)))) s\nFundamental: \(observation.fundamentalSource.rawValue)")
    }
}

private struct TimbreTrajectoryChart: View {
    let report: TimbreAnalysisReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Rank trajectory in timbre space").font(.headline)
                Spacer()
                Label("pipe observation", systemImage: "circle.fill").font(.caption).foregroundStyle(OrgRecTheme.shu)
            }
            Canvas { context, size in
                let points = report.observations.compactMap { observation -> (PipeTimbreObservation, Double, Double)? in
                    guard let x = observation.normalizedSpectralCentroid,
                          let y = observation.weightedAverageSlopeDBPerOctave else { return nil }
                    return (observation, x, y)
                }
                let maximumX = max(6, ceil((points.map { $0.1 }.max() ?? 5) + 0.5))
                let minimumY = min(-30, floor((points.map { $0.2 }.min() ?? -25) / 10) * 10)
                let maximumY = max(20, ceil((points.map { $0.2 }.max() ?? 15) / 10) * 10)
                let inset: CGFloat = 28
                func position(x: Double, y: Double) -> CGPoint {
                    CGPoint(
                        x: inset + (size.width - inset * 1.45) * CGFloat((x - 0.8) / max(0.1, maximumX - 0.8)),
                        y: inset * 0.45 + (size.height - inset * 1.25) * CGFloat((maximumY - y) / max(1, maximumY - minimumY))
                    )
                }
                for x in stride(from: 1.0, through: maximumX, by: 1) {
                    let p = position(x: x, y: minimumY)
                    var line = Path(); line.move(to: CGPoint(x: p.x, y: inset * 0.45)); line.addLine(to: CGPoint(x: p.x, y: size.height - inset * 0.8))
                    context.stroke(line, with: .color(OrgRecTheme.sumi.opacity(0.07)), lineWidth: 1)
                    context.draw(Text(x.formatted(.number.precision(.fractionLength(0)))).font(.caption2).foregroundColor(OrgRecTheme.secondaryText), at: CGPoint(x: p.x, y: size.height - 7))
                }
                for y in stride(from: minimumY, through: maximumY, by: 10) {
                    let p = position(x: 0.8, y: y)
                    var line = Path(); line.move(to: CGPoint(x: inset, y: p.y)); line.addLine(to: CGPoint(x: size.width - 8, y: p.y))
                    context.stroke(line, with: .color(OrgRecTheme.sumi.opacity(y == 0 ? 0.18 : 0.07)), lineWidth: 1)
                    context.draw(Text(y.formatted(.number.precision(.fractionLength(0)))).font(.caption2).foregroundColor(OrgRecTheme.secondaryText), at: CGPoint(x: 12, y: p.y))
                }
                if points.count > 1 {
                    var trajectory = Path()
                    for (index, point) in points.enumerated() {
                        let location = position(x: point.1, y: point.2)
                        if index == 0 { trajectory.move(to: location) } else { trajectory.addLine(to: location) }
                    }
                    context.stroke(trajectory, with: .color(OrgRecTheme.ai.opacity(0.72)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                }
                for point in points {
                    let location = position(x: point.1, y: point.2)
                    context.fill(Path(ellipseIn: CGRect(x: location.x - 4, y: location.y - 4, width: 8, height: 8)), with: .color(OrgRecTheme.shu))
                    if let label = point.0.noteName ?? point.0.midiNote.map(String.init) {
                        context.draw(Text(label).font(.caption2).foregroundColor(OrgRecTheme.sumi), at: CGPoint(x: location.x + 8, y: location.y - 8), anchor: .leading)
                    }
                }
            }
        }
        .padding(12)
        .background(OrgRecTheme.recessed, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
    }
}

private struct TimbreMethodologySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Timbre analysis: method, evidence, and publications")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                    Text("OrgRec \(TimbreMethodology.contractVersion) · inferred analysis")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    methodologySection
                    limitationsSection
                    Divider()
                    Text("Publication-to-method mapping").font(.headline)
                    ForEach(TimbreMethodology.publications) { publication in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(publication.shortCitation).font(.subheadline.bold())
                            Text(publication.title).font(.callout)
                            Text(publication.contribution).font(.caption).foregroundStyle(.secondary)
                            Link("doi:\(publication.doi)", destination: URL(string: "https://doi.org/\(publication.doi)")!)
                                .font(.caption)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OrgRecTheme.recessed, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 780, idealWidth: 850, minHeight: 680, idealHeight: 760)
        .background(OrgRecTheme.washi)
    }

    private var methodologySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Implemented process").font(.headline)
            Text("OrgRec selects the existing stable-sustain boundaries, reads only the take’s designated reference channel, resamples that channel to 48 kHz with AVAudioConverter, and averages Hann-window power spectra. The pitch-adaptive FFT is 8,192–65,536 samples; no stereo waveform downmix is performed. Harmonic peaks 1–20 are retained only when they exceed their local spectral noise estimate by 6 dB.")
                .font(.callout)
            Text("From those LTAS partial powers, OrgRec calculates c/f₁ = Σ(nPₙ)/ΣPₙ and the adjacent-partial slope with q = 1.729. The implementation uses (Lₙ₊₁ − Lₙ)/log₂((n+1)/n), so an ascending pair is positive and a falling spectrum negative. This sign follows the paper’s plots and prose; it is disclosed because the typeset Eq. 13 can be read with the opposite sign.")
                .font(.callout)
            Text("The FFT adaptation, 6 dB local threshold, family-profile centers, scale factors, out-of-distribution boundary, evidence weights, and distance normalization are explicit OrgRec engineering choices—not parameters fitted or claimed by the publications. Every report embeds the complete parameter set and its SHA-256 fingerprint, the generating software version/build, source hashes, source analysis-run IDs, channel, stable interval, FFT size, and frame count.")
                .font(.callout)
            Text("Frozen broad-family profile (center c/f₁, center slope, scale c/f₁, scale slope)")
                .font(.subheadline.bold())
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Family").bold(); Text("c/f₁").bold(); Text("dB/oct").bold(); Text("σ c/f₁").bold(); Text("σ slope").bold()
                }
                ForEach(TimbreMethodology.familyProfile) { point in
                    GridRow {
                        Text(point.family.displayName)
                        Text(point.centroidCenter.formatted(.number.precision(.fractionLength(2))))
                        Text(point.slopeCenterDBPerOctave.formatted(.number.precision(.fractionLength(1))))
                        Text(point.centroidScale.formatted(.number.precision(.fractionLength(2))))
                        Text(point.slopeScaleDBPerOctave.formatted(.number.precision(.fractionLength(1))))
                    }
                }
            }
            .font(.caption.monospacedDigit())
        }
    }

    private var limitationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interpretation and scope").font(.headline)
            Text("Characterization is the primary output. The empirical family suggestion follows a two-level hierarchy: flue versus reed, then flute, diapason/principal, or string within the flue branch. Node probabilities are temperature-scaled on calibration instruments; complete instruments, never individual notes, are assigned to training, calibration, or test. Low-confidence and out-of-distribution ranks are explicitly abstained. The classifier cannot establish exact stop name, footage, date, maker, pipe material, or documentary identity.")
                .font(.callout)
            Text("Mixtures/compound stops are marked not applicable because their percept depends on several sounding ranks, composition, breaks, critical bands, and pitch salience. Celestes and deliberately detuned ranks are marked not applicable because beating and fluctuation strength require simultaneous temporal analysis. The bundled model uses auditable weak labels derived from documentary stop names in the rights-conservative retrieved corpus. Pitch fingerprints fit multivariate segmented trajectories and require both ΔBIC evidence and a family-wise residual-permutation test; larger recording gaps produce no boundary claim.")
                .font(.callout)
        }
    }
}
