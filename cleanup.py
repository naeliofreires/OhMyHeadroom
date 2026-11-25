"""Compatibility entry point for the feature-based Police Scan engine."""

import sys

from police_scan_engine.cli.commands import run_main

if __name__ == "__main__":
    sys.exit(run_main())
