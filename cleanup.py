"""Compatibility entry point for the feature-based OhMyHeadroom engine."""

import sys

from ohmyheadroom_engine.cli.commands import run_main

if __name__ == "__main__":
    sys.exit(run_main())
