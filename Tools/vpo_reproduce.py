#!/usr/bin/env python3
"""Discoverable launcher for the comparative VPO reproduction tool."""

from pathlib import Path
import runpy


IMPLEMENTATION = (
    Path(__file__).resolve().parents[1]
    / "Research"
    / "ComparativeStopTimbre"
    / "vpo_reproduce.py"
)

if not IMPLEMENTATION.is_file():
    raise SystemExit(f"VPO reproduction implementation not found: {IMPLEMENTATION}")

runpy.run_path(str(IMPLEMENTATION), run_name="__main__")
