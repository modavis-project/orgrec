# Getting started with OrgRec

On the first launch, OrgRec opens **Getting Started**. The guide remains accessible in the sidebar on later launches. The St. Nikolai example can be opened through Explore demonstration / current project. It is identified as a demonstration; use a separate project for research recordings.

## Catalogue-based recording

1. Choose **Set up POD 1.6.0…** in Getting Started, or **Install POD 1.6.0…** in Find Organ.
2. Choose **Download, verify & install** with the prefilled Zenodo URL. No account or API key is required. The download is approximately 1.8 GB, expanding to a 5.8 GB database. Allow at least 15 GB free on the startup disk for temporary and installed copies.
3. Keep OrgRec open during download, verification and installation. The progress indicator shows activity, not a percentage. A failure leaves a retry explanation; the database becomes available only after verification succeeds.
4. Choose **Continue to Find Organ**. Search for an organ, inspect its source information, and create a project. Review the proposed ranks, keys and microphone setups against the actual instrument.
5. In **Setup**, select the audio interface and check channels and microphone geometry. Allow microphone access when requested. If previously denied, enable OrgRec in macOS System Settings → Privacy & Security → Microphone.
6. Complete the relevant **Field QA** checks and make a short test recording from a Roadmap target. Listen back and review analysis before continuing with the session.

If the unpacked OrgRec SQLite projection is already available, select it under **Local source**, wait for verification, then choose **Cache verified database**. A downloaded and installed database does not need to be cached again.

## Work without POD

Use **Create a local project…**, or **Open or import…** to reach the project library and its import controls. Audio dataset conversion is available in **Data Exchange**. POD and microphone access are not required to inspect imported audio. The demonstration project can be explored without downloading a catalogue.

## Scope of readiness indicators

The guide reports whether a verified catalogue is installed and whether a non-demo project is open. Opening a project does not certify its scientific suitability or recording readiness; those checks remain in Initialize, Setup and Field QA. Installation guidance does not perform a disk-space reservation. Download failures can be retried, but downloads do not resume from a saved partial file.

## Analyze a file directly

Choose **Analyze Audio** or drop a single audio file onto OrgRec. Short files are analyzed immediately; longer recordings offer an explicit excerpt selection. Results can be exported without a project. See [Standalone audio analysis](STANDALONE_AUDIO_ANALYSIS.md) for interpretation and export details. Getting Started now defers project loading until a project workflow is selected.
