# VAO Physical Instrument profile 0.4.0

Profile IRI: `https://w3id.org/modavis/vao/profile/physical-instrument/0.4.0`

The profile describes instrument components as a network of typed ports and connections. Sensors and actuators reference scientific protocols; sensors may reference calibration; actuators may reference measured transfer functions. State bindings distinguish commands from observations and estimates.

Components reference semantic instrument Entities rather than replacing them. SOSA/SSN and MIMO/CIDOC classifications may refine the topology. Cycles require an explicit delay; zero-delay copy/transpose graphs remain acyclic.
