# Third-party notices

## CREPE / torchcrepe

OrgRec includes a Core ML conversion of the CREPE tiny pitch-estimation model.
CREPE was developed by Jong Wook Kim, Justin Salamon, Peter Li, and Juan Pablo
Bello and is distributed under the MIT License. The PyTorch port and checkpoint
are also provided by torchcrepe under the MIT License. OrgRec bundles a Core ML
conversion of the tiny checkpoint and retains the learned weights.

- CREPE: https://github.com/marl/crepe
- torchcrepe: https://github.com/maxrmorrison/torchcrepe

OrgRec adds 16 kHz framing, normalization, local weighted-average decoding, and
conversion provenance. The applicable license text is in `LICENSES/MIT.txt`.

## Empirical pipe-timbre classifier

No empirically trained pipe-timbre classifier is included in the public source
archive or application bundle. A replacement may be released with the reduced
POD subset after its training inventory, attribution, license, model card, and
evaluation record are final.
