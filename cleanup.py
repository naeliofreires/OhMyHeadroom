"""Compatibility entry point for the feature-based Headroom engine."""

import sys

from headroom_engine.cli.commands import run_main

if __name__ == "__main__":
    sys.exit(run_main())
