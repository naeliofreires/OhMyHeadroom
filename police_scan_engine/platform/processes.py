"""Named process adapter seam for future test doubles."""

import subprocess
from collections.abc import Sequence


class ProcessRunner:
    """Run a command using the host process implementation.

    Example: ProcessRunner().run(("docker", "--version"))
    """

    def run(self, command: Sequence[str]) -> subprocess.CompletedProcess[str]:
        """Capture a command's output without raising on non-zero status."""
        return subprocess.run(command, capture_output=True, text=True, check=False)
