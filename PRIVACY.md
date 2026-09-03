# Privacy

OrgRec is a local macOS application. It has no telemetry, advertising, user
account, or automatic cloud backup in the current source tree.

## Data stored locally

OrgRec projects can contain audio recordings, analysis results, venue and
instrument descriptions, coordinates, equipment and microphone details,
operator or reviewer names, rights statements, and imported source material.
Projects are stored under `Application Support/OrgRec/Projects` by default or
at a location chosen during import or export. Audio-device settings and the last
project path are retained in macOS preferences.

A user-selected reduced POD subset can be copied into
`Application Support/OrgRec/Datasets/POD` after manifest and checksum
verification. That cache is removable from the dataset workflow. No POD source
bytes are bundled with OrgRec and the selected source directory is not modified.

The user controls project deletion and export. OrgRec does not remove the
original source of an imported dataset.

## Optional network requests

Network access occurs when a user invokes a feature that needs it:

- MODAVIS Navigator search and specification retrieval send the search text or
  requested instrument identifier to the configured Navigator server;
- explicit Navigator submission uploads the selected package to that server;
- venue search sends the entered place text to the configured Nominatim
  service;
- surrounding-noise assessment sends the confirmed coordinates and radius to
  the configured Overpass service;
- the map view loads MapLibre resources from `unpkg.com` and tiles from
  `tile.openstreetmap.org`;
- links opened from the application are handled by the user's browser.

Those services receive normal network metadata such as the IP address and user
agent. Their own terms and privacy policies apply. OrgRec does not send recorded
audio during search, geocoding, or map display. Package submission is a
separate, explicit action.

## Microphone access

OrgRec asks macOS for audio-input permission when recording begins. Audio is
written to the active local project. macOS permission can be revoked in System
Settings under Privacy & Security.

## Sharing and publication

An exported `.orgrec`, `.vao`, or IAD package may retain source files and
provenance intentionally. Inspect its rights, contributor, venue, consent, and
location fields before sharing it. Removing a display label does not guarantee
that related metadata or media is anonymous.

This statement must be reviewed against the shipped binary and its configured
services for every public release.
