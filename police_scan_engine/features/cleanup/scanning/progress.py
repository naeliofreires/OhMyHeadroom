"""Live progress for the menu bar app: one JSON line per folder measured, written to stderr.

The app reads these lines while the scan runs and shows which folder is being checked.
Without --progress nothing is written, so terminal output stays exactly as before.
"""

import json
import threading
from dataclasses import asdict
from typing import TextIO

from police_scan_engine.i18n import Localized


class ProgressReporter:
    """Numbers each folder as it starts being measured. With no stream it stays silent.

    Example: reporter = ProgressReporter(sys.stderr); reporter.start(10); reporter.step(label, path)
    """

    def __init__(self, stream: TextIO | None) -> None:
        self._stream = stream
        self._total = 0
        self._started = 0
        self._counter_lock = threading.Lock()
        self._write_lock = threading.Lock()

    def start(self, total: int) -> None:
        """Announce how many folders the scan will measure in total."""
        self._total = total
        self._write({"event": "start", "total": total})

    def step(self, label: Localized, path: str) -> None:
        """Announce the folder being measured now. Safe to call from worker threads."""
        with self._counter_lock:
            self._started += 1
            position = self._started
        self._write(
            {
                "event": "step",
                "position": position,
                "total": self._total,
                "label": asdict(label),
                "path": path,
            }
        )

    def _write(self, event: dict[str, object]) -> None:
        if self._stream is None:
            return
        line = json.dumps(event, ensure_ascii=False)
        with self._write_lock:
            self._stream.write(line + "\n")
            self._stream.flush()
