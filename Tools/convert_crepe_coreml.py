#!/usr/bin/env python3
"""Convert the open CREPE tiny checkpoint distributed by torchcrepe to Core ML."""

from __future__ import annotations

import argparse
from pathlib import Path

import coremltools as ct
import torch
import torchcrepe


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path, help="Destination .mlmodel")
    arguments = parser.parse_args()

    model = torchcrepe.Crepe("tiny")
    checkpoint = Path(torchcrepe.__file__).parent / "assets" / "tiny.pth"
    model.load_state_dict(torch.load(checkpoint, map_location="cpu", weights_only=True))
    model.eval()

    example = torch.zeros(1, 1024, dtype=torch.float32)
    traced = torch.jit.trace(model, example)
    converted = ct.convert(
        traced,
        convert_to="neuralnetwork",
        inputs=[ct.TensorType(name="audio", shape=example.shape, dtype=float)],
        outputs=[ct.TensorType(name="activation")],
        minimum_deployment_target=ct.target.macOS11,
    )
    converted.short_description = "CREPE tiny pitch activation model for OrgRec"
    converted.author = "CREPE authors; converted by OrgRec"
    converted.license = "MIT"
    converted.version = "torchcrepe-tiny/0.0.24; orgrec-coreml/1"
    converted.input_description["audio"] = "Normalized 1024-sample mono frame at 16 kHz"
    converted.output_description["activation"] = "360 pitch-bin confidence activations"
    converted.save(arguments.output)


if __name__ == "__main__":
    main()
