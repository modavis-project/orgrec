# Getting started with OrgRec

On first launch, OrgRec opens **Getting Started**. You can return to it from the sidebar. **Explore demonstration / current project** opens the St. Nikolai example when you have no previous project.

## Find an organ and plan a session

1. Choose **Find a pipe organ**. Enter an organ, venue, builder, city or MDVS ID and select **Search**. The online catalogue uses the public MODAVIS Navigator and needs no account or database download.
2. Check the title, location and identifier. **View in Navigator** opens the source record when a result includes a record link. Choose **Create recording project**, or **Attach & build roadmap** if you prepared an empty local project. OrgRec retrieves the selected specification and saves its evidence with your project.
3. In **Initialize** and **Roadmap**, compare the proposed stops, compasses and tuning with the instrument. Historical records may describe a different configuration. Check short octaves and shared pipework before recording.
4. In **Setup**, configure the planned microphone positions, select the input device and check channel routing. Allow microphone access when requested. Previously denied access can be enabled under macOS System Settings → Privacy & Security → Microphone.
5. Complete the relevant **Field QA** checks. Record a short test from a Roadmap target, then listen back before starting the session.

## Prepare for offline catalogue work

Choose **Install the optional offline catalogue…** in Getting Started, or **Install offline catalogue…** in Find Organ. Choose **Download, verify & install** with the prefilled Zenodo URL. POD 1.6.0 downloads about 1.8 GB and expands to a 5.8 GB database. Allow at least 15 GB of free space for temporary and installed copies. Keep OrgRec open through verification. Downloads can be retried after failure.

If you already have the unpacked OrgRec SQLite projection, select it under **Local source**, wait for verification and choose **Cache verified database**. Find Organ defaults to the verified local catalogue. Choose **Online Navigator** there when you need the live service. You can reopen a recording plan you already saved while offline.

## Work without POD

Use **Create a local project…**, or **Open or import…** to reach the project library and its import controls. Audio dataset conversion is available in **Data Exchange**. POD and microphone access are not required to inspect imported audio. The demonstration project can be explored without downloading a catalogue.

## Scope of readiness indicators

The guide reports whether a verified catalogue is installed and whether a non-demo project is open. Opening a project does not certify its scientific suitability or recording readiness; those checks remain in Initialize, Setup and Field QA. Installation guidance does not perform a disk-space reservation. Download failures can be retried, but downloads do not resume from a saved partial file.

## Analyze a file directly

Choose **Analyze Audio** or drop a single audio file onto OrgRec. Short files are analyzed immediately; longer recordings offer an explicit excerpt selection. Results can be exported without a project. See [Standalone audio analysis](STANDALONE_AUDIO_ANALYSIS.md) for interpretation and export details. Getting Started now defers project loading until a project workflow is selected.
