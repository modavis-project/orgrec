# VAO Playable profile 0.4.0

Profile IRI: `https://w3id.org/modavis/vao/profile/playable/0.4.0`

All 0.3.3 Playable functionality remains: protocol-independent interactions, exact half-open signal regions, multi-loop sets, tuning maps, perspectives, variants, mappings, recorded releases, source-sampler locators, persistent controls, guarded transitions, conditional routing, compound/timed processes, transfer functions, render bindings, capture states, event/audio alignment, take sets, and derivation maps.

0.4.0 strengthens the profile by requiring explicit deterministic execution semantics for `interactionModel`, reproducible stochastic processes, MIDI 2 metadata, delayed-cycle declarations, transfer domains/extrapolation, and executable conformance traces when deterministic-runtime capability is claimed. Sample data remains exact realization evidence; a runtime may render it but cannot rewrite it.

The MIDI number attached to a control is not assumed to be sounding pitch. Played key, source-definition key, actuator key, and sounding key remain separate meanings with explicit transforms.
