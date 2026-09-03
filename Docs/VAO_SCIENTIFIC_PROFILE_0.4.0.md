# VAO Scientific profile 0.4.0

Profile IRI: `https://w3id.org/modavis/vao/profile/scientific/0.4.0`

The profile is required when any scientific registry is non-empty. It requires typed Agent, Activity, Protocol, Software Environment, Observation, Analysis, Calibration, Claim, Review, and Consent records; resolved inputs/outputs; IRI units; explicit reproducibility; and evidence-preserving epistemic status.

PROV-O supplies Agent/Activity/Entity relations, SOSA/SSN supplies observation/procedure/sensor semantics, QUDT supplies quantities and units, and CRMsci/CRMdig may refine cultural-heritage measurement and digitization. External ontology use does not relax the closed VAO JSON contract.

Minimum reusable analysis evidence is: exact inputs and outputs, Activity, Protocol, responsible Agent, exact Software Environment, parameters, reproducibility class, and any random source. A result lacking that evidence is preserved as an unreviewed Claim or source document, not promoted to Analysis.
