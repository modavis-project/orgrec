# Field-pilot capture and review

## Recording contract

OrgRec captures each roadmap item as an independent take. The Core Audio input
callback only copies samples into a bounded pool of preallocated buffers. A
serial writer drains that pool to an explicit 24-bit little-endian PCM WAVE
file. The default pool holds 128 callback buffers; exhaustion is never hidden:
the take receives a queue-overrun fault and its dropped-buffer count increases.

Every completed take stores:

- received and written buffer/frame totals;
- timestamp-discontinuity and dropped-buffer counts;
- minimum observed free disk space;
- per-channel role, peak, RMS, clipped-sample, and silent-frame statistics;
- writer, device, disk, and format-change faults with timestamps;
- actual Core Audio device, channel count, sample rate, buffer, and latency;
- the selected reference channel for CREPE and spectral analysis; and
- BWF metadata, JSON sidecar, audio checksum, and file size.

The writer embeds an EBU Tech 3285 `bext` chunk after recording and writes the
same provenance to `<take>.bwf.json`. If embedding cannot safely be performed,
the audio remains intact, the sidecar remains authoritative, and OrgRec exposes
the finalizer message instead of silently claiming embedded metadata.

OrgRec refuses to start with less than 2 GiB free or when a configured
microphone channel exceeds the selected interface's input count. During
capture it watches device-alive state and nominal sample-rate changes.

## Interface and channel preparation

1. Select the physical, Aggregate, AVB, or virtual Core Audio input in Record.
2. Choose the requested sample rate and Safe, Balanced, Ultra-low, or custom
   buffer policy. The UI shows the negotiated value and estimated input path
   latency; hardware drivers retain final authority.
3. In Setup, create a revised setup and assign each microphone to a one-based
   interface channel and a semantic role. Choose one analysis reference
   channel. Phantom-power state is documentation only; OrgRec does not switch
   hardware phantom power.
4. Make a short routing take and check every channel meter and saved diagnostic.
   Correct persistent silence, clipping, wrong routing, or unexpected
   cross-channel energy at the hardware or setup level before the session.

Setup revisions are append-only. Saving a revision gives it a new identifier
and increments the revision number. Only roadmap items without takes are
reassigned; existing takes continue to point to the setup used at capture time.

## Continuous-stop field protocol

For the normal pipe-organ workflow, OrgRec can capture a complete stop in one
long take instead of requiring a separate recording action for every pipe.

1. Select the first expected roadmap note and choose **Ascending from selected
   note** in the Record screen.
2. Start **Record long take** and play one isolated pipe at a time in roadmap
   order. Hold each note for a stable sustain, release it fully, and leave at
   least 0.4 seconds before the next key-down.
3. Retries may remain in the same recording. Do not conceal absent, silent, or
   failed pipes by changing the starting position midway through a file.
4. After Stop, review the detected regions and joint roadmap assignments.
   Inspect warnings for retries, missing pipes, unrelated sounds, ambiguous
   pitch, censored decay, and fallback boundaries.
5. Create note takes only after this review. Every derived take begins in
   `needsReview`; the checksummed long master remains unchanged.

Existing PCM WAV or AIFF masters follow the same workflow through **Import long
WAV**. Capture/import parity is deliberate: both routes use the configured
reference channel, exact-frame boundaries, frequency-local harmonic decay, and
the same classification code. See
[`LONG_TAKE_RECORDING.md`](LONG_TAKE_RECORDING.md) for the method, recording
guidance, validation results, limitations, and scientific references.

## Review and marker correction

Analysis uses the selected setup reference channel for CREPE, adaptive acoustic
onset/offset detection, the waveform, spectrogram, and partial tracking. The
review screen can play, pause, seek, skip, and loop the take. An operator can
mark physical key-down and key-up live, or add annotations at the playback
cursor.

Automated and operator markers are not overwritten. Saving reviewed onset,
sustain, key-up, sound-offset, or tail values appends a `MarkerCorrection` with
the original automated value, corrected value, reviewer, reason, and timestamp.
The newest correction for a marker becomes the effective display value while
the complete history remains in the project and exported analysis envelope.

## Acceptance run

The hardware-independent harness exercises the same queued writer and BWF
finalizer used by the app:

~~~sh
swift run -c release OrgRecStress \
  --duration 30 \
  --channels 8 \
  --sample-rate 96000 \
  --buffer-frames 512 \
  --output /tmp/orgrec-field-pilot.wav
~~~

Accept the run only when the report shows:

- the requested channel count, sample rate, and 24-bit depth;
- written buffers equal received buffers;
- zero dropped buffers and timestamp discontinuities;
- zero faults; and
- successful embedded BWF metadata.

Use `--unthrottled` as a queue saturation test, not as a real-time acceptance
test. It deliberately supplies buffers faster than an interface would.

For a venue pilot, additionally record a short take on every routed microphone,
unplug/replug only in a sacrificial test project to verify the device fault is
visible, inspect the saved diagnostics, play the file, correct one marker, and
export a capture package. Verify package checksums before erasing any recorder
media.

## Recovery boundary

Each accepted take is durably closed and checksummed when Stop completes. A
process or power loss during an active WAVE write can leave that current file's
container header incomplete; previously stopped takes and project metadata are
unaffected. A journaled/recoverable active-take container and automatic crash
resume are beyond this field-pilot batch and remain the principal production
hardening item.
