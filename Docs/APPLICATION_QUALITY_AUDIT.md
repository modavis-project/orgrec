# OrgRec application quality audit

Audit date: 2026-08-31  
Scope: the native macOS application, recording and persistence paths, field-capture workflow, retained project evidence, organological pitch derivation, acoustic diagnostics, packaging, and automated verification.

This audit treats preservation of irreplaceable field evidence as the primary product requirement. A visually polished workflow is not considered release-ready when a quit, disk, route, concurrency, or metadata failure can silently invalidate a take.

## Evaluated and implemented points

| Area | Risk found | Implemented release requirement |
| --- | --- | --- |
| Capture durability | A recording could exist before its take was durably represented in the project, slower BWF rewriting could blur the true stop boundary, and reanalysis/review prose could erase a capture failure. | Keep atomic recovery journals from before start through the finalized manifest commit for ordinary takes, continuous masters, A4 calibrations, and signal-path rehearsals; reconcile them at launch; quarantine unreadable interrupted rehearsal bytes without deleting them; prevent a retained master from being silently replaced; close MIDI/sensor evidence at the Core Audio boundary while a finalization lock protects the asynchronous BWF rewrite; preserve immutable capture-integrity faults that block acceptance and checked export regardless of later analysis or review text. |
| Quit and sleep | App termination or Mac sleep could strand an active writer. | Disable idle/sudden/automatic termination during capture; intercept quit and sleep; stop, drain, finalize BWF metadata, save, and refuse termination if saving still fails. |
| Save failures | Several mutations silently ignored persistence errors, and overlapping continuations could report an older outcome or clear the busy state too early. | Propagate project-save failures, retain dirty in-memory state, expose Retry Save in the window and Project menu, count overlapping operations, and derive the final persistence state solely from the newest save generation after every write drains. Retry also resumes deferred take analysis and reconciles committed long-take transactions. |
| Stale analysis | A late analysis task could replace newer review edits or project state. | Token and source-hash each analysis operation; reject stale results; merge only the analyzed take while preserving human review and current project collections. |
| Long recording limits | Classic RIFF/WAVE limits and finalization disk needs were not enforced while recording. | Monitor estimated container size, available capacity, writer faults, input-device health, sample-rate drift, and a finalization reserve; request an orderly safety stop before a corrupt or unfinalizable file can result. |
| Real-time callback pressure | Metering and pitch work was scheduled for every audio callback. | Keep every buffer on the writer path while rate-limiting UI and pitch-monitor work to about 20 Hz. |
| Writer evidence | RMS depended on callback partitioning, silence counted blocks rather than samples, and live health was not observable. | Integrate sum-of-squares across the whole take, count literal silent samples, version the writer contract, and expose a lock-protected live diagnostic snapshot. |
| BWF conformance | `codingHistory` was reported but not embedded, and RIFF sizes assumed a fixed BEXT extent. | Write coding history after the fixed BEXT fields with CRLF termination and even-byte padding; derive BEXT and RIFF sizes from the actual chunks. |
| Audio routing | A reference channel could point outside documented microphone placement. | Require a positive, documented effective reference channel in readiness and complete consistency audits; preserve legacy `nil` as channel 1 only when channel 1 is documented. |
| Pre-capture signal-path assurance | Momentary meters could not establish room/electronic floor, realistic organ headroom, independent routing, continuity, or which exact setup/device state had been checked. | Require a guided quiet-then-loud 12-second rehearsal for every session/setup revision/interface/sample-rate context; analyze only documented microphone channels for silence, clipping, headroom, SNR, room tone, DC, and capture integrity; detect digital duplication/inversion with correlation plus a −60 dB residual test; retain the BWF, SHA-256, device state, versioned thresholds, typed findings, and immutable verdict; block capture on a missing or failed matching report and preserve it through VAO/IAD exchange. |
| Sensor evidence | A finalization error could leave sensor capture wedged and discard recoverable raw evidence. | Always close and reset capture state, preserve raw evidence on finalization errors, and permit the next capture. |
| Package containment | Retained paths could escape a project through symlinks; duplicate semantic IDs could destabilize dictionary-based validation. | Reject symlinks in retained files or any existing parent component and reject duplicate high-risk IDs with typed project errors. |
| VAO exchange | A development-version implementation would not be suitable for exchange with the final VAO release. | Pin the immutable VAO 0.5.0 schema/context/profile identifiers and release evidence; write 0.5.0 preservation closures; retain exact 0.2, 0.3, and 0.4 dispatch; verify generated 0.5.0 carriers with the normative Python reference implementation in CI. |
| Reduced POD data | Bundling an unpublished or ambiguously licensed dataset would make the public source release misleading and difficult to audit. | Keep dataset bytes out of the repository; accept only a closed `orgrec-pod-subset/1` manifest derived from MODAVIS POD release 1.5; verify its inventory, byte sizes, digests, source identity, and publication status before atomic local import. |
| Organ footage | Footage parsing treated labels loosely, ignored footage in some imports, and could assign incorrect frequencies to 4′/16′ stops. | Centralize a strict single-footage parser and nominal-frequency derivation; route Roadmap, Navigator, demos, temperament, GrandOrgue/corpus, and tremulant planning through it. |
| Compound sounds | Mixtures, registrations, effects, and multiple emitters could be judged as if they had one fundamental. | Add explicit inferred-pitch applicability and suppress monophonic wrong-note/pitch claims where the source is compound or non-pitched. |
| Acoustic and spectral interpretation | One spectral summary could hide perceptually relevant distribution and modulation, ordinary pipe release could be mistaken for room RT, noise could manufacture long decay fits, and coupled spaces could be misrepresented by one slope. | Add conventional and ERB-rate descriptors, harmonic slope/deviation and tristimulus, independent amplitude/brightness modulation, explicit excitation provenance, noise-intersection-truncated and noise-subtracted Schroeder curves, range-gated EDT/T20/T30 with uncertainty and R², BIC multi-slope evidence, qualified early-energy metrics, exact standards references, validation, export, and visible limitations. |
| macOS window model | Multiple windows shared one mutable recording model and could bootstrap concurrently. | Use one identifiable primary window and an idempotent bootstrap path. |
| macOS document opening | A Finder-open event could race the launch restoration task and be rejected as “busy.” | Queue incoming document URLs, await the complete bootstrap transaction, and replay every queued intent serially. |
| macOS commands | Standard File/Project/Capture commands were incomplete and unmodified global keys could fire while typing. | Provide native New/Open/Save/export/navigation/capture menus with conventional modified shortcuts; remove single-key capture controls. |
| Workflow layout | Roadmap and Field QA controls clipped at narrower supported window sizes; capture blockers and warnings were conflated. | Use adaptive layouts, native search, a concise planning menu, semantic blocker/warning counts, and responsive QA cards. |
| Accessibility | Several custom rows, meters, waveform, and boundary controls lacked useful roles or values. | Make roadmap rows real buttons, retain individually operable boundary controls, and provide labels, hints, channel roles, and dBFS values for visual signal displays. |
| Visual identity | The bundle lacked a production icon and complete music-application metadata. | Add a reproducible multiresolution organ/acoustic app icon, music category, copyright, document roles, and high-resolution bundle metadata. |
| Distribution integrity | The app bundle was assembled without an explicit verification gate. | Lint the staged plist and entitlements, copy the icon and resources, sign with hardened runtime and audio-input access (ad hoc by default or a supplied Developer ID), verify the signature and retained entitlement, then publish `dist/OrgRec.app`. |

## Automated acceptance gates

- `swift build --product OrgRec`
- `swift test` (209 tests on 2026-08-31, including VAO 0.5.0 reference cross-validation, the POD subset boundary, scientific-provenance integrity, signal-path, acoustic ground-truth, reliability, containment, interruption recovery, and fault injection)
- `Scripts/build-app.sh` (optimized application bundle, plist lint, hardened-runtime signing, and strict signature verification)
- Visual inspection of the packaged application at its supported minimum and default window sizes

## External release gates

The repository can enforce software correctness, metadata, and ad-hoc bundle integrity. Public distribution still requires credentials and evidence that cannot be manufactured in source code:

- sign with the release owner’s Apple Developer ID and notarize the exact distribution artifact;
- perform a calibrated multichannel hardware pilot on each supported interface/clock topology;
- exercise microphone permission denial/recovery, device unplug, sleep, disk exhaustion, and quit recovery on a clean current macOS account;
- run VoiceOver and keyboard-only task walkthroughs with representative field operators;
- archive the resulting pilot project and its exported VAO/IAD validation report as release evidence.
