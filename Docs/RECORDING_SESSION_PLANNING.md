# Recording-session planning and surrounding-noise context

OrgRec treats a field visit as a revisioned plan layered on top of the
scientific Roadmap. Planning does not change Roadmap coverage: missing, queued,
rejected, recorded, and accepted remain evidence states. A plan only chooses
and orders existing obligations for a particular visit.

## Wizard workflow

Choose **Plan session…** in the Roadmap. The wizard records:

1. session title, purpose, operator, institution, field window, and access;
2. a subset of currently outstanding Roadmap obligations, including optional
   instrument-mechanics protocols and their repeat-take targets;
3. a confirmed building or manually verified coordinate;
4. a reviewed surrounding-noise assessment;
5. an editable capture queue and time/storage estimate;
6. preflight notes and the frozen plan revision.

The default queue follows the project's explicit microphone-setup and
registration order, then groups work by division, sound, note, and technique.
It never derives operator-facing order from UUID values. Estimates include the
capture recipe, operator overhead, 20 minutes of preparation, 10 minutes per setup change, configurable
contingency, and 24-bit PCM storage plus a container allowance. They are
planning estimates, not capture promises.

Saving freezes a plan for later. **Save and start session** closes the prior
active session, activates this plan, selects the first outstanding item in its
queue, and copies the reviewed assessment into the new session. Subsequent
accept/reject review advances to the next outstanding planned item. Revising a
saved plan increments its revision. Revising an active plan closes the prior
session and continues with a new active session so every session retains one
immutable plan and noise-context revision.

## Noise-context assessment

Venue search uses separate venue/address and locality fields so an operator can
include a city, postal code, region, or country instead of relying on an
ambiguous organ or church name. It uses user-triggered OpenStreetMap Nominatim
requests. OrgRec throttles them to the public-service limit and does not autocomplete on every
keystroke. The chosen result or an operator-entered coordinate becomes a
confirmed `VenueAnchor`.

An assessment queries OpenStreetMap through Overpass within a configurable
250–1,500 m UI radius (the service accepts 100–2,500 m). It screens for:

- motorway, trunk, primary, and secondary roads;
- rail, tram, light rail, subway, stations, stops, and yards;
- mapped construction and works;
- schools, colleges, universities, and kindergartens;
- hospitals, clinics, police, and fire stations;
- industrial land use;
- aerodromes and helicopter facilities;
- sports and event venues.

Duplicate named features and adjacent unnamed road or rail segments are
consolidated into reviewable planning indicators before the 100-result display
limit is applied. Consolidated indicators retain the source count and complete
OSM identifier list in their tags while showing representative geometry, which
prevents one mapped corridor from overwhelming the review and map.
Dense categories also use explicit review budgets that retain their highest
priority, nearest indicators. This keeps transport, construction, education,
emergency, industrial, aviation, and event warnings represented without
presenting the result as an exhaustive GIS inventory.

Each result retains its OSM identifier(s) and tags, geometry/coordinate, distance,
temporal pattern, evidence confidence, heuristic planning priority, review
disposition, and notes. Operators can confirm, dismiss, leave unverified, mark
for venue contact, or add a locally known source. They can also document a
separate check of an official local noise map or construction register.

The modal map uses MapLibre GL JS with OpenStreetMap raster tiles, an explicit
venue marker, search radius, feature geometry, priority styling, popups, and OSM
attribution. Map tiles are loaded only when the user opens the map. A missing
network affects the background map, not the already stored assessment.

## Scientific limits

The feature is deliberately called a *noise context*, not a noise prediction.
Road class and distance do not establish indoor sound pressure, audibility,
time of operation, façade attenuation, weather, or room isolation. Priorities
are transparent planning heuristics and never dB values. Construction data can
be stale; hospitals do not imply sirens; a school does not imply occupancy; and
a mapped aviation facility does not establish a flight path. The operator must
review conditions, contact the venue where appropriate, and record actual
events during capture.

## Capture and paradata

The Record workspace shows the session's frozen assessment without refreshing
network data. While recording, the operator can mark traffic, rail/tram, siren,
construction, or crowd/event incidents. One action creates:

- a timed take annotation (`environment_noise_<category>`); and
- a structured session `NoiseObservation` with category, label, clock time,
  take UUID, elapsed seconds, and recorder identity.

Field QA displays the assessment, source/retrieval information, map, and recent
observations. A missing assessment is a readiness and consistency warning, not
a capture blocker; an invalid plan or assessment reference is a consistency
blocker.

## Persistence and export

Additive optional fields keep schema-1 projects and historical sessions
decodable. An `.orgrec` project preserves the venue anchor, assessment history,
plan revisions, active session snapshot, observations, and per-take provenance.
IAD `sessions.jsonl` exports the structured assessment and incidents, and the
existing VAO export profile includes them as recording-session properties.

This work intentionally does not add or align any VAO 0.4.0 contracts, schemas,
profiles, validators, or carrier behavior.
