#!/usr/bin/env python3
"""Run the reusable two-profile acceptance harness against Sprint 4.2.1.

The Compose project and evidence destination are isolated from retained data.
Credentials are supplied only through S42_OWNER_PASSWORD and are never logged.
"""

from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = spec_from_file_location(
    "sprint42_acceptance",
    ROOT / "scripts" / "sprint42-browser-acceptance.py",
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load the Sprint 4.2 browser harness")
HARNESS = module_from_spec(SPEC)
SPEC.loader.exec_module(HARNESS)
HARNESS.WEB = "http://localhost:3000"
HARNESS.OWNER_EMAIL = "owner@sprint421.local"
HARNESS.OWNER_COMPANY = "Sprint 4.2.1 Disposable Acceptance"
HARNESS.EVIDENCE = ROOT / "docs" / "evidence" / "sprint4_2_1"


if __name__ == "__main__":
    HARNESS.main()
