OrgRec 0.4.1 beta 1 (build 15) is a test build for **Apple Silicon and Intel Macs running macOS 14 or later**. It adds online MODAVIS organ lookup to the recording workflow. For basic app testing you need neither Xcode nor the offline POD database.

### Install the Mac app

1. Download **OrgRec-0.4.1-beta.1-macos-universal.zip** from Assets. To verify the download, place **SHA256SUMS** in the same folder and compare the app ZIP’s entry with the output of `shasum -a 256 OrgRec-0.4.1-beta.1-macos-universal.zip`.
2. Unzip the archive, move **OrgRec.app** to Applications and open it. This beta has an ad-hoc signature and is unnotarized. macOS may block the first launch. If you trust and have verified this download, follow Apple’s per-app instructions in System Settings → Privacy & Security. [Apple’s guide to opening apps safely](https://support.apple.com/en-us/102445)

### Try the recording workflow

1. Choose **Getting Started → Find a pipe organ**. Search for a venue, builder or MDVS ID. Use **View in Navigator** to inspect a matching source record.
2. Choose **Create recording project**. Check the venue, stops and proposed key ranges. A short-octave warning identifies keyboards that need a console check. Configure your own microphone placements in **Setup** before testing capture.
3. Quit, disconnect from the network and reopen the project. Check that the recording plan and source evidence are available. To test analysis separately, drop a short WAV file onto **Analyze Audio**.

The public Navigator can omit the protected database fingerprint required by IAD 1.0. Choose **Export VAO** to preserve such a project. The app writes VAO 0.5.0. The VAO 0.6.0 exporter is available in the source distribution as a command-line tool. For this beta, use a copy of any existing field project. Physical recording interfaces and Intel hardware still need tester coverage.

When reporting a problem, include your Mac model, macOS version, OrgRec build number and the steps to reproduce it. For catalogue issues, include the organ’s MDVS ID. [Report a testing issue](https://github.com/modavis-project/orgrec/issues)
