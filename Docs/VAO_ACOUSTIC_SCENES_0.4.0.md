# VAO Spatial and Acoustics profiles 0.4.0

Profile IRIs:

- `https://w3id.org/modavis/vao/profile/spatial/0.4.0`
- `https://w3id.org/modavis/vao/profile/acoustics/0.4.0`

The closed 0.3.3 coordinate-frame, pose, geometry binding, material, source/receiver measurement, response-set, metric-set, audio-scene, render-configuration, and exact impulse-response mapping contracts remain normative. AES69-SOFA, WAVE/FLAC, HDF5, netCDF, Zarr, glTF, IFC, and ADM remain external realization formats.

0.4.0 adds trajectory tracks, multimodal clocks, activity-derived registration/synchronization, typed scientific observations, calibration, and per-result uncertainty. A moving source, listener, performer, camera, or sensor therefore uses an exact Track and clock rather than an unspecified `trajectoryAssetId` alone.
